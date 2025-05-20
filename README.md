# Grafana-AlertManager-SCOM

# SCOM Management Pack for Grafana Alertmanager

## Overview

The **SCOM Management Pack for Grafana Alertmanager** enables integration between **System Center Operations Manager (SCOM)** and **Grafana Alertmanager**. This management pack connects to Grafana via its API, retrieves active alert workflows, and creates corresponding SCOM monitors and alerts. This provides a centralized monitoring approach where Grafana alerts are visible and actionable within SCOM.

## Features

- **Automatic Discovery**: Detects alert workflows running in Grafana.
- **Alert Synchronization**: Maps Grafana alerts to SCOM alerts in near real-time.
- **Customizable Monitoring**: Allows configuration of alert thresholds and severity mapping.
- **Secure API Authentication**: Supports API tokens for secure access to Grafana.
- **Event Logging**: Logs API interactions for troubleshooting and auditing.
- **Multi-org support**: Supports multiple organizations running on the same Grafana instance using separate service tokens.

## Requirements

- **SCOM Version**: 2016 or later
- **Grafana Version**: 9.x or later
- **Grafana API Access**: Requires an API token with appropriate permissions
- **Windows Server**: Running the SCOM Management Server
- **.NET Framework**: 4.7.2 or later

## Installation

1. **Download the Management Pack**

   - Obtain the `.mpb` file from the release page.

2. **Import into SCOM**

   - Open the **SCOM Console** → Navigate to **Administration** → Select **Management Packs** → Click **Import Management Pack**.

3. **Configure Grafana API Connection**

   - Create a new API token in Grafana (`Settings` → `API Keys`).
   - In SCOM, navigate to the **Management Pack Configuration** section and enter the **Grafana API URL** and **Token**.

4. **Create Run As Account**

   - Create a new Run As Account in SCOM Console as Basic Authentication with a username (not in use) and the token created in step 3 as Password.

5. **Configure Resource Pool**

   - Modify the Resource Pool 'Grafana Alertmanager Resource Pool' to manual membership and add the computer that shall run the API connection to Grafana. This server needs to have access to the Grafana URL.

6. **Configure Run As Profile**

   - Modify the Run As Profile 'Grafana Alertmanager Run As Profile' and add the Run As Account created in step 4 to 'All targeted objects'. Make sure the account is distributed to the server you added to the Resource Pool in step 5.

7. **Create Grafana Instance in SCOM**

   - Change the script below on line 3, 4 and 5 to change the displayname, url and orgID for the Grafana instance you want to add. After that run the script on a SCOM server which the adds the Grafana Instance to SCOM.

     `$ClassName = "Opslogix.Grafana.Labs.Grafana.Alertmanager.Instance.Endpoint.Class"`

     `$GrafanaDisplayName = "" # Friendly Name eg "Grafana Instance/OrgId X"`
     `$GrafanaEndpointURL = "" # Enter Grafana URL <httpORhttps>://<IPorFQDN>:<Port>`
     `$GrafanaEndpointOrgId = 1 # Enter Grafana Org Id as integer`

     `# Start Execution`

     `New-SCOMManagementGroupConnection -ComputerName "localhost"`
     `$MG = Get-SCOMManagementGroup`

     `#Get the monitoring class`
     `$Class = Get-SCOMClass -Name $ClassName`
     `$ClassInstance = New-Object Microsoft.EnterpriseManagement.Common.CreatableEnterpriseManagementObject($MG,$Class)`
     `$ClassInstance.Id = New-Guid` 
     `$ClassInstance[$Class,"DisplayName"].Value=$GrafanaDisplayName`
     `$ClassInstance[$Class,"URL"].Value=$GrafanaEndpointURL`
     `$ClassInstance[$Class,"OrgId"].Value=$GrafanaEndpointOrgId`


     `$discovery = New-Object Microsoft.EnterpriseManagement.ConnectorFramework.IncrementalDiscoveryData`

     `$discovery.Add($ClassInstance)`
     `$discovery.Commit($MG)`

8. **Enable Discovery**

   - Ensure the discovery rule is enabled to start detecting Grafana alerts.

9. **Verify Monitoring**

   - Check the **SCOM Monitoring Pane** for detected alerts and workflows from Grafana.

## Configuration

- **Alert Mapping**: You can customize how Grafana alerts map to SCOM alerts by adjusting severity levels in the **SCOM Authoring Pane**.
- **Polling Interval**: Default is 60 seconds. This can be modified to reduce API calls.
- **API Endpoint**: Uses `/api/v1/alerts` to fetch active alerts from Grafana Alertmanager.

## Usage

Once installed and configured:

- Grafana alerts will be visible in the SCOM **Active Alerts** view.
- SCOM operators can acknowledge and manage Grafana alerts within SCOM.
- Alert states will update automatically based on Grafana Alertmanager status.

## Troubleshooting

**Issue:** Alerts are not appearing in SCOM.

- Verify the API token has correct permissions (`Viewer` is be required) for each organization.
- Check event logs in SCOM for connection errors.
- Ensure the discovery rule is enabled.

**Issue:** API connection fails.

- Ensure the correct Grafana API URL is configured (e.g., `https://grafana.example.com/api/v1/alerts`).
- Test API connectivity using `curl` or Postman.

# Administration Guide: OpsLogix SCOM Management Pack for Grafana Alertmanager

Use the following PowerShell snippets to **add**, **get**, and **remove** Grafana Alertmanager instances in SCOM. Execute these from a machine with the SCOM PowerShell module and network access to your SCOM management server. Replace the `<…>` placeholders with your actual values.

---

## 1. Add a Grafana Alertmanager Instance

```powershell
# Parameters
$ClassName               = "Opslogix.Grafana.Labs.Grafana.Alertmanager.Instance.Endpoint.Class"
$GrafanaDisplayName      = "<Friendly Name, e.g. 'Grafana Europe/OrgId 1'>"
$GrafanaEndpointURL      = "https://<IP_or_FQDN>:<Port>"
$GrafanaEndpointOrgId    = 1

# Connect to SCOM
New-SCOMManagementGroupConnection -ComputerName "localhost"
$MG = Get-SCOMManagementGroup

# Prepare new class instance
$Class         = Get-SCOMClass -Name $ClassName
$ClassInstance = New-Object Microsoft.EnterpriseManagement.Common.CreatableEnterpriseManagementObject($MG, $Class)
$ClassInstance.Id = [Guid]::NewGuid()
$ClassInstance[$Class, "DisplayName"].Value = $GrafanaDisplayName
$ClassInstance[$Class, "URL"].Value         = $GrafanaEndpointURL
$ClassInstance[$Class, "OrgId"].Value       = $GrafanaEndpointOrgId

# Commit discovery
$discovery = New-Object Microsoft.EnterpriseManagement.ConnectorFramework.IncrementalDiscoveryData
$discovery.Add($ClassInstance)
$discovery.Commit($MG)

Write-Host "Grafana Alertmanager instance '$GrafanaDisplayName' added."
```

---

## 2. Get a Grafana Alertmanager Instance

```powershell
# Parameters
$ClassName          = "Opslogix.Grafana.Labs.Grafana.Alertmanager.Instance.Endpoint.Class"
$GrafanaDisplayName = "<DisplayName of Grafana Instance>"

# Connect to SCOM
New-SCOMManagementGroupConnection -ComputerName "localhost"
$MG = Get-SCOMManagementGroup

# Retrieve instance
$Class    = Get-SCOMClass -Name $ClassName
$Instance = Get-SCOMClassInstance -Class $Class |
            Where-Object { $_.DisplayName -eq $GrafanaDisplayName }

if ($Instance) {
    Write-Host "Found instance:" $Instance.DisplayName
    $Instance
} else {
    Write-Host "Instance '$GrafanaDisplayName' not found."
}
```

---

## 3. Remove a Grafana Alertmanager Instance

```powershell
# Parameters
$ClassName          = "Opslogix.Grafana.Labs.Grafana.Alertmanager.Instance.Endpoint.Class"
$GrafanaDisplayName = "<DisplayName of Grafana Instance to remove>"

# Connect to SCOM
New-SCOMManagementGroupConnection -ComputerName "localhost"
$MG = Get-SCOMManagementGroup

# Find instance
$Class    = Get-SCOMClass -Name $ClassName
$Instance = Get-SCOMClassInstance -Class $Class |
            Where-Object { $_.DisplayName -eq $GrafanaDisplayName }

if ($Instance) {
    # Mark for removal
    $discovery = New-Object Microsoft.EnterpriseManagement.ConnectorFramework.IncrementalDiscoveryData
    $discovery.Remove($Instance)
    $discovery.Commit($MG)
    Write-Host "Grafana instance '$GrafanaDisplayName' removed successfully."
} else {
    Write-Host "Instance '$GrafanaDisplayName' not found."
}
```
