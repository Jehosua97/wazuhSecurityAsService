param(
    [string]$ProjectId = "wazuh-iac-on-gcp",
    [string]$Zone = "us-central1-a",
    [string]$InstanceName = "wazuh-server"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$ConfigPath = Join-Path $RepoRoot "terraform\config\wazuh-manager"
$ConfigGlob = Join-Path $ConfigPath "*"

if (-not (Test-Path $ConfigPath)) {
    throw "Wazuh manager config path not found: $ConfigPath"
}

Write-Host "Preparing remote config directory on $InstanceName..."
gcloud compute ssh $InstanceName `
    --project=$ProjectId `
    --zone=$Zone `
    --quiet `
    --command="sudo rm -rf /tmp/wazuh-manager && mkdir -p /tmp/wazuh-manager"

Write-Host "Copying Wazuh PYME Mexico configuration..."
gcloud compute scp `
    --project=$ProjectId `
    --zone=$Zone `
    --quiet `
    --recurse `
    "$ConfigGlob" `
    "${InstanceName}:/tmp/wazuh-manager/"

Write-Host "Applying configuration inside the Wazuh manager..."
gcloud compute ssh $InstanceName `
    --project=$ProjectId `
    --zone=$Zone `
    --quiet `
    --command="sudo chmod +x /tmp/wazuh-manager/deploy.sh && sudo /tmp/wazuh-manager/deploy.sh"

Write-Host "Configuration applied. Open the Wazuh dashboard and review rules 100010, 100015, 100020, 100030 and 100100-100204."
