<#
.SYNOPSIS
    This script retrieves active alerts from Grafana Alertmanager API and filters them based on a specific rule.

.DESCRIPTION
    The script connects to the Grafana Alertmanager API using provided credentials and retrieves active alerts.
    It then filters the alerts based on a specific rule UID and generates a summary of the active alerts.
    The summary is returned as a property bag to be used in Operations Manager (SCOM).

.PARAMETER URL
    The base URL of the Grafana instance.

.PARAMETER QueryUser
    The username for authentication (not used in the script).

.PARAMETER QueryPwd
    The password or token for authentication.

.PARAMETER rule
    The name of the alert rule to filter.

.PARAMETER Uid
    The unique identifier of the alert rule to filter.

.PARAMETER OrgId
    The organization ID in Grafana.

.FUNCTIONS
    Write-Event
        Logs an event to the Operations Manager event log.

    Write-InfoEvent
        Logs an informational event to the Operations Manager event log.

    Write-WarningEvent
        Logs a warning event to the Operations Manager event log.

    Write-ErrorEvent
        Logs an error event to the Operations Manager event log.

.NOTES
    Version: 1.0.9
    Author: Opslogix

.EXAMPLE
    .\Instance.ActiveRules.ps1 -URL "http://grafana.example.com" -QueryPwd "your_token" -rule "HighCPUUsage" -Uid "rule-uid" -OrgId 1

    This example retrieves active alerts from the Grafana instance at "http://grafana.example.com" using the provided token,
    filters the alerts based on the rule UID "rule-uid", and returns a summary of the active alerts.
#>
#Insert parameters if necessary, otherwise remove this
param(
    [string]$URL,
    $QueryUser,
    $QueryPwd,
    [string]$rule,
    [string]$Uid,
    [int]$OrgId
)

### Define Operations Manager objects ###
$momScriptAPI = new-object -comObject 'MOM.ScriptAPI'

$scriptName = "Opslogix.Grafana.Labs.Grafana.Alertmanager.Instance.ActiveRules.ps1"
$version = "1.0.9"
$scriptOutput = ""


# Event log functions
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


#$OrgId = 1
$ServiceAccountToken = "$QueryPwd"

#Write-WarningEvent -EventID 5470 -Message "URL: $URL, Org: $OrgId, Token: $ServiceAccountToken, UID: $Uid"

# Get the active alerts from Grafana Alertmanager API
$WebRequestHeaders = @{
    "Accept"           = "application/json"
    "Content-Type"     = "application/json"
    "X-Grafana-Org-Id" = "$OrgId"
    "Authorization"    = "Bearer $ServiceAccountToken"
}
# implement try catch otherwise write error event 9201
try {
    $response = Invoke-RestMethod -Uri "$URL/api/alertmanager/grafana/api/v2/alerts/" -Method Get -headers $WebRequestHeaders
}
catch {
    Write-ErrorEvent -EventID 9201 -Message "Failed to get active alerts from Grafana Alertmanager API. Error: $_"
    Exit
}
#$response = Invoke-RestMethod -Uri "$URL/api/alertmanager/grafana/api/v2/alerts/" -Method Get -headers $WebRequestHeaders


# Filter the response to match the specific rule (alertname)
$filteredAlerts = $response | Where-Object { $_.labels.__alert_rule_uid__ -eq $Uid }

# Check if the output is empty (no active rules)
if ($null -eq $filteredAlerts -or $filteredAlerts.Count -eq 0) {
    # No active rules = rules is in healthy conditions
    Write-InfoEvent -EventID 5470 -Message "No active events found, Return ok"
    $alertSummary = "OK, no active Alert Rules in Grafana was found"
    $propertyBag = $momScriptAPI.CreatePropertyBag()
    $propertyBag.AddValue('Result', "OK")
    $propertyBag.AddValue('AlertSummary', $alertSummary)
    $propertyBag
}
else {
    # Build a summary of all active rules
    Write-InfoEvent -EventID 5470 -Message  "Alert Rule '$rule' is under state Firing:`n`n"
    $alertSummary = "Alert Rule '$rule' is under state Firing:`n`n"
    $alertCount = 0
    foreach ($alert in $filteredAlerts) {
        if ($alert.status.state -eq "active") {
            $alertCount++
            $alertName = $alert.labels.alertname
            $alertStart = $alert.startsAt
            # Adjust the time and format it to "yyyy-MM-dd HH:mm:ss"
            $alertStart = ([datetime]$alert.startsAt).AddHours(2).ToString("yyyy-MM-dd HH:mm:ss")

            # Adding the information/data into each specific alert/rule in the Summary
            $alertSummary += "$alertStart LABELS: "

            # Dynamically list all available labels on a single line separated by commas
            $labels = @()
            foreach ($label in $alert.labels.PSObject.Properties) {
                $labelName = $label.Name
                $labelValue = $label.Value

                # Exclude specific labels that are not interesting to present in the SCOM alert
                if ($labelName -notin "__alert_rule_uid__", "__grafana_autogenerated__", "__grafana_receiver__", "OperatedBy", "SCOMEnabled", "alertname") {
                    $labels += "[${labelName}: ${labelValue}]"
                }
            }

            $alertSummary += ($labels -join " ") + "`n"
        }
    }

    # Creating the URL that is presented in the SCOM alert
    $generatorURL = "$URL/alerting/grafana/$Uid/view"
    $alertSummary += "`n`nFor further analysis, please visit $generatorURL"

    # Creating the property bag
    $propertyBag = $momScriptAPI.CreatePropertyBag()
    $propertyBag.AddValue('Result', "CRITICAL")
    $propertyBag.AddValue('AlertSummary', $alertSummary)
    $propertyBag.AddValue('rule', $rule)
    $propertyBag
}

Write-InfoEvent -EventID 5470 -Message $scriptOutput
