# Homeatic / Homelab

Dieses Repository bündelt meine Home-Assistant-, Proxmox- und Pi-hole-Konfigurationen.

## Bereiche

- **proxmox/** – Proxmox VE Master-Installer und Dokumentation
- **pihole/** – eigene DNS-Einträge, Allow-/Blocklisten und Pi-hole-Dokumentation
- weitere Home-Assistant-/Homelab-Dateien können hier ergänzt werden

## Proxmox

Der Proxmox-Bereich enthält meinen modularen Komplett-Installer für Proxmox VE. Er kann unter anderem Home Assistant, Paperless-ngx + Ollama, Pi-hole + Unbound, NetAlertX, Uptime Kuma, Caddy, Prometheus, Grafana, PVE-UPS, EMQX und weitere Dienste installieren und konfigurieren.

Aktueller Installationskandidat: **V118**

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

## Hardware-Anforderungen

Die offiziellen Proxmox-VE-Anforderungen sind bewusst sehr allgemein gehalten. Für diesen Installer sind die Anforderungen höher, weil je nach Auswahl mehrere VMs/LXC, Docker-Dienste, Monitoring und lokale KI gleichzeitig betrieben werden.

### Proxmox VE – offizielle Basis

Laut Proxmox werden für einen produktiven Host unter anderem empfohlen:

- 64-Bit Intel-/AMD-CPU mit Intel VT bzw. AMD-V
- mindestens **2 GB RAM für Proxmox VE selbst**, zusätzlich RAM für die Gäste
- schneller, möglichst redundanter Storage; SSDs werden empfohlen
- mindestens Gigabit-Ethernet
- für PCIe-Passthrough zusätzlich Intel VT-d bzw. AMD-Vi
- bei ZFS oder Ceph zusätzlicher RAM-Bedarf

Quelle: https://www.proxmox.com/de/produkte/proxmox-virtual-environment/systemanforderungen

### Realistisch für diesen Installer

Der feste **Optimal-Stack** ist aktuell mit insgesamt ungefähr **61 vCPU**, **80 GB maximalem Gast-RAM** und **286 GB virtueller Root-Disk** konfiguriert. vCPU dürfen überbucht werden; die Zahl entspricht daher nicht der benötigten Anzahl physischer CPU-Kerne. LXC-RAM ist ebenfalls ein Limit und wird nicht dauerhaft vollständig belegt.

| Einsatz | CPU | RAM | Storage | Einschätzung |
|---|---:|---:|---:|---|
| Kleine Auswahl / Testbetrieb | 4 Kerne / 8 Threads | 16–32 GB | 256–500 GB SSD | Für einzelne Dienste, nicht für den kompletten Optimal-Stack |
| Voller Optimal-Stack – Untergrenze | 8 Kerne / 16 Threads | 64 GB | mindestens 500 GB SSD | Funktioniert bei moderater Last, wenig Reserve |
| **Empfohlen für den kompletten Stack** | **12 Kerne / 24 Threads** | **96 GB** | **1 TB SSD/NVMe** | Gute Reserve für Paperless/Ollama, HA und Monitoring |
| Komfortabel / Erweiterbar | 16+ Kerne / 32+ Threads | 128 GB+ | 2 TB SSD/NVMe | Für zusätzliche VMs, größere Datenmengen und Snapshots |

### Weitere Empfehlungen

- **Storage:** NVMe ist ideal; eine gute SATA-SSD reicht für ein Homelab ebenfalls aus.
- **Freier Speicher:** Für den Optimal-Stack prüft der Installer vor dem Löschen/Neuaufbau auf rund **315 GB freien VM/LXC-Speicher**.
- **NAS:** Paperless-Daten können auf ein externes NAS ausgelagert werden; das reduziert den lokalen Datenverbrauch deutlich.
- **Netzwerk:** 1 Gbit/s reicht grundsätzlich. **2,5 Gbit/s** ist sinnvoll, wenn NAS, Backups oder große Dateien häufig übertragen werden.
- **Backups:** Eine einzelne SSD ist keine Redundanz. Für wichtige Daten sollte ein separates NAS oder Proxmox Backup Server verwendet werden.
- **ZFS/Ceph:** Bei Nutzung dieser Storage-Systeme zusätzlichen RAM einplanen; die obigen Werte beziehen sich primär auf einen klassischen einzelnen Proxmox-Host mit lokalem VM/LXC-Storage.

> Die Angaben sind bewusst praxisnah und keine offiziellen Mindestanforderungen von Proxmox. Je mehr optionale Dienste oder zusätzliche VMs installiert werden, desto mehr CPU, RAM und Storage sollten eingeplant werden.



### Home Assistant HTTPS

Home Assistant wird vom Installer direkt auf **HTTPS-Port 443** vorbereitet. Bei der Standard-IP ist die Weboberfläche anschließend unter `https://192.168.178.101` erreichbar. Das Zertifikat wird von der lokalen NodeZero-CA signiert.
