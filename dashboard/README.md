# NodeZero Proxmox Dashboard

Diese Dateien sind die ausgelagerten Basisquellen des Proxmox-Dashboards.

- `collector.py` – sammelt Host-/Hardware-/VM-/LXC-Metriken.
- `app.py` – Flask/Gunicorn API des Dashboards.
- `index.html` – Basis-Frontend.

Seit Installer **V139** werden diese Dateien nicht mehr als große Heredocs in `proxmox/proxmox.sh` eingebettet. Der Installer lädt sie versionsgebunden in den persistenten Downloadbereich `/root/downloads/dashboard/<asset-ref>/` und installiert sie nach `/opt/nodezero/dashboard/`.

Die weiterhin im Installer enthaltenen Dashboard-Migrationsfunktionen werden danach angewendet, damit vorhandene Installationen aus älteren Versionen updatefähig bleiben.
