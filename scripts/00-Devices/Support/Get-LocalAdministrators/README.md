# Export Windows local Administrators group members with PowerShell

Get-LocalAdministrators.ps1 inventories members of the built-in Windows local Administrators group. It resolves the group by its well-known SID, so the script works on localized Windows installations and is useful for endpoint support, security reviews, and Microsoft Intune troubleshooting.

## Run the script

Run from 64-bit PowerShell on Windows:

    & (Join-Path $PWD 'Get-LocalAdministrators.ps1')

To save the result as CSV:

    & (Join-Path $PWD 'Get-LocalAdministrators.ps1') -CsvPath (Join-Path $env:TEMP 'LocalAdministrators.csv')

The CSV includes the computer name, localized group name, member name, object class, principal source, and SID.

## Requirements

- Windows 10, Windows 11, or Windows Server with the Microsoft.PowerShell.LocalAccounts module.
- 64-bit PowerShell on 64-bit Windows.
- Use an elevated session when the current account cannot read local group membership.

## Use with Intune

This is a local support and audit utility. It does not change group membership and is not an Intune Remediations detection or remediation script. For a fleet-wide review, run it through an approved management workflow that securely collects the CSV output.

## Limitations

- The script reports direct members of the local Administrators group. It does not expand nested Active Directory or Microsoft Entra groups to list their effective members.
- The PrincipalSource value may be unavailable on older Windows versions.
- Unresolved or orphaned SIDs can cause the LocalAccounts cmdlet to return an error. Resolve or remove those entries through your normal identity and device management process.
- The script does not remove accounts or assess whether an administrator is authorized.

## References

- Microsoft Learn: [Get-LocalGroupMember](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.localaccounts/get-localgroupmember)
- Microsoft Learn: [Get-LocalGroup](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.localaccounts/get-localgroup)
