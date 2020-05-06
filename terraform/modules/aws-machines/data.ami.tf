data "aws_ami" "instance_image" {
  count = length(var.instances) > 0 ? 1 : 0

  most_recent = true

  filter {
    name   = "name"
    values = [var.image.filter]
  }

  filter {
    name   = "virtualization-type"
    values = [var.image.hypervisor]
  }

  owners = [var.image.owner]
}
