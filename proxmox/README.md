# Proxmox Master Installer

Hier liegt der Proxmox VE Master-Installer.

## Aktueller Stand

Installationskandidat: **V149**

Geplante Hauptdatei:

```
proxmox.sh
```

## Enthaltene Funktionen

- kompaktes Menü mit thematischen Untermenüs
- `O – Optimale Installation`
- automatische No-Subscription-Konfiguration
- automatisches Self-Update des Installers beim Start gegen GitHub `main`
- Storage-Preflight mit zusätzlicher Reserve
- Home Assistant OS
- Paperless-ngx + PostgreSQL + Redis + Ollama
- Pi-hole + Unbound + Pi-hole Exporter
- NetAlertX
- Uptime Kuma, Caddy, Stirling PDF, Speedtest Tracker, Scrutiny
- Pulse, PVE-UPS, Prometheus, PVE Exporter, Grafana und EMQX
- Semaphore und weitere optionale Community-Erweiterungen
- lokale HTTPS-CA und Zertifikatsverwaltung
- aktive Passwort-/Token-/Secret-Dateien unter `/root/passwort/`
- lokale Secret-Sicherung unter `/home/passwort/`
- permanenter Image-/Container-Cache unter `/home/img/`
- Downloads und wiederverwendbare Artefakte unter `/home/downloads/`
- Backups unter `/home/backups/`
- Diagnose-/Laufprotokolle unter `/home/diagnose/`
- Pi-hole-Sprachlogs unter `/home/diagnose/pihole-language/` statt unter `/root`
- externe URLs mit automatischen Subdomain-Vorschlägen, nginx Reverse Proxy und Let's Encrypt
- Stirling PDF über offiziellen GHCR-Containerpfad mit Migration bestehender Compose-Installationen
- finale Healthchecks

## 🔐 Passwortmanager – Vaultwarden

| Persönliche Einrichtung | Root-Server-Backup |
|---|---|
| [📱 Android/iOS/PC: Schritt-für-Schritt-Anleitung mit Store-QR-Codes](passwortmanager/README.md) | [🗄️ Verschlüsseltes Offsite-Backup einrichten](VAULTWARDEN-BACKUP.md) |

## Installation

Am einfachsten direkt auf dem Proxmox-Host als `root` ausführen:

```bash
curl -fsSL https://link.2mycloud.de/proxmox -o /root/proxmox.sh && chmod +x /root/proxmox.sh && /root/proxmox.sh
```

Der Kurzlink verweist auf die aktuelle RAW-Version aus diesem Repository:

```text
https://raw.githubusercontent.com/Technox90/homeatic/refs/heads/main/proxmox/proxmox.sh
```

Optional kann vor der Ausführung geprüft werden, ob wirklich das Shell-Skript geliefert wird:

```bash
curl -fsSL https://link.2mycloud.de/proxmox | head
```

Die ersten Zeilen sollten mit folgendem Shebang beginnen:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
```

Alternativ nach einem manuellen Download:

```bash
chmod +x proxmox.sh
./proxmox.sh
```

> **Achtung:** Reset- und Optimal-Modi können vorhandene VMs/LXC löschen. Vor produktiver Nutzung Backups prüfen.

## Pi-hole Standardlisten

Bei der Pi-hole-Installation werden automatisch genau diese vier Listen als Abonnements in Pi-hole angelegt:

### Blocklisten

- `https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.txt`
- `https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/tif.txt`

### Allowlisten

- `https://raw.githubusercontent.com/Technox90/homeatic/refs/heads/main/pihole/allowlist/allowlist.txt`
- `https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/whitelist-referral-native.txt`

Anschließend führt der Installer ein `pihole -g` aus, damit die Listen sofort geladen werden.

Die Datei `pihole/dns/custom.list` bleibt separat für lokale DNS-Einträge vorgesehen.


## Fresh-PVE / Enterprise-Repository

Ab **V116** wird die Proxmox-Repository-Normalisierung auf **pve-no-subscription** vollständig durchgeführt, bevor der Auto-Updater Pakete nachinstallieren darf. Damit läuft auf einer frischen Proxmox-Installation kein frühes `apt-get update` mehr gegen die standardmäßig aktiven Enterprise-Repositories.


## Fresh-Install-Fix V116

Auf einem frisch installierten Proxmox VE wird zuerst die Repository-Konfiguration auf **pve-no-subscription** normalisiert. Erst nach einem erfolgreichen APT-Preflight wird der Proxmox-Auto-Updater installiert. Dadurch schlägt der erste Start nicht mehr an den standardmäßig aktiven Enterprise-Repositories mit HTTP 401 fehl.


## PVE-UPS-Preflight-Fix V117

Der PVE-UPS-Verfügbarkeitscheck wird jetzt definiert, bevor der Optimal-Preflight ihn aufruft. Damit tritt auf einem frischen Proxmox kein `community_pve_ups_available: command not found` mehr auf.


## Home-Assistant-HTTPS V118

Home Assistant OS wird bereits vor dem ersten Boot mit einem von der NodeZero Local-CA signierten Zertifikat vorbereitet und direkt auf **Port 443/TLS** konfiguriert.

Standard-Aufruf:

```text
https://192.168.178.101
```

Die Zertifikate werden in die HAOS-SSL-Ablage geschrieben und in die bestehende wöchentliche TLS-Erneuerung des Installers aufgenommen. Die lokale NodeZero-CA muss auf Clients einmalig als vertrauenswürdige Stamm-CA importiert werden, damit der Browser keine Zertifikatswarnung anzeigt.


## Fresh-Install-Fixes V117

- PVE-UPS-Verfügbarkeitsprüfung wird vor dem Optimal-Preflight definiert und kann deshalb auf einem frischen Lauf sicher aufgerufen werden.
- Docker-Installation in LXCs verwendet ein quoted heredoc. Dadurch werden awk-Ausdrücke wie `$4` und andere Shell-Variablen nicht mehr versehentlich vom Proxmox-Host expandiert.


## Dashboard-Fix V118

Nach einem vollständigen Dashboard-Reset erzeugt der Installer automatisch einen neuen Steuer-Code, falls kein vorbereiteter Code mehr im Shell-Kontext vorhanden ist. Der Code wird anschließend unter `/root/passwort/` gesichert und zusätzlich nach `/home/passwort/` kopiert.


## Pi-hole Exporter Fix V117

Der Pi-hole Exporter `ekofr/pihole-exporter:v1.2.0` wird mit seinem eigenen Docker-Image-CMD gestartet. Der zuvor gesetzte Pfad `/app/pihole-exporter` war für v1.2.0 falsch; das Image startet sein Binary aus `/root/pihole-exporter`. Bind-Adresse und Port werden jetzt über `BIND_ADDR` und `PORT` gesetzt.

Zusätzlich wurde die PVE-UPS-Verfügbarkeitsfunktion vor den Optimal-Preflight verschoben, damit der Preflight sie auf einem frischen Lauf bereits kennt.


## PVE-UPS-Preflight V117

Die PVE-UPS-Verfügbarkeitsprüfung wird jetzt vor dem Optimal-Stack-Preflight definiert. Dadurch kann der Pflichtcheck vor dem Guest-Reset auf einem frischen Proxmox korrekt ausgeführt werden.

Home Assistant OS wird im Installer ausdrücklich als native Weboberfläche auf `http://<HA-IP>:8123/` ausgewiesen. HTTPS/443 erfordert bei HAOS einen separaten Reverse Proxy.


## Versionsanzeige im Hauptmenü

Die aktuell ausgeführte Installer-Version wird im Whiptail-Hauptmenü direkt im Dialograhmen angezeigt, z. B. **HAUPTMENÜ · Version 118**.


## Modularisierung V139

V139 trennt Installerlogik und große Dashboard-Quelldateien. `collector.py`, `app.py` und `index.html` liegen im Repository unter `dashboard/`. Der Installer lädt die zu V139 gehörenden Dateien über einen unveränderlichen Commit-Ref in `/home/downloads/dashboard/<asset-ref>/` und installiert sie nach `/opt/nodezero/dashboard/`.

### Verzeichnisstandard

```text
/root/passwort/          aktive Passwörter, Tokens und Secrets
/home/passwort/          lokale Sicherung dieser Secret-Dateien
/home/downloads/         normale Downloads / GitHub-Artefakte
/home/backups/           Konfigurations- und Reparatur-Backups
/home/diagnose/          Diagnoseberichte und Installer-Logs
/home/img/               persistente Installationsimages und große Caches
/opt/nodezero/            eigener installierter NodeZero-Code
```

Der bestehende Cache aus `/home/Images` und das alte Dashboard unter `/opt/pve-sensor-dashboard` werden beim Update soweit eindeutig möglich automatisch übernommen. Kompatibilitäts-Symlinks verhindern, dass ältere Helfer sofort brechen.


## Dashboard vollständig modularisiert · V140

Ab V140 befindet sich die komplette Dashboard-Logik in:

```text
proxmox/modules/dashboard.sh
```

Der Master-Installer enthält nur noch den Modul-Loader. Das Modul wird über einen unveränderlichen Git-Commit nach `/home/downloads/nodezero/modules/<git-ref>/dashboard.sh` geladen, mit `bash -n` geprüft und anschließend per `source` eingebunden. Die separaten Dashboard-Basisdateien unter `dashboard/` bleiben bestehen.


## Auto-Updater / Pushover getrennt · V141

Unter **Wartung & Einstellungen** sind Auto-Updater und Pushover zwei getrennte Menüpunkte. Die Update-Uhrzeit kann im Auto-Updater-Menü geändert werden und wird persistent per systemd-Drop-in gespeichert. Pushover besitzt ein eigenes Whiptail-Menü im Stil des restlichen Installers.

```bash
proxmox-auto-updater-config
proxmox-pushover-config
```


## Navigation-Fix V142

Die Wartungspunkte **Auto-Updater** und **Pushover** kehren nach „Zurück“ wieder in den Master-Installer zurück. Die bisherigen `exit 0`-Anweisungen nach Auswahl 11 und 20 wurden durch `continue` ersetzt.


## Externe URLs · V146

Unter **Wartung & Einstellungen → Externe URLs** kann eine Hauptdomain wie `ltwbh.de` hinterlegt werden. Das Tool erkennt installierte Webdienste und schlägt passende Namen vor, zum Beispiel:

```text
dash.ltwbh.de      → Dashboard
ha.ltwbh.de        → Home Assistant
paper.ltwbh.de     → Paperless
vault.ltwbh.de     → Vaultwarden
pdf.ltwbh.de       → Stirling PDF
uptime.ltwbh.de    → Uptime Kuma
```

Die vorgeschlagenen Hostnamen und internen Backend-URLs können einzeln bearbeitet werden. Zusätzliche eigene Dienste lassen sich ergänzen. Sensible Admin-Oberflächen sind standardmäßig nicht für externen Zugriff ausgewählt.

Das Tool erzeugt exakte nginx-`server_name`-VHosts auf dem Proxmox-Host und verwendet Let's Encrypt für öffentlich vertrauenswürdige Zertifikate. **Proxmox VE selbst bleibt auf dem nativen Port 8006.** Das lokale NodeZero-Dashboard behält Port 80/443.

Voraussetzungen für Let's Encrypt HTTP-01:

- öffentliche DNS-Einträge der gewählten Subdomains zeigen auf den Heimanschluss bzw. auf das hinterlegte DynDNS-/CNAME-Ziel,
- TCP 80 und 443 werden auf den Proxmox-Host weitergeleitet.

Persistente Dateien:

```text
/home/Data/proxmox-installer/external-urls/config.json
/home/Data/proxmox-installer/external-urls/dns-records.txt
/home/diagnose/external-urls/
/home/backups/external-urls/
```

## Pi-hole-Logs · V146

Das Pi-hole-Sprach-/Update-Hilfswerkzeug schreibt keine Laufprotokolle mehr direkt nach `/root`. Neue Logs liegen unter:

```text
/home/diagnose/pihole-language/
```

Alte Dateien `/root/pihole-sprache-*.txt` werden beim Installer-Start übernommen. Diagnose-Logs werden nach 60 Tagen bereinigt. Aktive Passwörter und Tokens bleiben davon getrennt unter `/root/passwort/`.


## Automatisches Installer-Update · V147

Ab V147 reicht nach der einmaligen Aktualisierung weiterhin:

```bash
bash proxmox.sh
```

Vor dem eigentlichen Installer-Start wird `proxmox/proxmox.sh` aus dem GitHub-`main`-Branch geladen und mit der lokalen Datei verglichen.

Wenn beide Dateien identisch sind, startet die lokale Version direkt weiter. Bei einem Unterschied wird die GitHub-Datei zuerst geprüft:

```text
Download erfolgreich
→ Installer-Marker vorhanden
→ bash -n erfolgreich
→ bestehende lokale Datei sichern
→ neue Datei installieren
→ neue Version automatisch starten
```

Backups der ersetzten Installer-Versionen liegen unter:

```text
/home/backups/proxmox-installer-self-update/
```

Ist GitHub nicht erreichbar oder ist die heruntergeladene Datei ungültig, wird **kein** Update installiert. Die vorhandene lokale Version startet in diesem Fall normal weiter.

Der Vergleich erfolgt über den vollständigen Dateiinhalt. Dadurch werden auch Korrekturen erkannt, wenn die sichtbare Versionsnummer ausnahmsweise unverändert geblieben ist.


## Stirling PDF Registry · V148

Stirling PDF wird neu über den offiziellen GHCR-Pfad betrieben:

```text
ghcr.io/stirling-tools/stirling-pdf:latest
```

Der bisherige Pfad `docker.stirlingpdf.com/stirlingtools/stirling-pdf:latest` bleibt zwar offiziell, kann aber zeitweise nicht erreichbar sein. Stirling nennt Docker Hub und GitHub Container Registry ausdrücklich als alternative Registries.

Bestehende NodeZero-Stirling-Container werden beim Auto-Updater einmalig migriert. Vor der Änderung wird die aktive Compose-Datei gesichert und anschließend mit `docker compose config -q` validiert. Bei einem Fehler wird automatisch das Backup wiederhergestellt.


## Uptime Kuma URL · V149

Für Uptime Kuma lautet der Standardvorschlag der External-URL-Verwaltung jetzt:

```text
up.<hauptdomain>
```

Bei der Hauptdomain `ltwbh.de` wird damit `https://up.ltwbh.de` vorgeschlagen. Die URL kann weiterhin wie jede andere externe URL im Menü einzeln bearbeitet werden.


## ChatGPT-Handoff

Für einen neuen Chat bzw. eine vollständige technische Übergabe gibt es:

```text
proxmox/CHATGPT-HANDOFF.md
```

Die Datei enthält den aktuellen Proxmox-/nginx-/Domain-/Zertifikatsstand, die produktiven Pfade, den Uptime-Kuma-Stand zu `https://up.ltwbh.de` sowie einen direkt kopierbaren Startprompt. Keine Secrets in dieser Datei hinterlegen.
