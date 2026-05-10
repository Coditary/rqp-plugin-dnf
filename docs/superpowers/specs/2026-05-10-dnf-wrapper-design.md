# DNF Wrapper Design

## Scope

- support normal DNF package operations for ReqPack
- support versioned package requests by forwarding `name@version` as `name-version`
- support local `.rpm` installs
- exclude DNF groups and module streams for v1

## Runtime Shape

- `install`, `installLocal`, `remove`, and `update` call `dnf` directly
- `list` reads installed packages from `rpm -qa --queryformat`
- `search`, `outdated`, and `resolvePackage` use `dnf repoquery`
- `info` prefers installed metadata from `rpm -qi`, then falls back to `dnf info`

## Planning Behavior

- `getMissingPackages` checks installed state with `rpm -q`
- version-specific install checks compare requested version against installed `version-release`
- update checks use `dnf check-update -q <name>` and treat exit code `100` as update available

## Data Mapping

- use RPM package type and OSV ecosystem `RPM`
- expose `.rpm` through `plugin.fileExtensions`
- fill common `PackageInfo` fields: `name`, `version`, `latestVersion`, `installed`, `status`, `summary`, `description`, `architecture`, `license`, and `repository`

## Verification

- replace template core cases with DNF-specific hermetic fixtures
- keep tests fully fake through `fakeExec` rules
