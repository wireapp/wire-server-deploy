locals {
  name_suffix = concat(
    var.inject_addition_subtree ? [(var.domain != null ? var.domain : var.environment)] : [],
    [var.zone_fqdn]
  )
}
