{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
  pname = "kubectl";
  version = "1.14.10";

  src = {
    x86_64-linux = fetchurl {
      url = "https://storage.googleapis.com/kubernetes-release/release/v${version}/bin/linux/amd64/kubectl";
      sha256 = "0dhbrqgnshd71swdnimg2b1nrc6rw0k9p9r6g7fblxpc5dhwcabp";
    };
    x86_64-darwin = fetchurl {
      url = "https://storage.googleapis.com/kubernetes-release/release/v${version}/bin/darwin/amd64/kubectl";
      sha256 = "0j6wixbvl173caiicnijmbnq73k6f28bkhkpmjk0kvxjmx7c5lj3";
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
