This helm chart is a helper to set up needed services, ingresses and (likely) secrets to access your cluster.
It will _NOT_ deploy an ingress controller! Ensure you already have one on your cluster - or have a look at our [nginx-ingress-controller](../nginx-ingress-controller/README.md)

If tls.enabled == true, then you need to supply 2 variables, `tlsWildcardCert` and `tlsWildcardKey` that could either be supplied as plain text in the form of a `-f path/to/secrets.yaml`, like this:

```
secrets:
  tlsWildcardCert: |
    -----BEGIN CERTIFICATE-----
    ... (Your Primary SSL certificate) ...
    -----END CERTIFICATE-----
    -----BEGIN CERTIFICATE-----
    ... (Your Intermediate certificate) ...
    -----END CERTIFICATE-----
  tlsWildcardKey: |
    -----BEGIN PRIVATE KEY-----
    ...
    -----END PRIVATE KEY-----
```

or encrypted with `sops` and then use `helm-wrapper`.

Have a look at the [values file](values.yaml) for different configuration options.

# Common issues

Q: My ingress keeps serving "Kubernetes Ingress Controller Fake Certificate"!!

A: Ensure that your certificate is _valid_ and has _not expired_; trying to serve expired certificates will silently fail and the nginx ingress will simply fallback to the default certificate.
