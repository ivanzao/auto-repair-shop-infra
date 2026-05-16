output "cluster_name" { value = aws_eks_cluster.main.name }
output "cluster_endpoint" { value = aws_eks_cluster.main.endpoint }
output "cluster_ca" { value = aws_eks_cluster.main.certificate_authority[0].data }
output "cluster_sg_id" { value = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id }
output "node_group_asg_names" {
  value = flatten([for r in aws_eks_node_group.default.resources : r.autoscaling_groups[*].name])
}
