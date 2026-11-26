# Homeatic / Homelab

Repository für Home Assistant, Proxmox VE, Pi-hole und die zugehörigen Homelab-Werkzeuge.

## Aktueller Stand

**Aktueller Stand: V180 · Proxmox Master Installer · 26.11.2026**

➡️ **[Aktuelle Proxmox-Dokumentation](proxmox/README.md)**  
➡️ **[Vollständige Versionshistorie](proxmox/HISTORY.md)**

Bestehende Installationen: [einmalige Layout-Migration V164](proxmox/README.md#v164--einmalige-migration-bestehender-installationen).

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
- lokale Proxmox-CA und TLS
- externe URLs per nginx + Let's Encrypt
- Dashboard mit Menü, Kategorien, USV, Pi-hole, Layouts und mehreren Ansichten
- automatische Updates, Diagnose und Healthchecks

## Dashboard

Das Dashboard liegt lokal unter:

```text
/opt/dashboard/
```

Eigene Branding-Dateien:

```text
/opt/dashboard/static/assets/logo.png
/opt/dashboard/static/assets/favicon.png
```

**Update-Regel:** Ein normales Dashboard-Update verändert diese beiden Dateien niemals. Seit V152 bleiben außerdem die bereits aktuellen Dashboard-Programmdateien erhalten; der Installer setzt sie nicht mehr auf die V139-Basis zurück.

Bei Erst-/Neuinstallation werden nur dann neutrale, vollständig transparente PNG-Platzhalter aus dem Repository angelegt, wenn die jeweilige Datei noch fehlt.

Repository-Platzhalter:

```text
dashboard/assets/logo.png
dashboard/assets/favicon.png
```

Das Dashboard verwendet bei leerem/transparentem `logo.png` automatisch den konfigurierten Text-Fallback.

Dashboard aktualisieren:

```text
Hauptmenü → 1 Basis-Systeme → 2 Server-Dashboard installieren / aktualisieren
```

## Dateilayout

```text
/root/passwort/          aktive Secrets
/home/passwort/          lokale Secret-Sicherung
/home/downloads/         Downloads / wiederverwendbare Artefakte
/home/backups/           Backups
/home/diagnose/          Diagnoseberichte und Logs
/home/img/               Images / Container-/Template-Caches
/opt/dashboard/         installierter Dashboard-Code
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

1. `README.md` und `proxmox/proxmox.sh`
2. `proxmox/README.md`
3. `proxmox/HISTORY.md`
4. `proxmox/history.txt` als Text-Kompatibilitätsversion
5. `proxmox/CHATGPT-HANDOFF.md`
6. CI-Prüfungen unter `.github/workflows/`

> Reset-/Neuaufbau-Funktionen können VMs/LXC oder Dashboard-Daten entfernen. Vor destruktiven Aktionen Backups prüfen.

## Versionsverlauf – letzte 5 Versionen

### V180 · Automatische SSD-Speichereinheiten

- Speicherwerte unter 950 MB in MB, ab 950 MB in GB; gilt für Gesamtkapazität, belegt, verfügbar und reserviert.

### V179 · CPU/RAM-Icon und Update-Timer

- Doppeltes CPU-Icon entfernt, CPU/RAM-Symbole ausgerichtet; Updateprüfung alle fünf Minuten.

### V178 · Speicherwartung und Auto-Release

- Konservative Docker-/APT-/Journal-Bereinigung, TRIM, Speicherwarnungen, HA-Updateabfrage und stabile Releases; fehlende Docker-Logrotation wird gemeldet.

### V177 · CPU/RAM und physische SSD

- CPU/RAM nebeneinander, Temperaturen kompakt, physische SSD mit Kapazität, Belegung und getrennten Root-/Thin-Pool-Balken.

### V176 · Schutz und Speicher

- Fail2Ban-Schutzkachel, SSD-Temperatur, zentrale Host-Zeitzone für Dashboard und UPPER.

**[Vollständige Versionshistorie](proxmox/HISTORY.md)**
