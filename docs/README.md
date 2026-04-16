# Betrieb und Wartung

Diese Datei ergänzt die Root-`README.md` um praktische Hinweise für den Betrieb von **ArchiSteamFarm in einem Proxmox-LXC**.

## Ziel der ersten Version

Die aktuelle Startvariante ist bewusst einfach:
- ein einzelner LXC
- Zugriff im LAN
- keine Domain
- kein Reverse Proxy
- kein HTTPS

Damit eignet sich das Projekt gut zum **Testen und für den ersten produktiven Einstieg im Heimnetz**.

## Zugriff auf die Weboberfläche

Standardmäßig ist ASF nach der Installation über folgenden Port erreichbar:

```text
http://<LXC-IP>:1242
```

Die Zugangsdaten werden im Container in folgender Datei abgelegt:

```text
/root/asf-lxc-info.txt
```

## Wichtige Pfade im Container

```text
/opt/archisteamfarm/
/opt/archisteamfarm/config/
/etc/systemd/system/archisteamfarm.service
/root/asf-lxc-info.txt
```

## Häufige Verwaltungsbefehle

### Dienststatus prüfen

```bash
systemctl status archisteamfarm
```

### Dienst neu starten

```bash
systemctl restart archisteamfarm
```

### Logausgabe ansehen

```bash
journalctl -u archisteamfarm -n 100 --no-pager
```

## Ersten Bot anlegen

Die Installation legt eine Beispielvorlage an:

```text
/opt/archisteamfarm/config/ExampleBot.json.example
```

Beispiel:

```bash
cp /opt/archisteamfarm/config/ExampleBot.json.example /opt/archisteamfarm/config/main.json
nano /opt/archisteamfarm/config/main.json
systemctl restart archisteamfarm
```

## Sicherheit

Für diese erste Projektphase gilt:
- Port `1242` nur intern nutzen
- keine direkte Freigabe ins Internet
- Passwörter, Secrets und Bot-JSON-Dateien nicht committen
- Zugriff bevorzugt nur über LAN oder VPN

## Updates

Die Host-Seite ist so angelegt, dass spätere Updates strukturiert ergänzt werden können. Bei Änderungen an Installationslogik oder Standardwerten sollten immer auch diese Dateien aktualisiert werden:
- `README.md`
- `docs/README.md`
- `AGENTS.md`

## Fehlersuche

### Web UI nicht erreichbar

Prüfen:
- läuft der Dienst?
- hat sich die Container-IP geändert?
- ist Port `1242` im LAN erreichbar?
- blockiert die Proxmox-Firewall den Zugriff?
- wurde `IPC.config` korrekt geschrieben?

### Bot meldet sich nicht an

Häufige Ursachen:
- falscher Login oder falsches Passwort im Bot-JSON
- Steam Guard / 2FA noch nicht abgeschlossen
- `Enabled` ist auf `false`
- JSON-Datei ist syntaktisch ungültig

### Nach Änderungen keine Wirkung

```bash
systemctl restart archisteamfarm
journalctl -u archisteamfarm -n 100 --no-pager
```

## Backup-Hinweis

Für ein einfaches Backup sind besonders wichtig:
- `/opt/archisteamfarm/config/`
- `/root/asf-lxc-info.txt`

Bot-Dateien und sensible Daten sollten nicht in öffentliche Repositories gelangen.
