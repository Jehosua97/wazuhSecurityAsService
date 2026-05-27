param(
    [string]$ProjectId = "wazuh-iac-on-gcp",
    [string]$Zone = "us-central1-a",
    [string]$InstanceName = "wazuh-server",
    [string]$DashboardUser = "admin",
    [string]$DashboardPassword = "SecretPassword"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$DashboardsDir = Join-Path $RepoRoot "dashboards"
$SavedObjectsFile = Join-Path $DashboardsDir "wazuh-soc-dashboards.ndjson"
$RemoteSavedObjectsFile = "/tmp/wazuh-soc-dashboards.ndjson"
$AlertIndexPatternId = "wazuh-alerts-*"
$AlertIndexPatternTitle = "wazuh-alerts-*"
$AlertTimeField = "timestamp"
$DashboardVersion = "2.19.2"
$DashboardBaseUrl = $null

if (-not (Test-Path $DashboardsDir)) {
    New-Item -ItemType Directory -Path $DashboardsDir | Out-Null
}

function ConvertTo-CompactJson {
    param(
        [Parameter(Mandatory)]
        $InputObject
    )

    return ($InputObject | ConvertTo-Json -Compress -Depth 100)
}

function New-WazuhSearchObject {
    param(
        [Parameter(Mandatory)]
        [string]$Id,
        [Parameter(Mandatory)]
        [string]$Title,
        [Parameter(Mandatory)]
        [string]$Description,
        [Parameter(Mandatory)]
        [string]$Query,
        [string[]]$Columns = @("timestamp", "agent.name", "rule.level", "rule.id", "rule.description"),
        [string]$SortField = "timestamp"
    )

    $searchSource = [ordered]@{
        query        = [ordered]@{ language = "kuery"; query = $Query }
        filter       = @()
        indexRefName = "kibanaSavedObjectMeta.searchSourceJSON.index"
    }

    return [ordered]@{
        type       = "search"
        id         = $Id
        attributes = [ordered]@{
            title                  = $Title
            description            = $Description
            columns                = $Columns
            sort                   = @(@($SortField, "desc"))
            kibanaSavedObjectMeta  = [ordered]@{
                searchSourceJSON = (ConvertTo-CompactJson $searchSource)
            }
        }
        references = @(
            [ordered]@{
                name = "kibanaSavedObjectMeta.searchSourceJSON.index"
                type = "index-pattern"
                id   = $AlertIndexPatternId
            }
        )
    }
}

function New-WazuhIndexPatternObject {
    param(
        [Parameter(Mandatory)]
        [string]$Id,
        [Parameter(Mandatory)]
        [string]$Title,
        [Parameter(Mandatory)]
        [string]$TimeFieldName
    )

    return [ordered]@{
        type       = "index-pattern"
        id         = $Id
        attributes = [ordered]@{
            title         = $Title
            timeFieldName = $TimeFieldName
        }
    }
}

function New-WazuhDashboardObject {
    param(
        [Parameter(Mandatory)]
        [string]$Id,
        [Parameter(Mandatory)]
        [string]$Title,
        [Parameter(Mandatory)]
        [string]$Description,
        [Parameter(Mandatory)]
        [object[]]$Panels
    )

    $panelObjects = @()
    $references = @()
    $panelNumber = 0

    foreach ($panel in $Panels) {
        $panelRefName = "panel_$panelNumber"
        $panelIndex = [string]($panelNumber + 1)

        $panelObjects += [ordered]@{
            version          = $DashboardVersion
            type             = "search"
            panelIndex       = $panelIndex
            panelRefName     = $panelRefName
            embeddableConfig = @{}
            gridData         = [ordered]@{
                x = [int]$panel.x
                y = [int]$panel.y
                w = [int]$panel.w
                h = [int]$panel.h
                i = $panelIndex
            }
        }

        $references += [ordered]@{
            name = $panelRefName
            type = "search"
            id   = [string]$panel.searchId
        }

        $panelNumber++
    }

    $dashboardSearchSource = [ordered]@{
        query  = [ordered]@{ language = "kuery"; query = "" }
        filter = @()
    }

    return [ordered]@{
        type       = "dashboard"
        id         = $Id
        attributes = [ordered]@{
            title                 = $Title
            description           = $Description
            hits                  = 0
            timeRestore           = $false
            version               = 1
            optionsJSON           = (ConvertTo-CompactJson ([ordered]@{
                useMargins      = $true
                hidePanelTitles = $false
                syncColors      = $false
                syncCursor      = $false
                syncTooltips    = $false
            }))
            panelsJSON            = (ConvertTo-CompactJson $panelObjects)
            kibanaSavedObjectMeta = [ordered]@{
                searchSourceJSON = (ConvertTo-CompactJson $dashboardSearchSource)
            }
        }
        references = $references
    }
}

$savedObjects = @(
    (New-WazuhIndexPatternObject `
        -Id $AlertIndexPatternId `
        -Title $AlertIndexPatternTitle `
        -TimeFieldName $AlertTimeField),

    (New-WazuhSearchObject `
        -Id "soc-exec-riesgo-alto" `
        -Title "SOC Ejecutivo - Riesgo alto visible al cliente" `
        -Description "Incidentes P1 y P2 para mostrar riesgo visible al cliente." `
        -Query 'rule.groups: (incident_priority_p1 or incident_priority_p2)'),

    (New-WazuhSearchObject `
        -Id "soc-exec-activos-criticos" `
        -Title "SOC Ejecutivo - Riesgo en activos criticos" `
        -Description "Incidentes correlacionados en activos criticos." `
        -Query 'rule.groups: critical_asset and rule.groups: soc_incident'),

    (New-WazuhSearchObject `
        -Id "soc-exec-cumplimiento" `
        -Title "SOC Ejecutivo - Impacto de cumplimiento" `
        -Description "Senales con impacto en cumplimiento y datos sensibles." `
        -Query 'rule.groups: compliance_scope and rule.level >= 8'),

    (New-WazuhSearchObject `
        -Id "soc-exec-superficie-publica" `
        -Title "SOC Ejecutivo - Superficie publica expuesta" `
        -Description "Ataques y actividad internet-facing relevantes para narrativa ejecutiva." `
        -Query 'rule.groups: internet_facing and rule.groups: (web or attack or recon)'),

    (New-WazuhSearchObject `
        -Id "soc-ops-incidentes-correlacionados" `
        -Title "SOC Operativo - Incidentes correlacionados" `
        -Description "Vista principal de incidentes correlacionados para el analista." `
        -Query 'rule.groups: soc_incident'),

    (New-WazuhSearchObject `
        -Id "soc-ops-infra-incidentes" `
        -Title "SOC Operativo - Incidentes de infraestructura" `
        -Description "Correlacion de gateway, base de datos y docker host." `
        -Query 'rule.groups: infrastructure_incident'),

    (New-WazuhSearchObject `
        -Id "soc-ops-pyme-target" `
        -Title "SOC Operativo - Timeline pyme-demo-target" `
        -Description "Timeline del sitio web y del panel de ataques controlados." `
        -Query 'agent.name: "pyme-demo-target" and rule.groups: (soc_signal or soc_incident)'),

    (New-WazuhSearchObject `
        -Id "soc-ops-metasploit" `
        -Title "SOC Operativo - Actividad metasploit-node" `
        -Description "Actividad del endpoint ofensivo monitoreado." `
        -Query 'agent.name: "metasploit-node" and rule.groups: metasploit_endpoint'),

    (New-WazuhSearchObject `
        -Id "soc-ops-kali-attacker" `
        -Title "SOC Operativo - Actividad kali-attacker" `
        -Description "Actividad controlada del endpoint Kali monitoreado." `
        -Query 'agent.name: "kali-attacker" and rule.groups: (kali_endpoint or reconnaissance or active_scanning or port_scan)'),

    (New-WazuhSearchObject `
        -Id "soc-ops-edge-gateway" `
        -Title "SOC Operativo - Actividad edge-gateway" `
        -Description "Actividad de firewall y VPN del edge gateway." `
        -Query 'agent.name: "edge-gateway" and rule.groups: edge_gateway'),

    (New-WazuhSearchObject `
        -Id "soc-ops-db-server" `
        -Title "SOC Operativo - Actividad db-server" `
        -Description "Actividad de autenticacion, esquema y acceso sensible del database endpoint." `
        -Query 'agent.name: "db-server" and rule.groups: database_endpoint'),

    (New-WazuhSearchObject `
        -Id "soc-ops-docker-host" `
        -Title "SOC Operativo - Actividad docker-host" `
        -Description "Actividad del host de contenedores y drift operativo." `
        -Query 'agent.name: "docker-host" and rule.groups: docker_host'),

    (New-WazuhSearchObject `
        -Id "soc-ops-windows-server" `
        -Title "SOC Operativo - Actividad windows-server" `
        -Description "Actividad del endpoint Windows Server monitoreado." `
        -Query 'agent.name: "windows-server" and rule.groups: windows_endpoint'),

    (New-WazuhSearchObject `
        -Id "soc-ops-linux-ui-sensitive" `
        -Title "SOC Operativo - Linux UI /home/esquivel/Confidencial" `
        -Description "DLP/FIM, ransomware, autenticacion critica y port scan del endpoint Linux UI." `
        -Query 'rule.id: (100010 or 100015 or 100020 or 100030) or rule.groups: linux_ui_endpoint'),

    (New-WazuhSearchObject `
        -Id "soc-modules-overview" `
        -Title "SOC Modulos Wazuh - Vista general" `
        -Description "Eventos de visibilidad por modulo del agente Wazuh en los contenedores demo." `
        -Query 'rule.groups: wazuh_module_visibility or rule.groups: sca or rule.groups: syscheck or rule.groups: rootcheck or rule.groups: docker' `
        -Columns @("timestamp", "agent.name", "rule.level", "rule.id", "rule.description", "full_log")),

    (New-WazuhSearchObject `
        -Id "soc-modules-log-command" `
        -Title "SOC Modulos Wazuh - Log collector y Command" `
        -Description "Log collector y comandos autorizados ejecutados localmente por el agente." `
        -Query 'rule.groups: (wazuh_agent_logcollector or wazuh_agent_command)' `
        -Columns @("timestamp", "agent.name", "rule.level", "rule.id", "rule.description", "full_log")),

    (New-WazuhSearchObject `
        -Id "soc-modules-fim-sca" `
        -Title "SOC Modulos Wazuh - FIM y SCA" `
        -Description "Cambios de archivos, baseline de modulos y evaluacion de configuracion." `
        -Query 'rule.groups: (wazuh_agent_fim or wazuh_agent_sca or syscheck or sca)' `
        -Columns @("timestamp", "agent.name", "rule.level", "rule.id", "rule.description", "syscheck.path", "full_log")),

    (New-WazuhSearchObject `
        -Id "soc-modules-inventory-vuln-rootcheck" `
        -Title "SOC Modulos Wazuh - Inventario, vulnerabilidades y malware detection" `
        -Description "Syscollector, vulnerability detection y rootcheck/malware detection para narrativa de riesgo." `
        -Query 'rule.groups: (wazuh_agent_syscollector or wazuh_agent_vulnerability_detection or wazuh_agent_rootcheck or rootcheck or vulnerability_management)' `
        -Columns @("timestamp", "agent.name", "rule.level", "rule.id", "rule.description", "full_log")),

    (New-WazuhSearchObject `
        -Id "soc-modules-active-response" `
        -Title "SOC Modulos Wazuh - Active Response seguro" `
        -Description "Respuesta activa en modo evidencia: sin bloqueo ni acciones destructivas." `
        -Query 'rule.groups: wazuh_agent_active_response' `
        -Columns @("timestamp", "agent.name", "rule.level", "rule.id", "rule.description", "full_log")),

    (New-WazuhSearchObject `
        -Id "soc-modules-container-cloud" `
        -Title "SOC Modulos Wazuh - Contenedores y Cloud" `
        -Description "Docker listener en docker-host y telemetria cloud GCP simulada de forma segura." `
        -Query 'rule.groups: (wazuh_agent_container_security or docker or docker_host or container_platform or wazuh_agent_cloud_security or cloud_security)' `
        -Columns @("timestamp", "agent.name", "rule.level", "rule.id", "rule.description", "full_log")),

    (New-WazuhSearchObject `
        -Id "soc-docker-cloud-overview" `
        -Title "SOC Docker y Cloud Security - Vista general" `
        -Description "Vista combinada para explicar Docker listener, Docker lab telemetry y Cloud Security GCP." `
        -Query 'rule.groups: (wazuh_agent_container_security or docker or docker_host or container_platform or wazuh_agent_cloud_security or cloud_security)' `
        -Columns @("timestamp", "agent.name", "rule.level", "rule.id", "rule.description", "full_log")),

    (New-WazuhSearchObject `
        -Id "soc-docker-runtime" `
        -Title "SOC Docker y Cloud Security - Runtime Docker" `
        -Description "Eventos del runtime Docker: reinicios, pulls de imagenes y cambios en workloads." `
        -Query 'agent.name: "docker-host" and rule.groups: (wazuh_agent_container_security or docker or docker_host or container_platform or container_runtime or image_supply_chain)' `
        -Columns @("timestamp", "agent.name", "rule.level", "rule.id", "rule.description", "full_log")),

    (New-WazuhSearchObject `
        -Id "soc-docker-config-drift" `
        -Title "SOC Docker y Cloud Security - Drift de configuracion" `
        -Description "FIM sobre archivos usados por contenedores y cambios de configuracion del host Docker." `
        -Query 'agent.name: "docker-host" and (rule.groups: configuration_change or syscheck.path: "/opt/docker-lab*" or syscheck.path: "/etc/docker*")' `
        -Columns @("timestamp", "agent.name", "rule.level", "rule.id", "rule.description", "syscheck.path", "full_log")),

    (New-WazuhSearchObject `
        -Id "soc-cloud-gcp-demo" `
        -Title "SOC Docker y Cloud Security - GCP Cloud Security" `
        -Description "Eventos GCP simulados para demostrar cambios IAM y cambios de compute." `
        -Query 'rule.groups: (wazuh_agent_cloud_security or cloud_security or gcp or iam_change or compute_change)' `
        -Columns @("timestamp", "agent.name", "rule.level", "rule.id", "rule.description", "full_log")),

    (New-WazuhDashboardObject `
        -Id "soc-ejecutivo-dashboard" `
        -Title "SOC Ejecutivo - PYME Mexico" `
        -Description "Dashboard ejecutivo para clientes: riesgo visible, activos criticos, cumplimiento y superficie expuesta." `
        -Panels @(
            [ordered]@{ searchId = "soc-exec-riesgo-alto"; x = 0;  y = 0;  w = 24; h = 12 },
            [ordered]@{ searchId = "soc-exec-activos-criticos"; x = 24; y = 0;  w = 24; h = 12 },
            [ordered]@{ searchId = "soc-exec-cumplimiento"; x = 0;  y = 12; w = 24; h = 12 },
            [ordered]@{ searchId = "soc-exec-superficie-publica"; x = 24; y = 12; w = 24; h = 12 }
        )),

    (New-WazuhDashboardObject `
        -Id "soc-operativo-dashboard" `
        -Title "SOC Operativo - PYME Mexico" `
        -Description "Dashboard operativo para analistas: incidentes, infraestructura y actividad por endpoint." `
        -Panels @(
            [ordered]@{ searchId = "soc-ops-incidentes-correlacionados"; x = 0;  y = 0;  w = 48; h = 12 },
            [ordered]@{ searchId = "soc-ops-infra-incidentes"; x = 0;  y = 12; w = 24; h = 12 },
            [ordered]@{ searchId = "soc-ops-pyme-target"; x = 24; y = 12; w = 24; h = 12 },
            [ordered]@{ searchId = "soc-ops-metasploit"; x = 0;  y = 24; w = 12; h = 12 },
            [ordered]@{ searchId = "soc-ops-kali-attacker"; x = 12; y = 24; w = 12; h = 12 },
            [ordered]@{ searchId = "soc-ops-edge-gateway"; x = 24; y = 24; w = 12; h = 12 },
            [ordered]@{ searchId = "soc-ops-db-server"; x = 36; y = 24; w = 12; h = 12 },
            [ordered]@{ searchId = "soc-ops-docker-host"; x = 0;  y = 36; w = 24; h = 12 },
            [ordered]@{ searchId = "soc-ops-windows-server"; x = 24; y = 36; w = 24; h = 12 },
            [ordered]@{ searchId = "soc-ops-linux-ui-sensitive"; x = 0; y = 48; w = 48; h = 12 }
        )),

    (New-WazuhDashboardObject `
        -Id "soc-modulos-wazuh-dashboard" `
        -Title "SOC Modulos Wazuh - Demo tecnico" `
        -Description "Dashboard para demostrar los modulos del agente Wazuh en los contenedores locales." `
        -Panels @(
            [ordered]@{ searchId = "soc-modules-overview"; x = 0;  y = 0;  w = 48; h = 12 },
            [ordered]@{ searchId = "soc-modules-log-command"; x = 0;  y = 12; w = 24; h = 12 },
            [ordered]@{ searchId = "soc-modules-fim-sca"; x = 24; y = 12; w = 24; h = 12 },
            [ordered]@{ searchId = "soc-modules-inventory-vuln-rootcheck"; x = 0;  y = 24; w = 24; h = 12 },
            [ordered]@{ searchId = "soc-modules-active-response"; x = 24; y = 24; w = 24; h = 12 },
            [ordered]@{ searchId = "soc-modules-container-cloud"; x = 0;  y = 36; w = 48; h = 12 }
        )),

    (New-WazuhDashboardObject `
        -Id "soc-docker-cloud-security-dashboard" `
        -Title "SOC Docker y Cloud Security - Visual" `
        -Description "Dashboard visual para explicar el modulo Docker de Cloud Security y eventos cloud GCP del laboratorio." `
        -Panels @(
            [ordered]@{ searchId = "soc-docker-cloud-overview"; x = 0;  y = 0;  w = 48; h = 12 },
            [ordered]@{ searchId = "soc-docker-runtime"; x = 0;  y = 12; w = 24; h = 12 },
            [ordered]@{ searchId = "soc-docker-config-drift"; x = 24; y = 12; w = 24; h = 12 },
            [ordered]@{ searchId = "soc-cloud-gcp-demo"; x = 0;  y = 24; w = 48; h = 12 }
        ))
)

$ndjsonContent = ($savedObjects | ForEach-Object { ConvertTo-CompactJson $_ }) -join [Environment]::NewLine
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($SavedObjectsFile, "$ndjsonContent`n", $utf8NoBom)

Write-Host "Saved objects file generated at $SavedObjectsFile"

Write-Host "Preparing remote dashboard import on $InstanceName..."
gcloud compute ssh $InstanceName `
    --project=$ProjectId `
    --zone=$Zone `
    --quiet `
    --command="sudo rm -f $RemoteSavedObjectsFile"

Write-Host "Copying saved objects to $InstanceName..."
gcloud compute scp `
    --project=$ProjectId `
    --zone=$Zone `
    --quiet `
    $SavedObjectsFile `
    "${InstanceName}:$RemoteSavedObjectsFile"

$ImportCommand = @(
    "curl -sk",
    "-u '$DashboardUser`:$DashboardPassword'",
    "-H 'osd-xsrf: true'",
    "-F file=@$RemoteSavedObjectsFile",
    "'https://localhost/api/saved_objects/_import?overwrite=true'"
) -join " "

Write-Host "Importing dashboards into Wazuh Dashboard..."
$ImportResponse = gcloud compute ssh $InstanceName `
    --project=$ProjectId `
    --zone=$Zone `
    --quiet `
    --command=$ImportCommand

Write-Host $ImportResponse

try {
    $ManagerIp = gcloud compute instances describe $InstanceName `
        --project=$ProjectId `
        --zone=$Zone `
        --format="get(networkInterfaces[0].accessConfigs[0].natIP)"

    if ($ManagerIp) {
        $DashboardBaseUrl = "https://$ManagerIp"
    }
} catch {
    Write-Warning "Could not resolve current dashboard public IP automatically."
}

if (-not $DashboardBaseUrl) {
    $DashboardBaseUrl = "https://YOUR_WAZUH_IP"
}

Write-Host "Executive dashboard URL: $DashboardBaseUrl/app/dashboards#/view/soc-ejecutivo-dashboard"
Write-Host "Operational dashboard URL: $DashboardBaseUrl/app/dashboards#/view/soc-operativo-dashboard"
Write-Host "Wazuh modules dashboard URL: $DashboardBaseUrl/app/dashboards#/view/soc-modulos-wazuh-dashboard"
Write-Host "Docker and Cloud Security dashboard URL: $DashboardBaseUrl/app/dashboards#/view/soc-docker-cloud-security-dashboard"
