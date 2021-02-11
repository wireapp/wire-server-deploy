{ fetchurl
, lib
, runCommandNoCC
}:
let
  image_arch = "amd64";

  # These values are manually kept in sync with:
  # https://github.com/kubernetes-sigs/kubespray/blob/release-2.15/roles/download/defaults/main.yml
  # TODO: Find a better process. Automate this!
  kube_version = "v1.19.7";
  etcd_version = "v3.4.13";
  cni_version = "v0.9.0";
  calico_version = "v3.16.5";


  cassandra_version = "3.11.4";
  jmx_prometheus_javaagent_version = "0.10";
  elasticsearch_version = "6.6.0";
  srcs = {
    kubelet = fetchurl rec {
      passthru.url = url;
      url = "https://storage.googleapis.com/kubernetes-release/release/${ kube_version }/bin/linux/${ image_arch }/kubelet";
      sha256 = "0m3cj0b5070vijv8zj46paxhl89j9mhdcg5phxra3mvdby19dcnq";
    };
    kubeadm = fetchurl rec {
      passthru.url = url;
      url = "https://storage.googleapis.com/kubernetes-release/release/${ kube_version }/bin/linux/${ image_arch }/kubeadm";
      sha256 = "096vj9cx84mpmd09sghp3ky4bkqd6agsnb25qy47ik9k4n2g2gn6";
    };
    kubectl = fetchurl rec {
      passthru.url = url;
      url = "https://storage.googleapis.com/kubernetes-release/release/${ kube_version }/bin/linux/${ image_arch }/kubectl";
      sha256 = "15vjydl91h0igvps2zcxj9bjyksb88ckavdwxmmmnpjpwaxv6vnl";
    };
    calicoctl = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/projectcalico/calicoctl/releases/download/${ calico_version }/calicoctl-linux-${ image_arch }";
      sha256 = "1rra3nr578f6zyh7xcfmdifk1557w1584gdya89rmxhcmmcma5yl";
    };
    etcd = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/coreos/etcd/releases/download/${ etcd_version }/etcd-${ etcd_version }-linux-${ image_arch }.tar.gz";
      sha256 = "01zibyxi08jwan7jxhybazsf4j8g4cph6c3vvfn2sxdbggj2kh1a";
    };
    cni = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/containernetworking/plugins/releases/download/${ cni_version }/cni-plugins-linux-${ image_arch }-${ cni_version }.tgz";
      sha256 = "097cv5aysbhma2dzn2vd2f279fy0hvqk1wrypndrzflmk0w8v9aq";
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
      sha256 = "02cz845cfpjg381lafjfc95ka1ra9h2wn4565aa1asj91by6i0j3";
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
