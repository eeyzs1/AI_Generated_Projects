{{/*
通用标签
*/}}
{{- define "services.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
构建完整镜像地址
用法: {{ include "services.image" (list . "user-service:latest") }}
*/}}
{{- define "services.image" -}}
{{- $ctx := index . 0 -}}
{{- $img := index . 1 -}}
{{- printf "%s/%s" $ctx.Values.global.registry $img -}}
{{- end }}
