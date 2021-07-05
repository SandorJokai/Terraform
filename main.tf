terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

resource "aws_vpc" "vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "terraform-vpc"
  }
}

resource "aws_subnet" "subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "terraform-sn"
  }
}

# Create an internet gateway

resource "aws_internet_gateway" "terraform-gw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "terraform-gw"
  }
}

# Create a route table for vpc

resource "aws_route_table" "terraform-rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.terraform-gw.id
  }

  tags = {
    Name = "terraform-rt"
  }
}

# Create route table association with subnet

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet.id
  route_table_id = aws_route_table.terraform-rt.id
}

# Create a Security group where port 80 will be allowed

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow http 80 inbound traffic"
  vpc_id      = aws_vpc.vpc.id

# Incoming traffic enabled

  ingress {
    description      = "HTTP from everywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
# HTTP only allowed from the vpc
#    cidr_blocks      = [aws_vpc.vpc.cidr_block]
    cidr_blocks       = ["0.0.0.0/0"]
  }

ingress {
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
  }

# Outgoing traffic enabled

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_http"
  }
}

# Create a network interface

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_http.id]
}

resource "aws_eip" "one" {
  vpc                       = true
#  instance                  = aws_network_interface.web-server-nic.id
  instance                  = aws_instance.web.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.terraform-gw]
}

# Create an EC2 instance

resource "aws_instance" "web" {
  ami                    = "ami-09e67e426f25ce0d7"
  instance_type          = "t2.micro"
  availability_zone      = "us-east-1b"
  key_name               = "ssh-key.pem"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }
  #vpc_security_group_ids = ["aws_security_group.allow_http.id"]
  user_data = <<-EOF
    #!/bin/bash
    sudo apt update
    sudo apt install apache2 -y
    sudo systemctl enable --now apache2
    echo "<h3>Welcome to my website which has built via terraform</h3>" > /var/www/html/index.html
  EOF

  tags = {
    Name = "web-app"
  }
}

resource "aws_key_pair" "ssh-credentials" {
  key_name   = "ssh-key.pem"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDttZaLoMCBVPihZvEkNFEJ6uqKneChirrmcQzGWjghvcWCAb+glzmJEvWiH3EzwIq1pVrHJY21vGSig8gx2ExEJ8cdidsAH217TA6WBO//SUz1Zi4cGQjkkiGO5BhwZIiDmagT8m/JKE+8yLjIYgT8y261dJsRDh41nNk4K+clWnzZVFa0/7qVvRWfswChwirc26GGUO/rs9QaRxJkd+1Pv4+rBeckCEq9H//L38YrnH65YYWV+5+Qtp5JJv4iIzRKpsWkuUzXgvy4lSGi8lWJyzCKPXrFF4JR6cCwn8LyLx5H+4vWoOFGK7ownNuGIsobP8JGNIh2NhZwdV6CS91Z shanx@shanx"
}
