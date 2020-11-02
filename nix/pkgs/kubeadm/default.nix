{ wire-binaries, runCommandNoCC }:
runCommandNoCC "kubeadm" { } "install -Dm0775 ${wire-binaries}/kubeadm $out/bin/kubeadm"
