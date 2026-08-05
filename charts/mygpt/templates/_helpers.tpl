{{/*
Full name of the release-scoped resource prefix.
*/}}
{{- define "mygpt.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Name of the shared Secret that holds the .env values.
If .Values.secrets.existingSecret is set, reference that instead.
*/}}
{{- define "mygpt.secretName" -}}
{{- if .Values.secrets.existingSecret -}}
{{- .Values.secrets.existingSecret -}}
{{- else -}}
{{- include "mygpt.fullname" . }}-secrets
{{- end -}}
{{- end -}}

{{/*
Standard labels for a mygpt resource.
*/}}
{{- define "mygpt.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}

{{/*
Selector labels for a given component (litellm, openwebui, kokoro-web, db, redis, searxng).
Call with (dict "root" . "component" "<name>").
*/}}
{{- define "mygpt.selectorLabels" -}}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}
