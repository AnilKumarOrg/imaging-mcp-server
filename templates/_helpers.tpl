{{/*
==========================================================================
CAST Imaging MCP Server - Helm Template Helpers
==========================================================================
This file contains reusable template functions (helpers) for the 
CAST Imaging MCP Server Helm chart. These functions generate consistent
names, labels, and selectors across all Kubernetes resources.

Helper Functions:
1. cast-imaging-mcp.name         - Chart name (with override support)
2. cast-imaging-mcp.fullname     - Full application name for resources
3. cast-imaging-mcp.chart        - Chart name and version for labels
4. cast-imaging-mcp.labels       - Standard labels for all resources
5. cast-imaging-mcp.selectorLabels - Labels for pod selection

Naming Conventions:
- All names are truncated to 63 characters (Kubernetes DNS limit)
- Trailing hyphens are removed for clean naming
- Support for nameOverride and fullnameOverride values
- Consistent labeling following Kubernetes best practices
==========================================================================
*/}}

{{/*
Expand the name of the chart.
This helper generates the base name used for Kubernetes resources.

Precedence:
1. .Values.nameOverride (if specified)
2. .Chart.Name (from Chart.yaml)

Output: Truncated to 63 chars, no trailing hyphens
Example: "cast-imaging-mcp-server"
*/}}
{{- define "cast-imaging-mcp.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
This helper generates the full name used for most Kubernetes resource names.

Naming Logic:
1. If .Values.fullnameOverride is set, use it directly
2. If release name contains chart name, use release name only
3. Otherwise, combine release name and chart name with hyphen

Precedence:
1. .Values.fullnameOverride (if specified)
2. .Release.Name (if it contains chart name)
3. "<release-name>-<chart-name>" (default combination)

Output: Truncated to 63 chars (DNS naming spec limit), no trailing hyphens
Example: "imaging-mcp-server" or "my-release-cast-imaging-mcp-server"

Note: The 63 character limit is imposed by Kubernetes DNS naming specifications.
*/}}
{{- define "cast-imaging-mcp.fullname" -}}
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
This helper generates a label value that includes both chart name and version.

Format: "<chart-name>-<version>"
Example: "cast-imaging-mcp-server-1.1.0"

Note: Plus signs in version are replaced with underscores for label compatibility.
*/}}
{{- define "cast-imaging-mcp.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels applied to all Kubernetes resources.
These labels provide metadata for resource identification, management, and monitoring.

Labels included:
- helm.sh/chart: Chart name and version
- app.kubernetes.io/name: Application name  
- app.kubernetes.io/instance: Helm release name
- app.kubernetes.io/version: Application version (from Chart.appVersion)
- app.kubernetes.io/managed-by: Set to "Helm" for Helm-managed resources

These labels follow Kubernetes recommended label conventions:
https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/
*/}}
{{- define "cast-imaging-mcp.labels" -}}
helm.sh/chart: {{ include "cast-imaging-mcp.chart" . }}
{{ include "cast-imaging-mcp.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels for pod selection and service targeting.
These labels are used to identify and select pods belonging to this application.

Labels included:
- app.kubernetes.io/name: Application name (from chart name or override)
- app.kubernetes.io/instance: Helm release name for multi-release support

Note: This is a subset of the full labels, containing only immutable selectors.
These labels must remain consistent across all template versions to maintain
proper pod selection and service routing.
*/}}
{{- define "cast-imaging-mcp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cast-imaging-mcp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
