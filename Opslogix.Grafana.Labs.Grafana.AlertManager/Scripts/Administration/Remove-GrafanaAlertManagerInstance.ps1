$ClassName = "Opslogix.Grafana.Labs.Grafana.AlertManager.Instance.Endpoint.Class"
$GrafanaDisplayName = "<DisplayName of Grafana Instance>" # Enter DisplayName of Grafana Instance to remove

## Start execution
New-SCOMManagementGroupConnection -ComputerName "localhost"
$MG = Get-SCOMManagementGroup

# Get the class
$Class = Get-SCOMClass -Name $ClassName

# Find the instance based on its property value (in this case the DisplayName)
$Instance = Get-SCOMClassInstance -Class $Class | Where-Object DisplayName -eq $GrafanaDisplayName

if ($Instance) {
    # Create the discovery object for removal
    $discovery = New-Object Microsoft.EnterpriseManagement.ConnectorFramework.IncrementalDiscoveryData

    # Mark the instance for removal
    $discovery.Remove($Instance)
    
    # Commit the changes to the management group
    $discovery.Commit($MG)

    Write-Host "Instance removed successfully."
} else {
    Write-Host "Instance not found."
}
