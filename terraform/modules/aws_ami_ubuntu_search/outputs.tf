output "u18_arm64_ami_id" {

  value = data.aws_ami.U18_04_arm64.id

}

output "u18_amd64_ami_id" {

  value = data.aws_ami.U18_04_amd64.id

}
