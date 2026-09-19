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


## Pi-hole GitHub-Synchronisation

Der Installer verwendet die Dateien aus diesem Repository:

- `pihole/blocklist/blocklist.txt`
- `pihole/allowlist/allowlist.txt`
- `pihole/dns/custom.list`

Die lokalen DNS-Einträge werden bei der Pi-hole-Installation in einen verwalteten Bereich der `custom.list` übernommen. Bereits vorhandene Einträge außerhalb dieses Bereichs bleiben erhalten.
