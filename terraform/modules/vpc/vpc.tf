############################################
# modules/vpc/vpc.tf
#
# Key change for EKS: private AND public subnets now carry the
# kubernetes.io/cluster/<name> and kubernetes.io/role/* tags the
# AWS Load Balancer Controller and the EKS control plane use to
# auto-discover which subnets to place ENIs/ALBs in. Without these
# tags, `kubectl apply -f ingress.yaml` will fail to provision an
# ALB with an unhelpful "could not find subnets" error.
############################################

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    var.tags,
    { Name = "${var.environment}-vpc" }
  )
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    { Name = "${var.environment}-igw" }
  )
}

# ------------------------------------------------------------------
# Public subnets — one per AZ. Used by NAT Gateways and, if you ever
# expose an internet-facing ALB directly (rather than only via
# CloudFront), by the Load Balancer Controller.
# ------------------------------------------------------------------

resource "aws_subnet" "public" {
  count = var.az_count

  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name                                         = "${var.environment}-public-${count.index}"
      "kubernetes.io/cluster/${var.cluster_name}"  = "shared"
      "kubernetes.io/role/elb"                     = "1"
    }
  )
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(
    var.tags,
    { Name = "${var.environment}-public-rt" }
  )
}

resource "aws_route_table_association" "public" {
  count = var.az_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ------------------------------------------------------------------
# Private subnets — one per AZ. Where EKS nodes, RDS, and the
# control plane ENIs live.
# ------------------------------------------------------------------

resource "aws_subnet" "private" {
  count = var.az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + var.az_count)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(
    var.tags,
    {
      Name                                          = "${var.environment}-private-${count.index}"
      "kubernetes.io/cluster/${var.cluster_name}"   = "shared"
      "kubernetes.io/role/internal-elb"             = "1"
    }
  )
}

# ------------------------------------------------------------------
# NAT Gateways — one per AZ in prod (HA), single shared one in dev
# to save cost. Controlled by var.single_nat_gateway.
# ------------------------------------------------------------------

resource "aws_eip" "nat" {
  count  = var.single_nat_gateway ? 1 : var.az_count
  domain = "vpc"

  tags = merge(
    var.tags,
    { Name = "${var.environment}-nat-eip-${count.index}" }
  )
}

resource "aws_nat_gateway" "this" {
  count = var.single_nat_gateway ? 1 : var.az_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    var.tags,
    { Name = "${var.environment}-nat-${count.index}" }
  )

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "private" {
  count = var.az_count

  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.this[0].id : aws_nat_gateway.this[count.index].id
  }

  tags = merge(
    var.tags,
    { Name = "${var.environment}-private-rt-${count.index}" }
  )
}

resource "aws_route_table_association" "private" {
  count = var.az_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ------------------------------------------------------------------
# VPC Flow Logs
# ------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/novabank/${var.environment}/vpc-flow-logs"
  retention_in_days = var.flow_log_retention_days

  tags = merge(
    var.tags,
    { Name = "${var.environment}-vpc-flow-logs" }
  )
}

data "aws_iam_policy_document" "flow_logs_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow_logs" {
  name               = "${var.environment}-vpc-flow-logs-role"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume_role.json

  tags = var.tags
}

data "aws_iam_policy_document" "flow_logs_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["${aws_cloudwatch_log_group.flow_logs.arn}:*"]
  }
}

resource "aws_iam_role_policy" "flow_logs" {
  name   = "${var.environment}-vpc-flow-logs-policy"
  role   = aws_iam_role.flow_logs.id
  policy = data.aws_iam_policy_document.flow_logs_policy.json
}

resource "aws_flow_log" "this" {
  vpc_id               = aws_vpc.this.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow_logs.arn
  iam_role_arn         = aws_iam_role.flow_logs.arn

  tags = merge(
    var.tags,
    { Name = "${var.environment}-vpc-flow-log" }
  )
}
