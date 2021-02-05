self: super: {
  ansible_with_libs = super.python3Packages.toPythonApplication (super.python3Packages.ansible.overridePythonAttrs (old: rec {
    propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [
      super.python3Packages.boto
      super.python3Packages.boto3
      super.python3Packages.six
    ];
  }));

  pythonForAnsible = (self.python3.withPackages (_: self.ansible.requiredPythonModules));

  kubectl = self.callPackage ./pkgs/kubectl.nix { };


  generate-gpg1-key = super.runCommandNoCC "generate-gpg1-key"
    {
      nativeBuildInputs = [ super.makeWrapper ];
    } ''
    install -Dm755 ${./scripts/generate-gpg1-key.sh} $out/bin/generate-gpg1-key
    # we *--set* PATH here, to ensure we don't pick wrong gpgs
    wrapProgram $out/bin/generate-gpg1-key --set PATH '${super.lib.makeBinPath (with self; [ bash coreutils gnupg1orig ])}'
  '';

  mirror-apt =
    super.runCommandNoCC "mirror-apt"
      {
        nativeBuildInputs = [ super.makeWrapper ];
      } ''
      install -Dm755 ${./scripts/mirror-apt.sh} $out/bin/mirror-apt
      # we need to *--set* PATH here, otherwise aptly will pick the wrong gpg
      wrapProgram $out/bin/mirror-apt --set PATH '${super.lib.makeBinPath (with self; [ aptly bash coreutils curl gnupg1orig gnused gnutar ])}'
    '';

}
