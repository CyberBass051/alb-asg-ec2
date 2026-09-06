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

module "asg" {
  source = "../../modules/compute_asg"

  project_name        = "alb-project"
  region              = "us-east-1"
  lb_target_group_arn = module.alb.lb_target_group_arn
  web_sg_id           = module.security.web_sg_id
  app_subnet_ids      = values(module.vpc.app_subnet_ids)
}

module "dns_acm" {
  source = "../../modules/dns_acm"

  project_name        = "alb-project"
  owner               = "Pietro"
  domain_name         = "cyberbass.live"
  lb_target_group_arn = module.alb.lb_target_group_arn
  lb_arn              = module.alb.lb_arn
  nlb_dns_name        = module.nlb.nlb_dns_name
  nlb_zone_id         = module.nlb.nlb_zone_id
}

module "waf" {
  source       = "../../modules/waf"
  project_name = "alb-project"
  owner        = "Pietro"
  alb_arn      = module.alb.lb_arn
}

module "nlb" {
  source = "../../modules/nlb"

  project_name = "alb-project"
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = values(module.vpc.web_subnet_ids)

  internal          = false
  allocate_eips     = true
  enable_cross_zone = true

  listener_port     = 443
  listener_protocol = "TCP"


  client_cidrs     = ["0.0.0.0/0"]
  target_mode      = "alb"
  target_port      = 443
  target_protocol  = "TCP"
  alb_arn          = module.alb.lb_arn
  alb_listener_arn = module.dns_acm.https_listener_arn

  health_check = {
    protocol = "HTTPS"
    port     = "443"
    path     = "/"
    matcher  = "200-399"
  }
}
