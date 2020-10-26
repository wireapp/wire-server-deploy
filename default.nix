let
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs {};
in {
  env = pkgs.buildEnv{
    name = "wire-server-deploy";
    paths = with pkgs; [
      awscli
      gnumake
      gnupg
      moreutils
      python37Packages.poetry
      skopeo
      sops
      terraform_0_13
      yq
    ];
  };
}
