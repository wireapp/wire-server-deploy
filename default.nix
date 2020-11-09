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
  # nix run nixpkgs.nix-prefetch-docker -c nix-prefetch-docker --image-name alpine
  alpine = pkgs.dockerTools.pullImage {
    imageName = "alpine";
    imageDigest = "sha256:c0e9560cda118f9ec63ddefb4a173a2b2a0347082d7dff7dc14272e7841a5b5a";
    sha256 = "04six60cs8w77jggbxyrdi3k8hczn653yiwlbmyh9xcjrxb8jk60";
    finalImageName = "alpine";
    finalImageTag = "latest";
  };

in rec {
  inherit pkgs profileEnv scripts;

  container = pkgs.dockerTools.buildImage {
    name = "quay.io/wire/wire-server-deploy";
    fromImage = alpine;
    # we don't want git or ssh or anything in here, the ansible folder is
    # mounted into here.
    contents = [
      pkgs.cacert
      pkgs.coreutils
      pkgs.bashInteractive
      pkgs.openssh # ansible needs this too, even with paramiko
      env
      # provide /usr/bin/env and /tmp in the container too :-)
      #(pkgs.runCommandNoCC "foo" {} "
      #  mkdir -p $out/usr/bin $out/tmp
      #  ln -sfn ${pkgs.coreutils}/bin/env $out/usr/bin/env
      #")
    ];
    config = {
      Volumes = {
        "/wire-server-deploy" = {};
      };
      WorkingDir = "/wire-server-deploy";
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
