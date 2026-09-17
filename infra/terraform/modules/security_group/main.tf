# Least-privilege firewall: only 22 (admin), 80 and 443 (world) are public.
# The k8s API (6443) and all node-to-node k3s ports stay off the internet —
# 6443 is admin-only, everything else the cluster needs between nodes
# (flannel VXLAN, kubelet, etc.) is allowed only within this security group.

resource "aws_security_group" "nodes" {
  name        = "${var.project}-nodes-sg"
  description = "TaskApp k3s nodes"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project}-nodes-sg"
  }
}

resource "aws_security_group_rule" "ssh_admin" {
  type              = "ingress"
  security_group_id = aws_security_group.nodes.id
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.admin_cidrs
  description       = "SSH from admin CIDRs only"
}

resource "aws_security_group_rule" "http_world" {
  type              = "ingress"
  security_group_id = aws_security_group.nodes.id
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTP (cert-manager ACME HTTP-01 + ingress)"
}

resource "aws_security_group_rule" "https_world" {
  type              = "ingress"
  security_group_id = aws_security_group.nodes.id
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTPS ingress"
}

resource "aws_security_group_rule" "k8s_api_admin" {
  type              = "ingress"
  security_group_id = aws_security_group.nodes.id
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  cidr_blocks       = var.admin_cidrs
  description       = "kube-apiserver - admin CIDRs only, never 0.0.0.0/0"
}

resource "aws_security_group_rule" "node_to_node" {
  type              = "ingress"
  security_group_id = aws_security_group.nodes.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1" # All protocols, all ports hence from 0 to 0 is given that because any other value would be rejected by AWS
  self              = true # for only incoming traffic whose source is this same security group (i.e. node-to-node traffic)
  description       = "All node-to-node k3s traffic (API, flannel VXLAN, kubelet, etc.) stays inside this SG"
}

resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.nodes.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Outbound: pulling images, apt, ACME, etc."
}
