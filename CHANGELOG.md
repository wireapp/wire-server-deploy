<!--

# NEXT

## Features

## Fixes

## Versions

## Breaking changes

-->

# Relase 5.23 

## release-notes

* Changed: wire-server updated to version 5.23.0 for prod, wiab-staging and wiab-dev/demo
* Changed: cargohold service will use the scoped `cargohold` user with least privilege, with access limited to its `assets` bucket only (#814)
* Changed: Enable Ansible-based RabbitMQ deployment and fix RabbitMQ host configuration for wire-server (#861)

### Data stores (PostgreSQL, Cassandra)

* Added: enable support for PostgreSQL deployment via Ansible (#797)
* Added: PostgreSQL high availability cluster with repmgr (#807)
* Changed: PostgreSQL password management is now centralized in Kubernetes Secrets (repmgr and wire-server credentials), eliminating hardcoded passwords from inventory (#819)
* Changed: update Cassandra from 3.11.16 to 3.11.19 (#831)

### Features / configuration
* Added: config for MLS deployment into example files (#824)

## wire-builds

* Changed: pre_clean_values_0.sh to clean unnecessary files
  * Removed: `patch-chart-images.sh` as it is not required anymore
  * Fixed: default|demo|min-build definitions to have more precise values and chart definitions (#825)
* Changed: Standardized all scripts to use `yq-go` (v4+) for YAML processing, replacing deprecated `python-yq`. Updated syntax in offline deployment scripts (`cd.sh`, `cd-with-retry.sh`), build scripts (`build_adminhost_containers.sh`), demo deployment (`offline_deploy_k8s.sh`), secret sync utilities, and chart image extraction to ensure reliable YAML manipulation and fix CI build errors (#820)

## deploy-builds

### WIAB demo / staging (high‑level)

* Fixed: coturn and PostgreSQL secrets for demo-wiab
  * Added: `kube-prometheus-stack` values and enabled monitoring support from wire-server for demo-wiab
  * Added: values for wire-utility in demo-wiab (#826)
* Added: enable `cd-demo.sh` to verify demo-wiab builds (#826)
* Changed: add Ansible playbook for wiab-staging VM provisioning
  * Added: Terraform resources for wiab-staging
  * Added: `cd_staging` script to verify the default build bundle
  * Changed: restructured `offline.yml` flow – introduced wiab-staging build and split bundle processing with default-build (#861)

### Offline / CI / deployment pipeline

* Added: `bin/helm-operations.sh` to replace `offline-helm` and more closely follow production instructions
  * Changed: `bin/offline-secrets.sh` to support `helm-operations.sh` and add support for coturn secret (#858)
* Changed: Optimize Wire offline deployment pipeline with parallel job execution and S3 direct downloads
  * Added: retry logic with progressive server type fallbacks for Hetzner Cloud resource availability issues (#815)
* Changed: offline workflow to require explicit labels for PR builds (`build-default`, `build-demo`, `build-min`, `build-all`); PRs without labels no longer trigger builds (#836)
* Changed: remove hardcoded PostgreSQL passwords from `demo-secrets.example.yaml` and automatically inject passwords from `databases-ephemeral` chart during deployment (#817)

## docs

* Added: documentation on how to set up DKIM for SMTP in wire-server (#793)
* Added: enable cert-manager Helm chart deployment with example values files (#805)
* Added: wiab-staging documentation to wire-server-deploy and fixed coturn port ranges (#861)
* Added: Enable changelog management in wire-server-deploy (#764)

## bug-fixes
* Fixed: Optimize the `offline-env` load and add pipe/redirect functionality with `d` (#812)
* Fixed:  add localhost authentication for `postgres_exporter`, upgrade to v0.18.1, and enable `stat_checkpointer` collector for PostgreSQL 17 checkpoint metrics (#832)
* Fixed: changelog-verify.yml workflow to allow Zebot pushes to master (#806)
* Changed: offline-vm-setup.sh script now uses an Ubuntu cloud image and local seed ISO (#861) 

# 2021-08-27

## Fixes

* [Documentation] Fix offline deploy redis installation instructions, and SFT node tagging.
* [Wire-Server-Metrics] Fix spacing.

## Features

* [Operations] Add a custom terraform rule to the base Makefile, to improve deployment flexibility with terraform.


# 2021-06-16

## Fixes

* [Ansible] Prevent Minio installation from breaking when access or secret key contains `$`
* [CI] Ensure that the right version of wire-server is built into the air-gap bundle


# 2021-06-10

## Fixes

* update Cassandra role (#455)
* fix automated Ansible deployment (#468) 


# 2021-05-10

## Features

* Airgap installer is available. See [./offline/docs.md] for rudimentary
  instructions. We will integrate this into https://docs.wire.com/ over time
* Switched to nix+direnv for installing all the required dependencies for wire-server-deploy. If you do not want to use these tools you can use the [`quay.io/wire/wire-server-deploy`](https://quay.io/wire/wire-server-deploy) container image and mount wire-server-deploy into it.

## Versions

* wire version 2.106.0  when using the offline installer. However airgap
  bundles for charts might be moved to wire-server repository in the future; to
  decouple wire-server releases from the base platform.
* kubespray 2.15.0  (kubernetes 1.19.7)
* ansible-restund v0.2.6 (restund version v0.4.16b1.0.53)
* ansible-minio v2.1.0
* ansible-cassandra version v0.1.3
* ansible-elasticsearch 6.6.0


## Breaking changes

* Nix and direnv are used for installing all required tooling.

* charts have been moved to wire-server. Chart lifecycle is now tied to
  wire-server instead and is decoupled from the underlying platform. Charts in wire-server
  should be installed with helm 3.

* Our kubespray reference implementation has been bumped to kuberspray 2.15.0
  and kubernetes 1.19.7. This allows us to use Kubespray's support for offline deployments
  and new Kubernetes API features.

  If you were using our reference playbooks for setting up kubernetes, there is
  no direct upgrade path. Instead you should set up a new cluster; migrate the
  deployments there, and then point to the new cluster. This is rather easy at
  the moment as we only run stateless services in Kubernetes at this point.

* Restund role was bumped and uses `docker` instead of `rkt` now.
  We advice bringing up a fresh `restund` server; so that `rkt` is not installed.
  See https://github.com/wireapp/ansible-restund/commit/4db0bc066ded89cf0ae061e3ccac59f3738b33d9

  If you want to re-use your existing server we recommend:

  1. ssh into your `restund` server.
  2. `systemctl stop restund.service`
  3. now outside again, run the `restund.yml` playbook.


# 2020-12-21

* brig: Add setExpiredUserCleanupTimeout to configmap (#399) see also: https://github.com/wireapp/wire-server/pull/1264
* [helm] Remove duplicate fields from brig section in the example value files (#398)
* Add spar to the integration tests for brig (#397)

# 2020-12-17

## Update instructions
A new mandatory option has been introduced to
`brig` and `galley` which in the future will be used for Wire federation.  This domain name
is *not* optional even if federation is not used.

Please update your `values/wire-server/values.yaml` to set `brig.optSettings.setFederationDomain`
and `galley.settings.federationDomain` (Note the slightly different option name).

Because federation is not enabled yet the value of this option does not really
matter at this point, but we advise you to set it to the base domain of your
wire instalation.

**NOTE**: These changes apply to chart version **0.129.0** and later eventhough
this release was made later than that **0.129.0** chart was published. We're sorry for the
inconvenience.

## Features
* A chart has been added for setting up a single-node conferencing server (Also known as *SFT*) (#382)

# 2020-12-07

## Update instructions

The redis chart that we updated to exposes the redis service as
`redis-ephemeral-master` instead of `redis-ephemeral`.

**You should update your `values/wire-server/values.yaml` to point gundeck to the new service name**
```diff
       redis:
-        host: redis-ephemeral
+        host: redis-ephemeral-master
```

If a gundeck crashes whilst deploying this release, it might not be able to
reconnect to redis until the release is fully rolled out. However this risk is
small.


### If you installed the `wire/redis-ephemeral` chart directly:

```
helm upgrade redis-ephemeral wire/redis-ephemeral -f <values>
helm upgrade wire-server wire/wire-server -f <values>
```

### If you installed the `wire/databases-ephemeral` chart:

```
helm upgrade databases-ephemeral wire/databases-ephemeral -f <values>
helm upgrade wire-server wire/wire-server -f  <values>
```

## Features

* The redis chart is now backed by https://github.com/bitnami/charts/tree/master/bitnami/redis (#380)
* Bump versions for webapp to latest production (#375, #386)
* Introduce helm chart for legalhold (#378)
* Add features endpoint to galley (#381)
* Add tracestate header to nginz logs (#376)
* Allow configuring customer extensions in brig (#279)
* Remove cookie domain configuration from brig (#239)

## Bug fixes

* Fix invalid ObjectMeta in nginx-ingress-services chart (#385)
* Fix fake-aws chart on Helm 3 (#379)

## Internal Changes

* New config parameters for federation (#384)
  NOTE: This is not used yet.
* Update to newer version of helm s3 plugin (#373)
* Pin image version in cassandra-migrations and demo-smtp charts (#374)
* Ansible: Allow custom log dir when pulling logs from an instance (#372)

# 2020-10-28

## Features

* ansible/requirements.yml: Bump SFT for new checksum format (#361)
* Create SFT servers in two groups (#356)
* Skip creating SFT monitoring certs if there are no SFT servers (#357)
* Delete the SFT SRV record after provsioning (#368)
* Update message stats dashboard (#208)

## Bug fixes / work-arounds

* add support for cargohold s3Compatibility option (#364)

## Documentation

* Comment on email visibility feature flag (#276)

## Internal

* Better nix support (#362, #358, #367, #369)
* ansible/Makefile: Print errors correctly when ENV is not in order (#359)
* Makefile target to get logs (#355)
* Makefile target to decrypt sops containers (#354)
* [tf-module:push-notifications] Allow to define multiple apps per client platform (#347)

# 2020-10-06

## Internal

* Ansible & Terraform for bootstrapping Kubernetes (#343)
* Ansible & Terraform SFT improvements (#344, #346, #348)

# 2020-09-28

## Features
* Documentation: Add galley feature flags and default AWS region to example values files (#328, #335)
* Privacy: Add logrotation of 3 days to all pod logs (#329)
* Security: Update TLS config: Drop CBC cipher suites (#323, #324)

## Bug Fixes
* fix sanitized_request parsing on nginx (#330)

## Internal
* Add automation for deploying SFT servers (#337, #341, #322)
* Add account number to output of terraform gundeck module (#326)
* remove issuance of a default search domain via the AWS dhcp servers. breaks dns lookup inside of k8s. (#338)
* [terraform-module:cargohold] Replace subnet IDs input with route table IDs (#331)
* [terraform-module] Introduce network load balancer (#299)

# 2020-07-29

## Features

* [tf-module:dns-records] Add output for FQDNs (#315)
* README.md: stop explicitly referring to the "develop" branch (#318)
* nginz redirect /teams/invitations/by-email to brig (#317)
* S3 support (#311, #316)
* Provide AWS_REGION variable to cargohold (#314)

# 2020-07-13

## Features

* Brig: Allow overriding optSettings.setRestrictUserCreation (#313)
* add a bash script for talking to s3 with AWS authentication V4. for testing s3 connection during installation. (#305)

# 2020-07-07

## Notes

This release contains a staging version of the webapp. So, you might want to be a bit more cautious or
even skip this one entirely.

## Features

None

## Bug Fixes

* [charts] Update frontend apps version: webapp (#308)
* removed unused replicaCount settings (#304)

## Internal Changes

* team-settings: Set default of `FEATURE_ENABLE_PAYMENT` to false (#294)
* [terraform modules] Add a module to create some DNS records (#298)


# 2020-06-26

## Features

* [charts] introduce cert-manager support in `nginx-ingress-services` to automate TLS certificate
  issuing. Please refer to the [docs](https://docs.wire.com/how-to/install/helm.html#how-to-direct-traffic-to-your-cluster)
  or the issue [#280](https://github.com/wireapp/wire-server-deploy/pull/280) for more details.

## Bug Fixes

* [charts] Update frontend apps version: webapp, team-settings, due to a broken team-settings version (#300)

## Internal Changes

* cleanup scripts used in automation (#295)
* ongoing work in several Terraform modules: ingress, CORS, cargohold

For more information, please refer to the [diff](https://github.com/wireapp/wire-server-deploy/compare/v2020-06-19...v2020-06-26)

# 2020-06-19

## Features

* Update all three frontends (webapp, team-settings, account-pages) to latest production release (#286)

## Bug Fixes

* Quote smsSender (#287)

## Internal Changes

* Add Github templates for Issues and PRs (#259, d5b16a99f0aa)

# 2020-06-03

## Features

- Add .elasticsearch.additionalWriteIndex to brig config (#277)
- Upgrade restund to include fix from wireapp/restund#3 (#278)

## Internal Changes

- TF modules: Ensure uniqueness of cargohold bucket name (#272)

# 2020-05-25

- Fix typo in default galley helm values: teamSearchVisibility (#271)
- Make field brig.config.aws.sesQueue to be required if being used (#268)

# 2020-05-15

## Upgrade Notes

Deployment steps:
1. Deploy new version of all services as usual, make sure `galley.config.settings.enableIndexedBillingTeamMembers` is `false`.
1. Make sure `galley-migrate-data` job completes.
1. Set `galley.config.settings.enableIndexedBillingTeamMembers` to `true` and re-deploy the same version.

## Features

- Add aws region in brig and galley in prod values example file (#229)
- Add job to migrate galley data post-install/upgrade (#263)
- Add customSearchVisibility for galley chart (#252)
- Add indexedBillingTeamMember feature flag for galley (#251)
- Add maxFanoutSize to galley's options (#231)
- Add missing galley route to nginz (#223)
- Move to helm 3 (#236)
- All to set HTTP proxy environment vars for brig, cargohold, galley, gundeck, proxy, spar (#217)
- Add possibility to specify proxy env vars in Ansible inventory (#249)
- Add example for declaration of turns servers (#235)
- Skip memorizing the IPs of redis nodes if there are not any. (#224)
- Add a commented out block for specifying a non-default elasticsearch apt mirror (#225)

## Bug Fixes

- Fix helm --wait for cassandra (#253)
- Fix node_labels declaration example in inventory (#226)
- Fix smtpCredentials to match EmailSMTPCredentials in brig Options.hs (#265)

## Internal Changes

- Deploy instances (#238)
- Remove unused table (#222)
- Add TF module for brig to provide prekey locking, an event queue and (optionally) email sending services (#244)
- Add module to enable mobile push notification for Gundeck (#241)
- Add module to set up object storage (S3) on AWS for Cargohold (#243)
- Add terraform configuration from the offline environment. (#230)
- Add module to initialize state sharing on AWS (#234)
- Add missing cassandra host value for elasticsearch-index chart (#227)
- Ensure that no provider is defined in any of the modules (#257)

# 2020-04-24

## Features

- Add missing galley route to nginz. (#223)
- Add maxFanoutSize to galley's options (#231)
- move to helm 3. (#236)
- terraform configuration from the offline environment. (#230)
- terraform module to initialize state sharing on AWS (#234)
- add a commented out block for specifying a non-default elasticsearch apt mirror. (#225)

## Bug fixes

- Fix commented out example value for HTTPS proxy environment variable
- All to set HTTP proxy environment vars for brig, cargohold, galley, gundeck, proxy, spar (#217)
- skip memorizing the IPs of redis nodes if there are not any. (#224)
- Add missing cassandra host value for elasticsearch-index chart (#227)
- Remove unused table (#222)

# 2020-04-15

## Release Notes

- This version adds a new migration to the elasticsearch index, it will go through all users in
  cassandra and (re-)create all users in elasticsearch. So, it could take a long time to finish
  depending on the number of users in the system.

## Features

- Use brig-index to create index in ES (#189)
- Allow docker registry to run with custom host and port (023eb5e)
- Verify proper NTP installation on Cassandra hosts (#199, c1acc03)
- Pin openjdk 8 (#211)
- Add brig index migrations (#212)
- Bump external role ansible-helm to support installing newer versions of Helm (c86c36f)
- Add ES, restund_network_interface and http_proxy settings to terraform inventory template (#216)
- Add important envVars for team-settings and account-pages in example values (#215)
- Add comment about configuring maxScimTokens setting (#214)
- Lock ES version in ES ansible (#219)
- Add comment about restund_network_interface in example hosts.ini (#219)
- Allow network interfaces being unset in inventory for nodes hosting backing services (#213)

## Bug fixes

- Fix incorrect bash used in docker-registry (cb73c38)

# 2020-03-25

## Features

- `calling-test` chart using the wire-nwtesttool (#204)

## Internal changes

- Move hardcoded AWS_REGION env var value into chart values file (#197) - thanks @kvaps
- Use apps/v1 for all deployments (#201)
- Fix elasticsearch-external endpoint (#198)
- Minor improvements to consistency with naming and settings.

# 2020-03-06

## Bug fixes

- fix an issue where rerunning `helm upgrade nginx-ingress-controller` (w/o any change) might fail as
  described in https://github.com/helm/charts/pull/20518 (#194)

# 2020-03-02

## Breaking changes / known issues when upgrading

- upgrading an existing Helm release of `wire-server` needs to be enforced (i.e. `--force`) or done by reinstalling it

## Features

- enable Helm v3 support
- Helm charts:
  - nginz: Expose internal sso settings and custom backends (#178, #191)
  - brig: New option setUserMaxPermClients is now available for brig (#185)
  - cannon: comply with K8s StatefulSetSpec (#187)

## Other updates

- Skip flaky test in brig-integration (#184)
- Ansible: fix mc policy set (#181) - thanks @kvaps
- Ansible: Fix setting heap size for ES (#188)


# 2020-01-09

## Features

 - Helm charts:
   - gundeck: set soft limit to active max concurrent push metrics (#165)
   - backoffice: add missing backoffice second pod to offline download (#166)
   - nginz: sanitize access tokens from logs (#169)
   - brig: branding defaults to simplify customization (#168)
   - brig: added new config options (#173)
   - aws-ingress: added team settings and account pages (#42)
   - team-settings: updated to latest app (#175)
   - webapp: updated to latest app (#175)
   - account-pages: updated to latest app (#175)

## Other updates
- Standardise docs to use example.com everywhere (#161, #172)
- Cleaned up and moved docs around to wire-docs (#157)

## Breaking changes / known issues when upgrading

- None known

## Bug fixes
- Minor mc usage fix for minio


# 2019-09-30 #162

## Features

 - Helm charts:
   - Support for multiple helm repos (#151)
   - Default to using DaemonSet and externalTrafficPolicy as Local for the ingress (#121)
   - JSON logging for brig and galley, parser for nginz, making it friendly for kibana (#142)

 - Ansible:
   - Support multiple bucket bucket creation when provisioning minio (#153)
   - Host static files on minio to allow clients to point to custom backends (#155)

## Other updates
- Update script takes a path now (#140)
- Super simple k8s bootstrap (#150)

## Breaking changes / known issues when upgrading

- If using a kubernetes cluster installed with kubespray version kubespray master from 2018-10-09, i.e. commit 2ab2f3a0a3aeffdd9862bb485495b0c1e77a1ed8, the new DaemonSet default configuration will not work. See https://github.com/kubernetes-sigs/kubespray/issues/4036 for a detailed explanation and workaround.

## Bug fixes
- Fixed policy setting on minio for public files (#158)

## Internal Changes
- Lower default resource requirements (#152)
