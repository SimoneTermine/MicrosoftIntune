# Windows Update certificate rotation 2027 readiness check for Intune

Use this **Microsoft Intune Remediations detection script** to identify Windows devices that are below the servicing baseline Microsoft lists for the **Windows Update certificate rotation in 2027**. It covers supported Windows 10 and Windows 11 releases, plus Windows Server 2016, 2019, 2022, and 2025.

The certificate rotation has two dates: **May 17, 2027** for Windows Server 2016 and the Windows Server 2019 / Windows 10 LTSC 2019 servicing line, and **June 19, 2027** for the other Windows versions listed in Microsoft's guidance. Microsoft says the replacement certificates arrive through monthly Windows security updates.

## What the script checks

`Detect-WindowsUpdateCertificateReadiness.ps1` reads the Windows product, release, build, and UBR. It compares the build with the minimum servicing baseline for the covered release. When the build is below that baseline, or the OS cannot be classified, the script emits a compact JSON result and exits with code `1` so Intune records a detected condition.

The script is **detection-only**. Intune supports remediation packages containing only a detection script. This package does not install an update, start a Windows Update scan, change update policy, or modify the certificate store. Use the device's existing update source and deployment process to install the required cumulative update.

> **Important:** this is a build-based readiness check, not a cryptographic attestation that a particular certificate thumbprint exists. Microsoft's public guidance describes the required Windows update level; it does not provide a universal certificate thumbprint check for this purpose. A device at or above the mapped build is treated as meeting the published update baseline.

## Current baselines in the script

| Windows release | Minimum build used | Microsoft update reference | Deadline |
|---|---:|---|---|
| Windows 11 25H2 and later | No additional action | Microsoft guidance | — |
| Windows 11 24H2 / Windows Server 2025 | `26100.6584` | September 2025 security update, KB5065426 | June 19, 2027 |
| Windows 11 23H2 | `22631.7376` | July 2026 security update, KB5099414 | June 19, 2027 |
| Windows Server 2022 | `20348.5386` | July 2026 security update, KB5099540 | June 19, 2027 |
| Windows 10 22H2 / LTSC 2021 servicing builds | `19045.7548` / `19044.7548` | July 2026 security update, KB5099539 | June 19, 2027 |
| Windows Server 2019 / Windows 10 LTSC 2019 | `17763.9020` | July 2026 security update, KB5099538 | May 17, 2027 |
| Windows Server 2016 | `14393.9339` | July 2026 security update, KB5099535 | May 17, 2027 |

These build mappings are included for reporting convenience and should be reviewed against Microsoft's current release guidance before broad deployment. The script reports unsupported or unrecognized releases as `ManualReview`; it cannot determine ESU enrollment, edition-specific lifecycle entitlement, or whether the device is actually receiving updates from a particular service.

Microsoft's notice excludes devices **receiving updates through WSUS**. The script skips devices whose effective policy has `UseWUServer=1`; verify the actual update source in environments with mixed or dual-scan configuration.

## Deploy with Microsoft Intune

1. In the Intune admin center, go to **Devices > Manage devices > Scripts and remediations** and create a script package.
2. Upload `Detect-WindowsUpdateCertificateReadiness.ps1` as the detection script. Do not add a remediation script; this is a detection-only package.
3. Configure it to run using the signed-in credentials setting appropriate to the package; the script reads machine-level OS and update policy data, so run it as **SYSTEM**.
4. Select **64-bit PowerShell** and assign first to a pilot device group.
5. Review the per-device output and export results for remediation planning. Use your established Windows Update ring, Autopatch, Configuration Manager, or other servicing process to deploy missing updates.

## Results

- **No output, exit code 0:** the detected release is at or above the mapped build, is Windows 11 25H2 or later, or is configured to use WSUS.
- **JSON with `UpdateRequired`, exit code 1:** build is below the published baseline. Deploy the relevant cumulative update through the configured update source.
- **JSON with `ManualReview`, exit code 1:** OS release is not in the script's mapping. Confirm support status and determine the applicable update baseline.
- **JSON with `DetectionError`, exit code 1:** the script could not read required OS information; investigate the Intune Management Extension log and device health.

## Limitations

- Build readiness does not prove that Windows Update connectivity, proxy access, TLS inspection, policy assignment, or update installation is healthy.
- Windows 10 support status varies by edition and ESU/IoT entitlement. The script reports the build baseline only; validate lifecycle coverage separately.
- Devices that use WSUS are skipped according to Microsoft's stated scope. This script does not validate WSUS server certificate health or synchronization.
- The baseline table can change if Microsoft revises its guidance or publishes servicing changes. Review the references before republishing an updated script.
- Test with representative Windows client and server editions before assigning broadly.

## References

- [Microsoft: Prepare for Windows Update certificate rotation in 2027](https://techcommunity.microsoft.com/blog/windows-itpro-blog/prepare-for-windows-update-certificate-rotation-in-2027/4562463)
- [Microsoft: Intune Remediations](https://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations)
- [Windows 11 July 2026 update, KB5099414](https://support.microsoft.com/en-us/servicing/os/windows-11/2026/07/july-14-2026-kb5099414-os-build-22631-7376)
- [Windows 10 and Windows Server 2019 July 2026 update, KB5099538](https://support.microsoft.com/en-us/servicing/os/windows-10/2026/07/july-14-2026-kb5099538-os-build-17763-9020)
- [Windows Server 2016 July 2026 update, KB5099535](https://support.microsoft.com/en-us/servicing/os/windows-10/2026/07/july-14-2026-kb5099535-os-build-14393-9339)
- [Windows 10 July 2026 update, KB5099539](https://support.microsoft.com/en-us/servicing/os/windows-10/2026/07/july-14-2026-kb5099539-os-builds-19045-7548-and-19044-7548)
- [Windows Server 2022 July 2026 update, KB5099540](https://support.microsoft.com/en-us/servicing/os/windows-server/2026/07/july-14-2026-kb5099540-os-build-20348-5386)
- [Windows 11 and Windows Server 2025 September 2025 update, KB5065426](https://support.microsoft.com/en-us/servicing/os/windows-server/2025/09/september-9-2025-kb5065426-os-build-26100-6584)
