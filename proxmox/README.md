# Proxmox Master Installer

Modularer Komplett-Installer für Proxmox VE.

## Aktueller Stand

**Installationskandidat: V159 · 24.11.2026**

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

1. `README.md` und `proxmox/proxmox.sh`
2. `proxmox/README.md`
3. `proxmox/HISTORY.md`
4. `proxmox/history.txt`
5. `proxmox/CHATGPT-HANDOFF.md`
6. passende GitHub-CI-Tests

In beiden README-Dateien steht der Versionsverlauf am Ende, mit den fünf neuesten Versionen (neueste zuerst). Die vollständige Historie bleibt in HISTORY.md und history.txt erhalten.

> **Achtung:** Optimal-, Reset- und Neuaufbau-Funktionen können bestehende VMs/LXC oder Dashboard-Daten löschen. Vor destruktiven Aktionen Backups prüfen.

## Versionsverlauf – letzte 5 Versionen

### V159

- Dauerhafte Namen für Branding-CSS-Klassen, HTML-IDs und JavaScript-Funktionen statt Versionssuffixen.
- Desktop-Logo bis 350 × 60 px, responsive Skalierung auf kleineren Bildschirmen.
- Mobile Neustart- und Herunterfahren-Schaltflächen mit Icons und barrierefreien Beschriftungen; Sicherheitsabfragen bleiben erhalten.
- Installer und Auto-Updater migrieren das Branding; alte interne Kompatibilitätsmarker bleiben erhalten.

### V158

- Proxmox-Systeminformationen wandern vom Dashboard-Kopf in eine dezente Fußzeile.
- Die lokale Installer-Version ersetzt dort den Hostnamen; die Versionsangabe wird aus dem vorhandenen Update-Status gelesen.
- Copyright © Technox1990 mit GitHub-Link; bestehende Logos, Themes und Einstellungen bleiben unverändert.

### V157

- Dashboard-Branding erhält einen eigenen Inline-Script-Block statt Einfügen in das letzte Script-Element.
- Doppelte Einbindung der Installer-Updateanzeige wird entfernt; bestehende Logos, Favicons und Einstellungen bleiben erhalten.
- Sichtbare Theme-Namen entfallen in allen fünf Ansichten; Animationen und Auswahl bleiben erhalten.
- Auto-Updater repariert auch bestehende falsch platzierte Branding-Blöcke; Theme-Cache wird erneuert.
- Regressionstest für externe Script-Tags und wiederholbare Dashboard-Aktualisierung.

### V156

- Auto-Updater: drei unabhängige, standardmäßig ausgeschaltete Optionen für Master-Installer/Updater-Werkzeuge, verwaltete Dashboard-Oberfläche und vorhandene Kuma-Statusseite.
- Abruf aus veröffentlichtem `main`-Commit; Installer-Syntaxprüfung, keine Downgrades, Backups und atomarer Dateiaustausch.
- Keine Neuinstallation, kein Reset, keine Änderung an nginx, Zertifikaten, Logos/Favicons oder Datenbanken. Dashboard-Backend-Migrationen bleiben manuell.
- Update-Ergebnisse erscheinen im vorhandenen Auto-Updater-Bericht und in Pushover, sofern aktiviert.
- Menü: Wartung → Auto-Updater → 5; dort die gewünschten Komponenten einschalten.

### V155

- Einheitliche Nummerierung der sieben Haupt-Untermenüs; interne IDs bleiben stabil.
- Dashboard-Updates starten keine automatische Paperless-Migration mehr; vorhandene Paperless-, Kuma- und PVE-UPS-Container werden bei erneuter Installation übersprungen.
- Neue Kuma-Installationen verwenden das LXC-Hostnetz mit Bindung an 127.0.0.1:3001; IPv6 setzt funktionierendes LXC-IPv6 voraus.
- PVE-UPS erhält zusätzlich nicht vererbtes Sys.Audit auf /; PowerMgmt bleibt am Knoten.
- Wartung → 10: CPU-, RAM- und dateibasierter Festplattentest, 1–120 Minuten, Temperaturgrenze 60–99 °C (Standard 95 °C), Live-Messung und Bericht unter `/home/diagnose/stresstest/`.
- Wartung → 11: optionale öffentliche Kuma-Statusansicht mit Antwortzeitverlauf, ohne API-Token.
- Installer-Updateüberwachung alle 15 Minuten mit Dashboard und Pushover.
- Wildcard-DNS bleibt unverändert.

**[Vollständige Versionshistorie](HISTORY.md)**
