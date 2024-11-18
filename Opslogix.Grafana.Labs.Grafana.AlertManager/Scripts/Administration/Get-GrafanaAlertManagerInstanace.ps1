$ClassName = "Opslogix.Grafana.Labs.Grafana.AlertManager.Instance.Endpoint.Class"
$GrafanaDisplayName = "<DisplayName of Grafana Instance>" # Enter DisplayName of Grafana Instance

## Start execution
New-SCOMManagementGroupConnection -ComputerName "localhost"
$MG = Get-SCOMManagementGroup

# Get the class
$Class = Get-SCOMClass -Name $ClassName

# Find the instance based on its property value (in this case the DisplayName)
$Instance = Get-SCOMClassInstance -Class $Class | Where-Object DisplayName -eq $GrafanaDisplayName

