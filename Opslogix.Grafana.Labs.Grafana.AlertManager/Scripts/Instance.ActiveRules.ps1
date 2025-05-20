param(
    [string]$URL,
    $QueryUser,
    $QueryPwd,
    [int]$OrgId,
    $Debug,
    $SendSilencedAlerts
)

### Define Operations Manager objects ###
$momScriptAPI = new-object -comObject 'MOM.ScriptAPI'

$scriptName = "Opslogix.Grafana.Labs.Grafana.Alertmanager.Instance.ActiveRules.ps1"
$version = "1.0.9"
$scriptOutput = ""


# Event log functions
function Write-Event($EventID, $Severity, $Message) {
    If ($Debug.ToUpper() -eq "TRUE"){
        $momScriptAPI.LogScriptEvent($scriptName, $EventID, $Severity, "Version: $version`n$Message")
    }
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

$scriptOutput += "Script running as $whoami.`n"
$scriptOutput += "Param URL: $URL `nUsing access token from Run As Account`n`n"

$OrgId = $OrgId.ToString()
$ServiceAccountToken = "$QueryPwd"
$baseurl = $URL

#Write-WarningEvent -EventID 5470 -Message "URL: $URL, Org: $OrgId, Token: $ServiceAccountToken, UID: $Uid"

# Get the active alerts from Grafana Alertmanager API
$WebRequestHeaders = @{
    "Accept"           = "application/json"
    "Content-Type"     = "application/json"
    "X-Grafana-Org-Id" = "$OrgId"
    "Authorization"    = "Bearer $ServiceAccountToken"
}

#Set variables for getting alert rules
$resourceurl = "/api/v1/provisioning/alert-rules"
$ChecksURI = $baseurl + $resourceurl

# Get Rules - implement try catch otherwise write error event 9201
try {
    $Checks = Invoke-WebRequest -Uri $ChecksURI -UseBasicParsing -Method GET -headers $WebRequestHeaders
}
catch {
    Write-ErrorEvent -EventID 9201 -Message "Failed to get rules from Grafana Alertmanager API. Error: $_"
    Exit
}

#Set variables to get all alerts
$resourceurl = "/api/alertmanager/grafana/api/v2/alerts/"
$ChecksURI = $baseurl + $resourceurl

# Get Alerts - implement try catch otherwise write error event 9201
try {
    $response = Invoke-RestMethod -Uri $ChecksURI -Method GET -headers $WebRequestHeaders
}
catch {
    Write-ErrorEvent -EventID 9201 -Message "Failed to get active alerts from Grafana Alertmanager API. Error: $_"
    Exit
}
#$response = Invoke-RestMethod -Uri "$URL/api/alertmanager/grafana/api/v2/alerts/" -Method Get -headers $WebRequestHeaders

#Loop through each alert rule and filter alerts
Foreach ($check in ($Checks.Content | ConvertFrom-Json)) {

    #Pick up UID and title
    [string]$Uid = ($check).Uid
    [string]$rule = ($check).title

    #Reset variable
    $filteredAlerts = $null
    
    # Filter the response to match the specific rule (alertname)
    $filteredAlerts = $response | Where-Object { $_.labels.__alert_rule_uid__ -eq $Uid }

    $sendAlert = $True
    
    #Set variables to get silence Status
    $resourceurl = "/api/alertmanager/grafana/api/v2/silences"
    $ChecksURI = $baseurl + $resourceurl
    $silenced = "False"

    #Get silence rules
    $silencerules = Invoke-RestMethod -Uri $ChecksURI -Method GET -headers $WebRequestHeaders

    #Loop through each rule and check if Silence is Active
    Foreach ($silencerule in $silencerules){
        if (($silencerule.status.state -eq "active") -and ($silencerule.matchers.value -eq $Uid) -and ($SendSilencedAlerts -eq $False))
        {    
            $sendAlert = $False
        }
    }

    # Check if the output is empty (no active rules)
    if ($null -eq $filteredAlerts -or $filteredAlerts.Count -eq 0) {
        # No active rules = rules is in healthy conditions
        # Write-InfoEvent -EventID 5470 -Message "No active events found for rule $rule, Return ok"
        $alertSummary = "OK, no active Alert Rules in Grafana was found"
        $scriptOutput += "Alert Rule '$rule' is OK`n"
        $scriptOutput += "Result: OK, no active Alert Rules in Grafana was found`n`n"
        $propertyBag = $momScriptAPI.CreatePropertyBag()
        $propertyBag.AddValue('Result', "OK")
        $propertyBag.AddValue('AlertSummary', $alertSummary)
        $propertyBag.AddValue('rule', $rule)
        $propertyBag.AddValue('Uid', $Uid)
        #$momScriptAPI.Return($propertyBag)
        $propertyBag
    }
    else {
        # Build a summary of all active rules
        # Write-InfoEvent -EventID 5470 -Message  "Alert Rule '$rule' is under state Firing:`n`n"
        $alertSummary = "Alert Rule '$rule' is under state Firing:`n`n"
        $scriptOutput += "Alert Rule '$rule' is under state Firing:`n"
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

        if ($sendAlert)
        {
            # Creating the property bag  
            $scriptOutput += "Result: CRITICAL, The rule has fired`n`n"
            $propertyBag = $momScriptAPI.CreatePropertyBag()
            $propertyBag.AddValue('Result', "CRITICAL")
            $propertyBag.AddValue('AlertSummary', $alertSummary)
            $propertyBag.AddValue('rule', $rule)
            $propertyBag.AddValue('Uid', $Uid)
            #$momScriptAPI.Return($propertyBag)
            $propertyBag
        }
        else
        {
            # $sendAlerts set to false = rules is in healthy conditions
            # Write-InfoEvent -EventID 5470 -Message "No active events found for rule $rule, Return ok"
            $alertSummary = "OK, Rule might have Alerts but are silenced"
            $scriptOutput += "Result: OK, Rule might have Alerts but are silenced`n`n"
            $propertyBag = $momScriptAPI.CreatePropertyBag()
            $propertyBag.AddValue('Result', "OK")
            $propertyBag.AddValue('AlertSummary', $alertSummary)
            $propertyBag.AddValue('rule', $rule)
            $propertyBag.AddValue('Uid', $Uid)
            #$momScriptAPI.Return($propertyBag)
            $propertyBag
        }
    }
}

Write-InfoEvent -EventID 5470 -Message $scriptOutput
