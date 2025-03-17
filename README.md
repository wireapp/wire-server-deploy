# Wire™

[![Wire logo](https://github.com/wireapp/wire/blob/master/assets/header-small.png?raw=true)](https://wire.com/jobs/)

This repository is part of the source code of Wire. You can find more information at [wire.com](https://wire.com) or by contacting opensource@wire.com.

You can find the published source code at [github.com/wireapp/wire](https://github.com/wireapp/wire).

For licensing information, see the attached [LICENSE](LICENSE) file and the list of third-party licenses at [wire.com/legal/licenses/](https://wire.com/legal/licenses/).

No license is granted to the Wire trademark and its associated logos, all of which will continue to be owned exclusively by Wire Swiss GmbH. Any use of the Wire trademark and/or its associated logos is expressly prohibited without the express prior written consent of Wire Swiss GmbH.

## Introduction

This repository contains the code and configuration to deploy [wire-server](https://github.com/wireapp/wire-server) and [wire-webapp](https://github.com/wireapp/wire-webapp), as well as dependent components, such as cassandra databases. To allow a maximum of flexibility with respect to where wire-server can be deployed (e.g. with cloud providers like AWS, on bare-metal servers, etc), we chose [kubernetes](https://kubernetes.io/) as the target platform.

## Documentation

All the documentation on how to make use of this repository is hosted on https://docs.wire.com - refer to the Administrator's Guide.

## Contents

* `ansible/` contains Ansible roles and playbooks to install Kubernetes, Cassandra, etc. See the [Administrator's Guide](https://docs.wire.com) for more info.
* `charts/` contains helm charts that can be installed on kubernetes. The charts are mirroed to S3 and can be used with `helm repo add wire https://s3-eu-west-1.amazonaws.com/public.wire.com/charts`. See the [Administrator's Guide](https://docs.wire.com) for more info.
* `terraform/` contains some examples for provisioning servers. See the [Administrator's Guide](https://docs.wire.com) for more info.
* `bin/` contains some helper bash scripts. Some are used in the [Administrator's Guide](https://docs.wire.com) when installing wire-server, and some are used for developers/maintainers of this repository.

## PR Guidelines

In most cases, the only required action when creating a PR is creating a changelog entry (see below).

### Changelog entries

Every PR should add a new file in the appropriate subdirectory of `changelog.d`, containing just the text of the corresponding changelog entry. There is no need to explicitly write a PR number, because the `mk-changelog.sh` script (used on release) will add it automatically at the end. The name of the file does not matter, but it should be unique to avoid unnecessary conflicts (e.g. use the branch name). Read more [here](https://docs.wire.com/developer/developer/changelog.html)

Example: create the file ./changelog.d/2-wire-builds/wire-chart-bump-5.13 with one-line content like:
```
Wire backend upgrade to 5.13, see [docs](link-to-docs)```
