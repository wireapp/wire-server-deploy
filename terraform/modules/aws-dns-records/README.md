Terraform module: DNS records
=============================

State: __experimental__

This module creates a set of DNS entries on AWS. As of now it's capable of managing the following type of records:

* A (`ips`)
* CNAME (`cnames`)

AWS resources: route53


#### How to use the module

```hcl
module "dns_records" {
  source = "github.com/wireapp/wire-server-deploy.git//terraform/modules/aws-dns-records?ref=develop"
  
  environment = "staging"

  zone_fqdn = "example.com"
  ips = [ "9.9.9.10", "23.42.23.42" ]
}
```

If not further specified, it created entries for the following FQDNs:

* `nginz-https.staging.example.com`
* `nginz-ssl.staging.example.com`
* `webapp.staging.example.com`
* `assets.staging.example.com`
* `account.staging.example.com`
* `teams.staging.example.com`
