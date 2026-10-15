# Provisioning Flow Diagram

```
                       ┌─────────────────────────────┐
                       │   Git repository (this one) │
                       │                              │
                       │  clients/                   │
                       │    sample-client-a/values.yaml
                       │    sample-client-b/values.yaml
                       │    <new-client>/values.yaml  │  ← add a directory
                       └──────────────┬───────────────┘
                                      │ watched by (git generator, "directories" mode)
                                      v
                       ┌─────────────────────────────┐
                       │   Argo CD ApplicationSet     │
                       │   (argocd/applicationset.yaml)
                       └──────────────┬───────────────┘
                                      │ generates one Application per directory
                                      v
                 ┌────────────────────┴────────────────────┐
                 v                                          v
     ┌───────────────────────┐                  ┌───────────────────────┐
     │ Application            │                  │ Application            │
     │ "sample-client-a"      │                  │ "sample-client-b"      │
     └───────────┬─────────────┘                  └───────────┬─────────────┘
                 │ renders charts/sample-app                   │ renders charts/sample-app
                 │ with client's values.yaml                   │ with client's values.yaml
                 v                                              v
     ┌─────────────────────────────┐                ┌─────────────────────────────┐
     │ Namespace "sample-client-a" │                │ Namespace "sample-client-b" │
     │                             │                │                             │
     │  wave -1: Namespace         │                │  wave -1: Namespace         │
     │  wave  0: Dependency        │                │  wave  0: Dependency        │
     │  wave  1: Migration Job     │                │  wave  1: Migration Job     │
     │  wave  2: Application       │                │  wave  2: Application       │
     │           (waits for dep.   │                │           (waits for dep.   │
     │            via init guard)  │                │            via init guard)  │
     │  ResourceQuota/LimitRange/  │                │  ResourceQuota/LimitRange/  │
     │  NetworkPolicy (isolation)  │                │  NetworkPolicy (isolation)  │
     └─────────────────────────────┘                └─────────────────────────────┘
```

Removing a client's directory and committing causes Argo CD's `prune: true`
to delete its generated `Application`, which deletes the namespace and
everything in it.
