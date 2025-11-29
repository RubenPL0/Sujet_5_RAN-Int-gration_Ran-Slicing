{{- define "oai-gnb-slicing.fullname" -}}
{{- .Release.Name }}-gnb-slicing
{{- end }}

{{- define "oai-gnb-slicing.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}
