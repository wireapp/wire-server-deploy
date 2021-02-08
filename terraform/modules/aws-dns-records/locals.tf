locals {
  name_suffix = concat(
    var.domain != null ? [var.domain] : [],
    [var.zone_fqdn]
  )
}
