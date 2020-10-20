{ provideCIDependencies ? false }:
let
  sources = import ./nix/sources.nix;

  pkgs = import sources.nixpkgs {};

  ciDependencies = if provideCIDependencies
                   then with pkgs; [ awscli sops gnupg git ]
                   else [];
in
pkgs.mkShell{
  name = "wire-server-deploy";
  buildInputs = with pkgs; [
    terraform_0_13
    python37Packages.poetry
    python37Packages.pip
    python37
  ] ++ ciDependencies;
}
