self:
let helm-mapkubeapis = self.callPackage ./pkgs/helm-mapkubeapis.nix { };
  sources = import ./sources.nix;
  # for injecting old gnupg dependancy
  oldpkgs = import sources.oldpkgs {
    config = { };
  };
in
super: {

  # due to ansible package from nixpkgs missing some dependancies to run kubespray playbook
  # we are making our own custom ansible package and python interpreter, current ansible-core is 2.16.5
  customAnsible = oldpkgs.python3.withPackages (_:
    oldpkgs.ansible.requiredPythonModules ++ [
      oldpkgs.python3Packages.ansible-core

      oldpkgs.python3Packages.jmespath
      oldpkgs.python3Packages.botocore
      oldpkgs.python3Packages.boto3
      oldpkgs.python3Packages.cryptography
      oldpkgs.python3Packages.six
      oldpkgs.python3Packages.pyshark
      oldpkgs.python3Packages.matplotlib
    ]);

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
      # The private key (Github secret) was last replaced on 2026-07-15 and is valid for two years.

      install -Dm755 ${./scripts/generate-gpg1-key.sh} $out/bin/generate-gpg1-key
      # we *--set* PATH here, to ensure we don't pick wrong gpgs
      wrapProgram $out/bin/generate-gpg1-key --set PATH '${super.lib.makeBinPath (with self; [ bash coreutils ])}'
    '';
  mirror-apt-jammy = super.runCommandNoCC "mirror-apt-jammy"
    {
      nativeBuildInputs = [ super.makeWrapper ];
    }
    ''
      install -Dm755 ${./scripts/mirror-apt-jammy.sh} $out/bin/mirror-apt-jammy
      # we need to *--set* PATH here, otherwise aptly will pick the wrong gpg
      wrapProgram $out/bin/mirror-apt-jammy --set PATH '${super.lib.makeBinPath (with self; [ aptly bash coreutils curl gnupg gnused gnutar ])}'
    '';

  create-container-dump = super.runCommandNoCC "create-container-dump"
    {
      nativeBuildInputs = [ super.makeWrapper ];
    }
    ''
      install -Dm755 ${./scripts/create-container-dump.sh} $out/bin/create-container-dump
        wrapProgram $out/bin/create-container-dump --prefix PATH : '${super.lib.makeBinPath [ self.skopeo ]}'
    '';

  list-helm-containers = super.runCommandNoCC "list-helm-containers"
    {
      nativeBuildInputs = [ super.makeWrapper ];
    }
    ''
      install -Dm755 ${./scripts/list-helm-containers.sh} $out/bin/list-helm-containers
      wrapProgram $out/bin/list-helm-containers --prefix PATH : '${super.lib.makeBinPath [ self.kubernetes-helm ]}'
    '';

  create-build-entry = super.runCommandNoCC "create-build-entry"
    {
      nativeBuildInputs = [ super.makeWrapper ];
    }
    ''
      install -Dm755 ${./scripts/create-build-entry.sh} $out/bin/create-build-entry
      wrapProgram $out/bin/create-build-entry --prefix PATH : '${super.lib.makeBinPath (with self; [ bash jq ])}'
    '';

}
