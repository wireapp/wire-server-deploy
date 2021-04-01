self: super: {
  kubectl = self.callPackage ./pkgs/kubectl.nix { };
  kubernetes-helm = super.wrapHelm super.kubernetes-helm {
    plugins = with super.kubernetes-helmPlugins; [ helm-s3 helm-secrets helm-diff ];
  };
}
