{ fetchurl
, lib
, runCommandNoCC
}:
let
  image_arch = "amd64";
  kube_version = "v1.18.10";
  etcd_version = "v3.4.3";
  cni_version = "v0.8.7";
  calico_version = "v3.15.2";
  cassandra_version = "3.11.4";
  jmx_prometheus_javaagent_version = "0.10";
  srcs = {
    kubelet = fetchurl rec {
      passthru.url = url;
      url = "https://storage.googleapis.com/kubernetes-release/release/${ kube_version }/bin/linux/${ image_arch }/kubelet";
      sha256 = "18c90pm54gw2mg3rqf19v3922jix0n78mjxnjc32qd4kk4rwvbld";
    };
    kubeadm = fetchurl rec {
      passthru.url = url;
      url = "https://storage.googleapis.com/kubernetes-release/release/${ kube_version }/bin/linux/${ image_arch }/kubeadm";
      sha256 = "13f1fz1ji4sxk2nim8hgvkl6q8xkgd8aq1fgdlnx855wfr96xx4v";
    };
    kubectl = fetchurl rec {
      passthru.url = url;
      url = "https://storage.googleapis.com/kubernetes-release/release/${ kube_version }/bin/linux/${ image_arch }/kubectl";
      sha256 = "0mhlpailnfq5c6i9ka2ws5z8grylrq5va4qcb7g6icbandf48p5j";
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
    cassandra = fetchurl rec {
      passthru.url = url;
      url = "http://archive.apache.org/dist/cassandra/${ cassandra_version }/apache-cassandra-${ cassandra_version }-bin.tar.gz";
      sha256 = "11wr0vcps8w8g2sd8qwp1yp8y873c4q32azc041xpi7zqciqwnax";
    };
    jmx_prometheus_javaagent = fetchurl rec {
      passthru.url = url;
      url = "https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${ jmx_prometheus_javaagent_version }/jmx_prometheus_javaagent-${ jmx_prometheus_javaagent_version }.jar";
      sha256 = "0abyydm2dg5g57alpvigymycflgq4b3drw4qs7c65vn95yiaai5i";
    };
  };
in
runCommandNoCC "wire-binaries"
{
  nativeBuildInputs = [ ];
} ''
  mkdir -p $out
  ${toString (lib.mapAttrsToList (k: v: "cp ${v} $out/${baseNameOf v.url}\n") srcs)}
''
