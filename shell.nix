{ pkgs ? import <nixpkgs> {}}:
pkgs.mkShell {
  buildInputs = [
    pkgs.kubectl
    pkgs.kubernetes-helm
    pkgs.python27Packages.poetry
  ];
}
