{ system ? builtins.currentSystem }:

let
  sources = import ./nix/sources.nix;
  # for injecting old gnupg dependency
  oldpkgs = import sources.oldpkgs {
    inherit system;
    config = { };
  };
  # extract the module for injecting
  gnupg1orig = oldpkgs.gnupg1orig;

  pkgs = import sources.nixpkgs {
    inherit system;
    config = { };
    # layering is important here, the lowest takes precedance in case of overlaps
    overlays = [
      # custom overlay for injections 
      (self: super: {
        gnupg1orig = gnupg1orig;
      })
      # main overlay
      (import ./nix/overlay.nix)
    ];
  };

  # inject jmespath into a python package
  pythonWithJmespath = pkgs.python3.withPackages (ps: with ps; [
    jmespath
  ]);

  # override python used in pythonForAnsible with our custom jmespath injected package
  pythonForAnsibleWithJmespath = pkgs.pythonForAnsible.override {
    python = pythonWithJmespath;
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
      jmespath
      apacheHttpd
      awscli2
      gnumake
      gnupg1
      # injected dependacy gnupg1orig
      gnupg1orig

      kubernetes-tools

      # Note: This is overriden in nix/overlay.nix to have plugins. This is
      # required so that helmfile get's the correct version of helm in its PATH.
      kubernetes-helm
      helmfile
      openssl
      moreutils
      skopeo
      sops
      opentofu
      yq
      create-container-dump
      list-helm-containers
      mirror-apt-jammy
      generate-gpg1-key
      create-build-entry
      # Linting
      shellcheck

      # general utilities for bash operations
      jq
      gnused
      curl
      gawk

      niv
      nix-prefetch-docker
    ] ++ [
      profileEnv
    ] ++ lib.optionals pkgs.stdenv.isLinux [
      pkgs.containerd


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
        "LOCALHOST_PYTHON=${env}/bin/python" # is this even referencing the correct python used by ansible and is this even relevant for setting what is being used?
      ];
    };
  };
}