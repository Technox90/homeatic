# Proxmox Master Installer

Modularer Komplett-Installer für Proxmox VE.

## Aktueller Stand

**Installationskandidat: V166 · 25.11.2026**

## V164 · Einmalige Migration bestehender Installationen

Diese Version benennt aktive Installer-Pfade, Hilfswerkzeuge und den Dashboard-Ordner um. **Bestehende Installationen nicht durch eine Neuinstallation ersetzen.** Der bisherige Auto-Updater kennt die neuen Dateinamen noch nicht. Einmalig auf dem Proxmox-Host als root ausführen:

```bash
REF=$(curl -fsSL https://api.github.com/repos/Technox90/homeatic/commits/main | python3 -c 'import json,sys;print(json.load(sys.stdin)["sha"])')
curl -fsSL "https://raw.githubusercontent.com/Technox90/homeatic/$REF/proxmox/tools/proxmox-migrate-layout" -o /root/proxmox-migrate-layout
python3 /root/proxmox-migrate-layout --ref "$REF"
# Erst nach erfolgreicher Vorprüfung:
python3 /root/proxmox-migrate-layout --ref "$REF" --apply
```

Die Vorprüfung verändert keine Installation. Die Migration übernimmt vorhandene Dateien und erzeugt eine root-geschützte Sicherung unter `/home/backups/proxmox-layout-*`. Bei Fehlern werden die Änderungen zurückgenommen. Bestehende Zertifikatsidentitäten und historische Sicherungen werden nicht umgeschrieben; eine neue CA wird nicht erzeugt. Zertifikate und CA-Vertrauenseinstellungen bleiben gültig. Ein bestehender Zertifikatsname bleibt bis zu einer bewusst geplanten Zertifikatsmigration bestehen. Alte Git-Commits bleiben unverändert. Anschließend funktionieren die neuen Auto-Updater-Pfade.

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
1 → 2
```

Dashboard-Ansicht wechseln:

```text
1 → 3
```

## Dashboard

### Update-Modus V152

Der Installer prüft vor dem Update, ob der vollständige aktuelle Dashboard-Stand vorhanden ist. Ist er vollständig, läuft ein schnelles In-place-Update ohne Rücksetzen auf V139 und ohne erneutes Durchlaufen der historischen UI-Migrationen. Fehlen Pflichtmarker oder wurde Reset/Neuaufbau gewählt, wird einmalig der Kompatibilitäts-Bootstrap ausgeführt.


Installationspfad:

```text
/opt/dashboard/
```

### Eigene Logo-/Favicon-Dateien

Auf dem Proxmox-Host:

```text
/opt/dashboard/static/assets/logo.png
/opt/dashboard/static/assets/favicon.png
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
Fallback-Logo:  DASHBOARD
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
/usr/local/sbin/proxmox-dashboard-views
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
/opt/dashboard/         installierter Dashboard-Code
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

1. `README.md` und `proxmox/proxmox.sh`
2. `proxmox/README.md`
3. `proxmox/HISTORY.md`
4. `proxmox/history.txt`
5. `proxmox/CHATGPT-HANDOFF.md`
6. passende GitHub-CI-Tests

In beiden README-Dateien steht der Versionsverlauf am Ende, mit den fünf neuesten Versionen (neueste zuerst). Die vollständige Historie bleibt in HISTORY.md und history.txt erhalten.

> **Achtung:** Optimal-, Reset- und Neuaufbau-Funktionen können bestehende VMs/LXC oder Dashboard-Daten löschen. Vor destruktiven Aktionen Backups prüfen.

## Versionsverlauf – letzte 5 Versionen

### V166

- Ausschließlich lokale Host-Leistungsdaten: IPMI/DCMI hat Vorrang; andernfalls CPU-Package (oder vorhandener CPU-Teilbereich) plus separater Intel-RAPL-DRAM-Wert. Cores/Uncore nicht doppelt zählen. GPU separat ausweisen, wenn ihre Unabhängigkeit vom CPU-Messbereich nicht nachgewiesen ist; ohne CPU/DRAM kann GPU als Teilleistung angezeigt werden.
- Teilleistung wird in Kachel und Browser-Tab ausdrücklich gekennzeichnet. Fehlende Werte werden nicht geschätzt. Keine Smart-Home-, MQTT- oder externen Strommesser; USV/Pi-hole bleiben getrennt.

### V165

- Ladeanimation: führendes Wort „Dashboard“ wird ausschließlich im Ladebildschirm entfernt (z. B. `Dashboard LT-WBH` → `LT-WBH`). Gespeicherter Name, Seitentitel, Tab-Titel und Branding bleiben unverändert.

### V164

- Dashboard unter `/opt/dashboard/`; persönliche Dateien bleiben unter `static/assets/` erhalten.
- Neutrale Proxmox-Werkzeuge und lokale CA-Dateinamen; UPPER bleibt unabhängig unter `/var/www/upper/`.
- Boot-Animation übernimmt exakt den gespeicherten Dashboard-Namen, ohne zusätzliches Präfix.
- Bestehende Installationen erfordern eine einmalige, gesicherte Layout-Migration. Bestehende CA-Schlüssel, Zertifikate, Datenbanken und Gastdaten bleiben erhalten.

### V163

- UPPER: eigenständige Statusseite unter `/upper/`, Dateien in `/var/www/upper/`, Logo/Favicon bleiben bei Updates erhalten; Copyright und GitHub-Link, interaktive Ping-Diagramme mit Maus, Touch und Tastatur.
- Originale Kuma-Statusseiten bleiben unverändert. Opt-in-Updates migrieren alte Installationen; Nginx-Prüfung mit Rücksicherung.
- Dashboard: SVG-Symbole für Neustart und Herunterfahren. Uptime Kuma: Datenbank-Besitzrechte nicht rekursiv zurücksetzen, Health- und HTTP-Prüfung nach Updates.

### V162

- Freigabestand mit allen V161-Funktionen: individuell konfigurierbare aktive/inaktive Browser-Tab-Titel und priorisierte Update-Hinweise.
- Logo wird bei unveränderten Einstellungen während der laufenden USV-Statusabfragen nicht erneut geladen; bewusste Branding-Aktualisierung bleibt möglich.
- V162 enthält die bisherigen Änderungen kumulativ; der bestehende automatische Update-Zeitplan und die Opt-in-Einstellungen bleiben unverändert.

### V161

- Browser-Tab-Anzeige in den Dashboard-Einstellungen getrennt für aktive und inaktive Tabs konfigurierbar.
- Standard: aktiv nur Name; inaktiv Name → CPU/RAM → Leistungsaufnahme. Wechsel alle 5 Sekunden, Update-Hinweise alle 3 Sekunden.
- Update-Hinweise haben optional Vorrang; Messwerte und Versionsstatus werden aus bestehenden Abfragen übernommen. Speicherung lokal pro Browser, ohne Änderungen an Logos oder Favicons.

### V160

- Zusammenführung der parallelen V159-Änderungen: `randMenuLogo`, mittiger Titel, Logo bis 350 × 60 px sowie zugängliche mobile Power-Icons.
- Branding-Script erhält eine stabile ID; alte Update-Marker bleiben kompatibel.
- Beide verpflichtenden CI-Prüfungen laufen bei jedem Pull Request auf main, auch bei reinen Dokumentationsänderungen.
- Lokale Logo- und Favicon-Dateien bleiben unverändert.

### V159

- Aktive Branding-IDs und CSS-Klassen ohne Versionssuffix; das Logo verwendet `randMenuLogo`.
- Konfigurierter Dashboard-Titel wird auf Desktop und Mobilgeräten mittig angezeigt.
- Manueller und automatischer Updatepfad verwenden dieselben Branding-Quellen; lokale Logos/Favicons bleiben unverändert.

### V158

- Proxmox-Systeminformationen wandern vom Dashboard-Kopf in eine dezente Fußzeile.
- Die lokale Installer-Version ersetzt dort den Hostnamen; die Versionsangabe wird aus dem vorhandenen Update-Status gelesen.
- Copyright © Technox1990 mit GitHub-Link; bestehende Logos, Themes und Einstellungen bleiben unverändert.

**[Vollständige Versionshistorie](HISTORY.md)**
