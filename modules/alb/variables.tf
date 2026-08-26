variable "project_name" {
  type = string
}

variable "owner" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "web_subnet_ids" {
  type = list(string)
}

variable "alb_sg_id" {
  type = string
}
