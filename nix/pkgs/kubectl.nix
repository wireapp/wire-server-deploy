{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
  pname = "kubectl";
  version = "1.23.16";

  src = {
    aarch64-linux = fetchurl {
      url = "https://dl.k8s.io/v${version}/kubernetes-client-linux-arm64.tar.gz";
      hash = "sha256-wBNjAtDj7JnDxS6Xe4IQKTn8hqRHxk+N6J8pptvrKMU=";
    };
    aarch64-darwin = fetchurl {
      url = "https://dl.k8s.io/v${version}/kubernetes-client-darwin-arm64.tar.gz";
      hash = "sha256-cebSirs3vpNWrsmd1VDgnnpbTyPqj8subCXKu4J4vCM=";
    };
    x86_64-linux = fetchurl {
      url = "https://dl.k8s.io/v${version}/kubernetes-client-linux-amd64.tar.gz";
      hash = "sha256-ZEYy/M6VQejreCdAer7T7v2wg8e06mV9hiaH42LOfn4=";
    };
    x86_64-darwin = fetchurl {
      url = "https://dl.k8s.io/v${version}/kubernetes-client-darwin-amd64.tar.gz";
      hash = "sha256-vllW8C3wUP5J7e2PghB/ZqenMBTnuB6ZljNItwH9bcw=";
    };
  }."${stdenv.targetPlatform.system}";


  dontBuild = true;

  installPhase = ''
    cp client/bin/kubectl kubectl
    install -Dm0755 kubectl -t $out/bin
  '';

  meta.platforms = [ "aarch64-linux" "aarch64-darwin" "x86_64-linux" "x86_64-darwin" ];
}
