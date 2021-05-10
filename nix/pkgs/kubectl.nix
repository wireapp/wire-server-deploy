{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
  pname = "kubectl";
  version = "1.19.7";

  src = {
    x86_64-linux = fetchurl {
      url = "https://storage.googleapis.com/kubernetes-release/release/v${version}/bin/linux/amd64/kubectl";
      sha256 = "15vjydl91h0igvps2zcxj9bjyksb88ckavdwxmmmnpjpwaxv6vnl";
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
