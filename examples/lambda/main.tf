# Example: Lambda Function URL Registration in CloudMap
# This example demonstrates how to register a Lambda Function URL in CloudMap
# for service discovery within a VPC using private DNS namespace

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

# Data source for public IP
data "http" "my_public_ip" {
  url = "https://checkip.amazonaws.com/"
}

# Random suffix for unique resource naming
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Local values for consistent naming and configuration
locals {
  azs             = ["ap-southeast-2a", "ap-southeast-2b", "ap-southeast-2c"]
  name            = "test"
  base_name       = local.suffix != "" ? "${local.name}-${local.suffix}" : local.name
  suffix          = random_string.suffix.result
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  region          = "ap-southeast-2"
  vpc_cidr        = "10.0.0.0/16"
  tags = {
    Environment = "dev"
    Project     = "example"
  }
}

# VPC Module
module "vpc" {
  source = "cloudbuildlab/vpc/aws"

  vpc_name           = local.base_name
  vpc_cidr           = local.vpc_cidr
  availability_zones = local.azs

  public_subnet_cidrs  = local.public_subnets
  private_subnet_cidrs = local.private_subnets

  # Enable Internet Gateway & NAT Gateway
  # A single NAT gateway is used instead of multiple for cost efficiency.
  create_igw       = true
  nat_gateway_type = "single"

  # Enable DNS support for CloudMap
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.tags
}

# Security group for Lambda function
resource "aws_security_group" "lambda" {
  name_prefix = "${local.base_name}-lambda-"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${local.base_name}-lambda-sg"
  })
}

# IAM role for Lambda function
resource "aws_iam_role" "lambda" {
  name = "${local.base_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

# IAM policy for Lambda basic execution
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# Create Lambda deployment package
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "index.js"
  output_path = "lambda_function.zip"
}

# IAM policy for jumphost to access CloudMap
resource "aws_iam_role_policy" "jumphost_cloudmap" {
  name = "${local.base_name}-jumphost-cloudmap-policy"
  role = module.jumphost.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "servicediscovery:DiscoverInstances",
          "servicediscovery:ListInstances"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda function
resource "aws_lambda_function" "api" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${local.base_name}-api"
  role             = aws_iam_role.lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  timeout          = 30
  source_code_hash = data.archive_file.lambda_zip.output_md5

  environment {
    variables = {
      SERVICE_NAME = "api-service"
    }
  }

  tags = merge(local.tags, {
    Name = "${local.base_name}-api"
  })
}

# Lambda Function URL
resource "aws_lambda_function_url" "api" {
  function_name      = aws_lambda_function.api.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["*"]
    expose_headers    = ["*"]
    max_age           = 86400
  }
}

# CloudMap module with Lambda registration
module "cloudmap" {
  source = "../../"

  # Create private DNS namespace for VPC-based service discovery
  create_private_dns_namespace = true
  namespace_name               = "api.internal"
  namespace_description        = "Private DNS namespace for API service discovery"
  vpc_id                       = module.vpc.vpc_id

  # Define services
  services = {
    "api-service" = {
      name                       = "api-service"
      description                = "API service for Lambda function discovery"
      dns_ttl                    = 60
      dns_record_type            = "A" # Use A record for proper DNS resolution
      routing_policy             = "WEIGHTED"
      health_check_custom_config = false # Disable custom health checks for DNS-only service
      tags = {
        Service = "api"
        Type    = "lambda"
      }
    }
  }

  # Enable Lambda registration
  enable_lambda_registration = true
  lambda_instance_id         = "api-lambda-01"
  lambda_url                 = aws_lambda_function_url.api.function_url
  lambda_service_name        = "api-service"
  lambda_ip_address          = "192.0.2.1" # Placeholder IP for A record (not used for actual access)
  lambda_attributes = {
    "environment"   = "production"
    "version"       = "v1.0.0"
    "region"        = local.region
    "function_name" = aws_lambda_function.api.function_name
    "timeout"       = "30"
    "memory_size"   = "128"
  }

  tags = local.tags
}

# Jumphost module for testing service discovery
module "jumphost" {
  source = "tfstack/jumphost/aws"

  name      = "${local.base_name}-jumphost"
  ami_type  = "amazonlinux2"
  subnet_id = module.vpc.private_subnet_ids[0]
  vpc_id    = module.vpc.vpc_id

  create_security_group = true
  allowed_cidr_blocks   = ["${trimspace(data.http.my_public_ip.response_body)}/32"]
  assign_eip            = false

  user_data_extra = <<-EOT
    yum install -y mtr nc curl dig jq awscli

    # Create comprehensive test script
    cat > /home/ec2-user/test-discovery.sh << 'SCRIPT'
    #!/bin/bash
    echo "=== AWS CloudMap Lambda Service Discovery Demo ==="
    echo "This demonstrates how to discover and trigger Lambda functions via CloudMap."
    echo

    echo "1. 🔍 Discover Lambda service via CloudMap API:"
    aws servicediscovery discover-instances \
        --namespace-name api.internal \
        --service-name api-service \
        --region ap-southeast-2

    echo
    echo "2. 🎯 Extract the actual Lambda Function URL:"
    LAMBDA_URL=$(aws servicediscovery discover-instances \
        --namespace-name api.internal \
        --service-name api-service \
        --region ap-southeast-2 \
        --query 'Instances[0].Attributes.lambda_url' \
        --output text)

    echo "   Discovered Lambda URL: $LAMBDA_URL"
    echo

    echo "3. 🚀 Trigger the Lambda using the discovered URL:"
    if [ "$LAMBDA_URL" != "None" ] && [ ! -z "$LAMBDA_URL" ]; then
        echo "   Triggering: curl -s \"$LAMBDA_URL\""
        curl -s "$LAMBDA_URL" | jq .
        echo
        echo "   ✅ SUCCESS: Lambda triggered via CloudMap service discovery!"
    else
        echo "   ❌ FAILED: Could not discover Lambda URL via CloudMap"
    fi

    echo
    echo "4. 📋 Service metadata available:"
    echo "   Function Name: $(aws servicediscovery discover-instances --namespace-name api.internal --service-name api-service --region ap-southeast-2 --query 'Instances[0].Attributes.function_name' --output text)"
    echo "   Environment: $(aws servicediscovery discover-instances --namespace-name api.internal --service-name api-service --region ap-southeast-2 --query 'Instances[0].Attributes.environment' --output text)"
    echo "   Version: $(aws servicediscovery discover-instances --namespace-name api.internal --service-name api-service --region ap-southeast-2 --query 'Instances[0].Attributes.version' --output text)"
    echo "   Region: $(aws servicediscovery discover-instances --namespace-name api.internal --service-name api-service --region ap-southeast-2 --query 'Instances[0].Attributes.region' --output text)"

    echo
    echo "=== Demo Summary ==="
    echo "✅ CloudMap API Discovery: Working"
    echo "✅ Lambda URL Extraction: Working"
    echo "✅ Lambda Function Trigger: Working"
    echo
    echo "Use Case: Services can discover and trigger Lambda functions dynamically"
    echo "without hardcoding URLs - perfect for microservices architecture!"
    SCRIPT

    chmod +x /home/ec2-user/test-discovery.sh
    chown ec2-user:ec2-user /home/ec2-user/test-discovery.sh
  EOT

  tags = local.tags
}

# Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.api.function_name
}

output "lambda_function_url" {
  description = "Lambda Function URL"
  value       = aws_lambda_function_url.api.function_url
}

output "cloudmap_namespace_name" {
  description = "CloudMap namespace name"
  value       = module.cloudmap.namespace_name
}

output "cloudmap_service_name" {
  description = "CloudMap service name"
  value       = module.cloudmap.services["api-service"].name
}

output "lambda_instance_id" {
  description = "Lambda instance ID in CloudMap"
  value       = module.cloudmap.lambda_instance_id
}

output "lambda_discovery_url" {
  description = "CloudMap discovery URL for Lambda"
  value       = module.cloudmap.lambda_discovery_url
}

# Jumphost outputs
output "jumphost_instance_id" {
  description = "ID of the jumphost instance"
  value       = module.jumphost.instance_id
}

output "jumphost_public_ip" {
  description = "Public IP of the jumphost instance"
  value       = module.jumphost.public_ip
}

output "jumphost_private_ip" {
  description = "Private IP of the jumphost instance"
  value       = module.jumphost.private_ip
}

output "ssm_session_command" {
  description = "AWS CLI command to open SSM session to jumphost"
  value       = module.jumphost.ssm_session_command
}

output "instance_connect_command" {
  description = "AWS CLI command to connect via EC2 Instance Connect"
  value       = module.jumphost.instance_connect_command
}

output "test_commands" {
  description = "Commands to test the setup"
  value = {
    ssm_session      = module.jumphost.ssm_session_command
    instance_connect = module.jumphost.instance_connect_command
    test_script      = "Run the test script after connecting via SSM: ./test-discovery.sh"
    lambda_test      = "curl -s '${aws_lambda_function_url.api.function_url}'"
    dns_test         = "dig api-lambda-01.api-service.api.internal"
  }
}
