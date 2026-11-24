# ChatGPT-Handoff · Proxmox / NodeZero

Stand: 24.11.2026

Diese Datei dient als Übergabe für einen neuen Chat. Keine Passwörter, Tokens oder sonstige Secrets hier eintragen.

## Repository

- Repository: `Technox90/homeatic`
- Branch: `main`
- Master-Installer: `proxmox/proxmox.sh`
- Aktueller Installationskandidat: V149
- External-URL-Tool: `proxmox/tools/nodezero-external-urls`
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

## External-URL-Tool / wichtiger Migrationshinweis

Das aktuelle Repository-Tool `nodezero-external-urls` verwendet als eigenen Zertifikatsnamen:

```text
nodezero-external
```

Die bestehende produktive manuelle Installation verwendet dagegen noch:

```text
ltwbh-services
```

Nicht unüberlegt parallele nginx-VHosts mit denselben `server_name`-Werten erzeugen. Vor einer vollständigen Migration auf `nodezero-external` zuerst bestehende Dateien unter `/etc/nginx/sites-enabled/`, `/etc/nginx/conf.d/` und die aktiven Zertifikate prüfen.

Persistente External-URL-Dateien:

```text
/home/Data/proxmox-installer/external-urls/config.json
/home/Data/proxmox-installer/external-urls/dns-records.txt
/home/diagnose/external-urls/
/home/backups/external-urls/
```

CLI:

```bash
nodezero-external-urls --status
nodezero-external-urls --reapply
```

`--reapply` erst verwenden, wenn geklärt ist, dass keine doppelten nginx-VHosts zur bestehenden manuellen Konfiguration entstehen.

## Dashboard

Gewünschter Name:

```text
Dashboard LT-WBH
```

Obere Menüzeile soll dauerhaft/sticky oben bleiben:
- Menü
- Live
- USV Online
- Neustart
- Herunterfahren

Zusätzlich gewünscht:
- futuristisches Logo
- futuristisches Favicon
- bestehende Dashboard-Funktionen und Messdaten erhalten
- produktive Namen/Pfade nicht unnötig verändern

Dashboard-Ansichten:
- Boot Sequence
- Live Pulse
- Telemetry Flow
- Glass Motion
- Status Control

Tool:
`/usr/local/sbin/nodezero-dashboard-views`

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
Wir arbeiten am Proxmox-/NodeZero-Projekt im GitHub-Repository Technox90/homeatic auf Branch main.

Bitte lies zuerst pro­xmox/CHATGPT-HANDOFF.md und verwende diese Datei als aktuellen technischen Stand. Prüfe danach den aktuellen Stand von pro­xmox/proxmox.sh, pro­xmox/history.txt, pro­xmox/README.md und bei Bedarf pro­xmox/tools/nodezero-external-urls.

Wichtig:
- Produktive Namen und Pfade nicht eigenmächtig ändern.
- Keine Secrets ins Repository schreiben.
- Änderungen zuerst technisch prüfen und anschließend sauber in GitHub dokumentieren.
- nginx-Konfiguration nur so ändern, dass bestehende funktionierende Dienste nicht kaputtgehen.
- Aktuelle Hauptdomain ist ltwbh.de.
- Uptime Kuma soll extern über https://up.ltwbh.de erreichbar sein.
- Das produktive Sammelzertifikat heißt derzeit ltwbh-services.
- Dashboard soll "Dashboard LT-WBH" heißen und die obere Menüleiste sticky behalten.

Setze die Arbeit auf Basis des aktuellen GitHub-Stands fort.
```
