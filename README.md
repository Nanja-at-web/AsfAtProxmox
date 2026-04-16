# AsfAtProxmox

ArchiSteamFarm (ASF) als **Proxmox VE LXC** mit **Web UI** für den schnellen Start im Heimnetz.

Dieses Repository ist als schlanke Projektbasis für einen **einzelnen Test-LXC** gedacht und orientiert sich am Aufbau der **Proxmox VE Helper-Scripts / Community-Scripts**.

## Ziel

`AsfAtProxmox` soll eine einfache, nachvollziehbare und gut wartbare Möglichkeit bieten, **ASF in einem Proxmox-LXC** zu betreiben.

Für die erste Ausbaustufe liegt der Fokus auf:
- **einem einzelnen LXC**
- **direktem Zugriff im LAN** über ASFs Weboberfläche
- **keinem Reverse Proxy**
- **keinem HTTPS**
- **einfacher Wartung und späterer Erweiterbarkeit**

## Enthalten

- **ASF** als eigentliche Laufzeit
- die integrierte **ASF-Weboberfläche** über IPC
- automatisierte Erzeugung einer sicheren `IPCPassword`
- ein `systemd`-Dienst für automatischen Start
- eine Community-Scripts-nahe Trennung zwischen Host- und In-Container-Logik
- eine `.gitignore` für Repo-Hygiene und Secrets-Schutz
- ein `CHANGELOG.md` für nachvollziehbare Änderungen
- ein GitHub-Actions-Workflow für `bash -n` und `shellcheck`

## Repository-Struktur

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

## Komponenten

### `ct/archisteamfarm.sh`
Läuft auf dem **Proxmox-Host**.

Aufgaben:
- Container-Defaults definieren
- die Container-Erstellung über das Community-Scripts-Modell anstoßen
- ein Update-Skript für bestehende Installationen bereitstellen

### `install/archisteamfarm-install.sh`
Läuft **im Container**.

Aufgaben:
- Abhängigkeiten installieren
- passende ASF-Release-Datei laden
- ASF nach `/opt/archisteamfarm` entpacken
- `ASF.json` und `IPC.config` anlegen
- `archisteamfarm.service` erzeugen
- Verbindungsdaten in `/root/asf-lxc-info.txt` speichern

### `.github/workflows/shell-validation.yml`
Automatische Repository-Validierung bei Push und Pull Request.

Aufgaben:
- Shell-Skripte im Repo sammeln
- `bash -n` für Syntax-Checks ausführen
- `shellcheck` für statische Shell-Prüfung ausführen

### `docs/README.md`
Zusätzliche Laufzeit- und Wartungshinweise.

### `AGENTS.md`
Arbeitsregeln für AI-Agents und Mitwirkende im Repository.

## Standardverhalten

Die aktuelle Startvariante ist bewusst einfach:
- Zugriff im Browser über `http://<LXC-IP>:1242`
- Webzugriff über ASFs IPC/Weboberfläche
- Schutz per generiertem `IPCPassword`
- kein externer Internetzugriff vorgesehen

## Schnellstart in Proxmox

### 1. Repository klonen

```bash
git clone https://github.com/Nanja-at-web/AsfAtProxmox.git
cd AsfAtProxmox
```

### 2. CT-Skript auf dem Proxmox-Host ausführen

```bash
bash ./ct/archisteamfarm.sh
```

### 3. Nach der Erstellung im Browser öffnen

```text
http://<LXC-IP>:1242
```

### 4. Zugangsdaten im Container nachsehen

```bash
pct list
pct enter <CTID>
cat /root/asf-lxc-info.txt
```

## Ersten Bot anlegen

Im Container liegt eine Vorlage:

```text
/opt/archisteamfarm/config/ExampleBot.json.example
```

Kopieren und anpassen:

```bash
cp /opt/archisteamfarm/config/ExampleBot.json.example /opt/archisteamfarm/config/main.json
nano /opt/archisteamfarm/config/main.json
systemctl restart archisteamfarm
```

## Entwicklung mit deinem GitHub-Repo

### Direkt aus deinem Repo testen

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Nanja-at-web/AsfAtProxmox/main/ct/archisteamfarm.sh)"
```

### Einzelne Datei lokal prüfen

```bash
bash -n ct/archisteamfarm.sh
bash -n install/archisteamfarm-install.sh
shellcheck ct/archisteamfarm.sh
shellcheck install/archisteamfarm-install.sh
```

## CI / GitHub Actions

Das Repository enthält jetzt einen Workflow unter:

```text
.github/workflows/shell-validation.yml
```

Dieser Workflow läuft bei Push und Pull Request auf `main` und prüft alle `.sh`-Dateien mit:
- `bash -n`
- `shellcheck`

Damit bekommst du früh Rückmeldung, wenn ein Shell-Skript syntaktisch kaputt ist oder typische Shell-Probleme enthält.

## Geplante Ausbaustufen

Später lässt sich dieses Repository ohne Strukturbruch erweitern um:
- **Nginx Proxy Manager**
- **HTTPS / Reverse Proxy**
- **Debian 13 als alternative LXC-Basis**
- zusätzliche Dokumentation für Updates, Backups und Hardening

## Sicherheitshinweise

Für die A-Variante gilt:
- Port `1242` nur im **internen Netz** nutzen
- **nicht direkt ins Internet** freigeben
- Zugriffe möglichst per **LAN oder VPN**
- Passwörter und Bot-Konfigurationen nicht ins Repo committen

## Nützliche Befehle im Container

```bash
systemctl status archisteamfarm
systemctl restart archisteamfarm
journalctl -u archisteamfarm -n 100 --no-pager
```

## Status des Repositories

Dieses Repository ist als **Startbasis** gedacht. Die aktuelle Struktur ist jetzt so vorbereitet, dass du Shell-Änderungen nicht nur lokal, sondern auch automatisch über GitHub Actions validieren kannst.
