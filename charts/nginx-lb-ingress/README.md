# Notes

If tls.enabled == true, then you need to supply 2 variables, `tlsWildcardCert` and `tlsWildcardKey` that could either be supplied as plain text in the form of a `-f path/to/secrets.yaml`, like this:

```
secrets:
  tlsWildcardCert: |
    -----BEGIN CERTIFICATE-----
    ....
    -----END CERTIFICATE-----
    -----BEGIN CERTIFICATE-----
    ...
    -----END CERTIFICATE-----
  tlsWildcardKey: |
    -----BEGIN PRIVATE KEY-----
    ...
    -----END PRIVATE KEY-----
```

or encrypted with `sops` and then use `helm-wrapper`.

Have a look at the [values file](values.yaml) for different configuration options.
