# Microsoft Intune: Printer Driver and TCP/IP Printer Deployment (Win32 App + PowerShell)

This folder contains three PowerShell scripts (Installation, Uninstallation, and Detection) to deploy and manage traditional network printers through **Microsoft Intune Win32 apps**, without requiring Microsoft Universal Print.

The deployment installs a printer driver from a locally packaged INF file, creates a Standard TCP/IP printer port, and configures a local printer queue on the Windows device.

The installation and uninstallation scripts are designed to run in the **SYSTEM context**, allowing printers to be deployed without requiring local administrator privileges for the signed-in user.

The scripts are printer-independent and can be adapted to different manufacturers and models by changing the parameters provided through Microsoft Intune.

---

## Repository contents

- `Install-Printer.ps1`  
  Stages the printer driver in the Windows Driver Store, registers the driver, creates the TCP/IP port, and installs the printer queue.

- `Uninstall-Printer.ps1`  
  Removes the printer queue and optionally removes its TCP/IP port when it is no longer used by other printers. The printer driver is intentionally preserved.

- `Detect-Printer.ps1`  
  Verifies the installed printer configuration, including printer name, driver name, TCP/IP port name, printer IP address, and TCP port number.

---

## Prerequisites

- Windows 10 or Windows 11 device managed by Microsoft Intune.
- Microsoft Intune Management Extension installed on the device.
- Scripts executed as **SYSTEM** through an Intune Win32 app.
- Windows PowerShell 5.1.
- A complete and compatible printer driver package from the manufacturer.
- Printer driver INF file and all associated files required by the driver package.
- Network connectivity between the Windows device and the printer.
- Microsoft Win32 Content Prep Tool to generate the `.intunewin` package.

The printer must support direct TCP/IP printing using the configured protocol and port.

The examples in this repository use TCP port **9100**, which must be changed if the printer requires a different configuration.

---

## Key concepts

### Deployment workflow

The installation process follows this sequence:

1. Microsoft Intune downloads and extracts the Win32 app package.
2. `Install-Printer.ps1` is executed in the SYSTEM context.
3. The printer driver INF file is located inside the extracted package.
4. PnPUtil stages the driver package in the Windows Driver Store.
5. PowerShell registers the printer driver.
6. A Standard TCP/IP printer port is created or validated.
7. The local printer queue is created or validated.
8. Microsoft Intune executes the custom detection script to verify the installation.

The installation script is designed to handle repeated executions without unnecessarily recreating an existing printer that already matches the expected configuration.

---

## Prepare the printer driver package

Download the appropriate printer driver from the manufacturer's official support website.

Extract the driver package and identify the INF file required for the printer model.

The driver folder must contain the complete package, including any INF, CAT, CAB, DLL, or other files referenced by the driver.

### Example folder structure

```text
C:\IntunePackages\Printers\EPSON-WF-2510-Floor1
│
├── Source
│   ├── Install-Printer.ps1
│   ├── Uninstall-Printer.ps1
│   │
│   └── Drivers
│       ├── E_WF1IXE.INF
│       ├── E_WF1IXE.CAT
│       └── Other driver files...
│
└── Output
```

The `Drivers` folder must be located inside `Source`, because Microsoft Win32 Content Prep Tool includes the contents of the source directory when creating the `.intunewin` package.

The `Output` folder should remain outside `Source` to avoid including previously generated packages.

### Identify the correct printer driver name

The printer driver name used by the installation script must match the name registered in Windows.

On a test device where the driver is already installed, execute:

```powershell
Get-PrinterDriver |
    Sort-Object Name |
    Select-Object Name, Manufacturer, DriverVersion
```

For the example used in this repository:

```text
Printer name: IT Floor 1 - EPSON WF-2510

Driver name: EPSON WF-2510 Series

Driver INF: E_WF1IXE.INF
```

The INF filename and printer driver name are different values and must not be used interchangeably.

---

## Installation script: how it works (step-by-step)

`Install-Printer.ps1` receives the printer configuration through command-line parameters.

The script does not contain hardcoded printer names, IP addresses, or driver filenames.

### Parameters

| Parameter | Description | Required |
|---|---|---|
| `-PrinterName` | Display name of the printer in Windows | Yes |
| `-PrinterIP` | Printer IP address or DNS name | Yes |
| `-DriverName` | Exact printer driver name | Yes |
| `-InfFile` | Relative path to the printer driver INF file | Yes |
| `-PortName` | Name of the TCP/IP printer port | No |
| `-PortNumber` | TCP port used by the printer. Default: 9100 | No |

If `-PortName` is omitted, the script automatically generates a name using `IP_<PrinterIP>`.

### Installation process

1. Validates that the specified INF file exists inside the extracted Win32 app package.

2. Stages the driver package in the Windows Driver Store using:

   ```powershell
   pnputil.exe /add-driver
   ```

3. Checks whether the printer driver is already registered.

   If the driver is missing, it executes `Add-PrinterDriver`.

4. Checks whether the specified TCP/IP printer port exists.

   If the port is missing, it creates the port using `Add-PrinterPort`.

5. If the port already exists, validates its IP address and TCP port number.

   If the existing configuration does not match the expected values, the installation fails rather than silently reusing an incorrectly configured port.

6. Checks whether the printer queue already exists.

   If the printer is missing, it creates the queue using `Add-Printer`.

7. If a printer with the same name exists but uses a different driver or port, the script removes and recreates the queue.

8. Verifies the final printer configuration and returns the installation result.

Successful installation returns `exit 0`.

Installation failure returns `exit 1`.

### Important note about existing printers

If a printer with the specified name already exists but uses a different driver or port, the installation script removes and recreates the printer queue.

This operation can affect pending print jobs and existing printer-specific settings.

Test the behavior before deploying the application to production devices.

---

## Uninstallation script: how it works (step-by-step)

`Uninstall-Printer.ps1` removes a printer previously deployed through the installation script.

The uninstallation process is intentionally conservative to reduce the risk of affecting other printers.

### Parameters

| Parameter | Description | Required |
|---|---|---|
| `-PrinterName` | Exact name of the printer to remove | Yes |
| `-PortName` | Name of the associated printer port | No |
| `-RemovePort` | Removes the port if it is no longer used | No |

### Uninstallation process

1. Checks whether the specified printer exists.

2. If the printer exists and no port name was provided, retrieves its associated port.

3. If a port name was explicitly provided, verifies that it matches the printer's configured port.

4. Removes the printer queue using `Remove-Printer`.

5. If `-RemovePort` was specified, checks whether other printers are using the same port.

6. Removes the port only when it is no longer associated with another printer.

7. Preserves the installed printer driver.

Successful uninstallation returns `exit 0`.

Uninstallation failure returns `exit 1`.

### Important note about printer drivers

The uninstallation script does not remove the driver from the Windows Driver Store or unregister the printer driver.

This behavior is intentional because the same driver may be used by other printer queues.

Driver removal should be handled separately after confirming that the driver is no longer required.

---

## Detection script: how it works (step-by-step)

`Detect-Printer.ps1` is designed to be used as a **custom detection script for a Microsoft Intune Win32 app**.

Unlike the installation and uninstallation scripts, the detection script contains printer-specific variables that must be updated before uploading it to Intune.

### Customize this section

Open `Detect-Printer.ps1` and locate:

```powershell
# ============================================================
# CUSTOMIZE THIS SECTION
# ============================================================
```

Update the following variables:

```powershell
$PrinterName = "IT Floor 1 - EPSON WF-2510"

$ExpectedDriverName = "EPSON WF-2510 Series"

$ExpectedPortName = "IP_192.0.2.25"

$ExpectedPrinterIP = "192.0.2.25"

$ExpectedPortNumber = 9100
```

**Replace these example values with your actual printer configuration.**

The address `192.0.2.25` is reserved for documentation and must not be used as the actual destination of a printer deployment.

### Detection process

The detection script verifies the following properties:

1. The printer exists on the device.
2. The printer uses the expected driver.
3. The printer uses the expected TCP/IP port.
4. The printer port exists.
5. The printer port points to the expected IP address or DNS name.
6. The printer port uses the expected TCP port number.

If all values match:

```text
Detected
```

The script writes the detection result to STDOUT and returns `exit 0`.

If the printer is missing or any configuration value does not match, the script returns `exit 1`.

### Important note about Intune detection

For Win32 app custom detection scripts, Microsoft Intune considers an application detected when the script returns exit code `0` and writes data to STDOUT.

A non-zero exit code indicates that the application was not successfully detected.

The detection script verifies the installed printer configuration. It does not verify that the printer can successfully complete a print job.

---

## Create the Win32 app package

Download Microsoft Win32 Content Prep Tool and execute `IntuneWinAppUtil.exe`.

Example:

```powershell
.\IntuneWinAppUtil.exe `
    -c "C:\IntunePackages\Printers\EPSON-WF-2510-Floor1\Source" `
    -s "Install-Printer.ps1" `
    -o "C:\IntunePackages\Printers\EPSON-WF-2510-Floor1\Output" `
    -q
```

The generated package will be:

```text
Install-Printer.intunewin
```

Upload this package to Microsoft Intune as a Windows app (Win32).

**Do not include `Detect-Printer.ps1` in the source folder unless you specifically need it for another purpose.**

The custom detection script is uploaded separately in the Win32 app Detection rules section.

---

## Intune setup (Win32 app)

### 1. Create the application

Open the Microsoft Intune admin center.

Navigate to:

`Apps` → `Windows` → `Add`

Select:

**Windows app (Win32)**

Upload the `.intunewin` package generated in the previous step.

Example application name:

```text
Printer - IT Floor 1 - EPSON WF-2510
```

### 2. Configure the installation command

Example:

```text
%SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-Printer.ps1 -PrinterName "IT Floor 1 - EPSON WF-2510" -PrinterIP "192.0.2.25" -DriverName "EPSON WF-2510 Series" -InfFile ".\Drivers\E_WF1IXE.INF" -PortName "IP_192.0.2.25"
```

Replace the example values with your printer configuration.

The `SysNative` path ensures that 64-bit Windows PowerShell is launched when the installation command is started from a 32-bit process on 64-bit Windows.

### 3. Configure the uninstallation command

Example:

```text
%SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall-Printer.ps1 -PrinterName "IT Floor 1 - EPSON WF-2510" -PortName "IP_192.0.2.25" -RemovePort
```

The `-RemovePort` switch is optional.

Remove it if the printer port should be preserved after uninstalling the printer queue.

### 4. Configure application settings

Recommended settings for the example deployment:

| Setting | Value |
|---|---|
| Install behavior | System |
| Installation time required (mins) | 15 |
| Device restart behavior | No specific action |
| Operating system architecture | 64-bit, when using an x64 driver |
| Minimum operating system | Based on the supported versions of the selected driver |

Restart requirements and supported Windows versions must be validated against the printer manufacturer's driver documentation.

### 5. Configure detection rules

Select:

**Use a custom detection script**

Upload:

```text
Detect-Printer.ps1
```

Recommended settings:

| Setting | Value |
|---|---|
| Run script as 32-bit process on 64-bit clients | No |
| Enforce script signature check and run script silently | No |

Use the signature-check setting required by your organization's security policies. If signature enforcement is enabled, the detection script must be appropriately signed.

### 6. Assign the application

Assign the Win32 app to a pilot group before expanding the deployment.

Example:

```text
INTUNE-WIN-PRINTERS-PILOT
```

Use a **Required** assignment when the printer must be installed automatically.

An **Available** assignment can be used when users should install the printer through Company Portal, provided the assignment and application settings support the intended experience.

---

## Verify the installation

After Microsoft Intune reports a successful installation, verify the printer configuration directly on the Windows device.

### Check the installed printer

```powershell
Get-Printer -Name "IT Floor 1 - EPSON WF-2510" |
    Format-List Name, DriverName, PortName, Shared, Published
```

### Check the printer port

```powershell
Get-PrinterPort -Name "IP_192.0.2.25" |
    Format-List Name, PrinterHostAddress, PortNumber
```

### Check the printer driver

```powershell
Get-PrinterDriver -Name "EPSON WF-2510 Series" |
    Format-List Name, Manufacturer, DriverVersion
```

Replace the example printer name, driver name, and port name with your actual values.

### Check network connectivity

```powershell
Test-NetConnection 192.0.2.25 -Port 9100
```

Replace `192.0.2.25` with the actual printer IP address.

Expected result when the TCP connection succeeds:

```text
TcpTestSucceeded : True
```

A successful TCP connectivity test confirms that the destination port is reachable, but it does not guarantee that the printer driver and queue can successfully process a print job.

Complete the validation by printing a test page from the Windows device.

---

## How to interpret Intune status

### Installed

The installation command completed successfully and the detection script found the expected printer configuration.

### Failed

Possible causes include:

- Missing or invalid driver INF file.
- Incomplete driver package.
- Incorrect printer driver name.
- Printer driver installation failure.
- Existing TCP/IP port with an unexpected configuration.
- PowerShell execution error.
- Insufficient permissions or endpoint security restrictions.

### Not detected

The detection script did not find the expected printer configuration.

Possible causes include:

- The printer is missing.
- The printer name does not match.
- The installed driver name is different.
- The configured printer port is different.
- The printer port points to another IP address.
- The TCP port number does not match.

Always compare the detection script variables with the parameters used in the Win32 app installation command.

---

## Quick troubleshooting

### "Driver INF file not found"

Verify that the INF file exists in the expected location inside the source package.

Example:

```text
Source\Drivers\E_WF1IXE.INF
```

Confirm that the `-InfFile` parameter contains the correct relative path and that the package was rebuilt after adding the driver files.

### "PnPUtil failed"

Possible causes:

- Missing files referenced by the INF.
- Invalid or incompatible driver package.
- Driver signature validation failure.
- Unsupported operating system architecture.

Download the complete driver package from the manufacturer and validate it on a test device.

### "Printer driver installation could not be verified"

The driver was not registered under the expected name.

Check the available drivers:

```powershell
Get-PrinterDriver |
    Select-Object Name, Manufacturer, DriverVersion
```

Update the `-DriverName` parameter with the exact driver name.

### "Existing printer port configuration does not match"

A printer port with the specified name already exists but uses a different IP address or TCP port.

Check the configuration:

```powershell
Get-PrinterPort -Name "IP_192.0.2.25" |
    Format-List *
```

Verify whether the existing port is used by other printers before modifying or removing it.

### Printer installed but not printing

Possible causes:

- Printer IP address changed.
- Network connectivity issue.
- Firewall or network segmentation.
- Incorrect printer protocol or TCP port.
- Printer driver compatibility issue.
- Printer offline or unavailable.

Verify network connectivity and test the printer manually.

### Where to check client logs

The installation and uninstallation scripts create their own logs:

```text
C:\ProgramData\EndpointNinja\PrinterDeployment
```

Microsoft Intune Management Extension logs are located in:

```text
C:\ProgramData\Microsoft\IntuneManagementExtension\Logs
```

Relevant files include:

- `IntuneManagementExtension.log`
- `AppWorkload.log`
- `AppActionProcessor.log`

`AppWorkload.log` is particularly useful for troubleshooting Win32 app deployment activities, while `AppActionProcessor.log` provides information about detection and applicability checks.

---

## Operational safety notes

- Always validate the printer driver on a test device before deploying it through Intune.
- Start with a pilot group before assigning the application to production devices.
- Use drivers obtained from trusted manufacturer sources.
- Do not assume that all printer models support TCP port 9100.
- Do not disable printer security restrictions to work around driver installation issues without evaluating the security impact.
- Avoid removing printer drivers that may be shared by other printer queues.
- Test the installation and uninstallation commands independently before creating the Win32 app.
- Validate the detection script with the same configuration used during installation.
- Remember that recreating an existing printer queue may affect pending print jobs and custom printer settings.
- Review the printer manufacturer's redistribution terms before including driver files in a public repository.

**Printer driver files are not included in this repository.**

Download the required drivers from the manufacturer's official support website and place them in the `Drivers` folder before generating the Win32 app package.

---

## Microsoft references

The following Microsoft Learn documentation provides additional information about the technologies used in this project:

- Prepare Win32 app content for upload to Microsoft Intune.
- Add, assign, and monitor Win32 apps in Microsoft Intune.
- Understand the Microsoft Intune Management Extension.
- PnPUtil command syntax.
- Add-PrinterDriver PowerShell cmdlet.
- Add-PrinterPort PowerShell cmdlet.
- Add-Printer PowerShell cmdlet.

---
