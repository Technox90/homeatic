# Homeatic / Homelab

Repository für Home Assistant, Proxmox VE, Pi-hole und die zugehörigen Homelab-Werkzeuge.

## Aktueller Stand

**Aktueller Stand: V175 · Proxmox Master Installer · 25.11.2026**

➡️ **[Aktuelle Proxmox-Dokumentation](proxmox/README.md)**  
➡️ **[Vollständige Versionshistorie](proxmox/HISTORY.md)**

Bestehende Installationen: [einmalige Layout-Migration V164](proxmox/README.md#v164--einmalige-migration-bestehender-installationen).

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
- lokale Proxmox-CA und TLS
- externe URLs per nginx + Let's Encrypt
- Dashboard mit Menü, Kategorien, USV, Pi-hole, Layouts und mehreren Ansichten
- automatische Updates, Diagnose und Healthchecks

## Dashboard

Das Dashboard liegt lokal unter:

```text
/opt/dashboard/
```

Eigene Branding-Dateien:

```text
/opt/dashboard/static/assets/logo.png
/opt/dashboard/static/assets/favicon.png
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
/opt/dashboard/         installierter Dashboard-Code
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

### V175

- Fortschrittsbalken für CPU, RAM/Swap, Speicher, VM/LXC, Pi-hole, Netzwerk und USV; Leistungs-Mini-Verlauf aus tatsächlich beobachteten Messwerten. Dezimale Speichergrößen, deutsche Prozentwerte und Schutz vor alten Live-Renderern. Netzwerk-Maxima frei konfigurierbar (0 = Balken aus), Ping-Dienst bei Dashboard-Installation und verwalteten Updates. Bestehende Logos und Einstellungen bleiben erhalten.

### V174

- Kompakte CPU-, Speicher-, VM/LXC- und Pi-hole-Kacheln, farbige Messwerte mit Goldorange und fließenden Übergängen, SVG-Symbole und Warnrahmen. Systemstatus, browserlokale Warnhistorie und System Alert (75 %), Schlummermodus 5/10/30/60 Minuten oder dauerhaft mit Countdown, blauem Endabschnitt und animierten Z. Netzwerk-Ping-Anzeige liest optional die Host-Messdatei; Host-Sampler separat aktivieren. Keine Änderungen an Logos oder DNS.

### V173

- Modern Chime mit 100 % als neuer Standard; gespeicherte Einstellungen bleiben erhalten. Eigener Update-Reiter mit Versionsstatus, Zeitpunkt der Host-Prüfung, beobachteter lokaler Versionshistorie, Diagnose, GitHub-Verlauf und erneutem Statusabruf. Update-Badge am Menü, Ruhezeiten (optional), Export/Import der Browser-Ton- und Tab-Einstellungen, erneuter Abruf bei Wiederverbindung. Keine privilegierten Host-Aktionen aus dem Browser.

### V172

- Einstellungen: gemeinsame viewport-begrenzte Dialoghöhe, feste Reiter, scrollbarer Inhalt und erreichbare Aktionsleiste; mobile Reiter horizontal scrollbar. Zehn lokal synthetisierte Benachrichtigungsklänge, 1-%-Lautstärkeschritte, einzeilige Prozentanzeige, keine überlappenden Testtöne, temporärer Teststatus. Update-Hinweis nur bei tatsächlich neuer Version; bestehende Klang-IDs und Einstellungen bleiben erhalten.

### V171

- Dashboard: Sanfter Update-Klingelton (2,5 Sekunden, standardmäßig 50 %, auch für bestehende Browser), einmal pro neuer verfügbarer Version. Klang, Lautstärke, Aktivierung und Testton in den Einstellungen. Browser-Audiofreigabe bei erster Interaktion. Update-Hinweise verwenden die numerisch neueste Version auf GitHub main statt einer Zwischenversion; direkte Aktualisierung durch den bestehenden Managed-Updater.

### V170

- UPPER: Slug-Eingabemaske nur auf der Startseite bzw. bei fehlgeschlagener erstmaliger Auswahl. Nach erfolgreichem Laden wird das Formular vollständig ausgeblendet und bleibt auch bei späteren Abruffehlern verborgen. Andere Statusseiten über `/upper/` oder direkte Slug-URL öffnen. Normale Browser-Zurück-Navigation möglich; keine Änderung an API, Monitoren, Logo oder Favicon.

### V169

- Seitenmenü: Nur die Diensteliste mit Kategorien scrollt. Einstellungen und GitHub bleiben mit einer durchgehenden Trennlinie am unteren Rand sichtbar, auf Desktop und Mobilgeräten. Bestehende Links und Kategorien bleiben unverändert.

### V168

- Browser-Tab: Leistungsanzeige einheitlich als `Leistung 19,60 W` statt `Teil 19,60 W`; Messwertberechnung und Kennzeichnung der Teilleistung im Dashboard bleiben unverändert.

### V167

- Netzwerk- und Datenträger-Übertragungsraten in dezimalen B/s, kB/s, MB/s, GB/s bzw. TB/s (Faktor 1000), einschließlich Diagrammachsen. Automatische Skalierung; Rohdaten, Speichergrößen und RAM-Einheiten unverändert.

### V166

- Ausschließlich lokale Host-Leistungsdaten: IPMI/DCMI hat Vorrang; andernfalls CPU-Package (oder vorhandener CPU-Teilbereich) plus separater Intel-RAPL-DRAM-Wert. Cores/Uncore nicht doppelt zählen. GPU separat ausweisen, wenn ihre Unabhängigkeit vom CPU-Messbereich nicht nachgewiesen ist; ohne CPU/DRAM kann GPU als Teilleistung angezeigt werden.
- Teilleistung wird in Kachel und Browser-Tab ausdrücklich gekennzeichnet. Fehlende Werte werden nicht geschätzt. Keine Smart-Home-, MQTT- oder externen Strommesser; USV/Pi-hole bleiben getrennt.

### V165

- Ladeanimation: führendes Wort „Dashboard“ wird ausschließlich im Ladebildschirm entfernt (z. B. `Dashboard LT-WBH` → `LT-WBH`). Gespeicherter Name, Seitentitel, Tab-Titel und Branding bleiben unverändert.

### V164

- Dashboard unter `/opt/dashboard/`; persönliche Dateien bleiben unter `static/assets/` erhalten.
- Neutrale Proxmox-Werkzeuge und lokale CA-Dateinamen; UPPER bleibt unabhängig unter `/var/www/upper/`.
- Boot-Animation übernimmt exakt den gespeicherten Dashboard-Namen, ohne zusätzliches Präfix.
- Bestehende Installationen erfordern eine einmalige, gesicherte Layout-Migration. Bestehende CA-Schlüssel, Zertifikate, Datenbanken und Gastdaten bleiben erhalten.

### V163

- UPPER: eigenständige Statusseite unter `/upper/`, Dateien in `/var/www/upper/`, Logo/Favicon bleiben bei Updates erhalten; Copyright und GitHub-Link, interaktive Ping-Diagramme mit Maus, Touch und Tastatur.
- Originale Kuma-Statusseiten bleiben unverändert. Opt-in-Updates migrieren alte Installationen; Nginx-Prüfung mit Rücksicherung.
- Dashboard: SVG-Symbole für Neustart und Herunterfahren. Uptime Kuma: Datenbank-Besitzrechte nicht rekursiv zurücksetzen, Health- und HTTP-Prüfung nach Updates.

### V162

- Freigabestand mit allen V161-Funktionen: individuell konfigurierbare aktive/inaktive Browser-Tab-Titel und priorisierte Update-Hinweise.
- Logo wird bei unveränderten Einstellungen während der laufenden USV-Statusabfragen nicht erneut geladen; bewusste Branding-Aktualisierung bleibt möglich.
- V162 enthält die bisherigen Änderungen kumulativ; der bestehende automatische Update-Zeitplan und die Opt-in-Einstellungen bleiben unverändert.

### V161

- Browser-Tab-Anzeige in den Dashboard-Einstellungen getrennt für aktive und inaktive Tabs konfigurierbar.
- Standard: aktiv nur Name; inaktiv Name → CPU/RAM → Leistungsaufnahme. Wechsel alle 5 Sekunden, Update-Hinweise alle 3 Sekunden.
- Update-Hinweise haben optional Vorrang; Messwerte und Versionsstatus werden aus bestehenden Abfragen übernommen. Speicherung lokal pro Browser, ohne Änderungen an Logos oder Favicons.

### V160

- Zusammenführung der parallelen V159-Änderungen: `randMenuLogo`, mittiger Titel, Logo bis 350 × 60 px sowie zugängliche mobile Power-Icons.
- Branding-Script erhält eine stabile ID; alte Update-Marker bleiben kompatibel.
- Beide verpflichtenden CI-Prüfungen laufen bei jedem Pull Request auf main, auch bei reinen Dokumentationsänderungen.
- Lokale Logo- und Favicon-Dateien bleiben unverändert.

### V159

- Aktive Branding-IDs und CSS-Klassen ohne Versionssuffix; das Logo verwendet `randMenuLogo`.
- Konfigurierter Dashboard-Titel wird auf Desktop und Mobilgeräten mittig angezeigt.
- Manueller und automatischer Updatepfad verwenden dieselben Branding-Quellen; lokale Logos/Favicons bleiben unverändert.

### V158

- Proxmox-Systeminformationen wandern vom Dashboard-Kopf in eine dezente Fußzeile.
- Die lokale Installer-Version ersetzt dort den Hostnamen; die Versionsangabe wird aus dem vorhandenen Update-Status gelesen.
- Copyright © Technox1990 mit GitHub-Link; bestehende Logos, Themes und Einstellungen bleiben unverändert.

**[Vollständige Versionshistorie](proxmox/HISTORY.md)**
