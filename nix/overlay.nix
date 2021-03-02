self: super: {
  ansible_with_libs = super.python3Packages.toPythonApplication (super.python3Packages.ansible.overridePythonAttrs (old: rec {
    propagatedBuildInputs = old.propagatedBuildInputs or [] ++ [
      super.python3Packages.boto
      super.python3Packages.boto3
      super.python3Packages.six
    ];
  }));

  pythonForAnsible = (self.python3.withPackages (_: self.ansible.requiredPythonModules));

  kubectl = self.callPackage ./pkgs/kubectl.nix { };

  zauth = self.callPackage ./pkgs/zauth.nix { };
}
