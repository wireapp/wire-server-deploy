{ fetchurl
, lib
, runCommandNoCC
}:
let
  image_arch = "amd64";

  # These values are manually kept in sync with:
  # https://github.com/kubernetes-sigs/kubespray/blob/release-2.20/roles/download/defaults/main.yml
  # TODO: Find a better process. Automate this!
  kube_version = "v1.28.2";
  etcd_version = "v3.5.9";
  cni_version = "v1.3.0";
  calico_version = "v3.26.4";
  crictl_version = "v1.28.0";
  runc_version = "v1.1.10";
  nerdctl_version = "1.7.1";
  containerd_version = "1.7.11";


  # Note: If you change a version, replace the checksum with zeros, run « nix-build --no-out-link -A pkgs.wire-binaries », it will complain and give you the right checksum, use that checksum in this file, run it again and it should build without complaining.
  cassandra_version = "3.11.4";
  jmx_prometheus_javaagent_version = "0.10";
  elasticsearch_version = "6.8.23";
  srcs = {
    kubelet = fetchurl rec {
      passthru.url = url;
      url = "https://storage.googleapis.com/kubernetes-release/release/${ kube_version }/bin/linux/${ image_arch }/kubelet";
      sha256 = "17edb866636f14eceaad58c56eab12af7ab3be3c78400aff9680635d927f1185";
    };
    kubeadm = fetchurl rec {
      passthru.url = url;
      url = "https://storage.googleapis.com/kubernetes-release/release/${ kube_version }/bin/linux/${ image_arch }/kubeadm";
      sha256 = "6a4808230661c69431143db2e200ea2d021c7f1b1085e6353583075471310d00";
    };
    kubectl = fetchurl rec {
      passthru.url = url;
      url = "https://storage.googleapis.com/kubernetes-release/release/${ kube_version }/bin/linux/${ image_arch }/kubectl";
      sha256 = "c922440b043e5de1afa3c1382f8c663a25f055978cbc6e8423493ec157579ec5";
    };
    crictl = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/kubernetes-sigs/cri-tools/releases/download/${ crictl_version }/crictl-${ crictl_version }-linux-${ image_arch }.tar.gz";
      sha256 = "8dc78774f7cbeaf787994d386eec663f0a3cf24de1ea4893598096cb39ef2508";
    };
    containerd = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/containerd/containerd/releases/download/v${ containerd_version }/containerd-${ containerd_version }-linux-${ image_arch }.tar.gz";
      sha256 = "d66161d54546fad502fd50a13fcb79efff033fcd895adc9c44762680dcde4e69";
    };
    runc = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/opencontainers/runc/releases/download/${ runc_version }/runc.${ image_arch }";
      sha256 = "81f73a59be3d122ab484d7dfe9ddc81030f595cc59968f61c113a9a38a2c113a";
    };
    calico_crds = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/projectcalico/calico/archive/${ calico_version }.tar.gz";
      sha256 = "481e52de684c049f3f7f7bac78f0f6f4ae424d643451adc9e3d3fa9d03fb6d57";
    };
    nerdctl = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/containerd/nerdctl/releases/download/v${ nerdctl_version }/nerdctl-${ nerdctl_version }-linux-${ image_arch }.tar.gz";
      sha256 = "5fc0a6e8c3a71cbba95fbdb6833fb8a7cd8e78f53de10988362d4029c14b905a";
    };
    calicoctl = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/projectcalico/calico/releases/download/${ calico_version }/calicoctl-linux-${ image_arch }";
      sha256 = "9960357ef6d61eda7abf80bd397544c1952f89d61e5eaf9f6540dae379a3ef61";
    };
    etcd = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/coreos/etcd/releases/download/${ etcd_version }/etcd-${ etcd_version }-linux-${ image_arch }.tar.gz";
      sha256 = "d59017044eb776597eca480432081c5bb26f318ad292967029af1f62b588b042";
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
      url = "https://dl.min.io/server/minio/release/linux-amd64/archive/minio.RELEASE.2023-07-07T07-13-57Z";
      sha256 = "sha256-9tGq30uuwVVogOZZdI1/vGvI0trDVU+BbpVJLTiBZgo=";
    };
    mc = fetchurl rec {
      passthru.url = url;
      url = "https://dl.min.io/client/mc/release/linux-amd64/archive/mc.RELEASE.2023-07-07T05-25-51Z";
      sha256 = "sha256-IFotxaSdxGf3gijEPH02jjdsbMFEkll6fE/hlcKR8HQ=";
    };
    elasticsearch = fetchurl rec {
      passthru.url = url;
      url = "https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-oss-${elasticsearch_version}.deb";
      sha256 = "sha256:0s7m49rvg5n6mrjzg5snbg3092mq0n661qs9209phjzka1lqajvb";
    };
    jmespath = fetchurl rec {
      passthru.url = url;
      url = "http://ftp.de.debian.org/debian/pool/main/p/python-jmespath/python3-jmespath_1.0.1-1_all.deb";
      sha256 = "2b4351db7f00a8e4840140572b337a5005f897eaf6c7d9c929991e85a152d388";
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
