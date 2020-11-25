# SFTD Chart

## Deploy


Using your own certificates:

```
helm install sftd charts/std --set mediaAddress=10.0.0.1 --set host=example.com --set-file tls.crt=/path/to/tls.crt --set-file tls.key=/path/to/tls.key
```

Using Cert-manager:
```
helm install sftd charts/std --set mediaAddress=10.0.0.1 --set host=example.com --set tls.issuerRef.name=letsencrypt-staging
```

You can switch between `cert-manager` and own-provided certificates at any
time. Helm will delete the `sftd` secret automatically and then cert-manager
will create it instead.

