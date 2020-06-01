{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "nginx-ingress-services.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "nginx-ingress-services.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Determine DNS zone based on one of the given FQDNs
*/}}
{{- define "nginx-ingress-services.zone" -}}
{{- $zones := splitList "." .Values.config.dns.https -}}
{{- slice $zones 1 | join "." -}}
{{- end -}}

{{/*
Generate the secrate name in a conistent way, since it's referred to in multiple places, while
at the same time being used for distinct scenarios
*/}}
{{- define "nginx-ingress-services.getCertificateSecretName" -}}
{{- $nameParts := list (include "nginx-ingress-services.fullname" .) -}}
{{- if .Values.tls.useCertificateManager -}}
    {{- $nameParts = append $nameParts "managed" -}}
{{- else -}}
    {{- $nameParts = append $nameParts "wildcard" -}}
{{- end -}}
{{- $nameParts = append $nameParts "tls-certificate" -}}
{{- join "-" $nameParts -}}
{{- end -}}