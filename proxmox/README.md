# Proxmox Master Installer

Hier liegt der Proxmox VE Master-Installer.

## Aktueller Stand

Installationskandidat: **V139**

Geplante Hauptdatei:

```
proxmox.sh
```

## Enthaltene Funktionen

- kompaktes Menü mit thematischen Untermenüs
- `O – Optimale Installation`
- automatische No-Subscription-Konfiguration
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
- Download-Cache unter `/root/downloads/`
- finale Healthchecks

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

V139 trennt Installerlogik und große Dashboard-Quelldateien. `collector.py`, `app.py` und `index.html` liegen im Repository unter `dashboard/`. Der Installer lädt die zu V139 gehörenden Dateien über einen unveränderlichen Commit-Ref in `/root/downloads/dashboard/<asset-ref>/` und installiert sie nach `/opt/nodezero/dashboard/`.

### Verzeichnisstandard

```text
/root/passwort/          aktive Passwörter, Tokens und Secrets
/home/passwort/          lokale Sicherung dieser Secret-Dateien
/root/downloads/         normale Downloads / GitHub-Artefakte
/home/img/               persistente Installationsimages und große Caches
/opt/nodezero/            eigener installierter NodeZero-Code
```

Der bestehende Cache aus `/home/Images` und das alte Dashboard unter `/opt/pve-sensor-dashboard` werden beim Update soweit eindeutig möglich automatisch übernommen. Kompatibilitäts-Symlinks verhindern, dass ältere Helfer sofort brechen.
