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
Wire backend upgrade to 5.13, see [docs](link-to-docs) 
```

All changelog entries in the `changelog.d/` directory must follow commit message standards based on the [Keep a Changelog specification](https://keepachangelog.com/en/1.1.0/). Below are examples of properly formatted commit messages for each subdirectory in our changelog structure, along with descriptions of what content belongs in each subdirectory. 

**NOTE**: The changelog.d entries will be verified using the github workflow [Changelog verification](.github/workflows/changelog-verify.yml).

#### Directory Structure

##### 0-release-notes
This directory contains extra notes about the release. It is intended for high-level release notes that provide an overview of what's new, what's changed, and any important information about the release. This is typically used for communicating with stakeholders and end-users.

*changelog entry example:* `Changed: v0.0.0 Major Release`

##### 1-debian-builds
Contains notes about changes related to Debian package builds. This includes modifications to build scripts (e.g., `build_linux_pkgs.sh`), changes in dependencies, and any other updates related to the creation of Debian packages.

*changelog entry example:* `Fixed: resolve dependency issue for gngpg package`

##### 2-wire-builds
Documents changes related to the `wire-builds` repository. This includes updates to the values directory, modifications to Helm charts for Wire components, and any other changes specific to the Wire builds process.

*changelog entry example:* `Added: add support for postgresql to support wire release 5.17.0`

##### 3-deploy-builds
Used to document changes in deployment processes and upgrades. Examples include Kubernetes upgrades via Ansible, changes in the `/offline/tasks` directory, and other deployment-related modifications.

*changelog entry example:* `Deprecated: remove support for Kubernetes 1.26`

##### 4-docs
Contains documentation related to deployment or bundling processes. This includes updates to installation guides, configuration instructions, and any other relevant documentation.

*changelog entry example:* `Changed: update guide for wiab-demo solution`

##### 5-bug-fixes
Documents bug fixes for any existing solutions. This includes fixes for issues in the deployment process, build scripts, or any other component of the project.

*changelog entry example:* `Fixed: fix the postgresql dependency on old non-existing images`

### (Optional) Git commit message verification
This repository uses a Git commit [hook](./.git-hooks/commit-msg) to enforce the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) standard with an additional requirement for a Jira ticket ID (e.g., wpb-1234 or WPB-1234). The hook checks that commit messages follow the format:

```
<type>(<scope>): <description> <ticket-id> 
```

#### Examples of Valid Commit Messages:
- *build: WPB-1234 update build configuration*
- *feat(parser): add new parsing rules WPB-1234*
- *fix(ui): wpb-1234 correct button alignment*
- *ci: update CI pipeline wpb-1234*
- *docs: update wpb-1234 README*
- *refactor: wpb-1234 clean up code*
- *test: add unit tests wpb-1234*
- *chore!: WPB-1234 drop support for k8s 1.16 - add a 'BREAKING CHANGE:' statement*

#### Activation/Deactivation:
The commit hook is optional and can be activated or deactivated using the `.envrc` script with direnv:
```
wire-server-deploy$ direnv allow
direnv: loading ~/projects/git/wire-server-deploy/.envrc
Do you want to setup git commit hooks? (y/Y to continue):
```
