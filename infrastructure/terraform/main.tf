# =============================================================================
# Terraform Configuration - Production Infrastructure
# AWS EKS Cluster with RDS, Redis, and Monitoring
# =============================================================================

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
  
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "production/terraform.tfstate"
    region = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt = true
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Variables
# ─────────────────────────────────────────────────────────────────────────────

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "app-production"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.r6g.large"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 100
}

variable "redis_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.r6g.large"
}

variable "redis_num_cache_nodes" {
  description = "Number of cache nodes"
  type        = number
  default     = 2
}

# ─────────────────────────────────────────────────────────────────────────────
# Provider Configuration
# ─────────────────────────────────────────────────────────────────────────────

provider "aws" {
  region = var.region
  
  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy  = "Terraform"
      Project    = "Application"
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# VPC and Networking
# ─────────────────────────────────────────────────────────────────────────────

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  
  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr
  
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs
  
  enable_nat_gateway     = true
  single_nat_gateway    = false
  enable_dns_hostnames  = true
  enable_dns_support    = true
  
  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# EKS Cluster
# ─────────────────────────────────────────────────────────────────────────────

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"
  
  cluster_name    = var.cluster_name
  cluster_version = "1.28"
  
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets
  
  # EKS Addons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      service_account_role_policy_arn = aws_iam_policy.ebs_csi_policy.arn
    }
  }
  
  # Node groups configuration
  eks_managed_node_groups = {
    general = {
      name            = "general"
      instance_types  = ["m6i.xlarge"]
      min_size        = 2
      max_size        = 10
      desired_size    = 3
      
      labels = {
        role = "general"
      }
      
      taints = []
      
      update_config = {
        max_unavailable_percentage = 33
      }
      
      tags = {
        NodeGroup = "general"
      }
    }
    
    monitoring = {
      name            = "monitoring"
      instance_types  = ["m6i.large"]
      min_size        = 1
      max_size        = 3
      desired_size    = 1
      
      labels = {
        role = "monitoring"
      }
      
      taints = []
    }
  }
  
  # IRSA for cluster-autoscaler
  enable_cluster_creator_admin_permissions = true
  
  tags = {
    Environment = var.environment
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# EBS CSI Policy
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_policy" "ebs_csi_policy" {
  name        = "${var.cluster_name}-ebs-csi-policy"
  description = "Policy for EBS CSI driver"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSnapshot",
          "ec2:CreateTags",
          "ec2:DeleteSnapshot",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeSnapshots",
          "ec2:DescribeTags",
          "ec2:DescribeVolumes",
          "ec2:DescribeVolumesModifications",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateVolume",
          "ec2:DeleteVolume",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
        ]
        Resource = "*"
      }
    ]
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# RDS PostgreSQL
# ─────────────────────────────────────────────────────────────────────────────

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"
  
  identifier = "${var.cluster_name}-db"
  
  engine               = "postgres"
  engine_version       = "15.4"
  family               = "postgres15"
  instance_class       = var.db_instance_class
  allocated_storage    = var.db_allocated_storage
  max_allocated_storage = 500
  
  db_name  = "appdb"
  username = "appadmin"
  password = random_password.db_password.result
  
  multi_az               = true
  db_subnet_group_name   = module.vpc.database_subnet_group
  vpc_security_group_ids = [aws_security_group.rds.id]
  
  # Backup configuration
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"
  
  # Storage encryption
  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds_key.arn
  
  # Performance insights
  performance_insights_enabled = true
  
  # Logging
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  
  parameters = [
    {
      name  = "max_connections"
      value = "500"
    },
    {
      name  = "shared_buffers"
      value = "256MB"
    },
    {
      name  = "effective_cache_size"
      value = "768MB"
    },
    {
      name  = "maintenance_work_mem"
      value = "128MB"
    },
    {
      name  = "checkpoint_completion_target"
      value = "0.9"
    },
    {
      name  = "wal_buffers"
      value = "16MB"
    },
    {
      name  = "default_statistics_target"
      value = "100"
    },
    {
      name  = "random_page_cost"
      value = "1.1"
    },
    {
      name  = "effective_io_concurrency"
      value = "200"
    },
    {
      name  = "work_mem"
      value = "4MB"
    },
    {
      name  = "min_wal_size"
      value = "1GB"
    },
    {
      name  = "max_wal_size"
      value = "4GB"
    }
  ]
  
  tags = {
    Name = "${var.cluster_name}-db"
  }
}

resource "random_password" "db_password" {
  length  = 32
  special = true
}

resource "aws_kms_key" "rds_key" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  
  tags = {
    Name = "${var.cluster_name}-rds-key"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.cluster_name}-rds-sg"
  description = "Security group for RDS"
  vpc_id      = module.vpc.vpc_id
  
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks.id]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "${var.cluster_name}-rds-sg"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# ElastiCache Redis
# ─────────────────────────────────────────────────────────────────────────────

module "elasticache" {
  source  = "terraform-aws-modules/elasticache/aws"
  version = "~> 8.0"
  
  replication_group_id        = "${var.cluster_name}-redis"
  engine                      = "redis"
  engine_version              = "7.0"
  node_type                   = var.redis_node_type
  number_cache_nodes          = var.redis_num_cache_nodes
  parameter_group_name        = "default.redis7"
  port                        = 6379
  automatic_failover_enabled  = true
  multi_az_enabled           = true
  
  # Subnet group
  subnet_group_name        = "${var.cluster_name}-redis-subnet"
  subnet_ids               = module.vpc.private_subnets
  
  # Security group
  security_group_ids       = [aws_security_group.redis.id]
  
  # Backup
  snapshot_retention_limit   = 7
  snapshot_window           = "03:00-04:00"
  maintenance_window        = "mon:04:00-mon:05:00"
  
  # Encryption
  at_rest_encryption_enabled = true
  transit_encryption_enabled  = true
  auth_token_enabled          = true
  
  # Log delivery
  log_delivery_configuration = [
    {
      destination      = aws_cloudwatch_log_group.redis_slow_log.name
      destination_type = "cloudwatch-logs"
      log_format       = "json"
      log_type         = "slow-log"
    }
  ]
  
  tags = {
    Name = "${var.cluster_name}-redis"
  }
}

resource "aws_security_group" "redis" {
  name        = "${var.cluster_name}-redis-sg"
  description = "Security group for ElastiCache"
  vpc_id      = module.vpc.vpc_id
  
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.eks.id]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "${var.cluster_name}-redis-sg"
  }
}

resource "aws_cloudwatch_log_group" "redis_slow_log" {
  name              = "/aws/elasticache/${var.cluster_name}-redis/slow-log"
  retention_in_days = 7
  
  tags = {
    Name = "${var.cluster_name}-redis-slow-log"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# EKS Security Group
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_security_group" "eks" {
  name        = "${var.cluster_name}-eks-sg"
  description = "Security group for EKS cluster"
  vpc_id      = module.vpc.vpc_id
  
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
  
  tags = {
    Name = "${var.cluster_name}-eks-sg"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Load Balancer Controller
# ─────────────────────────────────────────────────────────────────────────────

data "aws_iam_policy_document" "lb_controller_assume_role" {
  statement {
    effect = "Allow"
    
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lb_controller" {
  name = "${var.cluster_name}-lb-controller"
  
  assume_role_policy = data.aws_iam_policy_document.lb_controller_assume_role.json
}

resource "aws_iam_policy" "lb_controller" {
  name = "${var.cluster_name}-lb-controller"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:CreateServiceLinkedRole",
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcs",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeTags",
          "ec2:GetSecurityGroups",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeVpcs",
          "ec2:ModifyVpcAttribute",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.lb_controller.arn
}

# ─────────────────────────────────────────────────────────────────────────────
# Metrics Server
# ─────────────────────────────────────────────────────────────────────────────

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.11.0"
  
  set {
    name  = "args[0]"
    value = "--kubelet-preferred-address-type=InternalIP"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Cluster Autoscaler
# ─────────────────────────────────────────────────────────────────────────────

resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = "9.35.0"
  
  set {
    name  = "cloudProvider"
    value = "aws"
  }
  
  set {
    name  = "awsRegion"
    value = var.region
  }
  
  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
  }
  
  set {
    name  = "rbac.serviceAccount.create"
    value = "true"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Output Values
# ─────────────────────────────────────────────────────────────────────────────

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = module.eks.cluster_security_group_id
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.db_instance_endpoint
  sensitive   = true
}

output "rds_password" {
  description = "RDS password"
  value       = random_password.db_password.result
  sensitive   = true
}

output "redis_endpoint" {
  description = "ElastiCache endpoint"
  value       = module.elasticache.redis_endpoint
  sensitive   = true
}

output "redis_auth_token" {
  description = "ElastiCache auth token"
  value       = module.elasticache.auth_token
  sensitive   = true
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}
