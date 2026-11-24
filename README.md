# Homeatic / Homelab

Repository für Home Assistant, Proxmox VE, Pi-hole und die zugehörigen NodeZero-/Homelab-Werkzeuge.

## Aktueller Stand

**Aktueller Stand: V159 · Proxmox Master Installer · 24.11.2026**

➡️ **[Aktuelle Proxmox-Dokumentation](proxmox/README.md)**  
➡️ **[Vollständige Versionshistorie](proxmox/HISTORY.md)**

## Bereiche

| Pfad | Inhalt |
|---|---|
| `proxmox/` | Master-Installer, Module, Tools, Dokumentation und History |
| `dashboard/` | Dashboard-Basisquellen, Styles, JavaScript und neutrale Branding-Platzhalter |
| `pihole/` | DNS-Einträge, Allow-/Blocklisten und Pi-hole-Daten |

## Proxmox Schnellinstallation

Auf dem Proxmox-Host als `root`:

```bash
curl -fsSL https://link.2mycloud.de/proxmox -o /root/proxmox.sh && chmod +x /root/proxmox.sh && /root/proxmox.sh
```

Direkte RAW-Quelle:

```text
https://raw.githubusercontent.com/Technox90/homeatic/refs/heads/main/proxmox/proxmox.sh
```

Der Installer besitzt seit V147 ein Self-Update und prüft beim Start den aktuellen Stand aus GitHub `main`.

## Wichtige Installer-Funktionen

Der Installer kann unter anderem verwalten:

- Home Assistant OS
- Paperless-ngx + PostgreSQL + Redis + Ollama
- Pi-hole + Unbound + Pi-hole Exporter
- NetAlertX
- Uptime Kuma
- Vaultwarden
- Stirling PDF
- Speedtest Tracker
- Scrutiny
- PVE-UPS
- Prometheus / PVE Exporter / Grafana
- EMQX
- weitere optionale Dienste
- lokale NodeZero-CA und TLS
- externe URLs per nginx + Let's Encrypt
- Dashboard mit Menü, Kategorien, USV, Pi-hole, Layouts und mehreren Ansichten
- automatische Updates, Diagnose und Healthchecks

## Dashboard

Das Dashboard liegt lokal unter:

```text
/opt/nodezero/dashboard/
```

Eigene Branding-Dateien:

```text
/opt/nodezero/dashboard/static/assets/logo.png
/opt/nodezero/dashboard/static/assets/favicon.png
```

**Update-Regel:** Ein normales Dashboard-Update verändert diese beiden Dateien niemals. Seit V152 bleiben außerdem die bereits aktuellen Dashboard-Programmdateien erhalten; der Installer setzt sie nicht mehr auf die V139-Basis zurück.

Bei Erst-/Neuinstallation werden nur dann neutrale, vollständig transparente PNG-Platzhalter aus dem Repository angelegt, wenn die jeweilige Datei noch fehlt.

Repository-Platzhalter:

```text
dashboard/assets/logo.png
dashboard/assets/favicon.png
```

Das Dashboard verwendet bei leerem/transparentem `logo.png` automatisch den konfigurierten Text-Fallback.

Dashboard aktualisieren:

```text
Hauptmenü → 1 Basis-Systeme → 2 Server-Dashboard installieren / aktualisieren
```

## Dateilayout

```text
/root/passwort/          aktive Secrets
/home/passwort/          lokale Secret-Sicherung
/home/downloads/         Downloads / wiederverwendbare Artefakte
/home/backups/           Backups
/home/diagnose/          Diagnoseberichte und Logs
/home/img/               Images / Container-/Template-Caches
/opt/nodezero/           installierter NodeZero-Code
```

## Passwortmanager

- [Vaultwarden / Bitwarden – Android, iOS und PC](proxmox/passwortmanager/README.md)
- [Optionales verschlüsseltes Vaultwarden-Offsite-Backup](proxmox/VAULTWARDEN-BACKUP.md)

## Pi-hole

Standardmäßig werden unter anderem folgende Listen eingebunden:

**Block**
- HaGeZi Pro
- HaGeZi TIF

**Allow**
- Homeatic-Allowlist aus diesem Repository
- HaGeZi Referral Native

Lokale DNS-/CNAME-Dateien liegen unter `pihole/`.

## Dokumentationsregel

Bei jeder neuen Installer-Version werden künftig gemeinsam aktualisiert:

1. `README.md` und `proxmox/proxmox.sh`
2. `proxmox/README.md`
3. `proxmox/HISTORY.md`
4. `proxmox/history.txt` als Text-Kompatibilitätsversion
5. `proxmox/CHATGPT-HANDOFF.md`
6. CI-Prüfungen unter `.github/workflows/`

> Reset-/Neuaufbau-Funktionen können VMs/LXC oder Dashboard-Daten entfernen. Vor destruktiven Aktionen Backups prüfen.

## Versionsverlauf – letzte 5 Versionen

### V159

- Dauerhafte Namen für Branding-CSS-Klassen, HTML-IDs und JavaScript-Funktionen statt Versionssuffixen.
- Desktop-Logo bis 350 × 60 px, responsive Skalierung auf kleineren Bildschirmen.
- Mobile Neustart- und Herunterfahren-Schaltflächen mit Icons und barrierefreien Beschriftungen; Sicherheitsabfragen bleiben erhalten.
- Installer und Auto-Updater migrieren das Branding; alte interne Kompatibilitätsmarker bleiben erhalten.

### V158

- Proxmox-Systeminformationen wandern vom Dashboard-Kopf in eine dezente Fußzeile.
- Die lokale Installer-Version ersetzt dort den Hostnamen; die Versionsangabe wird aus dem vorhandenen Update-Status gelesen.
- Copyright © Technox1990 mit GitHub-Link; bestehende Logos, Themes und Einstellungen bleiben unverändert.

### V157

- Dashboard-Branding erhält einen eigenen Inline-Script-Block statt Einfügen in das letzte Script-Element.
- Doppelte Einbindung der Installer-Updateanzeige wird entfernt; bestehende Logos, Favicons und Einstellungen bleiben erhalten.
- Sichtbare Theme-Namen entfallen in allen fünf Ansichten; Animationen und Auswahl bleiben erhalten.
- Auto-Updater repariert auch bestehende falsch platzierte Branding-Blöcke; Theme-Cache wird erneuert.
- Regressionstest für externe Script-Tags und wiederholbare Dashboard-Aktualisierung.

### V156

- Auto-Updater: drei unabhängige, standardmäßig ausgeschaltete Optionen für Master-Installer/Updater-Werkzeuge, verwaltete Dashboard-Oberfläche und vorhandene Kuma-Statusseite.
- Abruf aus veröffentlichtem `main`-Commit; Installer-Syntaxprüfung, keine Downgrades, Backups und atomarer Dateiaustausch.
- Keine Neuinstallation, kein Reset, keine Änderung an nginx, Zertifikaten, Logos/Favicons oder Datenbanken. Dashboard-Backend-Migrationen bleiben manuell.
- Update-Ergebnisse erscheinen im vorhandenen Auto-Updater-Bericht und in Pushover, sofern aktiviert.
- Menü: Wartung → Auto-Updater → 5; dort die gewünschten Komponenten einschalten.

### V155
- Einheitliche Nummerierung der sieben Haupt-Untermenüs; interne IDs bleiben stabil.
- Dashboard-Updates starten keine automatische Paperless-Migration mehr; vorhandene Paperless-, Kuma- und PVE-UPS-Container werden bei erneuter Installation übersprungen.
- Neue Kuma-Installationen verwenden das LXC-Hostnetz mit Bindung an 127.0.0.1:3001; IPv6 setzt funktionierendes LXC-IPv6 voraus.
- PVE-UPS erhält zusätzlich nicht vererbtes Sys.Audit auf /; PowerMgmt bleibt am Knoten.
- Wartung → 10: CPU-, RAM- und dateibasierter Festplattentest, 1–120 Minuten, Temperaturgrenze 60–99 °C (Standard 95 °C), Live-Messung und Bericht unter `/home/diagnose/stresstest/`.
- Wartung → 11: optionale öffentliche Kuma-Statusansicht mit Antwortzeitverlauf, ohne API-Token.
- Installer-Updateüberwachung alle 15 Minuten mit Dashboard und Pushover.
- Wildcard-DNS bleibt unverändert.

**[Vollständige Versionshistorie](proxmox/HISTORY.md)**
