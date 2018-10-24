### Demo-OnPrem

* A kubernetes node with a _public_ IP address (or internal, if you do not plan to expose the Wire backend over the Internet but we will assume you are using a public IP address)
* DNS records for the different exposed addresses (the ingress depends on the usage of virtual hosts), namely:
 * bare-https.<domain>
 * bare-ssl.<domain>
 * bare-s3.<domain>
 * bare-webapp.<domain>
 * bare-team.<domain> (optional)
* A wildcard certificate for the different hosts (*.<domain>) - we assume you want to do SSL termination on the ingress controller
* Similar limited functionality to Demo except:
    * Allows using a provided LB for incoming traffic
    * SSL termination is done on the ingress controller

Differences to the [Demo installation](../README.md#demo-installation) are:

* There is a load balancer that can assign public IP addresses from a given range to be exposed for incoming traffic to the cluster
 * Note that there can be a _single_ load balancer, otherwise your cluster might become [unstable](https://metallb.universe.tf/installation/)
* You can access your cluster with given DNS names, over SSL and from anywhere in the internet
