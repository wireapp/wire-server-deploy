resource "aws_instance" "machine" {
  ami           = data.aws_ami.instance_image[0].id

  // NOTE: the trick is to use a self-provided uID as identifier not an index of a list, otherwise
  // TF reshuffles things removes the wrong instance
  // see https://medium.com/@yashvanzara/terraform-deleting-an-element-from-a-list-cb5bdadc8bbd
  for_each = { for i,v in var.instances : lookup(v, "name") => v }

  instance_type = lookup(each.value, "type", null) != null ? lookup(each.value, "type") : var.type

  subnet_id = lookup(each.value, "subnet", null) != null ? lookup(each.value, "subnet") : var.subnet
  key_name = var.sshkey

  root_block_device {
    volume_size = lookup(each.value, "volume_size", null) != null ? tonumber(lookup(each.value, "volume_size")) : var.volume_size
  }

  vpc_security_group_ids = var.security_groups

  tags = merge(
    {
      Name        = "${var.environment}-${lookup(each.value, "name")}",
      Environment = var.environment,
      Role        = var.role
    },
    var.tags
  )
}
