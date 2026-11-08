# Proxmox Tools

## proxmox-auto-updater

Das Hauptskript liegt unter `proxmox/tools/proxmox-auto-updater` und wird auf dem Proxmox-Host unter `/usr/local/sbin/proxmox-auto-updater` installiert. Dateiname und bestehender systemd-Dienst bleiben unverändert.

- Der systemd-Timer bestimmt die tägliche Uhrzeit (lokal aktuell durch Drop-in auf 07:00 Uhr eingestellt).
- Der Updater aktualisiert die konfigurierten LXC-Container, Docker-Compose-Projekte, optionale Home-Assistant-Komponenten und zuletzt den Proxmox-Host.
- Vor automatischen APT-`dist-upgrade`-Läufen wird der Paketplan geprüft. Geplante Paketentfernungen stoppen das jeweilige Upgrade und erzeugen eine manuelle Warnung.
- Docker-Compose-Updates entfernen keine verwaisten Container mehr automatisch.
- Die Pushover-Zusammenfassung wird bei Bedarf gekürzt und verweist am Schluss auf die vollständige lokale Zusammenfassung. Fehler werden bei jedem Update-Lauf gemeldet, unveränderte manuelle Warnungen höchstens alle sieben Tage nach erfolgreichem Versand.
- Logs und Zusammenfassungen stehen unter `/home/diagnose/proxmox-auto-updater/` und werden nach 60 Tagen bereinigt.
- Der Proxmox-Host wird nicht automatisch neugestartet.

### Bestehende Installation von GitHub aktualisieren und starten

Als `root` auf dem Proxmox-Host ausführen:

```bash
set -Eeuo pipefail
URL="https://raw.githubusercontent.com/Technox90/homeatic/main/proxmox/tools/proxmox-auto-updater"
TARGET="/usr/local/sbin/proxmox-auto-updater"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

curl -fsSL --retry 3 "$URL" -o "$TMP"
test -s "$TMP"
bash -n "$TMP"
mkdir -p /root/update-backups
cp -a "$TARGET" "/root/update-backups/proxmox-auto-updater-$(date +%Y%m%d-%H%M%S)"
install -o root -g root -m 700 "$TMP" "$TARGET"
systemctl start proxmox-auto-updater.service
```

Dieser Befehl führt nach erfolgreicher Syntaxprüfung sofort einen **produktiven Update-Lauf** aus. Dabei können LXC-, Docker- und Home-Assistant-Dienste neugestartet werden. Die GitHub-Datei enthält keine Pushover-Zugangsdaten; lokale Secrets bleiben in `/root/.config/proxmox-auto-updater/pushover.env`.

### Tests

```bash
bash -n proxmox/tools/proxmox-auto-updater
bash proxmox/tests/test-auto-updater.sh
```

Die Tests verwenden simulierte Paketverwaltung und Pushover-Zustellung; sie führen keine echten Updates aus.

## proxmox-auto-updater-config

TUI-Konfiguration für den automatischen Update-Lauf. Unterstützt Status, tägliche Uhrzeit, Sofortlauf und Log-Anzeige. Eine geänderte Uhrzeit wird persistent in `/root/.config/proxmox-auto-updater/schedule.env` gespeichert und per systemd-Drop-in angewendet.

## proxmox-pushover-config

Eigenständiges TUI für Pushover. Verwaltet Empfänger, API-Zugangsdaten, Testnachrichten sowie Aktivieren/Deaktivieren. Die Zugangsdaten werden lokal mit restriktiven Dateiberechtigungen gespeichert; die optionale Gerätebindung kann durch Leeren des Feldes entfernt werden.
