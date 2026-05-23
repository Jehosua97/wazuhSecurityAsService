param(
    [string]$DemoRoot = "C:\AD-Demo\ModuleDemo",
    [string]$AgentRoot = "${env:ProgramFiles(x86)}\ossec-agent",
    [switch]$IncludeNarrativeOnlyModules,
    [switch]$AllowLocalActiveResponseFallback,
    [int]$ActiveResponseWaitSeconds = 20
)

$ErrorActionPreference = "Stop"

if (-not $PSBoundParameters.ContainsKey("IncludeNarrativeOnlyModules")) {
    $IncludeNarrativeOnlyModules = $true
}

if (-not $PSBoundParameters.ContainsKey("AllowLocalActiveResponseFallback")) {
    $AllowLocalActiveResponseFallback = $true
}

$LogsDir = Join-Path $DemoRoot "Logs"
$ConfigDir = Join-Path $DemoRoot "Config"
$EvidenceDir = Join-Path $DemoRoot "Evidence"
$ScriptsDir = Join-Path $DemoRoot "Scripts"

$ModuleLog = Join-Path $LogsDir "module-demo.log"
$CloudLog = Join-Path $LogsDir "cloud-gcp-demo.log"
$BaselineFile = Join-Path $ConfigDir "module-baseline.conf"
$ScaExceptionFile = Join-Path $ConfigDir "sca-demo-exception.txt"
$SummaryFile = Join-Path $EvidenceDir ("module-demo-summary-{0}.json" -f (Get-Date -Format "yyyyMMddHHmmss"))
$ActiveResponseScript = Join-Path $AgentRoot "active-response\bin\module-demo-response.ps1"
$EventSource = "WazuhWindowsModuleDemo"

function Ensure-Directory {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

function Append-AsciiLine {
    param(
        [string]$Path,
        [string]$Value
    )

    $encoding = [System.Text.ASCIIEncoding]::new()
    $bytes = $encoding.GetBytes($Value + [Environment]::NewLine)
    $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)

    try {
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush()
    } finally {
        $stream.Dispose()
    }
}

function Write-SyslogLine {
    param(
        [string]$Path,
        [string]$Program,
        [string]$Message
    )

    $culture = [Globalization.CultureInfo]::InvariantCulture
    $timestamp = (Get-Date).ToString("MMM dd HH:mm:ss", $culture)
    $line = "$timestamp $env:COMPUTERNAME $Program`: $Message"

    for ($attempt = 1; $attempt -le 10; $attempt++) {
        try {
            Append-AsciiLine -Path $Path -Value $line
            return
        } catch {
            if ($attempt -eq 10) {
                throw
            }

            Start-Sleep -Milliseconds 500
        }
    }
}

function Write-ModuleLine {
    param(
        [string]$Module,
        [string]$Action,
        [string]$Detail
    )

    Write-SyslogLine -Path $ModuleLog -Program "wazuh-module-demo" -Message "module=$Module action=$Action detail=$Detail"
}

function Write-GcpLine {
    param(
        [string]$Action,
        [string]$Detail
    )

    Write-SyslogLine -Path $CloudLog -Program "gcp-demo" -Message "module=cloud_security action=$Action detail=$Detail"
}

function Ensure-EventSource {
    if (-not [System.Diagnostics.EventLog]::SourceExists($EventSource)) {
        New-EventLog -LogName Application -Source $EventSource
    }
}

function Write-DemoEvent {
    param(
        [int]$EventId,
        [string]$EntryType,
        [string]$Action,
        [string]$Detail
    )

    Write-EventLog -LogName Application -Source $EventSource -EntryType $EntryType -EventId $EventId -Message "wazuh-module-demo: action=$Action detail=$Detail"
}

Ensure-Directory -Path $LogsDir
Ensure-Directory -Path $ConfigDir
Ensure-Directory -Path $EvidenceDir
Ensure-EventSource

if (-not (Test-Path -LiteralPath $BaselineFile)) {
    Set-Content -Path $BaselineFile -Value "created_by=Generate-WindowsWazuhModulesDemo.ps1" -Encoding ASCII
}

Add-Content -Path $BaselineFile -Value "last_demo_run=$(Get-Date -Format o)" -Encoding ASCII
Set-Content -Path $ScaExceptionFile -Value "intentional_demo_drift=$(Get-Date -Format o)" -Encoding ASCII
Set-Content -Path (Join-Path $EvidenceDir "sensitive-access-review.txt") -Value "reviewed_at=$(Get-Date -Format o)`nreviewer=soc-demo" -Encoding ASCII

Write-DemoEvent -EventId 5201 -EntryType Information -Action "log_collector_application_event" -Detail "channel=Application outcome=simulated"
Write-DemoEvent -EventId 5202 -EntryType Warning -Action "fim_baseline_change" -Detail "file=$BaselineFile outcome=simulated"
Write-DemoEvent -EventId 5203 -EntryType Information -Action "sca_intentional_drift" -Detail "file=$ScaExceptionFile outcome=expected_demo_failure"

Write-ModuleLine -Module "log_collector" -Action "eventchannel_and_flatlog_ready" -Detail "channels=Application|Microsoft-Windows-PowerShell/Operational file=$ModuleLog"
Write-ModuleLine -Module "fim" -Action "baseline_file_changed" -Detail "file=$BaselineFile"
Write-ModuleLine -Module "sca" -Action "custom_policy_expected" -Detail "policy=wazuh_demo_windows_sca.yml intentional_fail_marker=$ScaExceptionFile"
Write-ModuleLine -Module "syscollector" -Action "inventory_scan_expected" -Detail "tables=os,network,packages,ports,processes"
Write-ModuleLine -Module "malware_detection" -Action "rootcheck_scan_expected" -Detail "safe_demo=no_malware_created"
Write-ModuleLine -Module "vulnerability_detection" -Action "manager_uses_inventory" -Detail "source=syscollector_packages"

$containerService = Get-Service -Name "docker" -ErrorAction SilentlyContinue
if ($IncludeNarrativeOnlyModules) {
    if ($containerService) {
        Write-ModuleLine -Module "container_security" -Action "docker_listener_expected" -Detail "service=docker state=$($containerService.Status)"
    } else {
        Write-ModuleLine -Module "container_security" -Action "telemetry_narrative_only" -Detail "docker_engine=not_present native_scope=docker-host"
    }

    Write-GcpLine -Action "iam_policy_change" -Detail "project=wazuh-iac-on-gcp actor=demo-admin resource=service-account outcome=simulated"
    Write-GcpLine -Action "compute_instance_stop" -Detail "project=wazuh-iac-on-gcp instance=legacy-demo-vm outcome=simulated"
}

$beforeEvidence = @(Get-ChildItem -Path $EvidenceDir -Filter "active-response-*.json" -ErrorAction SilentlyContinue).Count
Write-ModuleLine -Module "active_response" -Action "trigger_windows_safe_response" -Detail "response=windows-module-demo-response evidence_only=true"

if ($AllowLocalActiveResponseFallback) {
    Start-Sleep -Seconds $ActiveResponseWaitSeconds
    $afterEvidence = @(Get-ChildItem -Path $EvidenceDir -Filter "active-response-*.json" -ErrorAction SilentlyContinue).Count

    if ($afterEvidence -le $beforeEvidence -and (Test-Path -LiteralPath $ActiveResponseScript)) {
        & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $ActiveResponseScript -Origin "local_fallback" -RuleId "100316" -Action "trigger_windows_safe_response" -DemoRoot $DemoRoot
    }
}

$summary = [ordered]@{
    timestamp_utc = (Get-Date).ToUniversalTime().ToString("o")
    host = $env:COMPUTERNAME
    agent_name = "ad2016-dc01"
    scope = "windows-server-demo"
    native_modules = @(
        "log_collector",
        "command",
        "fim",
        "sca",
        "syscollector",
        "malware_detection",
        "active_response"
    )
    narrative_modules = @(
        "container_security",
        "cloud_security",
        "vulnerability_detection"
    )
    note = "Container and cloud signals from this Windows VM are safe narrative events. Native collection lives in docker-host and cloud integrations."
}

$summary | ConvertTo-Json -Depth 6 | Set-Content -Path $SummaryFile -Encoding ASCII

Write-Output "Windows Wazuh module demo generated."
Write-Output "Evidence folder: $EvidenceDir"
Write-Output "Summary: $SummaryFile"
