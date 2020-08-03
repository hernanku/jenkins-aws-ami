# Remote state
terraform {
  backend "s3" {
    bucket = "jenkins-terraform-aws-44rf5"
    key    = "terraform-backend/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region     = var.aws_region
  # access_key = var.aws_access_key
  # secret_key = var.aws_secret_key
}


#------------IAM--------------- 
#S3_access
resource "aws_iam_instance_profile" "jenkinscc_s3_access_profile" {
  name = "s3_access_profile"
  role = aws_iam_role.jenkinscc_s3_access_role.name
}

resource "aws_iam_role_policy" "jenkinscc_s3_access_policy" {
  name = "s3_access_policy"
  role = aws_iam_role.jenkinscc_s3_access_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::jenkins-terraform-aws-44rf5"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": "arn:aws:s3:::jenkins-terraform-aws-44rf5/terraform-backend/terraform.tfstate"
    }
  ]
}
EOF
}

resource "aws_iam_role" "jenkinscc_s3_access_role" {
  name = "jenkinscc_s3_access_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
  {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
  },
      "Effect": "Allow",
      "Sid": ""
      }
    ]
}
EOF
}


# ssm access
resource "aws_iam_role" "jenkinscc_ssm_access_role" {
  name               = "Ec2RoleForSSM"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": ["ec2.amazonaws.com"]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

resource "aws_iam_instance_profile" "jenkinscc_ssm_access_profile" {
  role = aws_iam_role.jenkinscc_ssm_access_role.name
  name = "Ec2RoleForSSM"
}
resource "aws_iam_role_policy_attachment" "IamRoleManagedPolicyRoleAttachment0" {
  role       = aws_iam_role.jenkinscc_ssm_access_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "IamRoleManagedPolicyRoleAttachment1" {
  role       = aws_iam_role.jenkinscc_ssm_access_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMDirectoryServiceAccess"
}

resource "aws_iam_role_policy_attachment" "IamRoleManagedPolicyRoleAttachment2" {
  role       = aws_iam_role.jenkinscc_ssm_access_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "IamRoleInlinePolicyRoleAttachment0" {
  name   = "AllowAccessToS3"
  role   = aws_iam_role.jenkinscc_ssm_access_role.id
  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:PutObjectAcl"
            ],
            "Resource": "arn:aws:s3:::*jenkinscc_ssm_s3/*"
        }
    ]
}
POLICY
}

resource "aws_iam_role_policy" "IamRoleInlinePolicyRoleAttachment1" {
  name   = "AllowAccessToVpcEndpoints"
  role   = aws_iam_role.jenkinscc_ssm_access_role.id
  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject"
            ],
            "Resource": [
                "arn:aws:s3:::aws-ssm-us-east-1/*",
                "arn:aws:s3:::aws-windows-downloads-us-east-1/*",
                "arn:aws:s3:::amazon-ssm-us-east-1/*",
                "arn:aws:s3:::amazon-ssm-packages-us-east-1/*",
                "arn:aws:s3:::us-east-1-birdwatcher-prod/*",
                "arn:aws:s3:::patch-baseline-snapshot-us-east-1/*"
            ]
        }
    ]
}
POLICY
}

#-------------VPC-----------

resource "aws_vpc" "jenkinscc_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "jenkinscc_vpc"
  }
}

#internet gateway
resource "aws_internet_gateway" "jenkinscc_IGW" {
  vpc_id = aws_vpc.jenkinscc_vpc.id

  tags = {
    Name = "jenkinscc_IGW"
  }
}

# Route tables
resource "aws_route_table" "jenkinscc_RT_Public" {
  vpc_id = aws_vpc.jenkinscc_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.jenkinscc_IGW.id
  }

  tags = {
    Name = "jenkinscc_RT_Public"
  }
}

# Subnets
resource "aws_subnet" "jenkinscc_subnet_public01" {
  vpc_id                  = aws_vpc.jenkinscc_vpc.id
  cidr_block              = var.cidrs["public1"]
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "jenkinscc_subnet_public01"
  }
}

resource "aws_subnet" "jenkinscc_subnet_public02" {
  vpc_id                  = aws_vpc.jenkinscc_vpc.id
  cidr_block              = var.cidrs["public2"]
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "jenkinscc_subnet_public02"
  }
}

#create VPC endpoints
resource "aws_vpc_endpoint" "careCentrix-vpc-endpoint-priv-ssm" {
  vpc_id            = aws_vpc.jenkinscc_vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type = "Interface"
  subnet_ids        = ["${aws_subnet.jenkinscc_subnet_public01.id}", "${aws_subnet.jenkinscc_subnet_public02.id}"]

  security_group_ids = [
    aws_security_group.jenkinscc_public_sg.id,
    aws_security_group.jenkinscc_vpc_endpoint_sg.id,
  ]

  private_dns_enabled = true

  policy = <<POLICY
{
    "Statement": [
        {
            "Action": "*",
            "Effect": "Allow",
            "Resource": "*",
            "Principal": "*"
        }
    ]
}
POLICY
}

resource "aws_vpc_endpoint" "careCentrix-vpc-endpoint-priv-ssmmsg" {
  vpc_id            = aws_vpc.jenkinscc_vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type = "Interface"
  subnet_ids        = ["${aws_subnet.jenkinscc_subnet_public01.id}", "${aws_subnet.jenkinscc_subnet_public02.id}"]
  security_group_ids = [
    aws_security_group.jenkinscc_public_sg.id,
    aws_security_group.jenkinscc_vpc_endpoint_sg.id,
  ]

  private_dns_enabled = true

  policy = <<POLICY
{
    "Statement": [
        {
            "Action": "*",
            "Effect": "Allow",
            "Resource": "*",
            "Principal": "*"
        }
    ]
}
POLICY
}

resource "aws_vpc_endpoint" "careCentrix-vpc-endpoint-priv-ec2msg" {
  vpc_id            = aws_vpc.jenkinscc_vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type = "Interface"
  subnet_ids        = ["${aws_subnet.jenkinscc_subnet_public01.id}", "${aws_subnet.jenkinscc_subnet_public02.id}"]
  security_group_ids = [
    aws_security_group.jenkinscc_public_sg.id,
    aws_security_group.jenkinscc_vpc_endpoint_sg.id,
  ]

  private_dns_enabled = true

  policy = <<POLICY
{
    "Statement": [
        {
            "Action": "*",
            "Effect": "Allow",
            "Resource": "*",
            "Principal": "*"
        }
    ]
}
POLICY
}


resource "aws_vpc_endpoint" "careCentrix-vpc-endpoint-priv-ec2" {
  vpc_id            = aws_vpc.jenkinscc_vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.ec2"
  vpc_endpoint_type = "Interface"
  subnet_ids        = ["${aws_subnet.jenkinscc_subnet_public01.id}", "${aws_subnet.jenkinscc_subnet_public02.id}"]
  security_group_ids = [
    aws_security_group.jenkinscc_public_sg.id,
    aws_security_group.jenkinscc_vpc_endpoint_sg.id,
  ]

  private_dns_enabled = true

  policy = <<POLICY
{
    "Statement": [
        {
            "Action": "*",
            "Effect": "Allow",
            "Resource": "*",
            "Principal": "*"
        }
    ]
}
POLICY
}


resource "aws_vpc_endpoint" "careCentrix-vpc-endpoint-priv-s3-gateway" {
  vpc_id       = aws_vpc.jenkinscc_vpc.id
  service_name = "com.amazonaws.${var.aws_region}.s3"

  route_table_ids = [aws_route_table.jenkinscc_RT_Public.id,
  ]

  policy = <<POLICY
{
    "Statement": [
        {
            "Action": "*",
            "Effect": "Allow",
            "Resource": "*",
            "Principal": "*"
        }
    ]
}
POLICY
}

# Subnet Associations
resource "aws_route_table_association" "jenkinscc_public01_assoc" {
  subnet_id      = aws_subnet.jenkinscc_subnet_public01.id
  route_table_id = aws_route_table.jenkinscc_RT_Public.id
}

resource "aws_route_table_association" "jenkinscc_public02_assoc" {
  subnet_id      = aws_subnet.jenkinscc_subnet_public02.id
  route_table_id = aws_route_table.jenkinscc_RT_Public.id
}


# #Security groups
# Public Security Group
resource "aws_security_group" "jenkinscc_public_sg" {
  name        = "jenkinscc_private_sg"
  description = "Used for private instances"
  vpc_id      = aws_vpc.jenkinscc_vpc.id

  # Access from other security groups
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr, "0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_security_group" "jenkinscc_vpc_endpoint_sg" {
  name        = "jenkinscc_vpc_endpoint_sg"
  description = "Allow VPC traffic to communicate with AWS Services"
  vpc_id      = aws_vpc.jenkinscc_vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
}

#---------compute-----------
#dev server
resource "aws_instance" "jenkinscc_dev" {
  instance_type          = var.dev_instance_type
  ami                    = var.dev_ami
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.jenkinscc_public_sg.id, ]
  iam_instance_profile   = aws_iam_instance_profile.jenkinscc_ssm_access_profile.id
  subnet_id              = aws_subnet.jenkinscc_subnet_public01.id

  tags = {
    Name = "jenkinscc_dev"
  }

  provisioner "local-exec" {
    command = <<EOD
cat <<EOF > hosts 
[aws-docker-vms]
${aws_instance.jenkinscc_dev.public_ip}
EOF
EOD
  }

  provisioner "local-exec" {
    command = "/usr/local/bin/aws ec2 wait instance-status-ok --instance-ids ${aws_instance.jenkinscc_dev.id} && ansible-playbook -i hosts docker-setup.yml --extra-vars \"ansible_ssh_private_key_file='${var.ansible_key_file_path}'\""
  }
}

#load balancer
resource "aws_elb" "jenkinscc_elb" {
  name = "${var.domain_name}-elb"

  subnets = [aws_subnet.jenkinscc_subnet_public01.id,
    aws_subnet.jenkinscc_subnet_public02.id,
  ]

  security_groups = [aws_security_group.jenkinscc_public_sg.id]

  listener {
    instance_port     = 22
    instance_protocol = "tcp"
    lb_port           = 22
    lb_protocol       = "tcp"
  }

  health_check {
    healthy_threshold   = var.elb_healthy_threshold
    unhealthy_threshold = var.elb_unhealthy_threshold
    timeout             = var.elb_timeout
    target              = "TCP:22"
    interval            = var.elb_interval
  }

  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "jenkinscc_${var.domain_name}-elb"
  }
}

#AMI 
resource "random_id" "golden_ami" {
  byte_length = 8
}

resource "aws_ami_from_instance" "jenkinscc_golden" {
  name               = "jenkinscc_ami-${random_id.golden_ami.b64}"
  source_instance_id = aws_instance.jenkinscc_dev.id
}

#launch configuration

resource "aws_launch_configuration" "jenkinscc_lc" {
  name_prefix          = "jenkinscc_lc-"
  image_id             = aws_ami_from_instance.jenkinscc_golden.id
  instance_type        = var.lc_instance_type
  security_groups      = [aws_security_group.jenkinscc_public_sg.id]
  iam_instance_profile = aws_iam_instance_profile.jenkinscc_ssm_access_profile.id
  key_name             = var.key_name
  user_data            = file("userdata")

  lifecycle {
    create_before_destroy = true
  }
}

#ASG 
resource "aws_autoscaling_group" "jenkinscc_asg" {
  name                      = "asg-${aws_launch_configuration.jenkinscc_lc.id}"
  max_size                  = var.asg_max
  min_size                  = var.asg_min
  health_check_grace_period = var.asg_grace
  health_check_type         = var.asg_hct
  desired_capacity          = var.asg_cap
  force_delete              = true
  load_balancers            = [aws_elb.jenkinscc_elb.id]

  vpc_zone_identifier = [aws_subnet.jenkinscc_subnet_public01.id,
    aws_subnet.jenkinscc_subnet_public02.id,
  ]

  launch_configuration = aws_launch_configuration.jenkinscc_lc.name

  tag {
    key                 = "Name"
    value               = "jenkinscc_asg-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

#---------Route53-------------
data "aws_route53_zone" "main" {
  name         = "sillycloudz.com."
  private_zone = false
}

#www 
resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "www.${data.aws_route53_zone.main.name}"
  type    = "A"

  alias {
    name                   = aws_elb.jenkinscc_elb.dns_name
    zone_id                = aws_elb.jenkinscc_elb.zone_id
    evaluate_target_health = false
  }
}

#dev 
resource "aws_route53_record" "dev" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "dev.${data.aws_route53_zone.main.name}"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.jenkinscc_dev.private_ip]
}




