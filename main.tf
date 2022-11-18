terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

# Configure the AWS Provider

provider "aws" {
  region = "us-east-1"
  access_key = ""
  secret_key = ""
}

# 1. Create VPC

resource "aws_vpc" "Lab_VPC" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Lab VPC"
  }
}

# 2. Create Internet Gateway

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.Lab_VPC.id
}

# 3. Create Private and Public Route Tables

resource "aws_route_table" "Public_RT" {
  vpc_id = aws_vpc.Lab_VPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Public Route Table"
  }
}

resource "aws_nat_gateway" "Private_NAT_GW" {
  connectivity_type = "private"
  subnet_id         = aws_subnet.Public_Subnet_1.id
  tags = {
    Name = "Private Route Table"
  }
}

# 4. Create a Subnets

resource "aws_subnet" "Public_Subnet_1" {
  vpc_id     = aws_vpc.Lab_VPC.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Public Subnet 1"
  }
}

resource "aws_subnet" "Private_Subnet_1" {
  vpc_id     = aws_vpc.Lab_VPC.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Private Subnet 1"
  }
}

resource "aws_subnet" "Public_Subnet_2" {
  vpc_id     = aws_vpc.Lab_VPC.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Public Subnet 2"
  }
}

resource "aws_subnet" "Private_Subnet_2" {
  vpc_id     = aws_vpc.Lab_VPC.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Private Subnet 2"
  }
}
# 5. Associate subnet with Route Table

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.Public_Subnet_1.id
  route_table_id = aws_route_table.Public_RT.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.Public_Subnet_2.id
  route_table_id = aws_route_table.Public_RT.id
}

# 6. Create Security Group to allow port 22, 80, 443 (SSH, HTTP, HTTPS)

resource "aws_security_group" "Web_Security_Group" {
  name        = "Web Security Group"
  description = "Enable HTTP access"
  vpc_id      = aws_vpc.Lab_VPC.id

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# 7. Create a network interface with an ip in the subnet that was created in step 4

resource "aws_network_interface" "web_server_nic" {
  subnet_id       = aws_subnet.Public_Subnet_2.id
  private_ips     = ["10.0.2.50"]
  security_groups = [aws_security_group.Web_Security_Group.id]

}

# 8. Assign an elastic IP to the network interface created in step 7

resource "aws_eip" "two" {
  vpc                       = true
  network_interface         = aws_network_interface.web_server_nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [
    aws_internet_gateway.gw
  ]
}

# 9. Create Linux server and instal/enable apache2

resource "aws_instance" "web_server_instance" {
  ami = "ami-0b0dcb5067f052a63"
  instance_type = "t2.micro"
  availability_zone = "us-east-1b"
  key_name = "ReStart-access-key"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web_server_nic.id
  }

  user_data = <<-EOF
        #!/bin/bash
        # Install Apache Web Server and PHP
        yum install -y httpd mysql php
        # Download Lab files
        wget https://aws-tc-largeobjects.s3.us-west-2.amazonaws.com/CUR-TF-100-RESTRT-1/267-lab-NF-build-vpc-web-server/s3/lab-app.zip
        unzip lab-app.zip -d /var/www/html/
        # Turn on web server
        chkconfig httpd on
        service httpd start
        EOF

    tags = {
        Name = "Web Server 1"
    }
}