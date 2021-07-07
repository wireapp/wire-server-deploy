variable "image" {
  type = object({
    filter = string
    owner = string
    hypervisor = string
  })
  description = "AMI information"
}
