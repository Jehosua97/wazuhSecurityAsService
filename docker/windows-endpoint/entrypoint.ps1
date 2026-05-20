$ErrorActionPreference = "Stop"

$WazuhManager = $env:WAZUH_MANAGER_IP
if ([string]::IsNullOrWhiteSpace($WazuhManager)) {
    throw "WAZUH_MANAGER_IP is required"
}

$AgentName = if ($env:WAZUH_AGENT_NAME) { $env:WAZUH_AGENT_NAME } else { "windows-server" }
$WazuhVersion = if ($env:WAZUH_VERSION) { $env:WAZUH_VERSION } else { "4.13.0-1" }
$DemoDir = "C:\ProgramData\WazuhDemo"
$DemoLog = Join-Path $DemoDir "windows-demo.log"
$DemoScript = Join-Path $DemoDir "Generate-WindowsDemoEvents.ps1"
$EventSource = "WazuhWindowsDemo"
$AgentConfig = "C:\Program Files (x86)\ossec-agent\ossec.conf"

New-Item -ItemType Directory -Path $DemoDir -Force | Out-Null

function Write-SetupLog {
    param([string]$Message)

    $line = "$(Get-Date -Format s) $Message"
    Add-Content -Path $DemoLog -Value $line
    Write-Output $line
}

function Wait-WazuhManager {
    for ($attempt = 1; $attempt -le 90; $attempt++) {
        try {
            $tcp = New-Object Net.Sockets.TcpClient
            $async = $tcp.BeginConnect($WazuhManager, 1515, $null, $null)
            if ($async.AsyncWaitHandle.WaitOne(2000, $false)) {
                $tcp.EndConnect($async)
                $tcp.Close()
                Write-SetupLog "Wazuh manager authd is reachable."
                return
            }
            $tcp.Close()
        } catch {
        }

        Write-SetupLog "Waiting for Wazuh manager authd on ${WazuhManager}:1515 (attempt $attempt/90)..."
        Start-Sleep -Seconds 10
    }

    throw "Timed out waiting for Wazuh manager authd."
}

function Ensure-EventSource {
    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists($EventSource)) {
            New-EventLog -LogName Application -Source $EventSource
        }
        return $true
    } catch {
        Write-SetupLog "Could not create event source in this Windows container: $($_.Exception.Message)"
        return $false
    }
}

function Install-WazuhAgent {
    $service = Get-Service -Name "WazuhSvc" -ErrorAction SilentlyContinue
    if ($service) {
        Write-SetupLog "Wazuh Windows agent service already exists."
        return
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $installer = Join-Path $env:TEMP "wazuh-agent-$WazuhVersion.msi"
    $packageUrl = "https://packages.wazuh.com/4.x/windows/wazuh-agent-$WazuhVersion.msi"

    Write-SetupLog "Downloading Wazuh Windows agent from $packageUrl"
    Invoke-WebRequest -Uri $packageUrl -OutFile $installer -UseBasicParsing

    $arguments = "/i `"$installer`" /qn WAZUH_MANAGER=`"$WazuhManager`" WAZUH_REGISTRATION_SERVER=`"$WazuhManager`" WAZUH_AGENT_NAME=`"$AgentName`""
    Write-SetupLog "Installing Wazuh Windows agent"
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $arguments -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "Wazuh Windows agent installer failed with exit code $($process.ExitCode)"
    }
}

function Configure-WazuhAgent {
    if (-not (Test-Path $AgentConfig)) {
        Write-SetupLog "Wazuh agent config not found yet: $AgentConfig"
        return
    }

    $config = Get-Content -Path $AgentConfig -Raw
    if ($config -notmatch "LOCAL_DOCKER_WINDOWS_DEMO_START") {
        $block = @"
  <!-- LOCAL_DOCKER_WINDOWS_DEMO_START -->
  <localfile>
    <log_format>eventchannel</log_format>
    <location>Application</location>
  </localfile>
  <localfile>
    <log_format>syslog</log_format>
    <location>C:\ProgramData\WazuhDemo\windows-demo.log</location>
  </localfile>
  <syscheck>
    <disabled>no</disabled>
    <frequency>300</frequency>
    <scan_on_start>yes</scan_on_start>
    <alert_new_files>yes</alert_new_files>
    <directories realtime="yes" report_changes="yes">C:\ProgramData\WazuhDemo</directories>
  </syscheck>
  <!-- LOCAL_DOCKER_WINDOWS_DEMO_END -->
"@
        $config = $config -replace "</ossec_config>", "$block`r`n</ossec_config>"
        Set-Content -Path $AgentConfig -Value $config -Encoding ASCII
    }
}

function Write-DemoScript {
    $scriptContent = @'
$ErrorActionPreference = "Stop"

$DemoDir = "C:\ProgramData\WazuhDemo"
$DemoLog = Join-Path $DemoDir "windows-demo.log"
$EvidenceFile = Join-Path $DemoDir "customer-access-review.txt"
$EventSource = "WazuhWindowsDemo"

New-Item -ItemType Directory -Path $DemoDir -Force | Out-Null

function Emit-DemoEvent {
    param(
        [int]$EventId,
        [string]$EntryType,
        [string]$Message
    )

    $culture = [Globalization.CultureInfo]::InvariantCulture
    $syslogTime = (Get-Date).ToString("MMM dd HH:mm:ss", $culture)
    $line = "$syslogTime windows-server windows-lab: $Message"
    Add-Content -Path $DemoLog -Value $line
    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists($EventSource)) {
            New-EventLog -LogName Application -Source $EventSource
        }
        Write-EventLog -LogName Application -Source $EventSource -EntryType $EntryType -EventId $EventId -Message "windows-lab: $Message"
    } catch {
        Add-Content -Path $DemoLog -Value "$(Get-Date -Format s) windows-lab: eventlog_write_failed detail=$($_.Exception.Message)"
    }
}

Emit-DemoEvent -EventId 4201 -EntryType Warning -Message "action=failed_login detail=user=legacy-admin src=172.30.50.11 outcome=simulated"
Emit-DemoEvent -EventId 4202 -EntryType Warning -Message "action=privileged_process detail=process=powershell.exe user=Administrator outcome=simulated"
Emit-DemoEvent -EventId 4203 -EntryType Information -Message "action=configuration_change detail=object=windows_firewall profile=domain outcome=simulated"

Add-Content -Path $EvidenceFile -Value "reviewed_at=$(Get-Date -Format o) reviewer=soc-demo"
'@

    Set-Content -Path $DemoScript -Value $scriptContent -Encoding ASCII
}

Write-SetupLog "Starting local Docker Windows endpoint. Manager=$WazuhManager Agent=$AgentName Version=$WazuhVersion"
Wait-WazuhManager
Install-WazuhAgent
Configure-WazuhAgent
Set-Service -Name "WazuhSvc" -StartupType Automatic
Start-Service -Name "WazuhSvc" -ErrorAction SilentlyContinue

[void](Ensure-EventSource)
Write-DemoScript
powershell.exe -NoLogo -ExecutionPolicy Bypass -File $DemoScript

Write-SetupLog "Windows Server Docker endpoint is ready."

while ($true) {
    Start-Sleep -Seconds 60
    Write-SetupLog "heartbeat agent=$AgentName manager=$WazuhManager"
}
