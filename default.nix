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
      pkgs.aptly
      pkgs.awscli
      pkgs.gnumake
      pkgs.gnupg
      pkgs.kubectl_1_14_10
      pkgs.kubernetes-helm
      pkgs.mirror-bionic
      pkgs.moreutils
      pkgs.pythonForAnsible
      pkgs.skopeo
      pkgs.sops
      pkgs.terraform_0_13
      pkgs.yq
    ];
  };
}
