{ fetchurl
, lib
, runCommandNoCC
}:
let
  image_arch = "amd64";

  # These values are manually kept in sync with:
  # https://github.com/kubernetes-sigs/kubespray/blob/release-2.19/roles/download/defaults/main.yml
  # TODO: Find a better process. Automate this!
  kube_version = "v1.26.5";
  etcd_version = "v3.5.6";
  cni_version = "v1.3.0";
  calico_version = "v3.25.1";
  crictl_version = "v1.26.0";
  runc_version = "v1.1.7";
  nerdctl_version = "1.4.0";
  containerd_version = "1.7.1";


  # Note: If you change a version, replace the checksum with zeros, run « nix-build --no-out-link -A pkgs.wire-binaries », it will complain and give you the right checksum, use that checksum in this file, run it again and it should build without complaining.
  cassandra_version = "3.11.4";
  jmx_prometheus_javaagent_version = "0.10";
  elasticsearch_version = "6.8.23";
  srcs = {
    kubelet = fetchurl rec {
      passthru.url = url;
      url = "https://storage.googleapis.com/kubernetes-release/release/${ kube_version }/bin/linux/${ image_arch }/kubelet";
      sha256 = "ad5e318ff0e81bc2bef874b2038489722cfcc117bd31726d0193056458c18bff";
    };
    kubeadm = fetchurl rec {
      passthru.url = url;
      url = "https://storage.googleapis.com/kubernetes-release/release/${ kube_version }/bin/linux/${ image_arch }/kubeadm";
      sha256 = "793767419c382bae2dc2c9396baafbf051bfa3214accf40dcd7c5ea405583802";
    };
    kubectl = fetchurl rec {
      passthru.url = url;
      url = "https://storage.googleapis.com/kubernetes-release/release/${ kube_version }/bin/linux/${ image_arch }/kubectl";
      sha256 = "5080bb2e9631fe095139f7e973df9a31eb73e668d1785ffeb524832aed8f87c3";
    };
    crictl = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/kubernetes-sigs/cri-tools/releases/download/${ crictl_version }/crictl-${ crictl_version }-linux-${ image_arch }.tar.gz";
      sha256 = "cda5e2143bf19f6b548110ffba0fe3565e03e8743fadd625fee3d62fc4134eed";
    };
    containerd = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/containerd/containerd/releases/download/v${ containerd_version }/containerd-${ containerd_version }-linux-${ image_arch }.tar.gz";
      sha256 = "9504771bcb816d3b27fab37a6cf76928ee5e95a31eb41510a7d10ae726e01e85";
    };
    runc = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/opencontainers/runc/releases/download/${ runc_version }/runc.${ image_arch }";
      sha256 = "c3aadb419e5872af49504b6de894055251d2e685fddddb981a79703e7f895cbd";
    };
    calico_crds = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/projectcalico/calico/archive/${ calico_version }.tar.gz";
      sha256 = "4d6b6653499f24f80a85a0a7dac28d9571cabfa25356b08f3b438fd97e322e2d";
    };
    nerdctl = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/containerd/nerdctl/releases/download/v${ nerdctl_version }/nerdctl-${ nerdctl_version }-linux-${ image_arch }.tar.gz";
      sha256 = "d8dcd4e270ae76ab294be3a451a2d8299010e69dce6ae559bc3193535610e4cc";
    };
    calicoctl = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/projectcalico/calico/releases/download/${ calico_version }/calicoctl-linux-${ image_arch }";
      sha256 = "13565e5304209ffaa93df3ba722e6f623b66c76057ca8ff5c5864fa13176fe48";
    };
    etcd = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/coreos/etcd/releases/download/${ etcd_version }/etcd-${ etcd_version }-linux-${ image_arch }.tar.gz";
      sha256 = "4db32e3bc06dd0999e2171f76a87c1cffed8369475ec7aa7abee9023635670fb";
    };
    cni = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/containernetworking/plugins/releases/download/${ cni_version }/cni-plugins-linux-${ image_arch }-${ cni_version }.tgz";
      sha256 = "754a71ed60a4bd08726c3af705a7d55ee3df03122b12e389fdba4bea35d7dd7e";
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
