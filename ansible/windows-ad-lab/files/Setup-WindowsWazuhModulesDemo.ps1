param(
    [string]$DemoRoot = "C:\AD-Demo\ModuleDemo",
    [string]$AgentRoot = "${env:ProgramFiles(x86)}\ossec-agent",
    [bool]$RunInitialDemo = $true
)

$ErrorActionPreference = "Stop"

$LogsDir = Join-Path $DemoRoot "Logs"
$ConfigDir = Join-Path $DemoRoot "Config"
$EvidenceDir = Join-Path $DemoRoot "Evidence"
$ScriptsDir = Join-Path $DemoRoot "Scripts"

$ModuleLog = Join-Path $LogsDir "module-demo.log"
$CloudLog = Join-Path $LogsDir "cloud-gcp-demo.log"
$BaselineFile = Join-Path $ConfigDir "module-baseline.conf"
$ScaPolicyPath = Join-Path $AgentRoot "etc\shared\wazuh_demo_windows_sca.yml"
$OssecConfigPath = Join-Path $AgentRoot "ossec.conf"
$TriggerScriptSource = Join-Path $PSScriptRoot "Generate-WindowsWazuhModulesDemo.ps1"
$TriggerScriptPath = Join-Path $ScriptsDir "Generate-WindowsWazuhModulesDemo.ps1"
$DiskCommandScriptPath = Join-Path $ScriptsDir "Get-WazuhDemoDisk.ps1"
$AdminsCommandScriptPath = Join-Path $ScriptsDir "Get-WazuhDemoPrivilegedAccounts.ps1"
$ActiveResponseCmdPath = Join-Path $AgentRoot "active-response\bin\module-demo-response.cmd"
$ActiveResponsePsPath = Join-Path $AgentRoot "active-response\bin\module-demo-response.ps1"
$DesktopLauncherPath = "C:\Users\Public\Desktop\Run-Wazuh-Modules-Demo.cmd"
$RunbookPath = Join-Path $DemoRoot "DEMO-RUNBOOK.txt"

function Ensure-Directory {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

function Write-Status {
    param([string]$Message)

    Write-Output ("[{0}] {1}" -f (Get-Date -Format s), $Message)
}

function Set-ManagedOssecBlock {
    param(
        [string]$Marker,
        [string]$Body
    )

    if (-not (Test-Path -LiteralPath $OssecConfigPath)) {
        throw "Wazuh agent config not found at $OssecConfigPath"
    }

    $text = Get-Content -Path $OssecConfigPath -Raw
    $escapedMarker = [Regex]::Escape($Marker)
    $pattern = "(?s)\r?\n?<!-- $escapedMarker START -->.*?<!-- $escapedMarker END -->\r?\n?"
    $text = [Regex]::Replace($text, $pattern, [Environment]::NewLine)

    $rootClosingTag = "</ossec_config>"
    $rootClosingIndex = $text.LastIndexOf($rootClosingTag)
    if ($rootClosingIndex -lt 0) {
        throw "Could not find the root </ossec_config> tag in $OssecConfigPath"
    }

    $block = @"
  <!-- $Marker START -->
$Body
  <!-- $Marker END -->
"@

    $text = $text.Insert($rootClosingIndex, [Environment]::NewLine + $block + [Environment]::NewLine)
    Set-Content -Path $OssecConfigPath -Value $text -Encoding ASCII
}

function New-HelperScripts {
    $diskScript = @'
$ErrorActionPreference = "Stop"

$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
if (-not $disk) {
    throw "Drive C: not found."
}

$freeGb = [math]::Round($disk.FreeSpace / 1GB, 2)
$totalGb = [math]::Round($disk.Size / 1GB, 2)
$pctFree = if ($disk.Size -gt 0) {
    [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 2)
} else {
    0
}

Write-Output "wazuh_demo_disk module=command action=disk_space_check drive=C: free_gb=$freeGb total_gb=$totalGb pct_free=$pctFree"
'@

    $adminsScript = @'
$ErrorActionPreference = "Stop"

$members = @()

try {
    Import-Module ActiveDirectory -ErrorAction Stop
    $members = Get-ADGroupMember -Identity "Domain Admins" -Recursive -ErrorAction Stop |
        Select-Object -ExpandProperty SamAccountName
    $groupName = "Domain_Admins"
} catch {
    try {
        $members = Get-LocalGroupMember -Group "Administrators" -ErrorAction Stop |
            Select-Object -ExpandProperty Name
        $groupName = "Administrators"
    } catch {
        $members = @("Administrator")
        $groupName = "Administrators"
    }
}

$members = @($members | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$count = $members.Count
$sample = if ($count -gt 0) {
    ($members | Select-Object -First 5) -join ";"
} else {
    "none"
}

Write-Output "wazuh_demo_admins module=command action=privileged_group_inventory group=$groupName members=$count sample=$sample"
'@

    $activeResponsePowerShell = @'
param(
    [string]$InputFile = "",
    [string]$Origin = "manager_trigger",
    [string]$RuleId = "",
    [string]$Action = "trigger_windows_safe_response",
    [string]$DemoRoot = "C:\AD-Demo\ModuleDemo"
)

$ErrorActionPreference = "Stop"

$LogsDir = Join-Path $DemoRoot "Logs"
$EvidenceDir = Join-Path $DemoRoot "Evidence"
$ModuleLog = Join-Path $LogsDir "module-demo.log"

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
        [string]$Program,
        [string]$Message
    )

    $culture = [Globalization.CultureInfo]::InvariantCulture
    $timestamp = (Get-Date).ToString("MMM dd HH:mm:ss", $culture)

    for ($attempt = 1; $attempt -le 10; $attempt++) {
        try {
            Append-AsciiLine -Path $ModuleLog -Value "$timestamp $env:COMPUTERNAME $Program`: $Message"
            return
        } catch {
            if ($attempt -eq 10) {
                throw
            }

            Start-Sleep -Milliseconds 500
        }
    }
}

Ensure-Directory -Path $LogsDir
Ensure-Directory -Path $EvidenceDir

$payload = $null
if ($InputFile -and (Test-Path -LiteralPath $InputFile)) {
    $raw = Get-Content -Path $InputFile -Raw
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        try {
            $payload = $raw | ConvertFrom-Json -ErrorAction Stop
        } catch {
            $payload = @{ raw = $raw }
        }
    }
}

if (-not $RuleId -and $payload.parameters.alert.rule.id) {
    $RuleId = [string]$payload.parameters.alert.rule.id
}

$stamp = Get-Date -Format "yyyyMMddHHmmss"
$evidenceFile = Join-Path $EvidenceDir "active-response-$stamp.json"
$evidence = [ordered]@{
    timestamp_utc = (Get-Date).ToUniversalTime().ToString("o")
    host = $env:COMPUTERNAME
    origin = $Origin
    action = $Action
    rule_id = $RuleId
    payload = $payload
    note = "Safe Active Response evidence only. No network blocking or process termination performed."
}

$evidence | ConvertTo-Json -Depth 12 | Set-Content -Path $evidenceFile -Encoding ASCII

$detail = "file=$evidenceFile origin=$Origin"
if ($RuleId) {
    $detail += " rule_id=$RuleId"
}

Write-SyslogLine -Program "wazuh-module-demo" -Message "module=active_response action=evidence_collected detail=$detail"
'@

    $activeResponseCmd = @'
@echo off
setlocal
set "AR_INPUT=%TEMP%\module-demo-response-input.json"
more > "%AR_INPUT%"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0module-demo-response.ps1" -InputFile "%AR_INPUT%" -Origin manager_trigger >nul 2>&1
del "%AR_INPUT%" >nul 2>&1
exit /b 0
'@

    Set-Content -Path $DiskCommandScriptPath -Value $diskScript -Encoding ASCII
    Set-Content -Path $AdminsCommandScriptPath -Value $adminsScript -Encoding ASCII
    Set-Content -Path $ActiveResponsePsPath -Value $activeResponsePowerShell -Encoding ASCII
    Set-Content -Path $ActiveResponseCmdPath -Value $activeResponseCmd -Encoding ASCII
}

function New-ScaPolicy {
    $scaPolicy = @'
policy:
  id: "wazuh_demo_windows_modules"
  file: "wazuh_demo_windows_sca.yml"
  name: "Wazuh demo - Windows module baseline"
  description: "Safe checks for the Windows Server module visibility demonstration."
  references:
    - "https://documentation.wazuh.com/current/user-manual/capabilities/sec-config-assessment/"

requirements:
  title: "Windows endpoint"
  description: "Run only on Windows systems."
  condition: all
  rules:
    - 'r:HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion -> ProductName'

checks:
  - id: 210001
    title: "Module demo baseline file exists"
    description: "The controlled baseline file used for the Windows Wazuh module demo must exist."
    rationale: "The demo should be deterministic and auditable."
    remediation: "Run the setup script again to recreate the baseline."
    condition: all
    rules:
      - 'f:C:\AD-Demo\ModuleDemo\Config\module-baseline.conf'

  - id: 210002
    title: "Module demo log exists"
    description: "The Windows endpoint keeps a dedicated flat log for controlled module evidence."
    rationale: "This log powers the visual narrative in the dashboard."
    remediation: "Run the trigger script to recreate module-demo.log."
    condition: all
    rules:
      - 'f:C:\AD-Demo\ModuleDemo\Logs\module-demo.log'

  - id: 210003
    title: "Cloud narrative log exists"
    description: "The Windows endpoint keeps a dedicated cloud narrative log for safe visual telemetry."
    rationale: "The demo should surface a clear artifact for cloud monitoring conversations."
    remediation: "Run the trigger script to recreate cloud-gcp-demo.log."
    condition: all
    rules:
      - 'f:C:\AD-Demo\ModuleDemo\Logs\cloud-gcp-demo.log'

  - id: 210004
    title: "Intentional SCA drift marker should not exist"
    description: "This check intentionally fails after running the trigger script so the client can see a visible SCA finding."
    rationale: "A controlled failure makes configuration drift easy to explain live."
    remediation: 'Delete C:\AD-Demo\ModuleDemo\Config\sca-demo-exception.txt after the demo.'
    condition: none
    rules:
      - 'f:C:\AD-Demo\ModuleDemo\Config\sca-demo-exception.txt'
'@

    Set-Content -Path $ScaPolicyPath -Value $scaPolicy -Encoding ASCII
}

function New-BaselineFiles {
    $baseline = @(
        "profile=windows-ad-lab"
        "host=$env:COMPUTERNAME"
        "modules=log_collector,command,fim,sca,syscollector,malware_detection,active_response,container_security,cloud_security,vulnerability_detection"
        "note=Container and cloud signals are safe narrative events from this Windows VM. Native collection lives elsewhere in the full lab."
        "last_prepared=$(Get-Date -Format o)"
    )

    Set-Content -Path $BaselineFile -Value $baseline -Encoding ASCII
    if (-not (Test-Path -LiteralPath $ModuleLog)) {
        Set-Content -Path $ModuleLog -Value @() -Encoding ASCII
    }

    if (-not (Test-Path -LiteralPath $CloudLog)) {
        Set-Content -Path $CloudLog -Value @() -Encoding ASCII
    }

    $runbook = @'
Windows Wazuh Module Demo
=========================

Run the visual trigger:
  powershell.exe -ExecutionPolicy Bypass -File C:\AD-Demo\ModuleDemo\Scripts\Generate-WindowsWazuhModulesDemo.ps1

Useful dashboard queries:
  agent.name: "ad2016-dc01" and rule.groups: wazuh_module_visibility
  agent.name: "ad2016-dc01" and rule.groups: (wazuh_agent_logcollector or wazuh_agent_command)
  agent.name: "ad2016-dc01" and rule.groups: (wazuh_agent_fim or wazuh_agent_sca or syscheck or sca)
  agent.name: "ad2016-dc01" and rule.groups: (wazuh_agent_syscollector or wazuh_agent_vulnerability_detection or wazuh_agent_rootcheck or rootcheck or vulnerability_management)
  agent.name: "ad2016-dc01" and rule.groups: wazuh_agent_active_response
  agent.name: "ad2016-dc01" and rule.groups: (wazuh_agent_container_security or wazuh_agent_cloud_security or cloud_security)

Demo note:
  Container security and cloud security are narrative-only signals from this Windows VM.
  Native collection for those areas belongs to docker-host and cloud integrations in the full lab.
'@

    Set-Content -Path $RunbookPath -Value $runbook -Encoding ASCII

    $launcher = @'
@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "C:\AD-Demo\ModuleDemo\Scripts\Generate-WindowsWazuhModulesDemo.ps1"
pause
'@

    Set-Content -Path $DesktopLauncherPath -Value $launcher -Encoding ASCII
}

function Update-OssecConfig {
    $body = @"
  <labels>
    <label key="lab">wazuh-security-mvp</label>
    <label key="lab_profile">windows-ad-lab</label>
    <label key="module_catalog">windows-agent-modules-demo</label>
  </labels>

  <localfile>
    <log_format>syslog</log_format>
    <location>$ModuleLog</location>
  </localfile>

  <localfile>
    <log_format>syslog</log_format>
    <location>$CloudLog</location>
  </localfile>

  <localfile>
    <log_format>eventchannel</log_format>
    <location>Microsoft-Windows-PowerShell/Operational</location>
  </localfile>

  <wodle name="command">
    <disabled>no</disabled>
    <tag>wazuh_demo_disk</tag>
    <command>powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$DiskCommandScriptPath"</command>
    <interval>2m</interval>
    <ignore_output>no</ignore_output>
    <run_on_start>yes</run_on_start>
    <timeout>120</timeout>
  </wodle>

  <wodle name="command">
    <disabled>no</disabled>
    <tag>wazuh_demo_admins</tag>
    <command>powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$AdminsCommandScriptPath"</command>
    <interval>5m</interval>
    <ignore_output>no</ignore_output>
    <run_on_start>yes</run_on_start>
    <timeout>120</timeout>
  </wodle>

  <wodle name="syscollector">
    <disabled>no</disabled>
    <interval>10m</interval>
    <scan_on_start>yes</scan_on_start>
    <hardware>yes</hardware>
    <os>yes</os>
    <network>yes</network>
    <packages>yes</packages>
    <ports all="yes">yes</ports>
    <processes>yes</processes>
    <synchronization>
      <max_eps>10</max_eps>
    </synchronization>
  </wodle>

  <sca>
    <enabled>yes</enabled>
    <scan_on_start>yes</scan_on_start>
    <interval>6h</interval>
    <policies>
      <policy>etc/shared/wazuh_demo_windows_sca.yml</policy>
    </policies>
  </sca>

  <rootcheck>
    <disabled>no</disabled>
    <check_files>yes</check_files>
    <check_trojans>yes</check_trojans>
    <check_pids>yes</check_pids>
    <check_ports>yes</check_ports>
    <check_if>yes</check_if>
    <check_winapps>yes</check_winapps>
    <check_winaudit>yes</check_winaudit>
    <check_winmalware>yes</check_winmalware>
    <frequency>3600</frequency>
  </rootcheck>

  <syscheck>
    <disabled>no</disabled>
    <frequency>300</frequency>
    <scan_on_start>yes</scan_on_start>
    <alert_new_files>yes</alert_new_files>
    <auto_ignore frequency="10" timeframe="3600">no</auto_ignore>
    <directories realtime="yes" report_changes="yes">$ConfigDir</directories>
    <directories realtime="yes" report_changes="yes">$EvidenceDir</directories>
  </syscheck>

  <command>
    <name>windows-module-demo-response</name>
    <executable>module-demo-response.cmd</executable>
    <timeout_allowed>no</timeout_allowed>
  </command>

  <active-response>
    <disabled>no</disabled>
  </active-response>
"@

    Set-ManagedOssecBlock -Marker "WINDOWS_WAZUH_MODULE_DEMO" -Body $body
}

function Restart-WazuhAgent {
    $service = Get-Service -Name "WazuhSvc" -ErrorAction Stop

    if ($service.Status -eq "Running") {
        try {
            Restart-Service -Name "WazuhSvc" -Force -ErrorAction Stop
        } catch {
            Stop-Service -Name "WazuhSvc" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 5
            sc.exe start WazuhSvc | Out-Null
        }
    }
    else {
        sc.exe start WazuhSvc | Out-Null
    }

    $service.Refresh()
    $service.WaitForStatus("Running", [TimeSpan]::FromMinutes(2))
}

Ensure-Directory -Path $DemoRoot
Ensure-Directory -Path $LogsDir
Ensure-Directory -Path $ConfigDir
Ensure-Directory -Path $EvidenceDir
Ensure-Directory -Path $ScriptsDir
Ensure-Directory -Path (Split-Path -Path $ScaPolicyPath -Parent)
Ensure-Directory -Path (Split-Path -Path $ActiveResponseCmdPath -Parent)

if (-not (Test-Path -LiteralPath $TriggerScriptSource)) {
    throw "Expected trigger script next to setup script: $TriggerScriptSource"
}

Write-Status "Copying Windows module demo trigger script."
Copy-Item -Path $TriggerScriptSource -Destination $TriggerScriptPath -Force

Write-Status "Writing helper scripts, Active Response wrapper, and custom SCA policy."
New-HelperScripts
New-ScaPolicy
New-BaselineFiles

Write-Status "Enabling PowerShell Operational event channel."
try {
    & wevtutil sl "Microsoft-Windows-PowerShell/Operational" /e:true | Out-Null
} catch {
    Write-Status "Could not enable PowerShell Operational channel automatically: $($_.Exception.Message)"
}

Write-Status "Updating Wazuh agent ossec.conf with the Windows module demo block."
Update-OssecConfig

Write-Status "Restarting Wazuh agent to load command monitoring, SCA, syscollector, rootcheck, and FIM settings."
Restart-WazuhAgent

if ($RunInitialDemo) {
    Write-Status "Running the initial Windows Wazuh module demo trigger."
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $TriggerScriptPath
}

Write-Status "Windows Wazuh module demo is ready."
Write-Status "Runbook: $RunbookPath"
Write-Status "Desktop launcher: $DesktopLauncherPath"
