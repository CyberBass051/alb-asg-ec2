variable "project_name" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "tier_config" {
  type = map(object({
    cidr_offset   = number
    map_public_ip = bool
  }))
}

variable "route_config" {
  type = map(object({
    public = bool
  }))
}

variable "owner" {
  type = string
}