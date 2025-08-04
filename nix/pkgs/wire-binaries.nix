{ fetchurl
, lib
, runCommandNoCC
}:
let
  image_arch = "amd64";

  # These values are manually kept in sync with:
  # https://github.com/kubernetes-sigs/kubespray/blob/release-2.25/roles/kubespray-defaults/defaults/main/download.yml
  # TODO: Find a better process. Automate this!
  kube_version = "v1.29.10";
  etcd_version = "v3.5.16";
  cni_version = "v1.3.0";
  calico_version = "v3.27.4";
  crictl_version = "v1.29.0";
  runc_version = "v1.1.14";
  nerdctl_version = "1.7.7";
  containerd_version = "1.7.22";
  minio_version = "RELEASE.2023-07-07T07-13-57Z";
  mc_version = "RELEASE.2023-10-24T05-18-28Z";


  # Note: If you change a version, replace the checksum with zeros, run « nix-build --no-out-link -A pkgs.wire-binaries », it will complain and give you the right checksum, use that checksum in this file, run it again and it should build without complaining.
  cassandra_version = "3.11.16";
  jmx_prometheus_javaagent_version = "0.10";
  elasticsearch_version = "6.8.23";
  srcs = {
    kubelet = fetchurl rec {
      passthru.url = url;
      url = "https://dl.k8s.io/release/${kube_version}/bin/linux/${image_arch}/kubelet";
      sha256 = "sha256-TMCUBizRz/ScpVEghjVmmrhuOYLTjo0Kd6uDOpQf9wg=";
    };
    kubeadm = fetchurl rec {
      passthru.url = url;
      url = "https://dl.k8s.io/release/${kube_version}/bin/linux/${image_arch}/kubeadm";
      sha256 = "sha256-kJjJCODzpgHovvmyzbSpd34YIEWVplQr5Ys5KMe1FEA=";
    };
    kubectl = fetchurl rec {
      passthru.url = url;
      url = "https://dl.k8s.io/release/${kube_version}/bin/linux/${image_arch}/kubectl";
      sha256 = "sha256-JPLwmmNdNrLONurr8ZEybislCX7sVBo+R/7mcm7wbO8=";
    };
    crictl = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/kubernetes-sigs/cri-tools/releases/download/${ crictl_version }/crictl-${ crictl_version }-linux-${ image_arch }.tar.gz";
      sha256 = "d16a1ffb3938f5a19d5c8f45d363bd091ef89c0bc4d44ad16b933eede32fdcbb";
    };
    containerd = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/containerd/containerd/releases/download/v${ containerd_version }/containerd-${ containerd_version }-linux-${ image_arch }.tar.gz";
      sha256 = "f8b2d935d1f86003f4e0c1af3b9f0d2820bacabe6dc9f562785b74af24c5e468";
    };
    runc = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/opencontainers/runc/releases/download/${ runc_version }/runc.${ image_arch }";
      sha256 = "a83c0804ebc16826829e7925626c4793da89a9b225bbcc468f2b338ea9f8e8a8";
    };
    calico_crds = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/projectcalico/calico/archive/${ calico_version }.tar.gz";
      sha256 = "5f6ac510bd6bd8c14542afe91f7dbcf2a846dba02ae3152a3b07a1bfdea96078";
    };
    nerdctl = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/containerd/nerdctl/releases/download/v${ nerdctl_version }/nerdctl-${ nerdctl_version }-linux-${ image_arch }.tar.gz";
      sha256 = "298bb95aee485b24d566115ef7e4e90951dd232447b05de5646a652a23db70a9";
    };
    calicoctl = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/projectcalico/calico/releases/download/${ calico_version }/calicoctl-linux-${ image_arch }";
      sha256 = "84f2bd29ef7b06e85a2caf0b6c6e0d3da5ab5264d46b360e6baaf49bbc3b957d";
    };
    etcd = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/coreos/etcd/releases/download/${ etcd_version }/etcd-${ etcd_version }-linux-${ image_arch }.tar.gz";
      sha256 = "b414b27a5ad05f7cb01395c447c85d3227e3fb1c176e51757a283b817f645ccc";
    };
    cni = fetchurl rec {
      passthru.url = url;
      url = "https://github.com/containernetworking/plugins/releases/download/${ cni_version }/cni-plugins-linux-${ image_arch }-${ cni_version }.tgz";
      sha256 = "754a71ed60a4bd08726c3af705a7d55ee3df03122b12e389fdba4bea35d7dd7e";
    };
    cassandra = fetchurl rec {
      passthru.url = url;
      url = "http://archive.apache.org/dist/cassandra/${ cassandra_version }/apache-cassandra-${ cassandra_version }-bin.tar.gz";
      sha256 = "sha256-zQHG0SNFMWoflAEzJj7qnShMeiC370XCbxoitbR1/Ag=";
    };
    jmx_prometheus_javaagent = fetchurl rec {
      passthru.url = url;
      url = "https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${ jmx_prometheus_javaagent_version }/jmx_prometheus_javaagent-${ jmx_prometheus_javaagent_version }.jar";
      sha256 = "0abyydm2dg5g57alpvigymycflgq4b3drw4qs7c65vn95yiaai5i";
    };
    minio = fetchurl rec {
      passthru.url = url;
      url = "https://dl.min.io/server/minio/release/linux-amd64/archive/minio.${ minio_version }";
      sha256 = "sha256-9tGq30uuwVVogOZZdI1/vGvI0trDVU+BbpVJLTiBZgo=";
    };
    mc = fetchurl rec {
      passthru.url = url;
      url = "https://dl.min.io/client/mc/release/linux-amd64/archive/mc.${ mc_version }";
      sha256 = "sha256-XxKSa2RrUzzeoaVIxURgpNrXjye4sX05m6Av9O42jk0=";
    };
    elasticsearch = fetchurl rec {
      passthru.url = url;
      url = "https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-oss-${elasticsearch_version}.deb";
      sha256 = "sha256:0s7m49rvg5n6mrjzg5snbg3092mq0n661qs9209phjzka1lqajvb";
    };
    # when updating the packages, update the checksums too in wire-server-deploy/ansible/inventory/offline/group_vars/all/offline.yml
    postgresql = fetchurl rec {
      passthru.url = url;
      url = "https://apt.postgresql.org/pub/repos/apt/pool/main/p/postgresql-17/postgresql-17_17.5-1.pgdg22.04+1_amd64.deb";
      sha256 = "sha256:0ba8064cee5800f290485c3974081b399736feca050ad6ae06dd26d2c26cf167";
    };
    postgresql-client = fetchurl rec {
      passthru.url = url;
      url = "https://apt.postgresql.org/pub/repos/apt/pool/main/p/postgresql-17/postgresql-client-17_17.5-1.pgdg22.04+1_amd64.deb";
      sha256 = "sha256:1b3e96f9f488f234734266a7a212c7c3ac189ba763939a313906e3f2fe5492bb";
    };
    libpq5 = fetchurl rec {
      passthru.url = url;
      url = "https://apt.postgresql.org/pub/repos/apt/pool/main/p/postgresql-17/libpq5_17.5-1.pgdg22.04+1_amd64.deb";
      sha256 = "sha256:97cec98aa147de384066a027693e5a0864009e2209d170f891cb0d7583735936";
    };
    postgresql-client-common = fetchurl rec {
      passthru.url = url;
      url = "https://apt.postgresql.org/pub/repos/apt/pool/main/p/postgresql-common/postgresql-client-common_281.pgdg22.04+1_all.deb";
      sha256 = "sha256:c5ee58fea51a19753ac0496d06538c6a194705b11aef27683047e9c4ebff2c5e";
    };
    postgresql-common = fetchurl rec {
      passthru.url = url;
      url = "https://apt.postgresql.org/pub/repos/apt/pool/main/p/postgresql-common/postgresql-common_281.pgdg22.04+1_all.deb";
      sha256 = "sha256:317308f1eaeb8c3f93fdc3eaa5430290e5bce62b4bba3f78045ff339d6a8e7a1";
    };
    postgresql-common-dev = fetchurl rec {
      passthru.url = url;
      url = "https://apt.postgresql.org/pub/repos/apt/pool/main/p/postgresql-common/postgresql-common-dev_281.pgdg22.04+1_all.deb";
      sha256 = "sha256:aa116b0861d149dcba5cbf0cb6af611d9d59bd83178ee9c66c60363ce6cf77d0";
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
