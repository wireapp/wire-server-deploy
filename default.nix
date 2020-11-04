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
  inherit (pkgs) scripts;

in rec {
  inherit pkgs profileEnv scripts;

  container = pkgs.dockerTools.buildLayeredImage {
    name = "wire-server-deploy";
    maxLayers = 10;
    # we don't want git or ssh or anything in here, the ansible folder is
    # mounted into here.
    contents = [
      pkgs.cacert
      pkgs.coreutils
      pkgs.bashInteractive
      env
    ];
    config = {
      Volumes = {
        "/wire-server-deploy" = {};
      };
      Workdir = "/wire-server-deploy";
    };
  };

  env = pkgs.buildEnv{
    name = "wire-server-deploy";
    paths = [
      scripts.create-container-dump
      scripts.generate-gpg1-key
      scripts.download-helm-charts
      scripts.list-helm-containers
      scripts.mirror-bionic

      profileEnv
      pkgs.ansible_with_libs
      pkgs.aptly
      pkgs.awscli
      pkgs.gnumake
      pkgs.gnupg
      pkgs.just
      pkgs.kubeadm
      pkgs.kubectl_1_14_10
      pkgs.kubernetes-helm
      pkgs.moreutils
      pkgs.pythonForAnsible
      pkgs.skopeo
      pkgs.sops
      pkgs.terraform_0_13
      pkgs.yq
    ];
  };
}
