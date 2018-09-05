# Wire™

[![Wire logo](https://github.com/wireapp/wire/blob/master/assets/header-small.png?raw=true)](https://wire.com/jobs/)

This repository is part of the source code of Wire. You can find more information at [wire.com](https://wire.com) or by contacting opensource@wire.com.

You can find the published source code at [github.com/wireapp/wire](https://github.com/wireapp/wire).

For licensing information, see the attached LICENSE file and the list of third-party licenses at [wire.com/legal/licenses/](https://wire.com/legal/licenses/).

No license is granted to the Wire trademark and its associated logos, all of which will continue to be owned exclusively by Wire Swiss GmbH. Any use of the Wire trademark and/or its associated logos is expressly prohibited without the express prior written consent of Wire Swiss GmbH.

## Wire server deployment

This repository contains code and documentation on how to deploy [wire-server](https://github.com/wireapp/wire-server). To allow a maximum of flexibility with respect to where wire-server can be deployed (e.g. with cloud providers like AWS, on bare-metal servers, etc), we chose kubernetes as the target platform.

This means you first need to install a kubernetes cluster, and then deploy wire-server onto that kubernetes cluster.

### Prerequisites

You need:

* a **Kubernetes cluster** with enough resources. There are [many different options](https://kubernetes.io/docs/setup/pick-right-solution/). A tiny subset of those solutions we tried include:
    * if using AWS, you may want to look at:
        * [EKS](https://aws.amazon.com/eks/) (if you're okay having all your data in one of the EKS-supported US regions)
        * [kops](https://github.com/kubernetes/kops)
    * if using regular physical or virtual servers:
        * [kubespray](https://github.com/kubernetes-incubator/kubespray)
* a **Domain Name** under your control and the ability to set DNS entries
* the ability to generate **SSL certificates** for that domain name
    * you could use e.g. [Let's Encrypt](https://letsencrypt.org/)
* depending on your required functionality, you may or may not need an [**AWS account**](https://aws.amazon.com/). See details about limitations without an AWS account in the following sections.

#### Required resources

TODO

### Development setup

TODO

* kubectl
* helm
* make
* 

### Installing wire-server

TODO

Supported features

#### Not using AWS

#### Using AWS
