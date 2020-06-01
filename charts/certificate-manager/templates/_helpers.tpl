{{/* vim: set filetype=mustache: */}}

{{/*
Returns the Letsencrypt API server URL based on whether testMode is enabled or disabled
*/}}
{{- define "certificate-manager.apiServerURL" -}}
{{- $hostnameParts := list "acme" -}}
{{- if .Values.inTestMode -}}
    {{- $hostnameParts = append $hostnameParts "staging" -}}
{{- end -}}
{{- $hostnameParts = append $hostnameParts "v02" -}}
{{- join "-" $hostnameParts | printf "https://%s.api.letsencrypt.org/directory" -}}
{{- end -}}
