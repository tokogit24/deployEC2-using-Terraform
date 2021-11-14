# Configure the AWS Provider
provider "aws" {
    region = var.aws_region
}

variable vpc_cidr_block {}
variable subnet_cidr_block {}
variable avail_zone {}
variable env_prefix {}
variable aws_region {}
variable my_ip {}
variable instance_type {}
variable public_key_location {}
variable private_key_location {}
  
# Create a VPC
resource "aws_vpc" "myapp-vpc" {
    cidr_block        = var.vpc_cidr_block
    tags              = {
        Name          = "${var.env_prefix}-vpc"
    }
}

# Create myapp Subnet
resource "aws_subnet" "myapp-subnet-1" {
    vpc_id            = aws_vpc.myapp-vpc.id
    cidr_block        = var.subnet_cidr_block
    availability_zone = var.avail_zone
    tags              = {
        Name          = "${var.env_prefix}-subnet-1"
    }
}

# Create my app Internet Gateway
resource "aws_internet_gateway" "myapp-igw" {
  vpc_id              = aws_vpc.myapp-vpc.id

  tags                = {
    Name              = "${var.env_prefix}-igw"
  }
}

# Create myapp route table
resource "aws_route_table" "myapp-route-table" {
  vpc_id              = aws_vpc.myapp-vpc.id


  route {
    cidr_block        = "0.0.0.0/0"
    gateway_id        = aws_internet_gateway.myapp-igw.id
  }

  tags                = {
    Name              = "${var.env_prefix}-rtb"
  }
}

# Create myapp Subnet association with myapp route table
resource "aws_route_table_association" "a-rtb-subnet" {
  subnet_id           = aws_subnet.myapp-subnet-1.id
  route_table_id      = aws_route_table.myapp-route-table.id
}

# Create myapp Security Group
resource "aws_security_group" "myapp-sg" {
  name                = "myapp-sg"
  description         = "Allow HTTP inbound traffic"
  vpc_id              = aws_vpc.myapp-vpc.id

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
        values         = ["amzn2-ami-hvm-*-x86_64-gp2"]
    }
    filter {
        name           = "virtualization-type"
        values         = ["hvm"]

    }
}

output "aws_ami_id" {
    value              = data.aws_ami.latest-amazon-linux-image.id
}
output "ec2_public_ip" {
    value = aws_instance.myapp-server.public_ip
}
resource "aws_instance" "myapp-server" {
  ami                         = data.aws_ami.latest-amazon-linux-image.id
  instance_type               = var.instance_type
  availability_zone           = var.avail_zone
  vpc_security_group_ids      = [aws_security_group.myapp-sg.id]
  subnet_id                   = aws_subnet.myapp-subnet-1.id
  associate_public_ip_address = true
  key_name                    = aws_key_pair.ssh-key.key_name
  # user_data                   = file("entry-script.sh")

  # To run command to allow us to connect to the remote server and execute command on the server
  connection {
    type = "ssh"
    host = self.public_ip
    user = "ec2-user"
    private_key = file(var.private_key_location)
  }

  provisioner "file" {
    source = "entry-script.sh"
    destination = "/home/ec2-user/entry-script-on-ec2.sh"
  }

  provisioner "remote-exec" {
    script = file("entry-script-on-ec2.sh")
  }

  provisioner "local-exec" {
    command = "echo ${self.public_ip} > output.txt"
  }

  tags = {
    Name = "${var.env_prefix}-server"
  }

}
