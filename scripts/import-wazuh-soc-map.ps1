param(
    [string]$ProjectId = "wazuh-iac-on-gcp",
    [string]$Zone = "us-central1-a",
    [string]$InstanceName = "wazuh-server",
    [string]$DashboardUser = "admin",
    [string]$DashboardPassword = "SecretPassword",
    [string]$GeoIndex = "soc-lab-geo-events"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$DashboardsDir = Join-Path $RepoRoot "dashboards"
$MapObjectsFile = Join-Path $DashboardsDir "wazuh-soc-map.ndjson"
$MappingFile = Join-Path $DashboardsDir "soc-lab-geo-events-mapping.json"
$BulkFile = Join-Path $DashboardsDir "soc-lab-geo-events.bulk.ndjson"
$RemoteDir = "/tmp/wazuh-soc-map"
$MapId = "soc-geo-threat-map"
$DashboardAuth = "${DashboardUser}:$DashboardPassword"

if (-not (Test-Path $DashboardsDir)) {
    New-Item -ItemType Directory -Path $DashboardsDir | Out-Null
}

function Assert-NativeCommand {
    param(
        [Parameter(Mandatory)]
        [string]$Description
    )

    if ($LASTEXITCODE -ne 0) {
        throw "$Description failed with exit code $LASTEXITCODE."
    }
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [string]$Value
    )

    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Value, $Utf8NoBom)
}

function ConvertTo-CompactJson {
    param(
        [Parameter(Mandatory)]
        $InputObject
    )

    return ($InputObject | ConvertTo-Json -Compress -Depth 100)
}

function New-GeoPoint {
    param(
        [double]$Lat,
        [double]$Lon
    )

    return [ordered]@{
        lat = $Lat
        lon = $Lon
    }
}

function New-MapFilter {
    param(
        [Parameter(Mandatory)]
        [string]$Field,
        [Parameter(Mandatory)]
        [string]$Value,
        [Parameter(Mandatory)]
        [string]$IndexPatternId
    )

    $match = [ordered]@{}
    $match[$Field] = $Value

    return [ordered]@{
        meta     = [ordered]@{
            index    = $IndexPatternId
            alias    = $null
            negate   = $false
            disabled = $false
        }
        query    = [ordered]@{
            match_phrase = $match
        }
        '$state' = [ordered]@{
            store = "appState"
        }
    }
}

function New-DocumentLayer {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [string]$Description,
        [Parameter(Mandatory)]
        [string]$Id,
        [Parameter(Mandatory)]
        [string]$EventType,
        [Parameter(Mandatory)]
        [string]$FillColor,
        [Parameter(Mandatory)]
        [int]$MarkerSize
    )

    return [ordered]@{
        name        = $Name
        description = $Description
        type        = "documents"
        id          = $Id
        zoomRange   = @(0, 22)
        opacity     = 82
        visibility  = "visible"
        source      = [ordered]@{
            indexPatternRefName       = $GeoIndex
            geoFieldType              = "geo_point"
            geoFieldName              = "location"
            documentRequestNumber     = 1000
            tooltipFields             = @(
                "scenario",
                "event_type",
                "srcip",
                "target_agent",
                "rule_id",
                "response",
                "business_message"
            )
            showTooltips              = $true
            indexPatternId            = $GeoIndex
            useGeoBoundingBoxFilter   = $true
            filters                   = @(
                (New-MapFilter -Field "event_type" -Value $EventType -IndexPatternId $GeoIndex)
            )
        }
        style       = [ordered]@{
            fillColor       = $FillColor
            borderColor     = $FillColor
            borderThickness = 1
            markerSize      = $MarkerSize
        }
    }
}

$now = (Get-Date).ToUniversalTime().ToString("o")
$gcpCentral = New-GeoPoint -Lat 41.2619 -Lon -95.8608
$mexicoCity = New-GeoPoint -Lat 19.4326 -Lon -99.1332

$mapping = [ordered]@{
    settings = [ordered]@{
        number_of_shards   = 1
        number_of_replicas = 0
    }
    mappings = [ordered]@{
        properties = [ordered]@{
            timestamp            = [ordered]@{ type = "date" }
            location             = [ordered]@{ type = "geo_point" }
            destination_location = [ordered]@{ type = "geo_point" }
            srcip                = [ordered]@{ type = "ip" }
            dstip                = [ordered]@{ type = "ip" }
            scenario             = [ordered]@{ type = "keyword" }
            event_type           = [ordered]@{ type = "keyword" }
            response             = [ordered]@{ type = "keyword" }
            rule_id              = [ordered]@{ type = "keyword" }
            severity             = [ordered]@{ type = "keyword" }
            target_agent         = [ordered]@{ type = "keyword" }
            source_label         = [ordered]@{ type = "keyword" }
            business_message     = [ordered]@{
                type   = "text"
                fields = [ordered]@{
                    keyword = [ordered]@{ type = "keyword"; ignore_above = 256 }
                }
            }
        }
    }
}

$events = @(
    [ordered]@{
        id                   = "bruteforce-redhat-ui-private"
        timestamp            = $now
        scenario             = "SSH brute force contra RedHat-UI"
        event_type           = "brute_force"
        severity             = "P2"
        rule_id              = "100020"
        srcip                = "192.168.162.129"
        dstip                = "192.168.162.128"
        source_label         = "Atacante interno/lab"
        target_agent         = "RedHat-UI"
        response             = "firewall-drop all peers 120s"
        business_message     = "La IP que fuerza SSH contra el usuario esquivel se bloquea en todos los agentes conectados por 2 minutos."
        location             = $mexicoCity
        destination_location = $mexicoCity
    }
    [ordered]@{
        id                   = "bruteforce-db-server-public"
        timestamp            = $now
        scenario             = "SSH brute force repetido contra db-server"
        event_type           = "brute_force"
        severity             = "P2"
        rule_id              = "100120"
        srcip                = "34.146.217.105"
        dstip                = "10.0.1.23"
        source_label         = "Origen internet"
        target_agent         = "db-server"
        response             = "firewall-drop all peers 120s"
        business_message     = "Intentos repetidos de autenticacion desde la misma IP disparan bloqueo global temporal."
        location             = New-GeoPoint -Lat 35.6762 -Lon 139.6503
        destination_location = $gcpCentral
    }
    [ordered]@{
        id                   = "portscan-linux-ui-netherlands"
        timestamp            = $now
        scenario             = "Port scan observado en Linux UI"
        event_type           = "port_scan"
        severity             = "P2"
        rule_id              = "100030"
        srcip                = "45.142.193.12"
        dstip                = "10.0.1.25"
        source_label         = "Scanner externo"
        target_agent         = "linux-ui-workstation"
        response             = "firewall-drop local 120s"
        business_message     = "El escaneo de puertos se bloquea localmente en el endpoint que recibio el trafico."
        location             = New-GeoPoint -Lat 52.3676 -Lon 4.9041
        destination_location = $gcpCentral
    }
    [ordered]@{
        id                   = "portscan-linux-ui-california"
        timestamp            = $now
        scenario             = "Reconocimiento externo contra Linux UI"
        event_type           = "port_scan"
        severity             = "P3"
        rule_id              = "40101"
        srcip                = "64.62.197.225"
        dstip                = "10.0.1.25"
        source_label         = "Scanner externo"
        target_agent         = "linux-ui-workstation"
        response             = "firewall-drop local 120s"
        business_message     = "Otro punto de origen de reconocimiento queda visible como concentracion geografica de ruido."
        location             = New-GeoPoint -Lat 37.5485 -Lon -121.9886
        destination_location = $gcpCentral
    }
    [ordered]@{
        id                   = "malicious-reputation-source"
        timestamp            = $now
        scenario             = "IP con reputacion maliciosa conocida"
        event_type           = "malicious_ip"
        severity             = "P1"
        rule_id              = "100100"
        srcip                = "20.64.106.222"
        dstip                = "34.42.29.92"
        source_label         = "Lista AlienVault"
        target_agent         = "pyme-demo-target"
        response             = "firewall-drop all peers 600s"
        business_message     = "Una IP con reputacion maliciosa se bloquea en todo el laboratorio por 10 minutos."
        location             = New-GeoPoint -Lat 53.3498 -Lon -6.2603
        destination_location = $gcpCentral
    }
    [ordered]@{
        id                   = "controlled-kali-scan"
        timestamp            = $now
        scenario             = "Kali controlado ejecuta Nmap"
        event_type           = "controlled_recon"
        severity             = "P3"
        rule_id              = "100212"
        srcip                = "34.27.250.217"
        dstip                = "10.0.1.25"
        source_label         = "kali-attacker"
        target_agent         = "linux-ui-workstation"
        response             = "telemetria controlada"
        business_message     = "Actividad red-team autorizada para demostrar visibilidad y trazabilidad."
        location             = $gcpCentral
        destination_location = $gcpCentral
    }
    [ordered]@{
        id                   = "fim-sensitive-linux-ui"
        timestamp            = $now
        scenario             = "FIM en /home/esquivel/Confidencial"
        event_type           = "asset_signal"
        severity             = "P1"
        rule_id              = "100010,100015"
        srcip                = "136.119.238.132"
        dstip                = "10.0.1.25"
        source_label         = "Activo protegido"
        target_agent         = "linux-ui-workstation"
        response             = "alerta y triage SOC"
        business_message     = "Cambios en carpeta confidencial se presentan como activo critico protegido."
        location             = $gcpCentral
        destination_location = $gcpCentral
    }
    [ordered]@{
        id                   = "n8n-vulnerability-triage"
        timestamp            = $now
        scenario             = "n8n crea ticket de vulnerabilidad"
        event_type           = "asset_signal"
        severity             = "P3"
        rule_id              = "vulnerability-detection"
        srcip                = "34.61.115.165"
        dstip                = "10.0.1.8"
        source_label         = "n8n-automation"
        target_agent         = "wazuh.manager"
        response             = "ticket Jira / triage"
        business_message     = "La automatizacion convierte hallazgos de vulnerabilidad en accion rastreable."
        location             = $gcpCentral
        destination_location = $gcpCentral
    }
    [ordered]@{
        id                   = "docker-container-restart"
        timestamp            = $now
        scenario             = "Docker: reinicio de customer-portal"
        event_type           = "container_security"
        severity             = "P3"
        rule_id              = "100191"
        srcip                = "10.0.1.30"
        dstip                = "10.0.1.30"
        source_label         = "Docker Engine"
        target_agent         = "docker-host"
        response             = "docker-listener + alerta SOC"
        business_message     = "El agente del host Docker observa cambios del runtime y los muestra como actividad de contenedores."
        location             = $gcpCentral
        destination_location = $gcpCentral
    }
    [ordered]@{
        id                   = "docker-image-pull"
        timestamp            = $now
        scenario             = "Docker: nueva imagen descargada"
        event_type           = "container_security"
        severity             = "P3"
        rule_id              = "100192"
        srcip                = "34.117.59.81"
        dstip                = "10.0.1.30"
        source_label         = "Registry externo"
        target_agent         = "docker-host"
        response             = "revision de imagen"
        business_message     = "La descarga de imagenes queda visible para explicar cambios en la superficie de contenedores."
        location             = New-GeoPoint -Lat 41.8781 -Lon -87.6298
        destination_location = $gcpCentral
    }
    [ordered]@{
        id                   = "docker-config-drift"
        timestamp            = $now
        scenario             = "Docker: drift de configuracion web"
        event_type           = "container_security"
        severity             = "P2"
        rule_id              = "100193"
        srcip                = "10.0.1.30"
        dstip                = "10.0.1.30"
        source_label         = "FIM / Docker host"
        target_agent         = "docker-host"
        response             = "triage de cambio"
        business_message     = "FIM complementa Docker listener mostrando cambios en archivos montados por el contenedor."
        location             = $gcpCentral
        destination_location = $gcpCentral
    }
    [ordered]@{
        id                   = "gcp-iam-policy-change"
        timestamp            = $now
        scenario             = "GCP: cambio de politica IAM"
        event_type           = "cloud_security"
        severity             = "P2"
        rule_id              = "100313"
        srcip                = "35.235.240.1"
        dstip                = "10.0.1.8"
        source_label         = "Cloud Audit Logs"
        target_agent         = "wazuh.manager"
        response             = "revision de privilegios"
        business_message     = "Cloud Security convierte cambios de control plane en eventos SOC para revisar permisos."
        location             = New-GeoPoint -Lat 37.4220 -Lon -122.0841
        destination_location = $gcpCentral
    }
    [ordered]@{
        id                   = "gcp-compute-instance-stop"
        timestamp            = $now
        scenario             = "GCP: instancia detenida"
        event_type           = "cloud_security"
        severity             = "P3"
        rule_id              = "100314"
        srcip                = "35.235.240.2"
        dstip                = "10.0.1.8"
        source_label         = "Cloud Audit Logs"
        target_agent         = "wazuh.manager"
        response             = "validacion operativa"
        business_message     = "Eventos de infraestructura cloud ayudan a detectar cambios inesperados de disponibilidad."
        location             = New-GeoPoint -Lat 45.5019 -Lon -73.5674
        destination_location = $gcpCentral
    }
)

$indexPatternFields = @(
    [ordered]@{ name = "timestamp"; type = "date"; esTypes = @("date"); searchable = $true; aggregatable = $true; readFromDocValues = $true }
    [ordered]@{ name = "location"; type = "geo_point"; esTypes = @("geo_point"); searchable = $true; aggregatable = $true; readFromDocValues = $true }
    [ordered]@{ name = "destination_location"; type = "geo_point"; esTypes = @("geo_point"); searchable = $true; aggregatable = $true; readFromDocValues = $true }
    [ordered]@{ name = "srcip"; type = "ip"; esTypes = @("ip"); searchable = $true; aggregatable = $true; readFromDocValues = $true }
    [ordered]@{ name = "dstip"; type = "ip"; esTypes = @("ip"); searchable = $true; aggregatable = $true; readFromDocValues = $true }
    [ordered]@{ name = "scenario"; type = "string"; esTypes = @("keyword"); searchable = $true; aggregatable = $true; readFromDocValues = $true }
    [ordered]@{ name = "event_type"; type = "string"; esTypes = @("keyword"); searchable = $true; aggregatable = $true; readFromDocValues = $true }
    [ordered]@{ name = "response"; type = "string"; esTypes = @("keyword"); searchable = $true; aggregatable = $true; readFromDocValues = $true }
    [ordered]@{ name = "rule_id"; type = "string"; esTypes = @("keyword"); searchable = $true; aggregatable = $true; readFromDocValues = $true }
    [ordered]@{ name = "severity"; type = "string"; esTypes = @("keyword"); searchable = $true; aggregatable = $true; readFromDocValues = $true }
    [ordered]@{ name = "target_agent"; type = "string"; esTypes = @("keyword"); searchable = $true; aggregatable = $true; readFromDocValues = $true }
    [ordered]@{ name = "source_label"; type = "string"; esTypes = @("keyword"); searchable = $true; aggregatable = $true; readFromDocValues = $true }
    [ordered]@{ name = "business_message"; type = "string"; esTypes = @("text"); searchable = $true; aggregatable = $false; readFromDocValues = $false }
)

$indexPatternObject = [ordered]@{
    type       = "index-pattern"
    id         = $GeoIndex
    attributes = [ordered]@{
        title          = $GeoIndex
        timeFieldName  = "timestamp"
        fields         = (ConvertTo-CompactJson $indexPatternFields)
        fieldFormatMap = "{}"
    }
}

$baseLayer = [ordered]@{
    name        = "OpenStreetMap"
    description = "Mapa base publico para la demo SOC."
    type        = "custom_map"
    id          = "soc-geo-base-osm"
    zoomRange   = @(0, 22)
    opacity     = 100
    visibility  = "visible"
    source      = [ordered]@{
        url         = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
        customType  = "tms"
        attribution = "OpenStreetMap contributors"
        layers      = ""
        styles      = ""
        version     = ""
        format      = ""
        crs         = ""
        bbox        = ""
    }
}

$layers = @(
    $baseLayer
    (New-DocumentLayer `
        -Name "Fuerza bruta - bloqueo global 2m" `
        -Description "Reglas 100020, 100120 y 5712; firewall-drop a todos los agentes conectados." `
        -Id "soc-geo-layer-bruteforce" `
        -EventType "brute_force" `
        -FillColor "#d62728" `
        -MarkerSize 8)
    (New-DocumentLayer `
        -Name "IP maliciosa - reputacion" `
        -Description "Regla 100100; bloqueo global por reputacion AlienVault." `
        -Id "soc-geo-layer-malicious-ip" `
        -EventType "malicious_ip" `
        -FillColor "#8c1d40" `
        -MarkerSize 9)
    (New-DocumentLayer `
        -Name "Escaneo y reconocimiento" `
        -Description "Port scan y actividad de reconocimiento sobre Linux UI." `
        -Id "soc-geo-layer-port-scan" `
        -EventType "port_scan" `
        -FillColor "#ff7f0e" `
        -MarkerSize 7)
    (New-DocumentLayer `
        -Name "Kali controlado" `
        -Description "Actividad red-team autorizada desde kali-attacker." `
        -Id "soc-geo-layer-controlled-recon" `
        -EventType "controlled_recon" `
        -FillColor "#9467bd" `
        -MarkerSize 7)
    (New-DocumentLayer `
        -Name "Activos protegidos y automatizacion" `
        -Description "FIM sensible, n8n y senales de activos criticos del laboratorio." `
        -Id "soc-geo-layer-assets" `
        -EventType "asset_signal" `
        -FillColor "#1f77b4" `
        -MarkerSize 8)
    (New-DocumentLayer `
        -Name "Docker - Container Security" `
        -Description "Eventos del host Docker: reinicios, pulls de imagenes y drift de archivos montados." `
        -Id "soc-geo-layer-container-security" `
        -EventType "container_security" `
        -FillColor "#2ca02c" `
        -MarkerSize 8)
    (New-DocumentLayer `
        -Name "GCP - Cloud Security" `
        -Description "Eventos cloud simulados: IAM policy change y cambios de compute para demo visual." `
        -Id "soc-geo-layer-cloud-security" `
        -EventType "cloud_security" `
        -FillColor "#17becf" `
        -MarkerSize 8)
)

$mapState = [ordered]@{
    timeRange       = [ordered]@{ from = "now-7d"; to = "now" }
    query           = [ordered]@{ query = ""; language = "kuery" }
    refreshInterval = [ordered]@{ pause = $true; value = 12000 }
}

$mapObject = [ordered]@{
    type       = "map"
    id         = $MapId
    attributes = [ordered]@{
        title       = "SOC Geo - Amenazas y respuesta"
        description = "Mapa geografico del lab: fuerza bruta, port scan, reputacion maliciosa, Kali controlado, FIM, n8n, Docker y Cloud Security."
        layerList   = (ConvertTo-CompactJson $layers)
        mapState    = (ConvertTo-CompactJson $mapState)
    }
    references = @()
}

Write-Utf8NoBom -Path $MappingFile -Value (ConvertTo-CompactJson $mapping)

$bulkLines = New-Object System.Collections.Generic.List[string]
foreach ($event in $events) {
    $eventId = $event.id
    $indexAction = [ordered]@{
        index = [ordered]@{
            _index = $GeoIndex
            _id    = $eventId
        }
    }
    $bulkLines.Add((ConvertTo-CompactJson $indexAction))
    $bulkLines.Add((ConvertTo-CompactJson $event))
}
Write-Utf8NoBom -Path $BulkFile -Value (($bulkLines -join "`n") + "`n")

$savedObjectLines = @(
    (ConvertTo-CompactJson $indexPatternObject)
    (ConvertTo-CompactJson $mapObject)
)
Write-Utf8NoBom -Path $MapObjectsFile -Value ($savedObjectLines -join "`n")

Write-Host "Preparing remote map import directory on $InstanceName..."
gcloud compute ssh $InstanceName `
    --project=$ProjectId `
    --zone=$Zone `
    --quiet `
    --command="rm -rf $RemoteDir && mkdir -p $RemoteDir"
Assert-NativeCommand -Description "Preparing remote directory"

Write-Host "Copying map mapping, data and saved objects..."
gcloud compute scp `
    --project=$ProjectId `
    --zone=$Zone `
    --quiet `
    $MappingFile `
    $BulkFile `
    $MapObjectsFile `
    "${InstanceName}:$RemoteDir/"
Assert-NativeCommand -Description "Copying map files"

$RemoteCommand = @"
set -e
STATUS=`$(curl -sk -o /dev/null -w '%{http_code}' -u '$DashboardAuth' 'https://localhost:9200/$GeoIndex')
if [ "`$STATUS" = "404" ]; then
  curl -sk -u '$DashboardAuth' -H 'Content-Type: application/json' -X PUT 'https://localhost:9200/$GeoIndex' --data-binary '@$RemoteDir/soc-lab-geo-events-mapping.json'
fi
curl -sk -u '$DashboardAuth' -H 'Content-Type: application/x-ndjson' -X POST 'https://localhost:9200/_bulk?refresh=true' --data-binary '@$RemoteDir/soc-lab-geo-events.bulk.ndjson'
curl -fsk -u '$DashboardAuth' -H 'osd-xsrf: true' -F file=@$RemoteDir/wazuh-soc-map.ndjson 'https://localhost/api/saved_objects/_import?overwrite=true'
"@

Write-Host "Creating geo index, loading lab points and importing map..."
$ImportResponse = gcloud compute ssh $InstanceName `
    --project=$ProjectId `
    --zone=$Zone `
    --quiet `
    --command=$RemoteCommand
Assert-NativeCommand -Description "Importing SOC geo map"

$ImportResponse

$DashboardBaseUrl = "https://YOUR_WAZUH_IP"
try {
    $TerraformDir = Join-Path $RepoRoot "terraform\wazuh-deploy"
    $ManagerIp = terraform "-chdir=$TerraformDir" output -raw wazuh_manager_public_ip
    if ($ManagerIp) {
        $DashboardBaseUrl = "https://$ManagerIp"
    }
} catch {
    Write-Warning "Could not resolve current dashboard public IP automatically."
}

Write-Host "SOC geo map URL: $DashboardBaseUrl/app/maps-dashboards#/view/$MapId"
Write-Host "If the direct URL does not open, go to Wazuh Dashboard > Maps and open: SOC Geo - Amenazas y respuesta"
