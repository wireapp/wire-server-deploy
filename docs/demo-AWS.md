### Demo-AWS

* AWS account required
* Similar limited functionality to Demo except:
    * Allows using ELBs for incoming traffic
    * Potentially better availability of some parts

Differences to the [Demo installation](../README.md#demo-installation) are:

* instead of using fake-aws charts, you need to set up the respective services in your account, create queues,tables etc. Have a look at the fake-aws-* charts; you'll need to replicate a similar setup.
    * Once real AWS resources are created, adapt the configuration in the values and secrets files to use real endpoints and real AWS keys.
* instead of using a mail server and connect with SMTP, you may use SES. See configuration of brig and the `useSES` toggle.
* You can use ELBs in front of nginz for higher availability.
* SQS/dynamo have better availability gurantees.

## AWS resource creation automation

Creating AWS resources in a way that is easy to create and delete could be done using either [terraform](https://www.terraform.io/) or [pulumi](https://pulumi.io/). If you'd like to contribute by creating such automation, feel free to read the [contributing guidelines](../CONTRIBUTING.md) and open a PR.
