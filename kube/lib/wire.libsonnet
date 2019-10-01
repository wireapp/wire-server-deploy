local kube = import "kube.libsonnet";

// Wire deployment.

{
    local wire = self,

    // A Wire Environment. Also called a Deployment.
    // Contains all services/components required to run Wire on k8s, apart from
    // per-cluster services.
    // All components will be run in a given k8s namespace, by default named
    // after the environment.
    Environment(name):: {
        local env = self,
        local cfg = env.cfg,

        // User configurable.
        cfg:: {
            // Name of environment, used internally. Can be overridden.
            name: name,
            // Kubernetes namespace in which environment will be run. Can be overridden.
            namespace: name,

            // Public DNS names to be used by wire-server.
            dns: {
                // Top-level domain. Must be set, or all specific domain names
                // underneath must be overriden.
                domain: error "dns.domain must be set", // .my-wire.example.com

                // Default DNS prefixes for top-level domain.
                nginzHTTPS: "nginz-https.%s" % [cfg.dns.domain],
                nginzTLS: "nginz-tls.%s" % [cfg.dns.domain],
                webapp: "webapp.%s" % [cfg.dns.domain],
                assets: "assets.%s" % [cfg.dns.domain],
                account: "account.%s" % [cfg.dns.domain],
                teams: "teams.%s" % [cfg.dns.domain],
            },

            // Images and versions of components.
            images: {
                avsNetworkTestTool: "quay.io/wire/avs-nwtesttool:1.0.12",
            },
        },

        // Intermediary component configurations.
        components:: wire.blueprints(env),

        // Outputted to top-level files.
        outputs: {
            // To kubecfg.
            kubernetes: {
                namespace: kube.Namespace(cfg.namespace),

                components: {
                    [c]: env.components[c].kubernetes
                    for c in std.objectFields(env.components)
                },
            },

            // To sample nginz rule generator.
            nginz: {
                rules: std.flattenArrays([
                    [
                        {
                            local component = env.components[c],
                            rule: n.route,
                            target: {
                                host: component.kubernetes.service.host,
                                port: n.port,
                            },
                        },
                        for n in env.components[c].nginz
                    ]
                    for c in std.objectFields(env.components)
                ]),
            }
        },
    },

    // A Wire Component.
    // A Wire Component is a microservice that lives within an Environment.
    // These correspond to wire-server services.
    // Non wire-server services should likely define and use a different type.
    Component(name, env):: {
        local component = self,
        local cfg = component.cfg,

        name:: name,

        // One or more containers run as part of this component.
        // These must be of type kube.Container.
        container:: error "container(s) must be set!",
        containers:: [ component.container ],

        // Nginz rules incoming into this component.
        nginz:: {
            // { port: 8080, route: "/foo/bar" },
        },

        kubernetes: {
            local k8s = self,
            metadata:: {
                namespace: env.cfg.namespace,
            },

            deployment: kube.Deployment(name) {
                metadata+: k8s.metadata,

                spec+: {
                    template+: {
                        spec+: {
                            containers: component.containers,
                            serviceAccountName: k8s.account.metadata.name,
                        },
                    },
                },
            },

            service: kube.Service(name) {
                metadata+: k8s.metadata,
                target_pod:: k8s.deployment.spec.template,
                spec+: {
                    ports: [
                        { name: "nginz-%d" % [p.port], port: p.port, targetPort: p.port, protocol: "TCP" },
                        for p in component.nginz
                    ],
                }
            },

            account: kube.ServiceAccount(name) {
                metadata+: k8s.metadata,
                automountServiceAccountToken: false,
            },
        },
    },

    // Wrapper around kube.Container that gives us some nice defaults.
    Container(name): kube.Container(name) {
        resources: {
            local resources = self,
            requests: {
                memory: "64Mi",
                cpu: "100m",
            },

            limits: {
                // By default, set limits to twice the requests.
                memory: std.toString(kube.siToNum(resources.requests.memory) * 2),
                cpu: std.toString(kube.siToNum(resources.requests.cpu) * 2),
            },
        }
    },

    // All components required to run wire-server.
    blueprints(env):: {
        // AVS Network Test Tool.
        // Provides a self-rendered web view to run tests against TURN servers
        // in a given backend.
        AVSNetworkTestTool: wire.Component("avs-nwtesttool", env) {
            local component = self,

            container:: wire.Container("main") {
                image: env.cfg.images.avsNetworkTestTool,
                env_: {
                    // Public URL of Backend (not internal service!).
                    BACKEND_HTTPS_URL: "https://%s/" % [env.cfg.dns.nginzHTTPS],
                },
                // Args not needed. By default, container serves on port 80.
            },

            nginz: [
                { port: 80, route: "/calls/test" },
            ],
        },
    },

    asserts:: [
        // Old versions of jsonnet/kubecfg do not implement std.find.
        if !std.hasObject(std, "find") then error "please upgrade jsonnet/kubecfg" else null,
    ],
}
