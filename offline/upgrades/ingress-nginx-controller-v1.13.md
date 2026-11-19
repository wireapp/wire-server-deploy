# Upgrade ingress-nginx controller to v1.13.9 (wire-server 5.25)

Fixes known CVEs in the ingress-nginx controller image shipped with wire-server-deploy 5.25 (WPB-26631).

## Scope

| Component | Before | After |
|---|---|---|
| `ingress-nginx` subchart of `charts/ingress-nginx-controller` | `4.11.5` | `4.13.9` |
| Controller image (`registry.k8s.io/ingress-nginx/controller`) | `v1.10.6` (values) | `v1.13.9` |
| Admission webhook image (`registry.k8s.io/ingress-nginx/kube-webhook-certgen`) | `v20220916-gd32f8c343` | `v1.6.9` |
| `controller.config.annotations-risk-level` | not set (controller default) | `Critical` |

- No other chart or image changes. wire-server stays on 5.25.0.
- Supported Kubernetes versions: 1.29 – 1.33. The 5.25 bundle installs Kubernetes v1.29.10.
- Expected impact: rolling restart of the ingress controller pods. Ingress service, node ports and DNS do not change.

## Background

- Controller v1.12 changed the default of `annotations-risk-level` from `Critical` to `High`.
- `nginx-ingress-services` uses `*-snippet` annotations (risk `Critical`):
  - `nginx.ingress.kubernetes.io/server-snippet` (minio / fake S3 ingress)
  - `nginx.ingress.kubernetes.io/configuration-snippet` (nginz ingress, federator ingress)
- Without `annotations-risk-level: Critical`:
  - with admission webhook: `helm upgrade nginx-ingress-services` fails with `admission webhook "validate.nginx.ingress.kubernetes.io" denied the request: annotation group ServerSnippet contains risky annotation based on ingress configuration`.
  - without admission webhook: the controller ignores these ingresses and serves its fake default certificate.
- `annotations-risk-level` is a setting of the **ingress-nginx-controller** release (`ingress-nginx.controller.config`). Setting it on the `nginx-ingress-services` release (e.g. `--set controller.config.annotations-risk-level=...`) has no effect.

## Prerequisites

| Check | Command | Expected |
|---|---|---|
| Kubernetes version | `d kubectl version` | Server `v1.29.x` or later. Older: stop and contact Wire. |
| Release names and namespaces | `d helm list -A \| grep -E 'ingress-nginx-controller\|nginx-ingress-services'` | Both releases listed. Note `NAMESPACE` (below: `<NS>`, usually `default`). |
| Current revisions | `d helm history ingress-nginx-controller -n <NS>` and `d helm history nginx-ingress-services -n <NS>` | Note last `deployed` revision of each (for rollback). |
| Admin host workspace with current values | `ls <OLD_PACKAGE_DIR>/values/ingress-nginx-controller/values.yaml` | File exists |

## Warning

- Do **not** run `bin/offline-deploy.sh` or `bin/helm-operations.sh` on an existing installation.
- Both run a full fresh-install flow: existing `values.yaml` / `secrets.yaml` are moved to `*.bak.<timestamp>`, replaced with the `prod-*.example.yaml` files, and all charts are re-deployed with them.
- Use only the commands in this document.

## 1. Prepare the new bundle

```bash
wget https://s3-eu-west-1.amazonaws.com/public.wire.com/artifacts/wire-server-deploy-static-<HASH>.tgz
mkdir New-Wire-Server && cd New-Wire-Server
tar xvzf ../wire-server-deploy-static-<HASH>.tgz
source ./bin/offline-env.sh
```

- `<HASH>`: provided by Wire.
- Copy your inventory and values from the old workspace:

```bash
cp ../<OLD_PACKAGE_DIR>/ansible/inventory/offline/hosts.ini ansible/inventory/offline/hosts.ini
for chart in ingress-nginx-controller nginx-ingress-services; do
  cp ../<OLD_PACKAGE_DIR>/values/$chart/values.yaml values/$chart/values.yaml
done
cp ../<OLD_PACKAGE_DIR>/values/nginx-ingress-services/secrets.yaml values/nginx-ingress-services/secrets.yaml
```

## 2. Seed the new container images

```bash
d ansible-playbook -i ./ansible/inventory/offline/hosts.ini ansible/setup-offline-sources.yml
d ansible-playbook -i ./ansible/inventory/offline/hosts.ini ansible/seed-offline-containerd.yml
```

Verify on one Kubernetes node:

```bash
sudo crictl images | grep -E 'ingress-nginx/(controller|kube-webhook-certgen)'
```

Expected: `controller` tag `v1.13.9`, `kube-webhook-certgen` tag `v1.6.9`.

## 3. Update ingress-nginx-controller values

Edit `values/ingress-nginx-controller/values.yaml`. Required keys:

```yaml
ingress-nginx:
  controller:
    config:
      annotations-risk-level: Critical
    image:
      tag: "v1.13.9"
      digest: ""
      digestChroot: ""
    admissionWebhooks:
      patch:
        image:
          tag: "v1.6.9"
          digest: ""
```

- Keep all other existing keys (`kind`, `service`, `metrics`, ...).
- Remove any other `annotations-risk-level` setting (e.g. `Warning`).
- Reference: `values/ingress-nginx-controller/prod-values.example.yaml`.

Compare:

```bash
diff -u values/ingress-nginx-controller/prod-values.example.yaml values/ingress-nginx-controller/values.yaml
```

Expected: only your environment-specific differences.

## 4. Dry run

```bash
d helm template ingress-nginx-controller ./charts/ingress-nginx-controller -n <NS> \
  -f values/ingress-nginx-controller/values.yaml \
  | grep -E 'image: |annotations-risk-level|allow-snippet-annotations'
```

Expected:

```
  allow-snippet-annotations: "true"
  annotations-risk-level: "Critical"
          image: registry.k8s.io/ingress-nginx/controller:v1.13.9
          image: registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.6.9
          image: registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.6.9
```

## 5. Upgrade

Order: `ingress-nginx-controller` first, then `nginx-ingress-services`.

```bash
d helm upgrade --install ingress-nginx-controller ./charts/ingress-nginx-controller -n <NS> \
  -f values/ingress-nginx-controller/values.yaml --wait --timeout 15m

d helm upgrade --install nginx-ingress-services ./charts/nginx-ingress-services -n <NS> \
  -f values/nginx-ingress-services/values.yaml \
  -f values/nginx-ingress-services/secrets.yaml --wait --timeout 15m
```

- Do not pass `--set controller.config.*` to `nginx-ingress-services`.

## 6. Verify

```bash
SEL="app.kubernetes.io/instance=ingress-nginx-controller,app.kubernetes.io/component=controller"
```

| # | Check | Command | Expected |
|---|---|---|---|
| 1 | Pods ready | `d kubectl get pods -n <NS> -l "$SEL"` | All `Running`, `READY` 1/1 |
| 2 | Controller version | `d kubectl exec -n <NS> $(d kubectl get pod -n <NS> -l "$SEL" -o name \| head -1) -- /nginx-ingress-controller --version` | `Release: v1.13.9` |
| 3 | Risk level active | `d kubectl get cm -n <NS> ingress-nginx-controller-controller -o jsonpath='{.data.annotations-risk-level}'` | `Critical` |
| 4 | No rejected ingresses | `d kubectl logs -n <NS> -l "$SEL" --tail=-1 \| grep -Ei 'risky\|too risky\|cannot be used'` | No output |
| 5 | Ingresses | `d kubectl get ingress -n <NS>` | `ADDRESS` populated for all ingresses |
| 6 | API | `curl -s https://nginz-https.<DOMAIN>/api-version` | JSON with `supported` versions |
| 7 | TLS certificate | `openssl s_client -connect nginz-https.<DOMAIN>:443 -servername nginz-https.<DOMAIN> </dev/null 2>/dev/null \| openssl x509 -noout -subject -issuer` | Your certificate. **Not** `Kubernetes Ingress Controller Fake Certificate` |
| 8 | Assets (fake S3 / minio ingress) | Upload and download an image in a conversation | Works |
| 9 | Clients | Log in via webapp, team settings, mobile client | Works |

- Federation enabled: repeat check 7 for the federator host and verify federated search / messaging.

## 7. Rollback

```bash
d helm rollback nginx-ingress-services <REVISION> -n <NS> --wait --timeout 15m
d helm rollback ingress-nginx-controller <REVISION> -n <NS> --wait --timeout 15m
```

- `<REVISION>`: revisions noted in the prerequisites.
- Restores the previous chart and controller image. Re-run checks 1, 5, 6, 7.
