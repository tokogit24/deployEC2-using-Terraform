#!/bin/bash
sudo yum update -y && sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-usermod
docker run -p 8080:80 nginx
