Terraform module: DNS records
=============================

State: __experimental__

This module creates a set of DNS entries on AWS. As of now it's capable of managing the following type of records:

* A (`ips`)
* CNAME (`cnames`)

AWS resources: route53


#### How to use the module

Assuming you already have a root zone with fqdn `default.domain` in route53 setup elsewhere, example usage:

```hcl
module "dns_records" {
  source = "github.com/wireapp/wire-server-deploy.git//terraform/modules/aws-dns-records?ref=CHANGE-ME"

  zone_fqdn = "default.domain"
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
  srvs = { "_wire-server._tcp" = [ "0 10 443 nginz-https" ] }
}
```

This creates entries for the following FQDNs:

* `nginz-https.staging.default.domain`
* `nginz-ssl.staging.default.domain`
* `webapp.staging.default.domain`
* `assets.staging.default.domain`
* `account.staging.default.domain`
* `teams.staging.default.domain`

It also creates a TXT SPF record for your mail server on `staging.default.domain` with a value `"v=spf1 ip4:9.9.9.10 ip4:23.42.23.42 -all"`

As well as an SRV record `_wire-server._tcp.staging.default.domain` pointing to `0 10 443 nginz-https.staging.default.domain`

These sub-domains represent the primary set of FQDNs used in a
[`wire-server` installation](https://docs.wire.com/how-to/install/helm-prod.html#how-to-set-up-dns-records),
to expose all frontend applications as well as necessary HTTP & websocket endpoints.
