############################################
# envs/dev/main.tf
############################################

locals {
  environment = "dev"
  cluster_name = var.cluster_name

  common_tags = {
    Project     = "novabank"
    Environment = local.environment
    ManagedBy   = "terraform"
  }

  # Per-microservice metadata used to wire IRSA roles <-> namespaces <-> service accounts
  # consistently across modules.iam_eks_irsa and modules.kubernetes.
  microservices = {
    "auth-service" = {
      namespace       = "auth"
      service_account = "auth-service-sa"
    }
    "accounts-service" = {
      namespace       = "accounts"
      service_account = "accounts-service-sa"
    }
    "transactions-service" = {
      namespace       = "transactions"
      service_account = "transactions-service-sa"
    }
    "notifications-service" = {
      namespace       = "notifications"
      service_account = "notifications-service-sa"
    }
  }
}

############################################
# 1) Networking
############################################

module "vpc" {
  source = "../../modules/vpc"

  environment        = local.environment
  cluster_name       = local.cluster_name
  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  single_nat_gateway = var.single_nat_gateway

  tags = local.common_tags
}

module "security_groups" {
  source = "../../modules/security-groups"

  environment  = local.environment
  cluster_name = local.cluster_name
  vpc_id       = module.vpc.vpc_id
  vpc_cidr     = var.vpc_cidr

  tags = local.common_tags
}

# CloudWatch Logs VPC interface endpoint — lives at root, not inside
# modules/vpc, because it needs the SG created by modules/security_groups
# and putting it inside modules/vpc would create a circular module
# dependency (vpc needs the SG, security_groups needs the VPC id).
resource "aws_vpc_endpoint" "logs" {
  vpc_id             = module.vpc.vpc_id
  service_name       = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.security_groups.vpc_endpoints_security_group_id]

  private_dns_enabled = true

  tags = merge(
    local.common_tags,
    { Name = "${local.environment}-logs-vpce" }
  )
}

############################################
# 2) Data layer
############################################

module "secrets" {
  source = "../../modules/secrets"

  project              = "novabank"
  env                  = local.environment
  rds_master_username  = var.rds_master_username

  tags = local.common_tags
}

module "ecr" {
  source = "../../modules/ecr"

  project     = "novabank"
  env         = local.environment
  kms_key_arn = module.secrets.kms_key_arn

  tags = local.common_tags
}

module "rds" {
  source = "../../modules/rds"

  project = "novabank"
  env     = local.environment

  private_subnet_ids = module.vpc.private_subnet_ids
  rds_sg_id          = module.security_groups.rds_security_group_id
  lambda_sg_id       = module.security_groups.lambda_security_group_id
  kms_key_arn        = module.secrets.kms_key_arn

  rds_master_username    = var.rds_master_username
  rds_master_password    = module.secrets.rds_master_password
  rds_master_secret_arn  = module.secrets.rds_master_secret_arn
  schema_secret_arns     = module.secrets.schema_secret_arns

  db_instance_class = var.rds_instance_class

  tags = local.common_tags
}

############################################
# 3) IAM — base roles (no OIDC dependency yet)
############################################

module "iam_eks_base" {
  source = "../../modules/iam-eks"

  cluster_name        = local.cluster_name
  enable_ssm_on_nodes  = true
  irsa_roles          = {} # populated later by module.iam_eks_irsa, after OIDC exists

  tags = local.common_tags
}

############################################
# 4) EKS control plane
############################################

module "eks" {
  source = "../../modules/eks"

  cluster_name            = local.cluster_name
  kubernetes_version      = var.kubernetes_version
  cluster_role_arn        = module.iam_eks_base.cluster_role_arn
  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.vpc.private_subnet_ids
  node_security_group_id  = module.security_groups.eks_node_security_group_id
  endpoint_private_access = true
  endpoint_public_access  = var.eks_endpoint_public_access
  public_access_cidrs     = var.eks_public_access_cidrs
  log_retention_days      = var.log_retention_days
  kms_key_arn             = module.secrets.kms_key_arn

  tags = local.common_tags
}

############################################
# 5) OIDC provider (bridges eks -> iam-eks IRSA)
############################################

module "oidc" {
  source = "../../modules/oidc"

  cluster_name            = local.cluster_name
  cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url

  tags = local.common_tags
}

############################################
# 6) IAM — IRSA roles, now that OIDC exists
############################################

module "iam_eks_irsa" {
  source = "../../modules/iam-eks"

  cluster_name      = "${local.cluster_name}-irsa"
  oidc_provider_arn = module.oidc.oidc_provider_arn
  oidc_provider_url = module.oidc.oidc_provider_url

  irsa_roles = {
    for svc, cfg in local.microservices : svc => {
      namespace          = cfg.namespace
      service_account    = cfg.service_account
      policy_arns        = []
      inline_policy_json = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect   = "Allow"
          Action   = ["secretsmanager:GetSecretValue"]
          Resource = module.secrets.schema_secret_arns[cfg.namespace]
        }]
      })
    }
  }

  tags = local.common_tags
}

############################################
# 7) Worker nodes
############################################

module "eks_nodegroup" {
  source = "../../modules/eks-nodegroup"

  cluster_name                        = module.eks.cluster_name
  cluster_endpoint                    = module.eks.cluster_endpoint
  cluster_certificate_authority_data  = module.eks.cluster_certificate_authority_data
  kubernetes_version                  = var.kubernetes_version
  nodegroup_name                      = "general"

  node_role_arn           = module.iam_eks_base.node_role_arn
  node_security_group_id  = module.security_groups.eks_node_security_group_id
  subnet_ids              = module.vpc.private_subnet_ids
  kms_key_arn             = module.secrets.kms_key_arn

  capacity_type  = var.node_capacity_type
  instance_types = var.node_instance_types
  disk_size      = var.node_disk_size

  min_size     = var.node_min_size
  max_size     = var.node_max_size
  desired_size = var.node_desired_size

  tags = local.common_tags
}

############################################
# 8) EKS Add-ons
############################################

module "addons" {
  source = "../../modules/addons"

  cluster_name           = module.eks.cluster_name
  oidc_provider_arn      = module.oidc.oidc_provider_arn
  oidc_provider_url      = module.oidc.oidc_provider_url
  node_group_dependency  = module.eks_nodegroup.node_group_id

  enable_ebs_csi_driver = true

  tags = local.common_tags
}

############################################
# 9) Helm releases (ALB Controller, autoscaler, external-dns)
############################################

module "helm" {
  source = "../../modules/helm"

  cluster_name      = module.eks.cluster_name
  aws_region        = var.aws_region
  vpc_id            = module.vpc.vpc_id
  oidc_provider_arn = module.oidc.oidc_provider_arn
  oidc_provider_url = module.oidc.oidc_provider_url

  enable_cluster_autoscaler = true
  enable_external_dns       = var.enable_external_dns
  hosted_zone_name          = var.hosted_zone_name

  tags = local.common_tags

  depends_on = [module.addons]
}

############################################
# 10) Kubernetes-level objects (namespaces, service accounts, quotas)
############################################

module "kubernetes" {
  source = "../../modules/kubernetes"

  environment = local.environment

  namespaces = {
    "api-gateway"        = {}
    "auth"               = {}
    "accounts"           = {}
    "transactions"       = {}
    "notifications"      = {}
    "frontend-customers" = {}
    "frontend-teller"    = {}
  }

  service_accounts = {
    for svc, cfg in local.microservices : svc => {
      name          = cfg.service_account
      namespace     = cfg.namespace
      irsa_role_arn = module.iam_eks_irsa.irsa_role_arns[svc]
    }
  }

  enable_default_deny_network_policy = true

  depends_on = [module.eks_nodegroup]
}

############################################
# 11) Edge — WAF + CloudFront (in front of the ALB
#     that module.helm's ALB Controller provisions
#     dynamically once Ingress objects are applied)
############################################

module "waf" {
  source = "../../modules/waf"

  providers = {
    aws = aws.us_east_1
  }

  environment         = local.environment
  teller_allowed_ips  = var.teller_allowed_ips

  tags = local.common_tags
}

module "cloudfront" {
  source = "../../modules/cloudfront"

  environment                    = local.environment
  customer_domain                = var.customer_domain
  teller_domain                  = var.teller_domain
  hosted_zone_name               = var.hosted_zone_name
  acm_certificate_arn_us_east_1  = var.acm_certificate_arn_us_east_1
  waf_customer_acl_arn           = module.waf.customer_web_acl_arn
  waf_teller_acl_arn             = module.waf.teller_web_acl_arn

  # NOTE: the ALB origin domain isn't known until the AWS Load Balancer
  # Controller creates it from an Ingress (post-apply, out of band).
  # Set this manually after Step 9 in the README, or wire it via a
  # `data "kubernetes_ingress_v1"` lookup once the Ingress exists.
  alb_origin_domain = var.alb_origin_domain

  tags = local.common_tags
}
