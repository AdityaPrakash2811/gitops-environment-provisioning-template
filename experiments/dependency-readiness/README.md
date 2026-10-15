# Experiment: Dependency Readiness vs. Sync-Wave Ordering

## Hypothesis

Argo CD sync waves guarantee the *order resources are applied*, not that a
dependency is *actually ready to accept connections* by the time a
later-wave resource starts. Without an explicit readiness guard, the `app`
Deployment (wave 2) can start before the `dependency` Deployment (wave 0)
is actually accepting TCP connections, even though wave 0 was applied
first.

## What this distinguishes

This experiment isolates three different things that are easy to conflate:

1. **Argo CD resource ordering** — whether wave 0 is *applied* before wave 2.
2. **Kubernetes readiness** — whether the dependency Pod is *scheduled and
   running* (not the same as accepting application-level connections).
3. **Application-level connectivity** — whether a TCP connection to the
   dependency's port actually succeeds.

Sync waves only guarantee (1). This experiment demonstrates the gap between
(1) and (3).

## Method

`run-experiment.sh` renders the chart twice with `helm template` — once with
`app.waitForDependency=true` (the guard enabled) and once with
`app.waitForDependency=false` (disabled) — and diffs the resulting `app`
Deployment manifest to show exactly what the guard adds.

This is a **static, render-only** demonstration: it shows what Kubernetes
would run in each case by inspecting the rendered manifests, not a live
reproduction of the race condition on a running cluster (no cluster was
used in preparing this template — see the repository root README's
"Publication readiness" section).

## Expected results

- **Guard disabled**: the rendered `app` Deployment has no `initContainers`
  stanza. On a real cluster, the main container would start immediately
  once scheduled, with no guarantee the dependency is reachable yet. If the
  application's own code does not independently retry its connection, a
  pod that starts during that gap can fail or crash-loop depending on how
  it is written.
- **Guard enabled**: the rendered `app` Deployment includes an
  `initContainers` entry (`wait-for-dependency`) that loops a TCP connect
  attempt against the dependency's Service DNS name before the main
  container is allowed to start.

## Actual results

Run `./run-experiment.sh` from this directory. It prints the rendered diff
and was last run while preparing this template; see the script's own output
for the exact diff produced in this repository's current state.

## Limitations

- This experiment does not reproduce the race condition on a live cluster —
  it demonstrates the *manifest-level* difference the guard makes. A reader
  with a cluster available can apply both variants and observe the actual
  runtime behavior (e.g. with `kubectl logs <pod> -c wait-for-dependency`
  and `kubectl get events`) to confirm the guard's init container actually
  blocks main-container startup until the dependency is reachable.
- Whether disabling the guard produces a visible failure in practice depends
  on how the application itself is written (whether it retries its own
  connection on startup). This template's sample app is a placeholder image
  and does not implement that logic either way — the guard is the
  mechanism being demonstrated, not a specific application's failure mode.
