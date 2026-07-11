############################################
# modules/eks-nodegroup/nodegroup.tf
# Launch Template + EKS Managed Node Group
############################################

data "aws_ssm_parameter" "eks_ami" {
  name = "/aws/service/eks/optimized-ami/${var.kubernetes_version}/amazon-linux-2/recommended/image_id"
}

resource "aws_launch_template" "this" {
  name_prefix = "${var.cluster_name}-${var.nodegroup_name}-"
  description = "Launch template for ${var.cluster_name} / ${var.nodegroup_name} managed node group"

  image_id      = var.ami_id != "" ? var.ami_id : data.aws_ssm_parameter.eks_ami.value
  instance_type = var.instance_types[0]
  key_name      = var.ssh_key_name != "" ? var.ssh_key_name : null

  vpc_security_group_ids = [var.node_security_group_id]

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.disk_size
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.kms_key_arn
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # enforce IMDSv2
    http_put_response_hop_limit = 2
  }

  monitoring {
    enabled = true
  }

  # Bootstrap script joins the node to the cluster and applies labels/taints
  user_data = base64encode(templatefile("${path.module}/templates/userdata.sh.tpl", {
    cluster_name        = var.cluster_name
    cluster_endpoint    = var.cluster_endpoint
    cluster_ca          = var.cluster_certificate_authority_data
    bootstrap_extra_args = var.bootstrap_extra_args
    node_labels         = var.node_labels
    node_taints         = var.node_taints
  }))

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      var.tags,
      {
        Name                                          = "${var.cluster_name}-${var.nodegroup_name}"
        "kubernetes.io/cluster/${var.cluster_name}"    = "owned"
      }
    )
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(
      var.tags,
      {
        Name = "${var.cluster_name}-${var.nodegroup_name}-volume"
      }
    )
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eks_node_group" "this" {
  cluster_name    = var.cluster_name
  node_group_name = var.nodegroup_name
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids

  capacity_type  = var.capacity_type # ON_DEMAND or SPOT
  instance_types = var.instance_types

  launch_template {
    id      = aws_launch_template.this.id
    version = aws_launch_template.this.latest_version
  }

  scaling_config {
    min_size     = var.min_size
    max_size     = var.max_size
    desired_size = var.desired_size
  }

  update_config {
    max_unavailable = var.max_unavailable
  }

  dynamic "taint" {
    for_each = var.node_taints
    content {
      key    = taint.value.key
      value  = lookup(taint.value, "value", null)
      effect = taint.value.effect
    }
  }

  labels = var.node_labels

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-${var.nodegroup_name}"
    }
  )

  # Node IAM role must have policies attached before creating the node group
  depends_on = [aws_launch_template.this]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size] # let cluster-autoscaler manage this
  }
}
