[CmdletBinding()]
param(
    [ValidateSet("up", "down", "restart", "status", "logs", "import-workflow", "import-alert-workflow", "import-workflows", "run-triage", "run-alert-tickets")]
    [string]$Action = "status",

    [switch]$Follow
)

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$ComposeFile = Join-Path $RepoRoot "docker-compose.n8n.yml"
$EnvFile = Join-Path $RepoRoot "integrations\n8n\.env"
$EnvExample = Join-Path $RepoRoot "integrations\n8n\.env.example"
$WorkflowPath = "/home/node/.n8n/workflows/wazuh-vulnerability-triage.workflow.json"
$AlertWorkflowPath = "/home/node/.n8n/workflows/wazuh-alert-jira-tickets.workflow.json"
$TriageScript = "/home/node/.n8n/scripts/wazuh-vulnerability-triage.js"
$AlertScript = "/home/node/.n8n/scripts/wazuh-alert-jira-tickets.js"

function Test-Tool {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Assert-Docker {
    if (-not (Test-Tool "docker")) {
        throw "Docker no esta disponible en PATH. Instala o abre Docker Desktop."
    }
}

function Ensure-EnvFile {
    if (-not (Test-Path $EnvFile)) {
        Copy-Item -Path $EnvExample -Destination $EnvFile
        Write-Host "Creado integrations\n8n\.env desde .env.example."
        Write-Host "Edita ese archivo antes de activar Jira o usar credenciales reales."
    }
}

function Invoke-Compose {
    param([string[]]$ComposeArgs)
    Push-Location $RepoRoot
    try {
        & docker compose -f $ComposeFile @ComposeArgs
        if ($LASTEXITCODE -ne 0) {
            throw "docker compose fallo con codigo $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}

Assert-Docker

switch ($Action) {
    "up" {
        Ensure-EnvFile
        Invoke-Compose -ComposeArgs @("up", "-d")
        Write-Host "n8n disponible en http://localhost:5678"
    }
    "down" {
        Invoke-Compose -ComposeArgs @("down")
    }
    "restart" {
        Ensure-EnvFile
        Invoke-Compose -ComposeArgs @("restart")
    }
    "status" {
        Invoke-Compose -ComposeArgs @("ps")
    }
    "logs" {
        $composeArgs = @("logs", "n8n")
        if ($Follow) { $composeArgs += "-f" }
        Invoke-Compose -ComposeArgs $composeArgs
    }
    "import-workflow" {
        Ensure-EnvFile
        Invoke-Compose -ComposeArgs @("up", "-d")
        Invoke-Compose -ComposeArgs @("exec", "-T", "n8n", "n8n", "import:workflow", "--input=$WorkflowPath")
        Write-Host "Workflow importado. Abre http://localhost:5678 y revisa: Wazuh Vulnerability Triage - KEV EPSS Jira"
    }
    "import-alert-workflow" {
        Ensure-EnvFile
        Invoke-Compose -ComposeArgs @("up", "-d")
        Invoke-Compose -ComposeArgs @("exec", "-T", "n8n", "n8n", "import:workflow", "--input=$AlertWorkflowPath")
        Write-Host "Workflow importado. Abre http://localhost:5678 y revisa: Wazuh Alert Jira Tickets - P1 P2 P3"
    }
    "import-workflows" {
        Ensure-EnvFile
        Invoke-Compose -ComposeArgs @("up", "-d")
        Invoke-Compose -ComposeArgs @("exec", "-T", "n8n", "n8n", "import:workflow", "--input=$WorkflowPath")
        Invoke-Compose -ComposeArgs @("exec", "-T", "n8n", "n8n", "import:workflow", "--input=$AlertWorkflowPath")
        Write-Host "Workflows importados: vulnerabilidades y alertas P1/P2/P3 hacia Jira."
    }
    "run-triage" {
        Ensure-EnvFile
        Invoke-Compose -ComposeArgs @("up", "-d")
        Invoke-Compose -ComposeArgs @("exec", "-T", "n8n", "node", $TriageScript)
        Write-Host "Evidencia generada en integrations\n8n\output."
    }
    "run-alert-tickets" {
        Ensure-EnvFile
        Invoke-Compose -ComposeArgs @("up", "-d")
        Invoke-Compose -ComposeArgs @("exec", "-T", "n8n", "node", $AlertScript)
        Write-Host "Evidencia de alertas/Jira generada en integrations\n8n\output."
    }
}
