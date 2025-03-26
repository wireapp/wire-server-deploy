self:
let helm-mapkubeapis = self.callPackage ./pkgs/helm-mapkubeapis.nix { };
in
super: {
  pythonForAnsible = (self.python3.withPackages (_: self.ansible.requiredPythonModules ++ [
    super.python3Packages.boto
    super.python3Packages.boto3
    super.python3Packages.cryptography
    super.python3Packages.six
    # for packet debugging and reporting.
    super.python3Packages.pyshark
    super.python3Packages.matplotlib
  ]));

  # kubeadm and kubectl
  kubernetes-tools = self.callPackage ./pkgs/kubernetes-tools.nix { };

  kubernetes-helm = super.wrapHelm super.kubernetes-helm {
    plugins = with super.kubernetes-helmPlugins; [ helm-s3 helm-secrets helm-diff helm-mapkubeapis ];
  };

  wire-binaries = self.callPackage ./pkgs/wire-binaries.nix { };

  generate-gpg1-key = super.runCommandNoCC "generate-gpg1-key"
    {
      nativeBuildInputs = [ super.makeWrapper ];
    }
    ''
      # This key isn't a secret (it's built and uploaded to the binary cache after all ;-) )
      # It's created out of the necessity that apt wants to verify against a
      # key
      # It's set to expire 2y after its creation,
      # or whenever this derivation is built again without having the result in the binary cache.
      # The public part of the key is shipped with the offline bundle
      # ($aptly_root/public/gpg).
      # The private key (Github secret) was last replaced on 2024-07-12 and is valid for two years.

      install -Dm755 ${./scripts/generate-gpg1-key.sh} $out/bin/generate-gpg1-key
      # we *--set* PATH here, to ensure we don't pick wrong gpgs
      wrapProgram $out/bin/generate-gpg1-key --set PATH '${super.lib.makeBinPath (with self; [ bash coreutils gnupg1orig ])}'
    '';
  mirror-apt-jammy = super.runCommandNoCC "mirror-apt-jammy"
    {
      nativeBuildInputs = [ super.makeWrapper ];
    }
    ''
      install -Dm755 ${./scripts/mirror-apt-jammy.sh} $out/bin/mirror-apt-jammy
      # we need to *--set* PATH here, otherwise aptly will pick the wrong gpg
      wrapProgram $out/bin/mirror-apt-jammy --set PATH '${super.lib.makeBinPath (with self; [ aptly bash coreutils curl gnupg1orig gnused gnutar ])}'
    '';

  create-container-dump = super.runCommandNoCC "create-container-dump"
    {
      nativeBuildInputs = [ super.makeWrapper ];
    }
    ''
      install -Dm755 ${./scripts/create-container-dump.sh} $out/bin/create-container-dump
        wrapProgram $out/bin/create-container-dump --prefix PATH : '${super.lib.makeBinPath [ self.skopeo self.create-build-entry ]}'
    '';


  list-helm-containers = super.runCommandNoCC "list-helm-containers"
    {
      nativeBuildInputs = [ super.makeWrapper ];
    }
    ''
      install -Dm755 ${./scripts/list-helm-containers.sh} $out/bin/list-helm-containers
      wrapProgram $out/bin/list-helm-containers --prefix PATH : '${super.lib.makeBinPath [ self.kubernetes-helm ]}'
    '';

  patch-ingress-controller-images = super.runCommandNoCC "patch-ingress-controller-images"
    {
      nativeBuildInputs = [ super.makeWrapper ];
    }
    ''
      install -Dm755 ${./scripts/patch-ingress-controller-images.sh} $out/bin/patch-ingress-controller-images
        wrapProgram $out/bin/patch-ingress-controller-images --prefix PATH : '${super.lib.makeBinPath [ self.containerd ]}'
    '';

  create-build-entry = super.runCommandNoCC "create-build-entry"
    {
      nativeBuildInputs = [ super.makeWrapper ];
    }
  ''
    install -Dm755 ${./scripts/create-build-entry.sh} $out/bin/create-build-entry
      wrapProgram $out/bin/create-build-entry --prefix PATH : '${super.lib.makeBinPath (with self; [ jq gnutar ])}'
  '';
}
