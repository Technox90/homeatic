# Proxmox Tools

## proxmox-auto-updater-config

TUI-Konfiguration für den automatischen Update-Lauf. Unterstützt Status, tägliche Uhrzeit, Sofortlauf und Log-Anzeige. Eine geänderte Uhrzeit wird persistent in `/root/.config/proxmox-auto-updater/schedule.env` gespeichert und per systemd-Drop-in angewendet.

## proxmox-pushover-config

Eigenständiges TUI für Pushover. Verwaltet Empfänger, API-Zugangsdaten, Testnachrichten sowie Aktivieren/Deaktivieren.
