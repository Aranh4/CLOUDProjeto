
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.16"
    }
  }

  backend "s3" {
    bucket = "caiotieri-bucket"
    key    = "terraform.tfstate"
    region = "us-east-1"
    
  }
}

provider "aws" {
  region = var.aws_region // Replace with your desired AWS region
}

data "aws_availability_zones" "available" {
    state = "available"
  
}

resource "aws_vpc" "project_vpc" {
  cidr_block = var.vpc_cidr_block

  tags = {
    Name = "Project VPC"
  }
}


//SUBNET AND GATEWAY-----------------------------------------------------
resource "aws_subnet" "PublicSub" {
    count = var.subnet_count.public

  vpc_id            = aws_vpc.project_vpc.id
  cidr_block        = var.public_subnet_cidr_blocks[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "Public Subnet ${count.index + 1}"
  }
}



resource "aws_subnet" "PrivateSub" {
  vpc_id            = aws_vpc.project_vpc.id
  count = var.subnet_count.private
  cidr_block        = var.private_subnet_cidr_blocks[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index] 

  tags = {
    Name = "Private Subnet ${count.index + 1}"
  }
}



resource "aws_internet_gateway" "Gate" {
  vpc_id = aws_vpc.project_vpc.id

  tags = {
    Name = "Project Gateway"
  }

}

//ROUTE TABLES AND ASSOCIATIONS-----------------------------------------------------

resource "aws_route_table" "PublicRoute" {
  vpc_id = aws_vpc.project_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Gate.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.Gate.id
  }

  tags = {
    Name = "Public Route Table"
  }
}

resource "aws_route_table_association" "PublicSubRoute" {
    count = var.subnet_count.public
  subnet_id      = aws_subnet.PublicSub[count.index].id
  route_table_id = aws_route_table.PublicRoute.id
}



resource "aws_route_table" "private_rt" {
    vpc_id = aws_vpc.project_vpc.id  
}

resource "aws_route_table_association" "private_rta" {
    count = var.subnet_count.private
    subnet_id      = aws_subnet.PrivateSub[count.index].id
    route_table_id = aws_route_table.private_rt.id
}



//Security Groups-----------------------------------------------------

resource "aws_security_group" "web_sg" {
  name   = "HTTP and SSH"
  vpc_id = aws_vpc.project_vpc.id

  ingress {
    description = "HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db_sg" {
  name   = "DB"
  vpc_id = aws_vpc.project_vpc.id

  ingress {
    description = "allow mysql traffic from only web_sg"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.web_sg.id]
    
  }
}

//RDS-----------------------------------------------------
resource "aws_db_subnet_group" "my_db_subnet_group" {
    name       = "my_db_subnet_group"
    subnet_ids = [for subnet in aws_subnet.PrivateSub : subnet.id]
  
}



resource "aws_db_instance" "database" {
    skip_final_snapshot = var.settings.database.skip_final_snapshot
    
    db_name =  var.settings.database.db_name
    allocated_storage = var.settings.database.allocated_storage
    engine = var.settings.database.engine
    engine_version = var.settings.database.engine_version
    instance_class = var.settings.database.instance_class
    username = var.db_username
    password = var.db_password
    db_subnet_group_name = aws_db_subnet_group.my_db_subnet_group.id


    vpc_security_group_ids = [aws_security_group.db_sg.id]
    

  
}




//EC2-----------------------------------------------------

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


# resource "aws_instance" "web_instance" {
#     count = var.settings.web_app.count
#   ami           = data.aws_ami.ubuntu.id
#   instance_type = var.settings.web_app.instance_type
#   key_name      = "MyKeyPair"

#   subnet_id                   = aws_subnet.PublicSub[count.index].id
#   vpc_security_group_ids      = [aws_security_group.web_sg.id]
#   associate_public_ip_address = true

#   user_data = <<-EOF
#   #!/bin/bash -ex

#   sudo apt update -y
#   sudo apt install apache2    
#   sudo systemctl enable apache2
#   sudo systemctl start apache2  

#   sudo apt install mysql-client -
#   EOF


# }


#autoscaling-----------------------------------------------------

resource "aws_launch_template" "my_lt" {
  name_prefix   = "my-launch-template"
  image_id      = "ami-0fc5d935ebf8bc3bc"
  instance_type = "t2.micro"
  user_data = base64encode(<<-EOF
    #!/bin/bash
    sudo touch app.log 
    export DEBIAN_FRONTEND=noninteractive

    sudo apt -y remove needrestart
    echo "fez o needrestart" >> app.log
    sudo apt-get update
    echo "fez o update" >> app.log
    sudo apt-get install -y python3-pip python3-venv git
    echo "fez o install de tudo" >> app.log

    python3 -m venv /home/ubuntu/myappenv
    echo "criou o env" >> app.log
    source /home/ubuntu/myappenv/bin/activate
    echo "ativou o env" >> app.log

    git clone https://github.com/ArthurCisotto/aplicacao_projeto_cloud.git /home/ubuntu/myapp
    echo "clonou o repo" >> app.log


    pip install -r /home/ubuntu/myapp/requirements.txt
    echo "instalou os requirements" >> app.log

    sudo apt-get install -y uvicorn
    echo "instalou o uvicorn" >> app.log
 

    export DATABASE_URL="mysql+pymysql://${var.db_username}:${var.db_password}@${aws_db_instance.database.endpoint}/${var.settings.database.db_name}"
    echo "exportou o url" >> app.log

    cd /home/ubuntu/myapp
    # Inicialização da aplicação
    uvicorn main:app --host 0.0.0.0 --port 80 
    echo "inicializou" >> app.log
  EOF
  )

  network_interfaces {
    security_groups             = [aws_security_group.web_sg.id]
    associate_public_ip_address = true
    subnet_id                   = aws_subnet.PublicSub[0].id
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "mylaunchtemplate"
    }
  }
}

resource "aws_autoscaling_group" "asg" {
  desired_capacity     = 2
  max_size             = 5
  min_size             = 2
  vpc_zone_identifier = [for subnet in aws_subnet.PublicSub : subnet.id]
  target_group_arns = [aws_lb_target_group.mylb_target_group.arn]

  launch_template {
    id      = aws_launch_template.my_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "myasg"
    propagate_at_launch = true
  }   

  # Other configurations...
}

#LOAD BALANCER-----------------------------------------------------

resource "aws_lb" "mylb" {
  name               = "mylb"
  internal           = false
  load_balancer_type = "application"

  enable_deletion_protection = false

  security_groups = [aws_security_group.web_sg.id]
  subnets         = [for subnet in aws_subnet.PublicSub : subnet.id]
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "my-lb"
  }
}

resource "aws_lb_target_group" "mylb_target_group" {
  name     = "mylb-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.project_vpc.id

  health_check {
    interval            = 10
    path                = "/healthcheck"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }


}

resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = aws_lb.mylb.arn
  port              = "80"	
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.mylb_target_group.arn
    type             = "forward"
  }

  # Other configurations...
}

resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.asg.name
  lb_target_group_arn   = aws_lb_target_group.mylb_target_group.arn
  
}





