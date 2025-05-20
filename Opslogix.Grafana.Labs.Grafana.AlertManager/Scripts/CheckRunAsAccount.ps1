param(
    $QueryUser,
    $QueryPwd,
    $Debug
)

### Define Operations Manager objects ###
$momScriptAPI = new-object -comObject 'MOM.ScriptAPI'

$scriptName = "Opslogix.Grafana.Labs.Grafana.Alertmanager.CheckRunAsAccount.ps1"
$version = "1.0.0"
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

Write-InfoEvent -EventID 5470 -Message "$QueryUser/$QueryPwd" 

#Check if RunAsAccount is empty

if ($null -eq $QueryPwd -or "" -eq $QueryPwd)
{
    #RunAsAccount is empty so create an Alert
    $alertSummary = "RunAsAccount is not configured. Please configure a RunAsAccount and added it ot the Grafana Alertmanager Run As Profile"

    Write-InfoEvent -EventID 5470 -Message "$alertSummary" 
    # Creating the property bag  
    $propertyBag = $momScriptAPI.CreatePropertyBag()
    $propertyBag.AddValue('Result', "CRITICAL")
    $propertyBag.AddValue('AlertSummary', $alertSummary)
    #$momScriptAPI.Return($propertyBag)
    $propertyBag
}
else {
    $alertSummary = "RunAsAccount is configured. Everything is OK"

    Write-InfoEvent -EventID 5470 -Message "$alertSummary"
    # Creating the property bag 
    $propertyBag = $momScriptAPI.CreatePropertyBag()
    $propertyBag.AddValue('Result', "OK")
    $propertyBag.AddValue('AlertSummary', $alertSummary)
    #$momScriptAPI.Return($propertyBag)
    $propertyBag
}
Write-InfoEvent -EventID 5470 -Message $scriptOutput
