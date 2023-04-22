provider "aws" {
  # Configuration options
  region = "us-east-1"
  access_key = "abcd"
  secret_key = "efgh"

}

#1 Create a VPC
resource "aws_vpc" "myfirstvpc" {
  cidr_block       = "10.0.0.0/16"

  tags = {
    Name = "awsvpcc"
  }
}

#2 Create internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.myfirstvpc.id

  tags = {
    Name = "My demo gateway"
  }
}

#3 Create custom route table
resource "aws_route_table" "example" {
  vpc_id = aws_vpc.myfirstvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "custom route demo"
  }
}

#4 Create a subnet
resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.myfirstvpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "subent demo"
  }
}

#5 Associate subnet with route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.example.id
}

#6 Create a security group to allow port 22, 80, 443
resource "aws_security_group" "allow_tls" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.myfirstvpc.id

  ingress {
    description      = "Https"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

   ingress {
    description      = "http"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

   ingress {
    description      = "ssh"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
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

#7 create network interface
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.main.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_tls.id]
}

#8 assign elastic ip
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = ["aws_internet_gateway.gw"]
}

#9 ubuntu instance

resource "aws_instance" "web" {
  ami           = "ami-007855ac798b5175e"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "mykey2"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }

  tags = {
    Name = "HelloWorld"
  }

  user_data = <<-EOF
                #!bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo your very first web server > /var/www/html/index.html'
                EOF
}
