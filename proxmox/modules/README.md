# Proxmox Module

Seit **V140** wird größere Installationslogik aus dem Master-Installer ausgelagert.

## dashboard.sh

`dashboard.sh` enthält die vollständige Dashboard-Logik, die zuvor direkt in `proxmox/proxmox.sh` steckte:

- Dashboard-Installation und Basisdateien
- Service-/Link-Manager
- Menüsortierung und Router-Link
- Einstellungen, Farben und Theme-Migrationen
- Kategorien und Kategorie-Zuordnung
- HTTP/HTTPS-Dashboard-Konfiguration
- USV-/NAS-Karte und USV-Einstellungen
- Layout-Editor
- Pi-hole-Dashboard-Einstellungen
- finale Dashboard-Prüfung und `/usv`-Shortcut

Der Master-Installer lädt das Modul versionsgebunden nach:

```text
/root/downloads/nodezero/modules/<git-ref>/dashboard.sh
```

und bindet es anschließend mit `source` ein.
