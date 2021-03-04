{ stdenv , fetchurl }:

stdenv.mkDerivation rec {
  pname = "rke";
  version = "1.2.6";

  src = {
    x86_64-linux = fetchurl {
      url = "https://github.com/rancher/rke/releases/download/v${version}/rke_linux-amd64";
      sha256 = "6d4a44931cf2fddbac742b24a4172ecf41ab199eee047cb8fa598e15e45fff8c";
    };
    x86_64-darwin = fetchurl {
      url = "https://github.com/rancher/rke/releases/download/v${version}/rke_darwin-amd64";
      sha256 = "3122cba5dbe999c4693a44583bdc8de53a8102dbca9703d045a1e2582691ee29";
    };
  }."${stdenv.targetPlatform.system}";

 
  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    install -Dm775 $src $out/bin/rke
  '';

  meta.platforms = [ "x86_64-linux" "x86_64-darwin" ];
}
