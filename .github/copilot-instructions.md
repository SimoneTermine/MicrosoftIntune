# Copilot instructions

## Repository structure and conventions

- Preserve the existing hierarchy:
  - `scripts/00-Devices/` contains `CustomCompliance/`, `Enrollment/`, `Remediations/`, and `Support/` scripts.
  - `scripts/01-Apps/Win32/` contains detection, Evergreen Win32 app, MSI, packaging, and printer-driver examples.
  - `scripts/02-Management/Reports/` contains Intune and device inventory reports.
  - `scripts/_Templates/` is reserved for reusable script templates.
  - `tests/` contains Pester tests.
  - Put repository-wide documentation in `docs/`; keep script-specific usage documentation with the script in a `README.md`.
- The root `README.md` is an overview, but its illustrated tree is not exhaustive. Follow the actual folders above and nearby files rather than moving scripts to match the diagram.
- Existing remediation packages do not all contain both detection and remediation scripts: detection-only packages are valid. Keep detection and remediation roles explicit and add only the files needed for the package.
- `docs/` and `scripts/_Templates/` may contain only placeholders. Do not assume a convention or template exists unless the files are present.
- Existing script metadata and README headings are not fully uniform. Apply the new-script requirements below to new work; do not make unrelated legacy edits solely for consistency.

## PowerShell development

- Prefer Windows PowerShell 5.1-compatible syntax and APIs unless the task explicitly targets another version. Avoid PowerShell 7-only syntax and APIs; account for Windows PowerShell's different encoding and native-command behavior.
- Use approved PowerShell verbs and descriptive, consistent function and parameter names.
- Use `[CmdletBinding()]` for scripts or functions that benefit from common parameters, and declare parameters with appropriate types, validation, and help.
- Handle failures deliberately: use `-ErrorAction Stop` where a command's failure must be caught, surface useful errors, and avoid broad catches that hide failures or report success. Use `finally` for cleanup when needed.
- Avoid unnecessary dependencies. Some Microsoft Graph reporting scripts intentionally require Microsoft Graph modules; document the exact module, permissions/scopes, and setup when adding or changing such a dependency. Do not install dependencies automatically.
- Keep behavior safe to rerun where appropriate. Do not silently change existing command-line parameters, output shape, or exit-code behavior.

## Script metadata and help

Every new PowerShell script must include these exact metadata lines in its comment-based help:

```powershell
Author: Simone Termine
Version: 1.1
Blog: https://www.endpointninja.com
```

Include a concise `.SYNOPSIS` and a useful `.DESCRIPTION`; document parameters and examples where applicable. Do not retrofit existing scripts unless specifically requested.

## Microsoft Intune behavior

- Identify each script's deployment surface and role: Intune Remediations detection, Remediations remediation, Win32 app detection/install/uninstall, Custom Compliance, enrollment, support, or reporting. Their output and exit-code contracts differ; follow the applicable Intune contract and the local package's README.
- For Remediations, keep detection separate from state-changing remediation. Conventionally, detection exits `1` when it finds an issue and `0` when no issue is found; a remediation exits `0` on success and nonzero on failure. Preserve documented package-specific output and error semantics.
- For Win32 custom detection, follow its own Intune contract (including the interaction between exit code and standard output); do not apply Remediations exit semantics to it.
- Never add destructive or disruptive actions—such as deletion, reset, uninstall, data removal, or restart—without explicit user approval. Prefer preview/confirmation options where appropriate and clearly document impact and recovery limitations.
- Consider whether execution is as `SYSTEM` or a signed-in user, required permissions, registry view, architecture, and whether 64-bit PowerShell is required. Validate assumptions and fail clearly when prerequisites are unmet.

## Security

- Never hardcode credentials, tokens, private keys, or other secrets. Use supported authentication flows and least-privilege permissions.
- Validate and constrain external input, including paths, identifiers, URLs, and values used to construct commands or API requests. Prefer literal-path parameters for filesystem operations.
- Minimize sensitive output and protect exported inventory or diagnostic data. Treat registry, filesystem, network, and device-management changes as security-sensitive.

## Testing

- Use Pester 5 for automated PowerShell tests. Keep tests under `tests/` and use descriptive `*.Tests.ps1` names.
- Cover normal behavior, errors, negative cases, boundary conditions, and relevant combinations. Assert observable output, side effects, and exit codes without weakening expectations to obtain a passing run.
- Mock registry, filesystem, Graph/network, service, process, and other Windows operations that could access external state or cause changes. Tests must not change real device state, contact external services, or restart a computer unless the user explicitly authorizes that behavior.
- For scripts that call `exit`, isolate execution as needed to verify process exit codes without terminating the Pester host. Account for Pester 5 discovery and execution scopes when initializing fixtures and mocks.
- Run the narrowest relevant tests, report the Pester version and actual results, and investigate failures rather than suppressing them.

## Documentation

- Follow the nearby README's Markdown style and level of detail; headings vary by package, so use sections that suit the script rather than imposing a rigid template.
- Explain purpose, requirements and permissions, execution context, usage/Intune configuration, examples, output or exit-code behavior, limitations, and risks where relevant.
- Keep package documentation next to its scripts and preserve the repository's existing folder hierarchy. Update directly related documentation when behavior changes.

## Git workflow

- Never commit, push, or merge automatically.
- Preserve unrelated and pre-existing worktree changes. Do not revert or reformat unrelated files.
- Summarize every file modified or created and state the validation performed.
- Preserve backward compatibility unless the user explicitly approves a behavior change.
