# AGENTS.md

This file provides guidance to AI agents working in this repository.

## Specific Instructions

1. **Testing**
   - Always add tests for backend or installation logic changes where practical.
   - For shell-based Proxmox/LXC scripts, syntax checks, validation checks, rerun safety checks, service verification, and CI verification are the minimum expected test surface.
   - Frontend or UI-related changes should include tests when a harness exists; otherwise document manual verification steps.

2. **Code Style & Architecture**
   - Follow **DRY** principles. Avoid duplicated shell blocks, duplicated configuration generation, and duplicated service management logic.
   - Backend logic should remain modular and easy to review.
   - If higher-level backend code is introduced later, prefer **OOP**.
   - For shell code, keep functions short and focused on one responsibility.

3. **Refactoring**
   - You are authorized to refactor for readability, maintainability, safer automation, and DRY compliance.
   - **User permission is required** before any significant refactor that changes execution flow, repository layout, naming conventions, runtime behavior, or migration paths.

4. **Localization (i18n)**
   - If UI text, user-facing console output, or documentation wording changes, update all relevant localization resources.
   - Keep console output concise and readable.

5. **Documentation**
   - Always update `README.md` and all agent instruction files when behavior, commands, paths, configuration flow, setup assumptions, or CI behavior change.
   - The contents of all agent instruction files must remain identical except for the **Specific Instructions** section.
   - Keep all examples aligned with the current repository structure and the current Proxmox/LXC workflow.

6. **Security**
   - Never expose ASF IPC/Web UI publicly without authentication and explicit documentation.
   - Prefer LAN-only access or a reverse proxy over unrestricted public exposure.
   - Treat Steam credentials, shared secrets, 2FA material, IPC passwords, and bot config files as sensitive.
   - Do not hardcode secrets, tokens, passwords, Steam IDs, or example credentials in committed files.

7. **Project Scope**
   - Optimize first for the simple **single-LXC test setup** used by this repository.
   - Keep future expansion to reverse proxy, HTTPS, and Debian 13 possible without breaking the current simple path.
   - Preserve compatibility with the Community-Scripts split between `ct/` entry scripts and `install/` in-container installers.

---

## Project Overview

This repository packages **ArchiSteamFarm (ASF)** for **Proxmox VE** as an **LXC container** with browser-based access through ASF's built-in web interface.

The current repository scope is intentionally simple:
- one LXC
- direct LAN access
- no reverse proxy
- no HTTPS in the initial version

The repository should stay easy to understand, easy to test, and easy to extend.

---

## Architecture

The repository follows a two-stage deployment model.

1. **Proxmox host stage**
   - `ct/archisteamfarm.sh` runs on the Proxmox host.
   - It defines defaults, creates the container, runs the installer from this repository inside the container, and validates the resulting service state.

2. **Container stage**
   - `install/archisteamfarm-install.sh` runs inside the container.
   - It installs dependencies, downloads ASF, writes configuration files, creates the service, starts ASF, and stores connection details.

3. **Application layer**
   - **ASF** is the runtime.
   - **ASF IPC** provides the web/API backend.
   - The browser UI is served through ASF's IPC/web functionality.

4. **Validation layer**
   - `.github/workflows/shell-validation.yml` validates shell scripts with `bash -n` and `shellcheck` on push and pull request.

5. **Future extension layer**
   - Optional reverse proxy
   - Optional HTTPS
   - Optional Debian 13 variant

### Design Priorities
- Deterministic installation
- Simple first-run experience
- Secure defaults for LAN testing
- Clear separation of host logic and in-container logic
- Easy future extension without breaking the base path

---

## Project Structure

```text
.
├── .github/
│   └── workflows/
│       └── shell-validation.yml
├── .gitignore
├── AGENTS.md
├── CHANGELOG.md
├── README.md
├── ct/
│   └── archisteamfarm.sh
├── install/
│   └── archisteamfarm-install.sh
└── docs/
    └── README.md
```

### Responsibilities
- `.github/workflows/shell-validation.yml` → CI validation for shell syntax and linting
- `.gitignore` → protects against committing local artifacts and sensitive runtime data
- `CHANGELOG.md` → tracks notable repository changes
- `README.md` → user-facing overview and quick start
- `AGENTS.md` → contributor and AI-agent rules
- `ct/` → Proxmox host-side entry scripts
- `install/` → in-container install logic
- `docs/` → operational and troubleshooting notes

---

## Core Components

### 1. Proxmox CT Script
Responsible for host-side container creation defaults, repo-local installer execution, and install validation.

### 2. Install Script
Responsible for package installation, ASF deployment, configuration generation, and service registration.

### 3. ASF Runtime
Runs from `/opt/archisteamfarm` and is managed with `systemd`.

### 4. Configuration Files
- `config/ASF.json` → global ASF behavior
- `config/IPC.config` → web/IPC access behavior
- `config/<BotName>.json` → account-specific bot configuration

### 5. Runtime Metadata
- `/root/asf-lxc-info.txt` → connection details for first login and maintenance

### 6. CI Validation
- `.github/workflows/shell-validation.yml` → automatic checks for all tracked `.sh` files

---

## State Machine Flow

Conceptual flow:

1. User runs `ct/archisteamfarm.sh` on Proxmox host
2. Container is created with default resource values
3. The repository installer script is downloaded into the container
4. `install/archisteamfarm-install.sh` runs inside the container
5. Dependencies are installed
6. Matching ASF release asset is downloaded
7. Config files are created if absent
8. `archisteamfarm.service` is created and enabled
9. Service starts and is validated
10. User opens `http://<LXC-IP>:1242`
11. User creates or imports bot JSON files
12. Repository changes are validated in GitHub Actions

Expected rerun behavior:
- preserve existing config where practical
- do not overwrite user secrets without intent
- fail loudly on unsupported architecture or missing runtime requirements
- fail loudly when the service is not active after setup

---

## Authentication

Authentication in this repository currently centers on ASF IPC access.

### Current model
- Web access is enabled through `IPC.config`
- Authentication is protected using `IPCPassword`
- Access is intended for LAN use only in the initial setup

### Required handling
- Never commit real bot credentials
- Never commit generated passwords
- Never replace an existing user config unless explicitly required
- Document any authentication-related behavior changes in `README.md` and `docs/README.md`

---

## Key Files

### Repository files
- `README.md`
- `AGENTS.md`
- `.github/workflows/shell-validation.yml`
- `ct/archisteamfarm.sh`
- `install/archisteamfarm-install.sh`
- `docs/README.md`

### Container files
- `/opt/archisteamfarm/`
- `/opt/archisteamfarm/config/ASF.json`
- `/opt/archisteamfarm/config/IPC.config`
- `/opt/archisteamfarm/config/ExampleBot.json.example`
- `/etc/systemd/system/archisteamfarm.service`
- `/root/asf-lxc-info.txt`

---

## Development Commands

### Repository validation
```bash
bash -n ct/archisteamfarm.sh
bash -n install/archisteamfarm-install.sh
shellcheck ct/archisteamfarm.sh
shellcheck install/archisteamfarm-install.sh
```

### Local repository workflow
```bash
git status
git add .
git commit -m "Describe your change"
```

### Proxmox runtime checks
```bash
pct list
pct enter <CTID>
systemctl status archisteamfarm
journalctl -u archisteamfarm -n 100 --no-pager
```

---

## Testing Expectations

At minimum, verify:
- `bash -n ct/archisteamfarm.sh`
- `bash -n install/archisteamfarm-install.sh`
- `shellcheck ct/archisteamfarm.sh`
- `shellcheck install/archisteamfarm-install.sh`
- the GitHub Actions workflow completes successfully
- clean install path works on the intended Debian base
- service starts successfully
- `/root/asf-lxc-info.txt` is created
- Web UI loads on `http://<LXC-IP>:1242`
- login works with the generated IPC password
- a sample bot file can be added without breaking startup

When changing installation logic, also verify:
- rerun behavior does not destroy existing config unintentionally
- update flow preserves config and service state
- unsupported architectures fail clearly
- setup fails clearly when the installer or service validation fails

---

## Documentation Rules

Whenever behavior changes, update:
- `README.md`
- `docs/README.md`
- `AGENTS.md`
- any other agent instruction files added later

Keep examples consistent with:
- repository name `AsfAtProxmox`
- current file paths
- current quick-start instructions
- current CI workflow behavior

---

## Preferred Change Style

Preferred order of work:
1. keep the current simple test setup working
2. improve safety and maintainability
3. document the change
4. add validation or tests where practical
5. only then introduce optional complexity

Avoid introducing:
- premature multi-service assumptions
- hardcoded public exposure
- undocumented behavior changes
- large structural refactors without permission
