{{/*
Expand the name of the chart.
*/}}
{{- define "django-learn.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "django-learn.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "django-learn.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "django-learn.labels" -}}
helm.sh/chart: {{ include "django-learn.chart" . }}
{{ include "django-learn.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "django-learn.selectorLabels" -}}
app.kubernetes.io/name: {{ include "django-learn.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "django-learn.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "django-learn.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Application Secret Volumes
*/}}
{{- define "django-learn.secretVolumes" -}}
- name: twitch-secret
  secret:
    {{- if .Values.secret.twitch.existingSecretName }}
    secretName: {{ .Values.secret.twitch.existingSecretName }}
    {{- else }}
    secretName: {{ include "django-learn.fullname" . }}
    {{- end }}
    optional: false
    items:
      - key: {{ .Values.secret.twitch.clientIdKey }}
        path: "TWITCH_CLIENT_ID"
      - key: {{ .Values.secret.twitch.clientSecretKey }}
        path: "TWITCH_CLIENT_SECRET"
- name: django-secret
  secret:
    {{- if .Values.secret.django.existingSecretName }}
    secretName: {{ .Values.secret.django.existingSecretName }}
    {{- else }}
    secretName: {{ include "django-learn.fullname" . }}
    {{- end }}
    optional: false
    items:
      - key: {{.Values.secret.django.secretKeyKey }}
        path: "SECRET_KEY"
- name: postgres-secret
  secret:
    {{- if .Values.postgresql.enabled }}
    secretName: {{ include "postgresql.secretName" .Subcharts.postgresql }}
    {{- else }}
    {{- if .Values.postgresql.auth.existingSecret }}
    secretName: {{ .Values.postgresql.auth.existingSecret }}
    {{- else }}
    secretName: {{ .Values.global.postgresql.auth.existingSecret }}
    {{- end }}
    {{- end }}
    optional: false
    items:
      {{- if .Values.postgresql.enabled }}
      {{- if not (empty (include "postgresql.username" .Subcharts.postgresql)) }}
      - key: {{ include "postgresql.userPasswordKey" .Subcharts.postgresql }}
      {{- else }}
      - key: {{ include "postgresql.adminPasswordKey" .Subcharts.postgresql }}
      {{- end }}
      {{- else if .Values.postgresql.auth.secretKeys.userPasswordKey }}
      - key: {{ .Values.postgresql.auth.secretKeys.userPasswordKey }}
      {{- else }}
      - key: password
      {{- end }}
        path: "PGPASSWORD"
{{- end }}


{{/*
Application Secret Volume Mounts
*/}}
{{- define "django-learn.secretVolumeMounts" -}}
- name: twitch-secret
  mountPath: "/var/run/secrets/django_learn/twitch"
  readOnly: true
- name: django-secret
  mountPath: "/var/run/secrets/django_learn/django"
  readOnly: true
- name: postgres-secret
  mountPath: "/var/run/secrets/django_learn/postgres"
  readOnly: true
{{- end }}

{{/*
Application Environment Variables
*/}}
{{- define "django-learn.env" -}}
- name: ALLOWED_HOSTS
  value: "*"
{{- if .Values.postgresql.enabled }}
- name: PGHOST
  value: {{ include "postgresql.primary.fullname" .Subcharts.postgresql | quote }}
{{- if (include "postgresql.database" .Subcharts.postgresql) }}
- name: PGDATABASE
  value: {{ include "postgresql.database" .Subcharts.postgresql | quote }}
{{- end }}
{{- if not (empty (include "postgresql.username" .Subcharts.postgresql)) }}
- name: PGUSER
  value: {{ include "postgresql.username" .Subcharts.postgresql | quote }}
{{- else }}
- name: PGUSER
  value: postgres
{{- end }}
{{- else }}
- name: PGHOST
  value: {{ .Values.postgresql.auth.hostname | quote }}
{{- if .Values.postgresql.auth.database }}
- name: PGDATABASE
  value: {{ .Values.postgresql.auth.database | quote }}
{{- end }}
{{- if .Values.postgresql.auth.username }}
- name: PGUSER
  value: {{ .Values.postgresql.auth.username | quote }}
{{- end }}
{{- end -}}
{{- end }}
