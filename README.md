# Homeatic / Homelab

Repository für Home Assistant, Proxmox VE, Pi-hole und die zugehörigen NodeZero-/Homelab-Werkzeuge.

## Aktueller Stand

**Aktueller Stand: V151 · Proxmox Master Installer · 24.11.2026**

Neu in V151:
- Dashboard-Branding ist vollständig generisch und für andere Installationen nutzbar.
- Eigene Logo-/Favicon-Dateien werden bei Dashboard-Updates **niemals überschrieben**.
- Neutrale transparente Platzhalter werden nur bei Erst-/Neuinstallation und nur bei fehlenden Dateien angelegt.
- Persönliche LT-WBH-Bilder sind nicht mehr Bestandteil des aktuellen Repository-Standes.
- Dashboard-Logo und Favicon heißen generisch `logo.png` und `favicon.png`.
- Die vollständige Versionshistorie wird separat gepflegt.

➡️ **[Aktuelle Proxmox-Dokumentation](proxmox/README.md)**  
➡️ **[Vollständige Versionshistorie](proxmox/HISTORY.md)**

## Bereiche

| Pfad | Inhalt |
|---|---|
| `proxmox/` | Master-Installer, Module, Tools, Dokumentation und History |
| `dashboard/` | Dashboard-Basisquellen, Styles, JavaScript und neutrale Branding-Platzhalter |
| `pihole/` | DNS-Einträge, Allow-/Blocklisten und Pi-hole-Daten |

## Proxmox Schnellinstallation

Auf dem Proxmox-Host als `root`:

```bash
curl -fsSL https://link.2mycloud.de/proxmox -o /root/proxmox.sh && chmod +x /root/proxmox.sh && /root/proxmox.sh
```

Direkte RAW-Quelle:

```text
https://raw.githubusercontent.com/Technox90/homeatic/refs/heads/main/proxmox/proxmox.sh
```

Der Installer besitzt seit V147 ein Self-Update und prüft beim Start den aktuellen Stand aus GitHub `main`.

## Wichtige Installer-Funktionen

Der Installer kann unter anderem verwalten:

- Home Assistant OS
- Paperless-ngx + PostgreSQL + Redis + Ollama
- Pi-hole + Unbound + Pi-hole Exporter
- NetAlertX
- Uptime Kuma
- Vaultwarden
- Stirling PDF
- Speedtest Tracker
- Scrutiny
- PVE-UPS
- Prometheus / PVE Exporter / Grafana
- EMQX
- weitere optionale Dienste
- lokale NodeZero-CA und TLS
- externe URLs per nginx + Let's Encrypt
- Dashboard mit Menü, Kategorien, USV, Pi-hole, Layouts und mehreren Ansichten
- automatische Updates, Diagnose und Healthchecks

## Dashboard V151

Das Dashboard liegt lokal unter:

```text
/opt/nodezero/dashboard/
```

Eigene Branding-Dateien:

```text
/opt/nodezero/dashboard/static/assets/logo.png
/opt/nodezero/dashboard/static/assets/favicon.png
```

**Update-Regel:** Ein normales Dashboard-Update verändert diese beiden Dateien niemals.

Bei Erst-/Neuinstallation werden nur dann neutrale, vollständig transparente PNG-Platzhalter aus dem Repository angelegt, wenn die jeweilige Datei noch fehlt.

Repository-Platzhalter:

```text
dashboard/assets/logo.png
dashboard/assets/favicon.png
```

Das Dashboard verwendet bei leerem/transparentem `logo.png` automatisch den konfigurierten Text-Fallback.

Dashboard aktualisieren:

```text
Hauptmenü → 1 Basis-Systeme → 1 Server-Dashboard installieren / aktualisieren
```

## Dateilayout

```text
/root/passwort/          aktive Secrets
/home/passwort/          lokale Secret-Sicherung
/home/downloads/         Downloads / wiederverwendbare Artefakte
/home/backups/           Backups
/home/diagnose/          Diagnoseberichte und Logs
/home/img/               Images / Container-/Template-Caches
/opt/nodezero/           installierter NodeZero-Code
```

## Passwortmanager

- [Vaultwarden / Bitwarden – Android, iOS und PC](proxmox/passwortmanager/README.md)
- [Optionales verschlüsseltes Vaultwarden-Offsite-Backup](proxmox/VAULTWARDEN-BACKUP.md)

## Pi-hole

Standardmäßig werden unter anderem folgende Listen eingebunden:

**Block**
- HaGeZi Pro
- HaGeZi TIF

**Allow**
- Homeatic-Allowlist aus diesem Repository
- HaGeZi Referral Native

Lokale DNS-/CNAME-Dateien liegen unter `pihole/`.

## Dokumentationsregel

Bei jeder neuen Installer-Version werden künftig gemeinsam aktualisiert:

1. `proxmox/proxmox.sh`
2. `proxmox/README.md`
3. `proxmox/HISTORY.md`
4. `proxmox/history.txt` als Text-Kompatibilitätsversion
5. `proxmox/CHATGPT-HANDOFF.md`
6. CI-Prüfungen unter `.github/workflows/`

> Reset-/Neuaufbau-Funktionen können VMs/LXC oder Dashboard-Daten entfernen. Vor destruktiven Aktionen Backups prüfen.
