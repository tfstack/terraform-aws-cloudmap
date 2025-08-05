# Test HTTP Namespace for ECS Service Discovery
run "http_namespace_ecs_discovery" {
  command = plan

  variables {
    create_namespace      = true
    namespace_name        = "ecs-discovery"
    namespace_description = "HTTP namespace for ECS service discovery"
    services = {
      "backend-service" = {
        name            = "backend-service"
        description     = "Backend service for ECS tasks"
        dns_ttl         = 10
        dns_record_type = "A"
        routing_policy  = "MULTIVALUE"
        tags = {
          Service = "backend"
          Type    = "ecs"
        }
      }
    }
    tags = {
      Environment = "dev"
      Project     = "ecs-discovery"
    }
  }

  assert {
    condition     = var.create_namespace == true
    error_message = "HTTP namespace creation should be enabled"
  }

  assert {
    condition     = var.namespace_name == "ecs-discovery"
    error_message = "Namespace name should be ecs-discovery"
  }

  assert {
    condition     = var.services["backend-service"].name == "backend-service"
    error_message = "Service name should be backend-service"
  }
}

# Test Private DNS Namespace for EKS Service Discovery
run "private_dns_namespace_eks_discovery" {
  command = plan

  variables {
    create_private_dns_namespace = true
    namespace_name               = "eks.internal"
    namespace_description        = "Private DNS namespace for EKS service discovery"
    vpc_id                       = "vpc-12345678"
    services = {
      "api-service" = {
        name                                  = "api-service"
        description                           = "API service for EKS pods"
        dns_ttl                               = 30
        dns_record_type                       = "A"
        routing_policy                        = "MULTIVALUE"
        health_check_custom_config            = true
        custom_health_check_failure_threshold = 1
        tags = {
          Service = "api"
          Type    = "eks"
        }
      }
    }
    enable_health_checks = true
    tags = {
      Environment = "dev"
      Project     = "eks-discovery"
    }
  }

  assert {
    condition     = var.create_private_dns_namespace == true
    error_message = "Private DNS namespace creation should be enabled"
  }

  assert {
    condition     = var.vpc_id == "vpc-12345678"
    error_message = "VPC ID should be vpc-12345678"
  }

  assert {
    condition     = var.services["api-service"].health_check_custom_config == true
    error_message = "Custom health check should be enabled for EKS"
  }
}

# Test Public DNS Namespace for Fargate Service Discovery
run "public_dns_namespace_fargate_discovery" {
  command = plan

  variables {
    create_public_dns_namespace = true
    namespace_name              = "fargate.example.com"
    namespace_description       = "Public DNS namespace for Fargate service discovery"
    services = {
      "web-service" = {
        name            = "web-service"
        description     = "Web service for Fargate tasks"
        dns_ttl         = 60
        dns_record_type = "A"
        routing_policy  = "WEIGHTED"
        health_check_config = {
          resource_path     = "/health"
          type              = "HTTPS"
          failure_threshold = 3
        }
        tags = {
          Service = "web"
          Type    = "fargate"
        }
      }
    }
    enable_health_checks = true
    tags = {
      Environment = "dev"
      Project     = "fargate-discovery"
    }
  }

  assert {
    condition     = var.create_public_dns_namespace == true
    error_message = "Public DNS namespace creation should be enabled"
  }

  assert {
    condition     = var.services["web-service"].health_check_config.type == "HTTPS"
    error_message = "Health check type should be HTTPS for Fargate"
  }

  assert {
    condition     = var.services["web-service"].routing_policy == "WEIGHTED"
    error_message = "Routing policy should be WEIGHTED for Fargate"
  }
}

# Test ECS Service Discovery with IAM Role
run "ecs_service_discovery_with_iam" {
  command = plan

  variables {
    create_namespace                  = true
    namespace_name                    = "ecs-service-discovery"
    namespace_description             = "ECS service discovery with IAM role"
    create_ecs_service_discovery_role = true
    services = {
      "ecs-backend" = {
        name            = "ecs-backend"
        description     = "ECS backend service with IAM role"
        dns_ttl         = 10
        dns_record_type = "A"
        routing_policy  = "MULTIVALUE"
        tags = {
          Service = "backend"
          Type    = "ecs"
        }
      }
    }
    tags = {
      Environment = "dev"
      Project     = "ecs-iam-discovery"
    }
  }

  assert {
    condition     = var.create_ecs_service_discovery_role == true
    error_message = "ECS service discovery role creation should be enabled"
  }

  assert {
    condition     = var.services["ecs-backend"].name == "ecs-backend"
    error_message = "Service name should be ecs-backend"
  }

  assert {
    condition     = var.services["ecs-backend"].dns_ttl == 10
    error_message = "DNS TTL should be 10 for ECS"
  }
}

# Test Multiple Services for Container Orchestration
run "multiple_services_container_orchestration" {
  command = plan

  variables {
    create_namespace      = true
    namespace_name        = "container-orchestration"
    namespace_description = "Multiple services for container orchestration"
    services = {
      "frontend-service" = {
        name            = "frontend-service"
        description     = "Frontend service for containers"
        dns_ttl         = 30
        dns_record_type = "A"
        routing_policy  = "MULTIVALUE"
        tags = {
          Service = "frontend"
          Type    = "container"
        }
      }
      "backend-service" = {
        name            = "backend-service"
        description     = "Backend service for containers"
        dns_ttl         = 60
        dns_record_type = "A"
        routing_policy  = "MULTIVALUE"
        tags = {
          Service = "backend"
          Type    = "container"
        }
      }
      "database-service" = {
        name            = "database-service"
        description     = "Database service for containers"
        dns_ttl         = 120
        dns_record_type = "A"
        routing_policy  = "MULTIVALUE"
        tags = {
          Service = "database"
          Type    = "container"
        }
      }
    }
    tags = {
      Environment = "dev"
      Project     = "container-orchestration"
    }
  }

  assert {
    condition     = length(var.services) == 3
    error_message = "Should have 3 container services defined"
  }

  assert {
    condition     = var.services["frontend-service"].name == "frontend-service"
    error_message = "Frontend service name should be frontend-service"
  }

  assert {
    condition     = var.services["backend-service"].name == "backend-service"
    error_message = "Backend service name should be backend-service"
  }

  assert {
    condition     = var.services["database-service"].name == "database-service"
    error_message = "Database service name should be database-service"
  }
}

# Test Lambda Function URL Registration in CloudMap
run "lambda_function_url_registration" {
  command = plan

  variables {
    create_private_dns_namespace = true
    namespace_name               = "lambda.internal"
    namespace_description        = "Private DNS namespace for Lambda service discovery"
    vpc_id                       = "vpc-12345678"
    services = {
      "api-service" = {
        name                                  = "api-service"
        description                           = "API service for Lambda function discovery"
        dns_ttl                               = 60
        dns_record_type                       = "CNAME" # Required for Lambda Function URL
        routing_policy                        = "WEIGHTED"
        health_check_custom_config            = true
        custom_health_check_failure_threshold = 1
        tags = {
          Service = "api"
          Type    = "lambda"
        }
      }
    }
    enable_health_checks = true

    # Lambda registration configuration
    enable_lambda_registration = true
    lambda_instance_id         = "api-lambda-01"
    lambda_url                 = "https://abc123.lambda-url.ap-southeast-2.on.aws"
    lambda_service_name        = "api-service"
    lambda_attributes = {
      "environment"   = "production"
      "version"       = "v1.0.0"
      "region"        = "ap-southeast-2"
      "function_name" = "cloudmap-api"
      "timeout"       = "30"
      "memory_size"   = "128"
    }

    tags = {
      Environment = "production"
      Project     = "lambda-discovery"
    }
  }

  assert {
    condition     = var.create_private_dns_namespace == true
    error_message = "Private DNS namespace creation should be enabled for Lambda"
  }

  assert {
    condition     = var.services["api-service"].dns_record_type == "CNAME"
    error_message = "DNS record type should be CNAME for Lambda Function URL"
  }

  assert {
    condition     = var.enable_lambda_registration == true
    error_message = "Lambda registration should be enabled"
  }

  assert {
    condition     = var.lambda_instance_id == "api-lambda-01"
    error_message = "Lambda instance ID should be api-lambda-01"
  }

  assert {
    condition     = can(regex("^https://", var.lambda_url))
    error_message = "Lambda URL should be a valid HTTPS URL"
  }

  assert {
    condition     = var.lambda_service_name == "api-service"
    error_message = "Lambda service name should be api-service"
  }

  assert {
    condition     = var.lambda_attributes["environment"] == "production"
    error_message = "Lambda environment should be production"
  }

  assert {
    condition     = var.lambda_attributes["version"] == "v1.0.0"
    error_message = "Lambda version should be v1.0.0"
  }
}

# Test Lambda Registration with Multiple Services
run "lambda_registration_multiple_services" {
  command = plan

  variables {
    create_private_dns_namespace = true
    namespace_name               = "multi-lambda.internal"
    namespace_description        = "Multiple Lambda services in CloudMap"
    vpc_id                       = "vpc-12345678"
    services = {
      "api-service" = {
        name                                  = "api-service"
        description                           = "API service for Lambda functions"
        dns_ttl                               = 60
        dns_record_type                       = "CNAME"
        routing_policy                        = "WEIGHTED"
        health_check_custom_config            = true
        custom_health_check_failure_threshold = 1
      }
      "worker-service" = {
        name                                  = "worker-service"
        description                           = "Worker service for Lambda functions"
        dns_ttl                               = 120
        dns_record_type                       = "CNAME"
        routing_policy                        = "MULTIVALUE"
        health_check_custom_config            = true
        custom_health_check_failure_threshold = 1
      }
    }
    enable_health_checks = true

    # Lambda registration in specific service
    enable_lambda_registration = true
    lambda_instance_id         = "worker-lambda-01"
    lambda_url                 = "https://worker123.lambda-url.ap-southeast-2.on.aws"
    lambda_service_name        = "worker-service" # Register in worker-service
    lambda_attributes = {
      "environment"   = "production"
      "version"       = "v2.0.0"
      "function_name" = "worker-function"
      "service_type"  = "worker"
    }

    tags = {
      Environment = "production"
      Project     = "multi-lambda"
    }
  }

  assert {
    condition     = length(var.services) == 2
    error_message = "Should have 2 services defined"
  }

  assert {
    condition     = var.lambda_service_name == "worker-service"
    error_message = "Lambda should be registered in worker-service"
  }

  assert {
    condition     = var.lambda_instance_id == "worker-lambda-01"
    error_message = "Lambda instance ID should be worker-lambda-01"
  }

  assert {
    condition     = var.lambda_attributes["service_type"] == "worker"
    error_message = "Lambda service type should be worker"
  }
}

# Test Lambda Registration Validation
run "lambda_registration_validation" {
  command = plan

  variables {
    create_private_dns_namespace = true
    namespace_name               = "validation.internal"
    namespace_description        = "Lambda registration validation test"
    vpc_id                       = "vpc-12345678"
    services = {
      "api-service" = {
        name                                  = "api-service"
        description                           = "API service for validation"
        dns_ttl                               = 60
        dns_record_type                       = "CNAME"
        routing_policy                        = "WEIGHTED"
        health_check_custom_config            = true
        custom_health_check_failure_threshold = 1
      }
    }
    enable_health_checks = true

    # Lambda registration with validation
    enable_lambda_registration = true
    lambda_instance_id         = "valid-lambda-01" # Valid ID format
    lambda_url                 = "https://valid123.lambda-url.ap-southeast-2.on.aws"
    lambda_service_name        = "api-service"
    lambda_attributes = {
      "environment"   = "staging"
      "version"       = "v1.0.0"
      "function_name" = "valid-function"
    }

    tags = {
      Environment = "staging"
      Project     = "validation"
    }
  }

  assert {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.lambda_instance_id))
    error_message = "Lambda instance ID should contain only alphanumeric characters, hyphens, and underscores"
  }

  assert {
    condition     = can(regex("^https://", var.lambda_url))
    error_message = "Lambda URL should be a valid HTTPS URL"
  }

  assert {
    condition     = var.lambda_attributes["environment"] == "staging"
    error_message = "Lambda environment should be staging"
  }
}
