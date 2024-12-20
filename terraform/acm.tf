
# resource "aws_acm_certificate" "alb_cert" {
#   domain_name       = var.domain_name
#   validation_method = "DNS"

#   tags = {
#     Name = "${var.project_name}-alb-cert"
#   }
# }

# # DNS Validation Records
# resource "aws_route53_record" "alb_cert_validation" {
#   for_each = {
#     for dvo in aws_acm_certificate.alb_cert.domain_validation_options : dvo.domain_name => {
#       name   = dvo.resource_record_name
#       type   = dvo.resource_record_type
#       record = dvo.resource_record_value
#     }
#   }

#   zone_id = data.aws_route53_zone.main.zone_id
#   name    = each.value.name
#   type    = each.value.type
#   records = [each.value.record]
#   ttl     = 60
# }

# # Wait for Certificate Validation
# resource "aws_acm_certificate_validation" "alb_cert_validation" {
#   certificate_arn         = aws_acm_certificate.alb_cert.arn
#   validation_record_fqdns = [for record in aws_route53_record.alb_cert_validation : record.fqdn]
# }

# # Update ALB Listener for HTTPS
# resource "aws_lb_listener" "flask_listener_https" {
#   load_balancer_arn = aws_lb.flask_alb.arn
#   port              = "443"
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-2016-08"
#   certificate_arn   = aws_acm_certificate_validation.alb_cert_validation.certificate_arn

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.flask_tg.arn
#   }
# }

# # Update Security Group for ALB to Allow HTTPS
# resource "aws_security_group_rule" "allow_https" {
#   type              = "ingress"
#   from_port         = 443
#   to_port           = 443
#   protocol          = "tcp"
#   security_group_id = aws_security_group.alb_sg.id
#   cidr_blocks       = ["0.0.0.0/0"]
# }