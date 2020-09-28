let
  sources = import ./nix/sources.nix;

  pkgs = import sources.nixpkgs {
    overlays = [ (import (sources.poetry2nix + "/overlay.nix")) ];
  };

  poetryEnv = pkgs.poetry2nix.mkPoetryEnv {
    projectDir = ./ansible;
    python = pkgs.python37;
    overrides = pkgs.poetry2nix.overrides.withDefaults ( self: super: {
      psutil = super.psutil.overridePythonAttrs (old: rec {
        doCheck = false;
      });
      paramiko = super.paramiko.overridePythonAttrs (old: rec {
        doCheck = false;
      });
    });
  };
in
pkgs.mkShell{
  name = "wire-server-deploy";
  nativeBuildInputs = [ poetryEnv ] ;
  buildInputs = with pkgs; [
    terraform_0_13
    python37Packages.poetry
  ];
}
