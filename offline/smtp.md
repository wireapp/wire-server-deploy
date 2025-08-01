# SMTP Service

## DNS Setup

Generate a DKIM public/private key pair for email signing:

```bash
openssl genrsa -out dkim.private 2048
openssl rsa -in dkim.private -pubout -out dkim.public.pem
```

### DKIM DNS Record

Create a TXT DNS record for DKIM with the public key:

```
dkim._domainkey 10800 IN TXT "v=DKIM1; k=rsa; p=<your public key here>"
```
> **Note:** The public key must be split into multiple quoted strings if it's too long, because DNS TXT records have length limits. For example:

```
"v=DKIM1; k=rsa; p=MIIBIjANBgkqh..." "AQEFAAOCAQ8A..."
```

### SPF Record

Add an SPF record to authorize your SMTP server IP to send e-mails for your domain:

```
@ 1350 IN TXT "v=spf1 a mx ip4:<smtp.public.ip.address> -all"
```

### DMARC Record

Configure DMARC to specify policy and reporting addresses:

```
_dmarc 10800 IN TXT "v=DMARC1; p=quarantine; rua=mailto:<dmarc-report@your-domain>; ruf=mailto:<dmarc-report@your-domain>; fo=1; pct=100; sp=none;"
```
> Use a dedicated mailbox to receive DMARC reports.

---

## Deploying SMTP Service in Kubernetes

### Create DKIM Secret

Create a Kubernetes secret containing your DKIM private key:

```bash
kubectl create secret generic dkim-private-key --from-file=dkim.private
```

### Prepare Values File

Copy the example values file:

```bash
cp values/smtp/prod-values.example.yaml values/smtp/values.yaml
```

Edit `values.yaml`:

```yaml
MAILNAME: "your-domain-here"
DKIM_DOMAIN: "your-domain-here"
DKIM_PRIVATE_KEY: "/etc/exim4/dkim.key"
DKIM_KEY_PATH: "/secrets/dkim.key"
```

Uncomment and update the `extraVolumes` and `extraVolumeMounts` sections to mount the `dkim-private-key` secret at the correct path inside the pod.

### Deploy with Helm

Deploy SMTP chart:

```bash
helm upgrade --install smtp charts/smtp -f values/smtp/values.yaml
```
---

## Deploying SMTP for External Access

If you want your SMTP service to be accessible from outside the cluster (e.g., another Kubernetes cluster relaying mail), change the service type in `values/smtp/values.yaml` to NodePort:

```yaml
service:
  type: NodePort
```

Add to the corresponding service template (`charts/smtp/templates/service.yaml`) to expose the NodePort:

```yaml
spec:
  type: NodePort
  ports:
    - port: {{ .Values.service.port }}
      targetPort: smtp
      protocol: TCP
      name: smtp
      nodePort: 30025 # add nodePort
```

> Ensure the `nodePort` is in the range 30000-32767.

Redeploy with:

```bash
helm upgrade --install smtp charts/smtp -f values/smtp/values.yaml
```
---

### Additional Notes

- Use internal/private IP addresses if both clusters are in the same secure network to avoid public exposure.
- If using a public IP, ensure firewall rules allow SMTP traffic on port 25.
- Update secrets if keys change, and redeploy pods to reload them.
- Monitor logs for connection issues or DNS problems.
