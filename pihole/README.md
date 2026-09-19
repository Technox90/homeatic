# Pi-hole

Dieser Bereich enthält die eigene Pi-hole-Konfiguration.

## Struktur

- `dns/custom.list` – lokale DNS-Einträge im Format `IP Hostname`
- `allowlist/allowlist.txt` – eigene erlaubte Domains
- `blocklist/blocklist.txt` – eigene zusätzliche Blockeinträge
- `cname/cname.txt` – Dokumentation eigener CNAME-Zuordnungen

Der Proxmox-Installer richtet Pi-hole zusammen mit **Unbound** und dem **Pi-hole Prometheus Exporter** ein.

## Hinweise

Keine Passwörter, API-Tokens oder andere Secrets in dieses Repository committen.

Lokale DNS-Beispiele:

```text
192.168.178.100 pve.lan
192.168.178.103 pihole.lan
```
