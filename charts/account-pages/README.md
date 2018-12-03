Account pages are part of a private repo. This chart expects a secret named `wire-accountpages-readonly-pull-secret` to be made available with

kubectl create -f wire-accountpages-readonly-secret.yml --namespace=<namespace>
