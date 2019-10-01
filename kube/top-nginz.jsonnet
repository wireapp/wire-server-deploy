local deployments = import "deployments.libsonnet";

{
    [d]: deployments[d].outputs.nginz
    for d in std.objectFields(deployments)
}
