# rqp-plugin-dnf

ReqPack Lua wrapper for DNF.

## Scope

- install normal RPM packages through `dnf`
- install local `.rpm` artifacts
- remove and update installed packages
- list installed packages through `rpm`
- search, inspect, and resolve packages through `dnf`
- report outdated packages

Not in scope for v1:

- DNF package groups
- DNF module streams such as `nodejs:18`

## Commands Covered

- `install`: `dnf install -y`
- `installLocal`: `dnf install -y /path/to/file.rpm`
- `remove`: `dnf remove -y`
- `update`: `dnf upgrade -y`
- `list`: `rpm -qa --queryformat ...`
- `search`: `dnf repoquery --available --latest-limit 1 ...`
- `info`: `rpm -qi` with `dnf info` fallback
- `outdated`: `dnf repoquery --upgrades ...`
- `resolvePackage`: `dnf repoquery --latest-limit 1 ...`

## Notes

- versioned requests such as `curl@8.9.1` are forwarded as `curl-8.9.1`
- mutation commands pass ReqPack exec `rules` for DNF phase/progress parsing
- local artifact inference uses `plugin.fileExtensions = { ".rpm" }`
- security metadata maps this plugin to OSV ecosystem `RPM`

## Testing

Run core conformance cases from plugin root:

```bash
rqp test-plugin --plugin ./run.lua --cases ./.reqpack-test/core
```

Run one case directly:

```bash
rqp test-plugin --plugin ./run.lua --case ./.reqpack-test/core/info.lua
```
