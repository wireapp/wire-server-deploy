let
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs {};
in {
  env = pkgs.buildEnv{
    name = "wire-server-deploy";
    paths = with pkgs; [
      terraform_0_13
      python37Packages.poetry
      awscli
      sops
      gnupg
      git
      yq
      bash
    ];
  };
}
