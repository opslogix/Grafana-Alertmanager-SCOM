$ClassName = "Opslogix.Grafana.Labs.Grafana.Alertmanager.Instance.Endpoint.Class"

$GrafanaDisplayName = "" # Friendly Name eg "Grafana Instance/OrgId X"
$GrafanaEndpointURL = "" # Enter Grafana URL <httpORhttps>://<IPorFQDN>:<Port>
$GrafanaEndpointOrgId = 1 # Enter Grafana Org Id as integer
## START EXECUTION
New-SCOMManagementGroupConnection -ComputerName "localhost"
$MG = Get-SCOMManagementGroup

#Get the monitoring class
$Class = Get-SCOMClass -Name $ClassName
$ClassInstance = New-Object Microsoft.EnterpriseManagement.Common.CreatableEnterpriseManagementObject($MG,$Class)
$ClassInstance.Id = New-Guid 
$ClassInstance[$Class,"DisplayName"].Value=$GrafanaDisplayName
$ClassInstance[$Class,"URL"].Value=$GrafanaEndpointURL
$ClassInstance[$Class,"OrgId"].Value=$GrafanaEndpointOrgId


$discovery = New-Object Microsoft.EnterpriseManagement.ConnectorFramework.IncrementalDiscoveryData

$discovery.Add($ClassInstance)
$discovery.Commit($MG)

  
 
