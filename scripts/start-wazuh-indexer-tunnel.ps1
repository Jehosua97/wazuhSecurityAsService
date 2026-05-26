[CmdletBinding()]
param(
    [string]$ProjectId = "wazuh-iac-on-gcp",
    [string]$Zone = "us-central1-a",
    [string]$InstanceName = "wazuh-server",
    [int]$LocalPort = 9200,
    [int]$RemotePort = 9200
)

$ErrorActionPreference = "Stop"

Write-Host "Abriendo tunel local para Wazuh Indexer..."
Write-Host "Local:  https://localhost:$LocalPort"
Write-Host "Docker: https://host.docker.internal:$LocalPort"
Write-Host "Cierra esta ventana para terminar el tunel."

gcloud compute ssh $InstanceName `
    --project=$ProjectId `
    --zone=$Zone `
    -- `
    -N `
    -L "${LocalPort}:127.0.0.1:${RemotePort}"
