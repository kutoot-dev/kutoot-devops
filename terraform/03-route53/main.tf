# -----------------------------------------------------------------------------
# Remote state from 01-alb
# -----------------------------------------------------------------------------

data "terraform_remote_state" "alb" {
  backend = "local"
  config = {
    path = "${path.module}/../01-alb/terraform.tfstate"
  }
}

# -----------------------------------------------------------------------------
# Route 53 Hosted Zone (optional - create new or use existing)
# -----------------------------------------------------------------------------

resource "aws_route53_zone" "main" {
  count   = var.create_hosted_zone ? 1 : 0
  name    = var.domain_name
  comment = "Kutoot production - ${var.domain_name}"
}

locals {
  zone_id = var.create_hosted_zone ? aws_route53_zone.main[0].zone_id : (var.route53_zone_id != "" ? var.route53_zone_id : "")
  alb_dns = data.terraform_remote_state.alb.outputs.alb_dns_name
  alb_zone_id = data.terraform_remote_state.alb.outputs.alb_zone_id
}

# -----------------------------------------------------------------------------
# ACM Certificate (HTTPS)
# -----------------------------------------------------------------------------

resource "aws_acm_certificate" "main" {
  count             = local.zone_id != "" ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = [
    "www.${var.domain_name}"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "kutoot-${var.domain_name}"
  }
}

# DNS validation records for ACM
resource "aws_route53_record" "cert_validation" {
  for_each = local.zone_id != "" ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = local.zone_id
}

resource "aws_acm_certificate_validation" "main" {
  count                   = local.zone_id != "" ? 1 : 0
  certificate_arn         = aws_acm_certificate.main[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# -----------------------------------------------------------------------------
# DNS Records - www.kutoot.com -> ALB
# -----------------------------------------------------------------------------

resource "aws_route53_record" "www" {
  count   = local.zone_id != "" ? 1 : 0
  zone_id = local.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = local.alb_dns
    zone_id                = local.alb_zone_id
    evaluate_target_health = true
  }
}

# -----------------------------------------------------------------------------
# DNS Record - kutoot.com (apex) -> ALB (optional)
# -----------------------------------------------------------------------------

resource "aws_route53_record" "apex" {
  count   = local.zone_id != "" && var.create_apex_record ? 1 : 0
  zone_id = local.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = local.alb_dns
    zone_id                = local.alb_zone_id
    evaluate_target_health = true
  }
}
