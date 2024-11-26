<#
.SYNOPSIS
    This script discovers Grafana alert rules and integrates them with Operations Manager.

.DESCRIPTION
    The script connects to the Grafana API to retrieve alert rules and creates discovery data for Operations Manager.
    It logs events and handles errors during the connection process.

.PARAMETER SourceId
    The source identifier for the discovery data.

.PARAMETER ManagedEntityId
    The managed entity identifier for the discovery data.

.PARAMETER URL
    The base URL of the Grafana instance.

.PARAMETER QueryUser
    The username for the Grafana API (not used in this script).

.PARAMETER QueryPwd
    The password or token for the Grafana API.

.PARAMETER OrgId
    The organization ID for the Grafana API.

.EXAMPLE
    .\Instance.AlertRules.Discovery.ps1 -SourceId "source-id" -ManagedEntityId "entity-id" -URL "http://grafana-instance" -QueryUser "user" -QueryPwd "password" -OrgId 1

.NOTES
    Version: 1.0.5
    Author: Opslogix
    This script is part of the Opslogix Grafana Alertmanager integration with SCOM.
#>
#Define Parameters
Param(
    $SourceId,
    $ManagedEntityId,
    [string]$URL,
    $QueryUser,
    $QueryPwd,
    $OrgId
)

### Define Operations Manager objects ###
$momScriptAPI = new-object -comObject 'MOM.ScriptAPI'
$DiscoveryData = $momScriptAPI.CreateDiscoveryData(0, $SourceId, $ManagedEntityId);


#Define variables
$scriptName = "Opslogix.Grafana.Labs.Grafana.Alertmanager.Instance.AlertRules.Discovery.ps1"
$version = "1.0.5"
$scriptOutput = ""

#$OrgId = 1

$ServiceAccountToken = "$QueryPwd"
# Gather the start time of the script
$StartTime = Get-Date
#Set variable to be used in logging events
$whoami = whoami


$computerName = [System.Net.DNS]::GetHostByName('').HostName

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

$scriptOutput += "Script running as $whoami.`n"
$scriptOutput += "Param URL: $URL `n Using access token from Run As Account"

####Discovery Script#####

$baseurl = $URL

#### Todo, change to input parameter #
<#https://github.com/opslogix/Grafana-Alertmanager-SCOM/issues/14#>
$resourceurl = "/api/v1/provisioning/alert-rules"

$ChecksURI = $baseurl + $resourceurl

#Null the variables
$Checks = $null
$passed = $false

#Number of passes
$attempt = 0
$maxattempts = 3

# Write Error event if $ServiceAccountToken is empty
if ($null -eq $ServiceAccountToken) {
    Write-ErrorEvent -EventID 9201 -Message "No Service Account Token found in Run As Account and passed in the script as a parameter. Exiting script."
    exit
}

# Web Request Headers with Bearer Token
$WebRequestHeaders = @{
    "Accept"           = "application/json"
    "Content-Type"     = "application/json"
    "X-Grafana-Org-Id" = "$OrgId"
    "Authorization"    = "Bearer $ServiceAccountToken"
}

#Connect to Web API in a while loop
while ($passed -ne 200 -and $attempt -lt $maxattempts) {
    $attempt += 1
    $scriptOutput += "Number of Attempts: $attempt`n"
    Start-Sleep 10

    try {
        ## Try to connect to API
        $scriptOutput += "Trying to connect to: $ChecksURI`n using token: $ServiceAccountToken`n"
        #Request data from WebAPI
        $Checks = Invoke-WebRequest -Uri $ChecksURI -UseBasicParsing -Method GET -headers $WebRequestHeaders
        # test response
        $passed = $Checks.StatusCode

        # $propertyBag.AddValue('ScriptResult',"GOOD")
        $scriptOutput += "Connection to API a success`n"
        $scriptOutput += "URI to be used in the while loop: $ChecksURI`n"
    }

    catch {
        if ($attempt -ge $maxattempts) {
            $scriptOutput += "Connection to API $ChecksURI FAILED`n"
            $scriptOutput += "ScriptResult: BAD`n"
            $scriptOutput += "Error: $_`n"

            Write-ErrorEvent -EventID 9201 -Message "FAILED discovery connection to API`nUrl: $ChecksURI`n $Checks`n Token: $ServiceAccountToken`n"
            exit             
        }
    }
}

## Why is this called twice, is it only available in the try catch block?
$Checks = Invoke-RestMethod -Uri $ChecksURI -UseBasicParsing -Method GET -Headers $WebRequestHeaders
#$Checks | Select-Object Uid,ruleGroup,title,condition,isPaused,labels
   
Foreach ($check in ($Checks.Content | ConvertFrom-Json)) {

    [string]$Uid = ($check).Uid
    [string]$ruleGroup = ($check).ruleGroup
    [string]$title = ($check).title
    [string]$condition = ($check).condition
    [string]$isPaused = ($check).isPaused
    [string]$labels = ($check).labels

	

    $scriptOutput += "RuleName: $title`n"

    $Inst = $DiscoveryData.CreateClassInstance("$MPElement[Name='Opslogix.Grafana.Labs.Grafana.Alertmanager.Instance.AlertRules.Class']$")
    $Inst.AddProperty("$MPElement[Name='Opslogix.Grafana.Labs.Grafana.Alertmanager.Instance.Endpoint.Class']/URL$", $URL)
    $Inst.AddProperty("$MPElement[Name='Opslogix.Grafana.Labs.Grafana.Alertmanager.Instance.AlertRules.Class']/Uid$", $Uid)
    $Inst.AddProperty("$MPElement[Name='Opslogix.Grafana.Labs.Grafana.Alertmanager.Instance.AlertRules.Class']/ruleGroup$", $ruleGroup)
    $Inst.AddProperty("$MPElement[Name='Opslogix.Grafana.Labs.Grafana.Alertmanager.Instance.AlertRules.Class']/rule$", $title)
    $Inst.AddProperty("$MPElement[Name='Opslogix.Grafana.Labs.Grafana.Alertmanager.Instance.AlertRules.Class']/condition$", $condition)
    $Inst.AddProperty("$MPElement[Name='Opslogix.Grafana.Labs.Grafana.Alertmanager.Instance.AlertRules.Class']/isPaused$", $isPaused)
    $Inst.AddProperty("$MPElement[Name='Opslogix.Grafana.Labs.Grafana.Alertmanager.Instance.AlertRules.Class']/labels$", $labels)
    $Inst.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $title)
   

    $DiscoveryData.AddInstance($Inst)
    $scriptOutput += "Adding discovery data: $DiscoveryData`n"
    $scriptOutput += "properties: $Uid $URL $ruleGroup $title $condition $isPaused $labels`n"
}


# Return Discovery Items
$DiscoveryData

#Log an event for script ending and total execution time.
$EndTime = Get-Date
$ScriptTime = ($EndTime - $StartTime).TotalSeconds
$scriptOutput += "Script took: $ScriptTime seconds`n"


Write-InfoEvent -EventID 9250 -Message $scriptOutput