# ChatGPT-Handoff · Proxmox

Stand: 25.11.2026

Diese Datei dient als Übergabe für einen neuen Chat. Keine Passwörter, Tokens oder sonstige Secrets hier eintragen.

## Repository

- Repository: `Technox90/homeatic`
- Branch: `main`
- Master-Installer: `proxmox/proxmox.sh`
- Aktueller Installationskandidat: V169
- External-URL-Tool: `proxmox/tools/proxmox-external-urls`
- Auto-Updater: `proxmox/tools/proxmox-auto-updater`
- Dashboard-Modul: `proxmox/modules/dashboard.sh`

Produktive Namen und Pfade nicht ohne ausdrücklichen Wunsch ändern.

## Proxmox / Netzwerk

- Proxmox/nginx: `192.168.178.100`
- Home Assistant VM 101: `192.168.178.101`
- Paperless LXC 102
- Pi-hole LXC 103
- NetAlertX LXC 104
- Uptime Kuma LXC 105
- Stirling PDF LXC 106
- Speedtest Tracker LXC 107
- Scrutiny LXC 108
- PVE-UPS LXC 109
- Vaultwarden LXC 110

Home Assistant direkt:
- `http://192.168.178.101:80/`
- getestet: HTTP 200

Externer nginx läuft auf dem Proxmox-Host.

## Öffentliche Domains

Hauptdomain: `ltwbh.de`

Aktiv bzw. vorgesehen:

- `https://dash.ltwbh.de` → Dashboard
- `https://ha.ltwbh.de` → Home Assistant
- `https://paper.ltwbh.de` → Paperless
- `https://pdf.ltwbh.de` → Stirling PDF
- `https://vault.ltwbh.de` → Vaultwarden
- `https://up.ltwbh.de` → Uptime Kuma

DNS/DynDNS:
- `home.ltwbh.de` zeigt auf den Heimanschluss.
- Öffentliche Subdomains können per CNAME auf `home.ltwbh.de` zeigen.
- FRITZ!Box leitet TCP 80/443 auf den Proxmox/nginx-Host weiter.

## Aktuelles Let's-Encrypt-Zertifikat

Die manuell vorhandenen nginx-VHosts verwenden aktuell das gemeinsame Zertifikat:

```text
/etc/letsencrypt/live/ltwbh-services/fullchain.pem
/etc/letsencrypt/live/ltwbh-services/privkey.pem
```

Bekannter bisheriger SAN-Stand:

- `dash.ltwbh.de`
- `ha.ltwbh.de`
- `paper.ltwbh.de`
- `pdf.ltwbh.de`
- `vault.ltwbh.de`

Am 24.11.2026 war `up.ltwbh.de` bereits per DNS/nginx erreichbar, aber noch NICHT im Zertifikat enthalten. Fehler:

```text
curl: (60) SSL: no alternative certificate subject name matches target hostname 'up.ltwbh.de'
HTTP 000
```

Das ist ein Zertifikats-/SAN-Problem, kein Uptime-Kuma-Backendfehler.

## Sichere Reparatur für up.ltwbh.de

Bestehende SANs automatisch auslesen, `up.ltwbh.de` ergänzen und das Zertifikat `ltwbh-services` erweitern:

```bash
CERT="ltwbh-services"

mapfile -t DOMAINS < <(
  openssl x509     -in "/etc/letsencrypt/live/$CERT/fullchain.pem"     -noout -ext subjectAltName   | grep -oE 'DNS:[^, ]+'   | cut -d: -f2   | sort -u
)

ARGS=()
for d in "${DOMAINS[@]}" up.ltwbh.de; do
  ARGS+=( -d "$d" )
done

certbot certonly --nginx   --cert-name "$CERT"   --expand   "${ARGS[@]}"

nginx -t && systemctl reload nginx
```

Danach prüfen:

```bash
openssl x509   -in /etc/letsencrypt/live/ltwbh-services/fullchain.pem   -noout -ext subjectAltName

curl -sS -o /dev/null   -w "Uptime Kuma extern: HTTP %{http_code}\n"   https://up.ltwbh.de/
```

Erwartung: `up.ltwbh.de` steht in den SANs und curl liefert nicht mehr HTTP 000 wegen Zertifikatsprüfung.

Falls `certbot --nginx` meldet, dass das nginx-Plugin fehlt:

```bash
apt update
apt install -y python3-certbot-nginx
```

Danach denselben Certbot-Befehl erneut ausführen.

## Aktueller Status 24.11.2026 · Uptime-Kuma-TLS

Das Zertifikatsproblem für `https://up.ltwbh.de` ist behoben.

Installiert wurde auf dem Proxmox-Host:

```bash
apt install -y python3-certbot-nginx
```

Danach wurde das bestehende Zertifikat `ltwbh-services` erfolgreich erweitert. Certbot meldete:

```text
Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/ltwbh-services/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/ltwbh-services/privkey.pem
This certificate expires on 2027-02-22.
```

Aktueller SAN-Stand:

- `dash.ltwbh.de`
- `ha.ltwbh.de`
- `paper.ltwbh.de`
- `pdf.ltwbh.de`
- `up.ltwbh.de`
- `vault.ltwbh.de`

`nginx -t` war erfolgreich und nginx wurde neu geladen.

Damit ist der frühere Fehler

```text
SSL: no alternative certificate subject name matches target hostname 'up.ltwbh.de'
```

behoben.

Uptime-Kuma-Backend laut bestehender Installation:

```text
Proxmox/nginx 192.168.178.100:443
  -> CT 105 192.168.178.105:443
  -> Uptime Kuma 127.0.0.1:3001 im CT
```

Der nächste Prüfschritt betrifft nur noch Reverse Proxy / Backend-Antwort, falls der externe curl-Aufruf nicht sauber mit einem HTTP-Status endet.

Diagnose:

```bash
curl -vk --connect-timeout 5 --max-time 15 https://up.ltwbh.de/

curl -kI --connect-timeout 5 --max-time 15 https://192.168.178.105/

pct exec 105 -- bash -lc '
  echo "=== Listener ==="
  ss -lntp | grep -E ":(443|3001)\\b" || true
  echo
  echo "=== Kuma lokal ==="
  curl -sS -I --connect-timeout 3 --max-time 10 http://127.0.0.1:3001/ || true
'
```

## External-URL-Tool / wichtiger Migrationshinweis

Das aktuelle Repository-Tool `proxmox-external-urls` verwendet als eigenen Zertifikatsnamen:

```text
proxmox-external
```

Die bestehende produktive manuelle Installation verwendet dagegen noch:

```text
ltwbh-services
```

Nicht unüberlegt parallele nginx-VHosts mit denselben `server_name`-Werten erzeugen. Vor einer vollständigen Migration auf `proxmox-external` zuerst bestehende Dateien unter `/etc/nginx/sites-enabled/`, `/etc/nginx/conf.d/` und die aktiven Zertifikate prüfen.

Persistente External-URL-Dateien:

```text
/home/Data/proxmox-installer/external-urls/config.json
/home/Data/proxmox-installer/external-urls/dns-records.txt
/home/diagnose/external-urls/
/home/backups/external-urls/
```

CLI:

```bash
proxmox-external-urls --status
proxmox-external-urls --reapply
```

`--reapply` erst verwenden, wenn geklärt ist, dass keine doppelten nginx-VHosts zur bestehenden manuellen Konfiguration entstehen.

## Dashboard · V162

- Freigabestand mit allen V161-Funktionen: individuell konfigurierbare aktive/inaktive Browser-Tab-Titel und priorisierte Update-Hinweise.
- Logo wird bei unveränderten Einstellungen während der laufenden USV-Statusabfragen nicht erneut geladen; bewusste Branding-Aktualisierung bleibt möglich.
- V162 enthält die bisherigen Änderungen kumulativ; der bestehende automatische Update-Zeitplan und die Opt-in-Einstellungen bleiben unverändert.

## Dashboard · V161

- Browser-Tab-Anzeige in den Dashboard-Einstellungen getrennt für aktive und inaktive Tabs konfigurierbar.
- Standard: aktiv nur Name; inaktiv Name → CPU/RAM → Leistungsaufnahme. Wechsel alle 5 Sekunden, Update-Hinweise alle 3 Sekunden.
- Update-Hinweise haben optional Vorrang; Messwerte und Versionsstatus werden aus bestehenden Abfragen übernommen. Speicherung lokal pro Browser, ohne Änderungen an Logos oder Favicons.

## Dashboard · V160

- Zusammenführung der parallelen V159-Änderungen: `randMenuLogo`, mittiger Titel, Logo bis 350 × 60 px sowie zugängliche mobile Power-Icons.
- Branding-Script erhält eine stabile ID; alte Update-Marker bleiben kompatibel.
- Beide verpflichtenden CI-Prüfungen laufen bei jedem Pull Request auf main, auch bei reinen Dokumentationsänderungen.
- Lokale Logo- und Favicon-Dateien bleiben unverändert.

## Dashboard · V159

- Aktive Branding-IDs und CSS-Klassen ohne Versionssuffix; das Logo verwendet `randMenuLogo`.
- Konfigurierter Dashboard-Titel wird auf Desktop und Mobilgeräten mittig angezeigt.
- Manueller und automatischer Updatepfad verwenden dieselben Branding-Quellen; lokale Logos/Favicons bleiben unverändert.

## Dashboard · V154 Feinschliff

- Linker Hamburger-/Logo-Menübutton bleibt funktional identisch zu V153.
- Logo wird größer dargestellt.
- Sichtbarer Rahmen und permanenter Button-Hintergrund sind entfernt.
- Grundzustand transparent; nur dezenter Hover-/Focus-Effekt bleibt.
- Desktop: Logo bis ca. 230×38 px.
- Mobile/Tablet-Größen ebenfalls vergrößert.
- Logo/Favicon bleiben updategeschützt.

## Dashboard · V153 Toolbar

Produktives Soll-Layout:

```text
LINKS                     MITTE                       RECHTS
[ ☰ + Logo ]              [ LIVE ] [ USV Online ]   [ Neustart ] [ Herunterfahren ]
```

- Kein separater „Menü“-Button mehr.
- Hamburger und `logo.png` bilden zusammen einen Button.
- Dieser Button toggelt das Seitenmenü auf/zu.
- Bei leerem/transparentem Logo wird `logo_text` als Fallback angezeigt.
- Das Logo bleibt immer in der festen Toolbar sichtbar.
- Seitenmenü-Kopf und zusätzliches X sind ausgeblendet.
- SideNav/Overlay beginnen unterhalb der Toolbar, damit der Logo-Menübutton bedienbar bleibt.
- Frontend: `dashboard/branding-v153.css` und `dashboard/branding-v153.js`.

## Dashboard · V152 Updatepfad

Seit V152 wird ein bereits vollständiges Dashboard bei einem normalen Update nicht mehr auf die V139-Basis zurückgesetzt.

Erkennung:
- `prepare_dashboard_update_mode_v152`
- `dashboard_has_current_state_v152`
- `DASHBOARD_FAST_UPDATE_V152=1` bei vollständigem aktuellem Stand

Fast-Update:
- bestehende `app.py`, `index.html`, `collector.py` bleiben erhalten,
- historische Patches V42–V81 werden übersprungen,
- aktuelle Branding-/Konfigurations-/TLS-/Link-/Validierungslogik läuft weiter,
- Logo/Favicon bleiben geschützt.

Bootstrap:
- nur bei Erstinstallation,
- bewusstem Dashboard-Neuaufbau,
- oder wenn Pflichtmarker eines aktuellen Dashboards fehlen.

## Dashboard · V151 generisch / Update-Schutz

V151 ersetzt das persönliche V150-Branding durch eine vollständig generische Lösung.

### Serverpfade

```text
/opt/dashboard/static/assets/logo.png
/opt/dashboard/static/assets/favicon.png
```

### Repository

```text
dashboard/branding-v151.css
dashboard/branding-v151.js
dashboard/assets/logo.png
dashboard/assets/favicon.png
```

Die beiden Repository-PNGs sind neutrale, vollständig transparente Platzhalter.

### Harte Update-Regel

Bei einem normalen Dashboard-Update dürfen `logo.png` und `favicon.png` niemals:

- aus GitHub neu geladen,
- überschrieben,
- ersetzt,
- gelöscht,
- auf Standard zurückgesetzt werden.

Nur CSS/JavaScript des Brandings wird aktualisiert.

Erst-/Neuinstallationen legen die neutralen Platzhalter ausschließlich an, wenn die jeweilige Zieldatei fehlt.

### Migration V150 → V151

Falls auf einer bestehenden Installation noch Legacy-Dateien mit alten persönlichen Namen vorhanden sind und die generischen Dateien fehlen, werden die vorhandenen Bildbytes einmalig auf `logo.png` bzw. `favicon.png` kopiert. Es findet kein Bildaustausch statt.

### Branding-Einstellungen

Normales Update:
- vorhandener Webseitenname bleibt erhalten,
- vorhandener Logo-Text bleibt erhalten,
- vorhandener Logo-Stil bleibt erhalten,
- vorhandenes Custom-Favicon / `favicon_url` bleibt erhalten,
- keine Branding-Rückfragen.

Erst-/Neuinstallation:
- Webseitenname wird abgefragt,
- Fallback-Logo-Text wird abgefragt,
- Fallback-Stil wird abgefragt.

Generische Defaults:

```text
PVE Hardware Monitor
PROXMOX
neon
```

Ist `logo.png` leer/transparent oder nicht vorhanden, zeigt das Menü automatisch den Text-Fallback.

Die obere Bedienleiste bleibt sticky:

- Menü
- LIVE
- USV Online
- Neustart
- Herunterfahren

Dashboard-Ansichten:
- Boot Sequence
- Live Pulse
- Telemetry Flow
- Glass Motion
- Status Control

Tool:

```text
/usr/local/sbin/proxmox-dashboard-views
```

### Dokumentation

Aktuelle Bedien-/Installationsdokumentation:

```text
README.md
proxmox/README.md
```

Vollständige nachvollziehbare History:

```text
proxmox/HISTORY.md
proxmox/history.txt
```

Neue Versionen müssen immer oben dokumentiert werden.

## Grundregeln für weitere Änderungen

1. Vor Änderungen an nginx immer `nginx -t`.
2. Vor Ersetzen produktiver Dateien Backup anlegen.
3. Keine Secrets in GitHub committen.
4. Bestehende produktive Namen und Pfade beibehalten.
5. GitHub-`main` ist die kanonische Quelle des Installers.
6. Neue Änderungen mit `bash -n` bzw. passenden Syntax-/CI-Tests prüfen.
7. Bei externen URLs DNS, Zertifikat, nginx-VHost und Backend getrennt testen.
8. Proxmox selbst bleibt nativ auf Port 8006 und soll nicht unnötig extern publiziert werden.

## Startprompt für einen neuen Chat

Kopiere ab hier in einen neuen Chat:

```text
Wir arbeiten am Proxmox-Projekt im GitHub-Repository Technox90/homeatic auf Branch main.

Bitte lies zuerst pro­xmox/CHATGPT-HANDOFF.md und verwende diese Datei als aktuellen technischen Stand. Prüfe danach den aktuellen Stand von pro­xmox/proxmox.sh, pro­xmox/history.txt, pro­xmox/README.md und bei Bedarf pro­xmox/tools/proxmox-external-urls.

Wichtig:
- Produktive Namen und Pfade nicht eigenmächtig ändern.
- Keine Secrets ins Repository schreiben.
- Änderungen zuerst technisch prüfen und anschließend sauber in GitHub dokumentieren.
- nginx-Konfiguration nur so ändern, dass bestehende funktionierende Dienste nicht kaputtgehen.
- Aktuelle Hauptdomain ist ltwbh.de.
- Uptime Kuma soll extern über https://up.ltwbh.de erreichbar sein.
- Das produktive Sammelzertifikat heißt derzeit ltwbh-services.
- Dashboard V151 ist generisch; eigene Bilder liegen nur lokal als logo.png/favicon.png und werden bei Updates niemals überschrieben.
- Erst-/Neuinstallationen erhalten nur bei fehlenden Dateien neutrale transparente Platzhalter.
- Die obere Leiste bleibt sticky: Menü · LIVE · USV Online · Neustart · Herunterfahren.

Setze die Arbeit auf Basis des aktuellen GitHub-Stands fort.
```

## V163 · UPPER

- UPPER: eigenständige Statusseite unter `/upper/`, Dateien in `/var/www/upper/`, Logo/Favicon bleiben bei Updates erhalten; Copyright und GitHub-Link, interaktive Ping-Diagramme mit Maus, Touch und Tastatur.
- Originale Kuma-Statusseiten bleiben unverändert. Opt-in-Updates migrieren alte Installationen; Nginx-Prüfung mit Rücksicherung.
- Dashboard: SVG-Symbole für Neustart und Herunterfahren. Uptime Kuma: Datenbank-Besitzrechte nicht rekursiv zurücksetzen, Health- und HTTP-Prüfung nach Updates.

## V164

- Dashboard unter `/opt/dashboard/`; persönliche Dateien bleiben unter `static/assets/` erhalten.
- Neutrale Proxmox-Werkzeuge und lokale CA-Dateinamen; UPPER bleibt unabhängig unter `/var/www/upper/`.
- Boot-Animation übernimmt exakt den gespeicherten Dashboard-Namen, ohne zusätzliches Präfix.
- Bestehende Installationen erfordern eine einmalige, gesicherte Layout-Migration. Bestehende CA-Schlüssel, Zertifikate, Datenbanken und Gastdaten bleiben erhalten.

Für bestehende Hosts zuerst die dokumentierte Layout-Migration ausführen. Zertifikatsnamen des Bestands nicht ändern.

## V165

- Ladeanimation: führendes Wort „Dashboard“ wird ausschließlich im Ladebildschirm entfernt (z. B. `Dashboard LT-WBH` → `LT-WBH`). Gespeicherter Name, Seitentitel, Tab-Titel und Branding bleiben unverändert.

## V166

- Ausschließlich lokale Host-Leistungsdaten: IPMI/DCMI hat Vorrang; andernfalls CPU-Package (oder vorhandener CPU-Teilbereich) plus separater Intel-RAPL-DRAM-Wert. Cores/Uncore nicht doppelt zählen. GPU separat ausweisen, wenn ihre Unabhängigkeit vom CPU-Messbereich nicht nachgewiesen ist; ohne CPU/DRAM kann GPU als Teilleistung angezeigt werden.
- Teilleistung wird in Kachel und Browser-Tab ausdrücklich gekennzeichnet. Fehlende Werte werden nicht geschätzt. Keine Smart-Home-, MQTT- oder externen Strommesser; USV/Pi-hole bleiben getrennt.

## V167

- Netzwerk- und Datenträger-Übertragungsraten in dezimalen B/s, kB/s, MB/s, GB/s bzw. TB/s (Faktor 1000), einschließlich Diagrammachsen. Automatische Skalierung; Rohdaten, Speichergrößen und RAM-Einheiten unverändert.

## V168

- Browser-Tab: Leistungsanzeige einheitlich als `Leistung 19,60 W` statt `Teil 19,60 W`; Messwertberechnung und Kennzeichnung der Teilleistung im Dashboard bleiben unverändert.

## V169

- Seitenmenü: Nur die Diensteliste mit Kategorien scrollt. Einstellungen und GitHub bleiben mit einer durchgehenden Trennlinie am unteren Rand sichtbar, auf Desktop und Mobilgeräten. Bestehende Links und Kategorien bleiben unverändert.
