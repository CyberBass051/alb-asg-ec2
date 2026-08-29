module "vpc" {
  source = "../../modules/vpc"

  project_name = "alb-project"
  owner        = "Pietro"
  region       = "us-east-1"
  vpc_cidr     = "10.32.0.0/16"
  azs          = ["us-east-1a", "us-east-1b"]
  tier_config = {
    web = {
      cidr_offset   = 1
      map_public_ip = true
    }
    app = {
      cidr_offset   = 11
      map_public_ip = false
    }
    db = {
      cidr_offset   = 21
      map_public_ip = false
    }
  }
  route_config = {
    web = { public = true }
    app = { public = false }
    db  = { public = false }
  }
}

module "security" {
  source       = "../../modules/security"
  vpc_id       = module.vpc.vpc_id
  project_name = "alb-project"
  vpc_cidr     = "10.32.0.0/16"
}

module "alb" {
  source         = "../../modules/alb"
  vpc_id         = module.vpc.vpc_id
  project_name   = "alb-project"
  owner          = "Pietro"
  web_subnet_ids = values(module.vpc.web_subnet_ids)
  alb_sg_id      = module.security.alb_sg_id
}

module "dns_acm" {
  source = "../../modules/dns_acm"

  project_name        = "alb-project"
  owner               = "Pietro"
  domain_name         = "cyberbass.live"
  lb_target_group_arn = module.alb.lb_target_group_arn
  lb_arn              = module.alb.lb_arn
}