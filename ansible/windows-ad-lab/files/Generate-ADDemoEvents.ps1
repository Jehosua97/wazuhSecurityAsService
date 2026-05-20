param(
    [string]$DemoDir = "C:\AD-Demo",
    [string]$DomainName = "corp.demo.local"
)

$ErrorActionPreference = "Stop"

$ConfidentialDir = Join-Path $DemoDir "Confidential"
$EvidenceDir = Join-Path $DemoDir "Evidence"
$LogDir = Join-Path $DemoDir "Logs"
$DemoLog = Join-Path $LogDir "ad-demo.log"
$EvidenceFile = Join-Path $EvidenceDir "ad-demo-evidence.json"
$EventSource = "WazuhADLabDemo"

New-Item -ItemType Directory -Path $ConfidentialDir -Force | Out-Null
New-Item -ItemType Directory -Path $EvidenceDir -Force | Out-Null
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

if (-not [System.Diagnostics.EventLog]::SourceExists($EventSource)) {
    New-EventLog -LogName Application -Source $EventSource
}

function Write-DemoLog {
    param(
        [string]$Action,
        [string]$Severity,
        [string]$Detail
    )

    $culture = [Globalization.CultureInfo]::InvariantCulture
    $syslogTime = (Get-Date).ToString("MMM dd HH:mm:ss", $culture)
    $line = "$syslogTime $env:COMPUTERNAME ad-demo: action=$Action severity=$Severity detail=$Detail"
    Add-Content -Path $DemoLog -Value $line
    return $line
}

function Write-DemoEvent {
    param(
        [int]$EventId,
        [string]$EntryType,
        [string]$Action,
        [string]$Detail
    )

    $message = "ad-demo: action=$Action detail=$Detail"
    Write-EventLog -LogName Application -Source $EventSource -EntryType $EntryType -EventId $EventId -Message $message
    Write-DemoLog -Action $Action -Severity $EntryType -Detail $Detail | Out-Null
}

$runId = Get-Date -Format "yyyyMMddHHmmss"
$criticalFile = Join-Path $ConfidentialDir "customer-access-review-$runId.txt"
$aclFile = Join-Path $ConfidentialDir "privileged-groups-review.txt"

Set-Content -Path $criticalFile -Value "review_id=$runId`nclassification=confidential`nowner=finance-demo" -Encoding ASCII
Add-Content -Path $criticalFile -Value "reviewed_at=$(Get-Date -Format o)"
Set-Content -Path $aclFile -Value "Domain Admins review marker $(Get-Date -Format o)" -Encoding ASCII

Write-DemoEvent -EventId 5101 -EntryType Warning -Action "fim_sensitive_file_changed" -Detail "file=$criticalFile outcome=simulated"
Write-DemoEvent -EventId 5102 -EntryType Warning -Action "privileged_group_review" -Detail "group=Domain Admins outcome=simulated"
Write-DemoEvent -EventId 5103 -EntryType Information -Action "ad_health_check" -Detail "domain=$DomainName outcome=simulated"

$evidence = [ordered]@{
    timestamp_utc = (Get-Date).ToUniversalTime().ToString("o")
    host = $env:COMPUTERNAME
    scenario = "windows-ad-demo"
    generated_events = @(
        "Application/WazuhADLabDemo/5101",
        "Application/WazuhADLabDemo/5102",
        "Application/WazuhADLabDemo/5103",
        "FIM/$criticalFile",
        "Log/$DemoLog"
    )
    notes = "Defensive demo evidence only. No exploitation or real attack performed."
}

$evidence | ConvertTo-Json -Depth 5 | Set-Content -Path $EvidenceFile -Encoding ASCII

Write-Output "Safe AD demo events generated."
Write-Output "Evidence: $EvidenceFile"
