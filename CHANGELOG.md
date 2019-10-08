# 2019-09-30 #162

## What is new (helm charts)
- Support for multiple helm repos (#151)
- Default to using DaemonSet and externalTrafficPolicy as Local for the ingress (#121)
- JSON logging for brig and galley, parser for nginz, making it friendly for kibana (#142)

## What is new (ansible)
- Support multiple bucket bucket creation when provisioning minio (#153)
- Host static files on minio to allow clients to point to custom backends (#155)

## What else is new
- Update script takes a path now (#140)
- Super simple k8s bootstrap (#150)

## Bug fixes
- Fixed policy setting on minio for public files (#158)

## Internal Changes
- Lower default resource requirements (#152)
