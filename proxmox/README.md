# Proxmox Master Installer

Modularer Komplett-Installer für Proxmox VE.

## Aktueller Stand

**Installationskandidat: V153 · 24.11.2026**

### Neu in V153

- Toolbar-Layout neu strukturiert.
- Links: kombinierter Menübutton aus Hamburger + `logo.png` bzw. Text-Fallback.
- Mitte: `LIVE` und `USV Online`.
- Rechts: `Neustart` und `Herunterfahren`.
- Der Logo-/Hamburger-Button öffnet und schließt das Seitenmenü.
- Der alte separate „Menü“-Button und der sichtbare Seitenmenü-Kopf entfallen.
- Das Logo bleibt in der festen Toolbar immer sichtbar.
- Bestehende `logo.png` / `favicon.png` bleiben weiterhin updategeschützt.

### Neu in V152

- Aktuelle Dashboard-Installationen werden **in-place** aktualisiert.
- `app.py`, `index.html` und `collector.py` werden bei einem aktuellen Dashboard nicht mehr durch die alte V139-Basis ersetzt.
- Historische Migrationsschritte V42–V81 werden bei einem bereits vollständigen aktuellen Dashboard übersprungen.
- Alte/unvollständige Installationen werden automatisch erkannt und erhalten einmalig den Kompatibilitäts-Bootstrap.
- Reset/Neuaufbau nutzt weiterhin den vollständigen Bootstrap.
- Logo/Favicon bleiben unverändert geschützt.

### Neu in V151

- Dashboard-Branding vollständig generisch.
- Persönliche LT-WBH-Logo-/Favicon-Dateien aus dem aktuellen Repository entfernt.
- Neue neutrale Bildnamen:
  - `dashboard/assets/logo.png`
  - `dashboard/assets/favicon.png`
- Beide Repository-Bilder sind vollständig transparente PNG-Platzhalter.
- Bei einem **normalen Dashboard-Update werden Logo und Favicon niemals verändert**.
- Erst-/Neuinstallationen legen die Platzhalter nur an, wenn die jeweilige Datei fehlt.
- Bestehende ältere Branding-Dateien werden bei Bedarf nur byte-identisch auf die generischen Namen übernommen.
- Dashboard-Name und Branding-Metadaten bleiben bei normalen Updates erhalten.
- Die vollständige History steht separat in **[HISTORY.md](HISTORY.md)**.

## Installation

Auf dem Proxmox-Host als `root`:

```bash
curl -fsSL https://link.2mycloud.de/proxmox -o /root/proxmox.sh && chmod +x /root/proxmox.sh && /root/proxmox.sh
```

Direkte RAW-Quelle:

```text
https://raw.githubusercontent.com/Technox90/homeatic/refs/heads/main/proxmox/proxmox.sh
```

Alternativ:

```bash
chmod +x proxmox.sh
./proxmox.sh
```

Seit V147 prüft der Installer beim Start automatisch GitHub `main`, validiert eine neue Version mit `bash -n`, sichert die lokale Datei und startet anschließend mit der aktualisierten Version neu.

## Hauptmenü

```text
O  Optimale Installation
1  Basis-Systeme
2  Apps & Dienste
3  Monitoring & Infrastruktur
4  Automation & Security
5  VMs / Betriebssysteme
6  Wartung & Einstellungen
7  Reset / Neuaufbau
I  Info / Diagnose
```

Nur Dashboard installieren/aktualisieren:

```text
1 → 1
```

Dashboard-Ansicht wechseln:

```text
1 → DV
```

## Dashboard

### Update-Modus V152

Der Installer prüft vor dem Update, ob der vollständige aktuelle Dashboard-Stand vorhanden ist. Ist er vollständig, läuft ein schnelles In-place-Update ohne Rücksetzen auf V139 und ohne erneutes Durchlaufen der historischen UI-Migrationen. Fehlen Pflichtmarker oder wurde Reset/Neuaufbau gewählt, wird einmalig der Kompatibilitäts-Bootstrap ausgeführt.


Installationspfad:

```text
/opt/nodezero/dashboard/
```

### Eigene Logo-/Favicon-Dateien

Auf dem Proxmox-Host:

```text
/opt/nodezero/dashboard/static/assets/logo.png
/opt/nodezero/dashboard/static/assets/favicon.png
```

Repository-Platzhalter:

```text
dashboard/assets/logo.png
dashboard/assets/favicon.png
```

### Update-Regel

Ein normales Dashboard-Update:

- lädt **keine** Logo-/Favicon-Datei aus GitHub,
- überschreibt **keine** vorhandene Bilddatei,
- löscht **keine** vorhandene Bilddatei,
- setzt ein vorhandenes Custom-Favicon nicht zurück,
- übernimmt vorhandenen Dashboard-Namen und Branding-Einstellungen.

CSS/JavaScript des Brandings dürfen dagegen aktualisiert werden.

### Erst-/Neuinstallation

Nur bei Erstinstallation oder bewusstem Dashboard-Neuaufbau:

1. Zielordner wird angelegt.
2. Existiert `logo.png` nicht, wird der neutrale transparente Platzhalter geladen.
3. Existiert `favicon.png` nicht, wird der neutrale transparente Platzhalter geladen.
4. Bereits vorhandene Bilder bleiben unangetastet.

Standardwerte für eine generische Installation:

```text
Dashboard-Name: PVE Hardware Monitor
Fallback-Logo:  NODEZERO
Fallback-Stil:  neon
```

Bei einer normalen interaktiven Erst-/Neuinstallation werden Dashboard-Name, Fallback-Logo-Text und Fallback-Design abgefragt.

Ist `logo.png` vollständig transparent oder nicht erreichbar, zeigt das Seitenmenü automatisch den Text-Fallback.

### Toolbar

Die obere Bedienleiste bleibt beim Scrollen sichtbar:

```text
Menü · LIVE · USV Online · Neustart · Herunterfahren
```

### Dashboard-Ansichten

- Boot Sequence
- Live Pulse
- Telemetry Flow
- Glass Motion
- Status Control

Werkzeug:

```text
/usr/local/sbin/nodezero-dashboard-views
```

## Enthaltene Dienste

Je nach Auswahl unterstützt der Installer unter anderem:

- Home Assistant OS
- Paperless-ngx
- PostgreSQL / Redis / Ollama für Paperless
- Pi-hole + Unbound
- Pi-hole Exporter
- NetAlertX
- Uptime Kuma
- Vaultwarden
- Caddy
- Stirling PDF
- ntfy
- Forgejo
- Syncthing
- Speedtest Tracker
- Scrutiny
- Mealie
- Proxmox Backup Server
- Pulse
- PVE-UPS
- Semaphore
- Pocket ID
- Prometheus
- Prometheus PVE Exporter
- Grafana
- CrowdSec
- Pangolin / Newt
- Gatus
- Homepage
- Nginx Proxy Manager
- EMQX

## Externe URLs

Unter **Wartung & Einstellungen → Externe URLs** können Webdienste über nginx und Let's Encrypt veröffentlicht werden.

Beispiel:

```text
dash.example.de
ha.example.de
paper.example.de
pdf.example.de
vault.example.de
up.example.de
```

Persistente Konfiguration:

```text
/home/Data/proxmox-installer/external-urls/config.json
/home/Data/proxmox-installer/external-urls/dns-records.txt
```

Logs / Backups:

```text
/home/diagnose/external-urls/
/home/backups/external-urls/
```

Proxmox VE selbst bleibt standardmäßig auf Port `8006`.

## Dateilayout

```text
/root/passwort/          aktive Passwörter, Tokens und Secrets
/home/passwort/          lokale Secret-Sicherung
/home/downloads/         Downloads und wiederverwendbare Artefakte
/home/backups/           Konfigurations-/Reparatur-Backups
/home/diagnose/          Diagnoseberichte und Logs
/home/img/               Images, Docker-/Template-/Ollama-Caches
/opt/nodezero/           installierter NodeZero-Code
```

## Dashboard-Modul

Die Dashboard-Installations- und Migrationslogik liegt in:

```text
proxmox/modules/dashboard.sh
```

Der Master-Installer lädt das Modul über einen unveränderlichen Git-Commit und prüft es mit `bash -n`.

Basisquellen:

```text
dashboard/collector.py
dashboard/app.py
dashboard/index.html
dashboard/branding-v151.css
dashboard/branding-v151.js
dashboard/assets/logo.png
dashboard/assets/favicon.png
```

## Pi-hole

Standard-Blocklisten:

- HaGeZi Pro
- HaGeZi TIF

Standard-Allowlisten:

- Homeatic-Allowlist aus diesem Repository
- HaGeZi Referral Native

Lokale DNS-/CNAME-Daten liegen im Repository unter `pihole/`.

## Secrets

Aktive Secrets:

```text
/root/passwort/
```

Lokale Sicherung:

```text
/home/passwort/
```

Keine Passwörter, Tokens oder privaten Schlüssel ins öffentliche Repository committen.

## Backups und Diagnose

```text
/home/backups/
/home/diagnose/
```

Vor produktiven Änderungen erzeugt der Installer an vielen Stellen zusätzliche komponentenspezifische Backups.

## Versionshistorie

Die ausführliche, chronologische Historie wird getrennt von dieser aktuellen Bedien-/Installationsdokumentation gepflegt:

➡️ **[HISTORY.md – vollständige nachvollziehbare Versionshistorie](HISTORY.md)**

Zusätzlich bleibt `history.txt` als Text-Kompatibilitätsversion bestehen.

Die belastbare GitHub-Historie reicht aktuell bis V113 zurück. Für frühere Versionsnummern existiert im heutigen Repository keine vollständige belastbare Dokumentation; fehlende Einträge werden deshalb nicht erfunden.

## Dokumentationsregel für zukünftige Releases

Bei jeder neuen Installer-Version müssen gemeinsam aktualisiert werden:

1. `proxmox/proxmox.sh`
2. `proxmox/README.md`
3. `proxmox/HISTORY.md`
4. `proxmox/history.txt`
5. `proxmox/CHATGPT-HANDOFF.md`
6. passende GitHub-CI-Tests

Der **neueste Versionsstand steht immer oben**.

> **Achtung:** Optimal-, Reset- und Neuaufbau-Funktionen können bestehende VMs/LXC oder Dashboard-Daten löschen. Vor destruktiven Aktionen Backups prüfen.
