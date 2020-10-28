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
