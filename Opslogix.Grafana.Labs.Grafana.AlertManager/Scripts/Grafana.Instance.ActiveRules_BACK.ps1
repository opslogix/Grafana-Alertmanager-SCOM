#Insert parameters if necessary, otherwise remove this
param(
$QueryUser,
$QueryPwd,
[string]$Uid,
[string]$URL,
[string]$rule
)

### Define Operations Manager objects ###
$momScriptAPI = new-object -comObject 'MOM.ScriptAPI'

$scriptName = "Opslogix.Grafana.Labs.Grafana.AlertManager.Instance.ActiveRules.ps1"
$version = "1.0"
$scriptOutput = ""


# Event log functions (samma struktur som det fungerande skriptet)
function Write-Event($EventID, $Severity, $Message) {
    $momScriptAPI.LogScriptEvent($scriptName, $EventID, $Severity, "Version: $version`n$Message")
}
function Write-InfoEvent($EventID, $Message) {
    Write-Event -EventID $EventID -Severity 0 -Message $Message
}
function Write-WarningEvent($EventID, $Message) {
    Write-Event -EventID $EventID -Severity 2 -Message $Message
}
function Write-ErrorEvent($EventID, $Message) {
    Write-Event -EventID $EventID -Severity 1 -Message $Message
}

function Exit-Script() {
    #EventID should be changed
    Write-InfoEvent -EventID 5480 -Message $scriptOutput
    exit
}

#EventID should be changed
Write-InfoEvent -EventID 5450 -Message "Running script to check Grafana alerts. uid: $Uid"

# Get the active alerts from Grafana AlertManager API
$response = Invoke-RestMethod -Uri "$URL/api/alertmanager/grafana/api/v2/alerts/" -Method Get

# Filter the response to match the specific rule (alertname)
$filteredAlerts = $response | Where-Object { $_.labels.alertname -eq $rule }

# Kontrollera om svaret är tomt (inga aktiva larm)
if ($filteredAlerts -eq $null -or $filteredAlerts.Count -eq 0) {
    # Inga aktiva larm, alerten är i normalt tillstånd
    $alertSummary = "Inga aktiva larm - allt är i normalt tillstånd."
    $propertyBag = $momScriptAPI.CreatePropertyBag()
    $propertyBag.AddValue('Result', "OK")
    $propertyBag.AddValue('AlertSummary', $alertSummary)
    $scriptOutput += "$alertSummary"
    ### Return property bag
    $propertyBag
} else {
    # Bygg en sammanfattning över alla aktiva larm
    $alertSummary = "Alert Rule '$rule' is under state Firing:`n`n"
    $generatorURL = "$URL/alerting/grafana/$Uid/view"
    $alertCount = 0
    foreach ($alert in $filteredAlerts) {
        if ($alert.status.state -eq "active") {
            $alertCount++
            $alertName = $alert.labels.alertname
            $alertBeast = $alert.labels.beast
            $alertLevel = $alert.labels.detected_level
            $alertNamespace = $alert.labels.namespace
            $alertStart = $alert.startsAt

            # Lägg till information om varje larm i sammanfattningen
            $alertSummary += "$alertCount. Beast: $alertBeast, Level: $alertLevel, Namespace: $alertNamespace, Start: $alertStart`n"

            # Logga larmet
            $scriptOutput += "Larm är aktivt: $alertName (Beast: $alertBeast, Level: $alertLevel)`n"
        }
    }

    $alertSummary += "`nFor further analysis about the fired alert in Grafana, please visit $generatorURL"

    # Skapa en property bag med CRITICAL-status och lägg till sammanfattningen
    $propertyBag = $momScriptAPI.CreatePropertyBag()
    $propertyBag.AddValue('Result', "CRITICAL")
    $propertyBag.AddValue('AlertSummary', $alertSummary)

    ### Return property bag
    $propertyBag
}

# Avsluta scriptet och logga resultatet
Write-InfoEvent -EventID 5470 -Message $scriptOutput