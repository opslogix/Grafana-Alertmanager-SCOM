Param(
    $SourceId,
    $ManagedEntityId,
    [string]$URL,
    $OrgId,
    $QueryUser,
    $QueryPwd,
    $Debug
)

### Define Operations Manager objects ###
$momScriptAPI = new-object -comObject 'MOM.ScriptAPI'
$DiscoveryData = $momScriptAPI.CreateDiscoveryData(0, $SourceId, $ManagedEntityId);


#Define variables
$scriptName = "Opslogix.Grafana.Labs.Grafana.Alertmanager.Instance.Endpoint.OrgName.Discovery.ps1"
$version = "1.0.0"
$scriptOutput = ""

$OrgId = $OrgId.ToString()

$ServiceAccountToken = "$QueryPwd"
# Gather the start time of the script
$StartTime = Get-Date
#Set variable to be used in logging events
$whoami = whoami


#$computerName = [System.Net.DNS]::GetHostByName('').HostName

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
$scriptOutput += "Param URL: $URL `n Using access token from Run As Account"

####Discovery Script#####

$baseurl = $URL
$resourceurl = "/api/org"
$ChecksURI = $baseurl + $resourceurl

#Null the variables
$Checks = $null
$passed = $false

#Number of passes
$attempt = 0
$maxattempts = 3

#Connect to Web API in a while loop
while ($passed -ne 200 -and $attempt -lt $maxattempts) {
    $attempt += 1
    $scriptOutput += "Number of Attempts: $attempt`n"
    start-sleep 10

    try {
        ## Try to connect to API
        $scriptOutput += "Trying to connect to: $ChecksURI`n"
        #Request data from WebAPI

        $WebRequestHeaders = @{
            "Accept"           = "application/json"
            "Content-Type"     = "application/json"
            "X-Grafana-Org-Id" = "$OrgId"
            "Authorization"    = "Bearer $ServiceAccountToken"
        }
        $Checks = Invoke-WebRequest -Uri $ChecksURI -UseBasicParsing -Method GET -headers $WebRequestHeaders
        # test response
        $passed = $Checks.StatusCode

        # $propertyBag.AddValue('ScriptResult',"GOOD")
        $scriptOutput += "Connection to API a success`n"
        $scriptOutput += "URI to be used in the while loop: $ChecksURI`n"

    }#try

    catch {
        if ($attempt -ge $maxattempts) {
            $scriptOutput += "Connection to API $ChecksURI FAILED`n"
            $scriptOutput += "ScriptResult: BAD`n"
            $scriptOutput += "Error: $_`n"
            Write-InfoEvent -EventID 9201 -Message "FAILED connection to API`nUrl: $ChecksURI`n $Checks`n"
            Write-ErrorEvent -EventID 9201 -Message "$scriptOutput"
            exit
        }#if
    }#catch
}#while

#$checks = Invoke-RestMethod -Uri $ChecksURI -UseBasicParsing -Method GET
#$Checks | Select-Object Uid,ruleGroup,title,condition,isPaused,labels
   
Foreach ($check in ($Checks.Content | ConvertFrom-Json)) {

    [string]$OrgName = ($check).Name
    
    $scriptOutput += "OrgName: $OrgName`n"

    $Inst = $DiscoveryData.CreateClassInstance("$MPElement[Name='Opslogix.Grafana.Labs.Grafana.Alertmanager.Instance.Endpoint.Class']$")
    $Inst.AddProperty("$MPElement[Name='Opslogix.Grafana.Labs.Grafana.Alertmanager.Instance.Endpoint.Class']/URL$", $URL)
    $Inst.AddProperty("$MPElement[Name='Opslogix.Grafana.Labs.Grafana.Alertmanager.Instance.Endpoint.Class']/OrgId$", $OrgId)
    $Inst.AddProperty("$MPElement[Name='Opslogix.Grafana.Labs.Grafana.Alertmanager.Instance.Endpoint.Class']/OrgName$", $OrgName)
    # Add Path property as url/org. Retrieve the org name from the Alertmanager instance
   
    $DiscoveryData.AddInstance($Inst)
    $scriptOutput += "Returning discoverydata: $DiscoveryData`n"
    $scriptOutput += "properties: $URL $OrgId $OrgName`n"
}

# Return Discovery Items
$DiscoveryData

#Log an event for script ending and total execution time.
$EndTime = Get-Date
$ScriptTime = ($EndTime - $StartTime).TotalSeconds
$scriptOutput += "Script took: $ScriptTime seconds`n"

Write-InfoEvent -EventID 9250 -Message $scriptOutput