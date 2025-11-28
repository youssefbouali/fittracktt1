##################################################
# Security Group for Elastic Beanstalk
##################################################
resource "aws_security_group" "elastic_beanstalk" {
  name        = "${var.app_name}-${var.environment}-eb-sg"
  description = "Security group for Elastic Beanstalk"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

##################################################
# IAM Role & Instance Profile for EC2
##################################################
resource "aws_iam_role" "elastic_beanstalk_ec2" {
  name = "${var.app_name}-${var.environment}-eb-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "eb_web_tier" {
  role       = aws_iam_role.elastic_beanstalk_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws_iam_role_policy_attachment" "eb_worker_tier" {
  role       = aws_iam_role.elastic_beanstalk_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWorkerTier"
}

resource "aws_iam_role_policy_attachment" "eb_ssm" {
  role       = aws_iam_role.elastic_beanstalk_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "elastic_beanstalk_ec2" {
  name = "${var.app_name}-${var.environment}-eb-ec2-profile"
  role = aws_iam_role.elastic_beanstalk_ec2.name
}

##################################################
# Elastic Beanstalk Application
##################################################
resource "aws_elastic_beanstalk_application" "fittrack" {
  name        = "${var.app_name}-${var.environment}"
  description = "FitTrack application"
  tags        = var.tags
}

##################################################
# Elastic Beanstalk Environment
##################################################
resource "aws_elastic_beanstalk_environment" "fittrack" {
  name                = "${var.app_name}-${var.environment}-env"
  application         = aws_elastic_beanstalk_application.fittrack.name
  solution_stack_name = "64bit Amazon Linux 2023 v6.6.7 running Node.js 20"

  # Instance profile & Security Group (Launch Configuration)
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.elastic_beanstalk_ec2.name
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SecurityGroups"
    value     = aws_security_group.elastic_beanstalk.id
  }

  # Environment type
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "LoadBalanced"
  }

  # Instance type
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "t3.micro"
  }

  # Min/Max instances
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = "1"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = "3"
  }

  # VPC Subnets for Load Balancer (Security Group فقط في Launch Config)
  setting {
    namespace = "aws:elbv2:loadbalancer"
    name      = "Subnets"
    value     = join(",", aws_subnet.public[*].id)
  }

  # Environment variables
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "NODE_ENV"
    value     = var.environment
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "PORT"
    value     = "5000"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "AWS_REGION"
    value     = var.aws_region
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "COGNITO_USER_POOL_ID"
    value     = aws_cognito_user_pool.fittrack.id
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "COGNITO_CLIENT_ID"
    value     = aws_cognito_user_pool_client.fittrack_web.id
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DATABASE_URL"
    value     = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.fittrack.endpoint}/${aws_db_instance.fittrack.db_name}"
  }

  tags = var.tags

  
  depends_on = [
    aws_elastic_beanstalk_application.fittrack,
    aws_db_instance.fittrack,
    aws_security_group.elastic_beanstalk,  # Ensure this is included
    aws_iam_instance_profile.elastic_beanstalk_ec2,
    aws_db_subnet_group.fittrack
  ]
}
