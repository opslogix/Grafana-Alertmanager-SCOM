#Insert parameters if necessary, otherwise remove this
param(
$QueryUser,
$QueryPwd,
[string]$URL
)

### Define Operations Manager objects ###
$momScriptAPI = new-object -comObject 'MOM.ScriptAPI'
$propertyBag = $momScriptAPI.CreatePropertyBag();
	
$scriptName = "Opslogix.Grafana.Labs.Grafana.AlertManager.Instance.Endpoint.Availability.ps1"
$version = "1.0"
$scriptOutput = ""

#Insert Variables


function Write-Event($EventID, $Severity, $Message)
{
    $momScriptAPI.LogScriptEvent($scriptName, $EventID, $Severity, "Version: $version`n$Message")
}
function Write-InfoEvent($EventID, $Message)
{
    Write-Event -EventID $EventID -Severity 0 -Message $Message
}
function Write-WarningEvent($EventID, $Message)
{
    Write-Event -EventID $EventID -Severity 2 -Message $Message
}
function Write-ErrorEvent($EventID, $Message)
{
	Write-Event -EventID $EventID -Severity 1 -Message $Message
}
function Exit-Script()
{
	#EventID should be changed
    Write-InfoEvent -EventID 5380 -Message $scriptOutput
	exit
}

#EventID should be changed
Write-InfoEvent -EventID 5350 -Message "Running script."

$scriptOutput += "Script started.`n"
$scriptOutput += "URL: $URL`n"

##Certicate handling
<#	
add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
public bool CheckValidationResult(
ServicePoint srvPoint, X509Certificate certificate,
WebRequest request, int certificateProblem) {
return true;
}
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12
#>

<#

$headers = @{
    "api_key" = $Password
    "accept" = "application/json"
}
#>

# create Uri
$baseurl = $URL
$resourceurl = "/api/health"
$uri = $baseurl+ $resourceurl


# Get share information but output only name, path and description

	

#Null the variables
$testResult = $null
$passed = $false

#Number of passes
$attempt = 0
$maxattempts = 3

#Connect to Web API in a while loop
while ($passed -ne $null -and $attempt -lt $maxattempts) {
        $attempt += 1
        $scriptOutput += "Number of Attempts: $attempt`n"
        sleep 10

        try{
            ## Try to connect to API
            $scriptOutput += "Trying to connect to: $uri`n"
			#Request data from WebAPI
			$testResult = Invoke-RestMethod -Uri $uri -Method Get

            # test response
            $passed = $testResult
            $propertyBag.AddValue('Result',"OK")
			$scriptOutput += "Connection to API a success`n"

        }#try

        catch{
            if ($attempt -ge $maxattempts){
                $propertyBag.AddValue('Result',"CRITICAL")
				$propertyBag.AddValue('ErrorMessage', "$_")
				$scriptOutput += "Connection to API $URL FAILED`n"
				$scriptOutput += "ScriptResult: BAD`n"
				$scriptOutput += "Error: $_`n"


                
                        
            }#if
        }#catch
    }#while


### Add property bag values ###
$propertybag.AddValue('Attempt',"$attempt")
$propertybag.AddValue('URL',"$URL")

### Return property bag
$propertyBag


#EventID should be changed     
Write-InfoEvent -EventID 5370 -Message $scriptOutput