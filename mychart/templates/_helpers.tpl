{{/* 生成基本的lables标签 */}}
{{- define "mychart.labels" }}
from: helm
date: {{ now | htmlDate }}
chart: {{ .Chart.Name }}
version: {{ .Chart.Version }}
{{- end }}