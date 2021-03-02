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

in {
  inherit pkgs profileEnv;

  env = pkgs.buildEnv{
    name = "wire-server-deploy";
    paths = [
      profileEnv
      pkgs.ansible_with_libs
      pkgs.apacheHttpd
      pkgs.awscli
      pkgs.gnumake
      pkgs.gnupg
      pkgs.helmfile
      pkgs.kubectl
      pkgs.kubernetes-helm
      pkgs.moreutils
      pkgs.openssl
      pkgs.pythonForAnsible
      pkgs.skopeo
      pkgs.sops
      pkgs.terraform_0_13
      pkgs.yq
    ];
  };
}
