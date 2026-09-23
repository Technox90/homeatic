#!/usr/bin/env bash
# =============================================================================
# NODEZERO DASHBOARD-MODUL · V140
# =============================================================================
# Dieses Modul wird von proxmox/proxmox.sh versionsgebunden aus GitHub geladen.
# Es enthält die vollständige Dashboard-Installations-, Patch-, Settings-,
# Kategorie-, USV-, Pi-hole- und Layout-Logik, die bis V139 direkt im
# Hauptinstaller eingebettet war.
#
# WICHTIG:
# - Das Modul wird mit "source" geladen und teilt deshalb bewusst den globalen
#   Kontext des Master-Installers (header, ok, warn, die, TLS-Helfer usw.).
# - Keine eigenen set -e/set -u Optionen hier setzen.
# =============================================================================

dashboard_link_upsert() {
    local name="$1"
    local url="$2"

    command -v pve-dashboard-link >/dev/null 2>&1 || return 0

    local tmp
    tmp="$(mktemp)"
    printf '%s|%s|new\n' "$name" "$url" > "$tmp"
    pve-dashboard-link import "$tmp" >/dev/null 2>&1 || true
    rm -f "$tmp"
}

# -----------------------------------------------------------------------------
# V134 · VORHANDENE INSTALLER-WEB-CTs MIT DASHBOARD-LINKS ABGLEICHEN
# -----------------------------------------------------------------------------
# Ein reines Dashboard-Update setzt die INSTALL_* Flags bestehender Dienste
# nicht. V134 erkennt bekannte vorhandene LXC am Hostnamen und ergänzt nur
# fehlende Dashboard-Links. Vorhandene/manuelle Links bleiben unverändert.

dashboard_existing_ct_ipv4_v134() {
    local ctid="$1"
    local ip=""

    if pct status "$ctid" 2>/dev/null | grep -q 'status: running'; then
        ip="$(
            pct exec "$ctid" -- hostname -I 2>/dev/null |
            tr ' ' '\n' |
            grep -E '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)' |
            head -n1 || true
        )"
    fi

    if [[ -z "$ip" ]]; then
        ip="$(
            pct config "$ctid" 2>/dev/null |
            sed -n 's/^net[0-9][0-9]*:.*[, ]ip=\([^,]*\).*/\1/p' |
            cut -d/ -f1 |
            grep -E '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)' |
            head -n1 || true
        )"
    fi

    [[ -n "$ip" ]] || return 1
    printf '%s\n' "$ip"
}

dashboard_reconcile_existing_guests_v134() {
    [[ -f /var/lib/pve-sensor-dashboard-web/links.json ]] || return 0
    command -v pct >/dev/null 2>&1 || return 0

    local ctid=""
    local hostname=""
    local hostkey=""
    local ip=""
    local name=""
    local url=""
    local tmp=""

    tmp="$(mktemp /tmp/pve-dashboard-existing-guests-v134.XXXXXX)"
    : > "$tmp"

    while read -r ctid; do
        [[ "$ctid" =~ ^[0-9]+$ ]] || continue

        hostname="$(
            pct config "$ctid" 2>/dev/null |
            awk -F': ' '/^hostname:/ {print $2; exit}'
        )"

        [[ -n "$hostname" ]] || continue

        hostkey="$(
            printf '%s' "$hostname" |
            tr '[:upper:]_' '[:lower:]-'
        )"

        ip="$(dashboard_existing_ct_ipv4_v134 "$ctid" || true)"
        [[ -n "$ip" ]] || continue

        name=""
        url=""

        case "$hostkey" in
            paperless|paperless-ngx)
                name="Paperless"
                url="https://${ip}/"
                ;;
            pihole|pi-hole)
                name="Pi-hole"
                url="http://${ip}/admin/"
                ;;
            netalertx|netalert)
                name="NetAlertX"
                url="http://${ip}/"
                ;;
            uptime-kuma|uptime)
                name="Uptime Kuma"
                url="https://${ip}/"
                ;;
            vaultwarden)
                name="Vaultwarden"
                url="https://${ip}/"
                ;;
            caddy)
                name="Caddy Reverse Proxy"
                url="http://${ip}/"
                ;;
            stirling-pdf|stirlingpdf|stirling)
                name="Stirling PDF"
                url="https://${ip}/"
                ;;
            ntfy)
                name="ntfy"
                url="https://${ip}/"
                ;;
            forgejo)
                name="Forgejo"
                url="https://${ip}/"
                ;;
            syncthing)
                name="Syncthing"
                url="https://${ip}/"
                ;;
            speedtest-tracker|speedtest)
                name="Speedtest Tracker"
                url="https://${ip}/"
                ;;
            scrutiny)
                name="Scrutiny"
                url="https://${ip}/"
                ;;
            mealie)
                name="Mealie"
                url="https://${ip}/"
                ;;
            proxmox-backup-server|pbs)
                name="Proxmox Backup Server"
                url="https://${ip}:8007/"
                ;;
            pulse)
                name="Pulse"
                url="https://${ip}/"
                ;;
            pve-ups|pveups)
                name="PVE-UPS"
                url="https://${ip}/"
                ;;
            semaphore)
                name="Semaphore"
                url="https://${ip}/"
                ;;
            pocketid|pocket-id)
                name="Pocket ID"
                url="https://${ip}/"
                ;;
            prometheus)
                name="Prometheus"
                url="https://${ip}/"
                ;;
            pve-exporter|prometheus-pve-exporter)
                name="Prometheus PVE Exporter"
                url="https://${ip}/"
                ;;
            grafana)
                name="Grafana"
                url="https://${ip}/"
                ;;
            pangolin)
                name="Pangolin"
                url="http://${ip}:3002/"
                ;;
            gatus)
                name="Gatus"
                url="https://${ip}/"
                ;;
            homepage)
                name="Homepage"
                url="https://${ip}/"
                ;;
            nginx-proxy-manager|nginxproxymanager|npm)
                name="Nginx Proxy Manager"
                url="http://${ip}:81/"
                ;;
            emqx)
                name="EMQX MQTT"
                url="https://${ip}/"
                ;;
            *)
                continue
                ;;
        esac

        printf '%s\t%s\t%s\t%s\n' \
            "$ctid" "$hostname" "$name" "$url" >> "$tmp"

    done < <(pct list 2>/dev/null | awk 'NR>1 {print $1}')

    python3 - \
        /var/lib/pve-sensor-dashboard-web/links.json \
        "$tmp" <<'PYV134LINKS'
from pathlib import Path
import json
import re
import sys

links_path = Path(sys.argv[1])
discovered_path = Path(sys.argv[2])

try:
    links = json.loads(
        links_path.read_text(encoding="utf-8")
    )
except Exception:
    links = []

if not isinstance(links, list):
    links = []

existing_names = {
    str(item.get("name", "")).strip().casefold()
    for item in links
    if isinstance(item, dict)
    and str(item.get("name", "")).strip()
}

existing_ids = {
    str(item.get("id", "")).strip()
    for item in links
    if isinstance(item, dict)
    and str(item.get("id", "")).strip()
}

added = []

for raw in discovered_path.read_text(
    encoding="utf-8"
).splitlines():
    parts = raw.split("\t", 3)

    if len(parts) != 4:
        continue

    ctid, hostname, name, url = [
        value.strip()
        for value in parts
    ]

    if not name or not url:
        continue

    if name.casefold() in existing_names:
        continue

    base = re.sub(
        r"[^a-z0-9]+",
        "-",
        hostname.casefold(),
    ).strip("-") or f"ct-{ctid}"

    link_id = f"auto-{base}"

    if link_id in existing_ids:
        link_id = f"{link_id}-{ctid or 'ct'}"

    links.append({
        "id": link_id,
        "type": "link",
        "name": name,
        "url": url,
        "target": "new",
        "group": "",
    })

    existing_names.add(name.casefold())
    existing_ids.add(link_id)
    added.append((ctid, name, url))

if added:
    temp = links_path.with_suffix(".json.v134.tmp")
    temp.write_text(
        json.dumps(
            links,
            ensure_ascii=False,
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )
    temp.chmod(0o600)
    temp.replace(links_path)

print(
    f"[OK] Dashboard CT-Abgleich V134: "
    f"{len(added)} fehlende Link(s) ergänzt."
)

for ctid, name, url in added:
    print(f"  CT {ctid}: {name} -> {url}")
PYV134LINKS

    rm -f "$tmp"

    chown pve-monitor:pve-monitor \
        /var/lib/pve-sensor-dashboard-web/links.json \
        2>/dev/null || true
    chmod 600 \
        /var/lib/pve-sensor-dashboard-web/links.json \
        2>/dev/null || true
}

# =============================================================================
# DASHBOARD
# =============================================================================

# V139: Die großen Dashboard-Quellen liegen als echte Dateien im Repository.
# Der Ref zeigt auf den unveränderlichen Commit, in dem die V139-Basisdateien
# abgelegt wurden. Dadurch kann ein späteres main-Update keinen alten Installer
# mit inkompatiblen Dashboard-Dateien mischen.
NODEZERO_DASHBOARD_ASSET_REF="f1005bd0a8d385b791d0a4d25cf1ab2dc67198d2"
NODEZERO_DASHBOARD_RAW_BASE="https://raw.githubusercontent.com/Technox90/homeatic/${NODEZERO_DASHBOARD_ASSET_REF}/dashboard"

download_dashboard_asset_v139() {
    local name="$1"
    local target="$2"
    local url="${NODEZERO_DASHBOARD_RAW_BASE}/${name}"
    local tmp="${target}.tmp"

    if [[ -s "$target" ]]; then
        return 0
    fi

    mkdir -p "$(dirname "$target")"
    rm -f "$tmp"

    curl --fail --silent --show-error --location \
        --retry 3 --retry-delay 2 --connect-timeout 15 \
        "$url" -o "$tmp" ||
        die "Dashboard-Datei konnte nicht geladen werden: $url"

    [[ -s "$tmp" ]] || die "Dashboard-Datei ist leer: $url"
    mv -f "$tmp" "$target"
}

install_nodezero_dashboard_sources_v139() {
    local app_dir="$1"
    local static_dir="$2"
    local cache_dir="${NODEZERO_DOWNLOAD_DIR}/dashboard/${NODEZERO_DASHBOARD_ASSET_REF}"

    mkdir -p "$cache_dir" "$app_dir" "$static_dir"
    chmod 700 "$NODEZERO_DOWNLOAD_DIR"
    chmod 755 "$cache_dir"

    download_dashboard_asset_v139 "collector.py" "$cache_dir/collector.py"
    download_dashboard_asset_v139 "app.py" "$cache_dir/app.py"
    download_dashboard_asset_v139 "index.html" "$cache_dir/index.html"

    install -m 0644 -o root -g root "$cache_dir/collector.py" "$app_dir/collector.py"
    install -m 0644 -o root -g root "$cache_dir/app.py" "$app_dir/app.py"
    install -m 0644 -o root -g root "$cache_dir/index.html" "$static_dir/index.html"

    ok "Dashboard-Quellen aus GitHub/Download-Cache installiert."
    info "Cache: $cache_dir"
}

install_dashboard() {
    header "SERVER-DASHBOARD INSTALLIEREN / AKTUALISIEREN"

    local APP_DIR="/opt/nodezero/dashboard"
    local DATA_DIR="/var/lib/pve-sensor-dashboard"
    local STATIC_DIR="${APP_DIR}/static"
    local CONTROL_DIR="/etc/pve-sensor-dashboard"
    local CONTROL_HASH="${CONTROL_DIR}/control.hash"
    local WEB_DATA_DIR="/var/lib/pve-sensor-dashboard-web"
    local APP_PORT="9105"
    local POWER_HELPER="/usr/local/sbin/pve-sensor-powerctl"
    local SUDOERS_FILE="/etc/sudoers.d/pve-sensor-dashboard"

    apt-get update
    apt-get install -y \
        nginx \
        python3 \
        python3-flask \
        python3-psutil \
        gunicorn \
        lm-sensors \
        smartmontools \
        nvme-cli \
        pciutils \
        util-linux \
        curl \
        sudo \
        ipmitool

    # Sensor-Treiber nur laden, wenn vom Kernel unterstützt.
    for module in coretemp intel_rapl_common intel_rapl_msr drivetemp nct6775; do
        if modinfo "$module" >/dev/null 2>&1; then
            modprobe "$module" 2>/dev/null || true
        fi
    done

    cat > /etc/modules-load.d/pve-sensor-dashboard.conf <<'EOF'
coretemp
intel_rapl_common
intel_rapl_msr
drivetemp
EOF

    # Bestehendes Dashboard IMMER zuerst sichern, bevor Update/Reset beginnt.
    if [[ -d "$APP_DIR" || -d "$DATA_DIR" ||
          -f "$CONTROL_HASH" ||
          -d /var/lib/pve-sensor-dashboard-web ]]; then

        local backup="/root/backups/pve-sensor-dashboard-backup-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$backup"

        [[ -d "$APP_DIR" ]] && cp -a "$APP_DIR" "$backup/app" 2>/dev/null || true
        [[ -d "$DATA_DIR" ]] && cp -a "$DATA_DIR" "$backup/data" 2>/dev/null || true
        [[ -f "$CONTROL_HASH" ]] && cp -a "$CONTROL_HASH" "$backup/control.hash" 2>/dev/null || true
        [[ -d /var/lib/pve-sensor-dashboard-web ]] && \
            cp -a /var/lib/pve-sensor-dashboard-web "$backup/web-data" 2>/dev/null || true
        [[ -f /etc/systemd/system/pve-sensor-web.service ]] && \
            cp -a /etc/systemd/system/pve-sensor-web.service "$backup/" 2>/dev/null || true
        [[ -f /etc/systemd/system/pve-sensor-collector.service ]] && \
            cp -a /etc/systemd/system/pve-sensor-collector.service "$backup/" 2>/dev/null || true
        [[ -f /etc/systemd/system/pve-sensor-collector.timer ]] && \
            cp -a /etc/systemd/system/pve-sensor-collector.timer "$backup/" 2>/dev/null || true

        ok "Dashboard-Backup erstellt: $backup"
    fi

    if (( RESET_DASHBOARD_DATA )); then
        echo "Dashboard komplett zurücksetzen ..."
        systemctl stop pve-sensor-collector.timer 2>/dev/null || true
        systemctl stop pve-sensor-web.service 2>/dev/null || true

        rm -rf "$APP_DIR"
        rm -rf "$DATA_DIR"
        rm -rf /var/lib/pve-sensor-dashboard-web
        rm -f "$CONTROL_HASH"

    elif (( RESET_DASHBOARD_APP_ONLY )); then
        echo "Dashboard-Programmdateien neu aufbauen ..."
        systemctl stop pve-sensor-collector.timer 2>/dev/null || true
        systemctl stop pve-sensor-web.service 2>/dev/null || true

        # Messdaten, Links und Steuer-Code bleiben bewusst bestehen.
        rm -rf "$APP_DIR"
    fi

    # V124: WEB_DATA_DIR muss bereits VOR dem Start von pve-sensor-web
    # existieren. Ein vorhandenes systemd-Drop-in verwendet diesen Pfad als
    # ReadWritePaths; fehlt er, bricht systemd mit status=226/NAMESPACE ab.
    mkdir -p "$APP_DIR" "$DATA_DIR" "$STATIC_DIR" "$CONTROL_DIR" "$WEB_DATA_DIR"

    if ! id -u pve-monitor >/dev/null 2>&1; then
        useradd --system --home-dir "$APP_DIR" --shell /usr/sbin/nologin pve-monitor
    fi

    chown root:pve-monitor "$DATA_DIR" "$CONTROL_DIR"
    chmod 750 "$DATA_DIR" "$CONTROL_DIR"

    chown pve-monitor:pve-monitor "$WEB_DATA_DIR"
    chmod 700 "$WEB_DATA_DIR"

    # -------------------------------------------------------------------------
    # Collector
    # -------------------------------------------------------------------------

    install_nodezero_dashboard_sources_v139 "$APP_DIR" "$STATIC_DIR"

    # -------------------------------------------------------------------------
    # Flask App
    # -------------------------------------------------------------------------

    # V139: app.py wurde zusammen mit collector.py aus dem Repository installiert.

    # -------------------------------------------------------------------------
    # Frontend
    # -------------------------------------------------------------------------

    # V139: index.html wurde zusammen mit den Python-Quellen installiert.

    # -------------------------------------------------------------------------
    # Steuer-Code / Power Helper
    # -------------------------------------------------------------------------

    if [[ -n "$CONTROL_CODE" || ! -f "$CONTROL_HASH" ]]; then
        [[ -n "$CONTROL_CODE" ]] || die "Kein Steuer-Code vorhanden."

        CONTROL_CODE_ENV="$CONTROL_CODE" python3 <<'PYHASH' > "$CONTROL_HASH"
import os
from werkzeug.security import generate_password_hash
print(generate_password_hash(os.environ["CONTROL_CODE_ENV"], method="scrypt"))
PYHASH

        chown root:pve-monitor "$CONTROL_HASH"
        chmod 640 "$CONTROL_HASH"
        CONTROL_CODE=""
    else
        chown root:pve-monitor "$CONTROL_HASH"
        chmod 640 "$CONTROL_HASH"
    fi

    cat > "$POWER_HELPER" <<'POWERHELPER'
#!/usr/bin/env bash
set -Eeuo pipefail

case "${1:-}" in
    reboot)
        exec /usr/bin/systemd-run \
            --quiet \
            --unit="pve-dashboard-reboot-$(date +%s)" \
            --on-active=3s \
            /usr/bin/systemctl reboot
        ;;
    poweroff)
        exec /usr/bin/systemd-run \
            --quiet \
            --unit="pve-dashboard-poweroff-$(date +%s)" \
            --on-active=3s \
            /usr/bin/systemctl poweroff
        ;;
    *)
        echo "Ungültige Aktion." >&2
        exit 2
        ;;
esac
POWERHELPER

    chown root:root "$POWER_HELPER"
    chmod 755 "$POWER_HELPER"

    cat > "$SUDOERS_FILE" <<EOF
pve-monitor ALL=(root) NOPASSWD: ${POWER_HELPER} reboot, ${POWER_HELPER} poweroff
EOF
    chmod 440 "$SUDOERS_FILE"
    visudo -cf "$SUDOERS_FILE" >/dev/null || die "sudoers-Konfiguration ungültig."

    # Komfortbefehl: Code ohne alten Code neu setzen (nur root).
    cat > /usr/local/sbin/pve-dashboard-set-code <<'RESETPASS'
#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || {
    echo "Als root ausführen."
    exit 1
}

HASH="/etc/pve-sensor-dashboard/control.hash"

while true; do
    read -rsp "Neuen Steuer-Code (mindestens 6 Zeichen): " A
    echo
    [[ ${#A} -ge 6 ]] || {
        echo "Mindestens 6 Zeichen."
        continue
    }

    read -rsp "Neuen Steuer-Code wiederholen: " B
    echo

    [[ "$A" == "$B" ]] || {
        echo "Eingaben stimmen nicht überein."
        continue
    }

    break
done

[[ -f "$HASH" ]] && cp -a "$HASH" "${HASH}.backup-$(date +%Y%m%d-%H%M%S)"

CODE="$A" python3 <<'PY' > "${HASH}.new"
import os
from werkzeug.security import generate_password_hash
print(generate_password_hash(os.environ["CODE"], method="scrypt"))
PY

mv -f "${HASH}.new" "$HASH"
chown root:pve-monitor "$HASH"
chmod 640 "$HASH"

unset A B
echo "Steuer-Code erfolgreich geändert."
RESETPASS

    chmod 700 /usr/local/sbin/pve-dashboard-set-code

    # -------------------------------------------------------------------------
    # systemd
    # -------------------------------------------------------------------------

    cat > /etc/systemd/system/pve-sensor-collector.service <<EOF
[Unit]
Description=PVE Hardware Sensor Collector
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/python3 ${APP_DIR}/collector.py
Environment=PVE_MONITOR_RETENTION_DAYS=35
EOF

    cat > /etc/systemd/system/pve-sensor-collector.timer <<'EOF'
[Unit]
Description=PVE Hardware Sensor Collector Timer

[Timer]
OnBootSec=10s
OnUnitActiveSec=15s
AccuracySec=1s
Persistent=true

[Install]
WantedBy=timers.target
EOF

    cat > /etc/systemd/system/pve-sensor-web.service <<EOF
[Unit]
Description=PVE Hardware Monitor Web API
After=network-online.target
Wants=network-online.target

[Service]
User=pve-monitor
Group=pve-monitor
WorkingDirectory=${APP_DIR}
ExecStart=/usr/bin/gunicorn --workers 1 --threads 4 --bind 127.0.0.1:${APP_PORT} --access-logfile - --error-logfile - app:app
Restart=always
RestartSec=2
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
ReadOnlyPaths=${APP_DIR} ${DATA_DIR} ${CONTROL_DIR}

[Install]
WantedBy=multi-user.target
EOF

    # -------------------------------------------------------------------------
    # Nginx
    # -------------------------------------------------------------------------

    if ss -ltnp 2>/dev/null | grep -Eq ":${DASHBOARD_PORT}[[:space:]]" &&
       ! ss -ltnp 2>/dev/null | grep -E ":${DASHBOARD_PORT}[[:space:]].*nginx" >/dev/null; then
        die "Port ${DASHBOARD_PORT} ist bereits von einem anderen Dienst belegt."
    fi

    rm -f /etc/nginx/sites-enabled/default

    cat > /etc/nginx/sites-available/pve-sensor-dashboard <<EOF
server {
    listen ${DASHBOARD_PORT};
    server_name ${DASHBOARD_IP} _;

    access_log /var/log/nginx/pve-sensor-dashboard.access.log;
    error_log  /var/log/nginx/pve-sensor-dashboard.error.log;

    location / {
        proxy_pass http://127.0.0.1:${APP_PORT};
        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

        proxy_connect_timeout 5s;
        proxy_read_timeout 30s;
    }
}
EOF

    ln -sfn \
        /etc/nginx/sites-available/pve-sensor-dashboard \
        /etc/nginx/sites-enabled/pve-sensor-dashboard

    nginx -t

    # -------------------------------------------------------------------------
    # Rechte / Migration / Start
    # -------------------------------------------------------------------------

    chown -R root:root "$APP_DIR"
    chmod 755 "$APP_DIR" "$STATIC_DIR"
    chmod 644 "$APP_DIR/collector.py" "$APP_DIR/app.py" "$STATIC_DIR/index.html"

    # Kompatibilität für ältere Hilfsskripte/Pfade.
    if [[ ! -e /opt/pve-sensor-dashboard ]]; then
        ln -s "$APP_DIR" /opt/pve-sensor-dashboard
    fi

    python3 -m py_compile "$APP_DIR/collector.py" "$APP_DIR/app.py"

    # Vorhandene WAL-Dateien sauber migrieren.
    systemctl stop pve-sensor-collector.timer 2>/dev/null || true
    systemctl stop pve-sensor-web.service 2>/dev/null || true

    if [[ -f "$DATA_DIR/metrics.db" ]]; then
        DB_PATH="$DATA_DIR/metrics.db" python3 <<'PYDB'
import os
import sqlite3
db=os.environ["DB_PATH"]
con=sqlite3.connect(db,timeout=30)
try:
    try:
        con.execute("PRAGMA wal_checkpoint(TRUNCATE)")
    except Exception:
        pass
    con.execute("PRAGMA journal_mode=DELETE")
    con.commit()
finally:
    con.close()
PYDB
        rm -f "$DATA_DIR/metrics.db-wal" "$DATA_DIR/metrics.db-shm"
    fi

    # Erste Messung legt DB an bzw. migriert zusätzliche Spalten.
    /usr/bin/python3 "$APP_DIR/collector.py"

    chown root:pve-monitor "$DATA_DIR"
    chmod 750 "$DATA_DIR"

    [[ -f "$DATA_DIR/metrics.db" ]] && {
        chown root:pve-monitor "$DATA_DIR/metrics.db"
        chmod 640 "$DATA_DIR/metrics.db"
    }

    systemctl daemon-reload
    systemctl enable --now pve-sensor-collector.timer
    systemctl enable --now pve-sensor-web.service
    systemctl enable --now nginx
    systemctl restart nginx

    # V123: Gunicorn kann bei einem frischen Start etwas länger benötigen.
    # /api/info ist DB-unabhängig und eignet sich deshalb als echter
    # Prozess-/HTTP-Readiness-Test. Erst danach werden Messdaten geprüft.
    local dashboard_api_ready=0
    local dashboard_api_try=0

    echo
    echo "Dashboard API-Starttest:"

    for dashboard_api_try in {1..30}; do
        if curl -fsS --max-time 2 \
            "http://127.0.0.1:${APP_PORT}/api/info" \
            >/dev/null 2>&1; then
            dashboard_api_ready=1
            break
        fi

        sleep 1
    done

    if (( dashboard_api_ready == 0 )); then
        warn "Dashboard-Webdienst ist auf Port ${APP_PORT} nicht erreichbar."
        echo
        echo "----- systemctl status pve-sensor-web.service -----"
        systemctl status pve-sensor-web.service --no-pager -l || true
        echo
        echo "----- journalctl pve-sensor-web.service -----"
        journalctl -u pve-sensor-web.service -n 80 --no-pager || true
        echo
        echo "----- Listener Port ${APP_PORT} -----"
        ss -lntp 2>/dev/null | grep -E ":${APP_PORT}([[:space:]]|$)" || true
        die "Dashboard-Webdienst konnte innerhalb von 30 Sekunden nicht gestartet werden."
    fi

    ok "Dashboard-Webdienst antwortet auf 127.0.0.1:${APP_PORT}."

    echo
    echo "Dashboard Messdaten-Test:"
    if curl -fsS --max-time 3 \
        "http://127.0.0.1:${APP_PORT}/api/current" \
        >/dev/null 2>&1; then
        ok "Sensor-API liefert Messwerte."
    else
        warn "Web-API läuft, aber die erste Messung ist noch nicht verfügbar."
    fi

    ok "Dashboard: http://${DASHBOARD_IP}:${DASHBOARD_PORT}/"

    echo
    echo "Intel-RAPL-Erkennung:"
    if [[ -r /sys/class/powercap/intel-rapl:0/energy_uj ]]; then
        echo "  [OK] /sys/class/powercap/intel-rapl:0/energy_uj vorhanden"
        echo "  CPU-Package-Watt wird ab der zweiten Collector-Messung angezeigt."
    else
        echo "  [HINWEIS] Keine Intel-RAPL Package-Zone gefunden."
    fi

    echo
    echo "Steuer-Code später ändern:"
    echo "  pve-dashboard-set-code"
}

# =============================================================================
# DASHBOARD SERVICE-MENÜ + LINK-MANAGER
# =============================================================================

install_dashboard_extras() {
    header "DASHBOARD SERVICE-MENÜ + LINK-MANAGER"

    local menu_tmp="/tmp/pve-dashboard-service-menu-update.$$"
    local link_tmp="/tmp/pve-dashboard-link-manager-install.$$"

    cat > "$menu_tmp" <<'__PVE_MENU_UPDATE_PAYLOAD__'
#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================================
# PVE Hardware Monitor - Service-Menü Update
# ============================================================================
# Fügt hinzu:
#   - obere Leiste: Menü | LIVE | Neustart | Herunterfahren
#   - ausklappbares Menü von links
#   - Standardlinks zu Proxmox / HA / Paperless / Pi-hole / NetAlertX
#   - eigene Dienste per Name + IP/URL
#   - Bearbeiten/Löschen nur mit bestehendem Dashboard-Steuer-Code
#
# Bestehende Sensorwerte, Historie und Power-Funktionen bleiben erhalten.
# ============================================================================

[[ ${EUID:-$(id -u)} -eq 0 ]] || {
    echo "FEHLER: Bitte als root auf dem Proxmox-Host ausführen."
    exit 1
}

APP_DIR="/opt/nodezero/dashboard"
APP_FILE="${APP_DIR}/app.py"
INDEX_FILE="${APP_DIR}/static/index.html"
SERVICE_FILE="/etc/systemd/system/pve-sensor-web.service"
WEB_DATA="/var/lib/pve-sensor-dashboard-web"
LINKS_FILE="${WEB_DATA}/links.json"
BACKUP="/root/backups/pve-dashboard-menu-backup-$(date +%Y%m%d-%H%M%S)"

[[ -f "$APP_FILE" ]] || { echo "FEHLER: $APP_FILE nicht gefunden."; exit 1; }
[[ -f "$INDEX_FILE" ]] || { echo "FEHLER: $INDEX_FILE nicht gefunden."; exit 1; }
[[ -f "$SERVICE_FILE" ]] || { echo "FEHLER: $SERVICE_FILE nicht gefunden."; exit 1; }

echo "============================================================"
echo " PVE DASHBOARD - SERVICE-MENÜ UPDATE"
echo "============================================================"
echo

mkdir -p "$BACKUP"
cp -a "$APP_FILE" "$BACKUP/app.py"
cp -a "$INDEX_FILE" "$BACKUP/index.html"
cp -a "$SERVICE_FILE" "$BACKUP/pve-sensor-web.service"
[[ -f "$LINKS_FILE" ]] && cp -a "$LINKS_FILE" "$BACKUP/links.json"

echo "Backup:"
echo "  $BACKUP"
echo

mkdir -p "$WEB_DATA"
chown pve-monitor:pve-monitor "$WEB_DATA"
chmod 700 "$WEB_DATA"

if [[ ! -s "$LINKS_FILE" ]]; then
    HOST_IP="$(
        ip -4 route get 1.1.1.1 2>/dev/null |
        awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}'
    )"
    HOST_IP="${HOST_IP:-192.168.178.100}"

    find_ct_ip() {
        local wanted="$1"
        local id host net ip

        while read -r id; do
            [[ "$id" =~ ^[0-9]+$ ]] || continue

            host="$(
                pct config "$id" 2>/dev/null |
                awk -F': ' '/^hostname:/ {print $2; exit}'
            )"

            [[ "$host" == "$wanted" ]] || continue

            net="$(
                pct config "$id" 2>/dev/null |
                awk -F': ' '/^net0:/ {print $2; exit}'
            )"

            ip="$(
                printf '%s\n' "$net" |
                sed -n 's/.*[, ]ip=\([^,]*\).*/\1/p' |
                cut -d/ -f1
            )"

            if [[ -n "$ip" && "$ip" != "dhcp" ]]; then
                printf '%s' "$ip"
                return 0
            fi
        done < <(pct list 2>/dev/null | awk 'NR>1 {print $1}')

        return 1
    }

    PAPERLESS_IP="$(find_ct_ip paperless || true)"
    PIHOLE_IP="$(find_ct_ip pihole || true)"
    NETALERTX_IP="$(find_ct_ip netalertx || true)"

    HAS_HA=0
    HA_MENU_IP=""

    while read -r ha_vm_id; do
        [[ "$ha_vm_id" =~ ^[0-9]+$ ]] || continue

        ha_name="$(
            qm config "$ha_vm_id" 2>/dev/null |
            awk -F': ' '/^name:/ {print $2; exit}'
        )"

        [[ "$ha_name" == "homeassistant" ]] || continue

        HAS_HA=1

        HA_MENU_IP="$(
            qm config "$ha_vm_id" 2>/dev/null |
            sed -n 's/.*static-ip=\([0-9][0-9.]*\).*/\1/p' |
            head -n1
        )"

        break
    done < <(qm list 2>/dev/null | awk 'NR>1 {print $1}')

    HOST_IP="$HOST_IP" \
    HA_MENU_IP="$HA_MENU_IP" \
    PAPERLESS_IP="$PAPERLESS_IP" \
    PIHOLE_IP="$PIHOLE_IP" \
    NETALERTX_IP="$NETALERTX_IP" \
    HAS_HA="$HAS_HA" \
    python3 - "$LINKS_FILE" <<'PYDEFAULT'
import json
import os
import sys
from pathlib import Path

path = Path(sys.argv[1])
links = []

def add(link_id, name, url, target="new"):
    if url:
        links.append({
            "id": link_id,
            "name": name,
            "url": url,
            "target": target,
        })

host = os.environ.get("HOST_IP", "")
add("proxmox", "Proxmox Web UI", f"https://{host}:8006" if host else "")

if os.environ.get("HAS_HA") == "1":
    ha_ip = os.environ.get("HA_MENU_IP", "")
    add(
        "homeassistant",
        "Home Assistant",
        f"http://{ha_ip}/" if ha_ip else "http://homeassistant.local/",
    )

ip = os.environ.get("PAPERLESS_IP", "")
add("paperless", "Paperless", f"http://{ip}/" if ip else "")

ip = os.environ.get("PIHOLE_IP", "")
add("pihole", "Pi-hole", f"http://{ip}/admin/" if ip else "")

ip = os.environ.get("NETALERTX_IP", "")
add("netalertx", "NetAlertX", f"http://{ip}/" if ip else "")

path.write_text(
    json.dumps(links, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
PYDEFAULT

    chown pve-monitor:pve-monitor "$LINKS_FILE"
    chmod 600 "$LINKS_FILE"

    echo "Standard-Dienste wurden automatisch angelegt."
else
    echo "Vorhandene Menüeinträge werden beibehalten."
fi

python3 - "$APP_FILE" <<'PYAPP_PATCH'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

if "# PVE_SERVICE_MENU_API_V2" in text or "# PVE_SERVICE_MENU_API_V1" in text:
    print("Service-Menü API ist bereits vorhanden.")
    raise SystemExit(0)

if "import json\n" not in text:
    anchor = "import os\n"
    if anchor not in text:
        raise SystemExit("FEHLER: Import-Anker in app.py nicht gefunden.")
    text = text.replace(anchor, "import json\nimport os\n", 1)

if "import secrets\n" not in text:
    anchor = "import platform\n"
    if anchor not in text:
        raise SystemExit("FEHLER: platform-Import nicht gefunden.")
    text = text.replace(anchor, "import platform\nimport secrets\n", 1)

if "from urllib.parse import urlparse\n" not in text:
    anchor = "from pathlib import Path\n"
    if anchor not in text:
        raise SystemExit("FEHLER: pathlib-Import nicht gefunden.")
    text = text.replace(anchor, anchor + "from urllib.parse import urlparse\n", 1)

const_anchor = 'CONTROL_HASH_FILE = Path("/etc/pve-sensor-dashboard/control.hash")\n'
if const_anchor not in text:
    raise SystemExit("FEHLER: CONTROL_HASH_FILE-Anker nicht gefunden.")

text = text.replace(
    const_anchor,
    const_anchor +
    'LINKS_FILE = Path("/var/lib/pve-sensor-dashboard-web/links.json")\n',
    1,
)

lock_anchor = "_failed_lock = threading.Lock()\n"
if lock_anchor not in text:
    raise SystemExit("FEHLER: Lock-Anker nicht gefunden.")

text = text.replace(
    lock_anchor,
    lock_anchor + "_links_lock = threading.Lock()\n",
    1,
)

route_anchor = '@app.get("/")\ndef index():\n'
if route_anchor not in text:
    raise SystemExit("FEHLER: Route-Anker nicht gefunden.")

helpers = r'''
# PVE_SERVICE_MENU_API_V2

def normalize_service_url(value):
    value = str(value or "").strip()

    if not value:
        raise ValueError("Adresse/URL fehlt.")

    if len(value) > 300:
        raise ValueError("Adresse/URL ist zu lang.")

    if "://" not in value:
        value = "http://" + value

    parsed = urlparse(value)

    if parsed.scheme not in ("http", "https") or not parsed.netloc:
        raise ValueError("Nur gültige HTTP- oder HTTPS-Adressen sind erlaubt.")

    return value


def read_service_links():
    with _links_lock:
        try:
            data = json.loads(LINKS_FILE.read_text(encoding="utf-8"))
        except FileNotFoundError:
            return []
        except Exception:
            return []

    out = []

    if not isinstance(data, list):
        return out

    for item in data:
        if not isinstance(item, dict):
            continue

        link_id = str(item.get("id", "")).strip()
        name = str(item.get("name", "")).strip()
        url = str(item.get("url", "")).strip()
        target = str(item.get("target", "new")).strip()

        if not link_id or not name or not url:
            continue

        if target not in ("new", "same"):
            target = "new"

        out.append({
            "id": link_id,
            "name": name,
            "url": url,
            "target": target,
        })

    return out[:30]


def write_service_links(links):
    LINKS_FILE.parent.mkdir(parents=True, exist_ok=True)

    temp = LINKS_FILE.with_suffix(".tmp")

    with _links_lock:
        temp.write_text(
            json.dumps(links, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        temp.chmod(0o600)
        temp.replace(LINKS_FILE)


def verify_control_request(payload):
    ip = client_ip()
    locked, remaining = rate_state(ip)

    if locked:
        return False, (
            jsonify({
                "error": f"Zu viele Fehlversuche. Noch {remaining} Sekunden gesperrt."
            }),
            429,
        )

    code = str((payload or {}).get("code", ""))

    if not verify_code(code):
        fails, locked_until = record_failure(ip)

        if locked_until > time.time():
            return False, (
                jsonify({
                    "error": "Zu viele Fehlversuche. Diese IP ist 5 Minuten gesperrt."
                }),
                429,
            )

        return False, (
            jsonify({
                "error": f"Steuer-Code ist falsch. Fehlversuch {fails}/{MAX_FAILS}."
            }),
            403,
        )

    clear_failures(ip)
    return True, None


@app.get("/api/links")
def service_links():
    return jsonify(read_service_links())


@app.post("/api/links/save")
def save_service_link():
    payload = request.get_json(silent=True) or {}

    allowed, error = verify_control_request(payload)
    if not allowed:
        return error

    name = str(payload.get("name", "")).strip()

    if not name:
        return jsonify({"error": "Name fehlt."}), 400

    if len(name) > 50:
        return jsonify({"error": "Name darf höchstens 50 Zeichen haben."}), 400

    try:
        url = normalize_service_url(payload.get("url", ""))
    except ValueError as exc:
        return jsonify({"error": str(exc)}), 400

    target = str(payload.get("target", "new")).strip()
    if target not in ("new", "same"):
        target = "new"

    # JSON "id": null bedeutet: neuer Eintrag.
    requested_id = str(payload.get("id") or "").strip()
    links = read_service_links()

    if requested_id:
        found = False

        for item in links:
            if item["id"] == requested_id:
                item["name"] = name
                item["url"] = url
                item["target"] = target
                found = True
                break

        if not found:
            return jsonify({"error": "Eintrag wurde nicht gefunden."}), 404

        link_id = requested_id

    else:
        if len(links) >= 30:
            return jsonify({"error": "Maximal 30 Dienste sind möglich."}), 400

        link_id = secrets.token_hex(6)

        links.append({
            "id": link_id,
            "name": name,
            "url": url,
            "target": target,
        })

    write_service_links(links)

    return jsonify({
        "ok": True,
        "id": link_id,
        "links": links,
    })


@app.post("/api/links/delete")
def delete_service_link():
    payload = request.get_json(silent=True) or {}

    allowed, error = verify_control_request(payload)
    if not allowed:
        return error

    link_id = str(payload.get("id", "")).strip()

    if not link_id:
        return jsonify({"error": "Eintrag-ID fehlt."}), 400

    links = read_service_links()
    new_links = [item for item in links if item["id"] != link_id]

    if len(new_links) == len(links):
        return jsonify({"error": "Eintrag wurde nicht gefunden."}), 404

    write_service_links(new_links)

    return jsonify({
        "ok": True,
        "links": new_links,
    })


'''

text = text.replace(route_anchor, helpers + route_anchor, 1)

path.write_text(text, encoding="utf-8")
print("Flask API erweitert.")
PYAPP_PATCH

python3 - "$INDEX_FILE" <<'PYINDEX_PATCH'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

if "PVE_SERVICE_MENU_UI_V2" in text or "PVE_SERVICE_MENU_UI_V1" in text:
    print("Service-Menü Oberfläche ist bereits vorhanden.")
    raise SystemExit(0)

css = r'''
/* PVE_SERVICE_MENU_UI_V2 */
.toolbar{
  display:flex;gap:9px;align-items:center;flex-wrap:wrap
}
.top .brand{margin-left:auto;text-align:right}
.menuBtn{border-color:#315783;color:#a9ceff}
.navShade{
  position:fixed;inset:0;background:#02060ca8;z-index:30;
  opacity:0;pointer-events:none;transition:opacity .18s ease
}
.navShade.show{opacity:1;pointer-events:auto}
.sideNav{
  position:fixed;top:0;bottom:0;left:0;width:min(360px,88vw);
  background:linear-gradient(180deg,#101b2b,#0a121e);
  border-right:1px solid #304159;z-index:31;
  transform:translateX(-102%);transition:transform .2s ease;
  box-shadow:22px 0 65px #0009;padding:18px;
  display:flex;flex-direction:column
}
.sideNav.show{transform:translateX(0)}
.navHead{
  display:flex;justify-content:space-between;align-items:center;
  padding-bottom:15px;border-bottom:1px solid var(--line)
}
.navHead strong{font-size:18px}
.navClose{padding:7px 10px}
.navSection{
  margin:17px 3px 7px;color:var(--muted);font-size:11px;
  font-weight:750;letter-spacing:.09em;text-transform:uppercase
}
.navLink{
  display:flex;align-items:center;gap:11px;text-decoration:none;color:var(--text);
  border:1px solid transparent;border-radius:11px;padding:10px 11px;margin:2px 0
}
.navLink:hover{background:#142238;border-color:#263a55}
.navIcon{
  width:34px;height:34px;border-radius:10px;display:grid;place-items:center;
  background:#1a2b43;border:1px solid #2d4464;font-size:11px;font-weight:800
}
.navText{min-width:0;flex:1}
.navName{font-size:13px;font-weight:700}
.navUrl{
  color:var(--muted);font-size:11px;margin-top:2px;
  white-space:nowrap;overflow:hidden;text-overflow:ellipsis
}
.navManage{
  margin-top:auto;width:100%;text-align:left;border-color:#355174
}
.linkDialog{width:min(690px,100%)}
.linkList{
  max-height:220px;overflow:auto;border:1px solid var(--line);
  border-radius:11px;margin:10px 0 14px;background:#0a121d
}
.linkRow{
  display:flex;gap:8px;align-items:center;padding:9px 10px;
  border-bottom:1px solid #202e41
}
.linkRow:last-child{border-bottom:0}
.linkRowMain{flex:1;min-width:0}
.linkRowName{font-weight:700;font-size:13px}
.linkRowUrl{
  font-size:11px;color:var(--muted);overflow:hidden;
  white-space:nowrap;text-overflow:ellipsis
}
.linkRow button{padding:6px 9px;font-size:11px}
.formGrid{display:grid;grid-template-columns:1fr 1.5fr;gap:9px}
.formGrid .full{grid-column:1/-1}
.dialog label{
  display:block;font-size:11px;color:var(--muted);
  margin:3px 0 5px;font-weight:700
}
.dialog select{
  width:100%;padding:11px;background:#09111c;color:white;
  border:1px solid #35465e;border-radius:10px
}
.dialog .smallHint{color:var(--muted);font-size:11px;margin-top:5px}
button.secondaryDanger{border-color:#61303a;color:#ff9ba5}
@media(max-width:760px){
  .top .brand{width:100%;margin-left:0;text-align:left}
  .toolbar{width:100%}
  .formGrid{grid-template-columns:1fr}
  .formGrid .full{grid-column:auto}
}
'''

if "</style>" not in text:
    raise SystemExit("FEHLER: </style> nicht gefunden.")
text = text.replace("</style>", css + "\n</style>", 1)

old_top = '''<div class="top">
  <div class="brand">
    <h1>PVE Hardware Monitor</h1>
    <p id="hostinfo">Proxmox Server</p>
  </div>
  <div class="actions">
    <div class="live"><span id="dot" class="dot"></span><span id="state">START</span></div>
    <button class="reboot" onclick="openPower('reboot')">↻ Neustart</button>
    <button class="danger" onclick="openPower('poweroff')">⏻ Herunterfahren</button>
  </div>
</div>'''

new_top = '''<div class="top">
  <div class="toolbar">
    <button class="menuBtn" onclick="openNav()">☰ Menü</button>
    <div class="live"><span id="dot" class="dot"></span><span id="state">START</span></div>
    <button class="reboot" onclick="openPower('reboot')">↻ Neustart</button>
    <button class="danger" onclick="openPower('poweroff')">⏻ Herunterfahren</button>
  </div>
  <div class="brand">
    <h1>PVE Hardware Monitor</h1>
    <p id="hostinfo">Proxmox Server</p>
  </div>
</div>'''

if old_top not in text:
    raise SystemExit("FEHLER: Kopfzeile nicht in erwarteter Form gefunden.")
text = text.replace(old_top, new_top, 1)

sidebar = r'''
<div id="navShade" class="navShade" onclick="closeNav()"></div>

<aside id="sideNav" class="sideNav" aria-label="Dashboard Menü">
  <div class="navHead">
    <strong>Server-Menü</strong>
    <button class="navClose" onclick="closeNav()">✕</button>
  </div>

  <div class="navSection">Dashboard</div>

  <a class="navLink" href="/">
    <span class="navIcon">PVE</span>
    <span class="navText">
      <div class="navName">Live-Übersicht</div>
      <div class="navUrl">Hardware-Monitoring</div>
    </span>
  </a>

  <div class="navSection">Dienste</div>
  <div id="serviceNavLinks"></div>

  <button class="navManage" onclick="openLinkManager()">⚙ Dienste verwalten</button>
</aside>
'''

if "<body>" not in text:
    raise SystemExit("FEHLER: <body> nicht gefunden.")
text = text.replace("<body>", "<body>\n" + sidebar, 1)

power_modal_anchor = '<div class="modal" id="modal">\n'
if power_modal_anchor not in text:
    raise SystemExit("FEHLER: Power-Modal nicht gefunden.")

link_modal = r'''
<div class="modal" id="linksModal">
  <div class="dialog linkDialog">
    <h2>Dienste verwalten</h2>
    <p>
      Hier kannst du interne Webseiten hinzufügen. Beispiele:
      <b>192.168.178.104</b> oder <b>https://mein-server.local</b>.
    </p>

    <div id="linkList" class="linkList"></div>

    <div class="formGrid">
      <div>
        <label for="linkName">Name</label>
        <input id="linkName" type="text" maxlength="50" placeholder="z. B. NAS">
      </div>

      <div>
        <label for="linkUrl">IP / Adresse / URL</label>
        <input id="linkUrl" type="text" maxlength="300" placeholder="192.168.178.183:5001">
      </div>

      <div>
        <label for="linkTarget">Öffnen</label>
        <select id="linkTarget">
          <option value="new">Neuer Tab</option>
          <option value="same">Gleicher Tab</option>
        </select>
      </div>

      <div>
        <label for="linkCode">Sicherheitscode</label>
        <input id="linkCode" type="password" autocomplete="off" placeholder="Dashboard-Steuer-Code">
      </div>

      <div class="full">
        <div id="linkMsg" class="msg"></div>
        <div class="smallHint">
          Speichern und Löschen sind mit demselben Sicherheitscode geschützt wie Neustart/Herunterfahren.
        </div>
      </div>
    </div>

    <div class="modalButtons">
      <button id="linkDelete" class="secondaryDanger" style="display:none" onclick="deleteLink()">Löschen</button>
      <button onclick="clearLinkForm()">Neu</button>
      <button onclick="closeLinkManager()">Schließen</button>
      <button id="linkSave" onclick="saveLink()">Speichern</button>
    </div>
  </div>
</div>

'''
text = text.replace(power_modal_anchor, link_modal + power_modal_anchor, 1)

js_anchor = "const colors=['#64a7ff','#9b7cff','#37d996','#ffbd4a','#ff7080'];\n"
if js_anchor not in text:
    raise SystemExit("FEHLER: JavaScript-Anker nicht gefunden.")

js = r'''

let serviceLinks=[];
let editingLinkId=null;

function initials(name){
  const p=String(name||'').trim().split(/\s+/).filter(Boolean);
  if(!p.length)return 'WEB';
  if(p.length===1)return p[0].slice(0,3).toUpperCase();
  return (p[0][0]+p[1][0]).toUpperCase();
}

function openNav(){
  $('navShade').classList.add('show');
  $('sideNav').classList.add('show');
}

function closeNav(){
  $('navShade').classList.remove('show');
  $('sideNav').classList.remove('show');
}

function renderServiceLinks(){
  const box=$('serviceNavLinks');
  box.innerHTML='';

  if(!serviceLinks.length){
    const empty=document.createElement('div');
    empty.className='navUrl';
    empty.style.padding='9px 11px';
    empty.textContent='Noch keine Dienste eingetragen';
    box.appendChild(empty);
    return;
  }

  serviceLinks.forEach(item=>{
    const a=document.createElement('a');
    a.className='navLink';
    a.href=item.url;
    if(item.target!=='same'){
      a.target='_blank';
      a.rel='noopener noreferrer';
    }

    const icon=document.createElement('span');
    icon.className='navIcon';
    icon.textContent=initials(item.name);

    const tx=document.createElement('span');
    tx.className='navText';

    const nm=document.createElement('div');
    nm.className='navName';
    nm.textContent=item.name;

    const ur=document.createElement('div');
    ur.className='navUrl';
    ur.textContent=item.url;

    tx.append(nm,ur);
    a.append(icon,tx);
    box.appendChild(a);
  });
}

async function loadServiceLinks(){
  try{
    serviceLinks=await getJSON('/api/links');
    renderServiceLinks();
    renderLinkManagerList();
  }catch(e){
    console.error(e);
  }
}

function openLinkManager(){
  closeNav();
  clearLinkForm();
  renderLinkManagerList();
  $('linksModal').classList.add('show');
  setTimeout(()=>$('linkName').focus(),80);
}

function closeLinkManager(){
  $('linksModal').classList.remove('show');
}

function renderLinkManagerList(){
  const box=$('linkList');
  if(!box)return;

  box.innerHTML='';

  if(!serviceLinks.length){
    const row=document.createElement('div');
    row.className='linkRow';
    row.textContent='Noch keine Dienste eingetragen.';
    box.appendChild(row);
    return;
  }

  serviceLinks.forEach(item=>{
    const row=document.createElement('div');
    row.className='linkRow';

    const main=document.createElement('div');
    main.className='linkRowMain';

    const name=document.createElement('div');
    name.className='linkRowName';
    name.textContent=item.name;

    const url=document.createElement('div');
    url.className='linkRowUrl';
    url.textContent=item.url;

    const edit=document.createElement('button');
    edit.textContent='Bearbeiten';
    edit.onclick=()=>editLink(item.id);

    main.append(name,url);
    row.append(main,edit);
    box.appendChild(row);
  });
}

function editLink(id){
  const item=serviceLinks.find(x=>x.id===id);
  if(!item)return;

  editingLinkId=item.id;
  $('linkName').value=item.name;
  $('linkUrl').value=item.url;
  $('linkTarget').value=item.target||'new';
  $('linkCode').value='';
  $('linkDelete').style.display='';
  $('linkMsg').textContent='Eintrag wird bearbeitet.';
  $('linkMsg').className='msg';
}

function clearLinkForm(){
  editingLinkId=null;
  $('linkName').value='';
  $('linkUrl').value='';
  $('linkTarget').value='new';
  $('linkCode').value='';
  $('linkDelete').style.display='none';
  $('linkMsg').textContent='';
  $('linkMsg').className='msg';
}

async function saveLink(){
  const name=$('linkName').value.trim();
  const url=$('linkUrl').value.trim();
  const code=$('linkCode').value;

  if(!name||!url){
    $('linkMsg').textContent='Name und Adresse müssen ausgefüllt sein.';
    $('linkMsg').className='msg err';
    return;
  }

  if(code.length<6){
    $('linkMsg').textContent='Bitte den Dashboard-Sicherheitscode eingeben.';
    $('linkMsg').className='msg err';
    return;
  }

  $('linkSave').disabled=true;

  try{
    const d=await getJSON('/api/links/save',{
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify({
        ...(editingLinkId ? {id:editingLinkId} : {}),
        name,
        url,
        target:$('linkTarget').value,
        code
      })
    });

    serviceLinks=d.links||[];
    renderServiceLinks();
    renderLinkManagerList();
    clearLinkForm();

    $('linkMsg').textContent='Dienst gespeichert.';
    $('linkMsg').className='msg ok';

  }catch(e){
    $('linkMsg').textContent=e.message;
    $('linkMsg').className='msg err';
  }finally{
    $('linkSave').disabled=false;
  }
}

async function deleteLink(){
  if(!editingLinkId)return;

  const item=serviceLinks.find(x=>x.id===editingLinkId);
  const code=$('linkCode').value;

  if(code.length<6){
    $('linkMsg').textContent='Zum Löschen den Dashboard-Sicherheitscode eingeben.';
    $('linkMsg').className='msg err';
    return;
  }

  if(!confirm(`Dienst "${item?.name||''}" wirklich löschen?`))return;

  $('linkDelete').disabled=true;

  try{
    const d=await getJSON('/api/links/delete',{
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify({
        id:editingLinkId,
        code
      })
    });

    serviceLinks=d.links||[];
    renderServiceLinks();
    renderLinkManagerList();
    clearLinkForm();

    $('linkMsg').textContent='Dienst gelöscht.';
    $('linkMsg').className='msg ok';

  }catch(e){
    $('linkMsg').textContent=e.message;
    $('linkMsg').className='msg err';
  }finally{
    $('linkDelete').disabled=false;
  }
}

document.addEventListener('keydown',e=>{
  if(e.key==='Escape'){
    closeNav();
    if($('linksModal').classList.contains('show'))closeLinkManager();
  }
});

'''
text = text.replace(js_anchor, js_anchor + js, 1)

init_anchor = "(async()=>{\n  try{await info()}catch(e){}\n"
if init_anchor not in text:
    raise SystemExit("FEHLER: Initialisierungsblock nicht gefunden.")

text = text.replace(
    init_anchor,
    "(async()=>{\n  await loadServiceLinks();\n  try{await info()}catch(e){}\n",
    1,
)

path.write_text(text, encoding="utf-8")
print("Frontend erweitert.")
PYINDEX_PATCH

python3 - "$SERVICE_FILE" "$WEB_DATA" <<'PYSYSTEMD'
from pathlib import Path
import sys

path = Path(sys.argv[1])
web_data = sys.argv[2]
text = path.read_text(encoding="utf-8")

line = f"ReadWritePaths={web_data}"

if line not in text:
    if "[Install]" in text:
        text = text.replace("[Install]", line + "\n\n[Install]", 1)
    else:
        text += "\n" + line + "\n"

path.write_text(text, encoding="utf-8")
print("systemd Schreibbereich ergänzt.")
PYSYSTEMD

chown root:root "$APP_FILE" "$INDEX_FILE"
chmod 644 "$APP_FILE" "$INDEX_FILE"

chown -R pve-monitor:pve-monitor "$WEB_DATA"
chmod 700 "$WEB_DATA"
[[ -f "$LINKS_FILE" ]] && chmod 600 "$LINKS_FILE"

echo
echo "Prüfe Python-Syntax ..."
python3 -m py_compile "$APP_FILE"

echo "Prüfe systemd Unit ..."
systemd-analyze verify "$SERVICE_FILE" >/dev/null 2>&1 || {
    echo "FEHLER: systemd Unit ist ungültig. Backup liegt unter $BACKUP"
    exit 1
}

systemctl daemon-reload
systemctl restart pve-sensor-web.service
systemctl restart nginx

sleep 2

echo
echo "===== API TEST ====="

echo -n "Dashboard: "
curl -fsS http://127.0.0.1:9105/api/health >/dev/null && echo "OK" || echo "FEHLER"

echo -n "Menü-API:  "
curl -fsS http://127.0.0.1:9105/api/links >/tmp/pve-menu-links.json && echo "OK" || echo "FEHLER"

if [[ -s /tmp/pve-menu-links.json ]]; then
    echo
    python3 -m json.tool /tmp/pve-menu-links.json || cat /tmp/pve-menu-links.json
fi
rm -f /tmp/pve-menu-links.json

echo
echo "============================================================"
echo " UPDATE FERTIG"
echo "============================================================"
echo
echo "Obere Leiste:"
echo "  ☰ Menü | ● LIVE | ↻ Neustart | ⏻ Herunterfahren"
echo
echo "Im Menü:"
echo "  - erkannte Dienste"
echo "  - eigene Name/IP/URL-Einträge"
echo "  - Dienste verwalten"
echo
echo "Änderungen an Diensten benötigen denselben Sicherheitscode"
echo "wie Neustart und Herunterfahren."
echo
echo "Browser anschließend mit STRG + F5 neu laden."
echo
echo "Backup:"
echo "  $BACKUP"
echo "============================================================"

__PVE_MENU_UPDATE_PAYLOAD__

    chmod 700 "$menu_tmp"
    bash "$menu_tmp"
    rm -f "$menu_tmp"

    cat > "$link_tmp" <<'__PVE_LINK_MANAGER_PAYLOAD__'
#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || {
    echo "FEHLER: Bitte als root ausführen."
    exit 1
}

LINKS_FILE="/var/lib/pve-sensor-dashboard-web/links.json"
WEB_DIR="$(dirname "$LINKS_FILE")"
TOOL="/usr/local/sbin/pve-dashboard-link"
EXAMPLE="/root/pve-dashboard-links-beispiel.txt"

[[ -d /opt/nodezero/dashboard ]] || {
    echo "FEHLER: Das PVE Sensor Dashboard wurde nicht gefunden."
    exit 1
}

mkdir -p "$WEB_DIR"

if [[ ! -f "$LINKS_FILE" ]]; then
    echo '[]' > "$LINKS_FILE"
fi

chown pve-monitor:pve-monitor "$WEB_DIR" "$LINKS_FILE" 2>/dev/null || true
chmod 700 "$WEB_DIR"
chmod 600 "$LINKS_FILE"

cat > "$TOOL" <<'TOOL_EOF'
#!/usr/bin/env python3

import argparse
import json
import re
import secrets
import sys
from pathlib import Path
from urllib.parse import urlparse

LINKS_FILE = Path("/var/lib/pve-sensor-dashboard-web/links.json")
MAX_LINKS = 100


def normalize_url(value):
    value = value.strip()

    if not value:
        raise ValueError("Adresse/URL fehlt.")

    if "://" not in value:
        value = "http://" + value

    p = urlparse(value)

    if p.scheme not in ("http", "https") or not p.netloc:
        raise ValueError("Nur HTTP-/HTTPS-Adressen sind erlaubt.")

    return value


def read_links():
    if not LINKS_FILE.exists():
        return []

    try:
        data = json.loads(LINKS_FILE.read_text(encoding="utf-8"))
    except Exception as exc:
        raise SystemExit(f"FEHLER: links.json ist ungültig: {exc}")

    if not isinstance(data, list):
        raise SystemExit("FEHLER: links.json muss eine JSON-Liste enthalten.")

    out = []
    for item in data:
        if not isinstance(item, dict):
            continue

        link_id = str(item.get("id", "")).strip()
        name = str(item.get("name", "")).strip()
        url = str(item.get("url", "")).strip()
        target = str(item.get("target", "new")).strip()

        if link_id and name and url:
            out.append({
                "id": link_id,
                "name": name,
                "url": url,
                "target": target if target in ("new", "same") else "new",
            })

    return out


def write_links(links):
    LINKS_FILE.parent.mkdir(parents=True, exist_ok=True)

    tmp = LINKS_FILE.with_suffix(".tmp")
    tmp.write_text(
        json.dumps(links, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    tmp.chmod(0o600)
    tmp.replace(LINKS_FILE)

    # Dashboard-Webprozess läuft als pve-monitor.
    import os
    import pwd
    try:
        pw = pwd.getpwnam("pve-monitor")
        os.chown(LINKS_FILE, pw.pw_uid, pw.pw_gid)
    except Exception:
        pass


def unique_id(links):
    used = {x["id"] for x in links}

    while True:
        ident = secrets.token_hex(6)
        if ident not in used:
            return ident


def find_link(links, selector):
    # ID zuerst
    for item in links:
        if item["id"] == selector:
            return item

    # Danach exakter Name (case-insensitive)
    matches = [
        item for item in links
        if item["name"].casefold() == selector.casefold()
    ]

    if len(matches) == 1:
        return matches[0]

    if len(matches) > 1:
        raise SystemExit("FEHLER: Mehrere Einträge mit diesem Namen vorhanden. Bitte ID verwenden.")

    return None


def cmd_list(args):
    links = read_links()

    if not links:
        print("Keine Menüeinträge vorhanden.")
        return

    print(f"{'ID':<14} {'ÖFFNEN':<8} {'NAME':<28} URL")
    print("-" * 95)

    for item in links:
        print(
            f"{item['id']:<14} "
            f"{item['target']:<8} "
            f"{item['name'][:27]:<28} "
            f"{item['url']}"
        )


def cmd_add(args):
    links = read_links()

    if len(links) >= MAX_LINKS:
        raise SystemExit(f"FEHLER: Maximal {MAX_LINKS} Einträge.")

    name = args.name.strip()
    if not name:
        raise SystemExit("FEHLER: Name fehlt.")

    url = normalize_url(args.url)
    target = args.target

    # Derselbe Name + dieselbe URL nicht doppelt anlegen.
    for item in links:
        if item["name"].casefold() == name.casefold() and item["url"] == url:
            print(f"Bereits vorhanden: {item['name']} -> {item['url']}")
            return

    item = {
        "id": unique_id(links),
        "name": name,
        "url": url,
        "target": target,
    }

    links.append(item)
    write_links(links)

    print("Hinzugefügt:")
    print(f"  ID:   {item['id']}")
    print(f"  Name: {item['name']}")
    print(f"  URL:  {item['url']}")
    print(f"  Ziel: {item['target']}")


def cmd_delete(args):
    links = read_links()
    item = find_link(links, args.selector)

    if item is None:
        raise SystemExit("FEHLER: Eintrag nicht gefunden.")

    links = [x for x in links if x["id"] != item["id"]]
    write_links(links)

    print(f"Gelöscht: {item['name']} ({item['url']})")


def cmd_edit(args):
    links = read_links()
    item = find_link(links, args.selector)

    if item is None:
        raise SystemExit("FEHLER: Eintrag nicht gefunden.")

    if args.name is not None:
        new_name = args.name.strip()
        if not new_name:
            raise SystemExit("FEHLER: Neuer Name ist leer.")
        item["name"] = new_name

    if args.url is not None:
        item["url"] = normalize_url(args.url)

    if args.target is not None:
        item["target"] = args.target

    write_links(links)

    print("Geändert:")
    print(f"  ID:   {item['id']}")
    print(f"  Name: {item['name']}")
    print(f"  URL:  {item['url']}")
    print(f"  Ziel: {item['target']}")


def parse_import_line(line, lineno):
    line = line.strip()

    if not line or line.startswith("#"):
        return None

    parts = [x.strip() for x in line.split("|")]

    if len(parts) < 2 or len(parts) > 3:
        raise ValueError(
            f"Zeile {lineno}: erwartet NAME|URL oder NAME|URL|new/same"
        )

    name = parts[0]
    url = normalize_url(parts[1])
    target = parts[2].lower() if len(parts) == 3 and parts[2] else "new"

    if target not in ("new", "same"):
        raise ValueError(
            f"Zeile {lineno}: Ziel muss 'new' oder 'same' sein."
        )

    if not name:
        raise ValueError(f"Zeile {lineno}: Name fehlt.")

    return name, url, target


def cmd_import(args):
    source = Path(args.file)

    if not source.is_file():
        raise SystemExit(f"FEHLER: Datei nicht gefunden: {source}")

    links = read_links()
    added = 0
    updated = 0
    skipped = 0

    for lineno, raw in enumerate(
        source.read_text(encoding="utf-8").splitlines(),
        start=1,
    ):
        try:
            parsed = parse_import_line(raw, lineno)
        except ValueError as exc:
            raise SystemExit(f"FEHLER: {exc}")

        if parsed is None:
            continue

        name, url, target = parsed

        # Bei gleichem Namen den bestehenden Eintrag aktualisieren.
        existing = None
        for item in links:
            if item["name"].casefold() == name.casefold():
                existing = item
                break

        if existing:
            if existing["url"] == url and existing["target"] == target:
                skipped += 1
                continue

            existing["url"] = url
            existing["target"] = target
            updated += 1
        else:
            if len(links) >= MAX_LINKS:
                raise SystemExit(
                    f"FEHLER: Maximale Zahl von {MAX_LINKS} Einträgen erreicht."
                )

            links.append({
                "id": unique_id(links),
                "name": name,
                "url": url,
                "target": target,
            })
            added += 1

    write_links(links)

    print("Import abgeschlossen:")
    print(f"  Neu:          {added}")
    print(f"  Aktualisiert: {updated}")
    print(f"  Unverändert:  {skipped}")


def cmd_export(args):
    links = read_links()
    target = Path(args.file)

    lines = [
        "# PVE Dashboard Links",
        "# Format: NAME|URL|new",
        "# new  = neuer Tab",
        "# same = gleicher Tab",
        "",
    ]

    for item in links:
        lines.append(
            f"{item['name']}|{item['url']}|{item['target']}"
        )

    target.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Exportiert: {target}")


def main():
    parser = argparse.ArgumentParser(
        prog="pve-dashboard-link",
        description="Menülinks des PVE Hardware Monitors verwalten",
    )

    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("list", help="Alle Einträge anzeigen")
    p.set_defaults(func=cmd_list)

    p = sub.add_parser("add", help="Webseite hinzufügen")
    p.add_argument("name")
    p.add_argument("url")
    p.add_argument(
        "--target",
        choices=("new", "same"),
        default="new",
        help="new = neuer Tab, same = gleicher Tab",
    )
    p.set_defaults(func=cmd_add)

    p = sub.add_parser("delete", help="Webseite löschen")
    p.add_argument("selector", help="ID oder exakter Name")
    p.set_defaults(func=cmd_delete)

    p = sub.add_parser("edit", help="Webseite ändern")
    p.add_argument("selector", help="ID oder exakter Name")
    p.add_argument("--name")
    p.add_argument("--url")
    p.add_argument("--target", choices=("new", "same"))
    p.set_defaults(func=cmd_edit)

    p = sub.add_parser("import", help="Links aus Textdatei importieren")
    p.add_argument("file")
    p.set_defaults(func=cmd_import)

    p = sub.add_parser("export", help="Links in Textdatei exportieren")
    p.add_argument("file")
    p.set_defaults(func=cmd_export)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
TOOL_EOF

chmod 755 "$TOOL"

cat > "$EXAMPLE" <<'EOF'
# ============================================================
# PVE Dashboard - zusätzliche Webseiten
# ============================================================
#
# Format:
# NAME|URL|new
#
# new  = Link in neuem Browser-Tab öffnen
# same = Link im gleichen Tab öffnen
#
# Eine IP ohne http:// ist ebenfalls erlaubt.
#

Fritzbox|192.168.178.1|new
NAS|https://192.168.178.183:5001|new
Home Assistant|http://192.168.178.174/|new
Paperless|http://192.168.178.104/|new
Pi-hole|http://192.168.178.135/admin/|new
NetAlertX|http://192.168.178.136/|new
EOF

chmod 600 "$EXAMPLE"

echo
echo "============================================================"
echo " PVE DASHBOARD LINK-MANAGER INSTALLIERT"
echo "============================================================"
echo
echo "Einzelnen Link hinzufügen:"
echo
echo '  pve-dashboard-link add "NAS" "https://192.168.178.183:5001"'
echo
echo "Liste anzeigen:"
echo
echo "  pve-dashboard-link list"
echo
echo "Eintrag löschen:"
echo
echo '  pve-dashboard-link delete "NAS"'
echo
echo "Mehrere Links aus Datei importieren:"
echo
echo "  pve-dashboard-link import $EXAMPLE"
echo
echo "Beispieldatei:"
echo
echo "  $EXAMPLE"
echo
echo "Die Webseite liest links.json dynamisch ein."
echo "Nach Änderungen genügt normalerweise ein Neuladen des Dashboards."
echo "============================================================"

__PVE_LINK_MANAGER_PAYLOAD__

    chmod 700 "$link_tmp"
    bash "$link_tmp"
    rm -f "$link_tmp"

    echo
    ok "Service-Menü und Link-Manager sind installiert."
    echo
    echo "Links anzeigen:"
    echo "  pve-dashboard-link list"
    echo
    echo "Link hinzufügen:"
    echo '  pve-dashboard-link add "NAS" "https://192.168.178.183:5001"'
    echo
    echo "Mehrere Links importieren:"
    echo "  pve-dashboard-link import /root/pve-dashboard-links-beispiel.txt"
}


# =============================================================================
# DASHBOARD MENÜ-SORTIERUNG
# =============================================================================

install_dashboard_menu_sorting() {
    header "DASHBOARD MENÜ-SORTIERUNG"

    local sort_tmp="/tmp/pve-dashboard-menu-sort-update.$$"

    cat > "$sort_tmp" <<'__PVE_DASHBOARD_SORT_PAYLOAD__'
#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || {
    echo "FEHLER: Bitte als root ausführen."
    exit 1
}

APP_FILE="/opt/nodezero/dashboard/app.py"
INDEX_FILE="/opt/nodezero/dashboard/static/index.html"
LINK_TOOL="/usr/local/sbin/pve-dashboard-link"
BACKUP="/root/backups/pve-dashboard-sort-backup-$(date +%Y%m%d-%H%M%S)"

[[ -f "$APP_FILE" ]] || { echo "FEHLER: $APP_FILE nicht gefunden."; exit 1; }
[[ -f "$INDEX_FILE" ]] || { echo "FEHLER: $INDEX_FILE nicht gefunden."; exit 1; }

mkdir -p "$BACKUP"
cp -a "$APP_FILE" "$BACKUP/app.py"
cp -a "$INDEX_FILE" "$BACKUP/index.html"
[[ -f "$LINK_TOOL" ]] && cp -a "$LINK_TOOL" "$BACKUP/pve-dashboard-link"

echo "Backup:"
echo "  $BACKUP"
echo

# ------------------------------------------------------------------
# API: Reihenfolge dauerhaft speichern
# ------------------------------------------------------------------

python3 - "$APP_FILE" <<'PYAPP_SORT'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

marker = "# PVE_SERVICE_MENU_SORT_API_V1"

if marker in text:
    print("Sortier-API bereits vorhanden.")
    raise SystemExit(0)

anchor = '''@app.post("/api/links/delete")
def delete_service_link():
'''

if anchor not in text:
    raise SystemExit(
        "FEHLER: Service-Menü API wurde nicht gefunden. "
        "Bitte zuerst das Dashboard-Service-Menü installieren."
    )

route = r'''
# PVE_SERVICE_MENU_SORT_API_V1
@app.post("/api/links/reorder")
def reorder_service_links():
    payload = request.get_json(silent=True) or {}

    allowed, error = verify_control_request(payload)
    if not allowed:
        return error

    requested_ids = payload.get("ids", [])

    if not isinstance(requested_ids, list):
        return jsonify({"error": "Ungültige Sortierung."}), 400

    requested_ids = [str(x).strip() for x in requested_ids]

    if not requested_ids or any(not x for x in requested_ids):
        return jsonify({"error": "Ungültige Sortierung."}), 400

    if len(requested_ids) != len(set(requested_ids)):
        return jsonify({"error": "Eine Eintrag-ID kommt mehrfach vor."}), 400

    links = read_service_links()
    current_ids = [item["id"] for item in links]

    if len(requested_ids) != len(current_ids):
        return jsonify({
            "error": "Die Linkliste hat sich geändert. Bitte neu laden."
        }), 409

    if set(requested_ids) != set(current_ids):
        return jsonify({
            "error": "Die Linkliste hat sich geändert. Bitte neu laden."
        }), 409

    by_id = {item["id"]: item for item in links}
    reordered = [by_id[link_id] for link_id in requested_ids]

    write_service_links(reordered)

    return jsonify({
        "ok": True,
        "links": reordered,
    })


'''

text = text.replace(anchor, route + anchor, 1)
path.write_text(text, encoding="utf-8")
print("Sortier-API ergänzt.")
PYAPP_SORT

# ------------------------------------------------------------------
# Frontend: Pfeile + Sortierung speichern
# ------------------------------------------------------------------

python3 - "$INDEX_FILE" <<'PYINDEX_SORT'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

marker = "PVE_SERVICE_MENU_SORT_UI_V1"

if marker in text:
    print("Sortier-Oberfläche bereits vorhanden.")
    raise SystemExit(0)

if "PVE_SERVICE_MENU_UI_V2" not in text and "PVE_SERVICE_MENU_UI_V1" not in text:
    raise SystemExit(
        "FEHLER: Service-Menü Oberfläche wurde nicht gefunden. "
        "Bitte zuerst das Dashboard-Service-Menü installieren."
    )

css_anchor = "button.secondaryDanger{border-color:#61303a;color:#ff9ba5}\n"

css_extra = r'''/* PVE_SERVICE_MENU_SORT_UI_V1 */
.linkRowActions{
  display:flex;align-items:center;gap:5px;flex-wrap:nowrap
}
.linkRowActions button{
  min-width:34px;padding:6px 8px
}
.linkSortBtn{
  border-color:#355174;color:#b8d7ff
}
.linkSortBtn:disabled{
  opacity:.35;cursor:not-allowed
}
.sortBar{
  display:flex;gap:8px;align-items:center;justify-content:space-between;
  flex-wrap:wrap;margin:-3px 0 13px
}
.sortHint{
  color:var(--muted);font-size:11px;line-height:1.4
}
.sortDirty{
  color:#ffbd4a;font-weight:700
}
'''

if css_anchor not in text:
    raise SystemExit("FEHLER: CSS-Anker nicht gefunden.")

text = text.replace(css_anchor, css_anchor + css_extra, 1)

list_anchor = '''    <div id="linkList" class="linkList"></div>

    <div class="formGrid">
'''

list_replacement = '''    <div id="linkList" class="linkList"></div>

    <div class="sortBar">
      <div id="sortState" class="sortHint">
        Reihenfolge mit ↑ / ↓ ändern.
      </div>
      <button id="linkSortSave" class="linkSortBtn" type="button" onclick="saveLinkOrder()">
        Sortierung speichern
      </button>
    </div>

    <div class="formGrid">
'''

if list_anchor not in text:
    raise SystemExit("FEHLER: Linklisten-Anker nicht gefunden.")

text = text.replace(list_anchor, list_replacement, 1)

old_hint = '''          Speichern und Löschen sind mit demselben Sicherheitscode geschützt wie Neustart/Herunterfahren.
'''
new_hint = '''          Speichern, Löschen und die Menü-Sortierung sind mit demselben Sicherheitscode geschützt wie Neustart/Herunterfahren.
'''
text = text.replace(old_hint, new_hint, 1)

js_state_anchor = '''let serviceLinks=[];
let editingLinkId=null;
'''

js_state_replacement = '''let serviceLinks=[];
let editingLinkId=null;
let linkOrderDirty=false;
'''

if js_state_anchor not in text:
    raise SystemExit("FEHLER: JavaScript-Zustand nicht gefunden.")

text = text.replace(js_state_anchor, js_state_replacement, 1)

old_render = r'''function renderLinkManagerList(){
  const box=$('linkList');
  if(!box)return;

  box.innerHTML='';

  if(!serviceLinks.length){
    const row=document.createElement('div');
    row.className='linkRow';
    row.textContent='Noch keine Dienste eingetragen.';
    box.appendChild(row);
    return;
  }

  serviceLinks.forEach(item=>{
    const row=document.createElement('div');
    row.className='linkRow';

    const main=document.createElement('div');
    main.className='linkRowMain';

    const name=document.createElement('div');
    name.className='linkRowName';
    name.textContent=item.name;

    const url=document.createElement('div');
    url.className='linkRowUrl';
    url.textContent=item.url;

    const edit=document.createElement('button');
    edit.textContent='Bearbeiten';
    edit.onclick=()=>editLink(item.id);

    main.append(name,url);
    row.append(main,edit);
    box.appendChild(row);
  });
}
'''

new_render = r'''function renderLinkManagerList(){
  const box=$('linkList');
  if(!box)return;

  box.innerHTML='';

  if(!serviceLinks.length){
    const row=document.createElement('div');
    row.className='linkRow';
    row.textContent='Noch keine Dienste eingetragen.';
    box.appendChild(row);
    updateSortState();
    return;
  }

  serviceLinks.forEach((item,index)=>{
    const row=document.createElement('div');
    row.className='linkRow';

    const main=document.createElement('div');
    main.className='linkRowMain';

    const name=document.createElement('div');
    name.className='linkRowName';
    name.textContent=`${index+1}. ${item.name}`;

    const url=document.createElement('div');
    url.className='linkRowUrl';
    url.textContent=item.url;

    const actions=document.createElement('div');
    actions.className='linkRowActions';

    const up=document.createElement('button');
    up.type='button';
    up.className='linkSortBtn';
    up.textContent='↑';
    up.title='Nach oben';
    up.setAttribute('aria-label',`${item.name} nach oben`);
    up.disabled=index===0;
    up.onclick=()=>moveLink(item.id,-1);

    const down=document.createElement('button');
    down.type='button';
    down.className='linkSortBtn';
    down.textContent='↓';
    down.title='Nach unten';
    down.setAttribute('aria-label',`${item.name} nach unten`);
    down.disabled=index===serviceLinks.length-1;
    down.onclick=()=>moveLink(item.id,1);

    const edit=document.createElement('button');
    edit.type='button';
    edit.textContent='Bearbeiten';
    edit.onclick=()=>editLink(item.id);

    main.append(name,url);
    actions.append(up,down,edit);
    row.append(main,actions);
    box.appendChild(row);
  });

  updateSortState();
}
'''

if old_render not in text:
    raise SystemExit("FEHLER: renderLinkManagerList() nicht in erwarteter Form gefunden.")

text = text.replace(old_render, new_render, 1)

edit_anchor = '''function editLink(id){
'''

sort_functions = r'''function updateSortState(){
  const el=$('sortState');
  if(!el)return;

  if(linkOrderDirty){
    el.textContent='Reihenfolge geändert – noch nicht gespeichert.';
    el.className='sortHint sortDirty';
  }else{
    el.textContent='Reihenfolge mit ↑ / ↓ ändern.';
    el.className='sortHint';
  }
}

function moveLink(id,delta){
  const index=serviceLinks.findIndex(x=>x.id===id);
  if(index<0)return;

  const next=index+delta;
  if(next<0||next>=serviceLinks.length)return;

  const copy=[...serviceLinks];
  [copy[index],copy[next]]=[copy[next],copy[index]];
  serviceLinks=copy;
  linkOrderDirty=true;

  renderServiceLinks();
  renderLinkManagerList();
}

async function saveLinkOrder(){
  if(!linkOrderDirty){
    $('linkMsg').textContent='Die Reihenfolge wurde nicht geändert.';
    $('linkMsg').className='msg';
    return;
  }

  const code=$('linkCode').value;

  if(code.length<6){
    $('linkMsg').textContent='Zum Speichern der Sortierung den Dashboard-Sicherheitscode eingeben.';
    $('linkMsg').className='msg err';
    return;
  }

  const btn=$('linkSortSave');
  btn.disabled=true;

  try{
    const d=await getJSON('/api/links/reorder',{
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify({
        ids:serviceLinks.map(x=>x.id),
        code
      })
    });

    serviceLinks=d.links||[];
    linkOrderDirty=false;
    renderServiceLinks();
    renderLinkManagerList();

    $('linkMsg').textContent='Menü-Sortierung gespeichert.';
    $('linkMsg').className='msg ok';

  }catch(e){
    $('linkMsg').textContent=e.message;
    $('linkMsg').className='msg err';
  }finally{
    btn.disabled=false;
  }
}

'''

if edit_anchor not in text:
    raise SystemExit("FEHLER: editLink-Anker nicht gefunden.")

text = text.replace(edit_anchor, sort_functions + edit_anchor, 1)

load_old = '''    serviceLinks=await getJSON('/api/links');
    renderServiceLinks();
    renderLinkManagerList();
'''
load_new = '''    serviceLinks=await getJSON('/api/links');
    linkOrderDirty=false;
    renderServiceLinks();
    renderLinkManagerList();
'''
text = text.replace(load_old, load_new, 1)

save_delete_old = '''    serviceLinks=d.links||[];
    renderServiceLinks();
    renderLinkManagerList();
    clearLinkForm();
'''
save_delete_new = '''    serviceLinks=d.links||[];
    linkOrderDirty=false;
    renderServiceLinks();
    renderLinkManagerList();
    clearLinkForm();
'''
text = text.replace(save_delete_old, save_delete_new, 2)

path.write_text(text, encoding="utf-8")
print("Sortier-Oberfläche ergänzt.")
PYINDEX_SORT

# ------------------------------------------------------------------
# CLI: position / up / down / top / bottom
# ------------------------------------------------------------------

if [[ -f "$LINK_TOOL" ]]; then
python3 - "$LINK_TOOL" <<'PYCLI_SORT'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

marker = "# PVE_DASHBOARD_LINK_SORT_CLI_V1"

if marker in text:
    print("CLI-Sortierung bereits vorhanden.")
    raise SystemExit(0)

main_anchor = '''def cmd_delete(args):
'''

cmd = r'''# PVE_DASHBOARD_LINK_SORT_CLI_V1
def cmd_move(args):
    links = read_links()
    item = find_link(links, args.selector)

    if item is None:
        raise SystemExit("FEHLER: Eintrag nicht gefunden.")

    old_index = next(i for i, x in enumerate(links) if x["id"] == item["id"])
    pos = str(args.position).strip().lower()

    if pos == "top":
        new_index = 0
    elif pos == "bottom":
        new_index = len(links) - 1
    elif pos == "up":
        new_index = max(0, old_index - 1)
    elif pos == "down":
        new_index = min(len(links) - 1, old_index + 1)
    else:
        try:
            requested = int(pos)
        except ValueError:
            raise SystemExit(
                "FEHLER: Position muss up, down, top, bottom "
                "oder eine Zahl ab 1 sein."
            )

        if requested < 1 or requested > len(links):
            raise SystemExit(
                f"FEHLER: Position muss zwischen 1 und {len(links)} liegen."
            )

        new_index = requested - 1

    moved = links.pop(old_index)
    links.insert(new_index, moved)
    write_links(links)

    print(
        f"Verschoben: {moved['name']} -> Position {new_index + 1}"
    )


'''

if main_anchor not in text:
    raise SystemExit("FEHLER: CLI cmd_delete-Anker nicht gefunden.")

text = text.replace(main_anchor, cmd + main_anchor, 1)

parser_anchor = '''    p = sub.add_parser("delete", help="Webseite löschen")
    p.add_argument("selector", help="ID oder exakter Name")
    p.set_defaults(func=cmd_delete)
'''

parser_replacement = '''    p = sub.add_parser("move", help="Menüeintrag verschieben")
    p.add_argument("selector", help="ID oder exakter Name")
    p.add_argument(
        "position",
        help="up, down, top, bottom oder Zielposition ab 1",
    )
    p.set_defaults(func=cmd_move)

    p = sub.add_parser("delete", help="Webseite löschen")
    p.add_argument("selector", help="ID oder exakter Name")
    p.set_defaults(func=cmd_delete)
'''

if parser_anchor not in text:
    raise SystemExit("FEHLER: CLI Parser-Anker nicht gefunden.")

text = text.replace(parser_anchor, parser_replacement, 1)
path.write_text(text, encoding="utf-8")
print("CLI-Sortierung ergänzt.")
PYCLI_SORT

chmod 755 "$LINK_TOOL"
fi

python3 -m py_compile "$APP_FILE"
[[ -f "$LINK_TOOL" ]] && python3 -m py_compile "$LINK_TOOL"

systemctl restart pve-sensor-web.service
systemctl restart nginx

sleep 2

echo
echo "API-Test:"
curl -fsS http://127.0.0.1:9105/api/links | python3 -m json.tool || true

echo
echo "============================================================"
echo " MENÜ-SORTIERUNG INSTALLIERT"
echo "============================================================"
echo
echo "Webseite:"
echo "  Menü -> Dienste verwalten"
echo "  ↑ / ↓ zum Verschieben"
echo "  Sicherheitscode eingeben"
echo "  Sortierung speichern"
echo
echo "CLI-Beispiele:"
echo '  pve-dashboard-link move "NAS" top'
echo '  pve-dashboard-link move "Pi-hole" up'
echo '  pve-dashboard-link move "NetAlertX" 2'
echo
echo "Backup:"
echo "  $BACKUP"
echo "============================================================"

__PVE_DASHBOARD_SORT_PAYLOAD__

    chmod 700 "$sort_tmp"
    bash "$sort_tmp"
    rm -f "$sort_tmp"

    ok "Beliebige Service-Menü-Sortierung ist installiert."
}


# =============================================================================
# DASHBOARD ROUTER + DOMAIN-SPEICHER-FIX V3
# =============================================================================

install_dashboard_router_domain_fix() {
    header "DASHBOARD ROUTER + DOMAIN-SPEICHER-FIX"

    local patch="/tmp/pve-dashboard-router-domain-fix.$$"

    cat > "$patch" <<'__PVE_ROUTER_DOMAIN_FIX__'
#!/usr/bin/env bash
set -Eeuo pipefail

STAMP="$(date +%d-%m-%H-%M)"
LOGFILE="/root/diagnose/diagnose-dashboard-menu-fix-${STAMP}.txt"
if [[ -e "$LOGFILE" ]]; then
    N=2
    while [[ -e "/root/diagnose/diagnose-dashboard-menu-fix-${STAMP}-${N}.txt" ]]; do
        N=$((N + 1))
    done
    LOGFILE="/root/diagnose/diagnose-dashboard-menu-fix-${STAMP}-${N}.txt"
fi
exec > >(tee -a "$LOGFILE") 2>&1

[[ ${EUID:-$(id -u)} -eq 0 ]] || {
    echo "FEHLER: Bitte als root auf dem Proxmox-Host ausführen."
    exit 1
}

APP="/opt/nodezero/dashboard/app.py"
INDEX="/opt/nodezero/dashboard/static/index.html"
LINKS="/var/lib/pve-sensor-dashboard-web/links.json"
STAMP2="$(date +%Y%m%d-%H%M%S)"
BACKUP="/root/backups/pve-dashboard-menu-v3-backup-${STAMP2}"

[[ -f "$APP" ]] || { echo "FEHLER: $APP nicht gefunden."; exit 1; }
[[ -f "$INDEX" ]] || { echo "FEHLER: $INDEX nicht gefunden."; exit 1; }

ROUTER_IP="$(
    ip -4 route show default 2>/dev/null |
    awk '{print $3; exit}'
)"
ROUTER_IP="${ROUTER_IP:-192.168.178.1}"

echo "============================================================"
echo " DASHBOARD SERVICE-MENÜ V3"
echo "============================================================"
echo
echo "Router/Gateway:"
echo "  $ROUTER_IP"
echo
echo "Log:"
echo "  $LOGFILE"
echo

mkdir -p "$BACKUP"
cp -a "$APP" "$BACKUP/app.py"
cp -a "$INDEX" "$BACKUP/index.html"
[[ -f "$LINKS" ]] && cp -a "$LINKS" "$BACKUP/links.json"

ROUTER_IP="$ROUTER_IP" python3 - "$APP" "$INDEX" "$LINKS" <<'PY'
from pathlib import Path
from urllib.parse import urlparse
import json
import os
import re
import sys

app_path = Path(sys.argv[1])
index_path = Path(sys.argv[2])
links_path = Path(sys.argv[3])
router_ip = os.environ["ROUTER_IP"].strip()

app = app_path.read_text(encoding="utf-8")
index = index_path.read_text(encoding="utf-8")

def replace_one(text, pattern, replacement, label, flags=re.S):
    new, count = re.subn(pattern, lambda _m: replacement, text, count=1, flags=flags)
    if count != 1:
        raise SystemExit(f"FEHLER: {label} konnte nicht eindeutig gefunden werden.")
    return new

normalize = r'''def normalize_service_url(value):
    value = str(value or "").strip()

    if not value:
        raise ValueError("Adresse/URL fehlt.")

    if len(value) > 500:
        raise ValueError("Adresse/URL ist zu lang.")

    if any(ch.isspace() for ch in value):
        raise ValueError("Adresse/URL darf keine Leerzeichen enthalten.")

    if value.startswith("//"):
        value = "http:" + value
    elif "://" not in value:
        value = "http://" + value

    parsed = urlparse(value)

    if parsed.scheme.lower() not in ("http", "https"):
        raise ValueError("Nur HTTP- oder HTTPS-Adressen sind erlaubt.")

    if not parsed.netloc or not parsed.hostname:
        raise ValueError("Domain, Hostname oder IP-Adresse ist ungültig.")

    try:
        _ = parsed.port
    except ValueError:
        raise ValueError("Portangabe ist ungültig.")

    scheme = parsed.scheme.lower()
    if scheme != parsed.scheme:
        value = scheme + value[len(parsed.scheme):]

    return value


'''

app = replace_one(
    app,
    r'def normalize_service_url\(value\):.*?(?=def read_service_links\(\):)',
    normalize,
    "normalize_service_url()",
)

app = app.replace("    return out[:30]\n", "    return out[:100]\n")

write_func = r'''def pin_router_first(links):
    links = list(links or [])
    router = None
    rest = []

    for item in links:
        if str(item.get("id", "")).strip() == "router":
            if router is None:
                router = item
            continue
        rest.append(item)

    return ([router] if router else []) + rest


def write_service_links(links):
    LINKS_FILE.parent.mkdir(parents=True, exist_ok=True)

    links = pin_router_first(links)
    temp = LINKS_FILE.with_suffix(".tmp")

    with _links_lock:
        temp.write_text(
            json.dumps(links, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        temp.chmod(0o600)
        temp.replace(LINKS_FILE)


'''

app = replace_one(
    app,
    r'def write_service_links\(links\):.*?(?=def verify_control_request\(payload\):)',
    write_func,
    "write_service_links()",
)

if "    return out[:100]\n" in app:
    app = app.replace(
        "    return out[:100]\n",
        "    out = pin_router_first(out)\n    return out[:100]\n",
        1,
    )

save_route = r'''@app.post("/api/links/save")
def save_service_link():
    payload = request.get_json(silent=True) or {}

    allowed, error = verify_control_request(payload)
    if not allowed:
        return error

    name = str(payload.get("name", "")).strip()

    if not name:
        return jsonify({"error": "Name fehlt."}), 400

    if len(name) > 50:
        return jsonify({"error": "Name darf höchstens 50 Zeichen haben."}), 400

    try:
        url = normalize_service_url(payload.get("url", ""))
    except ValueError as exc:
        return jsonify({"error": str(exc)}), 400

    target = str(payload.get("target", "new")).strip()
    if target not in ("new", "same"):
        target = "new"

    requested_id = str(payload.get("id") or "").strip()

    if requested_id == "router":
        return jsonify({
            "error": "Der Router ist ein automatischer Systemeintrag."
        }), 400

    links = read_service_links()

    if requested_id:
        saved = None

        for item in links:
            if item["id"] == requested_id:
                item["name"] = name
                item["url"] = url
                item["target"] = target
                saved = item
                break

        if saved is None:
            return jsonify({"error": "Eintrag wurde nicht gefunden."}), 404

        link_id = requested_id

    else:
        if len(links) >= 100:
            return jsonify({"error": "Maximal 100 Dienste sind möglich."}), 400

        link_id = secrets.token_hex(6)
        saved = {
            "id": link_id,
            "name": name,
            "url": url,
            "target": target,
        }
        links.append(saved)

    try:
        write_service_links(links)
        verified_links = read_service_links()
    except Exception as exc:
        app.logger.exception("Service-Link konnte nicht gespeichert werden")
        return jsonify({
            "error": f"Speichern fehlgeschlagen: {exc}"
        }), 500

    verified = next(
        (item for item in verified_links if item["id"] == link_id),
        None,
    )

    if verified is None:
        return jsonify({
            "error": "Eintrag wurde geschrieben, konnte aber nicht erneut gelesen werden."
        }), 500

    return jsonify({
        "ok": True,
        "id": link_id,
        "item": verified,
        "links": verified_links,
    })


'''

app = replace_one(
    app,
    r'@app\.post\("/api/links/save"\)\ndef save_service_link\(\):.*?(?=@app\.post\("/api/links/reorder"\)|@app\.post\("/api/links/delete"\))',
    save_route,
    "save_service_link()",
)

if '@app.post("/api/links/reorder")' in app:
    reorder_route = r'''@app.post("/api/links/reorder")
def reorder_service_links():
    payload = request.get_json(silent=True) or {}

    allowed, error = verify_control_request(payload)
    if not allowed:
        return error

    requested_ids = payload.get("ids", [])

    if not isinstance(requested_ids, list):
        return jsonify({"error": "Ungültige Sortierung."}), 400

    requested_ids = [str(x).strip() for x in requested_ids]

    if not requested_ids or any(not x for x in requested_ids):
        return jsonify({"error": "Ungültige Sortierung."}), 400

    if len(requested_ids) != len(set(requested_ids)):
        return jsonify({"error": "Eine Eintrag-ID kommt mehrfach vor."}), 400

    links = read_service_links()
    current_ids = [item["id"] for item in links]

    if len(requested_ids) != len(current_ids) or set(requested_ids) != set(current_ids):
        return jsonify({
            "error": "Die Linkliste hat sich geändert. Bitte neu laden."
        }), 409

    if "router" in current_ids:
        requested_ids = ["router"] + [
            link_id for link_id in requested_ids
            if link_id != "router"
        ]

    by_id = {item["id"]: item for item in links}
    reordered = [by_id[link_id] for link_id in requested_ids]

    write_service_links(reordered)

    return jsonify({
        "ok": True,
        "links": read_service_links(),
    })


'''
    app = replace_one(
        app,
        r'@app\.post\("/api/links/reorder"\)\ndef reorder_service_links\(\):.*?(?=@app\.post\("/api/links/delete"\))',
        reorder_route,
        "reorder_service_links()",
    )

delete_pat = r'(@app\.post\("/api/links/delete"\)\ndef delete_service_link\(\):.*?link_id = str\(payload\.get\("id", ""\)\)\.strip\(\)\n)'
m = re.search(delete_pat, app, re.S)
if not m:
    raise SystemExit("FEHLER: delete_service_link() konnte nicht gefunden werden.")
inject = m.group(1) + '''
    if link_id == "router":
        return jsonify({
            "error": "Der Router ist ein automatischer Systemeintrag."
        }), 400
'''
app = app[:m.start()] + inject + app[m.end():]

app = app.replace("# PVE_SERVICE_MENU_API_V1", "# PVE_SERVICE_MENU_API_V3")
app = app.replace("# PVE_SERVICE_MENU_API_V2", "# PVE_SERVICE_MENU_API_V3")
app = app.replace("# PVE_SERVICE_MENU_SORT_API_V1", "# PVE_SERVICE_MENU_SORT_API_V2")

index = index.replace(
    'Hier kannst du interne Webseiten hinzufügen. Beispiele:',
    'Hier kannst du IP-Adressen, Hostnamen und Domains hinzufügen. Beispiele:',
)
index = index.replace(
    'placeholder="192.168.178.183:5001"',
    'placeholder="nas.local oder 192.168.178.183:5001"',
)

render_manager = r'''function renderLinkManagerList(){
  const box=$('linkList');
  if(!box)return;

  box.innerHTML='';

  if(!serviceLinks.length){
    const row=document.createElement('div');
    row.className='linkRow';
    row.textContent='Noch keine Dienste eingetragen.';
    box.appendChild(row);
    updateSortState();
    return;
  }

  serviceLinks.forEach((item,index)=>{
    const row=document.createElement('div');
    row.className='linkRow';

    const main=document.createElement('div');
    main.className='linkRowMain';

    const name=document.createElement('div');
    name.className='linkRowName';
    name.textContent=`${index+1}. ${item.name}`;

    const url=document.createElement('div');
    url.className='linkRowUrl';
    url.textContent=item.url;

    const actions=document.createElement('div');
    actions.className='linkRowActions';

    if(item.id==='router'){
      const fixed=document.createElement('span');
      fixed.className='sortHint';
      fixed.textContent='Router · fest';
      actions.append(fixed);
    }else{
      const up=document.createElement('button');
      up.type='button';
      up.className='linkSortBtn';
      up.textContent='↑';
      up.title='Nach oben';
      up.setAttribute('aria-label',`${item.name} nach oben`);
      up.disabled=index<=1;
      up.onclick=()=>moveLink(item.id,-1);

      const down=document.createElement('button');
      down.type='button';
      down.className='linkSortBtn';
      down.textContent='↓';
      down.title='Nach unten';
      down.setAttribute('aria-label',`${item.name} nach unten`);
      down.disabled=index===serviceLinks.length-1;
      down.onclick=()=>moveLink(item.id,1);

      const edit=document.createElement('button');
      edit.type='button';
      edit.textContent='Bearbeiten';
      edit.onclick=()=>editLink(item.id);

      actions.append(up,down,edit);
    }

    main.append(name,url);
    row.append(main,actions);
    box.appendChild(row);
  });

  updateSortState();
}
'''

index = replace_one(
    index,
    r'function renderLinkManagerList\(\)\{.*?(?=function updateSortState\(\)\{)',
    render_manager,
    "renderLinkManagerList()",
)

move_func = r'''function moveLink(id,delta){
  if(id==='router')return;

  const index=serviceLinks.findIndex(x=>x.id===id);
  if(index<0)return;

  const next=index+delta;
  if(next<1||next>=serviceLinks.length)return;

  const copy=[...serviceLinks];
  [copy[index],copy[next]]=[copy[next],copy[index]];
  serviceLinks=copy;
  linkOrderDirty=true;

  renderServiceLinks();
  renderLinkManagerList();
}

'''

index = replace_one(
    index,
    r'function moveLink\(id,delta\)\{.*?(?=async function saveLinkOrder\(\)\{)',
    move_func,
    "moveLink()",
)

edit_func = r'''function editLink(id){
  if(id==='router'){
    $('linkMsg').textContent='Der Router wird automatisch aus dem Proxmox-Gateway übernommen.';
    $('linkMsg').className='msg';
    return;
  }

  const item=serviceLinks.find(x=>x.id===id);
  if(!item)return;

  editingLinkId=item.id;
  $('linkName').value=item.name;
  $('linkUrl').value=item.url;
  $('linkTarget').value=item.target||'new';
  $('linkCode').value='';
  $('linkDelete').style.display='';
  $('linkMsg').textContent='Eintrag wird bearbeitet.';
  $('linkMsg').className='msg';
}

'''

index = replace_one(
    index,
    r'function editLink\(id\)\{.*?(?=function clearLinkForm\(\)\{)',
    edit_func,
    "editLink()",
)

save_js = r'''async function saveLink(){
  const name=$('linkName').value.trim();
  const url=$('linkUrl').value.trim();
  const code=$('linkCode').value;

  if(!name||!url){
    $('linkMsg').textContent='Name und Adresse müssen ausgefüllt sein.';
    $('linkMsg').className='msg err';
    return;
  }

  if(code.length<6){
    $('linkMsg').textContent='Bitte den Dashboard-Sicherheitscode eingeben.';
    $('linkMsg').className='msg err';
    return;
  }

  $('linkSave').disabled=true;

  try{
    const payload={
      name,
      url,
      target:$('linkTarget').value,
      code
    };

    if(editingLinkId){
      payload.id=editingLinkId;
    }

    const d=await getJSON('/api/links/save',{
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify(payload)
    });

    serviceLinks=await getJSON('/api/links');
    linkOrderDirty=false;

    renderServiceLinks();
    renderLinkManagerList();

    editingLinkId=d.id||null;

    if(d.item){
      $('linkName').value=d.item.name||name;
      $('linkUrl').value=d.item.url||url;
      $('linkTarget').value=d.item.target||'new';
    }

    $('linkCode').value='';
    $('linkDelete').style.display=editingLinkId ? '' : 'none';

    $('linkMsg').textContent=`Gespeichert: ${$('linkUrl').value}`;
    $('linkMsg').className='msg ok';

  }catch(e){
    $('linkMsg').textContent=e.message;
    $('linkMsg').className='msg err';
  }finally{
    $('linkSave').disabled=false;
  }
}

'''

index = replace_one(
    index,
    r'async function saveLink\(\)\{.*?(?=async function deleteLink\(\)\{)',
    save_js,
    "saveLink()",
)

index = index.replace("PVE_SERVICE_MENU_UI_V1", "PVE_SERVICE_MENU_UI_V3")
index = index.replace("PVE_SERVICE_MENU_UI_V2", "PVE_SERVICE_MENU_UI_V3")
index = index.replace("PVE_SERVICE_MENU_SORT_UI_V1", "PVE_SERVICE_MENU_SORT_UI_V2")

try:
    links = json.loads(links_path.read_text(encoding="utf-8")) if links_path.exists() else []
except Exception:
    links = []

if not isinstance(links, list):
    links = []

router_url = f"http://{router_ip}/"
clean = []

for item in links:
    if not isinstance(item, dict):
        continue

    item_id = str(item.get("id", "")).strip()
    name = str(item.get("name", "")).strip().lower()
    url = str(item.get("url", "")).strip()

    is_router = item_id == "router"
    is_router_name = name in {"router", "fritzbox", "fritz!box", "router / fritzbox"}

    host = ""
    try:
        candidate = url if "://" in url else "http://" + url
        host = urlparse(candidate).hostname or ""
    except Exception:
        pass

    if is_router or is_router_name or host == router_ip:
        continue

    clean.append(item)

router_item = {
    "id": "router",
    "name": "Router",
    "url": router_url,
    "target": "new",
}
links = [router_item] + clean

compile(app, str(app_path), "exec")

app_path.write_text(app, encoding="utf-8")
index_path.write_text(index, encoding="utf-8")

links_path.parent.mkdir(parents=True, exist_ok=True)
links_path.write_text(
    json.dumps(links, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)

print("[OK] Backend aktualisiert.")
print("[OK] Frontend aktualisiert.")
print(f"[OK] Router auf Position 1: {router_url}")
print("[OK] Domain-/Hostname-Speichern mit Read-Back-Prüfung aktiviert.")
PY

chown pve-monitor:pve-monitor "$(dirname "$LINKS")"
chown pve-monitor:pve-monitor "$LINKS"
chmod 700 "$(dirname "$LINKS")"
chmod 600 "$LINKS"

python3 -m py_compile "$APP"

systemctl restart pve-sensor-web.service
systemctl restart nginx

sleep 2

echo
echo "API-Test:"
curl -fsS http://127.0.0.1:9105/api/links | python3 -m json.tool

echo
echo "============================================================"
echo " FERTIG"
echo "============================================================"
echo
echo "Router:"
echo "  http://${ROUTER_IP}/"
echo "  immer Position 1"
echo
echo "Unterstützte Eingaben:"
echo "  nas.local"
echo "  server.home"
echo "  192.168.178.183"
echo "  192.168.178.183:5001"
echo "  https://mein-server.local"
echo
echo "Browser anschließend einmal mit STRG+F5 neu laden."
echo
echo "Backup:"
echo "  $BACKUP"
echo
echo "Log:"
echo "  $LOGFILE"
echo "============================================================"

__PVE_ROUTER_DOMAIN_FIX__

    chmod 700 "$patch"
    bash "$patch"
    rm -f "$patch"

    ok "Router ist fest auf Position 1 und Domain-Speichern wurde aktualisiert."
}


# =============================================================================
# FRITZ!BOX / ROUTER FEST GANZ OBEN IM SERVER-MENÜ
# =============================================================================

install_dashboard_router_top_link() {
    header "FRITZ!BOX / ROUTER GANZ OBEN"

    local patch="/tmp/pve-dashboard-router-top.$$"

    cat > "$patch" <<'__PVE_ROUTER_TOP__'
#!/usr/bin/env bash
set -Eeuo pipefail

STAMP="$(date +%d-%m-%H-%M)"
LOGFILE="/root/diagnose/diagnose-dashboard-router-top-${STAMP}.txt"

if [[ -e "$LOGFILE" ]]; then
    N=2
    while [[ -e "/root/diagnose/diagnose-dashboard-router-top-${STAMP}-${N}.txt" ]]; do
        N=$((N + 1))
    done
    LOGFILE="/root/diagnose/diagnose-dashboard-router-top-${STAMP}-${N}.txt"
fi

exec > >(tee -a "$LOGFILE") 2>&1

[[ ${EUID:-$(id -u)} -eq 0 ]] || {
    echo "FEHLER: Bitte als root auf dem Proxmox-Host ausführen."
    exit 1
}

INDEX="/opt/nodezero/dashboard/static/index.html"
LINKS="/var/lib/pve-sensor-dashboard-web/links.json"
BACKUP="/root/backups/pve-dashboard-router-top-backup-$(date +%Y%m%d-%H%M%S)"

[[ -f "$INDEX" ]] || {
    echo "FEHLER: $INDEX nicht gefunden."
    exit 1
}

ROUTER_IP="$(
    ip -4 route show default 2>/dev/null |
    awk '{print $3; exit}'
)"
ROUTER_IP="${ROUTER_IP:-192.168.178.1}"
ROUTER_URL="http://${ROUTER_IP}/"

echo "============================================================"
echo " DASHBOARD - FRITZ!BOX / ROUTER GANZ OBEN"
echo "============================================================"
echo
echo "Router-IP:"
echo "  $ROUTER_IP"
echo
echo "URL:"
echo "  $ROUTER_URL"
echo
echo "Log:"
echo "  $LOGFILE"
echo

mkdir -p "$BACKUP"
cp -a "$INDEX" "$BACKUP/index.html"
[[ -f "$LINKS" ]] && cp -a "$LINKS" "$BACKUP/links.json"

ROUTER_IP="$ROUTER_IP" python3 - "$INDEX" "$LINKS" <<'PY'
from pathlib import Path
import json
import os
import re
import sys

index_path = Path(sys.argv[1])
links_path = Path(sys.argv[2])
router_ip = os.environ["ROUTER_IP"].strip()
router_url = "http://{}/".format(router_ip)

text = index_path.read_text(encoding="utf-8")

marker = "<!-- PVE_ROUTER_TOP_V1 -->"

router_block = (
    "\n"
    "  " + marker + "\n"
    '  <div class="navSection">Router</div>\n'
    "\n"
    '  <a class="navLink" href="' + router_url + '" target="_blank" rel="noopener noreferrer">\n'
    '    <span class="navIcon">FB</span>\n'
    '    <span class="navText">\n'
    '      <div class="navName">Fritz!Box / Router</div>\n'
    '      <div class="navUrl">' + router_url + '</div>\n'
    '    </span>\n'
    '  </a>\n'
)

if marker in text:
    pattern = re.compile(
        r'\s*<!-- PVE_ROUTER_TOP_V1 -->.*?'
        r'(?=\s*<div class="navSection">Dashboard</div>)',
        re.S,
    )

    text, count = pattern.subn(
        lambda _m: router_block + "\n",
        text,
        count=1,
    )

    if count != 1:
        raise SystemExit(
            "FEHLER: Vorhandener Router-Block konnte nicht aktualisiert werden."
        )
else:
    anchor = '  <div class="navSection">Dashboard</div>\n'

    if anchor not in text:
        raise SystemExit(
            "FEHLER: Dashboard-Menüanker wurde nicht gefunden."
        )

    text = text.replace(
        anchor,
        router_block + "\n" + anchor,
        1,
    )

# Router innerhalb der dynamischen Dienste-Liste ausblenden,
# damit er nicht doppelt angezeigt wird.
render_start = text.find("function renderServiceLinks(){")

if render_start < 0:
    raise SystemExit(
        "FEHLER: renderServiceLinks() wurde nicht gefunden."
    )

render_end = text.find(
    "\n}\n\nasync function loadServiceLinks",
    render_start,
)

if render_end < 0:
    raise SystemExit(
        "FEHLER: Ende von renderServiceLinks() wurde nicht gefunden."
    )

render = text[render_start:render_end]

if "serviceLinks.filter(item=>item.id!=='router').forEach(item=>" not in render:
    if "serviceLinks.forEach(item=>{" not in render:
        raise SystemExit(
            "FEHLER: Dienste-Rendering konnte nicht angepasst werden."
        )

    render = render.replace(
        "serviceLinks.forEach(item=>{",
        "serviceLinks.filter(item=>item.id!=='router').forEach(item=>{",
        1,
    )

text = text[:render_start] + render + text[render_end:]

index_path.write_text(text, encoding="utf-8")

# Router zusätzlich in links.json als Systemeintrag hinterlegen.
try:
    if links_path.exists():
        data = json.loads(
            links_path.read_text(encoding="utf-8")
        )
    else:
        data = []
except Exception:
    data = []

if not isinstance(data, list):
    data = []

rest = []

for item in data:
    if not isinstance(item, dict):
        continue

    if str(item.get("id", "")).strip() == "router":
        continue

    rest.append(item)

router = {
    "id": "router",
    "name": "Fritz!Box / Router",
    "url": router_url,
    "target": "new",
}

links_path.parent.mkdir(
    parents=True,
    exist_ok=True,
)

links_path.write_text(
    json.dumps(
        [router] + rest,
        ensure_ascii=False,
        indent=2,
    ) + "\n",
    encoding="utf-8",
)

print(
    "[OK] Fritz!Box / Router fest ganz oben: "
    + router_url
)
print(
    "[OK] Router wird in der dynamischen Dienste-Liste "
    "nicht doppelt angezeigt."
)
PY

if getent passwd pve-monitor >/dev/null 2>&1; then
    chown pve-monitor:pve-monitor "$LINKS" 2>/dev/null || true
    chmod 600 "$LINKS" 2>/dev/null || true
fi

systemctl restart pve-sensor-web.service
systemctl restart nginx

sleep 2

echo
echo "API-Linkliste:"
curl -fsS http://127.0.0.1:9105/api/links | python3 -m json.tool || true

echo
echo "============================================================"
echo " FERTIG"
echo "============================================================"
echo
echo "Im Server-Menü steht jetzt GANZ OBEN:"
echo
echo "  Fritz!Box / Router"
echo "  $ROUTER_URL"
echo
echo "Danach folgen:"
echo "  Dashboard"
echo "  Dienste"
echo
echo "Browser bitte einmal hart neu laden:"
echo "  STRG + F5"
echo
echo "Backup:"
echo "  $BACKUP"
echo
echo "Log:"
echo "  $LOGFILE"
echo "============================================================"
__PVE_ROUTER_TOP__

    chmod 700 "$patch"
    bash "$patch"
    rm -f "$patch"

    ok "Fritz!Box / Router ist fest als erster Menüpunkt eingetragen."
}



# =============================================================================
# FLEXIBLER DASHBOARD MENÜ-EDITOR V4
# =============================================================================

install_dashboard_menu_editor_v4() {
    header "DASHBOARD MENÜ-EDITOR V4"

    local patch="/tmp/pve-dashboard-menu-editor-v4.$$"

    cat > "$patch" <<'__PVE_MENU_EDITOR_V4__'
#!/usr/bin/env bash
set -Eeuo pipefail

STAMP="$(date +%d-%m-%H-%M)"
LOGFILE="/root/diagnose/diagnose-dashboard-menu-editor-${STAMP}.txt"

if [[ -e "$LOGFILE" ]]; then
    N=2
    while [[ -e "/root/diagnose/diagnose-dashboard-menu-editor-${STAMP}-${N}.txt" ]]; do
        N=$((N + 1))
    done
    LOGFILE="/root/diagnose/diagnose-dashboard-menu-editor-${STAMP}-${N}.txt"
fi

exec > >(tee -a "$LOGFILE") 2>&1

[[ ${EUID:-$(id -u)} -eq 0 ]] || {
    echo "FEHLER: Bitte als root auf dem Proxmox-Host ausführen."
    exit 1
}

APP="/opt/nodezero/dashboard/app.py"
INDEX="/opt/nodezero/dashboard/static/index.html"
LINKS="/var/lib/pve-sensor-dashboard-web/links.json"
CLI="/usr/local/sbin/pve-dashboard-link"
BACKUP="/root/backups/pve-dashboard-menu-editor-backup-$(date +%Y%m%d-%H%M%S)"

[[ -f "$APP" ]] || {
    echo "FEHLER: $APP nicht gefunden."
    exit 1
}

[[ -f "$INDEX" ]] || {
    echo "FEHLER: $INDEX nicht gefunden."
    exit 1
}

echo "============================================================"
echo " DASHBOARD MENÜ-EDITOR V4"
echo "============================================================"
echo
echo "Neue Elementtypen:"
echo "  - Link"
echo "  - Dropdown / Gruppe"
echo "  - Überschrift"
echo "  - Trennstrich"
echo "  - Abstandshalter"
echo
echo "Log:"
echo "  $LOGFILE"
echo

mkdir -p "$BACKUP"
cp -a "$APP" "$BACKUP/app.py"
cp -a "$INDEX" "$BACKUP/index.html"
[[ -f "$LINKS" ]] && cp -a "$LINKS" "$BACKUP/links.json"
[[ -f "$CLI" ]] && cp -a "$CLI" "$BACKUP/pve-dashboard-link"

python3 - "$APP" "$INDEX" "$LINKS" <<'PY'
from pathlib import Path
import json
import re
import secrets
import sys

app_path = Path(sys.argv[1])
index_path = Path(sys.argv[2])
links_path = Path(sys.argv[3])

app = app_path.read_text(encoding="utf-8")
index = index_path.read_text(encoding="utf-8")


def replace_one(text, pattern, replacement, label, flags=re.S):
    new, count = re.subn(
        pattern,
        lambda _m: replacement,
        text,
        count=1,
        flags=flags,
    )

    if count != 1:
        raise SystemExit(
            f"FEHLER: {label} konnte nicht eindeutig gefunden werden."
        )

    return new


backend_helpers = r'''def normalize_menu_item(item):
    if not isinstance(item, dict):
        return None

    item_id = str(item.get("id", "")).strip()

    if not item_id:
        return None

    item_type = str(item.get("type", "link")).strip().lower()

    if item_type not in ("link", "group", "heading", "separator", "spacer"):
        item_type = "link"

    if item_id == "router":
        item_type = "link"

    if item_type == "link":
        name = str(item.get("name", "")).strip()
        url = str(item.get("url", "")).strip()
        target = str(item.get("target", "new")).strip()
        group = str(item.get("group", "") or "").strip()

        if not name or not url:
            return None

        if target not in ("new", "same"):
            target = "new"

        return {
            "id": item_id,
            "type": "link",
            "name": name,
            "url": url,
            "target": target,
            "group": group,
        }

    if item_type in ("group", "heading"):
        name = str(item.get("name", "")).strip()

        if not name:
            return None

        out = {
            "id": item_id,
            "type": item_type,
            "name": name,
        }

        if item_type == "group":
            out["collapsed"] = bool(item.get("collapsed", False))

        return out

    return {
        "id": item_id,
        "type": item_type,
    }


def pin_router_first(items):
    items = list(items or [])
    router = None
    rest = []

    for item in items:
        if str(item.get("id", "")).strip() == "router":
            if router is None:
                router = item
            continue

        rest.append(item)

    return ([router] if router else []) + rest


def read_service_links():
    with _links_lock:
        try:
            data = json.loads(
                LINKS_FILE.read_text(encoding="utf-8")
            )
        except FileNotFoundError:
            return []
        except Exception:
            return []

    if not isinstance(data, list):
        return []

    out = []

    for raw in data:
        item = normalize_menu_item(raw)

        if item is not None:
            out.append(item)

    group_ids = {
        item["id"]
        for item in out
        if item.get("type") == "group"
    }

    for item in out:
        if item.get("type") == "link":
            group = str(item.get("group", "") or "")

            if group and group not in group_ids:
                item["group"] = ""

    return pin_router_first(out)[:100]


def write_service_links(items):
    LINKS_FILE.parent.mkdir(parents=True, exist_ok=True)

    normalized = []

    for raw in items or []:
        item = normalize_menu_item(raw)

        if item is not None:
            normalized.append(item)

    normalized = pin_router_first(normalized)

    temp = LINKS_FILE.with_suffix(".tmp")

    with _links_lock:
        temp.write_text(
            json.dumps(
                normalized,
                ensure_ascii=False,
                indent=2,
            ) + "\n",
            encoding="utf-8",
        )

        temp.chmod(0o600)
        temp.replace(LINKS_FILE)


def unique_menu_id(items):
    used = {
        str(item.get("id", ""))
        for item in items
        if isinstance(item, dict)
    }

    while True:
        ident = secrets.token_hex(6)

        if ident not in used:
            return ident


def group_ids(items):
    return {
        item["id"]
        for item in items
        if item.get("type") == "group"
    }


'''

app = replace_one(
    app,
    r'def read_service_links\(\):.*?(?=def verify_control_request\(payload\):)',
    backend_helpers,
    "Menü-Datenmodell",
)

save_route = r'''@app.post("/api/links/save")
def save_service_link():
    payload = request.get_json(silent=True) or {}

    allowed, error = verify_control_request(payload)
    if not allowed:
        return error

    requested_id = str(payload.get("id") or "").strip()

    if requested_id == "router":
        return jsonify({
            "error": "Der Router ist ein fester Systemeintrag."
        }), 400

    item_type = str(payload.get("type", "link")).strip().lower()

    if item_type not in ("link", "group", "heading", "separator", "spacer"):
        return jsonify({
            "error": "Ungültiger Elementtyp."
        }), 400

    items = read_service_links()

    if requested_id:
        saved = next(
            (
                item
                for item in items
                if item.get("id") == requested_id
            ),
            None,
        )

        if saved is None:
            return jsonify({
                "error": "Menüelement wurde nicht gefunden."
            }), 404
    else:
        if len(items) >= 100:
            return jsonify({
                "error": "Maximal 100 Menüelemente sind möglich."
            }), 400

        requested_id = unique_menu_id(items)
        saved = {
            "id": requested_id,
        }
        items.append(saved)

    saved.clear()
    saved["id"] = requested_id
    saved["type"] = item_type

    if item_type == "link":
        name = str(payload.get("name", "")).strip()

        if not name:
            return jsonify({"error": "Name fehlt."}), 400

        if len(name) > 50:
            return jsonify({
                "error": "Name darf höchstens 50 Zeichen haben."
            }), 400

        try:
            url = normalize_service_url(
                payload.get("url", "")
            )
        except ValueError as exc:
            return jsonify({
                "error": str(exc)
            }), 400

        target = str(
            payload.get("target", "new")
        ).strip()

        if target not in ("new", "same"):
            target = "new"

        group = str(
            payload.get("group", "") or ""
        ).strip()

        available_groups = group_ids(items)

        if group and group not in available_groups:
            return jsonify({
                "error": "Das ausgewählte Dropdown existiert nicht mehr."
            }), 400

        saved.update({
            "name": name,
            "url": url,
            "target": target,
            "group": group,
        })

    elif item_type in ("group", "heading"):
        name = str(payload.get("name", "")).strip()

        if not name:
            return jsonify({
                "error": "Bezeichnung fehlt."
            }), 400

        if len(name) > 50:
            return jsonify({
                "error": "Bezeichnung darf höchstens 50 Zeichen haben."
            }), 400

        saved["name"] = name

        if item_type == "group":
            saved["collapsed"] = bool(
                payload.get("collapsed", False)
            )

    try:
        write_service_links(items)
        verified_items = read_service_links()
    except Exception as exc:
        app.logger.exception(
            "Menüelement konnte nicht gespeichert werden"
        )

        return jsonify({
            "error": f"Speichern fehlgeschlagen: {exc}"
        }), 500

    verified = next(
        (
            item
            for item in verified_items
            if item.get("id") == requested_id
        ),
        None,
    )

    return jsonify({
        "ok": True,
        "id": requested_id,
        "item": verified,
        "links": verified_items,
    })


'''

app = replace_one(
    app,
    r'@app\.post\("/api/links/save"\)\ndef save_service_link\(\):.*?(?=@app\.post\("/api/links/reorder"\)|@app\.post\("/api/links/delete"\))',
    save_route,
    "save_service_link()",
)

reorder_route = r'''@app.post("/api/links/reorder")
def reorder_service_links():
    payload = request.get_json(silent=True) or {}

    allowed, error = verify_control_request(payload)
    if not allowed:
        return error

    requested_ids = payload.get("ids", [])

    if not isinstance(requested_ids, list):
        return jsonify({
            "error": "Ungültige Sortierung."
        }), 400

    requested_ids = [
        str(value).strip()
        for value in requested_ids
    ]

    if (
        not requested_ids
        or any(not value for value in requested_ids)
        or len(requested_ids) != len(set(requested_ids))
    ):
        return jsonify({
            "error": "Ungültige Sortierung."
        }), 400

    items = read_service_links()
    current_ids = [
        item["id"]
        for item in items
    ]

    if (
        len(requested_ids) != len(current_ids)
        or set(requested_ids) != set(current_ids)
    ):
        return jsonify({
            "error": "Die Menüliste hat sich geändert. Bitte neu laden."
        }), 409

    if "router" in current_ids:
        requested_ids = [
            "router"
        ] + [
            item_id
            for item_id in requested_ids
            if item_id != "router"
        ]

    by_id = {
        item["id"]: item
        for item in items
    }

    reordered = [
        by_id[item_id]
        for item_id in requested_ids
    ]

    write_service_links(reordered)

    return jsonify({
        "ok": True,
        "links": read_service_links(),
    })


'''

if '@app.post("/api/links/reorder")' in app:
    app = replace_one(
        app,
        r'@app\.post\("/api/links/reorder"\)\ndef reorder_service_links\(\):.*?(?=@app\.post\("/api/links/delete"\))',
        reorder_route,
        "reorder_service_links()",
    )
else:
    delete_anchor = '@app.post("/api/links/delete")'

    if delete_anchor not in app:
        raise SystemExit(
            "FEHLER: Delete-Route konnte nicht gefunden werden."
        )

    app = app.replace(
        delete_anchor,
        reorder_route + delete_anchor,
        1,
    )

delete_route = r'''@app.post("/api/links/delete")
def delete_service_link():
    payload = request.get_json(silent=True) or {}

    allowed, error = verify_control_request(payload)
    if not allowed:
        return error

    item_id = str(payload.get("id", "")).strip()

    if not item_id:
        return jsonify({
            "error": "Menüelement-ID fehlt."
        }), 400

    if item_id == "router":
        return jsonify({
            "error": "Der Router ist ein fester Systemeintrag."
        }), 400

    items = read_service_links()
    item = next(
        (
            value
            for value in items
            if value.get("id") == item_id
        ),
        None,
    )

    if item is None:
        return jsonify({
            "error": "Menüelement wurde nicht gefunden."
        }), 404

    if item.get("type") == "group":
        for value in items:
            if (
                value.get("type") == "link"
                and value.get("group") == item_id
            ):
                value["group"] = ""

    items = [
        value
        for value in items
        if value.get("id") != item_id
    ]

    write_service_links(items)

    return jsonify({
        "ok": True,
        "links": read_service_links(),
    })


'''

app = replace_one(
    app,
    r'@app\.post\("/api/links/delete"\)\ndef delete_service_link\(\):.*?(?=@app\.(?:get|post)\(|\Z)',
    delete_route,
    "delete_service_link()",
)

app = app.replace(
    "# PVE_SERVICE_MENU_API_V3",
    "# PVE_SERVICE_MENU_API_V4",
)

if "# PVE_SERVICE_MENU_API_V4" not in app:
    app = app.replace(
        "# PVE_SERVICE_MENU_API_V2",
        "# PVE_SERVICE_MENU_API_V4",
    )

menu_css = r'''
/* PVE_MENU_EDITOR_V4 */
.navCustomHeading{
  padding:14px 11px 6px;
  color:#8ea2bd;
  font-size:10px;
  font-weight:800;
  letter-spacing:.09em;
  text-transform:uppercase;
}
.navSeparator{
  height:1px;
  margin:10px 10px;
  background:#29384c;
}
.navSpacer{
  height:18px;
}
.navGroup{
  margin:2px 0 5px;
}
.navGroupToggle{
  width:100%;
  display:flex;
  align-items:center;
  gap:8px;
  padding:9px 11px;
  border:0;
  border-radius:8px;
  background:transparent;
  color:#d9e5f5;
  font-size:13px;
  font-weight:750;
  text-align:left;
  cursor:pointer;
}
.navGroupToggle:hover{
  background:#172437;
}
.navGroupArrow{
  width:15px;
  color:#8fa7c4;
  transition:transform .15s ease;
}
.navGroup.open .navGroupArrow{
  transform:rotate(90deg);
}
.navGroupChildren{
  display:none;
  margin-left:11px;
  padding-left:8px;
  border-left:1px solid #263850;
}
.navGroup.open .navGroupChildren{
  display:block;
}
.navGroupChildren .navLink{
  margin:1px 0;
}
.menuTypeBadge{
  display:inline-block;
  margin-right:7px;
  padding:2px 6px;
  border:1px solid #344a66;
  border-radius:999px;
  color:#9fb4cf;
  font-size:9px;
  font-weight:800;
  letter-spacing:.04em;
  text-transform:uppercase;
}
.menuRowMeta{
  margin-top:3px;
  color:#8194ad;
  font-size:10px;
}
.menuFormHidden{
  display:none !important;
}
.linkRowActions{
  display:flex;
  gap:5px;
  align-items:center;
}
'''

if "/* PVE_MENU_EDITOR_V4 */" not in index:
    if "</style>" not in index:
        raise SystemExit(
            "FEHLER: </style> im Dashboard nicht gefunden."
        )

    index = index.replace(
        "</style>",
        menu_css + "\n</style>",
        1,
    )

menu_modal = r'''<div class="modal" id="linksModal">
  <div class="dialog linkDialog">
    <h2>Menü bearbeiten</h2>
    <p>
      Hier kannst du das Server-Menü selbst aufbauen:
      Links, Dropdowns, Überschriften, Trennstriche und Abstandshalter.
    </p>

    <div id="linkList" class="linkList"></div>

    <div class="formGrid">
      <div>
        <label for="linkType">Elementtyp</label>
        <select id="linkType" onchange="updateMenuEditorForm()">
          <option value="link">Link</option>
          <option value="group">Dropdown / Gruppe</option>
          <option value="heading">Überschrift</option>
          <option value="separator">Trennstrich</option>
          <option value="spacer">Abstandshalter</option>
        </select>
      </div>

      <div id="menuNameWrap">
        <label for="linkName">Name / Bezeichnung</label>
        <input id="linkName" type="text" maxlength="50" placeholder="z. B. Monitoring">
      </div>

      <div id="menuUrlWrap">
        <label for="linkUrl">IP / Adresse / URL</label>
        <input id="linkUrl" type="text" maxlength="500" placeholder="nas.local oder 192.168.178.183:5001">
      </div>

      <div id="menuTargetWrap">
        <label for="linkTarget">Öffnen</label>
        <select id="linkTarget">
          <option value="new">Neuer Tab</option>
          <option value="same">Gleicher Tab</option>
        </select>
      </div>

      <div id="menuGroupWrap">
        <label for="linkGroup">In Dropdown</label>
        <select id="linkGroup">
          <option value="">Kein Dropdown</option>
        </select>
      </div>

      <div id="menuCollapsedWrap" class="menuFormHidden">
        <label for="linkCollapsed">Standardzustand</label>
        <select id="linkCollapsed">
          <option value="0">Geöffnet</option>
          <option value="1">Eingeklappt</option>
        </select>
      </div>

      <div>
        <label for="linkCode">Sicherheitscode</label>
        <input id="linkCode" type="password" autocomplete="off" placeholder="Dashboard-Steuer-Code">
      </div>

      <div class="full">
        <div id="sortState" class="sortHint">Reihenfolge mit ↑ / ↓ ändern.</div>
        <div id="linkMsg" class="msg"></div>
        <div class="smallHint">
          Fritz!Box / Router bleibt ein fester Systemeintrag.
          Beim Löschen eines Dropdowns bleiben dessen Links erhalten.
        </div>
      </div>
    </div>

    <div class="modalButtons">
      <button id="linkDelete" class="secondaryDanger" style="display:none" onclick="deleteLink()">Löschen</button>
      <button onclick="clearLinkForm()">Neu</button>
      <button onclick="closeLinkManager()">Schließen</button>
      <button id="linkSortSave" onclick="saveLinkOrder()">Sortierung speichern</button>
      <button id="linkSave" onclick="saveLink()">Element speichern</button>
    </div>
  </div>
</div>

'''

index = replace_one(
    index,
    r'<div class="modal" id="linksModal">.*?(?=<div class="modal" id="modal">)',
    menu_modal,
    "Menü-Editor Modal",
)

menu_js = r'''let serviceLinks=[];
let editingLinkId=null;
let linkOrderDirty=false;

function initials(name){
  const p=String(name||'').trim().split(/\s+/).filter(Boolean);
  if(!p.length)return 'WEB';
  if(p.length===1)return p[0].slice(0,3).toUpperCase();
  return (p[0][0]+p[1][0]).toUpperCase();
}

function menuType(item){
  return String(item?.type||'link');
}

function openNav(){
  $('navShade').classList.add('show');
  $('sideNav').classList.add('show');
}

function closeNav(){
  $('navShade').classList.remove('show');
  $('sideNav').classList.remove('show');
}

function makeNavLink(item,sub=false){
  const a=document.createElement('a');
  a.className='navLink';
  if(sub)a.classList.add('navSubLink');

  a.href=item.url;

  if(item.target!=='same'){
    a.target='_blank';
    a.rel='noopener noreferrer';
  }

  const icon=document.createElement('span');
  icon.className='navIcon';
  icon.textContent=initials(item.name);

  const tx=document.createElement('span');
  tx.className='navText';

  const nm=document.createElement('div');
  nm.className='navName';
  nm.textContent=item.name;

  const ur=document.createElement('div');
  ur.className='navUrl';
  ur.textContent=item.url;

  tx.append(nm,ur);
  a.append(icon,tx);

  return a;
}

function groupStorageKey(id){
  return `pve-menu-group-${id}`;
}

function groupCollapsed(item){
  const stored=localStorage.getItem(groupStorageKey(item.id));

  if(stored==='1')return true;
  if(stored==='0')return false;

  return !!item.collapsed;
}

function toggleMenuGroup(id){
  const group=$(`menuGroup-${id}`);
  if(!group)return;

  const open=!group.classList.contains('open');
  group.classList.toggle('open',open);

  localStorage.setItem(
    groupStorageKey(id),
    open ? '0' : '1'
  );
}

function renderServiceLinks(){
  const box=$('serviceNavLinks');
  box.innerHTML='';

  const dynamic=serviceLinks.filter(item=>item.id!=='router');

  if(!dynamic.length){
    const empty=document.createElement('div');
    empty.className='navUrl';
    empty.style.padding='9px 11px';
    empty.textContent='Noch keine Menüelemente eingetragen';
    box.appendChild(empty);
    return;
  }

  const groups=new Map(
    dynamic
      .filter(item=>menuType(item)==='group')
      .map(item=>[item.id,item])
  );

  const groupChildren=new Map();

  for(const item of dynamic){
    if(
      menuType(item)==='link'
      && item.group
      && groups.has(item.group)
    ){
      if(!groupChildren.has(item.group)){
        groupChildren.set(item.group,[]);
      }
      groupChildren.get(item.group).push(item);
    }
  }

  for(const item of dynamic){
    const type=menuType(item);

    if(
      type==='link'
      && item.group
      && groups.has(item.group)
    ){
      continue;
    }

    if(type==='link'){
      box.appendChild(makeNavLink(item));
      continue;
    }

    if(type==='heading'){
      const heading=document.createElement('div');
      heading.className='navCustomHeading';
      heading.textContent=item.name;
      box.appendChild(heading);
      continue;
    }

    if(type==='separator'){
      const line=document.createElement('div');
      line.className='navSeparator';
      box.appendChild(line);
      continue;
    }

    if(type==='spacer'){
      const spacer=document.createElement('div');
      spacer.className='navSpacer';
      box.appendChild(spacer);
      continue;
    }

    if(type==='group'){
      const wrap=document.createElement('div');
      wrap.className='navGroup';
      wrap.id=`menuGroup-${item.id}`;

      if(!groupCollapsed(item)){
        wrap.classList.add('open');
      }

      const btn=document.createElement('button');
      btn.type='button';
      btn.className='navGroupToggle';
      btn.onclick=()=>toggleMenuGroup(item.id);

      const arrow=document.createElement('span');
      arrow.className='navGroupArrow';
      arrow.textContent='›';

      const label=document.createElement('span');
      label.textContent=item.name;

      btn.append(arrow,label);

      const children=document.createElement('div');
      children.className='navGroupChildren';

      const links=groupChildren.get(item.id)||[];

      if(!links.length){
        const empty=document.createElement('div');
        empty.className='navUrl';
        empty.style.padding='7px 10px';
        empty.textContent='Keine Links';
        children.appendChild(empty);
      }else{
        links.forEach(link=>children.appendChild(makeNavLink(link,true)));
      }

      wrap.append(btn,children);
      box.appendChild(wrap);
    }
  }
}

function menuTypeLabel(type){
  return ({
    link:'Link',
    group:'Dropdown',
    heading:'Überschrift',
    separator:'Trennstrich',
    spacer:'Abstand'
  })[type]||type;
}

function refreshGroupChoices(selected=''){
  const select=$('linkGroup');
  if(!select)return;

  select.innerHTML='';

  const none=document.createElement('option');
  none.value='';
  none.textContent='Kein Dropdown';
  select.appendChild(none);

  serviceLinks
    .filter(item=>menuType(item)==='group' && item.id!==editingLinkId)
    .forEach(item=>{
      const option=document.createElement('option');
      option.value=item.id;
      option.textContent=item.name;
      select.appendChild(option);
    });

  select.value=selected||'';
}

function updateMenuEditorForm(){
  const type=$('linkType').value;

  const show=(id,value)=>{
    const el=$(id);
    if(!el)return;
    el.classList.toggle('menuFormHidden',!value);
  };

  show('menuNameWrap',['link','group','heading'].includes(type));
  show('menuUrlWrap',type==='link');
  show('menuTargetWrap',type==='link');
  show('menuGroupWrap',type==='link');
  show('menuCollapsedWrap',type==='group');

  if(type==='separator'){
    $('linkMsg').textContent='Trennstrich: erzeugt eine horizontale Linie im Menü.';
    $('linkMsg').className='msg';
  }else if(type==='spacer'){
    $('linkMsg').textContent='Abstandshalter: fügt etwas freien Platz im Menü ein.';
    $('linkMsg').className='msg';
  }
}

async function loadServiceLinks(){
  try{
    serviceLinks=await getJSON('/api/links');
    linkOrderDirty=false;
    renderServiceLinks();
    refreshGroupChoices();
    renderLinkManagerList();
  }catch(e){
    console.error(e);
  }
}

function openLinkManager(){
  closeNav();
  clearLinkForm();
  renderLinkManagerList();
  $('linksModal').classList.add('show');
  setTimeout(()=>$('linkType').focus(),80);
}

function closeLinkManager(){
  $('linksModal').classList.remove('show');
}

function renderLinkManagerList(){
  const box=$('linkList');
  if(!box)return;

  box.innerHTML='';

  if(!serviceLinks.length){
    const row=document.createElement('div');
    row.className='linkRow';
    row.textContent='Noch keine Menüelemente eingetragen.';
    box.appendChild(row);
    updateSortState();
    return;
  }

  const groups=new Map(
    serviceLinks
      .filter(item=>menuType(item)==='group')
      .map(item=>[item.id,item.name])
  );

  serviceLinks.forEach((item,index)=>{
    const type=menuType(item);
    const row=document.createElement('div');
    row.className='linkRow';

    const main=document.createElement('div');
    main.className='linkRowMain';

    const name=document.createElement('div');
    name.className='linkRowName';

    const badge=document.createElement('span');
    badge.className='menuTypeBadge';
    badge.textContent=item.id==='router' ? 'System' : menuTypeLabel(type);

    const title=document.createElement('span');
    title.textContent=
      type==='separator'
        ? 'Trennstrich'
        : type==='spacer'
          ? 'Abstandshalter'
          : item.name||'Ohne Namen';

    name.append(badge,title);

    const meta=document.createElement('div');
    meta.className='menuRowMeta';

    if(item.id==='router'){
      meta.textContent='Fester Router-Systemeintrag';
    }else if(type==='link'){
      const groupName=
        item.group && groups.has(item.group)
          ? ` · Dropdown: ${groups.get(item.group)}`
          : '';
      meta.textContent=`${item.url||''}${groupName}`;
    }else if(type==='group'){
      meta.textContent=item.collapsed ? 'Standard: eingeklappt' : 'Standard: geöffnet';
    }else if(type==='heading'){
      meta.textContent='Freie Menü-Überschrift';
    }else if(type==='separator'){
      meta.textContent='Horizontale Trennlinie';
    }else if(type==='spacer'){
      meta.textContent='Freier vertikaler Abstand';
    }

    const actions=document.createElement('div');
    actions.className='linkRowActions';

    if(item.id==='router'){
      const fixed=document.createElement('span');
      fixed.className='navUrl';
      fixed.textContent='fest';
      actions.appendChild(fixed);
    }else{
      const up=document.createElement('button');
      up.type='button';
      up.className='linkSortBtn';
      up.textContent='↑';
      up.disabled=index<=1;
      up.onclick=()=>moveLink(item.id,-1);

      const down=document.createElement('button');
      down.type='button';
      down.className='linkSortBtn';
      down.textContent='↓';
      down.disabled=index===serviceLinks.length-1;
      down.onclick=()=>moveLink(item.id,1);

      const edit=document.createElement('button');
      edit.type='button';
      edit.textContent='Bearbeiten';
      edit.onclick=()=>editLink(item.id);

      actions.append(up,down,edit);
    }

    main.append(name,meta);
    row.append(main,actions);
    box.appendChild(row);
  });

  updateSortState();
}

function updateSortState(){
  const el=$('sortState');
  if(!el)return;

  if(linkOrderDirty){
    el.textContent='Reihenfolge geändert – noch nicht gespeichert.';
    el.className='sortHint sortDirty';
  }else{
    el.textContent='Reihenfolge mit ↑ / ↓ ändern.';
    el.className='sortHint';
  }
}

function moveLink(id,delta){
  if(id==='router')return;

  const index=serviceLinks.findIndex(item=>item.id===id);
  if(index<0)return;

  const next=index+delta;
  if(next<1||next>=serviceLinks.length)return;

  const copy=[...serviceLinks];
  [copy[index],copy[next]]=[copy[next],copy[index]];
  serviceLinks=copy;
  linkOrderDirty=true;

  renderServiceLinks();
  renderLinkManagerList();
}

async function saveLinkOrder(){
  if(!linkOrderDirty){
    $('linkMsg').textContent='Die Reihenfolge wurde nicht geändert.';
    $('linkMsg').className='msg';
    return;
  }

  const code=$('linkCode').value;

  if(code.length<6){
    $('linkMsg').textContent='Zum Speichern der Sortierung den Sicherheitscode eingeben.';
    $('linkMsg').className='msg err';
    return;
  }

  const btn=$('linkSortSave');
  btn.disabled=true;

  try{
    const d=await getJSON('/api/links/reorder',{
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify({
        ids:serviceLinks.map(item=>item.id),
        code
      })
    });

    serviceLinks=d.links||[];
    linkOrderDirty=false;

    renderServiceLinks();
    refreshGroupChoices();
    renderLinkManagerList();

    $('linkMsg').textContent='Menü-Sortierung gespeichert.';
    $('linkMsg').className='msg ok';

  }catch(e){
    $('linkMsg').textContent=e.message;
    $('linkMsg').className='msg err';
  }finally{
    btn.disabled=false;
  }
}

function editLink(id){
  if(id==='router'){
    $('linkMsg').textContent='Der Router ist ein fester Systemeintrag.';
    $('linkMsg').className='msg';
    return;
  }

  const item=serviceLinks.find(value=>value.id===id);
  if(!item)return;

  editingLinkId=item.id;

  $('linkType').value=menuType(item);
  $('linkName').value=item.name||'';
  $('linkUrl').value=item.url||'';
  $('linkTarget').value=item.target||'new';
  $('linkCollapsed').value=item.collapsed ? '1' : '0';

  refreshGroupChoices(item.group||'');

  $('linkCode').value='';
  $('linkDelete').style.display='';

  $('linkMsg').textContent=`${menuTypeLabel(menuType(item))} wird bearbeitet.`;
  $('linkMsg').className='msg';

  updateMenuEditorForm();
}

function clearLinkForm(){
  editingLinkId=null;

  $('linkType').value='link';
  $('linkName').value='';
  $('linkUrl').value='';
  $('linkTarget').value='new';
  $('linkCollapsed').value='0';
  $('linkCode').value='';

  refreshGroupChoices('');

  $('linkDelete').style.display='none';
  $('linkMsg').textContent='';
  $('linkMsg').className='msg';

  updateMenuEditorForm();
}

async function saveLink(){
  const type=$('linkType').value;
  const code=$('linkCode').value;

  if(code.length<6){
    $('linkMsg').textContent='Bitte den Dashboard-Sicherheitscode eingeben.';
    $('linkMsg').className='msg err';
    return;
  }

  const payload={type,code};

  if(editingLinkId){
    payload.id=editingLinkId;
  }

  if(type==='link'){
    const name=$('linkName').value.trim();
    const url=$('linkUrl').value.trim();

    if(!name||!url){
      $('linkMsg').textContent='Für einen Link werden Name und Adresse benötigt.';
      $('linkMsg').className='msg err';
      return;
    }

    payload.name=name;
    payload.url=url;
    payload.target=$('linkTarget').value;
    payload.group=$('linkGroup').value;

  }else if(type==='group'||type==='heading'){
    const name=$('linkName').value.trim();

    if(!name){
      $('linkMsg').textContent='Bitte eine Bezeichnung eingeben.';
      $('linkMsg').className='msg err';
      return;
    }

    payload.name=name;

    if(type==='group'){
      payload.collapsed=$('linkCollapsed').value==='1';
    }
  }

  $('linkSave').disabled=true;

  try{
    const d=await getJSON('/api/links/save',{
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify(payload)
    });

    serviceLinks=d.links||[];
    editingLinkId=d.id||null;
    linkOrderDirty=false;

    renderServiceLinks();
    refreshGroupChoices(d.item?.group||'');
    renderLinkManagerList();

    $('linkCode').value='';
    $('linkDelete').style.display=editingLinkId ? '' : 'none';

    $('linkMsg').textContent='Menüelement gespeichert.';
    $('linkMsg').className='msg ok';

  }catch(e){
    $('linkMsg').textContent=e.message;
    $('linkMsg').className='msg err';
  }finally{
    $('linkSave').disabled=false;
  }
}

async function deleteLink(){
  if(!editingLinkId)return;

  const item=serviceLinks.find(value=>value.id===editingLinkId);
  const code=$('linkCode').value;

  if(code.length<6){
    $('linkMsg').textContent='Zum Löschen den Dashboard-Sicherheitscode eingeben.';
    $('linkMsg').className='msg err';
    return;
  }

  const label=item?.name||menuTypeLabel(menuType(item));

  if(!confirm(`Menüelement "${label}" wirklich löschen?`))return;

  $('linkDelete').disabled=true;

  try{
    const d=await getJSON('/api/links/delete',{
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify({
        id:editingLinkId,
        code
      })
    });

    serviceLinks=d.links||[];
    editingLinkId=null;
    linkOrderDirty=false;

    renderServiceLinks();
    refreshGroupChoices();
    renderLinkManagerList();
    clearLinkForm();

    $('linkMsg').textContent='Menüelement gelöscht.';
    $('linkMsg').className='msg ok';

  }catch(e){
    $('linkMsg').textContent=e.message;
    $('linkMsg').className='msg err';
  }finally{
    $('linkDelete').disabled=false;
  }
}

'''

index = replace_one(
    index,
    r'let serviceLinks=\[\];.*?(?=document\.addEventListener\(\'keydown\',e=>\{)',
    menu_js,
    "Menü-JavaScript",
)

index = index.replace(
    "PVE_SERVICE_MENU_UI_V3",
    "PVE_SERVICE_MENU_UI_V4",
)

try:
    raw_items = json.loads(
        links_path.read_text(encoding="utf-8")
    ) if links_path.exists() else []
except Exception:
    raw_items = []

if not isinstance(raw_items, list):
    raw_items = []

migrated = []

for raw in raw_items:
    if not isinstance(raw, dict):
        continue

    item_id = str(raw.get("id", "")).strip() or secrets.token_hex(6)
    item_type = str(raw.get("type", "link")).strip().lower()

    if item_type not in ("link", "group", "heading", "separator", "spacer"):
        item_type = "link"

    if item_id == "router":
        item_type = "link"

    item = {"id": item_id, "type": item_type}

    if item_type == "link":
        name = str(raw.get("name", "")).strip()
        url = str(raw.get("url", "")).strip()

        if not name or not url:
            continue

        item.update({
            "name": name,
            "url": url,
            "target": raw.get("target", "new") if raw.get("target") in ("new", "same") else "new",
            "group": str(raw.get("group", "") or "").strip(),
        })

    elif item_type in ("group", "heading"):
        name = str(raw.get("name", "")).strip()

        if not name:
            continue

        item["name"] = name

        if item_type == "group":
            item["collapsed"] = bool(raw.get("collapsed", False))

    migrated.append(item)

router = [item for item in migrated if item.get("id") == "router"]
rest = [item for item in migrated if item.get("id") != "router"]
migrated = router[:1] + rest

compile(app, str(app_path), "exec")

app_tmp = app_path.with_suffix(".py.v4")
index_tmp = index_path.with_suffix(".html.v4")
links_tmp = links_path.with_suffix(".json.v4")

app_tmp.write_text(app, encoding="utf-8")
index_tmp.write_text(index, encoding="utf-8")

links_tmp.parent.mkdir(parents=True, exist_ok=True)
links_tmp.write_text(
    json.dumps(migrated, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)

app_tmp.replace(app_path)
index_tmp.replace(index_path)
links_tmp.replace(links_path)

print("[OK] Backend auf Menü-Schema V4 erweitert.")
print("[OK] Menü-Editor eingebaut.")
print("[OK] Bestehende Links wurden automatisch migriert.")
PY

cat > "$CLI" <<'PYCLI'
#!/usr/bin/env python3

import argparse
import json
import os
import pwd
import secrets
from pathlib import Path
from urllib.parse import urlparse

LINKS_FILE = Path("/var/lib/pve-sensor-dashboard-web/links.json")
MAX_ITEMS = 100
VALID_TYPES = {"link", "group", "heading", "separator", "spacer"}


def normalize_url(value):
    value = str(value or "").strip()

    if not value:
        raise ValueError("Adresse/URL fehlt.")

    if any(ch.isspace() for ch in value):
        raise ValueError("Adresse/URL darf keine Leerzeichen enthalten.")

    if value.startswith("//"):
        value = "http:" + value
    elif "://" not in value:
        value = "http://" + value

    parsed = urlparse(value)

    if parsed.scheme.lower() not in ("http", "https") or not parsed.netloc or not parsed.hostname:
        raise ValueError("Nur gültige HTTP-/HTTPS-Adressen sind erlaubt.")

    try:
        _ = parsed.port
    except ValueError:
        raise ValueError("Portangabe ist ungültig.")

    return value


def normalize_item(raw):
    if not isinstance(raw, dict):
        return None

    item_id = str(raw.get("id", "")).strip()

    if not item_id:
        return None

    item_type = str(raw.get("type", "link")).strip().lower()

    if item_type not in VALID_TYPES:
        item_type = "link"

    if item_id == "router":
        item_type = "link"

    if item_type == "link":
        name = str(raw.get("name", "")).strip()
        url = str(raw.get("url", "")).strip()

        if not name or not url:
            return None

        return {
            "id": item_id,
            "type": "link",
            "name": name,
            "url": url,
            "target": raw.get("target", "new") if raw.get("target") in ("new", "same") else "new",
            "group": str(raw.get("group", "") or "").strip(),
        }

    if item_type in ("group", "heading"):
        name = str(raw.get("name", "")).strip()

        if not name:
            return None

        item = {"id": item_id, "type": item_type, "name": name}

        if item_type == "group":
            item["collapsed"] = bool(raw.get("collapsed", False))

        return item

    return {"id": item_id, "type": item_type}


def read_items():
    if not LINKS_FILE.exists():
        return []

    try:
        data = json.loads(LINKS_FILE.read_text(encoding="utf-8"))
    except Exception as exc:
        raise SystemExit(f"FEHLER: links.json ist ungültig: {exc}")

    if not isinstance(data, list):
        raise SystemExit("FEHLER: links.json muss eine JSON-Liste enthalten.")

    out = []

    for raw in data:
        item = normalize_item(raw)
        if item is not None:
            out.append(item)

    router = [item for item in out if item.get("id") == "router"]
    rest = [item for item in out if item.get("id") != "router"]

    return router[:1] + rest


def write_items(items):
    LINKS_FILE.parent.mkdir(parents=True, exist_ok=True)

    temp = LINKS_FILE.with_suffix(".tmp")
    temp.write_text(
        json.dumps(items, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    temp.chmod(0o600)
    temp.replace(LINKS_FILE)

    try:
        pw = pwd.getpwnam("pve-monitor")
        os.chown(LINKS_FILE, pw.pw_uid, pw.pw_gid)
    except Exception:
        pass


def unique_id(items):
    used = {item["id"] for item in items}

    while True:
        ident = secrets.token_hex(6)
        if ident not in used:
            return ident


def find_item(items, selector):
    for item in items:
        if item["id"] == selector:
            return item

    matches = [
        item for item in items
        if str(item.get("name", "")).casefold() == selector.casefold()
    ]

    if len(matches) == 1:
        return matches[0]

    if len(matches) > 1:
        raise SystemExit("FEHLER: Mehrere Einträge mit diesem Namen. Bitte ID verwenden.")

    return None


def cmd_list(args):
    items = read_items()

    if not items:
        print("Keine Menüelemente vorhanden.")
        return

    groups = {
        item["id"]: item.get("name", "")
        for item in items
        if item.get("type") == "group"
    }

    print(f"{'ID':<14} {'TYP':<11} {'NAME':<28} INFO")
    print("-" * 100)

    for item in items:
        item_type = item.get("type", "link")
        name = item.get("name", "")

        if item_type == "link":
            info = item.get("url", "")
            if item.get("group"):
                info += " | Dropdown: " + groups.get(item["group"], item["group"])
        elif item_type == "group":
            info = "eingeklappt" if item.get("collapsed") else "geöffnet"
        else:
            info = ""

        print(f"{item['id']:<14} {item_type:<11} {name[:27]:<28} {info}")


def cmd_add(args):
    items = read_items()

    if len(items) >= MAX_ITEMS:
        raise SystemExit(f"FEHLER: Maximal {MAX_ITEMS} Menüelemente.")

    name = args.name.strip()

    if not name:
        raise SystemExit("FEHLER: Name fehlt.")

    url = normalize_url(args.url)

    for item in items:
        if item.get("type") == "link" and item.get("name", "").casefold() == name.casefold():
            item["url"] = url
            item["target"] = args.target
            write_items(items)
            print(f"Aktualisiert: {name} -> {url}")
            return

    items.append({
        "id": unique_id(items),
        "type": "link",
        "name": name,
        "url": url,
        "target": args.target,
        "group": "",
    })

    write_items(items)
    print(f"Hinzugefügt: {name} -> {url}")


def cmd_edit(args):
    items = read_items()
    item = find_item(items, args.selector)

    if item is None:
        raise SystemExit("FEHLER: Eintrag nicht gefunden.")

    if item["id"] == "router":
        raise SystemExit("FEHLER: Router ist ein fester Systemeintrag.")

    if item.get("type") != "link":
        raise SystemExit(
            "FEHLER: CLI edit unterstützt nur Links. Spezialelemente bitte im Dashboard-Editor bearbeiten."
        )

    if args.name is not None:
        value = args.name.strip()
        if not value:
            raise SystemExit("FEHLER: Neuer Name ist leer.")
        item["name"] = value

    if args.url is not None:
        item["url"] = normalize_url(args.url)

    if args.target is not None:
        item["target"] = args.target

    write_items(items)
    print(f"Geändert: {item['name']} -> {item['url']}")


def cmd_delete(args):
    items = read_items()
    item = find_item(items, args.selector)

    if item is None:
        raise SystemExit("FEHLER: Eintrag nicht gefunden.")

    if item["id"] == "router":
        raise SystemExit("FEHLER: Router ist ein fester Systemeintrag.")

    if item.get("type") == "group":
        for value in items:
            if value.get("type") == "link" and value.get("group") == item["id"]:
                value["group"] = ""

    items = [value for value in items if value["id"] != item["id"]]
    write_items(items)

    print(f"Gelöscht: {item.get('name') or item.get('type')}")


def cmd_move(args):
    items = read_items()
    item = find_item(items, args.selector)

    if item is None:
        raise SystemExit("FEHLER: Eintrag nicht gefunden.")

    if item["id"] == "router":
        raise SystemExit("FEHLER: Router ist fest auf Position 1.")

    old_index = next(
        index for index, value in enumerate(items)
        if value["id"] == item["id"]
    )

    position = str(args.position).strip().lower()

    if position == "top":
        new_index = 1 if items and items[0]["id"] == "router" else 0
    elif position == "bottom":
        new_index = len(items) - 1
    elif position == "up":
        minimum = 1 if items and items[0]["id"] == "router" else 0
        new_index = max(minimum, old_index - 1)
    elif position == "down":
        new_index = min(len(items) - 1, old_index + 1)
    else:
        try:
            requested = int(position)
        except ValueError:
            raise SystemExit(
                "FEHLER: Position muss up, down, top, bottom oder eine Zahl sein."
            )

        minimum = 2 if items and items[0]["id"] == "router" else 1

        if requested < minimum or requested > len(items):
            raise SystemExit(
                f"FEHLER: Position muss zwischen {minimum} und {len(items)} liegen."
            )

        new_index = requested - 1

    moved = items.pop(old_index)
    items.insert(new_index, moved)
    write_items(items)

    print(f"Verschoben -> Position {new_index + 1}")


def parse_import_line(line, lineno):
    line = line.strip()

    if not line or line.startswith("#"):
        return None

    parts = [value.strip() for value in line.split("|")]

    if len(parts) < 2 or len(parts) > 3:
        raise ValueError(
            f"Zeile {lineno}: NAME|URL oder NAME|URL|new/same erwartet."
        )

    name = parts[0]
    url = normalize_url(parts[1])
    target = parts[2].lower() if len(parts) == 3 and parts[2] else "new"

    if target not in ("new", "same"):
        raise ValueError(
            f"Zeile {lineno}: Ziel muss new oder same sein."
        )

    return name, url, target


def cmd_import(args):
    source = Path(args.file)

    if not source.is_file():
        raise SystemExit(f"FEHLER: Datei nicht gefunden: {source}")

    items = read_items()

    for lineno, raw in enumerate(
        source.read_text(encoding="utf-8").splitlines(),
        start=1,
    ):
        parsed = parse_import_line(raw, lineno)

        if parsed is None:
            continue

        name, url, target = parsed

        existing = next(
            (
                item
                for item in items
                if item.get("type") == "link"
                and item.get("name", "").casefold() == name.casefold()
            ),
            None,
        )

        if existing:
            existing["url"] = url
            existing["target"] = target
        else:
            items.append({
                "id": unique_id(items),
                "type": "link",
                "name": name,
                "url": url,
                "target": target,
                "group": "",
            })

    write_items(items)
    print("Import abgeschlossen.")


def cmd_export(args):
    items = read_items()
    target = Path(args.file)

    lines = [
        "# PVE Dashboard Links",
        "# Spezialelemente werden im Web-Editor verwaltet.",
        "# Format: NAME|URL|new",
        "",
    ]

    for item in items:
        if item.get("type") != "link" or item.get("id") == "router":
            continue

        lines.append(
            f"{item['name']}|{item['url']}|{item['target']}"
        )

    target.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Exportiert: {target}")


def main():
    parser = argparse.ArgumentParser(
        prog="pve-dashboard-link",
        description="Menüelemente des PVE Hardware Monitors verwalten",
    )

    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("list", help="Alle Menüelemente anzeigen")
    p.set_defaults(func=cmd_list)

    p = sub.add_parser("add", help="Link hinzufügen oder aktualisieren")
    p.add_argument("name")
    p.add_argument("url")
    p.add_argument("--target", choices=("new", "same"), default="new")
    p.set_defaults(func=cmd_add)

    p = sub.add_parser("edit", help="Link ändern")
    p.add_argument("selector")
    p.add_argument("--name")
    p.add_argument("--url")
    p.add_argument("--target", choices=("new", "same"))
    p.set_defaults(func=cmd_edit)

    p = sub.add_parser("delete", help="Menüelement löschen")
    p.add_argument("selector")
    p.set_defaults(func=cmd_delete)

    p = sub.add_parser("move", help="Menüelement verschieben")
    p.add_argument("selector")
    p.add_argument("position", help="up, down, top, bottom oder Zielposition")
    p.set_defaults(func=cmd_move)

    p = sub.add_parser("import", help="Links importieren")
    p.add_argument("file")
    p.set_defaults(func=cmd_import)

    p = sub.add_parser("export", help="Links exportieren")
    p.add_argument("file")
    p.set_defaults(func=cmd_export)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
PYCLI

chmod 755 "$CLI"

chown pve-monitor:pve-monitor \
    "$(dirname "$LINKS")" \
    "$LINKS" 2>/dev/null || true

chmod 700 "$(dirname "$LINKS")"
chmod 600 "$LINKS"

python3 -m py_compile "$APP"
python3 -m py_compile "$CLI"

systemctl restart pve-sensor-web.service
systemctl restart nginx

sleep 2

echo
echo "API-Test:"
curl -fsS http://127.0.0.1:9105/api/links |
    python3 -m json.tool || true

echo
echo "============================================================"
echo " MENÜ-EDITOR V4 INSTALLIERT"
echo "============================================================"
echo
echo "Im Dashboard:"
echo "  ☰ Menü -> ⚙ Dienste verwalten"
echo
echo "Elementtypen:"
echo "  Link"
echo "  Dropdown / Gruppe"
echo "  Überschrift"
echo "  Trennstrich"
echo "  Abstandshalter"
echo
echo "Links können über 'In Dropdown' einer Gruppe zugeordnet werden."
echo
echo "Browser anschließend einmal:"
echo "  STRG + F5"
echo
echo "Backup:"
echo "  $BACKUP"
echo
echo "Log:"
echo "  $LOGFILE"
echo "============================================================"
__PVE_MENU_EDITOR_V4__

    chmod 700 "$patch"
    bash "$patch"
    rm -f "$patch"

    ok "Flexibler Menü-Editor V4 ist installiert."
}


# =============================================================================
# DASHBOARD EINSTELLUNGEN / FARBEN / HTTPS / FAVICON - V4
# =============================================================================

install_dashboard_settings_v4() {
    header "DASHBOARD EINSTELLUNGEN / FARBEN / HTTPS / FAVICON"

    local patch="/tmp/pve-dashboard-settings-v4.$$"

    cat > "$patch" <<'__PVE_DASHBOARD_SETTINGS_V4__'
#!/usr/bin/env bash
set -Eeuo pipefail

STAMP="$(date +%d-%m-%H-%M)"
LOGFILE="/root/diagnose/diagnose-dashboard-einstellungen-${STAMP}.txt"

if [[ -e "$LOGFILE" ]]; then
    N=2
    while [[ -e "/root/diagnose/diagnose-dashboard-einstellungen-${STAMP}-${N}.txt" ]]; do
        N=$((N + 1))
    done
    LOGFILE="/root/diagnose/diagnose-dashboard-einstellungen-${STAMP}-${N}.txt"
fi

exec > >(tee -a "$LOGFILE") 2>&1

[[ ${EUID:-$(id -u)} -eq 0 ]] || {
    echo "FEHLER: Bitte als root auf dem Proxmox-Host ausführen."
    exit 1
}

APP="/opt/nodezero/dashboard/app.py"
INDEX="/opt/nodezero/dashboard/static/index.html"
NGINX_SITE="/etc/nginx/sites-available/pve-sensor-dashboard"
SUDOERS="/etc/sudoers.d/pve-sensor-dashboard"
SETTINGS_DIR="/etc/pve-sensor-dashboard"
SETTINGS_FILE="${SETTINGS_DIR}/ui.json"
SETTINGS_HELPER="/usr/local/sbin/pve-dashboard-settings-helper"
BACKUP="/root/backups/pve-dashboard-settings-backup-$(date +%Y%m%d-%H%M%S)"

[[ -f "$APP" ]] || {
    echo "FEHLER: $APP nicht gefunden."
    exit 1
}

[[ -f "$INDEX" ]] || {
    echo "FEHLER: $INDEX nicht gefunden."
    exit 1
}

[[ -f "$NGINX_SITE" ]] || {
    echo "FEHLER: $NGINX_SITE nicht gefunden."
    exit 1
}

echo "============================================================"
echo " DASHBOARD EINSTELLUNGEN + FARBEN + HTTPS + FAVICON - V4"
echo "============================================================"
echo
echo "Neu:"
echo "  - Webseitenname ändern"
echo "  - Server-Menü-Name ändern"
echo "  - Dashboard-Farben / Farbschema anpassen"
echo "  - Live-Vorschau + Standardfarben wiederherstellen"
echo "  - Favicon hochladen / ersetzen / löschen"
echo "  - Dashboard HTTPS aktivieren"
echo "  - HTTP -> HTTPS Umleitung optional"
echo "  - Menü-Links: HTTP / HTTPS Auswahl"
echo
echo "Log:"
echo "  $LOGFILE"
echo

mkdir -p "$BACKUP" "$SETTINGS_DIR"

cp -a "$APP" "$BACKUP/app.py"
cp -a "$INDEX" "$BACKUP/index.html"
cp -a "$NGINX_SITE" "$BACKUP/nginx-site"
[[ -f "$SUDOERS" ]] && cp -a "$SUDOERS" "$BACKUP/sudoers"
[[ -f "$SETTINGS_FILE" ]] && cp -a "$SETTINGS_FILE" "$BACKUP/ui.json"

export DEBIAN_FRONTEND=noninteractive

if ! command -v openssl >/dev/null 2>&1; then
    apt-get update
    apt-get install -y openssl
fi

DASHBOARD_IP="$(
    ip -4 route get 1.1.1.1 2>/dev/null |
    awk '{
        for(i=1;i<=NF;i++){
            if($i=="src"){
                print $(i+1);
                exit
            }
        }
    }'
)"

DASHBOARD_IP="${DASHBOARD_IP:-$(hostname -I 2>/dev/null | awk '{print $1}')}"
DASHBOARD_IP="${DASHBOARD_IP:-127.0.0.1}"

if [[ ! -s "$SETTINGS_FILE" ]]; then
    DASHBOARD_IP="$DASHBOARD_IP" python3 - "$SETTINGS_FILE" <<'PY'
from pathlib import Path
import json
import os
import sys

path = Path(sys.argv[1])

data = {
    "website_name": "PVE Hardware Monitor",
    "menu_name": "Server-Menü",
    "https_enabled": False,
    "https_redirect": True,
    "https_host": os.environ.get("DASHBOARD_IP", "127.0.0.1"),
    "favicon_url": "",
    "certificate_type": "HTTP",
    "theme_bg": "#08101b",
    "theme_panel": "#101a29",
    "theme_panel2": "#131f31",
    "theme_line": "#28364b",
    "theme_text": "#eef5ff",
    "theme_muted": "#92a4bc",
    "theme_accent": "#64a7ff",
    "theme_accent2": "#9b7cff",
    "theme_good": "#37d996",
    "theme_warn": "#ffbd4a",
    "theme_bad": "#ff5f6d",
}

path.write_text(
    json.dumps(data, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
PY
fi

chown root:pve-monitor "$SETTINGS_FILE"
chmod 640 "$SETTINGS_FILE"

cat > "$SETTINGS_HELPER" <<'PYHELPER'
#!/usr/bin/env python3

import base64
import ipaddress
import json
import os
import pwd
import re
import subprocess
import sys
import time
from pathlib import Path

APP_DIR = Path("/opt/nodezero/dashboard")
STATIC_DIR = APP_DIR / "static"
SETTINGS_DIR = Path("/etc/pve-sensor-dashboard")
SETTINGS_FILE = SETTINGS_DIR / "ui.json"
NGINX_SITE = Path("/etc/nginx/sites-available/pve-sensor-dashboard")
NGINX_ENABLED = Path("/etc/nginx/sites-enabled/pve-sensor-dashboard")
TLS_CERT = SETTINGS_DIR / "dashboard.crt"
TLS_KEY = SETTINGS_DIR / "dashboard.key"
TLS_HOST_FILE = SETTINGS_DIR / "tls-host.txt"
APP_PORT = 9105
MAX_FAVICON_BYTES = 1024 * 1024

HOST_RE = re.compile(
    r"^[A-Za-z0-9](?:[A-Za-z0-9.-]{0,251}[A-Za-z0-9])?$"
)

COLOR_RE = re.compile(r"^#[0-9A-Fa-f]{6}$")

THEME_DEFAULTS = {
    "theme_bg": "#08101b",
    "theme_panel": "#101a29",
    "theme_panel2": "#131f31",
    "theme_line": "#28364b",
    "theme_text": "#eef5ff",
    "theme_muted": "#92a4bc",
    "theme_accent": "#64a7ff",
    "theme_accent2": "#9b7cff",
    "theme_good": "#37d996",
    "theme_warn": "#ffbd4a",
    "theme_bad": "#ff5f6d",
}


def fail(message, code=1):
    print(
        json.dumps({
            "ok": False,
            "error": str(message),
        }),
        flush=True,
    )
    raise SystemExit(code)


def bool_value(value):
    if isinstance(value, bool):
        return value

    return str(value).strip().lower() in (
        "1",
        "true",
        "yes",
        "ja",
        "on",
    )


def valid_color(value, fallback):
    value = str(value or "").strip()

    if not COLOR_RE.fullmatch(value):
        return fallback

    return value.lower()


def current_ip():
    try:
        out = subprocess.check_output(
            ["ip", "-4", "route", "get", "1.1.1.1"],
            text=True,
            timeout=5,
        )

        parts = out.split()

        if "src" in parts:
            return parts[parts.index("src") + 1]
    except Exception:
        pass

    try:
        out = subprocess.check_output(
            ["hostname", "-I"],
            text=True,
            timeout=5,
        ).split()

        if out:
            return out[0]
    except Exception:
        pass

    return "127.0.0.1"


def valid_host(value):
    value = str(value or "").strip()

    if not value:
        return current_ip()

    try:
        ipaddress.ip_address(value)
        return value
    except ValueError:
        pass

    if (
        len(value) > 253
        or not HOST_RE.fullmatch(value)
        or ".." in value
    ):
        fail("HTTPS Hostname/Domain/IP ist ungültig.")

    return value.lower()


def detect_favicon(data):
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "png"

    if data.startswith(b"\x00\x00\x01\x00"):
        return "ico"

    if data.startswith(b"\xff\xd8\xff"):
        return "jpg"

    if (
        len(data) >= 12
        and data[0:4] == b"RIFF"
        and data[8:12] == b"WEBP"
    ):
        return "webp"

    sample = data[:512].lstrip().lower()

    if sample.startswith(b"<svg") or b"<svg" in sample:
        return "svg"

    fail(
        "Favicon-Datei wird nicht unterstützt. "
        "Erlaubt: PNG, ICO, SVG, JPG oder WEBP."
    )


def remove_custom_favicons():
    for file in STATIC_DIR.glob("favicon-custom.*"):
        try:
            file.unlink()
        except FileNotFoundError:
            pass


def install_favicon(payload, settings):
    action = str(
        payload.get("favicon_action", "keep")
    ).strip().lower()

    if action == "clear":
        remove_custom_favicons()
        settings["favicon_url"] = ""
        return

    if action != "upload":
        return

    encoded = str(payload.get("favicon_base64", ""))

    if not encoded:
        fail("Favicon-Upload enthält keine Daten.")

    try:
        data = base64.b64decode(encoded, validate=True)
    except Exception:
        fail("Favicon konnte nicht gelesen werden.")

    if not data or len(data) > MAX_FAVICON_BYTES:
        fail("Favicon muss zwischen 1 Byte und 1 MB groß sein.")

    ext = detect_favicon(data)

    STATIC_DIR.mkdir(parents=True, exist_ok=True)
    remove_custom_favicons()

    target = STATIC_DIR / ("favicon-custom." + ext)
    temp = target.with_suffix(target.suffix + ".tmp")

    temp.write_bytes(data)
    os.chmod(temp, 0o644)
    temp.replace(target)

    settings["favicon_url"] = (
        f"/{target.name}?v={int(time.time())}"
    )


def letsencrypt_certificate(host):
    try:
        ipaddress.ip_address(host)
        return None
    except ValueError:
        pass

    live = Path("/etc/letsencrypt/live") / host
    cert = live / "fullchain.pem"
    key = live / "privkey.pem"

    if cert.is_file() and key.is_file():
        return cert, key

    return None


def ensure_self_signed(host, dashboard_ip):
    SETTINGS_DIR.mkdir(parents=True, exist_ok=True)

    try:
        old_host = TLS_HOST_FILE.read_text(
            encoding="utf-8"
        ).strip()
    except Exception:
        old_host = ""

    if (
        TLS_CERT.is_file()
        and TLS_KEY.is_file()
        and old_host == host
    ):
        return TLS_CERT, TLS_KEY

    san = []

    for value in (host, dashboard_ip):
        if not value:
            continue

        try:
            ipaddress.ip_address(value)
            entry = "IP:" + value
        except ValueError:
            entry = "DNS:" + value

        if entry not in san:
            san.append(entry)

    hostname = os.uname().nodename

    if hostname:
        entry = "DNS:" + hostname

        if entry not in san:
            san.append(entry)

    temp_cert = TLS_CERT.with_suffix(".crt.new")
    temp_key = TLS_KEY.with_suffix(".key.new")

    for file in (temp_cert, temp_key):
        try:
            file.unlink()
        except FileNotFoundError:
            pass

    command = [
        "openssl",
        "req",
        "-x509",
        "-nodes",
        "-newkey",
        "rsa:2048",
        "-sha256",
        "-days",
        "825",
        "-keyout",
        str(temp_key),
        "-out",
        str(temp_cert),
        "-subj",
        f"/C=DE/ST=Deutschland/L=HomeLab/O=NodeZero/OU=Proxmox/CN={host}",
        "-addext",
        "subjectAltName=" + ",".join(san),
    ]

    subprocess.run(
        command,
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
    )

    os.chmod(temp_key, 0o600)
    os.chmod(temp_cert, 0o644)

    temp_key.replace(TLS_KEY)
    temp_cert.replace(TLS_CERT)

    TLS_HOST_FILE.write_text(
        host + "\n",
        encoding="utf-8",
    )
    os.chmod(TLS_HOST_FILE, 0o600)

    return TLS_CERT, TLS_KEY


def proxy_block():
    return f'''    location / {{
        proxy_pass http://127.0.0.1:{APP_PORT};
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_connect_timeout 5s;
        proxy_read_timeout 30s;
    }}
'''


def nginx_http(host):
    return f'''server {{
    listen 80;
    listen [::]:80;
    server_name {host} _;

    access_log /var/log/nginx/pve-sensor-dashboard.access.log;
    error_log  /var/log/nginx/pve-sensor-dashboard.error.log;

{proxy_block()}}}
'''


def nginx_https(host, cert, key, redirect):
    http_part = f'''server {{
    listen 80;
    listen [::]:80;
    server_name {host} _;

'''

    if redirect:
        http_part += (
            f"    return 301 https://{host}$request_uri;\n"
            "}\n\n"
        )
    else:
        http_part += (
            "    access_log /var/log/nginx/pve-sensor-dashboard.access.log;\n"
            "    error_log  /var/log/nginx/pve-sensor-dashboard.error.log;\n\n"
            + proxy_block()
            + "}\n\n"
        )

    https_part = f'''server {{
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name {host} _;

    ssl_certificate {cert};
    ssl_certificate_key {key};
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_session_cache shared:PVE_DASHBOARD_TLS:10m;
    ssl_session_timeout 1d;

    add_header Strict-Transport-Security "max-age=86400" always;

    access_log /var/log/nginx/pve-sensor-dashboard.ssl.access.log;
    error_log  /var/log/nginx/pve-sensor-dashboard.ssl.error.log;

{proxy_block()}}}
'''

    return http_part + https_part


def port_443_conflict():
    try:
        out = subprocess.check_output(
            ["ss", "-ltnp"],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=5,
        )
    except Exception:
        return False

    for line in out.splitlines():
        if ":443 " in line or ":443\t" in line:
            if "nginx" not in line:
                return True

    return False


def write_settings(settings):
    SETTINGS_DIR.mkdir(parents=True, exist_ok=True)

    temp = SETTINGS_FILE.with_suffix(".json.tmp")

    temp.write_text(
        json.dumps(
            settings,
            ensure_ascii=False,
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )

    os.chmod(temp, 0o640)
    temp.replace(SETTINGS_FILE)

    try:
        account = pwd.getpwnam("pve-monitor")
        os.chown(
            SETTINGS_FILE,
            0,
            account.pw_gid,
        )
    except Exception:
        pass


def apply(payload):
    website_name = str(
        payload.get(
            "website_name",
            "PVE Hardware Monitor",
        )
    ).strip()

    menu_name = str(
        payload.get(
            "menu_name",
            "Server-Menü",
        )
    ).strip()

    if not website_name:
        fail("Webseitenname darf nicht leer sein.")

    if len(website_name) > 80:
        fail("Webseitenname darf höchstens 80 Zeichen haben.")

    if not menu_name:
        fail("Menüname darf nicht leer sein.")

    if len(menu_name) > 60:
        fail("Menüname darf höchstens 60 Zeichen haben.")

    https_enabled = bool_value(
        payload.get("https_enabled", False)
    )

    https_redirect = bool_value(
        payload.get("https_redirect", True)
    )

    dashboard_ip = current_ip()

    https_host = valid_host(
        payload.get("https_host", dashboard_ip)
    )

    try:
        current = json.loads(
            SETTINGS_FILE.read_text(encoding="utf-8")
        )
    except Exception:
        current = {}

    theme = {}

    for key, default in THEME_DEFAULTS.items():
        theme[key] = valid_color(
            payload.get(
                key,
                current.get(key, default),
            ),
            default,
        )

    settings = {
        "website_name": website_name,
        "menu_name": menu_name,
        "https_enabled": https_enabled,
        "https_redirect": https_redirect,
        "https_host": https_host,
        "favicon_url": str(
            current.get("favicon_url", "")
        ),
        "certificate_type": "HTTP",
        **theme,
    }

    install_favicon(payload, settings)

    certificate_type = "HTTP"

    if https_enabled:
        if port_443_conflict():
            fail(
                "Port 443 wird von einem anderen "
                "Dienst als nginx belegt."
            )

        le = letsencrypt_certificate(https_host)

        if le:
            cert, key = le
            certificate_type = "Let's Encrypt"
        else:
            try:
                cert, key = ensure_self_signed(
                    https_host,
                    dashboard_ip,
                )
            except subprocess.CalledProcessError as exc:
                fail(
                    "Selbstsigniertes Zertifikat konnte "
                    "nicht erzeugt werden: "
                    + (exc.stderr or "").strip()
                )

            certificate_type = "Selbstsigniert"

        nginx = nginx_https(
            https_host,
            cert,
            key,
            https_redirect,
        )
    else:
        nginx = nginx_http(https_host)

    nginx_tmp = NGINX_SITE.with_suffix(".new")

    nginx_tmp.write_text(
        nginx,
        encoding="utf-8",
    )

    os.chmod(nginx_tmp, 0o644)

    old = None

    if NGINX_SITE.exists():
        old = NGINX_SITE.read_bytes()

    nginx_tmp.replace(NGINX_SITE)

    NGINX_ENABLED.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    if (
        not NGINX_ENABLED.exists()
        and not NGINX_ENABLED.is_symlink()
    ):
        NGINX_ENABLED.symlink_to(NGINX_SITE)

    test = subprocess.run(
        ["nginx", "-t"],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )

    if test.returncode != 0:
        if old is not None:
            NGINX_SITE.write_bytes(old)

        fail(
            "nginx-Konfiguration ungültig: "
            + test.stdout.strip()
        )

    settings["certificate_type"] = certificate_type
    write_settings(settings)

    reload_result = subprocess.run(
        ["systemctl", "reload", "nginx"],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )

    if reload_result.returncode != 0:
        fail(
            "nginx konnte nicht neu geladen werden: "
            + reload_result.stdout.strip()
        )

    url = (
        f"https://{https_host}/"
        if https_enabled
        else f"http://{https_host}/"
    )

    print(
        json.dumps({
            "ok": True,
            "settings": settings,
            "url": url,
            "certificate_type": certificate_type,
        }),
        flush=True,
    )


def main():
    if len(sys.argv) != 2:
        fail("Aufruf: pve-dashboard-settings-helper apply")

    if sys.argv[1] != "apply":
        fail("Ungültige Aktion.")

    raw = sys.stdin.buffer.read(2 * 1024 * 1024)

    if not raw:
        fail("Keine Einstellungsdaten empfangen.")

    try:
        payload = json.loads(raw.decode("utf-8"))
    except Exception:
        fail("Einstellungsdaten sind ungültig.")

    if not isinstance(payload, dict):
        fail("Einstellungsdaten müssen ein Objekt sein.")

    apply(payload)


if __name__ == "__main__":
    main()
PYHELPER

chown root:root "$SETTINGS_HELPER"
chmod 755 "$SETTINGS_HELPER"

SETTINGS_RULE="pve-monitor ALL=(root) NOPASSWD: ${SETTINGS_HELPER} apply"

if [[ -f "$SUDOERS" ]]; then
    grep -Fqx "$SETTINGS_RULE" "$SUDOERS" || \
        echo "$SETTINGS_RULE" >> "$SUDOERS"
else
    cat > "$SUDOERS" <<EOF
$SETTINGS_RULE
EOF
fi

chmod 440 "$SUDOERS"
visudo -cf "$SUDOERS" >/dev/null

python3 - "$APP" "$INDEX" <<'PY'
from pathlib import Path
import re
import sys

app_path = Path(sys.argv[1])
index_path = Path(sys.argv[2])

app = app_path.read_text(encoding="utf-8")
index = index_path.read_text(encoding="utf-8")

print("[INFO] linkUrl:", 'id="linkUrl"' in index)
print("[INFO] editLink:", "function editLink" in index)
print("[INFO] saveLink:", "function saveLink" in index)


def replace_one(text, pattern, replacement, label, flags=re.S):
    new, count = re.subn(
        pattern,
        lambda _m: replacement,
        text,
        count=1,
        flags=flags,
    )

    if count != 1:
        raise SystemExit(
            f"FEHLER: {label} konnte nicht eindeutig gefunden werden."
        )

    return new


if "import base64\n" not in app:
    app = app.replace(
        "import os\n",
        "import base64\nimport os\n",
        1,
    )

if "import json\n" not in app:
    app = app.replace(
        "import base64\n",
        "import base64\nimport json\n",
        1,
    )

if "SETTINGS_HELPER =" not in app:
    anchor = 'POWER_HELPER = "/usr/local/sbin/pve-sensor-powerctl"\n'

    replacement = (
        anchor
        + 'UI_SETTINGS_FILE = Path("/etc/pve-sensor-dashboard/ui.json")\n'
        + 'SETTINGS_HELPER = "/usr/local/sbin/pve-dashboard-settings-helper"\n'
    )

    if anchor not in app:
        raise SystemExit(
            "FEHLER: POWER_HELPER-Anker nicht gefunden."
        )

    app = app.replace(
        anchor,
        replacement,
        1,
    )

settings_api = r'''
def read_ui_settings():
    defaults = {
        "website_name": "PVE Hardware Monitor",
        "menu_name": "Server-Menü",
        "https_enabled": False,
        "https_redirect": True,
        "https_host": "",
        "favicon_url": "",
        "certificate_type": "HTTP",
        "theme_bg": "#08101b",
        "theme_panel": "#101a29",
        "theme_panel2": "#131f31",
        "theme_line": "#28364b",
        "theme_text": "#eef5ff",
        "theme_muted": "#92a4bc",
        "theme_accent": "#64a7ff",
        "theme_accent2": "#9b7cff",
        "theme_good": "#37d996",
        "theme_warn": "#ffbd4a",
        "theme_bad": "#ff5f6d",
    }

    try:
        data = json.loads(
            UI_SETTINGS_FILE.read_text(
                encoding="utf-8"
            )
        )

        if isinstance(data, dict):
            defaults.update(data)
    except Exception:
        pass

    return defaults


@app.get("/api/ui-settings")
def ui_settings_get():
    data = read_ui_settings()

    if not data.get("https_host"):
        data["https_host"] = request.host.split(":", 1)[0]

    return jsonify(data)


@app.post("/api/ui-settings")
def ui_settings_save():
    payload = request.form.to_dict(flat=True)

    allowed, error = verify_control_request(payload)

    if not allowed:
        return error

    website_name = str(
        payload.get("website_name", "")
    ).strip()

    menu_name = str(
        payload.get("menu_name", "")
    ).strip()

    if not website_name:
        return jsonify({
            "error": "Webseitenname fehlt."
        }), 400

    if len(website_name) > 80:
        return jsonify({
            "error": (
                "Webseitenname darf höchstens "
                "80 Zeichen haben."
            )
        }), 400

    if not menu_name:
        return jsonify({
            "error": "Menüname fehlt."
        }), 400

    if len(menu_name) > 60:
        return jsonify({
            "error": (
                "Menüname darf höchstens "
                "60 Zeichen haben."
            )
        }), 400

    helper_payload = {
        "website_name": website_name,
        "menu_name": menu_name,
        "https_enabled": (
            payload.get("https_enabled", "0") == "1"
        ),
        "https_redirect": (
            payload.get("https_redirect", "0") == "1"
        ),
        "https_host": str(
            payload.get("https_host", "")
        ).strip(),
        "favicon_action": str(
            payload.get("favicon_action", "keep")
        ).strip(),
        "theme_bg": str(payload.get("theme_bg", "")).strip(),
        "theme_panel": str(payload.get("theme_panel", "")).strip(),
        "theme_panel2": str(payload.get("theme_panel2", "")).strip(),
        "theme_line": str(payload.get("theme_line", "")).strip(),
        "theme_text": str(payload.get("theme_text", "")).strip(),
        "theme_muted": str(payload.get("theme_muted", "")).strip(),
        "theme_accent": str(payload.get("theme_accent", "")).strip(),
        "theme_accent2": str(payload.get("theme_accent2", "")).strip(),
        "theme_good": str(payload.get("theme_good", "")).strip(),
        "theme_warn": str(payload.get("theme_warn", "")).strip(),
        "theme_bad": str(payload.get("theme_bad", "")).strip(),
    }

    favicon = request.files.get("favicon")

    if favicon and favicon.filename:
        data = favicon.read(1024 * 1024 + 1)

        if len(data) > 1024 * 1024:
            return jsonify({
                "error": "Favicon darf maximal 1 MB groß sein."
            }), 400

        helper_payload["favicon_action"] = "upload"
        helper_payload["favicon_base64"] = base64.b64encode(
            data
        ).decode("ascii")

    try:
        proc = subprocess.run(
            [
                "sudo",
                "-n",
                SETTINGS_HELPER,
                "apply",
            ],
            input=json.dumps(
                helper_payload,
                ensure_ascii=False,
            ),
            text=True,
            capture_output=True,
            timeout=45,
        )
    except subprocess.TimeoutExpired:
        return jsonify({
            "error": "Dashboard-Einstellungen Timeout."
        }), 504

    raw = proc.stdout.strip() or proc.stderr.strip()

    try:
        result = json.loads(raw.splitlines()[-1])
    except Exception:
        result = {
            "ok": False,
            "error": raw or (
                "Einstellungen konnten nicht gespeichert werden."
            ),
        }

    if (
        proc.returncode != 0
        or not result.get("ok")
    ):
        return jsonify({
            "error": result.get(
                "error",
                "Einstellungen konnten nicht gespeichert werden.",
            )
        }), 500

    clear_failures(client_ip())

    return jsonify(result)


'''

if '@app.get("/api/ui-settings")' not in app:
    anchor = '@app.get("/api/current")'

    if anchor not in app:
        raise SystemExit(
            "FEHLER: /api/current-Anker nicht gefunden."
        )

    app = app.replace(
        anchor,
        settings_api + anchor,
        1,
    )

index = index.replace(
    "<title>PVE Hardware Monitor</title>",
    '<title id="pageTitle">PVE Hardware Monitor</title>',
    1,
)

index = index.replace(
    "<h1>PVE Hardware Monitor</h1>",
    '<h1 id="websiteTitle">PVE Hardware Monitor</h1>',
    1,
)

index = index.replace(
    "<strong>Server-Menü</strong>",
    '<strong id="navMenuTitle">Server-Menü</strong>',
    1,
)

settings_button = (
    '<button class="navManage" '
    'onclick="openDashboardSettings()">'
    '🎨 Dashboard anpassen</button>'
)

if settings_button not in index:
    anchor = (
        '<button class="navManage" '
        'onclick="openLinkManager()">'
        '⚙ Dienste verwalten</button>'
    )

    if anchor not in index:
        raise SystemExit(
            "FEHLER: Dienste-verwalten-Button nicht gefunden."
        )

    index = index.replace(
        anchor,
        anchor + "\n  " + settings_button,
        1,
    )

if 'id="linkProtocol"' not in index:
    protocol_wrap = r'''      <div id="menuProtocolWrap">
        <label for="linkProtocol">Protokoll</label>
        <select id="linkProtocol">
          <option value="http">HTTP</option>
          <option value="https">HTTPS</option>
        </select>
      </div>

'''

    # Unterschiedliche Dashboard-Versionen formatieren das URL-Feld
    # unterschiedlich. Deshalb nicht auf einen exakten HTML-String prüfen,
    # sondern den kompletten DIV-Block suchen, der id="linkUrl" enthält.
    url_block_pattern = re.compile(
        r'(?P<indent>^[ \t]*)'
        r'<div\b[^>]*>\s*'
        r'<label\b[^>]*for=["\']linkUrl["\'][^>]*>.*?</label>\s*'
        r'<input\b(?=[^>]*\bid=["\']linkUrl["\'])[^>]*>\s*'
        r'</div>',
        re.S | re.M | re.I,
    )

    match = url_block_pattern.search(index)

    if not match:
        # Fallback: wenigstens direkt vor dem konkreten linkUrl-Input
        # ein eigenes Protokollfeld einsetzen.
        input_pattern = re.compile(
            r'(?P<indent>^[ \t]*)'
            r'(?=<input\b(?=[^>]*\bid=["\']linkUrl["\'])[^>]*>)',
            re.M | re.I,
        )

        input_match = input_pattern.search(index)

        if not input_match:
            raise SystemExit(
                'FEHLER: Das Feld id="linkUrl" wurde im Menü-Editor '
                'nicht gefunden. Bitte zuerst den Menü-Editor V4 installieren.'
            )

        indent = input_match.group("indent")
        fallback = (
            indent + '<div id="menuProtocolWrap">\n'
            + indent + '  <label for="linkProtocol">Protokoll</label>\n'
            + indent + '  <select id="linkProtocol">\n'
            + indent + '    <option value="http">HTTP</option>\n'
            + indent + '    <option value="https">HTTPS</option>\n'
            + indent + '  </select>\n'
            + indent + '</div>\n\n'
        )

        index = (
            index[:input_match.start()]
            + fallback
            + index[input_match.start():]
        )
    else:
        original = match.group(0)
        indent = match.group("indent")

        protocol_indented = "\n".join(
            indent + line if line else ""
            for line in protocol_wrap.strip("\n").splitlines()
        )

        index = (
            index[:match.start()]
            + protocol_indented
            + "\n\n"
            + original
            + index[match.end():]
        )

settings_css = r'''
/* PVE_DASHBOARD_SETTINGS_V2 */
.settingsPreview{
  display:flex;
  align-items:center;
  gap:12px;
  min-height:54px;
  padding:9px 10px;
  border:1px solid #35465e;
  border-radius:10px;
  background:#09111c;
}
.settingsPreview img{
  width:36px;
  height:36px;
  object-fit:contain;
  border-radius:7px;
  background:#101a29;
}
.settingsPreview span{
  color:var(--muted);
  font-size:12px;
}
.checkRow{
  display:flex;
  align-items:center;
  gap:9px;
  min-height:42px;
}
.checkRow input[type="checkbox"]{
  width:auto;
  margin:0;
  accent-color:#64a7ff;
}
.checkRow label{
  margin:0;
  cursor:pointer;
}
.settingsNote{
  padding:10px 12px;
  border:1px solid #35465e;
  border-radius:10px;
  background:#0b1420;
  color:var(--muted);
  font-size:11px;
  line-height:1.5;
}
.settingsUrl{
  color:var(--accent);
  word-break:break-all;
}
.settingsDialog{
  width:min(820px,100%);
  max-height:90vh;
  overflow:auto;
}
.themeSectionHead{
  display:flex;
  align-items:center;
  justify-content:space-between;
  gap:12px;
  margin:4px 0 8px;
}
.themeSectionHead strong{
  font-size:13px;
}
.themeSectionHead span{
  display:block;
  margin-top:3px;
  color:var(--muted);
  font-size:11px;
}
.themeReset{
  white-space:nowrap;
  padding:7px 10px;
  font-size:11px;
}
.themeGrid{
  display:grid;
  grid-template-columns:repeat(3,minmax(0,1fr));
  gap:8px;
}
.themeColor{
  display:flex;
  align-items:center;
  justify-content:space-between;
  gap:8px;
  padding:8px 9px;
  border:1px solid var(--line);
  border-radius:10px;
  background:var(--panel2);
}
.themeColor label{
  margin:0;
  font-size:11px;
}
.themeColor input[type="color"]{
  width:48px;
  min-width:48px;
  height:34px;
  margin:0;
  padding:2px;
  border:1px solid var(--line);
  border-radius:8px;
  background:var(--panel);
  cursor:pointer;
}
.themeColor input[type="color"]::-webkit-color-swatch-wrapper{
  padding:0;
}
.themeColor input[type="color"]::-webkit-color-swatch{
  border:0;
  border-radius:5px;
}
.themeHint{
  margin-top:8px;
  color:var(--muted);
  font-size:11px;
  line-height:1.45;
}
body{
  background:var(--bg);
}
.live,
.chart,
.note,
.dialog,
.linkList,
.settingsPreview,
.settingsNote{
  background:var(--panel);
}
.card{
  background:linear-gradient(155deg,var(--panel2),var(--panel));
}
button,
.dialog input,
.dialog select{
  background:var(--panel2);
  color:var(--text);
  border-color:var(--line);
}
.sideNav{
  background:linear-gradient(180deg,var(--panel2),var(--bg));
  border-right-color:var(--line);
}
.menuBtn{
  border-color:var(--accent);
  color:var(--accent);
}
.navManage{
  border-color:var(--accent2);
}
.navIcon{
  background:var(--panel2);
  border-color:var(--line);
}
.navLink:hover{
  background:var(--panel2);
  border-color:var(--line);
}
.linkRow{
  border-bottom-color:var(--line);
}
.ranges button.active{
  background:var(--accent);
  border-color:var(--accent);
  color:var(--bg);
}
.checkRow input[type="checkbox"]{
  accent-color:var(--accent);
}
.msg.err{
  color:var(--bad);
}
.msg.ok{
  color:var(--good);
}
@media(max-width:760px){
  .themeGrid{
    grid-template-columns:repeat(2,minmax(0,1fr));
  }
}
'''

if "/* PVE_DASHBOARD_SETTINGS_V2 */" not in index:
    if "</style>" not in index:
        raise SystemExit("FEHLER: </style> nicht gefunden.")

    index = index.replace(
        "</style>",
        settings_css + "\n</style>",
        1,
    )

settings_modal = r'''
<div class="modal" id="settingsModal">
  <div class="dialog linkDialog settingsDialog">
    <h2>Dashboard anpassen</h2>

    <p>
      Webseitenname, Menüname, Farben, Favicon und HTTPS
      zentral einstellen.
    </p>

    <div class="formGrid">
      <div>
        <label for="websiteName">Webseitenname</label>
        <input
          id="websiteName"
          type="text"
          maxlength="80"
          placeholder="PVE Hardware Monitor"
        >
      </div>

      <div>
        <label for="menuName">Name des Server-Menüs</label>
        <input
          id="menuName"
          type="text"
          maxlength="60"
          placeholder="Server-Menü"
        >
      </div>

      <div class="full">
        <div class="themeSectionHead">
          <div>
            <strong>Farbschema</strong>
            <span>
              Farben werden sofort als Vorschau angezeigt.
            </span>
          </div>

          <button
            type="button"
            class="themeReset"
            onclick="resetThemeColors()"
          >
            Standardfarben
          </button>
        </div>

        <div class="themeGrid">
          <div class="themeColor">
            <label for="themeBg">Hintergrund</label>
            <input id="themeBg" type="color" value="#08101b" oninput="previewThemeColors()">
          </div>
          <div class="themeColor">
            <label for="themePanel">Panel dunkel</label>
            <input id="themePanel" type="color" value="#101a29" oninput="previewThemeColors()">
          </div>
          <div class="themeColor">
            <label for="themePanel2">Panel hell</label>
            <input id="themePanel2" type="color" value="#131f31" oninput="previewThemeColors()">
          </div>
          <div class="themeColor">
            <label for="themeLine">Linien / Rahmen</label>
            <input id="themeLine" type="color" value="#28364b" oninput="previewThemeColors()">
          </div>
          <div class="themeColor">
            <label for="themeText">Text</label>
            <input id="themeText" type="color" value="#eef5ff" oninput="previewThemeColors()">
          </div>
          <div class="themeColor">
            <label for="themeMuted">Sekundärtext</label>
            <input id="themeMuted" type="color" value="#92a4bc" oninput="previewThemeColors()">
          </div>
          <div class="themeColor">
            <label for="themeAccent">Akzent</label>
            <input id="themeAccent" type="color" value="#64a7ff" oninput="previewThemeColors()">
          </div>
          <div class="themeColor">
            <label for="themeAccent2">Akzent 2</label>
            <input id="themeAccent2" type="color" value="#9b7cff" oninput="previewThemeColors()">
          </div>
          <div class="themeColor">
            <label for="themeGood">OK</label>
            <input id="themeGood" type="color" value="#37d996" oninput="previewThemeColors()">
          </div>
          <div class="themeColor">
            <label for="themeWarn">Warnung</label>
            <input id="themeWarn" type="color" value="#ffbd4a" oninput="previewThemeColors()">
          </div>
          <div class="themeColor">
            <label for="themeBad">Fehler</label>
            <input id="themeBad" type="color" value="#ff5f6d" oninput="previewThemeColors()">
          </div>
        </div>

        <div class="themeHint">
          Die Vorschau ist erst nach „Einstellungen speichern“
          dauerhaft. „Schließen“ verwirft nicht gespeicherte Farben.
        </div>
      </div>

      <div class="full">
        <label for="faviconFile">Favicon hochladen</label>
        <input
          id="faviconFile"
          type="file"
          accept=".png,.ico,.svg,.jpg,.jpeg,.webp,image/png,image/x-icon,image/svg+xml,image/jpeg,image/webp"
          onchange="previewFavicon()"
        >
      </div>

      <div class="full">
        <div class="settingsPreview">
          <img
            id="faviconPreview"
            alt="Favicon"
            style="display:none"
          >
          <span id="faviconInfo">
            Kein eigenes Favicon gesetzt.
          </span>
        </div>
      </div>

      <div class="full">
        <div class="checkRow">
          <input
            id="faviconClear"
            type="checkbox"
          >
          <label for="faviconClear">
            Eigenes Favicon löschen
          </label>
        </div>
      </div>

      <div class="full">
        <div class="checkRow">
          <input
            id="httpsEnabled"
            type="checkbox"
            onchange="updateHttpsSettingsForm()"
          >
          <label for="httpsEnabled">
            HTTPS für dieses Dashboard aktivieren
          </label>
        </div>
      </div>

      <div id="httpsHostWrap">
        <label for="httpsHost">
          HTTPS Hostname / Domain / IP
        </label>
        <input
          id="httpsHost"
          type="text"
          maxlength="253"
          placeholder="192.168.178.100 oder dashboard.local"
        >
      </div>

      <div id="httpsRedirectWrap">
        <div class="checkRow">
          <input
            id="httpsRedirect"
            type="checkbox"
            checked
          >
          <label for="httpsRedirect">
            HTTP automatisch auf HTTPS umleiten
          </label>
        </div>
      </div>

      <div class="full">
        <div class="settingsNote">
          HTTPS verwendet automatisch ein vorhandenes
          Let's-Encrypt-Zertifikat für die eingetragene Domain.
          Ist keines vorhanden, wird ein selbstsigniertes Zertifikat
          erzeugt. Bei einem selbstsignierten Zertifikat zeigt der
          Browser zunächst eine Zertifikatswarnung.
        </div>
      </div>

      <div>
        <label for="settingsCode">Sicherheitscode</label>
        <input
          id="settingsCode"
          type="password"
          autocomplete="off"
          placeholder="Dashboard-Steuer-Code"
        >
      </div>

      <div class="full">
        <div id="settingsMsg" class="msg"></div>
      </div>
    </div>

    <div class="modalButtons">
      <button onclick="closeDashboardSettings()">
        Schließen
      </button>

      <button
        id="settingsSave"
        onclick="saveDashboardSettings()"
      >
        Einstellungen speichern
      </button>
    </div>
  </div>
</div>

'''

if 'id="settingsModal"' not in index:
    anchor = '<div class="modal" id="modal">\n'

    if anchor not in index:
        raise SystemExit(
            "FEHLER: Power-Modal-Anker nicht gefunden."
        )

    index = index.replace(
        anchor,
        settings_modal + anchor,
        1,
    )

settings_js = r'''
let uiSettings={};

const THEME_DEFAULTS={
  theme_bg:'#08101b',
  theme_panel:'#101a29',
  theme_panel2:'#131f31',
  theme_line:'#28364b',
  theme_text:'#eef5ff',
  theme_muted:'#92a4bc',
  theme_accent:'#64a7ff',
  theme_accent2:'#9b7cff',
  theme_good:'#37d996',
  theme_warn:'#ffbd4a',
  theme_bad:'#ff5f6d'
};

const THEME_VARS={
  theme_bg:'--bg',
  theme_panel:'--panel',
  theme_panel2:'--panel2',
  theme_line:'--line',
  theme_text:'--text',
  theme_muted:'--muted',
  theme_accent:'--accent',
  theme_accent2:'--accent2',
  theme_good:'--good',
  theme_warn:'--warn',
  theme_bad:'--bad'
};

const THEME_FIELDS={
  theme_bg:'themeBg',
  theme_panel:'themePanel',
  theme_panel2:'themePanel2',
  theme_line:'themeLine',
  theme_text:'themeText',
  theme_muted:'themeMuted',
  theme_accent:'themeAccent',
  theme_accent2:'themeAccent2',
  theme_good:'themeGood',
  theme_warn:'themeWarn',
  theme_bad:'themeBad'
};

function validThemeColor(value,fallback){
  const color=String(value||'').trim();

  return /^#[0-9a-f]{6}$/i.test(color)
    ? color.toLowerCase()
    : fallback;
}

function applyThemeColors(settings){
  const root=document.documentElement;

  Object.entries(THEME_VARS).forEach(([key,cssVar])=>{
    root.style.setProperty(
      cssVar,
      validThemeColor(
        settings?.[key],
        THEME_DEFAULTS[key]
      )
    );
  });
}

function fillThemeInputs(settings){
  Object.entries(THEME_FIELDS).forEach(([key,id])=>{
    const el=$(id);

    if(el){
      el.value=validThemeColor(
        settings?.[key],
        THEME_DEFAULTS[key]
      );
    }
  });
}

function themeFromInputs(){
  const theme={};

  Object.entries(THEME_FIELDS).forEach(([key,id])=>{
    theme[key]=validThemeColor(
      $(id)?.value,
      THEME_DEFAULTS[key]
    );
  });

  return theme;
}

function previewThemeColors(){
  applyThemeColors(themeFromInputs());
}

function resetThemeColors(){
  fillThemeInputs(THEME_DEFAULTS);
  previewThemeColors();
}

function ensureFaviconLink(){
  let link=document.querySelector(
    'link[data-dashboard-favicon="1"]'
  );

  if(!link){
    link=document.createElement('link');
    link.rel='icon';
    link.dataset.dashboardFavicon='1';
    document.head.appendChild(link);
  }

  return link;
}

function applyUiSettings(settings){
  uiSettings=settings||{};

  const website=
    uiSettings.website_name
    || 'PVE Hardware Monitor';

  const menu=
    uiSettings.menu_name
    || 'Server-Menü';

  document.title=website;

  if($('websiteTitle')){
    $('websiteTitle').textContent=website;
  }

  if($('navMenuTitle')){
    $('navMenuTitle').textContent=menu;
  }

  applyThemeColors(uiSettings);

  const favicon=ensureFaviconLink();

  if(uiSettings.favicon_url){
    favicon.href=uiSettings.favicon_url;
  }else{
    favicon.removeAttribute('href');
  }
}

async function loadUiSettings(){
  try{
    const settings=await getJSON('/api/ui-settings');
    applyUiSettings(settings);
    return settings;
  }catch(e){
    console.error('Dashboard-Einstellungen:',e);
    return uiSettings;
  }
}

function updateHttpsSettingsForm(){
  const enabled=$('httpsEnabled').checked;

  $('httpsHostWrap').classList.toggle(
    'menuFormHidden',
    !enabled
  );

  $('httpsRedirectWrap').classList.toggle(
    'menuFormHidden',
    !enabled
  );
}

function setFaviconPreview(url){
  const img=$('faviconPreview');
  const info=$('faviconInfo');

  if(url){
    img.src=url;
    img.style.display='';
    info.textContent='Aktuelles eigenes Favicon';
  }else{
    img.removeAttribute('src');
    img.style.display='none';
    info.textContent='Kein eigenes Favicon gesetzt.';
  }
}

function previewFavicon(){
  const file=$('faviconFile').files?.[0];

  if(!file){
    setFaviconPreview(uiSettings.favicon_url||'');
    return;
  }

  if(file.size>1024*1024){
    $('settingsMsg').textContent=
      'Favicon darf maximal 1 MB groß sein.';
    $('settingsMsg').className='msg err';
    $('faviconFile').value='';
    return;
  }

  const url=URL.createObjectURL(file);
  setFaviconPreview(url);

  $('faviconInfo').textContent=
    `${file.name} · ${Math.ceil(file.size/1024)} KB`;

  $('faviconClear').checked=false;
}

async function openDashboardSettings(){
  closeNav();

  const settings=await loadUiSettings();

  $('websiteName').value=
    settings.website_name
    || 'PVE Hardware Monitor';

  $('menuName').value=
    settings.menu_name
    || 'Server-Menü';

  $('httpsEnabled').checked=
    !!settings.https_enabled;

  $('httpsRedirect').checked=
    settings.https_redirect!==false;

  $('httpsHost').value=
    settings.https_host
    || location.hostname;

  fillThemeInputs(settings);

  $('faviconFile').value='';
  $('faviconClear').checked=false;
  $('settingsCode').value='';
  $('settingsMsg').textContent='';
  $('settingsMsg').className='msg';

  setFaviconPreview(settings.favicon_url||'');
  updateHttpsSettingsForm();

  $('settingsModal').classList.add('show');

  setTimeout(
    ()=>$('websiteName').focus(),
    80
  );
}

function closeDashboardSettings(){
  applyThemeColors(uiSettings);
  $('settingsModal').classList.remove('show');
}

async function saveDashboardSettings(){
  const websiteName=$('websiteName').value.trim();
  const menuName=$('menuName').value.trim();
  const code=$('settingsCode').value;

  if(!websiteName){
    $('settingsMsg').textContent='Webseitenname fehlt.';
    $('settingsMsg').className='msg err';
    return;
  }

  if(!menuName){
    $('settingsMsg').textContent='Menüname fehlt.';
    $('settingsMsg').className='msg err';
    return;
  }

  if(code.length<6){
    $('settingsMsg').textContent=
      'Bitte den Dashboard-Sicherheitscode eingeben.';
    $('settingsMsg').className='msg err';
    return;
  }

  const form=new FormData();

  form.append('website_name',websiteName);
  form.append('menu_name',menuName);
  form.append(
    'https_enabled',
    $('httpsEnabled').checked ? '1' : '0'
  );
  form.append(
    'https_redirect',
    $('httpsRedirect').checked ? '1' : '0'
  );
  form.append(
    'https_host',
    $('httpsHost').value.trim()
  );
  form.append('code',code);

  const theme=themeFromInputs();

  Object.entries(theme).forEach(([key,value])=>{
    form.append(key,value);
  });

  form.append(
    'favicon_action',
    $('faviconClear').checked ? 'clear' : 'keep'
  );

  const favicon=$('faviconFile').files?.[0];

  if(favicon){
    form.append('favicon',favicon);
  }

  const btn=$('settingsSave');
  btn.disabled=true;

  $('settingsMsg').textContent=
    'Einstellungen werden gespeichert ...';
  $('settingsMsg').className='msg';

  try{
    const response=await fetch(
      '/api/ui-settings',
      {
        method:'POST',
        body:form
      }
    );

    const data=await response.json().catch(()=>({}));

    if(!response.ok){
      throw new Error(
        data.error||`HTTP ${response.status}`
      );
    }

    uiSettings=data.settings||{};
    applyUiSettings(uiSettings);

    setFaviconPreview(
      uiSettings.favicon_url||''
    );

    $('faviconFile').value='';
    $('faviconClear').checked=false;
    $('settingsCode').value='';

    const cert=
      data.certificate_type
      || uiSettings.certificate_type
      || '';

    const url=
      data.url
      || (
        uiSettings.https_enabled
          ? `https://${uiSettings.https_host}/`
          : `http://${uiSettings.https_host}/`
      );

    $('settingsMsg').innerHTML=
      `Gespeichert. ${cert ? `Zertifikat: ${cert}. ` : ''}`
      + `<span class="settingsUrl">${url}</span>`;

    $('settingsMsg').className='msg ok';

    if(
      uiSettings.https_enabled
      && uiSettings.https_redirect
      && location.protocol==='http:'
    ){
      setTimeout(()=>{
        location.href=url;
      },1200);
    }

  }catch(e){
    $('settingsMsg').textContent=e.message;
    $('settingsMsg').className='msg err';
  }finally{
    btn.disabled=false;
  }
}

'''

if "function applyUiSettings(settings)" not in index:
    anchor = "let serviceLinks=[];\n"

    if anchor not in index:
        raise SystemExit(
            "FEHLER: serviceLinks JS-Anker nicht gefunden."
        )

    index = index.replace(
        anchor,
        settings_js + "\n" + anchor,
        1,
    )

# -------------------------------------------------------------------------
# Link-Protokoll-Kompatibilitätsschicht
# -------------------------------------------------------------------------

protocol_compat_js = r'''
/* PVE_LINK_PROTOCOL_COMPAT_V3 */

function dashboardLinkProtocolFromUrl(value){
  const url=String(value||'').trim().toLowerCase();

  if(url.startsWith('https://')){
    return 'https';
  }

  return 'http';
}

function dashboardStripLinkProtocol(value){
  return String(value||'').replace(
    /^https?:\/\//i,
    ''
  );
}

function dashboardSyncLinkProtocol(){
  const protocol=$('linkProtocol');
  const input=$('linkUrl');

  if(!protocol||!input)return;

  const value=String(input.value||'').trim();

  if(/^https:\/\//i.test(value)){
    protocol.value='https';
  }else if(/^http:\/\//i.test(value)){
    protocol.value='http';
  }
}

function dashboardApplyLinkProtocol(){
  const protocol=$('linkProtocol');
  const input=$('linkUrl');

  if(!protocol||!input)return;

  let value=String(input.value||'').trim();

  if(!value)return;

  if(!/^https?:\/\//i.test(value)){
    value=`${protocol.value||'http'}://${value}`;
  }

  input.value=value;
}

if(
  typeof updateMenuEditorForm==='function'
  && !window.__pveProtocolWrappedForm
){
  const originalUpdateMenuEditorForm=
    updateMenuEditorForm;

  updateMenuEditorForm=function(...args){
    const result=
      originalUpdateMenuEditorForm.apply(
        this,
        args
      );

    const wrap=$('menuProtocolWrap');
    const type=$('linkType');

    if(wrap){
      const isLink=
        !type
        || type.value==='link';

      wrap.classList.toggle(
        'menuFormHidden',
        !isLink
      );
    }

    return result;
  };

  window.__pveProtocolWrappedForm=true;
}

if(
  typeof editLink==='function'
  && !window.__pveProtocolWrappedEdit
){
  const originalEditLink=editLink;

  editLink=function(...args){
    const result=
      originalEditLink.apply(
        this,
        args
      );

    const input=$('linkUrl');
    const protocol=$('linkProtocol');

    if(input&&protocol){
      protocol.value=
        dashboardLinkProtocolFromUrl(
          input.value
        );

      input.value=
        dashboardStripLinkProtocol(
          input.value
        );
    }

    return result;
  };

  window.__pveProtocolWrappedEdit=true;
}

if(
  typeof clearLinkForm==='function'
  && !window.__pveProtocolWrappedClear
){
  const originalClearLinkForm=
    clearLinkForm;

  clearLinkForm=function(...args){
    const result=
      originalClearLinkForm.apply(
        this,
        args
      );

    const protocol=$('linkProtocol');

    if(protocol){
      protocol.value='http';
    }

    return result;
  };

  window.__pveProtocolWrappedClear=true;
}

if(
  typeof saveLink==='function'
  && !window.__pveProtocolWrappedSave
){
  const originalSaveLink=saveLink;

  saveLink=async function(...args){
    const type=$('linkType');

    if(!type||type.value==='link'){
      dashboardApplyLinkProtocol();
    }

    return await originalSaveLink.apply(
      this,
      args
    );
  };

  window.__pveProtocolWrappedSave=true;
}

setTimeout(()=>{
  const input=$('linkUrl');

  if(input&&!input.dataset.protocolWatcher){
    input.dataset.protocolWatcher='1';

    input.addEventListener(
      'input',
      dashboardSyncLinkProtocol
    );
  }

  if(
    typeof updateMenuEditorForm==='function'
  ){
    updateMenuEditorForm();
  }
},0);

'''

if "PVE_LINK_PROTOCOL_COMPAT_V3" not in index:
    keydown_anchor = "document.addEventListener('keydown'"

    pos = index.find(keydown_anchor)

    if pos < 0:
        init_match = re.search(
            r'\(async\(\)=>\{',
            index,
        )

        if not init_match:
            raise SystemExit(
                "FEHLER: JavaScript-Einfügepunkt für "
                "HTTP/HTTPS-Auswahl nicht gefunden."
            )

        pos = init_match.start()

    index = (
        index[:pos]
        + protocol_compat_js
        + "\n"
        + index[pos:]
    )

if "await loadUiSettings();" not in index:
    needle = "(async()=>{\n  try{await info()}catch(e){}\n"

    replacement = (
        "(async()=>{\n"
        "  await loadUiSettings();\n"
        "  try{await info()}catch(e){}\n"
    )

    if needle not in index:
        raise SystemExit(
            "FEHLER: Initialisierungs-Anker nicht gefunden."
        )

    index = index.replace(
        needle,
        replacement,
        1,
    )

compile(app,str(app_path),"exec")

app_tmp = app_path.with_suffix(".py.settings")
index_tmp = index_path.with_suffix(".html.settings")

app_tmp.write_text(app,encoding="utf-8")
index_tmp.write_text(index,encoding="utf-8")

app_tmp.replace(app_path)
index_tmp.replace(index_path)

print("[OK] Flask Settings-API eingebaut.")
print("[OK] Dashboard-Einstellungsdialog eingebaut.")
print("[OK] Menü-Link-Protokoll HTTP/HTTPS eingebaut.")
PY

# V133: Bestehende V131/V132-Dashboards explizit migrieren.
python3 - "$APP" "$INDEX" "$SETTINGS_FILE" <<'PYV133'
from pathlib import Path
import json
import re
import sys

app_path = Path(sys.argv[1])
index_path = Path(sys.argv[2])
settings_path = Path(sys.argv[3])

app = app_path.read_text(encoding="utf-8")
index = index_path.read_text(encoding="utf-8")

THEME_DEFAULTS = {
    "theme_bg": "#08101b",
    "theme_panel": "#101a29",
    "theme_panel2": "#131f31",
    "theme_line": "#28364b",
    "theme_text": "#eef5ff",
    "theme_muted": "#92a4bc",
    "theme_accent": "#64a7ff",
    "theme_accent2": "#9b7cff",
    "theme_good": "#37d996",
    "theme_warn": "#ffbd4a",
    "theme_bad": "#ff5f6d",
}

COLOR_RE = re.compile(r"^#[0-9A-Fa-f]{6}$")


def theme_lines(indent):
    return "".join(
        f'{indent}"{key}": "{value}",\n'
        for key, value in THEME_DEFAULTS.items()
    )


try:
    settings = json.loads(
        settings_path.read_text(encoding="utf-8")
    )
    if not isinstance(settings, dict):
        settings = {}
except Exception:
    settings = {}

settings_changed = False

for key, default in THEME_DEFAULTS.items():
    value = str(settings.get(key, "")).strip()
    if not COLOR_RE.fullmatch(value):
        settings[key] = default
        settings_changed = True

if settings_changed or not settings_path.exists():
    settings_path.parent.mkdir(parents=True, exist_ok=True)
    settings_path.write_text(
        json.dumps(
            settings,
            ensure_ascii=False,
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )


m = re.search(
    r'(def read_ui_settings\(\):\s*\n'
    r'\s*defaults\s*=\s*\{\s*\n)'
    r'(.*?)'
    r'(\n\s*\}\s*\n)',
    app,
    re.S,
)

if not m:
    raise SystemExit(
        "FEHLER: read_ui_settings()-Defaults nicht gefunden."
    )

if '"theme_bg"' not in m.group(2):
    body = m.group(2)
    if body and not body.endswith("\n"):
        body += "\n"
    body += theme_lines("        ")
    app = (
        app[:m.start()]
        + m.group(1)
        + body
        + m.group(3)
        + app[m.end():]
    )

m = re.search(
    r'(helper_payload\s*=\s*\{\s*\n)'
    r'(.*?)'
    r'(\n\s*\}\s*\n\s*\n'
    r'\s*favicon\s*=\s*request\.files\.get\("favicon"\))',
    app,
    re.S,
)

if not m:
    raise SystemExit(
        "FEHLER: helper_payload der Settings-API nicht gefunden."
    )

if '"theme_bg"' not in m.group(2):
    theme_payload = "".join(
        f'        "{key}": str(payload.get("{key}", "")).strip(),\n'
        for key in THEME_DEFAULTS
    )
    body = m.group(2)
    if body and not body.endswith("\n"):
        body += "\n"
    body += theme_payload
    app = (
        app[:m.start()]
        + m.group(1)
        + body
        + m.group(3)
        + app[m.end():]
    )


theme_html = r'''
      <div class="full">
        <div class="themeSectionHead">
          <div>
            <strong>Farbschema</strong>
            <span>Farben werden sofort als Vorschau angezeigt.</span>
          </div>
          <button
            type="button"
            class="themeReset"
            onclick="resetThemeColors()"
          >Standardfarben</button>
        </div>

        <div class="themeGrid">
          <div class="themeColor"><label for="themeBg">Hintergrund</label><input id="themeBg" type="color" value="#08101b" oninput="previewThemeColors()"></div>
          <div class="themeColor"><label for="themePanel">Panel dunkel</label><input id="themePanel" type="color" value="#101a29" oninput="previewThemeColors()"></div>
          <div class="themeColor"><label for="themePanel2">Panel hell</label><input id="themePanel2" type="color" value="#131f31" oninput="previewThemeColors()"></div>
          <div class="themeColor"><label for="themeLine">Linien / Rahmen</label><input id="themeLine" type="color" value="#28364b" oninput="previewThemeColors()"></div>
          <div class="themeColor"><label for="themeText">Text</label><input id="themeText" type="color" value="#eef5ff" oninput="previewThemeColors()"></div>
          <div class="themeColor"><label for="themeMuted">Sekundärtext</label><input id="themeMuted" type="color" value="#92a4bc" oninput="previewThemeColors()"></div>
          <div class="themeColor"><label for="themeAccent">Akzent</label><input id="themeAccent" type="color" value="#64a7ff" oninput="previewThemeColors()"></div>
          <div class="themeColor"><label for="themeAccent2">Akzent 2</label><input id="themeAccent2" type="color" value="#9b7cff" oninput="previewThemeColors()"></div>
          <div class="themeColor"><label for="themeGood">OK</label><input id="themeGood" type="color" value="#37d996" oninput="previewThemeColors()"></div>
          <div class="themeColor"><label for="themeWarn">Warnung</label><input id="themeWarn" type="color" value="#ffbd4a" oninput="previewThemeColors()"></div>
          <div class="themeColor"><label for="themeBad">Fehler</label><input id="themeBad" type="color" value="#ff5f6d" oninput="previewThemeColors()"></div>
        </div>

        <div class="themeHint">
          Erst „Einstellungen speichern“ übernimmt das Farbschema dauerhaft.
        </div>
      </div>

'''

if 'id="themeBg"' not in index:
    anchor = (
        '      <div class="full">\n'
        '        <label for="faviconFile">Favicon hochladen</label>'
    )

    if anchor not in index:
        raise SystemExit(
            "FEHLER: Favicon-Feld als Theme-Einfügepunkt nicht gefunden."
        )

    index = index.replace(
        anchor,
        theme_html + anchor,
        1,
    )


theme_js = r'''
const THEME_DEFAULTS={
  theme_bg:'#08101b',
  theme_panel:'#101a29',
  theme_panel2:'#131f31',
  theme_line:'#28364b',
  theme_text:'#eef5ff',
  theme_muted:'#92a4bc',
  theme_accent:'#64a7ff',
  theme_accent2:'#9b7cff',
  theme_good:'#37d996',
  theme_warn:'#ffbd4a',
  theme_bad:'#ff5f6d'
};

const THEME_VARS={
  theme_bg:'--bg',
  theme_panel:'--panel',
  theme_panel2:'--panel2',
  theme_line:'--line',
  theme_text:'--text',
  theme_muted:'--muted',
  theme_accent:'--accent',
  theme_accent2:'--accent2',
  theme_good:'--good',
  theme_warn:'--warn',
  theme_bad:'--bad'
};

const THEME_FIELDS={
  theme_bg:'themeBg',
  theme_panel:'themePanel',
  theme_panel2:'themePanel2',
  theme_line:'themeLine',
  theme_text:'themeText',
  theme_muted:'themeMuted',
  theme_accent:'themeAccent',
  theme_accent2:'themeAccent2',
  theme_good:'themeGood',
  theme_warn:'themeWarn',
  theme_bad:'themeBad'
};

function validThemeColor(value,fallback){
  const color=String(value||'').trim();
  return /^#[0-9a-f]{6}$/i.test(color)
    ? color.toLowerCase()
    : fallback;
}

function applyThemeColors(settings){
  const root=document.documentElement;
  Object.entries(THEME_VARS).forEach(([key,cssVar])=>{
    root.style.setProperty(
      cssVar,
      validThemeColor(
        settings?.[key],
        THEME_DEFAULTS[key]
      )
    );
  });
}

function fillThemeInputs(settings){
  Object.entries(THEME_FIELDS).forEach(([key,id])=>{
    const el=$(id);
    if(el){
      el.value=validThemeColor(
        settings?.[key],
        THEME_DEFAULTS[key]
      );
    }
  });
}

function themeFromInputs(){
  const theme={};
  Object.entries(THEME_FIELDS).forEach(([key,id])=>{
    theme[key]=validThemeColor(
      $(id)?.value,
      THEME_DEFAULTS[key]
    );
  });
  return theme;
}

function previewThemeColors(){
  applyThemeColors(themeFromInputs());
}

function resetThemeColors(){
  fillThemeInputs(THEME_DEFAULTS);
  previewThemeColors();
}

'''

if "const THEME_DEFAULTS={" not in index:
    anchor = "function ensureFaviconLink(){"
    if anchor not in index:
        raise SystemExit(
            "FEHLER: ensureFaviconLink() für Theme-JS nicht gefunden."
        )
    index = index.replace(
        anchor,
        theme_js + anchor,
        1,
    )

apply_match = re.search(
    r'function applyUiSettings\(settings\)\{.*?\n\}',
    index,
    re.S,
)
if not apply_match:
    raise SystemExit("FEHLER: applyUiSettings() nicht gefunden.")

apply_block = apply_match.group(0)
if "applyThemeColors(uiSettings);" not in apply_block:
    needle = "  const favicon=ensureFaviconLink();"
    if needle not in apply_block:
        raise SystemExit(
            "FEHLER: Favicon-Anker in applyUiSettings() fehlt."
        )
    apply_block = apply_block.replace(
        needle,
        "  applyThemeColors(uiSettings);\n\n" + needle,
        1,
    )
    index = (
        index[:apply_match.start()]
        + apply_block
        + index[apply_match.end():]
    )

open_match = re.search(
    r'async function openDashboardSettings\(\)\{.*?\n\}',
    index,
    re.S,
)
if not open_match:
    raise SystemExit(
        "FEHLER: openDashboardSettings() nicht gefunden."
    )

open_block = open_match.group(0)
if "fillThemeInputs(settings);" not in open_block:
    needle = "  $('faviconFile').value='';"
    if needle not in open_block:
        raise SystemExit(
            "FEHLER: Favicon-Anker in openDashboardSettings() fehlt."
        )
    open_block = open_block.replace(
        needle,
        "  fillThemeInputs(settings);\n\n" + needle,
        1,
    )
    index = (
        index[:open_match.start()]
        + open_block
        + index[open_match.end():]
    )

save_match = re.search(
    r'async function saveDashboardSettings\(\)\{.*?\n\}',
    index,
    re.S,
)
if not save_match:
    raise SystemExit(
        "FEHLER: saveDashboardSettings() nicht gefunden."
    )

save_block = save_match.group(0)
if "const theme=themeFromInputs();" not in save_block:
    needle = "  form.append('code',code);"
    if needle not in save_block:
        raise SystemExit(
            "FEHLER: Code-Anker in saveDashboardSettings() fehlt."
        )
    addition = """  form.append('code',code);

  const theme=themeFromInputs();

  Object.entries(theme).forEach(([key,value])=>{
    form.append(key,value);
  });"""
    save_block = save_block.replace(
        needle,
        addition,
        1,
    )
    index = (
        index[:save_match.start()]
        + save_block
        + index[save_match.end():]
    )

for required in (
    'id="themeBg"',
    "const THEME_DEFAULTS={",
    "applyThemeColors(uiSettings);",
    "fillThemeInputs(settings);",
    "const theme=themeFromInputs();",
):
    if required not in index:
        raise SystemExit(
            "FEHLER: Theme-Migration unvollständig: " + required
        )

for required in (
    '"theme_bg"',
    '"theme_bad"',
):
    if required not in app:
        raise SystemExit(
            "FEHLER: Settings-API Theme-Migration unvollständig: "
            + required
        )

app_path.write_text(app, encoding="utf-8")
index_path.write_text(index, encoding="utf-8")

print("[OK] Bestehende Dashboard-Settings auf Theme V133 migriert.")
PYV133

chmod 644 "$APP" "$INDEX"
chown root:root "$APP" "$INDEX"

python3 -m py_compile "$APP"
python3 -m py_compile "$SETTINGS_HELPER"

systemctl restart pve-sensor-web.service
systemctl restart nginx

sleep 2

echo
echo "API-Test:"
curl -fsS http://127.0.0.1:9105/api/ui-settings |
    python3 -m json.tool || true

echo
echo "============================================================"
echo " FERTIG"
echo "============================================================"
echo
echo "Im Dashboard:"
echo "  ☰ Menü"
echo "  -> ⚙ Dienste verwalten"
echo "     -> Links mit HTTP / HTTPS Auswahl"
echo "  -> 🎨 Dashboard anpassen"
echo "     -> Webseitenname"
echo "     -> Menüname"
echo "     -> Favicon"
echo "     -> HTTPS"
echo
echo "HTTPS:"
echo "  Vorhandenes Let's-Encrypt-Zertifikat wird automatisch genutzt."
echo "  Sonst wird ein selbstsigniertes Zertifikat erzeugt."
echo
echo "Browser anschließend einmal:"
echo "  STRG + F5"
echo
echo "Backup:"
echo "  $BACKUP"
echo
echo "Log:"
echo "  $LOGFILE"
echo "============================================================"
__PVE_DASHBOARD_SETTINGS_V4__

    chmod 700 "$patch"
    bash "$patch"
    rm -f "$patch"

    ok "Dashboard-Einstellungen, HTTPS und Favicon sind eingerichtet."
}


# =============================================================================
# V68 · DASHBOARD HTTP 80 + HTTPS 443 · CA-OUTPUT-FIX FEST INTEGRIERT
# =============================================================================

configure_dashboard_dual_ports_v65() {
    (( INSTALL_DASHBOARD )) || return 0

    local ip="${DASHBOARD_IP:-}"
    local hostname=""
    local cert_dir=""
    local issued=""
    local cert=""
    local key=""
    local helper="/usr/local/sbin/pve-dashboard-settings-helper"

    ip="${ip:-$(hostname -I | awk '{print $1}')}"
    hostname="$(hostname -s)"

    [[ -n "$ip" ]] || die "Dashboard-IP für TLS fehlt."
    [[ -x "$helper" ]] || die "Dashboard Settings Helper fehlt."

    cert_dir="$(mktemp -d /tmp/pve-dashboard-v67.XXXXXX)"

    read_issued_cert_pair_v68 \
        "$ip" \
        "$hostname" \
        "$cert_dir" \
        cert \
        key

    [[ -s "$cert" ]] || \
        die "Dashboard: erzeugtes Zertifikat wurde nicht gefunden."

    [[ -s "$key" ]] || \
        die "Dashboard: erzeugter Zertifikatsschlüssel wurde nicht gefunden."

    mkdir -p /etc/pve-sensor-dashboard
    cp -f "$cert" /etc/pve-sensor-dashboard/dashboard.crt
    cp -f "$key" /etc/pve-sensor-dashboard/dashboard.key
    chmod 644 /etc/pve-sensor-dashboard/dashboard.crt
    chmod 600 /etc/pve-sensor-dashboard/dashboard.key
    printf '%s\n' "$ip" > /etc/pve-sensor-dashboard/tls-host.txt
    chmod 600 /etc/pve-sensor-dashboard/tls-host.txt

    rm -rf "$cert_dir"

    python3 - "$ip" <<'PY' | "$helper" apply
import json
import sys
from pathlib import Path

ip = sys.argv[1]
settings_file = Path("/etc/pve-sensor-dashboard/ui.json")

try:
    current = json.loads(settings_file.read_text(encoding="utf-8"))
except Exception:
    current = {}

print(json.dumps({
    "website_name": current.get("website_name") or "PVE Hardware Monitor",
    "menu_name": current.get("menu_name") or "Server-Menü",
    "https_enabled": True,
    "https_redirect": True,
    "https_host": ip,
    "favicon_action": "keep",
}))
PY

    nginx -t
    systemctl reload nginx

    curl -fsS http://127.0.0.1/ >/dev/null
    curl -kfsS https://127.0.0.1/ >/dev/null

    register_managed_tls_service_v88 "host-dashboard" "0" "PVE Dashboard" "$ip" "$hostname"
    ok "Dashboard HTTPS: https://${ip}/ · HTTP leitet automatisch um."
}

# =============================================================================
# DASHBOARD SETTINGS - SYSTEMD SCHREIBBEREICHE V2
# =============================================================================

install_dashboard_settings_write_paths() {
    header "DASHBOARD SETTINGS - SCHREIBBEREICHE V2"

    local service="pve-sensor-web.service"
    local dropin_dir="/etc/systemd/system/${service}.d"
    local dropin="${dropin_dir}/dashboard-settings-write.conf"

    mkdir -p \
        "$dropin_dir" \
        /var/lib/pve-sensor-dashboard-web \
        /opt/nodezero/dashboard/static \
        /etc/pve-sensor-dashboard \
        /etc/nginx/sites-available \
        /etc/nginx/sites-enabled

    chown pve-monitor:pve-monitor /var/lib/pve-sensor-dashboard-web
    chmod 700 /var/lib/pve-sensor-dashboard-web

    cat > "$dropin" <<'EOF'
[Service]
# Basis-Sandbox weiter aktiv.
# /etc/pve-sensor-dashboard wird bewusst NICHT read-only gesetzt, weil dort
# UI-Einstellungen und lokale TLS-Dateien gespeichert werden.

ReadOnlyPaths=
ReadOnlyPaths=/opt/nodezero/dashboard /var/lib/pve-sensor-dashboard

ReadWritePaths=
ReadWritePaths=/var/lib/pve-sensor-dashboard-web
ReadWritePaths=/opt/nodezero/dashboard/static
ReadWritePaths=/etc/pve-sensor-dashboard
ReadWritePaths=/etc/nginx/sites-available
ReadWritePaths=/etc/nginx/sites-enabled
EOF

    chmod 644 "$dropin"
    chown root:root "$dropin"

    systemd-analyze verify \
        "/etc/systemd/system/${service}" \
        >/dev/null

    systemctl daemon-reload
    systemctl restart "$service"

    sleep 1

    systemctl is-active --quiet "$service" || \
        die "Dashboard-Webdienst läuft nach Schreibrechte-Fix nicht."

    local pid
    pid="$(
        systemctl show "$service" \
            -p MainPID \
            --value
    )"

    [[ "$pid" =~ ^[0-9]+$ ]] && (( pid > 1 )) || \
        die "Dashboard-Webdienst MainPID fehlt."

    local dir testfile

    for dir in \
        /var/lib/pve-sensor-dashboard-web \
        /opt/nodezero/dashboard/static \
        /etc/pve-sensor-dashboard \
        /etc/nginx/sites-available \
        /etc/nginx/sites-enabled
    do
        testfile="${dir}/.pve-dashboard-write-test-$$"

        if ! nsenter -t "$pid" -m -- \
            sh -c 'touch "$1" && rm -f "$1"' sh "$testfile" 2>/dev/null
        then
            die "Dashboard-Customizing-Pfad weiterhin nicht schreibbar: $dir"
        fi
    done

    ok "Dashboard-Customizing-Schreibbereiche korrekt freigegeben."
}


# =============================================================================
# DASHBOARD EINSTELLUNGEN - GEMEINSAMES FENSTER
# =============================================================================
install_dashboard_settings_hub_v42() {
    header "DASHBOARD EINSTELLUNGEN - GEMEINSAMES FENSTER"
    local patch="/tmp/install_dashboard_settings_hub_v42.$$"
    cat > "$patch" <<'__PVE_V42_INSTALL_DASHBOARD_SETTINGS_HUB_V42__'
#!/usr/bin/env bash
set -Eeuo pipefail

STAMP="$(date +%d-%m-%H-%M)"
LOGFILE="/root/diagnose/diagnose-dashboard-einstellungen-tabs-${STAMP}.txt"
if [[ -e "$LOGFILE" ]]; then
  N=2
  while [[ -e "/root/diagnose/diagnose-dashboard-einstellungen-tabs-${STAMP}-${N}.txt" ]]; do N=$((N+1)); done
  LOGFILE="/root/diagnose/diagnose-dashboard-einstellungen-tabs-${STAMP}-${N}.txt"
fi
exec > >(tee -a "$LOGFILE") 2>&1

[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo "FEHLER: Bitte als root ausführen."; exit 1; }

INDEX="/opt/nodezero/dashboard/static/index.html"
BACKUP="/root/backups/pve-dashboard-einstellungen-tabs-backup-$(date +%Y%m%d-%H%M%S)"
[[ -f "$INDEX" ]] || { echo "FEHLER: $INDEX fehlt."; exit 1; }

echo "============================================================"
echo " DASHBOARD - EINSTELLUNGEN MIT 2 REITERN"
echo "============================================================"
echo "Seitenmenü: ⚙ Einstellungen"
echo "Reiter: [ Linkverwaltung ] [ Dashboard ]"
echo "Standard: Linkverwaltung"
echo "Log: $LOGFILE"
echo

mkdir -p "$BACKUP"
cp -a "$INDEX" "$BACKUP/index.html"

python3 - "$INDEX" <<'PY'
from pathlib import Path
import re, sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

# 1) Seitenmenü: genau ein Button
if 'id="dashboardSettingsHubButton"' not in text:
    link_btn = re.compile(
        r'<button\b(?=[^>]*class=["\'][^"\']*\bnavManage\b[^"\']*["\'])'
        r'(?=[^>]*onclick=["\']openLinkManager\(\)["\'])[^>]*>.*?</button>',
        re.S | re.I
    )
    settings_btn = re.compile(
        r'<button\b(?=[^>]*class=["\'][^"\']*\bnavManage\b[^"\']*["\'])'
        r'(?=[^>]*onclick=["\']openDashboardSettings\(\)["\'])[^>]*>.*?</button>',
        re.S | re.I
    )
    if not link_btn.search(text):
        raise SystemExit("FEHLER: Linkverwaltungs-Button nicht gefunden.")
    replacement = (
        '<button id="dashboardSettingsHubButton" class="navManage" '
        'onclick="openUnifiedSettings(\'links\')">⚙ Einstellungen</button>'
    )
    text = link_btn.sub(lambda _: replacement, text, count=1)
    text = settings_btn.sub("", text, count=1)
else:
    text = re.sub(
        r'<button\b(?=[^>]*class=["\'][^"\']*\bnavManage\b[^"\']*["\'])'
        r'(?=[^>]*onclick=["\']openDashboardSettings\(\)["\'])[^>]*>.*?</button>',
        "", text, count=1, flags=re.S | re.I
    )

# V128: Projekt-/Quellenverweis direkt unterhalb von "Einstellungen".
github_link = (
    '<a id="dashboardGithubLink" class="navGithub" '
    'href="https://github.com/Technox90/homeatic" '
    'target="_blank" rel="noopener noreferrer" '
    'aria-label="GitHub Repository Technox90 homeatic">'
    '<span class="navGithubIcon" aria-hidden="true">GH</span>'
    '<span class="navGithubText">'
    '<span class="navGithubName">GitHub</span>'
    '<span class="navGithubRepo">Technox90 / homeatic</span>'
    '</span>'
    '</a>'
)

settings_anchor = re.compile(
    r'(<button\b(?=[^>]*id=["\']dashboardSettingsHubButton["\'])[^>]*>.*?</button>)',
    re.S | re.I
)

if 'id="dashboardGithubLink"' not in text:
    if not settings_anchor.search(text):
        raise SystemExit("FEHLER: Einstellungen-Button für GitHub-Verweis nicht gefunden.")
    text = settings_anchor.sub(lambda m: m.group(1) + "\n  " + github_link, text, count=1)

github_css = r'''
/* PVE_DASHBOARD_GITHUB_LINK_V1 */
.navGithub{
  display:flex;align-items:center;gap:10px;
  margin-top:9px;padding:10px 11px;
  border-top:1px solid #26384f;
  border-radius:10px;
  color:var(--text);text-decoration:none;
  transition:background .15s ease,border-color .15s ease
}
.navGithub:hover{
  background:#121f31;
  border-color:#355174
}
.navGithubIcon{
  width:32px;height:32px;display:grid;place-items:center;
  flex:0 0 32px;border-radius:9px;
  background:#172437;border:1px solid #304966;
  color:#d8e7f8;font-size:10px;font-weight:850;letter-spacing:.05em
}
.navGithubText{display:flex;flex-direction:column;min-width:0}
.navGithubName{font-size:12px;font-weight:750}
.navGithubRepo{
  margin-top:2px;color:var(--muted);font-size:10px;
  white-space:nowrap;overflow:hidden;text-overflow:ellipsis
}
'''

if "/* PVE_DASHBOARD_GITHUB_LINK_V1 */" not in text:
    if "</style>" not in text:
        raise SystemExit("FEHLER: </style> für GitHub-CSS nicht gefunden.")
    text = text.replace("</style>", github_css + "\n</style>", 1)

visibility_css = r'''
/* PVE_SETTINGS_MENU_VISIBILITY_V133 */
/* V134: Footerblock aus Trenner + Einstellungen + GitHub unten halten. */
.sideNav{
  overflow-y:auto;
}
#navSettingsDivider{
  flex:0 0 auto;
  margin-top:auto !important;
}
#dashboardSettingsHubButton{
  margin-top:0 !important;
  flex:0 0 auto;
}
#dashboardGithubLink{
  flex:0 0 auto;
  margin-bottom:6px;
}
'''

if "/* PVE_SETTINGS_MENU_VISIBILITY_V133 */" not in text:
    if "</style>" not in text:
        raise SystemExit(
            "FEHLER: </style> für Settings-Sichtbarkeit nicht gefunden."
        )
    text = text.replace(
        "</style>",
        visibility_css + "\n</style>",
        1,
    )

# 2) Alte Dialogtitel umbenennen
text = re.sub(
    r'(<div class="modal" id="linksModal">.*?<h2>).*?(</h2>)',
    r'\1Linkverwaltung\2', text, count=1, flags=re.S
)
text = re.sub(
    r'(<div class="modal" id="settingsModal">.*?<h2>).*?(</h2>)',
    r'\1Dashboard\2', text, count=1, flags=re.S
)

# 3) CSS
css = r'''
/* PVE_SETTINGS_HUB_V1 */
.settingsHubDialog{width:min(980px,calc(100vw - 28px));max-width:980px}
.settingsHubHeader{display:flex;align-items:flex-start;justify-content:space-between;gap:16px;margin-bottom:14px}
.settingsHubHeader h2{margin:0 0 4px}
.settingsHubHeader p{margin:0;color:var(--muted);font-size:12px}
.settingsHubTabs{display:flex;gap:7px;margin-bottom:16px;padding-bottom:10px;border-bottom:1px solid var(--line)}
.settingsHubTab{min-height:40px;padding:8px 15px;border:1px solid #344a66;border-radius:9px;background:#0b1420;color:#aebed3;font-weight:750;cursor:pointer}
.settingsHubTab:hover{background:#132033;color:#eef5ff}
.settingsHubTab.active{border-color:#5d8fc9;background:#192b43;color:#eef5ff}
.settingsHubPanel{display:none}
.settingsHubPanel.active{display:block}
.settingsHubPanel>.dialog{width:100%;max-width:none;margin:0;padding:0;border:0;border-radius:0;background:transparent;box-shadow:none}
.settingsHubPanel>.dialog>h2{display:none}
.settingsHubPanel>.dialog>p:first-of-type{margin-top:0}
#linksModal.settingsHubSource,#settingsModal.settingsHubSource{display:none!important}
'''
if "/* PVE_SETTINGS_HUB_V1 */" not in text:
    if "</style>" not in text:
        raise SystemExit("FEHLER: </style> fehlt.")
    text = text.replace("</style>", css + "\n</style>", 1)

# 4) Gemeinsames Fenster
hub = r'''
<div class="modal" id="settingsHubModal">
  <div class="dialog settingsHubDialog">
    <div class="settingsHubHeader">
      <div>
        <h2>Einstellungen</h2>
        <p>Linkverwaltung und Dashboard zentral verwalten.</p>
      </div>
    </div>
    <div class="settingsHubTabs" role="tablist" aria-label="Einstellungen">
      <button id="settingsHubTabLinks" class="settingsHubTab active" type="button"
        role="tab" aria-selected="true"
        onclick="switchUnifiedSettingsTab('links')">Linkverwaltung</button>
      <button id="settingsHubTabDashboard" class="settingsHubTab" type="button"
        role="tab" aria-selected="false"
        onclick="switchUnifiedSettingsTab('dashboard')">Dashboard</button>
    </div>
    <div id="settingsHubPanelLinks" class="settingsHubPanel active" role="tabpanel"></div>
    <div id="settingsHubPanelDashboard" class="settingsHubPanel" role="tabpanel"></div>
  </div>
</div>
'''
if 'id="settingsHubModal"' not in text:
    anchor = '<div class="modal" id="modal">'
    if anchor not in text:
        raise SystemExit("FEHLER: Modal-Einfügepunkt fehlt.")
    text = text.replace(anchor, hub + "\n" + anchor, 1)

# 5) JS
js = r'''
/* PVE_SETTINGS_HUB_V1 */
let dashboardSettingsHubInitialized=false;

function initializeUnifiedSettings(){
  if(dashboardSettingsHubInitialized)return;
  const linksSource=$('linksModal');
  const dashboardSource=$('settingsModal');
  const linksPanel=$('settingsHubPanelLinks');
  const dashboardPanel=$('settingsHubPanelDashboard');
  if(!linksSource||!dashboardSource||!linksPanel||!dashboardPanel){
    console.error('Einstellungs-Hub: Quelldialoge fehlen.');
    return;
  }
  const linksDialog=linksSource.querySelector('.dialog');
  const dashboardDialog=dashboardSource.querySelector('.dialog');
  if(!linksDialog||!dashboardDialog){
    console.error('Einstellungs-Hub: Dialoginhalt fehlt.');
    return;
  }
  linksPanel.appendChild(linksDialog);
  dashboardPanel.appendChild(dashboardDialog);
  linksSource.classList.add('settingsHubSource');
  dashboardSource.classList.add('settingsHubSource');
  dashboardSettingsHubInitialized=true;
}

function setUnifiedSettingsTab(tab){
  const d=tab==='dashboard';
  $('settingsHubTabLinks').classList.toggle('active',!d);
  $('settingsHubTabDashboard').classList.toggle('active',d);
  $('settingsHubPanelLinks').classList.toggle('active',!d);
  $('settingsHubPanelDashboard').classList.toggle('active',d);
  $('settingsHubTabLinks').setAttribute('aria-selected',String(!d));
  $('settingsHubTabDashboard').setAttribute('aria-selected',String(d));
}

const dashboardLegacyOpenLinkManager=
  typeof openLinkManager==='function' ? openLinkManager : null;
const dashboardLegacyOpenSettings=
  typeof openDashboardSettings==='function' ? openDashboardSettings : null;

async function prepareUnifiedSettingsTab(tab){
  if(tab==='dashboard'){
    if(dashboardLegacyOpenSettings){
      await dashboardLegacyOpenSettings();
      if($('settingsModal'))$('settingsModal').classList.remove('show');
    }
  }else{
    if(dashboardLegacyOpenLinkManager){
      dashboardLegacyOpenLinkManager();
      if($('linksModal'))$('linksModal').classList.remove('show');
    }
  }
}

async function openUnifiedSettings(tab='links'){
  closeNav();
  initializeUnifiedSettings();
  const wanted=tab==='dashboard'?'dashboard':'links';
  await prepareUnifiedSettingsTab(wanted);
  setUnifiedSettingsTab(wanted);
  $('settingsHubModal').classList.add('show');
}

async function switchUnifiedSettingsTab(tab){
  initializeUnifiedSettings();
  const wanted=tab==='dashboard'?'dashboard':'links';
  await prepareUnifiedSettingsTab(wanted);
  setUnifiedSettingsTab(wanted);
}

function closeUnifiedSettings(){
  if(typeof applyThemeColors==='function' && typeof uiSettings!=='undefined'){
    applyThemeColors(uiSettings);
  }
  $('settingsHubModal').classList.remove('show');
  if($('linksModal'))$('linksModal').classList.remove('show');
  if($('settingsModal'))$('settingsModal').classList.remove('show');
}

openLinkManager=function(){return openUnifiedSettings('links')};
openDashboardSettings=function(){return openUnifiedSettings('dashboard')};
closeLinkManager=function(){closeUnifiedSettings()};
closeDashboardSettings=function(){closeUnifiedSettings()};

document.addEventListener('keydown',event=>{
  if(event.key==='Escape' && $('settingsHubModal') &&
     $('settingsHubModal').classList.contains('show')){
    closeUnifiedSettings();
  }
});
'''
# Insert only once into script area
script_start = text.find("<script")
script_part = text[script_start:] if script_start >= 0 else text
if "/* PVE_SETTINGS_HUB_V1 */" not in script_part:
    m = re.search(r'\(async\(\)=>\{', text)
    if m:
        pos = m.start()
    else:
        pos = text.rfind("</script>")
        if pos < 0:
            raise SystemExit("FEHLER: JS-Einfügepunkt fehlt.")
    text = text[:pos] + js + "\n" + text[pos:]

for required in (
    'id="dashboardSettingsHubButton"',
    'id="settingsHubModal"',
    ">Linkverwaltung</button>",
    ">Dashboard</button>",
    "function openUnifiedSettings",
):
    if required not in text:
        raise SystemExit("FEHLER: Prüfung fehlgeschlagen: " + required)

path.write_text(text, encoding="utf-8")
print("[OK] Nur noch '⚙ Einstellungen' im Seitenmenü.")
print("[OK] Ein gemeinsames Fenster mit zwei Reitern.")
print("[OK] Standardreiter: Linkverwaltung.")
PY

systemctl restart pve-sensor-web.service
systemctl restart nginx
sleep 2

echo
echo "Prüfung:"
grep -Fq 'id="dashboardSettingsHubButton"' "$INDEX" && echo "  [OK] Einstellungen-Button"
grep -Fq 'id="dashboardGithubLink"' "$INDEX" && echo "  [OK] GitHub-Verweis"
grep -Fq 'https://github.com/Technox90/homeatic' "$INDEX" && echo "  [OK] GitHub-Ziel"
grep -Fq 'id="settingsHubModal"' "$INDEX" && echo "  [OK] Gemeinsames Fenster"
grep -Fq '>Linkverwaltung</button>' "$INDEX" && echo "  [OK] Reiter Linkverwaltung"
grep -Fq '>Dashboard</button>' "$INDEX" && echo "  [OK] Reiter Dashboard"

echo
echo "============================================================"
echo " FERTIG"
echo "============================================================"
echo "Seitenmenü: ⚙ Einstellungen"
echo "Fenster: [ Linkverwaltung ] [ Dashboard ]"
echo "Standardreiter: Linkverwaltung"
echo "Browser: STRG + F5"
echo "Backup: $BACKUP"
echo "Log: $LOGFILE"
__PVE_V42_INSTALL_DASHBOARD_SETTINGS_HUB_V42__
    chmod 700 "$patch"
    bash "$patch"
    rm -f "$patch"
}

# =============================================================================
# DASHBOARD KATEGORIEN
# =============================================================================
install_dashboard_categories_v42() {
    header "DASHBOARD KATEGORIEN"
    local patch="/tmp/install_dashboard_categories_v42.$$"
    cat > "$patch" <<'__PVE_V42_INSTALL_DASHBOARD_CATEGORIES_V42__'
#!/usr/bin/env bash
set -Eeuo pipefail

STAMP="$(date +%d-%m-%H-%M)"
LOGFILE="/root/diagnose/diagnose-dashboard-kategorien-test-${STAMP}.txt"

if [[ -e "$LOGFILE" ]]; then
    N=2
    while [[ -e "/root/diagnose/diagnose-dashboard-kategorien-test-${STAMP}-${N}.txt" ]]; do
        N=$((N + 1))
    done
    LOGFILE="/root/diagnose/diagnose-dashboard-kategorien-test-${STAMP}-${N}.txt"
fi

exec > >(tee -a "$LOGFILE") 2>&1

[[ ${EUID:-$(id -u)} -eq 0 ]] || {
    echo "FEHLER: Bitte als root auf dem Proxmox-Host ausführen."
    exit 1
}

APP="/opt/nodezero/dashboard/app.py"
INDEX="/opt/nodezero/dashboard/static/index.html"
DATA_DIR="/var/lib/pve-sensor-dashboard-web"
CATEGORY_FILE="${DATA_DIR}/categories.json"

BACKUP="/root/backups/pve-dashboard-kategorien-test-backup-$(date +%Y%m%d-%H%M%S)"

[[ -f "$APP" ]] || {
    echo "FEHLER: $APP fehlt."
    exit 1
}

[[ -f "$INDEX" ]] || {
    echo "FEHLER: $INDEX fehlt."
    exit 1
}

echo "============================================================"
echo " DASHBOARD - KATEGORIEN TEST-UPDATE V1"
echo "============================================================"
echo
echo "Ziel:"
echo "  ⚙ Einstellungen"
echo "  [ Webseitenverwaltung ] [ Kategorien ] [ Dashboard ]"
echo
echo "Kategorien:"
echo "  - Immer offen"
echo "  - Geöffnet, aber einklappbar"
echo "  - Eingeklappt, aber aufklappbar"
echo
echo "Technik:"
echo "  Kategorien werden separat gespeichert."
echo "  Das bestehende Link-Backend wird NICHT ersetzt."
echo "  Live-Metriken / Verlauf werden NICHT verändert."
echo
echo "Log:"
echo "  $LOGFILE"
echo

mkdir -p "$BACKUP" "$DATA_DIR"

cp -a "$APP" "$BACKUP/app.py"
cp -a "$INDEX" "$BACKUP/index.html"
[[ -f "$CATEGORY_FILE" ]] && cp -a "$CATEGORY_FILE" "$BACKUP/categories.json"

rollback() {
    echo
    echo "============================================================"
    echo " AUTOMATISCHES ROLLBACK"
    echo "============================================================"
    echo

    cp -a "$BACKUP/app.py" "$APP"
    cp -a "$BACKUP/index.html" "$INDEX"

    if [[ -f "$BACKUP/categories.json" ]]; then
        cp -a "$BACKUP/categories.json" "$CATEGORY_FILE"
    else
        rm -f "$CATEGORY_FILE"
    fi

    chmod 644 "$APP" "$INDEX"
    chown root:root "$APP" "$INDEX"

    if [[ -f "$CATEGORY_FILE" ]]; then
        chmod 600 "$CATEGORY_FILE"
        chown pve-monitor:pve-monitor "$CATEGORY_FILE" 2>/dev/null || true
    fi

    systemctl restart pve-sensor-web.service || true
    systemctl restart nginx || true

    echo "Vorheriger Dashboard-Stand wurde wiederhergestellt."
    echo "Backup:"
    echo "  $BACKUP"
}

trap 'echo "FEHLER in Zeile $LINENO"; rollback' ERR

echo "===== 1. BASIS VORHER PRÜFEN ====="

python3 -m py_compile "$APP"

CURRENT_BEFORE="$(
    curl -m 5 -fsS \
        http://127.0.0.1:9105/api/current \
        2>/dev/null || true
)"

if [[ -z "$CURRENT_BEFORE" ]]; then
    echo "FEHLER: /api/current antwortet bereits VOR dem Update nicht."
    echo "Update wird nicht gestartet."
    exit 1
fi

echo "[OK] /api/current funktioniert vor dem Update."

echo
echo "===== 2. KATEGORIE-DATEI VORBEREITEN ====="

if [[ ! -s "$CATEGORY_FILE" ]]; then
    cat > "$CATEGORY_FILE" <<'JSON'
{
  "categories": [],
  "assignments": {}
}
JSON
fi

chmod 600 "$CATEGORY_FILE"
chown pve-monitor:pve-monitor "$CATEGORY_FILE" 2>/dev/null || true

echo "[OK] $CATEGORY_FILE"

echo
echo "===== 3. BACKEND ERWEITERN ====="

python3 - "$APP" <<'PY'
from pathlib import Path
import py_compile
import sys

app_path = Path(sys.argv[1])
app = app_path.read_text(encoding="utf-8")

MARKER = "# PVE_CATEGORY_API_V1"

if MARKER not in app:
    if "import json\n" not in app:
        anchor = "import os\n"
        if anchor in app:
            app = app.replace(anchor, "import json\n" + anchor, 1)
        else:
            app = "import json\n" + app

    if "import secrets\n" not in app:
        anchor = "import sqlite3\n"
        if anchor in app:
            app = app.replace(anchor, anchor + "import secrets\n", 1)
        else:
            app = "import secrets\n" + app

    category_api = r'''
# PVE_CATEGORY_API_V1
CATEGORY_CONFIG_FILE = Path(
    "/var/lib/pve-sensor-dashboard-web/categories.json"
)
_category_config_lock = threading.Lock()


def _category_default_config():
    return {
        "categories": [],
        "assignments": {},
    }


def _category_normalize_mode(value):
    value = str(value or "").strip().lower()

    if value not in (
        "always_open",
        "open",
        "closed",
    ):
        value = "open"

    return value


def _category_read_config():
    with _category_config_lock:
        try:
            data = json.loads(
                CATEGORY_CONFIG_FILE.read_text(
                    encoding="utf-8"
                )
            )
        except Exception:
            data = _category_default_config()

    if not isinstance(data, dict):
        data = _category_default_config()

    raw_categories = data.get("categories", [])
    raw_assignments = data.get("assignments", {})

    if not isinstance(raw_categories, list):
        raw_categories = []

    if not isinstance(raw_assignments, dict):
        raw_assignments = {}

    categories = []
    seen = set()

    for raw in raw_categories:
        if not isinstance(raw, dict):
            continue

        category_id = str(raw.get("id", "")).strip()
        name = str(raw.get("name", "")).strip()

        if (
            not category_id
            or category_id in seen
            or not name
        ):
            continue

        seen.add(category_id)

        categories.append({
            "id": category_id,
            "name": name[:50],
            "mode": _category_normalize_mode(
                raw.get("mode")
            ),
        })

    valid_ids = {
        item["id"]
        for item in categories
    }

    assignments = {}

    for link_id, category_id in raw_assignments.items():
        link_id = str(link_id).strip()
        category_id = str(category_id or "").strip()

        if not link_id:
            continue

        if category_id and category_id not in valid_ids:
            category_id = ""

        assignments[link_id] = category_id

    return {
        "categories": categories,
        "assignments": assignments,
    }


def _category_write_config(data):
    CATEGORY_CONFIG_FILE.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    temp = CATEGORY_CONFIG_FILE.with_suffix(".tmp")

    with _category_config_lock:
        temp.write_text(
            json.dumps(
                data,
                ensure_ascii=False,
                indent=2,
            ) + "\n",
            encoding="utf-8",
        )

        temp.chmod(0o600)
        temp.replace(CATEGORY_CONFIG_FILE)


def _category_verify_request(payload):
    ip = client_ip()

    locked, remaining = rate_state(ip)

    if locked:
        return False, (
            jsonify({
                "error": (
                    "Zu viele Fehlversuche. "
                    f"Noch {remaining} Sekunden gesperrt."
                )
            }),
            429,
        )

    code = str(payload.get("code", ""))

    if not verify_code(code):
        fails, locked_until = record_failure(ip)

        if locked_until > time.time():
            return False, (
                jsonify({
                    "error": (
                        "Zu viele Fehlversuche. "
                        "Diese IP ist 5 Minuten gesperrt."
                    )
                }),
                429,
            )

        return False, (
            jsonify({
                "error": (
                    "Steuer-Code ist falsch. "
                    f"Fehlversuch {fails}/{MAX_FAILS}."
                )
            }),
            403,
        )

    clear_failures(ip)

    return True, None


@app.get("/api/categories")
def category_config_get():
    return jsonify(
        _category_read_config()
    )


@app.post("/api/categories/save")
def category_save():
    payload = request.get_json(silent=True) or {}

    allowed, error = _category_verify_request(payload)
    if not allowed:
        return error

    category_id = str(
        payload.get("id", "") or ""
    ).strip()

    name = str(
        payload.get("name", "")
    ).strip()

    mode = _category_normalize_mode(
        payload.get("mode")
    )

    if not name:
        return jsonify({
            "error": "Kategoriename fehlt."
        }), 400

    if len(name) > 50:
        return jsonify({
            "error": (
                "Kategoriename darf höchstens "
                "50 Zeichen haben."
            )
        }), 400

    data = _category_read_config()
    categories = data["categories"]

    if category_id:
        item = next(
            (
                category
                for category in categories
                if category["id"] == category_id
            ),
            None,
        )

        if item is None:
            return jsonify({
                "error": "Kategorie wurde nicht gefunden."
            }), 404

        item["name"] = name
        item["mode"] = mode

    else:
        used = {
            category["id"]
            for category in categories
        }

        while True:
            category_id = secrets.token_hex(6)
            if category_id not in used:
                break

        categories.append({
            "id": category_id,
            "name": name,
            "mode": mode,
        })

    _category_write_config(data)

    return jsonify({
        "ok": True,
        "id": category_id,
        **_category_read_config(),
    })


@app.post("/api/categories/delete")
def category_delete():
    payload = request.get_json(silent=True) or {}

    allowed, error = _category_verify_request(payload)
    if not allowed:
        return error

    category_id = str(
        payload.get("id", "")
    ).strip()

    if not category_id:
        return jsonify({
            "error": "Kategorie-ID fehlt."
        }), 400

    data = _category_read_config()

    exists = any(
        item["id"] == category_id
        for item in data["categories"]
    )

    if not exists:
        return jsonify({
            "error": "Kategorie wurde nicht gefunden."
        }), 404

    data["categories"] = [
        item
        for item in data["categories"]
        if item["id"] != category_id
    ]

    for link_id, assigned in list(
        data["assignments"].items()
    ):
        if assigned == category_id:
            data["assignments"][link_id] = ""

    _category_write_config(data)

    return jsonify({
        "ok": True,
        **_category_read_config(),
    })


@app.post("/api/categories/reorder")
def category_reorder():
    payload = request.get_json(silent=True) or {}

    allowed, error = _category_verify_request(payload)
    if not allowed:
        return error

    ids = payload.get("ids", [])

    if not isinstance(ids, list):
        return jsonify({
            "error": "Ungültige Sortierung."
        }), 400

    ids = [
        str(value).strip()
        for value in ids
    ]

    data = _category_read_config()

    current_ids = [
        item["id"]
        for item in data["categories"]
    ]

    if (
        len(ids) != len(current_ids)
        or set(ids) != set(current_ids)
        or len(ids) != len(set(ids))
    ):
        return jsonify({
            "error": (
                "Die Kategorienliste hat sich geändert. "
                "Bitte neu laden."
            )
        }), 409

    by_id = {
        item["id"]: item
        for item in data["categories"]
    }

    data["categories"] = [
        by_id[item_id]
        for item_id in ids
    ]

    _category_write_config(data)

    return jsonify({
        "ok": True,
        **_category_read_config(),
    })


@app.post("/api/category-assignment/save")
def category_assignment_save():
    payload = request.get_json(silent=True) or {}

    allowed, error = _category_verify_request(payload)
    if not allowed:
        return error

    link_id = str(
        payload.get("link_id", "")
    ).strip()

    category_id = str(
        payload.get("category_id", "") or ""
    ).strip()

    if not link_id:
        return jsonify({
            "error": "Webseiten-ID fehlt."
        }), 400

    data = _category_read_config()

    valid_categories = {
        item["id"]
        for item in data["categories"]
    }

    if (
        category_id
        and category_id not in valid_categories
    ):
        return jsonify({
            "error": "Kategorie existiert nicht mehr."
        }), 400

    data["assignments"][link_id] = category_id

    _category_write_config(data)

    return jsonify({
        "ok": True,
        **_category_read_config(),
    })


'''

    anchor = '@app.get("/api/current")'

    if anchor not in app:
        raise SystemExit(
            "FEHLER: /api/current wurde in app.py nicht gefunden."
        )

    app = app.replace(
        anchor,
        category_api + anchor,
        1,
    )

temp = app_path.with_suffix(".py.categories-test")
temp.write_text(app, encoding="utf-8")

py_compile.compile(
    str(temp),
    doraise=True,
)

temp.replace(app_path)

print("[OK] Kategorie-API ergänzt.")
print("[OK] Bestehendes Link-Backend blieb unangetastet.")
print("[OK] /api/current-Code blieb unangetastet.")
PY

echo
echo "===== 4. FRONTEND ERWEITERN ====="

python3 - "$INDEX" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
html = path.read_text(encoding="utf-8")

MARKER = "PVE_CATEGORY_UI_TEST_V1"

if MARKER not in html:
    html = html.replace(
        ">Linkverwaltung</button>",
        ">Webseitenverwaltung</button>",
        1,
    )

    html = html.replace(
        "<h2>Linkverwaltung</h2>",
        "<h2>Webseitenverwaltung</h2>",
        1,
    )

    html = html.replace(
        "Linkverwaltung und Dashboard zentral verwalten.",
        "Webseiten, Kategorien und Dashboard zentral verwalten.",
        1,
    )

    categories_tab = '''
      <button
        id="settingsHubTabCategories"
        class="settingsHubTab"
        type="button"
        role="tab"
        aria-selected="false"
        onclick="switchUnifiedSettingsTab('categories')"
      >Kategorien</button>
'''

    dashboard_tab_match = re.search(
        r'(?P<block>'
        r'<button\b'
        r'(?=[^>]*id=["\']settingsHubTabDashboard["\'])'
        r'.*?</button>'
        r')',
        html,
        re.S,
    )

    if not dashboard_tab_match:
        raise SystemExit(
            "FEHLER: Dashboard-Reiter wurde nicht gefunden."
        )

    html = (
        html[:dashboard_tab_match.start()]
        + categories_tab
        + dashboard_tab_match.group("block")
        + html[dashboard_tab_match.end():]
    )

    categories_panel = r'''
    <div
      id="settingsHubPanelCategories"
      class="settingsHubPanel"
      role="tabpanel"
    >
      <div class="categoryEditor">
        <p class="categoryIntro">
          Kategorien gruppieren die Webseiten im Seitenmenü.
          Beim Löschen einer Kategorie bleiben die Webseiten erhalten.
        </p>

        <div id="categoryList" class="categoryList"></div>

        <div class="formGrid categoryForm">
          <div>
            <label for="categoryName">Kategoriename</label>
            <input
              id="categoryName"
              type="text"
              maxlength="50"
              placeholder="z. B. Monitoring"
            >
          </div>

          <div>
            <label for="categoryMode">Verhalten</label>
            <select id="categoryMode">
              <option value="always_open">Immer offen</option>
              <option value="open">Geöffnet, aber einklappbar</option>
              <option value="closed">Eingeklappt, aber aufklappbar</option>
            </select>
          </div>

          <div>
            <label for="categoryCode">Sicherheitscode</label>
            <input
              id="categoryCode"
              type="password"
              autocomplete="off"
              placeholder="Dashboard-Steuer-Code"
            >
          </div>

          <div class="full">
            <div id="categoryMsg" class="msg"></div>
            <div class="smallHint">
              Die Reihenfolge der Kategorien bestimmt die Reihenfolge im Seitenmenü.
            </div>
          </div>
        </div>

        <div class="modalButtons categoryButtons">
          <button
            id="categoryDelete"
            class="secondaryDanger"
            style="display:none"
            onclick="deleteCategory()"
          >Löschen</button>

          <button onclick="clearCategoryForm()">Neu</button>

          <button
            id="categoryOrderSave"
            onclick="saveCategoryOrder()"
          >Sortierung speichern</button>

          <button
            id="categorySave"
            onclick="saveCategory()"
          >Kategorie speichern</button>
        </div>
      </div>
    </div>
'''

    dashboard_panel_anchor = re.search(
        r'<div\b'
        r'(?=[^>]*id=["\']settingsHubPanelDashboard["\'])',
        html,
    )

    if not dashboard_panel_anchor:
        raise SystemExit(
            "FEHLER: Dashboard-Panel wurde nicht gefunden."
        )

    html = (
        html[:dashboard_panel_anchor.start()]
        + categories_panel
        + "\n"
        + html[dashboard_panel_anchor.start():]
    )

    category_select = r'''
      <div id="linkCategoryWrap">
        <label for="linkCategory">Kategorie</label>
        <select id="linkCategory">
          <option value="">Keine Kategorie</option>
        </select>
      </div>
'''

    target_block = re.search(
        r'(?P<block>'
        r'<div\b[^>]*>\s*'
        r'<label\b[^>]*for=["\']linkTarget["\'][^>]*>.*?</label>\s*'
        r'<select\b(?=[^>]*id=["\']linkTarget["\'])[^>]*>.*?</select>\s*'
        r'</div>'
        r')',
        html,
        re.S | re.I,
    )

    if not target_block:
        raise SystemExit(
            "FEHLER: Feld 'Öffnen' der Webseitenverwaltung wurde nicht gefunden."
        )

    html = (
        html[:target_block.start()]
        + category_select
        + "\n"
        + target_block.group("block")
        + html[target_block.end():]
    )

    css = r'''
/* PVE_CATEGORY_UI_TEST_V1 */
.categoryEditor{width:100%}
.categoryIntro{margin-top:0;color:var(--muted);font-size:12px}
.categoryList{
  max-height:310px;
  overflow:auto;
  border:1px solid var(--line);
  border-radius:10px;
  margin-bottom:14px
}
.categoryRow{
  display:flex;
  align-items:center;
  justify-content:space-between;
  gap:10px;
  padding:9px 10px;
  border-bottom:1px solid var(--line)
}
.categoryRow:last-child{border-bottom:0}
.categoryRowMain{min-width:0;flex:1}
.categoryRowName{font-weight:750;color:#eef5ff}
.categoryRowMeta{margin-top:3px;color:var(--muted);font-size:10px}
.categoryRowActions{display:flex;gap:5px;align-items:center}
.categoryRowActions button{padding:6px 9px}
.categoryButtons{border-top:1px solid var(--line);padding-top:12px}
.categoryEmpty{padding:14px;color:var(--muted);font-size:12px}
.navCategory{margin:4px 0 7px}
.navCategoryHeader{
  width:100%;
  display:flex;
  align-items:center;
  gap:8px;
  padding:9px 11px;
  border:0;
  border-radius:8px;
  background:transparent;
  color:#dce7f5;
  text-align:left;
  font-size:12px;
  font-weight:800;
  letter-spacing:.02em
}
.navCategoryHeader.toggleable{cursor:pointer}
.navCategoryHeader.toggleable:hover{background:#172437}
.navCategoryArrow{
  width:14px;
  color:#91a9c6;
  transition:transform .15s ease
}
.navCategory.open .navCategoryArrow{transform:rotate(90deg)}
.navCategory.always-open .navCategoryArrow{visibility:hidden}
.navCategoryChildren{
  display:none;
  margin-left:9px;
  padding-left:7px;
  border-left:1px solid #273a51
}
.navCategory.open .navCategoryChildren,
.navCategory.always-open .navCategoryChildren{display:block}
.navCategoryChildren .navLink{margin:1px 0}
.navUnassignedHeading{
  margin:12px 10px 5px;
  color:#7e93ad;
  font-size:9px;
  font-weight:800;
  letter-spacing:.08em;
  text-transform:uppercase
}
'''

    if "</style>" not in html:
        raise SystemExit(
            "FEHLER: </style> wurde nicht gefunden."
        )

    html = html.replace(
        "</style>",
        css + "\n</style>",
        1,
    )

    js = r'''
/* PVE_CATEGORY_UI_TEST_V1 */

let categoryConfig={
  categories:[],
  assignments:{}
};

let editingCategoryId=null;
let categoryOrderDirty=false;

function categoryModeLabel(mode){
  return ({
    always_open:'Immer offen',
    open:'Geöffnet, aber einklappbar',
    closed:'Eingeklappt, aber aufklappbar'
  })[mode]||'Geöffnet, aber einklappbar';
}

async function loadCategoryConfig(){
  try{
    categoryConfig=await getJSON('/api/categories');

    if(!Array.isArray(categoryConfig.categories)){
      categoryConfig.categories=[];
    }

    if(
      !categoryConfig.assignments
      || typeof categoryConfig.assignments!=='object'
    ){
      categoryConfig.assignments={};
    }
  }catch(e){
    console.error('Kategorien:',e);
    categoryConfig={
      categories:[],
      assignments:{}
    };
  }

  refreshLinkCategorySelect();
  renderCategoryList();
}

function refreshLinkCategorySelect(selected){
  const select=$('linkCategory');
  if(!select)return;

  const wanted=
    selected!==undefined
      ? selected
      : select.value;

  select.innerHTML='';

  const none=document.createElement('option');
  none.value='';
  none.textContent='Keine Kategorie';
  select.appendChild(none);

  categoryConfig.categories.forEach(category=>{
    const option=document.createElement('option');
    option.value=category.id;
    option.textContent=category.name;
    select.appendChild(option);
  });

  if(
    wanted
    && categoryConfig.categories.some(
      category=>category.id===wanted
    )
  ){
    select.value=wanted;
  }else{
    select.value='';
  }
}

function categoryStorageKey(id){
  return `pve-category-open-${id}`;
}

function categoryIsOpen(category){
  if(category.mode==='always_open'){
    return true;
  }

  const stored=localStorage.getItem(
    categoryStorageKey(category.id)
  );

  if(stored==='1')return true;
  if(stored==='0')return false;

  return category.mode!=='closed';
}

function toggleCategory(id){
  const category=categoryConfig.categories.find(
    item=>item.id===id
  );

  if(!category||category.mode==='always_open'){
    return;
  }

  const box=$(`navCategory-${id}`);
  if(!box)return;

  const open=!box.classList.contains('open');

  box.classList.toggle('open',open);

  localStorage.setItem(
    categoryStorageKey(id),
    open ? '1' : '0'
  );
}

function makeCategoryNavLink(item){
  const a=document.createElement('a');
  a.className='navLink';
  a.href=item.url;

  if(item.target!=='same'){
    a.target='_blank';
    a.rel='noopener noreferrer';
  }

  const icon=document.createElement('span');
  icon.className='navIcon';
  icon.textContent=initials(item.name);

  const tx=document.createElement('span');
  tx.className='navText';

  const nm=document.createElement('div');
  nm.className='navName';
  nm.textContent=item.name;

  const ur=document.createElement('div');
  ur.className='navUrl';
  ur.textContent=item.url;

  tx.append(nm,ur);
  a.append(icon,tx);

  return a;
}

function renderCategorizedServiceLinks(){
  const box=$('serviceNavLinks');
  if(!box)return;

  box.innerHTML='';

  const links=Array.isArray(serviceLinks)
    ? serviceLinks
    : [];

  if(!links.length){
    const empty=document.createElement('div');
    empty.className='navUrl';
    empty.style.padding='9px 11px';
    empty.textContent='Noch keine Webseiten eingetragen';
    box.appendChild(empty);
    return;
  }

  const assigned=new Set();

  categoryConfig.categories.forEach(category=>{
    const members=links.filter(
      item=>
        categoryConfig.assignments[item.id]
        === category.id
    );

    if(!members.length){
      return;
    }

    members.forEach(
      item=>assigned.add(item.id)
    );

    const wrap=document.createElement('div');
    wrap.className='navCategory';
    wrap.id=`navCategory-${category.id}`;

    if(category.mode==='always_open'){
      wrap.classList.add('always-open');
    }else if(categoryIsOpen(category)){
      wrap.classList.add('open');
    }

    const header=document.createElement('button');
    header.type='button';
    header.className='navCategoryHeader';

    if(category.mode!=='always_open'){
      header.classList.add('toggleable');
      header.onclick=()=>toggleCategory(category.id);
    }

    const arrow=document.createElement('span');
    arrow.className='navCategoryArrow';
    arrow.textContent='›';

    const label=document.createElement('span');
    label.textContent=category.name;

    header.append(arrow,label);

    const children=document.createElement('div');
    children.className='navCategoryChildren';

    members.forEach(
      item=>children.appendChild(
        makeCategoryNavLink(item)
      )
    );

    wrap.append(header,children);
    box.appendChild(wrap);
  });

  const unassigned=links.filter(
    item=>!assigned.has(item.id)
  );

  if(unassigned.length){
    if(categoryConfig.categories.length){
      const heading=document.createElement('div');
      heading.className='navUnassignedHeading';
      heading.textContent='Ohne Kategorie';
      box.appendChild(heading);
    }

    unassigned.forEach(
      item=>box.appendChild(
        makeCategoryNavLink(item)
      )
    );
  }
}

function renderCategoryList(){
  const box=$('categoryList');
  if(!box)return;

  box.innerHTML='';

  if(!categoryConfig.categories.length){
    const empty=document.createElement('div');
    empty.className='categoryEmpty';
    empty.textContent='Noch keine Kategorien angelegt.';
    box.appendChild(empty);
    updateCategoryOrderState();
    return;
  }

  categoryConfig.categories.forEach(
    (category,index)=>{
      const row=document.createElement('div');
      row.className='categoryRow';

      const main=document.createElement('div');
      main.className='categoryRowMain';

      const name=document.createElement('div');
      name.className='categoryRowName';
      name.textContent=category.name;

      const count=Object.values(
        categoryConfig.assignments
      ).filter(
        value=>value===category.id
      ).length;

      const meta=document.createElement('div');
      meta.className='categoryRowMeta';
      meta.textContent=
        `${categoryModeLabel(category.mode)} · `
        + `${count} Webseite${count===1?'':'n'}`;

      main.append(name,meta);

      const actions=document.createElement('div');
      actions.className='categoryRowActions';

      const up=document.createElement('button');
      up.type='button';
      up.textContent='↑';
      up.title='Nach oben';
      up.disabled=index===0;
      up.onclick=()=>moveCategory(category.id,-1);

      const down=document.createElement('button');
      down.type='button';
      down.textContent='↓';
      down.title='Nach unten';
      down.disabled=
        index===categoryConfig.categories.length-1;
      down.onclick=()=>moveCategory(category.id,1);

      const edit=document.createElement('button');
      edit.type='button';
      edit.textContent='Bearbeiten';
      edit.onclick=()=>editCategory(category.id);

      actions.append(up,down,edit);
      row.append(main,actions);
      box.appendChild(row);
    }
  );

  updateCategoryOrderState();
}

function updateCategoryOrderState(){
  const button=$('categoryOrderSave');
  if(!button)return;

  button.disabled=!categoryOrderDirty;
}

function moveCategory(id,delta){
  const index=categoryConfig.categories.findIndex(
    item=>item.id===id
  );

  if(index<0)return;

  const next=index+delta;

  if(
    next<0
    || next>=categoryConfig.categories.length
  ){
    return;
  }

  const copy=[...categoryConfig.categories];

  [copy[index],copy[next]]=[
    copy[next],copy[index]
  ];

  categoryConfig.categories=copy;
  categoryOrderDirty=true;

  renderCategoryList();
  renderCategorizedServiceLinks();
}

function editCategory(id){
  const item=categoryConfig.categories.find(
    category=>category.id===id
  );

  if(!item)return;

  editingCategoryId=id;

  $('categoryName').value=item.name;
  $('categoryMode').value=item.mode||'open';
  $('categoryCode').value='';
  $('categoryDelete').style.display='';

  $('categoryMsg').textContent='Kategorie wird bearbeitet.';
  $('categoryMsg').className='msg';
}

function clearCategoryForm(){
  editingCategoryId=null;

  $('categoryName').value='';
  $('categoryMode').value='open';
  $('categoryCode').value='';
  $('categoryDelete').style.display='none';

  $('categoryMsg').textContent='';
  $('categoryMsg').className='msg';
}

async function saveCategory(){
  const name=$('categoryName').value.trim();
  const code=$('categoryCode').value;

  if(!name){
    $('categoryMsg').textContent=
      'Bitte einen Kategorienamen eingeben.';
    $('categoryMsg').className='msg err';
    return;
  }

  if(code.length<6){
    $('categoryMsg').textContent=
      'Bitte den Dashboard-Sicherheitscode eingeben.';
    $('categoryMsg').className='msg err';
    return;
  }

  $('categorySave').disabled=true;

  try{
    const data=await getJSON(
      '/api/categories/save',
      {
        method:'POST',
        headers:{
          'Content-Type':'application/json'
        },
        body:JSON.stringify({
          ...(editingCategoryId
            ? {id:editingCategoryId}
            : {}),
          name,
          mode:$('categoryMode').value,
          code
        })
      }
    );

    categoryConfig={
      categories:data.categories||[],
      assignments:data.assignments||{}
    };

    editingCategoryId=data.id||null;
    categoryOrderDirty=false;

    refreshLinkCategorySelect();
    renderCategoryList();
    renderCategorizedServiceLinks();

    $('categoryCode').value='';
    $('categoryDelete').style.display='';

    $('categoryMsg').textContent='Kategorie gespeichert.';
    $('categoryMsg').className='msg ok';

  }catch(e){
    $('categoryMsg').textContent=e.message;
    $('categoryMsg').className='msg err';
  }finally{
    $('categorySave').disabled=false;
  }
}

async function deleteCategory(){
  if(!editingCategoryId)return;

  const item=categoryConfig.categories.find(
    category=>category.id===editingCategoryId
  );

  const code=$('categoryCode').value;

  if(code.length<6){
    $('categoryMsg').textContent=
      'Zum Löschen den Sicherheitscode eingeben.';
    $('categoryMsg').className='msg err';
    return;
  }

  if(!confirm(
    `Kategorie "${item?.name||''}" löschen?\n`
    + 'Die Webseiten bleiben erhalten und werden auf '
    + '"Keine Kategorie" gesetzt.'
  )){
    return;
  }

  $('categoryDelete').disabled=true;

  try{
    const data=await getJSON(
      '/api/categories/delete',
      {
        method:'POST',
        headers:{
          'Content-Type':'application/json'
        },
        body:JSON.stringify({
          id:editingCategoryId,
          code
        })
      }
    );

    categoryConfig={
      categories:data.categories||[],
      assignments:data.assignments||{}
    };

    categoryOrderDirty=false;
    clearCategoryForm();

    refreshLinkCategorySelect();
    renderCategoryList();
    renderCategorizedServiceLinks();

    $('categoryMsg').textContent=
      'Kategorie gelöscht. Webseiten wurden nicht gelöscht.';
    $('categoryMsg').className='msg ok';

  }catch(e){
    $('categoryMsg').textContent=e.message;
    $('categoryMsg').className='msg err';
  }finally{
    $('categoryDelete').disabled=false;
  }
}

async function saveCategoryOrder(){
  if(!categoryOrderDirty){
    return;
  }

  const code=$('categoryCode').value;

  if(code.length<6){
    $('categoryMsg').textContent=
      'Zum Speichern der Sortierung den Sicherheitscode eingeben.';
    $('categoryMsg').className='msg err';
    return;
  }

  $('categoryOrderSave').disabled=true;

  try{
    const data=await getJSON(
      '/api/categories/reorder',
      {
        method:'POST',
        headers:{
          'Content-Type':'application/json'
        },
        body:JSON.stringify({
          ids:categoryConfig.categories.map(
            item=>item.id
          ),
          code
        })
      }
    );

    categoryConfig={
      categories:data.categories||[],
      assignments:data.assignments||{}
    };

    categoryOrderDirty=false;
    $('categoryCode').value='';

    renderCategoryList();
    renderCategorizedServiceLinks();

    $('categoryMsg').textContent=
      'Kategorie-Sortierung gespeichert.';
    $('categoryMsg').className='msg ok';

  }catch(e){
    $('categoryMsg').textContent=e.message;
    $('categoryMsg').className='msg err';
  }finally{
    updateCategoryOrderState();
  }
}

async function saveLinkCategoryAssignment(
  linkId,
  categoryId,
  code
){
  const data=await getJSON(
    '/api/category-assignment/save',
    {
      method:'POST',
      headers:{
        'Content-Type':'application/json'
      },
      body:JSON.stringify({
        link_id:linkId,
        category_id:categoryId||'',
        code
      })
    }
  );

  categoryConfig={
    categories:data.categories||[],
    assignments:data.assignments||{}
  };
}

const categoryOriginalLoadServiceLinks=
  typeof loadServiceLinks==='function'
    ? loadServiceLinks
    : null;

if(categoryOriginalLoadServiceLinks){
  loadServiceLinks=async function(...args){
    const result=
      await categoryOriginalLoadServiceLinks.apply(
        this,
        args
      );

    await loadCategoryConfig();
    renderCategorizedServiceLinks();

    return result;
  };
}

renderServiceLinks=function(){
  renderCategorizedServiceLinks();
};

const categoryOriginalEditLink=
  typeof editLink==='function'
    ? editLink
    : null;

if(categoryOriginalEditLink){
  editLink=function(id,...args){
    const result=
      categoryOriginalEditLink.call(
        this,
        id,
        ...args
      );

    refreshLinkCategorySelect(
      categoryConfig.assignments[id]||''
    );

    return result;
  };
}

const categoryOriginalClearLinkForm=
  typeof clearLinkForm==='function'
    ? clearLinkForm
    : null;

if(categoryOriginalClearLinkForm){
  clearLinkForm=function(...args){
    const result=
      categoryOriginalClearLinkForm.apply(
        this,
        args
      );

    refreshLinkCategorySelect('');

    return result;
  };
}

const categoryOriginalSaveLink=
  typeof saveLink==='function'
    ? saveLink
    : null;

if(categoryOriginalSaveLink){
  saveLink=async function(...args){
    const beforeIds=new Set(
      (serviceLinks||[]).map(
        item=>item.id
      )
    );

    const editId=
      typeof editingLinkId!=='undefined'
        ? editingLinkId
        : null;

    const selectedCategory=
      $('linkCategory')
        ? $('linkCategory').value
        : '';

    const code=
      $('linkCode')
        ? $('linkCode').value
        : '';

    const result=
      await categoryOriginalSaveLink.apply(
        this,
        args
      );

    let savedId=null;

    if(
      editId
      && (serviceLinks||[]).some(
        item=>item.id===editId
      )
      && (
        typeof editingLinkId==='undefined'
        || editingLinkId===null
      )
    ){
      savedId=editId;
    }

    if(!savedId){
      const added=(serviceLinks||[]).filter(
        item=>!beforeIds.has(item.id)
      );

      if(added.length===1){
        savedId=added[0].id;
      }
    }

    if(savedId&&code.length>=6){
      try{
        await saveLinkCategoryAssignment(
          savedId,
          selectedCategory,
          code
        );

        renderCategorizedServiceLinks();
        renderCategoryList();

        if($('linkMsg')){
          $('linkMsg').textContent=
            'Webseite gespeichert und Kategorie zugeordnet.';
          $('linkMsg').className='msg ok';
        }

      }catch(e){
        if($('linkMsg')){
          $('linkMsg').textContent=
            'Webseite wurde gespeichert, '
            + 'aber Kategorie konnte nicht gespeichert werden: '
            + e.message;
          $('linkMsg').className='msg err';
        }
      }
    }

    return result;
  };
}

setUnifiedSettingsTab=function(tab){
  const wanted=
    ['links','categories','dashboard'].includes(tab)
      ? tab
      : 'links';

  const mapping={
    links:[
      'settingsHubTabLinks',
      'settingsHubPanelLinks'
    ],
    categories:[
      'settingsHubTabCategories',
      'settingsHubPanelCategories'
    ],
    dashboard:[
      'settingsHubTabDashboard',
      'settingsHubPanelDashboard'
    ]
  };

  Object.entries(mapping).forEach(
    ([name,[tabId,panelId]])=>{
      const active=name===wanted;
      const tabEl=$(tabId);
      const panelEl=$(panelId);

      if(tabEl){
        tabEl.classList.toggle('active',active);
        tabEl.setAttribute(
          'aria-selected',
          String(active)
        );
      }

      if(panelEl){
        panelEl.classList.toggle('active',active);
      }
    }
  );
};

const categoryOriginalPrepareUnifiedSettingsTab=
  typeof prepareUnifiedSettingsTab==='function'
    ? prepareUnifiedSettingsTab
    : null;

prepareUnifiedSettingsTab=async function(tab){
  if(tab==='categories'){
    await loadCategoryConfig();
    clearCategoryForm();
    return;
  }

  if(categoryOriginalPrepareUnifiedSettingsTab){
    return await categoryOriginalPrepareUnifiedSettingsTab(tab);
  }
};

openUnifiedSettings=async function(tab='links'){
  closeNav();

  if(
    typeof initializeUnifiedSettings==='function'
  ){
    initializeUnifiedSettings();
  }

  const wanted=
    ['links','categories','dashboard'].includes(tab)
      ? tab
      : 'links';

  await prepareUnifiedSettingsTab(wanted);
  setUnifiedSettingsTab(wanted);

  $('settingsHubModal').classList.add('show');
};

switchUnifiedSettingsTab=async function(tab){
  const wanted=
    ['links','categories','dashboard'].includes(tab)
      ? tab
      : 'links';

  await prepareUnifiedSettingsTab(wanted);
  setUnifiedSettingsTab(wanted);
};

setTimeout(async()=>{
  await loadCategoryConfig();
  renderCategorizedServiceLinks();
},0);

'''

    init = re.search(
        r'\(async\(\)=>\{',
        html,
    )

    if not init:
        raise SystemExit(
            "FEHLER: JavaScript-Hauptinitialisierung wurde nicht gefunden."
        )

    html = (
        html[:init.start()]
        + js
        + "\n"
        + html[init.start():]
    )

required = [
    MARKER,
    'id="settingsHubTabCategories"',
    'id="settingsHubPanelCategories"',
    'id="linkCategory"',
    "renderCategorizedServiceLinks",
    "saveLinkCategoryAssignment",
    "Webseitenverwaltung",
]

for item in required:
    if item not in html:
        raise SystemExit(
            f"FEHLER: Frontend-Prüfung fehlgeschlagen: {item}"
        )

temp = path.with_suffix(".html.categories-test")
temp.write_text(
    html,
    encoding="utf-8",
)
temp.replace(path)

print("[OK] Reiter 'Webseitenverwaltung' eingerichtet.")
print("[OK] Reiter 'Kategorien' ergänzt.")
print("[OK] Reiter 'Dashboard' bleibt bestehen.")
print("[OK] Kategorie-Auswahl in Webseitenverwaltung ergänzt.")
print("[OK] Seitenmenü kann Webseiten nach Kategorien gruppieren.")
PY

chmod 644 "$APP" "$INDEX"
chown root:root "$APP" "$INDEX"

echo
echo "===== 5. SYNTAX / JAVASCRIPT PRÜFEN ====="

python3 -m py_compile "$APP"
echo "[OK] app.py"

if command -v node >/dev/null 2>&1; then
    python3 - "$INDEX" /tmp/pve-dashboard-category-test.js <<'PY'
from pathlib import Path
import re
import sys

html = Path(sys.argv[1]).read_text(
    encoding="utf-8"
)

scripts = re.findall(
    r"<script[^>]*>(.*?)</script>",
    html,
    re.S | re.I,
)

Path(sys.argv[2]).write_text(
    "\n".join(scripts),
    encoding="utf-8",
)
PY

    node --check /tmp/pve-dashboard-category-test.js
    rm -f /tmp/pve-dashboard-category-test.js
    echo "[OK] JavaScript"
else
    echo "[INFO] Node nicht installiert; JavaScript-Syntaxprüfung übersprungen."
fi

echo
echo "===== 6. WEB-DIENST NEU STARTEN ====="

systemctl restart pve-sensor-web.service
systemctl restart nginx

sleep 4

systemctl is-active --quiet pve-sensor-web.service
systemctl is-active --quiet nginx

echo "[OK] Webdienst aktiv"
echo "[OK] nginx aktiv"

echo
echo "===== 7. API NACH UPDATE PRÜFEN ====="

CURRENT_AFTER="$(
    curl -m 5 -fsS \
        http://127.0.0.1:9105/api/current \
        2>/dev/null || true
)"

if [[ -z "$CURRENT_AFTER" ]]; then
    echo "FEHLER: /api/current antwortet nach dem Update nicht."
    false
fi

echo "[OK] /api/current antwortet weiterhin."

CATEGORY_AFTER="$(
    curl -m 5 -fsS \
        http://127.0.0.1:9105/api/categories \
        2>/dev/null || true
)"

if [[ -z "$CATEGORY_AFTER" ]]; then
    echo "FEHLER: /api/categories antwortet nicht."
    false
fi

echo "[OK] /api/categories antwortet."

echo
echo "Kategorie-API:"
echo "$CATEGORY_AFTER" |
    python3 -m json.tool 2>/dev/null || echo "$CATEGORY_AFTER"

echo
echo "===== 8. LIVE-WERTE KURZ PRÜFEN ====="

echo "$CURRENT_AFTER" |
python3 -c '
import json
import sys

data=json.load(sys.stdin)

for key in (
    "cpu_percent",
    "ram_percent",
    "board_temp",
    "net_rx_bps",
):
    print(f"  {key}: {data.get(key)}")
'

trap - ERR

echo
echo "============================================================"
echo " TEST-UPDATE ERFOLGREICH"
echo "============================================================"
echo
echo "Live-Metrik-API funktioniert weiterhin."
echo
echo "Jetzt im Browser:"
echo "  STRG + F5"
echo
echo "Dann:"
echo "  ☰ Menü -> ⚙ Einstellungen"
echo
echo "Reiter:"
echo "  1. Webseitenverwaltung"
echo "  2. Kategorien"
echo "  3. Dashboard"
echo
echo "Empfohlener Test:"
echo "  1. Kategorie 'Router' anlegen"
echo "  2. Modus 'Immer offen' wählen"
echo "  3. Kategorie 'Monitoring' anlegen"
echo "  4. Fritz!Box / Router der Kategorie Router zuweisen"
echo "  5. Uptime Kuma der Kategorie Monitoring zuweisen"
echo
echo "Backup:"
echo "  $BACKUP"
echo
echo "Log:"
echo "  $LOGFILE"
echo "============================================================"
__PVE_V42_INSTALL_DASHBOARD_CATEGORIES_V42__
    chmod 700 "$patch"
    bash "$patch"
    rm -f "$patch"
}

# =============================================================================
# DASHBOARD KATEGORIE-ZUORDNUNG
# =============================================================================
install_dashboard_category_assignment_v42() {
    header "DASHBOARD KATEGORIE-ZUORDNUNG"
    local patch="/tmp/install_dashboard_category_assignment_v42.$$"
    cat > "$patch" <<'__PVE_V42_INSTALL_DASHBOARD_CATEGORY_ASSIGNMENT_V42__'
#!/usr/bin/env bash
set -Eeuo pipefail

STAMP="$(date +%d-%m-%H-%M)"
LOGFILE="/root/diagnose/diagnose-dashboard-kategorie-zuordnung-${STAMP}.txt"

if [[ -e "$LOGFILE" ]]; then
    N=2
    while [[ -e "/root/diagnose/diagnose-dashboard-kategorie-zuordnung-${STAMP}-${N}.txt" ]]; do
        N=$((N + 1))
    done
    LOGFILE="/root/diagnose/diagnose-dashboard-kategorie-zuordnung-${STAMP}-${N}.txt"
fi

exec > >(tee -a "$LOGFILE") 2>&1

[[ ${EUID:-$(id -u)} -eq 0 ]] || {
    echo "FEHLER: Bitte als root auf dem Proxmox-Host ausführen."
    exit 1
}

INDEX="/opt/nodezero/dashboard/static/index.html"
BACKUP="/root/backups/pve-dashboard-kategorie-zuordnung-backup-$(date +%Y%m%d-%H%M%S)"

[[ -f "$INDEX" ]] || {
    echo "FEHLER: $INDEX fehlt."
    exit 1
}

echo "============================================================"
echo " DASHBOARD - KATEGORIE-ZUORDNUNG FIX V2"
echo "============================================================"
echo
echo "Neu:"
echo "  - Zuordnung wird unabhängig vom Link-Speichern verwaltet"
echo "  - Jeder Link kann einer Kategorie zugeordnet werden"
echo "  - Auch Fritz!Box / Router kann einer Kategorie zugeordnet werden"
echo "  - Sicherheitscode wird sichtbar in der Webseitenverwaltung verwendet"
echo
echo "Log:"
echo "  $LOGFILE"
echo

mkdir -p "$BACKUP"
cp -a "$INDEX" "$BACKUP/index.html"

python3 - "$INDEX" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
html = path.read_text(encoding="utf-8")

if "PVE_CATEGORY_UI_TEST_V1" not in html:
    raise SystemExit(
        "FEHLER: Kategorien Test-Update V1 ist nicht installiert."
    )

MARKER = "PVE_CATEGORY_ASSIGNMENT_FIX_V2"

if MARKER not in html:
    # ---------------------------------------------------------------------
    # 1. Eigener Zuordnungsbereich in Webseitenverwaltung
    # ---------------------------------------------------------------------

    assignment_html = r'''
    <!-- PVE_CATEGORY_ASSIGNMENT_FIX_V2 -->
    <div class="categoryAssignBox">
      <div class="categoryAssignTitle">
        Kategorie zuordnen
      </div>

      <div class="formGrid categoryAssignGrid">
        <div>
          <label for="categoryAssignLink">
            Webseite
          </label>
          <select id="categoryAssignLink"></select>
        </div>

        <div>
          <label for="categoryAssignCategory">
            Kategorie
          </label>
          <select id="categoryAssignCategory">
            <option value="">Keine Kategorie</option>
          </select>
        </div>

        <div>
          <label for="categoryAssignCode">
            Sicherheitscode
          </label>
          <input
            id="categoryAssignCode"
            type="password"
            autocomplete="new-password"
            placeholder="Dashboard-Steuer-Code"
          >
        </div>

        <div class="categoryAssignAction">
          <button
            id="categoryAssignSave"
            type="button"
            onclick="saveSelectedCategoryAssignment()"
          >
            Zuordnung speichern
          </button>
        </div>

        <div class="full">
          <div id="categoryAssignMsg" class="msg"></div>
        </div>
      </div>
    </div>
'''

    # Im Link-Panel direkt NACH der Linkliste/Sortierung, vor dem Eingabeformular.
    panel_match = re.search(
        r'(<div\b'
        r'(?=[^>]*id=["\']settingsHubPanelLinks["\'])'
        r'.*?'
        r'<div\b[^>]*class=["\'][^"\']*\bformGrid\b[^"\']*["\'][^>]*>)',
        html,
        re.S | re.I,
    )

    if not panel_match:
        raise SystemExit(
            "FEHLER: Formular der Webseitenverwaltung wurde nicht gefunden."
        )

    form_start = panel_match.end() - len(
        re.search(
            r'<div\b[^>]*class=["\'][^"\']*\bformGrid\b[^"\']*["\'][^>]*>$',
            panel_match.group(1),
            re.I,
        ).group(0)
    )

    html = (
        html[:form_start]
        + assignment_html
        + "\n"
        + html[form_start:]
    )

    # ---------------------------------------------------------------------
    # 2. Falls linkCode im vorhandenen Formular unsichtbar ist:
    #    nicht duplizieren, sondern sichtbar machen.
    # ---------------------------------------------------------------------

    # CSS für Zuordnungsbereich.
    css = r'''
/* PVE_CATEGORY_ASSIGNMENT_FIX_V2 */
.categoryAssignBox{
  margin:14px 0 16px;
  padding:12px;
  border:1px solid #30435c;
  border-radius:10px;
  background:#0a1320;
}
.categoryAssignTitle{
  margin-bottom:10px;
  color:#eef5ff;
  font-size:12px;
  font-weight:800;
}
.categoryAssignGrid{
  align-items:end;
}
.categoryAssignAction{
  display:flex;
  align-items:flex-end;
}
.categoryAssignAction button{
  width:100%;
  min-height:42px;
}
.categoryAssignmentBadge{
  display:inline-block;
  margin-left:7px;
  padding:2px 6px;
  border:1px solid #38506e;
  border-radius:999px;
  color:#a9bed8;
  font-size:9px;
  font-weight:700;
}
'''

    if "</style>" not in html:
        raise SystemExit(
            "FEHLER: </style> nicht gefunden."
        )

    html = html.replace(
        "</style>",
        css + "\n</style>",
        1,
    )

    # ---------------------------------------------------------------------
    # 3. JavaScript: separate Zuordnung, unabhängig vom Link-Save
    # ---------------------------------------------------------------------

    js = r'''
/* PVE_CATEGORY_ASSIGNMENT_FIX_V2 */

function assignmentCategoryName(categoryId){
  if(!categoryId){
    return 'Keine Kategorie';
  }

  const category=categoryConfig.categories.find(
    item=>item.id===categoryId
  );

  return category
    ? category.name
    : 'Keine Kategorie';
}

function refreshCategoryAssignmentEditor(
  preferredLinkId
){
  const linkSelect=$('categoryAssignLink');
  const categorySelect=$('categoryAssignCategory');

  if(!linkSelect||!categorySelect){
    return;
  }

  const wantedLink=
    preferredLinkId!==undefined
      ? preferredLinkId
      : linkSelect.value;

  linkSelect.innerHTML='';

  (serviceLinks||[]).forEach(item=>{
    const option=document.createElement('option');
    option.value=item.id;
    option.textContent=item.name;
    linkSelect.appendChild(option);
  });

  if(
    wantedLink
    && (serviceLinks||[]).some(
      item=>item.id===wantedLink
    )
  ){
    linkSelect.value=wantedLink;
  }

  categorySelect.innerHTML='';

  const none=document.createElement('option');
  none.value='';
  none.textContent='Keine Kategorie';
  categorySelect.appendChild(none);

  categoryConfig.categories.forEach(category=>{
    const option=document.createElement('option');
    option.value=category.id;
    option.textContent=category.name;
    categorySelect.appendChild(option);
  });

  syncCategoryAssignmentSelection();
}

function syncCategoryAssignmentSelection(){
  const linkSelect=$('categoryAssignLink');
  const categorySelect=$('categoryAssignCategory');

  if(!linkSelect||!categorySelect){
    return;
  }

  const linkId=linkSelect.value;

  categorySelect.value=
    categoryConfig.assignments[linkId]
    || '';
}

async function saveSelectedCategoryAssignment(){
  const linkSelect=$('categoryAssignLink');
  const categorySelect=$('categoryAssignCategory');
  const codeInput=$('categoryAssignCode');
  const msg=$('categoryAssignMsg');
  const button=$('categoryAssignSave');

  if(
    !linkSelect
    || !categorySelect
    || !codeInput
    || !msg
  ){
    return;
  }

  const linkId=linkSelect.value;
  const categoryId=categorySelect.value;
  const code=codeInput.value;

  if(!linkId){
    msg.textContent='Bitte eine Webseite auswählen.';
    msg.className='msg err';
    return;
  }

  if(code.length<6){
    msg.textContent=
      'Bitte den Dashboard-Sicherheitscode eingeben.';
    msg.className='msg err';
    return;
  }

  button.disabled=true;

  try{
    const data=await getJSON(
      '/api/category-assignment/save',
      {
        method:'POST',
        headers:{
          'Content-Type':'application/json'
        },
        body:JSON.stringify({
          link_id:linkId,
          category_id:categoryId,
          code
        })
      }
    );

    categoryConfig={
      categories:data.categories||[],
      assignments:data.assignments||{}
    };

    codeInput.value='';

    refreshCategoryAssignmentEditor(
      linkId
    );

    refreshLinkCategorySelect(
      categoryConfig.assignments[linkId]||''
    );

    renderCategorizedServiceLinks();
    renderCategoryList();

    const link=(serviceLinks||[]).find(
      item=>item.id===linkId
    );

    msg.textContent=
      `${link?.name||'Webseite'} → `
      + assignmentCategoryName(
        categoryConfig.assignments[linkId]
      );

    msg.className='msg ok';

  }catch(e){
    msg.textContent=e.message;
    msg.className='msg err';
  }finally{
    button.disabled=false;
  }
}

document.addEventListener(
  'change',
  event=>{
    if(event.target?.id==='categoryAssignLink'){
      syncCategoryAssignmentSelection();
    }
  }
);

/*
 * Die bisherige Save-Link-Erweiterung war für vorhandene Links zu streng.
 * Wir legen eine zusätzliche, sichere Wrapper-Schicht darüber.
 */
const categoryAssignmentFixOriginalSaveLink=
  typeof saveLink==='function'
    ? saveLink
    : null;

if(
  categoryAssignmentFixOriginalSaveLink
  && !window.__categoryAssignmentFixV2
){
  saveLink=async function(...args){
    const editId=
      typeof editingLinkId!=='undefined'
        ? editingLinkId
        : null;

    const beforeIds=new Set(
      (serviceLinks||[]).map(
        item=>item.id
      )
    );

    const selectedCategory=
      $('linkCategory')
        ? $('linkCategory').value
        : '';

    const code=
      $('linkCode')
        ? $('linkCode').value
        : '';

    const result=
      await categoryAssignmentFixOriginalSaveLink.apply(
        this,
        args
      );

    /*
     * Hat die eigentliche Linkverwaltung einen Fehler gemeldet,
     * keine Kategorie separat speichern.
     */
    if(
      $('linkMsg')
      && $('linkMsg').classList.contains('err')
    ){
      return result;
    }

    let savedId=null;

    if(
      editId
      && (serviceLinks||[]).some(
        item=>item.id===editId
      )
    ){
      savedId=editId;
    }

    if(!savedId){
      const added=(serviceLinks||[]).filter(
        item=>!beforeIds.has(item.id)
      );

      if(added.length===1){
        savedId=added[0].id;
      }
    }

    if(
      savedId
      && code.length>=6
    ){
      try{
        await saveLinkCategoryAssignment(
          savedId,
          selectedCategory,
          code
        );

        refreshCategoryAssignmentEditor(
          savedId
        );

        renderCategorizedServiceLinks();
        renderCategoryList();

        if($('linkMsg')){
          $('linkMsg').textContent=
            'Webseite gespeichert und Kategorie zugeordnet.';
          $('linkMsg').className='msg ok';
        }

      }catch(e){
        if($('linkMsg')){
          $('linkMsg').textContent=
            'Webseite gespeichert, aber Kategorie-Zuordnung fehlgeschlagen: '
            + e.message;
          $('linkMsg').className='msg err';
        }
      }
    }

    return result;
  };

  window.__categoryAssignmentFixV2=true;
}

/*
 * Kategorien- und Linkdaten nach jedem Laden auch in den separaten
 * Zuordnungsbereich übernehmen.
 */
const categoryAssignmentFixOriginalLoadCategoryConfig=
  typeof loadCategoryConfig==='function'
    ? loadCategoryConfig
    : null;

if(categoryAssignmentFixOriginalLoadCategoryConfig){
  loadCategoryConfig=async function(...args){
    const result=
      await categoryAssignmentFixOriginalLoadCategoryConfig.apply(
        this,
        args
      );

    refreshCategoryAssignmentEditor();

    return result;
  };
}

const categoryAssignmentFixOriginalRenderLinkManagerList=
  typeof renderLinkManagerList==='function'
    ? renderLinkManagerList
    : null;

if(categoryAssignmentFixOriginalRenderLinkManagerList){
  renderLinkManagerList=function(...args){
    const result=
      categoryAssignmentFixOriginalRenderLinkManagerList.apply(
        this,
        args
      );

    refreshCategoryAssignmentEditor();

    /*
     * In der Übersicht direkt anzeigen, welcher Kategorie
     * der Link aktuell zugeordnet ist.
     */
    const rows=[
      ...document.querySelectorAll(
        '#settingsHubPanelLinks .linkRow'
      )
    ];

    rows.forEach((row,index)=>{
      const item=(serviceLinks||[])[index];

      if(!item)return;

      let badge=row.querySelector(
        '.categoryAssignmentBadge'
      );

      if(!badge){
        badge=document.createElement('span');
        badge.className='categoryAssignmentBadge';

        const name=row.querySelector(
          '.linkRowName'
        );

        if(name){
          name.appendChild(badge);
        }
      }

      badge.textContent=
        assignmentCategoryName(
          categoryConfig.assignments[item.id]
          || ''
        );
    });

    return result;
  };
}

/* Falls linkCode im alten Formular durch eine Zwischenversion versteckt wurde. */
setTimeout(()=>{
  const code=$('linkCode');

  if(code){
    const wrapper=code.closest('div');

    if(wrapper){
      wrapper.classList.remove(
        'menuFormHidden'
      );

      wrapper.style.removeProperty(
        'display'
      );
    }

    code.setAttribute(
      'autocomplete',
      'new-password'
    );
  }

  refreshCategoryAssignmentEditor();
},0);

'''

    init = re.search(
        r'\(async\(\)=>\{',
        html,
    )

    if not init:
        raise SystemExit(
            "FEHLER: JavaScript-Hauptinitialisierung nicht gefunden."
        )

    html = (
        html[:init.start()]
        + js
        + "\n"
        + html[init.start():]
    )

required = (
    MARKER,
    'id="categoryAssignLink"',
    'id="categoryAssignCategory"',
    'id="categoryAssignCode"',
    "saveSelectedCategoryAssignment",
    "__categoryAssignmentFixV2",
)

for needle in required:
    if needle not in html:
        raise SystemExit(
            f"FEHLER: Prüfung fehlgeschlagen: {needle}"
        )

temp = path.with_suffix(
    ".html.category-assignment-v2"
)

temp.write_text(
    html,
    encoding="utf-8",
)

temp.replace(path)

print("[OK] Separate Kategorie-Zuordnung eingebaut.")
print("[OK] Fritz!Box / Router ist ebenfalls auswählbar.")
print("[OK] Kategorie-Zuordnung beim normalen Speichern korrigiert.")
print("[OK] Aktuelle Kategorie wird in der Linkliste angezeigt.")
PY

chmod 644 "$INDEX"
chown root:root "$INDEX"

echo
echo "===== JAVASCRIPT PRÜFEN ====="

if command -v node >/dev/null 2>&1; then
    python3 - "$INDEX" /tmp/pve-category-assignment-v2.js <<'PY'
from pathlib import Path
import re
import sys

html = Path(sys.argv[1]).read_text(
    encoding="utf-8"
)

scripts = re.findall(
    r"<script[^>]*>(.*?)</script>",
    html,
    re.S | re.I,
)

Path(sys.argv[2]).write_text(
    "\n".join(scripts),
    encoding="utf-8",
)
PY

    node --check \
        /tmp/pve-category-assignment-v2.js

    rm -f \
        /tmp/pve-category-assignment-v2.js

    echo "[OK] JavaScript"
else
    echo "[INFO] Node nicht vorhanden; JS-Prüfung übersprungen."
fi

echo
echo "===== DIENSTE ====="

systemctl restart pve-sensor-web.service
systemctl restart nginx

sleep 3

systemctl is-active --quiet \
    pve-sensor-web.service

systemctl is-active --quiet \
    nginx

echo "[OK] pve-sensor-web.service"
echo "[OK] nginx"

echo
echo "===== API ====="

curl -m 5 -fsS \
    http://127.0.0.1:9105/api/current \
    >/dev/null

echo "[OK] /api/current"

curl -m 5 -fsS \
    http://127.0.0.1:9105/api/categories \
    | python3 -m json.tool

echo
echo "============================================================"
echo " FERTIG"
echo "============================================================"
echo
echo "Browser:"
echo "  STRG + F5"
echo
echo "Dann:"
echo "  ☰ Menü -> ⚙ Einstellungen"
echo "  -> Webseitenverwaltung"
echo
echo "Dort gibt es jetzt zusätzlich:"
echo "  Kategorie zuordnen"
echo
echo "Ablauf:"
echo "  1. Webseite auswählen"
echo "  2. Kategorie auswählen"
echo "  3. Sicherheitscode eingeben"
echo "  4. Zuordnung speichern"
echo
echo "Das funktioniert auch mit:"
echo "  Fritz!Box / Router"
echo
echo "Backup:"
echo "  $BACKUP"
echo
echo "Log:"
echo "  $LOGFILE"
echo "============================================================"
__PVE_V42_INSTALL_DASHBOARD_CATEGORY_ASSIGNMENT_V42__
    chmod 700 "$patch"
    bash "$patch"
    rm -f "$patch"
}

# =============================================================================
# DASHBOARD FESTE MENÜPUNKTE ENTFERNEN
# =============================================================================
install_dashboard_menu_cleanup_v42() {
    header "DASHBOARD FESTE MENÜPUNKTE ENTFERNEN"
    local patch="/tmp/install_dashboard_menu_cleanup_v42.$$"
    cat > "$patch" <<'__PVE_V42_INSTALL_DASHBOARD_MENU_CLEANUP_V42__'
#!/usr/bin/env bash
set -Eeuo pipefail

STAMP="$(date +%d-%m-%H-%M)"
LOGFILE="/root/diagnose/diagnose-dashboard-feste-menuepunkte-entfernen-${STAMP}.txt"

if [[ -e "$LOGFILE" ]]; then
    N=2
    while [[ -e "/root/diagnose/diagnose-dashboard-feste-menuepunkte-entfernen-${STAMP}-${N}.txt" ]]; do
        N=$((N + 1))
    done
    LOGFILE="/root/diagnose/diagnose-dashboard-feste-menuepunkte-entfernen-${STAMP}-${N}.txt"
fi

exec > >(tee -a "$LOGFILE") 2>&1

[[ ${EUID:-$(id -u)} -eq 0 ]] || {
    echo "FEHLER: Bitte als root auf dem Proxmox-Host ausführen."
    exit 1
}

INDEX="/opt/nodezero/dashboard/static/index.html"
BACKUP="/root/backups/pve-dashboard-menue-cleanup-backup-$(date +%Y%m%d-%H%M%S)"

[[ -f "$INDEX" ]] || {
    echo "FEHLER: $INDEX fehlt."
    exit 1
}

echo "============================================================"
echo " DASHBOARD MENÜ - FESTE PUNKTE ENTFERNEN"
echo "============================================================"
echo
echo "Entfernt werden:"
echo "  - ROUTER + fester Fritz!Box-Link"
echo "  - DASHBOARD + Live-Übersicht"
echo
echo "Erhalten bleiben:"
echo "  - dynamische Webseiten"
echo "  - Kategorien"
echo "  - Fritz!Box als normaler/dynamischer Link"
echo "  - ⚙ Einstellungen"
echo
echo "Log:"
echo "  $LOGFILE"
echo

mkdir -p "$BACKUP"
cp -a "$INDEX" "$BACKUP/index.html"

python3 - "$INDEX" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
html = path.read_text(encoding="utf-8")

before = html

# -------------------------------------------------------------------------
# 1) Fester Router-Block entfernen
# -------------------------------------------------------------------------

router_patterns = [
    # Aktueller Block mit Marker.
    re.compile(
        r'\s*<!--\s*PVE_ROUTER_TOP_V1\s*-->\s*'
        r'<div\s+class=["\']navSection["\']>\s*Router\s*</div>\s*'
        r'<a\b[^>]*class=["\'][^"\']*\bnavLink\b[^"\']*["\'][^>]*>'
        r'.*?'
        r'<div\s+class=["\']navName["\']>\s*Fritz!Box\s*/\s*Router\s*</div>'
        r'.*?'
        r'</a>\s*',
        re.S | re.I,
    ),

    # Fallback ohne Marker.
    re.compile(
        r'\s*<div\s+class=["\']navSection["\']>\s*Router\s*</div>\s*'
        r'<a\b[^>]*class=["\'][^"\']*\bnavLink\b[^"\']*["\'][^>]*>'
        r'.*?'
        r'<div\s+class=["\']navName["\']>\s*Fritz!Box\s*/\s*Router\s*</div>'
        r'.*?'
        r'</a>\s*',
        re.S | re.I,
    ),
]

router_removed = 0

for pattern in router_patterns:
    html, count = pattern.subn(
        "\n",
        html,
        count=1,
    )

    if count:
        router_removed = 1
        break


# -------------------------------------------------------------------------
# 2) Fester Dashboard-/Live-Übersicht-Block entfernen
# -------------------------------------------------------------------------

dashboard_pattern = re.compile(
    r'\s*<div\s+class=["\']navSection["\']>\s*Dashboard\s*</div>\s*'
    r'<a\b[^>]*class=["\'][^"\']*\bnavLink\b[^"\']*["\'][^>]*'
    r'href=["\']/["\'][^>]*>'
    r'.*?'
    r'<div\s+class=["\']navName["\']>\s*Live-Übersicht\s*</div>'
    r'.*?'
    r'</a>\s*',
    re.S | re.I,
)

html, dashboard_removed = dashboard_pattern.subn(
    "\n",
    html,
    count=1,
)


# -------------------------------------------------------------------------
# 3) Falls die feste "Dienste"-Überschrift jetzt direkt oben steht:
#    behalten wir sie vorerst absichtlich.
# -------------------------------------------------------------------------

if not router_removed:
    print(
        "[INFO] Fester Router-Block war bereits entfernt "
        "oder hatte eine unbekannte Variante."
    )
else:
    print("[OK] Fester ROUTER-Block entfernt.")

if not dashboard_removed:
    print(
        "[INFO] Fester Dashboard-Block war bereits entfernt "
        "oder hatte eine unbekannte Variante."
    )
else:
    print("[OK] Fester DASHBOARD-/Live-Übersicht-Block entfernt.")


# -------------------------------------------------------------------------
# 4) Prüfung
# -------------------------------------------------------------------------

fixed_top_router = re.search(
    r'<div\s+class=["\']navSection["\']>\s*Router\s*</div>',
    html,
    re.I,
)

fixed_dashboard = re.search(
    r'<div\s+class=["\']navSection["\']>\s*Dashboard\s*</div>',
    html,
    re.I,
)

fixed_live = re.search(
    r'<div\s+class=["\']navName["\']>\s*Live-Übersicht\s*</div>',
    html,
    re.I,
)

if fixed_top_router:
    raise SystemExit(
        "FEHLER: Fester ROUTER-Bereich ist noch vorhanden."
    )

if fixed_dashboard:
    raise SystemExit(
        "FEHLER: Fester DASHBOARD-Bereich ist noch vorhanden."
    )

if fixed_live:
    raise SystemExit(
        "FEHLER: Feste Live-Übersicht ist noch vorhanden."
    )

if 'id="serviceNavLinks"' not in html:
    raise SystemExit(
        "FEHLER: Dynamischer Webseiten-/Kategorienbereich fehlt."
    )

if "openUnifiedSettings" not in html:
    raise SystemExit(
        "FEHLER: Einstellungen-Funktion fehlt."
    )

if html == before:
    print("[INFO] Keine Änderung nötig; feste Blöcke waren bereits entfernt.")

temp = path.with_suffix(".html.menu-cleanup")
temp.write_text(
    html,
    encoding="utf-8",
)
temp.replace(path)

print("[OK] Dynamischer Kategorienbereich bleibt erhalten.")
print("[OK] Einstellungen bleiben erhalten.")
PY

chmod 644 "$INDEX"
chown root:root "$INDEX"

echo
echo "===== DIENSTE NEU STARTEN ====="

systemctl restart pve-sensor-web.service
systemctl restart nginx

sleep 3

systemctl is-active --quiet pve-sensor-web.service
systemctl is-active --quiet nginx

echo "[OK] pve-sensor-web.service"
echo "[OK] nginx"

echo
echo "===== LIVE-API PRÜFEN ====="

curl -m 5 -fsS \
    http://127.0.0.1:9105/api/current \
    >/dev/null

echo "[OK] /api/current"

curl -m 5 -fsS \
    http://127.0.0.1:9105/api/categories \
    >/dev/null

echo "[OK] /api/categories"

echo
echo "============================================================"
echo " FERTIG"
echo "============================================================"
echo
echo "Im Seitenmenü sind die festen Bereiche"
echo "ROUTER und DASHBOARD jetzt entfernt."
echo
echo "Übrig bleiben:"
echo "  - deine Kategorien"
echo "  - zugeordnete Webseiten"
echo "  - Webseiten ohne Kategorie"
echo "  - ⚙ Einstellungen"
echo
echo "Browser:"
echo "  STRG + F5"
echo
echo "Backup:"
echo "  $BACKUP"
echo
echo "Log:"
echo "  $LOGFILE"
echo "============================================================"
__PVE_V42_INSTALL_DASHBOARD_MENU_CLEANUP_V42__
    chmod 700 "$patch"
    bash "$patch"
    rm -f "$patch"
}

# =============================================================================
# DASHBOARD STANDARDKATEGORIEN / TRENNER
# =============================================================================
install_dashboard_default_categories_v42() {
    header "DASHBOARD STANDARDKATEGORIEN / TRENNER"
    local patch="/tmp/install-dashboard-default-categories-v42.$$"
    cat > "$patch" <<'__PVE_V42_DEFAULT_CATEGORIES__'
#!/usr/bin/env bash
set -Eeuo pipefail

STAMP="$(date +%d-%m-%H-%M)"
LOGFILE="/root/diagnose/diagnose-dashboard-standard-kategorien-${STAMP}.txt"

if [[ -e "$LOGFILE" ]]; then
    N=2
    while [[ -e "/root/diagnose/diagnose-dashboard-standard-kategorien-${STAMP}-${N}.txt" ]]; do
        N=$((N + 1))
    done
    LOGFILE="/root/diagnose/diagnose-dashboard-standard-kategorien-${STAMP}-${N}.txt"
fi

exec > >(tee -a "$LOGFILE") 2>&1

[[ ${EUID:-$(id -u)} -eq 0 ]] || {
    echo "FEHLER: Bitte als root auf dem Proxmox-Host ausführen."
    exit 1
}

INDEX="/opt/nodezero/dashboard/static/index.html"
LINKS="/var/lib/pve-sensor-dashboard-web/links.json"
CATEGORIES="/var/lib/pve-sensor-dashboard-web/categories.json"
BACKUP="/root/backups/pve-dashboard-standard-kategorien-backup-$(date +%Y%m%d-%H%M%S)"

[[ -f "$INDEX" ]] || {
    echo "FEHLER: $INDEX fehlt."
    exit 1
}

[[ -f "$LINKS" ]] || {
    echo "FEHLER: $LINKS fehlt."
    exit 1
}

grep -Fq "PVE_CATEGORY_UI_TEST_V1" "$INDEX" || {
    echo "FEHLER: Das Kategorien-Testupdate ist noch nicht installiert."
    exit 1
}

echo "============================================================"
echo " DASHBOARD - STANDARDKATEGORIEN + MENÜTRENNER"
echo "============================================================"
echo
echo "Standardkategorien:"
echo "  Intern  -> geschlossen, aufklappbar"
echo "  Basics  -> immer geöffnet"
echo "  Extras  -> geschlossen, aufklappbar"
echo
echo "Menütrenner:"
echo "  Ohne Kategorie -> -----------------------"
echo "  Vor Einstellungen -> _________________________"
echo
echo "Log:"
echo "  $LOGFILE"
echo

mkdir -p "$BACKUP"

cp -a "$INDEX" "$BACKUP/index.html"
cp -a "$LINKS" "$BACKUP/links.json"
[[ -f "$CATEGORIES" ]] && cp -a "$CATEGORIES" "$BACKUP/categories.json"

echo
echo "===== 1. STANDARDKATEGORIEN / ZUORDNUNGEN ====="

python3 - "$LINKS" "$CATEGORIES" <<'PY'
from pathlib import Path
import json
import sys

links_path = Path(sys.argv[1])
categories_path = Path(sys.argv[2])

try:
    links = json.loads(
        links_path.read_text(encoding="utf-8")
    )
except Exception as exc:
    raise SystemExit(
        f"FEHLER: links.json ist ungültig: {exc}"
    )

if not isinstance(links, list):
    raise SystemExit(
        "FEHLER: links.json muss eine Liste sein."
    )

try:
    data = json.loads(
        categories_path.read_text(encoding="utf-8")
    )
except FileNotFoundError:
    data = {}
except Exception as exc:
    raise SystemExit(
        f"FEHLER: categories.json ist ungültig: {exc}"
    )

if not isinstance(data, dict):
    data = {}

categories = data.get("categories", [])
assignments = data.get("assignments", {})

if not isinstance(categories, list):
    categories = []

if not isinstance(assignments, dict):
    assignments = {}

defaults_already_initialized = bool(
    data.get("defaults_initialized", False)
)

if not categories:
    categories = [
        {
            "id": "intern",
            "name": "Intern",
            "mode": "closed",
        },
        {
            "id": "basics",
            "name": "Basics",
            "mode": "always_open",
        },
        {
            "id": "extras",
            "name": "Extras",
            "mode": "closed",
        },
    ]

    data["defaults_initialized"] = True
    defaults_already_initialized = False

category_ids = {
    str(item.get("id", ""))
    for item in categories
    if isinstance(item, dict)
}

if not defaults_already_initialized:
    wanted = {
        "intern": {
            "id": "intern",
            "name": "Intern",
            "mode": "closed",
        },
        "basics": {
            "id": "basics",
            "name": "Basics",
            "mode": "always_open",
        },
        "extras": {
            "id": "extras",
            "name": "Extras",
            "mode": "closed",
        },
    }

    for category_id in ("intern", "basics", "extras"):
        if category_id not in category_ids:
            categories.append(wanted[category_id])
            category_ids.add(category_id)

    data["defaults_initialized"] = True

BASICS = {
    "home assistant",
    "paperless",
    "pi-hole",
    "netalertx",
    "proxmox backup server",
}

EXTRAS = {
    "uptime kuma",
    "vaultwarden",
    "caddy",
    "caddy reverse proxy",
    "stirling pdf",
    "pdf editor",
    "ntfy",
    "forgejo",
    "syncthing",
    "speedtest tracker",
    "scrutiny",
    "mealie",
    "pulse",
    "pve-ups",
    "semaphore",
    "pocket id",
    "prometheus",
    "prometheus pve exporter",
    "grafana",
    "pangolin",
    "gatus",
    "homepage",
    "nginx proxy manager",
    "emqx",
    "mqtt",
}

for item in links:
    if not isinstance(item, dict):
        continue

    link_id = str(item.get("id", "")).strip()
    name = str(item.get("name", "")).strip()
    name_key = name.casefold()

    if not link_id:
        continue

    existing = str(
        assignments.get(link_id, "") or ""
    ).strip()

    if existing:
        continue

    target = ""

    if (
        link_id in ("proxmox", "router")
        or name_key in (
            "proxmox web ui",
            "fritz!box / router",
            "fritzbox / router",
        )
    ):
        target = "intern"

    elif name_key in BASICS:
        target = "basics"

    elif name_key in EXTRAS:
        target = "extras"

    if target and target in category_ids:
        assignments[link_id] = target

data["categories"] = categories
data["assignments"] = assignments

categories_path.parent.mkdir(
    parents=True,
    exist_ok=True,
)

temp = categories_path.with_suffix(".tmp")

temp.write_text(
    json.dumps(
        data,
        ensure_ascii=False,
        indent=2,
    ) + "\n",
    encoding="utf-8",
)

temp.chmod(0o600)
temp.replace(categories_path)

print("Kategorien:")
for category in categories:
    if isinstance(category, dict):
        print(
            f"  {category.get('name')} "
            f"({category.get('mode')})"
        )

print()
print("Automatische Zuordnungen:")
for item in links:
    if not isinstance(item, dict):
        continue

    link_id = str(item.get("id", "")).strip()

    if not link_id:
        continue

    category_id = assignments.get(link_id, "")

    if category_id:
        print(
            f"  {item.get('name')} -> {category_id}"
        )
PY

chown pve-monitor:pve-monitor "$CATEGORIES" 2>/dev/null || true
chmod 600 "$CATEGORIES"

echo
echo "===== 2. MENÜTRENNER ====="

python3 - "$INDEX" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
html = path.read_text(encoding="utf-8")

MARKER = "PVE_DEFAULT_CATEGORY_LAYOUT_V1"

if MARKER not in html:
    html, count = re.subn(
        r"(heading\.textContent\s*=\s*)"
        r"(['\"])Ohne Kategorie\2\s*;",
        r"\1'-----------------------';",
        html,
        count=1,
        flags=re.I,
    )

    if count != 1:
        html, count = re.subn(
            r"(['\"])Ohne Kategorie\1",
            "'-----------------------'",
            html,
            count=1,
            flags=re.I,
        )

    if count != 1:
        raise SystemExit(
            "FEHLER: 'Ohne Kategorie' konnte im Frontend "
            "nicht eindeutig ersetzt werden."
        )

    settings_button = re.search(
        r'<button\b'
        r'(?=[^>]*id=["\']dashboardSettingsHubButton["\'])'
        r'[^>]*>.*?</button>',
        html,
        re.S | re.I,
    )

    if not settings_button:
        raise SystemExit(
            "FEHLER: Einstellungen-Button wurde nicht gefunden."
        )

    divider = r'''
  <!-- PVE_DEFAULT_CATEGORY_LAYOUT_V1 -->
  <div
    id="navSettingsDivider"
    class="navTextCharacterDivider"
    aria-hidden="true"
  >_________________________</div>
'''

    html = (
        html[:settings_button.start()]
        + divider
        + "\n"
        + html[settings_button.start():]
    )

    css = r'''
/* PVE_DEFAULT_CATEGORY_LAYOUT_V1 */
.navUnassignedHeading{
  margin:12px 10px 7px !important;
  color:#647991 !important;
  font-family:monospace;
  font-size:10px !important;
  font-weight:500 !important;
  letter-spacing:0 !important;
  text-transform:none !important;
  white-space:nowrap;
  overflow:hidden;
}
.navTextCharacterDivider{
  margin:14px 10px 8px;
  color:#52667e;
  font-family:monospace;
  font-size:10px;
  line-height:1;
  white-space:nowrap;
  overflow:hidden;
  user-select:none;
}
'''

    if "</style>" not in html:
        raise SystemExit(
            "FEHLER: </style> wurde nicht gefunden."
        )

    html = html.replace(
        "</style>",
        css + "\n</style>",
        1,
    )

for required in (
    "-----------------------",
    "_________________________",
    'id="navSettingsDivider"',
    MARKER,
):
    if required not in html:
        raise SystemExit(
            f"FEHLER: Frontend-Prüfung fehlgeschlagen: {required}"
        )

temp = path.with_suffix(".html.default-categories")

temp.write_text(
    html,
    encoding="utf-8",
)

temp.replace(path)

print("[OK] 'Ohne Kategorie' -> -----------------------")
print("[OK] Trenner vor Einstellungen -> _________________________")
PY

chmod 644 "$INDEX"
chown root:root "$INDEX"

echo
echo "===== 3. DIENSTE / API ====="

systemctl restart pve-sensor-web.service
systemctl restart nginx

sleep 3

systemctl is-active --quiet pve-sensor-web.service
systemctl is-active --quiet nginx

curl -m 5 -fsS \
    http://127.0.0.1:9105/api/current \
    >/dev/null

curl -m 5 -fsS \
    http://127.0.0.1:9105/api/categories \
    | python3 -m json.tool

echo
echo "[OK] Live-API"
echo "[OK] Kategorie-API"

echo
echo "============================================================"
echo " FERTIG"
echo "============================================================"
echo
echo "Standardstruktur:"
echo "  Intern -> geschlossen / aufklappbar"
echo "  Basics -> immer geöffnet"
echo "  Extras -> geschlossen / aufklappbar"
echo
echo "Menü:"
echo "  Ohne Kategorie = -----------------------"
echo "  Vor Einstellungen = _________________________"
echo
echo "Browser:"
echo "  STRG + F5"
echo
echo "Backup:"
echo "  $BACKUP"
echo
echo "Log:"
echo "  $LOGFILE"
echo "============================================================"
__PVE_V42_DEFAULT_CATEGORIES__
    chmod 700 "$patch"
    bash "$patch"
    rm -f "$patch"
}


# =============================================================================

# =============================================================================
# DASHBOARD USV / NAS KARTE
# =============================================================================
install_dashboard_ups_card_v53() {
    header "DASHBOARD · USV / NAS KARTE"
    local patch="/tmp/pve-dashboard-ups-card-v53.$$"
    cat > "$patch" <<'__PVE_V53_DASHBOARD_UPS_CARD__'
#!/usr/bin/env bash
set -Eeuo pipefail

STAMP="$(date +%d-%m-%H-%M)"
LOGFILE="/root/diagnose/diagnose-dashboard-usv-karte-${STAMP}.txt"

if [[ -e "$LOGFILE" ]]; then
    N=2
    while [[ -e "/root/diagnose/diagnose-dashboard-usv-karte-${STAMP}-${N}.txt" ]]; do
        N=$((N + 1))
    done
    LOGFILE="/root/diagnose/diagnose-dashboard-usv-karte-${STAMP}-${N}.txt"
fi

exec > >(tee -a "$LOGFILE") 2>&1

[[ ${EUID:-$(id -u)} -eq 0 ]] || {
    echo "FEHLER: Bitte als root auf dem Proxmox-Host ausführen."
    exit 1
}

APP="/opt/nodezero/dashboard/app.py"
INDEX="/opt/nodezero/dashboard/static/index.html"
UPS_CONFIG="/etc/pve-sensor-dashboard/ups-source.json"
UPS_STATUS_URL="${PVE_DASHBOARD_UPS_STATUS_URL:-http://192.168.178.111/api/status}"

BACKUP="/root/backups/pve-dashboard-usv-karte-backup-$(date +%Y%m%d-%H%M%S)"

[[ -f "$APP" ]] || {
    echo "FEHLER: $APP fehlt."
    exit 1
}

[[ -f "$INDEX" ]] || {
    echo "FEHLER: $INDEX fehlt."
    exit 1
}

echo "============================================================"
echo " DASHBOARD - USV / NAS KARTE"
echo "============================================================"
echo
echo "Quelle:"
echo "  $UPS_STATUS_URL"
echo
echo "Umbau:"
echo "  - Mainboard-Karte -> USV / NAS"
echo "  - USV-Karte verwendet denselben Rahmen wie das restliche Dashboard"
echo "  - Mainboard-Temperatur -> CPU-Unterzeile"
echo "  - USV-Ladestand / Laufzeit / Quelle / Akku / Last / Modell"
echo "  - fehlende Hardwarewerte werden nicht mehr als '-' angezeigt"
echo
echo "Log:"
echo "  $LOGFILE"
echo

mkdir -p "$BACKUP" "$(dirname "$UPS_CONFIG")"

cp -a "$APP" "$BACKUP/app.py"
cp -a "$INDEX" "$BACKUP/index.html"
[[ -f "$UPS_CONFIG" ]] && cp -a "$UPS_CONFIG" "$BACKUP/ups-source.json"

rollback() {
    echo
    echo "============================================================"
    echo " AUTOMATISCHES ROLLBACK"
    echo "============================================================"

    cp -a "$BACKUP/app.py" "$APP"
    cp -a "$BACKUP/index.html" "$INDEX"

    if [[ -f "$BACKUP/ups-source.json" ]]; then
        cp -a "$BACKUP/ups-source.json" "$UPS_CONFIG"
    fi

    chown root:root "$APP" "$INDEX"
    chmod 644 "$APP" "$INDEX"

    systemctl restart pve-sensor-web.service || true
    systemctl restart nginx || true

    echo "Vorheriger Dashboard-Stand wiederhergestellt."
}

trap 'echo "FEHLER in Zeile $LINENO"; rollback' ERR

echo
echo "===== 1. USV-QUELLE SPEICHERN ====="

python3 - "$UPS_CONFIG" "$UPS_STATUS_URL" <<'PY'
from pathlib import Path
import json
import sys

path = Path(sys.argv[1])
url = sys.argv[2].strip()

if not url.startswith(("http://", "https://")):
    raise SystemExit("FEHLER: UPS-Status-URL muss mit http:// oder https:// beginnen.")

path.parent.mkdir(parents=True, exist_ok=True)

tmp = path.with_suffix(".tmp")
tmp.write_text(
    json.dumps(
        {
            "status_url": url,
            "display_name": "NAS",
        },
        ensure_ascii=False,
        indent=2,
    ) + "\n",
    encoding="utf-8",
)
tmp.chmod(0o644)
tmp.replace(path)
PY

chown root:root "$UPS_CONFIG"
chmod 644 "$UPS_CONFIG"

echo "[OK] $UPS_CONFIG"

echo
echo "===== 2. PVE-UPS DIREKT TESTEN ====="

if UPS_RAW="$(curl -fsS --connect-timeout 3 --max-time 8 "$UPS_STATUS_URL" 2>/dev/null)"; then
    echo "[OK] PVE-UPS /api/status erreichbar."

    printf '%s' "$UPS_RAW" |
    python3 -c '
import json
import sys

data = json.load(sys.stdin)
ups = data.get("ups") or []

print(f"  UPS-Einträge: {len(ups)}")

if ups:
    u = ups[0]
    for key in (
        "name",
        "type",
        "reachable",
        "manufacturer",
        "model",
        "power_source",
        "battery_status",
        "battery_charge_pct",
        "runtime_remaining_min",
        "load_pct",
        "ups_load_pct",
        "last_poll",
    ):
        if key in u:
            print(f"  {key}: {u.get(key)}")
'
else
    echo "[WARNUNG] $UPS_STATUS_URL ist vom Proxmox-Host aktuell nicht erreichbar."
    echo "Das Dashboard wird trotzdem installiert und zeigt dann 'USV nicht erreichbar'."
fi

echo
echo "===== 3. DASHBOARD-BACKEND ERWEITERN ====="

python3 - "$APP" <<'PY'
from pathlib import Path
import py_compile
import sys

path = Path(sys.argv[1])
app = path.read_text(encoding="utf-8")

MARKER = "# PVE_DASHBOARD_UPS_CARD_V1"

if MARKER not in app:
    # Imports
    if "import json\n" not in app:
        app = app.replace(
            "import os\n",
            "import json\nimport os\n",
            1,
        )

    if "import urllib.request\n" not in app:
        app = app.replace(
            "import time\n",
            "import time\nimport urllib.error\nimport urllib.request\n",
            1,
        )

    constants_anchor = 'POWER_HELPER = "/usr/local/sbin/pve-sensor-powerctl"\n'

    if constants_anchor not in app:
        raise SystemExit(
            "FEHLER: POWER_HELPER-Anker in app.py wurde nicht gefunden."
        )

    constants = r'''
# PVE_DASHBOARD_UPS_CARD_V1
UPS_SOURCE_FILE = Path("/etc/pve-sensor-dashboard/ups-source.json")
UPS_DEFAULT_STATUS_URL = "http://192.168.178.111/api/status"

_ups_cache_lock = threading.Lock()
_ups_cache = {
    "fetched_at": 0.0,
    "data": None,
}
UPS_CACHE_SECONDS = 10
UPS_STALE_SECONDS = 180

'''

    app = app.replace(
        constants_anchor,
        constants_anchor + constants,
        1,
    )

    helper_anchor = "\ndef client_ip():\n"

    if helper_anchor not in app:
        raise SystemExit(
            "FEHLER: client_ip()-Anker wurde nicht gefunden."
        )

    helpers = r'''

def ups_source_config():
    result = {
        "status_url": UPS_DEFAULT_STATUS_URL,
        "display_name": "NAS",
    }

    try:
        raw = json.loads(
            UPS_SOURCE_FILE.read_text(encoding="utf-8")
        )

        if isinstance(raw, dict):
            url = str(raw.get("status_url") or "").strip()
            name = str(raw.get("display_name") or "").strip()

            if url.startswith(("http://", "https://")):
                result["status_url"] = url

            if name:
                result["display_name"] = name[:40]
    except Exception:
        pass

    return result


def _ups_num(value, low=None, high=None):
    try:
        value = float(value)

        if low is not None and value < low:
            return None

        if high is not None and value > high:
            return None

        return value
    except Exception:
        return None


def _ups_recursive_value(obj, wanted_keys):
    wanted = {
        str(key).lower()
        for key in wanted_keys
    }

    if isinstance(obj, dict):
        # Direct key first, so a top-level normalized value wins.
        for key, value in obj.items():
            if str(key).lower() in wanted and value not in (None, ""):
                return value

        for value in obj.values():
            found = _ups_recursive_value(value, wanted)
            if found not in (None, ""):
                return found

    elif isinstance(obj, list):
        for value in obj:
            found = _ups_recursive_value(value, wanted)
            if found not in (None, ""):
                return found

    return None


def _normalize_ups_snapshot(payload, cfg):
    ups_list = payload.get("ups") if isinstance(payload, dict) else None

    if not isinstance(ups_list, list) or not ups_list:
        return {
            "ok": False,
            "reachable": False,
            "configured": False,
            "source_url": cfg["status_url"],
            "display_name": cfg["display_name"],
            "error": "PVE-UPS liefert keinen konfigurierten UPS-Eintrag.",
        }

    # Bevorzugt einen erreichbaren UPS-Eintrag.
    ups = next(
        (
            item
            for item in ups_list
            if isinstance(item, dict) and item.get("reachable") is True
        ),
        None,
    )

    if ups is None:
        ups = next(
            (
                item
                for item in ups_list
                if isinstance(item, dict)
            ),
            {},
        )

    # PVE-UPS /api/status stellt die für Shutdown relevanten Werte direkt
    # normalisiert bereit. "load" ist versionsabhängig; deshalb mehrere
    # mögliche Schreibweisen inklusive verschachtelter/raw Werte unterstützen.
    load_raw = _ups_recursive_value(
        ups,
        (
            "load_pct",
            "load_percent",
            "ups_load_pct",
            "ups.load",
            "load",
        ),
    )

    appliance = (
        payload.get("appliance")
        if isinstance(payload.get("appliance"), dict)
        else {}
    )

    return {
        "ok": True,
        "configured": True,
        "source_url": cfg["status_url"],
        "display_name": cfg["display_name"],
        "name": ups.get("name"),
        "type": ups.get("type"),
        "reachable": bool(ups.get("reachable")),
        "manufacturer": ups.get("manufacturer"),
        "model": ups.get("model"),
        "last_poll": ups.get("last_poll"),
        "power_source": ups.get("power_source"),
        "battery_status": ups.get("battery_status"),
        "runtime_remaining_min": _ups_num(
            ups.get("runtime_remaining_min"),
            0,
            100000,
        ),
        "battery_charge_pct": _ups_num(
            ups.get("battery_charge_pct"),
            0,
            100,
        ),
        "load_pct": _ups_num(
            load_raw,
            0,
            100,
        ),
        "alarm": bool(ups.get("alarm")),
        "triggered": bool(ups.get("triggered")),
        "error": ups.get("error"),
        "engine_state": appliance.get("engine_state"),
        "dry_run": appliance.get("dry_run"),
        "pve_ups_version": appliance.get("version"),
    }


def read_ups_status():
    cfg = ups_source_config()
    now = time.time()

    with _ups_cache_lock:
        cached = _ups_cache.get("data")
        fetched_at = float(_ups_cache.get("fetched_at") or 0)

        if cached is not None and now - fetched_at < UPS_CACHE_SECONDS:
            return dict(cached)

    req = urllib.request.Request(
        cfg["status_url"],
        headers={
            "User-Agent": "PVE-Hardware-Monitor/UPS",
            "Accept": "application/json",
        },
    )

    try:
        with urllib.request.urlopen(
            req,
            timeout=4,
        ) as response:
            raw = response.read(1024 * 1024)

        payload = json.loads(raw.decode("utf-8", "replace"))

        if not isinstance(payload, dict):
            raise ValueError("PVE-UPS Antwort ist kein JSON-Objekt.")

        result = _normalize_ups_snapshot(
            payload,
            cfg,
        )

        result["stale"] = False
        result["dashboard_query_at"] = int(now)

        with _ups_cache_lock:
            _ups_cache["fetched_at"] = now
            _ups_cache["data"] = dict(result)

        return result

    except Exception as exc:
        with _ups_cache_lock:
            cached = _ups_cache.get("data")
            fetched_at = float(_ups_cache.get("fetched_at") or 0)

        if cached is not None and now - fetched_at <= UPS_STALE_SECONDS:
            result = dict(cached)
            result["stale"] = True
            result["fetch_error"] = str(exc)
            return result

        return {
            "ok": False,
            "reachable": False,
            "configured": True,
            "source_url": cfg["status_url"],
            "display_name": cfg["display_name"],
            "stale": False,
            "error": str(exc),
        }

'''

    app = app.replace(
        helper_anchor,
        helpers + helper_anchor,
        1,
    )

    route_anchor = '@app.get("/api/current")\ndef current():\n'

    if route_anchor not in app:
        raise SystemExit(
            "FEHLER: /api/current-Anker wurde nicht gefunden."
        )

    route = r'''@app.get("/api/ups")
def ups_status():
    # PVE-UPS /api/status ist read-only; Fehler der externen Quelle
    # dürfen die Hardware-Metrik-API nie offline setzen.
    return jsonify(read_ups_status())


'''

    app = app.replace(
        route_anchor,
        route + route_anchor,
        1,
    )

temp = path.with_suffix(".py.ups-card")
temp.write_text(app, encoding="utf-8")

py_compile.compile(
    str(temp),
    doraise=True,
)

temp.replace(path)

print("[OK] /api/ups Backend eingebaut.")
PY

chmod 644 "$APP"
chown root:root "$APP"

echo
echo "===== 4. DASHBOARD-FRONTEND UMBAUEN ====="

python3 - "$INDEX" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
html = path.read_text(encoding="utf-8")

MARKER = "PVE_DASHBOARD_UPS_CARD_V1"

if MARKER not in html:
    old_card = '''  <div class="card">
    <div class="label">Mainboard / Sensorik</div>
    <div class="value" id="board">–</div>
    <div class="sub" id="boardSub">–</div>
  </div>
'''

    new_card = '''  <div class="card ups-card ups-offline" id="upsCard">
    <div class="ups-head">
      <div class="label">USV / NAS</div>
      <div class="ups-badge" id="upsBadge">192.168.178.111</div>
    </div>
    <div class="value" id="upsValue">–</div>
    <div class="sub" id="upsSub">USV-Daten werden geladen</div>
    <div class="ups-meter"><span id="upsMeter"></span></div>
    <div class="sub ups-meta" id="upsMeta">PVE-UPS</div>
  </div>
'''

    if old_card not in html:
        raise SystemExit(
            "FEHLER: Mainboard-Karte wurde nicht gefunden."
        )

    html = html.replace(
        old_card,
        new_card,
        1,
    )

    css = r'''
/* PVE_DASHBOARD_UPS_CARD_V1 */
.ups-card{
  /* Gleicher Rahmen wie alle anderen Dashboard-Karten. */
  border-color:var(--line);
  box-shadow:none;
}
.ups-card.ups-ok,
.ups-card.ups-warning,
.ups-card.ups-danger,
.ups-card.ups-offline{
  border-color:var(--line);
  box-shadow:none;
}
.ups-head{
  display:flex;
  align-items:center;
  justify-content:space-between;
  gap:8px;
}
.ups-badge{
  max-width:48%;
  overflow:hidden;
  text-overflow:ellipsis;
  white-space:nowrap;
  color:#8fa9c8;
  font-size:10px;
}
.ups-meter{
  height:5px;
  margin:7px 0 6px;
  border-radius:999px;
  overflow:hidden;
  background:#223044;
}
.ups-meter>span{
  display:block;
  width:0;
  height:100%;
  border-radius:inherit;
  background:#37d996;
  transition:width .3s ease,background .2s ease;
}
.ups-meta{
  white-space:nowrap;
  overflow:hidden;
  text-overflow:ellipsis;
  font-size:10px;
}
'''

    if "</style>" not in html:
        raise SystemExit(
            "FEHLER: </style> wurde nicht gefunden."
        )

    html = html.replace(
        "</style>",
        css + "\n</style>",
        1,
    )

    # Hilfsfunktionen vor current().
    current_anchor = "async function current(){\n"

    if current_anchor not in html:
        raise SystemExit(
            "FEHLER: current()-Funktion wurde nicht gefunden."
        )

    ups_js = r'''
function upsSourceText(value){
  return ({
    mains:'Netz',
    battery:'Akku',
    bypass:'Bypass',
    none:'Aus',
    other:'Andere',
    unknown:'Unbekannt'
  })[String(value||'').toLowerCase()]||'Unbekannt';
}

function upsBatteryText(value){
  return ({
    normal:'normal',
    low:'niedrig',
    depleted:'leer',
    unknown:'unbekannt'
  })[String(value||'').toLowerCase()]||String(value||'unbekannt');
}

function upsPollTime(value){
  if(!value)return null;

  const dt=new Date(value);

  if(Number.isNaN(dt.getTime())){
    return null;
  }

  return dt.toLocaleTimeString(
    'de-DE',
    {
      hour:'2-digit',
      minute:'2-digit',
      second:'2-digit'
    }
  );
}

function upsModelText(u){
  const mfr=String(u.manufacturer||'').trim();
  const model=String(u.model||'').trim();

  if(model&&mfr&&model.toLowerCase().startsWith(mfr.toLowerCase())){
    return model;
  }

  return [mfr,model].filter(Boolean).join(' ');
}

function renderUps(u){
  const card=$('upsCard');
  const value=$('upsValue');
  const sub=$('upsSub');
  const meta=$('upsMeta');
  const badge=$('upsBadge');
  const meter=$('upsMeter');

  card.classList.remove(
    'ups-ok',
    'ups-warning',
    'ups-danger',
    'ups-offline'
  );

  const sourceUrl=String(
    u?.source_url||'http://192.168.178.111/api/status'
  );

  try{
    badge.textContent=
      u?.name
      ||u?.display_name
      ||new URL(sourceUrl).hostname
      ||'NAS';
  }catch{
    badge.textContent=u?.name||u?.display_name||'NAS';
  }

  if(!u||!u.ok){
    value.textContent='nicht erreichbar';
    sub.textContent='PVE-UPS Statusabfrage fehlgeschlagen';
    meta.textContent=u?.error||sourceUrl;
    meter.style.width='0%';
    card.classList.add('ups-offline');
    return;
  }

  const charge=
    u.battery_charge_pct==null
      ? null
      : Number(u.battery_charge_pct);

  const runtime=
    u.runtime_remaining_min==null
      ? null
      : Number(u.runtime_remaining_min);

  const load=
    u.load_pct==null
      ? null
      : Number(u.load_pct);

  const source=upsSourceText(u.power_source);
  const battery=upsBatteryText(u.battery_status);

  const valueParts=[
    Number.isFinite(charge)
      ? `${Math.round(charge)} %`
      : null,
    Number.isFinite(runtime)
      ? `${Math.round(runtime)} min`
      : null
  ].filter(Boolean);

  value.textContent=
    valueParts.length
      ? valueParts.join(' · ')
      : source;

  const stateParts=[
    `Quelle ${source}`,
    u.type
      ? String(u.type).toUpperCase()
      : null,
    Number.isFinite(load)
      ? `Last ${n(load,0)} %`
      : null,
    u.battery_status
      ? `Akku ${battery}`
      : null
  ].filter(Boolean);

  sub.textContent=
    stateParts.join(' · ')
    ||'USV-Status verfügbar';

  if(Number.isFinite(charge)){
    const bounded=Math.max(0,Math.min(100,charge));
    meter.style.width=`${bounded}%`;

    meter.style.background=
      bounded<=20
        ? '#ff6573'
        : bounded<=40
          ? '#e1ad42'
          : '#37d996';
  }else{
    meter.style.width='0%';
  }

  const model=upsModelText(u);
  const poll=upsPollTime(u.last_poll);

  meta.textContent=[
    model||null,
    poll
      ? `Abfrage ${poll}`
      : null,
    u.stale
      ? 'zwischengespeichert'
      : null,
    u.dry_run===true
      ? 'TESTMODUS'
      : null
  ].filter(Boolean).join(' · ')
  ||sourceUrl;

  if(
    !u.reachable
  ){
    card.classList.add('ups-offline');
  }else if(
    u.alarm
    ||u.triggered
    ||String(u.battery_status||'').toLowerCase()==='low'
    ||String(u.battery_status||'').toLowerCase()==='depleted'
    ||String(u.power_source||'').toLowerCase()==='battery'
  ){
    card.classList.add('ups-danger');
  }else if(
    String(u.power_source||'').toLowerCase()==='bypass'
    ||u.stale
  ){
    card.classList.add('ups-warning');
  }else{
    card.classList.add('ups-ok');
  }
}

'''

    html = html.replace(
        current_anchor,
        ups_js + current_anchor,
        1,
    )

    # CPU-Zeile: Mainboard-Temperatur mit anzeigen, nicht verfügbare Werte ausblenden.
    old_cpu = '''    $('cpu').textContent=pct(d.cpu_percent);
    $('cpuSub').textContent=
      `${temp(d.cpu_temp)} · ${d.cpu_freq==null?'–':Math.round(d.cpu_freq)+' MHz'} · Vcore ${d.vcore==null?'–':n(d.vcore,3)+' V'}`;

    const boardTemps=[
      d.board_temp!=null?'MB '+temp(d.board_temp):null,
      d.vrm_temp!=null?'VRM '+temp(d.vrm_temp):null,
      d.chipset_temp!=null?'PCH '+temp(d.chipset_temp):null
    ].filter(Boolean);
    $('board').textContent=d.board_temp!=null?temp(d.board_temp):'Sensor n/v';

    const boardDetails=[
      d.vrm_temp!=null?'VRM '+temp(d.vrm_temp):null,
      d.chipset_temp!=null?'PCH '+temp(d.chipset_temp):null
    ].filter(Boolean);

    $('boardSub').textContent=d.board_temp!=null
      ? ('Mainboard / ACPI'+(boardDetails.length?' · '+boardDetails.join(' · '):''))
      : 'Mainboard stellt keine weiteren Sensoren bereit';
'''

    new_cpu = '''    $('cpu').textContent=pct(d.cpu_percent);

    const cpuDetails=[
      d.cpu_temp!=null
        ? `CPU ${temp(d.cpu_temp)}`
        : null,
      d.board_temp!=null
        ? `Board ${temp(d.board_temp)}`
        : null,
      d.cpu_freq!=null
        ? `${Math.round(d.cpu_freq)} MHz`
        : null,
      d.vcore!=null
        ? `Vcore ${n(d.vcore,3)} V`
        : null,
      d.vrm_temp!=null
        ? `VRM ${temp(d.vrm_temp)}`
        : null,
      d.chipset_temp!=null
        ? `PCH ${temp(d.chipset_temp)}`
        : null
    ].filter(Boolean);

    $('cpuSub').textContent=
      cpuDetails.join(' · ')
      ||'Keine Zusatzsensoren verfügbar';

    try{
      renderUps(
        await getJSON('/api/ups')
      );
    }catch(e){
      renderUps({
        ok:false,
        error:e.message
      });
    }
'''

    if old_cpu not in html:
        raise SystemExit(
            "FEHLER: CPU/Mainboard-JavaScriptblock wurde nicht gefunden."
        )

    html = html.replace(
        old_cpu,
        new_cpu,
        1,
    )

    # Speicher/Lüfter: fehlende Sensoren nicht mehr als "–" darstellen.
    old_disk = '''    $('disk').textContent=pct(d.root_percent);
    $('diskSub').textContent=
      `${bytes(d.root_used)} / ${bytes(d.root_total)} · SSD ${temp(d.drive_temp)} · CPU-Fan ${rpm(d.cpu_fan_rpm)}`;
'''

    new_disk = '''    $('disk').textContent=pct(d.root_percent);

    const diskDetails=[
      `${bytes(d.root_used)} / ${bytes(d.root_total)}`,
      d.drive_temp!=null
        ? `SSD ${temp(d.drive_temp)}`
        : null,
      d.cpu_fan_rpm!=null
        ? `CPU-Fan ${rpm(d.cpu_fan_rpm)}`
        : null,
      d.system_fan_rpm!=null
        &&d.system_fan_rpm!==d.cpu_fan_rpm
        ? `System-Fan ${rpm(d.system_fan_rpm)}`
        : null
    ].filter(Boolean);

    $('diskSub').textContent=diskDetails.join(' · ');
'''

    if old_disk not in html:
        raise SystemExit(
            "FEHLER: Speicher/Lüfter-JavaScriptblock wurde nicht gefunden."
        )

    html = html.replace(
        old_disk,
        new_disk,
        1,
    )

    # Leistungsaufnahme: nur Werte zeigen, die wirklich messbar sind.
    old_power = '''    const bp=bestPower(d);
    $('power').textContent=bp[0];
    $('powerSub').textContent=
      `${bp[1]} · Package ${watts(d.cpu_power_w)} · Cores ${watts(d.cpu_core_power_w)} · DRAM ${watts(d.dram_power_w)} · GPU ${watts(d.gpu_power_w)} · System ${watts(d.system_power_w)}`;
'''

    new_power = '''    const bp=bestPower(d);
    $('power').textContent=bp[0];

    const powerDetails=[
      bp[1],
      d.cpu_power_w!=null
        ? `Package ${watts(d.cpu_power_w)}`
        : null,
      d.cpu_core_power_w!=null
        ? `Cores ${watts(d.cpu_core_power_w)}`
        : null,
      d.uncore_power_w!=null
        ? `Uncore ${watts(d.uncore_power_w)}`
        : null,
      d.dram_power_w!=null
        ? `DRAM ${watts(d.dram_power_w)}`
        : null,
      d.gpu_power_w!=null
        ? `GPU ${watts(d.gpu_power_w)}`
        : null,
      d.system_power_w!=null
        ? `System ${watts(d.system_power_w)}`
        : null
    ].filter(Boolean);

    $('powerSub').textContent=powerDetails.join(' · ');
'''

    if old_power not in html:
        raise SystemExit(
            "FEHLER: Leistungsaufnahme-JavaScriptblock wurde nicht gefunden."
        )

    html = html.replace(
        old_power,
        new_power,
        1,
    )

required = [
    MARKER,
    'id="upsCard"',
    'id="upsValue"',
    'id="upsMeter"',
    "renderUps",
    "await getJSON('/api/ups')",
    "`Board ${temp(d.board_temp)}`",
]

for needle in required:
    if needle not in html:
        raise SystemExit(
            f"FEHLER: Frontend-Prüfung fehlgeschlagen: {needle}"
        )

temp = path.with_suffix(".html.ups-card")
temp.write_text(html, encoding="utf-8")
temp.replace(path)

print("[OK] Mainboard-Karte durch USV/NAS ersetzt.")
print("[OK] Mainboard-Temperatur in CPU-Zeile verschoben.")
print("[OK] Nicht messbare Hardwarewerte werden ausgeblendet.")
PY

chmod 644 "$INDEX"
chown root:root "$INDEX"

echo
echo "===== 5. SYNTAX PRÜFEN ====="

python3 -m py_compile "$APP"
echo "[OK] app.py"

if command -v node >/dev/null 2>&1; then
    python3 - "$INDEX" /tmp/pve-dashboard-ups-card.js <<'PY'
from pathlib import Path
import re
import sys

html = Path(sys.argv[1]).read_text(encoding="utf-8")

scripts = re.findall(
    r"<script[^>]*>(.*?)</script>",
    html,
    re.S | re.I,
)

Path(sys.argv[2]).write_text(
    "\n".join(scripts),
    encoding="utf-8",
)
PY

    node --check /tmp/pve-dashboard-ups-card.js
    rm -f /tmp/pve-dashboard-ups-card.js
    echo "[OK] JavaScript"
else
    echo "[INFO] Node nicht installiert; JavaScript-Prüfung übersprungen."
fi

echo
echo "===== 6. DIENSTE NEU STARTEN ====="

systemctl restart pve-sensor-web.service
systemctl restart nginx

sleep 4

systemctl is-active --quiet pve-sensor-web.service
systemctl is-active --quiet nginx

echo "[OK] pve-sensor-web.service"
echo "[OK] nginx"

echo
echo "===== 7. DASHBOARD-APIS TESTEN ====="

CURRENT="$(
    curl -m 5 -fsS \
        http://127.0.0.1:9105/api/current
)"

[[ -n "$CURRENT" ]]

echo "[OK] /api/current"

UPS="$(
    curl -m 8 -fsS \
        http://127.0.0.1:9105/api/ups
)"

[[ -n "$UPS" ]]

echo "[OK] /api/ups"

echo
echo "USV-Dashboardantwort:"
printf '%s' "$UPS" |
    python3 -m json.tool 2>/dev/null || echo "$UPS"

trap - ERR

echo
echo "============================================================"
echo " TEST-UPDATE ERFOLGREICH"
echo "============================================================"
echo
echo "Browser:"
echo "  STRG + F5"
echo
echo "USV-Quelle:"
echo "  $UPS_STATUS_URL"
echo
echo "Backup:"
echo "  $BACKUP"
echo
echo "Log:"
echo "  $LOGFILE"
echo "============================================================"
__PVE_V53_DASHBOARD_UPS_CARD__
    chmod 700 "$patch"

    if (( PVEUPS_INSTALLED )) && [[ -n "${PVEUPS_IP:-}" ]]; then
        PVE_DASHBOARD_UPS_STATUS_URL="http://${PVEUPS_IP}/api/status" \
            bash "$patch"
    else
        PVE_DASHBOARD_UPS_STATUS_URL="http://192.168.178.111/api/status" \
            bash "$patch"
    fi

    rm -f "$patch"
}


# =============================================================================
# DASHBOARD USV-EINSTELLUNGEN / SETTINGS-SESSION
# =============================================================================
install_dashboard_ups_settings_v55() {
    header "DASHBOARD · USV-EINSTELLUNGEN"
    local patch="/tmp/pve-dashboard-ups-settings-v55.$$"
    cat > "$patch" <<'__PVE_V55_UPS_SETTINGS_SESSION__'
#!/usr/bin/env bash
set -Eeuo pipefail

STAMP="$(date +%d-%m-%H-%M)"
LOGFILE="/root/diagnose/diagnose-dashboard-usv-einstellungen-${STAMP}.txt"

if [[ -e "$LOGFILE" ]]; then
    N=2
    while [[ -e "/root/diagnose/diagnose-dashboard-usv-einstellungen-${STAMP}-${N}.txt" ]]; do
        N=$((N + 1))
    done
    LOGFILE="/root/diagnose/diagnose-dashboard-usv-einstellungen-${STAMP}-${N}.txt"
fi

exec > >(tee -a "$LOGFILE") 2>&1

[[ ${EUID:-$(id -u)} -eq 0 ]] || {
    echo "FEHLER: Bitte als root auf dem Proxmox-Host ausführen."
    exit 1
}

APP="/opt/nodezero/dashboard/app.py"
INDEX="/opt/nodezero/dashboard/static/index.html"
WEB_DIR="/var/lib/pve-sensor-dashboard-web"
UPS_CONFIG="${WEB_DIR}/ups-source.json"
OLD_UPS_CONFIG="/etc/pve-sensor-dashboard/ups-source.json"

BACKUP="/root/backups/pve-dashboard-usv-einstellungen-backup-$(date +%Y%m%d-%H%M%S)"

[[ -f "$APP" ]] || {
    echo "FEHLER: $APP fehlt."
    exit 1
}

[[ -f "$INDEX" ]] || {
    echo "FEHLER: $INDEX fehlt."
    exit 1
}

grep -Fq "PVE_DASHBOARD_UPS_CARD_V1" "$APP" || {
    echo "FEHLER: Die USV-Karte ist noch nicht installiert."
    exit 1
}

echo "============================================================"
echo " DASHBOARD - USV EINSTELLUNGEN + EINMALIGE ENTSPERRUNG"
echo "============================================================"
echo
echo "Neu:"
echo "  - Einstellungen erst nach Sicherheitscode sichtbar"
echo "  - Code nur einmal pro geöffnetem Einstellungsfenster"
echo "  - danach Links/Kategorien/Dashboard/USV ohne erneute Code-Eingabe"
echo "  - USV-Reiter mit PVE-UPS API oder direkter NUT-Abfrage"
echo "  - V63: re/shlex/socket Runtime-Imports werden immer geprüft"
echo "  - aktuelle Werte bereits vorausgefüllt"
echo "  - USV testen und verfügbare Messwerte anzeigen"
echo
echo "Log:"
echo "  $LOGFILE"
echo

mkdir -p "$BACKUP" "$WEB_DIR"

cp -a "$APP" "$BACKUP/app.py"
cp -a "$INDEX" "$BACKUP/index.html"
[[ -f "$UPS_CONFIG" ]] && cp -a "$UPS_CONFIG" "$BACKUP/ups-source.json"
[[ -f "$OLD_UPS_CONFIG" ]] && cp -a "$OLD_UPS_CONFIG" "$BACKUP/ups-source-old.json"

rollback() {
    echo
    echo "============================================================"
    echo " AUTOMATISCHES ROLLBACK"
    echo "============================================================"

    cp -a "$BACKUP/app.py" "$APP"
    cp -a "$BACKUP/index.html" "$INDEX"

    if [[ -f "$BACKUP/ups-source.json" ]]; then
        cp -a "$BACKUP/ups-source.json" "$UPS_CONFIG"
    else
        rm -f "$UPS_CONFIG"
    fi

    chown root:root "$APP" "$INDEX"
    chmod 644 "$APP" "$INDEX"

    [[ -f "$UPS_CONFIG" ]] && {
        chown pve-monitor:pve-monitor "$UPS_CONFIG" 2>/dev/null || true
        chmod 600 "$UPS_CONFIG"
    }

    systemctl restart pve-sensor-web.service || true
    systemctl restart nginx || true

    echo "Vorheriger Stand wiederhergestellt."
    echo "Backup: $BACKUP"
}

trap 'echo "FEHLER in Zeile $LINENO"; rollback' ERR

echo
echo "===== 1. USV-KONFIGURATION MIGRIEREN ====="

# Web-Verzeichnis gehört bereits dem Dashboard-Benutzer. Sicherstellen, dass
# atomare Konfigurationswrites aus app.py möglich bleiben.
chown pve-monitor:pve-monitor "$WEB_DIR" 2>/dev/null || true
chmod 700 "$WEB_DIR"

python3 - "$UPS_CONFIG" "$OLD_UPS_CONFIG" <<'PY'
from pathlib import Path
from urllib.parse import urlparse
import json
import sys

new_path = Path(sys.argv[1])
old_path = Path(sys.argv[2])

default = {
    "version": 2,
    "mode": "pveups",
    "display_name": "NAS",
    "status_url": "http://192.168.178.111/api/status",
    "pveups": {
        "scheme": "http",
        "host": "192.168.178.111",
        "port": 80,
        "path": "/api/status",
        "timeout": 4,
    },
    "nut": {
        "host": "192.168.178.20",
        "port": 3493,
        "ups_name": "ups",
        "username": "",
        "password": "",
        "timeout": 3,
    },
}

def merge(dst, src):
    if not isinstance(src, dict):
        return

    for key, value in src.items():
        if (
            key in dst
            and isinstance(dst[key], dict)
            and isinstance(value, dict)
        ):
            merge(dst[key], value)
        else:
            dst[key] = value

existing = None

for candidate in (new_path, old_path):
    try:
        data = json.loads(
            candidate.read_text(encoding="utf-8")
        )
    except Exception:
        continue

    if isinstance(data, dict):
        existing = data
        break

if existing:
    # Alte V1-Datei hatte vor allem status_url/display_name.
    status_url = str(
        existing.get("status_url") or ""
    ).strip()

    merge(default, existing)

    if status_url.startswith(("http://", "https://")):
        parsed = urlparse(status_url)

        if parsed.hostname:
            default["pveups"]["scheme"] = parsed.scheme
            default["pveups"]["host"] = parsed.hostname
            default["pveups"]["port"] = (
                parsed.port
                or (443 if parsed.scheme == "https" else 80)
            )
            default["pveups"]["path"] = parsed.path or "/api/status"

            if parsed.query:
                default["pveups"]["path"] += "?" + parsed.query

def build_status_url(cfg):
    p = cfg["pveups"]
    scheme = str(p.get("scheme") or "http")
    host = str(p.get("host") or "192.168.178.111")
    port = int(p.get("port") or (443 if scheme == "https" else 80))
    path = str(p.get("path") or "/api/status")

    if not path.startswith("/"):
        path = "/" + path

    default_port = 443 if scheme == "https" else 80
    port_text = "" if port == default_port else f":{port}"

    return f"{scheme}://{host}{port_text}{path}"

default["status_url"] = build_status_url(default)
default["version"] = 2

new_path.parent.mkdir(
    parents=True,
    exist_ok=True,
)

tmp = new_path.with_suffix(".tmp")

tmp.write_text(
    json.dumps(
        default,
        ensure_ascii=False,
        indent=2,
    ) + "\n",
    encoding="utf-8",
)

tmp.chmod(0o600)
tmp.replace(new_path)

print("Aktive USV-Konfiguration:")
print(json.dumps({
    "mode": default["mode"],
    "display_name": default["display_name"],
    "pveups": default["pveups"],
    "nut": {
        **default["nut"],
        "password": "***" if default["nut"].get("password") else "",
    },
}, ensure_ascii=False, indent=2))
PY

chown pve-monitor:pve-monitor "$UPS_CONFIG"
chmod 600 "$UPS_CONFIG"

echo
echo "===== 2. BACKEND ERWEITERN ====="

python3 - "$APP" <<'PY'
from pathlib import Path
import py_compile
import re
import sys

path = Path(sys.argv[1])
app = path.read_text(encoding="utf-8")

MARKER = "# PVE_UPS_SETTINGS_V2"

# V63:
# Diese Imports müssen auch bei bereits gepatchten Dashboards vorhanden sein.
# Frühere Versionen haben den Importblock nur ausgeführt, solange der
# PVE_UPS_SETTINGS_V2-Marker noch fehlte. Dadurch konnte bei späteren Läufen
# re.fullmatch() mit "name 're' is not defined" abbrechen.
required_runtime_imports = (
    "re",
    "shlex",
    "socket",
)

missing_runtime_imports = [
    module
    for module in required_runtime_imports
    if f"import {module}\n" not in app
]

if missing_runtime_imports:
    import_block = "".join(
        f"import {module}\n"
        for module in missing_runtime_imports
    )

    for anchor in (
        "import sqlite3\n",
        "import json\n",
        "from pathlib import Path\n",
    ):
        if anchor in app:
            app = app.replace(
                anchor,
                anchor + import_block,
                1,
            )
            break
    else:
        app = import_block + app

if MARKER not in app:
    # Direkt vor dem bestehenden /api/ups-Endpoint. So überschreiben die
    # V2-Funktionen die alten V1-Helfer ohne die stabile Karte zu ersetzen.
    route_anchor = '@app.get("/api/ups")\ndef ups_status():\n'

    if route_anchor not in app:
        raise SystemExit(
            "FEHLER: /api/ups wurde nicht gefunden."
        )

    code = r'''
# PVE_UPS_SETTINGS_V2
UPS_SETTINGS_FILE_V2 = Path(
    "/var/lib/pve-sensor-dashboard-web/ups-source.json"
)

# Auch die alten V1-Helfer sollen ab jetzt dieselbe Datei sehen.
UPS_SOURCE_FILE = UPS_SETTINGS_FILE_V2


def _ups_settings_default_v2():
    return {
        "version": 2,
        "mode": "pveups",
        "display_name": "NAS",
        "status_url": "http://192.168.178.111/api/status",
        "pveups": {
            "scheme": "http",
            "host": "192.168.178.111",
            "port": 80,
            "path": "/api/status",
            "timeout": 4,
        },
        "nut": {
            "host": "192.168.178.20",
            "port": 3493,
            "ups_name": "ups",
            "username": "",
            "password": "",
            "timeout": 3,
        },
    }


def _ups_settings_merge_v2(dst, src):
    if not isinstance(src, dict):
        return dst

    for key, value in src.items():
        if (
            key in dst
            and isinstance(dst[key], dict)
            and isinstance(value, dict)
        ):
            _ups_settings_merge_v2(
                dst[key],
                value,
            )
        else:
            dst[key] = value

    return dst


def _ups_build_status_url_v2(settings):
    p = settings["pveups"]
    scheme = str(
        p.get("scheme")
        or "http"
    ).lower()

    host = str(
        p.get("host")
        or "192.168.178.111"
    ).strip()

    port = int(
        p.get("port")
        or (443 if scheme == "https" else 80)
    )

    path = str(
        p.get("path")
        or "/api/status"
    ).strip()

    if not path.startswith("/"):
        path = "/" + path

    default_port = 443 if scheme == "https" else 80
    port_text = "" if port == default_port else f":{port}"

    return (
        f"{scheme}://{host}{port_text}{path}"
    )


def _ups_settings_read_v2():
    data = _ups_settings_default_v2()

    try:
        stored = json.loads(
            UPS_SETTINGS_FILE_V2.read_text(
                encoding="utf-8"
            )
        )

        if isinstance(stored, dict):
            _ups_settings_merge_v2(
                data,
                stored,
            )
    except Exception:
        pass

    data["mode"] = (
        "nut"
        if str(data.get("mode")).lower() == "nut"
        else "pveups"
    )

    data["status_url"] = _ups_build_status_url_v2(
        data
    )

    return data


def ups_source_config():
    # Rückwärtskompatibilität für die V1-Normalisierung.
    cfg = _ups_settings_read_v2()

    return {
        "status_url": cfg["status_url"],
        "display_name": cfg["display_name"],
    }


def _ups_public_settings_v2(settings):
    data = json.loads(
        json.dumps(settings)
    )

    password = str(
        data.get("nut", {}).get("password")
        or ""
    )

    data["nut"]["password"] = ""
    data["nut"]["has_password"] = bool(password)

    return data


def _ups_validate_host_v2(value, label):
    value = str(
        value or ""
    ).strip()

    if (
        not value
        or len(value) > 253
        or any(ch.isspace() for ch in value)
        or "/" in value
    ):
        raise ValueError(
            f"{label}: ungültiger Host/IP-Wert."
        )

    return value


def _ups_validate_port_v2(value, label):
    try:
        value = int(value)
    except Exception:
        raise ValueError(
            f"{label}: Port muss eine Zahl sein."
        )

    if not 1 <= value <= 65535:
        raise ValueError(
            f"{label}: Port muss zwischen 1 und 65535 liegen."
        )

    return value


def _ups_validate_timeout_v2(value):
    try:
        value = int(value)
    except Exception:
        raise ValueError(
            "Zeitlimit muss eine Zahl sein."
        )

    if not 1 <= value <= 15:
        raise ValueError(
            "Zeitlimit muss zwischen 1 und 15 Sekunden liegen."
        )

    return value


def _ups_settings_from_payload_v2(payload, current=None):
    current = current or _ups_settings_read_v2()

    mode = str(
        payload.get("mode")
        or current.get("mode")
        or "pveups"
    ).strip().lower()

    if mode not in ("pveups", "nut"):
        raise ValueError(
            "Abrufart muss PVE-UPS API oder NUT direkt sein."
        )

    display_name = str(
        payload.get("display_name")
        or current.get("display_name")
        or "NAS"
    ).strip()

    if not display_name or len(display_name) > 40:
        raise ValueError(
            "Anzeigename muss 1 bis 40 Zeichen haben."
        )

    pve_current = current.get("pveups") or {}
    nut_current = current.get("nut") or {}

    scheme = str(
        payload.get("pveups_scheme")
        or pve_current.get("scheme")
        or "http"
    ).strip().lower()

    if scheme not in ("http", "https"):
        raise ValueError(
            "PVE-UPS Protokoll muss HTTP oder HTTPS sein."
        )

    pve_host = _ups_validate_host_v2(
        payload.get("pveups_host")
        or pve_current.get("host"),
        "PVE-UPS Host/IP",
    )

    pve_port = _ups_validate_port_v2(
        payload.get("pveups_port")
        or pve_current.get("port")
        or (443 if scheme == "https" else 80),
        "PVE-UPS",
    )

    pve_path = str(
        payload.get("pveups_path")
        or pve_current.get("path")
        or "/api/status"
    ).strip()

    if not pve_path.startswith("/"):
        pve_path = "/" + pve_path

    if (
        len(pve_path) > 200
        or "\n" in pve_path
        or "\r" in pve_path
    ):
        raise ValueError(
            "PVE-UPS API-Pfad ist ungültig."
        )

    pve_timeout = _ups_validate_timeout_v2(
        payload.get("pveups_timeout")
        or pve_current.get("timeout")
        or 4
    )

    nut_host = _ups_validate_host_v2(
        payload.get("nut_host")
        or nut_current.get("host"),
        "NUT Host/IP",
    )

    nut_port = _ups_validate_port_v2(
        payload.get("nut_port")
        or nut_current.get("port")
        or 3493,
        "NUT",
    )

    ups_name = str(
        payload.get("nut_ups_name")
        or nut_current.get("ups_name")
        or "ups"
    ).strip()

    if not re.fullmatch(
        r"[A-Za-z0-9_.:-]{1,64}",
        ups_name,
    ):
        raise ValueError(
            "NUT USV-Name enthält ungültige Zeichen."
        )

    username = str(
        payload.get("nut_username")
        if "nut_username" in payload
        else nut_current.get("username", "")
    ).strip()

    if (
        len(username) > 64
        or "\n" in username
        or "\r" in username
    ):
        raise ValueError(
            "NUT Benutzer ist ungültig."
        )

    new_password = payload.get("nut_password")

    if new_password is None:
        password = str(
            nut_current.get("password")
            or ""
        )
    else:
        new_password = str(new_password)

        if new_password:
            password = new_password
        elif bool(payload.get("nut_clear_password")):
            password = ""
        else:
            password = str(
                nut_current.get("password")
                or ""
            )

    if (
        len(password) > 128
        or "\n" in password
        or "\r" in password
    ):
        raise ValueError(
            "NUT Passwort ist ungültig."
        )

    nut_timeout = _ups_validate_timeout_v2(
        payload.get("nut_timeout")
        or nut_current.get("timeout")
        or 3
    )

    result = {
        "version": 2,
        "mode": mode,
        "display_name": display_name,
        "pveups": {
            "scheme": scheme,
            "host": pve_host,
            "port": pve_port,
            "path": pve_path,
            "timeout": pve_timeout,
        },
        "nut": {
            "host": nut_host,
            "port": nut_port,
            "ups_name": ups_name,
            "username": username,
            "password": password,
            "timeout": nut_timeout,
        },
    }

    result["status_url"] = _ups_build_status_url_v2(
        result
    )

    return result


def _dashboard_code_check_v2(payload):
    ip = client_ip()

    locked, remaining = rate_state(ip)

    if locked:
        return False, (
            jsonify({
                "error": (
                    "Zu viele Fehlversuche. "
                    f"Noch {remaining} Sekunden gesperrt."
                )
            }),
            429,
        )

    code = str(
        payload.get("code")
        or ""
    )

    if not verify_code(code):
        fails, locked_until = record_failure(ip)

        if locked_until > time.time():
            return False, (
                jsonify({
                    "error": (
                        "Zu viele Fehlversuche. "
                        "Diese IP ist 5 Minuten gesperrt."
                    )
                }),
                429,
            )

        return False, (
            jsonify({
                "error": (
                    "Sicherheitscode ist falsch. "
                    f"Fehlversuch {fails}/{MAX_FAILS}."
                )
            }),
            403,
        )

    clear_failures(ip)

    return True, None


def _nut_unquote_v2(value):
    try:
        parts = shlex.split(
            value,
            posix=True,
        )

        return parts[0] if parts else ""
    except Exception:
        return value.strip().strip('"')


def _nut_query_v2(settings):
    cfg = settings["nut"]

    host = cfg["host"]
    port = int(cfg["port"])
    ups_name = cfg["ups_name"]
    username = cfg.get("username") or ""
    password = cfg.get("password") or ""
    timeout = int(cfg.get("timeout") or 3)

    values = {}

    with socket.create_connection(
        (host, port),
        timeout=timeout,
    ) as sock:
        sock.settimeout(timeout)

        reader = sock.makefile(
            "r",
            encoding="utf-8",
            errors="replace",
            newline="\n",
        )

        writer = sock.makefile(
            "w",
            encoding="utf-8",
            newline="\n",
        )

        def command(line):
            writer.write(line + "\n")
            writer.flush()
            return reader.readline().strip()

        if username:
            reply = command(
                f"USERNAME {username}"
            )

            if reply.startswith("ERR"):
                raise RuntimeError(
                    f"NUT USERNAME: {reply}"
                )

        if password:
            reply = command(
                f"PASSWORD {password}"
            )

            if reply.startswith("ERR"):
                raise RuntimeError(
                    f"NUT PASSWORD: {reply}"
                )

        writer.write(
            f"LIST VAR {ups_name}\n"
        )
        writer.flush()

        first = reader.readline().strip()

        if first.startswith("ERR"):
            raise RuntimeError(
                f"NUT LIST VAR: {first}"
            )

        if not first.startswith("BEGIN LIST VAR"):
            raise RuntimeError(
                f"Unerwartete NUT-Antwort: {first}"
            )

        while True:
            line = reader.readline()

            if not line:
                raise RuntimeError(
                    "NUT-Verbindung wurde während LIST VAR beendet."
                )

            line = line.strip()

            if line.startswith("END LIST VAR"):
                break

            prefix = f"VAR {ups_name} "

            if not line.startswith(prefix):
                continue

            rest = line[len(prefix):]

            if " " not in rest:
                continue

            key, raw_value = rest.split(
                " ",
                1,
            )

            values[key] = _nut_unquote_v2(
                raw_value
            )

    return values


def _nut_float_v2(values, *keys):
    for key in keys:
        value = values.get(key)

        if value in (None, ""):
            continue

        try:
            return float(value)
        except Exception:
            continue

    return None


def _nut_text_v2(values, *keys):
    for key in keys:
        value = str(
            values.get(key)
            or ""
        ).strip()

        if value:
            return value

    return None


def _nut_status_normalized_v2(settings):
    values = _nut_query_v2(
        settings
    )

    status = str(
        values.get("ups.status")
        or ""
    ).upper().split()

    power_source = "unknown"

    if "OB" in status:
        power_source = "battery"
    elif "BYPASS" in status:
        power_source = "bypass"
    elif "OL" in status:
        power_source = "mains"

    battery_status = (
        "low"
        if "LB" in status
        else "normal"
    )

    runtime_seconds = _nut_float_v2(
        values,
        "battery.runtime",
    )

    runtime_min = (
        runtime_seconds / 60.0
        if runtime_seconds is not None
        else None
    )

    manufacturer = _nut_text_v2(
        values,
        "device.mfr",
        "ups.mfr",
    )

    model = _nut_text_v2(
        values,
        "device.model",
        "ups.model",
    )

    temperature = _nut_float_v2(
        values,
        "ups.temperature",
        "battery.temperature",
    )

    normalized = {
        "ok": True,
        "configured": True,
        "reachable": True,
        "source_mode": "nut",
        "source_url": (
            f"nut://{settings['nut']['host']}:"
            f"{settings['nut']['port']}/"
            f"{settings['nut']['ups_name']}"
        ),
        "display_name": settings["display_name"],
        "name": settings["display_name"],
        "type": "nut",
        "manufacturer": manufacturer,
        "model": model,
        "last_poll": time.strftime(
            "%Y-%m-%dT%H:%M:%S%z"
        ),
        "power_source": power_source,
        "battery_status": battery_status,
        "runtime_remaining_min": runtime_min,
        "battery_charge_pct": _nut_float_v2(
            values,
            "battery.charge",
        ),
        "load_pct": _nut_float_v2(
            values,
            "ups.load",
        ),
        "input_voltage_v": _nut_float_v2(
            values,
            "input.voltage",
        ),
        "output_voltage_v": _nut_float_v2(
            values,
            "output.voltage",
        ),
        "battery_voltage_v": _nut_float_v2(
            values,
            "battery.voltage",
        ),
        "power_w": _nut_float_v2(
            values,
            "ups.realpower",
        ),
        "power_va": _nut_float_v2(
            values,
            "ups.power",
        ),
        "frequency_hz": _nut_float_v2(
            values,
            "input.frequency",
            "output.frequency",
        ),
        "temperature_c": temperature,
        "alarm": bool(
            set(status)
            & {"FSD", "LB", "RB", "OVER", "OFF"}
        ),
        "triggered": False,
        "error": None,
        "raw_values": {
            key: values[key]
            for key in sorted(values)
        },
    }

    return normalized


def _pveups_status_v2(settings):
    url = settings["status_url"]

    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "PVE-Hardware-Monitor/UPS-V2",
            "Accept": "application/json",
        },
    )

    timeout = int(
        settings["pveups"].get("timeout")
        or 4
    )

    with urllib.request.urlopen(
        req,
        timeout=timeout,
    ) as response:
        raw = response.read(
            1024 * 1024
        )

    payload = json.loads(
        raw.decode(
            "utf-8",
            "replace",
        )
    )

    if not isinstance(payload, dict):
        raise ValueError(
            "PVE-UPS Antwort ist kein JSON-Objekt."
        )

    normalized = _normalize_ups_snapshot(
        payload,
        {
            "status_url": url,
            "display_name": settings["display_name"],
        },
    )

    normalized["source_mode"] = "pveups"

    # Zusätzliche Werte finden, sofern die jeweilige PVE-UPS-Version
    # sie im normalisierten oder Raw-Status mitliefert.
    lookup = (
        ("input_voltage_v", (
            "input_voltage",
            "input.voltage",
            "input_voltage_v",
        )),
        ("output_voltage_v", (
            "output_voltage",
            "output.voltage",
            "output_voltage_v",
        )),
        ("battery_voltage_v", (
            "battery_voltage",
            "battery.voltage",
            "battery_voltage_v",
        )),
        ("power_w", (
            "realpower",
            "ups.realpower",
            "power_w",
        )),
        ("power_va", (
            "ups.power",
            "power_va",
        )),
        ("frequency_hz", (
            "input.frequency",
            "output.frequency",
            "frequency_hz",
        )),
        ("temperature_c", (
            "ups.temperature",
            "battery.temperature",
            "temperature_c",
        )),
    )

    for out_key, aliases in lookup:
        raw_value = _ups_recursive_value(
            payload,
            aliases,
        )

        normalized[out_key] = _ups_num(
            raw_value,
            -1000,
            1000000,
        )

    return normalized


def read_ups_status():
    settings = _ups_settings_read_v2()
    now = time.time()

    with _ups_cache_lock:
        cached = _ups_cache.get("data")
        fetched_at = float(
            _ups_cache.get("fetched_at")
            or 0
        )

        # Cache ist nur gültig, wenn die Quelle nicht zwischenzeitlich
        # in den Einstellungen gewechselt wurde.
        cache_key = _ups_cache.get("config_key")
        config_key = (
            settings["mode"],
            settings["status_url"],
            settings["nut"]["host"],
            settings["nut"]["port"],
            settings["nut"]["ups_name"],
        )

        if (
            cached is not None
            and cache_key == config_key
            and now - fetched_at < UPS_CACHE_SECONDS
        ):
            return dict(cached)

    try:
        if settings["mode"] == "nut":
            result = _nut_status_normalized_v2(
                settings
            )
        else:
            result = _pveups_status_v2(
                settings
            )

        result["stale"] = False
        result["dashboard_query_at"] = int(now)

        with _ups_cache_lock:
            _ups_cache["fetched_at"] = now
            _ups_cache["data"] = dict(result)
            _ups_cache["config_key"] = config_key

        return result

    except Exception as exc:
        with _ups_cache_lock:
            cached = _ups_cache.get("data")
            fetched_at = float(
                _ups_cache.get("fetched_at")
                or 0
            )
            cache_key = _ups_cache.get("config_key")

        if (
            cached is not None
            and cache_key == config_key
            and now - fetched_at <= UPS_STALE_SECONDS
        ):
            result = dict(cached)
            result["stale"] = True
            result["fetch_error"] = str(exc)
            return result

        return {
            "ok": False,
            "configured": True,
            "reachable": False,
            "source_mode": settings["mode"],
            "source_url": (
                settings["status_url"]
                if settings["mode"] == "pveups"
                else (
                    f"nut://{settings['nut']['host']}:"
                    f"{settings['nut']['port']}/"
                    f"{settings['nut']['ups_name']}"
                )
            ),
            "display_name": settings["display_name"],
            "stale": False,
            "error": str(exc),
        }


@app.post("/api/settings/unlock")
def dashboard_settings_unlock_v2():
    payload = request.get_json(
        silent=True
    ) or {}

    allowed, error = _dashboard_code_check_v2(
        payload
    )

    if not allowed:
        return error

    return jsonify({
        "ok": True,
    })


@app.post("/api/ups/settings/read")
def ups_settings_read_api_v2():
    payload = request.get_json(
        silent=True
    ) or {}

    allowed, error = _dashboard_code_check_v2(
        payload
    )

    if not allowed:
        return error

    return jsonify({
        "ok": True,
        "settings": _ups_public_settings_v2(
            _ups_settings_read_v2()
        ),
    })


@app.post("/api/ups/settings/test")
def ups_settings_test_api_v2():
    payload = request.get_json(
        silent=True
    ) or {}

    allowed, error = _dashboard_code_check_v2(
        payload
    )

    if not allowed:
        return error

    try:
        settings = _ups_settings_from_payload_v2(
            payload,
            _ups_settings_read_v2(),
        )

        if settings["mode"] == "nut":
            result = _nut_status_normalized_v2(
                settings
            )
        else:
            result = _pveups_status_v2(
                settings
            )

        result["stale"] = False

        return jsonify({
            "ok": True,
            "result": result,
        })

    except Exception as exc:
        return jsonify({
            "ok": False,
            "error": str(exc),
        }), 400


@app.post("/api/ups/settings/save")
def ups_settings_save_api_v2():
    payload = request.get_json(
        silent=True
    ) or {}

    allowed, error = _dashboard_code_check_v2(
        payload
    )

    if not allowed:
        return error

    try:
        current = _ups_settings_read_v2()

        settings = _ups_settings_from_payload_v2(
            payload,
            current,
        )

        UPS_SETTINGS_FILE_V2.parent.mkdir(
            parents=True,
            exist_ok=True,
        )

        temp = UPS_SETTINGS_FILE_V2.with_suffix(
            ".tmp"
        )

        temp.write_text(
            json.dumps(
                settings,
                ensure_ascii=False,
                indent=2,
            ) + "\n",
            encoding="utf-8",
        )

        temp.chmod(0o600)
        temp.replace(
            UPS_SETTINGS_FILE_V2
        )

        with _ups_cache_lock:
            _ups_cache["fetched_at"] = 0.0
            _ups_cache["data"] = None
            _ups_cache["config_key"] = None

        return jsonify({
            "ok": True,
            "settings": _ups_public_settings_v2(
                settings
            ),
        })

    except Exception as exc:
        return jsonify({
            "ok": False,
            "error": str(exc),
        }), 400


'''

    app = app.replace(
        route_anchor,
        code + route_anchor,
        1,
    )

temp = path.with_suffix(
    ".py.ups-settings-v2"
)

temp.write_text(
    app,
    encoding="utf-8",
)

py_compile.compile(
    str(temp),
    doraise=True,
)

temp.replace(path)

print("[OK] Sicherheitscode-Unlock-API")
print("[OK] USV-Einstellungen lesen/testen/speichern")
print("[OK] PVE-UPS API + direkte NUT-Abfrage")
PY

chmod 644 "$APP"
chown root:root "$APP"

echo
echo "===== 3. FRONTEND ERWEITERN ====="

python3 - "$INDEX" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
html = path.read_text(encoding="utf-8")

MARKER = "PVE_UPS_SETTINGS_UI_V2"

if MARKER not in html:
    # ---------------------------------------------------------------------
    # USV-Reiter vor Dashboard einfügen
    # ---------------------------------------------------------------------

    dashboard_tab = re.search(
        r'<button\b'
        r'(?=[^>]*id=["\']settingsHubTabDashboard["\'])'
        r'.*?</button>',
        html,
        re.S | re.I,
    )

    if not dashboard_tab:
        raise SystemExit(
            "FEHLER: Dashboard-Reiter wurde nicht gefunden."
        )

    ups_tab = r'''
      <button
        id="settingsHubTabUps"
        class="settingsHubTab"
        type="button"
        role="tab"
        aria-selected="false"
        onclick="switchUnifiedSettingsTab('ups')"
      >USV</button>
'''

    html = (
        html[:dashboard_tab.start()]
        + ups_tab
        + dashboard_tab.group(0)
        + html[dashboard_tab.end():]
    )

    dashboard_panel = re.search(
        r'<div\b'
        r'(?=[^>]*id=["\']settingsHubPanelDashboard["\'])',
        html,
        re.I,
    )

    if not dashboard_panel:
        raise SystemExit(
            "FEHLER: Dashboard-Panel wurde nicht gefunden."
        )

    ups_panel = r'''
    <div
      id="settingsHubPanelUps"
      class="settingsHubPanel"
      role="tabpanel"
    >
      <div class="upsSettingsPanel">
        <div class="settingsSectionTitle">
          USV-Datenquelle
        </div>

        <p class="settingsNote upsSettingsIntro">
          Das Dashboard kann die USV über die PVE-UPS-API oder direkt
          vom NUT-Server lesen. NUT direkt ist nützlich, wenn du zusätzliche
          Rohwerte wie Last, Spannung oder Leistung abrufen möchtest.
        </p>

        <div class="formGrid">
          <div>
            <label for="upsDisplayName">Anzeigename</label>
            <input
              id="upsDisplayName"
              type="text"
              maxlength="40"
              value="NAS"
            >
          </div>

          <div>
            <label for="upsMode">Abrufart</label>
            <select id="upsMode" onchange="updateUpsSettingsMode()">
              <option value="pveups">PVE-UPS API</option>
              <option value="nut">NUT direkt</option>
            </select>
          </div>
        </div>

        <div id="upsPveSettings" class="upsSourceBox">
          <div class="settingsSectionTitle">
            PVE-UPS API
          </div>

          <div class="formGrid">
            <div>
              <label for="upsPveScheme">Protokoll</label>
              <select id="upsPveScheme">
                <option value="http">HTTP</option>
                <option value="https">HTTPS</option>
              </select>
            </div>

            <div>
              <label for="upsPveHost">Host / IP</label>
              <input
                id="upsPveHost"
                type="text"
                value="192.168.178.111"
                placeholder="192.168.178.111"
              >
            </div>

            <div>
              <label for="upsPvePort">Port</label>
              <input
                id="upsPvePort"
                type="number"
                min="1"
                max="65535"
                value="80"
              >
            </div>

            <div>
              <label for="upsPvePath">API-Pfad</label>
              <input
                id="upsPvePath"
                type="text"
                value="/api/status"
              >
            </div>

            <div>
              <label for="upsPveTimeout">Zeitlimit (s)</label>
              <input
                id="upsPveTimeout"
                type="number"
                min="1"
                max="15"
                value="4"
              >
            </div>
          </div>
        </div>

        <div id="upsNutSettings" class="upsSourceBox menuFormHidden">
          <div class="settingsSectionTitle">
            NUT direkt
          </div>

          <div class="formGrid">
            <div>
              <label for="upsNutHost">Host / IP</label>
              <input
                id="upsNutHost"
                type="text"
                value="192.168.178.20"
                placeholder="192.168.178.20"
              >
            </div>

            <div>
              <label for="upsNutPort">Port</label>
              <input
                id="upsNutPort"
                type="number"
                min="1"
                max="65535"
                value="3493"
              >
            </div>

            <div>
              <label for="upsNutName">USV-Name</label>
              <input
                id="upsNutName"
                type="text"
                value="ups"
                placeholder="ups"
              >
            </div>

            <div>
              <label for="upsNutUser">Benutzer</label>
              <input
                id="upsNutUser"
                type="text"
                autocomplete="off"
                placeholder="optional"
              >
            </div>

            <div>
              <label for="upsNutPassword">Passwort</label>
              <input
                id="upsNutPassword"
                type="password"
                autocomplete="new-password"
                placeholder="optional / bestehendes Passwort bleibt erhalten"
              >
            </div>

            <div>
              <label for="upsNutTimeout">Zeitlimit (s)</label>
              <input
                id="upsNutTimeout"
                type="number"
                min="1"
                max="15"
                value="3"
              >
            </div>

            <div class="full">
              <div class="checkRow">
                <input
                  id="upsNutClearPassword"
                  type="checkbox"
                >
                <label for="upsNutClearPassword">
                  gespeichertes NUT-Passwort löschen
                </label>
              </div>
            </div>
          </div>
        </div>

        <div class="upsCurrentValues">
          <div class="settingsSectionTitle">
            Aktuelle / getestete Werte
          </div>

          <div id="upsSettingsValues" class="upsValueGrid">
            <div class="upsSettingsEmpty">
              Noch keine Abfrage durchgeführt.
            </div>
          </div>
        </div>

        <div id="upsSettingsMsg" class="msg"></div>

        <div class="modalButtons upsSettingsButtons">
          <button
            type="button"
            onclick="testUpsSettings()"
          >
            USV testen / Werte anzeigen
          </button>

          <button
            id="upsSettingsSave"
            type="button"
            onclick="saveUpsSettings()"
          >
            Speichern & anwenden
          </button>
        </div>
      </div>
    </div>
'''

    html = (
        html[:dashboard_panel.start()]
        + ups_panel
        + "\n"
        + html[dashboard_panel.start():]
    )

    # ---------------------------------------------------------------------
    # Entsperrfenster
    # ---------------------------------------------------------------------

    unlock_modal = r'''
<div class="modal" id="settingsUnlockModal">
  <div class="dialog settingsUnlockDialog">
    <h2>⚙ Einstellungen entsperren</h2>

    <p class="settingsNote">
      Die Einstellungen werden erst nach Eingabe des
      Dashboard-Sicherheitscodes angezeigt. Der Code gilt anschließend
      für dieses geöffnete Einstellungsfenster und muss beim Speichern
      nicht erneut eingegeben werden.
    </p>

    <div>
      <label for="settingsUnlockCode">Sicherheitscode</label>
      <input
        id="settingsUnlockCode"
        type="password"
        autocomplete="current-password"
        placeholder="Dashboard-Steuer-Code"
      >
    </div>

    <div id="settingsUnlockMsg" class="msg"></div>

    <div class="modalButtons">
      <button type="button" onclick="closeSettingsUnlock()">
        Schließen
      </button>

      <button
        id="settingsUnlockButton"
        type="button"
        onclick="unlockUnifiedSettings()"
      >
        Entsperren
      </button>
    </div>
  </div>
</div>
'''

    modal_anchor = '<div class="modal" id="settingsHubModal">'

    if modal_anchor not in html:
        raise SystemExit(
            "FEHLER: Einstellungs-Hub wurde nicht gefunden."
        )

    html = html.replace(
        modal_anchor,
        unlock_modal + "\n" + modal_anchor,
        1,
    )

    # ---------------------------------------------------------------------
    # CSS
    # ---------------------------------------------------------------------

    css = r'''
/* PVE_UPS_SETTINGS_UI_V2 */
.settingsUnlockDialog{
  width:min(470px,calc(100vw - 28px));
}
.upsSettingsPanel{
  width:100%;
}
.settingsSectionTitle{
  margin:3px 0 10px;
  color:#eef5ff;
  font-size:12px;
  font-weight:800;
  letter-spacing:.02em;
}
.upsSettingsIntro{
  margin:0 0 14px;
}
.upsSourceBox{
  margin-top:14px;
  padding:12px;
  border:1px solid var(--line);
  border-radius:10px;
  background:#0a1320;
}
.upsCurrentValues{
  margin-top:14px;
  padding-top:12px;
  border-top:1px solid var(--line);
}
.upsValueGrid{
  display:grid;
  grid-template-columns:repeat(3,minmax(0,1fr));
  gap:7px;
}
.upsValueItem{
  min-width:0;
  padding:8px 9px;
  border:1px solid #273a51;
  border-radius:8px;
  background:#0a1320;
}
.upsValueLabel{
  color:#7f98b7;
  font-size:9px;
  text-transform:uppercase;
  letter-spacing:.05em;
}
.upsValueValue{
  margin-top:3px;
  color:#eef5ff;
  font-size:12px;
  font-weight:750;
  overflow-wrap:anywhere;
}
.upsSettingsEmpty{
  grid-column:1/-1;
  color:var(--muted);
  font-size:12px;
}
.upsSettingsButtons{
  margin-top:12px;
  border-top:1px solid var(--line);
  padding-top:12px;
}
.settingsCodeSessionHidden{
  display:none!important;
}
@media(max-width:720px){
  .upsValueGrid{
    grid-template-columns:1fr 1fr;
  }
}
'''

    if "</style>" not in html:
        raise SystemExit(
            "FEHLER: </style> fehlt."
        )

    html = html.replace(
        "</style>",
        css + "\n</style>",
        1,
    )

    # ---------------------------------------------------------------------
    # JavaScript
    # ---------------------------------------------------------------------

    js = r'''
/* PVE_UPS_SETTINGS_UI_V2 */

let settingsSessionCode='';
let settingsPendingTab='links';
let upsSettingsLoaded=null;

function syncSettingsSessionCodeFields(){
  if(!settingsSessionCode)return;

  [
    'linkCode',
    'categoryCode',
    'categoryAssignCode',
    'settingsCode'
  ].forEach(id=>{
    const input=$(id);

    if(input){
      input.value=settingsSessionCode;
    }
  });
}

function hideRepeatedSecurityCodeFields(){
  [
    'linkCode',
    'categoryCode',
    'categoryAssignCode',
    'settingsCode'
  ].forEach(id=>{
    const input=$(id);

    if(!input)return;

    const wrapper=input.closest('div');

    if(wrapper){
      wrapper.classList.add(
        'settingsCodeSessionHidden'
      );
    }
  });

  const notes=[
    ...document.querySelectorAll(
      '#settingsHubModal .smallHint'
    )
  ];

  notes.forEach(note=>{
    if(
      /sicherheitscode|steuer-code/i.test(
        note.textContent||''
      )
    ){
      note.classList.add(
        'settingsCodeSessionHidden'
      );
    }
  });
}

function clearSettingsSession(){
  settingsSessionCode='';

  [
    'linkCode',
    'categoryCode',
    'categoryAssignCode',
    'settingsCode',
    'settingsUnlockCode'
  ].forEach(id=>{
    const input=$(id);

    if(input){
      input.value='';
    }
  });
}

function requestSettingsUnlock(tab='links'){
  closeNav();

  settingsPendingTab=
    ['links','categories','ups','dashboard'].includes(tab)
      ? tab
      : 'links';

  if(settingsSessionCode){
    return openUnlockedUnifiedSettings(
      settingsPendingTab
    );
  }

  $('settingsUnlockMsg').textContent='';
  $('settingsUnlockMsg').className='msg';
  $('settingsUnlockCode').value='';

  $('settingsUnlockModal').classList.add(
    'show'
  );

  setTimeout(
    ()=>$('settingsUnlockCode').focus(),
    80
  );
}

function closeSettingsUnlock(){
  $('settingsUnlockModal').classList.remove(
    'show'
  );

  $('settingsUnlockCode').value='';
  $('settingsUnlockMsg').textContent='';
}

async function unlockUnifiedSettings(){
  const code=$('settingsUnlockCode').value;
  const button=$('settingsUnlockButton');

  if(code.length<6){
    $('settingsUnlockMsg').textContent=
      'Bitte den Dashboard-Sicherheitscode eingeben.';
    $('settingsUnlockMsg').className='msg err';
    return;
  }

  button.disabled=true;

  try{
    await getJSON(
      '/api/settings/unlock',
      {
        method:'POST',
        headers:{
          'Content-Type':'application/json'
        },
        body:JSON.stringify({
          code
        })
      }
    );

    settingsSessionCode=code;

    closeSettingsUnlock();
    syncSettingsSessionCodeFields();
    hideRepeatedSecurityCodeFields();

    await openUnlockedUnifiedSettings(
      settingsPendingTab
    );

  }catch(e){
    $('settingsUnlockMsg').textContent=e.message;
    $('settingsUnlockMsg').className='msg err';

    $('settingsUnlockCode').select();
  }finally{
    button.disabled=false;
  }
}

const upsSettingsLegacyOpenUnifiedSettings=
  typeof openUnifiedSettings==='function'
    ? openUnifiedSettings
    : null;

const upsSettingsLegacyCloseUnifiedSettings=
  typeof closeUnifiedSettings==='function'
    ? closeUnifiedSettings
    : null;

const upsSettingsLegacyPrepareUnifiedSettingsTab=
  typeof prepareUnifiedSettingsTab==='function'
    ? prepareUnifiedSettingsTab
    : null;

async function openUnlockedUnifiedSettings(tab='links'){
  if(!settingsSessionCode){
    return requestSettingsUnlock(tab);
  }

  syncSettingsSessionCodeFields();
  hideRepeatedSecurityCodeFields();

  if(upsSettingsLegacyOpenUnifiedSettings){
    /*
     * Der alte Hub kennt den USV-Reiter noch nicht.
     * Bei USV zunächst Links öffnen, danach auf USV umschalten.
     */
    await upsSettingsLegacyOpenUnifiedSettings(
      tab==='ups' ? 'links' : tab
    );
  }

  if(tab==='ups'){
    await prepareUnifiedSettingsTab('ups');
    setUnifiedSettingsTab('ups');
  }

  syncSettingsSessionCodeFields();
  hideRepeatedSecurityCodeFields();
}

openUnifiedSettings=async function(tab='links'){
  if(!settingsSessionCode){
    return requestSettingsUnlock(tab);
  }

  return await openUnlockedUnifiedSettings(tab);
};

closeUnifiedSettings=function(){
  if(upsSettingsLegacyCloseUnifiedSettings){
    upsSettingsLegacyCloseUnifiedSettings();
  }else if($('settingsHubModal')){
    $('settingsHubModal').classList.remove('show');
  }

  clearSettingsSession();
};

openLinkManager=function(){
  return openUnifiedSettings('links');
};

openDashboardSettings=function(){
  return openUnifiedSettings('dashboard');
};

closeLinkManager=function(){
  closeUnifiedSettings();
};

closeDashboardSettings=function(){
  closeUnifiedSettings();
};

function setUnifiedSettingsTab(tab){
  const wanted=
    ['links','categories','ups','dashboard'].includes(tab)
      ? tab
      : 'links';

  const mapping={
    links:[
      'settingsHubTabLinks',
      'settingsHubPanelLinks'
    ],
    categories:[
      'settingsHubTabCategories',
      'settingsHubPanelCategories'
    ],
    ups:[
      'settingsHubTabUps',
      'settingsHubPanelUps'
    ],
    dashboard:[
      'settingsHubTabDashboard',
      'settingsHubPanelDashboard'
    ]
  };

  Object.entries(mapping).forEach(
    ([name,[tabId,panelId]])=>{
      const active=name===wanted;
      const tabEl=$(tabId);
      const panelEl=$(panelId);

      if(tabEl){
        tabEl.classList.toggle(
          'active',
          active
        );

        tabEl.setAttribute(
          'aria-selected',
          String(active)
        );
      }

      if(panelEl){
        panelEl.classList.toggle(
          'active',
          active
        );
      }
    }
  );
}

prepareUnifiedSettingsTab=async function(tab){
  if(tab==='ups'){
    await loadUpsSettings();
    syncSettingsSessionCodeFields();
    return;
  }

  if(upsSettingsLegacyPrepareUnifiedSettingsTab){
    const result=
      await upsSettingsLegacyPrepareUnifiedSettingsTab(
        tab
      );

    syncSettingsSessionCodeFields();
    hideRepeatedSecurityCodeFields();

    return result;
  }
};

switchUnifiedSettingsTab=async function(tab){
  if(!settingsSessionCode){
    return requestSettingsUnlock(tab);
  }

  const wanted=
    ['links','categories','ups','dashboard'].includes(tab)
      ? tab
      : 'links';

  await prepareUnifiedSettingsTab(
    wanted
  );

  setUnifiedSettingsTab(
    wanted
  );

  syncSettingsSessionCodeFields();
  hideRepeatedSecurityCodeFields();
};

function updateUpsSettingsMode(){
  const mode=$('upsMode').value;

  $('upsPveSettings').classList.toggle(
    'menuFormHidden',
    mode!=='pveups'
  );

  $('upsNutSettings').classList.toggle(
    'menuFormHidden',
    mode!=='nut'
  );
}

function upsSettingsPayload(){
  return {
    code:settingsSessionCode,
    mode:$('upsMode').value,
    display_name:$('upsDisplayName').value.trim(),

    pveups_scheme:$('upsPveScheme').value,
    pveups_host:$('upsPveHost').value.trim(),
    pveups_port:Number($('upsPvePort').value),
    pveups_path:$('upsPvePath').value.trim(),
    pveups_timeout:Number($('upsPveTimeout').value),

    nut_host:$('upsNutHost').value.trim(),
    nut_port:Number($('upsNutPort').value),
    nut_ups_name:$('upsNutName').value.trim(),
    nut_username:$('upsNutUser').value.trim(),
    nut_password:$('upsNutPassword').value,
    nut_clear_password:$('upsNutClearPassword').checked,
    nut_timeout:Number($('upsNutTimeout').value)
  };
}

function fillUpsSettings(settings){
  upsSettingsLoaded=settings||{};

  const p=settings?.pveups||{};
  const n=settings?.nut||{};

  $('upsDisplayName').value=
    settings?.display_name||'NAS';

  $('upsMode').value=
    settings?.mode==='nut'
      ? 'nut'
      : 'pveups';

  $('upsPveScheme').value=
    p.scheme==='https'
      ? 'https'
      : 'http';

  $('upsPveHost').value=
    p.host||'192.168.178.111';

  $('upsPvePort').value=
    p.port||80;

  $('upsPvePath').value=
    p.path||'/api/status';

  $('upsPveTimeout').value=
    p.timeout||4;

  $('upsNutHost').value=
    n.host||'192.168.178.20';

  $('upsNutPort').value=
    n.port||3493;

  $('upsNutName').value=
    n.ups_name||'ups';

  $('upsNutUser').value=
    n.username||'';

  $('upsNutPassword').value='';
  $('upsNutClearPassword').checked=false;

  $('upsNutPassword').placeholder=
    n.has_password
      ? 'Passwort gespeichert – leer lassen zum Beibehalten'
      : 'optional';

  $('upsNutTimeout').value=
    n.timeout||3;

  updateUpsSettingsMode();
}

async function loadUpsSettings(){
  if(!settingsSessionCode){
    return;
  }

  $('upsSettingsMsg').textContent=
    'USV-Einstellungen werden geladen ...';

  $('upsSettingsMsg').className='msg';

  try{
    const data=await getJSON(
      '/api/ups/settings/read',
      {
        method:'POST',
        headers:{
          'Content-Type':'application/json'
        },
        body:JSON.stringify({
          code:settingsSessionCode
        })
      }
    );

    fillUpsSettings(
      data.settings||{}
    );

    $('upsSettingsMsg').textContent='';
    $('upsSettingsMsg').className='msg';

    try{
      const current=await getJSON('/api/ups');
      renderUpsSettingsValues(current);
    }catch{
      renderUpsSettingsValues(null);
    }

  }catch(e){
    $('upsSettingsMsg').textContent=e.message;
    $('upsSettingsMsg').className='msg err';
  }
}

function upsValueDisplay(value,unit=''){
  if(value===null||value===undefined||value===''){
    return null;
  }

  if(typeof value==='number'){
    return `${n(value,1)}${unit}`;
  }

  return `${value}${unit}`;
}

function renderUpsSettingsValues(data){
  const box=$('upsSettingsValues');

  if(!box)return;

  box.innerHTML='';

  if(!data||!data.ok){
    const empty=document.createElement('div');
    empty.className='upsSettingsEmpty';
    empty.textContent=
      data?.error
      ||'Keine USV-Werte verfügbar.';
    box.appendChild(empty);
    return;
  }

  const rows=[
    ['Abrufart',
      data.source_mode==='nut'
        ? 'NUT direkt'
        : 'PVE-UPS API'],
    ['Quelle',upsSourceText(data.power_source)],
    ['Ladestand',upsValueDisplay(data.battery_charge_pct,' %')],
    ['Restlaufzeit',upsValueDisplay(data.runtime_remaining_min,' min')],
    ['Auslastung',upsValueDisplay(data.load_pct,' %')],
    ['Akku',upsBatteryText(data.battery_status)],
    ['Hersteller',data.manufacturer],
    ['Modell',data.model],
    ['Eingang',upsValueDisplay(data.input_voltage_v,' V')],
    ['Ausgang',upsValueDisplay(data.output_voltage_v,' V')],
    ['Akkuspannung',upsValueDisplay(data.battery_voltage_v,' V')],
    ['Wirkleistung',upsValueDisplay(data.power_w,' W')],
    ['Scheinleistung',upsValueDisplay(data.power_va,' VA')],
    ['Frequenz',upsValueDisplay(data.frequency_hz,' Hz')],
    ['Temperatur',upsValueDisplay(data.temperature_c,' °C')],
    ['Letzte Abfrage',upsPollTime(data.last_poll)]
  ].filter(
    row=>row[1]!==null
      &&row[1]!==undefined
      &&row[1]!==''
      &&row[1]!=='Unbekannt'
  );

  rows.forEach(([label,value])=>{
    const item=document.createElement('div');
    item.className='upsValueItem';

    const key=document.createElement('div');
    key.className='upsValueLabel';
    key.textContent=label;

    const val=document.createElement('div');
    val.className='upsValueValue';
    val.textContent=value;

    item.append(key,val);
    box.appendChild(item);
  });

  if(
    data.raw_values
    &&typeof data.raw_values==='object'
  ){
    const count=Object.keys(
      data.raw_values
    ).length;

    if(count){
      const item=document.createElement('div');
      item.className='upsValueItem';

      const key=document.createElement('div');
      key.className='upsValueLabel';
      key.textContent='NUT Rohwerte';

      const val=document.createElement('div');
      val.className='upsValueValue';
      val.textContent=`${count} Werte verfügbar`;

      item.title=Object.entries(
        data.raw_values
      ).map(
        ([k,v])=>`${k} = ${v}`
      ).join('\n');

      item.append(key,val);
      box.appendChild(item);
    }
  }
}

async function testUpsSettings(){
  if(!settingsSessionCode){
    return requestSettingsUnlock('ups');
  }

  $('upsSettingsMsg').textContent=
    'USV-Verbindung wird getestet ...';
  $('upsSettingsMsg').className='msg';

  try{
    const data=await getJSON(
      '/api/ups/settings/test',
      {
        method:'POST',
        headers:{
          'Content-Type':'application/json'
        },
        body:JSON.stringify(
          upsSettingsPayload()
        )
      }
    );

    renderUpsSettingsValues(
      data.result
    );

    $('upsSettingsMsg').textContent=
      'Verbindung erfolgreich. Die angezeigten Werte werden von dieser Quelle geliefert.';

    $('upsSettingsMsg').className='msg ok';

  }catch(e){
    renderUpsSettingsValues({
      ok:false,
      error:e.message
    });

    $('upsSettingsMsg').textContent=e.message;
    $('upsSettingsMsg').className='msg err';
  }
}

async function saveUpsSettings(){
  if(!settingsSessionCode){
    return requestSettingsUnlock('ups');
  }

  const button=$('upsSettingsSave');
  button.disabled=true;

  $('upsSettingsMsg').textContent=
    'USV-Einstellungen werden gespeichert ...';

  $('upsSettingsMsg').className='msg';

  try{
    const data=await getJSON(
      '/api/ups/settings/save',
      {
        method:'POST',
        headers:{
          'Content-Type':'application/json'
        },
        body:JSON.stringify(
          upsSettingsPayload()
        )
      }
    );

    fillUpsSettings(
      data.settings||{}
    );

    const current=await getJSON('/api/ups');

    renderUpsSettingsValues(
      current
    );

    renderUps(current);

    $('upsSettingsMsg').textContent=
      'Gespeichert und sofort angewendet.';

    $('upsSettingsMsg').className='msg ok';

  }catch(e){
    $('upsSettingsMsg').textContent=e.message;
    $('upsSettingsMsg').className='msg err';
  }finally{
    button.disabled=false;
  }
}

/*
 * Vor jedem Button-Klick im geöffneten Einstellungsfenster den einmal
 * eingegebenen Code automatisch in die alten, jetzt versteckten
 * Code-Felder einsetzen. Damit funktionieren alle vorhandenen
 * Link-/Kategorie-/Dashboard-Save-Routen unverändert weiter.
 */
document.addEventListener(
  'click',
  event=>{
    if(
      settingsSessionCode
      &&$('settingsHubModal')?.classList.contains('show')
    ){
      syncSettingsSessionCodeFields();
    }
  },
  true
);

$('settingsUnlockCode')?.addEventListener(
  'keydown',
  event=>{
    if(event.key==='Enter'){
      event.preventDefault();
      unlockUnifiedSettings();
    }
  }
);

document.addEventListener(
  'keydown',
  event=>{
    if(
      event.key==='Escape'
      &&$('settingsUnlockModal')?.classList.contains('show')
    ){
      closeSettingsUnlock();
    }
  }
);

setTimeout(()=>{
  hideRepeatedSecurityCodeFields();
},0);

'''

    init = re.search(
        r'\(async\(\)=>\{',
        html,
    )

    if not init:
        raise SystemExit(
            "FEHLER: JavaScript-Hauptinitialisierung fehlt."
        )

    html = (
        html[:init.start()]
        + js
        + "\n"
        + html[init.start():]
    )

required = [
    MARKER,
    'id="settingsHubTabUps"',
    'id="settingsHubPanelUps"',
    'id="settingsUnlockModal"',
    'id="upsPveHost"',
    'value="192.168.178.111"',
    'id="upsNutHost"',
    'value="192.168.178.20"',
    'value="3493"',
    'value="ups"',
    "settingsSessionCode",
    "unlockUnifiedSettings",
    "saveUpsSettings",
    "testUpsSettings",
]

for needle in required:
    if needle not in html:
        raise SystemExit(
            f"FEHLER: Frontend-Prüfung fehlgeschlagen: {needle}"
        )

temp = path.with_suffix(
    ".html.ups-settings-v2"
)

temp.write_text(
    html,
    encoding="utf-8",
)

temp.replace(path)

print("[OK] Einstellungen sind jetzt codegeschützt.")
print("[OK] USV-Reiter mit PVE-UPS und NUT direkt.")
print("[OK] Wiederholte Sicherheitscode-Felder ausgeblendet.")
PY

chmod 644 "$INDEX"
chown root:root "$INDEX"

echo
echo "===== 4. SYNTAXPRÜFUNG ====="

python3 -m py_compile "$APP"
echo "[OK] app.py"

if command -v node >/dev/null 2>&1; then
    python3 - "$INDEX" /tmp/pve-ups-settings-v2.js <<'PY'
from pathlib import Path
import re
import sys

html = Path(sys.argv[1]).read_text(
    encoding="utf-8"
)

scripts = re.findall(
    r"<script[^>]*>(.*?)</script>",
    html,
    re.S | re.I,
)

Path(sys.argv[2]).write_text(
    "\n".join(scripts),
    encoding="utf-8",
)
PY

    node --check /tmp/pve-ups-settings-v2.js
    rm -f /tmp/pve-ups-settings-v2.js

    echo "[OK] JavaScript"
else
    echo "[INFO] Node nicht vorhanden; JavaScript-Prüfung übersprungen."
fi

echo
echo "===== 5. DIENSTE ====="

systemctl restart pve-sensor-web.service
systemctl restart nginx

sleep 4

systemctl is-active --quiet pve-sensor-web.service
systemctl is-active --quiet nginx

echo "[OK] pve-sensor-web.service"
echo "[OK] nginx"

echo
echo "===== 6. ÖFFENTLICHE APIS ====="

curl -m 5 -fsS \
    http://127.0.0.1:9105/api/current \
    >/dev/null

echo "[OK] /api/current"

curl -m 8 -fsS \
    http://127.0.0.1:9105/api/ups \
    | python3 -m json.tool

echo
echo "[OK] /api/ups"

trap - ERR

echo
echo "============================================================"
echo " FERTIG"
echo "============================================================"
echo
echo "Browser:"
echo "  STRG + F5"
echo
echo "Danach:"
echo "  ☰ Menü -> ⚙ Einstellungen"
echo "  -> zuerst Sicherheitscode"
echo "  -> dann [Webseitenverwaltung] [Kategorien] [USV] [Dashboard]"
echo
echo "USV-Defaults:"
echo "  PVE-UPS: 192.168.178.111:80 /api/status"
echo "  NUT:     192.168.178.20:3493 / USV-Name ups"
echo
echo "Backup:"
echo "  $BACKUP"
echo
echo "Log:"
echo "  $LOGFILE"
echo "============================================================"
__PVE_V55_UPS_SETTINGS_SESSION__
    chmod 700 "$patch"
    bash "$patch"
    rm -f "$patch"
}


# =============================================================================
# DASHBOARD USV UI FIX V3
# =============================================================================
install_dashboard_ups_ui_fix_v56() {
    header "DASHBOARD · USV UI"
    local patch="/tmp/pve-dashboard-ups-ui-v56.$$"
    cat > "$patch" <<'__PVE_V56_UPS_UI_FIX_V3__'
#!/usr/bin/env bash
set -Eeuo pipefail

STAMP="$(date +%d-%m-%H-%M)"
LOGFILE="/root/diagnose/diagnose-dashboard-usv-ui-fix-${STAMP}.txt"

if [[ -e "$LOGFILE" ]]; then
    N=2
    while [[ -e "/root/diagnose/diagnose-dashboard-usv-ui-fix-${STAMP}-${N}.txt" ]]; do
        N=$((N + 1))
    done
    LOGFILE="/root/diagnose/diagnose-dashboard-usv-ui-fix-${STAMP}-${N}.txt"
fi

exec > >(tee -a "$LOGFILE") 2>&1

[[ ${EUID:-$(id -u)} -eq 0 ]] || {
    echo "FEHLER: Bitte als root ausführen."
    exit 1
}

INDEX="/opt/nodezero/dashboard/static/index.html"
BACKUP="/root/backups/pve-dashboard-usv-ui-backup-$(date +%Y%m%d-%H%M%S)"

[[ -f "$INDEX" ]] || {
    echo "FEHLER: $INDEX fehlt."
    exit 1
}

grep -Fq 'id="upsCard"' "$INDEX" || {
    echo "FEHLER: USV-Karte ist nicht installiert."
    exit 1
}

echo "============================================================"
echo " DASHBOARD - USV UI FIX V3"
echo "============================================================"
echo
echo "Korrekturen:"
echo "  - USV-Reiter zuverlässig anklickbar"
echo "  - USV-Karte normaler Standardrahmen"
echo "  - USV Netz/Batterie neben LIVE"
echo "  - Statuszeile gekürzt"
echo "  - APC-Modellbezeichnung gekürzt"
echo "  - Abfragezeit nur HH:MM Uhr"
echo
echo "Log:"
echo "  $LOGFILE"
echo

mkdir -p "$BACKUP"
cp -a "$INDEX" "$BACKUP/index.html"

python3 - "$INDEX" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
html = path.read_text(encoding="utf-8")

MARKER = "PVE_UPS_UI_FIX_V3"

if MARKER not in html:
    css = r'''
/* PVE_UPS_UI_FIX_V3 */

/* USV-Karte exakt wie alle normalen Cards.
   Keine Statusfarbe darf Rahmen oder Schatten verändern. */
#upsCard.card,
#upsCard.card.ups-ok,
#upsCard.card.ups-warning,
#upsCard.card.ups-danger,
#upsCard.card.ups-offline{
  background:linear-gradient(155deg,#121d2d,#0e1724)!important;
  border:1px solid var(--line)!important;
  box-shadow:none!important;
  outline:none!important;
}

/* USV-Status direkt neben LIVE */
.upsTopState{
  padding:9px 13px;
  border:1px solid var(--line);
  border-radius:12px;
  background:#0e1724;
  font-size:13px;
  font-weight:700;
  white-space:nowrap;
}
.upsTopDot{
  width:9px;
  height:9px;
  border-radius:50%;
  display:inline-block;
  margin-right:7px;
  vertical-align:-1px;
  background:#6f8198;
  box-shadow:none;
}
.upsTopState.mains .upsTopDot{
  background:#35d39a;
}
.upsTopState.battery .upsTopDot{
  background:#e1ad42;
}
.upsTopState.bypass .upsTopDot{
  background:#e1ad42;
}
.upsTopState.offline .upsTopDot{
  background:#6f8198;
}

/* Entsperr-Dialog immer über dem Settings-Hub. */
#settingsUnlockModal{
  z-index:10050!important;
}
'''

    if "</style>" not in html:
        raise SystemExit("FEHLER: </style> nicht gefunden.")

    html = html.replace(
        "</style>",
        css + "\n</style>",
        1,
    )

    js = r'''
/* PVE_UPS_UI_FIX_V3 */

function ensureUpsTopState(){
  let state=$('upsTopState');

  if(state){
    return state;
  }

  const live=$('state')?.closest('.live');

  if(!live){
    return null;
  }

  state=document.createElement('div');
  state.id='upsTopState';
  state.className='upsTopState offline';
  state.innerHTML=
    '<span class="upsTopDot"></span>'
    +'<span id="upsTopStateText">USV …</span>';

  live.insertAdjacentElement(
    'afterend',
    state
  );

  return state;
}

function setUpsTopState(data){
  const state=ensureUpsTopState();

  if(!state){
    return;
  }

  const text=$('upsTopStateText');

  state.classList.remove(
    'mains',
    'battery',
    'bypass',
    'offline'
  );

  if(!data||!data.ok||!data.reachable){
    state.classList.add('offline');
    text.textContent='USV Offline';
    return;
  }

  const source=String(
    data.power_source||''
  ).toLowerCase();

  if(source==='mains'){
    state.classList.add('mains');
    text.textContent='USV Netz';
  }else if(source==='battery'){
    state.classList.add('battery');
    text.textContent='USV Batterie';
  }else if(source==='bypass'){
    state.classList.add('bypass');
    text.textContent='USV Bypass';
  }else{
    state.classList.add('offline');
    text.textContent='USV Status';
  }
}

/* Gewünschte kurze Bezeichnungen. */
upsSourceText=function(value){
  return ({
    mains:'Netz',
    battery:'Batterie',
    bypass:'Bypass',
    none:'Aus',
    other:'Andere',
    unknown:'Unbekannt'
  })[String(value||'').toLowerCase()]
  ||'Unbekannt';
};

upsPollTime=function(value){
  if(!value){
    return null;
  }

  const dt=new Date(value);

  if(Number.isNaN(dt.getTime())){
    return null;
  }

  return dt.toLocaleTimeString(
    'de-DE',
    {
      hour:'2-digit',
      minute:'2-digit'
    }
  );
};

upsModelText=function(u){
  let mfr=String(
    u?.manufacturer||''
  ).trim();

  let model=String(
    u?.model||''
  ).trim();

  const combined=
    `${mfr} ${model}`.toLowerCase();

  const isApc=
    /american power conversion|\bapc\b/.test(
      combined
    );

  if(isApc){
    mfr='APC';

    model=model
      .replace(
        /^American Power Conversion\s*/i,
        ''
      )
      .replace(
        /^APC\s*/i,
        ''
      )
      .replace(
        /^Back-UPS\s*/i,
        ''
      )
      .trim();

    return [
      'APC',
      model
    ].filter(Boolean).join(' ');
  }

  if(
    model
    &&mfr
    &&model.toLowerCase().startsWith(
      mfr.toLowerCase()
    )
  ){
    return model;
  }

  return [
    mfr,
    model
  ].filter(Boolean).join(' ');
};

/*
 * Renderfunktion vollständig überschreiben:
 * - keine "Quelle " Vorsilbe
 * - kurzer APC-Name
 * - HH:MM Uhr
 * - Topbar-USV-Status
 */
renderUps=function(u){
  const card=$('upsCard');
  const value=$('upsValue');
  const sub=$('upsSub');
  const meta=$('upsMeta');
  const badge=$('upsBadge');
  const meter=$('upsMeter');

  setUpsTopState(u);

  if(!card||!value||!sub||!meta||!badge||!meter){
    return;
  }

  card.classList.remove(
    'ups-ok',
    'ups-warning',
    'ups-danger',
    'ups-offline'
  );

  const sourceUrl=String(
    u?.source_url
    ||'http://192.168.178.111/api/status'
  );

  try{
    badge.textContent=
      u?.name
      ||u?.display_name
      ||new URL(sourceUrl).hostname
      ||'NAS';
  }catch{
    badge.textContent=
      u?.name
      ||u?.display_name
      ||'NAS';
  }

  if(!u||!u.ok){
    value.textContent='nicht erreichbar';
    sub.textContent='USV-Status nicht verfügbar';
    meta.textContent=
      u?.error
      ||sourceUrl;

    meter.style.width='0%';
    card.classList.add('ups-offline');
    return;
  }

  const charge=
    u.battery_charge_pct==null
      ? null
      : Number(u.battery_charge_pct);

  const runtime=
    u.runtime_remaining_min==null
      ? null
      : Number(u.runtime_remaining_min);

  const load=
    u.load_pct==null
      ? null
      : Number(u.load_pct);

  const source=upsSourceText(
    u.power_source
  );

  const battery=upsBatteryText(
    u.battery_status
  );

  const valueParts=[
    Number.isFinite(charge)
      ? `${Math.round(charge)} %`
      : null,
    Number.isFinite(runtime)
      ? `${Math.round(runtime)} min`
      : null
  ].filter(Boolean);

  value.textContent=
    valueParts.length
      ? valueParts.join(' · ')
      : source;

  const stateParts=[
    source!=='Unbekannt'
      ? source
      : null,
    u.type
      ? String(u.type).toUpperCase()
      : null,
    Number.isFinite(load)
      ? `Last ${n(load,0)} %`
      : null,
    u.battery_status
      ? `Akku ${battery}`
      : null
  ].filter(Boolean);

  sub.textContent=
    stateParts.join(' · ')
    ||'USV-Status verfügbar';

  if(Number.isFinite(charge)){
    const bounded=Math.max(
      0,
      Math.min(100,charge)
    );

    meter.style.width=
      `${bounded}%`;

    meter.style.background=
      bounded<=20
        ? '#ff6573'
        : bounded<=40
          ? '#e1ad42'
          : '#37d996';
  }else{
    meter.style.width='0%';
  }

  const model=upsModelText(u);
  const poll=upsPollTime(
    u.last_poll
  );

  meta.textContent=[
    model||null,
    poll
      ? `Abfrage ${poll} Uhr`
      : null,
    u.stale
      ? 'zwischengespeichert'
      : null,
    u.dry_run===true
      ? 'TESTMODUS'
      : null
  ].filter(Boolean).join(' · ')
  ||sourceUrl;

  /*
   * Klassen bleiben für eventuelle spätere Statuslogik bestehen,
   * beeinflussen wegen CSS oben aber NICHT den Kartenrahmen.
   */
  if(!u.reachable){
    card.classList.add('ups-offline');
  }else if(
    u.alarm
    ||u.triggered
    ||String(
      u.battery_status||''
    ).toLowerCase()==='low'
    ||String(
      u.battery_status||''
    ).toLowerCase()==='depleted'
    ||String(
      u.power_source||''
    ).toLowerCase()==='battery'
  ){
    card.classList.add('ups-danger');
  }else if(
    String(
      u.power_source||''
    ).toLowerCase()==='bypass'
    ||u.stale
  ){
    card.classList.add('ups-warning');
  }else{
    card.classList.add('ups-ok');
  }
};

/*
 * USV-Tab robust machen.
 * Ältere Kategorien-/Settings-Patches dürfen ihn nicht mehr auf
 * "Webseitenverwaltung" zurückbiegen.
 */
const upsUiFixPreviousSwitch=
  typeof switchUnifiedSettingsTab==='function'
    ? switchUnifiedSettingsTab
    : null;

async function forceUpsSettingsTab(){
  if(
    typeof settingsSessionCode!=='undefined'
    &&!settingsSessionCode
  ){
    /*
     * Falls ein alter Event-Handler den Settings-Hub bereits geöffnet hat,
     * diesen ausblenden, damit der Unlock-Dialog garantiert sichtbar ist.
     */
    $('settingsHubModal')?.classList.remove(
      'show'
    );

    if(
      typeof requestSettingsUnlock==='function'
    ){
      requestSettingsUnlock('ups');
      return;
    }
  }

  /*
   * Sofort sichtbar umschalten. Erst danach Daten laden.
   * Damit bleibt der Klick auch bei einem API-Fehler sichtbar wirksam.
   */
  if(
    typeof setUnifiedSettingsTab==='function'
  ){
    setUnifiedSettingsTab('ups');
  }else{
    [
      'settingsHubPanelLinks',
      'settingsHubPanelCategories',
      'settingsHubPanelDashboard'
    ].forEach(id=>{
      $(id)?.classList.remove(
        'active'
      );
    });

    $('settingsHubPanelUps')?.classList.add(
      'active'
    );
  }

  try{
    if(
      typeof loadUpsSettings==='function'
    ){
      await loadUpsSettings();
    }
  }catch(e){
    const msg=$('upsSettingsMsg');

    if(msg){
      msg.textContent=e.message;
      msg.className='msg err';
    }
  }
}

switchUnifiedSettingsTab=async function(tab){
  if(tab==='ups'){
    return await forceUpsSettingsTab();
  }

  if(upsUiFixPreviousSwitch){
    return await upsUiFixPreviousSwitch(
      tab
    );
  }
};

function installUpsTabClickFix(){
  const tab=$('settingsHubTabUps');

  if(!tab||tab.dataset.upsUiFix==='1'){
    return;
  }

  tab.dataset.upsUiFix='1';

  /* Inline-Handler entfernen und selbst zuverlässig übernehmen. */
  tab.removeAttribute('onclick');

  tab.addEventListener(
    'click',
    async event=>{
      event.preventDefault();
      event.stopPropagation();

      await forceUpsSettingsTab();
    },
    true
  );
}

setTimeout(()=>{
  ensureUpsTopState();
  installUpsTabClickFix();
},0);

'''

    init = re.search(
        r'\(async\(\)=>\{',
        html,
    )

    if not init:
        raise SystemExit(
            "FEHLER: JavaScript-Hauptinitialisierung nicht gefunden."
        )

    html = (
        html[:init.start()]
        + js
        + "\n"
        + html[init.start():]
    )

required = [
    MARKER,
    "#upsCard.card.ups-ok",
    "USV Netz",
    "USV Batterie",
    "forceUpsSettingsTab",
    "installUpsTabClickFix",
    "Abfrage ${poll} Uhr",
    "Last ${n(load,0)} %",
    "replace(\n        /^Back-UPS",
]

for needle in required:
    if needle not in html:
        raise SystemExit(
            f"FEHLER: Prüfung fehlgeschlagen: {needle}"
        )

temp = path.with_suffix(
    ".html.ups-ui-v3"
)

temp.write_text(
    html,
    encoding="utf-8",
)

temp.replace(path)

print("[OK] USV-Reiter repariert.")
print("[OK] Kartenrahmen auf Standardrahmen erzwungen.")
print("[OK] USV Netz/Batterie neben LIVE eingebaut.")
print("[OK] Status- und Modelltexte gekürzt.")
PY

chmod 644 "$INDEX"
chown root:root "$INDEX"

echo
echo "===== SYNTAX ====="

if command -v node >/dev/null 2>&1; then
    python3 - "$INDEX" /tmp/pve-ups-ui-v3.js <<'PY'
from pathlib import Path
import re
import sys

html = Path(sys.argv[1]).read_text(
    encoding="utf-8"
)

scripts = re.findall(
    r"<script[^>]*>(.*?)</script>",
    html,
    re.S | re.I,
)

Path(sys.argv[2]).write_text(
    "\n".join(scripts),
    encoding="utf-8",
)
PY

    node --check /tmp/pve-ups-ui-v3.js
    rm -f /tmp/pve-ups-ui-v3.js
    echo "[OK] JavaScript"
else
    echo "[INFO] Node nicht vorhanden; JS-Prüfung übersprungen."
fi

echo
echo "===== DIENSTE ====="

systemctl restart pve-sensor-web.service
systemctl restart nginx

sleep 3

systemctl is-active --quiet pve-sensor-web.service
systemctl is-active --quiet nginx

curl -m 5 -fsS \
    http://127.0.0.1:9105/api/current \
    >/dev/null

curl -m 8 -fsS \
    http://127.0.0.1:9105/api/ups \
    >/dev/null

echo "[OK] Dashboard + USV API"

echo
echo "============================================================"
echo " FERTIG"
echo "============================================================"
echo
echo "Browser:"
echo "  STRG + F5"
echo
echo "Erwartet:"
echo "  LIVE | USV Netz"
echo "  oder"
echo "  LIVE | USV Batterie"
echo
echo "USV-Karte:"
echo "  Netz · NUT · Last 16 % · Akku normal"
echo "  APC RS 900G · Abfrage 22:23 Uhr"
echo
echo "Backup:"
echo "  $BACKUP"
echo
echo "Log:"
echo "  $LOGFILE"
echo "============================================================"
__PVE_V56_UPS_UI_FIX_V3__
    chmod 700 "$patch"
    bash "$patch"
    rm -f "$patch"
}


# =============================================================================
# DASHBOARD SETTINGS LOGIN / USV FIX V4
# =============================================================================
install_dashboard_settings_remember_v57() {
    header "DASHBOARD · SETTINGS LOGIN / USV"
    local patch="/tmp/pve-dashboard-settings-v57.$$"
    cat > "$patch" <<'__PVE_V57_SETTINGS_REMEMBER_USV_V4__'
#!/usr/bin/env bash
set -Eeuo pipefail

STAMP="$(date +%d-%m-%H-%M)"
LOGFILE="/root/diagnose/diagnose-dashboard-settings-login-usv-${STAMP}.txt"

if [[ -e "$LOGFILE" ]]; then
    N=2
    while [[ -e "/root/diagnose/diagnose-dashboard-settings-login-usv-${STAMP}-${N}.txt" ]]; do
        N=$((N + 1))
    done
    LOGFILE="/root/diagnose/diagnose-dashboard-settings-login-usv-${STAMP}-${N}.txt"
fi

exec > >(tee -a "$LOGFILE") 2>&1

[[ ${EUID:-$(id -u)} -eq 0 ]] || {
    echo "FEHLER: Bitte als root ausführen."
    exit 1
}

APP="/opt/nodezero/dashboard/app.py"
INDEX="/opt/nodezero/dashboard/static/index.html"
SESSION_KEY="/etc/pve-sensor-dashboard/settings-session.key"
BACKUP="/root/backups/pve-dashboard-settings-login-usv-backup-$(date +%Y%m%d-%H%M%S)"

[[ -f "$APP" ]] || {
    echo "FEHLER: $APP fehlt."
    exit 1
}

[[ -f "$INDEX" ]] || {
    echo "FEHLER: $INDEX fehlt."
    exit 1
}

grep -Fq "PVE_UPS_SETTINGS_V2" "$APP" || {
    echo "FEHLER: USV-Einstellungsbackend V2 fehlt."
    exit 1
}

grep -Fq 'id="settingsHubTabUps"' "$INDEX" || {
    echo "FEHLER: USV-Reiter fehlt."
    exit 1
}

echo "============================================================"
echo " DASHBOARD - SETTINGS LOGIN + USV FIX V4"
echo "============================================================"
echo
echo "Korrekturen:"
echo "  - USV-Reiter wird direkt und unabhängig vom alten Tab-Code geöffnet"
echo "  - Anmeldung kann 30 Tage in diesem Browser gemerkt werden"
echo "  - Passwort selbst wird NICHT im Browser gespeichert"
echo "  - Browser speichert nur einen signierten Sitzungsschlüssel"
echo "  - Abmelden-Button in den Einstellungen"
echo "  - NUT-Wirkleistung in Watt anzeigen, wenn vorhanden"
echo "  - bei fehlender Wirkleistung Schätzung aus Last% + Nennleistung"
echo
echo "Log:"
echo "  $LOGFILE"
echo

mkdir -p "$BACKUP" "$(dirname "$SESSION_KEY")"

cp -a "$APP" "$BACKUP/app.py"
cp -a "$INDEX" "$BACKUP/index.html"
[[ -f "$SESSION_KEY" ]] && cp -a "$SESSION_KEY" "$BACKUP/settings-session.key"

rollback() {
    echo
    echo "============================================================"
    echo " AUTOMATISCHES ROLLBACK"
    echo "============================================================"

    cp -a "$BACKUP/app.py" "$APP"
    cp -a "$BACKUP/index.html" "$INDEX"

    if [[ -f "$BACKUP/settings-session.key" ]]; then
        cp -a "$BACKUP/settings-session.key" "$SESSION_KEY"
    fi

    chown root:root "$APP" "$INDEX"
    chmod 644 "$APP" "$INDEX"

    systemctl restart pve-sensor-web.service || true
    systemctl restart nginx || true

    echo "Vorheriger Stand wiederhergestellt."
    echo "Backup: $BACKUP"
}

trap 'echo "FEHLER in Zeile $LINENO"; rollback' ERR

echo
echo "===== 1. SESSION-SCHLÜSSEL ====="

if [[ ! -s "$SESSION_KEY" ]]; then
    umask 0077
    openssl rand -hex 32 > "$SESSION_KEY"
fi

chown root:pve-monitor "$SESSION_KEY"
chmod 640 "$SESSION_KEY"

echo "[OK] $SESSION_KEY"

echo
echo "===== 2. BACKEND ====="

python3 - "$APP" <<'PY'
from pathlib import Path
import py_compile
import re
import sys

path = Path(sys.argv[1])
app = path.read_text(encoding="utf-8")

MARKER = "# PVE_SETTINGS_REMEMBER_V4"

if MARKER not in app:
    # ------------------------------------------------------------------
    # Imports
    # ------------------------------------------------------------------
    import_anchor = "import os\n"

    imports = (
        "import base64\n"
        "import hashlib\n"
        "import hmac\n"
    )

    if "import hmac\n" not in app:
        if import_anchor not in app:
            raise SystemExit(
                "FEHLER: Import-Anker in app.py fehlt."
            )

        app = app.replace(
            import_anchor,
            imports + import_anchor,
            1,
        )

    # ------------------------------------------------------------------
    # Session helpers directly after verify_code()
    # ------------------------------------------------------------------
    verify_anchor = re.search(
        r'def verify_code\(code\):\n'
        r'.*?'
        r'\n\n(?=def rate_state\(ip\):)',
        app,
        re.S,
    )

    if not verify_anchor:
        raise SystemExit(
            "FEHLER: verify_code()-Block nicht gefunden."
        )

    helpers = r'''

# PVE_SETTINGS_REMEMBER_V4
SETTINGS_SESSION_SECRET_FILE = Path(
    "/etc/pve-sensor-dashboard/settings-session.key"
)
SETTINGS_SESSION_TTL = 30 * 86400


def _settings_session_secret_v4():
    try:
        value = SETTINGS_SESSION_SECRET_FILE.read_text(
            encoding="utf-8"
        ).strip()

        if value:
            return value.encode("utf-8")
    except Exception:
        pass

    raise RuntimeError(
        "Settings-Session-Schlüssel fehlt."
    )


def _settings_control_fingerprint_v4():
    try:
        stored = CONTROL_HASH_FILE.read_text(
            encoding="utf-8"
        ).strip()
    except Exception:
        stored = ""

    return hashlib.sha256(
        stored.encode("utf-8")
    ).hexdigest()[:20]


def _settings_user_agent_hash_v4():
    user_agent = str(
        request.headers.get("User-Agent")
        or ""
    )

    return hashlib.sha256(
        user_agent.encode("utf-8")
    ).hexdigest()[:20]


def _settings_b64e_v4(value):
    return base64.urlsafe_b64encode(
        value
    ).decode("ascii").rstrip("=")


def _settings_b64d_v4(value):
    padding = "=" * (
        (-len(value)) % 4
    )

    return base64.urlsafe_b64decode(
        value + padding
    )


def issue_settings_session_v4():
    expires = int(
        time.time()
        + SETTINGS_SESSION_TTL
    )

    payload = "|".join([
        "v1",
        str(expires),
        _settings_user_agent_hash_v4(),
        _settings_control_fingerprint_v4(),
    ]).encode("utf-8")

    signature = hmac.new(
        _settings_session_secret_v4(),
        payload,
        hashlib.sha256,
    ).digest()

    token = (
        "sess."
        + _settings_b64e_v4(payload)
        + "."
        + _settings_b64e_v4(signature)
    )

    return token, expires


def verify_settings_session_v4(token):
    token = str(
        token or ""
    ).strip()

    if not token.startswith("sess."):
        return False

    try:
        _prefix, payload_text, signature_text = token.split(
            ".",
            2,
        )

        payload = _settings_b64d_v4(
            payload_text
        )

        supplied_signature = _settings_b64d_v4(
            signature_text
        )

        expected_signature = hmac.new(
            _settings_session_secret_v4(),
            payload,
            hashlib.sha256,
        ).digest()

        if not hmac.compare_digest(
            supplied_signature,
            expected_signature,
        ):
            return False

        decoded = payload.decode(
            "utf-8"
        )

        version, expires, ua_hash, control_hash = decoded.split(
            "|",
            3,
        )

        if version != "v1":
            return False

        if int(expires) < int(time.time()):
            return False

        if not hmac.compare_digest(
            ua_hash,
            _settings_user_agent_hash_v4(),
        ):
            return False

        if not hmac.compare_digest(
            control_hash,
            _settings_control_fingerprint_v4(),
        ):
            return False

        return True

    except Exception:
        return False
'''

    app = (
        app[:verify_anchor.end()]
        + helpers
        + app[verify_anchor.end():]
    )

    # ------------------------------------------------------------------
    # Generic protected routes accept signed session token in "code".
    # ------------------------------------------------------------------
    verify_request = re.search(
        r'def verify_control_request\(payload\):\n'
        r'.*?'
        r'\n\n(?=@app\.get\("/api/links"\))',
        app,
        re.S,
    )

    if not verify_request:
        raise SystemExit(
            "FEHLER: verify_control_request() nicht gefunden."
        )

    verify_request_new = r'''def verify_control_request(payload):
    ip = client_ip()
    locked, remaining = rate_state(ip)

    if locked:
        return False, (
            jsonify({
                "error": (
                    "Zu viele Fehlversuche. "
                    f"Noch {remaining} Sekunden gesperrt."
                )
            }),
            429,
        )

    credential = str(
        (payload or {}).get("session_token")
        or (payload or {}).get("code")
        or ""
    )

    # Ein signierter Browser-Session-Key ersetzt die erneute Passworteingabe.
    if verify_settings_session_v4(
        credential
    ):
        clear_failures(ip)
        return True, None

    if not verify_code(
        credential
    ):
        fails, locked_until = record_failure(ip)

        if locked_until > time.time():
            return False, (
                jsonify({
                    "error": (
                        "Zu viele Fehlversuche. "
                        "Diese IP ist 5 Minuten gesperrt."
                    )
                }),
                429,
            )

        return False, (
            jsonify({
                "error": (
                    "Steuer-Code ist falsch oder "
                    "die gespeicherte Anmeldung ist abgelaufen. "
                    f"Fehlversuch {fails}/{MAX_FAILS}."
                )
            }),
            403,
        )

    clear_failures(ip)
    return True, None
'''

    app = (
        app[:verify_request.start()]
        + verify_request_new
        + app[verify_request.end():]
    )

    # ------------------------------------------------------------------
    # UPS-specific auth helper delegates to generic session-aware verifier.
    # ------------------------------------------------------------------
    ups_auth = re.search(
        r'def _dashboard_code_check_v2\(payload\):\n'
        r'.*?'
        r'\n\n(?=def _nut_unquote_v2\(value\):)',
        app,
        re.S,
    )

    if not ups_auth:
        raise SystemExit(
            "FEHLER: _dashboard_code_check_v2() nicht gefunden."
        )

    ups_auth_new = r'''def _dashboard_code_check_v2(payload):
    return verify_control_request(
        payload
    )
'''

    app = (
        app[:ups_auth.start()]
        + ups_auth_new
        + app[ups_auth.end():]
    )

    # ------------------------------------------------------------------
    # Unlock endpoint returns a signed session key.
    # ------------------------------------------------------------------
    unlock_route = re.search(
        r'@app\.post\("/api/settings/unlock"\)\n'
        r'def dashboard_settings_unlock_v2\(\):\n'
        r'.*?'
        r'\n\n(?=@app\.post\("/api/ups/settings/read"\))',
        app,
        re.S,
    )

    if not unlock_route:
        raise SystemExit(
            "FEHLER: /api/settings/unlock nicht gefunden."
        )

    unlock_new = r'''@app.post("/api/settings/unlock")
def dashboard_settings_unlock_v2():
    payload = request.get_json(
        silent=True
    ) or {}

    # Bereits vorhandenen Session-Key ebenfalls akzeptieren.
    existing = str(
        payload.get("session_token")
        or payload.get("code")
        or ""
    )

    if verify_settings_session_v4(
        existing
    ):
        return jsonify({
            "ok": True,
            "session_token": existing,
            "expires_in": SETTINGS_SESSION_TTL,
        })

    allowed, error = verify_control_request(
        payload
    )

    if not allowed:
        return error

    token, expires = issue_settings_session_v4()

    return jsonify({
        "ok": True,
        "session_token": token,
        "expires_at": expires,
        "expires_in": SETTINGS_SESSION_TTL,
    })


@app.post("/api/settings/session/check")
def dashboard_settings_session_check_v4():
    payload = request.get_json(
        silent=True
    ) or {}

    token = str(
        payload.get("session_token")
        or payload.get("code")
        or ""
    )

    if not verify_settings_session_v4(
        token
    ):
        return jsonify({
            "ok": False,
            "error": "Gespeicherte Anmeldung ist abgelaufen.",
        }), 401

    return jsonify({
        "ok": True,
        "expires_in": SETTINGS_SESSION_TTL,
    })
'''

    app = (
        app[:unlock_route.start()]
        + unlock_new
        + app[unlock_route.end():]
    )

    # ------------------------------------------------------------------
    # NUT power enrichment:
    # ups.realpower = true output/load watts.
    # If unavailable: estimate from load % and ups.realpower.nominal.
    # This is NOT UPS self-consumption.
    # ------------------------------------------------------------------
    nut_wrapper_anchor = '\ndef _pveups_status_v2(settings):\n'

    if nut_wrapper_anchor not in app:
        raise SystemExit(
            "FEHLER: _pveups_status_v2()-Anker fehlt."
        )

    nut_wrapper = r'''

_nut_status_normalized_v2_base = _nut_status_normalized_v2


def _nut_status_normalized_v2(settings):
    result = _nut_status_normalized_v2_base(
        settings
    )

    raw = result.get("raw_values") or {}

    nominal_realpower = _nut_float_v2(
        raw,
        "ups.realpower.nominal",
    )

    nominal_va = _nut_float_v2(
        raw,
        "ups.power.nominal",
    )

    result["nominal_power_w"] = nominal_realpower
    result["nominal_power_va"] = nominal_va
    result["power_estimated"] = False

    power_w = result.get("power_w")
    load_pct = result.get("load_pct")

    if (
        power_w is None
        and nominal_realpower is not None
        and load_pct is not None
    ):
        result["power_w"] = (
            nominal_realpower
            * float(load_pct)
            / 100.0
        )

        result["power_estimated"] = True

    return result
'''

    app = app.replace(
        nut_wrapper_anchor,
        nut_wrapper + nut_wrapper_anchor,
        1,
    )

temp = path.with_suffix(
    ".py.settings-remember-v4"
)

temp.write_text(
    app,
    encoding="utf-8",
)

py_compile.compile(
    str(temp),
    doraise=True,
)

temp.replace(path)

print("[OK] 30-Tage Browser-Session backendseitig eingebaut.")
print("[OK] bestehende geschützte APIs akzeptieren Session-Key.")
print("[OK] NUT-Wirkleistung / Schätzung ergänzt.")
PY

chmod 644 "$APP"
chown root:root "$APP"

echo
echo "===== 3. FRONTEND ====="

python3 - "$INDEX" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
html = path.read_text(encoding="utf-8")

MARKER = "PVE_SETTINGS_REMEMBER_UI_V4"

if MARKER not in html:
    # ------------------------------------------------------------------
    # Remember checkbox into unlock dialog.
    # ------------------------------------------------------------------
    unlock_msg = '<div id="settingsUnlockMsg" class="msg"></div>'

    remember_html = r'''
    <div class="settingsRememberRow">
      <input
        id="settingsRememberLogin"
        type="checkbox"
        checked
      >
      <label for="settingsRememberLogin">
        Anmeldung auf diesem Browser 30 Tage merken
      </label>
    </div>
'''

    if unlock_msg not in html:
        raise SystemExit(
            "FEHLER: Unlock-Dialog wurde nicht gefunden."
        )

    html = html.replace(
        unlock_msg,
        remember_html + "\n" + unlock_msg,
        1,
    )

    css = r'''
/* PVE_SETTINGS_REMEMBER_UI_V4 */
.settingsRememberRow{
  display:flex;
  align-items:center;
  gap:8px;
  margin:11px 0 5px;
  color:#a9bed8;
  font-size:11px;
}
.settingsRememberRow input{
  width:auto;
  margin:0;
}
.settingsLoginState{
  display:flex;
  align-items:center;
  gap:8px;
  margin-left:auto;
}
.settingsLoginBadge{
  color:#9cb4cf;
  font-size:10px;
  white-space:nowrap;
}
.settingsLogoutButton{
  min-height:29px!important;
  padding:5px 9px!important;
  font-size:10px!important;
}

/* USV-Panel wird beim Aktivieren explizit sichtbar gemacht. */
#settingsHubPanelUps.upsPanelForced{
  display:block!important;
  visibility:visible!important;
  opacity:1!important;
}
'''

    if "</style>" not in html:
        raise SystemExit(
            "FEHLER: </style> fehlt."
        )

    html = html.replace(
        "</style>",
        css + "\n</style>",
        1,
    )

    js = r'''
/* PVE_SETTINGS_REMEMBER_UI_V4 */

const SETTINGS_REMEMBER_KEY=
  'pveDashboardSettingsSessionV1';

let settingsSessionValidated=false;

function storedSettingsSession(){
  try{
    const token=localStorage.getItem(
      SETTINGS_REMEMBER_KEY
    );

    return token&&token.startsWith('sess.')
      ? token
      : '';
  }catch{
    return '';
  }
}

function rememberSettingsSession(token){
  try{
    localStorage.setItem(
      SETTINGS_REMEMBER_KEY,
      token
    );
  }catch{}
}

function forgetSettingsSession(){
  try{
    localStorage.removeItem(
      SETTINGS_REMEMBER_KEY
    );
  }catch{}
}

function ensureSettingsLoginState(){
  const tabs=document.querySelector(
    '#settingsHubModal .settingsHubTabs'
  );

  if(!tabs){
    return;
  }

  let state=$('settingsLoginState');

  if(!state){
    state=document.createElement('div');
    state.id='settingsLoginState';
    state.className='settingsLoginState';

    const badge=document.createElement('span');
    badge.id='settingsLoginBadge';
    badge.className='settingsLoginBadge';
    badge.textContent='Einstellungen entsperrt';

    const logout=document.createElement('button');
    logout.type='button';
    logout.className='settingsLogoutButton';
    logout.textContent='Abmelden';
    logout.addEventListener(
      'click',
      logoutRememberedSettings
    );

    state.append(
      badge,
      logout
    );

    tabs.appendChild(state);
  }
}

function logoutRememberedSettings(){
  forgetSettingsSession();

  settingsSessionCode='';
  settingsSessionValidated=false;

  [
    'linkCode',
    'categoryCode',
    'categoryAssignCode',
    'settingsCode'
  ].forEach(id=>{
    const input=$(id);

    if(input){
      input.value='';
    }
  });

  $('settingsHubModal')?.classList.remove(
    'show'
  );

  requestSettingsUnlock('links');
}

async function validateStoredSettingsSession(){
  const token=
    settingsSessionCode
    ||storedSettingsSession();

  if(!token){
    return false;
  }

  try{
    await getJSON(
      '/api/settings/session/check',
      {
        method:'POST',
        headers:{
          'Content-Type':'application/json'
        },
        body:JSON.stringify({
          session_token:token
        })
      }
    );

    settingsSessionCode=token;
    settingsSessionValidated=true;

    syncSettingsSessionCodeFields();
    hideRepeatedSecurityCodeFields();

    return true;

  }catch{
    forgetSettingsSession();
    settingsSessionCode='';
    settingsSessionValidated=false;
    return false;
  }
}

/*
 * Passwort-Login überschreiben:
 * Passwort geht einmal an den Server.
 * Im Browser bleibt danach nur der signierte Session-Key.
 */
unlockUnifiedSettings=async function(){
  const code=$('settingsUnlockCode').value;
  const button=$('settingsUnlockButton');

  if(code.length<6){
    $('settingsUnlockMsg').textContent=
      'Bitte den Dashboard-Sicherheitscode eingeben.';

    $('settingsUnlockMsg').className=
      'msg err';

    return;
  }

  button.disabled=true;

  try{
    const data=await getJSON(
      '/api/settings/unlock',
      {
        method:'POST',
        headers:{
          'Content-Type':'application/json'
        },
        body:JSON.stringify({
          code
        })
      }
    );

    const token=String(
      data.session_token||''
    );

    if(!token.startsWith('sess.')){
      throw new Error(
        'Der Server hat keinen gültigen Sitzungsschlüssel geliefert.'
      );
    }

    settingsSessionCode=token;
    settingsSessionValidated=true;

    if(
      $('settingsRememberLogin')?.checked
    ){
      rememberSettingsSession(
        token
      );
    }else{
      forgetSettingsSession();
    }

    $('settingsUnlockCode').value='';

    closeSettingsUnlock();

    syncSettingsSessionCodeFields();
    hideRepeatedSecurityCodeFields();

    await openSettingsPanelV4(
      settingsPendingTab||'links'
    );

  }catch(e){
    $('settingsUnlockMsg').textContent=
      e.message;

    $('settingsUnlockMsg').className=
      'msg err';

    $('settingsUnlockCode').select();

  }finally{
    button.disabled=false;
  }
};

/*
 * Panel-Umschaltung bewusst ohne die historisch gewachsenen Wrapper.
 * Dadurch kann USV nicht mehr von einem alten Tab-Handler zurückgesetzt werden.
 */
function activateSettingsPanelV4(tab){
  const wanted=
    ['links','categories','ups','dashboard'].includes(tab)
      ? tab
      : 'links';

  const mapping={
    links:[
      'settingsHubTabLinks',
      'settingsHubPanelLinks'
    ],
    categories:[
      'settingsHubTabCategories',
      'settingsHubPanelCategories'
    ],
    ups:[
      'settingsHubTabUps',
      'settingsHubPanelUps'
    ],
    dashboard:[
      'settingsHubTabDashboard',
      'settingsHubPanelDashboard'
    ]
  };

  Object.entries(
    mapping
  ).forEach(
    ([name,[tabId,panelId]])=>{
      const active=
        name===wanted;

      const tabEl=$(tabId);
      const panelEl=$(panelId);

      if(tabEl){
        tabEl.classList.toggle(
          'active',
          active
        );

        tabEl.setAttribute(
          'aria-selected',
          String(active)
        );
      }

      if(panelEl){
        panelEl.classList.toggle(
          'active',
          active
        );

        panelEl.classList.toggle(
          'upsPanelForced',
          active&&name==='ups'
        );

        /*
         * display explizit setzen:
         * ältere CSS-/JS-Versionen können das USV-Panel so nicht verstecken.
         */
        panelEl.style.display=
          active
            ? 'block'
            : 'none';

        panelEl.style.visibility=
          active
            ? 'visible'
            : 'hidden';
      }
    }
  );
}

async function prepareSettingsPanelV4(tab){
  if(tab==='ups'){
    if(
      typeof loadUpsSettings==='function'
    ){
      await loadUpsSettings();
    }

    return;
  }

  /*
   * Für die drei bestehenden Bereiche den letzten funktionierenden
   * Prepare-Handler weiterverwenden, aber die Sichtbarkeit danach selbst setzen.
   */
  try{
    if(
      typeof upsSettingsLegacyPrepareUnifiedSettingsTab==='function'
    ){
      await upsSettingsLegacyPrepareUnifiedSettingsTab(
        tab
      );
    }
  }catch(e){
    console.warn(
      'Settings prepare:',
      e
    );
  }
}

async function openSettingsPanelV4(tab='links'){
  const wanted=
    ['links','categories','ups','dashboard'].includes(tab)
      ? tab
      : 'links';

  closeNav();

  if(
    typeof initializeUnifiedSettings==='function'
  ){
    initializeUnifiedSettings();
  }

  $('settingsHubModal')?.classList.add(
    'show'
  );

  activateSettingsPanelV4(
    wanted
  );

  syncSettingsSessionCodeFields();
  hideRepeatedSecurityCodeFields();
  ensureSettingsLoginState();

  try{
    await prepareSettingsPanelV4(
      wanted
    );
  }finally{
    /*
     * Nach async-Aufrufen nochmals erzwingen.
     * Falls alter Code auf Links zurückgestellt hat, wird das hier korrigiert.
     */
    activateSettingsPanelV4(
      wanted
    );
  }
}

requestSettingsUnlock=async function(tab='links'){
  closeNav();

  settingsPendingTab=
    ['links','categories','ups','dashboard'].includes(tab)
      ? tab
      : 'links';

  if(
    await validateStoredSettingsSession()
  ){
    return await openSettingsPanelV4(
      settingsPendingTab
    );
  }

  $('settingsUnlockMsg').textContent='';
  $('settingsUnlockMsg').className='msg';
  $('settingsUnlockCode').value='';

  $('settingsUnlockModal').classList.add(
    'show'
  );

  setTimeout(
    ()=>$('settingsUnlockCode').focus(),
    80
  );
};

openUnifiedSettings=async function(tab='links'){
  if(
    !await validateStoredSettingsSession()
  ){
    return requestSettingsUnlock(
      tab
    );
  }

  return openSettingsPanelV4(
    tab
  );
};

switchUnifiedSettingsTab=async function(tab){
  if(
    !await validateStoredSettingsSession()
  ){
    return requestSettingsUnlock(
      tab
    );
  }

  return openSettingsPanelV4(
    tab
  );
};

/* Schließen meldet NICHT mehr ab. */
closeUnifiedSettings=function(){
  $('settingsHubModal')?.classList.remove(
    'show'
  );

  $('linksModal')?.classList.remove(
    'show'
  );

  $('settingsModal')?.classList.remove(
    'show'
  );
};

openLinkManager=function(){
  return openUnifiedSettings('links');
};

openDashboardSettings=function(){
  return openUnifiedSettings('dashboard');
};

closeLinkManager=function(){
  closeUnifiedSettings();
};

closeDashboardSettings=function(){
  closeUnifiedSettings();
};

/*
 * Alten USV-Button vollständig ersetzen.
 * cloneNode entfernt auch Listener, die ältere Fixes hinzugefügt hatten.
 */
function rebuildUpsTabV4(){
  const oldTab=$('settingsHubTabUps');

  if(!oldTab){
    return;
  }

  const tab=oldTab.cloneNode(
    true
  );

  tab.removeAttribute(
    'onclick'
  );

  oldTab.replaceWith(
    tab
  );

  tab.addEventListener(
    'click',
    async event=>{
      event.preventDefault();
      event.stopImmediatePropagation();

      if(
        !await validateStoredSettingsSession()
      ){
        return requestSettingsUnlock(
          'ups'
        );
      }

      await openSettingsPanelV4(
        'ups'
      );
    },
    true
  );
}

/* Leistungsanzeige im USV-Kärtchen ergänzen. */
const renderUpsV4Previous=
  typeof renderUps==='function'
    ? renderUps
    : null;

if(renderUpsV4Previous){
  renderUps=function(u){
    renderUpsV4Previous(u);

    if(!u||!u.ok){
      return;
    }

    const sub=$('upsSub');

    if(!sub){
      return;
    }

    const power=
      u.power_w==null
        ? null
        : Number(u.power_w);

    if(!Number.isFinite(power)){
      return;
    }

    const powerText=
      u.power_estimated
        ? `≈ ${Math.round(power)} W`
        : `${Math.round(power)} W`;

    const parts=String(
      sub.textContent||''
    ).split(' · ').filter(Boolean);

    /*
     * Vor "Akku ..." einsetzen.
     */
    const batteryIndex=parts.findIndex(
      value=>/^Akku\s/i.test(value)
    );

    if(
      !parts.includes(powerText)
    ){
      if(batteryIndex>=0){
        parts.splice(
          batteryIndex,
          0,
          powerText
        );
      }else{
        parts.push(
          powerText
        );
      }
    }

    sub.textContent=
      parts.join(' · ');
  };
}

const renderUpsSettingsValuesV4Previous=
  typeof renderUpsSettingsValues==='function'
    ? renderUpsSettingsValues
    : null;

if(renderUpsSettingsValuesV4Previous){
  renderUpsSettingsValues=function(data){
    renderUpsSettingsValuesV4Previous(
      data
    );

    if(
      data?.power_estimated
    ){
      document.querySelectorAll(
        '#upsSettingsValues .upsValueItem'
      ).forEach(item=>{
        const label=item.querySelector(
          '.upsValueLabel'
        );

        if(
          label
          &&label.textContent==='Wirkleistung'
        ){
          label.textContent=
            'Leistung geschätzt';
        }
      });
    }
  };
}

setTimeout(async()=>{
  rebuildUpsTabV4();

  const token=storedSettingsSession();

  if(token){
    settingsSessionCode=token;
  }
},0);

'''

    init = re.search(
        r'\(async\(\)=>\{',
        html,
    )

    if not init:
        raise SystemExit(
            "FEHLER: JS-Hauptinitialisierung fehlt."
        )

    html = (
        html[:init.start()]
        + js
        + "\n"
        + html[init.start():]
    )

required = [
    MARKER,
    'id="settingsRememberLogin"',
    "SETTINGS_REMEMBER_KEY",
    "validateStoredSettingsSession",
    "activateSettingsPanelV4",
    "rebuildUpsTabV4",
    "Abmelden",
    "30 Tage",
    "≈ ${Math.round(power)} W",
]

for needle in required:
    if needle not in html:
        raise SystemExit(
            f"FEHLER: Frontend-Prüfung fehlgeschlagen: {needle}"
        )

temp = path.with_suffix(
    ".html.settings-remember-v4"
)

temp.write_text(
    html,
    encoding="utf-8",
)

temp.replace(path)

print("[OK] USV-Reiter hart auf eigenes Panel verdrahtet.")
print("[OK] Browser-Login 30 Tage / Abmelden.")
print("[OK] Watt-Anzeige im USV-Kärtchen ergänzt.")
PY

chmod 644 "$INDEX"
chown root:root "$INDEX"

echo
echo "===== 4. SYNTAX ====="

python3 -m py_compile "$APP"
echo "[OK] app.py"

if command -v node >/dev/null 2>&1; then
    python3 - "$INDEX" /tmp/pve-settings-v4.js <<'PY'
from pathlib import Path
import re
import sys

html = Path(sys.argv[1]).read_text(
    encoding="utf-8"
)

scripts = re.findall(
    r"<script[^>]*>(.*?)</script>",
    html,
    re.S | re.I,
)

Path(sys.argv[2]).write_text(
    "\n".join(scripts),
    encoding="utf-8",
)
PY

    node --check /tmp/pve-settings-v4.js
    rm -f /tmp/pve-settings-v4.js

    echo "[OK] JavaScript"
else
    echo "[INFO] Node nicht vorhanden; JS-Prüfung übersprungen."
fi

echo
echo "===== 5. DIENSTE ====="

systemctl restart pve-sensor-web.service
systemctl restart nginx

sleep 4

systemctl is-active --quiet pve-sensor-web.service
systemctl is-active --quiet nginx

echo "[OK] pve-sensor-web.service"
echo "[OK] nginx"

echo
echo "===== 6. API ====="

curl -m 5 -fsS \
    http://127.0.0.1:9105/api/current \
    >/dev/null

UPS="$(
    curl -m 8 -fsS \
        http://127.0.0.1:9105/api/ups
)"

echo "[OK] /api/current"
echo "[OK] /api/ups"

printf '%s' "$UPS" |
python3 - <<'PY'
import json
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    raise SystemExit

print()
print("USV-Leistungsdaten:")

for key in (
    "load_pct",
    "power_w",
    "power_estimated",
    "nominal_power_w",
    "power_va",
    "nominal_power_va",
):
    if key in data and data.get(key) is not None:
        print(f"  {key}: {data.get(key)}")
PY

trap - ERR

echo
echo "============================================================"
echo " FERTIG"
echo "============================================================"
echo
echo "WICHTIG:"
echo "  Browser einmal STRG + F5."
echo
echo "Danach:"
echo "  1. ⚙ Einstellungen öffnen"
echo "  2. Sicherheitscode EINMAL eingeben"
echo "  3. '30 Tage merken' aktiviert lassen"
echo "  4. danach USV anklicken"
echo
echo "Der Browser speichert NICHT das Passwort,"
echo "sondern nur einen signierten Sitzungsschlüssel."
echo
echo "USV-Leistung:"
echo "  - ups.realpower vorhanden -> echte Ausgangs-/Lastleistung in W"
echo "  - nur Last% + Nenn-W vorhanden -> ≈ geschätzte Leistung"
echo "  - das ist die Last der angeschlossenen Geräte,"
echo "    nicht zwingend der Eigenverbrauch der USV."
echo
echo "Backup:"
echo "  $BACKUP"
echo
echo "Log:"
echo "  $LOGFILE"
echo "============================================================"
__PVE_V57_SETTINGS_REMEMBER_USV_V4__
    chmod 700 "$patch"
    bash "$patch"
    rm -f "$patch"
}

# =============================================================================
# V71 · DASHBOARD LAYOUT-EDITOR
# =============================================================================

install_dashboard_layout_editor_v71() {
    header "DASHBOARD · KACHEL-LAYOUT"

    local patch="/tmp/pve-dashboard-layout-v71.$$"

    cat > "$patch" <<'__PVE_DASHBOARD_LAYOUT_V71__'
#!/usr/bin/env bash
set -Eeuo pipefail

STAMP="$(date +%d-%m-%H-%M)"
LOGFILE="/root/diagnose/diagnose-dashboard-layout-v71-${STAMP}.txt"

if [[ -e "$LOGFILE" ]]; then
    N=2
    while [[ -e "/root/diagnose/diagnose-dashboard-layout-v71-${STAMP}-${N}.txt" ]]; do
        N=$((N + 1))
    done
    LOGFILE="/root/diagnose/diagnose-dashboard-layout-v71-${STAMP}-${N}.txt"
fi

exec > >(tee -a "$LOGFILE") 2>&1

[[ ${EUID:-$(id -u)} -eq 0 ]] || {
    echo "FEHLER: Bitte als root ausführen."
    exit 1
}

APP="/opt/nodezero/dashboard/app.py"
INDEX="/opt/nodezero/dashboard/static/index.html"
WEB_DATA="/var/lib/pve-sensor-dashboard-web"
LAYOUT_FILE="${WEB_DATA}/dashboard-layout.json"
BACKUP="/root/backups/pve-dashboard-layout-v71-backup-$(date +%Y%m%d-%H%M%S)"

[[ -f "$APP" ]] || {
    echo "FEHLER: $APP fehlt."
    exit 1
}

[[ -f "$INDEX" ]] || {
    echo "FEHLER: $INDEX fehlt."
    exit 1
}

grep -Fq 'id="settingsHubTabUps"' "$INDEX" || {
    echo "FEHLER: USV-Reiter fehlt. Dashboard zuerst auf aktuellen Stand bringen."
    exit 1
}

grep -Fq 'PVE_SETTINGS_REMEMBER_UI_V4' "$INDEX" || {
    echo "FEHLER: aktueller Settings-Login fehlt."
    exit 1
}

mkdir -p "$BACKUP" "$WEB_DATA"

cp -a "$APP" "$BACKUP/app.py"
cp -a "$INDEX" "$BACKUP/index.html"
[[ -f "$LAYOUT_FILE" ]] && cp -a "$LAYOUT_FILE" "$BACKUP/dashboard-layout.json"

rollback() {
    echo
    echo "AUTOMATISCHES ROLLBACK"

    cp -a "$BACKUP/app.py" "$APP"
    cp -a "$BACKUP/index.html" "$INDEX"

    if [[ -f "$BACKUP/dashboard-layout.json" ]]; then
        cp -a "$BACKUP/dashboard-layout.json" "$LAYOUT_FILE"
    else
        rm -f "$LAYOUT_FILE"
    fi

    chown root:root "$APP" "$INDEX"
    chmod 644 "$APP" "$INDEX"

    systemctl restart pve-sensor-web.service || true
    systemctl reload nginx || true
}

trap 'echo "FEHLER in Zeile $LINENO"; rollback' ERR

echo "============================================================"
echo " DASHBOARD LAYOUT-EDITOR V71"
echo "============================================================"
echo
echo "  - Status-Kacheln verschieben"
echo "  - Diagramme verschieben"
echo "  - Kacheln/Diagramme ein- oder ausblenden"
echo "  - Drag & Drop direkt auf dem Dashboard"
echo "  - serverweit speichern"
echo

python3 - "$APP" <<'PY'
from pathlib import Path
import py_compile
import sys

path = Path(sys.argv[1])
app = path.read_text(encoding="utf-8")

MARKER = "# PVE_DASHBOARD_LAYOUT_API_V71"

if MARKER not in app:
    anchor = '\nif __name__ == "__main__":\n'

    if anchor not in app:
        raise SystemExit(
            "FEHLER: app.py Abschlussanker fehlt."
        )

    backend = r'''

# PVE_DASHBOARD_LAYOUT_API_V71
DASHBOARD_LAYOUT_FILE_V71 = Path(
    "/var/lib/pve-sensor-dashboard-web/dashboard-layout.json"
)

DASHBOARD_CARD_IDS_V71 = [
    "cpu",
    "ups",
    "ram",
    "disk",
    "network",
    "power",
    "guests",
    "pihole",
]

DASHBOARD_CHART_IDS_V71 = [
    "cpu-io",
    "temperature",
    "memory",
    "power",
    "network",
    "disk-io",
    "load",
    "cpu-gpu-temp",
]


def _dashboard_layout_default_v71():
    return {
        "version": 1,
        "cards": list(DASHBOARD_CARD_IDS_V71),
        "charts": list(DASHBOARD_CHART_IDS_V71),
        "hidden": [],
        "card_columns": 4,
        "chart_columns": 2,
    }


def _dashboard_layout_normalize_v71(data):
    default = _dashboard_layout_default_v71()

    if not isinstance(data, dict):
        data = {}

    def normalized_order(key, allowed):
        raw = data.get(key)

        if not isinstance(raw, list):
            raw = []

        out = []

        for item in raw:
            item = str(item)

            if item in allowed and item not in out:
                out.append(item)

        for item in allowed:
            if item not in out:
                out.append(item)

        return out

    cards = normalized_order(
        "cards",
        DASHBOARD_CARD_IDS_V71,
    )

    charts = normalized_order(
        "charts",
        DASHBOARD_CHART_IDS_V71,
    )

    allowed_hidden = {
        f"card:{item}"
        for item in DASHBOARD_CARD_IDS_V71
    } | {
        f"chart:{item}"
        for item in DASHBOARD_CHART_IDS_V71
    }

    hidden_raw = data.get("hidden")

    if not isinstance(hidden_raw, list):
        hidden_raw = []

    hidden = []

    for item in hidden_raw:
        item = str(item)

        if item in allowed_hidden and item not in hidden:
            hidden.append(item)

    try:
        card_columns = int(
            data.get(
                "card_columns",
                default["card_columns"],
            )
        )
    except Exception:
        card_columns = default["card_columns"]

    try:
        chart_columns = int(
            data.get(
                "chart_columns",
                default["chart_columns"],
            )
        )
    except Exception:
        chart_columns = default["chart_columns"]

    card_columns = max(1, min(4, card_columns))
    chart_columns = max(1, min(2, chart_columns))

    return {
        "version": 1,
        "cards": cards,
        "charts": charts,
        "hidden": hidden,
        "card_columns": card_columns,
        "chart_columns": chart_columns,
    }


def _dashboard_layout_read_v71():
    try:
        data = json.loads(
            DASHBOARD_LAYOUT_FILE_V71.read_text(
                encoding="utf-8"
            )
        )
    except Exception:
        data = {}

    return _dashboard_layout_normalize_v71(
        data
    )


def _dashboard_layout_write_v71(data):
    clean = _dashboard_layout_normalize_v71(
        data
    )

    DASHBOARD_LAYOUT_FILE_V71.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    temp = DASHBOARD_LAYOUT_FILE_V71.with_suffix(
        ".tmp"
    )

    temp.write_text(
        json.dumps(
            clean,
            ensure_ascii=False,
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )

    temp.chmod(0o640)
    temp.replace(DASHBOARD_LAYOUT_FILE_V71)

    return clean


@app.get("/api/dashboard/layout")
def dashboard_layout_read_v71():
    return jsonify({
        "ok": True,
        "layout": _dashboard_layout_read_v71(),
    })


@app.post("/api/dashboard/layout")
def dashboard_layout_save_v71():
    payload = request.get_json(
        silent=True
    ) or {}

    allowed, error = verify_control_request(
        payload
    )

    if not allowed:
        return error

    try:
        clean = _dashboard_layout_write_v71(
            payload.get("layout") or {}
        )

        return jsonify({
            "ok": True,
            "layout": clean,
        })
    except Exception as exc:
        return jsonify({
            "error": (
                "Dashboard-Layout konnte nicht "
                f"gespeichert werden: {exc}"
            )
        }), 500


@app.post("/api/dashboard/layout/reset")
def dashboard_layout_reset_v71():
    payload = request.get_json(
        silent=True
    ) or {}

    allowed, error = verify_control_request(
        payload
    )

    if not allowed:
        return error

    try:
        clean = _dashboard_layout_write_v71(
            _dashboard_layout_default_v71()
        )

        return jsonify({
            "ok": True,
            "layout": clean,
        })
    except Exception as exc:
        return jsonify({
            "error": (
                "Dashboard-Layout konnte nicht "
                f"zurückgesetzt werden: {exc}"
            )
        }), 500
'''

    app = app.replace(
        anchor,
        backend + anchor,
        1,
    )

temp = path.with_suffix(".py.layout-v71")
temp.write_text(app, encoding="utf-8")
py_compile.compile(str(temp), doraise=True)
temp.replace(path)

print("[OK] Dashboard Layout API eingebaut.")
PY

chown root:root "$APP"
chmod 644 "$APP"

python3 - "$INDEX" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
html = path.read_text(encoding="utf-8")

MARKER = "PVE_DASHBOARD_LAYOUT_UI_V71"

if MARKER not in html:
    dashboard_tab = re.search(
        r'<button\b'
        r'(?=[^>]*id=["\']settingsHubTabDashboard["\'])'
        r'.*?</button>',
        html,
        re.S | re.I,
    )

    if not dashboard_tab:
        raise SystemExit(
            "FEHLER: Dashboard-Tab wurde nicht gefunden."
        )

    layout_tab = r'''
      <button
        id="settingsHubTabLayout"
        class="settingsHubTab"
        type="button"
        role="tab"
        aria-selected="false"
        onclick="switchDashboardLayoutTabV71()"
      >Layout</button>
'''

    html = (
        html[:dashboard_tab.start()]
        + layout_tab
        + html[dashboard_tab.start():]
    )

    dashboard_panel = re.search(
        r'<div\b'
        r'(?=[^>]*id=["\']settingsHubPanelDashboard["\'])',
        html,
        re.I,
    )

    if not dashboard_panel:
        raise SystemExit(
            "FEHLER: Dashboard-Panel wurde nicht gefunden."
        )

    layout_panel = r'''
    <div
      id="settingsHubPanelLayout"
      class="settingsHubPanel"
      role="tabpanel"
    >
      <div class="layoutEditorV71">
        <div class="layoutEditorIntroV71">
          <strong>Dashboard-Layout</strong>
          <div>
            Kacheln und Diagramme können verschoben, ausgeblendet
            und wieder eingeblendet werden. Das Layout wird auf dem
            Server gespeichert und gilt damit für alle Browser.
          </div>
        </div>

        <div class="layoutColumnsV71">
          <label>
            Status-Kacheln pro Reihe
            <select id="layoutCardColumnsV71">
              <option value="1">1</option>
              <option value="2">2</option>
              <option value="3">3</option>
              <option value="4">4</option>
            </select>
          </label>

          <label>
            Diagramme pro Reihe
            <select id="layoutChartColumnsV71">
              <option value="1">1</option>
              <option value="2">2</option>
            </select>
          </label>
        </div>

        <div class="layoutEditorGridV71">
          <div>
            <h3>Status-Kacheln</h3>
            <div id="layoutCardsListV71" class="layoutListV71"></div>
          </div>

          <div>
            <h3>Diagramme</h3>
            <div id="layoutChartsListV71" class="layoutListV71"></div>
          </div>
        </div>

        <div class="layoutButtonsV71">
          <button
            type="button"
            onclick="startDashboardDirectEditV71()"
          >↕ Direkt auf dem Dashboard verschieben</button>

          <button
            type="button"
            onclick="resetDashboardLayoutV71()"
          >Standard wiederherstellen</button>

          <button
            id="layoutSaveButtonV71"
            type="button"
            onclick="saveDashboardLayoutV71()"
          >Speichern & anwenden</button>
        </div>

        <div id="layoutMessageV71" class="msg"></div>
      </div>
    </div>
'''

    html = (
        html[:dashboard_panel.start()]
        + layout_panel
        + html[dashboard_panel.start():]
    )

    body_end = html.rfind("</body>")

    if body_end < 0:
        raise SystemExit(
            "FEHLER: </body> fehlt."
        )

    toolbar = r'''
<div
  id="dashboardLayoutToolbarV71"
  class="dashboardLayoutToolbarV71"
>
  <strong>Layout bearbeiten</strong>
  <span>Kacheln mit der Maus ziehen.</span>

  <button
    type="button"
    onclick="cancelDashboardDirectEditV71()"
  >Abbrechen</button>

  <button
    type="button"
    onclick="finishDashboardDirectEditV71()"
  >Speichern</button>
</div>
'''

    html = (
        html[:body_end]
        + toolbar
        + "\n"
        + html[body_end:]
    )

    css = r'''
/* PVE_DASHBOARD_LAYOUT_UI_V71 */
.layoutEditorIntroV71{
  margin-bottom:14px;
  padding:12px;
  border:1px solid var(--line);
  border-radius:11px;
  background:#0b1420;
  color:#aebed3;
  font-size:12px;
  line-height:1.55;
}
.layoutEditorIntroV71 strong{
  display:block;
  margin-bottom:4px;
  color:#eef5ff;
}
.layoutColumnsV71{
  display:grid;
  grid-template-columns:1fr 1fr;
  gap:10px;
  margin-bottom:15px;
}
.layoutColumnsV71 label{
  color:#aebed3;
  font-size:11px;
  font-weight:700;
}
.layoutColumnsV71 select{
  width:100%;
  margin-top:5px;
  padding:10px;
  border:1px solid #334762;
  border-radius:9px;
  background:#09121e;
  color:#eef5ff;
}
.layoutEditorGridV71{
  display:grid;
  grid-template-columns:1fr 1fr;
  gap:14px;
}
.layoutEditorGridV71 h3{
  margin:0 0 8px;
  font-size:12px;
  color:#dbe9f8;
}
.layoutListV71{
  border:1px solid var(--line);
  border-radius:10px;
  overflow:hidden;
}
.layoutRowV71{
  display:grid;
  grid-template-columns:auto 1fr auto;
  align-items:center;
  gap:8px;
  padding:8px 9px;
  border-bottom:1px solid var(--line);
  background:#0b1420;
}
.layoutRowV71:last-child{
  border-bottom:0;
}
.layoutRowV71.dragging{
  opacity:.5;
}
.layoutRowV71 input{
  width:auto;
  margin:0;
}
.layoutRowNameV71{
  min-width:0;
  font-size:11px;
  font-weight:700;
}
.layoutRowActionsV71{
  display:flex;
  gap:4px;
}
.layoutRowActionsV71 button{
  padding:5px 8px;
  min-width:30px;
}
.layoutButtonsV71{
  display:flex;
  justify-content:flex-end;
  gap:7px;
  flex-wrap:wrap;
  margin-top:14px;
  padding-top:12px;
  border-top:1px solid var(--line);
}
.dashboardTileHiddenV71{
  display:none!important;
}
.dashboardLayoutEditingV71 .dashboardTileV71{
  cursor:grab;
  outline:2px dashed #64a7ff99!important;
  outline-offset:-4px;
  user-select:none;
}
.dashboardLayoutEditingV71 .dashboardTileV71:active{
  cursor:grabbing;
}
.dashboardLayoutEditingV71 .dashboardTileV71.dragging{
  opacity:.42;
}
.dashboardLayoutToolbarV71{
  display:none;
  position:fixed;
  left:50%;
  bottom:18px;
  transform:translateX(-50%);
  z-index:9999;
  align-items:center;
  gap:9px;
  padding:10px 12px;
  border:1px solid #44658d;
  border-radius:13px;
  background:#0d1827ee;
  box-shadow:0 14px 45px #000a;
}
.dashboardLayoutToolbarV71.show{
  display:flex;
}
.dashboardLayoutToolbarV71 span{
  color:#9db2cd;
  font-size:11px;
}
@media(min-width:1051px){
  .cards.dashboardLayoutColumnsV71{
    grid-template-columns:
      repeat(
        var(--dashboard-card-columns-v71,4),
        minmax(0,1fr)
      )!important;
  }
  .charts.dashboardLayoutColumnsV71{
    grid-template-columns:
      repeat(
        var(--dashboard-chart-columns-v71,2),
        minmax(0,1fr)
      )!important;
  }
}
@media(max-width:760px){
  .layoutEditorGridV71,
  .layoutColumnsV71{
    grid-template-columns:1fr;
  }
}
'''

    if "</style>" not in html:
        raise SystemExit(
            "FEHLER: </style> fehlt."
        )

    html = html.replace(
        "</style>",
        css + "\n</style>",
        1,
    )

    js = r'''
/* PVE_DASHBOARD_LAYOUT_UI_V71 */

const DASHBOARD_LAYOUT_DEFAULT_V71={
  version:1,
  cards:[
    'cpu','ups','ram','disk',
    'network','power','guests','pihole'
  ],
  charts:[
    'cpu-io','temperature','memory','power',
    'network','disk-io','load','cpu-gpu-temp'
  ],
  hidden:[],
  card_columns:4,
  chart_columns:2
};

const DASHBOARD_LAYOUT_NAMES_V71={
  'card:cpu':'CPU',
  'card:ups':'USV / NAS',
  'card:ram':'RAM / Swap',
  'card:disk':'Speicher / Lüfter',
  'card:network':'Netzwerk',
  'card:power':'Leistungsaufnahme',
  'card:guests':'VM / LXC',
  'card:pihole':'Pi-hole · Geblockt in %',
  'chart:cpu-io':'CPU / I/O Wait',
  'chart:temperature':'Temperaturen',
  'chart:memory':'RAM / Systemlaufwerk',
  'chart:power':'Leistungsaufnahme',
  'chart:network':'Netzwerk',
  'chart:disk-io':'Disk I/O',
  'chart:load':'Load Average',
  'chart:cpu-gpu-temp':'CPU / GPU Temperatur'
};

let dashboardLayoutV71=
  JSON.parse(
    JSON.stringify(
      DASHBOARD_LAYOUT_DEFAULT_V71
    )
  );

let dashboardLayoutBeforeDirectEditV71=null;
let dashboardDraggedTileV71=null;

function dashboardTileKeyV71(type,id){
  return `${type}:${id}`;
}

function cloneDashboardLayoutV71(layout){
  return JSON.parse(
    JSON.stringify(layout)
  );
}

function normalizeDashboardLayoutClientV71(layout){
  const source=
    layout&&typeof layout==='object'
      ? layout
      : {};

  const normalizeOrder=(raw,defaults)=>{
    const out=[];

    (Array.isArray(raw)?raw:[]).forEach(id=>{
      id=String(id);

      if(defaults.includes(id)&&!out.includes(id)){
        out.push(id);
      }
    });

    defaults.forEach(id=>{
      if(!out.includes(id)){
        out.push(id);
      }
    });

    return out;
  };

  const clean={
    version:1,
    cards:normalizeOrder(
      source.cards,
      DASHBOARD_LAYOUT_DEFAULT_V71.cards
    ),
    charts:normalizeOrder(
      source.charts,
      DASHBOARD_LAYOUT_DEFAULT_V71.charts
    ),
    hidden:[],
    card_columns:Number(source.card_columns)||4,
    chart_columns:Number(source.chart_columns)||2
  };

  const allowedHidden=new Set([
    ...DASHBOARD_LAYOUT_DEFAULT_V71.cards.map(
      id=>dashboardTileKeyV71('card',id)
    ),
    ...DASHBOARD_LAYOUT_DEFAULT_V71.charts.map(
      id=>dashboardTileKeyV71('chart',id)
    )
  ]);

  (Array.isArray(source.hidden)?source.hidden:[])
    .forEach(item=>{
      item=String(item);

      if(
        allowedHidden.has(item)
        &&!clean.hidden.includes(item)
      ){
        clean.hidden.push(item);
      }
    });

  clean.card_columns=Math.max(
    1,
    Math.min(4,clean.card_columns)
  );

  clean.chart_columns=Math.max(
    1,
    Math.min(2,clean.chart_columns)
  );

  return clean;
}

function identifyDashboardTilesV71(){
  const cards=document.querySelector('.cards');
  const charts=document.querySelector('.charts');

  if(cards){
    cards.classList.add('dashboardLayoutColumnsV71');

    [...cards.children].forEach(tile=>{
      if(!tile.classList.contains('card'))return;

      let id='';

      if(tile.id==='upsCard')id='ups';
      else if(tile.querySelector('#cpu'))id='cpu';
      else if(tile.querySelector('#ram'))id='ram';
      else if(tile.querySelector('#disk'))id='disk';
      else if(tile.querySelector('#net'))id='network';
      else if(tile.querySelector('#power'))id='power';
      else if(tile.querySelector('#guests'))id='guests';
      else if(tile.querySelector('#piholeBlockedPct'))id='pihole';

      if(!id)return;

      tile.dataset.dashboardTileType='card';
      tile.dataset.dashboardTileId=id;
      tile.classList.add('dashboardTileV71');
    });
  }

  const chartMap={
    cCpu:'cpu-io',
    cTemp:'temperature',
    cMem:'memory',
    cPower:'power',
    cNet:'network',
    cIO:'disk-io',
    cLoad:'load',
    cCpuGpu:'cpu-gpu-temp'
  };

  if(charts){
    charts.classList.add('dashboardLayoutColumnsV71');

    [...charts.children].forEach(tile=>{
      if(!tile.classList.contains('chart'))return;

      const canvas=tile.querySelector('canvas');
      const id=canvas?chartMap[canvas.id]:'';

      if(!id)return;

      tile.dataset.dashboardTileType='chart';
      tile.dataset.dashboardTileId=id;
      tile.classList.add('dashboardTileV71');
    });
  }
}

function dashboardTileElementV71(type,id){
  return document.querySelector(
    `.dashboardTileV71`
    +`[data-dashboard-tile-type="${type}"]`
    +`[data-dashboard-tile-id="${id}"]`
  );
}

function applyDashboardLayoutV71(layout){
  identifyDashboardTilesV71();

  dashboardLayoutV71=
    normalizeDashboardLayoutClientV71(layout);

  const cards=document.querySelector('.cards');
  const charts=document.querySelector('.charts');

  if(cards){
    dashboardLayoutV71.cards.forEach(id=>{
      const tile=dashboardTileElementV71('card',id);
      if(tile)cards.appendChild(tile);
    });

    cards.style.setProperty(
      '--dashboard-card-columns-v71',
      String(dashboardLayoutV71.card_columns)
    );
  }

  if(charts){
    dashboardLayoutV71.charts.forEach(id=>{
      const tile=dashboardTileElementV71('chart',id);
      if(tile)charts.appendChild(tile);
    });

    charts.style.setProperty(
      '--dashboard-chart-columns-v71',
      String(dashboardLayoutV71.chart_columns)
    );
  }

  document.querySelectorAll('.dashboardTileV71')
    .forEach(tile=>{
      const key=dashboardTileKeyV71(
        tile.dataset.dashboardTileType,
        tile.dataset.dashboardTileId
      );

      tile.classList.toggle(
        'dashboardTileHiddenV71',
        dashboardLayoutV71.hidden.includes(key)
      );
    });

  if($('layoutCardColumnsV71')){
    $('layoutCardColumnsV71').value=
      String(dashboardLayoutV71.card_columns);
  }

  if($('layoutChartColumnsV71')){
    $('layoutChartColumnsV71').value=
      String(dashboardLayoutV71.chart_columns);
  }
}

async function loadDashboardLayoutV71(){
  try{
    const data=await getJSON('/api/dashboard/layout');
    applyDashboardLayoutV71(data.layout);
  }catch(e){
    console.error('Dashboard Layout:',e);
    applyDashboardLayoutV71(
      DASHBOARD_LAYOUT_DEFAULT_V71
    );
  }
}

function layoutOrderArrayV71(type){
  return type==='card'
    ? dashboardLayoutV71.cards
    : dashboardLayoutV71.charts;
}

function moveLayoutItemV71(type,id,delta){
  const order=layoutOrderArrayV71(type);
  const index=order.indexOf(id);
  const next=index+delta;

  if(index<0||next<0||next>=order.length)return;

  [order[index],order[next]]=[
    order[next],order[index]
  ];

  applyDashboardLayoutV71(dashboardLayoutV71);
  renderDashboardLayoutEditorV71();
}

function toggleLayoutVisibilityV71(type,id,visible){
  const key=dashboardTileKeyV71(type,id);

  dashboardLayoutV71.hidden=
    dashboardLayoutV71.hidden.filter(
      item=>item!==key
    );

  if(!visible){
    dashboardLayoutV71.hidden.push(key);
  }

  applyDashboardLayoutV71(dashboardLayoutV71);
  renderDashboardLayoutEditorV71();
}

function layoutRowV71(type,id,index,total){
  const row=document.createElement('div');
  row.className='layoutRowV71';
  row.draggable=true;

  const checkbox=document.createElement('input');
  checkbox.type='checkbox';

  const key=dashboardTileKeyV71(type,id);

  checkbox.checked=
    !dashboardLayoutV71.hidden.includes(key);

  checkbox.onchange=()=>{
    toggleLayoutVisibilityV71(
      type,
      id,
      checkbox.checked
    );
  };

  const name=document.createElement('div');
  name.className='layoutRowNameV71';
  name.textContent=
    DASHBOARD_LAYOUT_NAMES_V71[key]||id;

  const actions=document.createElement('div');
  actions.className='layoutRowActionsV71';

  const up=document.createElement('button');
  up.type='button';
  up.textContent='↑';
  up.disabled=index===0;
  up.onclick=()=>moveLayoutItemV71(type,id,-1);

  const down=document.createElement('button');
  down.type='button';
  down.textContent='↓';
  down.disabled=index===total-1;
  down.onclick=()=>moveLayoutItemV71(type,id,1);

  actions.append(up,down);
  row.append(checkbox,name,actions);

  row.addEventListener('dragstart',event=>{
    event.dataTransfer.setData(
      'text/plain',
      `${type}:${id}`
    );
    row.classList.add('dragging');
  });

  row.addEventListener('dragend',()=>{
    row.classList.remove('dragging');
  });

  row.addEventListener('dragover',event=>{
    event.preventDefault();
  });

  row.addEventListener('drop',event=>{
    event.preventDefault();

    const raw=event.dataTransfer.getData('text/plain');
    const split=raw.split(':');
    const sourceType=split[0];
    const sourceId=split.slice(1).join(':');

    if(sourceType!==type)return;

    const order=layoutOrderArrayV71(type);
    const from=order.indexOf(sourceId);
    const to=order.indexOf(id);

    if(from<0||to<0||from===to)return;

    const item=order.splice(from,1)[0];
    order.splice(to,0,item);

    applyDashboardLayoutV71(dashboardLayoutV71);
    renderDashboardLayoutEditorV71();
  });

  return row;
}

function renderDashboardLayoutEditorV71(){
  const cards=$('layoutCardsListV71');
  const charts=$('layoutChartsListV71');

  if(!cards||!charts)return;

  cards.innerHTML='';
  charts.innerHTML='';

  dashboardLayoutV71.cards.forEach(
    (id,index)=>{
      cards.appendChild(
        layoutRowV71(
          'card',
          id,
          index,
          dashboardLayoutV71.cards.length
        )
      );
    }
  );

  dashboardLayoutV71.charts.forEach(
    (id,index)=>{
      charts.appendChild(
        layoutRowV71(
          'chart',
          id,
          index,
          dashboardLayoutV71.charts.length
        )
      );
    }
  );
}

function layoutMessageV71(text,kind=''){
  const box=$('layoutMessageV71');
  if(!box)return;

  box.textContent=text;
  box.className=`msg ${kind}`.trim();
}

async function saveDashboardLayoutV71(){
  if(!settingsSessionCode){
    return requestSettingsUnlock('links');
  }

  dashboardLayoutV71.card_columns=
    Number($('layoutCardColumnsV71')?.value||4);

  dashboardLayoutV71.chart_columns=
    Number($('layoutChartColumnsV71')?.value||2);

  applyDashboardLayoutV71(dashboardLayoutV71);

  layoutMessageV71('Layout wird gespeichert ...');

  try{
    const data=await getJSON(
      '/api/dashboard/layout',
      {
        method:'POST',
        headers:{
          'Content-Type':'application/json'
        },
        body:JSON.stringify({
          code:settingsSessionCode,
          layout:dashboardLayoutV71
        })
      }
    );

    applyDashboardLayoutV71(data.layout);
    renderDashboardLayoutEditorV71();

    layoutMessageV71(
      'Gespeichert und sofort angewendet.',
      'ok'
    );
  }catch(e){
    layoutMessageV71(e.message,'err');
  }
}

async function resetDashboardLayoutV71(){
  if(!settingsSessionCode){
    return requestSettingsUnlock('links');
  }

  if(!confirm(
    'Dashboard-Layout wirklich auf Standard zurücksetzen?'
  )){
    return;
  }

  try{
    const data=await getJSON(
      '/api/dashboard/layout/reset',
      {
        method:'POST',
        headers:{
          'Content-Type':'application/json'
        },
        body:JSON.stringify({
          code:settingsSessionCode
        })
      }
    );

    applyDashboardLayoutV71(data.layout);
    renderDashboardLayoutEditorV71();

    layoutMessageV71(
      'Standardlayout wiederhergestellt.',
      'ok'
    );
  }catch(e){
    layoutMessageV71(e.message,'err');
  }
}

function deactivateOtherSettingsTabsV71(){
  [
    'settingsHubTabLinks',
    'settingsHubTabCategories',
    'settingsHubTabUps',
    'settingsHubTabDashboard'
  ].forEach(id=>{
    const el=$(id);

    if(el){
      el.classList.remove('active');
      el.setAttribute('aria-selected','false');
    }
  });

  [
    'settingsHubPanelLinks',
    'settingsHubPanelCategories',
    'settingsHubPanelUps',
    'settingsHubPanelDashboard'
  ].forEach(id=>{
    $(id)?.classList.remove('active');
  });
}

async function switchDashboardLayoutTabV71(){
  if(!settingsSessionCode){
    return requestSettingsUnlock('links');
  }

  deactivateOtherSettingsTabsV71();

  $('settingsHubTabLayout')?.classList.add('active');
  $('settingsHubTabLayout')?.setAttribute(
    'aria-selected',
    'true'
  );
  $('settingsHubPanelLayout')?.classList.add('active');

  await loadDashboardLayoutV71();
  renderDashboardLayoutEditorV71();
}

const dashboardLayoutLegacySwitchSettingsV71=
  typeof switchUnifiedSettingsTab==='function'
    ? switchUnifiedSettingsTab
    : null;

if(dashboardLayoutLegacySwitchSettingsV71){
  switchUnifiedSettingsTab=async function(tab){
    if(tab==='layout'){
      return switchDashboardLayoutTabV71();
    }

    $('settingsHubTabLayout')?.classList.remove('active');
    $('settingsHubTabLayout')?.setAttribute(
      'aria-selected',
      'false'
    );
    $('settingsHubPanelLayout')?.classList.remove('active');

    return dashboardLayoutLegacySwitchSettingsV71(tab);
  };
}

function updateLayoutFromDashboardDomV71(){
  const cards=document.querySelector('.cards');
  const charts=document.querySelector('.charts');

  if(cards){
    dashboardLayoutV71.cards=[
      ...cards.querySelectorAll(':scope > .dashboardTileV71')
    ].map(
      tile=>tile.dataset.dashboardTileId
    ).filter(Boolean);
  }

  if(charts){
    dashboardLayoutV71.charts=[
      ...charts.querySelectorAll(':scope > .dashboardTileV71')
    ].map(
      tile=>tile.dataset.dashboardTileId
    ).filter(Boolean);
  }
}

function directDragStartV71(event){
  dashboardDraggedTileV71=event.currentTarget;
  dashboardDraggedTileV71.classList.add('dragging');
  event.dataTransfer.effectAllowed='move';
}

function directDragEndV71(event){
  event.currentTarget.classList.remove('dragging');
  dashboardDraggedTileV71=null;
}

function directDragOverV71(event){
  event.preventDefault();

  if(!dashboardDraggedTileV71)return;

  const target=event.currentTarget;

  if(
    target===dashboardDraggedTileV71
    ||target.dataset.dashboardTileType
      !==dashboardDraggedTileV71.dataset.dashboardTileType
  ){
    return;
  }

  const parent=target.parentElement;
  if(!parent)return;

  const rect=target.getBoundingClientRect();
  const before=
    event.clientY<rect.top+(rect.height/2);

  parent.insertBefore(
    dashboardDraggedTileV71,
    before?target:target.nextSibling
  );
}

function setDirectDragHandlersV71(enabled){
  document.querySelectorAll('.dashboardTileV71')
    .forEach(tile=>{
      tile.draggable=enabled;

      if(enabled){
        tile.addEventListener(
          'dragstart',
          directDragStartV71
        );
        tile.addEventListener(
          'dragend',
          directDragEndV71
        );
        tile.addEventListener(
          'dragover',
          directDragOverV71
        );
      }else{
        tile.removeEventListener(
          'dragstart',
          directDragStartV71
        );
        tile.removeEventListener(
          'dragend',
          directDragEndV71
        );
        tile.removeEventListener(
          'dragover',
          directDragOverV71
        );
      }
    });
}

function startDashboardDirectEditV71(){
  identifyDashboardTilesV71();

  dashboardLayoutBeforeDirectEditV71=
    cloneDashboardLayoutV71(dashboardLayoutV71);

  $('settingsHubModal')?.classList.remove('show');

  document.body.classList.add(
    'dashboardLayoutEditingV71'
  );

  $('dashboardLayoutToolbarV71')?.classList.add('show');

  setDirectDragHandlersV71(true);
}

function stopDashboardDirectEditV71(){
  document.body.classList.remove(
    'dashboardLayoutEditingV71'
  );

  $('dashboardLayoutToolbarV71')?.classList.remove('show');

  setDirectDragHandlersV71(false);
}

function cancelDashboardDirectEditV71(){
  stopDashboardDirectEditV71();

  if(dashboardLayoutBeforeDirectEditV71){
    applyDashboardLayoutV71(
      dashboardLayoutBeforeDirectEditV71
    );
  }

  dashboardLayoutBeforeDirectEditV71=null;
}

async function finishDashboardDirectEditV71(){
  updateLayoutFromDashboardDomV71();
  stopDashboardDirectEditV71();

  try{
    const data=await getJSON(
      '/api/dashboard/layout',
      {
        method:'POST',
        headers:{
          'Content-Type':'application/json'
        },
        body:JSON.stringify({
          code:settingsSessionCode,
          layout:dashboardLayoutV71
        })
      }
    );

    applyDashboardLayoutV71(data.layout);
    dashboardLayoutBeforeDirectEditV71=null;
  }catch(e){
    alert(
      'Layout konnte nicht gespeichert werden: '
      +e.message
    );

    if(dashboardLayoutBeforeDirectEditV71){
      applyDashboardLayoutV71(
        dashboardLayoutBeforeDirectEditV71
      );
    }

    dashboardLayoutBeforeDirectEditV71=null;
  }
}

$('layoutCardColumnsV71')?.addEventListener(
  'change',
  ()=>{
    dashboardLayoutV71.card_columns=
      Number($('layoutCardColumnsV71').value);

    applyDashboardLayoutV71(dashboardLayoutV71);
  }
);

$('layoutChartColumnsV71')?.addEventListener(
  'change',
  ()=>{
    dashboardLayoutV71.chart_columns=
      Number($('layoutChartColumnsV71').value);

    applyDashboardLayoutV71(dashboardLayoutV71);
  }
);

setTimeout(
  async()=>{
    identifyDashboardTilesV71();
    await loadDashboardLayoutV71();
  },
  0
);
'''

    script_end = html.rfind("</script>")

    if script_end < 0:
        raise SystemExit(
            "FEHLER: </script> fehlt."
        )

    html = (
        html[:script_end]
        + js
        + "\n"
        + html[script_end:]
    )

path.write_text(
    html,
    encoding="utf-8",
)

required = [
    MARKER,
    'id="settingsHubTabLayout"',
    'id="settingsHubPanelLayout"',
    'dashboardLayoutToolbarV71',
    'switchDashboardLayoutTabV71',
    'startDashboardDirectEditV71',
    'saveDashboardLayoutV71',
]

for marker in required:
    if marker not in html:
        raise SystemExit(
            f"FEHLER: Frontend-Marker fehlt: {marker}"
        )

print("[OK] Dashboard Layout-Editor eingebaut.")
PY

chown root:root "$INDEX"
chmod 644 "$INDEX"

if [[ ! -f "$LAYOUT_FILE" ]]; then
    cat > "$LAYOUT_FILE" <<'JSON'
{
  "version": 1,
  "cards": [
    "cpu",
    "ups",
    "ram",
    "disk",
    "network",
    "power",
    "guests",
    "pihole"
  ],
  "charts": [
    "cpu-io",
    "temperature",
    "memory",
    "power",
    "network",
    "disk-io",
    "load",
    "cpu-gpu-temp"
  ],
  "hidden": [],
  "card_columns": 4,
  "chart_columns": 2
}
JSON
fi

chown pve-monitor:pve-monitor "$LAYOUT_FILE"
chmod 640 "$LAYOUT_FILE"

python3 -m py_compile "$APP"

systemctl restart pve-sensor-web.service
nginx -t
systemctl reload nginx

sleep 3

curl -fsS \
    http://127.0.0.1:9105/api/dashboard/layout |
python3 -m json.tool

trap - ERR

echo
echo "============================================================"
echo " FERTIG"
echo "============================================================"
echo
echo "Einstellungen:"
echo "  Webseitenverwaltung | Kategorien | USV | Layout | Dashboard"
echo
echo "Persistenz:"
echo "  $LAYOUT_FILE"
echo
echo "Backup:"
echo "  $BACKUP"
echo
echo "Log:"
echo "  $LOGFILE"
__PVE_DASHBOARD_LAYOUT_V71__

    chmod +x "$patch"
    "$patch"
    rm -f "$patch"
}


# =============================================================================
# V78 · DASHBOARD PI-HOLE EINSTELLUNGEN
# =============================================================================

install_dashboard_pihole_settings_v78() {
    header "DASHBOARD · PI-HOLE EINSTELLUNGEN"

    local patch="/tmp/pve-dashboard-pihole-settings-v78.$$"

    cat > "$patch" <<'__PVE_DASHBOARD_PIHOLE_V78__'
#!/usr/bin/env bash
set -Eeuo pipefail

STAMP="$(date +%d-%m-%H-%M)"
LOGFILE="/root/diagnose/diagnose-dashboard-pihole-settings-v78-${STAMP}.txt"

if [[ -e "$LOGFILE" ]]; then
    N=2
    while [[ -e "/root/diagnose/diagnose-dashboard-pihole-settings-v78-${STAMP}-${N}.txt" ]]; do
        N=$((N + 1))
    done
    LOGFILE="/root/diagnose/diagnose-dashboard-pihole-settings-v78-${STAMP}-${N}.txt"
fi

exec > >(tee -a "$LOGFILE") 2>&1

[[ ${EUID:-$(id -u)} -eq 0 ]] || {
    echo "FEHLER: Bitte als root ausführen."
    exit 1
}

COLLECTOR="/opt/nodezero/dashboard/collector.py"
APP="/opt/nodezero/dashboard/app.py"
INDEX="/opt/nodezero/dashboard/static/index.html"
WEB_DIR="/var/lib/pve-sensor-dashboard-web"
CONFIG="${WEB_DIR}/pihole-source.json"
HELPER="/usr/local/sbin/pve-dashboard-pihole-helper"
SUDOERS="/etc/sudoers.d/pve-sensor-dashboard-pihole"
BACKUP="/root/backups/pve-dashboard-pihole-v78-backup-$(date +%Y%m%d-%H%M%S)"

for f in "$COLLECTOR" "$APP" "$INDEX"; do
    [[ -f "$f" ]] || {
        echo "FEHLER: $f fehlt."
        exit 1
    }
done

grep -Fq 'id="settingsHubTabUps"' "$INDEX" || {
    echo "FEHLER: USV-Reiter fehlt."
    exit 1
}

grep -Fq 'id="settingsHubTabLayout"' "$INDEX" || {
    echo "FEHLER: Layout-Reiter fehlt."
    exit 1
}

mkdir -p "$BACKUP" "$WEB_DIR"

cp -a "$COLLECTOR" "$BACKUP/collector.py"
cp -a "$APP" "$BACKUP/app.py"
cp -a "$INDEX" "$BACKUP/index.html"

[[ -f "$CONFIG" ]] && cp -a "$CONFIG" "$BACKUP/pihole-source.json"
[[ -f "$HELPER" ]] && cp -a "$HELPER" "$BACKUP/pve-dashboard-pihole-helper"
[[ -f "$SUDOERS" ]] && cp -a "$SUDOERS" "$BACKUP/pve-sensor-dashboard-pihole.sudoers"

rollback() {
    echo
    echo "AUTOMATISCHES ROLLBACK"

    cp -a "$BACKUP/collector.py" "$COLLECTOR"
    cp -a "$BACKUP/app.py" "$APP"
    cp -a "$BACKUP/index.html" "$INDEX"

    if [[ -f "$BACKUP/pihole-source.json" ]]; then
        cp -a "$BACKUP/pihole-source.json" "$CONFIG"
    fi

    if [[ -f "$BACKUP/pve-dashboard-pihole-helper" ]]; then
        cp -a "$BACKUP/pve-dashboard-pihole-helper" "$HELPER"
    fi

    if [[ -f "$BACKUP/pve-sensor-dashboard-pihole.sudoers" ]]; then
        cp -a "$BACKUP/pve-sensor-dashboard-pihole.sudoers" "$SUDOERS"
    fi

    chown root:root "$COLLECTOR" "$APP" "$INDEX"
    chmod 644 "$COLLECTOR" "$APP" "$INDEX"

    systemctl restart pve-sensor-web.service 2>/dev/null || true
    systemctl start pve-sensor-collector.service 2>/dev/null || true
    systemctl reload nginx 2>/dev/null || true
}

trap 'echo "FEHLER in Zeile $LINENO"; rollback' ERR

echo "============================================================"
echo " DASHBOARD · PI-HOLE SETTINGS V78"
echo "============================================================"
echo
echo "Neu:"
echo "  Einstellungen -> Pi-hole"
echo "  - Datenquelle aktivieren/deaktivieren"
echo "  - automatische LXC-Erkennung oder feste CT-ID"
echo "  - Hostname"
echo "  - FTL-Datenbankpfad"
echo "  - Auswertungszeitraum 1-168 Stunden"
echo "  - direkte Verbindung / Statistik testen"
echo

# ---------------------------------------------------------------------------
# 1. Root helper
# ---------------------------------------------------------------------------

cat > "$HELPER" <<'PYHELPER'
#!/usr/bin/env python3

from pathlib import Path
import json
import re
import subprocess
import sys

CONFIG = Path(
    "/var/lib/pve-sensor-dashboard-web/pihole-source.json"
)

PCT = "/usr/sbin/pct"


def default_config():
    return {
        "version": 1,
        "enabled": True,
        "mode": "auto",
        "hostname": "pihole",
        "ctid": "",
        "db_path": "/opt/pihole/etc-pihole/pihole-FTL.db",
        "hours": 24,
    }


def merge_config(data):
    cfg = default_config()

    if isinstance(data, dict):
        cfg.update(data)

    cfg["enabled"] = bool(
        cfg.get("enabled", True)
    )

    mode = str(
        cfg.get("mode") or "auto"
    ).strip().lower()

    cfg["mode"] = (
        "ctid"
        if mode == "ctid"
        else "auto"
    )

    hostname = str(
        cfg.get("hostname") or "pihole"
    ).strip()

    if not re.fullmatch(
        r"[A-Za-z0-9_.-]{1,63}",
        hostname,
    ):
        raise ValueError(
            "Hostname enthält ungültige Zeichen."
        )

    cfg["hostname"] = hostname

    ctid = str(
        cfg.get("ctid") or ""
    ).strip()

    if ctid and not re.fullmatch(
        r"[0-9]{1,9}",
        ctid,
    ):
        raise ValueError(
            "CT-ID muss numerisch sein."
        )

    cfg["ctid"] = ctid

    db_path = str(
        cfg.get("db_path")
        or "/opt/pihole/etc-pihole/pihole-FTL.db"
    ).strip()

    if (
        not db_path.startswith("/")
        or ".." in Path(db_path).parts
        or len(db_path) > 220
        or "\n" in db_path
        or "\r" in db_path
    ):
        raise ValueError(
            "FTL-Datenbankpfad ist ungültig."
        )

    cfg["db_path"] = db_path

    try:
        hours = int(
            cfg.get("hours", 24)
        )
    except Exception as exc:
        raise ValueError(
            "Zeitraum muss eine Zahl sein."
        ) from exc

    if not 1 <= hours <= 168:
        raise ValueError(
            "Zeitraum muss zwischen 1 und 168 Stunden liegen."
        )

    cfg["hours"] = hours
    cfg["version"] = 1

    return cfg


def read_config():
    try:
        data = json.loads(
            CONFIG.read_text(
                encoding="utf-8"
            )
        )
    except Exception:
        data = {}

    return merge_config(
        data
    )


def run(args, timeout=10):
    try:
        return subprocess.run(
            args,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
    except Exception as exc:
        return subprocess.CompletedProcess(
            args=args,
            returncode=125,
            stdout="",
            stderr=str(exc),
        )


def detect_ct(cfg):
    if cfg["mode"] == "ctid":
        ctid = cfg["ctid"]

        if not ctid:
            raise RuntimeError(
                "Feste CT-ID ist ausgewählt, aber keine CT-ID eingetragen."
            )

        conf = Path(
            f"/etc/pve/lxc/{ctid}.conf"
        )

        if not conf.is_file():
            raise RuntimeError(
                f"LXC CT {ctid} wurde nicht gefunden."
            )

        return ctid

    lxc_dir = Path(
        "/etc/pve/lxc"
    )

    if not lxc_dir.is_dir():
        raise RuntimeError(
            "Proxmox LXC-Konfiguration wurde nicht gefunden."
        )

    wanted = cfg["hostname"].lower()

    for conf in sorted(
        lxc_dir.glob("*.conf")
    ):
        try:
            content = conf.read_text(
                encoding="utf-8",
                errors="ignore",
            )
        except Exception:
            continue

        match = re.search(
            r"(?m)^hostname:\s*(\S+)\s*$",
            content,
        )

        if (
            match
            and match.group(1).lower() == wanted
        ):
            return conf.stem

    raise RuntimeError(
        f"Kein LXC mit Hostname '{cfg['hostname']}' gefunden."
    )


def ct_ip(ctid):
    result = run(
        [
            PCT,
            "config",
            ctid,
        ],
        timeout=6,
    )

    if result.returncode != 0:
        return ""

    match = re.search(
        r"(?m)^net\d+:\s.*?\bip=([^,/\s]+)",
        result.stdout,
    )

    if not match:
        return ""

    value = match.group(1)

    if value in {
        "dhcp",
        "manual",
    }:
        return ""

    return value


def query_stats(cfg, ctid):
    status = run(
        [
            PCT,
            "status",
            ctid,
        ],
        timeout=5,
    )

    if (
        status.returncode != 0
        or "status: running" not in status.stdout.lower()
    ):
        raise RuntimeError(
            f"Pi-hole LXC CT {ctid} läuft nicht."
        )

    db_path = cfg["db_path"]

    ready = run(
        [
            PCT,
            "exec",
            ctid,
            "--",
            "sqlite3",
            "-readonly",
            db_path,
            "SELECT name FROM sqlite_master WHERE name='queries';",
        ],
        timeout=8,
    )

    if (
        ready.returncode != 0
        or ready.stdout.strip() != "queries"
    ):
        raise RuntimeError(
            "Pi-hole FTL-Datenbank ist noch nicht initialisiert. "
            "Bitte Pi-hole vollständig starten lassen und erneut testen."
        )

    seconds = (
        int(cfg["hours"])
        * 3600
    )

    sql = (
        "SELECT "
        "COUNT(*),"
        "COALESCE(SUM(CASE WHEN status IN "
        "(1,4,5,6,7,8,9,10,11,15,16,18) "
        "THEN 1 ELSE 0 END),0) "
        "FROM queries "
        f"WHERE timestamp >= strftime('%s','now') - {seconds};"
    )

    result = run(
        [
            PCT,
            "exec",
            ctid,
            "--",
            "sqlite3",
            "-readonly",
            "-separator",
            "|",
            db_path,
            sql,
        ],
        timeout=12,
    )

    if result.returncode != 0:
        detail = (
            result.stderr.strip()
            or result.stdout.strip()
            or "sqlite3-Abfrage fehlgeschlagen."
        )

        raise RuntimeError(
            detail
        )

    raw = ""

    for line in result.stdout.splitlines():
        if "|" in line:
            raw = line.strip()

    if not raw:
        raise RuntimeError(
            "Pi-hole FTL-Datenbank lieferte keine Statistik."
        )

    parts = raw.split("|")

    if len(parts) != 2:
        raise RuntimeError(
            "Unerwartetes Ergebnis der Pi-hole Statistik."
        )

    total = int(
        parts[0]
    )

    blocked = int(
        parts[1]
    )

    percent = (
        round(
            blocked * 100.0 / total,
            2,
        )
        if total > 0
        else 0.0
    )

    return {
        "queries_total": total,
        "queries_blocked": blocked,
        "blocked_percent": percent,
    }


def perform(cfg):
    result = {
        "ok": False,
        "enabled": cfg["enabled"],
        "mode": cfg["mode"],
        "hostname": cfg["hostname"],
        "configured_ctid": cfg["ctid"],
        "db_path": cfg["db_path"],
        "hours": cfg["hours"],
        "ctid": "",
        "ip": "",
        "running": False,
        "queries_total": None,
        "queries_blocked": None,
        "blocked_percent": None,
    }

    if not cfg["enabled"]:
        result["ok"] = True
        result["message"] = "Pi-hole Dashboard-Datenquelle ist deaktiviert."
        return result

    ctid = detect_ct(
        cfg
    )

    result["ctid"] = ctid
    result["ip"] = ct_ip(
        ctid
    )

    status = run(
        [
            PCT,
            "status",
            ctid,
        ],
        timeout=5,
    )

    result["running"] = (
        status.returncode == 0
        and "status: running" in status.stdout.lower()
    )

    stats = query_stats(
        cfg,
        ctid,
    )

    result.update(
        stats
    )

    result["ok"] = True
    result["message"] = "Pi-hole Statistik erfolgreich gelesen."

    return result


def main():
    command = (
        sys.argv[1]
        if len(sys.argv) > 1
        else "test"
    )

    try:
        if command == "test":
            cfg = read_config()

        elif command == "test-stdin":
            raw = sys.stdin.read()

            try:
                payload = json.loads(
                    raw or "{}"
                )
            except Exception as exc:
                raise ValueError(
                    "Ungültige JSON-Konfiguration."
                ) from exc

            cfg = merge_config(
                payload
            )

        else:
            raise ValueError(
                "Unbekannter Helper-Befehl."
            )

        result = perform(
            cfg
        )

        print(
            json.dumps(
                result,
                ensure_ascii=False,
            )
        )

        return 0 if result.get("ok") else 1

    except Exception as exc:
        print(
            json.dumps(
                {
                    "ok": False,
                    "error": str(exc),
                },
                ensure_ascii=False,
            )
        )

        return 1


if __name__ == "__main__":
    raise SystemExit(
        main()
    )
PYHELPER

chmod 755 "$HELPER"
chown root:root "$HELPER"

python3 -m py_compile "$HELPER"

# ---------------------------------------------------------------------------
# 2. Default config
# ---------------------------------------------------------------------------

if [[ ! -f "$CONFIG" ]]; then
    cat > "$CONFIG" <<'JSON'
{
  "version": 1,
  "enabled": true,
  "mode": "auto",
  "hostname": "pihole",
  "ctid": "",
  "db_path": "/opt/pihole/etc-pihole/pihole-FTL.db",
  "hours": 24
}
JSON
fi

chown pve-monitor:pve-monitor "$CONFIG"
chmod 640 "$CONFIG"

# ---------------------------------------------------------------------------
# 3. sudoers for protected dashboard test
# ---------------------------------------------------------------------------

cat > "$SUDOERS" <<EOF
pve-monitor ALL=(root) NOPASSWD: $HELPER
EOF

chmod 440 "$SUDOERS"
chown root:root "$SUDOERS"

visudo -cf "$SUDOERS"

# ---------------------------------------------------------------------------
# 4. Collector uses central Pi-hole config/helper
# ---------------------------------------------------------------------------

python3 - "$COLLECTOR" <<'PY'
from pathlib import Path
import py_compile
import re
import sys

path = Path(
    sys.argv[1]
)

src = path.read_text(
    encoding="utf-8"
)

MARKER = "PVE_PIHOLE_COLLECTOR_SETTINGS_V78"

if MARKER not in src:
    pattern = re.compile(
        r'def pihole_stats\(\):\n'
        r'.*?\n\n'
        r'(?=def main\(\):)',
        re.S,
    )

    match = pattern.search(
        src
    )

    if not match:
        raise SystemExit(
            "FEHLER: pihole_stats() wurde im Collector nicht gefunden."
        )

    replacement = r'''def pihole_stats():
    # PVE_PIHOLE_COLLECTOR_SETTINGS_V78
    # Quelle/Zeitfenster werden zentral über das Dashboard konfiguriert.
    try:
        config_path = Path(
            "/var/lib/pve-sensor-dashboard-web/pihole-source.json"
        )

        try:
            config = json.loads(
                config_path.read_text(
                    encoding="utf-8"
                )
            )
        except Exception:
            config = {}

        if (
            isinstance(config, dict)
            and config.get("enabled") is False
        ):
            return None, None, None

        raw = run_text(
            [
                "/usr/local/sbin/pve-dashboard-pihole-helper",
                "test",
            ],
            timeout=14,
        )

        if not raw:
            return None, None, None

        data = json.loads(
            raw.splitlines()[-1]
        )

        if not data.get("ok"):
            return None, None, None

        total = data.get(
            "queries_total"
        )

        blocked = data.get(
            "queries_blocked"
        )

        percent = data.get(
            "blocked_percent"
        )

        if total is None or blocked is None:
            return None, None, None

        return (
            int(total),
            int(blocked),
            float(percent or 0.0),
        )

    except Exception:
        return None, None, None


'''

    src = (
        src[:match.start()]
        + replacement
        + src[match.end():]
    )

tmp = path.with_suffix(
    ".py.pihole-v78"
)

tmp.write_text(
    src,
    encoding="utf-8",
)

py_compile.compile(
    str(tmp),
    doraise=True,
)

tmp.replace(
    path
)

print("[OK] Collector liest Pi-hole Konfiguration V78.")
PY

chown root:root "$COLLECTOR"
chmod 644 "$COLLECTOR"

# ---------------------------------------------------------------------------
# 5. Web backend
# ---------------------------------------------------------------------------

python3 - "$APP" <<'PY'
from pathlib import Path
import py_compile
import sys

path = Path(
    sys.argv[1]
)

app = path.read_text(
    encoding="utf-8"
)

MARKER = "# PVE_PIHOLE_SETTINGS_API_V78"

if MARKER not in app:
    route_anchor = '@app.post("/api/ups/settings/read")\n'

    if route_anchor not in app:
        raise SystemExit(
            "FEHLER: API-Einfügepunkt vor UPS-Settings fehlt."
        )

    code = r'''
# PVE_PIHOLE_SETTINGS_API_V78
PIHOLE_SETTINGS_FILE_V78 = Path(
    "/var/lib/pve-sensor-dashboard-web/pihole-source.json"
)

PIHOLE_HELPER_V78 = (
    "/usr/local/sbin/pve-dashboard-pihole-helper"
)


def _pihole_settings_default_v78():
    return {
        "version": 1,
        "enabled": True,
        "mode": "auto",
        "hostname": "pihole",
        "ctid": "",
        "db_path": "/opt/pihole/etc-pihole/pihole-FTL.db",
        "hours": 24,
    }


def _pihole_settings_read_v78():
    cfg = _pihole_settings_default_v78()

    try:
        stored = json.loads(
            PIHOLE_SETTINGS_FILE_V78.read_text(
                encoding="utf-8"
            )
        )

        if isinstance(stored, dict):
            cfg.update(
                stored
            )
    except Exception:
        pass

    return _pihole_settings_from_payload_v78(
        cfg,
        base=_pihole_settings_default_v78(),
    )


def _pihole_settings_from_payload_v78(
    payload,
    base=None,
):
    base = (
        dict(base)
        if isinstance(base, dict)
        else _pihole_settings_default_v78()
    )

    enabled_raw = payload.get(
        "enabled",
        base.get("enabled", True),
    )

    if isinstance(enabled_raw, str):
        enabled = (
            enabled_raw.strip().lower()
            in ("1", "true", "yes", "ja", "on")
        )
    else:
        enabled = bool(
            enabled_raw
        )

    mode = str(
        payload.get(
            "mode",
            base.get("mode", "auto"),
        )
        or "auto"
    ).strip().lower()

    if mode not in (
        "auto",
        "ctid",
    ):
        raise ValueError(
            "Pi-hole Quelle muss Auto oder feste CT-ID sein."
        )

    hostname = str(
        payload.get(
            "hostname",
            base.get("hostname", "pihole"),
        )
        or "pihole"
    ).strip()

    if not re.fullmatch(
        r"[A-Za-z0-9_.-]{1,63}",
        hostname,
    ):
        raise ValueError(
            "Pi-hole Hostname enthält ungültige Zeichen."
        )

    ctid = str(
        payload.get(
            "ctid",
            base.get("ctid", ""),
        )
        or ""
    ).strip()

    if ctid and not re.fullmatch(
        r"[0-9]{1,9}",
        ctid,
    ):
        raise ValueError(
            "Pi-hole CT-ID muss numerisch sein."
        )

    if (
        mode == "ctid"
        and not ctid
    ):
        raise ValueError(
            "Bei fester CT-ID muss eine CT-ID eingetragen sein."
        )

    db_path = str(
        payload.get(
            "db_path",
            base.get(
                "db_path",
                "/opt/pihole/etc-pihole/pihole-FTL.db",
            ),
        )
        or "/opt/pihole/etc-pihole/pihole-FTL.db"
    ).strip()

    if (
        not db_path.startswith("/")
        or ".." in Path(db_path).parts
        or len(db_path) > 220
        or "\n" in db_path
        or "\r" in db_path
    ):
        raise ValueError(
            "Pi-hole FTL-Datenbankpfad ist ungültig."
        )

    try:
        hours = int(
            payload.get(
                "hours",
                base.get("hours", 24),
            )
        )
    except Exception:
        raise ValueError(
            "Pi-hole Zeitraum muss eine Zahl sein."
        )

    if not 1 <= hours <= 168:
        raise ValueError(
            "Pi-hole Zeitraum muss zwischen 1 und 168 Stunden liegen."
        )

    return {
        "version": 1,
        "enabled": enabled,
        "mode": mode,
        "hostname": hostname,
        "ctid": ctid,
        "db_path": db_path,
        "hours": hours,
    }


def _pihole_helper_test_v78(settings):
    result = subprocess.run(
        [
            "sudo",
            "-n",
            PIHOLE_HELPER_V78,
            "test-stdin",
        ],
        input=json.dumps(
            settings,
            ensure_ascii=False,
        ),
        capture_output=True,
        text=True,
        timeout=16,
        check=False,
    )

    raw = (
        result.stdout.strip()
        or result.stderr.strip()
    )

    if not raw:
        raise RuntimeError(
            "Pi-hole Helper lieferte keine Antwort."
        )

    try:
        data = json.loads(
            raw.splitlines()[-1]
        )
    except Exception:
        raise RuntimeError(
            raw
        )

    if (
        result.returncode != 0
        or not data.get("ok")
    ):
        raise RuntimeError(
            data.get("error")
            or data.get("message")
            or "Pi-hole Test fehlgeschlagen."
        )

    return data


@app.post("/api/pihole/settings/read")
def pihole_settings_read_v78():
    payload = request.get_json(
        silent=True
    ) or {}

    allowed, error = _dashboard_code_check_v2(
        payload
    )

    if not allowed:
        return error

    return jsonify({
        "ok": True,
        "settings": _pihole_settings_read_v78(),
    })


@app.post("/api/pihole/settings/test")
def pihole_settings_test_v78():
    payload = request.get_json(
        silent=True
    ) or {}

    allowed, error = _dashboard_code_check_v2(
        payload
    )

    if not allowed:
        return error

    try:
        settings = _pihole_settings_from_payload_v78(
            payload,
            base=_pihole_settings_read_v78(),
        )

        result = _pihole_helper_test_v78(
            settings
        )

        return jsonify({
            "ok": True,
            "result": result,
        })

    except Exception as exc:
        return jsonify({
            "ok": False,
            "error": str(exc),
        }), 400


@app.post("/api/pihole/settings/save")
def pihole_settings_save_v78():
    payload = request.get_json(
        silent=True
    ) or {}

    allowed, error = _dashboard_code_check_v2(
        payload
    )

    if not allowed:
        return error

    try:
        settings = _pihole_settings_from_payload_v78(
            payload,
            base=_pihole_settings_read_v78(),
        )

        PIHOLE_SETTINGS_FILE_V78.parent.mkdir(
            parents=True,
            exist_ok=True,
        )

        temp = PIHOLE_SETTINGS_FILE_V78.with_suffix(
            ".tmp"
        )

        temp.write_text(
            json.dumps(
                settings,
                ensure_ascii=False,
                indent=2,
            ) + "\n",
            encoding="utf-8",
        )

        temp.chmod(
            0o640
        )

        temp.replace(
            PIHOLE_SETTINGS_FILE_V78
        )

        return jsonify({
            "ok": True,
            "settings": settings,
        })

    except Exception as exc:
        return jsonify({
            "ok": False,
            "error": str(exc),
        }), 400


'''

    app = app.replace(
        route_anchor,
        code + route_anchor,
        1,
    )

tmp = path.with_suffix(
    ".py.pihole-v78"
)

tmp.write_text(
    app,
    encoding="utf-8",
)

py_compile.compile(
    str(tmp),
    doraise=True,
)

tmp.replace(
    path
)

print("[OK] Pi-hole Settings API V78 eingebaut.")
PY

chown root:root "$APP"
chmod 644 "$APP"

# ---------------------------------------------------------------------------
# 6. Frontend
# ---------------------------------------------------------------------------

python3 - "$INDEX" <<'PY'
from pathlib import Path
import re
import sys

path = Path(
    sys.argv[1]
)

html = path.read_text(
    encoding="utf-8"
)

MARKER = "PVE_PIHOLE_SETTINGS_UI_V78"

if MARKER not in html:
    # Tab between UPS and Layout.
    layout_tab = re.search(
        r'<button\b'
        r'(?=[^>]*id=["\']settingsHubTabLayout["\'])'
        r'.*?</button>',
        html,
        re.S | re.I,
    )

    if not layout_tab:
        raise SystemExit(
            "FEHLER: Layout-Reiter wurde nicht gefunden."
        )

    pihole_tab = r'''
      <button
        id="settingsHubTabPihole"
        class="settingsHubTab"
        type="button"
        role="tab"
        aria-selected="false"
        onclick="switchUnifiedSettingsTab('pihole')"
      >Pi-hole</button>
'''

    html = (
        html[:layout_tab.start()]
        + pihole_tab
        + html[layout_tab.start():]
    )

    layout_panel = re.search(
        r'<div\b'
        r'(?=[^>]*id=["\']settingsHubPanelLayout["\'])',
        html,
        re.I,
    )

    if not layout_panel:
        raise SystemExit(
            "FEHLER: Layout-Panel wurde nicht gefunden."
        )

    pihole_panel = r'''
    <div
      id="settingsHubPanelPihole"
      class="settingsHubPanel"
      role="tabpanel"
    >
      <div class="piholeSettingsV78">
        <p class="settingsNote">
          Hier wird nur die Pi-hole-Datenquelle der Dashboard-Kachel
          konfiguriert. Sichtbarkeit und Position der Kachel stellst du
          weiterhin unter <strong>Layout</strong> ein.
        </p>

        <div class="piholeToggleV78">
          <label>
            <input
              id="piholeEnabledV78"
              type="checkbox"
              checked
            >
            Pi-hole Statistik im Dashboard aktivieren
          </label>
        </div>

        <div class="formGrid">
          <div>
            <label for="piholeModeV78">Quelle</label>
            <select id="piholeModeV78">
              <option value="auto">
                LXC automatisch per Hostname erkennen
              </option>
              <option value="ctid">
                Feste LXC CT-ID
              </option>
            </select>
          </div>

          <div>
            <label for="piholeHoursV78">
              Zeitraum
            </label>
            <select id="piholeHoursV78">
              <option value="1">1 Stunde</option>
              <option value="6">6 Stunden</option>
              <option value="12">12 Stunden</option>
              <option value="24">24 Stunden</option>
              <option value="48">48 Stunden</option>
              <option value="72">72 Stunden</option>
              <option value="168">7 Tage</option>
            </select>
          </div>

          <div>
            <label for="piholeHostnameV78">
              LXC Hostname
            </label>
            <input
              id="piholeHostnameV78"
              type="text"
              maxlength="63"
              value="pihole"
            >
          </div>

          <div>
            <label for="piholeCtidV78">
              Feste CT-ID
            </label>
            <input
              id="piholeCtidV78"
              type="number"
              min="100"
              step="1"
              placeholder="z. B. 200"
            >
          </div>

          <div class="full">
            <label for="piholeDbPathV78">
              Pi-hole FTL-Datenbank im LXC
            </label>
            <input
              id="piholeDbPathV78"
              type="text"
              value="/opt/pihole/etc-pihole/pihole-FTL.db"
            >
          </div>
        </div>

        <div
          id="piholeTestResultV78"
          class="piholeStatusV78"
        >
          Noch nicht getestet.
        </div>

        <div
          id="piholeMessageV78"
          class="msg"
        ></div>

        <div class="modalButtons piholeButtonsV78">
          <button
            type="button"
            onclick="testPiholeSettingsV78()"
          >
            Verbindung testen
          </button>

          <button
            id="piholeSaveButtonV78"
            type="button"
            onclick="savePiholeSettingsV78()"
          >
            Speichern & anwenden
          </button>
        </div>
      </div>
    </div>
'''

    html = (
        html[:layout_panel.start()]
        + pihole_panel
        + "\n"
        + html[layout_panel.start():]
    )

    css = r'''
/* PVE_PIHOLE_SETTINGS_UI_V78 */
.piholeSettingsV78{
  width:100%;
}
.piholeToggleV78{
  margin:10px 0 14px;
  padding:10px 12px;
  border:1px solid var(--line);
  border-radius:10px;
  background:#0a1320;
}
.piholeToggleV78 label{
  display:flex;
  align-items:center;
  gap:8px;
  color:#eef5ff;
  font-size:12px;
  font-weight:750;
}
.piholeToggleV78 input{
  width:auto;
  margin:0;
}
.piholeStatusV78{
  margin-top:14px;
  padding:11px 12px;
  border:1px solid #2a405a;
  border-radius:10px;
  background:#09131f;
  color:#aebed3;
  font-size:12px;
  line-height:1.55;
  white-space:pre-line;
}
.piholeStatusV78.ok{
  border-color:#2e6244;
}
.piholeStatusV78.err{
  border-color:#7f3840;
}
.piholeButtonsV78{
  margin-top:12px;
  padding-top:12px;
  border-top:1px solid var(--line);
}
'''

    if "</style>" not in html:
        raise SystemExit(
            "FEHLER: </style> fehlt."
        )

    html = html.replace(
        "</style>",
        css + "\n</style>",
        1,
    )

    js = r'''
/* PVE_PIHOLE_SETTINGS_UI_V78 */

let piholeSettingsV78=null;

function piholeMessageV78(
  text,
  kind=''
){
  const el=$(
    'piholeMessageV78'
  );

  if(!el)return;

  el.textContent=text;
  el.className=
    `msg ${kind}`.trim();
}

function piholeResultV78(
  text,
  kind=''
){
  const el=$(
    'piholeTestResultV78'
  );

  if(!el)return;

  el.textContent=text;
  el.className=
    `piholeStatusV78 ${kind}`.trim();
}

function piholePayloadV78(){
  return {
    code:settingsSessionCode,
    enabled:
      $('piholeEnabledV78')?.checked
      ??true,
    mode:
      $('piholeModeV78')?.value
      ||'auto',
    hostname:
      $('piholeHostnameV78')?.value
      ||'pihole',
    ctid:
      $('piholeCtidV78')?.value
      ||'',
    db_path:
      $('piholeDbPathV78')?.value
      ||'/opt/pihole/etc-pihole/pihole-FTL.db',
    hours:Number(
      $('piholeHoursV78')?.value
      ||24
    )
  };
}

function applyPiholeSettingsV78(
  settings
){
  piholeSettingsV78=settings||{};

  $('piholeEnabledV78').checked=
    settings.enabled!==false;

  $('piholeModeV78').value=
    settings.mode||'auto';

  $('piholeHostnameV78').value=
    settings.hostname||'pihole';

  $('piholeCtidV78').value=
    settings.ctid||'';

  $('piholeDbPathV78').value=
    settings.db_path
    ||'/opt/pihole/etc-pihole/pihole-FTL.db';

  $('piholeHoursV78').value=
    String(
      settings.hours||24
    );

  updatePiholeModeV78();
}

function updatePiholeModeV78(){
  const fixed=
    $('piholeModeV78')?.value
    ==='ctid';

  if($('piholeCtidV78')){
    $('piholeCtidV78').disabled=
      !fixed;
  }

  if($('piholeHostnameV78')){
    $('piholeHostnameV78').disabled=
      fixed;
  }
}

async function loadPiholeSettingsV78(){
  if(!settingsSessionCode){
    return;
  }

  piholeMessageV78(
    'Pi-hole Einstellungen werden geladen ...'
  );

  try{
    const data=await getJSON(
      '/api/pihole/settings/read',
      {
        method:'POST',
        headers:{
          'Content-Type':'application/json'
        },
        body:JSON.stringify({
          code:settingsSessionCode
        })
      }
    );

    applyPiholeSettingsV78(
      data.settings
    );

    piholeMessageV78(
      '',
      ''
    );

  }catch(e){
    piholeMessageV78(
      e.message,
      'err'
    );
  }
}

function renderPiholeTestV78(
  result
){
  if(result.enabled===false){
    piholeResultV78(
      'Pi-hole Dashboard-Datenquelle ist deaktiviert.',
      'ok'
    );
    return;
  }

  const total=
    result.queries_total==null
      ? '–'
      : Number(
          result.queries_total
        ).toLocaleString('de-DE');

  const blocked=
    result.queries_blocked==null
      ? '–'
      : Number(
          result.queries_blocked
        ).toLocaleString('de-DE');

  const pct=
    result.blocked_percent==null
      ? '–'
      : Number(
          result.blocked_percent
        ).toLocaleString(
          'de-DE',
          {
            minimumFractionDigits:1,
            maximumFractionDigits:2
          }
        )+' %';

  piholeResultV78(
    `Verbindung OK
CT: ${result.ctid||'–'} · IP: ${result.ip||'–'}
LXC: ${result.running?'läuft':'nicht aktiv'}
Zeitraum: ${result.hours||'–'} h
Anfragen: ${total}
Geblockt: ${blocked} (${pct})
DB: ${result.db_path||'–'}`,
    'ok'
  );
}

async function testPiholeSettingsV78(){
  if(!settingsSessionCode){
    return requestSettingsUnlock(
      'links'
    );
  }

  piholeMessageV78(
    'Pi-hole Verbindung wird getestet ...'
  );

  piholeResultV78(
    'Test läuft ...'
  );

  try{
    const data=await getJSON(
      '/api/pihole/settings/test',
      {
        method:'POST',
        headers:{
          'Content-Type':'application/json'
        },
        body:JSON.stringify(
          piholePayloadV78()
        )
      }
    );

    renderPiholeTestV78(
      data.result
    );

    piholeMessageV78(
      'Test erfolgreich.',
      'ok'
    );

  }catch(e){
    piholeResultV78(
      e.message,
      'err'
    );

    piholeMessageV78(
      'Pi-hole Test fehlgeschlagen.',
      'err'
    );
  }
}

async function savePiholeSettingsV78(){
  if(!settingsSessionCode){
    return requestSettingsUnlock(
      'links'
    );
  }

  const button=$(
    'piholeSaveButtonV78'
  );

  if(button){
    button.disabled=true;
  }

  piholeMessageV78(
    'Pi-hole Einstellungen werden gespeichert ...'
  );

  try{
    const data=await getJSON(
      '/api/pihole/settings/save',
      {
        method:'POST',
        headers:{
          'Content-Type':'application/json'
        },
        body:JSON.stringify(
          piholePayloadV78()
        )
      }
    );

    applyPiholeSettingsV78(
      data.settings
    );

    piholeMessageV78(
      'Gespeichert. Der Collector übernimmt die Einstellung beim nächsten Lauf.',
      'ok'
    );

    await testPiholeSettingsV78();

  }catch(e){
    piholeMessageV78(
      e.message,
      'err'
    );

  }finally{
    if(button){
      button.disabled=false;
    }
  }
}

$('piholeModeV78')?.addEventListener(
  'change',
  updatePiholeModeV78
);

const piholeLegacySwitchUnifiedSettingsTabV78=
  typeof switchUnifiedSettingsTab==='function'
    ? switchUnifiedSettingsTab
    : null;

switchUnifiedSettingsTab=async function(tab){
  if(tab==='pihole'){
    if(!settingsSessionCode){
      return requestSettingsUnlock(
        'links'
      );
    }

    [
      'settingsHubTabLinks',
      'settingsHubTabCategories',
      'settingsHubTabUps',
      'settingsHubTabLayout',
      'settingsHubTabDashboard'
    ].forEach(id=>{
      const el=$(id);

      if(!el)return;

      el.classList.remove(
        'active'
      );

      el.setAttribute(
        'aria-selected',
        'false'
      );
    });

    [
      'settingsHubPanelLinks',
      'settingsHubPanelCategories',
      'settingsHubPanelUps',
      'settingsHubPanelLayout',
      'settingsHubPanelDashboard'
    ].forEach(id=>{
      $(id)?.classList.remove(
        'active'
      );
    });

    $('settingsHubTabPihole')?.classList.add(
      'active'
    );

    $('settingsHubTabPihole')?.setAttribute(
      'aria-selected',
      'true'
    );

    $('settingsHubPanelPihole')?.classList.add(
      'active'
    );

    await loadPiholeSettingsV78();

    return;
  }

  $('settingsHubTabPihole')?.classList.remove(
    'active'
  );

  $('settingsHubTabPihole')?.setAttribute(
    'aria-selected',
    'false'
  );

  $('settingsHubPanelPihole')?.classList.remove(
    'active'
  );

  if(piholeLegacySwitchUnifiedSettingsTabV78){
    return await piholeLegacySwitchUnifiedSettingsTabV78(
      tab
    );
  }
};
'''

    script_end = html.rfind(
        "</script>"
    )

    if script_end < 0:
        raise SystemExit(
            "FEHLER: </script> fehlt."
        )

    html = (
        html[:script_end]
        + js
        + "\n"
        + html[script_end:]
    )

path.write_text(
    html,
    encoding="utf-8",
)

required = [
    MARKER,
    'id="settingsHubTabPihole"',
    'id="settingsHubPanelPihole"',
    'id="piholeEnabledV78"',
    'id="piholeModeV78"',
    'id="piholeHoursV78"',
    'id="piholeHostnameV78"',
    'id="piholeCtidV78"',
    'id="piholeDbPathV78"',
    'loadPiholeSettingsV78',
    'testPiholeSettingsV78',
    'savePiholeSettingsV78',
]

for marker in required:
    if marker not in html:
        raise SystemExit(
            f"FEHLER: Frontend-Marker fehlt: {marker}"
        )

print("[OK] Pi-hole Reiter und Oberfläche V78 eingebaut.")
PY

chown root:root "$INDEX"
chmod 644 "$INDEX"

# ---------------------------------------------------------------------------
# 7. Validate
# ---------------------------------------------------------------------------

python3 -m py_compile \
    "$COLLECTOR" \
    "$APP" \
    "$HELPER"

grep -Fq "PVE_PIHOLE_COLLECTOR_SETTINGS_V78" "$COLLECTOR"
grep -Fq "PVE_PIHOLE_SETTINGS_API_V78" "$APP"
grep -Fq "PVE_PIHOLE_SETTINGS_UI_V78" "$INDEX"
grep -Fq 'id="settingsHubTabPihole"' "$INDEX"

systemctl restart pve-sensor-web.service
systemctl start pve-sensor-collector.service 2>/dev/null || true

nginx -t
systemctl reload nginx

sleep 3

echo
echo "===== PI-HOLE TEST MIT AKTUELLER KONFIGURATION ====="

"$HELPER" test |
python3 -m json.tool || true

trap - ERR

echo
echo "============================================================"
echo " FERTIG"
echo "============================================================"
echo
echo "Dashboard:"
echo "  Einstellungen"
echo "  -> Webseitenverwaltung"
echo "  -> Kategorien"
echo "  -> USV"
echo "  -> Pi-hole"
echo "  -> Layout"
echo "  -> Dashboard"
echo
echo "Konfiguration:"
echo "  $CONFIG"
echo
echo "Backup:"
echo "  $BACKUP"
echo
echo "Log:"
echo "  $LOGFILE"
__PVE_DASHBOARD_PIHOLE_V78__

    chmod +x "$patch"
    "$patch"
    rm -f "$patch"
}


# =============================================================================
# V80 · PI-HOLE SETTINGS-TAB SAUBER VOM WEBSEITEN-TAB TRENNEN
# =============================================================================

install_dashboard_pihole_menu_fix_v80() {
    header "DASHBOARD · PI-HOLE MENÜ-TRENNUNG V80"

    local patch="/tmp/pve-dashboard-pihole-menu-v80.$$"

    cat > "$patch" <<'__PVE_DASHBOARD_PIHOLE_MENU_V80__'
#!/usr/bin/env bash
set -Eeuo pipefail

INDEX="/opt/nodezero/dashboard/static/index.html"
BACKUP="/root/backups/pve-dashboard-pihole-menu-v80-$(date +%Y%m%d-%H%M%S)"
STAMP="$(date +%d-%m-%H-%M)"
LOG="/root/diagnose/diagnose-dashboard-pihole-menu-v80-${STAMP}.txt"

if [[ -e "$LOG" ]]; then
    N=2
    while [[ -e "/root/diagnose/diagnose-dashboard-pihole-menu-v80-${STAMP}-${N}.txt" ]]; do
        N=$((N + 1))
    done
    LOG="/root/diagnose/diagnose-dashboard-pihole-menu-v80-${STAMP}-${N}.txt"
fi

exec > >(tee -a "$LOG") 2>&1

[[ ${EUID:-$(id -u)} -eq 0 ]] || {
    echo "FEHLER: Bitte als root ausführen."
    exit 1
}

[[ -f "$INDEX" ]] || {
    echo "FEHLER: $INDEX fehlt."
    exit 1
}

grep -Fq 'id="settingsHubTabPihole"' "$INDEX" || {
    echo "FEHLER: Pi-hole Reiter V78 fehlt."
    exit 1
}

grep -Fq 'id="settingsHubPanelPihole"' "$INDEX" || {
    echo "FEHLER: Pi-hole Panel V78 fehlt."
    exit 1
}

mkdir -p "$BACKUP"
cp -a "$INDEX" "$BACKUP/index.html"

rollback() {
    echo
    echo "AUTOMATISCHES ROLLBACK"
    cp -a "$BACKUP/index.html" "$INDEX"
    chown root:root "$INDEX"
    chmod 644 "$INDEX"
    systemctl restart pve-sensor-web.service 2>/dev/null || true
    nginx -t >/dev/null 2>&1 && systemctl reload nginx 2>/dev/null || true
}

trap 'echo "FEHLER in Zeile $LINENO"; rollback' ERR

python3 - "$INDEX" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
html = path.read_text(encoding="utf-8")

MARKER = "PVE_PIHOLE_MENU_ISOLATION_V80"

if MARKER not in html:
    css = r'''
/* PVE_PIHOLE_MENU_ISOLATION_V80 */
#settingsHubModal .settingsHubPanel{
  display:none !important;
}
#settingsHubModal .settingsHubPanel.active{
  display:block !important;
}
#settingsHubPanelPihole{
  width:100%;
}
'''

    if "</style>" not in html:
        raise SystemExit("FEHLER: </style> fehlt.")

    html = html.replace(
        "</style>",
        css + "\n</style>",
        1,
    )

    js = r'''
/* PVE_PIHOLE_MENU_ISOLATION_V80 */

function normalizePiholeSettingsPanelV80(){
  const modal=$('settingsHubModal');
  const pihole=$('settingsHubPanelPihole');
  const layout=$('settingsHubPanelLayout');
  const dashboard=$('settingsHubPanelDashboard');

  if(!modal||!pihole){
    return false;
  }

  const dialog=modal.querySelector(
    '.settingsHubDialog'
  );

  if(!dialog){
    return false;
  }

  if(pihole.parentElement!==dialog){
    if(layout && layout.parentElement===dialog){
      dialog.insertBefore(
        pihole,
        layout
      );
    }else if(
      dashboard
      && dashboard.parentElement===dialog
    ){
      dialog.insertBefore(
        pihole,
        dashboard
      );
    }else{
      dialog.appendChild(
        pihole
      );
    }
  }

  return true;
}

function setExclusiveSettingsTabV80(wanted){
  normalizePiholeSettingsPanelV80();

  const tabs={
    links:'settingsHubTabLinks',
    categories:'settingsHubTabCategories',
    ups:'settingsHubTabUps',
    pihole:'settingsHubTabPihole',
    layout:'settingsHubTabLayout',
    dashboard:'settingsHubTabDashboard'
  };

  const panels={
    links:'settingsHubPanelLinks',
    categories:'settingsHubPanelCategories',
    ups:'settingsHubPanelUps',
    pihole:'settingsHubPanelPihole',
    layout:'settingsHubPanelLayout',
    dashboard:'settingsHubPanelDashboard'
  };

  Object.entries(tabs).forEach(([name,id])=>{
    const el=$(id);
    if(!el)return;

    const active=name===wanted;
    el.classList.toggle('active',active);
    el.setAttribute('aria-selected',String(active));
  });

  Object.entries(panels).forEach(([name,id])=>{
    const el=$(id);
    if(!el)return;

    const active=name===wanted;
    el.classList.toggle('active',active);
    el.style.display=active ? 'block' : 'none';
  });
}

const piholeMenuLegacySwitchV80=
  typeof switchUnifiedSettingsTab==='function'
    ? switchUnifiedSettingsTab
    : null;

switchUnifiedSettingsTab=async function(tab){
  if(tab==='pihole'){
    if(!settingsSessionCode){
      return requestSettingsUnlock('links');
    }

    setExclusiveSettingsTabV80('pihole');

    if(typeof loadPiholeSettingsV78==='function'){
      await loadPiholeSettingsV78();
    }

    return;
  }

  normalizePiholeSettingsPanelV80();

  const piholeTab=$('settingsHubTabPihole');
  const piholePanel=$('settingsHubPanelPihole');

  if(piholeTab){
    piholeTab.classList.remove('active');
    piholeTab.setAttribute('aria-selected','false');
  }

  if(piholePanel){
    piholePanel.classList.remove('active');
    piholePanel.style.display='none';
  }

  if(piholeMenuLegacySwitchV80){
    const result=await piholeMenuLegacySwitchV80(tab);

    if(
      ['links','categories','ups','layout','dashboard'].includes(tab)
    ){
      setExclusiveSettingsTabV80(tab);
    }

    return result;
  }
};

setTimeout(()=>{
  normalizePiholeSettingsPanelV80();

  if(
    !$('settingsHubTabPihole')?.classList.contains('active')
  ){
    const panel=$('settingsHubPanelPihole');

    if(panel){
      panel.classList.remove('active');
      panel.style.display='none';
    }
  }
},0);
'''

    script_end = html.rfind("</script>")

    if script_end < 0:
        raise SystemExit("FEHLER: </script> fehlt.")

    html = (
        html[:script_end]
        + js
        + "\n"
        + html[script_end:]
    )

path.write_text(
    html,
    encoding="utf-8",
)

for marker in (
    MARKER,
    "normalizePiholeSettingsPanelV80",
    "setExclusiveSettingsTabV80",
    "piholeMenuLegacySwitchV80",
):
    if marker not in html:
        raise SystemExit(
            f"FEHLER: Marker fehlt: {marker}"
        )

print("[OK] Pi-hole Menü-Isolation V80 eingebaut.")
PY

chown root:root "$INDEX"
chmod 644 "$INDEX"

grep -Fq "PVE_PIHOLE_MENU_ISOLATION_V80" "$INDEX"
grep -Fq "normalizePiholeSettingsPanelV80" "$INDEX"
grep -Fq "setExclusiveSettingsTabV80" "$INDEX"

systemctl restart pve-sensor-web.service
nginx -t
systemctl reload nginx

trap - ERR

echo
echo "============================================================"
echo " PI-HOLE MENÜ-TRENNUNG V80 FERTIG"
echo "============================================================"
echo
echo "Der Pi-hole-Reiter ist jetzt ein eigenständiger Settings-Bereich."
echo "Webseitenverwaltung und Pi-hole können nicht mehr gleichzeitig sichtbar sein."
echo
echo "Backup:"
echo "  $BACKUP"
echo
echo "Log:"
echo "  $LOG"
__PVE_DASHBOARD_PIHOLE_MENU_V80__

    chmod +x "$patch"
    "$patch"
    rm -f "$patch"
}


# =============================================================================
# V81 · SETTINGS-PANELS ALS ECHTE GESCHWISTER NORMALISIEREN
# =============================================================================

install_dashboard_settings_panels_host_v81() {
    header "DASHBOARD · SETTINGS-PANEL-HOST V81"

    local patch="/tmp/pve-dashboard-settings-panels-v81.$$"

    cat > "$patch" <<'__PVE_DASHBOARD_SETTINGS_PANELS_V81__'
#!/usr/bin/env bash
set -Eeuo pipefail

INDEX="/opt/nodezero/dashboard/static/index.html"
BACKUP="/root/backups/pve-dashboard-settings-panels-v81-$(date +%Y%m%d-%H%M%S)"
STAMP="$(date +%d-%m-%H-%M)"
LOG="/root/diagnose/diagnose-dashboard-settings-panels-v81-${STAMP}.txt"

if [[ -e "$LOG" ]]; then
    N=2
    while [[ -e "/root/diagnose/diagnose-dashboard-settings-panels-v81-${STAMP}-${N}.txt" ]]; do
        N=$((N + 1))
    done
    LOG="/root/diagnose/diagnose-dashboard-settings-panels-v81-${STAMP}-${N}.txt"
fi

exec > >(tee -a "$LOG") 2>&1

[[ ${EUID:-$(id -u)} -eq 0 ]] || {
    echo "FEHLER: Bitte als root ausführen."
    exit 1
}

[[ -f "$INDEX" ]] || {
    echo "FEHLER: $INDEX fehlt."
    exit 1
}

for id in \
    settingsHubPanelLinks \
    settingsHubPanelCategories \
    settingsHubPanelUps \
    settingsHubPanelPihole \
    settingsHubPanelLayout \
    settingsHubPanelDashboard
do
    grep -Fq "id=\"$id\"" "$INDEX" || {
        echo "FEHLER: $id fehlt."
        exit 1
    }
done

mkdir -p "$BACKUP"
cp -a "$INDEX" "$BACKUP/index.html"

rollback() {
    echo
    echo "AUTOMATISCHES ROLLBACK"
    cp -a "$BACKUP/index.html" "$INDEX"
    chown root:root "$INDEX"
    chmod 644 "$INDEX"
    systemctl restart pve-sensor-web.service 2>/dev/null || true
    nginx -t >/dev/null 2>&1 && systemctl reload nginx 2>/dev/null || true
}

trap 'echo "FEHLER in Zeile $LINENO"; rollback' ERR

python3 - "$INDEX" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
html = path.read_text(encoding="utf-8")

MARKER = "PVE_SETTINGS_PANELS_HOST_V81"

if MARKER not in html:
    css = r'''
/* PVE_SETTINGS_PANELS_HOST_V81 */
#settingsHubPanelsHostV81{
  width:100%;
}
#settingsHubPanelsHostV81 > .settingsHubPanel{
  display:none !important;
  width:100%;
}
#settingsHubPanelsHostV81 > .settingsHubPanel.active{
  display:block !important;
}
'''

    if "</style>" not in html:
        raise SystemExit("FEHLER: </style> fehlt.")

    html = html.replace(
        "</style>",
        css + "\n</style>",
        1,
    )

    js = r'''
/* PVE_SETTINGS_PANELS_HOST_V81 */

const SETTINGS_TABS_V81=[
  'links',
  'categories',
  'ups',
  'pihole',
  'layout',
  'dashboard'
];

const SETTINGS_TAB_IDS_V81={
  links:'settingsHubTabLinks',
  categories:'settingsHubTabCategories',
  ups:'settingsHubTabUps',
  pihole:'settingsHubTabPihole',
  layout:'settingsHubTabLayout',
  dashboard:'settingsHubTabDashboard'
};

const SETTINGS_PANEL_IDS_V81={
  links:'settingsHubPanelLinks',
  categories:'settingsHubPanelCategories',
  ups:'settingsHubPanelUps',
  pihole:'settingsHubPanelPihole',
  layout:'settingsHubPanelLayout',
  dashboard:'settingsHubPanelDashboard'
};

function ensureSettingsPanelsHostV81(){
  const modal=$('settingsHubModal');

  if(!modal){
    return null;
  }

  const dialog=modal.querySelector(
    '.settingsHubDialog'
  );

  const tabs=dialog?.querySelector(
    '.settingsHubTabs'
  );

  if(!dialog||!tabs){
    return null;
  }

  let host=$(
    'settingsHubPanelsHostV81'
  );

  if(!host){
    host=document.createElement(
      'div'
    );

    host.id=
      'settingsHubPanelsHostV81';

    host.setAttribute(
      'data-v81',
      'settings-panels-host'
    );

    tabs.insertAdjacentElement(
      'afterend',
      host
    );
  }

  /*
   * Entscheidend: ALLE Settings-Panels werden aus eventuell
   * verschachtelten Alt-Strukturen herausgenommen und in einer
   * festen Reihenfolge als direkte Geschwister in den Host gelegt.
   * appendChild verschiebt bestehende DOM-Knoten samt Inhalt und
   * Event-Handlern, es wird nichts dupliziert.
   */
  SETTINGS_TABS_V81.forEach(
    name=>{
      const panel=$(
        SETTINGS_PANEL_IDS_V81[name]
      );

      if(
        panel
        && panel.parentElement!==host
      ){
        host.appendChild(
          panel
        );
      }
    }
  );

  return host;
}

function activateSettingsPanelV81(
  wanted
){
  if(
    !SETTINGS_TABS_V81.includes(
      wanted
    )
  ){
    wanted='links';
  }

  ensureSettingsPanelsHostV81();

  SETTINGS_TABS_V81.forEach(
    name=>{
      const active=
        name===wanted;

      const tab=$(
        SETTINGS_TAB_IDS_V81[name]
      );

      const panel=$(
        SETTINGS_PANEL_IDS_V81[name]
      );

      if(tab){
        tab.classList.toggle(
          'active',
          active
        );

        tab.setAttribute(
          'aria-selected',
          String(active)
        );
      }

      if(panel){
        panel.classList.toggle(
          'active',
          active
        );

        panel.style.display=
          active
            ? 'block'
            : 'none';
      }
    }
  );
}

const settingsSwitchBeforeV81=
  typeof switchUnifiedSettingsTab==='function'
    ? switchUnifiedSettingsTab
    : null;

switchUnifiedSettingsTab=async function(tab){
  const wanted=
    SETTINGS_TABS_V81.includes(tab)
      ? tab
      : 'links';

  if(
    !settingsSessionCode
    && typeof requestSettingsUnlock==='function'
  ){
    return requestSettingsUnlock(
      wanted
    );
  }

  /*
   * Zuerst Struktur korrigieren, dann alten Loader ausführen.
   * Alte Wrapper dürfen Daten laden, aber nicht mehr dauerhaft
   * mehrere Panels sichtbar lassen.
   */
  ensureSettingsPanelsHostV81();

  if(settingsSwitchBeforeV81){
    try{
      await settingsSwitchBeforeV81(
        wanted
      );
    }catch(e){
      console.error(
        'Settings Legacy-Tabfehler:',
        e
      );
    }
  }

  activateSettingsPanelV81(
    wanted
  );

  /*
   * Einige ältere Wrapper arbeiten asynchron weiter.
   * Ein zweiter exklusiver Schaltlauf im nächsten Event-Loop
   * verhindert, dass USV/Pi-hole/Layout danach wieder gemeinsam
   * eingeblendet werden.
   */
  setTimeout(
    ()=>activateSettingsPanelV81(
      wanted
    ),
    0
  );
};

const settingsOpenBeforeV81=
  typeof openUnifiedSettings==='function'
    ? openUnifiedSettings
    : null;

openUnifiedSettings=async function(tab='links'){
  const wanted=
    SETTINGS_TABS_V81.includes(tab)
      ? tab
      : 'links';

  ensureSettingsPanelsHostV81();

  if(settingsOpenBeforeV81){
    try{
      await settingsOpenBeforeV81(
        wanted
      );
    }catch(e){
      console.error(
        'Settings Legacy-Openfehler:',
        e
      );
    }
  }else{
    $('settingsHubModal')?.classList.add(
      'show'
    );
  }

  activateSettingsPanelV81(
    wanted
  );

  setTimeout(
    ()=>activateSettingsPanelV81(
      wanted
    ),
    0
  );
};

function settingsPanelsV81SelfCheck(){
  const host=
    ensureSettingsPanelsHostV81();

  if(!host){
    return false;
  }

  return SETTINGS_TABS_V81.every(
    name=>{
      const panel=$(
        SETTINGS_PANEL_IDS_V81[name]
      );

      return (
        panel
        && panel.parentElement===host
      );
    }
  );
}

setTimeout(
  ()=>{
    ensureSettingsPanelsHostV81();

    const activeTab=
      SETTINGS_TABS_V81.find(
        name=>
          $(
            SETTINGS_TAB_IDS_V81[name]
          )?.classList.contains(
            'active'
          )
      )
      ||'links';

    activateSettingsPanelV81(
      activeTab
    );
  },
  0
);
'''

    script_end = html.rfind(
        "</script>"
    )

    if script_end < 0:
        raise SystemExit(
            "FEHLER: </script> fehlt."
        )

    html = (
        html[:script_end]
        + js
        + "\n"
        + html[script_end:]
    )

path.write_text(
    html,
    encoding="utf-8",
)

for marker in (
    MARKER,
    "ensureSettingsPanelsHostV81",
    "activateSettingsPanelV81",
    "settingsPanelsV81SelfCheck",
):
    if marker not in html:
        raise SystemExit(
            f"FEHLER: Frontend-Marker fehlt: {marker}"
        )

print("[OK] Settings Panel-Host V81 eingebaut.")
PY

chown root:root "$INDEX"
chmod 644 "$INDEX"

grep -Fq "PVE_SETTINGS_PANELS_HOST_V81" "$INDEX"
grep -Fq "ensureSettingsPanelsHostV81" "$INDEX"
grep -Fq "activateSettingsPanelV81" "$INDEX"

systemctl restart pve-sensor-web.service
nginx -t
systemctl reload nginx

trap - ERR

echo
echo "============================================================"
echo " SETTINGS-PANEL-HOST V81 FERTIG"
echo "============================================================"
echo
echo "Alle sechs Settings-Bereiche werden jetzt als echte"
echo "Geschwister-Panels in einem gemeinsamen Host geführt."
echo
echo "Reihenfolge:"
echo "  Webseitenverwaltung"
echo "  Kategorien"
echo "  USV"
echo "  Pi-hole"
echo "  Layout"
echo "  Dashboard"
echo
echo "Backup:"
echo "  $BACKUP"
echo
echo "Log:"
echo "  $LOG"
__PVE_DASHBOARD_SETTINGS_PANELS_V81__

    chmod +x "$patch"
    "$patch"
    rm -f "$patch"
}

# =============================================================================
# V69 · DASHBOARD FINALEN UI-STAND PRÜFEN
# =============================================================================

validate_dashboard_final_state_v69() {
    local index="/opt/nodezero/dashboard/static/index.html"
    local app="/opt/nodezero/dashboard/app.py"
    local marker=""
    local failed=0

    [[ -f "$index" ]] || {
        warn "Dashboard Finalprüfung: index.html fehlt."
        return 1
    }

    [[ -f "$app" ]] || {
        warn "Dashboard Finalprüfung: app.py fehlt."
        return 1
    }

    local index_markers=(
        'id="dashboardSettingsHubButton"'
        'id="dashboardGithubLink"'
        'PVE_SETTINGS_MENU_VISIBILITY_V133'
        'id="themeBg"'
        'PVE_CATEGORY_UI_TEST_V1'
        'PVE_CATEGORY_ASSIGNMENT_FIX_V2'
        'id="settingsHubTabCategories"'
        'id="settingsHubTabUps"'
        'PVE_UPS_UI_FIX_V3'
        'SETTINGS_REMEMBER_KEY'
        'PVE_DASHBOARD_LAYOUT_UI_V71'
        'id="settingsHubTabLayout"'
        'PVE_PIHOLE_SETTINGS_UI_V78'
        'id="settingsHubTabPihole"'
        'PVE_PIHOLE_MENU_ISOLATION_V80'
        'PVE_SETTINGS_PANELS_HOST_V81'
    )

    for marker in "${index_markers[@]}"; do
        if ! grep -Fq "$marker" "$index"; then
            warn "Dashboard Finalprüfung fehlt: $marker"
            failed=1
        fi
    done

    grep -Fq '"theme_bg"' "$app" || {
        warn "Dashboard Finalprüfung: Theme-API theme_bg fehlt."
        failed=1
    }

    grep -Fq 'PVE_UPS_SETTINGS_V2' "$app" || {
        warn "Dashboard Finalprüfung: PVE_UPS_SETTINGS_V2 fehlt."
        failed=1
    }

    grep -Fq 'PVE_DASHBOARD_LAYOUT_API_V71' "$app" || {
        warn "Dashboard Finalprüfung: Layout API V71 fehlt."
        failed=1
    }

    grep -Fq 'PVE_PIHOLE_SETTINGS_API_V78' "$app" || {
        warn "Dashboard Finalprüfung: Pi-hole Settings API V78 fehlt."
        failed=1
    }

    grep -Fq 'PVE_PIHOLE_COLLECTOR_SETTINGS_V78' /opt/nodezero/dashboard/collector.py || {
        warn "Dashboard Finalprüfung: Pi-hole Collector V78 fehlt."
        failed=1
    }

    (( failed == 0 )) || return 1

    ok "Dashboard UI vollständig: Einstellungen · Kategorien · USV · Pi-hole · Layout · Login-Session"
    return 0
}

# =============================================================================
# V95 · DASHBOARD-KURZPFAD /usv
# =============================================================================
# PVE-UPS bleibt als eigenständige Webanwendung auf seiner eigenen IP/443.
# /usv wird absichtlich NICHT als Subpath-Reverse-Proxy betrieben, weil
# absolute Asset-/API-Pfade und spätere App-Updates dadurch brechen können.
# Stattdessen liefert das Dashboard einen robusten Redirect auf PVE-UPS.

install_dashboard_usv_shortcut_v95() {
    (( PVEUPS_INSTALLED )) || return 0

    local site="/etc/nginx/sites-available/pve-sensor-dashboard"
    local target="https://${PVEUPS_IP}/"

    [[ -f "$site" ]] || {
        warn "Dashboard nginx-Konfiguration fehlt; /usv-Kurzpfad wird übersprungen."
        return 0
    }

    python3 - "$site" "$target" <<'PYUSVSHORTCUT'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
target = sys.argv[2]
text = path.read_text(encoding="utf-8")

begin = "    # NODEZERO-USV-SHORTCUT-V95-BEGIN\n"
end = "    # NODEZERO-USV-SHORTCUT-V95-END\n"

# Alte verwaltete Version entfernen, damit IP-Änderungen sauber übernommen werden.
text = re.sub(
    r"    # NODEZERO-USV-SHORTCUT-V95-BEGIN\n.*?    # NODEZERO-USV-SHORTCUT-V95-END\n\n?",
    "",
    text,
    flags=re.S,
)

block = (
    begin
    + "    location = /usv {\n"
    + f"        return 302 {target};\n"
    + "    }\n\n"
    + "    location = /usv/ {\n"
    + f"        return 302 {target};\n"
    + "    }\n"
    + end
    + "\n"
)

# In den HTTPS-Server einfügen. Nach TLS-Konfiguration existiert dort der
# normale Dashboard-Proxy 'location /'. Wir nehmen den letzten Treffer, damit
# bei einer optionalen HTTP-Proxy-Konfiguration sicher HTTPS modifiziert wird.
needle = "    location / {\n"
pos = text.rfind(needle)
if pos < 0:
    raise SystemExit("Dashboard nginx: location / nicht gefunden")

text = text[:pos] + block + text[pos:]
path.write_text(text, encoding="utf-8")
PYUSVSHORTCUT

    nginx -t || die "Dashboard /usv nginx-Konfiguration ist ungültig."
    systemctl reload nginx

    ok "Dashboard-Kurzpfad aktiv: https://${DASHBOARD_IP}/usv -> ${target}"
}

count_install_steps() {
    local total=1

    # Subscription-WebUI-Anpassung.
    # Zusätzlich zählt jede tatsächlich ausgewählte Hauptkomponente.
    (( INSTALL_DASHBOARD )) && total=$((total + 2))
    (( INSTALL_HA )) && total=$((total + 1))
    (( INSTALL_PAPERLESS )) && total=$((total + 1))
    (( INSTALL_PIHOLE )) && total=$((total + 1))
    (( INSTALL_NETALERTX )) && total=$((total + 1))
    (( INSTALL_UPTIME )) && total=$((total + 1))
    (( INSTALL_VAULTWARDEN )) && total=$((total + 1))
    (( INSTALL_CADDY )) && total=$((total + 1))
    (( INSTALL_STIRLING )) && total=$((total + 1))
    (( INSTALL_NTFY )) && total=$((total + 1))
    (( INSTALL_FORGEJO )) && total=$((total + 1))
    (( INSTALL_SYNCTHING )) && total=$((total + 1))
    (( INSTALL_SPEEDTEST )) && total=$((total + 1))
    (( INSTALL_SCRUTINY )) && total=$((total + 1))
    (( INSTALL_MEALIE )) && total=$((total + 1))
    (( INSTALL_PBS )) && total=$((total + 1))
    (( INSTALL_PULSE )) && total=$((total + 1))
    (( INSTALL_PVEUPS )) && total=$((total + 1))
    (( INSTALL_SEMAPHORE )) && total=$((total + 1))
    (( INSTALL_POCKETID )) && total=$((total + 1))
    (( INSTALL_PROMETHEUS )) && total=$((total + 1))
    (( INSTALL_PVE_EXPORTER )) && total=$((total + 1))
    (( INSTALL_GRAFANA )) && total=$((total + 1))
    (( INSTALL_CROWDSEC )) && total=$((total + 1))
    (( INSTALL_PANGOLIN )) && total=$((total + 1))
    (( INSTALL_NEWT )) && total=$((total + 1))
    (( INSTALL_GATUS )) && total=$((total + 1))
    (( INSTALL_HOMEPAGE )) && total=$((total + 1))
    (( INSTALL_NPM )) && total=$((total + 1))
    (( INSTALL_EMQX )) && total=$((total + 1))
    (( INSTALL_OS )) && total=$((total + 1))

    # V107: eigener Installationsschritt, wenn Monitoring-Komponenten
    # tatsächlich miteinander verbunden werden.
    if (( (INSTALL_PROMETHEUS && INSTALL_PVE_EXPORTER) ||
          (INSTALL_GRAFANA && INSTALL_PROMETHEUS) )); then
        total=$((total + 1))
    fi

    if (( INSTALL_PAPERLESS || INSTALL_PIHOLE || INSTALL_NETALERTX ||
          INSTALL_UPTIME || INSTALL_VAULTWARDEN || INSTALL_CADDY || INSTALL_STIRLING ||
          INSTALL_NTFY || INSTALL_FORGEJO || INSTALL_SYNCTHING || INSTALL_SPEEDTEST ||
          INSTALL_SCRUTINY || INSTALL_MEALIE )); then
        total=$((total + 1))
    fi

    printf '%s\n' "$total"
}
