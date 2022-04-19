# How to deploy the ldap-scim-bridge

copy your values and charts folders into the Wire-Server directory you're using.

pre-seed the docker container for ldap-scim-bridge onto all of your kubernetes hosts.

## get the Active Directory root authority's public certificate

ask the remote team to provide this.

## create a configmap for the Public Certificate

first, see if there's a configmap already in place.
```
d kubectl get configmaps
```

If not, create a configmap for this certificate.
```
d kubectl create configmap ca-ad-pemstore ad-public-root.crt
```

## Create a kubernetes patch

create a patch, which forces the ldap-scim-bridge to use the AD public certificate.
```
cat >> add_ad_ca.patch
```

place the following contents in the file:
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

Since the ldap-scim-bridge needs to be configured at least once per team, we must copy the values

edit the values. 
Set the schedule to "*/10 * * * *" for every 10 minutes.

### set the ldap source.

for AD:
```
ldapSource:
  tls: true
  host: "dc1.example.com"
  port: 636
  dn: "CN=Wire RO,CN=users,DC=com,DC=example"
  password: "SECRETPASSWORDHERE"
```

### Pick your users

select the user group you want to sync. for example, to find all of the people in the engineering department of the example.com AD domain:
```
search:
  base: ~DC=com,DC=example"
  objectClass: "person"
  memberOf "CN=WireTeam1,OU=engineering,DC=com,DC=example"
```

### pick the user mapping
An example mapping for AD is:
```
DisplayName: "displayName~
userNome: "mailNickname"
externalId: "mail"
email: "mail"
```

### Authorize the sync engine
add a `Bearer <secret>` token for ScimTarget's target attribute.


### Deploy the sync engine
```
d helm install ldap-scim-bridge-team-1 charts/ldap-scim-bridge/ --values values/ldap-scim-bridge_team-1/values.yaml
```

### Patch the sync engine.
```
d kubectl patch cronjob ldap-scim-bridge-team-1 -p "$(cat add_ad_ca.patch)"
```
