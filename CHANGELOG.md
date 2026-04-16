# Changelog

All notable changes to this project will be documented in this file.

The format is inspired by Keep a Changelog and uses a simple project-focused structure.

## [0.1.1] - 2026-04-16

### Fixed
- `ct/archisteamfarm.sh` now runs the installer from this repository after container creation instead of relying on a missing remote install path
- installation now fails clearly when `archisteamfarm.service` is not active after setup
- `install/archisteamfarm-install.sh` is now self-contained and no longer depends on the Community-Scripts in-container helper payload

### Changed
- `README.md` now documents the repo-local installer flow and the need to recreate earlier broken test containers

## [0.1.0] - 2026-04-16

### Added
- Initial repository structure for `AsfAtProxmox`
- `ct/archisteamfarm.sh` as Proxmox host-side container entry script
- `install/archisteamfarm-install.sh` as in-container ASF installer
- `AGENTS.md` with repository-specific contributor and AI-agent instructions
- `docs/README.md` with runtime, maintenance, and troubleshooting notes
- Secure default ASF configuration with generated `IPCPassword`
- `systemd` service setup for ArchiSteamFarm auto-start
- `.gitignore` for local artifacts, logs, editor files, and sensitive runtime data
- `.github/workflows/shell-validation.yml` for automatic `bash -n` and `shellcheck` validation

### Changed
- `README.md` updated with CI workflow documentation and local validation commands
- `AGENTS.md` updated with CI expectations and workflow responsibilities
- `docs/README.md` updated with repository validation guidance

### Notes
- Initial scope targets a single Proxmox LXC for LAN-only testing
- No reverse proxy and no HTTPS are included in this first version
