{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
  pname = "kubectl";
  version = "1.26.5";

  src = {
    x86_64-linux = fetchurl {
      url = "https://storage.googleapis.com/kubernetes-release/release/v${version}/bin/linux/amd64/kubectl";
      sha256 = "5080bb2e9631fe095139f7e973df9a31eb73e668d1785ffeb524832aed8f87c3";
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
