let
  sources = import ./nix/sources.nix;

  poetry2nixOverlay = builtins.fetchGit {
    ref = "master";
    rev = "ab40bbdc964b7cc0a69d6f9ce77afbc79bb6e815";
    url = "https://github.com/nix-community/poetry2nix";
  };

  pkgs = import sources.nixpkgs {
    overlays = [ (import "${poetry2nixOverlay}/overlay.nix") ];
  };
  lib = pkgs.lib;
  poetryOverrides = pkgs.poetry2nix.mkDefaultPoetryOverrides (import ./nix/poetry-overrides.nix { inherit pkgs lib; });
  poetryEnv = pkgs.poetry2nix.mkPoetryEnv {
    projectDir = ./ansible;
    python = pkgs.python37;
    overrides = poetryOverrides;
  };
in
pkgs.mkShell{
  name = "wire-server-deploy";
  nativeBuildInputs = [poetryEnv] ;
  buildInputs = with pkgs; [ terraform_0_13 ];
}

