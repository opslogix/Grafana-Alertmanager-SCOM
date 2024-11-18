$ClassName = "Opslogix.Grafana.Labs.Grafana.Alertmanager.Instance.Endpoint.Class"

$GrafanaDisplayName = "" # Friendly Name eg "Grafana Instance X"
$GrafanaEndpointURL = "" # Enter Grafana URL <httpORhttps>://<IPorFQDN>:<Port>
## START EXECUTION
New-SCOMManagementGroupConnection -ComputerName "localhost"
$MG = Get-SCOMManagementGroup

#Get the monitoring class
$Class = Get-SCOMClass -Name $ClassName
$ClassInstance = New-Object Microsoft.EnterpriseManagement.Common.CreatableEnterpriseManagementObject($MG,$Class)
$ClassInstance.Id = New-Guid 
$ClassInstance[$Class,"DisplayName"].Value=$GrafanaDisplayName
$ClassInstance[$Class,"URL"].Value=$GrafanaEndpointURL


$discovery = New-Object Microsoft.EnterpriseManagement.ConnectorFramework.IncrementalDiscoveryData

$discovery.Add($ClassInstance)
$discovery.Commit($MG)

  
 
