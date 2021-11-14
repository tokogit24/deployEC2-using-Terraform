# Create myapp Security Group
resource "aws_security_group" "myapp-sg" {
  name                = "myapp-sg"
  description         = "Allow HTTP inbound traffic"
  vpc_id              = var.vpc_id

  ingress {
    description       = "HTTP from VPC"
    from_port         = 22
    to_port           = 22
    protocol          = "tcp"
    cidr_blocks       = [var.my_ip]
  }

  ingress {
    description       = "HTTP from VPC"
    from_port         = 8080
    to_port           = 8080
    protocol          = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
  }


  egress {
    from_port         = 0
    to_port           = 0
    protocol          = "-1"
    cidr_blocks       = ["0.0.0.0/0"]
    prefix_list_ids   = []
  }

  tags                = {
    Name              = "${var.env_prefix}-sg"
  }
}

# Key pair creation and automation

resource "aws_key_pair" "ssh-key" {
    key_name           = "server-key"
    public_key         = file(var.public_key_location)
}

#Create EC2 Instance
data "aws_ami" "latest-amazon-linux-image" {
    most_recent        = true
    owners             = ["amazon"] 
    filter             {
        name           = "name"
        values         = [var.image_name]
    }
    filter {
        name           = "virtualization-type"
        values         = ["hvm"]

    }
}

resource "aws_instance" "myapp-server" {
  ami                         = data.aws_ami.latest-amazon-linux-image.id
  instance_type               = var.instance_type
  availability_zone           = var.avail_zone
  vpc_security_group_ids      = [aws_security_group.myapp-sg.id]
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true
  key_name                    = aws_key_pair.ssh-key.key_name
  user_data                   = file("entry-script.sh")

  tags = {
    Name = "${var.env_prefix}-server"
  }

}