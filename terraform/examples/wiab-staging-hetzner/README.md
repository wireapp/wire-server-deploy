# Wire-in-a-box-staging-hetzner

This environment is dynamically provisioned to validate the wiab-staging solution, developed as a follow-up to our HA architecture in which datastore and Kubernetes VMs are physically failure-resilient.

For wiab-staging, all components are deliberately colocated on a single physical node, resulting in zero physical redundancy and a single point of failure. This design is intentional and suitable only for staging and testing, not production deployments.
