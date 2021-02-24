Terraform module: DNS records
=============================

State: __experimental__

This module creates a set of DNS entries on AWS. As of now it's capable of managing the following type of records:

* A (`ips`)
* CNAME (`cnames`)

AWS resources: route53


#### How to use the module

Assuming you already have a root zone with fqdn `example.com` in route53 setup elsewhere, example usage:

```hcl
module "dns_records" {
  source = "github.com/wireapp/wire-server-deploy.git//terraform/modules/aws-dns-records?ref=CHANGE-ME"

  zone_fqdn = "example.com"
  domain = "staging"
  sub_domains = [
    "nginz-https",
    "nginz-ssl",
    "webapp",
    "assets",
    "account",
    "teams"
  ]
  ips = [ "9.9.9.10", "23.42.23.42" ]

  # Optional
  spf_record_ips = [ "9.9.9.10", "23.42.23.42" ]

  # Optional
  srvs = {
    prefix = "_wire-server._tcp"
    target_prefixes = [ "0 10 443 nginz-https" ]
  }
}
```

This creates entries for the following FQDNs:

* `nginz-https.staging.example.com`
* `nginz-ssl.staging.example.com`
* `webapp.staging.example.com`
* `assets.staging.example.com`
* `account.staging.example.com`
* `teams.staging.example.com`

It also creates a TXT SPF record for your mail server on `staging.example.com` with a value `"v=spf1 ip4:9.9.9.10 ip4:23.42.23.42 -all"`

These sub-domains represent the primary set of FQDNs used in a
[`wire-server` installation](https://docs.wire.com/how-to/install/helm-prod.html#how-to-set-up-dns-records),
to expose all frontend applications as well as necessary HTTP & websocket endpoints.
