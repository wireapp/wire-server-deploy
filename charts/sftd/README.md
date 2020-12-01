# SFTD Chart

## Deploy


Using your own certificates:

```
helm install sftd charts/std --set host=example.com --set-file tls.crt=/path/to/tls.crt --set-file tls.key=/path/to/tls.key
```

Using Cert-manager:
```
helm install sftd charts/std --set host=example.com --set tls.issuerRef.name=letsencrypt-staging
```

You can switch between `cert-manager` and own-provided certificates at any
time. Helm will delete the `sftd` secret automatically and then cert-manager
will create it instead.


## DNS

An SRV record needs to be present for the domain name defined in `host`.
This is an artifact of the fact the wire backend currently uses public SRV
records for service discovery. The record needs to be of the form:

```
_sft._tcp.{{ .Values.host }}  {{ .Values.host }} 443
```
