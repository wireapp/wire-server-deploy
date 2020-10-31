{ k8s-binaries, runCommandNoCC }:
runCommandNoCC "kubeadm" { } "install -Dm0775 ${k8s-binaries}/kubeadm $out/bin/kubeadm"
