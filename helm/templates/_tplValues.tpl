{{/*
Copyright VMware, Inc.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/* vim: set filetype=mustache: */}}
{{/*
Renders a value that contains template perhaps with scope if the scope is present.
Usage:
{{ include "common.tplvalues.render" ( dict "value" .Values.path.to.the.Value "context" $ ) }}
{{ include "common.tplvalues.render" ( dict "value" .Values.path.to.the.Value "context" $ "scope" $app ) }}
*/}}
{{- define "common.tplvalues.render" -}}
{{- $value := typeIs "string" .value | ternary .value (.value | toYaml) }}
{{- if contains "{{" (toJson .value) }}
  {{- if .scope }}
      {{- tpl (cat "{{- with $.RelativeScope -}}" $value "{{- end }}") (merge (dict "RelativeScope" .scope) .context) }}
  {{- else }}
    {{- tpl $value .context }}
  {{- end }}
{{- else }}
    {{- $value }}
{{- end }}
{{- end -}}

{{/*
Merge a list of values that contains template after rendering them.
Merge precedence is left to right
Usage:
{{ include "common.tplvalues.merge" ( dict "values" (list .Values.path.to.the.Value1 .Values.path.to.the.Value2) "context" $ ) }}
*/}}
{{- define "common.tplvalues.merge" -}}
{{- $dst := dict -}}
{{- range .values -}}
{{- $dst = include "common.tplvalues.render" (dict "value" . "context" $.context "scope" $.scope) | fromYaml | merge $dst -}}
{{- end -}}
{{ $dst | toYaml }}
{{- end -}}

{{/*
End of usage example
*/}}

{{/*
Custom definitions
*/}}

{{- define "common.storage.merged" -}}
{{- include "common.tplvalues.merge" ( dict "values" ( list .Values.storage .Values.global.storage ) "context" . ) }}
{{- end -}}

{{- define "common.db.merged" -}}
{{- include "common.tplvalues.merge" ( dict "values" ( list .Values.db .Values.global.db ) "context" . ) }}
{{- end -}}

{{- define "common.s3.merged" -}}
{{- include "common.tplvalues.merge" ( dict "values" ( list .Values.storage.s3 .Values.global.storage.s3 ) "context" . ) }}
{{- end -}}

{{- define "common.fs.merged" -}}
{{- include "common.tplvalues.merge" ( dict "values" ( list .Values.storage.fs .Values.global.storage.fs ) "context" . ) }}
{{- end -}}

{{- define "common.tracing.merged" -}}
{{- include "common.tplvalues.merge" ( dict "values" ( list .Values.tracing .Values.global.tracing ) "context" . ) }}
{{- end -}}

{{- define "common.metrics.merged" -}}
{{- include "common.tplvalues.merge" ( dict "values" ( list .Values.metrics .Values.global.metrics ) "context" . ) }}
{{- end -}}
