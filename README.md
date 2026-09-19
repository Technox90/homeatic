# Homeatic / Homelab

Dieses Repository bündelt meine Home-Assistant-, Proxmox- und Pi-hole-Konfigurationen.

## Bereiche

- **proxmox/** – Proxmox VE Master-Installer und Dokumentation
- **pihole/** – eigene DNS-Einträge, Allow-/Blocklisten und Pi-hole-Dokumentation
- weitere Home-Assistant-/Homelab-Dateien können hier ergänzt werden

## Proxmox

Der Proxmox-Bereich enthält meinen modularen Komplett-Installer für Proxmox VE. Er kann unter anderem Home Assistant, Paperless-ngx + Ollama, Pi-hole + Unbound, NetAlertX, Uptime Kuma, Caddy, Prometheus, Grafana, PVE-UPS, EMQX und weitere Dienste installieren und konfigurieren.

Aktueller Installationskandidat: **V115**

### Schnellinstallation

Auf dem Proxmox-Host als `root` ausführen:

```bash
curl -fsSL https://link.2mycloud.de/proxmox -o /root/proxmox.sh && chmod +x /root/proxmox.sh && /root/proxmox.sh
```

Der Kurzlink verweist auf die aktuelle RAW-Version dieses Repositorys:

```text
https://raw.githubusercontent.com/Technox90/homeatic/refs/heads/main/proxmox/proxmox.sh
```

Optional kann vor dem Start geprüft werden, ob wirklich das Shell-Skript ausgeliefert wird:

```bash
curl -fsSL https://link.2mycloud.de/proxmox | head
```

Die Ausgabe sollte mit folgendem Shebang beginnen:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
```

### Was der Installer vorbereitet

Der Installer kümmert sich unter anderem um:

- Proxmox No-Subscription-Konfiguration
- Storage- und Kapazitätsprüfungen
- LXC-/VM-Erstellung mit festen Ressourcenprofilen
- lokale HTTPS-Zertifikate und CA
- Passwort-, Token- und Secret-Ablage unter `/home/passwd/`
- Pi-hole + Unbound + Pi-hole Exporter
- automatische Pi-hole Block-/Allowlisten
- Prometheus-/Grafana-Monitoring
- finale Healthchecks der installierten Komponenten

Die ausführliche Dokumentation liegt unter **proxmox/README.md**.

## Pi-hole

Eigene DNS-Einträge und Listen werden unter **pihole/** gepflegt.

Bei der Pi-hole-Installation werden automatisch diese Standardlisten angelegt:

**Blocklisten**
- HaGeZi Pro
- HaGeZi TIF

**Allowlisten**
- eigene Homeatic-Allowlist aus diesem Repository
- HaGeZi Referral Native

Die Dateien unter `pihole/` können unabhängig vom Installer gepflegt und versioniert werden.

> **Wichtig:** Vor produktiven Änderungen immer Backups anlegen. Besonders die Reset- und Optimal-Modi des Proxmox-Installers können vorhandene VMs/LXC löschen oder neu aufbauen.
