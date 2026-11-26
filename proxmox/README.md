# Proxmox Master Installer

Modularer Komplett-Installer für Proxmox VE.

## Aktueller Stand

**Installationskandidat: V180 · 26.11.2026**

## V180 · Automatische SSD-Speichereinheiten

- SSD-Gesamtkapazität, belegter, verfügbarer und reservierter Speicher werden unter 950 MB in MB und ab 950 MB in GB angezeigt; dezimale Einheiten und deutsche Zahlenformatierung. Prozentwerte bleiben unverändert.

## V179 · CPU/RAM-Icon und Update-Timer

- Redundanten CPU-Kartenkopf vollständig entfernt; CPU- und RAM-Symbole bleiben jeweils einmal mit sauberem Abstand sichtbar. Installer-Monitor prüft zu festen 5-Minuten-Zeitpunkten; bestehende Timer werden beim verwalteten Update migriert. Der reguläre Installationszeitpunkt bleibt unverändert.

## V178 · Speicherwartung und Auto-Release

- Tägliche konservative Speicherwartung für laufende CTs und unterstützte Linux-VMs, Docker-Image- und Build-Cache-Bereinigung, lokaler APT-Autoclean, Journal-Vacuum, TRIM, Speicherwarnungen und HAOS-Sonderbehandlung. Externe Caches bleiben erhalten. Docker-Logrotation wird zunächst geprüft und gemeldet. CPU-/RAM-Kachel ohne doppelte Überschrift und mit eigenen Symbolen; direkte Home-Assistant-JSON-Abfragen und stabile GitHub-Releases für verwaltete Updates.

## V177 · CPU/RAM und physische SSD

- CPU und RAM gleich groß nebeneinander mit separaten Balken; CPU-, Board- und SSD-Temperaturen kompakt darunter. Die bisherige RAM/SSD/Swap-Kachel zeigt die physische System-SSD mit Gesamtkapazität, belegten und direkt verfügbaren dezimalen MB, reserviertem Rest und separaten Root-/Thin-Pool-Balken. Automatische Erkennung für eindeutige Single-Disk-Root-LVM-Layouts, ohne doppelt gezählte Storage-Verzeichnisse oder NAS; bei fehlenden/mehrdeutigen Messwerten n/v. Thin-Pool-Belegung ist blockbasiert und gerundet, nicht NAND-Auslastung. Swap entfällt aus der Übersicht, Swap-Partition bleibt unverändert. Keine Änderung an Partitionen, Gästen, Branding oder Fail2Ban.

## V176 · Schutz und Speicher

- Schutz-Kachel ersetzt die bisherige Speicher-Kachel: Fail2Ban-Dienst, SSH- und Proxmox-Jail, aktive IP-Sperren, Fehlversuche seit Dienststart und konfigurierte Pushover-Aktion. Der vorhandene Ping-Dienst liefert alle 10 Sekunden nur aggregierte Schutzdaten; keine IP-Adressen, Tokens oder administrativen Aktionen. Fehlende oder veraltete Daten werden als n/v angezeigt. SSD-Temperatur in der CPU-Kachel neben CPU und Board; Speicher-Kachel RAM / SSD / Swap in dieser Reihenfolge, System-SSD mit Prozent, Balken und belegten dezimalen MB (nur Root-Dateisystem, nicht local-lvm). Bestehende Fail2Ban-, SSH-, Pushover- und Branding-Konfiguration unverändert. Zentrale Zeit: Nur die IANA-Zeitzone des Proxmox-Hosts ist maßgeblich (z. B. `timedatectl set-timezone Europe/Berlin`). UPPER liest sie über `/upper/timezone.json`, konvertiert Kuma-UTC-Zeitstempel einschließlich expliziter Offsets und Sommer-/Winterzeit, und verwendet für den Aktualisierungszeitpunkt den HTTP-Date-Header. Der Timer `proxmox-timezone-sync.timer` gleicht laufende verwaltete LXCs und die UPPER-Zeitzonendatei alle 15 Minuten ab, ohne Gastneustart; Host-NTP wird geprüft, nicht erzwungen. Neue unterstützte Anwendungsinstallationen übernehmen die Host-Zeitzone. Der normale Docker-Update-Lauf gleicht bei eindeutigem Compose-Projekt die Zeitzonenparameter von Kuma, Pi-hole, Paperless, Speedtest-Tracker und Mealie ab und startet bei tatsächlicher Konfigurationsabweichung nur den betreffenden Docker-Dienst neu (ohne Image-Pull in diesem Teilschritt). Mehrdeutige Layouts werden gemeldet statt überschrieben; Konfigurationssicherung und Rücksetzversuch bei Fehlern. Datenbank-UTC bleibt unverändert. Dashboard-Warn-/USV-Zeitdarstellung nutzt die Host-Zeitzone. Bestehende VMs, nicht unterstützte App-Zeitzonen, alte USV-Sonderkonfigurationen und gestoppte Gäste sind separat zu prüfen; der Wechsel von V175 auf V176 kann einen weiteren regulären Updater-Lauf benötigen.

## V175 · Fortschrittsbalken

- Fortschrittsbalken für CPU, RAM/Swap, Speicher, VM/LXC, Pi-hole, Netzwerk und USV; Leistungs-Mini-Verlauf aus tatsächlich beobachteten Messwerten. Dezimale Speichergrößen, deutsche Prozentwerte und Schutz vor alten Live-Renderern. Netzwerk-Maxima frei konfigurierbar (0 = Balken aus), Ping-Dienst bei Dashboard-Installation und verwalteten Updates. Bestehende Logos und Einstellungen bleiben erhalten.

## V174 · Monitoring und Schlummermodus

- Kompakte CPU-, Speicher-, VM/LXC- und Pi-hole-Kacheln, farbige Messwerte mit Goldorange und fließenden Übergängen, SVG-Symbole und Warnrahmen. Systemstatus, browserlokale Warnhistorie und System Alert (75 %), Schlummermodus 5/10/30/60 Minuten oder dauerhaft mit Countdown, blauem Endabschnitt und animierten Z. Netzwerk-Ping-Anzeige liest optional die Host-Messdatei; Host-Sampler separat aktivieren. Keine Änderungen an Logos oder DNS.

## V173 · Update-Verwaltung

- Modern Chime mit 100 % als neuer Standard; gespeicherte Einstellungen bleiben erhalten. Eigener Update-Reiter mit Versionsstatus, Zeitpunkt der Host-Prüfung, beobachteter lokaler Versionshistorie, Diagnose, GitHub-Verlauf und erneutem Statusabruf. Update-Badge am Menü, Ruhezeiten (optional), Export/Import der Browser-Ton- und Tab-Einstellungen, erneuter Abruf bei Wiederverbindung. Keine privilegierten Host-Aktionen aus dem Browser.

## V172 · Einstellungen und Benachrichtigungsklänge

- Einstellungen: gemeinsame viewport-begrenzte Dialoghöhe, feste Reiter, scrollbarer Inhalt und erreichbare Aktionsleiste; mobile Reiter horizontal scrollbar. Zehn lokal synthetisierte Benachrichtigungsklänge, 1-%-Lautstärkeschritte, einzeilige Prozentanzeige, keine überlappenden Testtöne, temporärer Teststatus. Update-Hinweis nur bei tatsächlich neuer Version; bestehende Klang-IDs und Einstellungen bleiben erhalten.

## V171 · Dashboard-Update-Klingelton

- Dashboard: Sanfter Update-Klingelton (2,5 Sekunden, standardmäßig 50 %, auch für bestehende Browser), einmal pro neuer verfügbarer Version. Klang, Lautstärke, Aktivierung und Testton in den Einstellungen. Browser-Audiofreigabe bei erster Interaktion. Update-Hinweise verwenden die numerisch neueste Version auf GitHub main statt einer Zwischenversion; direkte Aktualisierung durch den bestehenden Managed-Updater.

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

**[Vollständige Versionshistorie](HISTORY.md)**
