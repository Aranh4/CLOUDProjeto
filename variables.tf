variable "aws_region" {
    type = string
    default = "us-east-1"
}

variable "vpc_cidr_block" {
    type = string
    default = "10.0.0.0/16"
}

variable "subnet_count" {
    type = map(number)
    default = {
        public = 2
        private = 2
    }
}

variable "settings" {
    type = map(any)
    default = {
      "database" = {
        allocated_storage = 10
        engine = "mysql"
        engine_version = "8.0.35"
        instance_class = "db.t2.micro"
        db_name =  "mydb"
        skip_final_snapshot = true
      },
      "web_app" = {
        count = 1
        instance_type = "t2.micro"
      }
    }
}

variable "public_subnet_cidr_blocks" {
    type = list(string)
    default = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
}

variable "private_subnet_cidr_blocks" {
    type = list(string)
    default = ["10.0.20.0/24","10.0.21.0/24","10.0.23.0/24","10.0.24.0/24"]
  
}

variable "db_username" {
    type = string
}

variable "db_password" {
    type = string
}


