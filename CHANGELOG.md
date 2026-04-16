# Changelog

All notable changes to this project will be documented in this file.

The format is inspired by Keep a Changelog and uses a simple project-focused structure.

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
