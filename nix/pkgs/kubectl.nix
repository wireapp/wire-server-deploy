{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
  pname = "kubectl";
  version = "1.18.10";

  src = {
    x86_64-linux = fetchurl {
      url = "https://storage.googleapis.com/kubernetes-release/release/v${version}/bin/linux/amd64/kubectl";
      sha256 = "0mhlpailnfq5c6i9ka2ws5z8grylrq5va4qcb7g6icbandf48p5j";
    };
    x86_64-darwin = fetchurl {
      url = "https://storage.googleapis.com/kubernetes-release/release/v${version}/bin/darwin/amd64/kubectl";
      sha256 = "0nz6f44qh16di6249qwczvr1mpmhvzbi0kd1himxlhsp34qfr993";
    };
  }."${stdenv.targetPlatform.system}";


  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    cp $src kubectl
    install -Dm0755 kubectl -t $out/bin
  '';

  meta.platforms = [ "x86_64-linux" "x86_64-darwin" ];
}
