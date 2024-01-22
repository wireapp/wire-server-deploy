{ buildGoModule, runtimeShell, fetchFromGitHub, makeWrapper, which, rsync, stdenv, fetchurl }:


buildGoModule rec {
  pname = "kubernetes";
  version = "1.28.2";

  src = fetchFromGitHub {
    owner = "kubernetes";
    repo = "kubernetes";
    rev = "v${version}";
    hash = "sha256-dLbKzPBMN8w+BA3lQUq6uYr+QoXGMm6SKaWGbYBTH0A=";
  };

  vendorSha256 = null;

  doCheck = false;

  nativeBuildInputs = [ makeWrapper which rsync ];

  outputs = [ "out" ];

  buildPhase = ''
    runHook preBuild
    substituteInPlace "hack/update-generated-docs.sh" --replace "make" "make SHELL=${runtimeShell}"
    patchShebangs ./hack ./cluster/addons/addon-manager
    make "SHELL=${runtimeShell}" "WHAT=cmd/kubeadm cmd/kubectl"
    ./hack/update-generated-docs.sh
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    for p in cmd/kubeadm cmd/kubectl; do
      install -D _output/local/go/bin/''${p##*/} -t $out/bin
    done

    runHook postInstall
  '';
}
