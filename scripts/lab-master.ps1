[CmdletBinding()]
param(
    [ValidateSet(
        "menu",
        "status",
        "start-wazuh",
        "stop-wazuh",
        "apply-gcp",
        "destroy-gcp",
        "configure-wazuh",
        "start-linux",
        "stop-linux",
        "destroy-linux",
        "start-windows",
        "stop-windows",
        "destroy-windows",
        "start-local",
        "stop-local",
        "cost-saver",
        "full-start"
    )]
    [string]$Action = "menu",

    [string]$ProjectId = "wazuh-iac-on-gcp",
    [string]$Region = "us-central1",
    [string]$Zone = "us-central1-a",
    [string]$WazuhInstanceName = "wazuh-server",
    [string]$WazuhManagerIp = "",
    [string]$TerraformDir = "terraform/wazuh-deploy",
    [string]$DashboardUser = "admin",
    [string]$DashboardPassword = $env:WAZUH_DASHBOARD_PASSWORD,

    [switch]$Yes,
    [switch]$AutoApprove
)

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$LinuxComposeFile = "docker-compose.endpoints.yml"
$WindowsComposeFile = "docker-compose.windows.yml"
$ExplicitWazuhManagerIp = if ($PSBoundParameters.ContainsKey("WazuhManagerIp")) { $WazuhManagerIp } else { "" }

Push-Location $RepoRoot

function Test-Tool {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Invoke-CheckedCommand {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [switch]$AllowFailure
    )

    Write-Host "> $FilePath $($Arguments -join ' ')"
    & $FilePath @Arguments
    $code = $LASTEXITCODE
    if ($code -ne 0 -and -not $AllowFailure) {
        throw "$FilePath failed with exit code $code"
    }
    return $code
}

function Confirm-LabAction {
    param(
        [string]$Message,
        [switch]$DefaultNo
    )

    if ($Yes) {
        return $true
    }

    $suffix = if ($DefaultNo) { "[y/N]" } else { "[Y/n]" }
    $answer = Read-Host "$Message $suffix"
    if ([string]::IsNullOrWhiteSpace($answer)) {
        return -not $DefaultNo
    }

    return $answer.Trim().ToLowerInvariant() -in @("y", "yes", "s", "si")
}

function ConvertFrom-DockerJsonLines {
    param([string[]]$Lines)

    $text = ($Lines | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        return @()
    }

    try {
        if ($text.StartsWith("[")) {
            $parsed = $text | ConvertFrom-Json
            return @($parsed)
        }

        $items = @()
        foreach ($line in ($text -split "`r?`n")) {
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                $items += ($line | ConvertFrom-Json)
            }
        }
        return $items
    } catch {
        return @()
    }
}

function Get-DockerEngineOsType {
    if (-not (Test-Tool "docker")) {
        return ""
    }

    $osType = & docker info --format "{{.OSType}}" 2>$null
    if ($LASTEXITCODE -ne 0) {
        return ""
    }

    return ($osType | Out-String).Trim().ToLowerInvariant()
}

function Assert-DockerEngine {
    param([ValidateSet("linux", "windows")][string]$Expected)

    $osType = Get-DockerEngineOsType
    if ([string]::IsNullOrWhiteSpace($osType)) {
        throw "No pude leer Docker. Verifica que Docker Desktop este abierto."
    }

    if ($osType -ne $Expected) {
        $label = if ($Expected -eq "windows") { "Windows containers" } else { "Linux containers" }
        $switchCommand = '& "$Env:ProgramFiles\Docker\Docker\DockerCli.exe" -SwitchDaemon'
        throw "Docker esta en modo '$osType'. Para esta accion necesitas $label.`n`nCambia el engine en Docker Desktop o intenta:`n  $switchCommand"
    }
}

function Resolve-WazuhManagerIp {
    if (-not [string]::IsNullOrWhiteSpace($ExplicitWazuhManagerIp)) {
        return $ExplicitWazuhManagerIp.Trim()
    }

    if (Test-Tool "gcloud") {
        try {
            $gcloudOutput = & gcloud compute instances describe $WazuhInstanceName --project=$ProjectId --zone=$Zone --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>$null
            if ($LASTEXITCODE -eq 0) {
                $value = ($gcloudOutput | Out-String).Trim()
                if ($value) {
                    return $value
                }
            }
        } catch {
        }

        try {
            $addressOutput = & gcloud compute addresses describe wazuh-server-public-ip --project=$ProjectId --region=$Region --format="value(address)" 2>$null
            if ($LASTEXITCODE -eq 0) {
                $value = ($addressOutput | Out-String).Trim()
                if ($value) {
                    return $value
                }
            }
        } catch {
        }
    }

    if (Test-Tool "terraform") {
        try {
            $output = & terraform "-chdir=$TerraformDir" output -raw wazuh_manager_public_ip 2>$null
            if ($LASTEXITCODE -eq 0) {
                $value = ($output | Out-String).Trim()
                if ($value) {
                    return $value
                }
            }
        } catch {
        }
    }

    if ($env:WAZUH_MANAGER_IP) {
        Write-Host "Aviso: usando WAZUH_MANAGER_IP del entorno porque no pude resolver la IP por gcloud/Terraform."
        return $env:WAZUH_MANAGER_IP
    }

    return ""
}

function Sync-WazuhManagerIpEnv {
    $managerIp = Resolve-WazuhManagerIp
    if ($managerIp) {
        $env:WAZUH_MANAGER_IP = $managerIp
        Write-Host "Wazuh manager IP activa: $managerIp"
    }
    return $managerIp
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
    if (-not (Test-Tool "gcloud")) {
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

function Get-GcpLabInstances {
    if (-not (Test-Tool "gcloud")) {
        return [pscustomobject]@{
            Available = $false
            Error     = "gcloud no esta instalado o no esta en PATH"
            Items     = @()
        }
    }

    $args = @(
        "compute", "instances", "list",
        "--project=$ProjectId",
        "--filter=labels.solution=wazuh-pyme-mx",
        "--format=json(name,status,machineType,zone,networkInterfaces)"
    )

    try {
        $raw = & gcloud @args 2>$null
    } catch {
        return [pscustomobject]@{
            Available = $false
            Error     = "No pude consultar instancias GCP. Revisa login/proyecto/permisos locales de gcloud."
            Items     = @()
        }
    }

    if ($LASTEXITCODE -ne 0) {
        return [pscustomobject]@{
            Available = $false
            Error     = "No pude consultar instancias GCP. Revisa login/proyecto/permisos locales de gcloud."
            Items     = @()
        }
    }

    $items = @()
    $parsed = ($raw | Out-String).Trim()
    if ($parsed) {
        $items = @($parsed | ConvertFrom-Json)
    }

    return [pscustomobject]@{
        Available = $true
        Error     = ""
        Items     = $items
    }
}

function Get-ComposeStatus {
    param([string]$ComposeFile)

    if (-not (Test-Tool "docker")) {
        return [pscustomobject]@{
            Available = $false
            Error     = "docker no esta instalado o no esta en PATH"
            Items     = @()
        }
    }

    $raw = & docker compose -f $ComposeFile ps --format json 2>$null
    if ($LASTEXITCODE -ne 0) {
        return [pscustomobject]@{
            Available = $false
            Error     = "No pude consultar $ComposeFile en el engine Docker actual"
            Items     = @()
        }
    }

    return [pscustomobject]@{
        Available = $true
        Error     = ""
        Items     = @(ConvertFrom-DockerJsonLines -Lines $raw)
    }
}

function Get-RunningCount {
    param([object[]]$Items)

    $running = @($Items | Where-Object {
        ($_.State -and $_.State.ToString().ToLowerInvariant() -eq "running") -or
        ($_.Status -and $_.Status.ToString().ToLowerInvariant().StartsWith("up"))
    })

    return $running.Count
}

function Show-GcpStatus {
    $gcp = Get-GcpLabInstances
    if (-not $gcp.Available) {
        Write-Host "GCP: $($gcp.Error)"
        return
    }

    $running = @($gcp.Items | Where-Object { $_.status -eq "RUNNING" }).Count
    $total = @($gcp.Items).Count
    Write-Host "GCP lab VMs: $running corriendo / $total totales"

    if ($total -gt 0) {
        $rows = foreach ($item in $gcp.Items) {
            $machine = ($item.machineType -split "/")[-1]
            $itemZone = ($item.zone -split "/")[-1]
            $natIp = ""
            if ($item.networkInterfaces -and $item.networkInterfaces[0].accessConfigs) {
                $natIp = $item.networkInterfaces[0].accessConfigs[0].natIP
            }
            [pscustomobject]@{
                Name   = $item.name
                Status = $item.status
                Zone   = $itemZone
                Type   = $machine
                NatIp  = $natIp
            }
        }
        $rows | Sort-Object Name | Format-Table -AutoSize
    }
}

function Show-ComposeStatus {
    param(
        [string]$Title,
        [string]$ComposeFile
    )

    $status = Get-ComposeStatus -ComposeFile $ComposeFile
    if (-not $status.Available) {
        Write-Host "${Title}: $($status.Error)"
        return
    }

    $running = Get-RunningCount -Items $status.Items
    $total = @($status.Items).Count
    Write-Host "${Title}: $running corriendo / $total totales"

    if ($total -gt 0) {
        $rows = foreach ($item in $status.Items) {
            [pscustomobject]@{
                Service = $item.Service
                Name    = $item.Name
                State   = $item.State
                Status  = $item.Status
            }
        }
        $rows | Sort-Object Service | Format-Table -AutoSize
    }
}

function Show-LabStatus {
    Write-Host ""
    Write-Host "==== Wazuh Security Lab Master ===="
    Write-Host "Repo: $RepoRoot"
    Write-Host "GCP project/zone: $ProjectId / $Zone"

    $managerIp = Resolve-WazuhManagerIp
    if ($managerIp) {
        $env:WAZUH_MANAGER_IP = $managerIp
        Write-Host "Wazuh manager IP: $managerIp"
        Write-Host "Dashboard: https://$managerIp"
    } else {
        Write-Host "Wazuh manager IP: no detectada todavia"
    }

    $engine = Get-DockerEngineOsType
    if ($engine) {
        Write-Host "Docker engine activo: $engine"
    } else {
        Write-Host "Docker engine activo: no disponible"
    }

    Write-Host ""
    Show-GcpStatus
    Write-Host ""
    Show-ComposeStatus -Title "Docker Linux endpoints" -ComposeFile $LinuxComposeFile
    Write-Host ""
    if ($engine -eq "windows") {
        Show-ComposeStatus -Title "Docker Windows endpoint" -ComposeFile $WindowsComposeFile
    } else {
        Write-Host "Docker Windows endpoint: cambia Docker Desktop a Windows containers para consultar/operar ese compose."
    }
    Write-Host ""
}

function Invoke-Terraform {
    param([string[]]$TerraformArgs)
    Invoke-CheckedCommand -FilePath "terraform" -Arguments (@("-chdir=$TerraformDir") + $TerraformArgs)
}

function Start-WazuhGcp {
    Invoke-CheckedCommand -FilePath "gcloud" -Arguments @(
        "compute", "instances", "start", $WazuhInstanceName,
        "--project=$ProjectId",
        "--zone=$Zone",
        "--quiet"
    )
    $null = Sync-WazuhManagerIpEnv
}

function Stop-WazuhGcp {
    Invoke-CheckedCommand -FilePath "gcloud" -Arguments @(
        "compute", "instances", "stop", $WazuhInstanceName,
        "--project=$ProjectId",
        "--zone=$Zone",
        "--quiet"
    )
}

function Apply-GcpLab {
    Invoke-Terraform -TerraformArgs @("init")
    $args = @("apply")
    if ($AutoApprove -or $Yes) {
        $args += "-auto-approve"
    }
    Invoke-Terraform -TerraformArgs $args
}

function Destroy-GcpLab {
    Write-Host "Esto destruye la infraestructura Terraform en GCP."
    Write-Host "Ahorro maximo, pero elimina Wazuh, disco e IP estatica del manager."
    if (-not (Confirm-LabAction -Message "Seguro que quieres destruir GCP?" -DefaultNo)) {
        Write-Host "Cancelado."
        return
    }

    $args = @("destroy")
    if ($AutoApprove -or $Yes) {
        $args += "-auto-approve"
    }
    Invoke-Terraform -TerraformArgs $args
}

function Configure-WazuhManager {
    Invoke-CheckedCommand -FilePath ".\scripts\apply-wazuh-config.ps1" -Arguments @(
        "-ProjectId", $ProjectId,
        "-Zone", $Zone,
        "-InstanceName", $WazuhInstanceName
    )

    if ([string]::IsNullOrWhiteSpace($DashboardPassword)) {
        Write-Host "Dashboards no importados: define WAZUH_DASHBOARD_PASSWORD o usa -DashboardPassword."
        return
    }

    Invoke-CheckedCommand -FilePath ".\scripts\import-wazuh-dashboards.ps1" -Arguments @(
        "-ProjectId", $ProjectId,
        "-Zone", $Zone,
        "-DashboardUser", $DashboardUser,
        "-DashboardPassword", $DashboardPassword
    )
}

function Invoke-ComposeLab {
    param(
        [ValidateSet("Linux", "Windows")][string]$Scope,
        [ValidateSet("up", "down", "destroy", "ps")][string]$ComposeAction
    )

    $managerIp = Sync-WazuhManagerIpEnv

    if ($ComposeAction -eq "up") {
        Ensure-AgentFirewallAllowsCurrentIp
    }

    if ($Scope -eq "Linux") {
        Assert-DockerEngine -Expected "linux"
        $file = $LinuxComposeFile
    } else {
        Assert-DockerEngine -Expected "windows"
        $file = $WindowsComposeFile
    }

    $args = @("compose", "-f", $file)
    switch ($ComposeAction) {
        "up" {
            $args += @("up", "-d", "--build")
        }
        "down" {
            $args += @("down", "--remove-orphans")
        }
        "destroy" {
            if (-not (Confirm-LabAction -Message "Seguro que quieres borrar contenedores y volumenes $Scope?" -DefaultNo)) {
                Write-Host "Cancelado."
                return
            }
            $args += @("down", "-v", "--remove-orphans")
        }
        "ps" {
            $args += "ps"
        }
    }

    Invoke-CheckedCommand -FilePath "docker" -Arguments $args
}

function Stop-LocalContainers {
    $engine = Get-DockerEngineOsType
    if ($engine -eq "linux") {
        Invoke-ComposeLab -Scope Linux -ComposeAction down
        Write-Host "Para detener Windows containers, cambia Docker Desktop a Windows containers y usa -Action stop-windows."
    } elseif ($engine -eq "windows") {
        Invoke-ComposeLab -Scope Windows -ComposeAction down
        Write-Host "Para detener Linux containers, cambia Docker Desktop a Linux containers y usa -Action stop-linux."
    } else {
        Write-Host "Docker no disponible; no pude detener contenedores locales."
    }
}

function Invoke-CostSaver {
    Write-Host "Modo ahorro: detiene contenedores visibles en el engine actual y apaga Wazuh en GCP."
    Stop-LocalContainers
    Stop-WazuhGcp
    Write-Host "Costo minimo sin destruir: quedan costos pequenos de disco/IP estatica. Para ahorro maximo usa -Action destroy-gcp."
}

function Start-FullLab {
    Start-WazuhGcp
    Write-Host "Esperando 45 segundos para que Wazuh/Docker despierten..."
    Start-Sleep -Seconds 45
    $null = Sync-WazuhManagerIpEnv
    Invoke-ComposeLab -Scope Linux -ComposeAction up
    Write-Host "Windows requiere cambiar Docker Desktop a Windows containers y correr -Action start-windows."
}

function Show-Menu {
    while ($true) {
        Show-LabStatus
        Write-Host "Opciones:"
        Write-Host "  1. Refrescar status"
        Write-Host "  2. Encender Wazuh GCP"
        Write-Host "  3. Apagar Wazuh GCP"
        Write-Host "  4. Crear/reparar GCP con Terraform apply"
        Write-Host "  5. Destruir GCP con Terraform destroy"
        Write-Host "  6. Aplicar config/reglas/dashboards Wazuh"
        Write-Host "  7. Encender contenedores Linux"
        Write-Host "  8. Apagar contenedores Linux"
        Write-Host "  9. Destruir contenedores Linux"
        Write-Host " 10. Encender contenedor Windows"
        Write-Host " 11. Apagar contenedor Windows"
        Write-Host " 12. Destruir contenedor Windows"
        Write-Host " 13. Modo ahorro: apagar local + apagar Wazuh"
        Write-Host " 14. Encender lab principal: Wazuh + Linux"
        Write-Host "  0. Salir"

        $choice = Read-Host "Elige"
        switch ($choice) {
            "1" { continue }
            "2" { Start-WazuhGcp }
            "3" { Stop-WazuhGcp }
            "4" { Apply-GcpLab }
            "5" { Destroy-GcpLab }
            "6" { Configure-WazuhManager }
            "7" { Invoke-ComposeLab -Scope Linux -ComposeAction up }
            "8" { Invoke-ComposeLab -Scope Linux -ComposeAction down }
            "9" { Invoke-ComposeLab -Scope Linux -ComposeAction destroy }
            "10" { Invoke-ComposeLab -Scope Windows -ComposeAction up }
            "11" { Invoke-ComposeLab -Scope Windows -ComposeAction down }
            "12" { Invoke-ComposeLab -Scope Windows -ComposeAction destroy }
            "13" { Invoke-CostSaver }
            "14" { Start-FullLab }
            "0" { return }
            default { Write-Host "Opcion no valida." }
        }

        Write-Host ""
        Read-Host "Presiona Enter para continuar"
    }
}

try {
    switch ($Action) {
        "menu" { Show-Menu }
        "status" { Show-LabStatus }
        "start-wazuh" { Start-WazuhGcp }
        "stop-wazuh" { Stop-WazuhGcp }
        "apply-gcp" { Apply-GcpLab }
        "destroy-gcp" { Destroy-GcpLab }
        "configure-wazuh" { Configure-WazuhManager }
        "start-linux" { Invoke-ComposeLab -Scope Linux -ComposeAction up }
        "stop-linux" { Invoke-ComposeLab -Scope Linux -ComposeAction down }
        "destroy-linux" { Invoke-ComposeLab -Scope Linux -ComposeAction destroy }
        "start-windows" { Invoke-ComposeLab -Scope Windows -ComposeAction up }
        "stop-windows" { Invoke-ComposeLab -Scope Windows -ComposeAction down }
        "destroy-windows" { Invoke-ComposeLab -Scope Windows -ComposeAction destroy }
        "start-local" { Invoke-ComposeLab -Scope Linux -ComposeAction up }
        "stop-local" { Stop-LocalContainers }
        "cost-saver" { Invoke-CostSaver }
        "full-start" { Start-FullLab }
    }
}
finally {
    Pop-Location
}
