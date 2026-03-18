==========================================
  KUTOOT AWS BACKEND - COMPLETE INVENTORY
  Region: ap-south-1
  Generated: 2026-03-18 12:26:59
==========================================

AWS Account: 408110214942

--- EC2 INSTANCES ---
  InstanceId: i-0ed31768c418663cb
  Name: kutoot-mysql
  State: running
  Type: t3.medium
  Private IP: 172.31.45.181
  Public IP: 13.235.24.13
  KeyName: kutoot-sql
  LaunchTime: 2026-03-04T11:40:28+00:00
  SecurityGroups: sg-0359e25605495361d

  InstanceId: i-03eb6851a0511b11a
  Name: kutoot-prod-laravel
  State: running
  Type: t3.medium
  Private IP: 172.31.9.158
  Public IP: 3.111.42.47
  KeyName: kutoot-sql
  LaunchTime: 2026-03-04T14:17:53+00:00
  SecurityGroups: sg-087b8d8e894225f6a

--- APPLICATION LOAD BALANCERS ---
  Name: kutoot-prod-alb
  DNSName: kutoot-prod-alb-614260800.ap-south-1.elb.amazonaws.com
  ARN: arn:aws:elasticloadbalancing:ap-south-1:408110214942:loadbalancer/app/kutoot-prod-alb/bb21fcdb485d6881
  Scheme: internet-facing
  State: active

--- TARGET GROUPS ---
  Name: kutoot-prod-tg
  ARN: arn:aws:elasticloadbalancing:ap-south-1:408110214942:targetgroup/kutoot-prod-tg/c1701cd2c50d9d32
  Port: 80
  HealthCheck: / (interval 30s)

--- ALB LISTENERS ---
  Port: 443 Protocol: HTTPS

  Port: 80 Protocol: HTTP

--- AUTO SCALING GROUPS ---
  Name: kutoot-prod-asg
  Min: 1 Max: 8 Desired: 1
  HealthCheckType: ELB
  HealthCheckGracePeriod: 1400000 seconds
  LaunchTemplate: 
  TargetGroups: arn:aws:elasticloadbalancing:ap-south-1:408110214942:targetgroup/kutoot-prod-tg/c1701cd2c50d9d32

--- SECURITY GROUPS (kutoot) ---
  sg-09644e966c3124ebd - kutoot-prod-alb-sg
  Description: Security group for Kutoot ALB
    Inbound: 80-80 tcp
    Inbound: 22-22 tcp
    Inbound: 443-443 tcp

  sg-087b8d8e894225f6a - kutoot-prod-laravel-sg
  Description: Security group for Kutoot Laravel EC2
    Inbound: 80-80 tcp
    Inbound: 22-22 tcp

--- ROUTE 53 (kutoot.com) ---
  Zone: kutoot.com. ID: /hostedzone/Z06053352W6STXYLEDP34
    kutoot.com. A -> d3g5p335unmlk2.cloudfront.net.
    kutoot.com. SOA -> ns-632.awsdns-15.net. awsdns-hostmaster.amazon.com. 1 7200 900 1209600 86400
    _11e34fedfd8f56d2c12313a86b798ff4.kutoot.com. CNAME -> _b9b660613e174184e32af31aabf31221.jkddzztszm.acm-validations.aws.
    frontend.kutoot.com. CNAME -> d3g5p335unmlk2.cloudfront.net

--- VPC ---
  vpc-0cb90a16f1d9f2033 172.31.0.0/16 Default: True

--- QUICK REFERENCE ---
  Laravel path: /var/www/kutoot
  MySQL host: 172.31.45.181
  DB name: kutoot_backend
  ALB URL: kutoot-prod-alb-614260800.ap-south-1.elb.amazonaws.com
  dev.kutoot.com: Cloudflare (not Route 53)

--- FIX IN MINUTES (if something breaks) ---
  1. Run: .\scripts\quick-recreate.ps1 (recreates ALB + ASG)
  2. Restore terraform.tfvars from backups/config-* if needed
  3. MySQL down? Restore from backup-mysql.sh backup
  4. Laravel instance down? ASG auto-launches new one (with User Data if terraform applied)
  5. SSH: ssh -i kutoot-sql.pem ubuntu@<PublicIP>
  6. See docs/QUICK-RECREATE.md for full runbook

==========================================
