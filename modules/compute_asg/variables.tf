variable "project_name" {
  type = string
}

variable "region" {
  type = string
}

variable "web_sg_id" {
  type = string
}

variable "lb_target_group_arn" {
  type = string
}

variable "app_subnet_ids" {
  type = list(any)
}