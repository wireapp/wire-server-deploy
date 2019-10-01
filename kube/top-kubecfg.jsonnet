local deployments = import "deployments.libsonnet";

{
    [d]: deployments[d].outputs.kubernetes
    for d in std.objectFields(deployments)
}
