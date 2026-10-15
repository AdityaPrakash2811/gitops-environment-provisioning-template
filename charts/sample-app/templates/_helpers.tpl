{{/*
Required client slug. Fails the render rather than defaulting, so a missing
override can't silently collide with another client's namespace/resources.
*/}}
{{- define "sample-app.slug" -}}
{{- if not .Values.client.slug -}}
{{- fail "client.slug is required: set it in clients/<slug>/values.yaml" -}}
{{- end -}}
{{- .Values.client.slug -}}
{{- end -}}

{{/*
Shared selector labels, consistent across every resource in this chart.
*/}}
{{- define "sample-app.selectorLabels" -}}
app.kubernetes.io/name: {{ .component }}
app.kubernetes.io/instance: {{ include "sample-app.slug" .root }}
{{- end -}}

{{/*
Minimal TCP-readiness guard: loops a raw TCP connect attempt against the
dependency's Service DNS name until it succeeds, then exits so the main
container can start. Demonstrates that sync-wave ordering only guarantees
apply order, not that a dependency is actually accepting connections yet.
See experiments/dependency-readiness/.
*/}}
{{- define "sample-app.waitForDependencyContainer" -}}
name: wait-for-dependency
image: busybox:1.36
command:
  - sh
  - -c
  - |
    echo "waiting for dependency tcp://dependency.{{ include "sample-app.slug" . }}.svc.cluster.local:{{ .Values.dependency.port }} ..."
    until nc -z -w 2 dependency.{{ include "sample-app.slug" . }}.svc.cluster.local {{ .Values.dependency.port }}; do
      echo "dependency not reachable yet, retrying in 2s"
      sleep 2
    done
    echo "dependency is reachable"
{{- end -}}

{{/*
Generic migration-style Job. Parameterized so additional migration jobs
could reuse it, mirroring a pattern where many services share one Job
template instead of duplicating boilerplate per service.
*/}}
{{- define "sample-app.migrationJob" -}}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ .name }}
  namespace: {{ include "sample-app.slug" .root }}
  annotations:
    argocd.argoproj.io/sync-wave: "1"
    argocd.argoproj.io/sync-options: Replace=true,Force=true
spec:
  activeDeadlineSeconds: {{ .root.Values.migration.activeDeadlineSeconds }}
  ttlSecondsAfterFinished: {{ .root.Values.migration.ttlSecondsAfterFinished }}
  backoffLimit: 2
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: migrate
          image: {{ .root.Values.migration.image }}
          command: ["sh", "-c", "echo 'running sample migration for {{ include \"sample-app.slug\" .root }}'; sleep 2; echo done"]
{{- end -}}
