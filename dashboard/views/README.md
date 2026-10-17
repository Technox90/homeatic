# NodeZero Dashboard-Ansichten (v1)

Fünf umschaltbare **Darstellungsprofile für das bestehende NodeZero-/Proxmox-Dashboard**. Die bestehenden API-Routen, Messwerte, Link-/Kategorieverwaltung, Start-/Stop-Funktionen und gespeicherte Einstellungen werden **nicht ersetzt**. Jede Ansicht verwendet dieselbe Dashboard-Weboberfläche plus eigenes CSS und die gemeinsame Frontend-Laufzeit `runtime.js`.

| Ansicht | ID | Besonderheit |
| --- | --- | --- |
| 1. Boot Sequence | `boot` | Initialer, zeitlich begrenzter Ladebildschirm mit animiertem Ring; kühles Cyan |
| 2. Live Pulse | `live` | Pulsierende Verbindungsanzeige und zeitbasierter 15-Sekunden-Balken; Grün/Türkis |
| 3. Telemetry Flow | `telemetry` | Grafikfokus mit feinem Diagrammraster und animierten Werteänderungen; Blau/Indigo |
| 4. Glass Motion | `glass` | Halbtransparente Karten, Unschärfe und Hover-Bewegungen; Violett |
| 5. Status Control | `status` | Klare Warnfarben, animierte Ressourcenwarnungen ab 80 % (kritisch ab 92 %); Dunkelgrün |

Alle Animationen respektieren `prefers-reduced-motion`. Der Ladebildschirm endet bei LIVE/OFFLINE oder nach spätestens 6,5 Sekunden. Kein Upload von Messdaten, keine zusätzlichen externen Abhängigkeiten.

## Installation und Wechsel

Im Proxmox-Installer `proxmox.sh`: **Basis-Systeme → Dashboard-Ansicht wählen · 5 GitHub-Designs / Offline-Cache**. Beim Neuinstallieren oder Aktualisieren des Server-Dashboards wird der letzte Zustand automatisch wiederhergestellt. Der Installer fragt bei einem existierenden Dashboard ggf. nach "Aktualisieren": ein reiner Wechsel erfolgt über den eigenen Menüpunkt und benötigt **keine komplette Dashboard-Neuinstallation**.

Direkt auf dem Proxmox-Host:

```bash
nodezero-dashboard-views --menu
nodezero-dashboard-views --list
nodezero-dashboard-views --status
nodezero-dashboard-views --select telemetry
nodezero-dashboard-views --refresh
```

Vor dem ersten Wechsel lädt das Werkzeug alle fünf CSS-Varianten und `runtime.js` über GitHub herunter; danach wird aus dem lokalen Cache umgeschaltet, selbst ohne Internet.

## Speicherpfade

- GitHub-Quelldateien: `dashboard/views/{boot,live,telemetry,glass,status}.css`, `dashboard/views/runtime.js`
- Offline-Cache: `/home/downloads/nodezero/dashboard-views/v1/`
- Aktive Frontend-Dateien: `/opt/nodezero/dashboard/static/nodezero-views/`
- Persistente Auswahl: `/etc/pve-sensor-dashboard/dashboard-view`
- Backup der HTML-Basis vor der ersten Aktivierung: `/home/backups/nodezero-dashboard-views/`
- Installer-Hilfswerkzeug: `/usr/local/sbin/nodezero-dashboard-views`

Das Werkzeug fügt **nur** drei Asset-Referenzen mit markiertem Start-/Endbereich im `<head>` hinzu und ersetzt diesen Bereich bei späteren Wechseln. Datenbanken, API-Routen, TLS, Links, Kategorien und Power-Steuercode bleiben unverändert. Ein Browser-Reload (Strg+F5) genügt. Für neue GitHub-Versionen den Cache explizit mit `--refresh` aktualisieren.

## Sicherheit und Status

Die Auswahl benötigt root-Rechte auf dem Proxmox-Host und ein installiertes Dashboard. Es wird kein Docker-Container neu gestartet. Die Schwellwerte in Status Control beziehen sich auf Ressourcenauslastung (CPU, RAM, Root-Speicher), nicht auf eigene neue Messungen. Die Animationsanzeige im Live-Profil visualisiert ein 15-Sekunden-Intervall und ist kein Garantieindikator für erfolgreiche API-Antworten.
