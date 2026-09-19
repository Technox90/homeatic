# Proxmox Master Installer

Hier liegt der Proxmox VE Master-Installer.

## Aktueller Stand

Installationskandidat: **V114**

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
- getrennte Passwort-/Token-/Secret-Dateien unter `/home/passwd/`
- finale Healthchecks

## Start

```bash
chmod +x proxmox.sh
./proxmox.sh
```

> Achtung: Reset- und Optimal-Modi können vorhandene VMs/LXC löschen.

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
