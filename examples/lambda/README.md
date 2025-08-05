# AWS CloudMap Lambda Service Discovery

This example demonstrates **AWS CloudMap service discovery with Lambda functions** - showing how to discover and trigger Lambda functions dynamically without hardcoding URLs.

## 🎯 **Use Case**

**Dynamic Lambda Function Discovery** - Enable microservices to discover and trigger Lambda functions programmatically:

- ✅ **Service Discovery API**: Discover Lambda functions via CloudMap API
- ✅ **Dynamic URL Resolution**: Extract Lambda Function URLs from CloudMap attributes
- ✅ **Direct Lambda Triggering**: Call Lambda functions using discovered URLs
- ✅ **Service Metadata**: Access rich attributes (version, environment, function name, etc.)
- ✅ **Microservices Pattern**: Perfect for service mesh architectures

## 🏗️ **Architecture**

```plaintext
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Microservice  │    │   CloudMap       │    │   Lambda        │
│   (EC2/ECS/etc) │    │   Service        │    │   Function URL  │
│                 │    │   Discovery      │    │                 │
│  🔍 API calls   │◄──►│   Registry       │◄──►│  📋 Registered  │
│                 │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘

Flow:
1. Lambda Function URL → Registered in CloudMap with metadata
2. Microservice → Calls CloudMap API to discover Lambda services
3. Microservice → Extracts Lambda URL and triggers function directly
```

## 📋 **Prerequisites**

- AWS CLI configured
- Terraform >= 1.0
- **No SSH keys required** - Uses SSM Session Manager for secure access

## 🚀 **Quick Start**

### 1. **Deploy Infrastructure**

```bash
# Navigate to the example directory
cd examples/lambda

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the configuration
terraform apply
```

**Note**: The Lambda function package is automatically created by Terraform using the `archive_file` data source - no manual zipping required!

### 2. **Test Service Discovery**

```bash
# Connect via SSM Session (recommended - no SSH keys needed)
$(terraform output -raw ssm_session_command)

# Or connect via EC2 Instance Connect
$(terraform output -raw instance_connect_command)

# Run the test script
./test-discovery.sh
```

## 🔧 **Configuration**

### **Infrastructure Components**

This example creates:

- **VPC with Public/Private Subnets**: Using the `cloudbuildlab/vpc/aws` module
- **Lambda Function with Function URL**: Serverless API endpoint (automatically packaged using `archive_file`)
- **CloudMap Private DNS Namespace**: For service discovery within VPC
- **Jumphost Instance**: Using `tfstack/jumphost/aws` module with SSM enabled
- **Security Groups**: For Lambda and jumphost instance

### **Lambda Function Packaging**

The Lambda function is automatically packaged using Terraform's `archive_file` data source:

```hcl
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "index.js"
  output_path = "lambda_function.zip"
}
```

This eliminates the need for manual zipping and ensures consistent deployments.

**Note**: The generated `lambda_function.zip` file is automatically ignored by `.gitignore` to keep the repository clean.

### **Jumphost Features**

The jumphost module provides:

- **SSM Integration**: Secure access via AWS Systems Manager (no SSH keys required)
- **EC2 Instance Connect**: Alternative SSH access method
- **CloudWatch Agent**: System monitoring and logging
- **Automatic Security**: Configurable security groups with dynamic IP allowlisting
- **Multi-OS Support**: Amazon Linux 2, Ubuntu, RHEL
- **IAM Integration**: Automatic SSM permissions

### **Lambda Registration Variables**

| Variable | Description | Default |
|----------|-------------|---------|
| `enable_lambda_registration` | Enable Lambda registration in CloudMap | `false` |
| `lambda_instance_id` | Unique identifier for Lambda instance | `"lambda-function"` |
| `lambda_url` | Lambda Function URL to register | `null` |
| `lambda_service_name` | CloudMap service name for Lambda | First service in `services` |
| `lambda_attributes` | Additional attributes for Lambda instance | `{}` |

### **Example Configuration**

```hcl
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
  name            = "lambda-cloudmap"
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
module "aws_vpc" {
  source = "cloudbuildlab/vpc/aws"

  vpc_name           = local.base_name
  vpc_cidr           = local.vpc_cidr
  availability_zones = local.azs

  public_subnet_cidrs  = local.public_subnets
  private_subnet_cidrs = local.private_subnets

  create_igw       = true
  nat_gateway_type = "single"
}

# Jumphost Module (Amazon Linux 2)
module "jumphost-ssm-amazonlinux2" {
  source = "tfstack/jumphost/aws"

  name      = "${local.base_name}-ssm-amazonlinux2"
  ami_type  = "amazonlinux2"
  subnet_id = module.aws_vpc.private_subnet_ids[0]
  vpc_id    = module.aws_vpc.vpc_id

  create_security_group = true
  allowed_cidr_blocks   = ["${data.http.my_public_ip.response_body}/32"]
  assign_eip            = false

  user_data_extra = <<-EOT
    yum install -y mtr nc curl dig jq awscli

    # Create test script
    cat > /home/ec2-user/test-discovery.sh << 'SCRIPT'
    #!/bin/bash
    echo "Testing CloudMap service discovery..."

    # Test DNS resolution
    echo "=== DNS Resolution Test ==="
    dig A api-lambda-01.api-service.api.internal

    # Test Lambda function call via CloudMap attributes
    echo "=== Lambda Function Test ==="
    LAMBDA_URL=$(aws servicediscovery discover-instances \
        --namespace-name api.internal \
        --service-name api-service \
        --region ap-southeast-2 \
        --query 'Instances[0].Attributes.lambda_url' \
        --output text)

    if [ "$LAMBDA_URL" != "None" ] && [ ! -z "$LAMBDA_URL" ]; then
      echo "Retrieved Lambda URL from CloudMap: $LAMBDA_URL"
      curl -s "$LAMBDA_URL" | jq .
    else
      echo "Failed to retrieve Lambda URL from CloudMap"
    fi

    # Test service discovery via AWS CLI
    echo "=== AWS CloudMap Discovery Test ==="
    aws servicediscovery discover-instances \
      --namespace-name api.internal \
      --service-name api-service \
      --region ap-southeast-2
    SCRIPT

    chmod +x /home/ec2-user/test-discovery.sh
    chown ec2-user:ec2-user /home/ec2-user/test-discovery.sh
  EOT
}

# CloudMap Module
module "cloudmap" {
  source = "../../"

  # Create private DNS namespace
  create_private_dns_namespace = true
  namespace_name               = "api.internal"
  vpc_id                      = module.aws_vpc.vpc_id

  # Define service with CNAME record type
  services = {
    "api-service" = {
      name        = "api-service"
      dns_record_type = "CNAME"  # Required for Lambda Function URL
      routing_policy = "WEIGHTED"
      health_check_custom_config = true
    }
  }

  # Enable Lambda registration
  enable_lambda_registration = true
  lambda_instance_id         = "api-lambda-01"
  lambda_url                 = aws_lambda_function_url.api.function_url
  lambda_service_name        = "api-service"
  lambda_attributes = {
    "environment"    = "production"
    "version"        = "v1.0.0"
    "function_name"  = aws_lambda_function.api.function_name
  }
}
```

## 🧪 **Testing**

### **SSM Session Access (Recommended - No SSH Keys Required)**

```bash
# Connect via SSM Session
$(terraform output -raw ssm_session_command)

# Run the test script
./test-discovery.sh
```

### **EC2 Instance Connect Access (Alternative)**

```bash
# Connect via EC2 Instance Connect
$(terraform output -raw instance_connect_command)

# Run the test script
./test-discovery.sh
```

### **CloudMap Lambda Service Discovery Demo**

```bash
# 1. Connect to the EC2 jumphost
aws ssm start-session --target $(terraform output -raw jumphost_instance_id) --region ap-southeast-2

# 2. Run the demo script
./test-discovery.sh
```

### **Manual Testing**

```bash
# 1. Discover Lambda service via CloudMap API
aws servicediscovery discover-instances \
  --namespace-name api.internal \
  --service-name api-service \
  --region ap-southeast-2

# 2. Extract Lambda URL and trigger function
LAMBDA_URL=$(aws servicediscovery discover-instances \
  --namespace-name api.internal \
  --service-name api-service \
  --region ap-southeast-2 \
  --query 'Instances[0].Attributes.lambda_url' \
  --output text)

curl -s "$LAMBDA_URL" | jq .
```

## 🎯 **Demo Output**

The demo shows:

- ✅ **Service Discovery**: CloudMap API returns Lambda instance details
- ✅ **URL Extraction**: Lambda Function URL extracted from attributes
- ✅ **Function Triggering**: Lambda executed using discovered URL
- ✅ **Metadata Access**: Function name, environment, version, region

## 💡 **Use Case**

Perfect for microservices that need to discover and trigger Lambda functions dynamically without hardcoding endpoints.

## 📊 **Key Outputs**

| Output | Description |
|--------|-------------|
| `lambda_function_url` | Direct Lambda Function URL |
| `lambda_discovery_url` | CloudMap service discovery URL |
| `ssm_session_command` | Command to connect to EC2 jumphost |
| `jumphost_instance_id` | EC2 instance ID for testing |
| `cloudmap_namespace_name` | CloudMap namespace name |
| `cloudmap_service_name` | CloudMap service name |

## 🔍 **Service Discovery Benefits**

### **1. Dynamic Service Discovery**

- Discover Lambda functions programmatically via CloudMap API
- No hardcoded URLs or endpoints
- Automatic service registration and deregistration

### **2. Rich Metadata Access**

- Access function metadata (version, environment, region)
- Service health status monitoring
- Instance-specific attributes

### **3. Microservices Architecture**

- Perfect for service mesh patterns
- Enables loose coupling between services
- Supports multiple Lambda instances per service

### **4. Secure Access**

- SSM Session Manager for secure testing
- IAM-based access control
- No SSH keys required
- Audit trail for all connections in CloudTrail
- EC2 Instance Connect as alternative access method
- Dynamic IP allowlisting for enhanced security

## 🛠️ **Advanced Usage**

### **Multiple Lambda Functions**

```hcl
# Register multiple Lambda functions in the same service
module "cloudmap" {
  # ... existing configuration ...

  services = {
    "api-service" = {
      name = "api-service"
      dns_record_type = "CNAME"
    }
  }

  # Register multiple Lambda instances
  enable_lambda_registration = true
  lambda_instance_id         = "api-lambda-01"
  lambda_url                 = aws_lambda_function_url.api1.url

  # Additional Lambda instances can be registered via AWS CLI or SDK
}
```

### **API Gateway Integration**

```hcl
# Use API Gateway URL instead of Lambda Function URL
lambda_url = aws_api_gateway_stage.prod.invoke_url
```

### **Custom Health Checks**

```hcl
# Configure custom health checks for Lambda
lambda_attributes = {
  "health_check_url" = "https://your-lambda-url/health"
  "health_check_interval" = "30"
  "health_check_timeout" = "5"
}
```

### **Jumphost Customization**

```hcl
# Customize jumphost configuration
module "jumphost-ssm-amazonlinux2" {
  source = "tfstack/jumphost/aws"

  name      = "${local.base_name}-ssm-amazonlinux2"
  ami_type  = "amazonlinux2"
  subnet_id = module.aws_vpc.private_subnet_ids[0]
  vpc_id    = module.aws_vpc.vpc_id

  create_security_group = true
  allowed_cidr_blocks   = ["${data.http.my_public_ip.response_body}/32"]
  assign_eip            = false

  # Custom user data
  user_data_extra = <<-EOT
    yum install -y mtr nc my-custom-package
  EOT
}
```

## 🧹 **Cleanup**

```bash
# Destroy the infrastructure
terraform destroy
```

## 📚 **Related Documentation**

- [AWS CloudMap Service Discovery](https://docs.aws.amazon.com/cloud-map/)
- [Lambda Function URLs](https://docs.aws.amazon.com/lambda/latest/dg/urls-configuration.html)
- [Private DNS Namespaces](https://docs.aws.amazon.com/cloud-map/latest/dg/private-dns-namespaces.html)
- [Service Discovery Instance Registration](https://docs.aws.amazon.com/cloud-map/latest/dg/registering-instances.html)
- [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- [EC2 Instance Connect](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-connect.html)

## 🐛 **Troubleshooting**

### **DNS Resolution Issues**

- Ensure VPC DNS resolution is enabled
- Check that the instance is in the correct VPC
- Verify CloudMap namespace is properly configured

### **Lambda Function Issues**

- Check Lambda function permissions
- Verify Function URL is properly configured
- Test Lambda function directly before CloudMap registration

### **Health Check Issues**

- Ensure Lambda function has `/health` endpoint
- Check CloudMap health check configuration
- Verify network connectivity from VPC to Lambda

### **SSM Session Issues**

- Verify IAM permissions for SSM Session Manager
- Check that the instance has internet connectivity
- Ensure SSM Agent is running on the instance

### **Jumphost Access Issues**

- Verify security group allows SSM traffic
- Check that the instance is in a subnet with NAT Gateway or VPC endpoints
- Ensure the instance has the required IAM role for SSM
