// This is the main configuration file for your Wire deployment.
//
// You can commit it to version control. We aim to not update this file unless necessary,
// and as such you will likely not have to deal with merge conflicts.

local wire = import "lib/wire.libsonnet";

{
    // An example deployment. Edit this to match your desired environment.
    // See clusters.libsonnet for tunables in `cfg`.
    example: wire.Environment("example") {
        cfg+: {
            dns+: {
                domain: "wire.example.com",
            },
        },
    },
}
