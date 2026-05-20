[CmdletBinding()]
param(
    [ValidateSet("up", "down", "destroy", "status", "logs", "restart", "build", "pull")]
    [string]$Action = "up",

    [ValidateSet("Linux", "Windows", "All")]
    [string]$Scope = "Linux",

    [string]$WazuhManagerIp = "",

    [string]$ProjectId = "wazuh-iac-on-gcp",

    [string]$Region = "us-central1",

    [string]$Zone = "us-central1-a",

    [string]$TerraformDir = "terraform/wazuh-deploy",

    [string]$Service = "",

    [switch]$Follow
)

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$ExplicitWazuhManagerIp = if ($PSBoundParameters.ContainsKey("WazuhManagerIp")) { $WazuhManagerIp } else { "" }
Push-Location $RepoRoot

function Resolve-WazuhManagerIp {
    param([string]$ManualValue)

    if (-not [string]::IsNullOrWhiteSpace($ManualValue)) {
        return $ManualValue.Trim()
    }

    $gcloud = Get-Command gcloud -ErrorAction SilentlyContinue
    if ($gcloud) {
        try {
            $gcloudOutput = & gcloud compute instances describe wazuh-server --project=$ProjectId --zone=$Zone --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>$null
            if ($LASTEXITCODE -eq 0) {
                $value = ($gcloudOutput | Out-String).Trim()
                if (-not [string]::IsNullOrWhiteSpace($value)) {
                    return $value
                }
            }
        } catch {
        }

        try {
            $addressOutput = & gcloud compute addresses describe wazuh-server-public-ip --project=$ProjectId --region=$Region --format="value(address)" 2>$null
            if ($LASTEXITCODE -eq 0) {
                $value = ($addressOutput | Out-String).Trim()
                if (-not [string]::IsNullOrWhiteSpace($value)) {
                    return $value
                }
            }
        } catch {
        }
    }

    $terraform = Get-Command terraform -ErrorAction SilentlyContinue
    if ($terraform) {
        try {
            $terraformOutput = & terraform "-chdir=$TerraformDir" output -raw wazuh_manager_public_ip 2>$null
            if ($LASTEXITCODE -eq 0) {
                $value = ($terraformOutput | Out-String).Trim()
                if (-not [string]::IsNullOrWhiteSpace($value)) {
                    return $value
                }
            }
        } catch {
        }
    }

    if ($env:WAZUH_MANAGER_IP) {
        Write-Host "Aviso: usando WAZUH_MANAGER_IP del entorno porque no pude resolver la IP por gcloud/Terraform."
        return $env:WAZUH_MANAGER_IP.Trim()
    }

    throw "No encontre la IP publica de Wazuh. Ejecuta Terraform primero o usa -WazuhManagerIp X.X.X.X."
}

function Get-CurrentPublicIpCidr {
    $providers = @(
        "https://api.ipify.org",
        "https://ifconfig.me/ip"
    )

    foreach ($provider in $providers) {
        try {
            $ip = (Invoke-RestMethod -Uri $provider -TimeoutSec 10).ToString().Trim()
            if ($ip -match '^\d{1,3}(\.\d{1,3}){3}$') {
                return "$ip/32"
            }
        } catch {
        }
    }

    return ""
}

function Ensure-AgentFirewallAllowsCurrentIp {
    $gcloud = Get-Command gcloud -ErrorAction SilentlyContinue
    if (-not $gcloud) {
        Write-Host "Aviso: gcloud no disponible; no pude validar firewall de agentes."
        return
    }

    $cidr = Get-CurrentPublicIpCidr
    if ([string]::IsNullOrWhiteSpace($cidr)) {
        Write-Host "Aviso: no pude detectar tu IP publica; valida extra_agent_source_ranges o wazuh-agent-ingress manualmente."
        return
    }

    $rawRanges = & gcloud compute firewall-rules describe wazuh-agent-ingress --project=$ProjectId --format="value(sourceRanges)" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Aviso: no pude leer wazuh-agent-ingress; se intentara levantar Docker de todos modos."
        return
    }

    $ranges = @()
    foreach ($line in $rawRanges) {
        $ranges += ($line -split '[,;\s]+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }
    $ranges = @($ranges | Select-Object -Unique)

    if ($ranges -contains $cidr) {
        Write-Host "Firewall de agentes ya permite tu IP publica: $cidr"
        return
    }

    $updatedRanges = @($ranges + $cidr | Select-Object -Unique)
    Write-Host "Agregando $cidr a wazuh-agent-ingress para enrolamiento/telemetria de agentes locales."
    & gcloud compute firewall-rules update wazuh-agent-ingress --project=$ProjectId --source-ranges=($updatedRanges -join ",") --quiet
    if ($LASTEXITCODE -ne 0) {
        throw "No pude actualizar wazuh-agent-ingress con $cidr"
    }
}

function Invoke-Compose {
    param(
        [string]$ComposeFile,
        [string]$ActionName
    )

    $ComposeArgs = @("compose", "-f", $ComposeFile)

    switch ($ActionName) {
        "up" {
            $ComposeArgs += @("up", "-d", "--build")
        }
        "down" {
            $ComposeArgs += @("down", "--remove-orphans")
        }
        "destroy" {
            $ComposeArgs += @("down", "-v", "--remove-orphans")
        }
        "status" {
            $ComposeArgs += @("ps")
        }
        "logs" {
            $ComposeArgs += @("logs", "--tail", "120")
            if ($Follow) {
                $ComposeArgs += "-f"
            }
        }
        "restart" {
            $ComposeArgs += @("restart")
        }
        "build" {
            $ComposeArgs += @("build")
        }
        "pull" {
            $ComposeArgs += @("pull")
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($Service) -and $ActionName -in @("logs", "restart", "build", "pull")) {
        $ComposeArgs += $Service
    }

    Write-Host "Ejecutando: docker $($ComposeArgs -join ' ')"
    & docker @ComposeArgs
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

function Get-DockerEngineOsType {
    $osType = & docker info --format "{{.OSType}}" 2>$null
    if ($LASTEXITCODE -ne 0) {
        return ""
    }

    return ($osType | Out-String).Trim().ToLowerInvariant()
}

function Assert-DockerEngine {
    param([string]$ExpectedScope)

    $osType = Get-DockerEngineOsType
    if ([string]::IsNullOrWhiteSpace($osType)) {
        throw "No pude leer el tipo de engine de Docker. Verifica que Docker Desktop este corriendo."
    }

    if ($ExpectedScope -eq "Windows" -and $osType -ne "windows") {
        throw @"
Docker esta en modo '$osType'. Para levantar windows-server necesitas cambiar Docker Desktop a Windows containers.

Opciones:
1. Docker Desktop > menu del icono de Docker > Switch to Windows containers.
2. O intenta desde PowerShell:
   & "`$Env:ProgramFiles\Docker\Docker\DockerCli.exe" -SwitchDaemon

Luego vuelve a ejecutar:
   .\scripts\local-docker-lab.ps1 -Scope Windows -Action up
"@
    }

    if ($ExpectedScope -eq "Linux" -and $osType -ne "linux") {
        throw @"
Docker esta en modo '$osType'. Para levantar los endpoints Linux necesitas cambiar Docker Desktop a Linux containers.

Opciones:
1. Docker Desktop > menu del icono de Docker > Switch to Linux containers.
2. O intenta desde PowerShell:
   & "`$Env:ProgramFiles\Docker\Docker\DockerCli.exe" -SwitchDaemon

Luego vuelve a ejecutar:
   .\scripts\local-docker-lab.ps1 -Scope Linux -Action up
"@
    }
}

try {
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $docker) {
        throw "No encontre Docker en el PATH. Instala Docker Desktop antes de levantar el lab local."
    }

    $ResolvedManagerIp = Resolve-WazuhManagerIp -ManualValue $ExplicitWazuhManagerIp
    $env:WAZUH_MANAGER_IP = $ResolvedManagerIp
    Write-Host "Wazuh manager cloud: $ResolvedManagerIp"

    if ($Action -eq "up") {
        Ensure-AgentFirewallAllowsCurrentIp
    }

    if ($Scope -eq "Linux") {
        Assert-DockerEngine -ExpectedScope "Linux"
        Invoke-Compose -ComposeFile "docker-compose.endpoints.yml" -ActionName $Action
        return
    }

    if ($Scope -eq "Windows") {
        Assert-DockerEngine -ExpectedScope "Windows"
        Invoke-Compose -ComposeFile "docker-compose.windows.yml" -ActionName $Action
        return
    }

    if ($Action -in @("up", "build", "pull")) {
        Write-Host "Levantando endpoints Linux primero."
        Assert-DockerEngine -ExpectedScope "Linux"
        Invoke-Compose -ComposeFile "docker-compose.endpoints.yml" -ActionName $Action
        Write-Host ""
        Write-Host "Windows containers usan otro engine de Docker Desktop."
        Write-Host "Cambia Docker Desktop a 'Windows containers' y ejecuta:"
        Write-Host ".\scripts\local-docker-lab.ps1 -Scope Windows -Action $Action -WazuhManagerIp $ResolvedManagerIp"
        return
    }

    Assert-DockerEngine -ExpectedScope "Linux"
    Invoke-Compose -ComposeFile "docker-compose.endpoints.yml" -ActionName $Action
    Write-Host "Para operar el compose Windows, cambia Docker Desktop a Windows containers y usa -Scope Windows."
}
finally {
    Pop-Location
}
