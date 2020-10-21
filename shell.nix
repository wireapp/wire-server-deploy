let
  sources = import ./nix/sources.nix;

  pkgs = import sources.nixpkgs {};
in
pkgs.mkShell{
  name = "wire-server-deploy";
  buildInputs = with pkgs; [
    terraform_0_13
    python37Packages.poetry
    python37Packages.pip
    python37
    awscli
    sops
    gnupg
    git
  ];
}
