{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
  pname = "kubectl";
  version = "1.23.7";

  src = {
    x86_64-linux = fetchurl {
      url = "https://storage.googleapis.com/kubernetes-release/release/v${version}/bin/linux/amd64/kubectl";
      sha256 = "b4c27ad52812ebf3164db927af1a01e503be3fb9dc5ffa058c9281d67c76f66e";
    };
    x86_64-darwin = fetchurl {
      url = "https://storage.googleapis.com/kubernetes-release/release/v${version}/bin/darwin/amd64/kubectl";
      sha256 = "1gpn6l8l5zznkrvydjv5km906adniid4wpsqy3qpdzlmgpscx1ir";
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
