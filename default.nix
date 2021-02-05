let
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs {
    config = {};
    overlays = [
      (import ./nix/overlay.nix)
    ];
  };
  profileEnv = pkgs.writeTextFile {
    name = "profile-env";
    destination = "/.profile";
    # This gets sourced by direnv. Set NIX_PATH, so `nix-shell` uses the same nixpkgs as here.
    text = ''
      export NIX_PATH=nixpkgs=${toString pkgs.path}
    '';
  };

  pythonForAnsible = pkgs.python3.withPackages (p: [ p.boto p.boto3 p.six p.cryptography ]);


in {
  inherit pkgs profileEnv;

  env = pkgs.buildEnv{
    name = "wire-server-deploy";
    paths = with pkgs; [
      ansible_2_9
      pythonForAnsible
      apacheHttpd
      awscli
      gnumake
      gnupg
      # Note: This is overriden in nix/overlay.nix to have plugins. This is
      # required so that helmfile get's the correct version of helm in its PATH.
      kubernetes-helm
      helmfile
      kubectl
      openssl
      moreutils
      skopeo
      sops
      terraform_0_13
      yq
      mirror-apt
      generate-gpg1-key
    ] ++ [ profileEnv];
  };
}
