# GitOps Environment Provisioning Template

An educational reference implementation demonstrating GitOps-based, multi-tenant
environment provisioning with Argo CD ApplicationSets, Helm, dependency
readiness guards, and a reproducible experiment.

This is a **sanitized, standalone template**, not a production system. It is
inspired by engineering challenges encountered while building a real
multi-tenant GitOps provisioning workflow, reduced to the minimum shape needed
to demonstrate the patterns. It intentionally omits secrets management
tooling, TLS automation, multi-service stacks, and anything specific to any
real company or product — see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
for what was simplified and why.

## What this demonstrates

1. **Client provisioning** — adding a directory under `clients/` causes Argo
   CD's `ApplicationSet` to generate a new `Application` automatically.
2. **Helm-based deployment** — each generated `Application` renders a shared
   chart (`charts/sample-app`) with per-client values.
3. **Dependency ordering** — Argo CD sync waves order namespace creation,
   a dependency (Redis), a migration-style Job, and the application itself.
4. **Dependency readiness** — a small init-container guard waits for the
   dependency to be reachable before the application starts (see the
   [dependency-readiness experiment](experiments/dependency-readiness/README.md)).
5. **Configuration isolation** — each client gets its own values file and
   namespace; no client configuration is shared.
6. **Resource allocation** — illustrative `ResourceQuota`/`LimitRange`
   examples, explicitly labeled as illustrative, not production sizing.
7. **Lifecycle management** — scripts to add, update, and remove a client.

## Prerequisites

Tested against:

| Component  | Version used while writing this template |
|------------|--------------------------------------------|
| Kubernetes | 1.29+ (any conformant cluster, e.g. kind/minikube) |
| Argo CD    | 2.11+ |
| Helm       | 3.14+ |

You will need a Kubernetes cluster with Argo CD installed, and `helm` +
`kubectl` on your path. This repository does not include cluster bootstrap
automation — bring your own cluster and Argo CD install.

**Status note:** the manifests and chart in this repository have been
statically validated (`helm lint`, `helm template`, YAML syntax checks — see
[Validation](#validation)) but have **not** been applied to a live cluster as
part of preparing this template. Treat the deployment steps below as the
intended, reviewed procedure, and the
[dependency-readiness experiment](experiments/dependency-readiness/README.md)
results as the only claims backed by an actual run. If you hit an issue
following these steps on your own cluster, please open an issue.

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full writeup and
[docs/DIAGRAM.md](docs/DIAGRAM.md) for the provisioning flow diagram.

## Deployment

1. Install Argo CD on your cluster (not covered here — see the
   [Argo CD getting-started guide](https://argo-cd.readthedocs.io/en/stable/getting_started/)).
2. Fork or clone this repository so Argo CD can read it as a Git source.
3. Apply the `ApplicationSet`:
   ```bash
   kubectl apply -f argocd/applicationset.yaml
   ```
4. Argo CD will discover `clients/sample-client-a` and `clients/sample-client-b`
   and generate one `Application` per directory, each deploying
   `charts/sample-app` into its own namespace.

## Adding a client

```bash
./scripts/new-client.sh my-client
```

This creates `clients/my-client/values.yaml` from a template. Commit and push
— Argo CD's `ApplicationSet` generator picks up the new directory on its next
poll (default: every 3 minutes; tune `requeueAfterSeconds` in
`argocd/applicationset.yaml`).

## Updating a client

Edit `clients/<slug>/values.yaml` and commit. Argo CD's automated sync
(`selfHeal: true`) reconciles the change.

## Removing a client

```bash
./scripts/teardown-client.sh my-client
```

This deletes the client's directory and, after you commit, Argo CD's
`prune: true` removes the generated `Application` and all resources it
created, including the namespace (see
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for why namespace deletion is
tied to pruning rather than `CreateNamespace=true`).

## Validation

```bash
./scripts/validate.sh
```

Runs `helm lint`, `helm template` (render-only, no cluster needed), and a
YAML syntax check over every manifest in the repository. This script was run
while preparing this template; see
[Publication readiness](#publication-readiness) for exactly what was and
was not exercised against a live cluster.

## Troubleshooting

- **Application stuck `Progressing`**: check the migration Job's logs first —
  sync waves only guarantee apply order, not that a dependency is actually
  reachable yet. That gap is exactly what the dependency-readiness experiment
  demonstrates.
- **Namespace not deleted after removing a client**: Argo CD's pruning can be
  blocked by finalizers on namespaced resources; check
  `kubectl get application <slug> -n argocd -o yaml` for sync errors before
  assuming the delete silently failed.

## Teardown

```bash
kubectl delete -f argocd/applicationset.yaml
kubectl delete namespace <slug>   # per client, if any namespaces remain
```

## Publication readiness

- Static validation (lint/template/YAML syntax) was run; a live-cluster
  deployment of this exact template was **not** performed as part of
  preparing it for publication.
- The [dependency-readiness experiment](experiments/dependency-readiness/README.md)
  documents what was actually run and what remains to be verified by a
  reader with a cluster available.
- No `LICENSE` file is included yet — add one before treating this as
  reusable by others under specific terms.
- This README and the architecture doc describe the generic pattern only;
  no proprietary source, secrets, hostnames, or client data from any real
  system are included anywhere in this repository.
