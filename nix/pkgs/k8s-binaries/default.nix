{ fetchurl
, lib
, runCommandNoCC
}:
let
  image_arch = "amd64";
  kube_version = "v1.18.9";
  etcd_version = "v3.4.3";
  cni_version = "v0.8.7";
  calico_version = "v3.15.2";
  srcs = {
    kubelet = fetchurl rec {
      passthru.url = url;
      url = "https://storage.googleapis.com/kubernetes-release/release/${ kube_version }/bin/linux/${ image_arch }/kubelet";
      sha256 = "02zjfcl4q36myw4sq79z7rlz2vlsinyyh40zhphf2f48irabca2h";
    };
    kubeadm = fetchurl rec {
      passthru.url = url;
      url = "https://storage.googleapis.com/kubernetes-release/release/${ kube_version }/bin/linux/${ image_arch }/kubeadm";
      sha256 = "0glnlvrnas87lsx782dqxwvmf555gdfzhhsk6idkzr1xzvh62zrz";
    };
    kubectl = fetchurl rec {
      passthru.url = url;
      url = "https://storage.googleapis.com/kubernetes-release/release/${ kube_version }/bin/linux/${ image_arch }/kubectl";
      sha256 = "1vg8qkvdkcwr1r53wbxk535iyb5sjdjdw01byp8b811x5mm7as3a";
    };
    calicoctl = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/projectcalico/calicoctl/releases/download/${ calico_version }/calicoctl-linux-${ image_arch }";
      sha256 = "1wgx95qmrvaczk5x7is8fp3rjpy67vhm5bd0xpd1bghwa1afk6i1";
    };
    etcd = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/coreos/etcd/releases/download/${ etcd_version }/etcd-${ etcd_version }-linux-${ image_arch }.tar.gz";
      sha256 = "01wgsr67z3nw4lry6pmi14r06fvdn806rzrxfncip54679r2nr3c";
    };
    cni = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/containernetworking/plugins/releases/download/${ cni_version }/cni-plugins-linux-${ image_arch }-${ cni_version }.tgz";
      sha256 = "1a6hmzky6dz8iczfi5xxwxrnh2hh82xcp8x6gaiwfrsn5n9j8y4p";
    };
  };
in
runCommandNoCC "k8s-binaries"
{
  nativeBuildInputs = [ ];
} ''
  mkdir -p $out
  ${toString (lib.mapAttrsToList (k: v: "cp ${v} $out/${baseNameOf v.url}\n") srcs)}
''
