# Homeatic / Homelab

Dieses Repository bündelt meine Home-Assistant-, Proxmox- und Pi-hole-Konfigurationen.

## Bereiche

- **proxmox/** – Proxmox VE Master-Installer und Dokumentation
- **pihole/** – eigene DNS-Einträge, Allow-/Blocklisten und Pi-hole-Dokumentation
- weitere Home-Assistant-/Homelab-Dateien können hier ergänzt werden

## Proxmox

Der Proxmox-Bereich ist für den modularen Komplett-Installer vorgesehen. Er umfasst unter anderem Home Assistant, Paperless-ngx + Ollama, Pi-hole + Unbound, NetAlertX, Monitoring, Grafana/Prometheus, PVE-UPS und weitere Dienste.

## Pi-hole

Eigene DNS-Einträge und Listen werden künftig unter **pihole/** gepflegt.

> Hinweis: Vor produktiven Änderungen immer Backups anlegen. Einige Proxmox-Installer-Modi können VMs/LXC löschen oder neu aufbauen.
