param()

$ErrorActionPreference = "Stop"

$Config = @{
  Hostname = "ad2016-dc01"
  AdministratorPassword = "ChangeMe!2026"
  DomainFqdn = "corp.demo.local"
  DomainNetbios = "CORPDEMO"
  BaseDn = "DC=corp,DC=demo,DC=local"
  SafeModePassword = "ChangeMe!2026"
  UsersOu = "DemoUsers"
  GroupsOu = "DemoGroups"
  ServiceAccountsOu = "ServiceAccounts"
  WazuhManagerIp = "34.135.112.15"
  WazuhAgentName = "ad2016-dc01"
  WazuhAgentVersion = "4.13.0-1"
  DemoDir = "C:\AD-Demo"
  RunDemoEvents = $true
  Groups = @(
    @{ Name = "Finance Users"; Description = "Demo finance users" }
    @{ Name = "Operations Users"; Description = "Demo operations users" }
    @{ Name = "SOC Analysts"; Description = "Demo SOC analysts" }
    @{ Name = "Privileged Admins"; Description = "Demo privileged administrators" }
  )
  Users = @(
    @{
      Username = "ana.garcia"
      FirstName = "Ana"
      Surname = "Garcia"
      Password = "ChangeMe!2026"
      Groups = @("Finance Users")
    }
    @{
      Username = "carlos.mendez"
      FirstName = "Carlos"
      Surname = "Mendez"
      Password = "ChangeMe!2026"
      Groups = @("Operations Users")
    }
    @{
      Username = "sofia.ramirez"
      FirstName = "Sofia"
      Surname = "Ramirez"
      Password = "ChangeMe!2026"
      Groups = @("Finance Users", "Operations Users")
    }
    @{
      Username = "it.soc"
      FirstName = "IT"
      Surname = "SOC"
      Password = "ChangeMe!2026"
      Groups = @("SOC Analysts", "Privileged Admins")
    }
  )
  ServiceAccounts = @(
    @{
      Username = "svc.backup"
      FirstName = "Service"
      Surname = "Backup"
      Password = "ChangeMe!2026"
      Description = "Demo backup service account"
    }
  )
}

$TaskName = "WazuhADLabFallback"
$LocalScriptPath = "C:\Windows\Temp\Setup-WindowsAdLabFallback.ps1"
$LocalEventScriptPath = "C:\Windows\Temp\Generate-ADDemoEvents.ps1"
$StateFile = "C:\Windows\Temp\WazuhADLabFallback.state"
$HostShare = "C:\vagrant"
$RuntimeDir = Join-Path $HostShare "runtime"
$StatusFile = Join-Path $RuntimeDir "windows-ad-lab-status.json"
$LogFile = Join-Path $RuntimeDir "windows-ad-lab-fallback.log"
$LocalLogFile = "C:\Windows\Temp\windows-ad-lab-fallback.log"
$SourceEventScript = Join-Path $HostShare "files\Generate-ADDemoEvents.ps1"

function Ensure-Directory {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -Path $Path -ItemType Directory -Force | Out-Null
  }
}

function Write-Log {
  param([string]$Message)

  $timestamp = Get-Date -Format "s"
  $line = "[{0}] {1}" -f $timestamp, $Message
  Add-Content -Path $LocalLogFile -Value $line -Encoding ASCII

  if (Test-Path -LiteralPath $HostShare) {
    Ensure-Directory -Path $RuntimeDir
    Add-Content -Path $LogFile -Value $line -Encoding ASCII
  }
}

function Update-Status {
  param(
    [string]$Phase,
    [string]$Message
  )

  $payload = @{
    timestamp = (Get-Date).ToString("s")
    phase = $Phase
    message = $Message
    computer_name = $env:COMPUTERNAME
  } | ConvertTo-Json -Depth 4

  if (Test-Path -LiteralPath $HostShare) {
    Ensure-Directory -Path $RuntimeDir
    Set-Content -Path $StatusFile -Value $payload -Encoding ASCII
  }
}

function Save-State {
  param([string]$Phase)

  Set-Content -Path $StateFile -Value $Phase -Encoding ASCII
}

function Get-State {
  if (Test-Path -LiteralPath $StateFile) {
    return (Get-Content -Path $StateFile -Raw).Trim()
  }

  return "start"
}

function Register-ResumeTask {
  $taskCommand = 'powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $LocalScriptPath
  schtasks.exe /Create /TN $TaskName /RU SYSTEM /SC ONSTART /RL HIGHEST /TR $taskCommand /F | Out-Null
}

function Remove-ResumeTask {
  schtasks.exe /Delete /TN $TaskName /F | Out-Null
}

function Ensure-LocalAssets {
  if ($PSCommandPath -ne $LocalScriptPath) {
    Copy-Item -Path $PSCommandPath -Destination $LocalScriptPath -Force
  }

  if (Test-Path -LiteralPath $SourceEventScript) {
    Copy-Item -Path $SourceEventScript -Destination $LocalEventScriptPath -Force
  }
}

function Ensure-WinRM {
  winrm quickconfig -q | Out-Null
  winrm set winrm/config/service/auth '@{Basic="true"}' | Out-Null
  winrm set winrm/config/service '@{AllowUnencrypted="true"}' | Out-Null
  Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
  Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $true
  Set-NetFirewallRule -DisplayGroup "Windows Remote Management" -Enabled True -ErrorAction SilentlyContinue
  Enable-PSRemoting -Force | Out-Null
}

function Ensure-DemoDirectories {
  $paths = @(
    $Config.DemoDir,
    (Join-Path $Config.DemoDir "Confidential"),
    (Join-Path $Config.DemoDir "Evidence"),
    (Join-Path $Config.DemoDir "Logs")
  )

  foreach ($path in $paths) {
    Ensure-Directory -Path $path
  }

  Set-Content -Path (Join-Path $Config.DemoDir "Confidential\access-review.txt") -Value @(
    "Demo confidential file."
    "Changes in this folder are monitored by Wazuh FIM."
  ) -Encoding ASCII
}

function Ensure-ModuleReady {
  $attempts = 40

  for ($index = 0; $index -lt $attempts; $index++) {
    try {
      Import-Module ActiveDirectory -ErrorAction Stop
      Get-ADDomain -ErrorAction Stop | Out-Null
      return
    }
    catch {
      Start-Sleep -Seconds 15
    }
  }

  throw "Active Directory services did not become ready in time."
}

function Ensure-Ou {
  param([string]$Name)

  $distinguishedName = "OU={0},{1}" -f $Name, $Config.BaseDn
  $existing = Get-ADOrganizationalUnit -LDAPFilter "(distinguishedName=$distinguishedName)" -ErrorAction SilentlyContinue

  if (-not $existing) {
    New-ADOrganizationalUnit -Name $Name -Path $Config.BaseDn -ProtectedFromAccidentalDeletion:$false | Out-Null
  }
}

function Ensure-Group {
  param([hashtable]$Group)

  $existing = Get-ADGroup -Filter "SamAccountName -eq '$($Group.Name)'" -ErrorAction SilentlyContinue
  if (-not $existing) {
    New-ADGroup `
      -Name $Group.Name `
      -SamAccountName $Group.Name `
      -GroupScope Global `
      -GroupCategory Security `
      -DisplayName $Group.Name `
      -Description $Group.Description `
      -Path ("OU={0},{1}" -f $Config.GroupsOu, $Config.BaseDn) | Out-Null
  }
}

function Ensure-User {
  param([hashtable]$User)

  $existing = Get-ADUser -Filter "SamAccountName -eq '$($User.Username)'" -ErrorAction SilentlyContinue
  $securePassword = ConvertTo-SecureString $User.Password -AsPlainText -Force

  if (-not $existing) {
    New-ADUser `
      -Name ("{0} {1}" -f $User.FirstName, $User.Surname) `
      -SamAccountName $User.Username `
      -UserPrincipalName ("{0}@{1}" -f $User.Username, $Config.DomainFqdn) `
      -GivenName $User.FirstName `
      -Surname $User.Surname `
      -AccountPassword $securePassword `
      -Enabled $true `
      -PasswordNeverExpires $true `
      -Path ("OU={0},{1}" -f $Config.UsersOu, $Config.BaseDn) | Out-Null
  }
}

function Ensure-ServiceAccount {
  param([hashtable]$Account)

  $existing = Get-ADUser -Filter "SamAccountName -eq '$($Account.Username)'" -ErrorAction SilentlyContinue
  $securePassword = ConvertTo-SecureString $Account.Password -AsPlainText -Force

  if (-not $existing) {
    New-ADUser `
      -Name $Account.Username `
      -SamAccountName $Account.Username `
      -UserPrincipalName ("{0}@{1}" -f $Account.Username, $Config.DomainFqdn) `
      -GivenName $Account.FirstName `
      -Surname $Account.Surname `
      -Description $Account.Description `
      -AccountPassword $securePassword `
      -Enabled $true `
      -PasswordNeverExpires $true `
      -Path ("OU={0},{1}" -f $Config.ServiceAccountsOu, $Config.BaseDn) | Out-Null
  }
}

function Ensure-UserMemberships {
  param([hashtable]$User)

  foreach ($groupName in $User.Groups) {
    $member = Get-ADGroupMember -Identity $groupName -Recursive | Where-Object { $_.SamAccountName -eq $User.Username }
    if (-not $member) {
      Add-ADGroupMember -Identity $groupName -Members $User.Username
    }
  }
}

function Configure-Wazuh {
  $msiPath = "C:\Windows\Temp\wazuh-agent-{0}.msi" -f $Config.WazuhAgentVersion
  $url = "https://packages.wazuh.com/4.x/windows/wazuh-agent-{0}.msi" -f $Config.WazuhAgentVersion

  if (-not (Test-Path -LiteralPath $msiPath)) {
    Invoke-WebRequest -Uri $url -OutFile $msiPath
  }

  $service = Get-Service -Name WazuhSvc -ErrorAction SilentlyContinue
  if (-not $service) {
    $arguments = @(
      "/i"
      $msiPath
      "/qn"
      ('WAZUH_MANAGER="{0}"' -f $Config.WazuhManagerIp)
      ('WAZUH_REGISTRATION_SERVER="{0}"' -f $Config.WazuhManagerIp)
      ('WAZUH_AGENT_NAME="{0}"' -f $Config.WazuhAgentName)
    )

    Start-Process -FilePath msiexec.exe -ArgumentList $arguments -Wait -NoNewWindow
  }

  $agentConfig = "C:\Program Files (x86)\ossec-agent\ossec.conf"
  if (-not (Test-Path -LiteralPath $agentConfig)) {
    throw "Wazuh agent config not found at $agentConfig"
  }

  $block = @"
  <!-- ANSIBLE_WINDOWS_AD_LAB_START -->
  <localfile>
    <log_format>eventchannel</log_format>
    <location>Application</location>
  </localfile>
  <localfile>
    <log_format>eventchannel</log_format>
    <location>Security</location>
  </localfile>
  <localfile>
    <log_format>eventchannel</log_format>
    <location>System</location>
  </localfile>
  <localfile>
    <log_format>eventchannel</log_format>
    <location>Directory Service</location>
  </localfile>
  <localfile>
    <log_format>syslog</log_format>
    <location>$($Config.DemoDir)\Logs\ad-demo.log</location>
  </localfile>
  <syscheck>
    <disabled>no</disabled>
    <frequency>300</frequency>
    <scan_on_start>yes</scan_on_start>
    <alert_new_files>yes</alert_new_files>
    <directories realtime="yes" report_changes="yes">$($Config.DemoDir)\Confidential</directories>
  </syscheck>
  <!-- ANSIBLE_WINDOWS_AD_LAB_END -->
"@

  $content = Get-Content -Path $agentConfig -Raw
  if ($content -notmatch "ANSIBLE_WINDOWS_AD_LAB_START") {
    $content = $content -replace "</ossec_config>", "$block`r`n</ossec_config>"
    Set-Content -Path $agentConfig -Value $content -Encoding ASCII
  }

  Copy-Item -Path $LocalEventScriptPath -Destination (Join-Path $Config.DemoDir "Generate-ADDemoEvents.ps1") -Force

  $service = Get-Service -Name WazuhSvc -ErrorAction Stop
  Set-Service -Name WazuhSvc -StartupType Automatic

  if ($service.Status -eq "Running") {
    Restart-Service -Name WazuhSvc -Force
  }
  else {
    Start-Service -Name WazuhSvc
  }

  $service.WaitForStatus("Running", [TimeSpan]::FromMinutes(2))
}

function Run-DemoEvents {
  if (-not $Config.RunDemoEvents) {
    return
  }

  $scriptPath = Join-Path $Config.DemoDir "Generate-ADDemoEvents.ps1"
  powershell.exe -NoLogo -ExecutionPolicy Bypass -File $scriptPath -DemoDir $Config.DemoDir -DomainName $Config.DomainFqdn
}

Ensure-LocalAssets
Register-ResumeTask
Ensure-Directory -Path (Split-Path -Path $LocalLogFile -Parent)

$phase = Get-State
Write-Log ("Starting phase '{0}'" -f $phase)
Update-Status -Phase $phase -Message "Runner started."

switch ($phase) {
  "start" {
    Update-Status -Phase "start" -Message "Configuring local administrator, hostname and WinRM."
    & net user Administrator $Config.AdministratorPassword | Out-Null
    Ensure-WinRM

    if ($env:COMPUTERNAME -ne $Config.Hostname) {
      Save-State -Phase "after_rename"
      Update-Status -Phase "rebooting_rename" -Message "Renaming computer before AD promotion."
      Write-Log "Renaming computer and rebooting."
      Rename-Computer -NewName $Config.Hostname -Force -Restart
      return
    }

    Save-State -Phase "after_rename"
    & $LocalScriptPath
    return
  }

  "after_rename" {
    Update-Status -Phase "after_rename" -Message "Installing AD prerequisites and preparing demo directories."
    Ensure-WinRM
    Ensure-DemoDirectories
    Install-WindowsFeature -Name RSAT-AD-PowerShell -IncludeManagementTools | Out-Null
    Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeAllSubFeature -IncludeManagementTools | Out-Null

    try {
      Import-Module ActiveDirectory -ErrorAction Stop
      Get-ADDomain -ErrorAction Stop | Out-Null
      Save-State -Phase "after_promotion"
      & $LocalScriptPath
      return
    }
    catch {
      $safeMode = ConvertTo-SecureString $Config.SafeModePassword -AsPlainText -Force
      Save-State -Phase "after_promotion"
      Update-Status -Phase "rebooting_promotion" -Message "Promoting Windows Server to Active Directory Domain Controller."
      Write-Log "Starting AD forest creation."
      Install-ADDSForest `
        -DomainName $Config.DomainFqdn `
        -DomainNetbiosName $Config.DomainNetbios `
        -InstallDNS `
        -SafeModeAdministratorPassword $safeMode `
        -Force:$true
      return
    }
  }

  "after_promotion" {
    Update-Status -Phase "after_promotion" -Message "Configuring AD objects, Wazuh agent and demo telemetry."
    Ensure-WinRM
    Ensure-DemoDirectories
    Ensure-ModuleReady

    Get-DnsClient | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" } | ForEach-Object {
      Set-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -ServerAddresses "127.0.0.1"
    }

    Ensure-Ou -Name $Config.UsersOu
    Ensure-Ou -Name $Config.GroupsOu
    Ensure-Ou -Name $Config.ServiceAccountsOu

    foreach ($group in $Config.Groups) {
      Ensure-Group -Group $group
    }

    foreach ($user in $Config.Users) {
      Ensure-User -User $user
    }

    foreach ($user in $Config.Users) {
      Ensure-UserMemberships -User $user
    }

    foreach ($serviceAccount in $Config.ServiceAccounts) {
      Ensure-ServiceAccount -Account $serviceAccount
    }

    Configure-Wazuh
    Run-DemoEvents

    Save-State -Phase "complete"
    Update-Status -Phase "complete" -Message "Windows AD lab fallback provisioning completed successfully."
    Write-Log "Provisioning completed successfully."
    Remove-ResumeTask
    return
  }

  "complete" {
    Update-Status -Phase "complete" -Message "Provisioning already completed."
    Write-Log "Nothing to do. Provisioning already completed."
    Remove-ResumeTask
    return
  }

  default {
    throw "Unknown phase '$phase'."
  }
}
