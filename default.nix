{ system ? builtins.currentSystem }:

let
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs {
    inherit system;
    config = { };
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


in
rec {
  inherit pkgs profileEnv;

  env = pkgs.buildEnv {
    name = "wire-server-deploy";
    paths = with pkgs; [
      ansible_2_16
      pythonForAnsible
      apacheHttpd
      awscli2
      gnumake
      gnupg

      kubernetes-tools

      # Note: This is overriden in nix/overlay.nix to have plugins. This is
      # required so that helmfile get's the correct version of helm in its PATH.
      kubernetes-helm
      helmfile
      openssl
      moreutils
      skopeo
      sops
      terraform_1
      yq
      create-container-dump
      list-helm-containers
      mirror-apt-jammy
      generate-gpg1-key
      # Linting
      shellcheck

      niv
      nix-prefetch-docker
    ] ++ [
      profileEnv
    ] ++ lib.optionals pkgs.stdenv.isLinux [
      pkgs.containerd
      patch-ingress-controller-images # depends on containerd, TODO: migrate to skopeo?


      # for RTP session debugging
      wireshark
      gnuplot
    ];
  };

  # The container we use for offline deploys. Where people probably do not have
  # nix + direnv :)
  container = pkgs.dockerTools.buildImage {
    name = "quay.io/wire/wire-server-deploy";
    fromImage = pkgs.dockerTools.pullImage (import ./nix/docker-alpine.nix);
    # we don't want git or ssh or anything in here, the ansible folder is
    # mounted into here.
    contents = [
      pkgs.cacert
      pkgs.coreutils
      pkgs.bashInteractive
      pkgs.openssh # ansible needs this too, even with paramiko
      pkgs.sshpass # needed for password login

      # The enivronment
      env
      # provide /usr/bin/env and /tmp in the container too :-)
      #(pkgs.runCommandNoCC "foo" {} "
      #  mkdir -p $out/usr/bin $out/tmp
      #  ln -sfn ${pkgs.coreutils}/bin/env $out/usr/bin/env
      #")
    ];
    config = {
      Volumes = {
        "/wire-server-deploy" = { };
      };
      WorkingDir = "/wire-server-deploy";
      Env = [
        "KUBECONFIG=/wire-server-deploy/ansible/inventory/offline/artifacts/admin.conf"
        "ANSIBLE_CONFIG=/wire-server-deploy/ansible/ansible.cfg"
        "LOCALHOST_PYTHON=${env}/bin/python"
      ];
    };
  };
}
