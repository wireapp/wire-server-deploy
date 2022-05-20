# How to deploy the ldap-scim-bridge

Note: the LDAP Scim bridge is in a separate package at the moment. the docker container is available from: 

https://temp-rhc-jun.s3.eu-west-1.amazonaws.com/ldap-scim-bridge%3A0.4.tar.bz2

the helm chart is in wire-server.

the values file is in wire-server-deploy.

When you get the package:

Copy your values and charts folders into the `Wire-Server` directory you're using.

Pre-seed the docker container for `ldap-scim-bridge` onto all of your kubernetes hosts.
```
sudo bash -c "cat ldap-scim-bridge-0.4.tar.bz2 | docker load"
```

## Get the Active Directory root authority's public certificate

Ask the remote team to provide this.

## Create a configmap for the Public Certificate

See if there's a configmap already in place.
```
d kubectl get configmaps
```

If not, create a configmap for this certificate.
```
d kubectl create configmap ca-ad-pemstore ad-public-root.crt
```

## Create a kubernetes patch

Create a patch, which forces the `ldap-scim-bridge` to use the AD public certificate.

```
cat >> add_ad_ca.patch
```

Place the following contents in the file:

```
spec:
  jobTemplate:
    spec:
      template:
        spec:
          containers:
           - name: ldap-scim-bridge
            VolumeMounts:
            - name: ca-ad-pemstore
              mountPath: /etc/ssl/certs/ad-public-root.crt
              subPath: ad-public-root.crt
              readOnly: true
          volumes:
          - name: ca-ad-pemstore
            configMap:
   	          name: ca-ad-pemstore
```

## Copy the values

Since the `ldap-scim-bridge` needs to be configured at least once per team, we must copy the values.

Edit the values. 

Set the schedule to `"*/10 * * * *"` for every 10 minutes.

### Set the ldap source.

For active Directory:

```
ldapSource:
  tls: true
  host: "dc1.example.com"
  port: 636
  dn: "CN=Wire RO,CN=users,DC=com,DC=example"
  password: "SECRETPASSWORDHERE"
```

### Pick your users

Select the user group you want to sync. for example, to find all of the people in the engineering department of the example.com AD domain:

```
search:
  base: ~DC=com,DC=example"
  objectClass: "person"
  memberOf "CN=WireTeam1,OU=engineering,DC=com,DC=example"
```

### Pick the user mapping

An example mapping for Active Directory is:
```
DisplayName: "displayName~
userNome: "mailNickname"
externalId: "mail"
email: "mail"
```

### Authorize the sync engine

Add a `Bearer <secret>` token for ScimTarget's target attribute.


### Deploy the sync engine
```
d helm install ldap-scim-bridge-team-1 charts/ldap-scim-bridge/ --values values/ldap-scim-bridge_team-1/values.yaml
```

### Patch the sync engine.
```
d kubectl patch cronjob ldap-scim-bridge-team-1 -p "$(cat add_ad_ca.patch)"
```
