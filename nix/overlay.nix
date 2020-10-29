self: super: {
  ansible_with_libs = super.python3Packages.toPythonApplication (super.python3Packages.ansible.overridePythonAttrs (old: rec {
    propagatedBuildInputs = old.propagatedBuildInputs or [] ++ [
      super.python3Packages.boto
      super.python3Packages.boto3
      super.python3Packages.six
    ];
  }));

  pythonForAnsible = (self.python3.withPackages (_: self.ansible.requiredPythonModules));

  mirror-bionic = self.callPackage ./pkgs/mirror-bionic {};

  kubectl_1_14_10 = self.callPackage ./pkgs/kubectl_1_14_10.nix {};

  mirror-bionic = self.callPackage ./pkgs/mirror-bionic {};
}
