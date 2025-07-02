# SMTP service

## DNS

Generate your public/private key pair:

```
openssl genrsa -out dkim.private
openssl rsa -in dkim.private -out dkim.public -pubout -outform PEM
```

Then, with the contents of the public key, create a DNS record for DKIM:

```
dkim._domainkey 10800 IN TXT "v=DKIM1; k=rsa; p="your public key here, you will have to split it into multiple string chunks or DNS will fail to validate"
```
SPF:
```
@ 1350 IN TXT "v=spf1 a mx ip4:smtp.public.ip.address -all"
```
DMARC:
```
_dmarc 10800 IN TXT "v=DMARC1; p=quarantine; rua=mailto:mailbox-to-your-dmarc; ruf=mailto:mailbox-to-your-dmarc; fo=1; pct=100; sp=none;"
```

For DMARC, a dedicated mailbox should be used.

## Deploying demo-smtp

Create a generic secret from the private key:

```
d kubectl create secret generic dkim-private-key --from-file=dkim.private
```

Then, create a copy of default `demo-smtp` values:

```
cp values/demo-smtp/prod-values.example.yaml values/demo-smtp/values.yaml
```

Open it, and edit:

```
MAILNAME: "your-domain-here"
DKIM_DOMAIN: "your-domain-here"
DKIM_PRIVATE_KEY: "/etc/exim4/dkim.key"
DKIM_KEY_PATH: "/secrets/dkim.key"

add the following sections

extraVolumes:
  - name: dkim-key
    secret:
      secretName: dkim-private-key

extraVolumeMounts:
  - name: dkim-key
    mountPath: /secrets/dkim.key
    subPath: dkim.private
    readOnly: true
```

### WIP (to-be-removed)
Current charts do not support mounting extra volumes, some hacking required before a fork of current charts has been made.

Replace `charts/demo-smtp/templates/deployment.yaml` with:
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ template "demo-smtp.fullname" . }}
  labels:
    app: {{ template "demo-smtp.name" . }}
    chart: {{ template "demo-smtp.chart" . }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ template "demo-smtp.name" . }}
      release: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app: {{ template "demo-smtp.name" . }}
        release: {{ .Release.Name }}
    spec:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: "kubernetes.io/hostname"
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app: {{ template "demo-smtp.name" . }}
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image }}"
          env:
        {{- range $key, $val := .Values.envVars }}
            - name: {{ $key }}
              value: {{ $val | quote }}
        {{- end }}
          ports:
            - name: smtp
              containerPort: 25
              protocol: TCP
          resources:
{{ toYaml .Values.resources | indent 12 }}
          {{- if .Values.extraVolumeMounts }}
          volumeMounts:
          {{- toYaml .Values.extraVolumeMounts | nindent 10 }}
          {{- end }}
      {{- if .Values.extraVolumes }}
      volumes:
      {{- toYaml .Values.extraVolumes | nindent 6 }}
      {{- end }}
```

Special use-case for Cloud Temple.
Replace `charts/demo-smtp/templates/service.yaml` with:

```
apiVersion: v1
kind: Service
metadata:
  name: {{ template "demo-smtp.fullname" . }}
  labels:
    app: {{ template "demo-smtp.name" . }}
    chart: {{ template "demo-smtp.chart" . }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
spec:
  type: LoadBalancer
  loadBalancerIP: <STATIC_IP>  # replace this with the static IP
  ports:
    - port: {{ .Values.service.port }}
      targetPort: smtp
      protocol: TCP
      name: smtp
  selector:
    app: {{ template "demo-smtp.name" . }}
    release: {{ .Release.Name }}
```

Deploy `demo-smtp`:

```
d helm upgrade --install demo-smtp charts/demo-smtp -f values/demo-smtp/values.yaml
```