{ fetchurl
, lib
, runCommandNoCC
}:
let
  image_arch = "amd64";

  # These values are manually kept in sync with:
  # https://github.com/kubernetes-sigs/kubespray/blob/release-2.20/roles/download/defaults/main.yml
  # TODO: Find a better process. Automate this!
  kube_version = "v1.23.7";
  etcd_version = "v3.5.3";
  cni_version = "v1.1.1";
  calico_version = "v3.23.3";
  crictl_version = "v1.23.0";
  runc_version = "v1.1.4";
  nerdctl_version = "0.22.2";
  containerd_version = "1.6.8";


  # Note: If you change a version, replace the checksum with zeros, run « nix-build --no-out-link -A pkgs.wire-binaries », it will complain and give you the right checksum, use that checksum in this file, run it again and it should build without complaining.
  cassandra_version = "3.11.4";
  jmx_prometheus_javaagent_version = "0.10";
  elasticsearch_version = "6.8.23";
  srcs = {
    kubelet = fetchurl rec {
      passthru.url = url;
      url = "https://storage.googleapis.com/kubernetes-release/release/${ kube_version }/bin/linux/${ image_arch }/kubelet";
      sha256 = "518f67200e853253ed6424488d6148476144b6b796ec7c6160cff15769b3e12a";
    };
    kubeadm = fetchurl rec {
      passthru.url = url;
      url = "https://storage.googleapis.com/kubernetes-release/release/${ kube_version }/bin/linux/${ image_arch }/kubeadm";
      sha256 = "d7d863213eeb4791cdbd7c5fd398cf0cc2ef1547b3a74de8285786040f75efd2";
    };
    kubectl = fetchurl rec {
      passthru.url = url;
      url = "https://storage.googleapis.com/kubernetes-release/release/${ kube_version }/bin/linux/${ image_arch }/kubectl";
      sha256 = "b4c27ad52812ebf3164db927af1a01e503be3fb9dc5ffa058c9281d67c76f66e";
    };
    crictl = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/kubernetes-sigs/cri-tools/releases/download/${ crictl_version }/crictl-${ crictl_version }-linux-${ image_arch }.tar.gz";
      sha256 = "b754f83c80acdc75f93aba191ff269da6be45d0fc2d3f4079704e7d1424f1ca8";
    };
    containerd = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/containerd/containerd/releases/download/v${ containerd_version }/containerd-${ containerd_version }-linux-${ image_arch }.tar.gz";
      sha256 = "3a1322c18ee5ff4b9bd5af6b7b30c923a3eab8af1df05554f530ef8e2b24ac5e";
    };
    runc = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/opencontainers/runc/releases/download/${ runc_version }/runc.${ image_arch }";
      sha256 = "db772be63147a4e747b4fe286c7c16a2edc4a8458bd3092ea46aaee77750e8ce";
    };
    calico_crds = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/projectcalico/calico/archive/${ calico_version }.tar.gz";
      sha256 = "d25f5c9a3adeba63219f3c8425a8475ebfbca485376a78193ec1e4c74e7a6115";
    };
    nerdctl = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/containerd/nerdctl/releases/download/v${ nerdctl_version }/nerdctl-${ nerdctl_version }-linux-${ image_arch }.tar.gz";
      sha256 = "ad40ecf11c689fad594a05a40fef65adb4df8ecd1ffb6711e13cff5382aeaed9";
    };
    calicoctl = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/projectcalico/calico/releases/download/${ calico_version }/calicoctl-linux-${ image_arch }";
      sha256 = "d9c04ab15bad9d8037192abd2aa4733a01b0b64a461c7b788118a0d6747c1737";
    };
    etcd = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/coreos/etcd/releases/download/${ etcd_version }/etcd-${ etcd_version }-linux-${ image_arch }.tar.gz";
      sha256 = "e13e119ff9b28234561738cd261c2a031eb1c8688079dcf96d8035b3ad19ca58";
    };
    cni = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/containernetworking/plugins/releases/download/${ cni_version }/cni-plugins-linux-${ image_arch }-${ cni_version }.tgz";
      sha256 = "b275772da4026d2161bf8a8b41ed4786754c8a93ebfb6564006d5da7f23831e5";
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
    minio = fetchurl rec {
      passthru.url = url;
      url = "https://dl.min.io/server/minio/release/linux-amd64/archive/minio.RELEASE.2020-10-28T08-16-50Z";
      sha256 = "135bnbcjlzp5w3801q8883ii93qgamiz74b729mbmyxym5s6fzic";
    };
    mc = fetchurl rec {
      passthru.url = url;
      url = "https://dl.min.io/client/mc/release/linux-amd64/archive/mc.RELEASE.2020-10-03T02-54-56Z";
      sha256 = "0lfyl4l1fa8fsnjy892s940y7m3vjyihs3vvhccqlfic9syq9qar";
    };
    elasticsearch = fetchurl rec {
      passthru.url = url;
      url = "https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-oss-${elasticsearch_version}.deb";
      sha256 = "sha256:0s7m49rvg5n6mrjzg5snbg3092mq0n661qs9209phjzka1lqajvb";
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
