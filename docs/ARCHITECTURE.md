# Architecture

## Overview

One Argo CD `ApplicationSet` watches a `clients/` directory in this
repository. Each subdirectory is a "client" (tenant). The generator produces
one Argo CD `Application` per client directory, which renders a shared Helm
chart (`charts/sample-app`) into that client's own namespace.

```
clients/<slug>/values.yaml  --(git generator)-->  Application "<slug>"
                                                        |
                                                        v
                                        charts/sample-app rendered with
                                        default values + client overrides
                                                        |
                                                        v
                                        namespace "<slug>" containing:
                                        dependency, migration Job, app
```

See [DIAGRAM.md](DIAGRAM.md) for a visual version.

## Design decisions

**One Application per client directory, not one Application per cluster.**
A `git` generator in "directories" mode turns "add a folder" into "provision
an environment" with no custom controller. Pruning is enabled
(`prune: true`) so deleting a client's folder tears down everything that
folder produced.

**Namespace declared in the chart, not via `CreateNamespace=true`.**
If Argo CD creates the namespace itself, pruning an `Application` does not
remove it. Declaring the `Namespace` object as a chart resource (at the
earliest sync wave) means deleting the client folder also deletes its
namespace.

**Sync waves instead of PreSync/PostSync hooks.** An earlier hook-based
approach could deadlock: a failed hook blocks the sync indefinitely with no
automatic retry path. Waves are plain ordering annotations
(`argocd.argoproj.io/sync-wave`) on ordinary resources, so a stuck wave is
just a normal, retryable out-of-sync `Application`.

Wave scheme used in `charts/sample-app`:

| Wave | Resources |
|------|-----------|
| -1   | `Namespace` |
| 0    | Dependency (sample Redis-like service) |
| 1    | Migration-style Job |
| 2    | Application Deployment/Service |

**Sync waves order resource *application*, not resource *readiness*.**
Argo CD applies wave -1 fully, then wave 0, then wave 1, and so on — but
"applied" does not mean "ready to accept connections." A Job in wave 1 can
start running before the wave-0 dependency has finished its own startup. This
template demonstrates the gap explicitly with the
[dependency-readiness experiment](../experiments/dependency-readiness/README.md),
rather than asserting it without evidence.

**A small TCP-readiness init container, not a service mesh or admission
webhook.** The guard in `charts/sample-app/templates/_helpers.tpl`
(`sample-app.waitForDependency`) is a minimal init container that loops on a
raw TCP connection attempt to the dependency's Service DNS name before the
main container starts. It is intentionally simple: no extra tooling
dependency, understandable in a few lines, and directly demonstrable with
`kubectl logs` on the init container.

**Resource quotas are illustrative, not sized from real measurements.**
`templates/guards.yaml` shows the *shape* of a `ResourceQuota` +
`LimitRange` + default-deny `NetworkPolicy` combination for namespace
isolation, with placeholder numbers. Real sizing requires measuring your own
workloads' actual idle/typical resource usage — this template does not
claim its numbers are appropriate for any real workload.

**Secrets are out of scope for this template.** A real deployment of this
pattern needs a secret-sealing mechanism (e.g. Sealed Secrets, External
Secrets Operator, or a cloud KMS-backed secret store) so that per-client
credentials can be committed to Git safely. This template uses plaintext
placeholder values in `clients/*/values.yaml` to keep the demo runnable
without extra cluster components, and calls this out explicitly rather than
implying it's production-ready as-is.

## What was simplified relative to a real system

- One dependency (a generic cache-like service) instead of several backing
  services.
- One application component instead of a multi-service stack.
- No TLS/ingress automation, no image-pull-secret handling, no
  multi-cluster/multi-environment layout.
- No CI pipeline — provisioning is "commit a client folder, Argo CD
  reconciles," matching the GitOps-as-CI approach of the system this
  template is inspired by.

These are deliberate reductions so the pattern stays readable end-to-end by
one engineer in one sitting, not omissions hiding missing functionality.
