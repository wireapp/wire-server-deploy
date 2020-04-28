# the world can ssh to this instance.
output "world_ssh_in" {
  value = aws_security_group.world_ssh_in.id
}

# this instance can SSH into other boxes in the VPC.
output "ssh_from" {
  value = aws_security_group.ssh_from.id
}

# apply to boxes you want "ssh_from" hosts to be able to talk to.
output "has_ssh" {
  value = aws_security_group.has_ssh.id
}

output "world_web_out" {
  value = aws_security_group.world_web_out.id
}

output "talk_to_assets" {
  value = aws_security_group.talk_to_assets.id
}

output "has_assets" {
  value = aws_security_group.has_assets.id
}

output "talk_to_stateful" {
  value = aws_security_group.talk_to_stateful.id
}

output "stateful_node" {
  value = aws_security_group.stateful_node.id
}

output "stateful_private" {
  value = aws_security_group.stateful_private.id
}

output "talk_to_k8s" {
  value = aws_security_group.talk_to_k8s.id
}

output "k8s_private" {
  value = aws_security_group.k8s_private.id
}

output "k8s_node" {
  value = aws_security_group.k8s_node.id
}

