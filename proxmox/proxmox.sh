#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# PROXMOX MODULARER KOMPLETT-INSTALLER V140
# =============================================================================
# Kompaktes Hauptmenü (V107):
#   O = Optimale Installation
#   1 = Basis-Systeme
#   2 = Apps & Dienste
#   3 = Monitoring & Infrastruktur
#   4 = Automation & Security
#   5 = VMs / Betriebssysteme
#   6 = Wartung & Einstellungen
#   7 = Reset / Neuaufbau
#   I = Info / Diagnose
#
# Die bisherigen internen Aktionscodes bleiben erhalten und werden nur noch
# über die thematischen Untermenüs aufgerufen. Dadurch bleibt die bestehende
# Installationslogik unverändert.
#   V96: PVE-UPS wird bei Basis-Paket, Alles installieren und KOMPLETT NEU immer mit eingeplant
#   V104: Unbound wird nach Erzeugung der 5335-Konfiguration explizit neu gestartet und geprüft
#   V105: Pi-hole FTL-Datenbank wird vom Dashboard nur read-only geöffnet; fehlende DB wird nie erzeugt
#   V106: kompaktes, thematisch gruppiertes Hauptmenü mit Untermenüs und empfohlenen Auswahlen
#   V107: Voll-Audit, Storage-Preflight + 10% Reserve, größere Root-Disks, Secret-Dateien, Healthchecks
#   V108: finaler statischer Audit, DNS-/Storage-/Preflight-Härtung, konsistente Doku und Abschlussprüfungen
#   V109: Start-Preflight erzwingt PVE No-Subscription, deaktiviert Enterprise/PVE-Test und prüft APT vor dem Menü
#   V110: Info-Menü set -u-sicher; Ceph-Repo-Cleanup ohne APT-Warnung; OpenRGB via offizieller AppImage statt inkompatiblem Trixie-DEB
#   V111: OpenRGB-AppImage Runtime-Fix für headless Proxmox (libEGL/libGL), Runtime-Preflight vor systemd-Start
#   V112: ungültige Dateien aus APT sources.list.d werden gesichert/entfernt; Script relokalisiert sich sicher aus APT-Verzeichnis
#   V113: Pi-hole Exporter v1.2.0 im Pi-hole-LXC; Prometheus-Scrape + Healthchecks + Passwort-Sync
#   V115: Pi-hole Standardlisten fest integriert: HaGeZi Pro/TIF + Homeatic/HaGeZi Allowlisten
#   V116: Auto-Updater erst nach No-Subscription/APT-Preflight installieren; Fresh-PVE Enterprise-401 behoben
#   V117: PVE-UPS-Verfügbarkeitsfunktion vor Optimal-Preflight verschoben; Version im Hauptmenü sichtbar
#   V118: Versionsanzeige im Hauptmenü ergänzt; Installer-Version zentral auf V118 angehoben
#   V119: Docker-LXC Bootstrap quoting gehärtet; awk/sed/printf lösen kein set -u/$4 mehr aus
#   V120: Einzelne VM/LXC-Löschbestätigungen nur noch über die numerische Gast-ID
#   V121: Destruktive Textbestätigungen gekürzt: KOMPLETT NEU -> NEU, PROXMOX AUF NULL -> NULL
#   V122: Pi-hole Exporter ohne hart codierten /app-Pfad; Start über Image-CMD + BIND_ADDR/PORT
#   V123: Dashboard-Webdienst mit 30-s-Readiness-Test, DB-unabhängigem /api/info und automatischer Fehlerdiagnose
#   V124: Dashboard systemd-NAMESPACE-Fix; /var/lib/pve-sensor-dashboard-web wird vor jedem Webdienst-Start angelegt
#   V125: PVE-UPS Standardprofil aus PDF + Proxmox Benutzer pve-ups@pve, Token pve-ups, Rolle UPSPower
#   V126: Pi-hole Listenimport mit docker exec -i + Verifikation; lokale DNS-/CNAME-Einträge aus GitHub
#   V127: CNAME-DNS-Verifikation auf kanonische dig-Argumentreihenfolge korrigiert
#   V128: Dashboard-Seitenmenü um dezenten GitHub-Verweis unterhalb von Einstellungen ergänzt
#   V129: Pi-hole SQLite-Kommandos korrigiert; ungültige Option -ni vollständig entfernt
#   V130: Pi-hole Local-DNS-Sync aus Proxmox-Gästen + Dashboard; Watcher + 10-Minuten-Fallback
#   V131: Pi-hole-v6 Local DNS auf offizielles dns.hosts umgestellt; WebUI zeigt synchronisierte IP/Host-Einträge
#   V132: Dashboard-Farbschema über Einstellungen anpassbar; persistente Theme-Farben mit Live-Vorschau
#   V133: bestehende Dashboard-Installationen auf Theme-UI/API migrieren; Einstellungen/GitHub direkt sichtbar
#   V134: Dashboard-Footer wieder unten; bestehende bekannte Web-CTs beim Update automatisch als fehlende Links ergänzen
#   V135: Paperless HTTPS-Reverse-Proxy/CSRF-Konfiguration repariert; bestehende Paperless-CTs automatisch migrieren
#   V136: Paperless allauth Client-IP hinter nginx korrigiert; X-Real-IP statt HTTP_X_REAL_IP
#   V137: Paperless Neuinstallation enthält vollständige HTTPS/CSRF/allauth-Proxy-Konfiguration + Abschlussprüfung
#   V138: Paperless NAS-Inbox auf NFS per Consumer-Polling überwachen; Inbox-Zugriff bei Installation prüfen
#   V139: NodeZero-Dateilayout + externes Dashboard-Quellpaket; Secrets/Downloads/Image-Cache sauber getrennt
#   V140: vollständige Dashboard-Logik als versionsgebundenes GitHub-Modul ausgelagert
#   V98: Standardressourcen angepasst: Uptime Kuma 4/4/4, Stirling PDF 8/8/8
#   V99: Paperless NAS-Eingangsordner standardmäßig /volume1/Rechnungen/inbox
#   V101: O = Optimale Installation · kompletter Guest-Reset + fester Optimal-Stack unattended; nur NAS interaktiv
#   V101: Proxmox Gaststatus "HA-Status" wird updatefest als "PVE-Failover" angezeigt
#   V102: Paperless-NAS-Fix · /opt/paperless wird vor Compose-Push immer angelegt und validiert
#
# Dashboard:
#   - ohne Login abrufbar
#   - Neustart / Herunterfahren nur mit Steuer-Code
#   - Historie: 1h / 6h / 12h / 24h / 7 Tage / 1 Monat
#   - CPU, RAM, Swap, Load, Netzwerk, Disk-I/O, VM/LXC
#   - CPU/Mainboard/VRM/PCH/Lüfter/Laufwerk-Sensoren soweit verfügbar
#   - CPU-Package-Leistung über RAPL soweit verfügbar
#   - GPU-Leistung/Temperatur soweit verfügbar
#   - Gesamtleistung über IPMI/DCMI soweit vom Mainboard/BMC unterstützt
#
# Proxmox Host:
#   - Subscription-Hinweis automatisch entfernen
#   - Desktop- und Mobile-WebUI
#   - DPkg-Hook stellt Patch nach Paketupdates erneut her
#
# Audit-Stand: 2026-09-15 · statischer Vollscan vor Ausgabe als proxmox.sh
# Zielsystem: Proxmox VE / Debian
# =============================================================================

[[ ${EUID:-$(id -u)} -eq 0 ]] || {
    echo "FEHLER: Dieses Script muss als root auf dem Proxmox-Host ausgeführt werden."
    exit 1
}

command -v pveversion >/dev/null 2>&1 || {
    echo "FEHLER: Dies scheint kein Proxmox-VE-Host zu sein."
    exit 1
}

# V112: Ein Shell-Script gehört niemals nach /etc/apt/sources.list.d/.
# Falls proxmox.sh versehentlich dort gestartet wurde, kopieren wir uns zuerst
# an einen sicheren Ort und starten exakt dieselbe Version von dort neu.
NODEZERO_SELF_PATH="$(readlink -f -- "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")"
if [[ "$NODEZERO_SELF_PATH" == /etc/apt/sources.list.d/* ]]; then
    NODEZERO_SAFE_SCRIPT="/root/proxmox.sh"
    echo "HINWEIS: Installer liegt im APT-Quellverzeichnis: $NODEZERO_SELF_PATH"
    echo "         Kopiere ihn nach $NODEZERO_SAFE_SCRIPT und starte dort neu."
    install -m 0755 -- "$NODEZERO_SELF_PATH" "$NODEZERO_SAFE_SCRIPT"
    exec "$NODEZERO_SAFE_SCRIPT" "$@"
fi

export DEBIAN_FRONTEND=noninteractive

# -----------------------------------------------------------------------------
# V70 · geordnete Root-Ausgaben
# -----------------------------------------------------------------------------
# Backups und Diagnoseberichte sollen nicht mehr direkt /root zumüllen.
BACKUP_ROOT="/root/backups"
DIAGNOSE_ROOT="/root/diagnose"

# V139 · feste NodeZero-Dateistruktur
NODEZERO_SECRET_DIR="/root/passwort"
NODEZERO_SECRET_BACKUP_DIR="/home/passwort"
NODEZERO_DOWNLOAD_DIR="/root/downloads"
NODEZERO_IMAGE_DIR="/home/img"
NODEZERO_APP_ROOT="/opt/nodezero"

nodezero_backup_secrets_v139() {
    install -d -m 0700 -o root -g root "$NODEZERO_SECRET_DIR" "$NODEZERO_SECRET_BACKUP_DIR"

    local file=""
    while IFS= read -r -d '' file; do
        install -m 0600 -o root -g root "$file" \
            "$NODEZERO_SECRET_BACKUP_DIR/$(basename "$file")"
    done < <(find "$NODEZERO_SECRET_DIR" -maxdepth 1 -type f -print0 2>/dev/null)
}

migrate_nodezero_layout_v139() {
    install -d -m 0700 -o root -g root \
        "$BACKUP_ROOT" \
        "$DIAGNOSE_ROOT" \
        "$NODEZERO_SECRET_DIR" \
        "$NODEZERO_SECRET_BACKUP_DIR" \
        "$NODEZERO_DOWNLOAD_DIR"

    install -d -m 0755 -o root -g root \
        "$NODEZERO_IMAGE_DIR" \
        "$NODEZERO_APP_ROOT"

    # Alter permanenter Image-Cache -> neuer Standardpfad.
    if [[ -d /home/Images && ! -L /home/Images ]]; then
        if [[ -z "$(find "$NODEZERO_IMAGE_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
            rmdir "$NODEZERO_IMAGE_DIR" 2>/dev/null || true
            mv /home/Images "$NODEZERO_IMAGE_DIR"
            ln -s "$NODEZERO_IMAGE_DIR" /home/Images
            echo "  [V139] Image-Cache nach $NODEZERO_IMAGE_DIR migriert."
        else
            echo "  [V139] Hinweis: /home/Images und $NODEZERO_IMAGE_DIR existieren beide; neuer Pfad bleibt maßgeblich."
        fi
    elif [[ ! -e /home/Images ]]; then
        ln -s "$NODEZERO_IMAGE_DIR" /home/Images
    fi

    # Alte Secret-Ablage übernehmen, ohne vorhandene neue Dateien zu überschreiben.
    if [[ -d /home/passwd && ! -L /home/passwd ]]; then
        cp -an /home/passwd/. "$NODEZERO_SECRET_DIR/" 2>/dev/null || true
        cp -an /home/passwd/. "$NODEZERO_SECRET_BACKUP_DIR/" 2>/dev/null || true
    fi

    # Bestehendes Dashboard in die neue /opt/nodezero-Struktur verschieben.
    if [[ -d /opt/pve-sensor-dashboard && ! -L /opt/pve-sensor-dashboard &&
          ! -e "$NODEZERO_APP_ROOT/dashboard" ]]; then
        mv /opt/pve-sensor-dashboard "$NODEZERO_APP_ROOT/dashboard"
    fi
    if [[ ! -e /opt/pve-sensor-dashboard && -d "$NODEZERO_APP_ROOT/dashboard" ]]; then
        ln -s "$NODEZERO_APP_ROOT/dashboard" /opt/pve-sensor-dashboard
    fi

    nodezero_backup_secrets_v139
}

migrate_nodezero_layout_v139


# -----------------------------------------------------------------------------
# Farben / Helfer
# -----------------------------------------------------------------------------

if [[ -t 1 ]]; then
    BOLD=$'\033[1m'
    GREEN=$'\033[32m'
    YELLOW=$'\033[33m'
    RED=$'\033[31m'
    BLUE=$'\033[36m'
    RESET=$'\033[0m'
else
    BOLD=""
    GREEN=""
    YELLOW=""
    RED=""
    BLUE=""
    RESET=""
fi

UI_WIDTH=70

ui_rule() {
    printf '%*s\n' "$UI_WIDTH" '' | tr ' ' '─'
}

ui_title_icon() {
    local title="${1^^}"

    case "$title" in
        *EINSTELLUNGEN*|*KONFIGURATION*)
            printf '⚙'
            ;;
        *INSTALLIEREN*|*INSTALLATION*)
            printf '▶'
            ;;
        *ZUSAMMENFASSUNG*|*ÜBERSICHT*)
            printf '▣'
            ;;
        *ABGESCHLOSSEN*|*FERTIG*)
            printf '✓'
            ;;
        *CACHE*|*DOWNLOAD*)
            printf '↓'
            ;;
        *UPDATE*|*AKTUALISIEREN*)
            printf '↻'
            ;;
        *LÖSCH*|*RESET*|*NEU*)
            printf '!'
            ;;
        *)
            printf '◆'
            ;;
    esac
}

ui_title_color() {
    local title="${1^^}"

    case "$title" in
        *LÖSCH*|*RESET*|*KOMPLETT\ NEU*)
            printf '%s' "$RED"
            ;;
        *EINSTELLUNGEN*|*KONFIGURATION*)
            printf '%s' "$BLUE"
            ;;
        *ABGESCHLOSSEN*|*FERTIG*)
            printf '%s' "$GREEN"
            ;;
        *WARN*|*HINWEIS*)
            printf '%s' "$YELLOW"
            ;;
        *)
            printf '%s' "$BLUE"
            ;;
    esac
}

header() {
    local title="$*"
    local icon color
    icon="$(ui_title_icon "$title")"
    color="$(ui_title_color "$title")"

    echo
    echo "${color}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${RESET}"
    printf "${color}${BOLD}║  %-2s %-64s ║${RESET}\n" "$icon" "$title"
    echo "${color}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${RESET}"
    echo
}

ui_section() {
    local title="$*"

    echo
    echo "${BOLD}┌─ ${title}${RESET}"
    echo "│"
}

ui_section_end() {
    echo "${BOLD}└─────────────────────────────────────────────────────────────────────${RESET}"
}

ui_kv() {
    local key="$1"
    shift
    printf "│  ${BLUE}%-16s${RESET} %s\n" "${key}:" "$*"
}

ui_note() {
    echo "│  ${BLUE}●${RESET} $*"
}

ui_warn_line() {
    echo "│  ${YELLOW}!${RESET} $*"
}

ui_card() {
    local title="$1"
    shift

    echo "${BOLD}┌─ ${title}${RESET}"

    while (( $# >= 2 )); do
        ui_kv "$1" "$2"
        shift 2
    done

    ui_section_end
    echo
}

ok() {
    echo "  ${GREEN}✓${RESET} $*"
}

warn() {
    echo "  ${YELLOW}!${RESET} $*"
}

die() {
    echo >&2
    echo "${RED}${BOLD}┌─ FEHLER${RESET}" >&2
    echo "${RED}│  ✗ $*${RESET}" >&2
    echo "${RED}${BOLD}└─────────────────────────────────────────────────────────────────────${RESET}" >&2
    exit 1
}

info() {
    echo "  ${BLUE}●${RESET} $*"
}


# -----------------------------------------------------------------------------
# V97 · APT-/CEPH-ROBUSTHEIT AUF DEM PROXMOX-HOST
# -----------------------------------------------------------------------------
# Ein unbenutztes oder veraltetes Ceph-Repository darf normale Host-Updates
# (z. B. Installation von nfs-common für Paperless) nicht blockieren.
# Aktive Ceph-Installationen werden ausdrücklich NICHT verändert.

pve_ceph_is_configured_v97() {
    [[ -s /etc/pve/ceph.conf ]] && return 0

    if [[ -f /etc/pve/storage.cfg ]] \
       && grep -Eq '^[[:space:]]*(rbd|cephfs):' /etc/pve/storage.cfg; then
        return 0
    fi

    return 1
}

# -----------------------------------------------------------------------------
# V109 · PROXMOX-REPOSITORIES BEIM SCRIPTSTART AUF NO-SUBSCRIPTION NORMALISIEREN
# -----------------------------------------------------------------------------
# Ziel:
#   - pve-enterprise und pve-test werden als aktive Paketquellen abgeschaltet.
#   - genau die offizielle PVE-No-Subscription-Quelle wird aktiviert.
#   - ein tatsächlich genutztes Ceph-Enterprise-Repo wird auf die entsprechende
#     No-Subscription-Quelle umgestellt; ungenutzte Ceph-Repos werden danach
#     von disable_unused_ceph_repositories_v97() abgeschaltet.
#   - erst nach erfolgreichem apt-get update geht der Installer ins Menü.
#
# Debian-Basis-Repositories und fremde Drittanbieter-Repositories werden nicht
# verändert.

cleanup_invalid_apt_source_files_v112() {
    local src_dir="/etc/apt/sources.list.d"
    local backup_dir=""
    local stamp=""
    local file=""
    local base=""
    local moved=0

    [[ -d "$src_dir" ]] || return 0

    stamp="$(date +%Y%m%d-%H%M%S)"
    backup_dir="${BACKUP_ROOT}/apt-invalid-sources-${stamp}"

    # APT wertet hier nur *.list und *.sources als Quellendateien aus.
    # Andere Dateien (z. B. proxmox.sh, *.bak, *.nodezero-disabled) erzeugen
    # Warnungen und gehören nicht in dieses Verzeichnis. Wir sichern sie zuerst.
    while IFS= read -r -d '' file; do
        base="$(basename -- "$file")"
        case "$base" in
            *.list|*.sources)
                continue
                ;;
        esac

        if (( moved == 0 )); then
            mkdir -p "$backup_dir"
            chmod 700 "$backup_dir"
        fi

        cp -a -- "$file" "$backup_dir/$base"
        rm -f -- "$file"
        moved=1
        warn "Ungültige Datei aus APT-Quellverzeichnis entfernt: $file"
    done < <(find "$src_dir" -maxdepth 1 -type f -print0 2>/dev/null)

    if (( moved )); then
        ok "Ungültige Dateien aus /etc/apt/sources.list.d wurden gesichert und entfernt."
        info "Backup: $backup_dir"
    fi
}

ensure_pve_no_subscription_repositories_v109() {
    local suite=""
    local stamp=""
    local backup_dir=""
    local apt_log=""
    local ceph_active=0

    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        suite="${VERSION_CODENAME:-}"
    fi

    [[ -n "$suite" ]] || suite="trixie"

    if pve_ceph_is_configured_v97; then
        ceph_active=1
    fi

    stamp="$(date +%Y%m%d-%H%M%S)"
    backup_dir="${BACKUP_ROOT}/apt-before-no-subscription-${stamp}"
    apt_log="${DIAGNOSE_ROOT}/apt-no-subscription-${stamp}.log"

    mkdir -p "$backup_dir"
    chmod 700 "$backup_dir"

    # Vor jeder Normalisierung eine vollständige Kopie der APT-Quellen sichern.
    [[ -e /etc/apt/sources.list ]] && cp -a /etc/apt/sources.list "$backup_dir/"
    [[ -d /etc/apt/sources.list.d ]] && cp -a /etc/apt/sources.list.d "$backup_dir/"

    # V112: Nach dem vollständigen APT-Backup alle Dateien entfernen, die
    # von APT ohnehin nicht als *.list / *.sources verwendet werden. Dadurch
    # verschwinden auch Warnungen durch versehentlich hier abgelegte proxmox.sh.
    cleanup_invalid_apt_source_files_v112

    command -v python3 >/dev/null 2>&1 || \
        die "python3 fehlt; Proxmox-Repository-Konfiguration kann nicht sicher normalisiert werden."

    NODEZERO_PVE_SUITE="$suite" \
    NODEZERO_CEPH_ACTIVE="$ceph_active" \
    python3 <<'PY_NOSUB_V109'
from __future__ import annotations

import os
import re
from pathlib import Path

suite = os.environ.get("NODEZERO_PVE_SUITE", "trixie").strip() or "trixie"
ceph_active = os.environ.get("NODEZERO_CEPH_ACTIVE", "0") == "1"
apt_dir = Path("/etc/apt")
sources_dir = apt_dir / "sources.list.d"
target = sources_dir / "proxmox.sources"

sources_dir.mkdir(parents=True, exist_ok=True)


def set_deb822_enabled_no(stanza: str) -> str:
    lines = stanza.splitlines()
    found = False
    out: list[str] = []
    for line in lines:
        if re.match(r"^\s*Enabled\s*:", line, re.I):
            out.append("Enabled: no")
            found = True
        else:
            out.append(line)
    if not found:
        out.append("Enabled: no")
    return "\n".join(out)


def normalize_sources_file(path: Path) -> None:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError):
        return

    stanzas = re.split(r"\n\s*\n", text.strip()) if text.strip() else []
    changed = False
    out: list[str] = []

    for stanza in stanzas:
        original = stanza
        low = stanza.lower()

        # PVE: alle bisherigen Kanäle deaktivieren. Die gewünschte einzelne
        # No-Subscription-Quelle wird anschließend deterministisch neu erzeugt.
        if "/debian/pve" in low or re.search(
            r"(?im)^\s*components\s*:.*\b(?:pve-enterprise|pve-no-subscription|pve-test)\b",
            stanza,
        ):
            stanza = set_deb822_enabled_no(stanza)

        # Ceph nur dann umschreiben, wenn Ceph auf diesem Host wirklich aktiv
        # konfiguriert ist. Andernfalls wird der Absatz deaktiviert und später
        # zusätzlich vom vorhandenen Ceph-Cleanup behandelt.
        if "/debian/ceph-" in low and "proxmox.com" in low:
            if ceph_active:
                stanza = re.sub(
                    r"https?://enterprise\.proxmox\.com/debian/(ceph-[^\s]+)",
                    r"http://download.proxmox.com/debian/\1",
                    stanza,
                    flags=re.I,
                )
                stanza = re.sub(
                    r"(?im)^(\s*Components\s*:\s*)enterprise(\s*)$",
                    r"\1no-subscription\2",
                    stanza,
                )
                # Falls der Absatz zuvor explizit deaktiviert war, respektieren
                # wir das. Nur Enterprise -> No-Subscription wird umgestellt.
            else:
                stanza = set_deb822_enabled_no(stanza)

        if stanza != original:
            changed = True
        out.append(stanza)

    new_text = "\n\n".join(out)
    if new_text:
        new_text += "\n"

    if changed:
        path.write_text(new_text, encoding="utf-8")


def normalize_list_file(path: Path) -> None:
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeError):
        return

    changed = False
    out: list[str] = []

    for line in lines:
        stripped = line.lstrip()
        low = stripped.lower()

        if stripped.startswith("#") or not re.match(r"^deb(?:-src)?\s+", stripped, re.I):
            out.append(line)
            continue

        # Alte PVE enterprise/no-subscription/test-Zeilen abschalten. Damit
        # existiert anschließend nur unsere Deb822-No-Subscription-Quelle.
        if "/debian/pve" in low and "proxmox.com" in low:
            out.append("# NODEZERO V109 deaktiviert: " + line)
            changed = True
            continue

        if "/debian/ceph-" in low and "proxmox.com" in low:
            if ceph_active:
                new = re.sub(
                    r"https?://enterprise\.proxmox\.com/debian/(ceph-[^\s]+)",
                    r"http://download.proxmox.com/debian/\1",
                    line,
                    flags=re.I,
                )
                new = re.sub(r"\s+enterprise\s*$", " no-subscription", new, flags=re.I)
                out.append(new)
                changed = changed or new != line
            else:
                out.append("# NODEZERO V109 unbenutztes Ceph-Repo deaktiviert: " + line)
                changed = True
            continue

        out.append(line)

    if changed:
        path.write_text("\n".join(out) + "\n", encoding="utf-8")


# Alle Deb822-Dateien außer der offiziellen Ziel-Datei normalisieren.
# Die Ziel-Datei wird anschließend separat behandelt, damit eventuell darin
# enthaltene Nicht-PVE-Stanzas (z. B. Ceph) nicht verloren gehen.
for path in sorted(apt_dir.rglob("*.sources")):
    if path == target:
        continue
    normalize_sources_file(path)

# Legacy .list-Dateien sowie /etc/apt/sources.list normalisieren.
legacy_files = list(sorted(apt_dir.rglob("*.list")))
main_list = apt_dir / "sources.list"
if main_list.exists() and main_list not in legacy_files:
    legacy_files.append(main_list)

for path in legacy_files:
    normalize_list_file(path)

# Vorhandene proxmox.sources kann theoretisch mehrere Stanzas enthalten.
# Nur alte PVE-Stanzas werden entfernt; andere Quellen bleiben erhalten.
kept_target_stanzas: list[str] = []
if target.exists():
    try:
        target_text = target.read_text(encoding="utf-8")
    except (OSError, UnicodeError):
        target_text = ""

    for stanza in re.split(r"\n\s*\n", target_text.strip()) if target_text.strip() else []:
        low = stanza.lower()

        is_pve = (
            "/debian/pve" in low
            or re.search(
                r"(?im)^\s*components\s*:.*\b(?:pve-enterprise|pve-no-subscription|pve-test)\b",
                stanza,
            )
        )
        if is_pve:
            continue

        # Falls ausnahmsweise eine Ceph-Quelle in proxmox.sources steckt,
        # behandeln wir sie genauso wie in anderen Deb822-Dateien.
        if "/debian/ceph-" in low and "proxmox.com" in low:
            if ceph_active:
                stanza = re.sub(
                    r"https?://enterprise\.proxmox\.com/debian/(ceph-[^\s]+)",
                    r"http://download.proxmox.com/debian/\1",
                    stanza,
                    flags=re.I,
                )
                stanza = re.sub(
                    r"(?im)^(\s*Components\s*:\s*)enterprise(\s*)$",
                    r"\1no-subscription\2",
                    stanza,
                )
            else:
                stanza = set_deb822_enabled_no(stanza)

        kept_target_stanzas.append(stanza)

# Offizielle PVE-No-Subscription-Deb822-Struktur. Suite wird aus os-release
# genommen, damit derselbe Installer nicht hart an einen Codenamen gebunden ist.
pve_no_subscription_stanza = (
    "Types: deb\n"
    "URIs: http://download.proxmox.com/debian/pve\n"
    f"Suites: {suite}\n"
    "Components: pve-no-subscription\n"
    "Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg"
)

kept_target_stanzas.append(pve_no_subscription_stanza)
target.write_text(
    "\n\n".join(kept_target_stanzas) + "\n",
    encoding="utf-8",
)
PY_NOSUB_V109

    chmod 644 /etc/apt/sources.list.d/proxmox.sources
    chown root:root /etc/apt/sources.list.d/proxmox.sources

    echo
    info "Proxmox APT-Kanal wird auf pve-no-subscription geprüft ..."

    if ! apt-get update 2>&1 | tee "$apt_log"; then
        die "apt-get update ist nach der No-Subscription-Umstellung fehlgeschlagen. Backup: $backup_dir"
    fi

    # Wenn APT trotzdem versucht, enterprise.proxmox.com zu erreichen, ist noch
    # eine aktive Enterprise-Quelle vorhanden. In diesem Fall NICHT still
    # weiterinstallieren.
    if grep -Fqi 'enterprise.proxmox.com' "$apt_log"; then
        die "Es ist weiterhin ein aktives Proxmox-Enterprise-Repository vorhanden. Siehe $apt_log"
    fi

    if ! grep -Fq 'Components: pve-no-subscription' /etc/apt/sources.list.d/proxmox.sources; then
        die "pve-no-subscription konnte nicht aktiviert werden."
    fi

    ok "PVE Enterprise/PVE-Test deaktiviert; pve-no-subscription ist aktiv."
    if (( ceph_active )); then
        ok "Aktive Ceph-Proxmox-Quellen wurden auf No-Subscription umgestellt, sofern Enterprise konfiguriert war."
    else
        info "Ceph ist nicht aktiv konfiguriert; unbenutzte Ceph-Repositories werden deaktiviert."
    fi
    info "APT-Backup: $backup_dir"
}

disable_unused_ceph_repositories_v97() {
    pve_ceph_is_configured_v97 && return 0

    local file=""
    local stamp=""
    local backup_dir=""
    local changed=0

    stamp="$(date +%Y%m%d-%H%M%S)"
    backup_dir="${BACKUP_ROOT}/apt-ceph-disabled-${stamp}"

    for file in \
        /etc/apt/sources.list.d/ceph.sources \
        /etc/apt/sources.list.d/ceph.list
    do
        [[ -f "$file" ]] || continue

        # Nur echte Proxmox-Ceph-Quellen anfassen.
        grep -Eiq '(download|enterprise)\.proxmox\.com/debian/ceph-' "$file" || continue

        if (( changed == 0 )); then
            mkdir -p "$backup_dir"
            chmod 700 "$backup_dir"
        fi

        cp -a "$file" "$backup_dir/"
        # V110: Nicht mit einer Fantasie-Endung in sources.list.d liegen
        # lassen, weil APT sonst bei jedem Lauf eine Warnung ausgibt. Die
        # vollständige Originaldatei liegt bereits im Backup-Verzeichnis.
        rm -f -- "$file"
        changed=1

        warn "Unbenutztes Ceph-Repository deaktiviert und gesichert: $file"
    done

    # Legacy-Einträge in *.list-Dateien ebenfalls entschärfen, ohne gemischte
    # Deb822-.sources-Dateien automatisch umzuschreiben.
    while IFS= read -r -d '' file; do
        [[ "$file" == "/etc/apt/sources.list.d/ceph.list" ]] && continue
        grep -Eiq '^[[:space:]]*deb .*proxmox\.com/debian/ceph-' "$file" || continue

        if (( changed == 0 )); then
            mkdir -p "$backup_dir"
            chmod 700 "$backup_dir"
        fi

        cp -a "$file" "$backup_dir/$(basename "$file")"
        sed -Ei \
            '/^[[:space:]]*deb .*proxmox\.com\/debian\/ceph-/ s|^|# NODEZERO V97: unbenutztes Ceph-Repo deaktiviert: |' \
            "$file"
        changed=1
        warn "Unbenutzter Ceph-Eintrag deaktiviert: $file"
    done < <(find /etc/apt -maxdepth 2 -type f -name '*.list' -print0 2>/dev/null)

    if (( changed )); then
        ok "Ceph wird auf diesem Host nicht verwendet; störende Ceph-APT-Quellen wurden gesichert und deaktiviert."
        info "Backup: $backup_dir"
    fi
}

yn_interactive() {
    local prompt="$1"
    local default="${2:-J}"

    if (( TUI_AVAILABLE )); then
        if [[ "$default" =~ ^[JjYy]$ ]]; then
            tui_yesno "BESTÄTIGUNG" "$prompt" "Ja" "Nein"
            return $?
        fi
    fi

    local ans
    printf >&2 "  ${BLUE}›${RESET} %s " "$prompt"
    read -r ans

    ans="${ans:-$default}"
    [[ "$ans" =~ ^[JjYy]$ ]]
}

yn() {
    local prompt="$1"
    local default="${2:-J}"

    if (( ${OPTIMAL_INSTALL:-0} )); then
        # V101: keine Rückfragen im Optimalmodus. Der jeweilige Default gilt.
        [[ "$default" =~ ^[JjYy]$ ]]
        return $?
    fi

    yn_interactive "$prompt" "$default"
}

INSTALL_PROGRESS_CURRENT=0
INSTALL_PROGRESS_TOTAL=0

ui_progress_init() {
    INSTALL_PROGRESS_CURRENT=0
    INSTALL_PROGRESS_TOTAL="$1"
}

ui_progress_step() {
    local label="$*"

    INSTALL_PROGRESS_CURRENT=$((INSTALL_PROGRESS_CURRENT + 1))

    echo
    echo "${BOLD}${BLUE}┌─ INSTALLATIONSFORTSCHRITT${RESET}"
    printf "│  ${GREEN}[%02d/%02d]${RESET} %s\n" \
        "$INSTALL_PROGRESS_CURRENT" \
        "$INSTALL_PROGRESS_TOTAL" \
        "$label"
    echo "${BLUE}└─────────────────────────────────────────────────────────────────────${RESET}"
}

run_install_step() {
    local label="$1"
    shift

    ui_progress_step "$label"
    "$@"

    if declare -F persist_install_secrets_v107 >/dev/null 2>&1; then
        persist_install_secrets_v107 || true
    fi
}


# =============================================================================
# WHIPTAIL / NEWT INSTALLER-OBERFLÄCHE V52
# =============================================================================

TUI_AVAILABLE=0
TUI_TITLE="PROXMOX INSTALLER V140"
TUI_BACKTITLE="Proxmox · Modularer Komplett-Installer V140"

ensure_tui() {
    if command -v whiptail >/dev/null 2>&1; then
        TUI_AVAILABLE=1
        return 0
    fi

    echo
    echo "Installer-Oberfläche wird vorbereitet (whiptail) ..."

    if apt-get update -qq >/dev/null 2>&1 \
       && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq whiptail >/dev/null 2>&1; then
        TUI_AVAILABLE=1
        return 0
    fi

    TUI_AVAILABLE=0
    warn "whiptail konnte nicht installiert werden; Terminal-Fallback wird verwendet."
}

tui_msgbox() {
    local title="$1"
    local message="$2"

    if (( TUI_AVAILABLE )); then
        whiptail \
            --backtitle "$TUI_BACKTITLE" \
            --title "$title" \
            --ok-button "Zurück" \
            --msgbox "$message" \
            22 82
    else
        header "$title"
        printf '%s\n' "$message"
        read -rp "ENTER zum Fortfahren ... " _
    fi
}

tui_yesno() {
    local title="$1"
    local message="$2"
    local yes_label="${3:-Ja}"
    local no_label="${4:-Nein}"

    if (( TUI_AVAILABLE )); then
        whiptail \
            --backtitle "$TUI_BACKTITLE" \
            --title "$title" \
            --yes-button "$yes_label" \
            --no-button "$no_label" \
            --yesno "$message" \
            14 78
        return $?
    fi

    local answer
    read -rp "${message} [j/N]: " answer
    [[ "$answer" =~ ^[JjYy]$ ]]
}

tui_input() {
    local title="$1"
    local prompt="$2"
    local default="${3:-}"
    local result=""

    if (( TUI_AVAILABLE )); then
        if result="$(
            whiptail \
                --backtitle "$TUI_BACKTITLE" \
                --title "$title" \
                --ok-button "Weiter" \
                --cancel-button "Abbrechen" \
                --inputbox "$prompt" \
                12 76 \
                "$default" \
                3>&1 1>&2 2>&3
        )"; then
            printf '%s' "$result"
            return 0
        fi

        return 1
    fi

    read -rp "$prompt [$default]: " result
    printf '%s' "${result:-$default}"
}

tui_password() {
    local title="$1"
    local prompt="$2"
    local result=""

    if (( TUI_AVAILABLE )); then
        if result="$(
            whiptail \
                --backtitle "$TUI_BACKTITLE" \
                --title "$title" \
                --ok-button "Weiter" \
                --cancel-button "Abbrechen" \
                --passwordbox "$prompt" \
                12 76 \
                3>&1 1>&2 2>&3
        )"; then
            printf '%s' "$result"
            return 0
        fi

        return 1
    fi

    read -rsp "$prompt: " result
    echo >&2
    printf '%s' "$result"
}

tui_host_status_v106() {
    local host ip pve_version vm_count ct_count root_use

    host="$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo pve)"
    ip="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
    [[ -n "$ip" ]] || ip="-"

    pve_version="$(pveversion 2>/dev/null | sed -E 's#^[^/]+/([^ -]+).*#\1#' || true)"
    [[ -n "$pve_version" ]] || pve_version="-"

    vm_count="$(qm list 2>/dev/null | awk 'NR>1 {n++} END {print n+0}' || true)"
    ct_count="$(pct list 2>/dev/null | awk 'NR>1 {n++} END {print n+0}' || true)"
    root_use="$(df -P / 2>/dev/null | awk 'NR==2 {print $5}' || true)"

    [[ -n "$vm_count" ]] || vm_count="0"
    [[ -n "$ct_count" ]] || ct_count="0"
    [[ -n "$root_use" ]] || root_use="-"

    printf 'Host: %s  ·  IP: %s  ·  PVE: %s\nVMs: %s  ·  LXC: %s  ·  Root: %s' \
        "$host" "$ip" "$pve_version" "$vm_count" "$ct_count" "$root_use"
}

tui_basis_menu_v106() {
    local result=""

    if (( TUI_AVAILABLE )); then
        result="$(
            whiptail \
                --backtitle "$TUI_BACKTITLE" \
                --title "BASIS-SYSTEME" \
                --ok-button "Auswählen" \
                --cancel-button "Zurück" \
                --menu "Basis-System oder Basis-Paket auswählen" \
                21 88 9 \
                "6" "★ Basis-Paket · Dashboard + HA + Paperless + Pi-hole + NetAlertX + PVE-UPS" \
                "1" "Server-Dashboard installieren / aktualisieren" \
                "2" "Home Assistant OS" \
                "3" "Paperless-ngx + Ollama" \
                "4" "Pi-hole + Unbound" \
                "5" "NetAlertX" \
                "9" "Freie Gesamtauswahl · Basis + Apps + Betriebssystem" \
                3>&1 1>&2 2>&3
        )" || return 1
        printf '%s' "$result"
        return 0
    fi

    printf >&2 '\nBASIS-SYSTEME\n  6 Basis-Paket (empfohlen)\n  1 Dashboard\n  2 Home Assistant\n  3 Paperless\n  4 Pi-hole\n  5 NetAlertX\n  9 Freie Gesamtauswahl\n  Z Zurück\nAuswahl [6]: '
    read -r result
    result="${result:-6}"
    [[ "${result^^}" == "Z" ]] && return 1
    printf '%s' "$result"
}

tui_apps_menu_v106() {
    local result=""

    if (( TUI_AVAILABLE )); then
        result="$(
            whiptail \
                --backtitle "$TUI_BACKTITLE" \
                --title "APPS & DIENSTE" \
                --ok-button "Auswählen" \
                --cancel-button "Zurück" \
                --menu "Wie möchtest du Apps auswählen?" \
                17 86 5 \
                "APPS_REC" "★ Empfohlene Apps · Uptime + Caddy + Stirling + Speedtest + Scrutiny" \
                "APPS"     "Apps einzeln auswählen · Checkliste" \
                "APPS_ALL" "Alle Apps & Dienste auswählen" \
                "9"        "Freie Gesamtauswahl · Basis + Apps + Betriebssystem" \
                3>&1 1>&2 2>&3
        )" || return 1
        printf '%s' "$result"
        return 0
    fi

    printf >&2 '\nAPPS & DIENSTE\n  1 Empfohlene Apps\n  2 Apps auswählen\n  3 Alle Apps\n  4 Freie Gesamtauswahl\n  Z Zurück\nAuswahl [1]: '
    read -r result
    case "${result:-1}" in
        1) printf 'APPS_REC' ;;
        2) printf 'APPS' ;;
        3) printf 'APPS_ALL' ;;
        4) printf '9' ;;
        [Zz]) return 1 ;;
        *) return 1 ;;
    esac
}

tui_monitoring_menu_v106() {
    local result=""

    if (( TUI_AVAILABLE )); then
        result="$(
            whiptail \
                --backtitle "$TUI_BACKTITLE" \
                --title "MONITORING & INFRASTRUKTUR" \
                --ok-button "Auswählen" \
                --cancel-button "Zurück" \
                --menu "Monitoring-/Infrastruktur-Paket auswählen" \
                17 92 5 \
                "MON_REC" "★ Empfohlen · Pulse + PVE-UPS + Prometheus + PVE Exporter + Grafana + EMQX" \
                "MON"     "Dienste einzeln auswählen · Checkliste" \
                "MON_ALL" "Alle Monitoring-/Infrastruktur-Dienste auswählen" \
                "14"      "Alte komplette Community-Auswahl öffnen" \
                3>&1 1>&2 2>&3
        )" || return 1
        printf '%s' "$result"
        return 0
    fi

    printf >&2 '\nMONITORING & INFRASTRUKTUR\n  1 Empfohlen\n  2 Einzeln auswählen\n  3 Alle\n  4 Komplette Community-Auswahl\n  Z Zurück\nAuswahl [1]: '
    read -r result
    case "${result:-1}" in
        1) printf 'MON_REC' ;;
        2) printf 'MON' ;;
        3) printf 'MON_ALL' ;;
        4) printf '14' ;;
        [Zz]) return 1 ;;
        *) return 1 ;;
    esac
}

tui_automation_menu_v106() {
    local result=""

    if (( TUI_AVAILABLE )); then
        result="$(
            whiptail \
                --backtitle "$TUI_BACKTITLE" \
                --title "AUTOMATION & SECURITY" \
                --ok-button "Auswählen" \
                --cancel-button "Zurück" \
                --menu "Automation-/Security-Dienste auswählen" \
                16 88 4 \
                "AUTOSEC" "Semaphore / Pocket ID / CrowdSec / Pangolin / Newt auswählen" \
                "SEMAPHORE" "Nur Semaphore installieren" \
                "REMOTE" "Remote-Stack · Pangolin + Newt" \
                "14" "Alte komplette Community-Auswahl öffnen" \
                3>&1 1>&2 2>&3
        )" || return 1
        printf '%s' "$result"
        return 0
    fi

    printf >&2 '\nAUTOMATION & SECURITY\n  1 Auswahl öffnen\n  2 Nur Semaphore\n  3 Pangolin + Newt\n  4 Komplette Community-Auswahl\n  Z Zurück\nAuswahl [1]: '
    read -r result
    case "${result:-1}" in
        1) printf 'AUTOSEC' ;;
        2) printf 'SEMAPHORE' ;;
        3) printf 'REMOTE' ;;
        4) printf '14' ;;
        [Zz]) return 1 ;;
        *) return 1 ;;
    esac
}

tui_vm_os_menu_v106() {
    local result=""

    if (( TUI_AVAILABLE )); then
        result="$(
            whiptail \
                --backtitle "$TUI_BACKTITLE" \
                --title "VMs / BETRIEBSSYSTEME" \
                --ok-button "Auswählen" \
                --cancel-button "Zurück" \
                --menu "VM/LXC-Verwaltung oder Betriebssystem-Installation" \
                15 84 4 \
                "0"  "VM / LXC verwalten" \
                "16" "Betriebssystem installieren · Windows / Debian / Ubuntu / Mint" \
                3>&1 1>&2 2>&3
        )" || return 1
        printf '%s' "$result"
        return 0
    fi

    printf >&2 '\nVMs / BETRIEBSSYSTEME\n  1 VM/LXC verwalten\n  2 Betriebssystem installieren\n  Z Zurück\nAuswahl [1]: '
    read -r result
    case "${result:-1}" in
        1) printf '0' ;;
        2) printf '16' ;;
        [Zz]) return 1 ;;
        *) return 1 ;;
    esac
}

tui_maintenance_menu_v106() {
    local result=""

    if (( TUI_AVAILABLE )); then
        result="$(
            whiptail \
                --backtitle "$TUI_BACKTITLE" \
                --title "WARTUNG & EINSTELLUNGEN" \
                --ok-button "Auswählen" \
                --cancel-button "Zurück" \
                --menu "Werkzeug oder Einstellung auswählen" \
                24 94 10 \
                "8"  "Pi-hole Authentifizierung / Home Assistant" \
                "10" "Pi-hole Sprache · DE / EN" \
                "11" "Auto-Updater / Pushover konfigurieren" \
                "12" "Installations-Passwörter anzeigen" \
                "15" "PVE Storage-Share-Helper" \
                "17" "Setup-Profile · laden / verwalten" \
                "19" "OpenRGB · Mainboard / RAM / USB-RGB" \
                3>&1 1>&2 2>&3
        )" || return 1
        printf '%s' "$result"
        return 0
    fi

    printf >&2 '\nWARTUNG & EINSTELLUNGEN\n  8 Pi-hole Auth\n  10 Pi-hole Sprache\n  11 Auto-Updater/Pushover\n  12 Passwörter\n  15 Storage-Share-Helper\n  17 Setup-Profile\n  19 OpenRGB\n  Z Zurück\nAuswahl: '
    read -r result
    [[ "${result^^}" == "Z" ]] && return 1
    printf '%s' "$result"
}

tui_reset_menu_v106() {
    local result=""

    if (( TUI_AVAILABLE )); then
        result="$(
            whiptail \
                --backtitle "$TUI_BACKTITLE" \
                --title "RESET / NEUAUFBAU" \
                --ok-button "Auswählen" \
                --cancel-button "Zurück" \
                --menu "ACHTUNG: Diese Funktionen können Gäste und Daten löschen." \
                18 96 5 \
                "7"  "KOMPLETT NEU · Auswahl + Löschbestätigung" \
                "13" "KOMPLETT NEU · SOFORT · 5-Sekunden-Countdown" \
                "18" "PROXMOX AUF NULL · VMs/LXC + lokale Images/Backups entfernen" \
                3>&1 1>&2 2>&3
        )" || return 1
        printf '%s' "$result"
        return 0
    fi

    printf >&2 '\nRESET / NEUAUFBAU\n  7 Komplett neu mit Bestätigung\n  13 Komplett neu SOFORT\n  18 Proxmox auf Null\n  Z Zurück\nAuswahl: '
    read -r result
    [[ "${result^^}" == "Z" ]] && return 1
    printf '%s' "$result"
}

tui_main_menu() {
    local result="" sub="" status=""

    while true; do
        status="$(tui_host_status_v106)"

        if (( TUI_AVAILABLE )); then
            result="$(
                whiptail \
                    --backtitle "$TUI_BACKTITLE" \
                    --title "HAUPTMENÜ · Version 138" \
                    --ok-button "Öffnen" \
                    --cancel-button "Beenden" \
                    --menu "${status}\n\nBereich auswählen" \
                    24 96 10 \
                    "O" "★ OPTIMALE INSTALLATION · kompletter Standard-Stack" \
                    "1" "Basis-Systeme" \
                    "2" "Apps & Dienste" \
                    "3" "Monitoring & Infrastruktur" \
                    "4" "Automation & Security" \
                    "5" "VMs / Betriebssysteme" \
                    "6" "Wartung & Einstellungen" \
                    "7" "Reset / Neuaufbau" \
                    "I" "Info / Diagnose" \
                    3>&1 1>&2 2>&3
            )" || return 1
        else
            printf >&2 '\n============================================================\n%s\n============================================================\n O  Optimale Installation\n 1  Basis-Systeme\n 2  Apps & Dienste\n 3  Monitoring & Infrastruktur\n 4  Automation & Security\n 5  VMs / Betriebssysteme\n 6  Wartung & Einstellungen\n 7  Reset / Neuaufbau\n I  Info / Diagnose\n Q  Beenden\nAuswahl [O]: ' "$status"
            read -r result
            result="${result:-O}"
            [[ "${result^^}" == "Q" ]] && return 1
        fi

        case "${result^^}" in
            O|I)
                printf '%s' "${result^^}"
                return 0
                ;;
            1)
                if sub="$(tui_basis_menu_v106)"; then
                    printf '%s' "$sub"
                    return 0
                fi
                ;;
            2)
                if sub="$(tui_apps_menu_v106)"; then
                    printf '%s' "$sub"
                    return 0
                fi
                ;;
            3)
                if sub="$(tui_monitoring_menu_v106)"; then
                    printf '%s' "$sub"
                    return 0
                fi
                ;;
            4)
                if sub="$(tui_automation_menu_v106)"; then
                    printf '%s' "$sub"
                    return 0
                fi
                ;;
            5)
                if sub="$(tui_vm_os_menu_v106)"; then
                    printf '%s' "$sub"
                    return 0
                fi
                ;;
            6)
                if sub="$(tui_maintenance_menu_v106)"; then
                    printf '%s' "$sub"
                    return 0
                fi
                ;;
            7)
                if sub="$(tui_reset_menu_v106)"; then
                    printf '%s' "$sub"
                    return 0
                fi
                ;;
            *)
                if (( TUI_AVAILABLE )); then
                    tui_msgbox "UNGÜLTIGE AUSWAHL" "Bitte einen Menüpunkt auswählen."
                else
                    echo "Ungültige Auswahl." >&2
                fi
                ;;
        esac
    done
}

tui_selected_extended_text() {
    local out=""

    out+="BASICS\n"
    out+="  [$([[ "$INSTALL_DASHBOARD" -eq 1 ]] && echo X || echo ' ')] Server-Dashboard   "
    out+="[$([[ "$INSTALL_HA" -eq 1 ]] && echo X || echo ' ')] Home Assistant OS\n"
    out+="  [$([[ "$INSTALL_PAPERLESS" -eq 1 ]] && echo X || echo ' ')] Paperless-ngx + Ollama   "
    out+="[$([[ "$INSTALL_PIHOLE" -eq 1 ]] && echo X || echo ' ')] Pi-hole + Unbound   "
    out+="[$([[ "$INSTALL_NETALERTX" -eq 1 ]] && echo X || echo ' ')] NetAlertX\n\n"

    out+="ZUSATZANWENDUNGEN\n"
    out+="  [$([[ "$INSTALL_UPTIME" -eq 1 ]] && echo X || echo ' ')] Uptime Kuma   "
    out+="[$([[ "$INSTALL_VAULTWARDEN" -eq 1 ]] && echo X || echo ' ')] Vaultwarden   "
    out+="[$([[ "$INSTALL_CADDY" -eq 1 ]] && echo X || echo ' ')] Caddy\n"
    out+="  [$([[ "$INSTALL_STIRLING" -eq 1 ]] && echo X || echo ' ')] Stirling PDF   "
    out+="[$([[ "$INSTALL_NTFY" -eq 1 ]] && echo X || echo ' ')] ntfy   "
    out+="[$([[ "$INSTALL_FORGEJO" -eq 1 ]] && echo X || echo ' ')] Forgejo\n"
    out+="  [$([[ "$INSTALL_SYNCTHING" -eq 1 ]] && echo X || echo ' ')] Syncthing   "
    out+="[$([[ "$INSTALL_SPEEDTEST" -eq 1 ]] && echo X || echo ' ')] Speedtest Tracker\n"
    out+="  [$([[ "$INSTALL_SCRUTINY" -eq 1 ]] && echo X || echo ' ')] Scrutiny   "
    out+="[$([[ "$INSTALL_MEALIE" -eq 1 ]] && echo X || echo ' ')] Mealie\n\n"

    out+="BETRIEBSSYSTEM\n"
    if (( INSTALL_OS )); then
        if [[ -n "${OS_LABEL:-}" ]]; then
            out+="  [X] ${OS_LABEL} · $([[ "${OS_MODE:-headless}" == "desktop" ]] && echo "mit Grafik" || echo "ohne Grafik")\n"
        else
            out+="  [X] Betriebssystem-VM · Auswahl folgt\n"
        fi
    else
        out+="  [ ] keine zusätzliche Betriebssystem-VM\n"
    fi

    printf '%b' "$out"
}

tui_review_extended_selection() {
    local content
    content="$(tui_selected_extended_text)"
    content+=$'\n\nMit dieser Auswahl weitermachen?'

    if (( TUI_AVAILABLE )); then
        whiptail \
            --backtitle "$TUI_BACKTITLE" \
            --title "AUSWAHL PRÜFEN" \
            --yes-button "Weiter" \
            --no-button "Ändern" \
            --yesno "$content" \
            24 82
        return $?
    fi

    printf '%s\n' "$content"
    yn "Mit dieser Auswahl weitermachen? [J/n]" "J"
}

tui_extended_checklist() {
    local selected=""

    if (( TUI_AVAILABLE )); then
        selected="$(
            whiptail \
                --backtitle "$TUI_BACKTITLE" \
                --title "KOMPONENTEN AUSWÄHLEN" \
                --ok-button "Prüfen" \
                --cancel-button "Abbrechen" \
                --separate-output \
                --checklist "Leertaste = auswählen/abwählen · TAB = Button wechseln" \
                27 94 16 \
                "1"  "BASICS · Server-Dashboard" ON \
                "2"  "BASICS · Home Assistant OS" ON \
                "3"  "BASICS · Paperless-ngx + Ollama" ON \
                "4"  "BASICS · Pi-hole + Unbound" ON \
                "5"  "BASICS · NetAlertX" ON \
                "6"  "EXTRAS · Uptime Kuma" OFF \
                "7"  "EXTRAS · Vaultwarden" OFF \
                "8"  "EXTRAS · Caddy Reverse Proxy" OFF \
                "9"  "EXTRAS · Stirling PDF" OFF \
                "10" "EXTRAS · ntfy" OFF \
                "11" "EXTRAS · Forgejo" OFF \
                "12" "EXTRAS · Syncthing" OFF \
                "13" "EXTRAS · Speedtest Tracker" OFF \
                "14" "EXTRAS · Scrutiny" OFF \
                "15" "EXTRAS · Mealie" OFF \
                "16" "OPTIONAL · Betriebssystem-VM · Windows / Linux" OFF \
                3>&1 1>&2 2>&3
        )" || return 1

        reset_install_flags

        local choice
        while IFS= read -r choice; do
            case "$choice" in
                1)  INSTALL_DASHBOARD=1 ;;
                2)  INSTALL_HA=1 ;;
                3)  INSTALL_PAPERLESS=1 ;;
                4)  INSTALL_PIHOLE=1 ;;
                5)  INSTALL_NETALERTX=1 ;;
                6)  INSTALL_UPTIME=1 ;;
                7)  INSTALL_VAULTWARDEN=1 ;;
                8)  INSTALL_CADDY=1 ;;
                9)  INSTALL_STIRLING=1 ;;
                10) INSTALL_NTFY=1 ;;
                11) INSTALL_FORGEJO=1 ;;
                12) INSTALL_SYNCTHING=1 ;;
                13) INSTALL_SPEEDTEST=1 ;;
                14) INSTALL_SCRUTINY=1 ;;
                15) INSTALL_MEALIE=1 ;;
                16) INSTALL_OS=1 ;;
            esac
        done <<<"$selected"

        return 0
    fi

    return 1
}

tui_community_checklist() {
    local selected=""

    if (( TUI_AVAILABLE )); then
        # V96: Kommentare dürfen nicht innerhalb der mit Backslash fortgesetzten
        # whiptail-Anweisung stehen. Das hat in V95 die Community-Checkliste
        # beendet, bevor die Einträge an whiptail übergeben wurden.
        # Grundauswahl: PBS + Pulse + Prometheus + PVE Exporter + Grafana + EMQX.
        selected="$(
            whiptail \
                --backtitle "$TUI_BACKTITLE" \
                --title "COMMUNITY-ERWEITERUNGEN" \
                --ok-button "Weiter" \
                --cancel-button "Abbrechen" \
                --separate-output \
                --checklist "Gewünschte Erweiterungen auswählen" \
                29 102 18 \
                "1"  "BASICS · Proxmox Backup Server · 128 GB" ON \
                "2"  "MONITORING · Pulse · automatisch vorkonfiguriert" ON \
                "3"  "USV · PVE-UPS · NUT/SNMP · Standard/Pflicht im Basis-Stack" ON \
                "4"  "AUTOMATION · Semaphore" OFF \
                "5"  "SECURITY · Pocket ID · OIDC / Passkeys · HTTPS" OFF \
                "6"  "MONITORING · Prometheus" ON \
                "7"  "MONITORING · Prometheus PVE Exporter" ON \
                "8"  "MONITORING · Grafana" ON \
                "9"  "SECURITY · CrowdSec Add-on · Ziel-CTs auswählbar" OFF \
                "10" "REMOTE · Pangolin" OFF \
                "11" "REMOTE · Newt · benötigt Pangolin-Zugangsdaten" OFF \
                "12" "MONITORING · Gatus" OFF \
                "13" "DASHBOARD · Homepage" OFF \
                "14" "PROXY · Nginx Proxy Manager · Admin Port 81" OFF \
                "15" "MQTT · EMQX Broker · Weboberfläche · MQTT/MQTTS" ON \
                3>&1 1>&2 2>&3
        )" || return 1

        INSTALL_PBS=0
        INSTALL_PULSE=0
        INSTALL_PVEUPS=0
        INSTALL_SEMAPHORE=0
        INSTALL_POCKETID=0
        INSTALL_PROMETHEUS=0
        INSTALL_PVE_EXPORTER=0
        INSTALL_GRAFANA=0
        INSTALL_CROWDSEC=0
        INSTALL_PANGOLIN=0
        INSTALL_NEWT=0
        INSTALL_GATUS=0
        INSTALL_HOMEPAGE=0
        INSTALL_NPM=0
        INSTALL_EMQX=0

        local choice
        while IFS= read -r choice; do
            case "$choice" in
                1)  INSTALL_PBS=1 ;;
                2)  INSTALL_PULSE=1 ;;
                3)  INSTALL_PVEUPS=1 ;;
                4)  INSTALL_SEMAPHORE=1 ;;
                5)  INSTALL_POCKETID=1 ;;
                6)  INSTALL_PROMETHEUS=1 ;;
                7)  INSTALL_PVE_EXPORTER=1 ;;
                8)  INSTALL_GRAFANA=1 ;;
                9)  INSTALL_CROWDSEC=1 ;;
                10) INSTALL_PANGOLIN=1 ;;
                11) INSTALL_NEWT=1 ;;
                12) INSTALL_GATUS=1 ;;
                13) INSTALL_HOMEPAGE=1 ;;
                14) INSTALL_NPM=1 ;;
                15) INSTALL_EMQX=1 ;;
            esac
        done <<<"$selected"

        return 0
    fi

    return 1
}

declare -A RESERVED_IDS=()

free_id_check() {
    local id="$1"
    [[ ! -e "/etc/pve/qemu-server/${id}.conf" &&
       ! -e "/etc/pve/lxc/${id}.conf" &&
       -z "${RESERVED_IDS[$id]:-}" ]]
}

NEXT_CANDIDATE="$(pvesh get /cluster/nextid)"
ALLOCATED_ID=""

allocate_id() {
    local candidate=101

    while true; do
        # ID 100 bleibt grundsätzlich reserviert und wird nie vergeben.
        if [[ "$candidate" -eq 100 ]]; then
            candidate=101
        fi

        if ! qm status "$candidate" >/dev/null 2>&1 \
           && ! pct status "$candidate" >/dev/null 2>&1 \
           && [[ -z "${RESERVED_IDS[$candidate]:-}" ]]; then
            ALLOCATED_ID="$candidate"
            return 0
        fi

        candidate=$((candidate + 1))
    done
}

# =============================================================================
# SETUP-PROFILE V64 · PERSISTENT / LOKAL / WEB
# =============================================================================

SETUP_PROFILE_ROOT="/home/Data/proxmox-installer"
SETUP_PROFILE_HISTORY_DIR="${SETUP_PROFILE_ROOT}/profiles"
SETUP_PROFILE_IMPORT_DIR="${SETUP_PROFILE_ROOT}/imported"
SETUP_PROFILE_LAST_SETUP="${SETUP_PROFILE_ROOT}/last-setup.json"
SETUP_PROFILE_LAST_SUCCESS="${SETUP_PROFILE_ROOT}/last-success.json"
SETUP_PROFILE_CAPTURE_FILE="/tmp/proxmox-installer-answers.$$"
SETUP_PROFILE_ACTIVE=""
SETUP_PROFILE_SELECTION_READY=0

declare -A SETUP_PROFILE_VALUES=()

: > "$SETUP_PROFILE_CAPTURE_FILE"
chmod 600 "$SETUP_PROFILE_CAPTURE_FILE"

setup_profile_prepare_dirs_v64() {
    mkdir -p \
        "$SETUP_PROFILE_ROOT" \
        "$SETUP_PROFILE_HISTORY_DIR" \
        "$SETUP_PROFILE_IMPORT_DIR"

    chmod 700 \
        "$SETUP_PROFILE_ROOT" \
        "$SETUP_PROFILE_HISTORY_DIR" \
        "$SETUP_PROFILE_IMPORT_DIR"
}

setup_profile_prompt_is_secret_v64() {
    local prompt="${1,,}"

    case "$prompt" in
        *passwort*|*password*|*kennwort*|*token*|*secret*|*sicherheitscode*|*steuer-code*|*webhook*|*api-key*|*apikey*|*private*key*|*credential*|*auth*)
            return 0
            ;;
    esac

    return 1
}

setup_profile_capture_value_v64() {
    local prompt="$1"
    local value="$2"

    setup_profile_prompt_is_secret_v64 "$prompt" && return 0

    local prompt_b64=""
    local value_b64=""

    prompt_b64="$(
        printf '%s' "$prompt" |
        base64 -w0
    )"

    value_b64="$(
        printf '%s' "$value" |
        base64 -w0
    )"

    printf '%s\t%s\n' \
        "$prompt_b64" \
        "$value_b64" \
        >> "$SETUP_PROFILE_CAPTURE_FILE"
}

get_value_interactive() {
    local prompt="$1"
    local default="$2"
    local var=""
    local result=""

    # Ein geladenes Profil ändert nur den vorgeschlagenen Standard.
    if [[ -n "${SETUP_PROFILE_VALUES[$prompt]+set}" ]]; then
        default="${SETUP_PROFILE_VALUES[$prompt]}"
    fi

    if (( TUI_AVAILABLE )); then
        var="$(
            tui_input                 "EINSTELLUNGEN"                 "$prompt"                 "$default"
        )" || return 1

        result="${var:-$default}"

        setup_profile_capture_value_v64             "$prompt"             "$result"

        printf '%s' "$result"
        return 0
    fi

    printf >&2 "  ${BLUE}›${RESET} %-38s ${BOLD}[%s]${RESET}: "         "$prompt" "$default"

    read -r var
    result="${var:-$default}"

    setup_profile_capture_value_v64         "$prompt"         "$result"

    printf '%s' "$result"
}

get_value() {
    local prompt="$1"
    local default="$2"

    if (( ${OPTIMAL_INSTALL:-0} )); then
        # V101: Profile und alte Antworten dürfen die feste Optimal-Konfiguration
        # nicht überschreiben. Der im Script definierte Standard wird übernommen.
        setup_profile_capture_value_v64 "$prompt" "$default"
        printf '%s' "$default"
        return 0
    fi

    get_value_interactive "$prompt" "$default"
}


guest_kind() {
    local id="$1"
    if [[ -e "/etc/pve/qemu-server/${id}.conf" ]]; then
        echo "VM"
    elif [[ -e "/etc/pve/lxc/${id}.conf" ]]; then
        echo "LXC"
    else
        echo ""
    fi
}

guest_name() {
    local id="$1"
    if [[ -e "/etc/pve/qemu-server/${id}.conf" ]]; then
        qm config "$id" 2>/dev/null | awk -F': ' '/^name:/{print $2;exit}'
    elif [[ -e "/etc/pve/lxc/${id}.conf" ]]; then
        pct config "$id" 2>/dev/null | awk -F': ' '/^hostname:/{print $2;exit}'
    fi
}

destroy_guest() {
    local id="$1"
    [[ "$id" =~ ^[0-9]+$ ]] || die "Ungültige VM/CT-ID: $id"

    if [[ -e "/etc/pve/qemu-server/${id}.conf" ]]; then
        local name
        name="$(guest_name "$id")"
        echo "Lösche VM $id${name:+ ($name)} ..."

        if qm status "$id" 2>/dev/null | grep -q "status: running"; then
            qm shutdown "$id" --timeout 30 2>/dev/null || true
            sleep 2
            qm status "$id" 2>/dev/null | grep -q "status: running" && \
                qm stop "$id" --skiplock 1 2>/dev/null || true
        fi

        qm destroy "$id" --purge 1 --destroy-unreferenced-disks 1 2>/dev/null || \
            qm destroy "$id" --purge 1

        ok "VM $id vollständig gelöscht."
        return
    fi

    if [[ -e "/etc/pve/lxc/${id}.conf" ]]; then
        local name
        name="$(guest_name "$id")"
        echo "Lösche LXC $id${name:+ ($name)} ..."

        if pct status "$id" 2>/dev/null | grep -q "status: running"; then
            pct shutdown "$id" --timeout 30 2>/dev/null || true
            sleep 2
            pct status "$id" 2>/dev/null | grep -q "status: running" && \
                pct stop "$id" --skiplock 1 2>/dev/null || pct stop "$id" 2>/dev/null || true
        fi

        pct destroy "$id" --purge 1 2>/dev/null || pct destroy "$id"
        ok "LXC $id vollständig gelöscht."
        return
    fi

    warn "VM/CT-ID $id existiert nicht mehr."
}

show_guests() {
    echo
    echo "------------------------------ VMs ------------------------------"
    qm list 2>/dev/null || true
    echo
    echo "------------------------------ LXC ------------------------------"
    pct list 2>/dev/null || true
    echo
}

manage_guests() {
    while true; do
        header "VM / LXC VERWALTEN"
        show_guests

        echo "Gib eine VM-/CT-ID ein, die vollständig gelöscht werden soll."
        echo "Mit ENTER kommst du zurück zum Installationsmenü."
        echo

        local id
        read -rp "VM/CT-ID: " id
        [[ -n "$id" ]] || return 0
        [[ "$id" =~ ^[0-9]+$ ]] || {
            warn "Bitte nur eine numerische VM-/CT-ID eingeben."
            continue
        }

        if free_id_check "$id"; then
            warn "ID $id ist nicht belegt."
            continue
        fi

        local kind name confirm
        kind="$(guest_kind "$id")"
        name="$(guest_name "$id")"

        echo
        echo "${RED}ACHTUNG:${RESET} $kind $id${name:+ ($name)} inklusive virtueller Datenträger wird gelöscht."
        read -rp "Zur Bestätigung exakt die ID '$id' eingeben: " confirm

        if [[ "$confirm" == "$id" ]]; then
            destroy_guest "$id"
        else
            warn "Nicht gelöscht."
        fi
    done
}

delete_all_lxc_and_managed_ha() {
    header "KOMPLETTER NEUAUFBAU"

    echo "${RED}${BOLD}ACHTUNG: DIESER MODUS IST DESTRUKTIV.${RESET}"
    echo
    echo "Folgendes wird gelöscht:"
    echo "  - ALLE LXC-Container auf diesem Proxmox-Host"
    echo "  - vorhandene VMs mit dem Namen 'homeassistant'"
    echo "  - das bestehende PVE-Dashboard inklusive Messhistorie und Steuer-Code"
    echo
    echo "Andere VMs mit anderen Namen bleiben bestehen."
    echo

    show_guests

    local confirm
    read -rp "Zur Bestätigung exakt 'NEU' eingeben: " confirm
    [[ "$confirm" == "NEU" ]] || {
        warn "Kompletter Neuaufbau abgebrochen."
        return 1
    }

    local ids=()
    mapfile -t ids < <(pct list 2>/dev/null | awk 'NR>1 && $1 ~ /^[0-9]+$/ {print $1}')

    for id in "${ids[@]}"; do
        destroy_guest "$id"
    done

    local vmids=()
    mapfile -t vmids < <(
        qm list 2>/dev/null |
        awk 'NR>1 && $1 ~ /^[0-9]+$/ && $2=="homeassistant" {print $1}'
    )

    for id in "${vmids[@]}"; do
        destroy_guest "$id"
    done

    # Dashboard-Daten erst beim Installationsschritt entfernen, damit
    # eventuell nötige Dienste kontrolliert gestoppt werden können.
    RESET_DASHBOARD_DATA=1

    ok "Bereinigung abgeschlossen. Danach wird alles frisch installiert."
    return 0
}


delete_all_lxc_and_managed_ha_no_confirm() {
    header "KOMPLETTER NEUAUFBAU - OHNE LÖSCHBESTÄTIGUNG"

    echo "${RED}${BOLD}ACHTUNG: SOFORTIGER DESTRUKTIVER MODUS.${RESET}"
    echo
    echo "Es wird KEINE Löschbestätigung abgefragt."
    echo
    echo "Folgendes wird automatisch gelöscht:"
    echo "  - ALLE LXC-Container auf diesem Proxmox-Host"
    echo "  - vorhandene VMs mit dem Namen 'homeassistant'"
    echo "  - das bestehende PVE-Dashboard inklusive Messhistorie und Steuer-Code"
    echo
    echo "Andere VMs mit anderen Namen bleiben bestehen."
    echo
    echo "NICHT gelöscht werden:"
    echo "  - /home/img"
    echo "  - /home/Data"
    echo "  - /root/passwort (V107) + alte /root/pw-*.txt"
    echo
    echo "Abbruch ist jetzt nur noch mit STRG+C möglich."
    echo

    for seconds in 5 4 3 2 1; do
        printf "\rStart der Löschung in %s Sekunden ... " "$seconds"
        sleep 1
    done

    printf "\rStarte Löschung jetzt.                  \n"
    echo

    show_guests

    local ids=()
    local id

    mapfile -t ids < <(
        pct list 2>/dev/null |
        awk 'NR>1 && $1 ~ /^[0-9]+$/ {print $1}'
    )

    for id in "${ids[@]}"; do
        destroy_guest "$id"
    done

    local vmids=()

    mapfile -t vmids < <(
        qm list 2>/dev/null |
        awk 'NR>1 && $1 ~ /^[0-9]+$/ && $2=="homeassistant" {print $1}'
    )

    for id in "${vmids[@]}"; do
        destroy_guest "$id"
    done

    # Dashboard-Daten werden im anschließenden Installationsschritt sauber
    # entfernt, nachdem die zugehörigen Dienste kontrolliert gestoppt wurden.
    RESET_DASHBOARD_DATA=1

    ok "Bereinigung ohne Rückfrage abgeschlossen."
    return 0
}


# =============================================================================
# V101 · OPTIMALE INSTALLATION · KOMPLETTER GUEST-RESET OHNE RÜCKFRAGE
# =============================================================================
# Löscht bewusst ALLE LXC und ALLE VMs. Persistente Installer-/Cache-Daten unter
# /home/img und /home/Data bleiben erhalten. Dadurch kann der optimale Stack
# anschließend mit festen IDs/IPs ab 101 vollständig neu aufgebaut werden.

optimal_install_reset_v100() {
    header "OPTIMALE INSTALLATION · GUEST-RESET"

    echo "${RED}${BOLD}V101 Optimalmodus: alle vorhandenen VMs und LXC werden jetzt ohne Rückfrage gelöscht.${RESET}"
    echo "Erhalten bleiben: /home/img, /home/Data, /root/backups, /root/diagnose."
    echo

    local id=""
    local ids=()

    mapfile -t ids < <(
        pct list 2>/dev/null |
        awk 'NR>1 && $1 ~ /^[0-9]+$/ {print $1}'
    )
    for id in "${ids[@]}"; do
        destroy_guest "$id"
    done

    ids=()
    mapfile -t ids < <(
        qm list 2>/dev/null |
        awk 'NR>1 && $1 ~ /^[0-9]+$/ {print $1}'
    )
    for id in "${ids[@]}"; do
        destroy_guest "$id"
    done

    RESET_DASHBOARD_DATA=1
    RESET_DASHBOARD_APP_ONLY=0
    RESERVED_IDS=()

    ok "Alle VMs/LXC entfernt. Persistente Cache-/Datenbereiche bleiben erhalten."
}

# =============================================================================
# V72 · PROXMOX AUF NULL
# =============================================================================
#
# Ziel:
#   - Proxmox VE selbst bleibt installiert.
#   - Netzwerk, Storage-Konfiguration und Proxmox-Pakete bleiben unangetastet.
#   - ALLE LXC und ALLE VMs werden gelöscht.
#   - Dashboard und vom Master auf dem Host installierte Hilfsdienste werden
#     entfernt.
#   - No-Subscription/Nag-Removal bleibt bewusst bestehen und wird erneut
#     angewendet.
#   - Persistente Benutzer-/Installer-Daten werden NICHT gelöscht:
#       /home/img
#       /home/Data
#       /root/backups
#       /root/diagnose
#       /root/passwort
#       /root/pw-*.txt (Legacy)
#
# Dieser Modus installiert anschließend NICHTS neu.
# =============================================================================

ensure_no_subscription_after_zero_v72() {
    local helper="/usr/local/bin/pve-remove-nag.sh"
    local apt_hook="/etc/apt/apt.conf.d/no-nag-script"

    mkdir -p /usr/local/bin /etc/apt/apt.conf.d

    if [[ ! -s "$helper" ]]; then
        cat > "$helper" <<'EOF'
#!/bin/sh
set -eu

WEB_JS="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"

if [ -s "$WEB_JS" ] && ! grep -q "NoMoreNagging" "$WEB_JS"; then
    sed -i \
        -e '/data\.status/ s/!//' \
        -e '/data\.status/ s/active/NoMoreNagging/' \
        "$WEB_JS"
fi

# NodeZero UI-Patch: "HA State" in der Gast-/Template-Übersicht ist bei
# diesem Setup missverständlich, weil HA = Home Assistant verwendet wird.
# Nur das hamanaged-Statusfeld wird auf "PVE-Failover" umbenannt.
# Der DPkg-Hook führt diesen Patch nach pve-manager-Updates erneut aus.
PVE_MANAGER_JS="/usr/share/pve-manager/js/pvemanagerlib.js"

if [ -s "$PVE_MANAGER_JS" ] && command -v python3 >/dev/null 2>&1; then
    python3 - "$PVE_MANAGER_JS" <<'PVEFAILOVERPY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
try:
    source = path.read_text(encoding="utf-8")
except Exception:
    raise SystemExit(0)

pattern = re.compile(
    r"(itemId\s*:\s*[\"']hamanaged[\"']\s*,[\s\S]{0,800}?title\s*:\s*)gettext\(\s*[\"']HA State[\"']\s*\)",
    re.MULTILINE,
)

patched, count = pattern.subn(r"\1'PVE-Failover'", source)

if count and patched != source:
    path.write_text(patched, encoding="utf-8")
PVEFAILOVERPY
fi

MOBILE_TPL="/usr/share/pve-yew-mobile-gui/index.html.tpl"
MARKER="<!-- MANAGED BLOCK FOR MOBILE NAG -->"

if [ -f "$MOBILE_TPL" ] && ! grep -qF "$MARKER" "$MOBILE_TPL"; then
    cat >> "$MOBILE_TPL" <<'MOBILEEOF'
<!-- MANAGED BLOCK FOR MOBILE NAG -->
<script>
  function removeSubscriptionElements() {
    const dialogs = document.querySelectorAll('dialog.pwt-outer-dialog');

    dialogs.forEach(dialog => {
      const text = (dialog.textContent || '').toLowerCase();

      if (text.includes('subscription')) {
        dialog.remove();
      }
    });

    const cards = document.querySelectorAll(
      '.pwt-card.pwt-p-2.pwt-d-flex.pwt-interactive.pwt-justify-content-center'
    );

    cards.forEach(card => {
      const text = (card.textContent || '').toLowerCase();
      const hasButton = card.querySelector('button');

      if (!hasButton && text.includes('subscription')) {
        card.remove();
      }
    });
  }

  const observer = new MutationObserver(removeSubscriptionElements);

  observer.observe(
    document.body,
    {
      childList: true,
      subtree: true
    }
  );

  removeSubscriptionElements();

  setInterval(
    removeSubscriptionElements,
    300
  );

  setTimeout(
    () => {
      observer.disconnect();
    },
    10000
  );
</script>
MOBILEEOF
fi
EOF

        chmod 755 "$helper"
        chown root:root "$helper"
    fi

    cat > "$apt_hook" <<'EOF'
DPkg::Post-Invoke { "/usr/local/bin/pve-remove-nag.sh"; };
EOF

    chmod 644 "$apt_hook"
    chown root:root "$apt_hook"

    "$helper" || true

    systemctl restart pveproxy.service 2>/dev/null || true

    ok "No-Subscription/Nag-Removal bleibt aktiv."
}

remove_master_host_components_v72() {
    header "HOST-KOMPONENTEN DES MASTER-INSTALLERS ENTFERNEN"

    # Dashboard-Dienste sicher stoppen.
    systemctl disable --now pve-sensor-collector.timer 2>/dev/null || true
    systemctl disable --now pve-pihole-dns-sync.path 2>/dev/null || true
    systemctl disable --now pve-pihole-dns-sync.timer 2>/dev/null || true
    systemctl stop pve-pihole-dns-sync.service 2>/dev/null || true
    systemctl disable --now pve-sensor-web.service 2>/dev/null || true

    # Auto-Updater entfernen.
    systemctl disable --now proxmox-auto-updater.timer 2>/dev/null || true
    systemctl stop proxmox-auto-updater.service 2>/dev/null || true
    systemctl disable --now proxmox-master-tls-renew.timer 2>/dev/null || true
    systemctl stop proxmox-master-tls-renew.service 2>/dev/null || true

    # V74 OpenRGB Host-Steuerung entfernen.
    systemctl disable --now openrgb-proxmox-status.service 2>/dev/null || true
    systemctl disable --now openrgb-proxmox-boot.service 2>/dev/null || true
    systemctl disable --now openrgb-proxmox-server.service 2>/dev/null || true

    # Dashboard / Systemd / nginx / sudoers.
    rm -f \
        /etc/systemd/system/pve-sensor-collector.service \
        /etc/systemd/system/pve-sensor-collector.timer \
        /etc/systemd/system/pve-sensor-web.service \
        /etc/systemd/system/proxmox-auto-updater.service \
        /etc/systemd/system/proxmox-auto-updater.timer \
        /etc/systemd/system/proxmox-master-tls-renew.service \
        /etc/systemd/system/proxmox-master-tls-renew.timer \
        /etc/systemd/system/openrgb-proxmox-server.service \
        /etc/systemd/system/openrgb-proxmox-status.service \
        /etc/systemd/system/openrgb-proxmox-boot.service \
        /etc/nginx/sites-enabled/pve-sensor-dashboard \
        /etc/nginx/sites-available/pve-sensor-dashboard \
        /etc/sudoers.d/pve-sensor-dashboard \
        /etc/modules-load.d/pve-sensor-dashboard.conf

    # Master-Helfer entfernen.
    rm -f \
        /usr/local/sbin/pve-dashboard-set-code \
        /usr/local/sbin/pve-dashboard-link \
        /usr/local/sbin/pve-dashboard-settings-helper \
        /usr/local/sbin/pve-pihole-dns-sync \
        /usr/local/sbin/proxmox-auto-updater \
        /usr/local/sbin/proxmox-auto-updater-config \
        /usr/local/sbin/proxmox-master-tls-renew \
        /usr/local/sbin/pihole-reset-password \
        /usr/local/sbin/pihole-ha-app-password \
        /usr/local/sbin/pihole-auth-manager \
        /usr/local/sbin/pihole-language \
        /usr/local/sbin/proxmox-openrgb \
        /usr/local/lib/openrgb-proxmox-status.py

    # OpenRGB-Konfiguration des Master-Installers entfernen.
    rm -f \
        /etc/openrgb-proxmox.conf \
        /etc/openrgb-proxmox-status.conf \
        /etc/modules-load.d/openrgb-proxmox.conf

    if dpkg-query -W -f='${Status}' openrgb 2>/dev/null | grep -q 'install ok installed'; then
        apt-get purge -y openrgb 2>/dev/null || true
    fi

    # Dashboard-Daten/Code entfernen.
    rm -rf \
        /opt/nodezero/dashboard \
        /etc/pve-sensor-dashboard \
        /var/lib/pve-sensor-dashboard \
        /var/lib/pve-sensor-dashboard-web \
        /var/lib/pve-pihole-dns-sync \
        /etc/pve-pihole-dns-sync

    # Auto-Updater Laufzeitdaten/Secrets entfernen.
    rm -rf \
        /var/lib/proxmox-auto-updater \
        /var/log/proxmox-auto-updater \
        /root/.config/proxmox-auto-updater

    # Dashboard-nginx-Logs entfernen.
    rm -f \
        /var/log/nginx/pve-sensor-dashboard.access.log \
        /var/log/nginx/pve-sensor-dashboard.error.log \
        /var/log/nginx/pve-sensor-dashboard.ssl.access.log \
        /var/log/nginx/pve-sensor-dashboard.ssl.error.log

    # Die persistente CA unter /home/Data bleibt erhalten.
    # Nur die Host-Trust-Kopie wird entfernt, damit der Host wieder möglichst
    # neutral ist.
    rm -f /usr/local/share/ca-certificates/nodezero-local-ca.crt
    update-ca-certificates >/dev/null 2>&1 || true

    systemctl daemon-reload

    if command -v nginx >/dev/null 2>&1; then
        nginx -t >/dev/null 2>&1 && \
            systemctl reload nginx 2>/dev/null || true
    fi

    # pve-monitor wird ausschließlich vom Dashboard benutzt.
    if id pve-monitor >/dev/null 2>&1; then
        userdel pve-monitor 2>/dev/null || true
    fi

    if getent group pve-monitor >/dev/null 2>&1; then
        groupdel pve-monitor 2>/dev/null || true
    fi

    ok "Installer-Hostdienste entfernt."
}


clean_local_vz_storage_v73() {
    header "LOKALE PROXMOX-DATENBEREICHE LEEREN"

    local dir=""
    local deleted_any=0

    for dir in \
        /var/lib/vz/template/iso \
        /var/lib/vz/dump \
        /var/lib/vz/images \
        /var/lib/vz/template/cache
    do
        if [[ ! -d "$dir" ]]; then
            echo "Überspringe (nicht vorhanden): $dir"
            continue
        fi

        echo "Leere: $dir"

        if find "$dir" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
            find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
            deleted_any=1
            ok "$dir wurde geleert."
        else
            echo "  Bereits leer."
        fi
    done

    if (( deleted_any == 0 )); then
        echo "Es waren keine zusätzlichen lokalen ISO/Backups/Images/Templates vorhanden."
    fi

    ok "Lokale Proxmox-Datenbereiche bereinigt."
}

proxmox_zero_v72() {
    header "PROXMOX AUF NULL"

    echo "${RED}${BOLD}ACHTUNG: MAXIMAL DESTRUKTIVER MODUS.${RESET}"
    echo
    echo "Dieser Punkt löscht:"
    echo "  - ALLE LXC-Container"
    echo "  - ALLE virtuellen Maschinen"
    echo "  - ALLE zugehörigen virtuellen Datenträger über qm/pct destroy"
    echo "  - /var/lib/vz/template/iso/*"
    echo "  - /var/lib/vz/dump/*"
    echo "  - /var/lib/vz/images/*"
    echo "  - /var/lib/vz/template/cache/*"
    echo "  - Server-Dashboard inkl. Historie, Layout, Links und Einstellungen"
    echo "  - Master-Auto-Updater inkl. Pushover-Konfiguration"
    echo "  - vom Master angelegte Dashboard-/Pi-hole-Hilfsprogramme"
    echo
    echo "Proxmox VE selbst bleibt installiert."
    echo
    echo "BEWUSST ERHALTEN:"
    echo "  - No-Subscription / Subscription-Nag-Removal"
    echo "  - Proxmox Netzwerk-Konfiguration"
    echo "  - Proxmox Storage-Konfiguration"
    echo "  - /home/img"
    echo "  - /home/Data inkl. Setup-Profile und Local-CA-Quelldateien"
    echo "  - /root/backups"
    echo "  - /root/diagnose"
    echo "  - /root/passwort (V107) + alte /root/pw-*.txt"
    echo
    echo "Danach wird NICHT automatisch neu installiert."
    echo "Der Host bleibt als leerer Proxmox-Host stehen."
    echo

    show_guests

    local confirm=""
    read -rp "Zur Bestätigung exakt 'NULL' eingeben: " confirm

    if [[ "$confirm" != "NULL" ]]; then
        warn "Proxmox-Auf-Null wurde abgebrochen."
        return 1
    fi

    echo
    echo "Letzte Abbruchmöglichkeit: STRG+C"
    echo

    local seconds
    for seconds in 5 4 3 2 1; do
        printf "\rLöschung startet in %s Sekunden ... " "$seconds"
        sleep 1
    done

    printf "\rStarte vollständige Gast-Bereinigung.       \n"
    echo

    # Kleine Host-Konfigurationssicherung, KEINE Gast-Datenträger und KEINE ISO-/Dump-Dateien.
    local backup="${BACKUP_ROOT}/proxmox-null-v72-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup"
    chmod 700 "$backup"

    for path in \
        /etc/pve-sensor-dashboard \
        /var/lib/pve-sensor-dashboard-web \
        /etc/systemd/system/pve-sensor-web.service \
        /etc/systemd/system/pve-pihole-dns-sync.service \
        /etc/systemd/system/pve-pihole-dns-sync.path \
        /etc/systemd/system/pve-pihole-dns-sync.timer \
        /etc/systemd/system/pve-sensor-collector.service \
        /etc/systemd/system/pve-sensor-collector.timer \
        /etc/systemd/system/proxmox-auto-updater.service \
        /etc/systemd/system/proxmox-auto-updater.timer \
        /etc/nginx/sites-available/pve-sensor-dashboard
    do
        [[ -e "$path" ]] || continue
        cp -a "$path" "$backup/" 2>/dev/null || true
    done

    local id=""
    local ids=()

    # 1. ALLE LXC.
    mapfile -t ids < <(
        pct list 2>/dev/null |
        awk 'NR>1 && $1 ~ /^[0-9]+$/ {print $1}'
    )

    for id in "${ids[@]}"; do
        destroy_guest "$id"
    done

    # 2. ALLE VMs.
    ids=()

    mapfile -t ids < <(
        qm list 2>/dev/null |
        awk 'NR>1 && $1 ~ /^[0-9]+$/ {print $1}'
    )

    for id in "${ids[@]}"; do
        destroy_guest "$id"
    done

    # 3. Lokale ISO-/Backup-/Image-/Template-Verzeichnisse bereinigen.
    clean_local_vz_storage_v73

    # 4. Host-Komponenten des Master-Installers entfernen.
    remove_master_host_components_v72

    # 5. No-Subscription explizit wieder sicherstellen.
    ensure_no_subscription_after_zero_v72

    echo
    header "PROXMOX IST AUF NULL"

    echo "Verbleibende Gäste:"
    echo

    local remaining_lxc=""
    local remaining_vm=""

    remaining_lxc="$(
        pct list 2>/dev/null |
        awk 'NR>1 && $1 ~ /^[0-9]+$/ {print $1}' |
        paste -sd, -
    )"

    remaining_vm="$(
        qm list 2>/dev/null |
        awk 'NR>1 && $1 ~ /^[0-9]+$/ {print $1}' |
        paste -sd, -
    )"

    if [[ -n "$remaining_lxc" || -n "$remaining_vm" ]]; then
        warn "Es sind noch Gäste vorhanden."
        [[ -n "$remaining_lxc" ]] && echo "  LXC: $remaining_lxc"
        [[ -n "$remaining_vm" ]] && echo "  VM:  $remaining_vm"
        return 1
    fi

    ok "Keine VM und kein LXC mehr vorhanden."
    ok "Proxmox VE selbst wurde nicht entfernt."
    ok "No-Subscription bleibt aktiv."

    echo
    echo "Erhaltene Daten:"
    echo "  /home/img"
    echo "  /home/Data"
    echo "  /root/backups"
    echo "  /root/diagnose"
    echo
    echo "Reset-Backup:"
    echo "  $backup"
    echo

    return 0
}



# =============================================================================
# V74 · OPENRGB HOST-STEUERUNG
# =============================================================================
#
# OpenRGB läuft bewusst direkt auf dem Proxmox-Host, weil Mainboard/RAM/USB-
# RGB physische Host-Hardware sind. Der SDK-Server bindet ausschließlich an
# 127.0.0.1:6742 und wird NICHT ins LAN freigegeben.
#
# Die optionale Statusanzeige nutzt OpenRGB nur als Ausgabegerät:
#   - Kritischer Fehler -> Rot
#   - Warnung           -> Orange/Rot
#   - normale CPU-Last  -> Grün / Gelb / Orange
#
# OpenRGB selbst ist kein Proxmox-Fehlermonitor. Die Fehler-/Lastlogik kommt
# daher aus dem von V74 installierten Statusdienst.
# =============================================================================

install_openrgb_manager_v74() {
    local manager="/usr/local/sbin/proxmox-openrgb"

    mkdir -p \
        /usr/local/sbin \
        /usr/local/lib \
        /root/backups \
        /root/diagnose

    cat > "$manager" <<'__OPENRGB_MANAGER_V74__'
#!/usr/bin/env bash
set -Eeuo pipefail

BACKUP_ROOT="/root/backups"
DIAGNOSE_ROOT="/root/diagnose"

OPENRGB_BIN="/usr/bin/openrgb"
OPENRGB_SERVER_SERVICE="openrgb-proxmox-server.service"
OPENRGB_STATUS_SERVICE="openrgb-proxmox-status.service"
OPENRGB_BOOT_SERVICE="openrgb-proxmox-boot.service"

OPENRGB_CONFIG="/etc/openrgb-proxmox.conf"
OPENRGB_STATUS_CONFIG="/etc/openrgb-proxmox-status.conf"
OPENRGB_STATUS_SCRIPT="/usr/local/lib/openrgb-proxmox-status.py"
OPENRGB_STATE="/run/openrgb-proxmox-status.json"

OPENRGB_RELEASES_URL="https://openrgb.org/releases.html"
OPENRGB_SDK_HOST="127.0.0.1"
OPENRGB_SDK_PORT="6742"

mkdir -p "$BACKUP_ROOT" "$DIAGNOSE_ROOT"

have_tui() {
    command -v whiptail >/dev/null 2>&1 \
        && [[ -t 0 ]] \
        && [[ -t 1 ]]
}

msg() {
    local title="$1"
    shift

    if have_tui; then
        whiptail \
            --title "$title" \
            --msgbox "$*" \
            20 86
    else
        echo
        echo "=== $title ==="
        printf '%s\n' "$*"
        echo
    fi
}

ask() {
    local title="$1"
    local prompt="$2"
    local default="${3:-}"
    local value=""

    if have_tui; then
        value="$(
            whiptail \
                --title "$title" \
                --inputbox "$prompt" \
                12 86 \
                "$default" \
                3>&1 1>&2 2>&3
        )" || return 1
    else
        read -rp "$prompt [$default]: " value
        value="${value:-$default}"
    fi

    printf '%s' "$value"
}

choose() {
    local title="$1"
    local prompt="$2"
    shift 2

    if have_tui; then
        whiptail \
            --title "$title" \
            --menu "$prompt" \
            24 92 14 \
            "$@" \
            3>&1 1>&2 2>&3
    else
        local args=("$@")
        local i=0

        # V76 · REGRESSIONSSCHUTZ:
        # choose() läuft in selected="$(choose ...)". Deshalb dürfen Menütext
        # und Optionen NIEMALS auf STDOUT gehen. Sonst landet der komplette
        # Menütext zusammen mit "1", "2", ... in der Variable "selected" und
        # kein case-Zweig wird getroffen.
        #
        # UI-Ausgabe -> STDERR
        # Rückgabewert -> ausschließlich STDOUT
        {
            echo
            echo "$title"
            echo "$prompt"

            while (( i < ${#args[@]} )); do
                printf '  %s) %s\n' \
                    "${args[$i]}" \
                    "${args[$((i + 1))]}"
                i=$((i + 2))
            done
        } >&2

        read -rp "Auswahl: " REPLY
        printf '%s' "$REPLY"
    fi
}

need_openrgb() {
    if [[ ! -x "$OPENRGB_BIN" ]]; then
        msg \
            "OPENRGB" \
            "OpenRGB ist noch nicht installiert.

Bitte zuerst 'Installieren / Aktualisieren' wählen."
        return 1
    fi

    return 0
}

default_main_config() {
    if [[ ! -f "$OPENRGB_CONFIG" ]]; then
        cat > "$OPENRGB_CONFIG" <<'EOF'
BOOT_MODE="unchanged"
STATIC_COLOR="FFFFFF"
STATIC_BRIGHTNESS="25"
EOF
        chmod 644 "$OPENRGB_CONFIG"
    fi
}

default_status_config() {
    if [[ ! -f "$OPENRGB_STATUS_CONFIG" ]]; then
        cat > "$OPENRGB_STATUS_CONFIG" <<'EOF'
INTERVAL="5"
BRIGHTNESS="25"

CPU_GREEN_MAX="40"
CPU_YELLOW_MAX="70"

TEMP_WARN="75"
TEMP_CRIT="85"

DISK_WARN="85"
DISK_CRIT="95"

CHECK_FAILED_UNITS="1"
CHECK_PVE_STORAGE="1"
CHECK_CLUSTER_QUORUM="1"

COLOR_LOW="00FF00"
COLOR_MEDIUM="FFFF00"
COLOR_HIGH="FF8000"
COLOR_WARNING="FF5500"
COLOR_CRITICAL="FF0000"
EOF
        chmod 644 "$OPENRGB_STATUS_CONFIG"
    fi
}

source_main_config() {
    default_main_config
    # shellcheck disable=SC1090
    source "$OPENRGB_CONFIG"
}

source_status_config() {
    default_status_config
    # shellcheck disable=SC1090
    source "$OPENRGB_STATUS_CONFIG"
}

validate_hex() {
    [[ "${1^^}" =~ ^[0-9A-F]{6}$ ]]
}

validate_int_range() {
    local value="$1"
    local min="$2"
    local max="$3"

    [[ "$value" =~ ^[0-9]+$ ]] || return 1
    (( value >= min && value <= max ))
}

find_latest_openrgb_appimage() {
    local deb_arch=""
    local app_arch=""
    local html=""
    local url=""

    deb_arch="$(dpkg --print-architecture)"

    case "$deb_arch" in
        amd64) app_arch="x86_64" ;;
        arm64) app_arch="arm64" ;;
        i386)  app_arch="i386" ;;
        armhf) app_arch="armhf" ;;
        *)
            echo "Nicht unterstützte Architektur für automatischen OpenRGB-Download: $deb_arch" >&2
            return 1
            ;;
    esac

    html="$(
        curl \
            -fsSL \
            --retry 3 \
            --retry-delay 1 \
            --connect-timeout 15 \
            --max-time 60 \
            "$OPENRGB_RELEASES_URL"
    )"

    url="$(
        python3 -c '
import html as html_mod
import re
import sys

arch = sys.argv[1]
page = html_mod.unescape(sys.stdin.read())

# Die Release-Seite ist absteigend sortiert. Der erste Treffer ist deshalb
# das aktuelle stabile AppImage für die gewünschte Architektur.
pattern = (
    r"https://codeberg\.org/OpenRGB/OpenRGB/releases/download/"
    r"[^\\\"\x27<> ]+/"
    r"OpenRGB_[^\\\"\x27<> ]+_"
    + re.escape(arch)
    + r"_[^\\\"\x27<> ]+\.AppImage"
)

match = re.search(pattern, page, re.I)
if match:
    print(match.group(0))
' "$app_arch" <<<"$html"
    )"

    [[ -n "$url" ]] || {
        echo "Aktuelles OpenRGB-AppImage konnte auf openrgb.org nicht gefunden werden." >&2
        return 1
    }

    printf '%s\n' "$url"
}

write_openrgb_units() {
    cat > "/etc/systemd/system/${OPENRGB_SERVER_SERVICE}" <<EOF
[Unit]
Description=OpenRGB SDK Server for Proxmox host RGB
After=local-fs.target
ConditionPathExists=${OPENRGB_BIN}

[Service]
Type=simple
# OpenRGB/Qt läuft auf dem Proxmox-Host ohne grafische Sitzung.
Environment=QT_QPA_PLATFORM=offscreen
ExecStart=${OPENRGB_BIN} --server --server-host ${OPENRGB_SDK_HOST} --server-port ${OPENRGB_SDK_PORT}
Restart=on-failure
RestartSec=3
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

    cat > "/etc/systemd/system/${OPENRGB_STATUS_SERVICE}" <<EOF
[Unit]
Description=OpenRGB Proxmox health and load indicator
After=${OPENRGB_SERVER_SERVICE}
Requires=${OPENRGB_SERVER_SERVICE}

[Service]
Type=simple
ExecStart=/usr/bin/python3 ${OPENRGB_STATUS_SCRIPT}
Restart=on-failure
RestartSec=5
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

    cat > "/etc/systemd/system/${OPENRGB_BOOT_SERVICE}" <<EOF
[Unit]
Description=Apply configured OpenRGB boot state
After=${OPENRGB_SERVER_SERVICE}
Requires=${OPENRGB_SERVER_SERVICE}

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/proxmox-openrgb --apply-boot
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
}

write_status_script() {
    cat > "$OPENRGB_STATUS_SCRIPT" <<'PYOPENRGB'
#!/usr/bin/env python3

import json
import os
from pathlib import Path
import re
import subprocess
import time

CONFIG = Path(
    "/etc/openrgb-proxmox-status.conf"
)

STATE = Path(
    "/run/openrgb-proxmox-status.json"
)

OPENRGB = "/usr/bin/openrgb"
SDK = "127.0.0.1:6742"


def read_shell_config(path):
    result = {}

    try:
        lines = path.read_text(
            encoding="utf-8"
        ).splitlines()
    except Exception:
        return result

    for line in lines:
        line = line.strip()

        if (
            not line
            or line.startswith("#")
            or "=" not in line
        ):
            continue

        key, value = line.split(
            "=",
            1,
        )

        key = key.strip()
        value = value.strip().strip(
            "\"'"
        )

        if re.fullmatch(
            r"[A-Z0-9_]+",
            key,
        ):
            result[key] = value

    return result


def cfg_int(cfg, key, default, low, high):
    try:
        value = int(
            cfg.get(
                key,
                default,
            )
        )
    except Exception:
        value = default

    return max(
        low,
        min(
            high,
            value,
        ),
    )


def cfg_bool(cfg, key, default=True):
    raw = str(
        cfg.get(
            key,
            "1" if default else "0",
        )
    ).lower()

    return raw in {
        "1",
        "true",
        "yes",
        "ja",
        "on",
    }


def cfg_color(cfg, key, default):
    value = str(
        cfg.get(
            key,
            default,
        )
    ).strip().upper()

    if not re.fullmatch(
        r"[0-9A-F]{6}",
        value,
    ):
        return default

    return value


def command(
    args,
    timeout=10,
):
    try:
        return subprocess.run(
            args,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
    except Exception:
        return None


def cpu_snapshot():
    try:
        fields = (
            Path("/proc/stat")
            .read_text(
                encoding="utf-8"
            )
            .splitlines()[0]
            .split()[1:]
        )

        values = [
            int(item)
            for item in fields
        ]

        idle = (
            values[3]
            + (
                values[4]
                if len(values) > 4
                else 0
            )
        )

        total = sum(values)

        return total, idle
    except Exception:
        return None


def cpu_percent(previous):
    current = cpu_snapshot()

    if (
        previous is None
        or current is None
    ):
        return current, 0.0

    total_delta = (
        current[0]
        - previous[0]
    )

    idle_delta = (
        current[1]
        - previous[1]
    )

    if total_delta <= 0:
        return current, 0.0

    busy = (
        total_delta
        - idle_delta
    )

    pct = (
        busy
        * 100.0
        / total_delta
    )

    return (
        current,
        max(
            0.0,
            min(
                100.0,
                pct,
            ),
        ),
    )


def max_temperature():
    values = []

    candidates = []

    candidates.extend(
        Path("/sys/class/thermal").glob(
            "thermal_zone*/temp"
        )
    )

    candidates.extend(
        Path("/sys/class/hwmon").glob(
            "hwmon*/temp*_input"
        )
    )

    for path in candidates:
        try:
            raw = float(
                path.read_text(
                    encoding="utf-8"
                ).strip()
            )

            value = (
                raw / 1000.0
                if raw > 200
                else raw
            )

            if 0.0 < value < 130.0:
                values.append(value)
        except Exception:
            continue

    if not values:
        return None

    return max(values)


def root_disk_percent():
    try:
        stat = os.statvfs("/")

        total = (
            stat.f_blocks
            * stat.f_frsize
        )

        available = (
            stat.f_bavail
            * stat.f_frsize
        )

        if total <= 0:
            return 0.0

        used = (
            total
            - available
        )

        return (
            used
            * 100.0
            / total
        )
    except Exception:
        return 0.0


def failed_units():
    result = command(
        [
            "systemctl",
            "--failed",
            "--no-legend",
            "--plain",
        ],
        timeout=8,
    )

    if result is None:
        return 0

    lines = [
        line
        for line in result.stdout.splitlines()
        if line.strip()
    ]

    return len(lines)


def inactive_pve_storage():
    if not Path(
        "/usr/sbin/pvesm"
    ).exists():
        return []

    result = command(
        [
            "/usr/sbin/pvesm",
            "status",
        ],
        timeout=10,
    )

    if (
        result is None
        or result.returncode != 0
    ):
        return []

    bad = []

    for line in result.stdout.splitlines()[1:]:
        parts = line.split()

        if len(parts) < 3:
            continue

        name = parts[0]
        status = parts[2].lower()

        if status != "active":
            bad.append(name)

    return bad


def cluster_quorate():
    if not Path(
        "/etc/pve/corosync.conf"
    ).exists():
        return True

    result = command(
        [
            "/usr/bin/pvecm",
            "status",
        ],
        timeout=10,
    )

    if (
        result is None
        or result.returncode != 0
    ):
        return False

    text = (
        result.stdout
        + "\n"
        + result.stderr
    )

    match = re.search(
        r"Quorate:\s+(Yes|No)",
        text,
        re.I,
    )

    if not match:
        return False

    return (
        match.group(1).lower()
        == "yes"
    )


def openrgb_device_indices():
    result = command(
        [
            OPENRGB,
            "--client",
            SDK,
            "--list-devices",
        ],
        timeout=15,
    )

    if result is None:
        return []

    text = (
        result.stdout
        + "\n"
        + result.stderr
    )

    devices = []

    for line in text.splitlines():
        match = re.match(
            r"^\s*(\d+):",
            line,
        )

        if not match:
            continue

        device = int(
            match.group(1)
        )

        if device not in devices:
            devices.append(device)

    return sorted(devices)


def apply_color_device(
    device,
    color,
    brightness,
):
    attempts = [
        [
            OPENRGB,
            "--client",
            SDK,
            "--device",
            str(device),
            "--mode",
            "Direct",
            "--color",
            color,
            "--brightness",
            str(brightness),
        ],
        [
            OPENRGB,
            "--client",
            SDK,
            "--device",
            str(device),
            "--mode",
            "Static",
            "--color",
            color,
            "--brightness",
            str(brightness),
        ],
        [
            OPENRGB,
            "--client",
            SDK,
            "--device",
            str(device),
            "--color",
            color,
            "--brightness",
            str(brightness),
        ],
        [
            OPENRGB,
            "--client",
            SDK,
            "--device",
            str(device),
            "--color",
            color,
        ],
    ]

    for args in attempts:
        result = command(
            args,
            timeout=15,
        )

        if (
            result is not None
            and result.returncode == 0
        ):
            return True

    return False


def apply_color(
    color,
    brightness,
):
    devices = openrgb_device_indices()

    if not devices:
        return False

    success = True

    for device in devices:
        if not apply_color_device(
            device,
            color,
            brightness,
        ):
            success = False

    return success


def write_state(payload):
    try:
        STATE.write_text(
            json.dumps(
                payload,
                ensure_ascii=False,
                indent=2,
            ) + "\n",
            encoding="utf-8",
        )
    except Exception:
        pass


def main():
    previous_cpu = cpu_snapshot()
    previous_color = None
    previous_brightness = None

    while True:
        cfg = read_shell_config(
            CONFIG
        )

        interval = cfg_int(
            cfg,
            "INTERVAL",
            5,
            2,
            60,
        )

        brightness = cfg_int(
            cfg,
            "BRIGHTNESS",
            25,
            1,
            100,
        )

        cpu_green = cfg_int(
            cfg,
            "CPU_GREEN_MAX",
            40,
            1,
            95,
        )

        cpu_yellow = cfg_int(
            cfg,
            "CPU_YELLOW_MAX",
            70,
            cpu_green + 1,
            99,
        )

        temp_warn = cfg_int(
            cfg,
            "TEMP_WARN",
            75,
            40,
            110,
        )

        temp_crit = cfg_int(
            cfg,
            "TEMP_CRIT",
            85,
            temp_warn + 1,
            120,
        )

        disk_warn = cfg_int(
            cfg,
            "DISK_WARN",
            85,
            50,
            99,
        )

        disk_crit = cfg_int(
            cfg,
            "DISK_CRIT",
            95,
            disk_warn + 1,
            100,
        )

        previous_cpu, cpu = cpu_percent(
            previous_cpu
        )

        temperature = max_temperature()
        disk = root_disk_percent()

        failed = (
            failed_units()
            if cfg_bool(
                cfg,
                "CHECK_FAILED_UNITS",
                True,
            )
            else 0
        )

        inactive_storage = (
            inactive_pve_storage()
            if cfg_bool(
                cfg,
                "CHECK_PVE_STORAGE",
                True,
            )
            else []
        )

        quorum_ok = (
            cluster_quorate()
            if cfg_bool(
                cfg,
                "CHECK_CLUSTER_QUORUM",
                True,
            )
            else True
        )

        critical_reasons = []
        warning_reasons = []

        if failed > 0:
            critical_reasons.append(
                f"{failed} fehlerhafte systemd-Unit(s)"
            )

        if inactive_storage:
            critical_reasons.append(
                "PVE-Storage inaktiv: "
                + ", ".join(
                    inactive_storage
                )
            )

        if not quorum_ok:
            critical_reasons.append(
                "Cluster nicht quorate"
            )

        if (
            temperature is not None
            and temperature >= temp_crit
        ):
            critical_reasons.append(
                f"Temperatur {temperature:.1f} C"
            )
        elif (
            temperature is not None
            and temperature >= temp_warn
        ):
            warning_reasons.append(
                f"Temperatur {temperature:.1f} C"
            )

        if disk >= disk_crit:
            critical_reasons.append(
                f"Root-Disk {disk:.1f}%"
            )
        elif disk >= disk_warn:
            warning_reasons.append(
                f"Root-Disk {disk:.1f}%"
            )

        if critical_reasons:
            state = "kritisch"
            color = cfg_color(
                cfg,
                "COLOR_CRITICAL",
                "FF0000",
            )
            reasons = critical_reasons
        elif warning_reasons:
            state = "warnung"
            color = cfg_color(
                cfg,
                "COLOR_WARNING",
                "FF5500",
            )
            reasons = warning_reasons
        elif cpu <= cpu_green:
            state = "normal"
            color = cfg_color(
                cfg,
                "COLOR_LOW",
                "00FF00",
            )
            reasons = [
                f"CPU {cpu:.1f}%"
            ]
        elif cpu <= cpu_yellow:
            state = "last_mittel"
            color = cfg_color(
                cfg,
                "COLOR_MEDIUM",
                "FFFF00",
            )
            reasons = [
                f"CPU {cpu:.1f}%"
            ]
        else:
            state = "last_hoch"
            color = cfg_color(
                cfg,
                "COLOR_HIGH",
                "FF8000",
            )
            reasons = [
                f"CPU {cpu:.1f}%"
            ]

        changed = (
            color != previous_color
            or brightness != previous_brightness
        )

        applied = True

        if changed:
            applied = apply_color(
                color,
                brightness,
            )

            if applied:
                previous_color = color
                previous_brightness = brightness

        payload = {
            "state": state,
            "color": color,
            "brightness": brightness,
            "cpu_pct": round(cpu, 1),
            "temperature_c": (
                round(
                    temperature,
                    1,
                )
                if temperature is not None
                else None
            ),
            "root_disk_pct": round(
                disk,
                1,
            ),
            "failed_units": failed,
            "inactive_storage": inactive_storage,
            "cluster_quorate": quorum_ok,
            "reasons": reasons,
            "openrgb_applied": applied,
            "updated": time.strftime(
                "%Y-%m-%d %H:%M:%S"
            ),
        }

        write_state(
            payload
        )

        time.sleep(
            interval
        )


if __name__ == "__main__":
    main()
PYOPENRGB

    chmod 755 "$OPENRGB_STATUS_SCRIPT"
    python3 -m py_compile "$OPENRGB_STATUS_SCRIPT"
}

install_update_openrgb() {
    local url=""
    local tmp=""
    local install_dir="/opt/openrgb-nodezero"
    local appimage="${install_dir}/OpenRGB.AppImage"
    local wrapper="/usr/bin/openrgb"

    echo
    echo "OpenRGB wird als offizielles AppImage von der OpenRGB-Release-Seite installiert."
    echo "Damit vermeiden wir die OpenRGB-1.0-DEB-Abhängigkeit auf hidapi-hotplug 0.15,"
    echo "die in Debian 13/Trixie nicht als reguläres Paket vorhanden ist."
    echo

    apt-get update

    apt-get install -y \
        ca-certificates \
        curl \
        python3 \
        whiptail \
        i2c-tools \
        lm-sensors \
        pciutils \
        usbutils \
        libegl1 \
        libgl1 \
        libopengl0

    # Das offizielle OpenRGB-AppImage enthält absichtlich nicht jede
    # Grafik-/Treiber-Laufzeitbibliothek des Hosts. Auf einem schlanken
    # Proxmox/Debian-13-System fehlt insbesondere libEGL.so.1 ohne libegl1.
    # Der SDK-Server benötigt die Bibliothek auch im Qt-Offscreen-Betrieb.
    ldconfig

    if ! ldconfig -p 2>/dev/null | grep -qE 'libEGL\.so\.1([[:space:]]|$)'; then
        echo "FEHLER: libEGL.so.1 fehlt trotz installiertem Paket libegl1." >&2
        return 1
    fi

    url="$(find_latest_openrgb_appimage)"

    echo "Download:"
    echo "  $url"

    tmp="$(mktemp /tmp/OpenRGB-latest.XXXXXX.AppImage)"
    trap 'rm -f -- "${tmp:-}"' RETURN

    curl \
        -fL \
        --retry 3 \
        --retry-delay 2 \
        --connect-timeout 15 \
        --max-time 300 \
        "$url" \
        -o "$tmp"

    [[ -s "$tmp" ]] || {
        echo "FEHLER: Das heruntergeladene OpenRGB-AppImage ist leer." >&2
        return 1
    }
    chmod 755 "$tmp"

    # Ein früher fehlgeschlagener .deb-Installationsversuch darf keinen
    # /usr/bin/openrgb-Pfad oder halb konfigurierten Paketstatus hinterlassen.
    systemctl disable --now "$OPENRGB_STATUS_SERVICE" 2>/dev/null || true
    systemctl disable --now "$OPENRGB_BOOT_SERVICE" 2>/dev/null || true
    systemctl disable --now "$OPENRGB_SERVER_SERVICE" 2>/dev/null || true

    if dpkg-query -W -f='${Status}' openrgb 2>/dev/null | grep -qE 'install ok (installed|unpacked|half-configured)'; then
        apt-get purge -y openrgb 2>/dev/null || \
            dpkg --remove --force-remove-reinstreq openrgb 2>/dev/null || true
        apt-get -f install -y || true
    fi

    mkdir -p "$install_dir"
    install -m 0755 "$tmp" "$appimage"

    cat > "$wrapper" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
# NODEZERO_OPENRGB_APPIMAGE_WRAPPER
APPIMAGE="/opt/openrgb-nodezero/OpenRGB.AppImage"
[[ -x "$APPIMAGE" ]] || {
    echo "OpenRGB AppImage fehlt: $APPIMAGE" >&2
    exit 127
}
# --appimage-extract-and-run benötigt kein FUSE-Paket und ist deshalb auch auf
# einem schlanken/headless Proxmox-Host zuverlässig nutzbar.
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}"
exec "$APPIMAGE" --appimage-extract-and-run "$@"
EOF
    chmod 755 "$wrapper"
    chown root:root "$wrapper" "$appimage"

    command -v openrgb >/dev/null 2>&1 || {
        echo "FEHLER: OpenRGB-Wrapper wurde nicht installiert." >&2
        return 1
    }

    # V111 · RUNTIME-PREFLIGHT:
    # Nicht erst systemd in eine Restart-Schleife laufen lassen. Das AppImage
    # wird einmal direkt gestartet. So fallen fehlende Host-Bibliotheken wie
    # libEGL.so.1 bereits hier mit einer verständlichen Diagnose auf.
    local runtime_log="/tmp/openrgb-runtime-check.$$"
    if ! timeout 45 openrgb --version >"$runtime_log" 2>&1; then
        echo "FEHLER: OpenRGB-AppImage kann auf diesem Proxmox-Host nicht gestartet werden." >&2
        echo >&2
        cat "$runtime_log" >&2 || true
        echo >&2

        if grep -q 'libEGL.so.1' "$runtime_log" 2>/dev/null; then
            echo "Hinweis: libEGL.so.1 wird durch das Debian-Paket libegl1 bereitgestellt." >&2
        fi

        rm -f "$runtime_log"
        return 1
    fi
    rm -f "$runtime_log"

    modprobe i2c-dev 2>/dev/null || true

    cat > /etc/modules-load.d/openrgb-proxmox.conf <<'EOF'
i2c-dev
EOF

    default_main_config
    default_status_config
    write_status_script
    write_openrgb_units

    systemctl daemon-reload
    systemctl enable --now "$OPENRGB_SERVER_SERVICE"

    sleep 4

    if ! systemctl is-active --quiet "$OPENRGB_SERVER_SERVICE"; then
        echo "FEHLER: OpenRGB SDK-Server konnte nicht gestartet werden." >&2
        journalctl -u "$OPENRGB_SERVER_SERVICE" -n 80 --no-pager || true
        return 1
    fi

    echo
    echo "Installierte Version:"
    openrgb --version || true

    echo
    echo "Erkannte RGB-Geräte:"
    openrgb \
        --client "${OPENRGB_SDK_HOST}:${OPENRGB_SDK_PORT}" \
        --list-devices \
        || true

    echo
    echo "Hinweis:"
    echo "Nicht jedes Mainboard/RAM-Modul wird von OpenRGB unterstützt."
    echo "Es wird nur das generische i2c-dev-Modul geladen; experimentelle"
    echo "Mainboard-spezifische Kernel-Treiber werden nicht automatisch aktiviert."

    rm -f -- "$tmp"
    trap - RETURN

    read -rp "ENTER zum Fortfahren ..."
}

ensure_server() {
    need_openrgb || return 1

    write_status_script
    write_openrgb_units

    systemctl enable --now "$OPENRGB_SERVER_SERVICE"

    sleep 2
}

show_devices() {
    need_openrgb || return 1
    ensure_server

    clear 2>/dev/null || true

    echo "============================================================"
    echo " OPENRGB · ERKANNTE GERÄTE"
    echo "============================================================"
    echo

    openrgb \
        --client "${OPENRGB_SDK_HOST}:${OPENRGB_SDK_PORT}" \
        --list-detailed \
        || true

    echo
    read -rp "ENTER zum Fortfahren ..."
}

openrgb_device_indices_v77() {
    openrgb \
        --client "${OPENRGB_SDK_HOST}:${OPENRGB_SDK_PORT}" \
        --list-devices \
        2>&1 \
    | sed -nE 's/^[[:space:]]*([0-9]+):.*/\1/p' \
    | sort -n -u
}

openrgb_apply_device_v77() {
    local device="$1"
    local color="${2^^}"
    local brightness="${3:-25}"
    local purpose="${4:-static}"
    local log="${DIAGNOSE_ROOT}/openrgb-device-${device}-last.log"

    : > "$log"

    # V77: OpenRGB-Modi sind gerätespezifisch.
    # Für "AUS" zuerst echten Off-Modus versuchen.
    if [[ "$purpose" == "off" ]]; then
        if openrgb \
            --client "${OPENRGB_SDK_HOST}:${OPENRGB_SDK_PORT}" \
            --device "$device" \
            --mode Off \
            >>"$log" 2>&1
        then
            echo "  Gerät $device: Off"
            return 0
        fi
    fi

    # Direct ist besonders bei RGB-RAM oft verfügbar, auch wenn Static fehlt.
    if openrgb \
        --client "${OPENRGB_SDK_HOST}:${OPENRGB_SDK_PORT}" \
        --device "$device" \
        --mode Direct \
        --color "$color" \
        --brightness "$brightness" \
        >>"$log" 2>&1
    then
        echo "  Gerät $device: Direct #$color"
        return 0
    fi

    # Manche Controller können dagegen nur Static.
    if openrgb \
        --client "${OPENRGB_SDK_HOST}:${OPENRGB_SDK_PORT}" \
        --device "$device" \
        --mode Static \
        --color "$color" \
        --brightness "$brightness" \
        >>"$log" 2>&1
    then
        echo "  Gerät $device: Static #$color"
        return 0
    fi

    # Letzter Fallback: Farbe im aktuellen Modus setzen.
    if openrgb \
        --client "${OPENRGB_SDK_HOST}:${OPENRGB_SDK_PORT}" \
        --device "$device" \
        --color "$color" \
        --brightness "$brightness" \
        >>"$log" 2>&1
    then
        echo "  Gerät $device: Farbe #$color im vorhandenen Modus"
        return 0
    fi

    if openrgb \
        --client "${OPENRGB_SDK_HOST}:${OPENRGB_SDK_PORT}" \
        --device "$device" \
        --color "$color" \
        >>"$log" 2>&1
    then
        echo "  Gerät $device: Farbe #$color"
        return 0
    fi

    echo "  Gerät $device: FEHLER"
    echo "    Diagnose: $log"
    return 1
}

set_color_client() {
    local color="${1^^}"
    local brightness="${2:-25}"
    local purpose="${3:-static}"
    local device=""
    local found=0
    local failed=0

    need_openrgb || return 1
    ensure_server

    validate_hex "$color" || {
        msg "OPENRGB" "Ungültige Farbe: $color"
        return 1
    }

    validate_int_range "$brightness" 0 100 || {
        msg "OPENRGB" "Ungültige Helligkeit: $brightness"
        return 1
    }

    echo
    echo "OpenRGB: Geräte werden einzeln gesetzt ..."

    while IFS= read -r device; do
        [[ "$device" =~ ^[0-9]+$ ]] || continue
        found=1

        openrgb_apply_device_v77 \
            "$device" \
            "$color" \
            "$brightness" \
            "$purpose" \
        || failed=$((failed + 1))
    done < <(openrgb_device_indices_v77)

    if (( found == 0 )); then
        msg \
            "OPENRGB" \
            "OpenRGB meldet aktuell keine RGB-Geräte.

Bitte über Punkt 2 die Geräteerkennung prüfen."
        return 1
    fi

    if (( failed > 0 )); then
        echo
        echo "WARNUNG: $failed Gerät(e) konnten nicht gesetzt werden."
        echo "Diagnosen:"
        echo "  ${DIAGNOSE_ROOT}/openrgb-device-*-last.log"
        return 1
    fi

    return 0
}

rgb_off() {
    systemctl disable --now "$OPENRGB_STATUS_SERVICE" 2>/dev/null || true

    set_color_client \
        "000000" \
        "0" \
        "off"

    source_main_config

    cat > "$OPENRGB_CONFIG" <<EOF
BOOT_MODE="off"
STATIC_COLOR="${STATIC_COLOR:-FFFFFF}"
STATIC_BRIGHTNESS="${STATIC_BRIGHTNESS:-25}"
EOF

    chmod 644 "$OPENRGB_CONFIG"

    write_openrgb_units

    systemctl enable "$OPENRGB_BOOT_SERVICE" >/dev/null 2>&1 || true

    msg \
        "OPENRGB" \
        "RGB wurde ausgeschaltet.

Startverhalten wurde auf 'Aus' gesetzt."
}

static_color_menu() {
    local color=""
    local brightness=""

    color="$(
        ask \
            "OPENRGB · FARBE" \
            "RGB-Farbe als 6-stelligen HEX-Wert ohne # eingeben." \
            "FFFFFF"
    )" || return 0

    color="${color^^}"

    validate_hex "$color" || {
        msg "OPENRGB" "Ungültiger HEX-Wert."
        return 0
    }

    brightness="$(
        ask \
            "OPENRGB · HELLIGKEIT" \
            "Helligkeit in Prozent (1-100)." \
            "25"
    )" || return 0

    validate_int_range "$brightness" 1 100 || {
        msg "OPENRGB" "Ungültige Helligkeit."
        return 0
    }

    systemctl disable --now "$OPENRGB_STATUS_SERVICE" 2>/dev/null || true

    set_color_client \
        "$color" \
        "$brightness"

    cat > "$OPENRGB_CONFIG" <<EOF
BOOT_MODE="static"
STATIC_COLOR="$color"
STATIC_BRIGHTNESS="$brightness"
EOF

    chmod 644 "$OPENRGB_CONFIG"

    # Boot-Service verwendet denselben geräteweisen V77-Fallback.
    write_openrgb_units
    systemctl daemon-reload
    systemctl enable "$OPENRGB_BOOT_SERVICE" >/dev/null

    msg \
        "OPENRGB" \
        "Statische Farbe gesetzt:

#$color
Helligkeit: ${brightness} %

Die Einstellung wird beim Start erneut angewendet."
}

configure_status() {
    default_status_config
    source_status_config

    local interval=""
    local brightness=""
    local cpu_green=""
    local cpu_yellow=""
    local temp_warn=""
    local temp_crit=""
    local disk_warn=""
    local disk_crit=""

    interval="$(
        ask \
            "OPENRGB STATUS" \
            "Prüfintervall in Sekunden (2-60)." \
            "$INTERVAL"
    )" || return 0

    brightness="$(
        ask \
            "OPENRGB STATUS" \
            "Status-Helligkeit in Prozent (1-100)." \
            "$BRIGHTNESS"
    )" || return 0

    cpu_green="$(
        ask \
            "OPENRGB STATUS" \
            "CPU bis wieviel % = GRÜN?" \
            "$CPU_GREEN_MAX"
    )" || return 0

    cpu_yellow="$(
        ask \
            "OPENRGB STATUS" \
            "CPU bis wieviel % = GELB? Darüber = ORANGE." \
            "$CPU_YELLOW_MAX"
    )" || return 0

    temp_warn="$(
        ask \
            "OPENRGB STATUS" \
            "Temperatur-Warnschwelle in °C." \
            "$TEMP_WARN"
    )" || return 0

    temp_crit="$(
        ask \
            "OPENRGB STATUS" \
            "Temperatur-Kritisch in °C." \
            "$TEMP_CRIT"
    )" || return 0

    disk_warn="$(
        ask \
            "OPENRGB STATUS" \
            "Root-Disk Warnung ab %." \
            "$DISK_WARN"
    )" || return 0

    disk_crit="$(
        ask \
            "OPENRGB STATUS" \
            "Root-Disk Kritisch ab %." \
            "$DISK_CRIT"
    )" || return 0

    validate_int_range "$interval" 2 60 || {
        msg "OPENRGB STATUS" "Intervall ungültig."
        return 0
    }

    validate_int_range "$brightness" 1 100 || {
        msg "OPENRGB STATUS" "Helligkeit ungültig."
        return 0
    }

    validate_int_range "$cpu_green" 1 90 || {
        msg "OPENRGB STATUS" "CPU Grün-Wert ungültig."
        return 0
    }

    validate_int_range "$cpu_yellow" 2 99 || {
        msg "OPENRGB STATUS" "CPU Gelb-Wert ungültig."
        return 0
    }

    (( cpu_yellow > cpu_green )) || {
        msg "OPENRGB STATUS" "CPU Gelb muss größer als CPU Grün sein."
        return 0
    }

    validate_int_range "$temp_warn" 40 105 || {
        msg "OPENRGB STATUS" "Temperatur-Warnwert ungültig."
        return 0
    }

    validate_int_range "$temp_crit" 41 120 || {
        msg "OPENRGB STATUS" "Temperatur-Kritisch ungültig."
        return 0
    }

    (( temp_crit > temp_warn )) || {
        msg "OPENRGB STATUS" "Temperatur Kritisch muss größer als Warnung sein."
        return 0
    }

    validate_int_range "$disk_warn" 50 98 || {
        msg "OPENRGB STATUS" "Disk-Warnwert ungültig."
        return 0
    }

    validate_int_range "$disk_crit" 51 100 || {
        msg "OPENRGB STATUS" "Disk-Kritisch ungültig."
        return 0
    }

    (( disk_crit > disk_warn )) || {
        msg "OPENRGB STATUS" "Disk Kritisch muss größer als Warnung sein."
        return 0
    }

    cat > "$OPENRGB_STATUS_CONFIG" <<EOF
INTERVAL="$interval"
BRIGHTNESS="$brightness"

CPU_GREEN_MAX="$cpu_green"
CPU_YELLOW_MAX="$cpu_yellow"

TEMP_WARN="$temp_warn"
TEMP_CRIT="$temp_crit"

DISK_WARN="$disk_warn"
DISK_CRIT="$disk_crit"

CHECK_FAILED_UNITS="1"
CHECK_PVE_STORAGE="1"
CHECK_CLUSTER_QUORUM="1"

COLOR_LOW="00FF00"
COLOR_MEDIUM="FFFF00"
COLOR_HIGH="FF8000"
COLOR_WARNING="FF5500"
COLOR_CRITICAL="FF0000"
EOF

    chmod 644 "$OPENRGB_STATUS_CONFIG"

    msg \
        "OPENRGB STATUS" \
        "Statuswerte gespeichert.

GRÜN  = geringe CPU-Last
GELB  = mittlere CPU-Last
ORANGE= hohe CPU-Last / Warnung
ROT   = kritischer Fehler"
}

enable_status() {
    need_openrgb || return 1

    default_status_config
    write_status_script
    write_openrgb_units
    ensure_server

    systemctl disable --now "$OPENRGB_BOOT_SERVICE" 2>/dev/null || true

    systemctl enable --now "$OPENRGB_STATUS_SERVICE"

    source_main_config

    cat > "$OPENRGB_CONFIG" <<EOF
BOOT_MODE="status"
STATIC_COLOR="${STATIC_COLOR:-FFFFFF}"
STATIC_BRIGHTNESS="${STATIC_BRIGHTNESS:-25}"
EOF

    chmod 644 "$OPENRGB_CONFIG"

    sleep 3

    msg \
        "OPENRGB STATUS" \
        "Fehler-/Auslastungsanzeige ist aktiv.

Priorität:
1. Kritischer Fehler = ROT
2. Warnung = ORANGE/ROT
3. sonst CPU-Auslastung:
   GRÜN / GELB / ORANGE

Der Dienst schreibt nur dann eine neue RGB-Farbe,
wenn sich Farbe oder Helligkeit tatsächlich ändern."
}

disable_status() {
    systemctl disable --now "$OPENRGB_STATUS_SERVICE" 2>/dev/null || true

    msg \
        "OPENRGB STATUS" \
        "Automatische Fehler-/Auslastungsanzeige wurde deaktiviert.

Die zuletzt gesetzte RGB-Farbe bleibt erhalten."
}

show_status() {
    clear 2>/dev/null || true

    echo "============================================================"
    echo " OPENRGB / PROXMOX STATUS"
    echo "============================================================"
    echo

    if [[ -x "$OPENRGB_BIN" ]]; then
        echo "OpenRGB:"
        "$OPENRGB_BIN" --version 2>/dev/null || true
    else
        echo "OpenRGB: nicht installiert"
    fi

    echo
    echo "SDK Server:"
    systemctl --no-pager --full status "$OPENRGB_SERVER_SERVICE" 2>/dev/null \
        | sed -n '1,12p' || true

    echo
    echo "Statusanzeige:"
    systemctl --no-pager --full status "$OPENRGB_STATUS_SERVICE" 2>/dev/null \
        | sed -n '1,12p' || true

    if [[ -f "$OPENRGB_STATE" ]]; then
        echo
        echo "Letzte Auswertung:"
        python3 -m json.tool "$OPENRGB_STATE" 2>/dev/null || cat "$OPENRGB_STATE"
    fi

    echo
    read -rp "ENTER zum Fortfahren ..."
}

boot_behavior() {
    need_openrgb || return 1
    source_main_config

    local selected=""

    selected="$(
        choose \
            "OPENRGB · STARTVERHALTEN" \
            "Was soll nach einem Host-Neustart passieren?" \
            "1" "RGB unverändert lassen" \
            "2" "RGB ausschalten" \
            "3" "Statische Farbe" \
            "4" "Fehler-/Auslastungsanzeige starten" \
            "0" "Abbrechen"
    )" || return 0

    case "$selected" in
        1)
            systemctl disable --now "$OPENRGB_BOOT_SERVICE" 2>/dev/null || true
            systemctl disable --now "$OPENRGB_STATUS_SERVICE" 2>/dev/null || true

            cat > "$OPENRGB_CONFIG" <<EOF
BOOT_MODE="unchanged"
STATIC_COLOR="${STATIC_COLOR:-FFFFFF}"
STATIC_BRIGHTNESS="${STATIC_BRIGHTNESS:-25}"
EOF
            ;;
        2)
            rgb_off
            ;;
        3)
            static_color_menu
            ;;
        4)
            enable_status
            ;;
        0)
            return 0
            ;;
    esac
}

uninstall_openrgb() {
    local confirm=""

    if have_tui; then
        if ! whiptail \
            --title "OPENRGB DEINSTALLIEREN" \
            --yesno "OpenRGB und die Proxmox-RGB-Steuerung wirklich vom Host entfernen?" \
            12 80
        then
            return 0
        fi
    else
        read -rp "OpenRGB wirklich deinstallieren? [j/N]: " confirm

        case "${confirm,,}" in
            j|ja|y|yes)
                ;;
            *)
                return 0
                ;;
        esac
    fi

    systemctl disable --now "$OPENRGB_STATUS_SERVICE" 2>/dev/null || true
    systemctl disable --now "$OPENRGB_BOOT_SERVICE" 2>/dev/null || true
    systemctl disable --now "$OPENRGB_SERVER_SERVICE" 2>/dev/null || true

    rm -f \
        "/etc/systemd/system/${OPENRGB_STATUS_SERVICE}" \
        "/etc/systemd/system/${OPENRGB_BOOT_SERVICE}" \
        "/etc/systemd/system/${OPENRGB_SERVER_SERVICE}" \
        "$OPENRGB_STATUS_SCRIPT" \
        "$OPENRGB_CONFIG" \
        "$OPENRGB_STATUS_CONFIG" \
        /etc/modules-load.d/openrgb-proxmox.conf

    systemctl daemon-reload

    # V110: Von NodeZero installierte AppImage-Variante entfernen. Den Wrapper
    # nur löschen, wenn er eindeutig von diesem Installer stammt.
    if [[ -f /usr/bin/openrgb ]] \
       && grep -Fq 'NODEZERO_OPENRGB_APPIMAGE_WRAPPER' /usr/bin/openrgb 2>/dev/null; then
        rm -f /usr/bin/openrgb
    fi
    rm -rf /opt/openrgb-nodezero

    if dpkg-query -W -f='${Status}' openrgb 2>/dev/null \
        | grep -q 'install ok installed'
    then
        apt-get purge -y openrgb || true
    fi

    msg \
        "OPENRGB" \
        "OpenRGB wurde vom Proxmox-Host entfernt."
}

apply_boot() {
    need_openrgb || exit 0
    source_main_config

    case "${BOOT_MODE:-unchanged}" in
        off)
            ensure_server
            set_color_client "000000" "0" "off"
            ;;
        static)
            ensure_server
            set_color_client \
                "${STATIC_COLOR:-FFFFFF}" \
                "${STATIC_BRIGHTNESS:-25}"
            ;;
        status)
            write_status_script
            write_openrgb_units
            systemctl enable --now "$OPENRGB_STATUS_SERVICE"
            ;;
        *)
            ;;
    esac
}

main_menu() {
    while true; do
        local version="nicht installiert"

        if [[ -x "$OPENRGB_BIN" ]]; then
            version="$(
                "$OPENRGB_BIN" --version 2>/dev/null \
                | head -n1 \
                || true
            )"

            version="${version:-installiert}"
        fi

        local selected=""

        selected="$(
            choose \
                "OPENRGB · PROXMOX RGB-STEUERUNG" \
                "OpenRGB: ${version}

Mainboard/RAM-Erkennung hängt von der OpenRGB-Geräteunterstützung ab." \
                "1" "Installieren / auf aktuellsten offiziellen Release aktualisieren" \
                "2" "Erkannte RGB-Geräte / Zonen / Modi anzeigen" \
                "3" "RGB komplett AUS · auch nach Neustart" \
                "4" "Statische Farbe + Helligkeit setzen" \
                "5" "Fehler-/Auslastungsanzeige konfigurieren" \
                "6" "Fehler-/Auslastungsanzeige AKTIVIEREN" \
                "7" "Fehler-/Auslastungsanzeige DEAKTIVIEREN" \
                "8" "OpenRGB / Statusdienst anzeigen" \
                "9" "Startverhalten festlegen" \
                "10" "OpenRGB deinstallieren" \
                "0" "Zurück zum Proxmox Master-Installer"
        )" || return 0

        case "$selected" in
            1) install_update_openrgb ;;
            2) show_devices ;;
            3) rgb_off ;;
            4) static_color_menu ;;
            5) configure_status ;;
            6) enable_status ;;
            7) disable_status ;;
            8) show_status ;;
            9) boot_behavior ;;
            10) uninstall_openrgb ;;
            0) return 0 ;;
        esac
    done
}

if [[ "${1:-}" == "--apply-boot" ]]; then
    apply_boot
    exit 0
fi

main_menu
__OPENRGB_MANAGER_V74__

    chmod 755 "$manager"
    chown root:root "$manager"

    ok "OpenRGB-Steuermenü bereit: $manager"
}

openrgb_menu_v74() {
    header "OPENRGB · MAINBOARD / RAM RGB"

    echo "OpenRGB wird direkt auf dem Proxmox-Host betrieben."
    echo
    echo "Damit kannst du unterstützte RGB-Hardware:"
    echo "  - erkennen"
    echo "  - ausschalten"
    echo "  - statisch einfärben"
    echo "  - beim Booten automatisch setzen"
    echo "  - als Proxmox Fehler-/Auslastungsanzeige verwenden"
    echo
    echo "Der OpenRGB-SDK-Server wird aus Sicherheitsgründen nur an"
    echo "127.0.0.1:6742 gebunden und nicht ins LAN freigegeben."
    echo

    install_openrgb_manager_v74

    /usr/local/sbin/proxmox-openrgb
}


resolve_guest_id() {
    if [[ "${1:-}" == "100" ]]; then
        die "VM-/CT-ID 100 ist reserviert und wird nicht vergeben. Bitte ID 101 oder höher verwenden."
    fi

    local requested="$1"
    local label="$2"
    local id="$requested"

    while true; do
        if free_id_check "$id"; then
            RESOLVED_ID="$id"
            return 0
        fi

        local kind name choice new_id
        kind="$(guest_kind "$id")"
        name="$(guest_name "$id")"

        echo
        echo "${YELLOW}ID-Konflikt:${RESET} $label möchte ID $id verwenden."
        echo "Belegt durch: $kind $id${name:+ ($name)}"
        echo
        echo "  1) Vorhandenes Objekt vollständig löschen und ID $id verwenden"
        echo "  2) Automatisch nächste freie ID verwenden"
        echo "  3) Andere ID eingeben"
        echo "  4) Installation abbrechen"
        echo

        read -rp "Auswahl [2]: " choice
        choice="${choice:-2}"

        case "$choice" in
            1)
                local confirm
                read -rp "Zur Bestätigung exakt die ID '$id' eingeben: " confirm
                if [[ "$confirm" == "$id" ]]; then
                    destroy_guest "$id"
                    RESOLVED_ID="$id"
                    return 0
                fi
                warn "Nicht gelöscht."
                ;;
            2)
                allocate_id
                RESOLVED_ID="$ALLOCATED_ID"
                ok "$label verwendet stattdessen freie ID $RESOLVED_ID."
                return 0
                ;;
            3)
                read -rp "Neue gewünschte ID: " new_id
                [[ "$new_id" =~ ^[0-9]+$ ]] || {
                    warn "Ungültige ID."
                    continue
                }
                id="$new_id"
                ;;
            4)
                die "Installation auf Wunsch abgebrochen."
                ;;
            *)
                warn "Ungültige Auswahl."
                ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Pi-hole Passwort-Reset Tool
# -----------------------------------------------------------------------------

install_pihole_password_reset_tool() {
    local tool="/usr/local/sbin/pihole-reset-password"

    cat > "$tool" <<'__PIHOLE_RESET_TOOL__'
#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || {
    echo "FEHLER: Bitte als root auf dem Proxmox-Host ausführen."
    exit 1
}

find_pihole_ct() {
    local id host

    while read -r id; do
        [[ "$id" =~ ^[0-9]+$ ]] || continue

        host="$(
            pct config "$id" 2>/dev/null |
            awk -F': ' '/^hostname:/ {print $2; exit}'
        )"

        if [[ "$host" == "pihole" ]]; then
            echo "$id"
            return 0
        fi
    done < <(pct list 2>/dev/null | awk 'NR>1 {print $1}')

    return 1
}

random_password() {
    python3 - <<'PY'
import secrets
alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#%_-"
print("".join(secrets.choice(alphabet) for _ in range(24)))
PY
}

new_pw_file() {
    local stamp file nr
    install -d -m 0700 -o root -g root /root/passwort
    stamp="$(date +%Y%m%d-%H%M%S)"
    file="/root/passwort/pihole-web-api-pw-${stamp}.txt"

    if [[ -e "$file" ]]; then
        nr=2
        while [[ -e "/root/passwort/pihole-web-api-pw-${stamp}-${nr}.txt" ]]; do
            nr=$((nr + 1))
        done
        file="/root/passwort/pihole-web-api-pw-${stamp}-${nr}.txt"
    fi

    printf '%s\n' "$file"
}

clear 2>/dev/null || true

echo "============================================================"
echo " PI-HOLE WEB/API-PASSWORT"
echo "============================================================"
echo

CTID="$(find_pihole_ct || true)"

if [[ -z "$CTID" ]]; then
    echo "FEHLER: Kein LXC mit hostname 'pihole' gefunden."
    pct list || true
    exit 1
fi

if ! pct status "$CTID" | grep -q "status: running"; then
    echo "Starte CT $CTID ..."
    pct start "$CTID"
    sleep 5
fi

COMPOSE="/opt/pihole/docker-compose.yml"

pct exec "$CTID" -- test -f "$COMPOSE" || {
    echo "FEHLER: $COMPOSE wurde nicht gefunden."
    exit 1
}

echo "Pi-hole:"
echo "  CT-ID: $CTID"
echo
echo "Neues Passwort eingeben."
echo "ENTER = automatisch starkes Passwort erzeugen."
echo

read -rsp "Neues Pi-hole Web/API-Passwort: " NEW_PASS
echo

if [[ -z "$NEW_PASS" ]]; then
    NEW_PASS="$(random_password)"
    echo "Zufälliges Passwort wurde erzeugt."
else
    read -rsp "Passwort wiederholen: " NEW_PASS_2
    echo

    [[ "$NEW_PASS" == "$NEW_PASS_2" ]] || {
        echo "FEHLER: Passwörter stimmen nicht überein."
        exit 1
    }

    unset NEW_PASS_2
fi

[[ ${#NEW_PASS} -ge 6 ]] || {
    echo "FEHLER: Passwort muss mindestens 6 Zeichen lang sein."
    exit 1
}

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="/root/backups/pihole-compose-ct${CTID}-pw-v84-${STAMP}.yml"
mkdir -p /root/backups

pct exec "$CTID" -- cat "$COMPOSE" > "$BACKUP"
chmod 600 "$BACKUP"

echo
echo "Aktualisiere Docker-Compose ..."

pct exec "$CTID" -- env PIHOLE_NEW_PASSWORD="$NEW_PASS" python3 - <<'PY'
from pathlib import Path
import os

password = os.environ["PIHOLE_NEW_PASSWORD"]
path = Path("/opt/pihole/docker-compose.yml")

lines = path.read_text(encoding="utf-8").splitlines()
out = []
found = False

safe = password.replace("\\", "\\\\").replace('"', '\\"')

for line in lines:
    stripped = line.strip()
    indent = line[:len(line) - len(line.lstrip())]

    if stripped.startswith("FTLCONF_webserver_api_password:"):
        out.append(
            f'{indent}FTLCONF_webserver_api_password: "{safe}"'
        )
        found = True
    elif stripped.startswith("PIHOLE_PASSWORD:"):
        # V113: Exporter verwendet dasselbe Pi-hole Web/API-Passwort.
        out.append(
            f'{indent}PIHOLE_PASSWORD: "{safe}"'
        )
    else:
        out.append(line)

if not found:
    raise SystemExit(
        "FEHLER: FTLCONF_webserver_api_password fehlt in docker-compose.yml."
    )

path.write_text(
    "\n".join(out) + "\n",
    encoding="utf-8",
)
PY

echo
echo "Prüfe Compose-Datei ..."
pct exec "$CTID" -- bash -lc \
    'cd /opt/pihole && docker compose config >/dev/null'

echo "Erstelle Pi-hole Container neu ..."
pct exec "$CTID" -- bash -lc '
    set -Eeuo pipefail
    cd /opt/pihole
    if docker compose config --services | grep -qx pihole-exporter; then
        docker compose up -d --force-recreate pihole pihole-exporter
    else
        docker compose up -d --force-recreate pihole
    fi
'

echo "Warte auf Pi-hole API ..."

PIHOLE_IP="$(
    pct config "$CTID" 2>/dev/null |
    awk -F'ip=' '/^net0:/ {
        split($2,a,",");
        split(a[1],b,"/");
        print b[1];
        exit
    }'
)"

[[ -n "$PIHOLE_IP" ]] || {
    echo "FEHLER: Pi-hole IP konnte nicht ermittelt werden."
    exit 1
}

for i in $(seq 1 30); do
    if curl -fsS \
        --max-time 2 \
        "http://${PIHOLE_IP}/api/info/version" \
        >/dev/null 2>&1; then
        break
    fi

    if (( i == 30 )); then
        echo "FEHLER: Pi-hole API wurde nicht erreichbar."
        pct exec "$CTID" -- docker logs pihole --tail 100 || true
        exit 1
    fi

    sleep 2
done

echo "Verifiziere das neue Passwort ..."

VERIFY="$(
    PIHOLE_URL="http://${PIHOLE_IP}" \
    PIHOLE_PASSWORD="$NEW_PASS" \
    python3 <<'PY'
import json
import os
import urllib.error
import urllib.request

url = os.environ["PIHOLE_URL"].rstrip("/") + "/api/auth"
password = os.environ["PIHOLE_PASSWORD"]

req = urllib.request.Request(
    url,
    data=json.dumps(
        {"password": password}
    ).encode("utf-8"),
    headers={
        "Content-Type": "application/json",
        "Accept": "application/json",
        "User-Agent": "Proxmox-Pi-hole-V84/1.0",
    },
    method="POST",
)

try:
    with urllib.request.urlopen(req, timeout=10) as response:
        data = json.loads(
            response.read().decode("utf-8") or "{}"
        )
except urllib.error.HTTPError as exc:
    body = exc.read().decode("utf-8", errors="replace")
    raise SystemExit(
        f"HTTP {exc.code}: {body}"
    )

session = data.get("session") or {}

if not session.get("valid") or not session.get("sid"):
    raise SystemExit(
        "Pi-hole meldet keine gültige SID: "
        + json.dumps(data, ensure_ascii=False)
    )

print("OK")
PY
)" || {
    echo
    echo "FEHLER: Neues Passwort wird von Pi-hole nicht akzeptiert."
    echo "Compose-Backup:"
    echo "  $BACKUP"
    exit 1
}

[[ "$VERIFY" == "OK" ]] || {
    echo "FEHLER: Unerwartete Passwortprüfung: $VERIFY"
    exit 1
}

if pct exec "$CTID" -- bash -lc 'cd /opt/pihole && docker compose config --services | grep -qx pihole-exporter' 2>/dev/null; then
    echo "Prüfe Pi-hole Exporter nach Passwortänderung ..."
    for i in $(seq 1 30); do
        if curl -fsS --max-time 3 "http://${PIHOLE_IP}:9617/metrics" 2>/dev/null | grep -q '^pihole_'; then
            break
        fi
        if (( i == 30 )); then
            echo "FEHLER: Pi-hole Exporter akzeptiert das neue Passwort nicht."
            pct exec "$CTID" -- docker logs --tail 100 pihole-exporter || true
            exit 1
        fi
        sleep 2
    done
fi

PASSWORD_FILE="$(new_pw_file)"
umask 077

{
    echo "============================================================"
    echo " PI-HOLE WEB/API-PASSWORT"
    echo "============================================================"
    echo
    echo "Erstellt: $(date '+%d.%m.%Y %H:%M:%S')"
    echo "CT-ID:    $CTID"
    echo "Web:      http://${PIHOLE_IP}/admin"
    echo
    echo "Web/API-Passwort:"
    echo "$NEW_PASS"
    echo
    echo "Home Assistant:"
    echo "  separates App-Passwort verwenden"
    echo "  erzeugen/ersetzen mit: pihole-ha-app-password"
} > "$PASSWORD_FILE"

chmod 600 "$PASSWORD_FILE"

echo
echo "============================================================"
echo " PASSWORT AKTIV UND VERIFIZIERT"
echo "============================================================"
echo "Web:"
echo "  http://${PIHOLE_IP}/admin"
echo
echo "Web/API-Passwort:"
echo "  $NEW_PASS"
echo
echo "Gespeichert:"
echo "  $PASSWORD_FILE"
echo
echo "Compose-Backup:"
echo "  $BACKUP"
echo
echo "Home-Assistant App-Passwort:"
echo "  pihole-ha-app-password"
__PIHOLE_RESET_TOOL__

    chmod 700 "$tool"
    chown root:root "$tool"
}


# Reset-Tool bei jedem Start des Master-Installers aktualisieren.
install_pihole_password_reset_tool

# -----------------------------------------------------------------------------
# V83 · Pi-hole Home-Assistant App-Passwort + Auth-Manager
# -----------------------------------------------------------------------------

install_pihole_auth_tools_v83() {
    local app_tool="/usr/local/sbin/pihole-ha-app-password"
    local manager="/usr/local/sbin/pihole-auth-manager"

    cat > "$app_tool" <<'__PIHOLE_HA_APP_TOOL_V83__'
#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || {
    echo "FEHLER: Bitte als root auf dem Proxmox-Host ausführen."
    exit 1
}

find_ct() {
    local id host
    while read -r id; do
        [[ "$id" =~ ^[0-9]+$ ]] || continue
        host="$(pct config "$id" 2>/dev/null | awk -F': ' '/^hostname:/ {print $2; exit}')"
        if [[ "$host" == "pihole" ]]; then
            echo "$id"
            return 0
        fi
    done < <(pct list 2>/dev/null | awk 'NR>1 {print $1}')
    return 1
}

CTID="$(find_ct || true)"
[[ -n "$CTID" ]] || {
    echo "FEHLER: Pi-hole LXC nicht gefunden."
    exit 1
}

if ! pct status "$CTID" | grep -q "status: running"; then
    pct start "$CTID"
    sleep 5
fi

PIHOLE_IP="$(
    pct config "$CTID" |
    awk -F'ip=' '/^net0:/ {
        split($2,a,",");
        split(a[1],b,"/");
        print b[1];
        exit
    }'
)"

[[ -n "$PIHOLE_IP" ]] || {
    echo "FEHLER: Pi-hole IP konnte nicht ermittelt werden."
    exit 1
}

ADMIN_PASS="$(
    pct exec "$CTID" -- python3 - <<'PY'
from pathlib import Path
import re

path = Path("/opt/pihole/docker-compose.yml")
if not path.exists():
    raise SystemExit(1)

text = path.read_text(encoding="utf-8")
m = re.search(
    r'FTLCONF_webserver_api_password:\s*["\']?([^"\'\n]*)',
    text,
)
if not m or not m.group(1):
    raise SystemExit(2)

print(m.group(1).strip())
PY
)" || true

if [[ -z "$ADMIN_PASS" ]]; then
    echo "FEHLER: Kein aktives Web/API-Passwort in docker-compose.yml gefunden."
    echo "Zuerst ausführen: pihole-reset-password"
    exit 1
fi

echo "Erzeuge neues Home-Assistant App-Passwort ..."

APP_PASS="$(
    PIHOLE_URL="http://${PIHOLE_IP}" \
    PIHOLE_ADMIN_PASS="$ADMIN_PASS" \
    python3 <<'PY'
import json
import os
import urllib.error
import urllib.request

base = os.environ["PIHOLE_URL"].rstrip("/")
admin = os.environ["PIHOLE_ADMIN_PASS"]

def req(method, path, payload=None, sid=None):
    data = None
    headers = {
        "Accept": "application/json",
        "User-Agent": "Proxmox-Pi-hole-Auth-V84/1.0",
    }
    if payload is not None:
        data = json.dumps(payload).encode()
        headers["Content-Type"] = "application/json"
    if sid:
        headers["X-FTL-SID"] = sid

    request = urllib.request.Request(
        base + path,
        data=data,
        headers=headers,
        method=method,
    )

    try:
        with urllib.request.urlopen(request, timeout=12) as response:
            return json.loads(response.read().decode() or "{}")
    except urllib.error.HTTPError as exc:
        body = exc.read().decode(errors="replace")
        raise RuntimeError(f"HTTP {exc.code}: {body[:500]}") from exc

auth = req("POST", "/api/auth", {"password": admin})
session = auth.get("session") or {}
sid = session.get("sid")
if not session.get("valid") or not sid:
    raise RuntimeError("Web/API-Passwort liefert keine echte Pi-hole SID.")

generated = req("GET", "/api/auth/app", sid=sid).get("app") or {}
password = generated.get("password")
app_hash = generated.get("hash")

if not password or not app_hash:
    raise RuntimeError("Pi-hole lieferte kein App-Passwort/Hash.")

req(
    "PATCH",
    "/api/config",
    {"config": {"webserver": {"api": {
        "app_pwhash": app_hash,
        "app_sudo": False,
    }}}},
    sid=sid,
)

# Pi-hole schützt den Login vor zu schnellen Folgelogins.
# Daher kurz warten und bei Bedarf kontrolliert erneut versuchen.
import time

last_error = None

for _ in range(4):
    time.sleep(2)

    try:
        verify = req(
            "POST",
            "/api/auth",
            {"password": password},
        )

        vs = verify.get("session") or {}

        if vs.get("valid") and vs.get("sid"):
            print(password)
            break

        last_error = RuntimeError(
            "App-Passwort liefert keine gültige SID."
        )

    except Exception as exc:
        last_error = exc
else:
    raise RuntimeError(
        f"App-Passwort-Verifikation fehlgeschlagen: {last_error}"
    )
PY
)"

STAMP="$(date +%Y%m%d-%H%M%S)"
install -d -m 0700 -o root -g root /root/passwort
FILE="/root/passwort/pihole-home-assistant-app-pw-${STAMP}.txt"
N=2
while [[ -e "$FILE" ]]; do
    FILE="/root/passwort/pihole-home-assistant-app-pw-${STAMP}-${N}.txt"
    N=$((N + 1))
done

umask 077
cat > "$FILE" <<EOF
============================================================
 PI-HOLE · HOME ASSISTANT
============================================================
Erstellt: $(date '+%d.%m.%Y %H:%M:%S')
CT-ID: $CTID
Pi-hole: http://${PIHOLE_IP}/admin

Home Assistant Pi-hole Integration:
Host: ${PIHOLE_IP}
Port: 80
Location: /admin
App-Passwort/API-Schlüssel: ${APP_PASS}
SSL verwenden: AUS
SSL prüfen: AUS
EOF
chmod 600 "$FILE"

echo
echo "============================================================"
echo " HOME-ASSISTANT APP-PASSWORT ERZEUGT"
echo "============================================================"
echo "Host:       $PIHOLE_IP"
echo "Port:       80"
echo "Location:   /admin"
echo "SSL:        AUS"
echo
echo "App-Passwort:"
echo "  $APP_PASS"
echo
echo "Gespeichert:"
echo "  $FILE"
__PIHOLE_HA_APP_TOOL_V83__

    chmod 700 "$app_tool"
    chown root:root "$app_tool"

    cat > "$manager" <<'__PIHOLE_AUTH_MANAGER_V83__'
#!/usr/bin/env bash
set -Eeuo pipefail

while true; do
    clear 2>/dev/null || true
    echo "============================================================"
    echo " PI-HOLE AUTHENTIFIZIERUNG"
    echo "============================================================"
    echo
    echo "1) Web/API-Passwort setzen oder ändern"
    echo "2) Home-Assistant App-Passwort erzeugen / ersetzen"
    echo "3) Home-Assistant Verbindungsdaten anzeigen"
    echo "0) Beenden"
    echo
    read -rp "Auswahl: " CHOICE

    case "$CHOICE" in
        1)
            /usr/local/sbin/pihole-reset-password
            exit $?
            ;;
        2)
            /usr/local/sbin/pihole-ha-app-password
            exit $?
            ;;
        3)
            CTID="$(
                pct list 2>/dev/null |
                awk 'NR>1 {print $1}' |
                while read -r id; do
                    host="$(pct config "$id" 2>/dev/null | awk -F": " '/^hostname:/ {print $2; exit}')"
                    [[ "$host" == "pihole" ]] && { echo "$id"; break; }
                done
            )"

            if [[ -z "$CTID" ]]; then
                echo "Pi-hole nicht gefunden."
            else
                IP="$(
                    pct config "$CTID" |
                    awk -F'ip=' '/^net0:/ {
                        split($2,a,","); split(a[1],b,"/"); print b[1]; exit
                    }'
                )"
                echo
                echo "Home Assistant:"
                echo "  Host:       $IP"
                echo "  Port:       80"
                echo "  Location:   /admin"
                echo "  SSL:        AUS"
                echo "  App-Passwort neu erzeugen: pihole-ha-app-password"
            fi
            echo
            read -rp "ENTER zum Fortfahren ..." _
            ;;
        0|"")
            exit 0
            ;;
        *)
            echo "Ungültige Auswahl."
            sleep 1
            ;;
    esac
done
__PIHOLE_AUTH_MANAGER_V83__

    chmod 700 "$manager"
    chown root:root "$manager"
}

install_pihole_auth_tools_v83

# -----------------------------------------------------------------------------
# Pi-hole Sprachumschaltung DE / EN
# -----------------------------------------------------------------------------

install_pihole_language_tool() {
    local tool="/usr/local/sbin/pihole-language"

    cat > "$tool" <<'__PIHOLE_LANGUAGE_TOOL__'
#!/usr/bin/env bash
set -Eeuo pipefail

TRANSLATE_URL="https://raw.githubusercontent.com/pimanDE/translate2german/master/translate2german.sh"
CACHE_DIR="/root/downloads/pihole-language"
SOURCE_FILE="${CACHE_DIR}/translate2german.sh"
CONVERTED_FILE="${CACHE_DIR}/translate2german.docker.sh"

STAMP="$(date +%d-%m-%H-%M)"
LOGFILE="/root/pihole-sprache-${STAMP}.txt"

if [[ -e "$LOGFILE" ]]; then
    N=2
    while [[ -e "/root/pihole-sprache-${STAMP}-${N}.txt" ]]; do
        N=$((N + 1))
    done
    LOGFILE="/root/pihole-sprache-${STAMP}-${N}.txt"
fi

exec > >(tee -a "$LOGFILE") 2>&1

[[ ${EUID:-$(id -u)} -eq 0 ]] || {
    echo "FEHLER: Bitte als root auf dem Proxmox-Host ausführen."
    exit 1
}

find_pihole_ct() {
    local id host
    while read -r id; do
        [[ "$id" =~ ^[0-9]+$ ]] || continue
        host="$(
            pct config "$id" 2>/dev/null |
            awk -F': ' '/^hostname:/ {print $2; exit}'
        )"
        if [[ "$host" == "pihole" ]]; then
            echo "$id"
            return 0
        fi
    done < <(pct list 2>/dev/null | awk 'NR>1 {print $1}')
    return 1
}

get_ct_ip() {
    local ctid="$1"
    pct config "$ctid" 2>/dev/null |
    awk -F'ip=' '/^net0:/ {
        split($2,a,",");
        split(a[1],b,"/");
        print b[1];
        exit
    }'
}

ensure_running() {
    local ctid="$1"

    if ! pct status "$ctid" 2>/dev/null | grep -q 'status: running'; then
        echo "Starte Pi-hole-LXC CT $ctid ..."
        pct start "$ctid"
        sleep 5
    fi

    if ! pct exec "$ctid" -- docker inspect pihole >/dev/null 2>&1; then
        echo "FEHLER: Docker-Container 'pihole' wurde nicht gefunden."
        exit 1
    fi

    if [[ "$(
        pct exec "$ctid" -- docker inspect -f '{{.State.Running}}' pihole 2>/dev/null
    )" != "true" ]]; then
        echo "Starte Docker-Container pihole ..."
        pct exec "$ctid" -- docker start pihole >/dev/null
        sleep 4
    fi
}

wait_for_pihole() {
    local ctid="$1"
    local tries="${2:-60}"

    for _ in $(seq 1 "$tries"); do
        if pct exec "$ctid" -- \
            docker exec pihole sh -c \
            'wget -q -T 3 -O /dev/null http://127.0.0.1/admin/ 2>/dev/null || curl -fsS --max-time 3 http://127.0.0.1/admin/ >/dev/null 2>&1' \
            >/dev/null 2>&1; then
            return 0
        fi
        sleep 2
    done

    return 1
}

clean_english_container() {
    local ctid="$1"

    echo
    echo "Erstelle Pi-hole aus dem bereits vorhandenen Docker-Image sauber neu ..."
    echo "Die persistente Pi-hole-Konfiguration unter /etc/pihole bleibt erhalten."

    pct exec "$ctid" -- bash -lc '
        set -Eeuo pipefail
        cd /opt/pihole
        docker compose up -d --force-recreate --no-deps pihole
    '

    if wait_for_pihole "$ctid" 60; then
        echo "[OK] Pi-hole ist wieder erreichbar."
    else
        echo "WARNUNG: Pi-hole Weboberfläche antwortet noch nicht."
    fi
}

update_source() {
    mkdir -p "$CACHE_DIR"
    chmod 755 "$CACHE_DIR"

    local tmp="${SOURCE_FILE}.part"

    echo "Lade aktuelle translate2german-Quelle ..."
    echo "  $TRANSLATE_URL"

    if curl -fL --retry 3 --connect-timeout 10 \
        "$TRANSLATE_URL" \
        -o "$tmp"; then
        mv -f "$tmp" "$SOURCE_FILE"
        chmod 644 "$SOURCE_FILE"
        echo "[OK] Quelle gespeichert:"
        echo "  $SOURCE_FILE"
    else
        rm -f "$tmp"
        if [[ -s "$SOURCE_FILE" ]]; then
            echo "WARNUNG: Download fehlgeschlagen."
            echo "Verwende vorhandenen Cache:"
            echo "  $SOURCE_FILE"
        else
            echo "FEHLER: Keine Übersetzungsquelle verfügbar."
            exit 1
        fi
    fi
}

ensure_source() {
    mkdir -p "$CACHE_DIR"
    chmod 755 "$CACHE_DIR"

    if [[ -s "$SOURCE_FILE" ]]; then
        local tmp="${SOURCE_FILE}.part"

        echo "Prüfe translate2german auf Aktualität ..."
        rm -f "$tmp"

        if curl -fL --retry 3 --connect-timeout 10 \
            -R -z "$SOURCE_FILE" \
            "$TRANSLATE_URL" \
            -o "$tmp"; then
            if [[ -s "$tmp" ]]; then
                mv -f "$tmp" "$SOURCE_FILE"
                chmod 644 "$SOURCE_FILE"
                echo "[OK] Übersetzungsquelle aktualisiert."
            else
                rm -f "$tmp"
                echo "[OK] Übersetzungsquelle bereits aktuell."
            fi
        else
            rm -f "$tmp"
            echo "WARNUNG: Online-Prüfung fehlgeschlagen – vorhandener Cache wird benutzt."
        fi
    else
        update_source
    fi
}

convert_for_docker() {
    python3 - "$SOURCE_FILE" "$CONVERTED_FILE" <<'PY'
import re
import shlex
import sys

src_path = sys.argv[1]
dst_path = sys.argv[2]

dep_block_start = re.compile(r"^\s*if\s+dpkg-query\s+-s\s+rpl\b")
sudo_prefix = re.compile(r"^(\s*)sudo\s+")
rpl_active = re.compile(r"^\s*rpl\s+--encoding\s+UTF-8\b")

in_dep_block = False
dep_if_depth = 0
converted_count = 0
unconverted_lines = []

def sed_escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace("&", r"\&").replace("|", r"\|")

def shell_single_quote(value: str) -> str:
    return "'" + value.replace("'", "'\"'\"'") + "'"

with open(src_path, "r", encoding="utf-8") as fin, \
     open(dst_path, "w", encoding="utf-8") as fout:

    for lineno, raw_line in enumerate(fin, start=1):
        line = raw_line.rstrip("\n")

        if dep_block_start.match(line):
            in_dep_block = True
            dep_if_depth = 1
            continue

        if in_dep_block:
            stripped = line.strip()
            if stripped.startswith("if "):
                dep_if_depth += 1
            if stripped == "fi":
                dep_if_depth -= 1
                if dep_if_depth == 0:
                    in_dep_block = False
            continue

        no_sudo = sudo_prefix.sub(r"\1", line, count=1)
        stripped = no_sudo.strip()

        if stripped == "clear":
            fout.write(": # clear im Docker-Lauf übersprungen\n")
            continue

        if stripped.startswith("#") or stripped == "":
            fout.write(no_sudo + "\n")
            continue

        try:
            parts = shlex.split(no_sudo, posix=True)
        except ValueError:
            fout.write(no_sudo + "\n")
            continue

        if (
            len(parts) >= 6
            and parts[0] == "rpl"
            and parts[1] == "--encoding"
            and parts[2] == "UTF-8"
        ):
            src = parts[3]
            dst = parts[4]
            file_path = " ".join(parts[5:])
            sed_expr = "s|{}|{}|g".format(
                sed_escape(src),
                sed_escape(dst),
            )
            fout.write(
                "sed -i {} {}\n".format(
                    shell_single_quote(sed_expr),
                    shell_single_quote(file_path),
                )
            )
            converted_count += 1
            continue

        fout.write(no_sudo + "\n")

with open(dst_path, "r", encoding="utf-8") as chk:
    for lineno, raw_line in enumerate(chk, start=1):
        if raw_line.lstrip().startswith("#"):
            continue
        if rpl_active.search(raw_line):
            unconverted_lines.append(lineno)

if unconverted_lines:
    print(
        "FEHLER: Unkonvertierte rpl-Zeilen: {}".format(
            ",".join(map(str, unconverted_lines))
        ),
        file=sys.stderr,
    )
    raise SystemExit(2)

if converted_count == 0:
    print(
        "FEHLER: Keine rpl-Befehle gefunden. Upstream-Format evtl. geändert.",
        file=sys.stderr,
    )
    raise SystemExit(3)

print(f"Konvertierte Übersetzungsbefehle: {converted_count}")
PY

    chmod 700 "$CONVERTED_FILE"
}

show_versions() {
    local ctid="$1"
    echo
    echo "Installierte Pi-hole-Versionen:"
    pct exec "$ctid" -- docker exec pihole pihole -v 2>/dev/null || true
    echo
    echo "Hinweis:"
    echo "  translate2german ist eine Community-Übersetzung."
    echo "  Der aktuelle Repository-Stand nennt Pi-hole Web v6.6 als Zielversion."
}

apply_de() {
    local ctid="$1"

    show_versions "$ctid"
    ensure_source
    convert_for_docker

    clean_english_container "$ctid"

    echo
    echo "Übertrage Docker-kompatible Übersetzung in den LXC ..."
    pct exec "$ctid" -- mkdir -p /opt/pihole/language-cache
    pct push \
        "$ctid" \
        "$CONVERTED_FILE" \
        /opt/pihole/language-cache/translate2german.docker.sh

    echo "Wende deutsche Übersetzung an ..."

    pct exec "$ctid" -- bash -lc '
        set -Eeuo pipefail
        docker exec -i pihole sh -s \
            < /opt/pihole/language-cache/translate2german.docker.sh
    '

    echo
    echo "Prüfe Übersetzung ..."

    if pct exec "$ctid" -- docker exec pihole \
        grep -Fq 'Ups! Zugriff verweigert.' \
        /var/www/html/admin/error403.lp 2>/dev/null; then

        pct exec "$ctid" -- docker exec pihole \
            sh -c 'printf "DE\n" > /var/www/html/.pihole-language'

        pct exec "$ctid" -- \
            sh -c 'printf "DE\n" > /opt/pihole/.web-language'

        echo "[OK] Deutsche Pi-hole-Weboberfläche aktiviert."
    else
        echo
        echo "FEHLER: Die deutsche Übersetzung konnte nicht verifiziert werden."
        echo "Möglicherweise passt die aktuelle Pi-hole-Webversion nicht"
        echo "zum derzeitigen translate2german-Stand."
        echo
        echo "Übersetzungsfehler aus dem Docker-Container:"
        pct exec "$ctid" -- docker exec pihole \
            sh -c 'cat /tmp/error-translate.log 2>/dev/null || true' || true
        exit 1
    fi
}

apply_en() {
    local ctid="$1"
    clean_english_container "$ctid"
    pct exec "$ctid" -- \
        sh -c 'printf "EN\n" > /opt/pihole/.web-language'
    echo "[OK] Englische Original-Weboberfläche aktiviert."
}

show_status() {
    local ctid="$1"
    local configured="unbekannt"
    local runtime="EN"

    configured="$(
        pct exec "$ctid" -- \
            sh -c 'cat /opt/pihole/.web-language 2>/dev/null || true' |
        tr -d '\r\n'
    )"

    if pct exec "$ctid" -- docker exec pihole \
        test -f /var/www/html/.pihole-language \
        >/dev/null 2>&1; then
        runtime="DE"
    fi

    echo "Gespeicherter Sprachmodus:"
    echo "  ${configured:-unbekannt}"
    echo
    echo "Aktuell im Docker-Container erkannt:"
    echo "  $runtime"

    if [[ "$configured" == "DE" && "$runtime" != "DE" ]]; then
        echo
        echo "WARNUNG:"
        echo "  DE ist gespeichert, die Übersetzung ist im aktuellen Container"
        echo "  aber nicht mehr vorhanden. Das kann nach einem Docker-Update passieren."
        echo "  Erneut anwenden: pihole-language DE"
    fi
}

usage() {
    cat <<'EOF'
Verwendung:
  pihole-language
  pihole-language DE
  pihole-language EN
  pihole-language status
  pihole-language update
EOF
}

CTID="$(find_pihole_ct || true)"

if [[ -z "$CTID" ]]; then
    echo "FEHLER: Kein LXC mit hostname 'pihole' gefunden."
    exit 1
fi

ensure_running "$CTID"
PIHOLE_IP="$(get_ct_ip "$CTID")"

MODE="${1:-}"
MODE="${MODE^^}"

if [[ -z "$MODE" ]]; then
    clear 2>/dev/null || true

    echo "============================================================"
    echo " PI-HOLE SPRACHE"
    echo "============================================================"
    echo
    echo "CT-ID: $CTID"
    echo "IP:    ${PIHOLE_IP:-unbekannt}"
    echo
    echo "1) Deutsch (translate2german)"
    echo "2) Englisch (Pi-hole Original)"
    echo "3) Status"
    echo "4) Übersetzungsquelle aktualisieren"
    echo "0) Abbrechen"
    echo

    read -rp "Auswahl [3]: " CHOICE
    CHOICE="${CHOICE:-3}"

    case "$CHOICE" in
        1) MODE="DE" ;;
        2) MODE="EN" ;;
        3) MODE="STATUS" ;;
        4) MODE="UPDATE" ;;
        0) exit 0 ;;
        *) echo "Ungültige Auswahl."; exit 1 ;;
    esac
fi

case "$MODE" in
    DE) apply_de "$CTID" ;;
    EN) apply_en "$CTID" ;;
    STATUS) show_status "$CTID" ;;
    UPDATE) update_source ;;
    -H|--HELP|HELP) usage ;;
    *) usage; exit 1 ;;
esac

echo
if [[ -n "$PIHOLE_IP" ]]; then
    echo "Pi-hole:"
    echo "  http://${PIHOLE_IP}/admin/"
    echo
fi

echo "Log:"
echo "  $LOGFILE"

__PIHOLE_LANGUAGE_TOOL__

    chmod 700 "$tool"
    chown root:root "$tool"
}

install_pihole_language_tool


# -----------------------------------------------------------------------------
# Täglicher Auto-Updater 05:00 Uhr + Pushover
# -----------------------------------------------------------------------------

install_proxmox_auto_updater() {
    local installer="/tmp/proxmox-auto-updater-install.$$"

    cat > "$installer" <<'__AUTO_UPDATER_INSTALLER__'
#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || {
    echo "FEHLER: Bitte als root auf dem Proxmox-Host ausführen."
    exit 1
}

echo "============================================================"
echo " PROXMOX AUTO-UPDATER INSTALLIEREN"
echo "============================================================"
echo

mkdir -p \
    /var/log/proxmox-auto-updater \
    /var/lib/proxmox-auto-updater \
    /root/.config/proxmox-auto-updater

chmod 700 \
    /var/log/proxmox-auto-updater \
    /var/lib/proxmox-auto-updater \
    /root/.config/proxmox-auto-updater

if ! command -v jq >/dev/null 2>&1 || \
   ! command -v curl >/dev/null 2>&1 || \
   ! command -v flock >/dev/null 2>&1; then

    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        curl \
        jq \
        util-linux \
        xz-utils
fi

cat > /usr/local/sbin/proxmox-auto-updater <<'__UPDATER__'
#!/usr/bin/env bash
set -Eeuo pipefail

LOCKFILE="/run/proxmox-auto-updater.lock"
LOG_DIR="/var/log/proxmox-auto-updater"
STATE_DIR="/var/lib/proxmox-auto-updater"
PUSH_CONF="/root/.config/proxmox-auto-updater/pushover.env"

IMAGE_DIR="/home/img"
HAOS_CACHE="${IMAGE_DIR}/haos"
LXC_CACHE="${IMAGE_DIR}/template/cache"
DOCKER_CACHE="${IMAGE_DIR}/docker"
OLLAMA_CACHE="${IMAGE_DIR}/ollama"
DOWNLOAD_CACHE="/root/downloads"
PIHOLE_LANG_CACHE="/root/downloads/pihole-language"

mkdir -p "$LOG_DIR" "$STATE_DIR"
chmod 700 "$LOG_DIR" "$STATE_DIR"

STAMP="$(date +%Y-%m-%d-%H-%M)"
LOGFILE="${LOG_DIR}/update-${STAMP}.txt"
touch "$LOGFILE"
chmod 600 "$LOGFILE"

exec > >(tee -a "$LOGFILE") 2>&1

exec 9>"$LOCKFILE"
if ! flock -n 9; then
    echo "Updater läuft bereits. Abbruch."
    exit 0
fi

# Alte Update-Logs nach 60 Tagen entfernen.
find "$LOG_DIR" -type f -name 'update-*.txt' -mtime +60 -delete 2>/dev/null || true

UPDATED_ITEMS=()
MANUAL_ITEMS=()
FAILED_ITEMS=()

PIHOLE_DOCKER_CHANGED=0
PIHOLE_TRANSLATION_CHANGED=0

add_update() {
    UPDATED_ITEMS+=("$1")
    echo "[UPDATE] $1"
}

add_manual() {
    MANUAL_ITEMS+=("$1")
    echo "[MANUELL] $1"
}

add_failure() {
    FAILED_ITEMS+=("$1")
    MANUAL_ITEMS+=("$1")
    echo "[FEHLER] $1"
}

short_list() {
    local data="$1"
    local count

    count="$(printf '%s\n' "$data" | awk 'NF' | wc -l)"

    if (( count == 0 )); then
        printf '0'
        return
    fi

    local names
    names="$(
        printf '%s\n' "$data" |
        awk 'NF' |
        head -n 12 |
        paste -sd ', ' -
    )"

    if (( count > 12 )); then
        printf '%s Pakete (%s, ...)' "$count" "$names"
    else
        printf '%s Pakete (%s)' "$count" "$names"
    fi
}

find_ct_by_hostname() {
    local wanted="$1"
    local id host

    while read -r id; do
        [[ "$id" =~ ^[0-9]+$ ]] || continue

        host="$(
            pct config "$id" 2>/dev/null |
            awk -F': ' '/^hostname:/ {print $2; exit}'
        )"

        if [[ "$host" == "$wanted" ]]; then
            echo "$id"
            return 0
        fi
    done < <(pct list 2>/dev/null | awk 'NR>1 {print $1}')

    return 1
}

find_ha_vm() {
    local id name

    while read -r id; do
        [[ "$id" =~ ^[0-9]+$ ]] || continue

        name="$(
            qm config "$id" 2>/dev/null |
            awk -F': ' '/^name:/ {print $2; exit}'
        )"

        if [[ "$name" == "homeassistant" ]]; then
            echo "$id"
            return 0
        fi
    done < <(qm list 2>/dev/null | awk 'NR>1 {print $1}')

    return 1
}

download_if_changed() {
    local url="$1"
    local dest="$2"
    local tmp="${dest}.part"

    mkdir -p "$(dirname "$dest")"
    rm -f "$tmp"

    if [[ -s "$dest" ]]; then
        if curl -fL --retry 2 --connect-timeout 15 \
            -R -z "$dest" \
            "$url" \
            -o "$tmp"; then

            if [[ -s "$tmp" ]]; then
                mv -f "$tmp" "$dest"
                return 0
            fi

            rm -f "$tmp"
            return 1
        fi

        rm -f "$tmp"
        return 2
    fi

    if curl -fL --retry 3 --connect-timeout 15 \
        -R \
        "$url" \
        -o "$tmp"; then
        mv -f "$tmp" "$dest"
        return 0
    fi

    rm -f "$tmp"
    return 2
}

# -----------------------------------------------------------------------------
# Pushover
# -----------------------------------------------------------------------------

pushover_send() {
    local title="$1"
    local message="$2"
    local priority="${3:-0}"

    [[ -f "$PUSH_CONF" ]] || return 0

    # shellcheck disable=SC1090
    source "$PUSH_CONF"

    [[ "${PUSHOVER_ENABLED:-0}" == "1" ]] || return 0
    [[ -n "${PUSHOVER_APP_TOKEN:-}" ]] || return 0

    # Pushover message body begrenzen.
    message="$(printf '%s' "$message" | head -c 900)"

    local idx user_var device_var name_var
    local user device name
    local sent=0

    for idx in 1 2; do
        user_var="PUSHOVER_USER_KEY_${idx}"
        device_var="PUSHOVER_DEVICE_${idx}"
        name_var="PUSHOVER_NAME_${idx}"

        user="${!user_var:-}"
        device="${!device_var:-}"
        name="${!name_var:-Empfänger ${idx}}"

        # Abwärtskompatibilität mit älteren V22-V26-Konfigurationen:
        if [[ "$idx" == "1" && -z "$user" ]]; then
            user="${PUSHOVER_USER_KEY:-}"
            device="${PUSHOVER_DEVICE:-}"
            name="${PUSHOVER_NAME:-Empfänger 1}"
        fi

        [[ -n "$user" ]] || continue

        local args=(
            -fsS
            --connect-timeout 10
            --max-time 20
            -X POST
            --data-urlencode "token=${PUSHOVER_APP_TOKEN}"
            --data-urlencode "user=${user}"
            --data-urlencode "title=${title}"
            --data-urlencode "message=${message}"
            --data-urlencode "priority=${priority}"
        )

        if [[ -n "$device" ]]; then
            args+=(--data-urlencode "device=${device}")
        fi

        if curl "${args[@]}" \
            https://api.pushover.net/1/messages.json \
            >/dev/null; then
            echo "Pushover gesendet an: $name"
            sent=$((sent + 1))
        else
            echo "WARNUNG: Pushover an '$name' konnte nicht gesendet werden."
        fi
    done

    if (( sent == 0 )); then
        echo "WARNUNG: Pushover ist aktiviert, aber kein gültiger Empfänger ist konfiguriert."
    fi
}

manual_notification_due() {
    local body="$1"
    local hash_file="${STATE_DIR}/manual-warning.sha256"
    local hash age now mtime

    hash="$(printf '%s' "$body" | sha256sum | awk '{print $1}')"

    if [[ ! -f "$hash_file" ]]; then
        printf '%s\n' "$hash" > "$hash_file"
        return 0
    fi

    if [[ "$(cat "$hash_file" 2>/dev/null)" != "$hash" ]]; then
        printf '%s\n' "$hash" > "$hash_file"
        return 0
    fi

    now="$(date +%s)"
    mtime="$(stat -c %Y "$hash_file" 2>/dev/null || echo 0)"
    age=$(( now - mtime ))

    # Gleiche manuelle Warnung höchstens einmal pro 7 Tage.
    if (( age >= 604800 )); then
        touch "$hash_file"
        return 0
    fi

    return 1
}

# -----------------------------------------------------------------------------
# Cache aktuell halten
# -----------------------------------------------------------------------------

update_lxc_template_cache() {
    command -v pveam >/dev/null 2>&1 || return 0
    pvesm status 2>/dev/null | awk 'NR>1 {print $1}' | grep -Fxq image-cache || return 0

    echo
    echo "=== LXC TEMPLATE CACHE ==="

    if ! pveam update; then
        add_failure "LXC-Template-Liste konnte nicht aktualisiert werden"
        return
    fi

    local template dest

    template="$(
        pveam available --section system 2>/dev/null |
        awk '$2~/^debian-13-standard_.*amd64\.tar\.(zst|xz|gz)$/{print $2}' |
        sort -V |
        tail -1
    )"

    [[ -n "$template" ]] || return 0

    dest="${LXC_CACHE}/${template}"

    if [[ ! -s "$dest" ]]; then
        if pveam download image-cache "$template"; then
            add_update "LXC-Template-Cache: $template"
        else
            add_failure "LXC-Template $template konnte nicht geladen werden"
        fi
    fi
}

update_haos_cache() {
    command -v jq >/dev/null 2>&1 || return 0

    echo
    echo "=== HAOS INSTALLATIONS-IMAGE CACHE ==="

    mkdir -p "$HAOS_CACHE"

    local json="${HAOS_CACHE}/stable.json"
    local tmp="${json}.part"
    local version xz qcow2

    if ! curl -fsSL --connect-timeout 15 \
        https://version.home-assistant.io/stable.json \
        -o "$tmp"; then
        rm -f "$tmp"
        echo "HAOS Versionsprüfung nicht erreichbar; vorhandener Cache bleibt."
        return
    fi

    mv -f "$tmp" "$json"

    version="$(jq -r '.hassos.ova // empty' "$json")"
    [[ -n "$version" ]] || return 0

    xz="${HAOS_CACHE}/haos_ova-${version}.qcow2.xz"
    qcow2="${HAOS_CACHE}/haos_ova-${version}.qcow2"

    if [[ ! -s "$qcow2" ]]; then
        if [[ ! -s "$xz" ]]; then
            if curl -fL --retry 3 \
                "https://github.com/home-assistant/operating-system/releases/download/${version}/haos_ova-${version}.qcow2.xz" \
                -o "${xz}.part"; then
                mv -f "${xz}.part" "$xz"
            else
                rm -f "${xz}.part"
                add_failure "HAOS Cache-Version $version konnte nicht geladen werden"
                return
            fi
        fi

        if xz -dkf "$xz"; then
            add_update "HAOS Installations-Cache: Version $version"
        else
            add_failure "HAOS Cache-Version $version konnte nicht entpackt werden"
        fi
    fi
}

update_misc_downloads() {
    echo
    echo "=== KLEINE DOWNLOAD-CACHES ==="

    mkdir -p \
        "${DOWNLOAD_CACHE}/pihole" \
        "${DOWNLOAD_CACHE}/scrutiny" \
        "$PIHOLE_LANG_CACHE" \
        "$DOCKER_CACHE"

    local rc

    set +e
    download_if_changed \
        "https://download.docker.com/linux/debian/gpg" \
        "${DOCKER_CACHE}/docker.asc"
    rc=$?
    set -e

    if (( rc == 0 )); then
        chmod 644 "${DOCKER_CACHE}/docker.asc"
        chown 100000:100000 "${DOCKER_CACHE}/docker.asc" 2>/dev/null || true
        add_update "Docker Repository-Key Cache"
    elif (( rc == 2 )); then
        add_failure "Docker Repository-Key konnte nicht geprüft werden"
    fi

    set +e
    download_if_changed \
        "https://www.internic.net/domain/named.root" \
        "${DOWNLOAD_CACHE}/pihole/named.root"
    rc=$?
    set -e

    if (( rc == 0 )); then
        add_update "Unbound Root-Hints Cache"
        update_running_pihole_root_hints || true
    elif (( rc == 2 )); then
        echo "Root-Hints Online-Prüfung fehlgeschlagen; Cache bleibt."
    fi

    set +e
    download_if_changed \
        "https://raw.githubusercontent.com/pimanDE/translate2german/master/translate2german.sh" \
        "${PIHOLE_LANG_CACHE}/translate2german.sh"
    rc=$?
    set -e

    if (( rc == 0 )); then
        PIHOLE_TRANSLATION_CHANGED=1
        add_update "Pi-hole deutsche Übersetzungsquelle"
    elif (( rc == 2 )); then
        echo "Pi-hole Übersetzungsquelle konnte nicht geprüft werden; Cache bleibt."
    fi

    update_scrutiny_collector_cache || true
}

update_running_pihole_root_hints() {
    local ctid
    ctid="$(find_ct_by_hostname pihole || true)"
    [[ -n "$ctid" ]] || return 0

    pct status "$ctid" 2>/dev/null | grep -q 'status: running' || return 0

    pct push \
        "$ctid" \
        "${DOWNLOAD_CACHE}/pihole/named.root" \
        /var/lib/unbound/root.hints >/dev/null

    pct exec "$ctid" -- bash -lc '
        chown unbound:unbound /var/lib/unbound/root.hints
        chmod 644 /var/lib/unbound/root.hints
        systemctl restart unbound
    ' >/dev/null
}

update_scrutiny_collector_cache() {
    local arch dest rc

    case "$(uname -m)" in
        x86_64|amd64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *) return 0 ;;
    esac

    dest="${DOWNLOAD_CACHE}/scrutiny/scrutiny-collector-metrics-linux-${arch}"

    set +e
    download_if_changed \
        "https://github.com/AnalogJ/scrutiny/releases/latest/download/scrutiny-collector-metrics-linux-${arch}" \
        "$dest"
    rc=$?
    set -e

    if (( rc == 0 )); then
        chmod 755 "$dest"
        add_update "Scrutiny Collector Cache"

        if [[ -f /opt/scrutiny-collector/scrutiny-collector-metrics ]]; then
            install -m 0755 \
                "$dest" \
                /opt/scrutiny-collector/scrutiny-collector-metrics
        fi
    elif (( rc == 2 )); then
        echo "Scrutiny Collector konnte nicht online geprüft werden."
    fi
}

# -----------------------------------------------------------------------------
# LXC / Docker Updates
# -----------------------------------------------------------------------------

update_ct_apt() {
    local ctid="$1"
    local label="$2"
    local packages=""

    echo
    echo "--- ${label}: APT ---"

    if ! pct exec "$ctid" -- bash -lc '
        set -Eeuo pipefail
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
    '; then
        add_failure "${label}: apt update fehlgeschlagen"
        return
    fi

    packages="$(
        pct exec "$ctid" -- bash -lc '
            apt-get -s dist-upgrade 2>/dev/null |
            awk "/^Inst / {print \$2}"
        ' 2>/dev/null |
        tr -d '\r'
    )"

    if [[ -n "$packages" ]]; then
        if pct exec "$ctid" -- bash -lc '
            set -Eeuo pipefail
            export DEBIAN_FRONTEND=noninteractive
            export NEEDRESTART_MODE=a
            apt-get -y dist-upgrade
        '; then
            add_update "${label} APT: $(short_list "$packages")"
        else
            add_failure "${label}: APT-Upgrade fehlgeschlagen"
        fi
    else
        echo "${label}: keine APT-Updates."
    fi
}

compose_state() {
    local ctid="$1"
    local dir="$2"

    pct exec "$ctid" -- bash -lc "
        set -e
        cd '$dir'

        docker compose config --images |
        awk 'NF' |
        sort -u |
        while read -r image; do
            id=\$(docker image inspect --format '{{.Id}}' \"\$image\" 2>/dev/null || true)
            printf '%s|%s\\n' \"\$image\" \"\$id\"
        done
    " 2>/dev/null | tr -d '\r'
}

update_ct_compose() {
    local ctid="$1"
    local label="$2"
    local dir="$3"
    local hostname="$4"

    [[ -n "$dir" ]] || return 0

    if ! pct exec "$ctid" -- test -f "${dir}/docker-compose.yml" >/dev/null 2>&1 \
       && ! pct exec "$ctid" -- test -f "${dir}/compose.yml" >/dev/null 2>&1 \
       && ! pct exec "$ctid" -- test -f "${dir}/compose.yaml" >/dev/null 2>&1; then
        return 0
    fi

    echo
    echo "--- ${label}: Docker ---"

    local before after

    before="$(compose_state "$ctid" "$dir" || true)"

    if pct exec "$ctid" -- bash -lc "
        set -Eeuo pipefail
        cd '$dir'

        if command -v docker-cache-pull >/dev/null 2>&1; then
            docker-cache-pull .
        else
            docker compose pull
        fi
    "; then
        after="$(compose_state "$ctid" "$dir" || true)"

        if [[ "$before" != "$after" ]]; then
            if pct exec "$ctid" -- bash -lc "
                set -Eeuo pipefail
                cd '$dir'
                docker compose up -d --remove-orphans
            "; then
                add_update "${label}: Docker-Images/Container aktualisiert"

                if [[ "$hostname" == "pihole" ]]; then
                    PIHOLE_DOCKER_CHANGED=1
                fi
            else
                add_failure "${label}: neue Docker-Images geladen, Container-Neustart fehlgeschlagen"
            fi
        else
            echo "${label}: Docker-Images bereits aktuell."
        fi
    else
        add_failure "${label}: Docker-Updateprüfung fehlgeschlagen"
    fi
}

update_one_ct() {
    local hostname="$1"
    local label="$2"
    local dir="$3"

    local ctid was_running=0

    ctid="$(find_ct_by_hostname "$hostname" || true)"
    [[ -n "$ctid" ]] || return 0

    echo
    echo "============================================================"
    echo " ${label} (CT ${ctid})"
    echo "============================================================"

    if pct status "$ctid" 2>/dev/null | grep -q 'status: running'; then
        was_running=1
    else
        echo "Container war gestoppt; starte nur für Update ..."
        if ! pct start "$ctid"; then
            add_failure "${label}: LXC konnte für Update nicht gestartet werden"
            return
        fi
        sleep 5
    fi

    update_ct_apt "$ctid" "$label"
    update_ct_compose "$ctid" "$label" "$dir" "$hostname"

    # Automatischer LXC-Reboot, falls Debian diesen verlangt.
    if pct exec "$ctid" -- test -f /var/run/reboot-required >/dev/null 2>&1; then
        if pct reboot "$ctid"; then
            add_update "${label}: LXC-Neustart nach Paketupdate"
            sleep 4
        else
            add_manual "${label}: Neustart nach Paketupdate erforderlich"
        fi
    fi

    if (( was_running == 0 )); then
        echo "Container war vor dem Update gestoppt; stoppe wieder ..."
        pct shutdown "$ctid" --timeout 60 || pct stop "$ctid" || true
    fi
}

update_managed_lxcs() {
    update_one_ct "paperless"         "Paperless/Ollama"    "/opt/paperless"
    update_one_ct "pihole"            "Pi-hole/Unbound"     "/opt/pihole"
    update_one_ct "netalertx"         "NetAlertX"           "/opt/netalertx"
    update_one_ct "uptime-kuma"       "Uptime Kuma"         "/opt/uptime-kuma"
    update_one_ct "vaultwarden"       "Vaultwarden"         "/opt/vaultwarden"
    update_one_ct "caddy"             "Caddy"               "/opt/caddy"
    update_one_ct "stirling-pdf"      "Stirling PDF"        "/opt/stirling-pdf"
    update_one_ct "ntfy"              "ntfy"                "/opt/ntfy"
    update_one_ct "forgejo"           "Forgejo"             "/opt/forgejo"
    update_one_ct "syncthing"         "Syncthing"           "/opt/syncthing"
    update_one_ct "speedtest-tracker" "Speedtest Tracker"   "/opt/speedtest-tracker"
    update_one_ct "scrutiny"          "Scrutiny"            "/opt/scrutiny"
    update_one_ct "mealie"            "Mealie"              "/opt/mealie"
}

# -----------------------------------------------------------------------------
# Ollama Models
# -----------------------------------------------------------------------------

ollama_model_id() {
    local ctid="$1"
    local model="$2"

    pct exec "$ctid" -- \
        docker exec paperless-ollama ollama list 2>/dev/null |
    awk -v model="$model" '$1==model {print $2; exit}' |
    tr -d '\r'
}

update_ollama_models() {
    local ctid

    ctid="$(find_ct_by_hostname paperless || true)"
    [[ -n "$ctid" ]] || return 0
    pct status "$ctid" 2>/dev/null | grep -q 'status: running' || return 0

    if ! pct exec "$ctid" -- docker inspect paperless-ollama >/dev/null 2>&1; then
        return 0
    fi

    echo
    echo "============================================================"
    echo " OLLAMA MODELLE"
    echo "============================================================"

    local model before after

    for model in "qwen2.5:7b" "embeddinggemma"; do
        before="$(ollama_model_id "$ctid" "$model" || true)"

        if pct exec "$ctid" -- \
            docker exec paperless-ollama ollama pull "$model"; then

            after="$(ollama_model_id "$ctid" "$model" || true)"

            if [[ "$before" != "$after" ]]; then
                add_update "Ollama-Modell: ${model}"
            else
                echo "Ollama ${model}: bereits aktuell."
            fi
        else
            add_failure "Ollama-Modell ${model}: Updateprüfung fehlgeschlagen"
        fi
    done
}

# -----------------------------------------------------------------------------
# Pi-hole deutsche Übersetzung nach Container-Update wieder anwenden
# -----------------------------------------------------------------------------

restore_pihole_language() {
    local ctid lang

    ctid="$(find_ct_by_hostname pihole || true)"
    [[ -n "$ctid" ]] || return 0

    lang="$(
        pct exec "$ctid" -- \
            sh -c 'cat /opt/pihole/.web-language 2>/dev/null || true' |
        tr -d '\r\n'
    )"

    [[ "$lang" == "DE" ]] || return 0

    if (( PIHOLE_DOCKER_CHANGED == 1 || PIHOLE_TRANSLATION_CHANGED == 1 )); then
        if command -v pihole-language >/dev/null 2>&1; then
            if pihole-language DE; then
                add_update "Pi-hole: deutsche Webübersetzung erneut angewendet"
            else
                add_manual "Pi-hole: deutsche Übersetzung muss geprüft werden"
            fi
        else
            add_manual "Pi-hole DE: Sprachtool fehlt"
        fi
    fi
}

# -----------------------------------------------------------------------------
# Home Assistant OS
# -----------------------------------------------------------------------------

qga_output() {
    local vmid="$1"
    shift

    timeout 120 qm guest exec "$vmid" \
        --output-format json \
        -- "$@" 2>/dev/null |
    jq -r '."out-data" // empty' 2>/dev/null
}

ha_update_available() {
    local vmid="$1"
    local component="$2"
    local info

    info="$(qga_output "$vmid" sh -lc "ha ${component} info --raw-json" || true)"
    [[ -n "$info" ]] || return 2

    if printf '%s' "$info" |
       jq -e '.. | objects | select(.update_available == true)' >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

update_home_assistant() {
    local vmid

    vmid="$(find_ha_vm || true)"
    [[ -n "$vmid" ]] || return 0

    echo
    echo "============================================================"
    echo " HOME ASSISTANT (VM ${vmid})"
    echo "============================================================"

    qm status "$vmid" 2>/dev/null | grep -q 'status: running' || {
        echo "Home Assistant VM ist gestoppt; automatische Aktualisierung übersprungen."
        return 0
    }

    if ! timeout 20 qm guest cmd "$vmid" ping >/dev/null 2>&1; then
        add_manual "Home Assistant: QEMU Guest Agent nicht erreichbar; Updates im HA-Menü prüfen"
        return 0
    fi

    local rc

    set +e
    ha_update_available "$vmid" core
    rc=$?
    set -e

    if (( rc == 0 )); then
        if timeout 3600 qm guest exec "$vmid" \
            -- sh -lc 'ha core update --backup'; then
            add_update "Home Assistant Core (mit Backup)"
        else
            add_failure "Home Assistant Core Update fehlgeschlagen"
        fi
    elif (( rc == 2 )); then
        echo "HA Core Update-Status konnte nicht gelesen werden."
    else
        echo "Home Assistant Core: aktuell."
    fi

    set +e
    ha_update_available "$vmid" supervisor
    rc=$?
    set -e

    if (( rc == 0 )); then
        if timeout 1800 qm guest exec "$vmid" \
            -- sh -lc 'ha supervisor update'; then
            add_update "Home Assistant Supervisor"
        else
            add_failure "Home Assistant Supervisor Update fehlgeschlagen"
        fi
    elif (( rc == 2 )); then
        echo "HA Supervisor Update-Status konnte nicht gelesen werden."
    else
        echo "Home Assistant Supervisor: aktuell."
    fi

    set +e
    ha_update_available "$vmid" os
    rc=$?
    set -e

    if (( rc == 0 )); then
        echo "HAOS Update gefunden; OS-Update wird zuletzt ausgeführt."
        if timeout 3600 qm guest exec "$vmid" \
            -- sh -lc 'ha os update'; then
            add_update "Home Assistant OS (VM führt Neustart selbst durch)"
        else
            add_failure "Home Assistant OS Update fehlgeschlagen"
        fi
    elif (( rc == 2 )); then
        echo "HAOS Update-Status konnte nicht gelesen werden."
    else
        echo "Home Assistant OS: aktuell."
    fi
}

# -----------------------------------------------------------------------------
# Proxmox Host Updates
# -----------------------------------------------------------------------------

update_proxmox_host() {
    echo
    echo "============================================================"
    echo " PROXMOX HOST"
    echo "============================================================"

    local packages=""

    if ! apt-get update; then
        add_failure "Proxmox Host: apt update fehlgeschlagen"
        return
    fi

    packages="$(
        apt-get -s dist-upgrade 2>/dev/null |
        awk '/^Inst / {print $2}'
    )"

    if [[ -n "$packages" ]]; then
        if DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a \
           apt-get -y dist-upgrade; then
            add_update "Proxmox Host APT: $(short_list "$packages")"
        else
            add_failure "Proxmox Host: dist-upgrade fehlgeschlagen"
        fi
    else
        echo "Proxmox Host: keine APT-Updates."
    fi

    local running newest

    running="$(uname -r)"

    newest="$(
        find /boot -maxdepth 1 -type f -name 'vmlinuz-*-pve' \
            -printf '%f\n' 2>/dev/null |
        sed 's/^vmlinuz-//' |
        sort -V |
        tail -1
    )"

    if [[ -f /var/run/reboot-required ]]; then
        add_manual "Proxmox Host: Neustart erforderlich"
    elif [[ -n "$newest" && "$newest" != "$running" ]]; then
        add_manual "Proxmox Host: neuer Kernel ${newest}; aktuell läuft ${running} – Neustart erforderlich"
    fi
}

# -----------------------------------------------------------------------------
# Summary / Notifications
# -----------------------------------------------------------------------------

build_summary() {
    local out=""

    if (( ${#UPDATED_ITEMS[@]} > 0 )); then
        out+="Installiert/aktualisiert:\n"
        local item
        for item in "${UPDATED_ITEMS[@]}"; do
            out+="- ${item}\n"
        done
    fi

    if (( ${#MANUAL_ITEMS[@]} > 0 )); then
        [[ -n "$out" ]] && out+="\n"
        out+="Persönliches Eingreifen:\n"
        local item
        for item in "${MANUAL_ITEMS[@]}"; do
            out+="- ${item}\n"
        done
    fi

    printf '%b' "$out"
}

send_summary() {
    local summary
    summary="$(build_summary)"

    if [[ -z "$summary" ]]; then
        echo
        echo "Keine Updates und kein Eingreifen erforderlich."
        return
    fi

    echo
    echo "============================================================"
    echo " ZUSAMMENFASSUNG"
    echo "============================================================"
    printf '%s\n' "$summary"

    if (( ${#MANUAL_ITEMS[@]} > 0 )); then
        if (( ${#UPDATED_ITEMS[@]} > 0 )); then
            pushover_send \
                "Proxmox Updates + Eingreifen nötig" \
                "$summary" \
                1
        elif manual_notification_due "$summary"; then
            pushover_send \
                "Proxmox: Eingreifen nötig" \
                "$summary" \
                1
        else
            echo "Identische manuelle Pushover-Warnung wurde in den letzten 7 Tagen bereits gesendet."
        fi
    elif (( ${#UPDATED_ITEMS[@]} > 0 )); then
        pushover_send \
            "Proxmox Updates installiert" \
            "$summary" \
            0
    fi
}

# =============================================================================
# START
# =============================================================================

echo "============================================================"
echo " PROXMOX AUTO-UPDATER"
echo " $(date)"
echo "============================================================"
echo
echo "Log:"
echo "  $LOGFILE"

update_lxc_template_cache
update_haos_cache
update_misc_downloads

update_managed_lxcs
update_ollama_models
restore_pihole_language
update_home_assistant

# Host zuletzt, damit PVE-Paketupdates die laufende CT-Aktualisierung nicht stören.
update_proxmox_host

send_summary

echo
echo "Fertig: $(date)"
echo "Log: $LOGFILE"

__UPDATER__

cat > /usr/local/sbin/proxmox-auto-updater-config <<'__CONFIG__'
#!/usr/bin/env bash
set -Eeuo pipefail

CONF_DIR="/root/.config/proxmox-auto-updater"
CONF="${CONF_DIR}/pushover.env"
UPDATER="/usr/local/sbin/proxmox-auto-updater"

mkdir -p "$CONF_DIR"
chmod 700 "$CONF_DIR"

test_pushover_values() {
    local token="$1"
    local user="$2"
    local device="${3:-}"
    local label="${4:-Empfänger}"

    [[ -n "$token" ]] || {
        echo "FEHLER: Application/API Token fehlt."
        return 1
    }

    [[ -n "$user" ]] || {
        echo "FEHLER: User/Group Key für '$label' fehlt."
        return 1
    }

    local args=(
        -fsS
        --connect-timeout 10
        --max-time 20
        -X POST
        --data-urlencode "token=${token}"
        --data-urlencode "user=${user}"
        --data-urlencode "title=Proxmox Auto-Updater"
        --data-urlencode "message=Pushover-Verbindung für ${label} erfolgreich."
    )

    [[ -z "$device" ]] || args+=(--data-urlencode "device=${device}")

    local response

    response="$(
        curl "${args[@]}" \
            https://api.pushover.net/1/messages.json
    )"

    if printf '%s' "$response" | grep -q '"status":1'; then
        echo "[OK] Testnachricht gesendet an: $label"
        return 0
    fi

    echo "FEHLER: Pushover-Test für '$label' fehlgeschlagen."
    echo "$response"
    return 1
}

configure_pushover() {
    local token
    local name1 user1 device1
    local name2="" user2="" device2=""
    local add_second="n"

    echo
    echo "Pushover benötigt:"
    echo "  - einen Application/API Token"
    echo "  - mindestens einen User/Group Key"
    echo "  - optional einen zweiten User/Group Key"
    echo "  - optional pro Empfänger einen Device-Namen"
    echo

    read -rsp "Pushover Application/API Token: " token
    echo

    [[ -n "$token" ]] || {
        echo "Token darf nicht leer sein."
        return 1
    }

    echo
    echo "=== Empfänger 1 ==="
    read -rp "Name/Bezeichnung [Empfänger 1]: " name1
    name1="${name1:-Empfänger 1}"

    read -rsp "User/Group Key für ${name1}: " user1
    echo
    read -rp "Device für ${name1} (ENTER = alle Geräte): " device1

    [[ -n "$user1" ]] || {
        echo "User/Group Key für Empfänger 1 darf nicht leer sein."
        return 1
    }

    echo
    read -rp "Zweiten Pushover-Empfänger einrichten? [j/N]: " add_second
    add_second="${add_second:-n}"

    if [[ "$add_second" =~ ^[JjYy]$ ]]; then
        echo
        echo "=== Empfänger 2 ==="

        read -rp "Name/Bezeichnung [Empfänger 2]: " name2
        name2="${name2:-Empfänger 2}"

        read -rsp "User/Group Key für ${name2}: " user2
        echo
        read -rp "Device für ${name2} (ENTER = alle Geräte): " device2

        [[ -n "$user2" ]] || {
            echo "User/Group Key für Empfänger 2 darf nicht leer sein."
            return 1
        }
    fi

    echo
    echo "Teste Empfänger ..."

    test_pushover_values \
        "$token" \
        "$user1" \
        "$device1" \
        "$name1" || return 1

    if [[ -n "$user2" ]]; then
        test_pushover_values \
            "$token" \
            "$user2" \
            "$device2" \
            "$name2" || return 1
    fi

    {
        echo 'PUSHOVER_ENABLED=1'
        printf 'PUSHOVER_APP_TOKEN=%q\n' "$token"

        printf 'PUSHOVER_NAME_1=%q\n' "$name1"
        printf 'PUSHOVER_USER_KEY_1=%q\n' "$user1"
        printf 'PUSHOVER_DEVICE_1=%q\n' "$device1"

        printf 'PUSHOVER_NAME_2=%q\n' "$name2"
        printf 'PUSHOVER_USER_KEY_2=%q\n' "$user2"
        printf 'PUSHOVER_DEVICE_2=%q\n' "$device2"
    } > "$CONF"

    chmod 600 "$CONF"

    echo
    echo "[OK] Pushover-Konfiguration gespeichert:"
    echo "  $CONF"
    echo
    echo "Aktive Empfänger:"
    echo "  1) $name1"
    [[ -z "$user2" ]] || echo "  2) $name2"
}

test_configured_pushover() {
    if [[ ! -f "$CONF" ]]; then
        echo "Pushover ist noch nicht konfiguriert."
        return 1
    fi

    # shellcheck disable=SC1090
    source "$CONF"

    [[ "${PUSHOVER_ENABLED:-0}" == "1" ]] || {
        echo "Pushover ist deaktiviert."
        return 1
    }

    local token="${PUSHOVER_APP_TOKEN:-}"
    local user1="${PUSHOVER_USER_KEY_1:-${PUSHOVER_USER_KEY:-}}"
    local device1="${PUSHOVER_DEVICE_1:-${PUSHOVER_DEVICE:-}}"
    local name1="${PUSHOVER_NAME_1:-${PUSHOVER_NAME:-Empfänger 1}}"

    local user2="${PUSHOVER_USER_KEY_2:-}"
    local device2="${PUSHOVER_DEVICE_2:-}"
    local name2="${PUSHOVER_NAME_2:-Empfänger 2}"

    test_pushover_values \
        "$token" \
        "$user1" \
        "$device1" \
        "$name1" || return 1

    if [[ -n "$user2" ]]; then
        test_pushover_values \
            "$token" \
            "$user2" \
            "$device2" \
            "$name2" || return 1
    fi
}

show_status() {
    echo
    echo "Timer:"
    systemctl status proxmox-auto-updater.timer --no-pager || true
    echo
    systemctl list-timers proxmox-auto-updater.timer --no-pager || true
    echo

    if [[ -f "$CONF" ]]; then
        # shellcheck disable=SC1090
        source "$CONF"

        if [[ "${PUSHOVER_ENABLED:-0}" == "1" ]]; then
            local user1="${PUSHOVER_USER_KEY_1:-${PUSHOVER_USER_KEY:-}}"
            local device1="${PUSHOVER_DEVICE_1:-${PUSHOVER_DEVICE:-}}"
            local name1="${PUSHOVER_NAME_1:-${PUSHOVER_NAME:-Empfänger 1}}"

            local user2="${PUSHOVER_USER_KEY_2:-}"
            local device2="${PUSHOVER_DEVICE_2:-}"
            local name2="${PUSHOVER_NAME_2:-Empfänger 2}"

            echo "Pushover: aktiviert"

            if [[ -n "$user1" ]]; then
                echo "Empfänger 1: $name1"
                echo "  Device: ${device1:-alle Geräte}"
            fi

            if [[ -n "$user2" ]]; then
                echo "Empfänger 2: $name2"
                echo "  Device: ${device2:-alle Geräte}"
            else
                echo "Empfänger 2: nicht eingerichtet"
            fi
        else
            echo "Pushover: deaktiviert"
        fi
    else
        echo "Pushover: nicht konfiguriert"
    fi
}

while true; do
    echo
    echo "============================================================"
    echo " PROXMOX AUTO-UPDATER"
    echo "============================================================"
    echo
    echo "Täglich automatisch: 05:00 Uhr"
    echo
    echo "1) Status anzeigen"
    echo "2) Pushover konfigurieren / ändern"
    echo "3) Pushover Testnachricht senden"
    echo "4) Pushover deaktivieren"
    echo "5) Update-Lauf JETZT starten"
    echo "6) Letztes Update-Log anzeigen"
    echo "0) Beenden"
    echo

    read -rp "Auswahl [1]: " choice
    choice="${choice:-1}"

    case "$choice" in
        1)
            show_status
            ;;
        2)
            configure_pushover
            ;;
        3)
            test_configured_pushover || true
            ;;
        4)
            if [[ -f "$CONF" ]]; then
                sed -i 's/^PUSHOVER_ENABLED=.*/PUSHOVER_ENABLED=0/' "$CONF"
                chmod 600 "$CONF"
            fi
            echo "[OK] Pushover deaktiviert."
            ;;
        5)
            "$UPDATER"
            ;;
        6)
            latest="$(
                find /var/log/proxmox-auto-updater \
                    -maxdepth 1 -type f -name 'update-*.txt' \
                    -printf '%T@ %p\n' 2>/dev/null |
                sort -nr |
                head -n1 |
                cut -d' ' -f2-
            )"

            if [[ -n "$latest" && -f "$latest" ]]; then
                less "$latest"
            else
                echo "Noch kein Update-Log vorhanden."
            fi
            ;;
        0)
            exit 0
            ;;
        *)
            echo "Ungültige Auswahl."
            ;;
    esac
done

__CONFIG__

chmod 700 \
    /usr/local/sbin/proxmox-auto-updater \
    /usr/local/sbin/proxmox-auto-updater-config

chown root:root \
    /usr/local/sbin/proxmox-auto-updater \
    /usr/local/sbin/proxmox-auto-updater-config

cat > /etc/systemd/system/proxmox-auto-updater.service <<'EOF'
[Unit]
Description=Proxmox täglicher Auto-Updater
After=network-online.target pve-cluster.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/proxmox-auto-updater
Nice=10
IOSchedulingClass=best-effort
IOSchedulingPriority=7
EOF

cat > /etc/systemd/system/proxmox-auto-updater.timer <<'EOF'
[Unit]
Description=Proxmox Auto-Updater täglich um 05:00 Uhr

[Timer]
OnCalendar=*-*-* 05:00:00
Persistent=true
AccuracySec=1s
Unit=proxmox-auto-updater.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now proxmox-auto-updater.timer

echo
echo "[OK] Auto-Updater installiert."
echo
echo "Zeitplan:"
systemctl list-timers proxmox-auto-updater.timer --no-pager || true
echo
echo "Konfiguration:"
echo "  proxmox-auto-updater-config"
echo
echo "Manueller Lauf:"
echo "  proxmox-auto-updater"
echo
echo "Pushover ist optional und zunächst deaktiviert."

__AUTO_UPDATER_INSTALLER__

    chmod 700 "$installer"
    bash "$installer"
    rm -f "$installer"
}

# V116:
# Der Auto-Updater darf hier NICHT gestartet werden. Auf einem frischen
# Proxmox-Host sind standardmäßig noch Enterprise-Repositories aktiv und der
# eingebettete Installer benötigt ggf. Pakete (z. B. jq). Sein apt-get update
# würde sonst vor dem No-Subscription-Preflight mit HTTP 401 abbrechen.
# Der Aufruf erfolgt deshalb erst im Startup-Preflight weiter unten.


# -----------------------------------------------------------------------------
# Installations-Passwörter anzeigen
# -----------------------------------------------------------------------------

install_password_viewer_tool() {
    local tool="/usr/local/sbin/proxmox-passwoerter"

    cat > "$tool" <<'__PROXMOX_PASSWORD_VIEWER__'
#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || {
    echo "FEHLER: Installations-Passwörter dürfen nur als root angezeigt werden."
    exit 1
}

PW_DIR="/root/passwort"
LEGACY_PW_DIR="/root"

load_files() {
    mapfile -t PW_FILES < <(
        {
            find "$PW_DIR" \
                -maxdepth 1 \
                -type f \
                \( -name '*-pw-*.txt' -o -name 'install-index-*.txt' \) \
                -printf '%T@|%p\n' 2>/dev/null
            find "$LEGACY_PW_DIR" \
                -maxdepth 1 \
                -type f \
                -name 'pw-*.txt' \
                -printf '%T@|%p\n' 2>/dev/null
        } |
        sort -t'|' -k1,1nr |
        cut -d'|' -f2-
    )
}

file_label() {
    local file="$1"
    local date_text

    date_text="$(stat -c '%y' "$file" 2>/dev/null | cut -d'.' -f1)"

    printf '%s  [%s]' \
        "$(basename "$file")" \
        "${date_text:-unbekannt}"
}

confirm_secret_display() {
    local confirm

    echo
    echo "ACHTUNG: Die nächste Ausgabe enthält Klartext-Passwörter."
    read -rsp "Zum Anzeigen exakt ANZEIGEN eingeben: " confirm
    echo

    [[ "$confirm" == "ANZEIGEN" ]]
}

show_file() {
    local file="$1"

    [[ -f "$file" ]] || {
        echo "Datei nicht gefunden: $file"
        return 1
    }

    confirm_secret_display || {
        echo "Anzeige abgebrochen."
        return 0
    }

    clear 2>/dev/null || true

    echo "============================================================"
    echo " INSTALLATIONS-PASSWÖRTER"
    echo "============================================================"
    echo
    echo "Datei:"
    echo "  $file"
    echo
    echo "------------------------------------------------------------"
    cat "$file"
    echo "------------------------------------------------------------"
    echo
    echo "Es wurde KEIN zusätzliches Passwort-Log erzeugt."
}

show_latest() {
    load_files

    if (( ${#PW_FILES[@]} == 0 )); then
        echo "Keine Passwortdateien unter /root/passwort oder alte /root/pw-*.txt gefunden."
        return 1
    fi

    show_file "${PW_FILES[0]}"
}

choose_file() {
    load_files

    if (( ${#PW_FILES[@]} == 0 )); then
        echo "Keine Passwortdateien gefunden."
        return 1
    fi

    echo
    echo "Passwortdateien – neueste zuerst:"
    echo

    local i

    for i in "${!PW_FILES[@]}"; do
        printf ' %2d) %s\n' \
            "$((i + 1))" \
            "$(file_label "${PW_FILES[$i]}")"
    done

    echo
    echo "  0) Abbrechen"
    echo

    local choice
    read -rp "Datei auswählen: " choice

    [[ "$choice" =~ ^[0-9]+$ ]] || {
        echo "Ungültige Auswahl."
        return 1
    }

    (( choice == 0 )) && return 0

    if (( choice < 1 || choice > ${#PW_FILES[@]} )); then
        echo "Ungültige Auswahl."
        return 1
    fi

    show_file "${PW_FILES[$((choice - 1))]}"
}

search_files() {
    load_files

    if (( ${#PW_FILES[@]} == 0 )); then
        echo "Keine Passwortdateien gefunden."
        return 1
    fi

    local term
    echo
    read -rp "Dienst/Suchbegriff, z. B. Pi-hole, Paperless, Vaultwarden: " term

    [[ -n "$term" ]] || {
        echo "Kein Suchbegriff eingegeben."
        return 1
    }

    local matches=()
    local file

    for file in "${PW_FILES[@]}"; do
        grep -qiF -- "$term" "$file" && matches+=("$file")
    done

    if (( ${#matches[@]} == 0 )); then
        echo "Keine Passwortdatei mit '$term' gefunden."
        return 0
    fi

    echo
    echo "Treffer für '$term' – neueste zuerst:"
    echo

    local i

    for i in "${!matches[@]}"; do
        printf ' %2d) %s\n' \
            "$((i + 1))" \
            "$(file_label "${matches[$i]}")"
    done

    echo
    echo "  0) Abbrechen"
    echo

    local choice
    read -rp "Treffer auswählen [1]: " choice
    choice="${choice:-1}"

    [[ "$choice" =~ ^[0-9]+$ ]] || {
        echo "Ungültige Auswahl."
        return 1
    }

    (( choice == 0 )) && return 0

    if (( choice < 1 || choice > ${#matches[@]} )); then
        echo "Ungültige Auswahl."
        return 1
    fi

    show_file "${matches[$((choice - 1))]}"
}

list_files() {
    load_files

    if (( ${#PW_FILES[@]} == 0 )); then
        echo "Keine Passwortdateien gefunden."
        return 0
    fi

    echo
    echo "Vorhandene Installations-Passwortdateien:"
    echo

    local i

    for i in "${!PW_FILES[@]}"; do
        printf ' %2d) %s\n' \
            "$((i + 1))" \
            "$(file_label "${PW_FILES[$i]}")"
    done
}

MODE="${1:-}"

case "$MODE" in
    latest)
        show_latest
        exit $?
        ;;
    list)
        list_files
        exit $?
        ;;
    search)
        search_files
        exit $?
        ;;
esac

while true; do
    clear 2>/dev/null || true

    echo "============================================================"
    echo " INSTALLATIONS-PASSWÖRTER ABRUFEN"
    echo "============================================================"
    echo
    echo "1) Letzte Passwortdatei anzeigen"
    echo "2) Passwortdatei auswählen"
    echo "3) Nach Dienst / Namen suchen"
    echo "4) Nur Passwortdateien auflisten"
    echo "0) Beenden"
    echo

    read -rp "Auswahl [1]: " choice
    choice="${choice:-1}"

    case "$choice" in
        1)
            show_latest
            read -rp "ENTER zum Fortfahren ..." _
            ;;
        2)
            choose_file
            read -rp "ENTER zum Fortfahren ..." _
            ;;
        3)
            search_files
            read -rp "ENTER zum Fortfahren ..." _
            ;;
        4)
            list_files
            read -rp "ENTER zum Fortfahren ..." _
            ;;
        0)
            exit 0
            ;;
        *)
            echo "Ungültige Auswahl."
            sleep 1
            ;;
    esac
done

__PROXMOX_PASSWORD_VIEWER__

    chmod 700 "$tool"
    chown root:root "$tool"
}

install_password_viewer_tool

# -----------------------------------------------------------------------------
# Erweiterte Komponentenauswahl
# -----------------------------------------------------------------------------

# =============================================================================
# BETRIEBSSYSTEME V61
# =============================================================================

OS_DISTRO=""
OS_MODE=""
OS_LABEL=""
OS_ID=""
OS_NAME=""
OS_CORES=""
OS_MEMORY=""
OS_DISK=""
OS_CIDR=""
OS_IP=""
OS_USER=""
OS_PASS=""
OS_ISO_FILE=""
OS_ISO_VOLUME=""
OS_WINDOWS_VIRTIO_VOLUME=""

select_operating_system() {
    local selected=""
    local mode_answer=""

    if (( TUI_AVAILABLE )); then
        selected="$(
            whiptail \
                --backtitle "$TUI_BACKTITLE" \
                --title "BETRIEBSSYSTEM" \
                --ok-button "Weiter" \
                --cancel-button "Abbrechen" \
                --menu "Welches Betriebssystem möchtest du installieren?" \
                20 88 8 \
                "win11"  "Windows 11 · UEFI + Secure Boot + TPM 2.0" \
                "win10"  "Windows 10 · Legacy / Testsystem" \
                "debian" "Debian 13 · Cloud-Image" \
                "ubuntu" "Ubuntu 24.04 LTS · Cloud-Image" \
                "mint"   "Linux Mint · ISO-Installation" \
                3>&1 1>&2 2>&3
        )" || return 1
    else
        header "BETRIEBSSYSTEM"
        echo "1) Windows 11"
        echo "2) Windows 10"
        echo "3) Debian 13"
        echo "4) Ubuntu 24.04 LTS"
        echo "5) Linux Mint"
        echo
        read -rp "Auswahl: " selected

        case "$selected" in
            1) selected="win11" ;;
            2) selected="win10" ;;
            3) selected="debian" ;;
            4) selected="ubuntu" ;;
            5) selected="mint" ;;
            *) return 1 ;;
        esac
    fi

    OS_DISTRO="$selected"

    case "$OS_DISTRO" in
        win11)
            OS_MODE="desktop"
            OS_LABEL="Windows 11"
            ;;
        win10)
            OS_MODE="desktop"
            OS_LABEL="Windows 10"

            if (( TUI_AVAILABLE )); then
                tui_msgbox \
                    "WINDOWS 10" \
                    "Windows 10 ist in V61 bewusst nur als Legacy-/Testprofil enthalten.

Für neue produktive Windows-VMs ist Windows 11 die empfohlene Auswahl."
            else
                warn "Windows 10 ist nur als Legacy-/Testprofil vorgesehen."
            fi
            ;;
        debian|ubuntu|mint)
            if (( TUI_AVAILABLE )); then
                OS_MODE="$(
                    whiptail \
                        --backtitle "$TUI_BACKTITLE" \
                        --title "LINUX PROFIL" \
                        --ok-button "Weiter" \
                        --cancel-button "Abbrechen" \
                        --menu "Wie soll Linux eingerichtet werden?" \
                        16 84 4 \
                        "desktop"  "Mit Grafik / Desktop" \
                        "headless" "Ohne Grafik / Server / Konsole" \
                        3>&1 1>&2 2>&3
                )" || return 1
            else
                read -rp "Mit Grafik? [J/n]: " mode_answer
                if [[ "${mode_answer:-J}" =~ ^[Nn]$ ]]; then
                    OS_MODE="headless"
                else
                    OS_MODE="desktop"
                fi
            fi

            case "$OS_DISTRO" in
                debian) OS_LABEL="Debian 13" ;;
                ubuntu) OS_LABEL="Ubuntu 24.04 LTS" ;;
                mint)
                    OS_LABEL="Linux Mint"

                    if [[ "$OS_MODE" == "headless" ]]; then
                        if (( TUI_AVAILABLE )); then
                            tui_msgbox \
                                "LINUX MINT · KONSOLENPROFIL" \
                                "Linux Mint ist eine Desktop-Distribution und besitzt kein offizielles Server-/Cloud-Image.

V61 kann dafür eine kleinere ISO-basierte VM anlegen. Die Installation selbst bleibt Mint-typisch grafisch; anschließend kann auf das Konsolen-Ziel umgestellt werden.

Für einen echten Headless-Server sind Debian oder Ubuntu technisch sinnvoller."
                        else
                            warn "Mint hat kein offizielles Headless-/Server-Image; für Server besser Debian/Ubuntu."
                        fi
                    fi
                    ;;
            esac
            ;;
        *)
            return 1
            ;;
    esac

    INSTALL_OS=1
    return 0
}

select_optional_operating_system_v62() {
    local answer=1

    if (( TUI_AVAILABLE )); then
        if whiptail \
            --backtitle "$TUI_BACKTITLE" \
            --title "BETRIEBSSYSTEM-VM" \
            --yes-button "Ja" \
            --no-button "Nein" \
            --yesno "Soll in diesem Installationslauf zusätzlich eine Windows- oder Linux-VM eingerichtet werden?

Die Betriebssystem-VM ist optional und gehört nicht zwingend zum Proxmox-Basis-Stack.

Wenn du Ja wählst, folgt direkt die Auswahl Windows 11 / Windows 10 / Debian / Ubuntu / Linux Mint." \
            18 86; then
            answer=0
        else
            answer=$?
        fi
    else
        if yn "Zusätzlich eine Betriebssystem-VM installieren? [j/N]" "N"; then
            answer=0
        else
            answer=1
        fi
    fi

    if (( answer == 0 )); then
        select_operating_system || {
            INSTALL_OS=0
            warn "Betriebssystem-Auswahl abgebrochen; der übrige Installationslauf wird fortgesetzt."
        }
    else
        INSTALL_OS=0
    fi
}

# -----------------------------------------------------------------------------
# V94 · Zusatzanwendungen für "KOMPLETT NEU"
# -----------------------------------------------------------------------------

reset_addon_flags_v94() {
    INSTALL_UPTIME=0
    INSTALL_VAULTWARDEN=0
    INSTALL_CADDY=0
    INSTALL_STIRLING=0
    INSTALL_NTFY=0
    INSTALL_FORGEJO=0
    INSTALL_SYNCTHING=0
    INSTALL_SPEEDTEST=0
    INSTALL_SCRUTINY=0
    INSTALL_MEALIE=0
}

reset_community_flags_v94() {
    INSTALL_PBS=0
    INSTALL_PULSE=0
    INSTALL_PVEUPS=0
    INSTALL_SEMAPHORE=0
    INSTALL_POCKETID=0
    INSTALL_PROMETHEUS=0
    INSTALL_PVE_EXPORTER=0
    INSTALL_GRAFANA=0
    INSTALL_CROWDSEC=0
    INSTALL_PANGOLIN=0
    INSTALL_NEWT=0
    INSTALL_GATUS=0
    INSTALL_HOMEPAGE=0
    INSTALL_NPM=0
    INSTALL_EMQX=0
}

select_addon_components_v94() {
    reset_addon_flags_v94

    local selected=""

    if (( TUI_AVAILABLE )); then
        selected="$(
            whiptail \
                --backtitle "$TUI_BACKTITLE" \
                --title "ZUSATZANWENDUNGEN" \
                --ok-button "Übernehmen" \
                --cancel-button "Keine Zusätze" \
                --separate-output \
                --checklist "Gewünschte Zusatzanwendungen auswählen" \
                27 94 14 \
                "1"  "Uptime Kuma" OFF \
                "2"  "Vaultwarden" OFF \
                "3"  "Caddy Reverse Proxy" OFF \
                "4"  "Stirling PDF" OFF \
                "5"  "ntfy" OFF \
                "6"  "Forgejo" OFF \
                "7"  "Syncthing" OFF \
                "8"  "Speedtest Tracker" OFF \
                "9"  "Scrutiny" OFF \
                "10" "Mealie" OFF \
                3>&1 1>&2 2>&3
        )" || return 1
    else
        header "ZUSATZANWENDUNGEN"
        echo " 1) Uptime Kuma"
        echo " 2) Vaultwarden"
        echo " 3) Caddy Reverse Proxy"
        echo " 4) Stirling PDF"
        echo " 5) ntfy"
        echo " 6) Forgejo"
        echo " 7) Syncthing"
        echo " 8) Speedtest Tracker"
        echo " 9) Scrutiny"
        echo "10) Mealie"
        echo
        read -rp "Zusatzanwendungen auswählen (z.B. 1,4,10; ENTER = keine): " selected
        [[ -n "$selected" ]] || return 1
        selected="$(tr ', ' '\n\n' <<<"$selected" | sed '/^$/d')"
    fi

    local choice=""
    while IFS= read -r choice; do
        [[ -n "$choice" ]] || continue
        case "$choice" in
            1)  INSTALL_UPTIME=1 ;;
            2)  INSTALL_VAULTWARDEN=1 ;;
            3)  INSTALL_CADDY=1 ;;
            4)  INSTALL_STIRLING=1 ;;
            5)  INSTALL_NTFY=1 ;;
            6)  INSTALL_FORGEJO=1 ;;
            7)  INSTALL_SYNCTHING=1 ;;
            8)  INSTALL_SPEEDTEST=1 ;;
            9)  INSTALL_SCRUTINY=1 ;;
            10) INSTALL_MEALIE=1 ;;
            *)
                warn "Ungültige Zusatzanwendungs-Auswahl: $choice"
                ;;
        esac
    done <<<"$selected"

    (( INSTALL_UPTIME || INSTALL_VAULTWARDEN || INSTALL_CADDY ||
       INSTALL_STIRLING || INSTALL_NTFY || INSTALL_FORGEJO ||
       INSTALL_SYNCTHING || INSTALL_SPEEDTEST || INSTALL_SCRUTINY ||
       INSTALL_MEALIE )) || return 1

    return 0
}

select_optional_complete_new_components_v94() {
    # Die Basis-Komponenten sind beim kompletten Neuaufbau bereits gesetzt.
    # Hier werden nur optionale Zusatzanwendungen und Community-Scripts ergänzt.
    reset_addon_flags_v94
    reset_community_flags_v94

    if (( TUI_AVAILABLE )); then
        if whiptail \
            --backtitle "$TUI_BACKTITLE" \
            --title "KOMPLETT NEU · ZUSATZANWENDUNGEN" \
            --yes-button "Ja, auswählen" \
            --no-button "Nein" \
            --yesno "Sollen beim kompletten Neuaufbau auch Zusatzanwendungen installiert werden?\n\nDanach kannst du Uptime Kuma, Vaultwarden, Caddy, Stirling PDF, ntfy, Forgejo, Syncthing, Speedtest Tracker, Scrutiny und Mealie einzeln auswählen." \
            18 90; then
            select_addon_components_v94 || {
                reset_addon_flags_v94
                warn "Keine Zusatzanwendung ausgewählt. Der Basis-Stack wird trotzdem installiert."
            }
        fi
    else
        if yn "Beim kompletten Neuaufbau auch Zusatzanwendungen installieren? [j/N]" "N"; then
            select_addon_components_v94 || {
                reset_addon_flags_v94
                warn "Keine Zusatzanwendung ausgewählt."
            }
        fi
    fi

    if (( TUI_AVAILABLE )); then
        if whiptail \
            --backtitle "$TUI_BACKTITLE" \
            --title "KOMPLETT NEU · COMMUNITY-/CUSTOM-SCRIPTS" \
            --yes-button "Ja, auswählen" \
            --no-button "Nein" \
            --yesno "Sollen beim kompletten Neuaufbau auch weitere Community-/Custom-Scripts installiert werden?\n\nPVE-UPS wird bei KOMPLETT NEU immer installiert. Hier wählst du zusätzlich PBS, Pulse, Semaphore, Pocket ID, Prometheus, PVE Exporter, Grafana, CrowdSec, Pangolin, Newt, Gatus, Homepage, Nginx Proxy Manager und EMQX aus." \
            21 92; then
            select_community_extensions || {
                reset_community_flags_v94
                warn "Keine Community-/Custom-Script-Erweiterung ausgewählt."
            }
        fi
    else
        if yn "Beim kompletten Neuaufbau weitere Community-/Custom-Scripts installieren? PVE-UPS ist immer dabei. [j/N]" "N"; then
            select_community_extensions || {
                reset_community_flags_v94
                warn "Keine zusätzliche Community-/Custom-Script-Erweiterung ausgewählt."
            }
        fi
    fi

    # V95: PVE-UPS gehört beim kompletten Neuaufbau fest zum Basis-Stack.
    # Eine vorherige Community-Auswahl darf diese Pflichtkomponente nicht
    # deaktivieren. Falls das Upstream-Script tatsächlich nicht erreichbar
    # ist, bricht die PVE-UPS-Verfügbarkeitsprüfung kontrolliert ab/überspringt
    # nur diese Komponente mit deutlicher Warnung.
    INSTALL_PVEUPS=1
}

reset_install_flags() {
    INSTALL_DASHBOARD=0
    INSTALL_HA=0
    INSTALL_PAPERLESS=0
    INSTALL_PIHOLE=0
    INSTALL_NETALERTX=0
    INSTALL_OS=0

    INSTALL_UPTIME=0
    INSTALL_VAULTWARDEN=0
    INSTALL_CADDY=0
    INSTALL_STIRLING=0
    INSTALL_NTFY=0
    INSTALL_FORGEJO=0
    INSTALL_SYNCTHING=0
    INSTALL_SPEEDTEST=0
    INSTALL_SCRUTINY=0
    INSTALL_MEALIE=0

    # Community-Scripts Erweiterungen
    INSTALL_PBS=0
    INSTALL_PULSE=0
    INSTALL_PVEUPS=0
    INSTALL_SEMAPHORE=0
    INSTALL_POCKETID=0
    INSTALL_PROMETHEUS=0
    INSTALL_PVE_EXPORTER=0
    INSTALL_GRAFANA=0
    INSTALL_CROWDSEC=0
    INSTALL_PANGOLIN=0
    INSTALL_NEWT=0
    INSTALL_GATUS=0
    INSTALL_HOMEPAGE=0
    INSTALL_NPM=0
    INSTALL_EMQX=0
}


# -----------------------------------------------------------------------------
# V106 · Kompakte Kategorien / empfohlene Pakete
# -----------------------------------------------------------------------------

select_apps_compact_v106() {
    local selected="" choice=""

    if (( TUI_AVAILABLE )); then
        selected="$(
            whiptail \
                --backtitle "$TUI_BACKTITLE" \
                --title "APPS & DIENSTE AUSWÄHLEN" \
                --ok-button "Weiter" \
                --cancel-button "Zurück" \
                --separate-output \
                --checklist "Leertaste = auswählen/abwählen" \
                25 88 12 \
                "1"  "Uptime Kuma" ON \
                "2"  "Vaultwarden" OFF \
                "3"  "Caddy Reverse Proxy" ON \
                "4"  "Stirling PDF" ON \
                "5"  "ntfy" OFF \
                "6"  "Forgejo" OFF \
                "7"  "Syncthing" OFF \
                "8"  "Speedtest Tracker" ON \
                "9"  "Scrutiny" ON \
                "10" "Mealie" OFF \
                3>&1 1>&2 2>&3
        )" || return 1
    else
        header "APPS & DIENSTE AUSWÄHLEN"
        echo "1 Uptime · 2 Vaultwarden · 3 Caddy · 4 Stirling · 5 ntfy"
        echo "6 Forgejo · 7 Syncthing · 8 Speedtest · 9 Scrutiny · 10 Mealie"
        read -rp "Auswahl kommasepariert [1,3,4,8,9]: " selected
        selected="${selected:-1,3,4,8,9}"
        selected="$(printf '%s' "$selected" | tr ',' '\n')"
    fi

    while IFS= read -r choice; do
        choice="${choice//[[:space:]]/}"
        [[ -n "$choice" ]] || continue
        case "$choice" in
            1)  INSTALL_UPTIME=1 ;;
            2)  INSTALL_VAULTWARDEN=1 ;;
            3)  INSTALL_CADDY=1 ;;
            4)  INSTALL_STIRLING=1 ;;
            5)  INSTALL_NTFY=1 ;;
            6)  INSTALL_FORGEJO=1 ;;
            7)  INSTALL_SYNCTHING=1 ;;
            8)  INSTALL_SPEEDTEST=1 ;;
            9)  INSTALL_SCRUTINY=1 ;;
            10) INSTALL_MEALIE=1 ;;
            *) warn "Unbekannte App-Auswahl ignoriert: $choice" ;;
        esac
    done <<<"$selected"

    (( INSTALL_UPTIME || INSTALL_VAULTWARDEN || INSTALL_CADDY || INSTALL_STIRLING ||
       INSTALL_NTFY || INSTALL_FORGEJO || INSTALL_SYNCTHING || INSTALL_SPEEDTEST ||
       INSTALL_SCRUTINY || INSTALL_MEALIE )) || return 1

    return 0
}

select_monitoring_compact_v106() {
    local selected="" choice=""

    if (( TUI_AVAILABLE )); then
        selected="$(
            whiptail \
                --backtitle "$TUI_BACKTITLE" \
                --title "MONITORING & INFRASTRUKTUR" \
                --ok-button "Weiter" \
                --cancel-button "Zurück" \
                --separate-output \
                --checklist "Leertaste = auswählen/abwählen" \
                26 94 12 \
                "1"  "Proxmox Backup Server" OFF \
                "2"  "Pulse" ON \
                "3"  "PVE-UPS" ON \
                "4"  "Prometheus" ON \
                "5"  "Prometheus PVE Exporter" ON \
                "6"  "Grafana" ON \
                "7"  "Gatus" OFF \
                "8"  "Homepage" OFF \
                "9"  "Nginx Proxy Manager" OFF \
                "10" "EMQX MQTT Broker" ON \
                3>&1 1>&2 2>&3
        )" || return 1
    else
        header "MONITORING & INFRASTRUKTUR"
        echo "1 PBS · 2 Pulse · 3 PVE-UPS · 4 Prometheus · 5 PVE Exporter"
        echo "6 Grafana · 7 Gatus · 8 Homepage · 9 NPM · 10 EMQX"
        read -rp "Auswahl kommasepariert [2,3,4,5,6,10]: " selected
        selected="${selected:-2,3,4,5,6,10}"
        selected="$(printf '%s' "$selected" | tr ',' '\n')"
    fi

    while IFS= read -r choice; do
        choice="${choice//[[:space:]]/}"
        [[ -n "$choice" ]] || continue
        case "$choice" in
            1)  INSTALL_PBS=1 ;;
            2)  INSTALL_PULSE=1 ;;
            3)  INSTALL_PVEUPS=1 ;;
            4)  INSTALL_PROMETHEUS=1 ;;
            5)  INSTALL_PVE_EXPORTER=1 ;;
            6)  INSTALL_GRAFANA=1 ;;
            7)  INSTALL_GATUS=1 ;;
            8)  INSTALL_HOMEPAGE=1 ;;
            9)  INSTALL_NPM=1 ;;
            10) INSTALL_EMQX=1 ;;
            *) warn "Unbekannte Monitoring-Auswahl ignoriert: $choice" ;;
        esac
    done <<<"$selected"

    (( INSTALL_PBS || INSTALL_PULSE || INSTALL_PVEUPS || INSTALL_PROMETHEUS ||
       INSTALL_PVE_EXPORTER || INSTALL_GRAFANA || INSTALL_GATUS || INSTALL_HOMEPAGE ||
       INSTALL_NPM || INSTALL_EMQX )) || return 1

    return 0
}

select_automation_security_compact_v106() {
    local selected="" choice=""

    if (( TUI_AVAILABLE )); then
        selected="$(
            whiptail \
                --backtitle "$TUI_BACKTITLE" \
                --title "AUTOMATION & SECURITY" \
                --ok-button "Weiter" \
                --cancel-button "Zurück" \
                --separate-output \
                --checklist "Leertaste = auswählen/abwählen" \
                20 90 8 \
                "1" "Semaphore" ON \
                "2" "Pocket ID" OFF \
                "3" "CrowdSec Add-on" OFF \
                "4" "Pangolin" OFF \
                "5" "Newt" OFF \
                3>&1 1>&2 2>&3
        )" || return 1
    else
        header "AUTOMATION & SECURITY"
        echo "1 Semaphore · 2 Pocket ID · 3 CrowdSec · 4 Pangolin · 5 Newt"
        read -rp "Auswahl kommasepariert [1]: " selected
        selected="${selected:-1}"
        selected="$(printf '%s' "$selected" | tr ',' '\n')"
    fi

    while IFS= read -r choice; do
        choice="${choice//[[:space:]]/}"
        [[ -n "$choice" ]] || continue
        case "$choice" in
            1) INSTALL_SEMAPHORE=1 ;;
            2) INSTALL_POCKETID=1 ;;
            3) INSTALL_CROWDSEC=1 ;;
            4) INSTALL_PANGOLIN=1 ;;
            5) INSTALL_NEWT=1 ;;
            *) warn "Unbekannte Automation-/Security-Auswahl ignoriert: $choice" ;;
        esac
    done <<<"$selected"

    (( INSTALL_SEMAPHORE || INSTALL_POCKETID || INSTALL_CROWDSEC || INSTALL_PANGOLIN || INSTALL_NEWT )) || return 1
    return 0
}

setup_profile_validate_v64() {
    local file="$1"

    python3 - "$file" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])

try:
    data = json.loads(
        path.read_text(
            encoding="utf-8"
        )
    )
except Exception as exc:
    print(
        f"Ungültiges JSON: {exc}",
        file=sys.stderr,
    )
    raise SystemExit(1)

if data.get("format") != "pve-modular-setup-profile":
    print(
        "Kein gültiges Proxmox-Installer-Setup-Profil.",
        file=sys.stderr,
    )
    raise SystemExit(1)

if int(data.get("version") or 0) != 1:
    print(
        "Nicht unterstützte Setup-Profil-Version.",
        file=sys.stderr,
    )
    raise SystemExit(1)

answers = data.get("answers") or {}

if not isinstance(answers, dict):
    print(
        "Profilfeld 'answers' ist ungültig.",
        file=sys.stderr,
    )
    raise SystemExit(1)

if len(answers) > 500:
    print(
        "Setup-Profil enthält zu viele Werte.",
        file=sys.stderr,
    )
    raise SystemExit(1)

for key, value in answers.items():
    if not isinstance(key, str):
        raise SystemExit(1)

    if not isinstance(value, (str, int, float, bool)):
        print(
            f"Ungültiger Wert bei: {key}",
            file=sys.stderr,
        )
        raise SystemExit(1)

print("OK")
PY
}

setup_profile_description_v64() {
    local file="$1"

    python3 - "$file" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])

try:
    data = json.loads(
        path.read_text(
            encoding="utf-8"
        )
    )
except Exception:
    print("Ungültiges Profil")
    raise SystemExit

created = str(
    data.get("created")
    or "-"
)

installer = str(
    data.get("installer_version")
    or "-"
)

selection = data.get(
    "selection"
) or {}

labels = [
    ("INSTALL_DASHBOARD", "Dashboard"),
    ("INSTALL_HA", "HA"),
    ("INSTALL_PAPERLESS", "Paperless"),
    ("INSTALL_PIHOLE", "Pi-hole"),
    ("INSTALL_NETALERTX", "NetAlertX"),
    ("INSTALL_OS", "OS"),
    ("INSTALL_PBS", "PBS"),
    ("INSTALL_PULSE", "Pulse"),
    ("INSTALL_PVEUPS", "PVE-UPS"),
    ("INSTALL_SEMAPHORE", "Semaphore"),
    ("INSTALL_POCKETID", "Pocket ID"),
    ("INSTALL_PROMETHEUS", "Prometheus"),
    ("INSTALL_PVE_EXPORTER", "PVE Exporter"),
    ("INSTALL_GRAFANA", "Grafana"),
    ("INSTALL_CROWDSEC", "CrowdSec"),
    ("INSTALL_PANGOLIN", "Pangolin"),
    ("INSTALL_NEWT", "Newt"),
    ("INSTALL_GATUS", "Gatus"),
    ("INSTALL_HOMEPAGE", "Homepage"),
    ("INSTALL_NPM", "NPM"),
    ("INSTALL_EMQX", "EMQX"),
]

selected = [
    label
    for key, label in labels
    if int(selection.get(key) or 0) == 1
]

summary = ", ".join(
    selected[:5]
)

if len(selected) > 5:
    summary += ", …"

if not summary:
    summary = "nur Werte"

print(
    f"{created} · {installer} · {summary}"
)
PY
}

setup_profile_import_file_v64() {
    local source="$1"
    local origin_label="$2"

    setup_profile_prepare_dirs_v64

    [[ -f "$source" ]] || {
        warn "Setup-Profil-Datei fehlt: $source"
        return 1
    }

    local bytes="0"
    bytes="$(
        stat -c '%s' "$source" 2>/dev/null || echo 0
    )"

    [[ "$bytes" =~ ^[0-9]+$ ]] || bytes=0

    if (( bytes <= 0 || bytes > 1048576 )); then
        warn "Setup-Profil muss zwischen 1 Byte und 1 MiB groß sein."
        return 1
    fi

    setup_profile_validate_v64 \
        "$source" \
        >/dev/null || return 1

    local stamp=""
    local target=""

    stamp="$(date +%Y-%m-%d_%H-%M-%S)"
    target="${SETUP_PROFILE_IMPORT_DIR}/${stamp}-${origin_label}.json"

    cp -- "$source" "$target"
    chmod 600 "$target"

    printf '%s\n' "$target"
}

setup_profile_download_web_v64() {
    local url="$1"

    case "$url" in
        http://*|https://*)
            ;;
        *)
            warn "Nur HTTP- oder HTTPS-Adressen sind erlaubt."
            return 1
            ;;
    esac

    local tmp=""
    tmp="$(mktemp /tmp/proxmox-setup-profile-web.XXXXXX.json)"

    if ! curl \
        -fL \
        --proto '=http,https' \
        --proto-redir '=http,https' \
        --connect-timeout 10 \
        --max-time 45 \
        --max-filesize 1048576 \
        -A "Proxmox-Modular-Installer-V64" \
        "$url" \
        -o "$tmp"
    then
        rm -f "$tmp"
        warn "Setup-Profil konnte nicht aus dem Web geladen werden."
        return 1
    fi

    local imported=""

    imported="$(
        setup_profile_import_file_v64 \
            "$tmp" \
            "web"
    )" || {
        rm -f "$tmp"
        return 1
    }

    rm -f "$tmp"

    printf '%s\n' "$imported"
}

setup_profile_apply_selection_v64() {
    local file="$1"

    reset_install_flags

    while IFS=$'\t' read -r key value; do
        case "$key" in
            INSTALL_DASHBOARD) INSTALL_DASHBOARD="$value" ;;
            INSTALL_HA) INSTALL_HA="$value" ;;
            INSTALL_PAPERLESS) INSTALL_PAPERLESS="$value" ;;
            INSTALL_PIHOLE) INSTALL_PIHOLE="$value" ;;
            INSTALL_NETALERTX) INSTALL_NETALERTX="$value" ;;
            INSTALL_OS) INSTALL_OS="$value" ;;
            INSTALL_UPTIME) INSTALL_UPTIME="$value" ;;
            INSTALL_VAULTWARDEN) INSTALL_VAULTWARDEN="$value" ;;
            INSTALL_CADDY) INSTALL_CADDY="$value" ;;
            INSTALL_STIRLING) INSTALL_STIRLING="$value" ;;
            INSTALL_NTFY) INSTALL_NTFY="$value" ;;
            INSTALL_FORGEJO) INSTALL_FORGEJO="$value" ;;
            INSTALL_SYNCTHING) INSTALL_SYNCTHING="$value" ;;
            INSTALL_SPEEDTEST) INSTALL_SPEEDTEST="$value" ;;
            INSTALL_SCRUTINY) INSTALL_SCRUTINY="$value" ;;
            INSTALL_MEALIE) INSTALL_MEALIE="$value" ;;
            INSTALL_PBS) INSTALL_PBS="$value" ;;
            INSTALL_PULSE) INSTALL_PULSE="$value" ;;
            INSTALL_PVEUPS) INSTALL_PVEUPS="$value" ;;
            INSTALL_SEMAPHORE) INSTALL_SEMAPHORE="$value" ;;
            INSTALL_POCKETID) INSTALL_POCKETID="$value" ;;
            INSTALL_PROMETHEUS) INSTALL_PROMETHEUS="$value" ;;
            INSTALL_PVE_EXPORTER) INSTALL_PVE_EXPORTER="$value" ;;
            INSTALL_GRAFANA) INSTALL_GRAFANA="$value" ;;
            INSTALL_CROWDSEC) INSTALL_CROWDSEC="$value" ;;
            INSTALL_PANGOLIN) INSTALL_PANGOLIN="$value" ;;
            INSTALL_NEWT) INSTALL_NEWT="$value" ;;
            INSTALL_GATUS) INSTALL_GATUS="$value" ;;
            INSTALL_HOMEPAGE) INSTALL_HOMEPAGE="$value" ;;
            INSTALL_NPM) INSTALL_NPM="$value" ;;
            INSTALL_EMQX) INSTALL_EMQX="$value" ;;
            OS_DISTRO)
                case "$value" in
                    win11|win10|debian|ubuntu|mint)
                        OS_DISTRO="$value"
                        ;;
                esac
                ;;
            OS_MODE)
                case "$value" in
                    desktop|headless)
                        OS_MODE="$value"
                        ;;
                esac
                ;;
        esac
    done < <(
        python3 - "$file" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(
    Path(sys.argv[1]).read_text(
        encoding="utf-8"
    )
)

selection = data.get(
    "selection"
) or {}

allowed = {
    "INSTALL_DASHBOARD",
    "INSTALL_HA",
    "INSTALL_PAPERLESS",
    "INSTALL_PIHOLE",
    "INSTALL_NETALERTX",
    "INSTALL_OS",
    "INSTALL_UPTIME",
    "INSTALL_VAULTWARDEN",
    "INSTALL_CADDY",
    "INSTALL_STIRLING",
    "INSTALL_NTFY",
    "INSTALL_FORGEJO",
    "INSTALL_SYNCTHING",
    "INSTALL_SPEEDTEST",
    "INSTALL_SCRUTINY",
    "INSTALL_MEALIE",
    "INSTALL_PBS",
    "INSTALL_PULSE",
    "INSTALL_PVEUPS",
    "INSTALL_SEMAPHORE",
    "INSTALL_POCKETID",
    "INSTALL_PROMETHEUS",
    "INSTALL_PVE_EXPORTER",
    "INSTALL_GRAFANA",
    "INSTALL_CROWDSEC",
    "INSTALL_PANGOLIN",
    "INSTALL_NEWT",
    "INSTALL_GATUS",
    "INSTALL_HOMEPAGE",
    "INSTALL_NPM",
    "INSTALL_EMQX",
    "OS_DISTRO",
    "OS_MODE",
}

for key, value in selection.items():
    if key not in allowed:
        continue

    if key.startswith("INSTALL_"):
        value = 1 if int(value or 0) == 1 else 0

    print(
        key,
        value,
        sep="\t",
    )
PY
    )

    if (( INSTALL_OS )); then
        case "$OS_DISTRO" in
            win11)
                OS_MODE="desktop"
                OS_LABEL="Windows 11"
                ;;
            win10)
                OS_MODE="desktop"
                OS_LABEL="Windows 10"
                ;;
            debian)
                OS_LABEL="Debian 13"
                ;;
            ubuntu)
                OS_LABEL="Ubuntu 24.04 LTS"
                ;;
            mint)
                OS_LABEL="Linux Mint"
                ;;
            *)
                warn "Profil enthält keine gültige Betriebssystemauswahl; OS-VM wird deaktiviert."
                INSTALL_OS=0
                ;;
        esac
    fi
}

setup_profile_load_answers_v64() {
    local file="$1"

    SETUP_PROFILE_VALUES=()

    while IFS=$'\t' read -r key_b64 value_b64; do
        local key=""
        local value=""

        key="$(
            printf '%s' "$key_b64" |
            base64 -d 2>/dev/null || true
        )"

        value="$(
            printf '%s' "$value_b64" |
            base64 -d 2>/dev/null || true
        )"

        [[ -n "$key" ]] || continue

        # Sicherheitsfilter auch beim Import.
        setup_profile_prompt_is_secret_v64 "$key" && continue

        SETUP_PROFILE_VALUES["$key"]="$value"
    done < <(
        python3 - "$file" <<'PY'
import base64
import json
import sys
from pathlib import Path

data = json.loads(
    Path(sys.argv[1]).read_text(
        encoding="utf-8"
    )
)

answers = data.get(
    "answers"
) or {}

for key, value in answers.items():
    def enc(item):
        return base64.b64encode(
            str(item).encode("utf-8")
        ).decode("ascii")

    print(
        enc(key),
        enc(value),
        sep="\t",
    )
PY
    )

    SETUP_PROFILE_ACTIVE="$file"
}

setup_profile_load_mode_v64() {
    local file="$1"
    local mode=""

    setup_profile_validate_v64 \
        "$file" \
        >/dev/null || return 1

    if (( TUI_AVAILABLE )); then
        if whiptail \
            --backtitle "$TUI_BACKTITLE" \
            --title "SETUP-PROFIL VERWENDEN" \
            --yes-button "Werte + Auswahl" \
            --no-button "Nur Werte" \
            --yesno "Profil:
$(basename "$file")

$(setup_profile_description_v64 "$file")

Werte + Auswahl:
Die damalige Komponentenauswahl wird ebenfalls übernommen.

Nur Werte:
IDs, IPs, CPU/RAM/Disk usw. werden als alte Vorgaben geladen. Danach wählst du im Hauptmenü selbst, was installiert werden soll.

Passwörter, Tokens und Sicherheitscodes werden nie aus Setup-Profilen geladen." \
            23 94
        then
            mode="selection"
        else
            mode="values"
        fi
    else
        echo
        setup_profile_description_v64 "$file"
        echo
        if yn "Komponentenauswahl ebenfalls übernehmen? [J/n]" "J"; then
            mode="selection"
        else
            mode="values"
        fi
    fi

    setup_profile_load_answers_v64 \
        "$file" || return 1

    if [[ "$mode" == "selection" ]]; then
        setup_profile_apply_selection_v64 \
            "$file"

        SETUP_PROFILE_SELECTION_READY=1

        tui_msgbox \
            "SETUP-PROFIL GELADEN" \
            "Alte Werte und damalige Komponentenauswahl wurden geladen.

Alle normalen Eingabemasken bleiben aktiv. Die alten Werte stehen dort als Vorgabe und können vor der Installation geändert werden."

        return 0
    fi

    SETUP_PROFILE_SELECTION_READY=0

    tui_msgbox \
        "SETUP-WERTE GELADEN" \
        "Die alten Setup-Werte sind jetzt als Vorgaben aktiv.

Wähle anschließend im Hauptmenü z. B.:
- KOMPLETT NEU
- BASIS-PAKET
- ALLES INSTALLIEREN
- Betriebssysteme
- einzelne Komponenten

Die alten Werte erscheinen automatisch in den jeweiligen Eingabefeldern."

    return 0
}

setup_profile_pick_saved_v64() {
    setup_profile_prepare_dirs_v64

    local files=()
    local labels=()
    local file=""
    local chosen=""
    local i=""

    if [[ -f "$SETUP_PROFILE_LAST_SUCCESS" ]]; then
        files+=(
            "$SETUP_PROFILE_LAST_SUCCESS"
        )
        labels+=(
            "Letzte erfolgreiche Installation"
        )
    fi

    if [[ -f "$SETUP_PROFILE_LAST_SETUP" ]]; then
        files+=(
            "$SETUP_PROFILE_LAST_SETUP"
        )
        labels+=(
            "Letztes ausgefülltes Setup"
        )
    fi

    while IFS= read -r file; do
        [[ -n "$file" ]] || continue

        files+=("$file")
        labels+=(
            "$(basename "$file" .json)"
        )
    done < <(
        find "$SETUP_PROFILE_HISTORY_DIR" \
            -maxdepth 1 \
            -type f \
            -name '*.json' \
            -printf '%T@\t%p\n' 2>/dev/null |
        sort -rn |
        head -n 10 |
        cut -f2-
    )

    if (( ${#files[@]} == 0 )); then
        tui_msgbox \
            "SETUP-PROFILE" \
            "Es gibt noch kein gespeichertes Setup-Profil.

V64 speichert ab dem nächsten Installationslauf automatisch unter:

${SETUP_PROFILE_ROOT}"
        return 1
    fi

    if (( TUI_AVAILABLE )); then
        local args=()

        for (( i=0; i<${#files[@]}; i++ )); do
            args+=(
                "$((i + 1))"
                "${labels[$i]} · $(setup_profile_description_v64 "${files[$i]}")"
            )
        done

        chosen="$(
            whiptail \
                --backtitle "$TUI_BACKTITLE" \
                --title "GESPEICHERTES SETUP-PROFIL" \
                --ok-button "Laden" \
                --cancel-button "Abbrechen" \
                --menu "Profil auswählen:" \
                25 104 13 \
                "${args[@]}" \
                3>&1 1>&2 2>&3
        )" || return 1
    else
        echo
        for (( i=0; i<${#files[@]}; i++ )); do
            echo "  $((i + 1))) ${labels[$i]}"
        done

        read -rp "Profilnummer: " chosen
    fi

    [[ "$chosen" =~ ^[0-9]+$ ]] || return 1
    (( chosen >= 1 && chosen <= ${#files[@]} )) || return 1

    printf '%s\n' \
        "${files[chosen-1]}"
}

setup_profile_manager_v64() {
    setup_profile_prepare_dirs_v64

    local source_mode=""
    local file=""
    local path=""
    local url=""

    if (( TUI_AVAILABLE )); then
        source_mode="$(
            whiptail \
                --backtitle "$TUI_BACKTITLE" \
                --title "SETUP-PROFIL LADEN" \
                --ok-button "Weiter" \
                --cancel-button "Abbrechen" \
                --menu "Woher soll das Setup-Profil geladen werden?" \
                21 94 7 \
                "saved" "Gespeicherte Profile aus /home/Data" \
                "file"  "Festplatten-/Dateipfad · z. B. /mnt/usb/setup.json" \
                "web"   "Web-Adresse · HTTP oder HTTPS" \
                3>&1 1>&2 2>&3
        )" || return 1
    else
        echo
        echo "Setup-Profil laden:"
        echo "  1) Gespeichert unter /home/Data"
        echo "  2) Festplatten-/Dateipfad"
        echo "  3) Web-Adresse (HTTP/HTTPS)"
        read -rp "Auswahl: " source_mode

        case "$source_mode" in
            1) source_mode="saved" ;;
            2) source_mode="file" ;;
            3) source_mode="web" ;;
            *) return 1 ;;
        esac
    fi

    case "$source_mode" in
        saved)
            file="$(
                setup_profile_pick_saved_v64
            )" || return 1
            ;;
        file)
            if (( TUI_AVAILABLE )); then
                path="$(
                    tui_input \
                        "SETUP-PROFIL · DATEIPFAD" \
                        "Vollständigen Pfad zum JSON-Profil eingeben.

Beispiele:
/mnt/usb/proxmox-setup.json
/root/backups/setup.json
/home/Data/proxmox-installer/profiles/mein-profil.json" \
                        ""
                )" || return 1
            else
                read -rp "Vollständiger Profilpfad: " path
            fi

            [[ -n "$path" ]] || return 1

            file="$(
                setup_profile_import_file_v64 \
                    "$path" \
                    "datei"
            )" || return 1
            ;;
        web)
            if (( TUI_AVAILABLE )); then
                url="$(
                    tui_input \
                        "SETUP-PROFIL · WEB" \
                        "HTTP- oder HTTPS-Adresse des JSON-Profils eingeben.

Beispiel:
https://example.de/proxmox/setup.json

Maximal 1 MiB. Das Profil wird validiert und danach lokal unter /home/Data importiert." \
                        "https://"
                )" || return 1
            else
                read -rp "HTTP/HTTPS URL: " url
            fi

            [[ -n "$url" ]] || return 1

            file="$(
                setup_profile_download_web_v64 \
                    "$url"
            )" || return 1
            ;;
        *)
            return 1
            ;;
    esac

    setup_profile_load_mode_v64 \
        "$file"
}

setup_profile_save_v64() {
    local state="${1:-setup}"
    local target=""
    local history=""

    setup_profile_prepare_dirs_v64

    case "$state" in
        setup)
            target="$SETUP_PROFILE_LAST_SETUP"
            ;;
        success)
            target="$SETUP_PROFILE_LAST_SUCCESS"
            history="${SETUP_PROFILE_HISTORY_DIR}/$(date +%Y-%m-%d_%H-%M-%S).json"
            ;;
        *)
            return 1
            ;;
    esac

    env \
        INSTALL_DASHBOARD="${INSTALL_DASHBOARD:-0}" \
        INSTALL_HA="${INSTALL_HA:-0}" \
        INSTALL_PAPERLESS="${INSTALL_PAPERLESS:-0}" \
        INSTALL_PIHOLE="${INSTALL_PIHOLE:-0}" \
        INSTALL_NETALERTX="${INSTALL_NETALERTX:-0}" \
        INSTALL_OS="${INSTALL_OS:-0}" \
        INSTALL_UPTIME="${INSTALL_UPTIME:-0}" \
        INSTALL_VAULTWARDEN="${INSTALL_VAULTWARDEN:-0}" \
        INSTALL_CADDY="${INSTALL_CADDY:-0}" \
        INSTALL_STIRLING="${INSTALL_STIRLING:-0}" \
        INSTALL_NTFY="${INSTALL_NTFY:-0}" \
        INSTALL_FORGEJO="${INSTALL_FORGEJO:-0}" \
        INSTALL_SYNCTHING="${INSTALL_SYNCTHING:-0}" \
        INSTALL_SPEEDTEST="${INSTALL_SPEEDTEST:-0}" \
        INSTALL_SCRUTINY="${INSTALL_SCRUTINY:-0}" \
        INSTALL_MEALIE="${INSTALL_MEALIE:-0}" \
        INSTALL_PBS="${INSTALL_PBS:-0}" \
        INSTALL_PULSE="${INSTALL_PULSE:-0}" \
        INSTALL_PVEUPS="${INSTALL_PVEUPS:-0}" \
        INSTALL_SEMAPHORE="${INSTALL_SEMAPHORE:-0}" \
        INSTALL_POCKETID="${INSTALL_POCKETID:-0}" \
        INSTALL_PROMETHEUS="${INSTALL_PROMETHEUS:-0}" \
        INSTALL_PVE_EXPORTER="${INSTALL_PVE_EXPORTER:-0}" \
        INSTALL_GRAFANA="${INSTALL_GRAFANA:-0}" \
        INSTALL_CROWDSEC="${INSTALL_CROWDSEC:-0}" \
        INSTALL_PANGOLIN="${INSTALL_PANGOLIN:-0}" \
        INSTALL_NEWT="${INSTALL_NEWT:-0}" \
        INSTALL_GATUS="${INSTALL_GATUS:-0}" \
        INSTALL_HOMEPAGE="${INSTALL_HOMEPAGE:-0}" \
        INSTALL_NPM="${INSTALL_NPM:-0}" \
        INSTALL_EMQX="${INSTALL_EMQX:-0}" \
        OS_DISTRO="${OS_DISTRO:-}" \
        OS_MODE="${OS_MODE:-}" \
        ACTIVE_PROFILE="${SETUP_PROFILE_ACTIVE:-}" \
        python3 - \
            "$SETUP_PROFILE_CAPTURE_FILE" \
            "$target" \
            "$history" <<'PY'
import base64
import json
import os
import sys
from datetime import datetime
from pathlib import Path

capture_file = Path(
    sys.argv[1]
)

target = Path(
    sys.argv[2]
)

history = Path(
    sys.argv[3]
) if sys.argv[3] else None

answers = {}

active = os.environ.get(
    "ACTIVE_PROFILE",
    "",
).strip()

if active:
    active_path = Path(
        active
    )

    try:
        old = json.loads(
            active_path.read_text(
                encoding="utf-8"
            )
        )

        if (
            old.get("format")
            == "pve-modular-setup-profile"
            and isinstance(
                old.get("answers"),
                dict,
            )
        ):
            answers.update(
                {
                    str(key): str(value)
                    for key, value
                    in old["answers"].items()
                }
            )
    except Exception:
        pass

if capture_file.is_file():
    for line in capture_file.read_text(
        encoding="utf-8",
        errors="replace",
    ).splitlines():
        try:
            key_b64, value_b64 = line.split(
                "\t",
                1,
            )

            key = base64.b64decode(
                key_b64
            ).decode("utf-8")

            value = base64.b64decode(
                value_b64
            ).decode("utf-8")

            answers[key] = value
        except Exception:
            continue

flags = [
    "INSTALL_DASHBOARD",
    "INSTALL_HA",
    "INSTALL_PAPERLESS",
    "INSTALL_PIHOLE",
    "INSTALL_NETALERTX",
    "INSTALL_OS",
    "INSTALL_UPTIME",
    "INSTALL_VAULTWARDEN",
    "INSTALL_CADDY",
    "INSTALL_STIRLING",
    "INSTALL_NTFY",
    "INSTALL_FORGEJO",
    "INSTALL_SYNCTHING",
    "INSTALL_SPEEDTEST",
    "INSTALL_SCRUTINY",
    "INSTALL_MEALIE",
    "INSTALL_PBS",
    "INSTALL_PULSE",
    "INSTALL_PVEUPS",
    "INSTALL_SEMAPHORE",
    "INSTALL_POCKETID",
    "INSTALL_PROMETHEUS",
    "INSTALL_PVE_EXPORTER",
    "INSTALL_GRAFANA",
    "INSTALL_CROWDSEC",
    "INSTALL_PANGOLIN",
    "INSTALL_NEWT",
    "INSTALL_GATUS",
    "INSTALL_HOMEPAGE",
    "INSTALL_NPM",
    "INSTALL_EMQX",
]

selection = {
    key: 1
    if int(
        os.environ.get(
            key,
            "0",
        )
        or 0
    ) == 1
    else 0
    for key in flags
}

os_distro = os.environ.get(
    "OS_DISTRO",
    "",
)

os_mode = os.environ.get(
    "OS_MODE",
    "",
)

if os_distro in {
    "win11",
    "win10",
    "debian",
    "ubuntu",
    "mint",
}:
    selection["OS_DISTRO"] = os_distro

if os_mode in {
    "desktop",
    "headless",
}:
    selection["OS_MODE"] = os_mode

payload = {
    "format": "pve-modular-setup-profile",
    "version": 1,
    "installer_version": "V140",
    "created": datetime.now().strftime(
        "%d.%m.%Y %H:%M:%S"
    ),
    "host": os.uname().nodename,
    "selection": selection,
    "answers": answers,
    "secrets_saved": False,
    "note": (
        "Passwörter, Tokens, Sicherheitscodes und Webhook-Secrets "
        "werden absichtlich nicht gespeichert."
    ),
}

content = json.dumps(
    payload,
    ensure_ascii=False,
    indent=2,
) + "\n"

target.parent.mkdir(
    parents=True,
    exist_ok=True,
)

tmp = target.with_suffix(
    ".tmp"
)

tmp.write_text(
    content,
    encoding="utf-8",
)

tmp.chmod(0o600)
tmp.replace(
    target
)

if history is not None:
    history.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    history.write_text(
        content,
        encoding="utf-8",
    )

    history.chmod(0o600)
PY

    chmod 600 "$target"

    if [[ -n "$history" ]]; then
        chmod 600 "$history"

        mapfile -t old_profiles < <(
            find "$SETUP_PROFILE_HISTORY_DIR" \
                -maxdepth 1 \
                -type f \
                -name '*.json' \
                -printf '%T@\t%p\n' |
            sort -rn |
            cut -f2-
        )

        if (( ${#old_profiles[@]} > 10 )); then
            local i

            for (( i=10; i<${#old_profiles[@]}; i++ )); do
                rm -f -- "${old_profiles[$i]}"
            done
        fi
    fi

    return 0
}

select_extended_components() {
    while true; do
        if (( TUI_AVAILABLE )); then
            if ! tui_extended_checklist; then
                return 1
            fi

            if (( INSTALL_OS )); then
                if ! select_operating_system; then
                    INSTALL_OS=0
                    tui_msgbox \
                        "BETRIEBSSYSTEM" \
                        "Die Betriebssystem-Auswahl wurde abgebrochen.

Die übrige Komponentenauswahl bleibt erhalten."
                fi
            fi

            (( INSTALL_DASHBOARD || INSTALL_HA || INSTALL_PAPERLESS || INSTALL_PIHOLE ||
               INSTALL_NETALERTX || INSTALL_UPTIME || INSTALL_VAULTWARDEN ||
               INSTALL_CADDY || INSTALL_STIRLING || INSTALL_NTFY || INSTALL_FORGEJO ||
               INSTALL_SYNCTHING || INSTALL_SPEEDTEST || INSTALL_SCRUTINY ||
               INSTALL_MEALIE || INSTALL_OS )) || {
                tui_msgbox \
                    "KEINE AUSWAHL" \
                    "Es wurde keine Komponente ausgewählt."
                continue
            }

            if tui_review_extended_selection; then
                break
            fi

            # "Ändern" führt zurück zur Checkliste.
            continue
        fi

        header "ALLES INSTALLIEREN - KOMPONENTEN AUSWÄHLEN"
        echo "Terminal-Fallback:"
        echo "1-5 = Basics · 6-15 = Extras · 16 = Betriebssystem-VM"
        echo "A = alle inkl. Betriebssystem · B = Basics · Z = Extras"
        echo

        local extended_selection
        read -rp "Komponenten auswählen [B]: " extended_selection
        extended_selection="${extended_selection:-B}"

        reset_install_flags

        case "${extended_selection^^}" in
            A)
                INSTALL_DASHBOARD=1
                INSTALL_HA=1
                INSTALL_PAPERLESS=1
                INSTALL_PIHOLE=1
                INSTALL_NETALERTX=1
                INSTALL_UPTIME=1
                INSTALL_VAULTWARDEN=1
                INSTALL_CADDY=1
                INSTALL_STIRLING=1
                INSTALL_NTFY=1
                INSTALL_FORGEJO=1
                INSTALL_SYNCTHING=1
                INSTALL_SPEEDTEST=1
                INSTALL_SCRUTINY=1
                INSTALL_MEALIE=1
                INSTALL_OS=1
                ;;
            B)
                INSTALL_DASHBOARD=1
                INSTALL_HA=1
                INSTALL_PAPERLESS=1
                INSTALL_PIHOLE=1
                INSTALL_NETALERTX=1
                ;;
            Z)
                INSTALL_UPTIME=1
                INSTALL_VAULTWARDEN=1
                INSTALL_CADDY=1
                INSTALL_STIRLING=1
                INSTALL_NTFY=1
                INSTALL_FORGEJO=1
                INSTALL_SYNCTHING=1
                INSTALL_SPEEDTEST=1
                INSTALL_SCRUTINY=1
                INSTALL_MEALIE=1
                ;;
            *)
                local choices choice
                IFS=', ' read -r -a choices <<<"$extended_selection"

                for choice in "${choices[@]}"; do
                    case "$choice" in
                        1) INSTALL_DASHBOARD=1 ;;
                        2) INSTALL_HA=1 ;;
                        3) INSTALL_PAPERLESS=1 ;;
                        4) INSTALL_PIHOLE=1 ;;
                        5) INSTALL_NETALERTX=1 ;;
                        6) INSTALL_UPTIME=1 ;;
                        7) INSTALL_VAULTWARDEN=1 ;;
                        8) INSTALL_CADDY=1 ;;
                        9) INSTALL_STIRLING=1 ;;
                        10) INSTALL_NTFY=1 ;;
                        11) INSTALL_FORGEJO=1 ;;
                        12) INSTALL_SYNCTHING=1 ;;
                        13) INSTALL_SPEEDTEST=1 ;;
                        14) INSTALL_SCRUTINY=1 ;;
                        15) INSTALL_MEALIE=1 ;;
                        16) INSTALL_OS=1 ;;
                        *) die "Ungültige Komponentenauswahl: $choice" ;;
                    esac
                done
                ;;
        esac

        if (( INSTALL_OS )); then
            if ! select_operating_system; then
                INSTALL_OS=0
                warn "Betriebssystem-Auswahl abgebrochen; übrige Komponenten bleiben ausgewählt."
            fi
        fi

        break
    done

    if (( INSTALL_VAULTWARDEN )); then
        warn "Vaultwarden benötigt für Web-Vault/Clients HTTPS."
    fi
}

# -----------------------------------------------------------------------------
# Community-Scripts Erweiterungen
# -----------------------------------------------------------------------------

select_community_extensions() {
    if (( TUI_AVAILABLE )); then
        while true; do
            tui_community_checklist || return 1

            (( INSTALL_PBS || INSTALL_PULSE || INSTALL_PVEUPS ||
               INSTALL_SEMAPHORE || INSTALL_POCKETID || INSTALL_PROMETHEUS ||
               INSTALL_PVE_EXPORTER || INSTALL_GRAFANA || INSTALL_CROWDSEC ||
               INSTALL_PANGOLIN || INSTALL_NEWT || INSTALL_GATUS ||
               INSTALL_HOMEPAGE || INSTALL_NPM || INSTALL_EMQX )) || {
                tui_msgbox \
                    "KEINE AUSWAHL" \
                    "Es wurde keine Community-Erweiterung ausgewählt."
                continue
            }

            local summary=""
            summary+="[$([[ "$INSTALL_PBS" -eq 1 ]] && echo X || echo ' ')] Proxmox Backup Server
"
            summary+="[$([[ "$INSTALL_PULSE" -eq 1 ]] && echo X || echo ' ')] Pulse
"
            summary+="[$([[ "$INSTALL_PVEUPS" -eq 1 ]] && echo X || echo ' ')] PVE-UPS
"
            summary+="[$([[ "$INSTALL_SEMAPHORE" -eq 1 ]] && echo X || echo ' ')] Semaphore
"
            summary+="[$([[ "$INSTALL_POCKETID" -eq 1 ]] && echo X || echo ' ')] Pocket ID
"
            summary+="[$([[ "$INSTALL_PROMETHEUS" -eq 1 ]] && echo X || echo ' ')] Prometheus
"
            summary+="[$([[ "$INSTALL_PVE_EXPORTER" -eq 1 ]] && echo X || echo ' ')] Prometheus PVE Exporter
"
            summary+="[$([[ "$INSTALL_GRAFANA" -eq 1 ]] && echo X || echo ' ')] Grafana
"
            summary+="[$([[ "$INSTALL_CROWDSEC" -eq 1 ]] && echo X || echo ' ')] CrowdSec Add-on
"
            summary+="[$([[ "$INSTALL_PANGOLIN" -eq 1 ]] && echo X || echo ' ')] Pangolin
"
            summary+="[$([[ "$INSTALL_NEWT" -eq 1 ]] && echo X || echo ' ')] Newt
"
            summary+="[$([[ "$INSTALL_GATUS" -eq 1 ]] && echo X || echo ' ')] Gatus
"
            summary+="[$([[ "$INSTALL_HOMEPAGE" -eq 1 ]] && echo X || echo ' ')] Homepage
"
            summary+="[$([[ "$INSTALL_NPM" -eq 1 ]] && echo X || echo ' ')] Nginx Proxy Manager
"
            summary+="[$([[ "$INSTALL_EMQX" -eq 1 ]] && echo X || echo ' ')] EMQX MQTT Broker
"
            summary+=$'
Mit dieser Auswahl weitermachen?'

            if whiptail \
                --backtitle "$TUI_BACKTITLE" \
                --title "AUSWAHL PRÜFEN" \
                --yes-button "Weiter" \
                --no-button "Ändern" \
                --yesno "$(printf '%b' "$summary")" \
                29 90; then
                return 0
            fi
        done
    fi

    header "COMMUNITY-SCRIPTS ERWEITERUNGEN"
    echo " 1) PBS"
    echo " 2) Pulse"
    echo " 3) PVE-UPS"
    echo " 4) Semaphore"
    echo " 5) Pocket ID"
    echo " 6) Prometheus"
    echo " 7) Prometheus PVE Exporter"
    echo " 8) Grafana"
    echo " 9) CrowdSec Add-on"
    echo "10) Pangolin"
    echo "11) Newt"
    echo "12) Gatus"
    echo "13) Homepage"
    echo "14) Nginx Proxy Manager"
    echo "15) EMQX MQTT Broker + Weboberfläche"
    echo

    local selection choices choice
    read -rp "Community-Erweiterungen auswählen [1,2,6,7,8,15]: " selection
    selection="${selection:-1,2,6,7,8,15}"

    IFS=', ' read -r -a choices <<<"$selection"

    for choice in "${choices[@]}"; do
        case "$choice" in
            1)  INSTALL_PBS=1 ;;
            2)  INSTALL_PULSE=1 ;;
            3)  INSTALL_PVEUPS=1 ;;
            4)  INSTALL_SEMAPHORE=1 ;;
            5)  INSTALL_POCKETID=1 ;;
            6)  INSTALL_PROMETHEUS=1 ;;
            7)  INSTALL_PVE_EXPORTER=1 ;;
            8)  INSTALL_GRAFANA=1 ;;
            9)  INSTALL_CROWDSEC=1 ;;
            10) INSTALL_PANGOLIN=1 ;;
            11) INSTALL_NEWT=1 ;;
            12) INSTALL_GATUS=1 ;;
            13) INSTALL_HOMEPAGE=1 ;;
            14) INSTALL_NPM=1 ;;
            15) INSTALL_EMQX=1 ;;
            *) die "Ungültige Community-Auswahl: $choice" ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Installer-Informationen
# -----------------------------------------------------------------------------

show_installer_info() {
    local info_text=""
    local network_prefix="${NETWORK_PREFIX:-192.168.178}"

    info_text+="MINDEST-RESSOURCEN\n"
    info_text+="  CPU: Standard mindestens 2 Kerne; PVE Exporter darf 1 Kern verwenden\n"
    info_text+="  RAM: mindestens 1 GB\n"
    info_text+="  Disk: absolute Untergrenze 2 GB; Docker-Dienste werden deutlich größer geplant\n"
    info_text+="  Docker: vor Installation >= 4 GB frei, vor Image-Pull >= 3 GB frei\n"
    info_text+="  Home Assistant Standard: 64 GB\n"
    info_text+="  Paperless/Ollama Standard: 64 GB\n"
    info_text+="  PBS Standard: 128 GB\n\n"

    info_text+="PERMANENTER DOWNLOAD-CACHE\n"
    info_text+="  /home/img\n"
    info_text+="  LXC-Templates, HAOS, Docker-Images, Ollama-Modelle\n"
    info_text+="  APT-Pakete/Paketlisten, Pi-hole Daten, Scrutiny Collector\n"
    info_text+="  Docker-Images werden nur gespeichert, wenn dort >= 10 GB frei sind\n"
    info_text+="  KOMPLETT NEU löscht /home/img NICHT\n\n"

    info_text+="PERSISTENTE ANWENDUNGSDATEN\n"
    info_text+="  Uptime Kuma: /home/Data/uptime-kuma\n"
    info_text+="  Setup-Profile: /home/Data/proxmox-installer\n"
    info_text+="  Zugangsdaten: jeweils eigene Datei unter /root/passwort (0600)\n"
    info_text+="  last-setup.json: zuletzt ausgefüllte Konfiguration\n"
    info_text+="  last-success.json: letzte erfolgreiche Installation\n"
    info_text+="  Historie: maximal 10 erfolgreiche Profile\n"
    info_text+="  Laden: /home/Data · beliebiger Dateipfad · HTTP/HTTPS\n"
    info_text+="  Keine Passwörter/API-Tokens/Sicherheitscodes im Setup-Profil\n"
    info_text+="  KOMPLETT NEU löscht /home/Data und /root/passwort NICHT\n\n"

    info_text+="ID-/IP-AUTOMATIK\n"
    info_text+="  ID 100 bleibt reserviert\n"
    info_text+="  automatische Vergabe startet bei 101\n"
    info_text+="  CT 101 -> ${network_prefix}.101\n\n"

    info_text+="SPEICHERPROFILE (ROOT-DISK)\n"
    info_text+="  Home Assistant 64 · Paperless/Ollama 64 · PBS 128 GB\n"
    info_text+="  Pi-hole 8 · NetAlertX 12 · Uptime 12 · Caddy 8 GB\n"
    info_text+="  Stirling 16 · Speedtest 8 · Scrutiny 12 · Mealie 8 GB\n"
    info_text+="  Vaultwarden 8 · ntfy 8 · Forgejo 12 · Syncthing 8 GB\n"
    info_text+="  Pulse 12 · PVE-UPS 8 · Semaphore 10 · Pocket ID 8 GB\n"
    info_text+="  Prometheus 24 · PVE Exporter 6 · Grafana 12 · EMQX 10 GB\n"
    info_text+="  Pangolin 16 · Newt 8 · Gatus 8 · Homepage 10 · NPM 12 GB\n"
    info_text+="  Optimal-Stack: 286 GB virtuell; Preflight verlangt +10 % = 315 GB\n\n"

    info_text+="BETRIEBSSYSTEME\n"
    info_text+="  Windows 11: ISO · UEFI/Secure Boot/TPM 2.0 · VirtIO\n"
    info_text+="  Windows 10: ISO · Legacy/Testprofil · VirtIO\n"
    info_text+="  Debian 13: Cloud-Image · Desktop oder Headless\n"
    info_text+="  Ubuntu 24.04 LTS: Cloud-Image · Desktop oder Headless\n"
    info_text+="  Linux Mint: ISO · Desktop empfohlen\n"
    info_text+="  ISO-Cache: /home/img/template/iso\n"
    info_text+="  Cloud-Images: /home/img/os\n"
    info_text+="  Cloud-Init: /home/img/snippets\n"
    info_text+="  Betriebssystem-VM ist auch in ALLES INSTALLIEREN/AUSWAHL wählbar\n"
    info_text+="  KOMPLETT NEU und Basis-Paket fragen optional nach einer OS-VM\n"
    info_text+="  O = Optimale Installation: ALLE VMs/LXC löschen, Optimal-Stack unattended installieren; nur NAS bleibt interaktiv\n"
    info_text+="  maximal eine neue Betriebssystem-VM pro Installationslauf\n\n"

    info_text+="WEB / TLS\n"
    info_text+="  verwaltete App-UIs werden soweit geeignet über HTTP 80 -> HTTPS 443 geführt\n"
    info_text+="  Proxmox bleibt nativ HTTPS 8006 · Home Assistant nativ 8123\n"
    info_text+="  PBS bleibt nativ HTTPS 8007 · NPM nutzt nativ 80/443 + Admin 81\n"
    info_text+="  Caddy bleibt als eigener Reverse-Proxy-Dienst auf seinem vorgesehenen Listener\n"
    info_text+="  Pulse/PVE-UPS/Semaphore/Pocket ID/Prometheus/PVE Exporter/Grafana/Gatus/Homepage: HTTPS 443\n"
    info_text+="  Pocket ID intern 1411 · Semaphore/Grafana intern 3000 · Prometheus 9090 · Exporter 9221\n"
    info_text+="  EMQX: MQTT 1883 · MQTTS 8883 · WS 8083 · WSS 8084 · Dashboard intern 18083\n"
    info_text+="  Newt/CrowdSec: keine normale Weboberfläche\n"
    info_text+="  Local CA: /home/Data/proxmox-installer/tls/nodezero-local-ca.crt\n"

    tui_msgbox \
        "INSTALLER · INFO" \
        "$(printf '%b' "$info_text")"
}

# -----------------------------------------------------------------------------
# Auswahl
# -----------------------------------------------------------------------------

RESET_DASHBOARD_DATA=0
RESET_DASHBOARD_APP_ONLY=0

# V101 · One-shot Optimalmodus. In diesem Modus werden alle normalen
# Konfigurationsfragen automatisch mit den definierten Standardwerten beantwortet.
# Ausschließlich die Paperless-NAS-Konfiguration bleibt interaktiv.
OPTIMAL_INSTALL=0
OPTIMAL_RESET_PENDING=0


# V107 · Jede Zugangsinformation bekommt eine eigene, root-only Datei.
# Der Zeitstempel gilt für den gesamten Installationslauf.
INSTALL_SECRET_STAMP_V107="$(date +%Y%m%d-%H%M%S)"
INSTALL_SECRET_DIR_V107="/root/passwort"
PASSWORD_FILE="${INSTALL_SECRET_DIR_V107}/install-index-${INSTALL_SECRET_STAMP_V107}.txt"

secret_slug_v107() {
    printf '%s' "$1" |
        tr '[:upper:]' '[:lower:]' |
        sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//'
}

secret_write_v107() {
    local slug="$1"
    local label="$2"
    local value="$3"
    local user="${4:-}"
    local url="${5:-}"
    local file old_umask

    [[ -n "$value" ]] || return 0

    slug="$(secret_slug_v107 "$slug")"
    [[ -n "$slug" ]] || return 0

    mkdir -p "$INSTALL_SECRET_DIR_V107"
    chmod 700 "$INSTALL_SECRET_DIR_V107"
    chown root:root "$INSTALL_SECRET_DIR_V107"

    file="${INSTALL_SECRET_DIR_V107}/${slug}-pw-${INSTALL_SECRET_STAMP_V107}.txt"
    old_umask="$(umask)"
    umask 077

    {
        echo "Komponente: ${label}"
        echo "Erstellt:   $(date '+%d.%m.%Y %H:%M:%S')"
        [[ -n "$user" ]] && echo "Benutzer:   ${user}"
        [[ -n "$url" ]] && echo "URL:        ${url}"
        echo
        echo "Secret:"
        printf '%s\n' "$value"
    } > "$file"

    chmod 600 "$file"
    chown root:root "$file"
    umask "$old_umask"
}

refresh_secret_index_v107() {
    local old_umask
    mkdir -p "$INSTALL_SECRET_DIR_V107"
    chmod 700 "$INSTALL_SECRET_DIR_V107"
    chown root:root "$INSTALL_SECRET_DIR_V107"

    old_umask="$(umask)"
    umask 077
    {
        echo "============================================================"
        echo " PROXMOX INSTALLER V140 · SECRET-INDEX"
        echo "============================================================"
        echo "Erstellt: $(date '+%d.%m.%Y %H:%M:%S')"
        echo "Host:     $(hostname)"
        echo
        echo "Jedes Passwort/Token liegt absichtlich in einer eigenen Datei:"
        find "$INSTALL_SECRET_DIR_V107" -maxdepth 1 -type f \
            -name "*-pw-${INSTALL_SECRET_STAMP_V107}.txt" \
            -printf '  %p\n' 2>/dev/null | sort
    } > "$PASSWORD_FILE"
    chmod 600 "$PASSWORD_FILE"
    chown root:root "$PASSWORD_FILE"
    umask "$old_umask"
}

persist_install_secrets_v107() {
    # Alle Variablen werden mit ${VAR:-} gelesen, damit diese Funktion auch
    # während eines teilweise abgeschlossenen Installationslaufs sicher ist.
    secret_write_v107 "dashboard-control" "Dashboard Steuer-Code" "${DASHBOARD_CODE_FOR_FILE:-}" "" "${DASHBOARD_IP:+https://${DASHBOARD_IP}/}"

    if [[ -n "${OS_PASS:-}" ]]; then
        secret_write_v107 "os-${OS_NAME:-vm}-login" "Betriebssystem ${OS_LABEL:-VM}" "$OS_PASS" "${OS_USER:-}" "${OS_IP:-}"
    fi

    secret_write_v107 "paperless-admin" "Paperless Admin" "${PAPERLESS_PASS:-}" "${PAPERLESS_USER:-admin}" "${PAPERLESS_IP:+https://${PAPERLESS_IP}/}"
    secret_write_v107 "paperless-postgresql" "Paperless PostgreSQL" "${DB_PASS:-}" "paperless" ""
    secret_write_v107 "paperless-secret-key" "Paperless Secret Key" "${SECRET_KEY:-}" "" ""

    secret_write_v107 "pihole-web-api" "Pi-hole Web/API" "${PIHOLE_PASS:-}" "" "${PIHOLE_IP:+http://${PIHOLE_IP}/admin}"
    secret_write_v107 "pihole-home-assistant-app" "Pi-hole Home Assistant App-Passwort" "${PIHOLE_APP_PASS:-}" "" ""

    secret_write_v107 "vaultwarden-admin-token" "Vaultwarden Admin Token" "${VAULTWARDEN_ADMIN_TOKEN:-}" "" "${VAULTWARDEN_IP:+https://${VAULTWARDEN_IP}/admin/}"
    secret_write_v107 "stirling-admin" "Stirling PDF Admin" "${STIRLING_ADMIN_PASS:-}" "${STIRLING_ADMIN_USER:-admin}" "${STIRLING_IP:+https://${STIRLING_IP}/}"
    secret_write_v107 "speedtest-admin" "Speedtest Tracker Admin" "${SPEEDTEST_ADMIN_PASS:-}" "${SPEEDTEST_ADMIN_EMAIL:-}" "${SPEEDTEST_IP:+https://${SPEEDTEST_IP}/}"
    secret_write_v107 "speedtest-app-key" "Speedtest Tracker APP_KEY" "${SPEEDTEST_APP_KEY:-}" "" ""
    if (( ${INSTALL_MEALIE:-0} )); then
        secret_write_v107 "mealie-default-login" "Mealie Erstlogin" "${MEALIE_DEFAULT_PASS:-}" "${MEALIE_DEFAULT_USER:-}" "${MEALIE_IP:+https://${MEALIE_IP}/}"
    fi

    secret_write_v107 "pbs-lxc-root" "Proxmox Backup Server LXC root" "${PBS_ROOT_PASS:-}" "root" "${PBS_IP:+https://${PBS_IP}:8007/}"
    secret_write_v107 "pulse-lxc-root" "Pulse LXC root" "${PULSE_ROOT_PASS:-}" "root" ""
    secret_write_v107 "pulse-admin" "Pulse Admin" "${PULSE_ADMIN_PASS:-}" "${PULSE_ADMIN_USER:-admin}" "${PULSE_IP:+https://${PULSE_IP}/}"
    secret_write_v107 "pulse-api-token" "Pulse API Token" "${PULSE_API_TOKEN:-}" "" ""
    secret_write_v107 "pve-ups-lxc-root" "PVE-UPS LXC root" "${PVEUPS_ROOT_PASS:-}" "root" "${PVEUPS_IP:+https://${PVEUPS_IP}/}"

    secret_write_v107 "semaphore-lxc-root" "Semaphore LXC root" "${SEMAPHORE_ROOT_PASS:-}" "root" ""
    secret_write_v107 "semaphore-admin" "Semaphore Admin" "${SEMAPHORE_ADMIN_PASS:-}" "admin" "${SEMAPHORE_IP:+https://${SEMAPHORE_IP}/}"
    secret_write_v107 "semaphore-cookie-hash" "Semaphore Cookie Hash" "${SEMAPHORE_COOKIE_HASH:-}" "" ""
    secret_write_v107 "semaphore-cookie-encryption" "Semaphore Cookie Encryption" "${SEMAPHORE_COOKIE_ENCRYPTION:-}" "" ""
    secret_write_v107 "semaphore-access-key-encryption" "Semaphore Access-Key Encryption" "${SEMAPHORE_ACCESS_KEY_ENCRYPTION:-}" "" ""
    secret_write_v107 "pocketid-lxc-root" "Pocket ID LXC root" "${POCKETID_ROOT_PASS:-}" "root" ""
    secret_write_v107 "pocketid-encryption-key" "Pocket ID Encryption Key" "${POCKETID_ENCRYPTION_KEY:-}" "" ""
    secret_write_v107 "prometheus-lxc-root" "Prometheus LXC root" "${PROMETHEUS_ROOT_PASS:-}" "root" ""
    secret_write_v107 "pve-exporter-lxc-root" "PVE Exporter LXC root" "${PVE_EXPORTER_ROOT_PASS:-}" "root" ""
    secret_write_v107 "pve-exporter-api-token" "PVE Exporter Proxmox API Token" "${PVE_EXPORTER_TOKEN_SECRET:-}" "${PVE_EXPORTER_TOKEN_ID:-prometheus@pve!exporter}" ""
    secret_write_v107 "grafana-lxc-root" "Grafana LXC root" "${GRAFANA_ROOT_PASS:-}" "root" ""
    secret_write_v107 "grafana-admin" "Grafana Admin" "${GRAFANA_ADMIN_PASS:-}" "admin" "${GRAFANA_IP:+https://${GRAFANA_IP}/}"
    secret_write_v107 "pangolin-lxc-root" "Pangolin LXC root" "${PANGOLIN_ROOT_PASS:-}" "root" ""
    secret_write_v107 "newt-lxc-root" "Newt LXC root" "${NEWT_ROOT_PASS:-}" "root" ""
    secret_write_v107 "newt-site-secret" "Newt Site Secret" "${NEWT_SITE_SECRET:-}" "" ""
    secret_write_v107 "gatus-lxc-root" "Gatus LXC root" "${GATUS_ROOT_PASS:-}" "root" ""
    secret_write_v107 "homepage-lxc-root" "Homepage LXC root" "${HOMEPAGE_ROOT_PASS:-}" "root" ""
    secret_write_v107 "npm-lxc-root" "Nginx Proxy Manager LXC root" "${NPM_ROOT_PASS:-}" "root" ""
    secret_write_v107 "emqx-lxc-root" "EMQX LXC root" "${EMQX_ROOT_PASS:-}" "root" ""
    secret_write_v107 "emqx-admin" "EMQX Dashboard Admin" "${EMQX_ADMIN_PASS:-}" "admin" "${EMQX_IP:+https://${EMQX_IP}/}"

    refresh_secret_index_v107
    nodezero_backup_secrets_v139
}

# V110: Noch VOR dem ersten apt-get update / Menü die Proxmox-Paketquellen
# deterministisch auf No-Subscription setzen. Dadurch kann weder eine fehlende
# Enterprise-Lizenz noch ein versehentlich aktiver pve-test-Kanal den weiteren
# Installationslauf beeinflussen.
header "PROXMOX REPOSITORIES · NO-SUBSCRIPTION"
ensure_pve_no_subscription_repositories_v109

# Nicht verwendete Ceph-Quellen anschließend komplett deaktivieren. Bei einer
# realen Ceph-Konfiguration bleiben die zuvor auf No-Subscription umgestellten
# Ceph-Quellen aktiv.
disable_unused_ceph_repositories_v97

# Subscription-Popup/Nag-Removal ebenfalls sofort beim Scriptstart aktivieren
# und updatefest über den vorhandenen DPkg-Hook halten.
ensure_no_subscription_after_zero_v72

# V116: Erst jetzt darf der Auto-Updater installiert/aktualisiert werden.
# Zu diesem Zeitpunkt sind Enterprise/PVE-Test deaktiviert, pve-no-subscription
# ist aktiv und ein apt-get update wurde bereits erfolgreich durchgeführt.
install_proxmox_auto_updater

ensure_tui

while true; do
    if ! INSTALL_SELECTION="$(tui_main_menu)"; then
        clear 2>/dev/null || true
        echo "Installer beendet."
        exit 0
    fi

    INSTALL_SELECTION="${INSTALL_SELECTION:-6}"

    if [[ "${INSTALL_SELECTION^^}" == "I" ]]; then
        show_installer_info
        continue
    fi

    if [[ "$INSTALL_SELECTION" == "0" ]]; then
        manage_guests
        continue
    fi

    if [[ "$INSTALL_SELECTION" == "8" ]]; then
        /usr/local/sbin/pihole-auth-manager
        exit 0
    fi

    if [[ "$INSTALL_SELECTION" == "10" ]]; then
        /usr/local/sbin/pihole-language
        exit 0
    fi

    if [[ "$INSTALL_SELECTION" == "11" ]]; then
        /usr/local/sbin/proxmox-auto-updater-config
        exit 0
    fi

    if [[ "$INSTALL_SELECTION" == "12" ]]; then
        /usr/local/sbin/proxmox-passwoerter
        exit 0
    fi

    if [[ "$INSTALL_SELECTION" == "15" ]]; then
        header "PVE STORAGE-SHARE-HELPER"
        echo "Starte den aktuellen offiziellen Community-Scripts Storage-Share-Helper ..."
        echo
        bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/storage-share-helper.sh)"
        exit $?
    fi

    if [[ "$INSTALL_SELECTION" == "17" ]]; then
        SETUP_PROFILE_SELECTION_READY=0

        if setup_profile_manager_v64; then
            if (( SETUP_PROFILE_SELECTION_READY )); then
                break
            fi
        fi

        continue
    fi

    if [[ "$INSTALL_SELECTION" == "18" ]]; then
        if proxmox_zero_v72; then
            echo
            ok "PROXMOX AUF NULL abgeschlossen."
            exit 0
        fi

        continue
    fi

    if [[ "$INSTALL_SELECTION" == "19" ]]; then
        openrgb_menu_v74
        continue
    fi

    reset_install_flags

    # V106 · kompakte thematische Kategorien. Die Funktionen setzen nur die
    # bekannten Installations-Flags; der gesamte bestehende Installationspfad
    # darunter bleibt unverändert.
    case "${INSTALL_SELECTION^^}" in
        APPS_REC)
            INSTALL_UPTIME=1
            INSTALL_CADDY=1
            INSTALL_STIRLING=1
            INSTALL_SPEEDTEST=1
            INSTALL_SCRUTINY=1
            break
            ;;
        APPS_ALL)
            INSTALL_UPTIME=1
            INSTALL_VAULTWARDEN=1
            INSTALL_CADDY=1
            INSTALL_STIRLING=1
            INSTALL_NTFY=1
            INSTALL_FORGEJO=1
            INSTALL_SYNCTHING=1
            INSTALL_SPEEDTEST=1
            INSTALL_SCRUTINY=1
            INSTALL_MEALIE=1
            break
            ;;
        APPS)
            if select_apps_compact_v106; then
                break
            fi
            continue
            ;;
        MON_REC)
            INSTALL_PULSE=1
            INSTALL_PVEUPS=1
            INSTALL_PROMETHEUS=1
            INSTALL_PVE_EXPORTER=1
            INSTALL_GRAFANA=1
            INSTALL_EMQX=1
            break
            ;;
        MON_ALL)
            INSTALL_PBS=1
            INSTALL_PULSE=1
            INSTALL_PVEUPS=1
            INSTALL_PROMETHEUS=1
            INSTALL_PVE_EXPORTER=1
            INSTALL_GRAFANA=1
            INSTALL_GATUS=1
            INSTALL_HOMEPAGE=1
            INSTALL_NPM=1
            INSTALL_EMQX=1
            break
            ;;
        MON)
            if select_monitoring_compact_v106; then
                break
            fi
            continue
            ;;
        AUTOSEC)
            if select_automation_security_compact_v106; then
                break
            fi
            continue
            ;;
        SEMAPHORE)
            INSTALL_SEMAPHORE=1
            break
            ;;
        REMOTE)
            INSTALL_PANGOLIN=1
            INSTALL_NEWT=1
            break
            ;;
    esac

    if [[ "${INSTALL_SELECTION^^}" == "O" ]]; then
        OPTIMAL_INSTALL=1

        # V101 · fester Optimal-Stack. Keine optionalen Betriebssystem-VMs und
        # keine nicht aufgeführten Zusatzdienste.
        INSTALL_DASHBOARD=1
        INSTALL_HA=1
        INSTALL_PAPERLESS=1
        INSTALL_PIHOLE=1
        INSTALL_NETALERTX=1

        INSTALL_UPTIME=1
        INSTALL_CADDY=1
        INSTALL_STIRLING=1
        INSTALL_SPEEDTEST=1
        INSTALL_SCRUTINY=1

        INSTALL_PULSE=1
        INSTALL_PVEUPS=1
        INSTALL_SEMAPHORE=1
        INSTALL_PROMETHEUS=1
        INSTALL_PVE_EXPORTER=1
        INSTALL_GRAFANA=1
        INSTALL_EMQX=1

        # V107: Der destruktive Reset erfolgt absichtlich erst NACH der
        # Storage-/Netzwerk-Vorprüfung. So wird kein bestehender Gast gelöscht,
        # wenn der gewählte Datenträger den Optimal-Stack nicht tragen kann.
        OPTIMAL_RESET_PENDING=1
        break
    fi

    if [[ "$INSTALL_SELECTION" == "16" ]]; then
        select_operating_system || continue
        break
    fi

    if [[ "$INSTALL_SELECTION" == "14" ]]; then
        select_community_extensions
        break
    fi

    if [[ "$INSTALL_SELECTION" == "13" ]]; then
        # V94: Basis-Stack zuerst festlegen. Vor dem destruktiven Schritt werden
        # zusätzliche Anwendungen, Community-/Custom-Scripts und optional eine
        # Betriebssystem-VM abgefragt.
        INSTALL_DASHBOARD=1
        INSTALL_HA=1
        INSTALL_PAPERLESS=1
        INSTALL_PIHOLE=1
        INSTALL_NETALERTX=1

        select_optional_complete_new_components_v94
        select_optional_operating_system_v62

        delete_all_lxc_and_managed_ha_no_confirm
        break
    fi

    if [[ "$INSTALL_SELECTION" == "7" ]]; then
        # V94: Beim kompletten Neuaufbau werden vor der Löschbestätigung alle
        # optionalen Bestandteile abgefragt. Dadurch kann der gesamte Stack in
        # einem einzigen Installationslauf geplant und anschließend aufgebaut werden.
        INSTALL_DASHBOARD=1
        INSTALL_HA=1
        INSTALL_PAPERLESS=1
        INSTALL_PIHOLE=1
        INSTALL_NETALERTX=1

        select_optional_complete_new_components_v94
        select_optional_operating_system_v62

        if delete_all_lxc_and_managed_ha; then
            break
        else
            continue
        fi
    fi

    if [[ "$INSTALL_SELECTION" == "6" ]]; then
        INSTALL_DASHBOARD=1
        INSTALL_HA=1
        INSTALL_PAPERLESS=1
        INSTALL_PIHOLE=1
        INSTALL_NETALERTX=1
        # V96: USV-Server gehört fest zum Basis-Stack.
        INSTALL_PVEUPS=1

        # Auch das Basis-Paket kann in demselben Lauf optional eine
        # Betriebssystem-VM mit einrichten.
        select_optional_operating_system_v62
        break
    fi

    if [[ "$INSTALL_SELECTION" == "9" ]]; then
        select_extended_components
        # V96: USV-Server wird bei "Alles installieren" immer ergänzt.
        INSTALL_PVEUPS=1
        break
    fi

    IFS=', ' read -r -a choices <<< "$INSTALL_SELECTION"

    for choice in "${choices[@]}"; do
        case "$choice" in
            1) INSTALL_DASHBOARD=1 ;;
            2) INSTALL_HA=1 ;;
            3) INSTALL_PAPERLESS=1 ;;
            4) INSTALL_PIHOLE=1 ;;
            5) INSTALL_NETALERTX=1 ;;
            *) die "Ungültige Auswahl: $choice" ;;
        esac
    done

    (( INSTALL_DASHBOARD || INSTALL_HA || INSTALL_PAPERLESS ||
       INSTALL_PIHOLE || INSTALL_NETALERTX )) || \
        die "Es wurde nichts ausgewählt."

    break
done

# -----------------------------------------------------------------------------
# Auswahl vor der Konfiguration bestätigen
# -----------------------------------------------------------------------------

if (( TUI_AVAILABLE && ! OPTIMAL_INSTALL )); then
    SELECTED_OVERVIEW=""

    if [[ -n "$SETUP_PROFILE_ACTIVE" ]]; then
        SELECTED_OVERVIEW+="Setup-Profil: $(basename "$SETUP_PROFILE_ACTIVE")\n\n"
    fi

    (( INSTALL_DASHBOARD )) && SELECTED_OVERVIEW+="[X] Server-Dashboard\n"
    (( INSTALL_HA )) && SELECTED_OVERVIEW+="[X] Home Assistant OS\n"
    (( INSTALL_PAPERLESS )) && SELECTED_OVERVIEW+="[X] Paperless-ngx + Ollama\n"
    (( INSTALL_PIHOLE )) && SELECTED_OVERVIEW+="[X] Pi-hole + Unbound\n"
    (( INSTALL_NETALERTX )) && SELECTED_OVERVIEW+="[X] NetAlertX\n"
    (( INSTALL_OS )) && SELECTED_OVERVIEW+="[X] ${OS_LABEL} · $([[ "$OS_MODE" == "desktop" ]] && echo "mit Grafik" || echo "ohne Grafik")\n"
    (( INSTALL_UPTIME )) && SELECTED_OVERVIEW+="[X] Uptime Kuma\n"
    (( INSTALL_VAULTWARDEN )) && SELECTED_OVERVIEW+="[X] Vaultwarden\n"
    (( INSTALL_CADDY )) && SELECTED_OVERVIEW+="[X] Caddy Reverse Proxy\n"
    (( INSTALL_STIRLING )) && SELECTED_OVERVIEW+="[X] Stirling PDF\n"
    (( INSTALL_NTFY )) && SELECTED_OVERVIEW+="[X] ntfy\n"
    (( INSTALL_FORGEJO )) && SELECTED_OVERVIEW+="[X] Forgejo\n"
    (( INSTALL_SYNCTHING )) && SELECTED_OVERVIEW+="[X] Syncthing\n"
    (( INSTALL_SPEEDTEST )) && SELECTED_OVERVIEW+="[X] Speedtest Tracker\n"
    (( INSTALL_SCRUTINY )) && SELECTED_OVERVIEW+="[X] Scrutiny\n"
    (( INSTALL_MEALIE )) && SELECTED_OVERVIEW+="[X] Mealie\n"
    (( INSTALL_PBS )) && SELECTED_OVERVIEW+="[X] Proxmox Backup Server\n"
    (( INSTALL_PULSE )) && SELECTED_OVERVIEW+="[X] Pulse\n"
    (( INSTALL_PVEUPS )) && SELECTED_OVERVIEW+="[X] PVE-UPS\n"
    (( INSTALL_SEMAPHORE )) && SELECTED_OVERVIEW+="[X] Semaphore\n"
    (( INSTALL_POCKETID )) && SELECTED_OVERVIEW+="[X] Pocket ID\n"
    (( INSTALL_PROMETHEUS )) && SELECTED_OVERVIEW+="[X] Prometheus\n"
    (( INSTALL_PVE_EXPORTER )) && SELECTED_OVERVIEW+="[X] Prometheus PVE Exporter\n"
    (( INSTALL_GRAFANA )) && SELECTED_OVERVIEW+="[X] Grafana\n"
    (( INSTALL_CROWDSEC )) && SELECTED_OVERVIEW+="[X] CrowdSec Add-on\n"
    (( INSTALL_PANGOLIN )) && SELECTED_OVERVIEW+="[X] Pangolin\n"
    (( INSTALL_NEWT )) && SELECTED_OVERVIEW+="[X] Newt\n"
    (( INSTALL_GATUS )) && SELECTED_OVERVIEW+="[X] Gatus\n"
    (( INSTALL_HOMEPAGE )) && SELECTED_OVERVIEW+="[X] Homepage\n"
    (( INSTALL_NPM )) && SELECTED_OVERVIEW+="[X] Nginx Proxy Manager\n"
    (( INSTALL_EMQX )) && SELECTED_OVERVIEW+="[X] EMQX MQTT Broker\n"

    if ! whiptail \
        --backtitle "$TUI_BACKTITLE" \
        --title "AUSWAHL PRÜFEN" \
        --yes-button "Weiter" \
        --no-button "Abbrechen" \
        --yesno "$(printf '%b\nMit dieser Auswahl zur Konfiguration weitergehen?' "$SELECTED_OVERVIEW")" \
        24 78; then
        exit 0
    fi
fi

# -----------------------------------------------------------------------------
# Dashboard-Konfiguration
# -----------------------------------------------------------------------------

DASHBOARD_IP=""
DASHBOARD_PORT=""
CONTROL_CODE=""
DASHBOARD_CODE_FOR_FILE=""

if (( INSTALL_DASHBOARD )); then
    header "DASHBOARD INSTALLIEREN / AKTUALISIEREN"

    DASHBOARD_EXISTS=0
    if [[ -f /opt/nodezero/dashboard/app.py &&
          -f /opt/nodezero/dashboard/static/index.html ]]; then
        DASHBOARD_EXISTS=1
    fi

    if (( DASHBOARD_EXISTS )) && (( ! RESET_DASHBOARD_DATA )); then
        if (( TUI_AVAILABLE )); then
            DASHBOARD_ACTION="$(
                whiptail \
                    --backtitle "$TUI_BACKTITLE" \
                    --title "DASHBOARD VORHANDEN" \
                    --ok-button "Weiter" \
                    --cancel-button "Abbrechen" \
                    --menu "Wie soll mit dem vorhandenen Dashboard verfahren werden?" \
                    18 84 6 \
                    "1" "Aktualisieren · empfohlen · Daten/Links/Code behalten" \
                    "2" "Programmdateien neu aufbauen · Daten/Links/Code behalten" \
                    "3" "KOMPLETT ZURÜCKSETZEN · Historie/Links/Code löschen" \
                    "4" "Dashboard in diesem Lauf überspringen" \
                    3>&1 1>&2 2>&3
            )" || DASHBOARD_ACTION="4"
        else
            printf "  ${BLUE}›${RESET} Auswahl ${BOLD}[1]${RESET}: "
            read -r DASHBOARD_ACTION
        fi
        DASHBOARD_ACTION="${DASHBOARD_ACTION:-1}"

        case "$DASHBOARD_ACTION" in
            1)
                echo
                ok "Dashboard wird aktualisiert; Daten bleiben erhalten."
                ;;
            2)
                RESET_DASHBOARD_APP_ONLY=1
                echo
                warn "Dashboard-Programmdateien werden neu aufgebaut."
                echo "Historie, Links und Steuer-Code bleiben erhalten."
                ;;
            3)
                echo
                echo "${RED}ACHTUNG:${RESET} Dashboard-Historie, Links und Steuer-Code werden gelöscht."
                read -rp "Zur Bestätigung exakt 'DASHBOARD RESET' eingeben: " DASH_RESET_CONFIRM

                if [[ "$DASH_RESET_CONFIRM" != "DASHBOARD RESET" ]]; then
                    warn "Dashboard-Reset abgebrochen. Es wird stattdessen normal aktualisiert."
                else
                    RESET_DASHBOARD_DATA=1
                    warn "Dashboard wird vollständig zurückgesetzt."
                fi
                ;;
            4)
                INSTALL_DASHBOARD=0
                warn "Dashboard wird übersprungen."
                ;;
            *)
                die "Ungültige Dashboard-Auswahl."
                ;;
        esac
    elif (( RESET_DASHBOARD_DATA )); then
        warn "Komplett-Neu-Modus: Dashboard wird vollständig neu installiert."
    else
        ok "Noch kein Dashboard vorhanden: vollständige Neuinstallation."
    fi
fi

if (( INSTALL_DASHBOARD )); then
    header "DASHBOARD EINSTELLUNGEN"

    HOST_IP_DEFAULT="$(
        ip -4 route get 1.1.1.1 2>/dev/null |
        awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}'
    )"
    HOST_IP_DEFAULT="${HOST_IP_DEFAULT:-192.168.178.100}"

    DASHBOARD_IP="$(get_value "IP des Proxmox-Hosts für das Dashboard" "$HOST_IP_DEFAULT")"
    DASHBOARD_PORT="80"
    echo "Dashboard HTTP-Port: 80 (fest)"

    NEED_NEW_CONTROL_CODE=0

    if (( RESET_DASHBOARD_DATA )); then
        NEED_NEW_CONTROL_CODE=1
    elif [[ -f /etc/pve-sensor-dashboard/control.hash ]]; then
        echo
        if yn "Bestehenden Steuer-Code für Neustart/Herunterfahren behalten? [J/n]" "J"; then
            NEED_NEW_CONTROL_CODE=0
        else
            NEED_NEW_CONTROL_CODE=1
        fi
    else
        NEED_NEW_CONTROL_CODE=1
    fi

    if (( NEED_NEW_CONTROL_CODE )); then
        if (( OPTIMAL_INSTALL )); then
            CONTROL_CODE="$(openssl rand -hex 8)"
            DASHBOARD_CODE_FOR_FILE="$CONTROL_CODE"
            ok "Optimalmodus: Dashboard-Steuer-Code wurde automatisch erzeugt."
        else
        while true; do
            CONTROL_CODE="$(
                tui_password                     "DASHBOARD · SICHERHEITSCODE"                     "Neuen Steuer-Code festlegen (mindestens 6 Zeichen)"
            )" || die "Eingabe abgebrochen."
            [[ ${#CONTROL_CODE} -ge 6 ]] || {
                echo "Der Code muss mindestens 6 Zeichen lang sein."
                continue
            }

            CONTROL_CODE_2="$(
                tui_password                     "DASHBOARD · SICHERHEITSCODE"                     "Steuer-Code wiederholen"
            )" || die "Eingabe abgebrochen."
            [[ "$CONTROL_CODE" == "$CONTROL_CODE_2" ]] || {
                echo "Die Eingaben stimmen nicht überein."
                continue
            }

            unset CONTROL_CODE_2
            DASHBOARD_CODE_FOR_FILE="$CONTROL_CODE"
            break
        done
        fi
    fi
fi

# -----------------------------------------------------------------------------
# Permanenter Image-Cache
# -----------------------------------------------------------------------------

IMAGE_CACHE_DIR="/home/img"
IMAGE_CACHE_STORAGE="image-cache"

HAOS_CACHE_DIR="${IMAGE_CACHE_DIR}/haos"
LXC_CACHE_DIR="${IMAGE_CACHE_DIR}/template/cache"
ISO_CACHE_DIR="${IMAGE_CACHE_DIR}/template/iso"
SNIPPET_CACHE_DIR="${IMAGE_CACHE_DIR}/snippets"
OS_CACHE_DIR="${IMAGE_CACHE_DIR}/os"
OLLAMA_CACHE_DIR="${IMAGE_CACHE_DIR}/ollama"

DOCKER_IMAGE_CACHE_DIR="${IMAGE_CACHE_DIR}/docker"
APT_CACHE_DIR="${IMAGE_CACHE_DIR}/apt"
DOWNLOAD_CACHE_DIR="/root/downloads"

HOST_APT_ARCHIVES="${APT_CACHE_DIR}/host/archives"
DOCKER_GPG_CACHE="${DOCKER_IMAGE_CACHE_DIR}/docker.asc"
PIHOLE_DOWNLOAD_CACHE="${DOWNLOAD_CACHE_DIR}/pihole"
SCRUTINY_DOWNLOAD_CACHE="${DOWNLOAD_CACHE_DIR}/scrutiny"

# -----------------------------------------------------------------------------
# Persistente Anwendungsdaten
# -----------------------------------------------------------------------------

DATA_ROOT="/home/Data"
UPTIME_DATA_DIR="${DATA_ROOT}/uptime-kuma"

prepare_persistent_data_base() {
    mkdir -p         "$DATA_ROOT"         "$UPTIME_DATA_DIR"

    chmod 755         "$DATA_ROOT"         "$UPTIME_DATA_DIR"

    chown -R 100000:100000 "$UPTIME_DATA_DIR" 2>/dev/null || true
}

prepare_image_cache_base() {
    mkdir -p \
        "$IMAGE_CACHE_DIR" \
        "$HAOS_CACHE_DIR" \
        "$ISO_CACHE_DIR" \
        "$SNIPPET_CACHE_DIR" \
        "$OS_CACHE_DIR" \
        "$LXC_CACHE_DIR" \
        "$ISO_CACHE_DIR" \
        "$SNIPPET_CACHE_DIR" \
        "$OS_CACHE_DIR" \
        "$OLLAMA_CACHE_DIR" \
        "$DOCKER_IMAGE_CACHE_DIR" \
        "$APT_CACHE_DIR" \
        "$HOST_APT_ARCHIVES/partial" \
        "$DOWNLOAD_CACHE_DIR" \
        "$PIHOLE_DOWNLOAD_CACHE" \
        "$SCRUTINY_DOWNLOAD_CACHE"

    chmod 755 \
        "$IMAGE_CACHE_DIR" \
        "$HAOS_CACHE_DIR" \
        "$LXC_CACHE_DIR" \
        "$OLLAMA_CACHE_DIR" \
        "$DOCKER_IMAGE_CACHE_DIR" \
        "$APT_CACHE_DIR" \
        "$HOST_APT_ARCHIVES" \
        "$HOST_APT_ARCHIVES/partial" \
        "$DOWNLOAD_CACHE_DIR" \
        "$PIHOLE_DOWNLOAD_CACHE" \
        "$SCRUTINY_DOWNLOAD_CACHE"

    chown -R 100000:100000 \
        "$OLLAMA_CACHE_DIR" \
        "$DOCKER_IMAGE_CACHE_DIR" 2>/dev/null || true

    mkdir -p /etc/apt/apt.conf.d

    cat > /etc/apt/apt.conf.d/90-proxmox-installer-image-cache <<EOF
Dir::Cache::archives "${HOST_APT_ARCHIVES}/";
APT::Keep-Downloaded-Packages "true";
Binary::apt::APT::Keep-Downloaded-Packages "true";
EOF
}

# V107 · /home/img liegt auf dem Host-Dateisystem. Docker-Image-Caches
# dürfen dieses Dateisystem niemals bis auf wenige GB füllen. Für den
# Optimal-Stack verlangen wir vor dem destruktiven Reset zusätzlich 15 GB
# freien Host-Speicher. Beim späteren Cache-Speichern bleiben mindestens 10 GB.
IMAGE_CACHE_SAVE_MIN_FREE_MB_V107=10240
OPTIMAL_HOST_CACHE_MIN_FREE_GB_V107=15

host_image_cache_free_mb_v107() {
    local free_kb
    free_kb="$(df -Pk "$IMAGE_CACHE_DIR" 2>/dev/null | awk 'NR==2 {print $4}')"
    [[ "$free_kb" =~ ^[0-9]+$ ]] || return 1
    printf '%s\n' $(( free_kb / 1024 ))
}

host_image_cache_preflight_v107() {
    local min_gb="${1:-10}"
    local context="${2:-Image-Cache}"
    local free_mb free_gb

    prepare_image_cache_base
    free_mb="$(host_image_cache_free_mb_v107)" || \
        die "${context}: freier Speicher unter $IMAGE_CACHE_DIR konnte nicht ermittelt werden."
    free_gb=$(( free_mb / 1024 ))

    echo
    echo "Host-Cache-Preflight · ${context}"
    echo "  Pfad:             ${IMAGE_CACHE_DIR}"
    echo "  aktuell frei:     ${free_gb} GB"
    echo "  Mindestfreiraum:  ${min_gb} GB"

    (( free_gb >= min_gb )) || die \
        "${context}: Host-Dateisystem für ${IMAGE_CACHE_DIR} hat nur ${free_gb} GB frei; mindestens ${min_gb} GB erforderlich."
}

cache_download() {
    local url="$1"
    local dest="$2"
    local label="${3:-Download}"
    local tmp="${dest}.part"

    mkdir -p "$(dirname "$dest")"

    if [[ -s "$dest" ]]; then
        echo "${label}: Cache vorhanden."
        echo "  $dest"
        echo "Prüfe auf neuere Version ..."

        rm -f "$tmp"

        if curl -fL --retry 3 --connect-timeout 15 \
            -R -z "$dest" \
            "$url" \
            -o "$tmp"; then
            if [[ -s "$tmp" ]]; then
                mv -f "$tmp" "$dest"
                echo "[OK] Cache aktualisiert."
            else
                rm -f "$tmp"
                echo "[OK] Cache bereits aktuell."
            fi
        else
            rm -f "$tmp"
            warn "${label}: Online-Prüfung fehlgeschlagen – vorhandener Cache wird benutzt."
        fi
    else
        echo "${label}: noch nicht im Cache."
        echo "Lade einmalig nach:"
        echo "  $dest"

        curl -fL --retry 3 --connect-timeout 15 \
            -R \
            "$url" \
            -o "$tmp"

        mv -f "$tmp" "$dest"
    fi

    [[ -s "$dest" ]] || die "${label}: Cache-Datei fehlt: $dest"
}

prepare_ct_cache_dirs() {
    local hostname="$1"
    local safe

    safe="$(
        printf '%s' "$hostname" |
        tr '[:upper:]' '[:lower:]' |
        sed 's/[^a-z0-9._-]/_/g'
    )"

    CT_APT_ARCHIVES="${APT_CACHE_DIR}/${safe}/archives"
    CT_APT_LISTS="${APT_CACHE_DIR}/${safe}/lists"

    mkdir -p \
        "$CT_APT_ARCHIVES/partial" \
        "$CT_APT_LISTS/partial"

    chown -R 100000:100000 \
        "${APT_CACHE_DIR}/${safe}" \
        "$DOCKER_IMAGE_CACHE_DIR"

    chmod 755 \
        "${APT_CACHE_DIR}/${safe}" \
        "$CT_APT_ARCHIVES" \
        "$CT_APT_ARCHIVES/partial" \
        "$CT_APT_LISTS" \
        "$CT_APT_LISTS/partial" \
        "$DOCKER_IMAGE_CACHE_DIR"
}

prepare_reusable_downloads() {
    prepare_image_cache_base

    cache_download \
        "https://download.docker.com/linux/debian/gpg" \
        "$DOCKER_GPG_CACHE" \
        "Docker Repository-Key"

    chmod 644 "$DOCKER_GPG_CACHE"
    chown 100000:100000 "$DOCKER_GPG_CACHE" 2>/dev/null || true
}

# Nur Docker-Komponenten benötigen den Docker-Repository-Key. Ein reines
# Dashboard/VM-Setup soll nicht unnötig von download.docker.com abhängen.
prepare_image_cache_base
prepare_persistent_data_base
if (( ${INSTALL_PAPERLESS:-0} || ${INSTALL_PIHOLE:-0} || ${INSTALL_NETALERTX:-0} ||
      ${INSTALL_UPTIME:-0} || ${INSTALL_VAULTWARDEN:-0} || ${INSTALL_CADDY:-0} ||
      ${INSTALL_STIRLING:-0} || ${INSTALL_NTFY:-0} || ${INSTALL_FORGEJO:-0} ||
      ${INSTALL_SYNCTHING:-0} || ${INSTALL_SPEEDTEST:-0} || ${INSTALL_SCRUTINY:-0} ||
      ${INSTALL_MEALIE:-0} )); then
    prepare_reusable_downloads
fi

storage_cfg_type() {
    local wanted="$1"

    awk -v wanted="$wanted" '
        $1 ~ /:$/ && $2 == wanted {
            gsub(/:$/, "", $1)
            print $1
            exit
        }
    ' /etc/pve/storage.cfg 2>/dev/null
}

storage_cfg_path() {
    local wanted="$1"

    awk -v wanted="$wanted" '
        $1 ~ /:$/ {
            inblock = ($2 == wanted)
            next
        }

        inblock && $1 == "path" {
            print $2
            exit
        }
    ' /etc/pve/storage.cfg 2>/dev/null
}

prepare_image_cache_storage() {
    prepare_image_cache_base

    local existing_type existing_path
    existing_type="$(storage_cfg_type "$IMAGE_CACHE_STORAGE")"

    if [[ -z "$existing_type" ]]; then
        echo "Lege Proxmox Image-Cache-Storage an:"
        echo "  $IMAGE_CACHE_STORAGE -> $IMAGE_CACHE_DIR"

        pvesm add dir "$IMAGE_CACHE_STORAGE" \
            --path "$IMAGE_CACHE_DIR" \
            --content vztmpl,iso,snippets
    else
        [[ "$existing_type" == "dir" ]] || \
            die "Storage '$IMAGE_CACHE_STORAGE' existiert bereits, ist aber kein Directory-Storage."

        existing_path="$(storage_cfg_path "$IMAGE_CACHE_STORAGE")"

        if [[ "$existing_path" == "/home/Images" &&
              -L /home/Images &&
              "$(readlink -f /home/Images)" == "$IMAGE_CACHE_DIR" ]]; then
            # Bestehende V138-Storage-Definition möglichst direkt auf den
            # neuen V139-Pfad umstellen. Der Legacy-Symlink hält den Cache
            # auch dann funktionsfähig, falls die Pfadänderung abgelehnt wird.
            pvesm set "$IMAGE_CACHE_STORAGE" --path "$IMAGE_CACHE_DIR" >/dev/null 2>&1 || true
            existing_path="$(storage_cfg_path "$IMAGE_CACHE_STORAGE")"
        fi

        if [[ "$existing_path" != "$IMAGE_CACHE_DIR" ]]; then
            if [[ "$existing_path" == "/home/Images" &&
                  -L /home/Images &&
                  "$(readlink -f /home/Images)" == "$IMAGE_CACHE_DIR" ]]; then
                :
            else
                die "Storage '$IMAGE_CACHE_STORAGE' zeigt auf '$existing_path' statt '$IMAGE_CACHE_DIR'."
            fi
        fi

        # Permanenter Cache für LXC-Templates, Installations-ISOs
        # und Cloud-Init-Snippets.
        pvesm set "$IMAGE_CACHE_STORAGE" --content vztmpl,iso,snippets >/dev/null
    fi

    mkdir -p         "$LXC_CACHE_DIR"         "$ISO_CACHE_DIR"         "$SNIPPET_CACHE_DIR"         "$OS_CACHE_DIR"

    chmod 755         "$LXC_CACHE_DIR"         "$ISO_CACHE_DIR"         "$SNIPPET_CACHE_DIR"         "$OS_CACHE_DIR"

    ok "Permanenter Image-Cache: $IMAGE_CACHE_DIR"
}

find_cached_debian_template() {
    local cached=""

    # Debian 13 bevorzugen.
    cached="$(
        find "$LXC_CACHE_DIR" -maxdepth 1 -type f \
            \( -name 'debian-13-standard_*amd64.tar.zst' \
               -o -name 'debian-13-standard_*amd64.tar.xz' \
               -o -name 'debian-13-standard_*amd64.tar.gz' \) \
            -printf '%f\n' 2>/dev/null |
        sort -V |
        tail -1
    )"

    # Fallback Debian 12.
    if [[ -z "$cached" ]]; then
        cached="$(
            find "$LXC_CACHE_DIR" -maxdepth 1 -type f \
                \( -name 'debian-12-standard_*amd64.tar.zst' \
                   -o -name 'debian-12-standard_*amd64.tar.xz' \
                   -o -name 'debian-12-standard_*amd64.tar.gz' \) \
                -printf '%f\n' 2>/dev/null |
            sort -V |
            tail -1
        )"
    fi

    printf '%s\n' "$cached"
}

copy_existing_template_into_cache() {
    local template="$1"
    local storage volume source

    [[ -f "$LXC_CACHE_DIR/$template" ]] && return 0

    while read -r storage; do
        [[ -n "$storage" ]] || continue
        [[ "$storage" == "$IMAGE_CACHE_STORAGE" ]] && continue

        if pvesm list "$storage" 2>/dev/null |
           awk '{print $1}' |
           grep -Fxq "${storage}:vztmpl/${template}"; then

            volume="${storage}:vztmpl/${template}"
            source="$(pvesm path "$volume" 2>/dev/null || true)"

            if [[ -f "$source" ]]; then
                echo "Vorhandenes LXC-Template gefunden:"
                echo "  $source"
                echo "Kopiere einmalig nach:"
                echo "  $LXC_CACHE_DIR/$template"

                cp --reflink=auto --sparse=always \
                    "$source" \
                    "$LXC_CACHE_DIR/$template"

                return 0
            fi
        fi
    done < <(pvesm status 2>/dev/null | awk 'NR>1 {print $1}')

    return 1
}

find_cached_haos_version() {
    local versions

    versions="$(
        {
            find "$HAOS_CACHE_DIR" -maxdepth 1 -type f \
                -name 'haos_ova-*.qcow2' -printf '%f\n' 2>/dev/null
            find "$HAOS_CACHE_DIR" -maxdepth 1 -type f \
                -name 'haos_ova-*.qcow2.xz' -printf '%f\n' 2>/dev/null
        } |
        sed -E 's/^haos_ova-(.*)\.qcow2(\.xz)?$/\1/' |
        sort -Vu
    )"

    printf '%s\n' "$versions" | tail -1
}

# -----------------------------------------------------------------------------
# V107 · Storage-Auswahl / Preflight
# -----------------------------------------------------------------------------

STORAGE_RESERVE_PERCENT_V107=10
# Fester O-Stack: HA 64 + Paperless 64 + Pi-hole 8 + NetAlertX 12 +
# Uptime 12 + Caddy 8 + Stirling 16 + Speedtest 8 + Scrutiny 12 +
# Pulse 12 + PVE-UPS 8 + Semaphore 10 + Prometheus 24 + Exporter 6 +
# Grafana 12 + EMQX 10 = 286 GB. Mit 10 % Reserve werden 315 GB verlangt.
OPTIMAL_STACK_DISK_GB_V107=$((
    64 + 64 + 8 + 12 + 12 + 8 + 16 + 8 +
    12 + 12 + 8 + 10 + 24 + 6 + 12 + 10
))

best_guest_storage_v107() {
    local st avail best="" best_avail=-1
    local -A rootdir_ok=()

    # Für den Optimal-Stack muss der Storage sowohl VM-Images als auch
    # LXC-rootdir unterstützen. Bei aktuellen Proxmox-Versionen kann pvesm
    # danach filtern. Falls das nicht möglich ist, greifen wir unten sauber
    # auf local-lvm bzw. den ersten aktiven Storage zurück.
    while read -r st _ _ _ _ avail _; do
        [[ -n "$st" && "$st" != "Name" ]] || continue
        rootdir_ok["$st"]=1
    done < <(pvesm status --content rootdir 2>/dev/null || true)

    while read -r st _ status _ _ avail _; do
        [[ -n "$st" && "$st" != "Name" ]] || continue
        [[ "$status" == "active" ]] || continue
        [[ -n "${rootdir_ok[$st]:-}" ]] || continue
        [[ "$avail" =~ ^[0-9]+$ ]] || continue

        if (( avail > best_avail )); then
            best="$st"
            best_avail="$avail"
        fi
    done < <(pvesm status --content images 2>/dev/null || true)

    if [[ -n "$best" ]]; then
        printf '%s\n' "$best"
        return 0
    fi

    if pvesm status 2>/dev/null | awk 'NR>1 && $1=="local-lvm" && $3=="active"{found=1} END{exit !found}'; then
        printf '%s\n' "local-lvm"
        return 0
    fi

    # V112: Niemals irgendeinen beliebigen aktiven Storage als Fallback nehmen.
    # Ein reines ISO/Backup-"local" würde sonst ausgewählt und erst später
    # scheitern. Ohne geeigneten Gast-Storage soll der Preflight klar abbrechen.
    return 1
}

validate_selected_storage_v107() {
    local storage="$1"
    local need_images=0 need_rootdir=0

    pvesm status 2>/dev/null |
        awk -v s="$storage" 'NR>1 && $1==s && $3=="active" {found=1} END {exit !found}' ||
        die "Storage '$storage' existiert nicht oder ist nicht aktiv."

    (( ${INSTALL_HA:-0} || ${INSTALL_OS:-0} )) && need_images=1

    if (( ${INSTALL_PAPERLESS:-0} || ${INSTALL_PIHOLE:-0} || ${INSTALL_NETALERTX:-0} ||
          ${INSTALL_UPTIME:-0} || ${INSTALL_VAULTWARDEN:-0} || ${INSTALL_CADDY:-0} ||
          ${INSTALL_STIRLING:-0} || ${INSTALL_NTFY:-0} || ${INSTALL_FORGEJO:-0} ||
          ${INSTALL_SYNCTHING:-0} || ${INSTALL_SPEEDTEST:-0} || ${INSTALL_SCRUTINY:-0} ||
          ${INSTALL_MEALIE:-0} || ${INSTALL_PBS:-0} || ${INSTALL_PULSE:-0} ||
          ${INSTALL_PVEUPS:-0} || ${INSTALL_SEMAPHORE:-0} || ${INSTALL_POCKETID:-0} ||
          ${INSTALL_PROMETHEUS:-0} || ${INSTALL_PVE_EXPORTER:-0} || ${INSTALL_GRAFANA:-0} ||
          ${INSTALL_PANGOLIN:-0} || ${INSTALL_NEWT:-0} || ${INSTALL_GATUS:-0} ||
          ${INSTALL_HOMEPAGE:-0} || ${INSTALL_NPM:-0} || ${INSTALL_EMQX:-0} )); then
        need_rootdir=1
    fi

    if (( need_images )); then
        pvesm status --content images 2>/dev/null |
            awk -v s="$storage" 'NR>1 && $1==s && $3=="active" {found=1} END {exit !found}' ||
            die "Storage '$storage' unterstützt keine VM-Images (content=images)."
    fi

    if (( need_rootdir )); then
        pvesm status --content rootdir 2>/dev/null |
            awk -v s="$storage" 'NR>1 && $1==s && $3=="active" {found=1} END {exit !found}' ||
            die "Storage '$storage' unterstützt keine LXC-rootdir-Datenträger."
    fi

    ok "Storage '$storage' ist aktiv und unterstützt die benötigten Gast-Typen."
}

storage_kib_value_v107() {
    local storage="$1"
    local field="$2"

    pvesm status 2>/dev/null |
        awk -v s="$storage" -v f="$field" '
            NR>1 && $1==s {
                if (f=="total") print $4;
                else if (f=="used") print $5;
                else if (f=="avail") print $6;
                exit
            }
        '
}

kib_to_gib_ceil_v107() {
    local kib="${1:-0}"
    [[ "$kib" =~ ^[0-9]+$ ]] || kib=0
    printf '%s\n' $(( (kib + 1048575) / 1048576 ))
}

required_with_reserve_gb_v107() {
    local requested="$1"
    printf '%s\n' $(( (requested * (100 + STORAGE_RESERVE_PERCENT_V107) + 99) / 100 ))
}

storage_capacity_preflight_v107() {
    local storage="$1"
    local requested_gb="$2"
    local context="${3:-Installation}"
    local total_kib total_gb required_gb

    total_kib="$(storage_kib_value_v107 "$storage" total)"
    [[ "$total_kib" =~ ^[0-9]+$ ]] || die "Storage '$storage': Gesamtkapazität konnte nicht ermittelt werden."

    total_gb="$(kib_to_gib_ceil_v107 "$total_kib")"
    required_gb="$(required_with_reserve_gb_v107 "$requested_gb")"

    echo
    echo "Storage-Preflight · ${context}"
    echo "  Storage:              ${storage}"
    echo "  geplante Gast-Disks:  ${requested_gb} GB"
    echo "  + Reserve:            ${STORAGE_RESERVE_PERCENT_V107}%"
    echo "  Mindestkapazität:     ${required_gb} GB"
    echo "  Storage gesamt:       ${total_gb} GB"

    (( total_gb >= required_gb )) || die \
        "Storage '$storage' ist für ${context} zu klein: benötigt mindestens ${required_gb} GB Gesamtkapazität."
}

storage_available_preflight_v107() {
    local storage="$1"
    local requested_gb="$2"
    local context="${3:-Installation}"
    local avail_kib avail_gb required_gb

    avail_kib="$(storage_kib_value_v107 "$storage" avail)"
    [[ "$avail_kib" =~ ^[0-9]+$ ]] || die "Storage '$storage': freier Speicher konnte nicht ermittelt werden."

    # Verfügbare KiB werden absichtlich ABGERUNDET, damit die Prüfung nicht
    # optimistischer als der echte Storage ist.
    avail_gb=$(( avail_kib / 1048576 ))
    required_gb="$(required_with_reserve_gb_v107 "$requested_gb")"

    echo
    echo "Storage-Freiplatzprüfung · ${context}"
    echo "  Storage:              ${storage}"
    echo "  geplant:              ${requested_gb} GB"
    echo "  inkl. ${STORAGE_RESERVE_PERCENT_V107}% Reserve: ${required_gb} GB"
    echo "  aktuell frei:         ${avail_gb} GB"

    (( avail_gb >= required_gb )) || die \
        "Storage '$storage' hat zu wenig freien physischen Speicher: ${avail_gb} GB frei, ${required_gb} GB erforderlich."
}

selected_guest_disk_sum_v107() {
    local total=0

    (( INSTALL_OS )) && total=$((total + OS_DISK))
    (( INSTALL_HA )) && total=$((total + HA_DISK))
    (( INSTALL_PAPERLESS )) && total=$((total + PL_DISK))
    (( INSTALL_PIHOLE )) && total=$((total + PH_DISK))
    (( INSTALL_NETALERTX )) && total=$((total + NETALERTX_DISK))
    (( INSTALL_UPTIME )) && total=$((total + UPTIME_DISK))
    (( INSTALL_VAULTWARDEN )) && total=$((total + VAULTWARDEN_DISK))
    (( INSTALL_CADDY )) && total=$((total + CADDY_DISK))
    (( INSTALL_STIRLING )) && total=$((total + STIRLING_DISK))
    (( INSTALL_NTFY )) && total=$((total + NTFY_DISK))
    (( INSTALL_FORGEJO )) && total=$((total + FORGEJO_DISK))
    (( INSTALL_SYNCTHING )) && total=$((total + SYNCTHING_DISK))
    (( INSTALL_SPEEDTEST )) && total=$((total + SPEEDTEST_DISK))
    (( INSTALL_SCRUTINY )) && total=$((total + SCRUTINY_DISK))
    (( INSTALL_MEALIE )) && total=$((total + MEALIE_DISK))
    (( INSTALL_PBS )) && total=$((total + PBS_DISK))
    (( INSTALL_PULSE )) && total=$((total + PULSE_DISK))
    (( INSTALL_PVEUPS )) && total=$((total + PVEUPS_DISK))
    (( INSTALL_SEMAPHORE )) && total=$((total + SEMAPHORE_DISK))
    (( INSTALL_POCKETID )) && total=$((total + POCKETID_DISK))
    (( INSTALL_PROMETHEUS )) && total=$((total + PROMETHEUS_DISK))
    (( INSTALL_PVE_EXPORTER )) && total=$((total + PVE_EXPORTER_DISK))
    (( INSTALL_GRAFANA )) && total=$((total + GRAFANA_DISK))
    (( INSTALL_PANGOLIN )) && total=$((total + PANGOLIN_DISK))
    (( INSTALL_NEWT )) && total=$((total + NEWT_DISK))
    (( INSTALL_GATUS )) && total=$((total + GATUS_DISK))
    (( INSTALL_HOMEPAGE )) && total=$((total + HOMEPAGE_DISK))
    (( INSTALL_NPM )) && total=$((total + NPM_DISK))
    (( INSTALL_EMQX )) && total=$((total + EMQX_DISK))

    printf '%s\n' "$total"
}

# -----------------------------------------------------------------------------
# V117 · Community-Scripts Status / Verfügbarkeit
# Muss VOR optimal_network_preflight_v107 definiert sein, weil Bash
# Funktionsnamen beim tatsächlichen Aufruf bereits kennen muss.
# -----------------------------------------------------------------------------

community_pve_ups_available() {
    local page=""
    local page_url="https://community-scripts.org/scripts/pve-ups"
    local script_url="https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/pve-ups.sh"

    page="$(curl -fsSL --connect-timeout 10 --max-time 20 "$page_url" 2>/dev/null || true)"

    if [[ -n "$page" ]] && grep -Eqi \
        'currently not available|being checked by the maintainers' <<<"$page"; then
        return 1
    fi

    # V95: Die Status-Webseite ist nur ein zusätzlicher Schutz.
    # Ist sie temporär nicht erreichbar, entscheidet die tatsächliche
    # Erreichbarkeit des offiziellen Community-Scripts. So wird PVE-UPS
    # bei einem Komplett-Neu-Lauf nicht nur wegen eines Website-Fehlers
    # unnötig übersprungen.
    curl -fsSL --connect-timeout 10 --max-time 20 \
        "$script_url" -o /dev/null 2>/dev/null
}

optimal_network_preflight_v107() {
    header "OPTIMALE INSTALLATION · NETZWERK-/HOST-PREFLIGHT"

    host_image_cache_preflight_v107 "$OPTIMAL_HOST_CACHE_MIN_FREE_GB_V107" "Optimal-Stack Host-Cache"

    local -a wrappers=(
        "pulse.sh"
        "pve-ups.sh"
        "semaphore.sh"
        "prometheus.sh"
        "prometheus-pve-exporter.sh"
        "grafana.sh"
        "emqx.sh"
    )
    local wrapper tmp

    for wrapper in "${wrappers[@]}"; do
        tmp="$(mktemp)"
        if ! curl -fsSL --connect-timeout 10 --max-time 25 \
            "https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/${wrapper}" \
            -o "$tmp"; then
            rm -f "$tmp"
            die "Community-Script ${wrapper} ist nicht erreichbar. Vor dem Löschen wird abgebrochen."
        fi
        if ! bash -n "$tmp"; then
            rm -f "$tmp"
            die "Community-Script ${wrapper} ist syntaktisch ungültig. Vor dem Löschen wird abgebrochen."
        fi
        rm -f "$tmp"
    done

    curl -fsSL --connect-timeout 10 --max-time 25 \
        https://download.docker.com/linux/debian/gpg \
        -o /dev/null || die "Docker-Repository ist nicht erreichbar. Vor dem Löschen wird abgebrochen."

    curl -fsSL --connect-timeout 10 --max-time 25 \
        https://www.internic.net/domain/named.root \
        -o /dev/null || die "Unbound Root-Hints sind nicht erreichbar. Vor dem Löschen wird abgebrochen."

    community_pve_ups_available || die \
        "PVE-UPS ist nicht verfügbar. Der feste Optimal-Stack wird deshalb VOR dem Löschen abgebrochen."

    ok "Netzwerk-/Community-Preflight erfolgreich: alle O-Stack-Wrapper und Pflichtquellen erreichbar."
}

# -----------------------------------------------------------------------------
# Gemeinsame Proxmox-/Netzwerk-Konfiguration nur wenn VM/LXC gewählt
# -----------------------------------------------------------------------------

NEED_GUESTS=0
(( INSTALL_HA || INSTALL_PAPERLESS || INSTALL_PIHOLE || INSTALL_NETALERTX || INSTALL_OS ||
   INSTALL_UPTIME || INSTALL_VAULTWARDEN || INSTALL_CADDY || INSTALL_STIRLING ||
   INSTALL_NTFY || INSTALL_FORGEJO || INSTALL_SYNCTHING || INSTALL_SPEEDTEST ||
   INSTALL_SCRUTINY || INSTALL_MEALIE || INSTALL_PBS || INSTALL_PULSE ||
   INSTALL_PVEUPS || INSTALL_SEMAPHORE || INSTALL_POCKETID ||
   INSTALL_PROMETHEUS || INSTALL_PVE_EXPORTER || INSTALL_GRAFANA ||
   INSTALL_PANGOLIN || INSTALL_NEWT || INSTALL_GATUS ||
   INSTALL_HOMEPAGE || INSTALL_NPM || INSTALL_EMQX )) && NEED_GUESTS=1

DISK_STORAGE=""
TEMPLATE_STORAGE=""
BRIDGE=""
GATEWAY=""
NETWORK_PREFIX="192.168.178"

if (( NEED_GUESTS )); then
    header "PROXMOX STORAGE / NETZWERK"

    apt-get update
    apt-get install -y curl jq xz-utils ca-certificates openssl

    echo
    pvesm status
    echo

    # V107: Standardmäßig den aktiven Gast-Storage mit dem meisten freien
    # Platz verwenden. Das ist besonders wichtig, wenn eine neue SSD als
    # eigener Proxmox-Storage hinzugefügt wurde.
    DISK_DEFAULT="$(best_guest_storage_v107 || true)"
    [[ -n "$DISK_DEFAULT" ]] || die "Kein aktiver Storage gefunden, der VM-Images UND LXC-rootdir unterstützt. Neue SSD zuerst in Proxmox als geeigneten Gast-Storage einrichten (z. B. LVM-Thin oder Directory mit content=images,rootdir)."

    DISK_STORAGE="$(get_value "Storage für VM/LXC-Datenträger" "$DISK_DEFAULT")"
    validate_selected_storage_v107 "$DISK_STORAGE"

    prepare_image_cache_base

    if (( INSTALL_PAPERLESS || INSTALL_PIHOLE || INSTALL_NETALERTX || INSTALL_OS ||
          INSTALL_UPTIME || INSTALL_VAULTWARDEN || INSTALL_CADDY || INSTALL_STIRLING ||
          INSTALL_NTFY || INSTALL_FORGEJO || INSTALL_SYNCTHING || INSTALL_SPEEDTEST ||
          INSTALL_SCRUTINY || INSTALL_MEALIE || INSTALL_PBS || INSTALL_PULSE ||
          INSTALL_PVEUPS || INSTALL_SEMAPHORE || INSTALL_POCKETID ||
          INSTALL_PROMETHEUS || INSTALL_PVE_EXPORTER || INSTALL_GRAFANA ||
          INSTALL_PANGOLIN || INSTALL_NEWT || INSTALL_GATUS ||
          INSTALL_HOMEPAGE || INSTALL_NPM || INSTALL_EMQX )); then

        # LXC-Templates liegen immer persistent unter /home/img.
        prepare_image_cache_storage
        TEMPLATE_STORAGE="$IMAGE_CACHE_STORAGE"

        echo
        echo "LXC-Template-Cache:"
        echo "  $LXC_CACHE_DIR"
        echo
    fi

    BRIDGE_DEFAULT="vmbr0"
    ip link show "$BRIDGE_DEFAULT" >/dev/null 2>&1 || \
        BRIDGE_DEFAULT="$(ip -br link | awk '$1~/^vmbr/{print $1;exit}')"
    [[ -n "$BRIDGE_DEFAULT" ]] || die "Keine Proxmox-Bridge gefunden."

    BRIDGE="$(get_value "Netzwerk-Bridge" "$BRIDGE_DEFAULT")"
    ip link show "$BRIDGE" >/dev/null 2>&1 || die "Bridge '$BRIDGE' existiert nicht."

    GATEWAY_DEFAULT="$(ip -4 route show default | awk '{print $3;exit}')"
    GATEWAY_DEFAULT="${GATEWAY_DEFAULT:-192.168.178.1}"
    GATEWAY="$(get_value "Gateway" "$GATEWAY_DEFAULT")"

    if [[ "$GATEWAY" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\.[0-9]+$ ]]; then
        NETWORK_PREFIX="${BASH_REMATCH[1]}"
    fi
fi

# V107: Erst Storage und Internet prüfen, DANACH destruktiv löschen. Dadurch
# bleibt ein bestehender Host unangetastet, wenn die neue SSD noch nicht als
# geeigneter Proxmox-Storage eingerichtet ist oder Internet/Community-Scripts
# nicht erreichbar sind.
if (( OPTIMAL_RESET_PENDING )); then
    [[ "$OPTIMAL_STACK_DISK_GB_V107" -eq 286 ]] || die "Interner Fehler: Optimal-Stack-Disk-Summe ist nicht 286 GB."

    storage_capacity_preflight_v107         "$DISK_STORAGE"         "$OPTIMAL_STACK_DISK_GB_V107"         "Optimal-Stack vor Guest-Reset"

    optimal_network_preflight_v107
    optimal_install_reset_v100
    OPTIMAL_RESET_PENDING=0

    # Nach dem Reset muss der Storage tatsächlich genügend freien PHYSISCHEN
    # Platz für den kompletten Stack plus 10 % Reserve besitzen.
    storage_available_preflight_v107         "$DISK_STORAGE"         "$OPTIMAL_STACK_DISK_GB_V107"         "Optimal-Stack nach Guest-Reset"
fi

# -----------------------------------------------------------------------------
# Ressourcen-Eingaben / Mindestwerte
# -----------------------------------------------------------------------------

MIN_CPU_CORES=2
MIN_RAM_MB=1024
MIN_DISK_GB=4
ABS_MIN_DISK_GB=2

# V65 · persistente lokale CA für interne HTTPS-Dienste.
LOCAL_CA_ROOT="/home/Data/proxmox-installer/tls"
LOCAL_CA_CERT="${LOCAL_CA_ROOT}/nodezero-local-ca.crt"
LOCAL_CA_KEY="${LOCAL_CA_ROOT}/nodezero-local-ca.key"

TLS_CERT_COUNTRY="DE"
TLS_CERT_STATE="Deutschland"
TLS_CERT_LOCALITY="HomeLab"
TLS_CERT_ORG="NodeZero"
TLS_CERT_OU="Proxmox"
TLS_CERT_DAYS=397

get_cpu_cores() {
    local prompt="$1"
    local default="$2"
    local minimum="${3:-$MIN_CPU_CORES}"
    local value

    while true; do
        value="$(get_value "$prompt" "$default")"

        if [[ "$value" =~ ^[0-9]+$ ]] && (( value >= minimum )); then
            printf '%s\n' "$value"
            return 0
        fi

        warn "Mindestens ${minimum} CPU-Kerne erforderlich." >&2
    done
}

ram_to_mb() {
    local raw="$1"
    local value

    raw="${raw//[[:space:]]/}"
    raw="${raw^^}"

    if [[ "$raw" =~ ^([0-9]+)(GB|G)$ ]]; then
        value="${BASH_REMATCH[1]}"
        printf '%s\n' $(( value * 1024 ))
        return 0
    fi

    if [[ "$raw" =~ ^([0-9]+)(MB|M)$ ]]; then
        value="${BASH_REMATCH[1]}"
        printf '%s\n' "$value"
        return 0
    fi

    # Eine reine Zahl wird als GB interpretiert:
    # 1 = 1 GB, 4 = 4 GB, 12 = 12 GB.
    if [[ "$raw" =~ ^[0-9]+$ ]]; then
        printf '%s\n' $(( raw * 1024 ))
        return 0
    fi

    return 1
}

get_ram_mb() {
    local prompt="$1"
    local default_gb="$2"
    local raw mb

    while true; do
        raw="$(get_value "$prompt" "$default_gb")"

        if mb="$(ram_to_mb "$raw")"; then
            if (( mb >= MIN_RAM_MB )); then
                printf '%s\n' "$mb"
                return 0
            fi
        fi

        warn "Ungültige RAM-Angabe. Mindestens 1 GB erforderlich." >&2
        echo "Beispiele: 1 | 2 | 4 | 4G | 8GB | 2048M" >&2
    done
}

get_disk_gb() {
    local prompt="$1"
    local default="$2"
    local recommended_disk="${3:-$MIN_DISK_GB}"
    local value

    [[ "$recommended_disk" =~ ^[0-9]+$ ]] || \
        die "Ungültiger Richtwert für Disk: ${recommended_disk}"

    while true; do
        value="$(get_value "$prompt" "$default")"

        value="${value//[[:space:]]/}"
        value="${value^^}"
        value="${value%GB}"
        value="${value%G}"

        if [[ "$value" =~ ^[0-9]+$ ]] && (( value >= ABS_MIN_DISK_GB )); then
            if (( value < recommended_disk )); then
                warn "Gewählt: ${value} GB. Empfohlen sind mindestens ${recommended_disk} GB; der kleinere Wert wird trotzdem übernommen." >&2
            fi

            printf '%s\n' "$value"
            return 0
        fi

        warn "Disk muss mindestens ${ABS_MIN_DISK_GB} GB groß sein." >&2
    done
}

# -----------------------------------------------------------------------------
# IP-Vorschlag aus VM-/CT-ID
# -----------------------------------------------------------------------------

suggest_ip_from_guest_id() {
    local guest_id="$1"

    # Nur gültige Hostanteile 1..254 können direkt übernommen werden.
    if [[ "$guest_id" =~ ^[0-9]+$ ]] \
       && (( guest_id >= 1 && guest_id <= 254 )); then
        printf '%s.%s/24\n' "$NETWORK_PREFIX" "$guest_id"
        return 0
    fi

    return 1
}

reject_reserved_guest_id() {
    local guest_id="$1"

    if [[ "$guest_id" == "100" ]]; then
        die "VM-/CT-ID 100 ist reserviert und wird nicht vergeben. Bitte ID 101 oder höher verwenden."
    fi
}


# -----------------------------------------------------------------------------
# Generische Einstellungen für zusätzliche Docker-LXC
# -----------------------------------------------------------------------------

configure_optional_lxc_app() {
    local prefix="$1"
    local label="$2"
    local default_cores="$3"
    local default_memory="$4"
    local default_disk="$5"
    local recommended_disk="${6:-$MIN_DISK_GB}"
    local minimum_cores="${7:-$MIN_CPU_CORES}"

    [[ "$recommended_disk" =~ ^[0-9]+$ ]] || \
        die "${label}: ungültiger Disk-Richtwert '${recommended_disk}'."

    local -n ref_id="${prefix}_ID"
    local -n ref_cidr="${prefix}_CIDR"
    local -n ref_ip="${prefix}_IP"
    local -n ref_cores="${prefix}_CORES"
    local -n ref_memory="${prefix}_MEMORY"
    local -n ref_disk="${prefix}_DISK"

    ui_section "Netzwerk & Ressourcen · ${label}"
    ui_note "ENTER übernimmt jeweils den vorgeschlagenen Wert."
    ui_note "Disk-Richtwert: mindestens ${recommended_disk} GB · kleinere Werte ab ${ABS_MIN_DISK_GB} GB möglich"
    ui_section_end

    allocate_id
    ref_id="$(get_value "CT-ID ${label}" "$ALLOCATED_ID")"
    reject_reserved_guest_id "$ref_id"
    resolve_guest_id "$ref_id" "$label"
    ref_id="$RESOLVED_ID"
    RESERVED_IDS["$ref_id"]="$label"

    local ip_default
    ip_default="$(suggest_ip_from_guest_id "$ref_id" || true)"

    if [[ -n "$ip_default" ]]; then
        ref_cidr="$(get_value "${label} IP/CIDR" "$ip_default")"
    else
        warn "CT-ID $ref_id kann nicht direkt als IPv4-Endung verwendet werden."
        ref_cidr="$(get_value "${label} IP/CIDR" "")"
        [[ -n "$ref_cidr" ]] || die "Für ${label} muss eine IP/CIDR angegeben werden."
    fi

    ref_ip="${ref_cidr%%/*}"
    ref_cores="$(get_cpu_cores "CPU-Kerne für ${label}" "$default_cores" "$minimum_cores")"
    ref_memory="$(get_ram_mb "RAM für ${label} in GB" "$default_memory")"
    ref_disk="$(
        get_disk_gb \
            "Root-Disk für ${label} in GB" \
            "$default_disk" \
            "$recommended_disk"
    )"
}


# =============================================================================
# BETRIEBSSYSTEM-VM KONFIGURATION V61
# =============================================================================

validate_vm_name_v61() {
    local value="$1"

    [[ "$value" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,62}$ ]] || \
        die "VM-Name darf nur Buchstaben, Zahlen, Punkt, Minus und Unterstrich enthalten."
}

select_iso_from_cache_v61() {
    local purpose="$1"
    local exclude_virtio="${2:-0}"
    local files=()
    local file selected=""
    local source_path=""

    mkdir -p "$ISO_CACHE_DIR"

    while IFS= read -r file; do
        [[ -n "$file" ]] || continue

        if (( exclude_virtio )) && [[ "${file,,}" == *virtio-win* ]]; then
            continue
        fi

        files+=("$file")
    done < <(
        find "$ISO_CACHE_DIR" -maxdepth 1 -type f -iname '*.iso' -printf '%f\n' 2>/dev/null |
        sort -V
    )

    if (( ${#files[@]} == 0 )); then
        if (( TUI_AVAILABLE )); then
            source_path="$(
                tui_input \
                    "$purpose" \
                    "Keine ISO in ${ISO_CACHE_DIR} gefunden.

Du kannst jetzt einen lokalen ISO-Pfad eingeben; die Datei wird in den permanenten Cache kopiert.
Leer lassen = abbrechen." \
                    ""
            )" || return 1
        else
            read -rp "Lokaler ISO-Pfad für ${purpose} (leer = abbrechen): " source_path
        fi

        [[ -n "$source_path" ]] || return 1
        [[ -f "$source_path" ]] || die "ISO '$source_path' existiert nicht."

        local basename
        basename="$(basename "$source_path")"

        cp --reflink=auto --sparse=always \
            "$source_path" \
            "$ISO_CACHE_DIR/$basename"

        files=("$basename")
    fi

    if (( ${#files[@]} == 1 )); then
        selected="${files[0]}"
    elif (( TUI_AVAILABLE )); then
        local args=()

        for file in "${files[@]}"; do
            args+=("$file" "$file")
        done

        selected="$(
            whiptail \
                --backtitle "$TUI_BACKTITLE" \
                --title "$purpose" \
                --ok-button "Auswählen" \
                --cancel-button "Abbrechen" \
                --menu "ISO aus /home/img auswählen:" \
                22 92 12 \
                "${args[@]}" \
                3>&1 1>&2 2>&3
        )" || return 1
    else
        echo
        echo "ISO-Dateien:"

        local i=1

        for file in "${files[@]}"; do
            echo "  $i) $file"
            i=$((i + 1))
        done

        read -rp "Nummer: " i
        [[ "$i" =~ ^[0-9]+$ ]] || return 1
        (( i >= 1 && i <= ${#files[@]} )) || return 1

        selected="${files[i-1]}"
    fi

    OS_ISO_FILE="$selected"
    OS_ISO_VOLUME="${IMAGE_CACHE_STORAGE}:iso/${selected}"
}

configure_operating_system_v61() {
    (( INSTALL_OS )) || return 0

    header "BETRIEBSSYSTEM · ${OS_LABEL}"

    allocate_id
    OS_ID="$(get_value "VM-ID für ${OS_LABEL}" "$ALLOCATED_ID")"
    reject_reserved_guest_id "$OS_ID"
    resolve_guest_id "$OS_ID" "$OS_LABEL"
    OS_ID="$RESOLVED_ID"
    RESERVED_IDS["$OS_ID"]="$OS_LABEL"

    local default_name=""
    local default_cores=""
    local default_ram=""
    local default_disk=""
    local disk_recommendation=""

    case "$OS_DISTRO:$OS_MODE" in
        win11:*)
            default_name="windows11-${OS_ID}"
            default_cores="4"
            default_ram="8"
            default_disk="128"
            disk_recommendation="64"
            ;;
        win10:*)
            default_name="windows10-${OS_ID}"
            default_cores="4"
            default_ram="8"
            default_disk="128"
            disk_recommendation="64"
            ;;
        debian:desktop)
            default_name="debian-desktop-${OS_ID}"
            default_cores="4"
            default_ram="4"
            default_disk="64"
            disk_recommendation="32"
            ;;
        debian:headless)
            default_name="debian-server-${OS_ID}"
            default_cores="2"
            default_ram="2"
            default_disk="32"
            disk_recommendation="16"
            ;;
        ubuntu:desktop)
            default_name="ubuntu-desktop-${OS_ID}"
            default_cores="4"
            default_ram="6"
            default_disk="64"
            disk_recommendation="32"
            ;;
        ubuntu:headless)
            default_name="ubuntu-server-${OS_ID}"
            default_cores="2"
            default_ram="2"
            default_disk="32"
            disk_recommendation="16"
            ;;
        mint:desktop)
            default_name="linuxmint-${OS_ID}"
            default_cores="4"
            default_ram="6"
            default_disk="64"
            disk_recommendation="32"
            ;;
        mint:headless)
            default_name="linuxmint-console-${OS_ID}"
            default_cores="2"
            default_ram="2"
            default_disk="32"
            disk_recommendation="16"
            ;;
        *)
            die "Unbekanntes Betriebssystemprofil: ${OS_DISTRO}:${OS_MODE}"
            ;;
    esac

    OS_NAME="$(get_value "VM-Name" "$default_name")"
    validate_vm_name_v61 "$OS_NAME"

    OS_CORES="$(get_cpu_cores "CPU-Kerne für ${OS_LABEL}" "$default_cores")"
    OS_MEMORY="$(get_ram_mb "RAM für ${OS_LABEL} in GB" "$default_ram")"
    OS_DISK="$(
        get_disk_gb \
            "System-Disk für ${OS_LABEL} in GB" \
            "$default_disk" \
            "$disk_recommendation"
    )"

    if [[ "$OS_DISTRO" == "debian" || "$OS_DISTRO" == "ubuntu" ]]; then
        local ip_default
        ip_default="$(suggest_ip_from_guest_id "$OS_ID" || true)"

        if [[ -n "$ip_default" ]]; then
            OS_CIDR="$(get_value "${OS_LABEL} IP/CIDR" "$ip_default")"
        else
            OS_CIDR="$(get_value "${OS_LABEL} IP/CIDR" "")"
        fi

        [[ -n "$OS_CIDR" ]] || die "Für ${OS_LABEL} muss eine IP/CIDR angegeben werden."

        OS_IP="${OS_CIDR%%/*}"
        OS_USER="$(get_value "Linux-Benutzer" "admin")"

        [[ "$OS_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || \
            die "Linux-Benutzername ist ungültig."

        OS_PASS="$(openssl rand -hex 8)"
    fi

    if [[ "$OS_DISTRO" == "win11" || "$OS_DISTRO" == "win10" ]]; then
        select_iso_from_cache_v61 "${OS_LABEL} ISO" 1 || \
            die "Windows-ISO fehlt. Lege sie unter ${ISO_CACHE_DIR} ab."
    elif [[ "$OS_DISTRO" == "mint" ]]; then
        select_iso_from_cache_v61 "Linux Mint ISO" 1 || \
            die "Linux-Mint-ISO fehlt. Lege sie unter ${ISO_CACHE_DIR} ab."
    fi
}

configure_operating_system_v61

# -----------------------------------------------------------------------------
# Home Assistant Einstellungen
# -----------------------------------------------------------------------------

HA_ID=""
HA_CORES=""
HA_MEMORY=""
HA_DISK=""
HA_CIDR=""
HA_IP=""
HA_DNS=""

if (( INSTALL_HA )); then
    header "HOME ASSISTANT EINSTELLUNGEN"

    allocate_id
    HA_ID="$(get_value "VM-ID Home Assistant" "$ALLOCATED_ID")"
    reject_reserved_guest_id "$HA_ID"
    resolve_guest_id "$HA_ID" "Home Assistant"
    HA_ID="$RESOLVED_ID"
    RESERVED_IDS["$HA_ID"]="Home Assistant"

    HA_IP_DEFAULT="$(suggest_ip_from_guest_id "$HA_ID" || true)"

    if [[ -n "$HA_IP_DEFAULT" ]]; then
        HA_CIDR="$(get_value "Home Assistant IP/CIDR" "$HA_IP_DEFAULT")"
    else
        warn "VM-ID $HA_ID kann nicht direkt als IPv4-Endung verwendet werden."
        HA_CIDR="$(get_value "Home Assistant IP/CIDR" "")"
        [[ -n "$HA_CIDR" ]] || die "Für Home Assistant muss eine IP/CIDR angegeben werden."
    fi
    HA_IP="${HA_CIDR%%/*}"
    HA_DNS="$(get_value "DNS-Server für Home Assistant" "$GATEWAY")"

    if ping -c 1 -W 1 "$HA_IP" >/dev/null 2>&1; then
        warn "Die gewünschte Home-Assistant-IP $HA_IP antwortet bereits auf Ping."
        yn "IP trotzdem verwenden? [j/N]" "N" || die "Andere Home-Assistant-IP wählen."
    fi

    HA_CORES="$(get_cpu_cores "CPU-Kerne für Home Assistant" "8")"
    HA_MEMORY="$(get_ram_mb "RAM für Home Assistant in GB" "16")"
    HA_DISK="$(get_disk_gb "System-Disk für Home Assistant in GB" "64" "64")"
fi

# -----------------------------------------------------------------------------
# Paperless Einstellungen
# -----------------------------------------------------------------------------

PL_ID=""
PAPERLESS_CIDR=""
PAPERLESS_IP=""
PL_CORES=""
PL_MEMORY=""
PL_DISK=""
OLLAMA_MODEL=""
OLLAMA_EMBED_MODEL=""

# V89 · optionaler externer Paperless-Datenspeicher (z. B. Synology NAS via NFS)
PAPERLESS_EXTERNAL_STORAGE=0
PAPERLESS_NAS_IP="192.168.178.20"
PAPERLESS_NAS_PATH="/volume1/Rechnungen"
PAPERLESS_NAS_MOUNT="/mnt/paperless-nas"
PAPERLESS_DATA_SUBDIR="data"
PAPERLESS_MEDIA_SUBDIR="media"
PAPERLESS_EXPORT_SUBDIR="export"
PAPERLESS_CONSUME_SUBDIR="inbox"

PAPERLESS_USER="admin"
PAPERLESS_PASS=""
DB_PASS=""
SECRET_KEY=""

if (( INSTALL_PAPERLESS )); then
    header "PAPERLESS + OLLAMA EINSTELLUNGEN"

    allocate_id
    PL_ID="$(get_value "CT-ID Paperless" "$ALLOCATED_ID")"
    reject_reserved_guest_id "$PL_ID"
    resolve_guest_id "$PL_ID" "Paperless"
    PL_ID="$RESOLVED_ID"
    RESERVED_IDS["$PL_ID"]="Paperless"

    PAPERLESS_IP_DEFAULT="$(suggest_ip_from_guest_id "$PL_ID" || true)"

    if [[ -n "$PAPERLESS_IP_DEFAULT" ]]; then
        PAPERLESS_CIDR="$(get_value "Paperless IP/CIDR" "$PAPERLESS_IP_DEFAULT")"
    else
        warn "CT-ID $PL_ID kann nicht direkt als IPv4-Endung verwendet werden."
        PAPERLESS_CIDR="$(get_value "Paperless IP/CIDR" "")"
        [[ -n "$PAPERLESS_CIDR" ]] || die "Für Paperless muss eine IP/CIDR angegeben werden."
    fi
    PAPERLESS_IP="${PAPERLESS_CIDR%%/*}"

    PL_CORES="$(get_cpu_cores "CPU-Kerne für Paperless/Ollama" "8")"
    PL_MEMORY="$(get_ram_mb "RAM für Paperless/Ollama in GB" "16")"
    PL_DISK="$(get_disk_gb "Root-Disk für Paperless in GB" "64" "64")"

    OLLAMA_MODEL="$(get_value "Ollama LLM-Modell" "qwen2.5:7b")"
    OLLAMA_EMBED_MODEL="$(get_value "Ollama Embedding-Modell" "embeddinggemma")"

    if yn_interactive "Paperless-Daten extern auf einem NAS speichern? [J/n]" "J"; then
        PAPERLESS_EXTERNAL_STORAGE=1
        PAPERLESS_NAS_IP="$(get_value_interactive "Paperless NAS · IP/Hostname" "192.168.178.20")"
        PAPERLESS_NAS_PATH="$(get_value_interactive "Paperless NAS · NFS-Pfad" "/volume1/Rechnungen")"
        PAPERLESS_NAS_MOUNT="$(get_value_interactive "Paperless NAS · lokaler Mountpunkt auf Proxmox" "/mnt/paperless-nas")"
        PAPERLESS_DATA_SUBDIR="$(get_value_interactive "Paperless NAS · Unterordner Daten" "data")"
        PAPERLESS_MEDIA_SUBDIR="$(get_value_interactive "Paperless NAS · Unterordner Media" "media")"
        PAPERLESS_EXPORT_SUBDIR="$(get_value_interactive "Paperless NAS · Unterordner Export" "export")"
        PAPERLESS_CONSUME_SUBDIR="$(get_value_interactive "Paperless NAS · Unterordner Eingang/Inbox" "inbox")"

        [[ -n "$PAPERLESS_NAS_IP" ]] || die "Paperless NAS: IP/Hostname darf nicht leer sein."
        [[ "$PAPERLESS_NAS_PATH" == /* ]] || die "Paperless NAS: NFS-Pfad muss absolut sein (z. B. /volume1/Rechnungen)."
        [[ "$PAPERLESS_NAS_MOUNT" == /* ]] || die "Paperless NAS: lokaler Mountpunkt muss absolut sein."
        [[ "$PAPERLESS_NAS_PATH" != *[[:space:]]* ]] || die "Paperless NAS: NFS-Pfad darf in dieser Version keine Leerzeichen enthalten."
        [[ "$PAPERLESS_NAS_MOUNT" != *[[:space:]]* ]] || die "Paperless NAS: lokaler Mountpunkt darf keine Leerzeichen enthalten."

        for _pl_subdir in \
            "$PAPERLESS_DATA_SUBDIR" \
            "$PAPERLESS_MEDIA_SUBDIR" \
            "$PAPERLESS_EXPORT_SUBDIR" \
            "$PAPERLESS_CONSUME_SUBDIR"
        do
            [[ -n "$_pl_subdir" ]] || die "Paperless NAS: Unterordner darf nicht leer sein."
            [[ "$_pl_subdir" != /* && "$_pl_subdir" != *".."* ]] || \
                die "Paperless NAS: Unterordner muss relativ und ohne '..' angegeben werden: $_pl_subdir"
        done
    fi

    PAPERLESS_PASS="$(openssl rand -hex 10)"
    DB_PASS="$(openssl rand -hex 24)"
    SECRET_KEY="$(openssl rand -hex 32)"
fi

# -----------------------------------------------------------------------------
# Pi-hole Einstellungen
# -----------------------------------------------------------------------------

PH_ID=""
PIHOLE_CIDR=""
PIHOLE_IP=""
PIHOLE_PASS=""
PIHOLE_APP_PASS=""
PIHOLE_LANG="DE"
PH_CORES=""
PH_MEMORY=""
PH_DISK=""

if (( INSTALL_PIHOLE )); then
    header "PI-HOLE + UNBOUND EINSTELLUNGEN"

    allocate_id
    PH_ID="$(get_value "CT-ID Pi-hole" "$ALLOCATED_ID")"
    reject_reserved_guest_id "$PH_ID"
    resolve_guest_id "$PH_ID" "Pi-hole"
    PH_ID="$RESOLVED_ID"
    RESERVED_IDS["$PH_ID"]="Pi-hole"

    PIHOLE_IP_DEFAULT="$(suggest_ip_from_guest_id "$PH_ID" || true)"

    if [[ -n "$PIHOLE_IP_DEFAULT" ]]; then
        PIHOLE_CIDR="$(get_value "Pi-hole IP/CIDR" "$PIHOLE_IP_DEFAULT")"
    else
        warn "CT-ID $PH_ID kann nicht direkt als IPv4-Endung verwendet werden."
        PIHOLE_CIDR="$(get_value "Pi-hole IP/CIDR" "")"
        [[ -n "$PIHOLE_CIDR" ]] || die "Für Pi-hole muss eine IP/CIDR angegeben werden."
    fi
    PIHOLE_IP="${PIHOLE_CIDR%%/*}"

    PH_CORES="$(get_cpu_cores "CPU-Kerne für Pi-hole" "4")"
    PH_MEMORY="$(get_ram_mb "RAM für Pi-hole in GB" "4")"
    PH_DISK="$(get_disk_gb "Root-Disk für Pi-hole in GB" "8" "8")"

    echo
    echo "Pi-hole Weboberfläche:"
    echo "  EN = englisches Pi-hole Original"
    echo "  DE = deutsche Community-Übersetzung pimanDE/translate2german"
    echo "       (Repository-Stand derzeit für Pi-hole Web v6.6)"
    echo

    while true; do
        PIHOLE_LANG="$(
            get_value \
                "Sprache für Pi-hole [EN/DE]" \
                "DE"
        )"

        PIHOLE_LANG="${PIHOLE_LANG^^}"

        case "$PIHOLE_LANG" in
            EN|DE) break ;;
            *) warn "Bitte EN oder DE eingeben." ;;
        esac
    done

    # V83: Pi-hole wird absichtlich MIT Web/API-Passwort installiert.
    # Home Assistant Pi-hole v6 benötigt eine authentifizierbare API-Session.
    # Zusätzlich wird nach dem Start ein eigenes App-Passwort für HA erzeugt.
    PIHOLE_PASS="PiHole"
    PIHOLE_APP_PASS=""
fi

# -----------------------------------------------------------------------------
# NetAlertX Einstellungen
# -----------------------------------------------------------------------------

NAX_ID=""
NETALERTX_CIDR=""
NETALERTX_IP=""
NETALERTX_SUBNET=""
NETALERTX_CORES=""
NETALERTX_MEMORY=""
NETALERTX_DISK=""

if (( INSTALL_NETALERTX )); then
    header "NETALERTX EINSTELLUNGEN"

    allocate_id
    NAX_ID="$(get_value "CT-ID NetAlertX" "$ALLOCATED_ID")"
    reject_reserved_guest_id "$NAX_ID"
    resolve_guest_id "$NAX_ID" "NetAlertX"
    NAX_ID="$RESOLVED_ID"
    RESERVED_IDS["$NAX_ID"]="NetAlertX"

    NETALERTX_IP_DEFAULT="$(suggest_ip_from_guest_id "$NAX_ID" || true)"

    if [[ -n "$NETALERTX_IP_DEFAULT" ]]; then
        NETALERTX_CIDR="$(get_value "NetAlertX IP/CIDR" "$NETALERTX_IP_DEFAULT")"
    else
        warn "CT-ID $NAX_ID kann nicht direkt als IPv4-Endung verwendet werden."
        NETALERTX_CIDR="$(get_value "NetAlertX IP/CIDR" "")"
        [[ -n "$NETALERTX_CIDR" ]] || die "Für NetAlertX muss eine IP/CIDR angegeben werden."
    fi
    NETALERTX_IP="${NETALERTX_CIDR%%/*}"

    NETALERTX_SUBNET="$(get_value "Zu scannendes Netzwerk" "${NETWORK_PREFIX}.0/24")"
    NETALERTX_CORES="$(get_cpu_cores "CPU-Kerne für NetAlertX" "4")"
    NETALERTX_MEMORY="$(get_ram_mb "RAM für NetAlertX in GB" "4")"
    NETALERTX_DISK="$(get_disk_gb "Root-Disk für NetAlertX in GB" "12" "12")"
fi

# -----------------------------------------------------------------------------
# Zusatzanwendungen Einstellungen
# -----------------------------------------------------------------------------

UPTIME_ID=""; UPTIME_CIDR=""; UPTIME_IP=""; UPTIME_CORES=""; UPTIME_MEMORY=""; UPTIME_DISK=""
VAULTWARDEN_ID=""; VAULTWARDEN_CIDR=""; VAULTWARDEN_IP=""; VAULTWARDEN_CORES=""; VAULTWARDEN_MEMORY=""; VAULTWARDEN_DISK=""
CADDY_ID=""; CADDY_CIDR=""; CADDY_IP=""; CADDY_CORES=""; CADDY_MEMORY=""; CADDY_DISK=""
STIRLING_ID=""; STIRLING_CIDR=""; STIRLING_IP=""; STIRLING_CORES=""; STIRLING_MEMORY=""; STIRLING_DISK=""
NTFY_ID=""; NTFY_CIDR=""; NTFY_IP=""; NTFY_CORES=""; NTFY_MEMORY=""; NTFY_DISK=""
FORGEJO_ID=""; FORGEJO_CIDR=""; FORGEJO_IP=""; FORGEJO_CORES=""; FORGEJO_MEMORY=""; FORGEJO_DISK=""
SYNCTHING_ID=""; SYNCTHING_CIDR=""; SYNCTHING_IP=""; SYNCTHING_CORES=""; SYNCTHING_MEMORY=""; SYNCTHING_DISK=""
SPEEDTEST_ID=""; SPEEDTEST_CIDR=""; SPEEDTEST_IP=""; SPEEDTEST_CORES=""; SPEEDTEST_MEMORY=""; SPEEDTEST_DISK=""
SCRUTINY_ID=""; SCRUTINY_CIDR=""; SCRUTINY_IP=""; SCRUTINY_CORES=""; SCRUTINY_MEMORY=""; SCRUTINY_DISK=""
MEALIE_ID=""; MEALIE_CIDR=""; MEALIE_IP=""; MEALIE_CORES=""; MEALIE_MEMORY=""; MEALIE_DISK=""

# Community-Scripts Erweiterungen
PBS_ID=""; PBS_CIDR=""; PBS_IP=""; PBS_CORES=""; PBS_MEMORY=""; PBS_DISK=""
PULSE_ID=""; PULSE_CIDR=""; PULSE_IP=""; PULSE_CORES=""; PULSE_MEMORY=""; PULSE_DISK=""
PVEUPS_ID=""; PVEUPS_CIDR=""; PVEUPS_IP=""; PVEUPS_CORES=""; PVEUPS_MEMORY=""; PVEUPS_DISK=""
SEMAPHORE_ID=""; SEMAPHORE_CIDR=""; SEMAPHORE_IP=""; SEMAPHORE_CORES=""; SEMAPHORE_MEMORY=""; SEMAPHORE_DISK=""
POCKETID_ID=""; POCKETID_CIDR=""; POCKETID_IP=""; POCKETID_CORES=""; POCKETID_MEMORY=""; POCKETID_DISK=""
PROMETHEUS_ID=""; PROMETHEUS_CIDR=""; PROMETHEUS_IP=""; PROMETHEUS_CORES=""; PROMETHEUS_MEMORY=""; PROMETHEUS_DISK=""
PVE_EXPORTER_ID=""; PVE_EXPORTER_CIDR=""; PVE_EXPORTER_IP=""; PVE_EXPORTER_CORES=""; PVE_EXPORTER_MEMORY=""; PVE_EXPORTER_DISK=""
GRAFANA_ID=""; GRAFANA_CIDR=""; GRAFANA_IP=""; GRAFANA_CORES=""; GRAFANA_MEMORY=""; GRAFANA_DISK=""
PANGOLIN_ID=""; PANGOLIN_CIDR=""; PANGOLIN_IP=""; PANGOLIN_CORES=""; PANGOLIN_MEMORY=""; PANGOLIN_DISK=""
NEWT_ID=""; NEWT_CIDR=""; NEWT_IP=""; NEWT_CORES=""; NEWT_MEMORY=""; NEWT_DISK=""
GATUS_ID=""; GATUS_CIDR=""; GATUS_IP=""; GATUS_CORES=""; GATUS_MEMORY=""; GATUS_DISK=""
HOMEPAGE_ID=""; HOMEPAGE_CIDR=""; HOMEPAGE_IP=""; HOMEPAGE_CORES=""; HOMEPAGE_MEMORY=""; HOMEPAGE_DISK=""
NPM_ID=""; NPM_CIDR=""; NPM_IP=""; NPM_CORES=""; NPM_MEMORY=""; NPM_DISK=""
EMQX_ID=""; EMQX_CIDR=""; EMQX_IP=""; EMQX_CORES=""; EMQX_MEMORY=""; EMQX_DISK=""
PBS_ROOT_PASS=""
PULSE_ROOT_PASS=""
PULSE_ADMIN_USER="admin"
PULSE_ADMIN_PASS=""
PULSE_API_TOKEN=""
PULSE_PVE_REGISTERED=0
PULSE_PBS_REGISTERED=0
PULSE_API_TOKEN_VALID=0
PULSE_INSTALL_FAILED=0
PULSE_INSTALL_ERROR=""
PVEUPS_ROOT_PASS=""
PVEUPS_SKIPPED=0
PVEUPS_INSTALLED=0

SEMAPHORE_ROOT_PASS=""
SEMAPHORE_ADMIN_PASS=""
SEMAPHORE_COOKIE_HASH=""
SEMAPHORE_COOKIE_ENCRYPTION=""
SEMAPHORE_ACCESS_KEY_ENCRYPTION=""
POCKETID_ROOT_PASS=""
POCKETID_PUBLIC_URL=""
POCKETID_ENCRYPTION_KEY=""
PROMETHEUS_ROOT_PASS=""
PVE_EXPORTER_ROOT_PASS=""
PVE_EXPORTER_TOKEN_SECRET=""
PVE_EXPORTER_TOKEN_ID="prometheus@pve!exporter"
PVE_EXPORTER_TARGET_IP=""
GRAFANA_ROOT_PASS=""
GRAFANA_ADMIN_PASS=""
PANGOLIN_ROOT_PASS=""
NEWT_ROOT_PASS=""
GATUS_ROOT_PASS=""
HOMEPAGE_ROOT_PASS=""
NPM_ROOT_PASS=""
EMQX_ROOT_PASS=""
EMQX_ADMIN_PASS=""

PANGOLIN_URL=""
PANGOLIN_EMAIL=""
NEWT_SITE_ID=""
NEWT_SITE_SECRET=""
NEWT_ENDPOINT=""
CROWDSEC_TARGETS=""

VAULTWARDEN_ADMIN_TOKEN=""
STIRLING_ADMIN_USER="admin"
STIRLING_ADMIN_PASS=""
SPEEDTEST_ADMIN_EMAIL="admin@local.invalid"
SPEEDTEST_ADMIN_PASS=""
SPEEDTEST_APP_KEY=""
MEALIE_DEFAULT_USER="changeme@example.com"
MEALIE_DEFAULT_PASS="MyPassword"

if (( INSTALL_UPTIME )); then
    header "UPTIME KUMA EINSTELLUNGEN"
    configure_optional_lxc_app UPTIME "Uptime Kuma" 4 4 12 12
fi

if (( INSTALL_VAULTWARDEN )); then
    header "VAULTWARDEN EINSTELLUNGEN"
    configure_optional_lxc_app VAULTWARDEN "Vaultwarden" 2 1 8 8
    VAULTWARDEN_ADMIN_TOKEN="$(openssl rand -hex 32)"
fi

if (( INSTALL_CADDY )); then
    header "CADDY REVERSE PROXY EINSTELLUNGEN"
    configure_optional_lxc_app CADDY "Caddy Reverse Proxy" 2 2 8 8
fi

if (( INSTALL_STIRLING )); then
    header "STIRLING PDF EINSTELLUNGEN"
    configure_optional_lxc_app STIRLING "Stirling PDF" 8 8 16 16
    STIRLING_ADMIN_PASS="$(openssl rand -hex 12)"
fi

if (( INSTALL_NTFY )); then
    header "NTFY EINSTELLUNGEN"
    configure_optional_lxc_app NTFY "ntfy" 2 1 8 8
fi

if (( INSTALL_FORGEJO )); then
    header "FORGEJO EINSTELLUNGEN"
    configure_optional_lxc_app FORGEJO "Forgejo" 2 1 12 12
fi

if (( INSTALL_SYNCTHING )); then
    header "SYNCTHING EINSTELLUNGEN"
    configure_optional_lxc_app SYNCTHING "Syncthing" 2 1 8 8
fi

if (( INSTALL_SPEEDTEST )); then
    header "SPEEDTEST TRACKER EINSTELLUNGEN"
    configure_optional_lxc_app SPEEDTEST "Speedtest Tracker" 2 1 8 8
    SPEEDTEST_ADMIN_PASS="$(openssl rand -hex 12)"
    SPEEDTEST_APP_KEY="base64:$(openssl rand -base64 32 | tr -d '\n')"
fi

if (( INSTALL_SCRUTINY )); then
    header "SCRUTINY EINSTELLUNGEN"
    configure_optional_lxc_app SCRUTINY "Scrutiny" 2 2 12 12
fi

if (( INSTALL_MEALIE )); then
    header "MEALIE EINSTELLUNGEN"
    configure_optional_lxc_app MEALIE "Mealie" 2 1 8 8
    # Mealie v3 dokumentiert diesen Erstlogin weiterhin offiziell. Das Script
    # speichert ihn separat und weist im Abschluss darauf hin, ihn sofort zu ändern.
    MEALIE_DEFAULT_USER="changeme@example.com"
    MEALIE_DEFAULT_PASS="MyPassword"
fi

if (( INSTALL_PBS )); then
    header "PROXMOX BACKUP SERVER EINSTELLUNGEN"
    configure_optional_lxc_app PBS "Proxmox Backup Server" 2 2 128 32
    PBS_ROOT_PASS="$(openssl rand -hex 12)"
    echo
    echo "PBS-LXC Standardgröße: 128 GB."
    echo "PBS-Datastore: nach Installation separat konfigurieren, z. B. auf dem NAS."
fi

if (( INSTALL_PULSE )); then
    header "PULSE EINSTELLUNGEN"
    ui_section "Empfohlener Standard"
    ui_kv "CPU" "2 Kerne"
    ui_kv "RAM" "4 GB"
    ui_kv "Disk" "12 GB"
    ui_section_end
    configure_optional_lxc_app PULSE "Pulse" 2 4 12 12

    # Getrennte Zugangsdaten:
    # - LXC-root nur für Containerwartung
    # - Pulse-Admin für die Weboberfläche
    # - API-Token für die automatische Proxmox/PBS-Einrichtung
    PULSE_ROOT_PASS="$(openssl rand -hex 12)"
    PULSE_ADMIN_PASS="$(openssl rand -hex 16)"
    PULSE_API_TOKEN="$(openssl rand -hex 32)"

    ui_section "Automatische Pulse-Einrichtung"
    ui_kv "Admin" "$PULSE_ADMIN_USER"
    ui_kv "Web" "https://${PULSE_IP}/"
    ui_kv "Zeitzone" "Europe/Berlin"
    ui_kv "Discovery-Netz" "${NETWORK_PREFIX}.0/24"
    ui_note "Der First-Run-/Bootstrap-Assistent wird automatisch übersprungen."
    ui_note "Der Proxmox-Host wird mit einem eigenen eingeschränkten Monitoring-Token registriert."
    if (( INSTALL_PBS )); then
        ui_note "Der in diesem Lauf installierte PBS wird ebenfalls automatisch registriert."
    fi
    ui_note "Passwörter/API-Token werden nur in der geschützten Passwortdatei gespeichert."
    ui_section_end
fi

if (( INSTALL_PVEUPS )); then
    header "PVE-UPS EINSTELLUNGEN"
    if community_pve_ups_available; then
        ui_section "Empfohlener Standard"
        ui_kv "CPU" "2 Kerne"
        ui_kv "RAM" "2 GB"
        ui_kv "Disk" "8 GB"
        ui_kv "Disk-Richtwert" "8 GB · V107 Sicherheitsreserve"
        ui_section_end
        configure_optional_lxc_app PVEUPS "PVE-UPS" 2 2 8 8
        PVEUPS_ROOT_PASS="$(openssl rand -hex 12)"
    else
        if (( OPTIMAL_INSTALL )); then
            die "PVE-UPS ist nicht verfügbar; der feste Optimal-Stack wird nicht unvollständig installiert."
        fi
        warn "PVE-UPS ist bei Community-Scripts derzeit nicht freigegeben oder der Status ist nicht erreichbar."
        echo "Die Komponente wird in diesem Lauf sicher übersprungen."
        INSTALL_PVEUPS=0
        PVEUPS_SKIPPED=1
    fi
fi


if (( INSTALL_SEMAPHORE )); then
    header "SEMAPHORE EINSTELLUNGEN"
    configure_optional_lxc_app SEMAPHORE "Semaphore" 4 4 10 10
    SEMAPHORE_ROOT_PASS="$(openssl rand -hex 12)"
fi

if (( INSTALL_POCKETID )); then
    header "POCKET ID EINSTELLUNGEN"
    configure_optional_lxc_app POCKETID "Pocket ID" 2 2 8 8
    POCKETID_ROOT_PASS="$(openssl rand -hex 12)"
    POCKETID_PUBLIC_URL="$(get_value "Pocket ID öffentliche Domain (ohne https://)" "pocketid.example.invalid")"
    POCKETID_PUBLIC_URL="${POCKETID_PUBLIC_URL#https://}"
    POCKETID_PUBLIC_URL="${POCKETID_PUBLIC_URL#http://}"
    POCKETID_PUBLIC_URL="${POCKETID_PUBLIC_URL%/}"
    [[ -n "$POCKETID_PUBLIC_URL" ]] || die "Pocket ID: öffentliche Domain darf nicht leer sein."
    [[ "$POCKETID_PUBLIC_URL" != *[[:space:]]* ]] || die "Pocket ID: öffentliche Domain darf keine Leerzeichen enthalten."
fi

if (( INSTALL_PROMETHEUS )); then
    header "PROMETHEUS EINSTELLUNGEN"
    configure_optional_lxc_app PROMETHEUS "Prometheus" 4 4 24 24
    PROMETHEUS_ROOT_PASS="$(openssl rand -hex 12)"
fi

if (( INSTALL_PVE_EXPORTER )); then
    header "PROMETHEUS PVE EXPORTER EINSTELLUNGEN"
    configure_optional_lxc_app PVE_EXPORTER "Prometheus PVE Exporter" 1 1 6 6 1
    PVE_EXPORTER_ROOT_PASS="$(openssl rand -hex 12)"
fi

if (( INSTALL_GRAFANA )); then
    header "GRAFANA EINSTELLUNGEN"
    configure_optional_lxc_app GRAFANA "Grafana" 4 4 12 12
    GRAFANA_ROOT_PASS="$(openssl rand -hex 12)"
    GRAFANA_ADMIN_PASS="$(openssl rand -hex 16)"
fi

if (( INSTALL_PANGOLIN )); then
    header "PANGOLIN EINSTELLUNGEN"
    configure_optional_lxc_app PANGOLIN "Pangolin" 2 4 16 16
    PANGOLIN_ROOT_PASS="$(openssl rand -hex 12)"

    PANGOLIN_URL="$(get_value "Pangolin öffentliche Domain" "pangolin.example.invalid")"
    PANGOLIN_EMAIL="$(get_value "Pangolin Admin-E-Mail" "admin@example.invalid")"
fi

if (( INSTALL_NEWT )); then
    header "NEWT EINSTELLUNGEN"
    configure_optional_lxc_app NEWT "Newt" 2 1 8 8
    NEWT_ROOT_PASS="$(openssl rand -hex 12)"
    NEWT_SITE_ID="$(get_value "Newt ID" "")"

    if (( TUI_AVAILABLE )); then
        NEWT_SITE_SECRET="$(
            tui_password "NEWT SECRET" "Newt Secret aus dem Pangolin-Dashboard"
        )" || die "Newt Secret fehlt."
    else
        read -rsp "Newt Secret: " NEWT_SITE_SECRET
        echo
    fi

    newt_default="https://"
    if [[ -n "$PANGOLIN_URL" && "$PANGOLIN_URL" != "pangolin.example.invalid" ]]; then
        newt_default="https://${PANGOLIN_URL}"
    fi

    NEWT_ENDPOINT="$(get_value "Pangolin Endpoint für Newt" "$newt_default")"

    [[ -n "$NEWT_SITE_ID" ]] || die "Newt ID fehlt."
    [[ -n "$NEWT_SITE_SECRET" ]] || die "Newt Secret fehlt."
fi

if (( INSTALL_GATUS )); then
    header "GATUS EINSTELLUNGEN"
    configure_optional_lxc_app GATUS "Gatus" 2 2 8 8
    GATUS_ROOT_PASS="$(openssl rand -hex 12)"
fi

if (( INSTALL_HOMEPAGE )); then
    header "HOMEPAGE EINSTELLUNGEN"
    configure_optional_lxc_app HOMEPAGE "Homepage" 2 4 10 10
    HOMEPAGE_ROOT_PASS="$(openssl rand -hex 12)"
fi

if (( INSTALL_NPM )); then
    header "NGINX PROXY MANAGER EINSTELLUNGEN"
    configure_optional_lxc_app NPM "Nginx Proxy Manager" 2 2 12 12
    NPM_ROOT_PASS="$(openssl rand -hex 12)"
    ui_note "NPM nutzt Port 80/443 selbst. Die Admin-Oberfläche bleibt technisch bedingt auf Port 81."
fi

if (( INSTALL_EMQX )); then
    header "EMQX MQTT EINSTELLUNGEN"
    configure_optional_lxc_app EMQX "EMQX MQTT Broker" 2 4 10 10
    EMQX_ROOT_PASS="$(openssl rand -hex 12)"
    EMQX_ADMIN_PASS="$(openssl rand -hex 12)"
    ui_note "MQTT 1883 · MQTTS 8883 · WebSocket 8083 · WSS 8084"
    ui_note "EMQX Dashboard intern 18083 -> extern HTTP 80 + HTTPS 443."
fi

if (( INSTALL_CROWDSEC )); then
    header "CROWDSEC ADD-ON"

    crowdsec_default_targets=()
    (( INSTALL_CADDY )) && crowdsec_default_targets+=("$CADDY_ID")
    (( INSTALL_POCKETID )) && crowdsec_default_targets+=("$POCKETID_ID")
    (( INSTALL_PANGOLIN )) && crowdsec_default_targets+=("$PANGOLIN_ID")
    (( INSTALL_NPM )) && crowdsec_default_targets+=("$NPM_ID")

    crowdsec_default="$(IFS=,; printf '%s' "${crowdsec_default_targets[*]}")"

    CROWDSEC_TARGETS="$(
        get_value \
            "CrowdSec Ziel-CT-IDs (Komma getrennt)" \
            "$crowdsec_default"
    )"
fi

# IP-Konflikte zwischen ausgewählten Diensten verhindern.
declare -A SERVICE_IPS=()

register_service_ip() {
    local name="$1"
    local ip="$2"

    [[ -n "$ip" ]] || return 0

    if [[ -n "${SERVICE_IPS[$ip]:-}" ]]; then
        die "IP-Konflikt: $name und ${SERVICE_IPS[$ip]} verwenden beide $ip."
    fi

    SERVICE_IPS["$ip"]="$name"
}

(( INSTALL_HA )) && register_service_ip "Home Assistant" "$HA_IP"
(( INSTALL_PAPERLESS )) && register_service_ip "Paperless" "$PAPERLESS_IP"
(( INSTALL_PIHOLE )) && register_service_ip "Pi-hole" "$PIHOLE_IP"
(( INSTALL_NETALERTX )) && register_service_ip "NetAlertX" "$NETALERTX_IP"
(( INSTALL_UPTIME )) && register_service_ip "Uptime Kuma" "$UPTIME_IP"
(( INSTALL_VAULTWARDEN )) && register_service_ip "Vaultwarden" "$VAULTWARDEN_IP"
(( INSTALL_CADDY )) && register_service_ip "Caddy" "$CADDY_IP"
(( INSTALL_STIRLING )) && register_service_ip "Stirling PDF" "$STIRLING_IP"
(( INSTALL_NTFY )) && register_service_ip "ntfy" "$NTFY_IP"
(( INSTALL_FORGEJO )) && register_service_ip "Forgejo" "$FORGEJO_IP"
(( INSTALL_SYNCTHING )) && register_service_ip "Syncthing" "$SYNCTHING_IP"
(( INSTALL_SPEEDTEST )) && register_service_ip "Speedtest Tracker" "$SPEEDTEST_IP"
(( INSTALL_SCRUTINY )) && register_service_ip "Scrutiny" "$SCRUTINY_IP"
(( INSTALL_MEALIE )) && register_service_ip "Mealie" "$MEALIE_IP"
(( INSTALL_PBS )) && register_service_ip "Proxmox Backup Server" "$PBS_IP"
(( INSTALL_PULSE )) && register_service_ip "Pulse" "$PULSE_IP"
(( INSTALL_PVEUPS )) && register_service_ip "PVE-UPS" "$PVEUPS_IP"
(( INSTALL_SEMAPHORE )) && register_service_ip "Semaphore" "$SEMAPHORE_IP"
(( INSTALL_POCKETID )) && register_service_ip "Pocket ID" "$POCKETID_IP"
(( INSTALL_PROMETHEUS )) && register_service_ip "Prometheus" "$PROMETHEUS_IP"
(( INSTALL_PVE_EXPORTER )) && register_service_ip "Prometheus PVE Exporter" "$PVE_EXPORTER_IP"
(( INSTALL_GRAFANA )) && register_service_ip "Grafana" "$GRAFANA_IP"
(( INSTALL_PANGOLIN )) && register_service_ip "Pangolin" "$PANGOLIN_IP"
(( INSTALL_NEWT )) && register_service_ip "Newt" "$NEWT_IP"
(( INSTALL_GATUS )) && register_service_ip "Gatus" "$GATUS_IP"
(( INSTALL_HOMEPAGE )) && register_service_ip "Homepage" "$HOMEPAGE_IP"
(( INSTALL_NPM )) && register_service_ip "Nginx Proxy Manager" "$NPM_IP"
(( INSTALL_EMQX )) && register_service_ip "EMQX MQTT Broker" "$EMQX_IP"

# -----------------------------------------------------------------------------
# Zusammenfassung
# -----------------------------------------------------------------------------

header "ZUSAMMENFASSUNG"

echo "${BOLD}Die folgenden Komponenten werden mit diesen Einstellungen installiert:${RESET}"
echo

(( INSTALL_DASHBOARD )) && ui_card \
    "Dashboard" \
    "URL" "https://${DASHBOARD_IP}/" \
    "Historie" "1h · 6h · 12h · 24h · 7 Tage · 1 Monat" \
    "Power" "Neustart/Shutdown mit Steuer-Code"

if (( INSTALL_OS )); then
    ui_card \
        "Betriebssystem · ${OS_LABEL}" \
        "VM-ID" "$OS_ID" \
        "Name" "$OS_NAME" \
        "Profil" "$([[ "$OS_MODE" == "desktop" ]] && echo "mit Grafik" || echo "ohne Grafik")" \
        "CPU / RAM" "${OS_CORES} / $((OS_MEMORY / 1024)) GB" \
        "Disk" "${OS_DISK} GB" \
        "Netzwerk" "$([[ -n "$OS_CIDR" ]] && echo "$OS_CIDR" || echo "DHCP / im Gast")" \
        "Methode" "$([[ "$OS_DISTRO" == "debian" || "$OS_DISTRO" == "ubuntu" ]] && echo "Cloud-Image · automatisch" || echo "ISO · VM vorbereitet")"
fi

(( INSTALL_HA )) && ui_card \
    "Home Assistant" \
    "VM-ID" "$HA_ID" \
    "IP" "$HA_IP" \
    "CPU / RAM" "${HA_CORES} / $((HA_MEMORY / 1024)) GB" \
    "Disk" "${HA_DISK} GB" \
    "Web (HAOS nativ)" "http://${HA_IP}:8123/"

if (( INSTALL_PAPERLESS )); then
    if (( PAPERLESS_EXTERNAL_STORAGE )); then
        ui_card \
            "Paperless + Ollama" \
            "CT-ID" "$PL_ID" \
            "IP" "$PAPERLESS_IP" \
            "CPU / RAM" "${PL_CORES} / $((PL_MEMORY / 1024)) GB" \
            "Disk" "${PL_DISK} GB" \
            "LLM" "$OLLAMA_MODEL" \
            "NAS" "${PAPERLESS_NAS_IP}:${PAPERLESS_NAS_PATH}" \
            "Ordner" "data=${PAPERLESS_DATA_SUBDIR} · media=${PAPERLESS_MEDIA_SUBDIR} · export=${PAPERLESS_EXPORT_SUBDIR} · inbox=${PAPERLESS_CONSUME_SUBDIR}"
    else
        ui_card \
            "Paperless + Ollama" \
            "CT-ID" "$PL_ID" \
            "IP" "$PAPERLESS_IP" \
            "CPU / RAM" "${PL_CORES} / $((PL_MEMORY / 1024)) GB" \
            "Disk" "${PL_DISK} GB" \
            "LLM" "$OLLAMA_MODEL" \
            "Daten" "lokal im LXC"
    fi
fi

(( INSTALL_PIHOLE )) && ui_card \
    "Pi-hole + Unbound" \
    "CT-ID" "$PH_ID" \
    "IP / DNS" "${PIHOLE_IP} / Port 53" \
    "CPU / RAM" "${PH_CORES} / $((PH_MEMORY / 1024)) GB" \
    "Disk" "${PH_DISK} GB" \
    "Sprache" "$PIHOLE_LANG"

(( INSTALL_NETALERTX )) && ui_card \
    "NetAlertX" \
    "CT-ID" "$NAX_ID" \
    "Web" "https://${NETALERTX_IP}/" \
    "Scan-Netz" "$NETALERTX_SUBNET" \
    "CPU / RAM" "${NETALERTX_CORES} / $((NETALERTX_MEMORY / 1024)) GB" \
    "Disk" "${NETALERTX_DISK} GB"

(( INSTALL_UPTIME )) && ui_card \
    "Uptime Kuma" \
    "CT-ID" "$UPTIME_ID" \
    "Web" "https://${UPTIME_IP}/" \
    "CPU / RAM" "${UPTIME_CORES} / $((UPTIME_MEMORY / 1024)) GB" \
    "Disk" "${UPTIME_DISK} GB" \
    "Daten" "/home/Data/uptime-kuma"

(( INSTALL_VAULTWARDEN )) && ui_card \
    "Vaultwarden" \
    "CT-ID" "$VAULTWARDEN_ID" \
    "Web" "https://${VAULTWARDEN_IP}/" \
    "CPU / RAM" "${VAULTWARDEN_CORES} / $((VAULTWARDEN_MEMORY / 1024)) GB" \
    "Disk" "${VAULTWARDEN_DISK} GB" \
    "Hinweis" "HTTPS für Web-Vault erforderlich"

(( INSTALL_CADDY )) && ui_card \
    "Caddy Reverse Proxy" \
    "CT-ID" "$CADDY_ID" \
    "Web" "http://${CADDY_IP}/" \
    "CPU / RAM" "${CADDY_CORES} / $((CADDY_MEMORY / 1024)) GB" \
    "Disk" "${CADDY_DISK} GB"

(( INSTALL_STIRLING )) && ui_card \
    "Stirling PDF" \
    "CT-ID" "$STIRLING_ID" \
    "Web" "https://${STIRLING_IP}/" \
    "CPU / RAM" "${STIRLING_CORES} / $((STIRLING_MEMORY / 1024)) GB" \
    "Disk" "${STIRLING_DISK} GB"

(( INSTALL_NTFY )) && ui_card \
    "ntfy" \
    "CT-ID" "$NTFY_ID" \
    "Web" "https://${NTFY_IP}/" \
    "CPU / RAM" "${NTFY_CORES} / $((NTFY_MEMORY / 1024)) GB" \
    "Disk" "${NTFY_DISK} GB"

(( INSTALL_FORGEJO )) && ui_card \
    "Forgejo" \
    "CT-ID" "$FORGEJO_ID" \
    "Web" "https://${FORGEJO_IP}/" \
    "Git SSH" "${FORGEJO_IP}:222" \
    "CPU / RAM" "${FORGEJO_CORES} / $((FORGEJO_MEMORY / 1024)) GB"

(( INSTALL_SYNCTHING )) && ui_card \
    "Syncthing" \
    "CT-ID" "$SYNCTHING_ID" \
    "Web" "https://${SYNCTHING_IP}/" \
    "CPU / RAM" "${SYNCTHING_CORES} / $((SYNCTHING_MEMORY / 1024)) GB" \
    "Disk" "${SYNCTHING_DISK} GB"

(( INSTALL_SPEEDTEST )) && ui_card \
    "Speedtest Tracker" \
    "CT-ID" "$SPEEDTEST_ID" \
    "Web" "https://${SPEEDTEST_IP}/" \
    "CPU / RAM" "${SPEEDTEST_CORES} / $((SPEEDTEST_MEMORY / 1024)) GB" \
    "Disk" "${SPEEDTEST_DISK} GB"

(( INSTALL_SCRUTINY )) && ui_card \
    "Scrutiny" \
    "CT-ID" "$SCRUTINY_ID" \
    "Web" "https://${SCRUTINY_IP}/" \
    "CPU / RAM" "${SCRUTINY_CORES} / $((SCRUTINY_MEMORY / 1024)) GB" \
    "Disk" "${SCRUTINY_DISK} GB" \
    "Collector" "Proxmox-Host · alle 15 Minuten"

(( INSTALL_MEALIE )) && ui_card \
    "Mealie" \
    "CT-ID" "$MEALIE_ID" \
    "Web" "https://${MEALIE_IP}/" \
    "CPU / RAM" "${MEALIE_CORES} / $((MEALIE_MEMORY / 1024)) GB" \
    "Disk" "${MEALIE_DISK} GB"

(( INSTALL_PBS )) && ui_card \
    "Proxmox Backup Server" \
    "CT-ID" "$PBS_ID" \
    "Web" "https://${PBS_IP}:8007/" \
    "CPU / RAM" "${PBS_CORES} / $((PBS_MEMORY / 1024)) GB" \
    "Disk" "${PBS_DISK} GB" \
    "Kategorie" "Basics" \
    "Datastore" "nach Installation separat konfigurieren"

(( INSTALL_PULSE )) && ui_card \
    "Pulse" \
    "CT-ID" "$PULSE_ID" \
    "Web" "https://${PULSE_IP}/" \
    "Admin" "$PULSE_ADMIN_USER" \
    "CPU / RAM" "${PULSE_CORES} / $((PULSE_MEMORY / 1024)) GB" \
    "Disk" "${PULSE_DISK} GB" \
    "PVE Setup" "automatisch · API-only · Backup-Sichtbarkeit" \
    "PBS Setup" "$([[ "$INSTALL_PBS" -eq 1 ]] && echo automatisch || echo nicht ausgewählt)" \
    "Kategorie" "Extras"

(( INSTALL_PVEUPS )) && ui_card \
    "PVE-UPS" \
    "CT-ID" "$PVEUPS_ID" \
    "Web" "https://${PVEUPS_IP}/" \
    "CPU / RAM" "${PVEUPS_CORES} / $((PVEUPS_MEMORY / 1024)) GB" \
    "Disk" "${PVEUPS_DISK} GB" \
    "Kategorie" "Extras" \
    "Setup" "NAS-NUT + Proxmox API-Token"

echo "${BOLD}${GREEN}┌─ BEREIT ZUR INSTALLATION${RESET}"
echo "│  ${GREEN}✓${RESET} Konfiguration vollständig"
echo "│  ${BLUE}●${RESET} ENTER bzw. J startet die Installation"
echo "│  ${YELLOW}!${RESET} N bricht ohne Änderungen an den noch nicht installierten Komponenten ab"
echo "${GREEN}${BOLD}└─────────────────────────────────────────────────────────────────────${RESET}"
echo

yn "Installation jetzt starten? [J/n]" "J" || exit 0

# =============================================================================
# LXC TEMPLATE / DOCKER HELFER
# =============================================================================

TEMPLATE_VOL=""

prepare_lxc_template() {
    header "DEBIAN LXC TEMPLATE / DOWNLOAD-CACHE"

    prepare_image_cache_storage
    TEMPLATE_STORAGE="$IMAGE_CACHE_STORAGE"

    local template=""
    local cached=""
    local cache_file=""

    echo "Prüfe aktuelle Proxmox-LXC-Template-Liste ..."

    if pveam update; then
        template="$(
            pveam available --section system 2>/dev/null |
            awk '$2~/^debian-13-standard_.*amd64\.tar\.(zst|xz|gz)$/{print $2}' |
            sort -V |
            tail -1
        )"

        [[ -n "$template" ]] || template="$(
            pveam available --section system 2>/dev/null |
            awk '$2~/^debian-12-standard_.*amd64\.tar\.(zst|xz|gz)$/{print $2}' |
            sort -V |
            tail -1
        )"
    else
        warn "Template-Liste konnte nicht aktualisiert werden."
    fi

    cached="$(find_cached_debian_template)"
    [[ -n "$template" ]] || template="$cached"

    [[ -n "$template" ]] || \
        die "Kein Debian-LXC-Template verfügbar und kein Cache vorhanden."

    cache_file="$LXC_CACHE_DIR/$template"

    if [[ -s "$cache_file" ]]; then
        echo "Aktuelles LXC-Template bereits im Cache:"
        echo "  $cache_file"
    else
        copy_existing_template_into_cache "$template" || true

        if [[ ! -s "$cache_file" ]]; then
            echo "Neue LXC-Template-Version gefunden."
            echo "Lade einmalig nach:"
            echo "  $cache_file"

            pveam download "$IMAGE_CACHE_STORAGE" "$template"
        fi
    fi

    [[ -s "$cache_file" ]] || \
        die "LXC-Template fehlt nach Cache-Prüfung: $cache_file"

    TEMPLATE_VOL="${IMAGE_CACHE_STORAGE}:vztmpl/${template}"
    ok "LXC-Template bereit: $template"
    echo "Cache: $cache_file"
}

install_docker_in_ct() {
    local ctid="$1"

    # V119: Remote-Script als literal heredoc an bash -lc übergeben.
    # Dadurch können awk/sed/printf im Container normale einfache Quotes
    # enthalten, ohne den äußeren Installer-String vorzeitig zu beenden.
    pct exec "$ctid" -- bash -lc "$(cat <<'NODEZERO_DOCKER_CT_V119'
        set -Eeuo pipefail
        export DEBIAN_FRONTEND=noninteractive

        ROOT_FREE_MB="$(df -Pm / | awk 'NR==2 {print $4}')"
        if [[ ! "$ROOT_FREE_MB" =~ ^[0-9]+$ ]] || (( ROOT_FREE_MB < 4096 )); then
            echo "FEHLER: Für Debian + Docker werden vor der Installation mindestens 4 GB freier Root-Speicher verlangt." >&2
            df -hT / >&2 || true
            exit 1
        fi

        mkdir -p \
            /var/cache/apt/archives/partial \
            /var/lib/apt/lists/partial

        cat > /etc/apt/apt.conf.d/90-persistent-installer-cache <<EOF
APT::Keep-Downloaded-Packages "true";
Binary::apt::APT::Keep-Downloaded-Packages "true";
EOF

        apt-get update
        apt-get install -y ca-certificates curl gnupg locales

        sed -i \
            -e "s/^# *de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/" \
            -e "s/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" \
            /etc/locale.gen

        locale-gen de_DE.UTF-8 en_US.UTF-8
        update-locale LANG=de_DE.UTF-8 LANGUAGE=de_DE:de LC_ALL=de_DE.UTF-8

        install -m 0755 -d /etc/apt/keyrings

        [[ -s /mnt/docker-image-cache/docker.asc ]] || {
            echo "FEHLER: Docker Repository-Key fehlt im Cache."
            exit 1
        }

        cp -f /mnt/docker-image-cache/docker.asc /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc

        . /etc/os-release

        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian ${VERSION_CODENAME} stable" \
            > /etc/apt/sources.list.d/docker.list

        apt-get update
        apt-get install -y \
            docker-ce \
            docker-ce-cli \
            containerd.io \
            docker-buildx-plugin \
            docker-compose-plugin

        systemctl enable --now docker
        timedatectl set-timezone Europe/Berlin || true

        ROOT_FREE_MB="$(df -Pm / | awk 'NR==2 {print $4}')"
        if [[ ! "$ROOT_FREE_MB" =~ ^[0-9]+$ ]] || (( ROOT_FREE_MB < 3072 )); then
            echo "FEHLER: Nach der Docker-Installation sind weniger als 3 GB auf / frei." >&2
            echo "Die Root-Disk des LXC ist zu klein; Docker-Images werden NICHT geladen." >&2
            df -hT / >&2 || true
            exit 1
        fi

        cat > /usr/local/sbin/docker-cache-pull <<'EOS'
#!/usr/bin/env bash
set -Eeuo pipefail

COMPOSE_DIR="${1:-.}"
CACHE_DIR="/mnt/docker-image-cache"

cd "$COMPOSE_DIR"

# Syntax/Interpolation der Compose-Datei prüfen, bevor Registry oder Runtime
# verändert werden. Ein Fehler bricht hier eindeutig ab.
docker compose config -q

ROOT_FREE_MB="$(df -Pm / | awk 'NR==2 {print $4}')"
if [[ ! "$ROOT_FREE_MB" =~ ^[0-9]+$ ]] || (( ROOT_FREE_MB < 3072 )); then
    echo "FEHLER: Docker-Image-Pull abgebrochen: weniger als 3 GB auf der LXC-Root-Disk frei." >&2
    df -hT / >&2 || true
    exit 1
fi

mapfile -t IMAGES < <(
    docker compose config --images |
    awk 'NF' |
    sort -u
)

if (( ${#IMAGES[@]} == 0 )); then
    docker compose pull
    exit 0
fi

APP="$(
    basename "$(pwd)" |
    tr '[:upper:]' '[:lower:]' |
    sed 's/[^a-z0-9._-]/_/g'
)"

mkdir -p "$CACHE_DIR"

TAR="${CACHE_DIR}/${APP}.tar"
META="${CACHE_DIR}/${APP}.image-ids"
TMP="${TAR}.part"

echo
echo "Docker-Image-Cache:"
echo "  $TAR"

if [[ -s "$TAR" ]]; then
    echo "Lade vorhandene Images aus /home/img ..."
    docker load -i "$TAR" >/dev/null
fi

echo "Prüfe Registry auf neuere Images ..."
docker compose pull

CURRENT="$(
    for image in "${IMAGES[@]}"; do
        printf '%s=' "$image"
        docker image inspect --format '{{.Id}}' "$image"
    done
)"

OLD=""
[[ -s "$META" ]] && OLD="$(cat "$META")"

if [[ ! -s "$TAR" || "$CURRENT" != "$OLD" ]]; then
    CACHE_FREE_MB="$(df -Pm "$CACHE_DIR" | awk 'NR==2 {print $4}')"

    if [[ "$CACHE_FREE_MB" =~ ^[0-9]+$ ]] && (( CACHE_FREE_MB >= 10240 )); then
        echo "Speichere aktuellen Docker-Image-Stand persistent ..."

        rm -f "$TMP"
        docker save "${IMAGES[@]}" -o "$TMP"
        mv -f "$TMP" "$TAR"
        printf '%s\n' "$CURRENT" > "$META"

        echo "[OK] Docker-Cache aktualisiert."
    else
        echo "[WARN] Weniger als 10 GB im Host-Image-Cache frei; docker save wird übersprungen."
        echo "       Die laufende Anwendung ist davon nicht betroffen."
        df -h "$CACHE_DIR" || true
    fi
else
    echo "[OK] Docker-Cache bereits aktuell."
fi
EOS

        chmod 755 /usr/local/sbin/docker-cache-pull
NODEZERO_DOCKER_CT_V119
)"
}

create_docker_app_lxc() {
    local ctid="$1"
    local hostname="$2"
    local cidr="$3"
    local cores="$4"
    local memory="$5"
    local disk="$6"
    local persistent_source="${7:-}"
    local persistent_mount="${8:-}"

    prepare_ct_cache_dirs "$hostname"

    local extra_mount=()

    if [[ -n "$persistent_source" || -n "$persistent_mount" ]]; then
        [[ -n "$persistent_source" && -n "$persistent_mount" ]] || \
            die "${hostname}: persistenter Source/Mount muss vollständig angegeben werden."

        mkdir -p "$persistent_source"
        chown -R 100000:100000 "$persistent_source" 2>/dev/null || true
        chmod 755 "$persistent_source"

        extra_mount=(
            --mp3
            "${persistent_source},mp=${persistent_mount}"
        )
    fi

    pct create "$ctid" "$TEMPLATE_VOL" \
        --hostname "$hostname" \
        --ostype debian \
        --unprivileged 1 \
        --features nesting=1,keyctl=1 \
        --cores "$cores" \
        --memory "$memory" \
        --swap 512 \
        --rootfs "${DISK_STORAGE}:${disk}" \
        --mp0 "${DOCKER_IMAGE_CACHE_DIR},mp=/mnt/docker-image-cache" \
        --mp1 "${CT_APT_ARCHIVES},mp=/var/cache/apt/archives" \
        --mp2 "${CT_APT_LISTS},mp=/var/lib/apt/lists" \
        "${extra_mount[@]}" \
        --net0 "name=eth0,bridge=${BRIDGE},ip=${cidr},gw=${GATEWAY},type=veth" \
        --nameserver "$GATEWAY" \
        --onboot 1 \
        --start 1

    sleep 4
    install_docker_in_ct "$ctid"
}

# V107: Einheitlicher, strikter Docker-Compose-Start. Dadurch kann ein
# fehlgeschlagener Pull/Compose-Parse nicht durch einen späteren Befehl
# verdeckt werden.
docker_compose_deploy_in_ct_v107() {
    local ctid="$1"
    local compose_dir="$2"
    shift 2

    local cmd service
    printf -v cmd 'set -Eeuo pipefail; cd %q; docker compose config -q; /usr/local/sbin/docker-cache-pull .; docker compose up -d' "$compose_dir"

    for service in "$@"; do
        printf -v service '%q' "$service"
        cmd+=" ${service}"
    done

    cmd+='; docker compose ps'
    pct exec "$ctid" -- bash -lc "$cmd"
}

docker_compose_up_in_ct_v107() {
    local ctid="$1"
    local compose_dir="$2"
    shift 2

    local cmd service
    printf -v cmd 'set -Eeuo pipefail; cd %q; docker compose config -q; docker compose up -d' "$compose_dir"

    for service in "$@"; do
        printf -v service '%q' "$service"
        cmd+=" ${service}"
    done

    cmd+='; docker compose ps'
    pct exec "$ctid" -- bash -lc "$cmd"
}

wait_for_web() {
    local label="$1"
    local url="$2"
    local attempts="${3:-90}"

    echo "Warte auf ${label} ..."

    local i
    for i in $(seq 1 "$attempts"); do
        if curl -fsS --max-time 3 "$url" >/dev/null 2>&1; then
            ok "${label} ist erreichbar: $url"
            return 0
        fi
        sleep 2
    done

    warn "${label} ist noch nicht erreichbar. Container-Logs prüfen."
    return 1
}

verify_web_v107() {
    local label="$1"
    local url="$2"
    local attempts="${3:-90}"

    if wait_for_web "$label" "$url" "$attempts"; then
        return 0
    fi

    if (( ${OPTIMAL_INSTALL:-0} )); then
        die "${label}: Web-Healthcheck im Optimalmodus fehlgeschlagen: ${url}"
    fi

    warn "${label}: Healthcheck fehlgeschlagen; manueller Installationslauf wird fortgesetzt."
    return 0
}

# =============================================================================
# V140 · NODEZERO DASHBOARD-MODUL
# =============================================================================
# Die komplette Dashboard-Logik liegt nicht mehr im Master-Installer.
# Sie wird über einen unveränderlichen Git-Commit in /root/downloads gecacht
# und anschließend mit source in den aktuellen Installer-Kontext eingebunden.
NODEZERO_MODULE_REF="44722c61915c6bcce5b0257962a03a3774db440a"
NODEZERO_MODULE_RAW_BASE="https://raw.githubusercontent.com/Technox90/homeatic/${NODEZERO_MODULE_REF}/proxmox/modules"

load_nodezero_module_v140() {
    local module="$1"
    local module_dir="${NODEZERO_DOWNLOAD_DIR}/nodezero/modules/${NODEZERO_MODULE_REF}"
    local module_file="${module_dir}/${module}.sh"
    local module_url="${NODEZERO_MODULE_RAW_BASE}/${module}.sh"
    local tmp="${module_file}.tmp"

    install -d -m 0700 -o root -g root "$NODEZERO_DOWNLOAD_DIR"
    install -d -m 0755 -o root -g root "$module_dir"

    if [[ ! -s "$module_file" ]]; then
        rm -f "$tmp"
        curl --fail --silent --show-error --location \
            --retry 3 --retry-delay 2 --connect-timeout 15 \
            "$module_url" -o "$tmp" ||
            die "NodeZero-Modul konnte nicht geladen werden: $module_url"

        [[ -s "$tmp" ]] || die "NodeZero-Modul ist leer: $module_url"
        mv -f "$tmp" "$module_file"
        chmod 0644 "$module_file"
    fi

    bash -n "$module_file" ||
        die "Syntaxprüfung des NodeZero-Moduls fehlgeschlagen: $module_file"

    # shellcheck source=/dev/null
    source "$module_file"

    ok "NodeZero-Modul geladen: $module"
    info "Modul-Cache: $module_file"
}

load_nodezero_module_v140 "dashboard"

# =============================================================================
# HOME ASSISTANT
# =============================================================================


# =============================================================================
# BETRIEBSSYSTEM-INSTALLATION V61
# =============================================================================

download_os_image_v61() {
    local url="$1"
    local target="$2"

    mkdir -p "$(dirname "$target")"

    if [[ -s "$target" ]]; then
        ok "Image-Cache: $target"
        return 0
    fi

    local tmp="${target}.part"
    rm -f "$tmp"

    echo "Download:"
    echo "  $url"
    echo "  -> $target"

    curl -fL \
        --retry 3 \
        --connect-timeout 15 \
        --max-time 1800 \
        --progress-bar \
        "$url" \
        -o "$tmp"

    [[ -s "$tmp" ]] || die "Download fehlgeschlagen: $url"

    mv -f "$tmp" "$target"
    chmod 644 "$target"
}

ensure_virtio_windows_iso_v61() {
    local target="${ISO_CACHE_DIR}/virtio-win.iso"
    local url="https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"

    download_os_image_v61 "$url" "$target"
    OS_WINDOWS_VIRTIO_VOLUME="${IMAGE_CACHE_STORAGE}:iso/virtio-win.iso"
}

resize_imported_vm_disk_v61() {
    local vmid="$1"
    local disk_name="$2"
    local volume="$3"
    local target_gb="$4"
    local path=""
    local bytes=""
    local current_gb=""

    path="$(pvesm path "$volume" 2>/dev/null || true)"

    if [[ -n "$path" && -e "$path" ]]; then
        bytes="$(
            qemu-img info --output=json "$path" 2>/dev/null |
            python3 -c '
import json
import sys

try:
    data=json.load(sys.stdin)
    print(int(data.get("virtual-size") or 0))
except Exception:
    print(0)
'
        )"

        if [[ "$bytes" =~ ^[0-9]+$ ]] && (( bytes > 0 )); then
            current_gb="$(
                python3 - "$bytes" <<'PY'
import math
import sys

print(max(1, math.ceil(int(sys.argv[1]) / (1024 ** 3))))
PY
            )"

            if (( target_gb > current_gb )); then
                qm disk resize "$vmid" "$disk_name" "${target_gb}G"
            elif (( target_gb < current_gb )); then
                warn "Gewünschte ${target_gb} GB liegen unter der Imagegröße von ca. ${current_gb} GB. Die Disk wird nicht verkleinert."
            fi

            return 0
        fi
    fi

    qm disk resize "$vmid" "$disk_name" "${target_gb}G" || \
        warn "Diskgröße konnte nicht automatisch auf ${target_gb} GB angepasst werden."
}

create_windows_vm_v61() {
    local ostype="$1"

    ensure_virtio_windows_iso_v61

    qm create "$OS_ID" \
        --name "$OS_NAME" \
        --ostype "$ostype" \
        --machine q35 \
        --bios ovmf \
        --cpu host \
        --sockets 1 \
        --cores "$OS_CORES" \
        --memory "$OS_MEMORY" \
        --balloon 0 \
        --scsihw virtio-scsi-single \
        --net0 "virtio,bridge=${BRIDGE}" \
        --agent enabled=1,fstrim_cloned_disks=1 \
        --tablet 1 \
        --vga std \
        --onboot 0 \
        --description "${OS_LABEL} | ISO=${OS_ISO_FILE} | VirtIO-Treiber angehängt"

    if [[ "$OS_DISTRO" == "win11" ]]; then
        qm set "$OS_ID" \
            --efidisk0 "${DISK_STORAGE}:0,efitype=4m,pre-enrolled-keys=1"

        qm set "$OS_ID" \
            --tpmstate0 "${DISK_STORAGE}:0,version=v2.0"
    else
        qm set "$OS_ID" \
            --efidisk0 "${DISK_STORAGE}:0,efitype=4m,pre-enrolled-keys=0"
    fi

    qm set "$OS_ID" \
        --scsi0 "${DISK_STORAGE}:${OS_DISK},discard=on,ssd=1,iothread=1"

    qm set "$OS_ID" \
        --ide2 "${OS_ISO_VOLUME},media=cdrom"

    qm set "$OS_ID" \
        --sata1 "${OS_WINDOWS_VIRTIO_VOLUME},media=cdrom"

    qm set "$OS_ID" \
        --boot "order=ide2;scsi0"

    qm start "$OS_ID"

    ok "${OS_LABEL}: VM ${OS_ID} erstellt und ISO gestartet."

    echo
    echo "Windows-Installation über die Proxmox-Konsole fortsetzen."
    echo
    echo "Wenn die System-Disk im Windows-Setup nicht angezeigt wird:"
    echo "  Treiber laden -> VirtIO-CD -> vioscsi -> w11/w10 -> amd64"
    echo
    echo "Nach dem Setup:"
    echo "  VirtIO Guest Tools von der zweiten CD installieren."
}

create_linux_cloud_vm_v61() {
    local image_url=""
    local image_file=""
    local packages=""
    local desktop_commands=""

    case "$OS_DISTRO" in
        debian)
            image_url="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2"
            image_file="${OS_CACHE_DIR}/debian-13-generic-amd64.qcow2"

            if [[ "$OS_MODE" == "desktop" ]]; then
                packages=$'  - task-xfce-desktop\n  - lightdm\n'
                desktop_commands=$'  - [ systemctl, set-default, graphical.target ]\n'
            fi
            ;;
        ubuntu)
            image_url="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
            image_file="${OS_CACHE_DIR}/ubuntu-24.04-noble-server-cloudimg-amd64.img"

            if [[ "$OS_MODE" == "desktop" ]]; then
                packages=$'  - ubuntu-desktop-minimal\n'
                desktop_commands=$'  - [ systemctl, set-default, graphical.target ]\n'
            fi
            ;;
        *)
            die "Cloud-Image für ${OS_DISTRO} nicht unterstützt."
            ;;
    esac

    download_os_image_v61 "$image_url" "$image_file"

    local password_hash
    password_hash="$(openssl passwd -6 "$OS_PASS")"

    local snippet_name="os-${OS_ID}-${OS_DISTRO}-${OS_MODE}.yaml"
    local snippet="${SNIPPET_CACHE_DIR}/${snippet_name}"

    cat > "$snippet" <<EOF
#cloud-config
hostname: ${OS_NAME}
manage_etc_hosts: true
timezone: Europe/Berlin
ssh_pwauth: true

users:
  - name: ${OS_USER}
    groups:
      - sudo
      - adm
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    passwd: '${password_hash}'

chpasswd:
  expire: false

package_update: true
package_upgrade: true

packages:
  - qemu-guest-agent
  - curl
  - ca-certificates
${packages}
runcmd:
  - [ systemctl, enable, --now, qemu-guest-agent ]
${desktop_commands}
EOF

    if [[ "$OS_MODE" == "desktop" ]]; then
        cat >> "$snippet" <<'EOF'

power_state:
  delay: now
  mode: reboot
  message: "Desktop-Installation abgeschlossen"
  timeout: 30
  condition: true
EOF
    fi

    chmod 600 "$snippet"

    qm create "$OS_ID" \
        --name "$OS_NAME" \
        --ostype l26 \
        --machine q35 \
        --bios ovmf \
        --cpu host \
        --sockets 1 \
        --cores "$OS_CORES" \
        --memory "$OS_MEMORY" \
        --balloon 0 \
        --scsihw virtio-scsi-single \
        --net0 "virtio,bridge=${BRIDGE}" \
        --agent enabled=1,fstrim_cloned_disks=1 \
        --serial0 socket \
        --vga "$([[ "$OS_MODE" == "headless" ]] && echo serial0 || echo std)" \
        --onboot 1 \
        --description "${OS_LABEL} | ${OS_MODE} | cloud-init | ${OS_IP}"

    qm set "$OS_ID" \
        --efidisk0 "${DISK_STORAGE}:0,efitype=4m,pre-enrolled-keys=0"

    qm disk import "$OS_ID" "$image_file" "$DISK_STORAGE"

    local imported_disk
    imported_disk="$(
        qm config "$OS_ID" |
        awk -F': ' '/^unused0:/{print $2;exit}'
    )"

    [[ -n "$imported_disk" ]] || die "Importierte Linux-Disk wurde nicht gefunden."

    qm set "$OS_ID" \
        --scsi0 "${imported_disk},discard=on,ssd=1,iothread=1"

    resize_imported_vm_disk_v61 \
        "$OS_ID" \
        scsi0 \
        "$imported_disk" \
        "$OS_DISK"

    qm set "$OS_ID" \
        --ide2 "${DISK_STORAGE}:cloudinit"

    qm set "$OS_ID" \
        --cicustom "user=${IMAGE_CACHE_STORAGE}:snippets/${snippet_name}"

    qm set "$OS_ID" \
        --ipconfig0 "ip=${OS_CIDR},gw=${GATEWAY}" \
        --nameserver "$GATEWAY"

    qm set "$OS_ID" \
        --boot "order=scsi0"

    qm start "$OS_ID"

    ok "${OS_LABEL}: VM ${OS_ID} gestartet."

    echo
    echo "SSH:"
    echo "  ssh ${OS_USER}@${OS_IP}"

    if [[ "$OS_MODE" == "desktop" ]]; then
        echo
        echo "Desktop-Pakete werden beim ersten Boot automatisch installiert."
        echo "Die VM startet danach einmal neu."
    fi
}

create_linux_mint_vm_v61() {
    qm create "$OS_ID" \
        --name "$OS_NAME" \
        --ostype l26 \
        --machine q35 \
        --bios ovmf \
        --cpu host \
        --sockets 1 \
        --cores "$OS_CORES" \
        --memory "$OS_MEMORY" \
        --balloon 0 \
        --scsihw virtio-scsi-single \
        --net0 "virtio,bridge=${BRIDGE}" \
        --agent enabled=1,fstrim_cloned_disks=1 \
        --vga std \
        --tablet 1 \
        --onboot 0 \
        --description "Linux Mint | ${OS_MODE} | ISO=${OS_ISO_FILE}"

    qm set "$OS_ID" \
        --efidisk0 "${DISK_STORAGE}:0,efitype=4m,pre-enrolled-keys=0"

    qm set "$OS_ID" \
        --scsi0 "${DISK_STORAGE}:${OS_DISK},discard=on,ssd=1,iothread=1"

    qm set "$OS_ID" \
        --ide2 "${OS_ISO_VOLUME},media=cdrom"

    qm set "$OS_ID" \
        --boot "order=ide2;scsi0"

    qm start "$OS_ID"

    ok "Linux Mint: VM ${OS_ID} erstellt und ISO gestartet."

    if [[ "$OS_MODE" == "headless" ]]; then
        echo
        echo "Mint-Konsolenprofil:"
        echo "  Die Mint-Installation selbst bleibt grafisch."
        echo "  Danach für Konsolenstart:"
        echo "    sudo systemctl set-default multi-user.target"
        echo
        echo "Für echte Server-/Headless-Systeme ist Debian/Ubuntu empfohlen."
    fi
}

install_operating_system_v61() {
    case "$OS_DISTRO" in
        win11) create_windows_vm_v61 "win11" ;;
        win10) create_windows_vm_v61 "win10" ;;
        debian|ubuntu) create_linux_cloud_vm_v61 ;;
        mint) create_linux_mint_vm_v61 ;;
        *) die "Unbekanntes Betriebssystem: ${OS_DISTRO}" ;;
    esac
}

install_home_assistant() {
    header "HOME ASSISTANT OS INSTALLIEREN"

    # libguestfs wird verwendet, um die offizielle HAOS CONFIG/network-
    # Konfiguration vor dem ersten Boot direkt in die Boot-Partition
    # des qcow2-Images einzufügen.
    apt-get update
    apt-get install -y \
        curl \
        jq \
        xz-utils \
        libguestfs-tools \
        uuid-runtime

    prepare_image_cache_base

    local haos=""
    local cached_haos=""
    local stable_json="${HAOS_CACHE_DIR}/stable.json"
    local cache_xz=""
    local cache_image=""
    local image=""
    local network_file="/tmp/haos-network-${HA_ID}"
    local network_uuid

    cached_haos="$(find_cached_haos_version)"

    echo "Prüfe aktuelle Home-Assistant-OS Stable-Version ..."

    if curl -fsSL \
        https://version.home-assistant.io/stable.json \
        -o "${stable_json}.tmp"; then
        mv -f "${stable_json}.tmp" "$stable_json"
    else
        rm -f "${stable_json}.tmp"
        warn "HAOS Versionsprüfung fehlgeschlagen – vorhandener Cache wird verwendet."
    fi

    if [[ -s "$stable_json" ]]; then
        haos="$(jq -r '.hassos.ova // empty' "$stable_json")"
    fi

    [[ -n "$haos" && "$haos" != "null" ]] || haos="$cached_haos"

    [[ -n "$haos" && "$haos" != "null" ]] || \
        die "Keine HAOS-Version ermittelbar und kein Cache vorhanden."

    if [[ -n "$cached_haos" && "$haos" == "$cached_haos" ]]; then
        echo "[OK] HAOS-Cache ist aktuell."
    elif [[ -n "$cached_haos" ]]; then
        echo "Neuere HAOS-Version gefunden:"
        echo "  vorhanden: $cached_haos"
        echo "  aktuell:   $haos"
    fi

    cache_xz="${HAOS_CACHE_DIR}/haos_ova-${haos}.qcow2.xz"
    cache_image="${HAOS_CACHE_DIR}/haos_ova-${haos}.qcow2"
    image="/tmp/haos_ova-${haos}-vm${HA_ID}.qcow2"

    network_uuid="$(uuidgen)"

    echo "Home Assistant OS: $haos"
    echo "Image-Cache:       $HAOS_CACHE_DIR"
    echo "Statische IP:      $HA_CIDR"
    echo "Gateway:            $GATEWAY"
    echo "DNS:                $HA_DNS"
    echo "Web:                http://${HA_IP}:8123/"

    if [[ ! -s "$cache_image" ]]; then
        if [[ ! -s "$cache_xz" ]]; then
            echo
            echo "Lade HAOS EINMALIG direkt nach:"
            echo "  $cache_xz"

            curl -fL --retry 3 --progress-bar \
                "https://github.com/home-assistant/operating-system/releases/download/${haos}/haos_ova-${haos}.qcow2.xz" \
                -o "${cache_xz}.part"

            mv -f "${cache_xz}.part" "$cache_xz"
        else
            echo "Verwende vorhandenes komprimiertes HAOS-Image:"
            echo "  $cache_xz"
        fi

        echo "Entpacke HAOS einmalig im Cache ..."
        xz -dkf "$cache_xz"
    else
        echo "Verwende vorhandenes entpacktes HAOS-Image:"
        echo "  $cache_image"
    fi

    [[ -s "$cache_image" ]] || \
        die "HAOS-Cache-Image fehlt: $cache_image"

    qemu-img info "$cache_image" >/dev/null || \
        die "HAOS-Cache-Image ist kein gültiges qcow2-Image."

    # WICHTIG:
    # Das Cache-Original bleibt unverändert. Die individuelle statische
    # Netzwerkkonfiguration wird nur in eine Arbeitskopie geschrieben.
    rm -f "$image"

    cp --reflink=auto --sparse=always \
        "$cache_image" \
        "$image"

    [[ -s "$image" ]] || die "HAOS-Arbeitskopie konnte nicht erstellt werden."

    cat > "$network_file" <<EOF
[connection]
id=my-network
uuid=${network_uuid}
type=802-3-ethernet
llmnr=2
mdns=2

[ipv4]
method=manual
address=${HA_CIDR};${GATEWAY}
dns=${HA_DNS};

[ipv6]
addr-gen-mode=stable-privacy
method=auto
EOF

    chmod 600 "$network_file"

    echo
    echo "Injiziere statische Netzwerkkonfiguration in HAOS ..."

    local boot_part
    boot_part="$(
        guestfish --ro -a "$image" <<'EOF' 2>/dev/null
run
findfs-label hassos-boot
EOF
    )"

    boot_part="$(printf '%s\n' "$boot_part" | tail -n1 | tr -d '\r')"

    [[ -n "$boot_part" && "$boot_part" == /dev/* ]] || {
        rm -f "$network_file" "$image"
        die "HAOS Boot-Partition 'hassos-boot' wurde nicht gefunden."
    }

    guestfish --rw -a "$image" <<EOF
run
mount $boot_part /
mkdir-p /CONFIG
mkdir-p /CONFIG/network
upload $network_file /CONFIG/network/my-network
umount-all
EOF

    rm -f "$network_file"

    qm create "$HA_ID" \
        --name homeassistant \
        --ostype l26 \
        --machine q35 \
        --bios ovmf \
        --cpu host \
        --sockets 1 \
        --cores "$HA_CORES" \
        --memory "$HA_MEMORY" \
        --balloon 0 \
        --scsihw virtio-scsi-single \
        --net0 "virtio,bridge=${BRIDGE}" \
        --onboot 1 \
        --agent enabled=1 \
        --description "Home Assistant OS ${haos} | static-ip=${HA_IP} | web=http://${HA_IP}:8123/"

    qm set "$HA_ID" \
        --efidisk0 "${DISK_STORAGE}:0,efitype=4m,pre-enrolled-keys=0"

    qm disk import "$HA_ID" "$image" "$DISK_STORAGE"

    local hadisk
    hadisk="$(
        qm config "$HA_ID" |
        awk -F': ' '/^unused0:/{print $2;exit}'
    )"

    [[ -n "$hadisk" ]] || die "Importierte HAOS-Disk wurde nicht gefunden."

    qm set "$HA_ID" \
        --scsi0 "${hadisk},discard=on,ssd=1,iothread=1"

    # HAOS-Images haben bereits eine feste virtuelle Ausgangsgröße.
    # Auf den gewünschten Wert vergrößern; ein bewusst kleiner eingegebener
    # Wert darf das Image nicht schrumpfen und wird deshalb nur als Wunschwert
    # behandelt, wenn er größer als die importierte HAOS-Disk ist.
    local ha_disk_path=""
    local ha_current_bytes=""
    local ha_current_gb=""

    ha_disk_path="$(pvesm path "$hadisk" 2>/dev/null || true)"

    if [[ -n "$ha_disk_path" && -e "$ha_disk_path" ]]; then
        ha_current_bytes="$(
            qemu-img info --output=json "$ha_disk_path" 2>/dev/null |
            python3 -c '
import json
import sys

try:
    data=json.load(sys.stdin)
    print(int(data.get("virtual-size") or 0))
except Exception:
    print(0)
'
        )"

        if [[ "$ha_current_bytes" =~ ^[0-9]+$ ]] && (( ha_current_bytes > 0 )); then
            ha_current_gb="$(
                python3 - "$ha_current_bytes" <<'PY'
import math
import sys

value=int(sys.argv[1])
print(max(1, math.ceil(value / (1024 ** 3))))
PY
            )"

            if (( HA_DISK > ha_current_gb )); then
                qm disk resize "$HA_ID" scsi0 "${HA_DISK}G"
                ok "Home Assistant System-Disk auf ${HA_DISK} GB vergrößert."
            elif (( HA_DISK < ha_current_gb )); then
                warn "Home Assistant: gewünschte ${HA_DISK} GB liegen unter der HAOS-Imagegröße von ca. ${ha_current_gb} GB. Die Disk bleibt bei der Imagegröße; HAOS-Disks werden nicht verkleinert."
            else
                ok "Home Assistant System-Disk entspricht bereits ca. ${HA_DISK} GB."
            fi
        else
            warn "Home Assistant: aktuelle HAOS-Diskgröße konnte nicht ermittelt werden; versuche Zielgröße ${HA_DISK} GB."
            qm disk resize "$HA_ID" scsi0 "${HA_DISK}G" || true
        fi
    else
        warn "Home Assistant: Storage-Pfad konnte nicht ermittelt werden; versuche Zielgröße ${HA_DISK} GB."
        qm disk resize "$HA_ID" scsi0 "${HA_DISK}G" || true
    fi

    qm set "$HA_ID" --boot order=scsi0

    rm -f "$image"

    qm start "$HA_ID"

    ok "Home Assistant VM $HA_ID gestartet."
    echo
    echo "Statische IP:"
    echo "  $HA_IP"
    echo
    echo "Home Assistant Weboberfläche (HAOS nativ):"
    echo "  http://${HA_IP}:8123/"
    echo "  Hinweis: HAOS nutzt nativ Port 8123; HTTPS/443 benötigt einen Reverse Proxy."
    echo

    echo "Warte kurz auf die Netzwerkschnittstelle ..."

    local network_ready=0
    for _ in $(seq 1 60); do
        if ping -c 1 -W 1 "$HA_IP" >/dev/null 2>&1; then
            network_ready=1
            break
        fi
        sleep 2
    done

    if (( network_ready )); then
        ok "Home Assistant antwortet unter $HA_IP."
    else
        warn "HAOS bootet noch. Der erste Start kann mehrere Minuten dauern."
    fi

    echo
    echo "Weboberfläche:"
    echo "  http://${HA_IP}:8123/"
}


# =============================================================================
# PAPERLESS + OLLAMA
# =============================================================================

prepare_paperless_external_storage_v89() {
    (( PAPERLESS_EXTERNAL_STORAGE )) || return 0

    header "PAPERLESS NAS-SPEICHER VORBEREITEN"

    # V97: Ein unbenutztes Ceph-Repo darf die NFS-Paketinstallation nicht blockieren.
    disable_unused_ceph_repositories_v97

    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq nfs-common >/dev/null

    mkdir -p "$PAPERLESS_NAS_MOUNT"

    local nfs_source="${PAPERLESS_NAS_IP}:${PAPERLESS_NAS_PATH}"
    local fstab_opts="rw,_netdev,nofail,x-systemd.automount,x-systemd.device-timeout=15s,x-systemd.mount-timeout=30s"
    local fstab_line="${nfs_source} ${PAPERLESS_NAS_MOUNT} nfs ${fstab_opts} 0 0"
    local fstab_tmp="/tmp/fstab.paperless.$$"
    local fstab_backup="${BACKUP_ROOT}/fstab-before-paperless-nas-$(date +%Y%m%d-%H%M%S)"

    cp -a /etc/fstab "$fstab_backup"

    # Vorhandene Einträge für genau diesen Mountpunkt ersetzen.
    awk -v mp="$PAPERLESS_NAS_MOUNT" '
        BEGIN { OFS=" " }
        /^[[:space:]]*#/ { print; next }
        NF >= 2 && $2 == mp { next }
        { print }
    ' /etc/fstab > "$fstab_tmp"

    printf '%s\n' "$fstab_line" >> "$fstab_tmp"
    install -m 0644 "$fstab_tmp" /etc/fstab
    rm -f "$fstab_tmp"

    systemctl daemon-reload

    if mountpoint -q "$PAPERLESS_NAS_MOUNT"; then
        local current_source=""
        current_source="$(findmnt -n -o SOURCE --target "$PAPERLESS_NAS_MOUNT" 2>/dev/null || true)"
        if [[ "$current_source" != "$nfs_source" ]]; then
            umount "$PAPERLESS_NAS_MOUNT" 2>/dev/null || true
        fi
    fi

    if ! mountpoint -q "$PAPERLESS_NAS_MOUNT"; then
        mount "$PAPERLESS_NAS_MOUNT" || \
            die "Paperless NAS konnte nicht gemountet werden: ${nfs_source} -> ${PAPERLESS_NAS_MOUNT}. Prüfe NFS-Freigabe und Berechtigungen auf dem NAS."
    fi

    findmnt --target "$PAPERLESS_NAS_MOUNT" >/dev/null 2>&1 || \
        die "Paperless NAS-Mount wurde nach dem Mount nicht gefunden."

    mkdir -p \
        "$PAPERLESS_NAS_MOUNT/$PAPERLESS_DATA_SUBDIR" \
        "$PAPERLESS_NAS_MOUNT/$PAPERLESS_MEDIA_SUBDIR" \
        "$PAPERLESS_NAS_MOUNT/$PAPERLESS_EXPORT_SUBDIR" \
        "$PAPERLESS_NAS_MOUNT/$PAPERLESS_CONSUME_SUBDIR" || \
        die "Paperless-Unterordner konnten auf dem NAS nicht angelegt werden."

    # In einem unprivilegierten LXC entspricht UID/GID 1000 auf Host-Seite
    # standardmäßig 101000. Schreibtest verhindert eine Installation, die erst
    # später beim Dokumentimport an NFS-Rechten scheitert.
    local testfile="${PAPERLESS_NAS_MOUNT}/${PAPERLESS_CONSUME_SUBDIR}/.paperless-write-test.$$"
    if command -v setpriv >/dev/null 2>&1; then
        if ! setpriv --reuid=101000 --regid=101000 --clear-groups \
            sh -c 'touch "$1" && rm -f "$1"' _ "$testfile" 2>/dev/null; then
            warn "NAS ist gemountet, aber UID/GID 101000 kann nicht schreiben."
            warn "Bei Synology NFS bitte die Freigabe so konfigurieren, dass der Proxmox-Host Schreibzugriff hat (Squash/Zuordnung beachten)."
            die "Paperless NAS-Schreibtest fehlgeschlagen: $PAPERLESS_NAS_MOUNT"
        fi
    else
        touch "$testfile" && rm -f "$testfile" || \
            die "Paperless NAS ist nicht beschreibbar: $PAPERLESS_NAS_MOUNT"
    fi

    ok "Paperless NAS eingebunden: ${nfs_source}"
    info "Daten:   ${PAPERLESS_NAS_MOUNT}/${PAPERLESS_DATA_SUBDIR}"
    info "Media:   ${PAPERLESS_NAS_MOUNT}/${PAPERLESS_MEDIA_SUBDIR}"
    info "Export:  ${PAPERLESS_NAS_MOUNT}/${PAPERLESS_EXPORT_SUBDIR}"
    info "Inbox: ${PAPERLESS_NAS_MOUNT}/${PAPERLESS_CONSUME_SUBDIR}"
}

install_paperless() {
    header "PAPERLESS-NGX + OLLAMA INSTALLIEREN"

    prepare_ct_cache_dirs "paperless"
    prepare_paperless_external_storage_v89

    local paperless_external_mp=()
    if (( PAPERLESS_EXTERNAL_STORAGE )); then
        paperless_external_mp=(
            --mp4
            "${PAPERLESS_NAS_MOUNT},mp=/mnt/paperless-storage"
        )
    fi

    pct create "$PL_ID" "$TEMPLATE_VOL" \
        --hostname paperless \
        --ostype debian \
        --unprivileged 1 \
        --features nesting=1,keyctl=1 \
        --cores "$PL_CORES" \
        --memory "$PL_MEMORY" \
        --swap 2048 \
        --rootfs "${DISK_STORAGE}:${PL_DISK}" \
        --mp0 "${OLLAMA_CACHE_DIR},mp=/mnt/ollama-cache" \
        --mp1 "${DOCKER_IMAGE_CACHE_DIR},mp=/mnt/docker-image-cache" \
        --mp2 "${CT_APT_ARCHIVES},mp=/var/cache/apt/archives" \
        --mp3 "${CT_APT_LISTS},mp=/var/lib/apt/lists" \
        "${paperless_external_mp[@]}" \
        --net0 "name=eth0,bridge=${BRIDGE},ip=${PAPERLESS_CIDR},gw=${GATEWAY},type=veth" \
        --nameserver "$GATEWAY" \
        --onboot 1 \
        --start 1

    sleep 5

    install_docker_in_ct "$PL_ID"

    # V102: Der Compose-Arbeitsordner muss unabhängig davon existieren,
    # ob Paperless seine Daten lokal oder auf dem NAS speichert.
    # pct push erzeugt fehlende Elternverzeichnisse nicht automatisch.
    pct exec "$PL_ID" -- bash -lc '
        set -Eeuo pipefail
        install -d -m 0755 /opt/paperless
    ' || die "Paperless Arbeitsverzeichnis /opt/paperless konnte nicht angelegt werden."

    if (( PAPERLESS_EXTERNAL_STORAGE )); then
        pct exec "$PL_ID" -- bash -lc '
            set -Eeuo pipefail
            test -d /mnt/paperless-storage
            command -v setpriv >/dev/null 2>&1
            testfile="/mnt/paperless-storage/'"$PAPERLESS_CONSUME_SUBDIR"'/.paperless-lxc-write-test.$$"
            setpriv --reuid=1000 --regid=1000 --clear-groups sh -c '"'"'touch "$1" && rm -f "$1"'"'"' _ "$testfile"
        ' || die "Paperless NAS ist im unprivilegierten LXC für UID/GID 1000 nicht beschreibbar."
    fi

    local paperless_data_path="/opt/paperless/data"
    local paperless_media_path="/opt/paperless/media"
    local paperless_export_path="/opt/paperless/export"
    local paperless_consume_path="/opt/paperless/consume"
    local paperless_consumer_polling_interval="0"

    if (( PAPERLESS_EXTERNAL_STORAGE )); then
        paperless_data_path="/mnt/paperless-storage/${PAPERLESS_DATA_SUBDIR}"
        paperless_media_path="/mnt/paperless-storage/${PAPERLESS_MEDIA_SUBDIR}"
        paperless_export_path="/mnt/paperless-storage/${PAPERLESS_EXPORT_SUBDIR}"
        paperless_consume_path="/mnt/paperless-storage/${PAPERLESS_CONSUME_SUBDIR}"

        # NFS/SMB liefern Dateisystem-Ereignisse nicht zuverlässig an inotify.
        # Paperless soll die NAS-Inbox deshalb aktiv abfragen.
        paperless_consumer_polling_interval="10"
    else
        pct exec "$PL_ID" -- \
            mkdir -p \
            /opt/paperless/data \
            /opt/paperless/media \
            /opt/paperless/export \
            /opt/paperless/consume
    fi

    cat > /tmp/paperless-compose.yml <<EOF
services:

  broker:
    image: redis:7
    restart: unless-stopped
    volumes:
      - redisdata:/data

  database:
    image: postgres:17
    restart: unless-stopped
    volumes:
      - pgdata:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: paperless
      POSTGRES_USER: paperless
      POSTGRES_PASSWORD: "${DB_PASS}"

  ollama:
    image: ollama/ollama:latest
    container_name: paperless-ollama
    restart: unless-stopped
    volumes:
      - /mnt/ollama-cache:/root/.ollama
    environment:
      OLLAMA_KEEP_ALIVE: "10m"
      OLLAMA_MAX_LOADED_MODELS: "1"
      OLLAMA_NUM_PARALLEL: "1"

  webserver:
    image: ghcr.io/paperless-ngx/paperless-ngx:latest
    restart: unless-stopped

    depends_on:
      - broker
      - database
      - ollama

    ports:
      - "127.0.0.1:8000:8000"

    volumes:
      - ${paperless_data_path}:/usr/src/paperless/data
      - ${paperless_media_path}:/usr/src/paperless/media
      - ${paperless_export_path}:/usr/src/paperless/export
      - ${paperless_consume_path}:/usr/src/paperless/consume

    environment:
      PAPERLESS_REDIS: redis://broker:6379

      PAPERLESS_DBHOST: database
      PAPERLESS_DBNAME: paperless
      PAPERLESS_DBUSER: paperless
      PAPERLESS_DBPASS: "${DB_PASS}"

      PAPERLESS_TIME_ZONE: Europe/Berlin
      PAPERLESS_OCR_LANGUAGE: deu
      PAPERLESS_OCR_LANGUAGES: "deu eng"

      # V138: Bei NAS/NFS/SMB positive Polling-Zeit, lokal weiterhin 0/inotify.
      PAPERLESS_CONSUMER_POLLING_INTERVAL: "${paperless_consumer_polling_interval}"

      PAPERLESS_ADMIN_USER: "${PAPERLESS_USER}"
      PAPERLESS_ADMIN_PASSWORD: "${PAPERLESS_PASS}"
      PAPERLESS_ADMIN_MAIL: admin@localhost
      PAPERLESS_SECRET_KEY: "${SECRET_KEY}"

      # V137: vollständige Paperless-HTTPS-/CSRF-/allauth-Konfiguration hinter nginx.
      PAPERLESS_URL: "https://${PAPERLESS_IP}"
      PAPERLESS_PROXY_SSL_HEADER: '["HTTP_X_FORWARDED_PROTO", "https"]'
      PAPERLESS_TRUSTED_PROXIES: "127.0.0.1"
      PAPERLESS_ALLAUTH_TRUSTED_CLIENT_IP_HEADER: "X-Real-IP"

      USERMAP_UID: 1000
      USERMAP_GID: 1000

      # Native Paperless-ngx AI
      PAPERLESS_AI_ENABLED: "true"
      PAPERLESS_AI_LLM_BACKEND: "ollama"
      PAPERLESS_AI_LLM_ENDPOINT: "http://ollama:11434"
      PAPERLESS_AI_LLM_MODEL: "${OLLAMA_MODEL}"
      PAPERLESS_AI_LLM_ALLOW_INTERNAL_ENDPOINTS: "true"
      PAPERLESS_AI_LLM_OUTPUT_LANGUAGE: "de"
      PAPERLESS_AI_LLM_CONTEXT_SIZE: "8192"
      PAPERLESS_AI_LLM_REQUEST_TIMEOUT: "600"

      # RAG / Similar Documents / Document Chat
      PAPERLESS_AI_LLM_EMBEDDING_BACKEND: "ollama"
      PAPERLESS_AI_LLM_EMBEDDING_ENDPOINT: "http://ollama:11434"
      PAPERLESS_AI_LLM_EMBEDDING_MODEL: "${OLLAMA_EMBED_MODEL}"

volumes:
  redisdata:
  pgdata:
EOF

    pct push \
        "$PL_ID" \
        /tmp/paperless-compose.yml \
        /opt/paperless/docker-compose.yml

    # V102: Nicht erst beim docker-compose-Aufruf merken, dass Push/Ziel fehlt.
    pct exec "$PL_ID" -- bash -lc '
        set -Eeuo pipefail
        test -s /opt/paperless/docker-compose.yml
        cd /opt/paperless
        docker compose config >/dev/null
    ' || die "Paperless docker-compose.yml fehlt oder ist ungültig."

    rm -f /tmp/paperless-compose.yml

    docker_compose_deploy_in_ct_v107 "$PL_ID" "/opt/paperless" "ollama"

    echo "Warte auf Ollama ..."

    local ready=0
    for _ in $(seq 1 60); do
        if pct exec "$PL_ID" -- \
            docker exec paperless-ollama ollama list >/dev/null 2>&1; then
            ready=1
            break
        fi
        sleep 2
    done

    (( ready == 1 )) || die "Ollama ist nicht gestartet."

    echo
    echo "Persistenter Ollama-Modell-Cache:"
    echo "  $OLLAMA_CACHE_DIR"
    echo

    echo "Prüfe LLM-Modell auf Aktualität:"
    echo "  $OLLAMA_MODEL"
    echo "Vorhandene Layer werden aus /home/img/ollama wiederverwendet."

    pct exec "$PL_ID" -- \
        docker exec paperless-ollama ollama pull "$OLLAMA_MODEL"

    echo
    echo "Prüfe Embedding-Modell auf Aktualität:"
    echo "  $OLLAMA_EMBED_MODEL"

    pct exec "$PL_ID" -- \
        docker exec paperless-ollama ollama pull "$OLLAMA_EMBED_MODEL"

    docker_compose_up_in_ct_v107 "$PL_ID" "/opt/paperless"

    configure_lxc_web_standard_ports_v65 "$PL_ID" "Paperless-ngx" "http" "8000"
    verify_web_v107 "Paperless-ngx" "https://${PAPERLESS_IP}/" 120

    # V138: Neuinstallation gilt erst als erfolgreich, wenn der laufende
    # Container, Django und nginx die erwartete Proxy-Konfiguration verwenden.
    verify_paperless_proxy_v138 "$PL_ID" "$PAPERLESS_IP" "$paperless_consumer_polling_interval" || \
        die "Paperless Reverse-Proxy-/Login-/Inbox-Konfiguration ist unvollständig."

    ok "Paperless + Ollama installiert."
    echo "Paperless: https://${PAPERLESS_IP}/"
    if (( PAPERLESS_EXTERNAL_STORAGE )); then
        echo "NAS: ${PAPERLESS_NAS_IP}:${PAPERLESS_NAS_PATH}"
        echo "  Daten:   ${PAPERLESS_DATA_SUBDIR}"
        echo "  Media:   ${PAPERLESS_MEDIA_SUBDIR}"
        echo "  Export:  ${PAPERLESS_EXPORT_SUBDIR}"
        echo "  Inbox:   ${PAPERLESS_CONSUME_SUBDIR}"
    fi
}

# =============================================================================
# V138 · PAPERLESS HTTPS / CSRF / ALLAUTH / NAS-INBOX
# =============================================================================

verify_paperless_proxy_v138() {
    local ctid="$1"
    local ip="$2"
    local expected_polling="${3:-}"
    local env_out=""
    local django_out=""

    [[ "$ctid" =~ ^[0-9]+$ ]] || {
        warn "Paperless V138: ungültige CT-ID: $ctid"
        return 1
    }

    [[ -n "$ip" ]] || {
        warn "Paperless V138: erwartete IP fehlt."
        return 1
    }

    pct exec "$ctid" -- bash -lc '
        set -Eeuo pipefail
        cd /opt/paperless
        docker compose config -q
    ' || {
        warn "Paperless V138: docker compose config ist ungültig."
        return 1
    }

    if ! pct exec "$ctid" -- bash -lc '
        set -Eeuo pipefail
        cd /opt/paperless

        for _ in $(seq 1 60); do
            cid="$(docker compose ps -q webserver)"

            if [[ -n "$cid" ]]; then
                state="$(
                    docker inspect \
                        --format "{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}" \
                        "$cid" 2>/dev/null || true
                )"

                if [[ "$state" == "healthy" || "$state" == "running" ]]; then
                    exit 0
                fi
            fi

            sleep 2
        done

        docker compose ps
        exit 1
    '; then
        warn "Paperless V138: Webserver wurde nicht healthy."
        return 1
    fi

    env_out="$(
        pct exec "$ctid" -- bash -lc '
            set -Eeuo pipefail
            cd /opt/paperless
            docker compose exec -T webserver env
        '
    )" || {
        warn "Paperless V138: Webserver-Environment konnte nicht gelesen werden."
        return 1
    }

    grep -Fxq "PAPERLESS_URL=https://${ip}" <<<"$env_out" || {
        warn "Paperless V138: PAPERLESS_URL fehlt/falsch."
        return 1
    }

    grep -Fxq 'PAPERLESS_PROXY_SSL_HEADER=["HTTP_X_FORWARDED_PROTO", "https"]' <<<"$env_out" || {
        warn "Paperless V138: PAPERLESS_PROXY_SSL_HEADER fehlt/falsch."
        return 1
    }

    grep -Fxq 'PAPERLESS_TRUSTED_PROXIES=127.0.0.1' <<<"$env_out" || {
        warn "Paperless V138: PAPERLESS_TRUSTED_PROXIES fehlt/falsch."
        return 1
    }

    grep -Fxq 'PAPERLESS_ALLAUTH_TRUSTED_CLIENT_IP_HEADER=X-Real-IP' <<<"$env_out" || {
        warn "Paperless V138: allauth Client-IP-Header fehlt/falsch."
        return 1
    }

    if [[ -n "$expected_polling" ]]; then
        grep -Fxq "PAPERLESS_CONSUMER_POLLING_INTERVAL=${expected_polling}" <<<"$env_out" || {
            warn "Paperless V138: Consumer-Polling-Intervall fehlt/falsch."
            return 1
        }
    fi

    if [[ "$expected_polling" == "10" ]]; then
        pct exec "$ctid" -- bash -lc '
            set -Eeuo pipefail
            cd /opt/paperless
            docker compose exec -T webserver sh -lc "
                test -d /usr/src/paperless/consume
                test -r /usr/src/paperless/consume
                test -w /usr/src/paperless/consume
            "
        ' || {
            warn "Paperless V138: NAS-Inbox ist im laufenden Container nicht les-/schreibbar."
            return 1
        }
    fi

    django_out="$(
        pct exec "$ctid" -- bash -lc '
            set -Eeuo pipefail
            cd /opt/paperless
            docker compose exec -T webserver \
                python manage.py shell -c '\''
from django.conf import settings
print("CSRF=" + "|".join(settings.CSRF_TRUSTED_ORIGINS))
print("PROXY=" + repr(settings.SECURE_PROXY_SSL_HEADER))
'\''
        '
    )" || {
        warn "Paperless V138: Django-Einstellungen konnten nicht geprüft werden."
        return 1
    }

    grep -Fq "https://${ip}" <<<"$django_out" || {
        warn "Paperless V138: externe HTTPS-Adresse fehlt in CSRF_TRUSTED_ORIGINS."
        printf '%s\n' "$django_out" >&2
        return 1
    }

    grep -Fq "HTTP_X_FORWARDED_PROTO" <<<"$django_out" || {
        warn "Paperless V138: SECURE_PROXY_SSL_HEADER nicht aktiv."
        printf '%s\n' "$django_out" >&2
        return 1
    }

    pct exec "$ctid" -- \
        grep -Fq 'proxy_set_header X-Real-IP $remote_addr;' \
        /etc/nginx/conf.d/pve-master-standard-web.conf || {
        warn "Paperless V138: nginx setzt X-Real-IP nicht."
        return 1
    }

    pct exec "$ctid" -- \
        grep -Fq 'proxy_set_header X-Forwarded-Proto https;' \
        /etc/nginx/conf.d/pve-master-standard-web.conf || {
        warn "Paperless V138: nginx setzt X-Forwarded-Proto=https nicht."
        return 1
    }

    ok "Paperless V138: HTTPS, CSRF, allauth Client-IP und Inbox-Polling geprüft."
}


repair_existing_paperless_proxy_v138() {
    command -v pct >/dev/null 2>&1 || return 0

    local ctid=""
    local ip=""
    local fix_script=""
    local expected_polling="0"

    while read -r candidate; do
        [[ "$candidate" =~ ^[0-9]+$ ]] || continue

        if [[ "$(
            pct config "$candidate" 2>/dev/null |
            awk -F': ' '/^hostname:/ {print tolower($2); exit}'
        )" == "paperless" ]]; then
            ctid="$candidate"
            break
        fi
    done < <(pct list 2>/dev/null | awk 'NR>1 {print $1}')

    [[ -n "$ctid" ]] || {
        info "Paperless V138: kein vorhandener Paperless-LXC gefunden."
        return 0
    }

    if ! pct status "$ctid" 2>/dev/null | grep -q 'status: running'; then
        pct start "$ctid"
        sleep 4
    fi

    ip="$(
        pct exec "$ctid" -- hostname -I 2>/dev/null |
        tr ' ' '\n' |
        grep -E '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)' |
        head -n1 || true
    )"

    [[ -n "$ip" ]] || {
        warn "Paperless V138: IP von CT ${ctid} konnte nicht ermittelt werden."
        return 1
    }

    pct exec "$ctid" -- test -s /opt/paperless/docker-compose.yml || {
        warn "Paperless V138: /opt/paperless/docker-compose.yml fehlt in CT ${ctid}."
        return 1
    }

    if pct exec "$ctid" --         grep -Fq '/mnt/paperless-storage/' /opt/paperless/docker-compose.yml; then
        expected_polling="10"
    fi

    fix_script="/tmp/paperless-v138-${ctid}.py"

    cat > "$fix_script" <<'PYV138'
from pathlib import Path
import os
import re

path = Path("/opt/paperless/docker-compose.yml")
text = path.read_text(encoding="utf-8")
ip = os.environ["PAPERLESS_PUBLIC_IP"].strip()

external_consume = (
    "/mnt/paperless-storage/" in text
    and ":/usr/src/paperless/consume" in text
)

wanted = {
    "PAPERLESS_URL": f'"https://{ip}"',
    "PAPERLESS_PROXY_SSL_HEADER": """'["HTTP_X_FORWARDED_PROTO", "https"]'""",
    "PAPERLESS_TRUSTED_PROXIES": '"127.0.0.1"',
    "PAPERLESS_ALLAUTH_TRUSTED_CLIENT_IP_HEADER": '"X-Real-IP"',
    "PAPERLESS_CONSUMER_POLLING_INTERVAL": '"10"' if external_consume else '"0"',
}

for key in wanted:
    text = re.sub(
        rf"(?m)^\s{{6}}{re.escape(key)}:\s*.*\n?",
        "",
        text,
    )

text = re.sub(
    r"(?m)^\s{6}PAPERLESS_CSRF_TRUSTED_ORIGINS:\s*.*\n?",
    "",
    text,
)

anchor = re.search(
    r'(?m)^(\s{6}PAPERLESS_SECRET_KEY:\s*.*)$',
    text,
)

if not anchor:
    raise SystemExit(
        "FEHLER: PAPERLESS_SECRET_KEY-Anker nicht gefunden."
    )

block = "\n".join(
    f"      {key}: {value}"
    for key, value in wanted.items()
)

text = (
    text[:anchor.end()]
    + "\n\n"
    + block
    + text[anchor.end():]
)

path.write_text(text, encoding="utf-8")
PYV138

    pct push \
        "$ctid" \
        "$fix_script" \
        /root/paperless-v138.py \
        -perms 0700 \
        >/dev/null

    rm -f "$fix_script"

    if ! pct exec "$ctid" -- \
        env PAPERLESS_PUBLIC_IP="$ip" \
        python3 /root/paperless-v138.py; then
        warn "Paperless V138: Compose-Migration fehlgeschlagen."
        return 1
    fi

    pct exec "$ctid" -- rm -f /root/paperless-v138.py >/dev/null 2>&1 || true

    if ! pct exec "$ctid" -- bash -lc '
        set -Eeuo pipefail
        cd /opt/paperless
        docker compose config -q
        docker compose up -d --force-recreate webserver
    '; then
        warn "Paperless V138: Webserver-Recreate fehlgeschlagen."
        return 1
    fi

    verify_paperless_proxy_v138 "$ctid" "$ip" "$expected_polling"
}


# =============================================================================
# PI-HOLE + UNBOUND
# =============================================================================

install_pihole_standard_lists_v82() {
    local ct_id="${1:-$PH_ID}"
    local host_script="/tmp/pihole-standardlisten-v82-${ct_id}.sh"
    local ct_script="/root/pihole-standardlisten-v82.sh"

    cat > "$host_script" <<'__PIHOLE_STANDARDLISTEN_V82__'
#!/usr/bin/env bash
set -Eeuo pipefail

DB="/opt/pihole/etc-pihole/gravity.db"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="/opt/pihole/etc-pihole/gravity.db.pre-v82-${STAMP}"

BLOCK_PRO="https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.txt"
BLOCK_TIF="https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/tif.txt"
ALLOW_TOBI="https://raw.githubusercontent.com/Technox90/homeatic/refs/heads/main/pihole/allowlist/allowlist.txt"
ALLOW_REFERRAL="https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/whitelist-referral-native.txt"
OLD_ALLOW_TOBI="https://raw.githubusercontent.com/Technox90/projekte/refs/heads/main/tobi-whitelist"

echo "============================================================"
echo " PI-HOLE STANDARDLISTEN V115"
echo "============================================================"
echo

docker ps --format '{{.Names}}' | grep -qx pihole || {
    echo "FEHLER: Docker-Container 'pihole' läuft nicht."
    exit 1
}

echo "Warte auf gravity.db ..."

for i in $(seq 1 45); do
    if [[ -s "$DB" ]]; then
        break
    fi

    if (( i == 10 )); then
        docker exec pihole pihole -g >/dev/null 2>&1 || true
    fi

    sleep 2
done

[[ -s "$DB" ]] || {
    echo "FEHLER: gravity.db wurde nicht gefunden: $DB"
    exit 1
}

if ! docker exec pihole pihole-FTL sqlite3 /etc/pihole/gravity.db \
    "PRAGMA table_info(adlist);" \
    | grep -q '|type|'; then
    echo "FEHLER: Pi-hole gravity.db unterstützt noch keine"
    echo "abonnierten Allowlisten (adlist.type fehlt)."
    echo "Für diese V82-Konfiguration wird Pi-hole v6 benötigt."
    exit 1
fi

cp -a "$DB" "$BACKUP"

echo "Backup:"
echo "  $BACKUP"
echo

SQL_FILE="/tmp/pihole-standardlisten-v82.sql"

cat > "$SQL_FILE" <<SQL
.timeout 30000
PRAGMA foreign_keys=ON;
BEGIN TRANSACTION;

INSERT INTO adlist (
    address,
    enabled,
    comment,
    type
)
VALUES (
    '${BLOCK_PRO}',
    1,
    'V82 · HaGeZi Pro Blocklist',
    0
)
ON CONFLICT(address,type) DO UPDATE SET
    enabled=1,
    comment=excluded.comment,
    date_modified=cast(strftime('%s','now') as int);

INSERT INTO adlist (
    address,
    enabled,
    comment,
    type
)
VALUES (
    '${BLOCK_TIF}',
    1,
    'V82 · HaGeZi TIF Threat Intelligence Feeds',
    0
)
ON CONFLICT(address,type) DO UPDATE SET
    enabled=1,
    comment=excluded.comment,
    date_modified=cast(strftime('%s','now') as int);

INSERT INTO adlist (
    address,
    enabled,
    comment,
    type
)
VALUES (
    '${ALLOW_TOBI}',
    1,
    'V115 · Technox90 Homeatic Allowlist',
    1
)
ON CONFLICT(address,type) DO UPDATE SET
    enabled=1,
    comment=excluded.comment,
    date_modified=cast(strftime('%s','now') as int);

INSERT INTO adlist (
    address,
    enabled,
    comment,
    type
)
VALUES (
    '${ALLOW_REFERRAL}',
    1,
    'V82 · HaGeZi Allowlist Referral Native',
    1
)
ON CONFLICT(address,type) DO UPDATE SET
    enabled=1,
    comment=excluded.comment,
    date_modified=cast(strftime('%s','now') as int);

-- Alten, früher verwendeten Technox90/projekte-Eintrag entfernen.
DELETE FROM adlist
WHERE address = '${OLD_ALLOW_TOBI}'
  AND type = 1;

COMMIT;
SQL

# V126: docker exec muss STDIN mit -i offen halten. Ohne -i konnte SQLite
# erfolgreich starten, ohne die SQL-INSERTs tatsächlich zu erhalten.
docker exec -i pihole \
    pihole-FTL sqlite3 /etc/pihole/gravity.db \
    < "$SQL_FILE"

LIST_COUNT="$(
    docker exec pihole \
        pihole-FTL sqlite3 /etc/pihole/gravity.db \
        "SELECT COUNT(*) FROM adlist
         WHERE (address='${BLOCK_PRO}' AND type=0)
            OR (address='${BLOCK_TIF}' AND type=0)
            OR (address='${ALLOW_TOBI}' AND type=1)
            OR (address='${ALLOW_REFERRAL}' AND type=1);" \
        2>/dev/null |
    tr -d '[:space:]'
)"

if [[ "$LIST_COUNT" != "4" ]]; then
    echo "FEHLER: Standardlisten wurden nicht vollständig in gravity.db eingetragen."
    echo "Erwartet: 4 · Gefunden: ${LIST_COUNT:-0}"
    exit 1
fi

rm -f "$SQL_FILE"

echo "Listen eingetragen und verifiziert (4/4)."
echo
echo "Aktualisiere Gravity ..."
echo

if ! docker exec pihole pihole -g; then
    echo
    echo "FEHLER: pihole -g ist fehlgeschlagen."
    echo "Die Datenbank wurde vor der Änderung gesichert."
    echo "Backup: $BACKUP"
    exit 1
fi

echo
echo "============================================================"
echo " EINGETRAGENE LISTEN"
echo "============================================================"

docker exec pihole pihole-FTL sqlite3 -header -column \
    /etc/pihole/gravity.db \
    "SELECT
       CASE type
         WHEN 0 THEN 'BLOCK'
         WHEN 1 THEN 'ALLOW'
         ELSE 'TYPE ' || type
       END AS Art,
       enabled AS Aktiv,
       number AS Eintraege,
       invalid_domains AS Ungueltig,
       status AS Status,
       address AS URL
     FROM adlist
     WHERE address IN (
       '${BLOCK_PRO}',
       '${BLOCK_TIF}',
       '${ALLOW_TOBI}',
       '${ALLOW_REFERRAL}'
     )
     ORDER BY type,address;"

echo
echo "Fertig."
__PIHOLE_STANDARDLISTEN_V82__

    chmod +x "$host_script"

    pct push \
        "$ct_id" \
        "$host_script" \
        "$ct_script"

    rm -f "$host_script"

    if pct exec "$ct_id" -- bash "$ct_script"; then
        pct exec "$ct_id" -- rm -f "$ct_script" 2>/dev/null || true
        ok "Pi-hole Block- und Allowlisten V115 eingetragen."
    else
        warn "Pi-hole Standardlisten konnten nicht vollständig eingerichtet werden."
        warn "CT-Skript bleibt zur Diagnose erhalten: $ct_script"
        return 1
    fi
}

install_pihole_local_dns_v131() {
    local ct_id="${1:-$PH_ID}"
    local host_script="/tmp/pihole-local-dns-v131-${ct_id}.sh"
    local ct_script="/root/pihole-local-dns-v131.sh"

    cat > "$host_script" <<'__PIHOLE_LOCAL_DNS_V131__'
#!/usr/bin/env bash
set -Eeuo pipefail

DNS_URL="https://raw.githubusercontent.com/Technox90/homeatic/refs/heads/main/pihole/dns/custom.list"
CNAME_URL="https://raw.githubusercontent.com/Technox90/homeatic/refs/heads/main/pihole/cname/cname.txt"

DNS_TMP="/tmp/pihole-dns-hosts.txt"
CNAME_TMP="/tmp/pihole-cname.txt"

echo "============================================================"
echo " PI-HOLE V6 LOKALE DNS-/CNAME-EINTRÄGE V131"
echo "============================================================"
echo

docker ps --format '{{.Names}}' | grep -qx pihole || {
    echo "FEHLER: Docker-Container 'pihole' läuft nicht."
    exit 1
}

curl -fsSL --retry 3 --connect-timeout 10 "$DNS_URL" -o "$DNS_TMP"
curl -fsSL --retry 3 --connect-timeout 10 "$CNAME_URL" -o "$CNAME_TMP"

declare -a DNS_ITEMS=()
DNS_FIRST_IP=""
DNS_FIRST_HOST=""

while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    [[ -n "${line//[[:space:]]/}" ]] || continue

    read -r ip host extra <<< "$line"

    [[ -n "${ip:-}" && -n "${host:-}" && -z "${extra:-}" ]] || {
        echo "FEHLER: Ungültige DNS-Zeile: $line"
        exit 1
    }

    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || {
        echo "FEHLER: Ungültige IPv4-Adresse: $ip"
        exit 1
    }

    [[ "$host" =~ ^[A-Za-z0-9._-]+$ ]] || {
        echo "FEHLER: Ungültiger DNS-Hostname: $host"
        exit 1
    }

    DNS_ITEMS+=("\"${ip} ${host}\"")

    if [[ -z "$DNS_FIRST_IP" ]]; then
        DNS_FIRST_IP="$ip"
        DNS_FIRST_HOST="$host"
    fi
done < "$DNS_TMP"

(( ${#DNS_ITEMS[@]} > 0 )) || {
    echo "FEHLER: Keine lokalen DNS-Einträge aus $DNS_URL geladen."
    exit 1
}

DNS_JSON="[$(IFS=,; echo "${DNS_ITEMS[*]}")]"

echo "Setze Pi-hole-v6 dns.hosts ..."
docker exec pihole pihole-FTL --config dns.hosts "$DNS_JSON"

declare -a CNAME_ITEMS=()
CNAME_ALIAS=""
CNAME_TARGET=""

while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    [[ -n "${line//[[:space:]]/}" ]] || continue

    read -r alias target extra <<< "$line"

    [[ -n "${alias:-}" && -n "${target:-}" && -z "${extra:-}" ]] || {
        echo "FEHLER: Ungültige CNAME-Zeile: $line"
        exit 1
    }

    [[ "$alias" =~ ^[A-Za-z0-9._-]+$ && "$target" =~ ^[A-Za-z0-9._-]+$ ]] || {
        echo "FEHLER: Ungültiger CNAME: $alias -> $target"
        exit 1
    }

    CNAME_ITEMS+=("\"${alias},${target}\"")

    if [[ -z "$CNAME_ALIAS" ]]; then
        CNAME_ALIAS="$alias"
        CNAME_TARGET="$target"
    fi
done < "$CNAME_TMP"

(( ${#CNAME_ITEMS[@]} > 0 )) || {
    echo "FEHLER: Keine CNAME-Einträge aus $CNAME_URL geladen."
    exit 1
}

CNAME_JSON="[$(IFS=,; echo "${CNAME_ITEMS[*]}")]"
docker exec pihole pihole-FTL --config dns.cnameRecords "$CNAME_JSON"

rm -f "$DNS_TMP" "$CNAME_TMP"

docker restart pihole >/dev/null

READY=0
for _ in $(seq 1 30); do
    if dig +short @127.0.0.1 "$DNS_FIRST_HOST" A +time=2 2>/dev/null | grep -Fxq "$DNS_FIRST_IP"; then
        READY=1
        break
    fi
    sleep 2
done

(( READY == 1 )) || {
    echo "FEHLER: Lokaler DNS-Eintrag $DNS_FIRST_HOST -> $DNS_FIRST_IP ist nicht auflösbar."
    docker logs --tail 80 pihole 2>/dev/null || true
    exit 1
}

CNAME_RESULT="$(
    dig +short @127.0.0.1 "$CNAME_ALIAS" CNAME +time=2 2>/dev/null |
    head -n1 |
    sed 's/[.]$//'
)"

[[ "$CNAME_RESULT" == "$CNAME_TARGET" ]] || {
    echo "FEHLER: CNAME $CNAME_ALIAS -> $CNAME_TARGET wurde nicht korrekt aktiviert."
    echo "Antwort: ${CNAME_RESULT:-<leer>}"
    exit 1
}

echo "Lokale DNS-Einträge (dns.hosts): ${#DNS_ITEMS[@]}"
echo "CNAME-Einträge: ${#CNAME_ITEMS[@]}"
echo "DNS-Test: $DNS_FIRST_HOST -> $DNS_FIRST_IP [OK]"
echo "CNAME-Test: $CNAME_ALIAS -> $CNAME_TARGET [OK]"
__PIHOLE_LOCAL_DNS_V131__

    chmod +x "$host_script"

    pct push \
        "$ct_id" \
        "$host_script" \
        "$ct_script"

    rm -f "$host_script"

    if pct exec "$ct_id" -- bash "$ct_script"; then
        pct exec "$ct_id" -- rm -f "$ct_script" 2>/dev/null || true
        ok "Pi-hole-v6 lokale DNS- und CNAME-Einträge eingerichtet."
    else
        warn "Pi-hole lokale DNS-/CNAME-Einträge konnten nicht vollständig eingerichtet werden."
        warn "CT-Skript bleibt zur Diagnose erhalten: $ct_script"
        return 1
    fi
}

install_pihole_dns_sync_v131() {
    local ct_id="${1:-$PH_ID}"
    local sync_dir="/etc/pve-pihole-dns-sync"
    local helper="/usr/local/sbin/pve-pihole-dns-sync"
    local base_file="${sync_dir}/custom.list.base"
    local base_url="https://raw.githubusercontent.com/Technox90/homeatic/refs/heads/main/pihole/dns/custom.list"

    header "PI-HOLE V6 DNS-SYNC · PROXMOX + DASHBOARD"

    mkdir -p "$sync_dir" /var/lib/pve-sensor-dashboard-web /var/lib/pve-pihole-dns-sync
    chmod 755 "$sync_dir" /var/lib/pve-pihole-dns-sync

    if ! curl -fsSL --retry 3 --connect-timeout 10 "$base_url" -o "${base_file}.tmp"; then
        warn "GitHub-DNS-Basis konnte nicht geladen werden."
        : > "${base_file}.tmp"
    fi

    mv -f "${base_file}.tmp" "$base_file"
    chmod 644 "$base_file"

    cat > "$helper" <<'PY_SYNC'
#!/usr/bin/env python3
import fcntl
import ipaddress
import json
import os
import re
import subprocess
import sys
import time
import unicodedata
from pathlib import Path
from urllib.parse import urlparse

BASE_FILE = Path("/etc/pve-pihole-dns-sync/custom.list.base")
LINKS_FILE = Path("/var/lib/pve-sensor-dashboard-web/links.json")
STATE_FILE = Path("/var/lib/pve-pihole-dns-sync/managed-hosts.json")
LOCK_FILE = Path("/run/lock/pve-pihole-dns-sync.lock")

RFC1918 = (
    ipaddress.ip_network("10.0.0.0/8"),
    ipaddress.ip_network("172.16.0.0/12"),
    ipaddress.ip_network("192.168.0.0/16"),
)

KNOWN = {
    "pve": "pve.lan",
    "proxmox": "pve.lan",
    "homeassistant": "homeassistant.lan",
    "home assistant": "homeassistant.lan",
    "ha": "homeassistant.lan",
    "paperless": "paperless.lan",
    "paperless ngx": "paperless.lan",
    "paperless-ngx": "paperless.lan",
    "pihole": "pihole.lan",
    "pi-hole": "pihole.lan",
    "netalertx": "netalert.lan",
    "netalert": "netalert.lan",
    "uptime": "uptime.lan",
    "uptime kuma": "uptime.lan",
    "stirling": "pdf.lan",
    "stirling pdf": "pdf.lan",
    "speedtest": "speedtest.lan",
    "speedtest tracker": "speedtest.lan",
    "scrutiny": "scrutiny.lan",
    "pve-ups": "ups.lan",
    "pve ups": "ups.lan",
    "ups": "ups.lan",
}

def run(args, timeout=8):
    try:
        return subprocess.run(
            args,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
            check=False,
        )
    except Exception as exc:
        return subprocess.CompletedProcess(args, 1, "", str(exc))

def out(args, timeout=8):
    return run(args, timeout).stdout.strip()

def private_ipv4(value):
    try:
        ip = ipaddress.ip_address(str(value or "").split("/", 1)[0].strip())
    except Exception:
        return None
    if ip.version == 4 and any(ip in net for net in RFC1918):
        return str(ip)
    return None

def first_private(text):
    for token in re.split(r"[\s,;]+", text or ""):
        ip = private_ipv4(token)
        if ip:
            return ip
    return None

def normalized_key(value):
    text = unicodedata.normalize("NFKD", str(value or ""))
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    text = text.lower().replace("_", " ").strip()
    return re.sub(r"\s+", " ", text)

def dns_name(value):
    key = normalized_key(value)
    if key in KNOWN:
        return KNOWN[key]
    slug = re.sub(r"[^a-z0-9]+", "-", key).strip("-")
    if slug.endswith("-lan"):
        slug = slug[:-4]
    return (slug[:55] + ".lan") if slug else None

def find_pihole_ct():
    for conf in sorted(Path("/etc/pve/lxc").glob("*.conf")):
        try:
            text = conf.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        if re.search(r"(?m)^hostname:\s*pihole\s*$", text):
            return conf.stem
    return None

def parse_dns_hosts(raw):
    raw = re.sub(r"\x1b\[[0-9;]*m", "", raw or "").strip()
    if not raw:
        return []
    try:
        data = json.loads(raw)
    except Exception:
        return []
    if not isinstance(data, list):
        return []
    return [str(x).strip() for x in data if str(x).strip()]

LOCK_FILE.parent.mkdir(parents=True, exist_ok=True)
lock = LOCK_FILE.open("w")
try:
    fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
except BlockingIOError:
    sys.exit(0)

ph_id = find_pihole_ct()
if not ph_id:
    print("[HINWEIS] Pi-hole-LXC nicht gefunden; kein DNS-Sync.")
    sys.exit(0)

if "status: running" not in out(["pct", "status", ph_id], 3).lower():
    print(f"[HINWEIS] Pi-hole-LXC {ph_id} läuft nicht; kein DNS-Sync.")
    sys.exit(0)

records = {}
seq = 0

def put(host, ip, priority, source):
    global seq
    host = str(host or "").strip().lower().rstrip(".")
    ip = private_ipv4(ip)
    if not host or not ip:
        return
    if "." not in host:
        host += ".lan"
    seq += 1
    current = records.get(host)
    if (
        current is None
        or priority > current["priority"]
        or (priority == current["priority"] and seq >= current["seq"])
    ):
        records[host] = {
            "ip": ip,
            "priority": priority,
            "source": source,
            "seq": seq,
        }

# 1) GitHub-Fallback.
if BASE_FILE.is_file():
    for raw in BASE_FILE.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        parts = line.split()
        if len(parts) >= 2:
            put(parts[1], parts[0], 10, "github")

# 2) Dashboard: ausschließlich private IPv4-Ziele.
try:
    dashboard = json.loads(LINKS_FILE.read_text(encoding="utf-8"))
except Exception:
    dashboard = []

if isinstance(dashboard, list):
    for item in dashboard:
        if not isinstance(item, dict):
            continue
        if item.get("type", "link") != "link" or item.get("id") == "router":
            continue
        name = str(item.get("name", "")).strip()
        url = str(item.get("url", "")).strip()
        try:
            parsed = urlparse(url if "://" in url else "http://" + url)
            ip = private_ipv4(parsed.hostname)
        except Exception:
            ip = None
        host = dns_name(name)
        if host and ip:
            put(host, ip, 20, "dashboard")

# 3) Proxmox-Host.
route = out(["ip", "-4", "route", "get", "1.1.1.1"], 3)
match = re.search(r"\bsrc\s+(\d+\.\d+\.\d+\.\d+)", route)
if match:
    put("pve.lan", match.group(1), 40, "proxmox-host")

# 4) LXC.
for conf in sorted(Path("/etc/pve/lxc").glob("*.conf")):
    ctid = conf.stem
    try:
        text = conf.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        continue
    hm = re.search(r"(?m)^hostname:\s*(\S+)\s*$", text)
    guest_name = hm.group(1) if hm else f"ct-{ctid}"
    host = dns_name(guest_name)
    if not host:
        continue

    ip = None
    if "status: running" in out(["pct", "status", ctid], 2).lower():
        ip = first_private(out(["pct", "exec", ctid, "--", "hostname", "-I"], 4))

    if not ip:
        nm = re.search(r"(?m)^net\d+:.*?\bip=([^,\s]+)", text)
        if nm:
            ip = private_ipv4(nm.group(1))

    if ip:
        put(host, ip, 30, f"lxc:{ctid}")

# 5) QEMU/VM über Guest Agent.
for conf in sorted(Path("/etc/pve/qemu-server").glob("*.conf")):
    vmid = conf.stem
    try:
        text = conf.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        continue
    nm = re.search(r"(?m)^name:\s*(\S+)\s*$", text)
    guest_name = nm.group(1) if nm else f"vm-{vmid}"
    host = dns_name(guest_name)
    if not host:
        continue

    raw = out(["qm", "guest", "cmd", vmid, "network-get-interfaces"], 5)
    ip = None
    if raw:
        try:
            stack = [json.loads(raw)]
            while stack and not ip:
                current = stack.pop()
                if isinstance(current, dict):
                    candidate = private_ipv4(current.get("ip-address"))
                    if candidate:
                        ip = candidate
                        break
                    stack.extend(current.values())
                elif isinstance(current, list):
                    stack.extend(current)
        except Exception:
            pass

    if ip:
        put(host, ip, 30, f"qemu:{vmid}")

if not records:
    print("FEHLER: Keine verwalteten DNS-Einträge ermittelt.", file=sys.stderr)
    sys.exit(1)

# Aktuelle Pi-hole-v6 Local-DNS-Einträge direkt aus dns.hosts lesen.
current_cmd = [
    "pct", "exec", ph_id, "--",
    "docker", "exec", "pihole",
    "pihole-FTL", "--config", "dns.hosts",
]
current_result = run(current_cmd, 10)
if current_result.returncode != 0:
    print("FEHLER: Pi-hole dns.hosts konnte nicht gelesen werden.", file=sys.stderr)
    print(current_result.stderr.strip(), file=sys.stderr)
    sys.exit(1)

current_hosts = parse_dns_hosts(current_result.stdout)

try:
    old_managed = set(json.loads(STATE_FILE.read_text(encoding="utf-8")))
except Exception:
    old_managed = set()

new_managed = set(records)
replace_hosts = old_managed | new_managed

# Manuelle Pi-hole-Einträge erhalten, sofern sie nicht denselben Hostnamen
# wie ein von NodeZero verwalteter Datensatz verwenden.
preserved = []
for entry in current_hosts:
    parts = entry.split()
    if len(parts) < 2:
        continue
    names = {x.lower().rstrip(".") for x in parts[1:]}
    if names & replace_hosts:
        continue
    preserved.append(entry)

managed_entries = [
    f"{records[host]['ip']} {host}"
    for host in sorted(records)
]
final_hosts = preserved + managed_entries

if final_hosts != current_hosts:
    payload = json.dumps(final_hosts, ensure_ascii=False, separators=(",", ":"))
    set_result = run(
        [
            "pct", "exec", ph_id, "--",
            "docker", "exec", "pihole",
            "pihole-FTL", "--config", "dns.hosts", payload,
        ],
        20,
    )
    if set_result.returncode != 0:
        print("FEHLER: Pi-hole dns.hosts konnte nicht aktualisiert werden.", file=sys.stderr)
        print(set_result.stderr.strip(), file=sys.stderr)
        sys.exit(1)

STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
STATE_FILE.write_text(
    json.dumps(sorted(new_managed), ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
STATE_FILE.chmod(0o600)

print(
    f"[OK] Pi-hole-v6 DNS-Sync: {len(managed_entries)} automatisch verwaltete "
    f"+ {len(preserved)} manuelle Einträge."
)

# Echtes DNS prüfen.
for probe in ("pve.lan", "pihole.lan"):
    expected = records.get(probe, {}).get("ip")
    if not expected:
        continue

    actual = ""
    for _ in range(10):
        answer = out(
            ["pct", "exec", ph_id, "--", "dig", "+short", "@127.0.0.1", probe, "A", "+time=2"],
            5,
        ).splitlines()
        actual = answer[0].strip() if answer else ""
        if actual == expected:
            break
        time.sleep(1)

    if actual == expected:
        print(f"[OK] {probe} -> {actual}")
    else:
        print(
            f"[WARNUNG] {probe}: erwartet {expected}, DNS antwortet {actual or '<leer>'}.",
            file=sys.stderr,
        )
PY_SYNC

    chmod 755 "$helper"

    cat > /etc/systemd/system/pve-pihole-dns-sync.service <<EOF
[Unit]
Description=Synchronize Proxmox and Dashboard IPs to Pi-hole v6 local DNS
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=${helper}
EOF

    cat > /etc/systemd/system/pve-pihole-dns-sync.path <<'EOF'
[Unit]
Description=Watch Dashboard links for Pi-hole DNS synchronization

[Path]
PathChanged=/var/lib/pve-sensor-dashboard-web/links.json
Unit=pve-pihole-dns-sync.service

[Install]
WantedBy=multi-user.target
EOF

    cat > /etc/systemd/system/pve-pihole-dns-sync.timer <<'EOF'
[Unit]
Description=Periodic Pi-hole DNS synchronization

[Timer]
OnBootSec=2min
OnUnitActiveSec=10min
RandomizedDelaySec=20s
Persistent=true
Unit=pve-pihole-dns-sync.service

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable --now pve-pihole-dns-sync.path
    systemctl enable --now pve-pihole-dns-sync.timer

    if systemctl start pve-pihole-dns-sync.service; then
        ok "Pi-hole-v6 DNS-Sync eingerichtet und initial ausgeführt."
    else
        systemctl status pve-pihole-dns-sync.service --no-pager -l || true
        journalctl -u pve-pihole-dns-sync.service -n 80 --no-pager || true
        if (( OPTIMAL_INSTALL )); then
            die "Pi-hole DNS-Sync konnte im Optimalmodus nicht initialisiert werden."
        fi
        warn "Pi-hole DNS-Sync konnte nicht initialisiert werden."
        return 1
    fi

    echo "  Quelle: Proxmox-Gäste > Dashboard > GitHub-Fallback"
    echo "  Pi-hole-v6 Ziel: dns.hosts"
    echo "  Dashboard-Watcher: aktiv"
    echo "  Fallback-Timer: alle 10 Minuten"
}

generate_pihole_app_password_v83() {
    local ip="$1"
    local admin_password="$2"

    PIHOLE_URL="http://${ip}" \
    PIHOLE_ADMIN_PASS="$admin_password" \
    python3 <<'PY'
import json
import os
import sys
import urllib.error
import urllib.request

base = os.environ["PIHOLE_URL"].rstrip("/")
admin = os.environ["PIHOLE_ADMIN_PASS"]

def request(method, path, payload=None, sid=None, timeout=12):
    data = None
    headers = {
        "Accept": "application/json",
        "User-Agent": "Proxmox-Pi-hole-V83/1.0",
    }

    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"

    if sid:
        headers["X-FTL-SID"] = sid

    req = urllib.request.Request(
        base + path,
        data=data,
        headers=headers,
        method=method,
    )

    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            raw = response.read().decode("utf-8")
            return json.loads(raw or "{}")
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(
            f"HTTP {exc.code} bei {path}: {body[:500]}"
        ) from exc

# 1. Normale Web/API-Anmeldung -> echte SID
auth = request(
    "POST",
    "/api/auth",
    {"password": admin},
)

session = auth.get("session") or {}
sid = session.get("sid")

if not session.get("valid") or not sid:
    raise RuntimeError(
        "Pi-hole Web/API-Passwort erzeugt keine gültige SID."
    )

# 2. Pi-hole selbst erzeugt Passwort + passenden Hash
app = request(
    "GET",
    "/api/auth/app",
    sid=sid,
).get("app") or {}

password = app.get("password")
app_hash = app.get("hash")

if not password or not app_hash:
    raise RuntimeError(
        "Pi-hole konnte kein App-Passwort erzeugen."
    )

# 3. Den von Pi-hole erzeugten Hash aktivieren
request(
    "PATCH",
    "/api/config",
    {
        "config": {
            "webserver": {
                "api": {
                    "app_pwhash": app_hash,
                    "app_sudo": False,
                }
            }
        }
    },
    sid=sid,
)

# 4. App-Passwort separat verifizieren
import time

last_error = None

for _ in range(4):
    time.sleep(2)

    try:
        verify = request(
            "POST",
            "/api/auth",
            {"password": password},
        )

        verify_session = verify.get("session") or {}

        if (
            verify_session.get("valid")
            and verify_session.get("sid")
        ):
            print(password)
            break

        last_error = RuntimeError(
            "App-Passwort liefert keine gültige SID."
        )

    except Exception as exc:
        last_error = exc
else:
    raise RuntimeError(
        "Erzeugtes Pi-hole App-Passwort konnte nicht "
        f"verifiziert werden: {last_error}"
    )
PY
}

install_pihole() {
    header "PI-HOLE + UNBOUND INSTALLIEREN"

    prepare_ct_cache_dirs "pihole"

    local root_hints_cache="${PIHOLE_DOWNLOAD_CACHE}/named.root"

    cache_download \
        "https://www.internic.net/domain/named.root" \
        "$root_hints_cache" \
        "Unbound Root-Hints"

    pct create "$PH_ID" "$TEMPLATE_VOL" \
        --hostname pihole \
        --ostype debian \
        --unprivileged 1 \
        --features nesting=1,keyctl=1 \
        --cores "$PH_CORES" \
        --memory "$PH_MEMORY" \
        --swap 512 \
        --rootfs "${DISK_STORAGE}:${PH_DISK}" \
        --mp0 "${DOCKER_IMAGE_CACHE_DIR},mp=/mnt/docker-image-cache" \
        --mp1 "${CT_APT_ARCHIVES},mp=/var/cache/apt/archives" \
        --mp2 "${CT_APT_LISTS},mp=/var/lib/apt/lists" \
        --net0 "name=eth0,bridge=${BRIDGE},ip=${PIHOLE_CIDR},gw=${GATEWAY},type=veth" \
        --nameserver "$GATEWAY" \
        --onboot 1 \
        --start 1

    sleep 5

    install_docker_in_ct "$PH_ID"

    pct exec "$PH_ID" -- bash -lc '
        set -Eeuo pipefail
        export DEBIAN_FRONTEND=noninteractive

        apt-get update
        apt-get install -y unbound unbound-anchor dnsutils curl sqlite3

        systemctl disable --now systemd-resolved 2>/dev/null || true

        mkdir -p /var/lib/unbound

        cat > /etc/unbound/unbound.conf.d/pi-hole.conf <<EOF
server:
    verbosity: 0
    interface: 127.0.0.1
    port: 5335

    do-ip4: yes
    do-udp: yes
    do-tcp: yes

    do-ip6: no
    prefer-ip6: no

    root-hints: "/var/lib/unbound/root.hints"

    harden-glue: yes
    harden-dnssec-stripped: yes
    qname-minimisation: yes
    aggressive-nsec: yes
    prefetch: yes

    edns-buffer-size: 1232

    hide-identity: yes
    hide-version: yes

    private-address: 10.0.0.0/8
    private-address: 172.16.0.0/12
    private-address: 192.168.0.0/16
    private-address: 169.254.0.0/16
    private-address: fd00::/8
    private-address: fe80::/10
EOF

        mkdir -p /opt/pihole/etc-pihole
    '

    pct push \
        "$PH_ID" \
        "$root_hints_cache" \
        /var/lib/unbound/root.hints

    pct exec "$PH_ID" -- bash -lc '
        set -Eeuo pipefail
        chown unbound:unbound /var/lib/unbound/root.hints
        chmod 644 /var/lib/unbound/root.hints
        unbound-checkconf
        systemctl enable unbound
        systemctl restart unbound
        sleep 2
        ss -lntup | grep -qE "127\.0\.0\.1:5335" || {
            echo "FEHLER: Unbound lauscht nach Neustart nicht auf 127.0.0.1:5335." >&2
            systemctl status unbound --no-pager >&2 || true
            exit 1
        }
    '

    cat > /tmp/pihole-compose.yml <<EOF
services:

  pihole:
    image: pihole/pihole:latest
    container_name: pihole
    network_mode: host
    restart: unless-stopped

    environment:
      TZ: Europe/Berlin

      # V83: Web/API-Passwort ist aktiv.
      # Dadurch liefert Pi-hole v6 echte API-Sessions (SID) und ist
      # mit der offiziellen Home-Assistant-Pi-hole-Integration kompatibel.
      FTLCONF_webserver_api_password: "${PIHOLE_PASS}"
      FTLCONF_webserver_api_app_sudo: "false"

      FTLCONF_dns_upstreams: "127.0.0.1#5335"
      FTLCONF_dns_listeningMode: "LOCAL"
      FTLCONF_dns_queryLogging: "true"

    volumes:
      - /opt/pihole/etc-pihole:/etc/pihole

  # V113: Pi-hole Prometheus Exporter direkt im vorhandenen Pi-hole-LXC.
  # Kein zusätzlicher LXC nötig. Der Exporter nutzt intern die lokale Pi-hole-API
  # und bindet seinen Metrik-Endpunkt gezielt an die Pi-hole-IP auf Port 9617.
  pihole-exporter:
    image: ekofr/pihole-exporter:v1.2.0
    container_name: pihole-exporter
    network_mode: host
    restart: unless-stopped
    depends_on:
      - pihole
    environment:
      PIHOLE_PROTOCOL: "http"
      PIHOLE_HOSTNAME: "127.0.0.1"
      PIHOLE_PORT: "80"
      PIHOLE_PASSWORD: "${PIHOLE_PASS}"
      BIND_ADDR: "${PIHOLE_IP}"
      PORT: "9617"
EOF

    pct push \
        "$PH_ID" \
        /tmp/pihole-compose.yml \
        /opt/pihole/docker-compose.yml

    rm -f /tmp/pihole-compose.yml

    pct exec "$PH_ID" -- bash -lc '
        set -Eeuo pipefail
        cd /opt/pihole

        # V105 migration guard: ältere Dashboard-Versionen konnten beim frühen
        # Statistik-Test eine leere pihole-FTL.db erzeugen. Eine 0-Byte-Datei
        # vor dem ersten FTL-Start ist wertlos und wird sicher entfernt.
        if [[ -f /opt/pihole/etc-pihole/pihole-FTL.db && ! -s /opt/pihole/etc-pihole/pihole-FTL.db ]]; then
            rm -f /opt/pihole/etc-pihole/pihole-FTL.db
        fi

        docker compose config -q
        /usr/local/sbin/docker-cache-pull .
        docker compose up -d
        docker compose ps
    '

    sleep 12

    # V105: FTL muss eine echte Langzeitdatenbank mit dem queries-View erzeugt
    # haben, bevor die Dashboard-Statistik darauf zugreift.
    if ! pct exec "$PH_ID" -- bash -lc '
        set -Eeuo pipefail
        DB=/opt/pihole/etc-pihole/pihole-FTL.db
        for i in $(seq 1 30); do
            if [[ -s "$DB" ]] && sqlite3 -readonly "$DB" ".tables queries" 2>/dev/null | grep -qw queries; then
                exit 0
            fi
            sleep 2
        done
        exit 1
    '; then
        die "Pi-hole FTL-Datenbank wurde nicht korrekt initialisiert."
    fi

    # V113: Nicht nur den offenen Port, sondern echte Pi-hole-Metriken prüfen.
    local pihole_exporter_ok=0
    for _ in $(seq 1 30); do
        if curl -fsS --max-time 5 "http://${PIHOLE_IP}:9617/metrics" 2>/dev/null | grep -q '^pihole_'; then
            pihole_exporter_ok=1
            break
        fi
        sleep 2
    done

    if (( pihole_exporter_ok == 1 )); then
        ok "Pi-hole Exporter liefert Metriken auf ${PIHOLE_IP}:9617."
    elif (( OPTIMAL_INSTALL )); then
        pct exec "$PH_ID" -- docker logs --tail 100 pihole-exporter 2>/dev/null || true
        die "Pi-hole Exporter liefert im Optimalmodus keine Metriken."
    else
        warn "Pi-hole Exporter liefert noch keine Metriken auf Port 9617."
        pct exec "$PH_ID" -- docker logs --tail 50 pihole-exporter 2>/dev/null || true
    fi

    echo
    echo "Pi-hole Authentifizierung:"
    echo "  Web/API-Passwort: aktiv"
    echo "  Home-Assistant App-Passwort: wird erzeugt"

    if PIHOLE_APP_PASS="$(
        generate_pihole_app_password_v83             "$PIHOLE_IP"             "$PIHOLE_PASS"
    )"; then
        ok "Pi-hole App-Passwort für Home Assistant erzeugt und verifiziert."
    else
        PIHOLE_APP_PASS=""
        if (( OPTIMAL_INSTALL )); then
            die "Pi-hole App-Passwort für Home Assistant konnte im Optimalmodus nicht erzeugt werden."
        fi
        warn "Pi-hole App-Passwort konnte nicht automatisch erzeugt werden."
        warn "Später ausführen: pihole-ha-app-password"
    fi

    echo
    echo "Pi-hole Standardlisten:"
    echo "  BLOCK · HaGeZi Pro"
    echo "  BLOCK · HaGeZi TIF"
    echo "  ALLOW · Technox90 Homeatic Allowlist"
    echo "  ALLOW · HaGeZi Referral Native"
    echo

    if ! install_pihole_standard_lists_v82 "$PH_ID"; then
        if (( OPTIMAL_INSTALL )); then
            die "Pi-hole Standardlisten konnten im Optimalmodus nicht eingerichtet werden."
        fi
        warn "Pi-hole läuft weiter; die Listen können später erneut importiert werden."
    fi

    echo
    echo "Pi-hole lokale DNS-/CNAME-Einträge:"
    echo "  Quelle DNS:   Technox90/homeatic · pihole/dns/custom.list"
    echo "  Quelle CNAME: Technox90/homeatic · pihole/cname/cname.txt"

    if ! install_pihole_local_dns_v131 "$PH_ID"; then
        if (( OPTIMAL_INSTALL )); then
            die "Pi-hole lokale DNS-/CNAME-Einträge konnten im Optimalmodus nicht eingerichtet werden."
        fi
        warn "Pi-hole läuft weiter; lokale DNS-/CNAME-Einträge können später erneut importiert werden."
    fi

    if ! install_pihole_dns_sync_v131 "$PH_ID"; then
        warn "Automatischer Pi-hole DNS-Sync ist derzeit nicht aktiv."
    fi

    if pct exec "$PH_ID" -- \
        dig pi-hole.net @127.0.0.1 -p 5335 +short +time=5 \
        >/dev/null 2>&1; then
        ok "Unbound funktioniert."
    else
        warn "Unbound-Test fehlgeschlagen. Bitte Logs prüfen."
    fi

    if pct exec "$PH_ID" -- \
        dig pi-hole.net @"$PIHOLE_IP" +short +time=5 \
        >/dev/null 2>&1; then
        ok "Pi-hole DNS funktioniert."
    else
        warn "Pi-hole-DNS-Test fehlgeschlagen. Container-Logs prüfen."
    fi

    echo
    echo "Pi-hole Sprache: $PIHOLE_LANG"

    if [[ "$PIHOLE_LANG" == "DE" ]]; then
        if /usr/local/sbin/pihole-language DE; then
            ok "Deutsche Pi-hole-Weboberfläche aktiviert."
        else
            warn "Deutsche Übersetzung konnte nicht vollständig angewendet werden."
            warn "Pi-hole selbst bleibt installiert und funktionsfähig."
            warn "Später erneut versuchen mit: pihole-language DE"
        fi
    else
        pct exec "$PH_ID" --             sh -c 'printf "EN\n" > /opt/pihole/.web-language'
    fi

    ok "Pi-hole + Unbound installiert."
    echo "Web:"
    echo "  http://${PIHOLE_IP}/admin"
    echo
    echo "Pi-hole WebUI / API:"
    echo "  Passwortschutz: AKTIV"
    echo
    echo "Home Assistant:"
    if [[ -n "$PIHOLE_APP_PASS" ]]; then
        echo "  separates App-Passwort wurde erzeugt"
    else
        echo "  App-Passwort noch erzeugen mit: pihole-ha-app-password"
    fi
    echo "  Host: $PIHOLE_IP"
    echo "  Port: 80"
    echo "  Location: /admin"
    echo "  SSL: AUS"
    echo
    echo "Pi-hole Authentifizierung später verwalten:"
    echo "  pihole-auth-manager"
    echo "  pihole-reset-password"
    echo "  pihole-ha-app-password"
    echo
    echo "Pi-hole Exporter / Prometheus:"
    echo "  http://${PIHOLE_IP}:9617/metrics"
    echo "  Docker-Service: pihole-exporter"
    echo
    echo "Pi-hole Sprache später umstellen:"
    echo "  pihole-language"
    echo "  pihole-language DE"
    echo "  pihole-language EN"
    echo
    echo "Standardlisten V115:"
    echo "  BLOCK · HaGeZi Pro"
    echo "  BLOCK · HaGeZi TIF"
    echo "  ALLOW · Technox90 Homeatic Allowlist"
    echo "  ALLOW · HaGeZi Referral Native"
}

# =============================================================================
# NETALERTX
# =============================================================================

install_netalertx() {
    header "NETALERTX INSTALLIEREN"

    prepare_ct_cache_dirs "netalertx"

    # NetAlertX benötigt für ARP/Nmap Layer-2-Zugriff. Der LXC bleibt
    # unprivilegiert, Docker erhält nur die benötigten Netzwerk-Capabilities.
    # Der Webserver läuft direkt auf Port 80. NET_BIND_SERVICE erlaubt
    # dem nicht-root Prozess das Binden an einen Port <1024.
    pct create "$NAX_ID" "$TEMPLATE_VOL" \
        --hostname netalertx \
        --ostype debian \
        --unprivileged 1 \
        --features nesting=1,keyctl=1 \
        --cores "$NETALERTX_CORES" \
        --memory "$NETALERTX_MEMORY" \
        --swap 512 \
        --rootfs "${DISK_STORAGE}:${NETALERTX_DISK}" \
        --mp0 "${DOCKER_IMAGE_CACHE_DIR},mp=/mnt/docker-image-cache" \
        --mp1 "${CT_APT_ARCHIVES},mp=/var/cache/apt/archives" \
        --mp2 "${CT_APT_LISTS},mp=/var/lib/apt/lists" \
        --net0 "name=eth0,bridge=${BRIDGE},ip=${NETALERTX_CIDR},gw=${GATEWAY},type=veth" \
        --nameserver "$GATEWAY" \
        --onboot 1 \
        --start 1

    sleep 5

    install_docker_in_ct "$NAX_ID"

    pct exec "$NAX_ID" -- bash -lc '
        set -Eeuo pipefail
        mkdir -p /opt/netalertx/data
        chown -R 20211:20211 /opt/netalertx/data
        chmod 750 /opt/netalertx/data
    '

    cat > /tmp/netalertx-compose.yml <<EOF
services:
  netalertx:
    image: ghcr.io/netalertx/netalertx:latest
    container_name: netalertx
    network_mode: host
    read_only: true

    cap_drop:
      - ALL

    cap_add:
      - NET_ADMIN
      - NET_RAW
      - NET_BIND_SERVICE
      - CHOWN
      - SETUID
      - SETGID

    environment:
      PUID: "20211"
      PGID: "20211"
      LISTEN_ADDR: "0.0.0.0"
      PORT: "20211"
      GRAPHQL_PORT: "20212"
      APP_CONF_OVERRIDE: "{\"SCAN_SUBNETS\":\"['${NETALERTX_SUBNET} --interface=eth0']\",\"GRAPHQL_PORT\":\"20212\"}"

    volumes:
      - /opt/netalertx/data:/data
      - /etc/localtime:/etc/localtime:ro

    tmpfs:
      - "/tmp:uid=20211,gid=20211,mode=1700,rw,noexec,nosuid,nodev,async,noatime,nodiratime"

    # RAM wird ausschließlich durch das Proxmox-LXC-Limit begrenzt.
    # Kein zusätzliches Docker-Limit, damit der konfigurierte LXC-RAM
    # vollständig für NetAlertX nutzbar bleibt.
    cpu_shares: 512
    pids_limit: 512

    logging:
      options:
        max-size: "10m"
        max-file: "3"

    restart: unless-stopped
EOF

    pct push \
        "$NAX_ID" \
        /tmp/netalertx-compose.yml \
        /opt/netalertx/docker-compose.yml

    rm -f /tmp/netalertx-compose.yml

    docker_compose_deploy_in_ct_v107 "$NAX_ID" "/opt/netalertx"

    echo "Warte auf NetAlertX internen Webserver 20211 ..."

    local internal_ready=0
    for _ in $(seq 1 90); do
        if pct exec "$NAX_ID" --             curl -fsS --max-time 3 http://127.0.0.1:20211/             >/dev/null 2>&1; then
            internal_ready=1
            break
        fi
        sleep 2
    done

    if (( internal_ready == 0 )); then
        warn "NetAlertX interner Webserver 20211 ist noch nicht erreichbar."
        pct exec "$NAX_ID" -- docker logs netalertx --tail 100 || true
    fi

    configure_lxc_web_standard_ports_v65 \
        "$NAX_ID" \
        "NetAlertX" \
        "http" \
        "20211"

    echo "Warte auf NetAlertX HTTPS-Webinterface ..."

    local ready=0
    for _ in $(seq 1 90); do
        if pct exec "$NAX_ID" -- \
            curl -kfsS --max-time 3 https://127.0.0.1/ \
            >/dev/null 2>&1; then
            ready=1
            break
        fi
        sleep 2
    done

    if (( ready == 1 )); then
        ok "NetAlertX Webinterface ist erreichbar."
    else
        echo "Logs:"
        echo "  pct exec $NAX_ID -- docker logs netalertx --tail 100"
        if (( OPTIMAL_INSTALL )); then
            die "NetAlertX ist im Optimalmodus nach der Wartezeit nicht erreichbar."
        fi
        warn "NetAlertX ist noch nicht erreichbar. Der erste Start kann einige Minuten dauern."
    fi

    ok "NetAlertX installiert."
    echo "Web:"
    echo "  https://${NETALERTX_IP}/"
    echo "Scan-Netz:"
    echo "  ${NETALERTX_SUBNET}"
    echo
    echo "Der erste Geräte-Scan kann mehrere Minuten dauern."
}


# =============================================================================
# ZUSATZANWENDUNGEN
# =============================================================================

install_uptime_kuma() {
    header "UPTIME KUMA INSTALLIEREN"

    prepare_persistent_data_base

    echo "Persistente Uptime-Kuma-Daten:"
    echo "  $UPTIME_DATA_DIR"
    echo

    create_docker_app_lxc \
        "$UPTIME_ID" "uptime-kuma" "$UPTIME_CIDR" \
        "$UPTIME_CORES" "$UPTIME_MEMORY" "$UPTIME_DISK" \
        "$UPTIME_DATA_DIR" "/mnt/uptime-kuma-data"

    pct exec "$UPTIME_ID" -- mkdir -p /opt/uptime-kuma

    cat > /tmp/uptime-kuma-compose.yml <<EOF
services:
  uptime-kuma:
    image: louislam/uptime-kuma:2
    container_name: uptime-kuma
    restart: unless-stopped
    ports:
      - "127.0.0.1:3001:3001"
    volumes:
      - /mnt/uptime-kuma-data:/app/data
EOF

    pct push "$UPTIME_ID" /tmp/uptime-kuma-compose.yml /opt/uptime-kuma/docker-compose.yml
    rm -f /tmp/uptime-kuma-compose.yml

    docker_compose_deploy_in_ct_v107 "$UPTIME_ID" "/opt/uptime-kuma"

    configure_lxc_web_standard_ports_v65 "$UPTIME_ID" "Uptime Kuma" "http" "3001"
    verify_web_v107 "Uptime Kuma" "https://${UPTIME_IP}/" 90
    dashboard_link_upsert "Uptime Kuma" "https://${UPTIME_IP}/"

    echo
    echo "Uptime-Kuma-Datenbank und Konfiguration bleiben dauerhaft unter:"
    echo "  $UPTIME_DATA_DIR"
}

install_vaultwarden() {
    header "VAULTWARDEN INSTALLIEREN"

    create_docker_app_lxc \
        "$VAULTWARDEN_ID" "vaultwarden" "$VAULTWARDEN_CIDR" \
        "$VAULTWARDEN_CORES" "$VAULTWARDEN_MEMORY" "$VAULTWARDEN_DISK"

    pct exec "$VAULTWARDEN_ID" -- mkdir -p /opt/vaultwarden

    cat > /tmp/vaultwarden-compose.yml <<EOF
services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: unless-stopped
    ports:
      - "127.0.0.1:8080:80"
    environment:
      ADMIN_TOKEN: "${VAULTWARDEN_ADMIN_TOKEN}"
      SIGNUPS_ALLOWED: "true"
      WEBSOCKET_ENABLED: "true"
    volumes:
      - vaultwarden-data:/data

volumes:
  vaultwarden-data:
EOF

    pct push "$VAULTWARDEN_ID" /tmp/vaultwarden-compose.yml /opt/vaultwarden/docker-compose.yml
    rm -f /tmp/vaultwarden-compose.yml

    docker_compose_deploy_in_ct_v107 "$VAULTWARDEN_ID" "/opt/vaultwarden"

    configure_lxc_web_standard_ports_v65 "$VAULTWARDEN_ID" "Vaultwarden" "http" "8080"
    verify_web_v107 "Vaultwarden" "https://${VAULTWARDEN_IP}/admin/" 90
    dashboard_link_upsert "Vaultwarden" "https://${VAULTWARDEN_IP}/"

    ok "Vaultwarden läuft ausschließlich über den verwalteten HTTPS-Einstieg; HTTP wird umgeleitet."
}

install_caddy() {
    header "CADDY REVERSE PROXY INSTALLIEREN"

    create_docker_app_lxc \
        "$CADDY_ID" "caddy" "$CADDY_CIDR" \
        "$CADDY_CORES" "$CADDY_MEMORY" "$CADDY_DISK"

    pct exec "$CADDY_ID" -- mkdir -p /opt/caddy

    cat > /tmp/Caddyfile <<EOF
:80 {
    respond "Caddy Reverse Proxy bereit auf ${CADDY_IP}" 200
}
EOF

    cat > /tmp/caddy-compose.yml <<'EOF'
services:
  caddy:
    image: caddy:2
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    volumes:
      - /opt/caddy/Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy-data:/data
      - caddy-config:/config

volumes:
  caddy-data:
  caddy-config:
EOF

    pct push "$CADDY_ID" /tmp/Caddyfile /opt/caddy/Caddyfile
    pct push "$CADDY_ID" /tmp/caddy-compose.yml /opt/caddy/docker-compose.yml
    rm -f /tmp/Caddyfile /tmp/caddy-compose.yml

    docker_compose_deploy_in_ct_v107 "$CADDY_ID" "/opt/caddy"

    verify_web_v107 "Caddy" "http://${CADDY_IP}/" 60
    dashboard_link_upsert "Caddy Reverse Proxy" "http://${CADDY_IP}/"
}

install_stirling_pdf() {
    header "STIRLING PDF INSTALLIEREN"

    create_docker_app_lxc \
        "$STIRLING_ID" "stirling-pdf" "$STIRLING_CIDR" \
        "$STIRLING_CORES" "$STIRLING_MEMORY" "$STIRLING_DISK"

    pct exec "$STIRLING_ID" -- mkdir -p /opt/stirling-pdf

    cat > /tmp/stirling-compose.yml <<EOF
services:
  stirling-pdf:
    image: docker.stirlingpdf.com/stirlingtools/stirling-pdf:latest
    container_name: stirling-pdf
    restart: unless-stopped
    ports:
      - "127.0.0.1:8080:8080"
    environment:
      SECURITY_ENABLELOGIN: "true"
      SECURITY_INITIALLOGIN_USERNAME: "${STIRLING_ADMIN_USER}"
      SECURITY_INITIALLOGIN_PASSWORD: "${STIRLING_ADMIN_PASS}"
      SYSTEM_DEFAULTLOCALE: "de-DE"
      DISABLE_ADDITIONAL_FEATURES: "false"
    volumes:
      - stirling-config:/configs
      - stirling-logs:/logs
      - stirling-tessdata:/usr/share/tessdata
      - stirling-pipeline:/pipeline

volumes:
  stirling-config:
  stirling-logs:
  stirling-tessdata:
  stirling-pipeline:
EOF

    pct push "$STIRLING_ID" /tmp/stirling-compose.yml /opt/stirling-pdf/docker-compose.yml
    rm -f /tmp/stirling-compose.yml

    docker_compose_deploy_in_ct_v107 "$STIRLING_ID" "/opt/stirling-pdf"

    configure_lxc_web_standard_ports_v65 "$STIRLING_ID" "Stirling PDF" "http" "8080"
    verify_web_v107 "Stirling PDF" "https://${STIRLING_IP}/" 120
    dashboard_link_upsert "Stirling PDF" "https://${STIRLING_IP}/"
}

install_ntfy() {
    header "NTFY INSTALLIEREN"

    create_docker_app_lxc \
        "$NTFY_ID" "ntfy" "$NTFY_CIDR" \
        "$NTFY_CORES" "$NTFY_MEMORY" "$NTFY_DISK"

    pct exec "$NTFY_ID" -- mkdir -p /opt/ntfy

    cat > /tmp/ntfy-compose.yml <<EOF
services:
  ntfy:
    image: binwiederhier/ntfy:latest
    container_name: ntfy
    restart: unless-stopped
    command: serve
    ports:
      - "127.0.0.1:8080:80"
    environment:
      NTFY_BASE_URL: "https://${NTFY_IP}"
      NTFY_CACHE_FILE: "/var/lib/ntfy/cache.db"
      NTFY_ATTACHMENT_CACHE_DIR: "/var/lib/ntfy/attachments"
    volumes:
      - ntfy-data:/var/lib/ntfy

volumes:
  ntfy-data:
EOF

    pct push "$NTFY_ID" /tmp/ntfy-compose.yml /opt/ntfy/docker-compose.yml
    rm -f /tmp/ntfy-compose.yml

    docker_compose_deploy_in_ct_v107 "$NTFY_ID" "/opt/ntfy"

    configure_lxc_web_standard_ports_v65 "$NTFY_ID" "ntfy" "http" "8080"
    verify_web_v107 "ntfy" "https://${NTFY_IP}/" 60
    dashboard_link_upsert "ntfy" "https://${NTFY_IP}/"
}

install_forgejo() {
    header "FORGEJO INSTALLIEREN"

    create_docker_app_lxc \
        "$FORGEJO_ID" "forgejo" "$FORGEJO_CIDR" \
        "$FORGEJO_CORES" "$FORGEJO_MEMORY" "$FORGEJO_DISK"

    pct exec "$FORGEJO_ID" -- mkdir -p /opt/forgejo

    cat > /tmp/forgejo-compose.yml <<EOF
services:
  forgejo:
    image: codeberg.org/forgejo/forgejo:16
    container_name: forgejo
    restart: unless-stopped
    environment:
      USER_UID: "1000"
      USER_GID: "1000"
      FORGEJO__server__HTTP_PORT: "3000"
      FORGEJO__server__ROOT_URL: "https://${FORGEJO_IP}/"
      FORGEJO__server__SSH_PORT: "222"
    ports:
      - "127.0.0.1:3000:3000"
      - "222:22"
    volumes:
      - forgejo-data:/data
      - /etc/localtime:/etc/localtime:ro

volumes:
  forgejo-data:
EOF

    pct push "$FORGEJO_ID" /tmp/forgejo-compose.yml /opt/forgejo/docker-compose.yml
    rm -f /tmp/forgejo-compose.yml

    docker_compose_deploy_in_ct_v107 "$FORGEJO_ID" "/opt/forgejo"

    configure_lxc_web_standard_ports_v65 "$FORGEJO_ID" "Forgejo" "http" "3000"
    verify_web_v107 "Forgejo" "https://${FORGEJO_IP}/" 90
    dashboard_link_upsert "Forgejo" "https://${FORGEJO_IP}/"
}

install_syncthing() {
    header "SYNCTHING INSTALLIEREN"

    create_docker_app_lxc \
        "$SYNCTHING_ID" "syncthing" "$SYNCTHING_CIDR" \
        "$SYNCTHING_CORES" "$SYNCTHING_MEMORY" "$SYNCTHING_DISK"

    pct exec "$SYNCTHING_ID" -- mkdir -p /opt/syncthing

    cat > /tmp/syncthing-compose.yml <<'EOF'
services:
  syncthing:
    image: syncthing/syncthing:latest
    container_name: syncthing
    restart: unless-stopped
    ports:
      - "127.0.0.1:8384:8384"
      - "22000:22000/tcp"
      - "22000:22000/udp"
      - "21027:21027/udp"
    volumes:
      - syncthing-data:/var/syncthing

volumes:
  syncthing-data:
EOF

    pct push "$SYNCTHING_ID" /tmp/syncthing-compose.yml /opt/syncthing/docker-compose.yml
    rm -f /tmp/syncthing-compose.yml

    docker_compose_deploy_in_ct_v107 "$SYNCTHING_ID" "/opt/syncthing"

    configure_lxc_web_standard_ports_v65 "$SYNCTHING_ID" "Syncthing" "http" "8384"
    verify_web_v107 "Syncthing" "https://${SYNCTHING_IP}/" 90
    dashboard_link_upsert "Syncthing" "https://${SYNCTHING_IP}/"
}

install_speedtest_tracker() {
    header "SPEEDTEST TRACKER INSTALLIEREN"

    create_docker_app_lxc \
        "$SPEEDTEST_ID" "speedtest-tracker" "$SPEEDTEST_CIDR" \
        "$SPEEDTEST_CORES" "$SPEEDTEST_MEMORY" "$SPEEDTEST_DISK"

    pct exec "$SPEEDTEST_ID" -- mkdir -p /opt/speedtest-tracker

    cat > /tmp/speedtest-compose.yml <<EOF
services:
  speedtest-tracker:
    image: lscr.io/linuxserver/speedtest-tracker:latest
    container_name: speedtest-tracker
    restart: unless-stopped
    ports:
      - "127.0.0.1:8080:80"
    environment:
      PUID: "1000"
      PGID: "1000"
      APP_KEY: "${SPEEDTEST_APP_KEY}"
      APP_URL: "https://${SPEEDTEST_IP}"
      ASSET_URL: "https://${SPEEDTEST_IP}"
      DB_CONNECTION: "sqlite"
      ADMIN_NAME: "Admin"
      ADMIN_EMAIL: "${SPEEDTEST_ADMIN_EMAIL}"
      ADMIN_PASSWORD: "${SPEEDTEST_ADMIN_PASS}"
      APP_TIMEZONE: "Europe/Berlin"
      DISPLAY_TIMEZONE: "Europe/Berlin"
    volumes:
      - speedtest-data:/config

volumes:
  speedtest-data:
EOF

    pct push "$SPEEDTEST_ID" /tmp/speedtest-compose.yml /opt/speedtest-tracker/docker-compose.yml
    rm -f /tmp/speedtest-compose.yml

    docker_compose_deploy_in_ct_v107 "$SPEEDTEST_ID" "/opt/speedtest-tracker"

    configure_lxc_web_standard_ports_v65 "$SPEEDTEST_ID" "Speedtest Tracker" "http" "8080"
    verify_web_v107 "Speedtest Tracker" "https://${SPEEDTEST_IP}/api/healthcheck" 120
    dashboard_link_upsert "Speedtest Tracker" "https://${SPEEDTEST_IP}/"
}

install_scrutiny() {
    header "SCRUTINY INSTALLIEREN"

    create_docker_app_lxc \
        "$SCRUTINY_ID" "scrutiny" "$SCRUTINY_CIDR" \
        "$SCRUTINY_CORES" "$SCRUTINY_MEMORY" "$SCRUTINY_DISK"

    pct exec "$SCRUTINY_ID" -- mkdir -p /opt/scrutiny

    cat > /tmp/scrutiny-compose.yml <<'EOF'
services:
  influxdb:
    image: influxdb:2.8
    container_name: scrutiny-influxdb
    restart: unless-stopped
    volumes:
      - scrutiny-influxdb:/var/lib/influxdb2

  scrutiny:
    image: ghcr.io/analogj/scrutiny:latest-web
    container_name: scrutiny-web
    restart: unless-stopped
    ports:
      - "127.0.0.1:8080:8080"
    environment:
      SCRUTINY_WEB_INFLUXDB_HOST: "influxdb"
      SCRUTINY_WEB_INFLUXDB_PORT: "8086"
    volumes:
      - scrutiny-config:/opt/scrutiny/config
    depends_on:
      - influxdb

volumes:
  scrutiny-influxdb:
  scrutiny-config:
EOF

    pct push "$SCRUTINY_ID" /tmp/scrutiny-compose.yml /opt/scrutiny/docker-compose.yml
    rm -f /tmp/scrutiny-compose.yml

    docker_compose_deploy_in_ct_v107 "$SCRUTINY_ID" "/opt/scrutiny"

    configure_lxc_web_standard_ports_v65 "$SCRUTINY_ID" "Scrutiny" "http" "8080"
    verify_web_v107 "Scrutiny" "https://${SCRUTINY_IP}/" 120

    echo
    echo "Installiere Scrutiny SMART-Collector nativ auf dem Proxmox-Host ..."

    apt-get update
    apt-get install -y smartmontools curl

    local arch
    case "$(uname -m)" in
        x86_64|amd64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *) die "Scrutiny Collector: nicht unterstützte Architektur $(uname -m)" ;;
    esac

    mkdir -p /opt/scrutiny-collector

    local scrutiny_cache="${SCRUTINY_DOWNLOAD_CACHE}/scrutiny-collector-metrics-linux-${arch}"

    cache_download \
        "https://github.com/AnalogJ/scrutiny/releases/latest/download/scrutiny-collector-metrics-linux-${arch}" \
        "$scrutiny_cache" \
        "Scrutiny Collector"

    install -m 0755 \
        "$scrutiny_cache" \
        /opt/scrutiny-collector/scrutiny-collector-metrics

    cat > /etc/systemd/system/scrutiny-collector.service <<EOF
[Unit]
Description=Scrutiny SMART Collector
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/opt/scrutiny-collector/scrutiny-collector-metrics run --api-endpoint http://${SCRUTINY_IP}:8080/
EOF

    cat > /etc/systemd/system/scrutiny-collector.timer <<'EOF'
[Unit]
Description=Scrutiny SMART Collector alle 15 Minuten

[Timer]
OnBootSec=3min
OnUnitActiveSec=15min
Persistent=true
Unit=scrutiny-collector.service

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable --now scrutiny-collector.timer

    if ! systemctl start scrutiny-collector.service; then
        if (( OPTIMAL_INSTALL )); then
            die "Scrutiny: erster SMART-Collector-Lauf ist im Optimalmodus fehlgeschlagen."
        fi
        warn "Erster Scrutiny-Collector-Lauf war noch nicht erfolgreich."
    fi

    dashboard_link_upsert "Scrutiny" "https://${SCRUTINY_IP}/"
}

install_mealie() {
    header "MEALIE INSTALLIEREN"

    create_docker_app_lxc \
        "$MEALIE_ID" "mealie" "$MEALIE_CIDR" \
        "$MEALIE_CORES" "$MEALIE_MEMORY" "$MEALIE_DISK"

    pct exec "$MEALIE_ID" -- mkdir -p /opt/mealie

    cat > /tmp/mealie-compose.yml <<EOF
services:
  mealie:
    image: ghcr.io/mealie-recipes/mealie:v3.26.0
    container_name: mealie
    restart: unless-stopped
    ports:
      - "127.0.0.1:9000:9000"
    environment:
      TZ: "Europe/Berlin"
      BASE_URL: "https://${MEALIE_IP}"
      ALLOW_SIGNUP: "false"
      PUID: "1000"
      PGID: "1000"
      DEFAULT_EMAIL: "${MEALIE_DEFAULT_USER}"
      DEFAULT_GROUP: "Home"
      DEFAULT_HOUSEHOLD: "Family"
    volumes:
      - mealie-data:/app/data

volumes:
  mealie-data:
EOF

    pct push "$MEALIE_ID" /tmp/mealie-compose.yml /opt/mealie/docker-compose.yml
    rm -f /tmp/mealie-compose.yml

    docker_compose_deploy_in_ct_v107 "$MEALIE_ID" "/opt/mealie"

    configure_lxc_web_standard_ports_v65 "$MEALIE_ID" "Mealie" "http" "9000"
    verify_web_v107 "Mealie" "https://${MEALIE_IP}/" 120
    dashboard_link_upsert "Mealie" "https://${MEALIE_IP}/"
}


# =============================================================================
# V65 · LOKALE CA + STANDARDPORTS 80/443
# =============================================================================

ensure_local_ca_v65() {
    mkdir -p "$LOCAL_CA_ROOT"
    chmod 700 "$LOCAL_CA_ROOT"

    local created=0

    if [[ ! -s "$LOCAL_CA_CERT" || ! -s "$LOCAL_CA_KEY" ]]; then
        openssl req \
            -x509 \
            -nodes \
            -newkey rsa:3072 \
            -sha256 \
            -days 3650 \
            -keyout "$LOCAL_CA_KEY" \
            -out "$LOCAL_CA_CERT" \
            -subj "/C=${TLS_CERT_COUNTRY}/ST=${TLS_CERT_STATE}/L=${TLS_CERT_LOCALITY}/O=${TLS_CERT_ORG}/OU=${TLS_CERT_OU}/CN=NodeZero Local CA" \
            >/dev/null 2>&1

        created=1
    fi

    [[ -s "$LOCAL_CA_CERT" ]] || \
        die "NodeZero Local CA Zertifikat fehlt: $LOCAL_CA_CERT"

    [[ -s "$LOCAL_CA_KEY" ]] || \
        die "NodeZero Local CA Schlüssel fehlt: $LOCAL_CA_KEY"

    chmod 600 "$LOCAL_CA_KEY"
    chmod 644 "$LOCAL_CA_CERT"

    install -m 0644 \
        "$LOCAL_CA_CERT" \
        /usr/local/share/ca-certificates/nodezero-local-ca.crt

    update-ca-certificates >/dev/null 2>&1 || true

    # V88: Client-Importhilfen persistent bereitstellen. Ohne einmaliges Vertrauen
    # der privaten CA melden Browser bei internen IP-Zertifikaten zwangsläufig
    # "nicht vertrauenswürdig", obwohl Zertifikat und SAN technisch korrekt sind.
    cat > "${LOCAL_CA_ROOT}/install-nodezero-ca-windows.ps1" <<'POWERSHELL'
$ErrorActionPreference = 'Stop'
$cert = Join-Path $PSScriptRoot 'nodezero-local-ca.crt'
if (-not (Test-Path $cert)) { throw "CA-Datei nicht gefunden: $cert" }
certutil.exe -addstore -f Root $cert
Write-Host 'NodeZero Local CA wurde in Vertrauenswürdige Stammzertifizierungsstellen importiert.'
POWERSHELL
    chmod 644 "${LOCAL_CA_ROOT}/install-nodezero-ca-windows.ps1"

    cat > "${LOCAL_CA_ROOT}/README-CA.txt" <<EOF
NodeZero Local CA
=================

CA-Datei:
  ${LOCAL_CA_CERT}

Windows (PowerShell als Administrator):
  powershell -ExecutionPolicy Bypass -File .\\install-nodezero-ca-windows.ps1

Alternativ manuell:
  nodezero-local-ca.crt in "Vertrauenswürdige Stammzertifizierungsstellen" importieren.

Danach Browser vollständig schließen und neu öffnen.
Die CA gilt nur für die von diesem Installer lokal ausgestellten Zertifikate.
EOF
    chmod 644 "${LOCAL_CA_ROOT}/README-CA.txt"

    if [[ -d /opt/nodezero/dashboard/static ]]; then
        install -m 0644 "$LOCAL_CA_CERT" /opt/nodezero/dashboard/static/nodezero-local-ca.crt
    fi

    # WICHTIG: keine Statusmeldung auf STDOUT.
    if (( created )); then
        ok "NodeZero Local CA erstellt: $LOCAL_CA_CERT" >&2
    else
        info "NodeZero Local CA vorhanden: $LOCAL_CA_CERT" >&2
    fi
}

issue_local_service_cert_v65() {
    local ip="$1"
    local hostname="$2"
    local output_dir="$3"

    ensure_local_ca_v65

    mkdir -p "$output_dir"
    chmod 700 "$output_dir"

    local key="${output_dir}/service.key"
    local csr="${output_dir}/service.csr"
    local cert="${output_dir}/service.crt"
    local ext="${output_dir}/service.ext"

    cat > "$ext" <<EOF
subjectAltName=IP:${ip},DNS:${hostname},DNS:${hostname}.local
basicConstraints=critical,CA:FALSE
extendedKeyUsage=serverAuth
keyUsage=critical,digitalSignature,keyEncipherment
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
EOF

    openssl req \
        -nodes \
        -newkey rsa:2048 \
        -sha256 \
        -keyout "$key" \
        -out "$csr" \
        -subj "/C=${TLS_CERT_COUNTRY}/ST=${TLS_CERT_STATE}/L=${TLS_CERT_LOCALITY}/O=${TLS_CERT_ORG}/OU=${TLS_CERT_OU}/CN=${hostname}" \
        >/dev/null 2>&1

    openssl x509 \
        -req \
        -sha256 \
        -days "$TLS_CERT_DAYS" \
        -in "$csr" \
        -CA "$LOCAL_CA_CERT" \
        -CAkey "$LOCAL_CA_KEY" \
        -CAcreateserial \
        -out "$cert" \
        -extfile "$ext" \
        >/dev/null 2>&1

    chmod 600 "$key"
    chmod 644 "$cert"

    [[ -s "$cert" ]] || die "TLS-Zertifikat wurde nicht erzeugt: $cert"
    [[ -s "$key" ]] || die "TLS-Schlüssel wurde nicht erzeugt: $key"

    # Einzige zulässige STDOUT-Ausgabe: cert<TAB>key
    printf '%s\t%s\n' "$cert" "$key"
}

read_issued_cert_pair_v68() {
    local ip="$1"
    local hostname="$2"
    local output_dir="$3"
    local cert_var="$4"
    local key_var="$5"

    local parsed_cert=""
    local parsed_key=""
    local extra=""

    IFS=$'\t' read -r parsed_cert parsed_key extra < <(
        issue_local_service_cert_v65 \
            "$ip" \
            "$hostname" \
            "$output_dir"
    )

    [[ -z "$extra" ]] || \
        die "TLS-Zertifikatsübergabe enthält unerwartete Zusatzdaten."

    [[ -n "$parsed_cert" && -f "$parsed_cert" ]] || \
        die "TLS-Zertifikatspfad ungültig: ${parsed_cert:-leer}"

    [[ -n "$parsed_key" && -f "$parsed_key" ]] || \
        die "TLS-Schlüsselpfad ungültig: ${parsed_key:-leer}"

    printf -v "$cert_var" '%s' "$parsed_cert"
    printf -v "$key_var" '%s' "$parsed_key"
}

configure_lxc_web_standard_ports_v65() {
    local ctid="$1"
    local label="$2"
    local backend_scheme="$3"
    local backend_port="$4"

    local ip=""
    local hostname=""
    local cert_dir=""
    local issued=""
    local cert=""
    local key=""

    ip="$(
        pct exec "$ctid" -- bash -lc "hostname -I | awk '{print \$1}'" 2>/dev/null |
        tr -d '\r\n'
    )"

    hostname="$(
        pct exec "$ctid" -- hostname -s 2>/dev/null |
        tr -d '\r\n'
    )"

    [[ -n "$ip" ]] || die "${label}: Container-IP für TLS fehlt."
    hostname="${hostname:-service-${ctid}}"

    cert_dir="$(mktemp -d "/tmp/pve-master-cert-${ctid}.XXXXXX")"

    read_issued_cert_pair_v68 \
        "$ip" \
        "$hostname" \
        "$cert_dir" \
        cert \
        key

    [[ -s "$cert" ]] || \
        die "${label}: erzeugtes Zertifikat wurde nicht gefunden."

    [[ -s "$key" ]] || \
        die "${label}: erzeugter Zertifikatsschlüssel wurde nicht gefunden."

    pct exec "$ctid" -- mkdir -p /etc/pve-master/tls
    pct push "$ctid" "$cert" /etc/pve-master/tls/service.crt -perms 0644 >/dev/null
    pct push "$ctid" "$key" /etc/pve-master/tls/service.key -perms 0600 >/dev/null

    rm -rf "$cert_dir"

    pct exec "$ctid" -- bash -s -- \
        "$backend_scheme" \
        "$backend_port" <<'EOS'
set -Eeuo pipefail

BACKEND_SCHEME="$1"
BACKEND_PORT="$2"

export DEBIAN_FRONTEND=noninteractive

if command -v apt-get >/dev/null 2>&1; then
    if ! apt-get update -qq; then
        echo "APT-Update mit Standard-Sandbox fehlgeschlagen; einmaliger Root-Sandbox-Fallback." >&2
        apt-get -o APT::Sandbox::User=root update -qq
    fi
    if ! apt-get install -y -qq nginx curl >/dev/null; then
        echo "APT-Installation mit Standard-Sandbox fehlgeschlagen; einmaliger Root-Sandbox-Fallback." >&2
        apt-get -o APT::Sandbox::User=root install -y -qq nginx curl >/dev/null
    fi
elif command -v apk >/dev/null 2>&1; then
    apk add --no-cache nginx curl >/dev/null
else
    exit 1
fi

mkdir -p /etc/nginx/conf.d /etc/nginx/sites-enabled

rm -f \
    /etc/nginx/sites-enabled/default \
    /etc/nginx/conf.d/default.conf \
    /etc/nginx/http.d/default.conf 2>/dev/null || true

cat > /etc/nginx/conf.d/pve-master-standard-web.conf <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    return 308 https://\$host\$request_uri;
}

server {
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;
    server_name _;

    ssl_certificate /etc/pve-master/tls/service.crt;
    ssl_certificate_key /etc/pve-master/tls/service.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_session_cache shared:PVE_MASTER_TLS:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;

    add_header X-Content-Type-Options nosniff always;
    add_header Referrer-Policy no-referrer-when-downgrade always;

    client_max_body_size 0;

    location / {
        proxy_pass ${BACKEND_SCHEME}://127.0.0.1:${BACKEND_PORT};
        proxy_http_version 1.1;
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Port 443;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }
}
EOF

if [[ "$BACKEND_SCHEME" == "https" ]]; then
    sed -i \
        '/proxy_pass https:/a\        proxy_ssl_verify off;\n        proxy_ssl_server_name on;' \
        /etc/nginx/conf.d/pve-master-standard-web.conf
fi

nginx -t
systemctl enable nginx >/dev/null 2>&1 || true
systemctl restart nginx
EOS

    register_managed_tls_service_v88 "lxc" "$ctid" "$label" "$ip" "$hostname"
    ok "${label}: HTTPS aktiv: https://${ip}/ · HTTP leitet automatisch um."
}

# V88 · verwaltete TLS-Zertifikate automatisch erneuern.
# Die lokale CA bleibt unter /home/Data persistent. Alle vom Installer verwalteten
# nginx-Endpunkte werden registriert und wöchentlich geprüft. Zertifikate werden
# 45 Tage vor Ablauf erneuert und nginx anschließend ohne Downtime neu geladen.
install_managed_tls_renewer_v88() {
    ensure_local_ca_v65

    local renewer="/usr/local/sbin/proxmox-master-tls-renew"
    local service="/etc/systemd/system/proxmox-master-tls-renew.service"
    local timer="/etc/systemd/system/proxmox-master-tls-renew.timer"

    cat > "$renewer" <<'__TLS_RENEWER_V88__'
#!/usr/bin/env bash
set -Eeuo pipefail

CA_ROOT="/home/Data/proxmox-installer/tls"
CA_CERT="${CA_ROOT}/nodezero-local-ca.crt"
CA_KEY="${CA_ROOT}/nodezero-local-ca.key"
REGISTRY="${CA_ROOT}/managed-services.tsv"
DAYS=397
CHECKEND=$((45 * 24 * 60 * 60))

[[ -s "$CA_CERT" && -s "$CA_KEY" ]] || exit 0
[[ -s "$REGISTRY" ]] || exit 0

issue_cert() {
    local ip="$1" hostname="$2" out="$3"
    mkdir -p "$out"
    chmod 700 "$out"

    cat > "${out}/service.ext" <<EOF
subjectAltName=IP:${ip},DNS:${hostname},DNS:${hostname}.local
basicConstraints=critical,CA:FALSE
extendedKeyUsage=serverAuth
keyUsage=critical,digitalSignature,keyEncipherment
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
EOF

    openssl req -nodes -newkey rsa:2048 -sha256 \
        -keyout "${out}/service.key" \
        -out "${out}/service.csr" \
        -subj "/C=DE/ST=Deutschland/L=HomeLab/O=NodeZero/OU=Proxmox/CN=${hostname}" \
        >/dev/null 2>&1

    openssl x509 -req -sha256 -days "$DAYS" \
        -in "${out}/service.csr" \
        -CA "$CA_CERT" -CAkey "$CA_KEY" -CAcreateserial \
        -out "${out}/service.crt" -extfile "${out}/service.ext" \
        >/dev/null 2>&1

    chmod 600 "${out}/service.key"
    chmod 644 "${out}/service.crt"
}

while IFS=$'\t' read -r kind id label ip hostname; do
    [[ -n "${kind:-}" && "${kind:0:1}" != "#" ]] || continue
    [[ -n "${ip:-}" && -n "${hostname:-}" ]] || continue

    if [[ "$kind" == "lxc" ]]; then
        [[ "$id" =~ ^[0-9]+$ ]] || continue
        pct config "$id" >/dev/null 2>&1 || continue
        pct status "$id" 2>/dev/null | grep -q 'status: running' || continue

        if pct exec "$id" -- test -s /etc/pve-master/tls/service.crt \
           && pct exec "$id" -- cat /etc/pve-master/tls/service.crt 2>/dev/null \
                | openssl x509 -checkend "$CHECKEND" -noout >/dev/null 2>&1; then
            continue
        fi

        tmp="$(mktemp -d /tmp/pve-master-tls-renew.XXXXXX)"
        issue_cert "$ip" "$hostname" "$tmp"
        pct exec "$id" -- mkdir -p /etc/pve-master/tls
        pct push "$id" "$tmp/service.crt" /etc/pve-master/tls/service.crt -perms 0644 >/dev/null
        pct push "$id" "$tmp/service.key" /etc/pve-master/tls/service.key -perms 0600 >/dev/null
        rm -rf "$tmp"
        pct exec "$id" -- nginx -t >/dev/null 2>&1
        pct exec "$id" -- systemctl reload nginx >/dev/null 2>&1 || pct exec "$id" -- systemctl restart nginx >/dev/null 2>&1
        logger -t proxmox-master-tls "renewed ${label} (${ip})"

    elif [[ "$kind" == "pbs-native" ]]; then
        [[ "$id" =~ ^[0-9]+$ ]] || continue
        pct config "$id" >/dev/null 2>&1 || continue
        pct status "$id" 2>/dev/null | grep -q 'status: running' || continue

        if pct exec "$id" -- test -s /etc/proxmox-backup/proxy.pem \
           && pct exec "$id" -- cat /etc/proxmox-backup/proxy.pem 2>/dev/null \
                | openssl x509 -checkend "$CHECKEND" -noout >/dev/null 2>&1; then
            continue
        fi

        tmp="$(mktemp -d /tmp/pbs-native-tls-renew.XXXXXX)"
        issue_cert "$ip" "$hostname" "$tmp"
        pct push "$id" "$tmp/service.crt" /etc/proxmox-backup/proxy.pem -perms 0640 >/dev/null
        pct push "$id" "$tmp/service.key" /etc/proxmox-backup/proxy.key -perms 0640 >/dev/null
        rm -rf "$tmp"
        pct exec "$id" -- chown root:backup /etc/proxmox-backup/proxy.pem /etc/proxmox-backup/proxy.key
        pct exec "$id" -- systemctl reload proxmox-backup-proxy >/dev/null 2>&1
        logger -t proxmox-master-tls "renewed PBS native certificate (${ip}:8007)"

    elif [[ "$kind" == "host-dashboard" ]]; then
        cert="/etc/pve-sensor-dashboard/dashboard.crt"
        key="/etc/pve-sensor-dashboard/dashboard.key"
        if [[ -s "$cert" ]] && openssl x509 -checkend "$CHECKEND" -noout -in "$cert" >/dev/null 2>&1; then
            continue
        fi

        tmp="$(mktemp -d /tmp/pve-dashboard-tls-renew.XXXXXX)"
        issue_cert "$ip" "$hostname" "$tmp"
        install -m 0644 "$tmp/service.crt" "$cert"
        install -m 0600 "$tmp/service.key" "$key"
        rm -rf "$tmp"
        nginx -t >/dev/null 2>&1 && systemctl reload nginx >/dev/null 2>&1
        logger -t proxmox-master-tls "renewed dashboard (${ip})"
    fi
done < "$REGISTRY"
__TLS_RENEWER_V88__

    chmod 700 "$renewer"

    cat > "$service" <<'EOF'
[Unit]
Description=NodeZero managed TLS certificate renewal
After=network-online.target pve-cluster.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/proxmox-master-tls-renew
EOF

    cat > "$timer" <<'EOF'
[Unit]
Description=Weekly NodeZero TLS certificate renewal check

[Timer]
OnBootSec=15min
OnCalendar=weekly
RandomizedDelaySec=30min
Persistent=true
Unit=proxmox-master-tls-renew.service

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable --now proxmox-master-tls-renew.timer >/dev/null 2>&1 || true
}

register_managed_tls_service_v88() {
    local kind="$1" id="$2" label="$3" ip="$4" hostname="$5"
    local registry="${LOCAL_CA_ROOT}/managed-services.tsv"
    local tmp="${registry}.tmp.$$"

    ensure_local_ca_v65
    mkdir -p "$LOCAL_CA_ROOT"
    touch "$registry"
    chmod 600 "$registry"

    awk -F '\t' -v k="$kind" -v i="$id" '!(NF >= 2 && $1 == k && $2 == i)' "$registry" > "$tmp" || true
    printf '%s\t%s\t%s\t%s\t%s\n' "$kind" "$id" "$label" "$ip" "$hostname" >> "$tmp"
    mv -f "$tmp" "$registry"
    chmod 600 "$registry"

    install_managed_tls_renewer_v88
}

# Bestehende PBS/Pulse/PVE-UPS-Aufrufe bleiben kompatibel,
# bekommen ab V65 aber automatisch Port 80 UND 443.
configure_lxc_web_port80() {
    configure_lxc_web_standard_ports_v65 "$@"
}

# COMMUNITY-SCRIPTS ERWEITERUNGEN
# =============================================================================

install_community_generated_lxc() {
    local label="$1"
    local script_url="$2"
    local ctid="$3"
    local hostname="$4"
    local cidr="$5"
    local cores="$6"
    local ram_mb="$7"
    local disk_gb="$8"
    local root_pw="$9"
    local tmp

    tmp="$(mktemp "/tmp/community-${hostname}.XXXXXX.sh")"

    echo "Lade offiziellen Community-Script-Installer:"
    echo "  $script_url"

    curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 15 \
        "$script_url" -o "$tmp"
    chmod 700 "$tmp"
    bash -n "$tmp" || die "${label}: heruntergeladenes Community-Script hat ungültige Bash-Syntax."

    mode=generated \
    var_ctid="$ctid" \
    var_hostname="$hostname" \
    var_cpu="$cores" \
    var_ram="$ram_mb" \
    var_disk="$disk_gb" \
    var_brg="$BRIDGE" \
    var_net="$cidr" \
    var_gateway="$GATEWAY" \
    var_ipv6_method="none" \
    var_unprivileged="1" \
    var_pw="$root_pw" \
    var_container_storage="$DISK_STORAGE" \
    var_template_storage="$IMAGE_CACHE_STORAGE" \
    var_timezone="Europe/Berlin" \
    var_tags="community-script;proxmox-master" \
        bash "$tmp"

    rm -f "$tmp"

    pct config "$ctid" >/dev/null 2>&1 || \
        die "${label}: CT ${ctid} wurde nicht angelegt."

    pct set "$ctid" -onboot 1 >/dev/null

    if ! pct status "$ctid" 2>/dev/null | grep -q 'status: running'; then
        pct start "$ctid"
        sleep 5
    fi
}


install_community_generated_lxc_v65() {
    local label="$1"
    local script_url="$2"
    local ctid="$3"
    local hostname="$4"
    local cidr="$5"
    local cores="$6"
    local ram_mb="$7"
    local disk_gb="$8"
    local root_pw="$9"

    shift 9
    local extra_env=("$@")
    local tmp=""

    tmp="$(mktemp "/tmp/community-v65-${hostname}.XXXXXX.sh")"

    curl -fsSL \
        --retry 3 \
        --retry-delay 1 \
        --connect-timeout 15 \
        "$script_url" \
        -o "$tmp"

    chmod 700 "$tmp"
    bash -n "$tmp" || die "${label}: heruntergeladenes Community-Script hat ungültige Bash-Syntax."

    local stdin_payload="${COMMUNITY_STDIN_V107:-}"
    local env_args=(
        "mode=generated"
        "var_ctid=${ctid}"
        "var_hostname=${hostname}"
        "var_cpu=${cores}"
        "var_ram=${ram_mb}"
        "var_disk=${disk_gb}"
        "var_brg=${BRIDGE}"
        "var_net=${cidr}"
        "var_gateway=${GATEWAY}"
        "var_ipv6_method=none"
        "var_unprivileged=1"
        "var_pw=${root_pw}"
        "var_container_storage=${DISK_STORAGE}"
        "var_template_storage=${IMAGE_CACHE_STORAGE}"
        "var_timezone=Europe/Berlin"
        "var_os=debian"
        "var_version=13"
        "var_tags=community-script;proxmox-master;v107"
    )
    env_args+=("${extra_env[@]}")

    if [[ -n "$stdin_payload" ]]; then
        printf '%b' "$stdin_payload" | env "${env_args[@]}" bash "$tmp"
    else
        env "${env_args[@]}" bash "$tmp"
    fi

    rm -f "$tmp"

    pct config "$ctid" >/dev/null 2>&1 || \
        die "${label}: CT ${ctid} wurde nicht angelegt."

    pct set "$ctid" -onboot 1 >/dev/null

    if ! pct status "$ctid" 2>/dev/null | grep -q 'status: running'; then
        pct start "$ctid"
        sleep 5
    fi
}


install_semaphore_v65() {
    install_community_generated_lxc_v65 \
        "Semaphore" \
        "https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/semaphore.sh" \
        "$SEMAPHORE_ID" "semaphore" "$SEMAPHORE_CIDR" \
        "$SEMAPHORE_CORES" "$SEMAPHORE_MEMORY" "$SEMAPHORE_DISK" "$SEMAPHORE_ROOT_PASS" \
        "var_os=ubuntu" \
        "var_version=24.04"

    SEMAPHORE_ADMIN_PASS="$(pct exec "$SEMAPHORE_ID" -- cat /root/semaphore.creds 2>/dev/null | tr -d '\r\n' || true)"
    [[ -n "$SEMAPHORE_ADMIN_PASS" ]] || die "Semaphore: automatisch erzeugtes Admin-Passwort konnte nicht gelesen werden."

    # Das aktuelle Community-Script erzeugt zusätzlich drei kryptographische
    # Schlüssel in /opt/semaphore/config.json. Auch diese werden getrennt und
    # mit 0600 außerhalb des Containers gesichert.
    local semaphore_cfg
    semaphore_cfg="$(pct exec "$SEMAPHORE_ID" -- cat /opt/semaphore/config.json 2>/dev/null || true)"
    [[ -n "$semaphore_cfg" ]] || die "Semaphore: config.json konnte für die Secret-Sicherung nicht gelesen werden."
    SEMAPHORE_COOKIE_HASH="$(printf '%s' "$semaphore_cfg" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("cookie_hash", ""))')"
    SEMAPHORE_COOKIE_ENCRYPTION="$(printf '%s' "$semaphore_cfg" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("cookie_encryption", ""))')"
    SEMAPHORE_ACCESS_KEY_ENCRYPTION="$(printf '%s' "$semaphore_cfg" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("access_key_encryption", ""))')"
    [[ -n "$SEMAPHORE_COOKIE_HASH" && -n "$SEMAPHORE_COOKIE_ENCRYPTION" && -n "$SEMAPHORE_ACCESS_KEY_ENCRYPTION" ]] || \
        die "Semaphore: interne Verschlüsselungs-Secrets konnten nicht vollständig gelesen werden."
    persist_install_secrets_v107

    configure_lxc_web_standard_ports_v65 "$SEMAPHORE_ID" "Semaphore" "http" "3000"
}

install_pocketid_v65() {
    COMMUNITY_STDIN_V107="${POCKETID_PUBLIC_URL}\n" \
    install_community_generated_lxc_v65 \
        "Pocket ID" \
        "https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/pocketid.sh" \
        "$POCKETID_ID" "pocketid" "$POCKETID_CIDR" \
        "$POCKETID_CORES" "$POCKETID_MEMORY" "$POCKETID_DISK" "$POCKETID_ROOT_PASS"

    # Pocket ID erzeugt bei der Erstinstallation einen ENCRYPTION_KEY in .env.
    # Er gehört zur Installation und wird deshalb wie jedes andere Secret
    # separat unter /root/passwort gesichert.
    POCKETID_ENCRYPTION_KEY="$(
        pct exec "$POCKETID_ID" -- bash -lc \
            "sed -n 's/^ENCRYPTION_KEY=//p' /opt/pocket-id/.env | head -n1" 2>/dev/null |
        tr -d '\r\n'
    )"
    [[ -n "$POCKETID_ENCRYPTION_KEY" ]] || die "Pocket ID: ENCRYPTION_KEY konnte nicht gelesen werden."
    persist_install_secrets_v107

    configure_lxc_web_standard_ports_v65 "$POCKETID_ID" "Pocket ID" "http" "1411"
}

install_prometheus_v65() {
    install_community_generated_lxc_v65 \
        "Prometheus" \
        "https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/prometheus.sh" \
        "$PROMETHEUS_ID" "prometheus" "$PROMETHEUS_CIDR" \
        "$PROMETHEUS_CORES" "$PROMETHEUS_MEMORY" "$PROMETHEUS_DISK" "$PROMETHEUS_ROOT_PASS"

    configure_lxc_web_standard_ports_v65 "$PROMETHEUS_ID" "Prometheus" "http" "9090"
}

install_pve_exporter_v65() {
    install_community_generated_lxc_v65 \
        "Prometheus PVE Exporter" \
        "https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/prometheus-pve-exporter.sh" \
        "$PVE_EXPORTER_ID" "pve-exporter" "$PVE_EXPORTER_CIDR" \
        "$PVE_EXPORTER_CORES" "$PVE_EXPORTER_MEMORY" "$PVE_EXPORTER_DISK" "$PVE_EXPORTER_ROOT_PASS"

    # Das Community-Script legt nur Beispiel-Zugangsdaten an. V107 erzeugt
    # deshalb einen eigenen, ausschließlich lesenden PVE-API-Benutzer samt
    # Token und ersetzt die Beispielkonfiguration vollständig.
    PVE_EXPORTER_TARGET_IP="$(
        ip -4 route get "${GATEWAY:-1.1.1.1}" 2>/dev/null |
        awk '{for (i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}'
    )"
    [[ -n "$PVE_EXPORTER_TARGET_IP" ]] || \
        PVE_EXPORTER_TARGET_IP="$(hostname -I | awk '{print $1}')"
    [[ -n "$PVE_EXPORTER_TARGET_IP" ]] || die "PVE Exporter: Proxmox-Host-IP konnte nicht ermittelt werden."

    pveum user add prometheus@pve --comment "Prometheus PVE Exporter (read-only)" >/dev/null 2>&1 || true
    pveum acl modify / -user prometheus@pve -role PVEAuditor
    pveum user token remove prometheus@pve exporter >/dev/null 2>&1 || true

    local token_json
    token_json="$(pveum user token add prometheus@pve exporter --privsep 0 --output-format json)"
    PVE_EXPORTER_TOKEN_SECRET="$(
        printf '%s' "$token_json" |
        python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("value") or d.get("token") or "")'
    )"
    [[ -n "$PVE_EXPORTER_TOKEN_SECRET" ]] || die "PVE Exporter: API-Token wurde erzeugt, Secret konnte aber nicht gelesen werden."

    pct exec "$PVE_EXPORTER_ID" -- \
        env PVE_EXPORTER_TOKEN_SECRET="$PVE_EXPORTER_TOKEN_SECRET" bash -lc '
            set -Eeuo pipefail
            install -d -m 0755 /opt/prometheus-pve-exporter
            umask 077
            cat > /opt/prometheus-pve-exporter/pve.yml <<EOF
default:
  user: prometheus@pve
  token_name: exporter
  token_value: "${PVE_EXPORTER_TOKEN_SECRET}"
  verify_ssl: false
EOF
            chmod 600 /opt/prometheus-pve-exporter/pve.yml
            systemctl restart prometheus-pve-exporter
            systemctl is-active --quiet prometheus-pve-exporter
        '

    # Nicht nur den HTTP-Port prüfen, sondern einen echten API-Scrape gegen
    # diesen Proxmox-Host erzwingen. Nur dann gilt der Exporter als funktionsfähig.
    local exporter_ok=0
    for _ in $(seq 1 30); do
        if pct exec "$PVE_EXPORTER_ID" -- \
            curl -fsS --max-time 8 \
            "http://127.0.0.1:9221/pve?target=${PVE_EXPORTER_TARGET_IP}" 2>/dev/null |
            grep -q '^pve_'; then
            exporter_ok=1
            break
        fi
        sleep 2
    done
    (( exporter_ok == 1 )) || die "PVE Exporter: echter Proxmox-Metrik-Scrape ist fehlgeschlagen."

    configure_lxc_web_standard_ports_v65 "$PVE_EXPORTER_ID" "PVE Exporter" "http" "9221"
    persist_install_secrets_v107 || true
}

install_grafana_v65() {
    install_community_generated_lxc_v65 \
        "Grafana" \
        "https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/grafana.sh" \
        "$GRAFANA_ID" "grafana" "$GRAFANA_CIDR" \
        "$GRAFANA_CORES" "$GRAFANA_MEMORY" "$GRAFANA_DISK" "$GRAFANA_ROOT_PASS"

    pct exec "$GRAFANA_ID" -- env GRAFANA_NEW_PASS="$GRAFANA_ADMIN_PASS" bash -lc '
        set -Eeuo pipefail
        if command -v grafana >/dev/null 2>&1; then
            grafana cli --homepath /usr/share/grafana admin reset-admin-password "$GRAFANA_NEW_PASS"
        elif command -v grafana-cli >/dev/null 2>&1; then
            grafana-cli --homepath /usr/share/grafana admin reset-admin-password "$GRAFANA_NEW_PASS"
        else
            echo "FEHLER: Grafana CLI wurde nicht gefunden." >&2
            exit 1
        fi
    '

    configure_lxc_web_standard_ports_v65 "$GRAFANA_ID" "Grafana" "http" "3000"
}

install_pangolin_v65() {
    install_community_generated_lxc_v65 \
        "Pangolin" \
        "https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/pangolin.sh" \
        "$PANGOLIN_ID" "pangolin" "$PANGOLIN_CIDR" \
        "$PANGOLIN_CORES" "$PANGOLIN_MEMORY" "$PANGOLIN_DISK" "$PANGOLIN_ROOT_PASS" \
        "var_tun=1" \
        "var_pangolin_url=${PANGOLIN_URL}" \
        "var_pangolin_email=${PANGOLIN_EMAIL}"

    ok "Pangolin lokal: http://${PANGOLIN_IP}:3002/"
    ok "Pangolin produktiv: HTTPS Port 443."
}

install_newt_v65() {
    install_community_generated_lxc_v65 \
        "Newt" \
        "https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/newt.sh" \
        "$NEWT_ID" "newt" "$NEWT_CIDR" \
        "$NEWT_CORES" "$NEWT_MEMORY" "$NEWT_DISK" "$NEWT_ROOT_PASS" \
        "NEWT_ID=${NEWT_SITE_ID}" \
        "NEWT_SECRET=${NEWT_SITE_SECRET}" \
        "PANGOLIN_ENDPOINT=${NEWT_ENDPOINT}"
}

install_gatus_v65() {
    install_community_generated_lxc_v65 \
        "Gatus" \
        "https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/gatus.sh" \
        "$GATUS_ID" "gatus" "$GATUS_CIDR" \
        "$GATUS_CORES" "$GATUS_MEMORY" "$GATUS_DISK" "$GATUS_ROOT_PASS"

    configure_lxc_web_standard_ports_v65 "$GATUS_ID" "Gatus" "http" "8080"
}

install_homepage_v65() {
    install_community_generated_lxc_v65 \
        "Homepage" \
        "https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/homepage.sh" \
        "$HOMEPAGE_ID" "homepage" "$HOMEPAGE_CIDR" \
        "$HOMEPAGE_CORES" "$HOMEPAGE_MEMORY" "$HOMEPAGE_DISK" "$HOMEPAGE_ROOT_PASS"

    configure_lxc_web_standard_ports_v65 "$HOMEPAGE_ID" "Homepage" "http" "3000"
}

install_npm_v65() {
    install_community_generated_lxc_v65 \
        "Nginx Proxy Manager" \
        "https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/nginxproxymanager.sh" \
        "$NPM_ID" "nginx-proxy-manager" "$NPM_CIDR" \
        "$NPM_CORES" "$NPM_MEMORY" "$NPM_DISK" "$NPM_ROOT_PASS"

    ok "NPM Proxy: Port 80/443 nativ."
    ok "NPM Admin: http://${NPM_IP}:81/"
}

install_crowdsec_addon_v65() {
    [[ -n "$CROWDSEC_TARGETS" ]] || {
        warn "Keine CrowdSec-Zielcontainer angegeben."
        return 0
    }

    local raw=""
    local ctid=""

    IFS=',' read -r -a crowdsec_ids <<<"$CROWDSEC_TARGETS"

    for raw in "${crowdsec_ids[@]}"; do
        ctid="${raw//[[:space:]]/}"

        [[ "$ctid" =~ ^[0-9]+$ ]] || {
            warn "CrowdSec: ungültige CT-ID '$raw'."
            continue
        }

        pct config "$ctid" >/dev/null 2>&1 || {
            warn "CrowdSec: CT ${ctid} existiert nicht."
            continue
        }

        if ! pct status "$ctid" | grep -q 'status: running'; then
            pct start "$ctid"
            sleep 3
        fi

        if pct exec "$ctid" -- bash -lc \
            'printf "y\n" | bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/addon/crowdsec.sh)"'
        then
            ok "CrowdSec in CT ${ctid} installiert."
        else
            warn "CrowdSec in CT ${ctid} fehlgeschlagen."
        fi
    done
}

install_emqx_v66() {
    header "EMQX MQTT BROKER INSTALLIEREN"

    COMMUNITY_STDIN_V107="\n" \
    install_community_generated_lxc_v65 \
        "EMQX" \
        "https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/emqx.sh" \
        "$EMQX_ID" "emqx" "$EMQX_CIDR" \
        "$EMQX_CORES" "$EMQX_MEMORY" "$EMQX_DISK" "$EMQX_ROOT_PASS"

    configure_lxc_web_standard_ports_v65 \
        "$EMQX_ID" \
        "EMQX Dashboard" \
        "http" \
        "18083"

    echo "Setze zufälliges EMQX Dashboard-Admin-Passwort ..."

    if pct exec "$EMQX_ID" -- bash -lc 'command -v emqx >/dev/null 2>&1'; then
        pct exec "$EMQX_ID" -- emqx ctl admins passwd admin "$EMQX_ADMIN_PASS"
    elif pct exec "$EMQX_ID" -- test -x /opt/emqx/bin/emqx; then
        pct exec "$EMQX_ID" -- /opt/emqx/bin/emqx ctl admins passwd admin "$EMQX_ADMIN_PASS"
    else
        die "EMQX CLI wurde nach der Installation nicht gefunden."
    fi

    pct exec "$EMQX_ID" -- bash -lc '
set -e
if command -v emqx >/dev/null 2>&1; then
    emqx ctl status
    emqx ctl listeners || true
elif [ -x /opt/emqx/bin/emqx ]; then
    /opt/emqx/bin/emqx ctl status
    /opt/emqx/bin/emqx ctl listeners || true
else
    exit 1
fi
ss -lnt | grep -q ":18083 "
ss -lnt | grep -q ":1883 "
'

    curl -fsS --connect-timeout 4 --max-time 10 "http://${EMQX_IP}/" >/dev/null
    curl -kfsS --connect-timeout 4 --max-time 10 "https://${EMQX_IP}/" >/dev/null

    ok "EMQX MQTT Broker aktiv."
    ok "Dashboard HTTP : http://${EMQX_IP}/"
    ok "Dashboard HTTPS: https://${EMQX_IP}/"
    ok "MQTT           : mqtt://${EMQX_IP}:1883"
    ok "MQTTS          : mqtts://${EMQX_IP}:8883"
}

# V113 · Monitoring-Stack wirklich miteinander verbinden.
# Prometheus erhält nur Jobs für Komponenten, die in diesem Lauf vorhanden sind.
configure_monitoring_stack_v107() {
    local pve_target="${PVE_EXPORTER_TARGET_IP:-}"
    local prom_cfg=""

    if (( INSTALL_PROMETHEUS && (INSTALL_PVE_EXPORTER || INSTALL_PIHOLE) )); then
        if (( INSTALL_PVE_EXPORTER )); then
            [[ -n "$pve_target" ]] || pve_target="$(
                ip -4 route get "${GATEWAY:-1.1.1.1}" 2>/dev/null |
                awk '{for (i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}'
            )"
            [[ -n "$pve_target" ]] || die "Monitoring: Proxmox-Ziel-IP konnte nicht ermittelt werden."
        fi

        prom_cfg="$(mktemp /tmp/prometheus-nodezero-v113.XXXXXX.yml)"
        cat > "$prom_cfg" <<'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ["127.0.0.1:9090"]
EOF

        if (( INSTALL_PVE_EXPORTER )); then
            cat >> "$prom_cfg" <<EOF

  - job_name: proxmox
    metrics_path: /pve
    params:
      module: [default]
    static_configs:
      - targets: ["${pve_target}"]
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: "${PVE_EXPORTER_IP}:9221"
EOF
        fi

        if (( INSTALL_PIHOLE )); then
            cat >> "$prom_cfg" <<EOF

  - job_name: pihole
    static_configs:
      - targets: ["${PIHOLE_IP}:9617"]
EOF
        fi

        pct push "$PROMETHEUS_ID" "$prom_cfg" /tmp/prometheus-nodezero-v113.yml >/dev/null
        rm -f "$prom_cfg"

        pct exec "$PROMETHEUS_ID" -- bash -lc '
            set -Eeuo pipefail
            cp -a /etc/prometheus/prometheus.yml "/etc/prometheus/prometheus.yml.v113.bak.$(date +%s)" 2>/dev/null || true
            install -m 0644 /tmp/prometheus-nodezero-v113.yml /etc/prometheus/prometheus.yml
            rm -f /tmp/prometheus-nodezero-v113.yml
            if command -v promtool >/dev/null 2>&1; then
                promtool check config /etc/prometheus/prometheus.yml
            fi
            systemctl restart prometheus
            systemctl is-active --quiet prometheus
        '

        if (( INSTALL_PVE_EXPORTER )); then
            local prom_pve_ok=0
            for _ in $(seq 1 45); do
                if curl -fsS --max-time 5 "http://${PROMETHEUS_IP}:9090/api/v1/targets" 2>/dev/null |
                    python3 -c '
import json,sys
try:
 d=json.load(sys.stdin)
 a=d.get("data",{}).get("activeTargets",[])
 ok=any(t.get("labels",{}).get("job")=="proxmox" and t.get("health")=="up" for t in a)
 raise SystemExit(0 if ok else 1)
except Exception:
 raise SystemExit(1)
'
                then
                    prom_pve_ok=1
                    break
                fi
                sleep 2
            done
            (( prom_pve_ok == 1 )) || die "Monitoring: Prometheus sieht den Proxmox-Exporter nicht als UP."
            ok "Prometheus -> PVE Exporter -> Proxmox ist vollständig verbunden."
        fi

        if (( INSTALL_PIHOLE )); then
            local prom_pihole_ok=0
            for _ in $(seq 1 45); do
                if curl -fsS --max-time 5 "http://${PROMETHEUS_IP}:9090/api/v1/targets" 2>/dev/null |
                    python3 -c '
import json,sys
try:
 d=json.load(sys.stdin)
 a=d.get("data",{}).get("activeTargets",[])
 ok=any(t.get("labels",{}).get("job")=="pihole" and t.get("health")=="up" for t in a)
 raise SystemExit(0 if ok else 1)
except Exception:
 raise SystemExit(1)
'
                then
                    prom_pihole_ok=1
                    break
                fi
                sleep 2
            done
            (( prom_pihole_ok == 1 )) || die "Monitoring: Prometheus sieht den Pi-hole-Exporter nicht als UP."
            ok "Prometheus -> Pi-hole Exporter ist vollständig verbunden."
        fi
    fi

    if (( INSTALL_GRAFANA && INSTALL_PROMETHEUS )); then
        pct exec "$GRAFANA_ID" -- env PROMETHEUS_IP="$PROMETHEUS_IP" bash -lc '
            set -Eeuo pipefail
            install -d -m 0755 /etc/grafana/provisioning/datasources
            cat > /etc/grafana/provisioning/datasources/proxmox-prometheus-v107.yaml <<EOF
apiVersion: 1
datasources:
  - name: Prometheus
    uid: prometheus-v107
    type: prometheus
    access: proxy
    url: http://${PROMETHEUS_IP}:9090
    isDefault: true
    editable: true
EOF
            systemctl restart grafana-server
            systemctl is-active --quiet grafana-server
        '

        local grafana_ok=0
        for _ in $(seq 1 30); do
            if curl -fsS --max-time 5 -u "admin:${GRAFANA_ADMIN_PASS}" \
                "http://${GRAFANA_IP}:3000/api/datasources/uid/prometheus-v107" 2>/dev/null |
                grep -q '"type":"prometheus"'; then
                grafana_ok=1
                break
            fi
            sleep 2
        done
        (( grafana_ok == 1 )) || die "Monitoring: Grafana Prometheus-Datasource wurde nicht erfolgreich provisioniert."
        ok "Grafana -> Prometheus Datasource ist vollständig verbunden."
    fi
}

configure_pbs_native_tls_v88() {
    local ctid="$1"
    local ip="$2"
    local hostname="proxmox-backup-server"
    local cert_dir cert key

    cert_dir="$(mktemp -d "/tmp/pbs-native-cert-${ctid}.XXXXXX")"
    read_issued_cert_pair_v68 "$ip" "$hostname" "$cert_dir" cert key

    pct push "$ctid" "$cert" /etc/proxmox-backup/proxy.pem -perms 0640 >/dev/null
    pct push "$ctid" "$key" /etc/proxmox-backup/proxy.key -perms 0640 >/dev/null
    rm -rf "$cert_dir"

    pct exec "$ctid" -- chown root:backup /etc/proxmox-backup/proxy.pem /etc/proxmox-backup/proxy.key
    pct exec "$ctid" -- systemctl reload proxmox-backup-proxy

    register_managed_tls_service_v88 "pbs-native" "$ctid" "Proxmox Backup Server" "$ip" "$hostname"
    ok "PBS bleibt nativ auf HTTPS-Port 8007 und nutzt das verwaltete NodeZero-Zertifikat."
}

install_proxmox_backup_server() {
    header "PROXMOX BACKUP SERVER INSTALLIEREN"

    install_community_generated_lxc \
        "Proxmox Backup Server" \
        "https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/proxmox-backup-server.sh" \
        "$PBS_ID" "proxmox-backup-server" "$PBS_CIDR" \
        "$PBS_CORES" "$PBS_MEMORY" "$PBS_DISK" "$PBS_ROOT_PASS"

    configure_pbs_native_tls_v88 "$PBS_ID" "$PBS_IP"

    ok "Proxmox Backup Server installiert."
    echo "Web: https://${PBS_IP}:8007/"
    echo "Nativer PBS-Port 8007 bleibt erhalten."
    echo "Datastore muss anschließend in PBS eingerichtet werden."
}

pulse_detect_pve_host_ip() {
    local ip=""

    ip="$(
        ip -4 route get "${GATEWAY:-1.1.1.1}" 2>/dev/null |
        awk '{
            for (i=1; i<=NF; i++) {
                if ($i == "src" && (i+1) <= NF) {
                    print $(i+1)
                    exit
                }
            }
        }'
    )"

    if [[ -z "$ip" && -n "${BRIDGE:-}" ]]; then
        ip="$(
            ip -4 -o addr show dev "$BRIDGE" scope global 2>/dev/null |
            awk '{print $4}' |
            cut -d/ -f1 |
            head -n 1
        )"
    fi

    if [[ -z "$ip" ]]; then
        ip="$(
            hostname -I 2>/dev/null |
            tr ' ' '\n' |
            grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' |
            head -n 1 || true
        )"
    fi

    [[ -n "$ip" ]] || return 1
    printf '%s\n' "$ip"
}

configure_pulse_headless() {
    local ctid="$1"
    local pulse_ip="$2"
    local admin_user="$3"
    local admin_pass="$4"
    local api_token="$5"
    local discovery_subnet="$6"

    info "Pulse: Security-/Admin-Konfiguration für aktuelle v6-LXC-Installation vorbereiten."

    pct exec "$ctid" -- bash -s -- \
        "$pulse_ip" \
        "$admin_user" \
        "$admin_pass" \
        "$api_token" \
        "$discovery_subnet" <<'EOS'
set -Eeuo pipefail

PULSE_IP="$1"
ADMIN_USER="$2"
ADMIN_PASS="$3"
API_TOKEN="$4"
DISCOVERY_SUBNET="$5"

DATA_DIR="/etc/pulse"
ENV_FILE="${DATA_DIR}/.env"
SERVICE="pulse.service"

# Aktuelle Community-Scripts-Installation:
#   User=pulse
#   PULSE_DATA_DIR=/etc/pulse
#   kein systemd EnvironmentFile=
#
# Pulse selbst liest ${PULSE_DATA_DIR}/.env. V85 legte die Datei zwar dort an,
# aber root:root 0600. Da pulse.service als User=pulse läuft, konnte Pulse diese
# Datei weder zuverlässig lesen noch im Security-Setup aktualisieren.
SERVICE_USER="$(
    systemctl show "$SERVICE" -p User --value 2>/dev/null || true
)"
SERVICE_GROUP="$(
    systemctl show "$SERVICE" -p Group --value 2>/dev/null || true
)"

SERVICE_USER="${SERVICE_USER:-pulse}"
SERVICE_GROUP="${SERVICE_GROUP:-pulse}"

mkdir -p "$DATA_DIR"

if id "$SERVICE_USER" >/dev/null 2>&1; then
    chown "$SERVICE_USER:$SERVICE_GROUP" "$DATA_DIR"
fi

chmod 700 "$DATA_DIR"

touch "$ENV_FILE"

# Nur vom Master verwaltete Werte austauschen.
sed -i \
    -e '/^PULSE_AUTH_USER=/d' \
    -e '/^PULSE_AUTH_PASS=/d' \
    -e '/^API_TOKENS=/d' \
    -e '/^API_TOKEN=/d' \
    -e '/^PULSE_PUBLIC_URL=/d' \
    -e '/^ALLOWED_ORIGINS=/d' \
    -e '/^PULSE_TRUSTED_PROXY_CIDRS=/d' \
    -e '/^DISCOVERY_SUBNET=/d' \
    -e '/^FRONTEND_PORT=/d' \
    -e '/^BIND_ADDRESS=/d' \
    -e '/^TZ=/d' \
    "$ENV_FILE"

cat >> "$ENV_FILE" <<EOF
PULSE_AUTH_USER=${ADMIN_USER}
PULSE_AUTH_PASS=${ADMIN_PASS}
API_TOKENS=${API_TOKEN}
PULSE_PUBLIC_URL=http://${PULSE_IP}
ALLOWED_ORIGINS=http://${PULSE_IP}
PULSE_TRUSTED_PROXY_CIDRS=127.0.0.1/32
DISCOVERY_SUBNET=${DISCOVERY_SUBNET}
FRONTEND_PORT=7655
BIND_ADDRESS=0.0.0.0
TZ=Europe/Berlin
EOF

if id "$SERVICE_USER" >/dev/null 2>&1; then
    chown "$SERVICE_USER:$SERVICE_GROUP" "$ENV_FILE"

    # Bereits durch einen fehlgeschlagenen First-Run erzeugte Security-Dateien
    # müssen ebenfalls vom Pulse-Dienst beschreibbar sein.
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$DATA_DIR"
fi

chmod 700 "$DATA_DIR"
chmod 600 "$ENV_FILE"

systemctl daemon-reload
systemctl restart "$SERVICE"

# Auf die öffentliche Health-API warten.
for _ in $(seq 1 60); do
    code="$(
        curl -sS \
            --connect-timeout 2 \
            --max-time 4 \
            -o /dev/null \
            -w '%{http_code}' \
            http://127.0.0.1:7655/api/health \
            2>/dev/null || true
    )"

    case "$code" in
        2??|3??)
            break
            ;;
    esac

    sleep 2
done

code="$(
    curl -sS \
        --connect-timeout 2 \
        --max-time 4 \
        -o /dev/null \
        -w '%{http_code}' \
        http://127.0.0.1:7655/api/health \
        2>/dev/null || true
)"

case "$code" in
    2??|3??)
        ;;
    *)
        echo "FEHLER: Pulse API wurde nach Security-Konfiguration nicht erreichbar." >&2
        echo "--- Listener ---" >&2
        ss -lntp 2>/dev/null | grep -E '(:7655|pulse)' >&2 || true
        echo "--- Service ---" >&2
        systemctl status "$SERVICE" --no-pager -l >&2 || true
        echo "--- Journal ---" >&2
        journalctl -u "$SERVICE" -n 120 --no-pager >&2 || true
        exit 1
        ;;
esac

# Wirklich prüfen, ob Benutzer/Passwort akzeptiert werden.
LOGIN_JSON="$(
    python3 - \
        "$ADMIN_USER" \
        "$ADMIN_PASS" <<'PY'
import json
import sys
print(json.dumps({
    "username": sys.argv[1],
    "password": sys.argv[2],
    "rememberMe": False,
}))
PY
)"

LOGIN_CODE="$(
    curl -sS \
        --connect-timeout 3 \
        --max-time 8 \
        -o /tmp/pulse-login-v86.json \
        -w '%{http_code}' \
        -H 'Content-Type: application/json' \
        -X POST \
        --data "$LOGIN_JSON" \
        http://127.0.0.1:7655/api/login \
        2>/dev/null || true
)"

case "$LOGIN_CODE" in
    2??)
        echo "[OK] Pulse Admin-Authentifizierung funktioniert."
        ;;
    *)
        echo "FEHLER: Pulse Admin-Login fehlgeschlagen (HTTP ${LOGIN_CODE:-kein Code})." >&2
        cat /tmp/pulse-login-v86.json >&2 2>/dev/null || true
        journalctl -u "$SERVICE" -n 80 --no-pager >&2 || true
        rm -f /tmp/pulse-login-v86.json
        exit 1
        ;;
esac

rm -f /tmp/pulse-login-v86.json

echo "[OK] Pulse Security-Dateien gehören ${SERVICE_USER}:${SERVICE_GROUP}."
EOS

    ok "Pulse: Security-Konfiguration ist beschreibbar; Admin-Login wurde geprüft."
}

pulse_validate_api_token_v86() {
    local code=""

    # /api/health ist öffentlich und kann einen falschen Token nicht erkennen.
    # /api/state/summary benötigt monitoring:read und eignet sich zur echten Prüfung.
    code="$(
        curl -sS \
            --connect-timeout 5 \
            --max-time 12 \
            -o /dev/null \
            -w '%{http_code}' \
            -H "X-API-Token: ${PULSE_API_TOKEN}" \
            "http://${PULSE_IP}:7655/api/state/summary" \
            2>/dev/null || true
    )"

    case "$code" in
        2??)
            PULSE_API_TOKEN_VALID=1
            ok "Pulse API-Token wurde an einem geschützten Endpoint verifiziert."
            return 0
            ;;
        *)
            PULSE_API_TOKEN_VALID=0
            warn "Pulse API-Token ist noch nicht nutzbar (HTTP ${code:-kein Code})."
            warn "Pulse selbst ist installiert; automatische PVE/PBS-Registrierung wird übersprungen."
            return 1
            ;;
    esac
}


pulse_setup_artifact() {
    local type="$1"
    local host_url="$2"
    local backup_perms="${3:-false}"
    local response=""
    local payload=""

    payload="$(
        python3 - \
            "$type" \
            "$host_url" \
            "$backup_perms" <<'PY'
import json
import sys

node_type = sys.argv[1]
host = sys.argv[2]
backup = sys.argv[3].lower() == "true"

data = {
    "type": node_type,
    "host": host,
}

if node_type == "pve":
    data["backupPerms"] = backup

print(json.dumps(data, separators=(",", ":")))
PY
    )"

    response="$(
        curl -fsS \
            --connect-timeout 10 \
            --max-time 30 \
            -H "X-API-Token: ${PULSE_API_TOKEN}" \
            -H "Content-Type: application/json" \
            -X POST \
            --data "$payload" \
            "http://${PULSE_IP}:7655/api/setup-script-url"
    )"

    python3 - <<'PY' <<<"$response"
import json
import sys
from urllib.parse import urlparse

data = json.load(sys.stdin)

token = data.get("setupToken")
url = data.get("downloadURL")
expires = data.get("expires")

if not isinstance(token, str) or not token:
    raise SystemExit("Pulse setupToken fehlt.")

if not isinstance(url, str) or not url:
    raise SystemExit("Pulse downloadURL fehlt.")

if not expires:
    raise SystemExit("Pulse setupToken-Ablaufzeit fehlt.")

parsed = urlparse(url)

if parsed.scheme not in ("http", "https"):
    raise SystemExit("Pulse downloadURL hat ein ungültiges Schema.")

print(token)
print(url)
PY
}

pulse_register_pve_host() {
    local pve_ip=""
    local artifact=""
    local setup_token=""
    local download_url=""
    local tmp=""

    pve_ip="$(pulse_detect_pve_host_ip)" || {
        warn "Pulse: Proxmox-Host-IP konnte nicht automatisch ermittelt werden."
        return 1
    }

    info "Pulse: Proxmox VE ${pve_ip} automatisch registrieren."

    artifact="$(
        pulse_setup_artifact \
            "pve" \
            "https://${pve_ip}:8006" \
            "true"
    )" || {
        warn "Pulse: Setup-Artefakt für Proxmox VE konnte nicht erzeugt werden."
        return 1
    }

    setup_token="$(sed -n '1p' <<<"$artifact")"
    download_url="$(sed -n '2p' <<<"$artifact")"

    case "$download_url" in
        "http://${PULSE_IP}/"*|"http://${PULSE_IP}:7655/"*|"https://${PULSE_IP}/"*)
            ;;
        *)
            warn "Pulse: unerwartete Setup-URL; automatische PVE-Registrierung wird aus Sicherheitsgründen nicht ausgeführt."
            return 1
            ;;
    esac

    tmp="$(mktemp /tmp/pulse-pve-setup.XXXXXX.sh)"

    if ! curl -fsSL \
        --connect-timeout 10 \
        --max-time 60 \
        "$download_url" \
        -o "$tmp"; then
        rm -f "$tmp"
        warn "Pulse: PVE-Setup-Script konnte nicht geladen werden."
        return 1
    fi

    chmod 700 "$tmp"

    if PULSE_SETUP_TOKEN="$setup_token" bash "$tmp"; then
        PULSE_PVE_REGISTERED=1
        ok "Pulse: Proxmox VE wurde automatisch registriert."
    else
        warn "Pulse: automatische Proxmox-Registrierung ist fehlgeschlagen."
        rm -f "$tmp"
        return 1
    fi

    rm -f "$tmp"
}

pulse_register_pbs() {
    local artifact=""
    local setup_token=""
    local download_url=""
    local tmp=""
    local inside="/root/pulse-pbs-setup.sh"

    (( INSTALL_PBS )) || return 0
    pct status "$PBS_ID" >/dev/null 2>&1 || return 1

    info "Pulse: Proxmox Backup Server automatisch registrieren."

    artifact="$(
        pulse_setup_artifact \
            "pbs" \
            "https://${PBS_IP}:8007" \
            "false"
    )" || {
        warn "Pulse: Setup-Artefakt für PBS konnte nicht erzeugt werden."
        return 1
    }

    setup_token="$(sed -n '1p' <<<"$artifact")"
    download_url="$(sed -n '2p' <<<"$artifact")"

    case "$download_url" in
        "http://${PULSE_IP}/"*|"http://${PULSE_IP}:7655/"*|"https://${PULSE_IP}/"*)
            ;;
        *)
            warn "Pulse: unerwartete PBS-Setup-URL; automatische Registrierung wird aus Sicherheitsgründen nicht ausgeführt."
            return 1
            ;;
    esac

    tmp="$(mktemp /tmp/pulse-pbs-setup.XXXXXX.sh)"

    if ! curl -fsSL \
        --connect-timeout 10 \
        --max-time 60 \
        "$download_url" \
        -o "$tmp"; then
        rm -f "$tmp"
        warn "Pulse: PBS-Setup-Script konnte nicht geladen werden."
        return 1
    fi

    chmod 700 "$tmp"

    pct push "$PBS_ID" "$tmp" "$inside" -perms 0700 >/dev/null
    rm -f "$tmp"

    if pct exec "$PBS_ID" -- \
        env "PULSE_SETUP_TOKEN=${setup_token}" \
        bash "$inside"; then

        PULSE_PBS_REGISTERED=1
        ok "Pulse: PBS wurde automatisch registriert."
    else
        warn "Pulse: automatische PBS-Registrierung ist fehlgeschlagen."
        pct exec "$PBS_ID" -- rm -f "$inside" >/dev/null 2>&1 || true
        return 1
    fi

    pct exec "$PBS_ID" -- rm -f "$inside" >/dev/null 2>&1 || true
}

install_pulse_community() {
    header "PULSE INSTALLIEREN & EINRICHTEN"

    install_community_generated_lxc \
        "Pulse" \
        "https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/pulse.sh" \
        "$PULSE_ID" "pulse" "$PULSE_CIDR" \
        "$PULSE_CORES" "$PULSE_MEMORY" "$PULSE_DISK" "$PULSE_ROOT_PASS"

    configure_pulse_headless \
        "$PULSE_ID" \
        "$PULSE_IP" \
        "$PULSE_ADMIN_USER" \
        "$PULSE_ADMIN_PASS" \
        "$PULSE_API_TOKEN" \
        "${NETWORK_PREFIX}.0/24"

    configure_lxc_web_port80 \
        "$PULSE_ID" \
        "Pulse" \
        "http" \
        "7655"

    # V86: API-Token nicht mehr an /api/health prüfen, da Health öffentlich ist.
    if pulse_validate_api_token_v86; then
        # Standardmäßig API-only anbinden: kleinste benötigte Rechte,
        # kein zusätzlicher Agent auf dem Proxmox-Host.
        if ! pulse_register_pve_host; then
            (( OPTIMAL_INSTALL )) && die "Pulse: Proxmox-Registrierung im Optimalmodus fehlgeschlagen."
        fi

        if (( INSTALL_PBS )); then
            if ! pulse_register_pbs; then
                (( OPTIMAL_INSTALL )) && die "Pulse: PBS-Registrierung im Optimalmodus fehlgeschlagen."
            fi
        fi
    else
        (( OPTIMAL_INSTALL )) && die "Pulse: API-Token konnte im Optimalmodus nicht verifiziert werden."
    fi

    # Status für den Pulse-Fehlerwrapper außerhalb des Subshells persistieren.
    if [[ -n "${PULSE_STATE_FILE_V86:-}" ]]; then
        {
            printf 'PULSE_PVE_REGISTERED=%q\n' "$PULSE_PVE_REGISTERED"
            printf 'PULSE_PBS_REGISTERED=%q\n' "$PULSE_PBS_REGISTERED"
            printf 'PULSE_API_TOKEN_VALID=%q\n' "$PULSE_API_TOKEN_VALID"
        } > "$PULSE_STATE_FILE_V86"
        chmod 600 "$PULSE_STATE_FILE_V86"
    fi

    ok "Pulse installiert und vorkonfiguriert."
    echo "Web: https://${PULSE_IP}/"
    echo "Admin: ${PULSE_ADMIN_USER}"
    echo "API-Token gültig: $([[ "$PULSE_API_TOKEN_VALID" -eq 1 ]] && echo ja || echo nein)"
    echo "Proxmox automatisch registriert: $([[ "$PULSE_PVE_REGISTERED" -eq 1 ]] && echo ja || echo nein)"
    if (( INSTALL_PBS )); then
        echo "PBS automatisch registriert: $([[ "$PULSE_PBS_REGISTERED" -eq 1 ]] && echo ja || echo nein)"
    fi
}

run_pulse_install_step_v86() {
    local state="/tmp/pulse-install-state-v86.$$"
    local rc=0

    ui_progress_step "Pulse"

    rm -f "$state"

    # Pulse ist eine optionale Community-Erweiterung. Ein Fehler dort darf
    # Prometheus/Grafana/EMQX und den Abschluss des Master-Installers nicht stoppen.
    set +e
    (
        export PULSE_STATE_FILE_V86="$state"
        install_pulse_community
    )
    rc=$?
    set -e

    if [[ -f "$state" ]]; then
        # Nur drei numerische, vom eigenen Installer erzeugte Variablen laden.
        # shellcheck disable=SC1090
        source "$state"
        rm -f "$state"
    fi

    if (( rc != 0 )); then
        PULSE_INSTALL_FAILED=1
        PULSE_INSTALL_ERROR="Pulse-Setup fehlgeschlagen (Exit ${rc})"

        echo
        warn "Pulse-Einrichtung ist fehlgeschlagen (Exit ${rc})."
        if (( OPTIMAL_INSTALL )); then
            die "Pulse ist Bestandteil des festen Optimal-Stacks; Installation wird nicht als erfolgreich fortgesetzt."
        fi
        warn "Der übrige manuelle Installationslauf wird trotzdem fortgesetzt."
        warn "Pulse später reparieren mit: pulse-security-repair-v87"
        echo
        persist_install_secrets_v107 || true

        return 0
    fi

    PULSE_INSTALL_FAILED=0
    PULSE_INSTALL_ERROR=""
    persist_install_secrets_v107 || true
    return 0
}


install_pulse_repair_tool_v87() {
    local tool="/usr/local/sbin/pulse-security-repair-v87"

    cat > "$tool" <<'__PULSE_SECURITY_REPAIR_V87__'
#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || {
    echo "FEHLER: Bitte als root auf dem Proxmox-Host ausführen."
    exit 1
}

STAMP="$(date +%d-%m-%H-%M)"
LOGDIR="/root/diagnose"
BACKUPDIR="/root/backups"
LOG="${LOGDIR}/pulse-security-repair-v87-${STAMP}.txt"

mkdir -p "$LOGDIR" "$BACKUPDIR"

if [[ -e "$LOG" ]]; then
    N=2
    while [[ -e "${LOGDIR}/pulse-security-repair-v87-${STAMP}-${N}.txt" ]]; do
        N=$((N + 1))
    done
    LOG="${LOGDIR}/pulse-security-repair-v87-${STAMP}-${N}.txt"
fi

exec > >(tee -a "$LOG") 2>&1

find_pulse_ct() {
    local id host

    while read -r id; do
        [[ "$id" =~ ^[0-9]+$ ]] || continue

        host="$(
            pct config "$id" 2>/dev/null |
            awk -F': ' '/^hostname:/ {print $2; exit}'
        )"

        if [[ "$host" == "pulse" ]]; then
            echo "$id"
            return 0
        fi
    done < <(pct list 2>/dev/null | awk 'NR>1 {print $1}')

    return 1
}

CTID="$(find_pulse_ct || true)"

[[ -n "$CTID" ]] || {
    echo "FEHLER: Kein LXC mit Hostname 'pulse' gefunden."
    exit 1
}

if ! pct status "$CTID" | grep -q "status: running"; then
    pct start "$CTID"
    sleep 5
fi

IP="$(
    pct config "$CTID" |
    awk -F'ip=' '/^net0:/ {
        split($2,a,",");
        split(a[1],b,"/");
        print b[1];
        exit
    }'
)"

[[ -n "$IP" ]] || {
    echo "FEHLER: Pulse-IP konnte nicht ermittelt werden."
    exit 1
}

BACKUP="${BACKUPDIR}/pulse-ct${CTID}-v87-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"

pct exec "$CTID" -- bash -lc '
tar -C / -czf /tmp/pulse-v86-backup.tgz \
    etc/pulse \
    etc/systemd/system/pulse.service \
    2>/dev/null || true
'
pct pull "$CTID" /tmp/pulse-v86-backup.tgz "$BACKUP/pulse-v86-backup.tgz" >/dev/null 2>&1 || true
pct exec "$CTID" -- rm -f /tmp/pulse-v86-backup.tgz 2>/dev/null || true

echo "============================================================"
echo " PULSE SECURITY REPAIR V87"
echo "============================================================"
echo "CT: $CTID"
echo "IP: $IP"
echo
echo "V85/V86-Ursache:"
echo "  /etc/pulse/.env wurde root:root 0600 angelegt."
echo "  pulse.service läuft aber als Benutzer 'pulse'."
echo "  Dadurch konnte das Security-Setup nicht zuverlässig gespeichert werden.
  Zusätzlich prüfte V86 danach fälschlich Port 80 statt den nativen Pulse-Port 7655."
echo
echo "Backup:"
echo "  $BACKUP"
echo

ADMIN_USER="admin"

read -rsp "Neues Pulse Admin-Passwort (ENTER = automatisch): " ADMIN_PASS
echo

if [[ -z "$ADMIN_PASS" ]]; then
    ADMIN_PASS="$(
        python3 - <<'PY'
import secrets
alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#%_-"
print("".join(secrets.choice(alphabet) for _ in range(24)))
PY
    )"
    echo "Starkes Admin-Passwort automatisch erzeugt."
fi

[[ ${#ADMIN_PASS} -ge 8 ]] || {
    echo "FEHLER: Passwort muss mindestens 8 Zeichen lang sein."
    exit 1
}

API_TOKEN="$(
    openssl rand -hex 32
)"

pct exec "$CTID" -- bash -s -- \
    "$IP" \
    "$ADMIN_USER" \
    "$ADMIN_PASS" \
    "$API_TOKEN" <<'EOS'
set -Eeuo pipefail

IP="$1"
ADMIN_USER="$2"
ADMIN_PASS="$3"
API_TOKEN="$4"

DATA_DIR="/etc/pulse"
ENV_FILE="${DATA_DIR}/.env"
SERVICE="pulse.service"

SERVICE_USER="$(
    systemctl show "$SERVICE" -p User --value 2>/dev/null || true
)"
SERVICE_GROUP="$(
    systemctl show "$SERVICE" -p Group --value 2>/dev/null || true
)"

SERVICE_USER="${SERVICE_USER:-pulse}"
SERVICE_GROUP="${SERVICE_GROUP:-pulse}"

mkdir -p "$DATA_DIR"

# Erst Besitzrechte der gesamten Pulse-Konfiguration reparieren.
if id "$SERVICE_USER" >/dev/null 2>&1; then
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$DATA_DIR"
fi

chmod 700 "$DATA_DIR"

touch "$ENV_FILE"

sed -i \
    -e '/^PULSE_AUTH_USER=/d' \
    -e '/^PULSE_AUTH_PASS=/d' \
    -e '/^API_TOKENS=/d' \
    -e '/^API_TOKEN=/d' \
    -e '/^PULSE_PUBLIC_URL=/d' \
    -e '/^ALLOWED_ORIGINS=/d' \
    -e '/^FRONTEND_PORT=/d' \
    -e '/^BIND_ADDRESS=/d' \
    "$ENV_FILE"

cat >> "$ENV_FILE" <<EOF
PULSE_AUTH_USER=${ADMIN_USER}
PULSE_AUTH_PASS=${ADMIN_PASS}
API_TOKENS=${API_TOKEN}
PULSE_PUBLIC_URL=http://${IP}:7655
ALLOWED_ORIGINS=http://${IP}:7655
FRONTEND_PORT=7655
BIND_ADDRESS=0.0.0.0
TZ=Europe/Berlin
EOF

if id "$SERVICE_USER" >/dev/null 2>&1; then
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$DATA_DIR"
fi

chmod 700 "$DATA_DIR"
chmod 600 "$ENV_FILE"

systemctl restart "$SERVICE"

for _ in $(seq 1 45); do
    if curl -fsS \
        --connect-timeout 2 \
        --max-time 4 \
        http://127.0.0.1:7655/api/health \
        >/dev/null 2>&1; then
        exit 0
    fi

    sleep 2
done

journalctl -u "$SERVICE" -n 100 --no-pager >&2 || true
exit 1
EOS

echo
echo "Prüfe Pulse nativen Listener auf Port 7655 ..."

LISTEN_CODE="$(
    curl -sS         --connect-timeout 4         --max-time 8         -o /dev/null         -w '%{http_code}'         "http://${IP}:7655/api/health"         2>/dev/null || true
)"

case "$LISTEN_CODE" in
    2??|3??)
        echo "  ✓ Pulse ist direkt auf ${IP}:7655 erreichbar."
        ;;
    *)
        echo "FEHLER: Pulse ist von Proxmox nicht auf ${IP}:7655 erreichbar."
        echo
        echo "Listener im Pulse-LXC:"
        pct exec "$CTID" -- bash -lc             'ss -lntp 2>/dev/null | grep -E "(:7655|pulse)" || true'
        echo
        echo "Pulse Service:"
        pct exec "$CTID" -- systemctl status pulse.service --no-pager -l || true
        echo
        echo "Pulse Journal:"
        pct exec "$CTID" -- journalctl -u pulse.service -n 120 --no-pager || true
        exit 1
        ;;
esac

echo
echo "Prüfe Pulse Admin-Login direkt auf Port 7655 ..."

LOGIN_CODE="$(
    PULSE_URL="http://${IP}:7655" \
    PULSE_USER="$ADMIN_USER" \
    PULSE_PASS="$ADMIN_PASS" \
    python3 <<'PY'
import json
import os
import urllib.error
import urllib.request

url = os.environ["PULSE_URL"].rstrip("/") + "/api/login"

req = urllib.request.Request(
    url,
    data=json.dumps({
        "username": os.environ["PULSE_USER"],
        "password": os.environ["PULSE_PASS"],
        "rememberMe": False,
    }).encode(),
    headers={"Content-Type": "application/json"},
    method="POST",
)

try:
    with urllib.request.urlopen(req, timeout=10) as response:
        print(response.status)
except urllib.error.HTTPError as exc:
    print(exc.code)
PY
)"

case "$LOGIN_CODE" in
    2??)
        echo "  ✓ Admin-Login funktioniert."
        ;;
    *)
        echo "FEHLER: Admin-Login fehlgeschlagen (HTTP $LOGIN_CODE)."
        exit 1
        ;;
esac

echo
echo "Prüfe API-Token an geschütztem Endpoint ..."

TOKEN_CODE="$(
    curl -sS \
        --connect-timeout 4 \
        --max-time 10 \
        -o /dev/null \
        -w '%{http_code}' \
        -H "X-API-Token: ${API_TOKEN}" \
        "http://${IP}:7655/api/state/summary" \
        2>/dev/null || true
)"

install -d -m 0700 -o root -g root /root/passwort
STAMP_SEC="$(date +%Y%m%d-%H%M%S)"
PWFILE_ADMIN="/root/passwort/pulse-admin-pw-${STAMP_SEC}.txt"
PWFILE_TOKEN="/root/passwort/pulse-api-token-pw-${STAMP_SEC}.txt"

umask 077
cat > "$PWFILE_ADMIN" <<EOF
Komponente: Pulse Admin
Erstellt: $(date '+%d.%m.%Y %H:%M:%S')
CT-ID: $CTID
Web: http://${IP}/
Benutzer: ${ADMIN_USER}

Secret:
${ADMIN_PASS}
EOF

cat > "$PWFILE_TOKEN" <<EOF
Komponente: Pulse API Token
Erstellt: $(date '+%d.%m.%Y %H:%M:%S')
CT-ID: $CTID
API-Token Test HTTP: ${TOKEN_CODE}

Secret:
${API_TOKEN}
EOF
chmod 600 "$PWFILE_ADMIN" "$PWFILE_TOKEN"

echo
echo "============================================================"
echo " REPARATUR ABGESCHLOSSEN"
echo "============================================================"
echo "Web (direkt):"
echo "  http://${IP}:7655/"
echo
echo "Port 80 ist nur verfügbar, wenn der Master-Reverse-Proxy"
echo "für Pulse bereits eingerichtet wurde."
echo
echo "Admin:"
echo "  ${ADMIN_USER}"
echo
echo "Passwort:"
echo "  ${ADMIN_PASS}"
echo
echo "API-Token Test:"
case "$TOKEN_CODE" in
    2??)
        echo "  ✓ gültig (HTTP $TOKEN_CODE)"
        ;;
    *)
        echo "  ! noch nicht als Managed Token aktiv (HTTP ${TOKEN_CODE:-kein Code})"
        echo "  Pulse selbst funktioniert trotzdem."
        echo "  Falls nötig: Settings → Security → API Tokens → New token"
        ;;
esac
echo
echo "Gespeichert:"
echo "  $PWFILE_ADMIN"
echo "  $PWFILE_TOKEN"
echo
echo "Log:"
echo "  $LOG"
__PULSE_SECURITY_REPAIR_V87__

    chmod 700 "$tool"
    chown root:root "$tool"
}

install_pulse_repair_tool_v87


configure_pve_ups_policy_and_report_v58() {
    header "PVE-UPS · SHUTDOWN-LOGIK / STATUSBERICHT"
    local patch="/tmp/pve-ups-policy-report-v58.$$"
    cat > "$patch" <<'__PVE_V58_UPS_CONFIG_REPORT__'
#!/usr/bin/env bash
set -Eeuo pipefail

STAMP="$(date +%d-%m-%H-%M)"
LOGFILE="/root/diagnose/diagnose-pve-ups-konfiguration-statusbericht-${STAMP}.txt"

if [[ -e "$LOGFILE" ]]; then
    N=2
    while [[ -e "/root/diagnose/diagnose-pve-ups-konfiguration-statusbericht-${STAMP}-${N}.txt" ]]; do
        N=$((N + 1))
    done
    LOGFILE="/root/diagnose/diagnose-pve-ups-konfiguration-statusbericht-${STAMP}-${N}.txt"
fi

exec > >(tee -a "$LOGFILE") 2>&1

[[ ${EUID:-$(id -u)} -eq 0 ]] || {
    echo "FEHLER: Bitte als root auf dem Proxmox-Host ausführen."
    exit 1
}

command -v pct >/dev/null 2>&1 || {
    echo "FEHLER: pct wurde nicht gefunden. Dieses Script muss auf Proxmox VE laufen."
    exit 1
}

CONFIGURE_PY="/tmp/pve-ups-configure-v58.py"
TEST_PY="/tmp/pve-ups-test-arm-v58.py"
REPORT_PY="/tmp/pve-ups-status-report-v58.py"
RUNNER="/tmp/pve-ups-python-runner-v58"
SERVICE="/tmp/pve-usv-status-report.service"
TIMER="/tmp/pve-usv-status-report.timer"

cleanup() {
    rm -f \
        "$CONFIGURE_PY" \
        "$TEST_PY" \
        "$REPORT_PY" \
        "$RUNNER" \
        "$SERVICE" \
        "$TIMER"
}
trap cleanup EXIT

detect_pveups_ct() {
    if [[ -n "${PVEUPS_CTID:-}" ]]; then
        printf '%s\n' "$PVEUPS_CTID"
        return 0
    fi

    local id=""

    id="$(
        pct list 2>/dev/null |
        awk '
            NR > 1 {
                name=tolower($3)
                if (
                    name == "pve-ups"
                    || name == "pve-usv"
                    || name ~ /^pve[-_]?ups/
                    || name ~ /^pve[-_]?usv/
                ) {
                    print $1
                    exit
                }
            }
        '
    )"

    if [[ -n "$id" ]]; then
        printf '%s\n' "$id"
        return 0
    fi

    # Fallback: CT mit der bekannten PVE-UPS-Adresse 192.168.178.111.
    while read -r candidate; do
        [[ "$candidate" =~ ^[0-9]+$ ]] || continue

        if pct config "$candidate" 2>/dev/null |
           grep -Eq 'ip=192\.168\.178\.111(/|,|$)'; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done < <(
        pct list 2>/dev/null |
        awk 'NR > 1 {print $1}'
    )

    return 1
}

CTID="$(detect_pveups_ct)" || {
    echo "FEHLER: PVE-UPS-LXC wurde nicht automatisch gefunden."
    echo "Alternativ:"
    echo "  PVEUPS_CTID=<CT-ID> $0"
    exit 1
}

NODE_NAME="$(hostname -s)"
PVE_IP="$(
    ip -4 route get 1.1.1.1 2>/dev/null |
    awk '{
        for(i=1;i<=NF;i++){
            if($i=="src"){
                print $(i+1)
                exit
            }
        }
    }'
)"

if [[ -z "$PVE_IP" ]]; then
    PVE_IP="$(
        hostname -I 2>/dev/null |
        tr ' ' '\n' |
        grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' |
        head -n 1
    )"
fi

[[ -n "$PVE_IP" ]] || {
    echo "FEHLER: IPv4-Adresse des Proxmox-Hosts konnte nicht ermittelt werden."
    exit 1
}

echo "============================================================"
echo " PVE-UPS KONFIGURATION + 12H STATUSBERICHT"
echo "============================================================"
echo
echo "PVE-UPS CT: $CTID"
echo "Proxmox:    $NODE_NAME / $PVE_IP"
echo
echo "USV:"
echo "  NAS -> NUT 192.168.178.20:3493 / ups"
echo
echo "Shutdown:"
echo "  600 s Akkubetrieb"
echo "  Restlaufzeit < 10 Min."
echo "  Ladestand < 30 %"
echo "  Battery low/depleted = sofort"
echo "  Poll Netz 30 s / Akku 8 s"
echo "  Nicht erreichbar nach 3 Polls"
echo "  Kommunikationsverlust bei Netzbetrieb = KEIN Shutdown"
echo "  laufender Batterie-Countdown bleibt bei Kommunikationsverlust aktiv"
echo "  Host-Shutdown-Timeout 60 s"
echo "  Wieder scharf nach 5 Min. stabilem Netz"
echo
echo "Statusbericht:"
echo "  08:00 + 20:00 Europe/Berlin"
echo "  interner systemd-Timer im PVE-UPS-LXC"
echo "  kein externer Cronjob"
echo
echo "Log:"
echo "  $LOGFILE"
echo

if ! pct status "$CTID" 2>/dev/null | grep -q 'status: running'; then
    echo
    echo "PVE-UPS-LXC wird gestartet ..."
    pct start "$CTID"
    sleep 5
fi

pct exec "$CTID" -- test -f /etc/pve-usv/config.yaml || {
    echo "FEHLER: /etc/pve-usv/config.yaml fehlt in CT $CTID."
    exit 1
}

BACKUP_DIR="/root/backups/pve-ups-backup-$(date +%Y%m%d-%H%M%S)"
pct exec "$CTID" -- mkdir -p "$BACKUP_DIR"
pct exec "$CTID" -- cp -a /etc/pve-usv/config.yaml "$BACKUP_DIR/config.yaml"

echo
echo "Backup im PVE-UPS-LXC:"
echo "  $BACKUP_DIR/config.yaml"

# ---------------------------------------------------------------------------
# Dynamic app-Python runner.
# It uses exactly the Python interpreter + working directory of pve-usv.service.
# ---------------------------------------------------------------------------

cat > "$RUNNER" <<'RUNNER_EOF'
#!/bin/bash
set -Eeuo pipefail

SCRIPT="$1"
shift || true

PID="$(
    systemctl show \
        --property MainPID \
        --value \
        pve-usv.service
)"

if [[ ! "$PID" =~ ^[0-9]+$ ]] || [[ "$PID" -le 1 ]]; then
    echo "FEHLER: pve-usv.service läuft nicht." >&2
    exit 1
fi

PYTHON="$(
    readlink -f "/proc/${PID}/exe"
)"

WORKDIR="$(
    readlink -f "/proc/${PID}/cwd"
)"

[[ -x "$PYTHON" ]] || {
    echo "FEHLER: Python-Interpreter von PVE-UPS nicht gefunden." >&2
    exit 1
}

[[ -d "$WORKDIR" ]] || {
    echo "FEHLER: Arbeitsverzeichnis von PVE-UPS nicht gefunden." >&2
    exit 1
}

cd "$WORKDIR"
export PYTHONPATH="${WORKDIR}${PYTHONPATH:+:${PYTHONPATH}}"

exec "$PYTHON" "$SCRIPT" "$@"
RUNNER_EOF

chmod 755 "$RUNNER"

# ---------------------------------------------------------------------------
# Config merge script.
# ---------------------------------------------------------------------------

cat > "$CONFIGURE_PY" <<'PY_CONFIG'
from __future__ import annotations

import json
import os
import sys

from app.config import (
    NutConfig,
    PveHostConfig,
    WebhookFormat,
    WebhookLevel,
    assign_ups_ids,
    load_config,
    save_config,
)

HOST_NAME = os.environ.get("PVE_HOST_NAME", "pve").strip() or "pve"
HOST_IP = os.environ.get("PVE_HOST_IP", "").strip()
TOKEN_ID = os.environ.get("PVE_TOKEN_ID", "").strip()
TOKEN_SECRET = os.environ.get("PVE_TOKEN_SECRET", "").strip()

cfg = load_config()

# Safety while settings are changed and tested.
cfg.dry_run = True

if hasattr(cfg, "timezone"):
    cfg.timezone = "Europe/Berlin"

if hasattr(cfg, "ntp_server"):
    cfg.ntp_server = ""

if hasattr(cfg, "selftest_enabled"):
    cfg.selftest_enabled = True

if hasattr(cfg, "selftest_hour"):
    cfg.selftest_hour = 9

if hasattr(cfg, "selftest_interval_min"):
    cfg.selftest_interval_min = 1440

if hasattr(cfg, "selftest_log_ok"):
    cfg.selftest_log_ok = True

# -----------------------------------------------------------------------
# UPS NAS / NUT
# Preserve id, credentials and per-UPS overrides when the entry exists.
# -----------------------------------------------------------------------

ups = None

for item in cfg.ups:
    if (
        getattr(item, "type", "") == "nut"
        and (
            getattr(item, "name", "") == "USV"
            or (
                getattr(item, "host", "") == "192.168.178.20"
                and int(getattr(item, "port", 3493)) == 3493
            )
        )
    ):
        ups = item
        break

if ups is None:
    ups = NutConfig(
        name="USV",
        host="192.168.178.20",
        port=3493,
        ups_name="ups",
        username="",
        password="",
        timeout_s=3.0,
    )
    cfg.ups.append(ups)
else:
    ups.name = "USV"
    ups.host = "192.168.178.20"
    ups.port = 3493
    ups.ups_name = "ups"
    ups.timeout_s = 3.0

assign_ups_ids(cfg.ups)

# No per-UPS trigger override: global settings below are authoritative.
# Existing explicit overrides are cleared only for the requested shutdown fields,
# so the requested global values really apply.
if hasattr(ups, "overrides"):
    overrides = ups.overrides

    for field in (
        "on_battery_seconds",
        "runtime_below_minutes",
        "charge_below_percent",
        "on_battery_low",
        "comm_loss_shutdown_after_min",
        "keep_shutdown_on_comm_loss",
    ):
        if hasattr(overrides, field):
            setattr(overrides, field, None)

# -----------------------------------------------------------------------
# Shutdown logic exactly as requested.
# -----------------------------------------------------------------------

th = cfg.thresholds

requested = {
    "on_battery_seconds": 600,
    "runtime_below_minutes": 10,
    "charge_below_percent": 30,
    "on_battery_low": True,
    "poll_interval_normal_s": 30,
    "poll_interval_battery_s": 8,
    "unreachable_alarm_after_polls": 3,
    "comm_loss_shutdown_after_min": None,
    "keep_shutdown_on_comm_loss": True,
    "host_shutdown_timeout_s": 60,
    "rearm_after_mains_min": 5,
}

applied = {}

for field, value in requested.items():
    if hasattr(th, field):
        setattr(th, field, value)
        applied[field] = value

# -----------------------------------------------------------------------
# Existing Proxmox target is preserved. Add it only if necessary.
# The token is only replaced when a new token was explicitly supplied.
# -----------------------------------------------------------------------

pve_host = None

for host in cfg.hosts:
    if getattr(host, "type", "pve") != "pve":
        continue

    api_url = str(getattr(host, "api_url", ""))

    if (
        getattr(host, "name", "") == HOST_NAME
        or (HOST_IP and HOST_IP in api_url)
    ):
        pve_host = host
        break

if pve_host is None and TOKEN_ID and TOKEN_SECRET:
    pve_host = PveHostConfig(
        name=HOST_NAME,
        api_url=f"https://{HOST_IP}:8006",
        token_id=TOKEN_ID,
        token_secret=TOKEN_SECRET,
        verify_tls=False,
        this_host=True,
        order=0,
        ups_ids=[ups.id],
        ups_policy="all",
    )
    cfg.hosts.append(pve_host)

elif pve_host is not None:
    pve_host.name = HOST_NAME
    pve_host.api_url = f"https://{HOST_IP}:8006"
    pve_host.verify_tls = False
    pve_host.this_host = True
    pve_host.order = 0
    pve_host.enabled = True

    if hasattr(pve_host, "ups_ids"):
        pve_host.ups_ids = [ups.id]

    if hasattr(pve_host, "ups_policy"):
        pve_host.ups_policy = "all"

    if TOKEN_ID and TOKEN_SECRET:
        pve_host.token_id = TOKEN_ID
        pve_host.token_secret = TOKEN_SECRET

def secret_text(value):
    if hasattr(value, "get_secret_value"):
        return value.get_secret_value()
    return str(value or "")

EXPECTED_TOKEN_ID = "pve-ups@pve!pve-ups"
needs_token = True

if pve_host is not None:
    needs_token = not (
        str(getattr(pve_host, "token_id", "")).strip() == EXPECTED_TOKEN_ID
        and secret_text(getattr(pve_host, "token_secret", "")).strip()
    )

# -----------------------------------------------------------------------
# Notifications:
# Preserve URL/auth. Only enforce JSON + all events on the Pushover target.
# -----------------------------------------------------------------------

hooks = []

if hasattr(cfg.notifications, "webhooks"):
    hooks = list(cfg.notifications.webhooks or [])
elif hasattr(cfg.notifications, "webhook"):
    legacy = cfg.notifications.webhook
    if legacy is not None:
        hooks = [legacy]

def hook_label(hook):
    return " ".join([
        str(getattr(hook, "name", "") or ""),
        str(getattr(hook, "id", "") or ""),
        str(getattr(hook, "label", "") or ""),
    ]).lower()

pushover_hook = next(
    (
        hook
        for hook in hooks
        if "pushover" in hook_label(hook)
    ),
    None,
)

if pushover_hook is None:
    enabled = [
        hook
        for hook in hooks
        if bool(getattr(hook, "enabled", False))
        and str(getattr(hook, "url", "") or "").strip()
    ]

    if len(enabled) == 1:
        pushover_hook = enabled[0]

if pushover_hook is not None:
    pushover_hook.enabled = True
    pushover_hook.format = WebhookFormat.json
    pushover_hook.min_severity = WebhookLevel.info

cfg.configured = bool(cfg.ups and cfg.hosts)

save_config(cfg)

print(json.dumps({
    "ok": True,
    "ups_id": ups.id,
    "needs_token": needs_token,
    "host_present": pve_host is not None,
    "pushover_webhook_found": pushover_hook is not None,
    "thresholds_applied": applied,
}, ensure_ascii=False))
PY_CONFIG

# ---------------------------------------------------------------------------
# Test + arm script.
# ---------------------------------------------------------------------------

cat > "$TEST_PY" <<'PY_TEST'
from __future__ import annotations

import asyncio
import json

from app.config import load_config, save_config
from app.sources import poll
from app import targets

async def main():
    cfg = load_config()

    ups_results = []

    for ups in cfg.ups:
        if (
            getattr(ups, "type", "") != "nut"
            or getattr(ups, "name", "") != "USV"
        ):
            continue

        try:
            state = await poll(ups)

            reachable = bool(
                getattr(state, "reachable", False)
            )

            ups_results.append({
                "name": getattr(ups, "name", "USV"),
                "reachable": reachable,
                "power_source": getattr(state, "power_source", None),
                "battery_status": getattr(state, "battery_status", None),
                "charge": getattr(state, "battery_charge_pct", None),
                "runtime_min": getattr(state, "runtime_remaining_min", None),
                "error": getattr(state, "error", None),
            })

        except Exception as exc:
            ups_results.append({
                "name": getattr(ups, "name", "USV"),
                "reachable": False,
                "error": str(exc),
            })

    host_results = []

    for host in cfg.hosts:
        if (
            getattr(host, "type", "pve") != "pve"
            or not bool(getattr(host, "enabled", True))
        ):
            continue

        try:
            result = await targets.test_connection(host)

            host_results.append({
                "name": getattr(host, "name", ""),
                "ok": bool(getattr(result, "ok", False)),
                "power_mgmt": bool(getattr(result, "has_power_mgmt", False)),
                "message": getattr(result, "message", ""),
            })

        except Exception as exc:
            host_results.append({
                "name": getattr(host, "name", ""),
                "ok": False,
                "power_mgmt": False,
                "message": str(exc),
            })

    ups_ok = bool(ups_results) and all(
        item["reachable"]
        for item in ups_results
    )

    hosts_ok = bool(host_results) and all(
        item["ok"] and item["power_mgmt"]
        for item in host_results
    )

    armed = ups_ok and hosts_ok

    if armed:
        cfg.dry_run = False
        cfg.configured = True
        save_config(cfg)

    print(json.dumps({
        "ups": ups_results,
        "hosts": host_results,
        "ups_ok": ups_ok,
        "hosts_ok": hosts_ok,
        "armed": armed,
    }, ensure_ascii=False))

asyncio.run(main())
PY_TEST

# ---------------------------------------------------------------------------
# Periodic report implementation.
# Runs in a separate systemd oneshot, outside the shutdown polling loop.
# ---------------------------------------------------------------------------

cat > "$REPORT_PY" <<'PY_REPORT'
from __future__ import annotations

import asyncio
import fcntl
import json
import os
import socket
import sys
import urllib.request

from datetime import datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

from app import db, notify
from app.config import load_config

TITLE = "[PVE-UPS] USV-Statusbericht"
TZ = ZoneInfo("Europe/Berlin")

STATE_PATH = Path(
    "/var/lib/pve-usv/status-report-state.json"
)
LOCK_PATH = Path(
    "/var/lib/pve-usv/status-report.lock"
)

FORCE = "--force" in sys.argv


def clean_none(value):
    if isinstance(value, dict):
        return {
            key: clean_none(item)
            for key, item in value.items()
            if item is not None
        }

    if isinstance(value, list):
        return [
            clean_none(item)
            for item in value
            if item is not None
        ]

    return value


def translate_status_values(value):
    translations = {
        "mains": "Netzbetrieb",
        "battery": "Akkubetrieb",
        "bypass": "Bypass",
        "normal": "Normal",
        "low": "Niedrig",
        "depleted": "Leer",
        "ONLINE": "Netzbetrieb",
        "ON_BATTERY": "Akkubetrieb",
        "SHUTDOWN_PENDING": "Shutdown ausstehend",
        "SHUTTING_DOWN": "Shutdown läuft",
        "idle": "Bereit",
        "sent": "Gesendet",
        "failed": "Fehlgeschlagen",
    }

    if isinstance(value, dict):
        return {
            key: translate_status_values(item)
            for key, item in value.items()
        }

    if isinstance(value, list):
        return [
            translate_status_values(item)
            for item in value
        ]

    if isinstance(value, str):
        return translations.get(
            value,
            value,
        )

    return value


def scheduled_slot(now):
    today = now.replace(
        minute=0,
        second=0,
        microsecond=0,
    )

    if now.hour >= 20:
        return today.replace(hour=20)

    if now.hour >= 8:
        return today.replace(hour=8)

    return (
        today
        - timedelta(days=1)
    ).replace(hour=20)


def last_slot():
    try:
        data = json.loads(
            STATE_PATH.read_text(
                encoding="utf-8"
            )
        )

        return str(
            data.get("last_slot")
            or ""
        )

    except Exception:
        return ""


def save_slot(slot):
    STATE_PATH.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    temp = STATE_PATH.with_suffix(
        ".tmp"
    )

    temp.write_text(
        json.dumps({
            "last_slot": slot,
            "sent_at": datetime.now(TZ).isoformat(),
        }) + "\n",
        encoding="utf-8",
    )

    os.replace(
        temp,
        STATE_PATH,
    )


def local_status():
    with urllib.request.urlopen(
        "http://127.0.0.1:8080/api/status",
        timeout=5,
    ) as response:
        payload = json.loads(
            response.read(
                2 * 1024 * 1024
            ).decode(
                "utf-8",
                "replace",
            )
        )

    # Normal webhook payload uses engine.snapshot(), not the 48-hour event history.
    payload.pop(
        "events",
        None,
    )
    payload.pop(
        "events_summary",
        None,
    )

    return payload


def nut_unquote(value):
    value = value.strip()

    if (
        len(value) >= 2
        and value[0] == '"'
        and value[-1] == '"'
    ):
        value = value[1:-1]

    return (
        value
        .replace(r"\"", '"')
        .replace(r"\\", "\\")
    )


def nut_values(host, port, ups_name, timeout=3):
    values = {}

    with socket.create_connection(
        (host, int(port)),
        timeout=timeout,
    ) as sock:
        sock.settimeout(timeout)

        reader = sock.makefile(
            "r",
            encoding="utf-8",
            errors="replace",
        )

        writer = sock.makefile(
            "w",
            encoding="utf-8",
        )

        writer.write(
            f"LIST VAR {ups_name}\n"
        )
        writer.flush()

        first = reader.readline().strip()

        if not first.startswith(
            "BEGIN LIST VAR"
        ):
            return values

        prefix = f"VAR {ups_name} "

        while True:
            line = reader.readline()

            if not line:
                break

            line = line.strip()

            if line.startswith(
                "END LIST VAR"
            ):
                break

            if not line.startswith(
                prefix
            ):
                continue

            rest = line[len(prefix):]

            if " " not in rest:
                continue

            key, raw = rest.split(
                " ",
                1,
            )

            values[key] = nut_unquote(
                raw
            )

    return values


def as_float(value):
    try:
        return float(value)
    except Exception:
        return None


def choose_hook(cfg):
    notifications = cfg.notifications

    if hasattr(
        notifications,
        "webhooks",
    ):
        hooks = list(
            notifications.webhooks
            or []
        )
    elif hasattr(
        notifications,
        "webhook",
    ):
        hooks = [
            notifications.webhook
        ]
    else:
        hooks = []

    enabled = [
        hook
        for hook in hooks
        if bool(
            getattr(
                hook,
                "enabled",
                False,
            )
        )
        and str(
            getattr(
                hook,
                "url",
                "",
            )
            or ""
        ).strip()
    ]

    def label(hook):
        return " ".join([
            str(
                getattr(
                    hook,
                    "name",
                    "",
                )
                or ""
            ),
            str(
                getattr(
                    hook,
                    "id",
                    "",
                )
                or ""
            ),
            str(
                getattr(
                    hook,
                    "label",
                    "",
                )
                or ""
            ),
        ]).lower()

    pushover = next(
        (
            hook
            for hook in enabled
            if "pushover" in label(hook)
        ),
        None,
    )

    if pushover is not None:
        return pushover

    json_hooks = [
        hook
        for hook in enabled
        if str(
            getattr(
                getattr(hook, "format", ""),
                "value",
                getattr(hook, "format", ""),
            )
        ).lower() == "json"
    ]

    if len(json_hooks) == 1:
        return json_hooks[0]

    if len(enabled) == 1:
        return enabled[0]

    return None


def text_bool(value):
    if value is True:
        return "Ja"

    if value is False:
        return "Nein"

    return "-"


def power_source(value):
    return {
        "mains": "Netzbetrieb",
        "battery": "Akkubetrieb",
        "bypass": "Bypass",
    }.get(
        str(value or "").lower(),
        "-",
    )


def battery_state(value):
    return {
        "normal": "Normal",
        "low": "Niedrig",
        "depleted": "Leer",
    }.get(
        str(value or "").lower(),
        "-",
    )


def time_hms(value):
    if not value:
        return "-"

    try:
        dt = datetime.fromisoformat(
            str(value).replace(
                "Z",
                "+00:00",
            )
        )

        return dt.astimezone(
            TZ
        ).strftime(
            "%H:%M:%S"
        )

    except Exception:
        return str(value)


def add_line(lines, text, value, suffix=""):
    if value is None:
        return

    if value == "":
        return

    lines.append(
        f"{text}: {value}{suffix}"
    )


def build_report(status, cfg):
    ups_list = status.get(
        "ups",
        [],
    )

    ups = next(
        (
            item
            for item in ups_list
            if str(
                item.get("name")
                or ""
            ) == "NAS"
        ),
        ups_list[0] if ups_list else {},
    )

    # Enrich with raw NUT load where the REST snapshot does not expose it.
    nut_raw = {}

    for item in cfg.ups:
        if (
            getattr(
                item,
                "type",
                "",
            ) == "nut"
            and (
                getattr(
                    item,
                    "name",
                    "",
                ) == "NAS"
                or getattr(
                    item,
                    "host",
                    "",
                ) == "192.168.178.20"
            )
        ):
            try:
                nut_raw = nut_values(
                    getattr(
                        item,
                        "host",
                        "192.168.178.20",
                    ),
                    getattr(
                        item,
                        "port",
                        3493,
                    ),
                    getattr(
                        item,
                        "ups_name",
                        "ups",
                    ),
                    int(
                        getattr(
                            item,
                            "timeout_s",
                            3,
                        )
                    ),
                )
            except Exception:
                nut_raw = {}

            break

    load_pct = ups.get(
        "load_pct"
    )

    if load_pct is None:
        load_pct = as_float(
            nut_raw.get(
                "ups.load"
            )
        )

    host_list = [
        item
        for item in status.get(
            "hosts",
            [],
        )
        if str(
            item.get("type")
            or "pve"
        ) == "pve"
    ]

    host = next(
        (
            item
            for item in host_list
            if str(
                item.get("name")
                or ""
            ) == "pve"
        ),
        host_list[0] if host_list else {},
    )

    appliance = status.get(
        "appliance",
        {},
    )

    shutdown = status.get(
        "shutdown",
        {},
    )

    lines = []

    add_line(
        lines,
        "⚡ Versorgung",
        power_source(
            ups.get(
                "power_source"
            )
        ),
    )

    charge = ups.get(
        "battery_charge_pct"
    )

    if charge is not None:
        add_line(
            lines,
            "🔋 Akkuladung",
            f"{round(float(charge))} %",
        )

    runtime = ups.get(
        "runtime_remaining_min"
    )

    if runtime is not None:
        add_line(
            lines,
            "⏱ Restlaufzeit",
            f"{round(float(runtime))} Min.",
        )

    if load_pct is not None:
        add_line(
            lines,
            "📊 USV-Auslastung",
            f"{round(float(load_pct))} %",
        )

    add_line(
        lines,
        "🪫 Akkuzustand",
        battery_state(
            ups.get(
                "battery_status"
            )
        ),
    )

    add_line(
        lines,
        "🔌 USV-Verbindung",
        (
            "OK"
            if ups.get("reachable") is True
            else "Gestört"
        ),
    )

    lines.append("")

    add_line(
        lines,
        "🏭 Hersteller",
        ups.get(
            "manufacturer"
        ),
    )

    add_line(
        lines,
        "📦 Modell",
        ups.get(
            "model"
        ),
    )

    lines.append("")

    add_line(
        lines,
        "🖥 Proxmox-Host",
        host.get(
            "name"
        )
        or "pve",
    )

    host_reachable = host.get(
        "reachable"
    )

    if host_reachable is None:
        host_reachable = host.get(
            "credentials_ok"
        )

    add_line(
        lines,
        "✅ Host erreichbar",
        text_bool(
            host_reachable
        ),
    )

    power_ok = host.get(
        "power_mgmt_ok"
    )

    add_line(
        lines,
        "🔐 Shutdown-Berechtigung",
        (
            "OK"
            if power_ok is True
            else (
                "Fehlt"
                if power_ok is False
                else "-"
            )
        ),
    )

    lines.append("")

    add_line(
        lines,
        "🛡 PVE-UPS",
        (
            "TESTMODUS"
            if appliance.get(
                "dry_run"
            ) is True
            else "SCHARF"
        ),
    )

    add_line(
        lines,
        "🚨 Shutdown ausgelöst",
        text_bool(
            shutdown.get(
                "triggered",
                False,
            )
        ),
    )

    reason = shutdown.get(
        "reason"
    )

    add_line(
        lines,
        "📋 Shutdown-Grund",
        reason if reason else "-",
    )

    countdown = shutdown.get(
        "countdown_remaining_s"
    )

    add_line(
        lines,
        "⏳ Countdown",
        (
            f"{int(countdown)} Sek."
            if countdown is not None
            else "-"
        ),
    )

    lines.append("")

    add_line(
        lines,
        "🕒 Letzte USV-Abfrage",
        time_hms(
            ups.get(
                "last_poll"
            )
        ),
    )

    add_line(
        lines,
        "🕒 Bericht erstellt",
        datetime.now(
            TZ
        ).strftime(
            "%d.%m.%Y %H:%M"
        ),
    )

    german_status = translate_status_values(
        clean_none(
            status
        )
    )

    german_status["statusbericht"] = clean_none({
        "versorgung": power_source(
            ups.get(
                "power_source"
            )
        ),
        "akkuladung_prozent": charge,
        "restlaufzeit_minuten": runtime,
        "auslastung_prozent": load_pct,
        "akkuzustand": battery_state(
            ups.get(
                "battery_status"
            )
        ),
        "usv_verbindung": (
            "OK"
            if ups.get("reachable") is True
            else "Gestört"
        ),
        "proxmox_host": (
            host.get("name")
            or "pve"
        ),
        "host_erreichbar": host_reachable,
        "shutdown_berechtigung": (
            "OK"
            if power_ok is True
            else (
                "Fehlt"
                if power_ok is False
                else "-"
            )
        ),
        "pve_ups_modus": (
            "TESTMODUS"
            if appliance.get(
                "dry_run"
            ) is True
            else "SCHARF"
        ),
        "shutdown_ausgeloest": shutdown.get(
            "triggered",
            False,
        ),
        "shutdown_grund": reason or "-",
        "countdown_sekunden": countdown,
        "bericht_erstellt": datetime.now(
            TZ
        ).isoformat(
            timespec="seconds"
        ),
    })

    return "\n".join(
        lines
    ), german_status


async def main():
    LOCK_PATH.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    with LOCK_PATH.open(
        "a+",
        encoding="utf-8",
    ) as lock:
        fcntl.flock(
            lock,
            fcntl.LOCK_EX,
        )

        now = datetime.now(
            TZ
        )

        slot = scheduled_slot(
            now
        ).isoformat(
            timespec="minutes"
        )

        if (
            not FORCE
            and last_slot() == slot
        ):
            print(
                f"Statusbericht für Slot {slot} wurde bereits gesendet."
            )
            return

        try:
            cfg = load_config()
            hook = choose_hook(
                cfg
            )

            if hook is None:
                try:
                    db.log_event(
                        "USV-Statusbericht: kein Webhook",
                        "Kein eindeutiger aktivierter Pushover/JSON-Webhook gefunden.",
                        db.WARNING,
                    )
                except Exception:
                    pass

                print(
                    "Kein eindeutiger Pushover/JSON-Webhook gefunden."
                )
                return

            status = local_status()

            body, payload = build_report(
                status,
                cfg,
            )

            result = await notify.send_webhook(
                hook,
                TITLE,
                body,
                db.INFO,
                payload,
            )

            if not FORCE:
                save_slot(
                    slot
                )

            try:
                db.log_event(
                    "USV-Statusbericht",
                    (
                        "12-Stunden-Statusbericht erfolgreich gesendet "
                        f"({result})."
                    ),
                    db.INFO,
                )
            except Exception:
                pass

            print(
                f"{TITLE}: gesendet ({result})"
            )

        except Exception as exc:
            # Never raise into PVE-UPS: this is a separate oneshot process and
            # notification trouble must not become shutdown trouble.
            try:
                db.log_event(
                    "USV-Statusbericht: Versand fehlgeschlagen",
                    str(exc) or exc.__class__.__name__,
                    db.WARNING,
                )
            except Exception:
                pass

            print(
                "Statusbericht konnte nicht gesendet werden: "
                f"{exc}",
                file=sys.stderr,
            )

            return


asyncio.run(
    main()
)
PY_REPORT

# ---------------------------------------------------------------------------
# Internal wrapper.
# ---------------------------------------------------------------------------

cat > "$RUNNER" <<'RUNNER_EOF'
#!/bin/bash
set -Eeuo pipefail

SCRIPT="$1"
shift || true

PID="$(
    systemctl show \
        --property MainPID \
        --value \
        pve-usv.service
)"

if [[ ! "$PID" =~ ^[0-9]+$ ]] || [[ "$PID" -le 1 ]]; then
    echo "PVE-UPS läuft nicht; Statusbericht wird übersprungen." >&2
    exit 0
fi

PYTHON="$(
    readlink -f "/proc/${PID}/exe"
)"

WORKDIR="$(
    readlink -f "/proc/${PID}/cwd"
)"

[[ -x "$PYTHON" ]] || exit 0
[[ -d "$WORKDIR" ]] || exit 0

cd "$WORKDIR"
export PYTHONPATH="${WORKDIR}${PYTHONPATH:+:${PYTHONPATH}}"

exec "$PYTHON" "$SCRIPT" "$@"
RUNNER_EOF

chmod 755 "$RUNNER"

cat > "$SERVICE" <<'SERVICE_EOF'
[Unit]
Description=PVE-UPS 12-Stunden Statusbericht
After=network-online.target pve-usv.service
Wants=network-online.target
Requires=pve-usv.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/pve-usv-python-runner /usr/local/lib/pve-usv-status-report.py
Nice=10
IOSchedulingClass=idle
TimeoutStartSec=35
SERVICE_EOF

cat > "$TIMER" <<'TIMER_EOF'
[Unit]
Description=PVE-UPS Statusbericht 08:00 und 20:00 Europe/Berlin

[Timer]
OnCalendar=*-*-* 08:00:00 Europe/Berlin
OnCalendar=*-*-* 20:00:00 Europe/Berlin
Persistent=true
AccuracySec=1min
RandomizedDelaySec=0
Unit=pve-usv-status-report.service

[Install]
WantedBy=timers.target
TIMER_EOF

# ---------------------------------------------------------------------------
# Push helper files.
# ---------------------------------------------------------------------------

pct push "$CTID" "$CONFIGURE_PY" /root/pve-ups-configure-v58.py -perms 0700 >/dev/null
pct push "$CTID" "$TEST_PY" /root/pve-ups-test-arm-v58.py -perms 0700 >/dev/null
pct push "$CTID" "$REPORT_PY" /usr/local/lib/pve-usv-status-report.py -perms 0755 >/dev/null
pct push "$CTID" "$RUNNER" /usr/local/sbin/pve-usv-python-runner -perms 0755 >/dev/null
pct push "$CTID" "$SERVICE" /etc/systemd/system/pve-usv-status-report.service -perms 0644 >/dev/null
pct push "$CTID" "$TIMER" /etc/systemd/system/pve-usv-status-report.timer -perms 0644 >/dev/null

# ---------------------------------------------------------------------------
# First config pass: preserve existing host token.
# ---------------------------------------------------------------------------

echo
echo "===== KONFIGURATION ====="

CONFIG_RESULT="$(
    pct exec "$CTID" -- \
        env \
        "PVE_HOST_NAME=$NODE_NAME" \
        "PVE_HOST_IP=$PVE_IP" \
        /usr/local/sbin/pve-usv-python-runner \
        /root/pve-ups-configure-v58.py
)"

echo "$CONFIG_RESULT" |
python3 -m json.tool 2>/dev/null || echo "$CONFIG_RESULT"

NEEDS_TOKEN="$(
    printf '%s' "$CONFIG_RESULT" |
    python3 -c '
import json,sys
try:
    print("1" if json.load(sys.stdin).get("needs_token") else "0")
except Exception:
    print("1")
'
)"

PUSHOVER_FOUND="$(
    printf '%s' "$CONFIG_RESULT" |
    python3 -c '
import json,sys
try:
    print("1" if json.load(sys.stdin).get("pushover_webhook_found") else "0")
except Exception:
    print("0")
'
)"

# ---------------------------------------------------------------------------
# Create a PVE token ONLY when PVE-UPS has no usable token stored.
# ---------------------------------------------------------------------------

PVEUPS_USER_ID="pve-ups@pve"
PVEUPS_TOKEN_NAME="pve-ups"
PVEUPS_ROLE_NAME="UPSPower"
PVEUPS_NODE_PATH="/nodes/${NODE_NAME}"
PVEUPS_TOKEN_ID="${PVEUPS_USER_ID}!${PVEUPS_TOKEN_NAME}"

echo
echo "===== PVE-UPS PROXMOX API-BERECHTIGUNGEN ====="

if pveum role list 2>/dev/null | awk '{print $1}' | grep -Fxq "$PVEUPS_ROLE_NAME"; then
    pveum role modify "$PVEUPS_ROLE_NAME" \
        -privs "Sys.Audit Sys.PowerMgmt"
else
    pveum role add "$PVEUPS_ROLE_NAME" \
        -privs "Sys.Audit Sys.PowerMgmt"
fi

if pveum user list 2>/dev/null | awk '{print $1}' | grep -Fxq "$PVEUPS_USER_ID"; then
    pveum user modify "$PVEUPS_USER_ID" \
        -comment "UPS Shutdown API | Token-ID: ${PVEUPS_TOKEN_ID}" >/dev/null
else
    pveum user add "$PVEUPS_USER_ID" \
        -comment "UPS Shutdown API | Token-ID: ${PVEUPS_TOKEN_ID}" >/dev/null
fi

pveum acl modify "$PVEUPS_NODE_PATH" \
    -user "$PVEUPS_USER_ID" \
    -role "$PVEUPS_ROLE_NAME"

# Bei Privilege Separation braucht auch der Token eine eigene ACL.
pveum acl modify "$PVEUPS_NODE_PATH" \
    -token "$PVEUPS_TOKEN_ID" \
    -role "$PVEUPS_ROLE_NAME" \
    2>/dev/null || true

if [[ "$NEEDS_TOKEN" == "1" ]]; then
    echo
    echo "PVE-UPS benötigt den Standard-Token ${PVEUPS_TOKEN_ID}."
    echo "Der Token wird neu erzeugt, damit das Secret sicher übernommen werden kann."

    # Ein vorhandenes Secret kann Proxmox nicht erneut anzeigen.
    pveum user token remove "$PVEUPS_USER_ID" "$PVEUPS_TOKEN_NAME" >/dev/null 2>&1 || true

    TOKEN_JSON="$(
        pveum user token add \
            "$PVEUPS_USER_ID" \
            "$PVEUPS_TOKEN_NAME" \
            -privsep 1 \
            --output-format json
    )"

    TOKEN_SECRET="$(
        printf '%s' "$TOKEN_JSON" |
        python3 -c '
import json,sys
data=json.load(sys.stdin)
print(data.get("value") or data.get("token") or "")
'
    )"

    [[ -n "$TOKEN_SECRET" ]] || {
        echo "FEHLER: PVE-Token wurde erstellt, Secret konnte aber nicht gelesen werden."
        exit 1
    }

    TOKEN_ID="$PVEUPS_TOKEN_ID"

    # Token-ACL nach der Erzeugung nochmals verbindlich setzen.
    pveum acl modify "$PVEUPS_NODE_PATH" \
        -token "$TOKEN_ID" \
        -role "$PVEUPS_ROLE_NAME"

    CONFIG_RESULT="$(
        pct exec "$CTID" -- \
            env \
            "PVE_HOST_NAME=$NODE_NAME" \
            "PVE_HOST_IP=$PVE_IP" \
            "PVE_TOKEN_ID=$TOKEN_ID" \
            "PVE_TOKEN_SECRET=$TOKEN_SECRET" \
            /usr/local/sbin/pve-usv-python-runner \
            /root/pve-ups-configure-v58.py
    )"

    # Secret root-only ablegen; der Proxmox-Kommentar enthält bewusst nur
    # Token-ID + Dateipfad und NICHT das Secret im Klartext.
    install -d -m 0700 -o root -g root /root/passwort
    TOKEN_STAMP="${INSTALL_SECRET_STAMP_V107:-$(date +%Y%m%d-%H%M%S)}"
    TOKEN_FILE="/root/passwort/pve-ups-proxmox-api-token-pw-${TOKEN_STAMP}.txt"
    umask 077
    {
        echo "Komponente: PVE-UPS Proxmox API Token"
        echo "Benutzer:   ${PVEUPS_USER_ID}"
        echo "Rolle:      ${PVEUPS_ROLE_NAME}"
        echo "Rechte:     Sys.Audit Sys.PowerMgmt"
        echo "Pfad:       ${PVEUPS_NODE_PATH}"
        echo "Token-ID:   ${TOKEN_ID}"
        echo "Erstellt:   $(date '+%d.%m.%Y %H:%M:%S')"
        echo
        echo "Secret:"
        printf '%s\n' "$TOKEN_SECRET"
    } > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
    chown root:root "$TOKEN_FILE"

    pveum user modify "$PVEUPS_USER_ID" \
        -comment "UPS Shutdown API | Token-ID: ${TOKEN_ID} | Secret: ${TOKEN_FILE}" \
        >/dev/null

    unset TOKEN_SECRET TOKEN_JSON

    echo "[OK] Proxmox-Shutdown-Token eingerichtet."
    echo "[OK] Token-ID: ${TOKEN_ID}"
    echo "[OK] Token-Secret gespeichert: $TOKEN_FILE"
fi

echo
echo "Token-Berechtigungen:"
pveum user token permissions "$PVEUPS_USER_ID" "$PVEUPS_TOKEN_NAME" || true

# ---------------------------------------------------------------------------
# Apply timezone at OS level as well. This does not alter shutdown thresholds.
# ---------------------------------------------------------------------------

pct exec "$CTID" -- timedatectl set-timezone Europe/Berlin >/dev/null 2>&1 || true

# Reload the deliberately-safe dry-run config before the test.
pct exec "$CTID" -- systemctl restart pve-usv.service
sleep 4

echo
echo "===== USV + HOST TEST ====="

TEST_RESULT="$(
    pct exec "$CTID" -- \
        /usr/local/sbin/pve-usv-python-runner \
        /root/pve-ups-test-arm-v58.py
)"

echo "$TEST_RESULT" |
python3 -m json.tool 2>/dev/null || echo "$TEST_RESULT"

ARMED="$(
    printf '%s' "$TEST_RESULT" |
    python3 -c '
import json,sys
try:
    print("1" if json.load(sys.stdin).get("armed") else "0")
except Exception:
    print("0")
'
)"

if [[ "$ARMED" == "1" ]]; then
    pct exec "$CTID" -- systemctl restart pve-usv.service
    sleep 3
    echo
    echo "[OK] USV erreichbar + Shutdown-Berechtigung OK."
    echo "[OK] PVE-UPS wurde auf SCHARF gestellt."
else
    echo
    echo "[WARNUNG] Test nicht vollständig erfolgreich."
    echo "[WARNUNG] PVE-UPS bleibt aus Sicherheitsgründen im TESTMODUS / Dry-Run."
fi

# ---------------------------------------------------------------------------
# Internal report timer
# ---------------------------------------------------------------------------

echo
echo "===== 12-STUNDEN STATUSBERICHT ====="

pct exec "$CTID" -- systemctl daemon-reload
pct exec "$CTID" -- systemctl enable --now pve-usv-status-report.timer >/dev/null

pct exec "$CTID" -- systemctl status \
    pve-usv-status-report.timer \
    --no-pager \
    -l || true

echo
echo "Nächste Termine:"
pct exec "$CTID" -- systemctl list-timers \
    pve-usv-status-report.timer \
    --no-pager || true

if [[ "$PUSHOVER_FOUND" != "1" ]]; then
    echo
    echo "[HINWEIS] Kein eindeutiger bereits eingerichteter Pushover/JSON-Webhook erkannt."
    echo "Der Timer ist installiert, sendet aber erst, sobald ein geeigneter Webhook"
    echo "in PVE-UPS aktiviert ist."
else
    echo
    echo "[OK] Bestehender Pushover/JSON-Webhook:"
    echo "  Format = JSON"
    echo "  Mindeststufe = INFO / alle Ereignisse"
fi

# ---------------------------------------------------------------------------
# Final config/status verification
# ---------------------------------------------------------------------------

echo
echo "===== AKTUELLER PVE-UPS STATUS ====="

pct exec "$CTID" -- \
    curl -fsS \
    --connect-timeout 3 \
    --max-time 8 \
    http://127.0.0.1:8080/api/status |
python3 - <<'PY'
import json
import sys

data = json.load(sys.stdin)

appliance = data.get("appliance") or {}
ups = (data.get("ups") or [{}])[0]
shutdown = data.get("shutdown") or {}
hosts = data.get("hosts") or []

print("PVE-UPS:")
print("  Modus:", "TESTMODUS" if appliance.get("dry_run") else "SCHARF")
print("  Engine:", appliance.get("engine_state", "-"))

print("USV:")
print("  Name:", ups.get("name", "-"))
print("  Quelle:", ups.get("power_source", "-"))
print("  Akku:", ups.get("battery_charge_pct", "-"))
print("  Restlaufzeit:", ups.get("runtime_remaining_min", "-"))
print("  Erreichbar:", ups.get("reachable", "-"))

print("Shutdown:")
print("  ausgelöst:", shutdown.get("triggered", False))
print("  Grund:", shutdown.get("reason") or "-")

for host in hosts:
    if (host.get("type") or "pve") == "pve":
        print("Host:")
        print("  Name:", host.get("name", "-"))
        print("  Credentials:", host.get("credentials_ok", "-"))
        print("  Sys.PowerMgmt:", host.get("power_mgmt_ok", "-"))
PY

echo
echo "============================================================"
echo " FERTIG"
echo "============================================================"
echo
echo "PVE-UPS-LXC:"
echo "  CT $CTID"
echo
echo "Statusbericht intern:"
echo "  08:00 + 20:00 Europe/Berlin"
echo "  /etc/systemd/system/pve-usv-status-report.timer"
echo "  /usr/local/lib/pve-usv-status-report.py"
echo
echo "Manueller Berichtstest:"
echo "  pct exec $CTID -- /usr/local/sbin/pve-usv-python-runner \\"
echo "    /usr/local/lib/pve-usv-status-report.py --force"
echo
echo "Backup:"
echo "  CT $CTID:$BACKUP_DIR/config.yaml"
echo
echo "Log:"
echo "  $LOGFILE"
echo "============================================================"
__PVE_V58_UPS_CONFIG_REPORT__
    chmod 700 "$patch"
    PVEUPS_CTID="$PVEUPS_ID" INSTALL_SECRET_STAMP_V107="$INSTALL_SECRET_STAMP_V107" bash "$patch"
    rm -f "$patch"
}

configure_pve_ups_notifications_de_v59() {
    header "PVE-UPS · BENACHRICHTIGUNGEN DEUTSCH"
    local patch="/tmp/pve-ups-notify-de-v59.$$"
    cat > "$patch" <<'__PVE_V59_NOTIFY_DE__'
#!/usr/bin/env bash
set -Eeuo pipefail

STAMP="$(date +%d-%m-%H-%M)"
LOGFILE="/root/diagnose/diagnose-pve-ups-benachrichtigungen-de-${STAMP}.txt"

if [[ -e "$LOGFILE" ]]; then
    N=2
    while [[ -e "/root/diagnose/diagnose-pve-ups-benachrichtigungen-de-${STAMP}-${N}.txt" ]]; do
        N=$((N + 1))
    done
    LOGFILE="/root/diagnose/diagnose-pve-ups-benachrichtigungen-de-${STAMP}-${N}.txt"
fi

exec > >(tee -a "$LOGFILE") 2>&1

[[ ${EUID:-$(id -u)} -eq 0 ]] || {
    echo "FEHLER: Bitte als root auf dem Proxmox-Host ausführen."
    exit 1
}

detect_pveups_ct() {
    if [[ -n "${PVEUPS_CTID:-}" ]]; then
        printf '%s\n' "$PVEUPS_CTID"
        return 0
    fi

    local id=""
    id="$(
        pct list 2>/dev/null |
        awk '
            NR > 1 {
                name=tolower($3)
                if (
                    name == "pve-ups"
                    || name == "pve-usv"
                    || name ~ /^pve[-_]?ups/
                    || name ~ /^pve[-_]?usv/
                ) {
                    print $1
                    exit
                }
            }
        '
    )"

    if [[ -n "$id" ]]; then
        printf '%s\n' "$id"
        return 0
    fi

    while read -r candidate; do
        [[ "$candidate" =~ ^[0-9]+$ ]] || continue
        if pct config "$candidate" 2>/dev/null |
           grep -Eq 'ip=192\.168\.178\.111(/|,|$)'; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done < <(
        pct list 2>/dev/null |
        awk 'NR > 1 {print $1}'
    )

    return 1
}

CTID="$(detect_pveups_ct)" || {
    echo "FEHLER: PVE-UPS-LXC wurde nicht gefunden."
    echo "Alternativ: PVEUPS_CTID=<CT-ID> $0"
    exit 1
}

PATCHER="/tmp/pve-usv-notify-de-patch.py"
UNIT="/tmp/pve-usv-notify-de-patch.service"
DROPIN="/tmp/pve-usv-notify-de.conf"

echo "============================================================"
echo " PVE-UPS JSON-BENACHRICHTIGUNGEN DEUTSCH"
echo "============================================================"
echo
echo "CT: $CTID"
echo
echo "Nur JSON-Webhooks:"
echo "  - Betreff + Meldung Deutsch"
echo "  - bekannte Statuswerte Deutsch"
echo "  - true/false -> Ja/Nein"
echo "  - null-Werte rekursiv entfernen"
echo "  - Shutdown-Engine bleibt unverändert"
echo

cat > "$PATCHER" <<'__PATCHER_PY__'
#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import py_compile
import re
import shutil
import sys

NOTIFY = Path("/opt/pve-usv/app/notify.py")
MARKER = "PVE_UPS_JSON_DE_V1"

if not NOTIFY.is_file():
    print(f"FEHLER: {NOTIFY} wurde nicht gefunden.", file=sys.stderr)
    raise SystemExit(1)

src = NOTIFY.read_text(encoding="utf-8")

if MARKER in src:
    print("[OK] Deutsche JSON-Webhook-Schicht ist bereits aktiv.")
    raise SystemExit(0)

backup = NOTIFY.with_suffix(".py.pre-de")
if not backup.exists():
    shutil.copy2(NOTIFY, backup)

if "import re\n" not in src:
    anchor = "import logging\n"
    if anchor not in src:
        print("FEHLER: Import-Anker in notify.py fehlt.", file=sys.stderr)
        raise SystemExit(1)
    src = src.replace(anchor, anchor + "import re\n", 1)

render = re.search(
    r'def _render_json\(subject: str, body: str, severity: str, payload: dict\) -> dict:\n'
    r'.*?\n\n(?=def _render_teams\()',
    src,
    re.S,
)

if not render:
    print(
        "FEHLER: _render_json() entspricht nicht der erwarteten "
        "PVE-UPS-Struktur. Datei bleibt unverändert.",
        file=sys.stderr,
    )
    raise SystemExit(1)

replacement = r__PATCHER_PY__

cat > "$UNIT" <<'__UNIT__'
[Unit]
Description=PVE-UPS deutsche JSON-Webhook-Schicht anwenden
Before=pve-usv.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/pve-usv-notify-de-patch
__UNIT__

cat > "$DROPIN" <<'__DROPIN__'
[Unit]
Requires=pve-usv-notify-de-patch.service
After=pve-usv-notify-de-patch.service
__DROPIN__

if ! pct status "$CTID" 2>/dev/null | grep -q 'status: running'; then
    pct start "$CTID"
    sleep 5
fi

pct push "$CTID" "$PATCHER" \
    /usr/local/sbin/pve-usv-notify-de-patch \
    -perms 0755 >/dev/null

pct push "$CTID" "$UNIT" \
    /etc/systemd/system/pve-usv-notify-de-patch.service \
    -perms 0644 >/dev/null

pct exec "$CTID" -- mkdir -p \
    /etc/systemd/system/pve-usv.service.d

pct push "$CTID" "$DROPIN" \
    /etc/systemd/system/pve-usv.service.d/20-notify-de.conf \
    -perms 0644 >/dev/null

echo "===== PATCH ANWENDEN ====="

pct exec "$CTID" -- \
    /usr/local/sbin/pve-usv-notify-de-patch

pct exec "$CTID" -- \
    /opt/pve-usv/venv/bin/python \
    -m py_compile \
    /opt/pve-usv/app/notify.py

pct exec "$CTID" -- systemctl daemon-reload
pct exec "$CTID" -- systemctl restart pve-usv.service

sleep 4

pct exec "$CTID" -- systemctl is-active --quiet pve-usv.service

pct exec "$CTID" -- grep -Fq \
    "PVE_UPS_JSON_DE_V1" \
    /opt/pve-usv/app/notify.py

pct exec "$CTID" -- \
    curl -fsS \
    --connect-timeout 3 \
    --max-time 8 \
    http://127.0.0.1:8080/api/status \
    >/dev/null

echo "[OK] Deutsche JSON-Schicht aktiv."
echo "[OK] PVE-UPS erreichbar."
echo
echo "Die systemd-Abhängigkeit prüft den Patch vor PVE-UPS-Starts erneut."
echo "Wird notify.py bei einem Update ersetzt, wird der Patch beim nächsten"
echo "Service-Start erneut angewendet, solange die Upstream-Struktur kompatibel ist."
echo
echo "Log:"
echo "  $LOGFILE"
__PVE_V59_NOTIFY_DE__
    chmod 700 "$patch"
    PVEUPS_CTID="$PVEUPS_ID" bash "$patch"
    rm -f "$patch"
}

# =============================================================================
# PVE-UPS · AKTUELLSTEN RELEASE SICHERSTELLEN V63
# =============================================================================

pve_ups_installed_version_v63() {
    local ctid="$1"

    pct exec "$ctid" -- \
        curl -fsS \
        --connect-timeout 3 \
        --max-time 8 \
        http://127.0.0.1:8080/api/status 2>/dev/null |
    python3 -c '
import json
import sys

try:
    data=json.load(sys.stdin)
except Exception:
    raise SystemExit(0)

value=(
    data.get("version")
    or (data.get("appliance") or {}).get("version")
    or ""
)

print(str(value).strip())
'
}

pve_ups_latest_release_v63() {
    curl -fsSL \
        --connect-timeout 10 \
        --max-time 25 \
        https://api.github.com/repos/ffind-dev/pve-ups/releases/latest |
    python3 -c '
import json
import sys

try:
    data=json.load(sys.stdin)
except Exception:
    raise SystemExit(0)

print(str(data.get("tag_name") or "").strip())
'
}

normalize_version_v63() {
    local value="$1"

    value="${value#v}"
    value="${value#V}"

    printf '%s\n' "$value"
}

ensure_pve_ups_latest_v63() {
    local latest=""
    local installed=""
    local latest_norm=""
    local installed_norm=""

    header "PVE-UPS · AKTUELLSTEN STAND PRÜFEN"

    latest="$(pve_ups_latest_release_v63 || true)"
    installed="$(pve_ups_installed_version_v63 "$PVEUPS_ID" || true)"

    latest_norm="$(normalize_version_v63 "$latest")"
    installed_norm="$(normalize_version_v63 "$installed")"

    if [[ -n "$latest_norm" && -n "$installed_norm" && "$latest_norm" == "$installed_norm" ]]; then
        ok "PVE-UPS ist bereits aktuell: ${installed}"
        return 0
    fi

    if [[ -n "$latest" ]]; then
        echo "Aktuellstes GitHub-Release: $latest"
    else
        warn "Aktuellstes GitHub-Release konnte vor dem Update nicht ermittelt werden."
    fi

    if [[ -n "$installed" ]]; then
        echo "Installierter Stand:       $installed"
    else
        echo "Installierter Stand:       wird durch Community-Updater geprüft"
    fi

    echo
    echo "Starte den offiziellen Community-Scripts App-Updater"
    echo "gezielt nur für PVE-UPS CT ${PVEUPS_ID} ..."

    if ! \
        var_backup=no \
        var_container="$PVEUPS_ID" \
        var_unattended=yes \
        var_skip_confirm=yes \
        var_auto_reboot=no \
        var_continue_on_error=no \
        bash -c "$(
            curl -fsSL \
                --connect-timeout 10 \
                --max-time 30 \
                https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/update-apps.sh
        )"
    then
        warn "Community-App-Updater meldete einen Fehler."

        # Der initiale Community-Scripts Installer lädt bereits den aktuellen
        # Release. Deshalb jetzt nicht blind eine funktionierende Neuinstallation
        # zerstören, sondern unten explizit die Version verifizieren.
    fi

    sleep 4

    latest="$(pve_ups_latest_release_v63 || true)"
    installed="$(pve_ups_installed_version_v63 "$PVEUPS_ID" || true)"

    latest_norm="$(normalize_version_v63 "$latest")"
    installed_norm="$(normalize_version_v63 "$installed")"

    if [[ -n "$latest_norm" && -n "$installed_norm" ]]; then
        if [[ "$latest_norm" == "$installed_norm" ]]; then
            ok "PVE-UPS aktueller Release aktiv: ${installed}"
            return 0
        fi

        die "PVE-UPS ist nicht auf dem neuesten Release. Installiert=${installed} · Aktuell=${latest}"
    fi

    if [[ -n "$installed" ]]; then
        warn "Installierte PVE-UPS-Version erkannt (${installed}), der GitHub-Latest-Tag konnte aber nicht sicher verglichen werden."
        return 0
    fi

    die "PVE-UPS-Version konnte nach Installation/Update nicht ermittelt werden."
}

install_pve_ups_community() {
    header "PVE-UPS INSTALLIEREN"

    if ! community_pve_ups_available; then
        if (( OPTIMAL_INSTALL )); then
            die "PVE-UPS ist während der Optimal-Installation nicht mehr verfügbar."
        fi
        warn "PVE-UPS ist aktuell nicht freigegeben; Installation wird übersprungen."
        PVEUPS_SKIPPED=1
        INSTALL_PVEUPS=0
        return 0
    fi

    install_community_generated_lxc \
        "PVE-UPS" \
        "https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/pve-ups.sh" \
        "$PVEUPS_ID" "pve-ups" "$PVEUPS_CIDR" \
        "$PVEUPS_CORES" "$PVEUPS_MEMORY" "$PVEUPS_DISK" "$PVEUPS_ROOT_PASS"

    configure_lxc_web_port80 \
        "$PVEUPS_ID" \
        "PVE-UPS" \
        "http" \
        "8080"

    PVEUPS_INSTALLED=1

    # V63:
    # Nach der Community-Erstinstallation noch einmal explizit den
    # Community App-Updater für genau diesen CT ausführen und den aktiven
    # PVE-UPS-Stand gegen GitHub "releases/latest" verifizieren.
    ensure_pve_ups_latest_v63

    # V58: aktuelle NAS/NUT-Konfiguration, Shutdown-Schwellen,
    # minimaler PVE-API-Token und interner 12h-Statusbericht.
    configure_pve_ups_policy_and_report_v58
    configure_pve_ups_notifications_de_v59

    ok "PVE-UPS installiert und vorkonfiguriert."
    echo "Web: http://${PVEUPS_IP}/"
    echo "Intern: HTTP 8080 hinter nginx."
    echo "NUT: 192.168.178.20:3493 / ups"
    echo "Statusbericht: 08:00 + 20:00 Europe/Berlin"
}

# =============================================================================
# PROXMOX SUBSCRIPTION-HINWEIS ENTFERNEN
# =============================================================================
# Basierend auf dem "SUBSCRIPTION NAG"-Teil von:
# https://github.com/community-scripts/ProxmoxVE
# tools/pve/post-pve-install.sh
#
# Bewusst NICHT das gesamte Post-Install-Script starten:
# Repository-, Ceph-, HA-, Upgrade- und Reboot-Einstellungen bleiben unangetastet.
# =============================================================================

install_pve_subscription_nag_removal() {
    header "PROXMOX SUBSCRIPTION-HINWEIS ENTFERNEN"

    local helper="/usr/local/bin/pve-remove-nag.sh"
    local apt_hook="/etc/apt/apt.conf.d/no-nag-script"

    mkdir -p /usr/local/bin /etc/apt/apt.conf.d

    cat > "$helper" <<'EOF'
#!/bin/sh
set -eu

WEB_JS="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"

if [ -s "$WEB_JS" ] && ! grep -q "NoMoreNagging" "$WEB_JS"; then
    echo "Patching Proxmox Desktop Web UI subscription nag..."
    sed -i \
        -e '/data\.status/ s/!//' \
        -e '/data\.status/ s/active/NoMoreNagging/' \
        "$WEB_JS"
fi

# NodeZero UI-Patch: "HA State" in der Gast-/Template-Übersicht ist bei
# diesem Setup missverständlich, weil HA = Home Assistant verwendet wird.
# Nur das hamanaged-Statusfeld wird auf "PVE-Failover" umbenannt.
# Der DPkg-Hook führt diesen Patch nach pve-manager-Updates erneut aus.
PVE_MANAGER_JS="/usr/share/pve-manager/js/pvemanagerlib.js"

if [ -s "$PVE_MANAGER_JS" ] && command -v python3 >/dev/null 2>&1; then
    python3 - "$PVE_MANAGER_JS" <<'PVEFAILOVERPY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
try:
    source = path.read_text(encoding="utf-8")
except Exception:
    raise SystemExit(0)

pattern = re.compile(
    r"(itemId\s*:\s*[\"']hamanaged[\"']\s*,[\s\S]{0,800}?title\s*:\s*)gettext\(\s*[\"']HA State[\"']\s*\)",
    re.MULTILINE,
)

patched, count = pattern.subn(r"\1'PVE-Failover'", source)

if count and patched != source:
    path.write_text(patched, encoding="utf-8")
PVEFAILOVERPY
fi

MOBILE_TPL="/usr/share/pve-yew-mobile-gui/index.html.tpl"
MARKER="<!-- MANAGED BLOCK FOR MOBILE NAG -->"

if [ -f "$MOBILE_TPL" ] && ! grep -qF "$MARKER" "$MOBILE_TPL"; then
    echo "Patching Proxmox Mobile Web UI subscription nag..."

    cat >> "$MOBILE_TPL" <<'MOBILEEOF'
<!-- MANAGED BLOCK FOR MOBILE NAG -->
<script>
  function removeSubscriptionElements() {
    const dialogs = document.querySelectorAll('dialog.pwt-outer-dialog');

    dialogs.forEach(dialog => {
      const text = (dialog.textContent || '').toLowerCase();

      if (text.includes('subscription')) {
        dialog.remove();
      }
    });

    const cards = document.querySelectorAll(
      '.pwt-card.pwt-p-2.pwt-d-flex.pwt-interactive.pwt-justify-content-center'
    );

    cards.forEach(card => {
      const text = (card.textContent || '').toLowerCase();
      const hasButton = card.querySelector('button');

      if (!hasButton && text.includes('subscription')) {
        card.remove();
      }
    });
  }

  const observer = new MutationObserver(removeSubscriptionElements);

  observer.observe(
    document.body,
    {
      childList: true,
      subtree: true
    }
  );

  removeSubscriptionElements();

  setInterval(
    removeSubscriptionElements,
    300
  );

  setTimeout(
    () => {
      observer.disconnect();
    },
    10000
  );
</script>
MOBILEEOF
fi
EOF

    chmod 755 "$helper"
    chown root:root "$helper"

    cat > "$apt_hook" <<'EOF'
DPkg::Post-Invoke { "/usr/local/bin/pve-remove-nag.sh"; };
EOF

    chmod 644 "$apt_hook"
    chown root:root "$apt_hook"

    # Sofort anwenden. Kein apt reinstall nötig.
    "$helper"

    # UI-Prozess neu laden, falls vorhanden.
    if systemctl list-unit-files pveproxy.service >/dev/null 2>&1; then
        systemctl restart pveproxy.service || \
            warn "pveproxy konnte nicht automatisch neu gestartet werden."
    fi

    local desktop="nicht erkannt"
    local mobile="nicht vorhanden"
    local failover_label="nicht erkannt"

    if [[ -f /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js ]]; then
        if grep -q "NoMoreNagging" \
            /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js; then
            desktop="aktiv"
        else
            desktop="Patch-Muster nicht gefunden"
        fi
    fi

    if [[ -f /usr/share/pve-yew-mobile-gui/index.html.tpl ]]; then
        if grep -qF "<!-- MANAGED BLOCK FOR MOBILE NAG -->" \
            /usr/share/pve-yew-mobile-gui/index.html.tpl; then
            mobile="aktiv"
        else
            mobile="Patch nicht aktiv"
        fi
    fi

    if [[ -f /usr/share/pve-manager/js/pvemanagerlib.js ]]; then
        if grep -q "PVE-Failover" /usr/share/pve-manager/js/pvemanagerlib.js; then
            failover_label="PVE-Failover"
        else
            failover_label="Patch-Muster nicht gefunden"
        fi
    fi

    ok "Subscription-Hinweis: Desktop = ${desktop}, Mobile = ${mobile}"
    ok "PVE-Gaststatus: HA-Status -> ${failover_label}"
    ok "Persistenter DPkg-Hook: ${apt_hook}"
}


# =============================================================================
# INSTALLATIONSFORTSCHRITT V48
# =============================================================================



# =============================================================================
# V107 · FINALER FUNKTIONSTEST
# =============================================================================

final_http_check_v107() {
    local label="$1"
    local url="$2"
    local attempts="${3:-12}"
    local code="" i

    for i in $(seq 1 "$attempts"); do
        code="$(curl -k -sS --connect-timeout 3 --max-time 6 -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || true)"
        if [[ "$code" =~ ^[1-4][0-9][0-9]$ ]]; then
            ok "FINALTEST: ${label} erreichbar (${code}) · ${url}"
            return 0
        fi
        sleep 2
    done

    warn "FINALTEST: ${label} nicht erreichbar · ${url} · HTTP ${code:-000}"
    return 1
}

final_lxc_check_v107() {
    local label="$1"
    local ctid="$2"

    pct config "$ctid" >/dev/null 2>&1 || {
        warn "FINALTEST: ${label} CT ${ctid} fehlt."
        return 1
    }

    pct status "$ctid" 2>/dev/null | grep -q 'status: running' || {
        warn "FINALTEST: ${label} CT ${ctid} läuft nicht."
        return 1
    }

    ok "FINALTEST: ${label} CT ${ctid} läuft."
}

final_vm_check_v107() {
    local label="$1"
    local vmid="$2"

    qm config "$vmid" >/dev/null 2>&1 || {
        warn "FINALTEST: ${label} VM ${vmid} fehlt."
        return 1
    }

    qm status "$vmid" 2>/dev/null | grep -q 'status: running' || {
        warn "FINALTEST: ${label} VM ${vmid} läuft nicht."
        return 1
    }

    ok "FINALTEST: ${label} VM ${vmid} läuft."
}

final_secret_file_check_v107() {
    local slug="$1"
    local value="${2:-}"
    local file="${INSTALL_SECRET_DIR_V107}/${slug}-pw-${INSTALL_SECRET_STAMP_V107}.txt"

    [[ -n "$value" ]] || return 0

    if [[ ! -s "$file" ]]; then
        warn "FINALTEST: Secret-Datei fehlt/leer: $file"
        return 1
    fi

    [[ "$(stat -c '%a' "$file" 2>/dev/null || true)" == "600" ]] || {
        warn "FINALTEST: Secret-Datei hat nicht 0600: $file"
        return 1
    }

    # Der Secret-Wert muss exakt irgendwo als eigene Zeile enthalten sein.
    grep -Fqx -- "$value" "$file" || {
        warn "FINALTEST: Secret-Datei enthält nicht den erwarteten Wert: $file"
        return 1
    }

    return 0
}

final_install_validation_v107() {
    header "FINALER FUNKTIONSTEST V107"
    local failures=0
    local ct=""

    if (( INSTALL_DASHBOARD )); then
        systemctl is-active --quiet pve-sensor-web.service || { warn "FINALTEST: pve-sensor-web.service ist nicht aktiv."; failures=$((failures+1)); }
        systemctl is-active --quiet pve-sensor-collector.timer || { warn "FINALTEST: pve-sensor-collector.timer ist nicht aktiv."; failures=$((failures+1)); }
        systemctl is-active --quiet nginx || { warn "FINALTEST: nginx ist nicht aktiv."; failures=$((failures+1)); }
        final_http_check_v107 "Dashboard" "https://${DASHBOARD_IP}/" 10 || failures=$((failures+1))
    fi

    if (( INSTALL_OS )); then
        final_vm_check_v107 "${OS_LABEL}" "$OS_ID" || failures=$((failures+1))
    fi

    if (( INSTALL_HA )); then
        final_vm_check_v107 "Home Assistant" "$HA_ID" || failures=$((failures+1))
        final_http_check_v107 "Home Assistant" "http://${HA_IP}:8123/" 150 || failures=$((failures+1))
    fi

    if (( INSTALL_PAPERLESS )); then
        final_lxc_check_v107 "Paperless" "$PL_ID" || failures=$((failures+1))
        final_http_check_v107 "Paperless" "https://${PAPERLESS_IP}/" 20 || failures=$((failures+1))
    fi

    if (( INSTALL_PIHOLE )); then
        final_lxc_check_v107 "Pi-hole" "$PH_ID" || failures=$((failures+1))
        if ! pct exec "$PH_ID" -- dig @127.0.0.1 -p 5335 google.de +short +time=5 2>/dev/null | grep -q .; then
            warn "FINALTEST: Unbound 127.0.0.1:5335 liefert keine DNS-Antwort."
            failures=$((failures+1))
        else
            ok "FINALTEST: Unbound antwortet auf 5335."
        fi
        if ! pct exec "$PH_ID" -- dig @127.0.0.1 google.de +short +time=5 2>/dev/null | grep -q .; then
            warn "FINALTEST: Pi-hole Port 53 liefert keine DNS-Antwort."
            failures=$((failures+1))
        else
            ok "FINALTEST: Pi-hole DNS antwortet auf Port 53."
        fi
        if ! pct exec "$PH_ID" -- sqlite3 -readonly /opt/pihole/etc-pihole/pihole-FTL.db \
            "SELECT name FROM sqlite_master WHERE name='queries';" 2>/dev/null | grep -qx queries; then
            warn "FINALTEST: Pi-hole FTL-Datenbank/queries-View fehlt."
            failures=$((failures+1))
        else
            ok "FINALTEST: Pi-hole FTL-Datenbank ist initialisiert."
        fi
        final_http_check_v107 "Pi-hole" "http://${PIHOLE_IP}/admin/" 10 || failures=$((failures+1))
        if ! curl -fsS --max-time 8 "http://${PIHOLE_IP}:9617/metrics" 2>/dev/null | grep -q '^pihole_'; then
            warn "FINALTEST: Pi-hole Exporter liefert keine Pi-hole-Metriken auf Port 9617."
            failures=$((failures+1))
        else
            ok "FINALTEST: Pi-hole Exporter liefert echte Pi-hole-Metriken."
        fi
    fi

    if (( INSTALL_NETALERTX )); then
        final_lxc_check_v107 "NetAlertX" "$NAX_ID" || failures=$((failures+1))
        final_http_check_v107 "NetAlertX" "https://${NETALERTX_IP}/" 15 || failures=$((failures+1))
    fi

    (( INSTALL_UPTIME )) && { final_lxc_check_v107 "Uptime Kuma" "$UPTIME_ID" || failures=$((failures+1)); final_http_check_v107 "Uptime Kuma" "https://${UPTIME_IP}/" 15 || failures=$((failures+1)); }
    (( INSTALL_VAULTWARDEN )) && { final_lxc_check_v107 "Vaultwarden" "$VAULTWARDEN_ID" || failures=$((failures+1)); final_http_check_v107 "Vaultwarden" "https://${VAULTWARDEN_IP}/" 15 || failures=$((failures+1)); }
    (( INSTALL_CADDY )) && { final_lxc_check_v107 "Caddy" "$CADDY_ID" || failures=$((failures+1)); final_http_check_v107 "Caddy" "http://${CADDY_IP}/" 10 || failures=$((failures+1)); }
    (( INSTALL_STIRLING )) && { final_lxc_check_v107 "Stirling PDF" "$STIRLING_ID" || failures=$((failures+1)); final_http_check_v107 "Stirling PDF" "https://${STIRLING_IP}/" 20 || failures=$((failures+1)); }
    (( INSTALL_NTFY )) && { final_lxc_check_v107 "ntfy" "$NTFY_ID" || failures=$((failures+1)); final_http_check_v107 "ntfy" "https://${NTFY_IP}/" 10 || failures=$((failures+1)); }
    (( INSTALL_FORGEJO )) && { final_lxc_check_v107 "Forgejo" "$FORGEJO_ID" || failures=$((failures+1)); final_http_check_v107 "Forgejo" "https://${FORGEJO_IP}/" 15 || failures=$((failures+1)); }
    (( INSTALL_SYNCTHING )) && { final_lxc_check_v107 "Syncthing" "$SYNCTHING_ID" || failures=$((failures+1)); final_http_check_v107 "Syncthing" "https://${SYNCTHING_IP}/" 15 || failures=$((failures+1)); }
    (( INSTALL_SPEEDTEST )) && { final_lxc_check_v107 "Speedtest Tracker" "$SPEEDTEST_ID" || failures=$((failures+1)); final_http_check_v107 "Speedtest Tracker" "https://${SPEEDTEST_IP}/api/healthcheck" 20 || failures=$((failures+1)); }
    (( INSTALL_SCRUTINY )) && { final_lxc_check_v107 "Scrutiny" "$SCRUTINY_ID" || failures=$((failures+1)); final_http_check_v107 "Scrutiny" "https://${SCRUTINY_IP}/" 20 || failures=$((failures+1)); systemctl is-enabled --quiet scrutiny-collector.timer || { warn "FINALTEST: Scrutiny Collector Timer nicht aktiviert."; failures=$((failures+1)); }; }
    (( INSTALL_MEALIE )) && { final_lxc_check_v107 "Mealie" "$MEALIE_ID" || failures=$((failures+1)); final_http_check_v107 "Mealie" "https://${MEALIE_IP}/" 20 || failures=$((failures+1)); }

    (( INSTALL_PBS )) && { final_lxc_check_v107 "PBS" "$PBS_ID" || failures=$((failures+1)); final_http_check_v107 "PBS" "https://${PBS_IP}:8007/" 20 || failures=$((failures+1)); }
    (( INSTALL_PULSE )) && { final_lxc_check_v107 "Pulse" "$PULSE_ID" || failures=$((failures+1)); final_http_check_v107 "Pulse" "https://${PULSE_IP}/" 15 || failures=$((failures+1)); }
    (( PVEUPS_INSTALLED )) && { final_lxc_check_v107 "PVE-UPS" "$PVEUPS_ID" || failures=$((failures+1)); final_http_check_v107 "PVE-UPS" "https://${PVEUPS_IP}/" 15 || failures=$((failures+1)); }
    (( INSTALL_SEMAPHORE )) && { final_lxc_check_v107 "Semaphore" "$SEMAPHORE_ID" || failures=$((failures+1)); final_http_check_v107 "Semaphore" "https://${SEMAPHORE_IP}/" 15 || failures=$((failures+1)); }
    (( INSTALL_POCKETID )) && { final_lxc_check_v107 "Pocket ID" "$POCKETID_ID" || failures=$((failures+1)); final_http_check_v107 "Pocket ID" "https://${POCKETID_IP}/" 15 || failures=$((failures+1)); }
    (( INSTALL_PROMETHEUS )) && { final_lxc_check_v107 "Prometheus" "$PROMETHEUS_ID" || failures=$((failures+1)); final_http_check_v107 "Prometheus" "https://${PROMETHEUS_IP}/" 15 || failures=$((failures+1)); }
    (( INSTALL_PVE_EXPORTER )) && { final_lxc_check_v107 "PVE Exporter" "$PVE_EXPORTER_ID" || failures=$((failures+1)); final_http_check_v107 "PVE Exporter" "https://${PVE_EXPORTER_IP}/" 15 || failures=$((failures+1)); }
    (( INSTALL_GRAFANA )) && { final_lxc_check_v107 "Grafana" "$GRAFANA_ID" || failures=$((failures+1)); final_http_check_v107 "Grafana" "https://${GRAFANA_IP}/" 15 || failures=$((failures+1)); }
    (( INSTALL_PANGOLIN )) && { final_lxc_check_v107 "Pangolin" "$PANGOLIN_ID" || failures=$((failures+1)); final_http_check_v107 "Pangolin" "http://${PANGOLIN_IP}:3002/" 15 || failures=$((failures+1)); }
    if (( INSTALL_NEWT )); then
        final_lxc_check_v107 "Newt" "$NEWT_ID" || failures=$((failures+1))
        pct exec "$NEWT_ID" -- systemctl is-active --quiet newt || { warn "FINALTEST: Newt-Service nicht aktiv."; failures=$((failures+1)); }
    fi
    (( INSTALL_GATUS )) && { final_lxc_check_v107 "Gatus" "$GATUS_ID" || failures=$((failures+1)); final_http_check_v107 "Gatus" "https://${GATUS_IP}/" 15 || failures=$((failures+1)); }
    (( INSTALL_HOMEPAGE )) && { final_lxc_check_v107 "Homepage" "$HOMEPAGE_ID" || failures=$((failures+1)); final_http_check_v107 "Homepage" "https://${HOMEPAGE_IP}/" 15 || failures=$((failures+1)); }
    (( INSTALL_NPM )) && { final_lxc_check_v107 "NPM" "$NPM_ID" || failures=$((failures+1)); final_http_check_v107 "NPM Admin" "http://${NPM_IP}:81/" 15 || failures=$((failures+1)); }
    if (( INSTALL_EMQX )); then
        final_lxc_check_v107 "EMQX" "$EMQX_ID" || failures=$((failures+1))
        final_http_check_v107 "EMQX Dashboard" "https://${EMQX_IP}/" 15 || failures=$((failures+1))
        if ! timeout 5 bash -c "</dev/tcp/${EMQX_IP}/1883" 2>/dev/null; then
            warn "FINALTEST: EMQX MQTT-Port 1883 ist nicht erreichbar."
            failures=$((failures+1))
        else
            ok "FINALTEST: EMQX MQTT-Port 1883 erreichbar."
        fi
    fi

    # Monitoring wird funktional geprüft, nicht nur per offenem HTTP-Port.
    if (( INSTALL_PVE_EXPORTER )); then
        if ! pct exec "$PVE_EXPORTER_ID" -- curl -fsS --max-time 8 \
            "http://127.0.0.1:9221/pve?target=${PVE_EXPORTER_TARGET_IP}" 2>/dev/null | grep -q '^pve_'; then
            warn "FINALTEST: PVE Exporter liefert keine echten Proxmox-Metriken."
            failures=$((failures+1))
        else
            ok "FINALTEST: PVE Exporter liefert echte Proxmox-Metriken."
        fi
    fi

    if (( INSTALL_PROMETHEUS && INSTALL_PVE_EXPORTER )); then
        if ! curl -fsS --max-time 8 "http://${PROMETHEUS_IP}:9090/api/v1/targets" 2>/dev/null |
            python3 -c 'import json,sys; d=json.load(sys.stdin); a=d.get("data",{}).get("activeTargets",[]); raise SystemExit(0 if any(t.get("labels",{}).get("job")=="proxmox" and t.get("health")=="up" for t in a) else 1)'; then
            warn "FINALTEST: Prometheus-Proxmox-Target ist nicht UP."
            failures=$((failures+1))
        else
            ok "FINALTEST: Prometheus sieht den Proxmox-Target als UP."
        fi
    fi

    if (( INSTALL_PROMETHEUS && INSTALL_PIHOLE )); then
        if ! curl -fsS --max-time 8 "http://${PROMETHEUS_IP}:9090/api/v1/targets" 2>/dev/null |
            python3 -c 'import json,sys; d=json.load(sys.stdin); a=d.get("data",{}).get("activeTargets",[]); raise SystemExit(0 if any(t.get("labels",{}).get("job")=="pihole" and t.get("health")=="up" for t in a) else 1)'; then
            warn "FINALTEST: Prometheus-Pi-hole-Target ist nicht UP."
            failures=$((failures+1))
        else
            ok "FINALTEST: Prometheus sieht den Pi-hole-Target als UP."
        fi
    fi

    if (( INSTALL_GRAFANA && INSTALL_PROMETHEUS )); then
        if ! curl -fsS --max-time 8 -u "admin:${GRAFANA_ADMIN_PASS}" \
            "http://${GRAFANA_IP}:3000/api/datasources/uid/prometheus-v107" 2>/dev/null |
            grep -q '"type":"prometheus"'; then
            warn "FINALTEST: Grafana Prometheus-Datasource fehlt oder ist nicht abrufbar."
            failures=$((failures+1))
        else
            ok "FINALTEST: Grafana Prometheus-Datasource vorhanden."
        fi
    fi

    # Sobald mindestens ein verwalteter TLS-Endpunkt registriert ist, müssen
    # Service und wöchentlicher Renewal-Timer tatsächlich vorhanden/aktiv sein.
    if [[ -s "${LOCAL_CA_ROOT}/managed-services.tsv" ]]; then
        systemctl is-enabled --quiet proxmox-master-tls-renew.timer || {
            warn "FINALTEST: TLS-Renewal-Timer ist nicht aktiviert."
            failures=$((failures+1))
        }
        systemctl is-active --quiet proxmox-master-tls-renew.timer || {
            warn "FINALTEST: TLS-Renewal-Timer ist nicht aktiv."
            failures=$((failures+1))
        }
        [[ -s "${LOCAL_CA_ROOT}/nodezero-local-ca.crt" && -s "${LOCAL_CA_ROOT}/nodezero-local-ca.key" ]] || {
            warn "FINALTEST: lokale NodeZero-CA ist unvollständig."
            failures=$((failures+1))
        }
    fi

    if (( NEED_GUESTS )); then
        local avail_kib avail_pct
        avail_kib="$(storage_kib_value_v107 "$DISK_STORAGE" avail)"
        avail_pct="$(pvesm status 2>/dev/null | awk -v s="$DISK_STORAGE" 'NR>1 && $1==s {print $7; exit}')"
        info "FINALTEST Storage: ${DISK_STORAGE} · frei $(kib_to_gib_ceil_v107 "${avail_kib:-0}") GB · Belegung ${avail_pct:-unbekannt}"
    fi

    persist_install_secrets_v107 || { warn "FINALTEST: Secret-Dateien konnten nicht aktualisiert werden."; failures=$((failures+1)); }

    # Explizit prüfen, dass jedes in diesem Lauf erzeugte Secret in seiner
    # eigenen Datei angekommen ist. Leere/nicht erzeugte optionale Werte werden
    # absichtlich übersprungen.
    final_secret_file_check_v107 "dashboard-control" "${DASHBOARD_CODE_FOR_FILE:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "os-${OS_NAME:-vm}-login" "${OS_PASS:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "paperless-admin" "${PAPERLESS_PASS:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "paperless-postgresql" "${DB_PASS:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "paperless-secret-key" "${SECRET_KEY:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "pihole-web-api" "${PIHOLE_PASS:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "pihole-home-assistant-app" "${PIHOLE_APP_PASS:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "vaultwarden-admin-token" "${VAULTWARDEN_ADMIN_TOKEN:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "stirling-admin" "${STIRLING_ADMIN_PASS:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "speedtest-admin" "${SPEEDTEST_ADMIN_PASS:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "speedtest-app-key" "${SPEEDTEST_APP_KEY:-}" || failures=$((failures+1))
    if (( INSTALL_MEALIE )); then
        final_secret_file_check_v107 "mealie-default-login" "${MEALIE_DEFAULT_PASS:-}" || failures=$((failures+1))
    fi
    final_secret_file_check_v107 "pbs-lxc-root" "${PBS_ROOT_PASS:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "pulse-lxc-root" "${PULSE_ROOT_PASS:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "pulse-admin" "${PULSE_ADMIN_PASS:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "pulse-api-token" "${PULSE_API_TOKEN:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "pve-ups-lxc-root" "${PVEUPS_ROOT_PASS:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "semaphore-lxc-root" "${SEMAPHORE_ROOT_PASS:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "semaphore-admin" "${SEMAPHORE_ADMIN_PASS:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "semaphore-cookie-hash" "${SEMAPHORE_COOKIE_HASH:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "semaphore-cookie-encryption" "${SEMAPHORE_COOKIE_ENCRYPTION:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "semaphore-access-key-encryption" "${SEMAPHORE_ACCESS_KEY_ENCRYPTION:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "pocketid-lxc-root" "${POCKETID_ROOT_PASS:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "pocketid-encryption-key" "${POCKETID_ENCRYPTION_KEY:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "prometheus-lxc-root" "${PROMETHEUS_ROOT_PASS:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "pve-exporter-lxc-root" "${PVE_EXPORTER_ROOT_PASS:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "pve-exporter-api-token" "${PVE_EXPORTER_TOKEN_SECRET:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "grafana-lxc-root" "${GRAFANA_ROOT_PASS:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "grafana-admin" "${GRAFANA_ADMIN_PASS:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "pangolin-lxc-root" "${PANGOLIN_ROOT_PASS:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "newt-lxc-root" "${NEWT_ROOT_PASS:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "newt-site-secret" "${NEWT_SITE_SECRET:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "gatus-lxc-root" "${GATUS_ROOT_PASS:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "homepage-lxc-root" "${HOMEPAGE_ROOT_PASS:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "npm-lxc-root" "${NPM_ROOT_PASS:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "emqx-lxc-root" "${EMQX_ROOT_PASS:-}" || failures=$((failures+1))
    final_secret_file_check_v107 "emqx-admin" "${EMQX_ADMIN_PASS:-}" || failures=$((failures+1))

    if [[ -d "$INSTALL_SECRET_DIR_V107" ]]; then
        local bad_secret_perm=0 f mode
        while IFS= read -r f; do
            mode="$(stat -c '%a' "$f" 2>/dev/null || true)"
            [[ "$mode" == "600" ]] || { warn "FINALTEST: falsche Rechte ${mode:-?} auf $f"; bad_secret_perm=1; }
        done < <(find "$INSTALL_SECRET_DIR_V107" -maxdepth 1 -type f -name "*${INSTALL_SECRET_STAMP_V107}*.txt" -print)
        (( bad_secret_perm == 0 )) || failures=$((failures+1))
    fi

    if (( failures > 0 )); then
        warn "FINALTEST: ${failures} Prüfung(en) fehlgeschlagen."
        return 1
    fi

    ok "FINALTEST: alle ausgewählten Komponenten haben die Abschlussprüfung bestanden."
    return 0
}

# =============================================================================
# V107 · FINALER STORAGE-PREFLIGHT NACH ALLEN RESSOURCEN-EINGABEN
# =============================================================================

PLANNED_GUEST_DISK_GB_V107=0
if (( NEED_GUESTS )); then
    PLANNED_GUEST_DISK_GB_V107="$(selected_guest_disk_sum_v107)"

    if (( PLANNED_GUEST_DISK_GB_V107 > 0 )); then
        storage_capacity_preflight_v107             "$DISK_STORAGE"             "$PLANNED_GUEST_DISK_GB_V107"             "ausgewählte Installation"

        storage_available_preflight_v107             "$DISK_STORAGE"             "$PLANNED_GUEST_DISK_GB_V107"             "ausgewählte Installation"
    fi
fi

# Zugangsdaten sind bereits VOR den eigentlichen Installationsschritten
# persistent. Ein späterer Download-/Runtime-Fehler verliert daher keine
# zuvor erzeugten Passwörter.
persist_install_secrets_v107

# Falls ein späterer Installationsschritt abbricht, werden bis dahin neu
# entstandene Secrets (z. B. Semaphore-Admin oder PVE-UPS-Token) trotzdem
# nochmals extern gesichert. Der ursprüngliche Exit-Code bleibt erhalten.
persist_install_secrets_on_exit_v107() {
    local rc=$?
    trap - EXIT
    set +e
    persist_install_secrets_v107 >/dev/null 2>&1
    exit "$rc"
}
trap persist_install_secrets_on_exit_v107 EXIT

# =============================================================================
# AUSFÜHRUNG
# =============================================================================

# Die vollständig ausgefüllte Konfiguration bereits VOR der eigentlichen
# Installation persistent sichern. So bleiben die Werte auch dann erhalten,
# wenn später ein Download oder Installationsschritt fehlschlägt.
if setup_profile_save_v64 setup; then
    ok "Setup-Konfiguration gespeichert: $SETUP_PROFILE_LAST_SETUP"
else
    warn "Setup-Konfiguration konnte nicht gespeichert werden."
fi

if (( TUI_AVAILABLE && ! OPTIMAL_INSTALL )); then
    whiptail         --backtitle "$TUI_BACKTITLE"         --title "INSTALLATION STARTET"         --ok-button "Starten"         --msgbox "Die Konfiguration ist abgeschlossen.

Nach dem Schließen dieses Fensters läuft die Installation im Terminal weiter. Fortschritt und Fehler bleiben dadurch vollständig sichtbar."         14 80
    clear 2>/dev/null || true
elif (( OPTIMAL_INSTALL )); then
    clear 2>/dev/null || true
    header "OPTIMALE INSTALLATION · AUTOMATISCHER START"
    info "Alle Standardwerte sind gesetzt; Installation startet ohne weitere Rückfrage."
fi

ui_progress_init "$(count_install_steps)"

run_install_step \
    "Proxmox WebUI vorbereiten · Subscription-Hinweis" \
    install_pve_subscription_nag_removal

if (( INSTALL_PAPERLESS || INSTALL_PIHOLE || INSTALL_NETALERTX ||
      INSTALL_UPTIME || INSTALL_VAULTWARDEN || INSTALL_CADDY || INSTALL_STIRLING ||
      INSTALL_NTFY || INSTALL_FORGEJO || INSTALL_SYNCTHING || INSTALL_SPEEDTEST ||
      INSTALL_SCRUTINY || INSTALL_MEALIE )); then
    run_install_step \
        "Installationsbasis vorbereiten · Debian LXC Template" \
        prepare_lxc_template
fi

(( INSTALL_DASHBOARD )) && run_install_step "Server-Dashboard" install_dashboard
(( INSTALL_OS )) && run_install_step "Betriebssystem · ${OS_LABEL}" install_operating_system_v61
(( INSTALL_HA )) && run_install_step "Home Assistant OS" install_home_assistant
(( INSTALL_PAPERLESS )) && run_install_step "Paperless-ngx + Ollama" install_paperless

# V138: Bei einem reinen Dashboard-Update einen bereits vorhandenen
# Paperless-CT nachziehen. Bei Neuinstallation prüft install_paperless() selbst.
if (( INSTALL_DASHBOARD && ! INSTALL_PAPERLESS )); then
    run_install_step         "Paperless HTTPS / CSRF / Login-IP prüfen"         repair_existing_paperless_proxy_v138
fi

(( INSTALL_PIHOLE )) && run_install_step "Pi-hole + Unbound" install_pihole
(( INSTALL_NETALERTX )) && run_install_step "NetAlertX" install_netalertx

(( INSTALL_UPTIME )) && run_install_step "Uptime Kuma" install_uptime_kuma
(( INSTALL_VAULTWARDEN )) && run_install_step "Vaultwarden" install_vaultwarden
(( INSTALL_CADDY )) && run_install_step "Caddy Reverse Proxy" install_caddy
(( INSTALL_STIRLING )) && run_install_step "Stirling PDF" install_stirling_pdf
(( INSTALL_NTFY )) && run_install_step "ntfy" install_ntfy
(( INSTALL_FORGEJO )) && run_install_step "Forgejo" install_forgejo
(( INSTALL_SYNCTHING )) && run_install_step "Syncthing" install_syncthing
(( INSTALL_SPEEDTEST )) && run_install_step "Speedtest Tracker" install_speedtest_tracker
(( INSTALL_SCRUTINY )) && run_install_step "Scrutiny" install_scrutiny
(( INSTALL_MEALIE )) && run_install_step "Mealie" install_mealie

(( INSTALL_PBS )) && run_install_step "Proxmox Backup Server" install_proxmox_backup_server
(( INSTALL_PULSE )) && run_pulse_install_step_v86
(( INSTALL_PVEUPS )) && run_install_step "PVE-UPS" install_pve_ups_community
(( INSTALL_SEMAPHORE )) && run_install_step "Semaphore" install_semaphore_v65
(( INSTALL_POCKETID )) && run_install_step "Pocket ID" install_pocketid_v65
(( INSTALL_PROMETHEUS )) && run_install_step "Prometheus" install_prometheus_v65
(( INSTALL_PVE_EXPORTER )) && run_install_step "Prometheus PVE Exporter" install_pve_exporter_v65
(( INSTALL_GRAFANA )) && run_install_step "Grafana" install_grafana_v65
(( INSTALL_PANGOLIN )) && run_install_step "Pangolin" install_pangolin_v65
(( INSTALL_NEWT )) && run_install_step "Newt" install_newt_v65
(( INSTALL_GATUS )) && run_install_step "Gatus" install_gatus_v65
(( INSTALL_HOMEPAGE )) && run_install_step "Homepage" install_homepage_v65
(( INSTALL_NPM )) && run_install_step "Nginx Proxy Manager" install_npm_v65
(( INSTALL_EMQX )) && run_install_step "EMQX MQTT Broker" install_emqx_v66
(( INSTALL_CROWDSEC )) && run_install_step "CrowdSec Add-on" install_crowdsec_addon_v65

if (( INSTALL_PROMETHEUS && INSTALL_PVE_EXPORTER || INSTALL_GRAFANA && INSTALL_PROMETHEUS )); then
    run_install_step "Monitoring-Stack verbinden · PVE Exporter · Prometheus · Grafana" configure_monitoring_stack_v107
fi

# Menü/Link-Manager bewusst erst am Ende:
# Dann können frisch installierte HA/Paperless/Pi-hole/NetAlertX-Instanzen
# automatisch in die Linkliste übernommen werden.
if (( INSTALL_DASHBOARD )); then
    ui_progress_step "Dashboard integrieren · Links · Kategorien · Einstellungen"
fi

(( INSTALL_DASHBOARD )) && install_dashboard_extras
(( INSTALL_DASHBOARD )) && install_dashboard_menu_sorting
(( INSTALL_DASHBOARD )) && install_dashboard_router_domain_fix
(( INSTALL_DASHBOARD )) && install_dashboard_router_top_link
(( INSTALL_DASHBOARD )) && install_dashboard_menu_editor_v4
(( INSTALL_DASHBOARD )) && install_dashboard_settings_v4
(( INSTALL_DASHBOARD )) && install_dashboard_settings_write_paths
# V69: TLS erst nach allen modernen Dashboard-Patches.
# Dadurch bleibt das Menü selbst bei einem TLS-Fehler auf dem aktuellen Stand.

# V42: ein Einstellungsfenster + Kategorien, ohne das Messdaten-Backend zu ersetzen.
(( INSTALL_DASHBOARD )) && install_dashboard_settings_hub_v42
(( INSTALL_DASHBOARD )) && install_dashboard_categories_v42
(( INSTALL_DASHBOARD )) && install_dashboard_category_assignment_v42
(( INSTALL_DASHBOARD )) && install_dashboard_menu_cleanup_v42

# Neue Zusatzdienste nach Installation/Update des Link-Managers sicher eintragen.
(( INSTALL_UPTIME )) && dashboard_link_upsert "Uptime Kuma" "https://${UPTIME_IP}/"
(( INSTALL_VAULTWARDEN )) && dashboard_link_upsert "Vaultwarden" "https://${VAULTWARDEN_IP}/"
(( INSTALL_CADDY )) && dashboard_link_upsert "Caddy Reverse Proxy" "http://${CADDY_IP}/"
(( INSTALL_STIRLING )) && dashboard_link_upsert "Stirling PDF" "https://${STIRLING_IP}/"
(( INSTALL_NTFY )) && dashboard_link_upsert "ntfy" "https://${NTFY_IP}/"
(( INSTALL_FORGEJO )) && dashboard_link_upsert "Forgejo" "https://${FORGEJO_IP}/"
(( INSTALL_SYNCTHING )) && dashboard_link_upsert "Syncthing" "https://${SYNCTHING_IP}/"
(( INSTALL_SPEEDTEST )) && dashboard_link_upsert "Speedtest Tracker" "https://${SPEEDTEST_IP}/"
(( INSTALL_SCRUTINY )) && dashboard_link_upsert "Scrutiny" "https://${SCRUTINY_IP}/"
(( INSTALL_MEALIE )) && dashboard_link_upsert "Mealie" "https://${MEALIE_IP}/"
(( INSTALL_PBS )) && dashboard_link_upsert "Proxmox Backup Server" "https://${PBS_IP}:8007/"
(( INSTALL_PULSE )) && dashboard_link_upsert "Pulse" "https://${PULSE_IP}/"
(( PVEUPS_INSTALLED )) && dashboard_link_upsert "PVE-UPS" "https://${PVEUPS_IP}/"
(( INSTALL_SEMAPHORE )) && dashboard_link_upsert "Semaphore" "https://${SEMAPHORE_IP}/"
(( INSTALL_POCKETID )) && dashboard_link_upsert "Pocket ID" "https://${POCKETID_IP}/"
(( INSTALL_PROMETHEUS )) && dashboard_link_upsert "Prometheus" "https://${PROMETHEUS_IP}/"
(( INSTALL_PVE_EXPORTER )) && dashboard_link_upsert "Prometheus PVE Exporter" "https://${PVE_EXPORTER_IP}/"
(( INSTALL_GRAFANA )) && dashboard_link_upsert "Grafana" "https://${GRAFANA_IP}/"
(( INSTALL_PANGOLIN )) && dashboard_link_upsert "Pangolin" "http://${PANGOLIN_IP}:3002/"
(( INSTALL_GATUS )) && dashboard_link_upsert "Gatus" "https://${GATUS_IP}/"
(( INSTALL_HOMEPAGE )) && dashboard_link_upsert "Homepage" "https://${HOMEPAGE_IP}/"
(( INSTALL_NPM )) && dashboard_link_upsert "Nginx Proxy Manager" "http://${NPM_IP}:81/"
(( INSTALL_EMQX )) && dashboard_link_upsert "EMQX MQTT" "https://${EMQX_IP}/"

# V134: Bei Dashboard-Updates vorhandene bekannte Web-CTs erneut erkennen.
# Nur fehlende Links werden ergänzt; manuelle/bestehende Links bleiben erhalten.
if (( INSTALL_DASHBOARD )) || [[ -f /opt/nodezero/dashboard/static/index.html ]]; then
    dashboard_reconcile_existing_guests_v134
fi

if (( INSTALL_DASHBOARD )); then
    python3 - <<'PYROUTERFINAL'
from pathlib import Path
import json

p = Path("/var/lib/pve-sensor-dashboard-web/links.json")

try:
    links = json.loads(p.read_text(encoding="utf-8"))
except Exception:
    links = []

if isinstance(links, list):
    router = [x for x in links if isinstance(x, dict) and x.get("id") == "router"]
    rest = [x for x in links if not (isinstance(x, dict) and x.get("id") == "router")]
    if router:
        p.write_text(
            json.dumps(router[:1] + rest, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
PYROUTERFINAL
    chown pve-monitor:pve-monitor /var/lib/pve-sensor-dashboard-web/links.json 2>/dev/null || true
    chmod 600 /var/lib/pve-sensor-dashboard-web/links.json 2>/dev/null || true
fi

# Erst jetzt sind Basis- und optionale Webseiten vollständig bekannt.
# Bei einem bereits installierten Dashboard Kategorien auch dann aktualisieren,
# wenn in diesem Lauf nur PBS/Pulse/PVE-UPS ergänzt wurden.
if (( INSTALL_DASHBOARD )) || {
    [[ -f /opt/nodezero/dashboard/static/index.html ]] &&
    [[ -f /var/lib/pve-sensor-dashboard-web/categories.json ]];
}; then
    install_dashboard_default_categories_v42
fi

# V53: Mainboard-Karte durch USV/NAS ersetzen.
# Bei frisch installiertem PVE-UPS dessen tatsächlich gewählte IP verwenden.
# Bei bestehender Installation Standardquelle 192.168.178.111 verwenden.
if (( INSTALL_DASHBOARD )) || [[ -f /opt/nodezero/dashboard/static/index.html ]]; then
    install_dashboard_ups_card_v53
    install_dashboard_ups_settings_v55
    install_dashboard_ups_ui_fix_v56
    install_dashboard_settings_remember_v57
    install_dashboard_layout_editor_v71
    install_dashboard_pihole_settings_v78
    install_dashboard_pihole_menu_fix_v80
    install_dashboard_settings_panels_host_v81
fi

# V69:
# Erst muss die moderne Dashboard-Oberfläche vollständig vorhanden sein.
# Danach wird TLS/443 eingerichtet.
if (( INSTALL_DASHBOARD )); then
    validate_dashboard_final_state_v69 ||         die "Dashboard-UI ist nicht vollständig. TLS wird nicht angewendet."

    configure_dashboard_dual_ports_v65

    # V95: PVE-UPS bleibt eigenständig auf HTTPS/443; /usv ist nur ein
    # stabiler Dashboard-Kurzpfad (Redirect), kein fehleranfälliger Subpath-Proxy.
    install_dashboard_usv_shortcut_v95

    # TLS darf die fertige UI nicht verändern oder zurücksetzen.
    validate_dashboard_final_state_v69 ||         die "Dashboard-UI wurde nach TLS unerwartet verändert."
fi

# =============================================================================
# V107 · ABSCHLIESSENDE LAUFZEITPRÜFUNG
# =============================================================================

if ! final_install_validation_v107; then
    persist_install_secrets_v107 || true
    die "Der finale Funktionstest hat Fehler gefunden. Das Setup wird NICHT als erfolgreich gespeichert. Bitte die ausgegebenen FINALTEST-Meldungen prüfen."
fi

# =============================================================================
# SETUP-PROFIL · ERFOLGREICHER STAND
# =============================================================================

if setup_profile_save_v64 success; then
    ok "Erfolgreiches Setup-Profil gespeichert: $SETUP_PROFILE_LAST_SUCCESS"
else
    warn "Erfolgreiches Setup-Profil konnte nicht gespeichert werden."
fi

# =============================================================================
# PASSWÖRTER / ÜBERSICHT / ABSCHLUSS
# =============================================================================

# V107: Passwörter/Tokens liegen nicht mehr gesammelt in einer großen Datei.
# Jede Zugangsinformation hat ihre eigene Datei unter /root/passwort. Die Variable
# PASSWORD_FILE zeigt auf einen Index, der ausschließlich Dateipfade enthält.
persist_install_secrets_v107

OVERVIEW_FILE="/root/PROXMOX-MODULAR-INSTALL-CREDENTIALS.txt"


# ------------------------------------------------------------------
# Normale Installationsübersicht / Logs
# KEINE Klartext-Passwörter hier speichern.
# ------------------------------------------------------------------

{
    echo "Proxmox Modular Installer"
    echo "Erstellt: $(date)"
    echo "Host: $(hostname)"
    echo
    echo "Passwörter / Sicherheitscodes:"
    echo "  $PASSWORD_FILE"
    echo

    if (( INSTALL_DASHBOARD )); then
        echo "=================================================="
        echo "Dashboard"
        echo "=================================================="
        echo "URL: https://${DASHBOARD_IP}/"
        echo "Normale Seite: kein Login"
        echo "Power-Aktionen: Steuer-Code erforderlich"
        echo "Steuer-Code: siehe $PASSWORD_FILE"
        echo "Code neu setzen: pve-dashboard-set-code"
        echo "Service-Links anzeigen: pve-dashboard-link list"
        echo "Service-Link hinzufügen: pve-dashboard-link add NAME URL"
        echo "Service-Link sortieren: pve-dashboard-link move NAME POSITION"
        echo "Link-Importdatei: /root/pve-dashboard-links-beispiel.txt"
        echo
    fi

    if (( INSTALL_OS )); then
        echo "=================================================="
        echo "Betriebssystem · ${OS_LABEL}"
        echo "=================================================="
        echo "VM-ID: $OS_ID"
        echo "VM-Name: $OS_NAME"
        echo "Profil: $([[ "$OS_MODE" == "desktop" ]] && echo "mit Grafik" || echo "ohne Grafik")"
        echo "CPU: $OS_CORES"
        echo "RAM: $((OS_MEMORY / 1024)) GB"
        echo "Disk: $OS_DISK GB"

        if [[ -n "$OS_IP" ]]; then
            echo "IP: $OS_IP"
            echo "Zugang: siehe $PASSWORD_FILE"
        else
            echo "Installation: ISO / Proxmox-Konsole"
        fi

        echo
    fi

    if (( INSTALL_HA )); then
        echo "=================================================="
        echo "Home Assistant"
        echo "=================================================="
        echo "VM-ID: $HA_ID"
        echo "IP: $HA_IP"
        echo "URL: http://${HA_IP}:8123/"
        echo "Port: 8123"
        echo "System-Disk: ${HA_DISK} GB"
        echo "Login wird innerhalb Home Assistant angelegt."
        echo
    fi

    if (( INSTALL_PAPERLESS )); then
        echo "=================================================="
        echo "Paperless + Ollama"
        echo "=================================================="
        echo "CT-ID: $PL_ID"
        echo "URL: https://${PAPERLESS_IP}/"
        echo "Benutzer: $PAPERLESS_USER"
        echo "Passwort: siehe $PASSWORD_FILE"
        echo "LLM: $OLLAMA_MODEL"
        echo "Embedding: $OLLAMA_EMBED_MODEL"
        echo
    fi

    if (( INSTALL_PIHOLE )); then
        echo "=================================================="
        echo "Pi-hole + Unbound"
        echo "=================================================="
        echo "CT-ID: $PH_ID"
        echo "Web: http://${PIHOLE_IP}/admin"
        echo "DNS: $PIHOLE_IP"
        echo "Web/API-Passwort: siehe $PASSWORD_FILE"
        echo "HA App-Passwort: siehe $PASSWORD_FILE"
        echo "Authentifizierung: pihole-auth-manager"
        echo "Web/API-Passwort ändern: pihole-reset-password"
        echo "HA App-Passwort neu erzeugen: pihole-ha-app-password"
        echo "HA Integration: Host $PIHOLE_IP · Port 80 · Location /admin · SSL AUS"
        echo "Sprache: $PIHOLE_LANG"
        echo "Sprache umstellen: pihole-language"
        echo "Unbound: 127.0.0.1#5335"
        echo "Prometheus Exporter: http://${PIHOLE_IP}:9617/metrics"
        echo
    fi

    if (( INSTALL_NETALERTX )); then
        echo "=================================================="
        echo "NetAlertX"
        echo "=================================================="
        echo "CT-ID: $NAX_ID"
        echo "Web: https://${NETALERTX_IP}/"
        echo "Web-Port: 80 (nginx -> 20211)"
        echo "NetAlertX intern: 20211"
        echo "GraphQL-Backend: separater Port 20212"
        echo "Scan-Netz: $NETALERTX_SUBNET"
        echo "Daten: /opt/netalertx/data im CT"
        echo
    fi

    if (( INSTALL_UPTIME )); then
        echo "Uptime Kuma: CT $UPTIME_ID | https://${UPTIME_IP}/ | Monitoring | Daten: /home/Data/uptime-kuma"
    fi
    if (( INSTALL_VAULTWARDEN )); then
        echo "Vaultwarden: CT $VAULTWARDEN_ID | https://${VAULTWARDEN_IP}/ | Passwort siehe $PASSWORD_FILE"
    fi
    if (( INSTALL_CADDY )); then
        echo "Caddy: CT $CADDY_ID | http://${CADDY_IP}/ | /opt/caddy/Caddyfile"
    fi
    if (( INSTALL_STIRLING )); then
        echo "Stirling PDF: CT $STIRLING_ID | https://${STIRLING_IP}/ | Login siehe $PASSWORD_FILE"
    fi
    if (( INSTALL_NTFY )); then
        echo "ntfy: CT $NTFY_ID | https://${NTFY_IP}/ | Push-Benachrichtigungen"
    fi
    if (( INSTALL_FORGEJO )); then
        echo "Forgejo: CT $FORGEJO_ID | https://${FORGEJO_IP}/ | SSH-Port 222"
    fi
    if (( INSTALL_SYNCTHING )); then
        echo "Syncthing: CT $SYNCTHING_ID | https://${SYNCTHING_IP}/"
    fi
    if (( INSTALL_SPEEDTEST )); then
        echo "Speedtest Tracker: CT $SPEEDTEST_ID | https://${SPEEDTEST_IP}/ | Login siehe $PASSWORD_FILE"
    fi
    if (( INSTALL_SCRUTINY )); then
        echo "Scrutiny: CT $SCRUTINY_ID | https://${SCRUTINY_IP}/ | Proxmox Collector alle 15 Minuten"
    fi
    if (( INSTALL_MEALIE )); then
        echo "Mealie: CT $MEALIE_ID | https://${MEALIE_IP}/ | Erstlogin siehe $PASSWORD_FILE"
    fi
    if (( INSTALL_PBS )); then
        echo "Proxmox Backup Server: CT $PBS_ID | https://${PBS_IP}:8007/ | Passwort siehe $PASSWORD_FILE | Datastore noch konfigurieren"
    fi
    if (( INSTALL_PULSE )); then
        echo "Pulse: CT $PULSE_ID | https://${PULSE_IP}/ | Admin/API-Zugang siehe $PASSWORD_FILE | PVE auto=$PULSE_PVE_REGISTERED | PBS auto=$PULSE_PBS_REGISTERED"
    fi
    if (( PVEUPS_INSTALLED )); then
        echo "PVE-UPS: CT $PVEUPS_ID | https://${PVEUPS_IP}/ | NUT/API-Setup erforderlich"
    elif (( PVEUPS_SKIPPED )); then
        echo "PVE-UPS: übersprungen; Community-Script aktuell nicht freigegeben/Status nicht erreichbar"
    fi

} > "$OVERVIEW_FILE"

chmod 600 "$OVERVIEW_FILE"
chown root:root "$OVERVIEW_FILE"

header "INSTALLATION ABGESCHLOSSEN"

echo "${GREEN}${BOLD}Alle ausgewählten Installationsschritte wurden beendet.${RESET}"
echo

if (( INSTALL_OS )); then
    ui_section "Betriebssystem"
    ui_kv "System" "$OS_LABEL"
    ui_kv "VM" "${OS_ID} · ${OS_NAME}"
    ui_kv "Profil" "$([[ "$OS_MODE" == "desktop" ]] && echo "mit Grafik" || echo "ohne Grafik")"
    ui_kv "CPU / RAM" "${OS_CORES} Kerne / $((OS_MEMORY / 1024)) GB"
    ui_kv "Disk" "${OS_DISK} GB"

    if [[ -n "$OS_IP" ]]; then
        ui_kv "IP" "$OS_IP"
        ui_kv "Zugang" "siehe $PASSWORD_FILE"
    else
        ui_kv "Setup" "in der Proxmox-Konsole fortsetzen"
    fi

    ui_section_end
    echo
fi

ui_section "Weboberflächen"

(( INSTALL_DASHBOARD )) && ui_kv "Dashboard" "https://${DASHBOARD_IP}/ · HTTP → HTTPS"
(( INSTALL_HA )) && ui_kv "Home Assistant" "http://${HA_IP}:8123/ · HAOS nativ"
(( INSTALL_PAPERLESS )) && ui_kv "Paperless" "https://${PAPERLESS_IP}/"
(( INSTALL_PIHOLE )) && ui_kv "Pi-hole" "http://${PIHOLE_IP}/admin"
(( INSTALL_NETALERTX )) && ui_kv "NetAlertX" "https://${NETALERTX_IP}/"
(( INSTALL_UPTIME )) && ui_kv "Uptime Kuma" "https://${UPTIME_IP}/"
(( INSTALL_VAULTWARDEN )) && ui_kv "Vaultwarden" "https://${VAULTWARDEN_IP}/"
(( INSTALL_CADDY )) && ui_kv "Caddy" "http://${CADDY_IP}/"
(( INSTALL_STIRLING )) && ui_kv "Stirling PDF" "https://${STIRLING_IP}/"
(( INSTALL_NTFY )) && ui_kv "ntfy" "https://${NTFY_IP}/"
(( INSTALL_FORGEJO )) && ui_kv "Forgejo" "https://${FORGEJO_IP}/"
(( INSTALL_SYNCTHING )) && ui_kv "Syncthing" "https://${SYNCTHING_IP}/"
(( INSTALL_SPEEDTEST )) && ui_kv "Speedtest" "https://${SPEEDTEST_IP}/"
(( INSTALL_SCRUTINY )) && ui_kv "Scrutiny" "https://${SCRUTINY_IP}/"
(( INSTALL_MEALIE )) && ui_kv "Mealie" "https://${MEALIE_IP}/"
(( INSTALL_PBS )) && ui_kv "PBS" "https://${PBS_IP}:8007/"
(( INSTALL_PULSE )) && ui_kv "Pulse" "https://${PULSE_IP}/"
(( PVEUPS_INSTALLED )) && ui_kv "PVE-UPS" "https://${PVEUPS_IP}/ · HTTP → HTTPS"
(( INSTALL_SEMAPHORE )) && ui_kv "Semaphore" "https://${SEMAPHORE_IP}/ · HTTP → HTTPS"
(( INSTALL_POCKETID )) && ui_kv "Pocket ID" "https://${POCKETID_IP}/"
(( INSTALL_PROMETHEUS )) && ui_kv "Prometheus" "https://${PROMETHEUS_IP}/ · HTTP → HTTPS"
(( INSTALL_PVE_EXPORTER )) && ui_kv "PVE Exporter" "https://${PVE_EXPORTER_IP}/ · HTTP → HTTPS"
(( INSTALL_GRAFANA )) && ui_kv "Grafana" "https://${GRAFANA_IP}/ · HTTP → HTTPS"
(( INSTALL_PANGOLIN )) && ui_kv "Pangolin" "http://${PANGOLIN_IP}:3002/ · HTTPS 443 produktiv"
(( INSTALL_GATUS )) && ui_kv "Gatus" "https://${GATUS_IP}/ · HTTP → HTTPS"
(( INSTALL_HOMEPAGE )) && ui_kv "Homepage" "https://${HOMEPAGE_IP}/ · HTTP → HTTPS"
(( INSTALL_NPM )) && ui_kv "NPM Admin" "http://${NPM_IP}:81/ · Proxy 80/443"
(( INSTALL_EMQX )) && ui_kv "EMQX Dashboard" "https://${EMQX_IP}/ · HTTP → HTTPS"
(( INSTALL_EMQX )) && ui_kv "EMQX MQTT" "1883 · MQTTS 8883 · WS 8083 · WSS 8084"

ui_section_end
echo

ui_section "Wichtige Dateien & Befehle"
ui_kv "Passwörter" "$PASSWORD_FILE"
ui_kv "Übersicht" "$OVERVIEW_FILE"
ui_kv "Passwort-Tool" "proxmox-passwoerter"
ui_kv "Auto-Updater" "proxmox-auto-updater-config"
ui_kv "Setup-Profile" "Hauptmenü → 17"
(( INSTALL_PIHOLE )) && ui_kv "Pi-hole PW" "pihole-reset-password"
(( INSTALL_PIHOLE )) && ui_kv "Pi-hole Sprache" "pihole-language"
ui_section_end
echo

ui_section "Persistenz"
ui_kv "Download-Cache" "/home/img"
ui_kv "App-Daten" "/home/Data"
ui_kv "Backups" "/root/backups/"
ui_kv "Diagnosen" "/root/diagnose/"
ui_kv "Setup zuletzt" "/home/Data/proxmox-installer/last-setup.json"
ui_kv "Setup erfolgreich" "/home/Data/proxmox-installer/last-success.json"
ui_kv "Setup-Historie" "/home/Data/proxmox-installer/profiles/"
ui_kv "Lokale TLS-CA" "/home/Data/proxmox-installer/tls/nodezero-local-ca.crt"
(( INSTALL_PAPERLESS && PAPERLESS_EXTERNAL_STORAGE )) && ui_kv "Paperless NAS" "${PAPERLESS_NAS_IP}:${PAPERLESS_NAS_PATH} → ${PAPERLESS_NAS_MOUNT}"
ui_note "Setup-Profile können aus /home/Data, von beliebigen Dateipfaden oder per HTTP/HTTPS geladen werden."
ui_note "Passwörter, Tokens und Sicherheitscodes werden nicht in Setup-Profilen gespeichert."
ui_note "\"KOMPLETT NEU\" löscht /home/img und /home/Data nicht."
ui_section_end
echo

ui_section "Proxmox WebUI"
ui_kv "Subscription" "Hinweis automatisch entfernt"
ui_kv "Update-Schutz" "DPkg-Hook wendet Patch nach Paketupdates erneut an"
ui_section_end
echo

if (( INSTALL_DASHBOARD )); then
    ui_section "Dashboard"
    ui_kv "Einstellungen" "☰ Menü → ⚙ Einstellungen"
    ui_kv "Reiter" "Webseitenverwaltung · Kategorien · Dashboard"
    ui_kv "Intern" "Proxmox + Fritz!Box · geschlossen/aufklappbar"
    ui_kv "Basics" "Basisdienste + PBS · immer geöffnet"
    ui_kv "Extras" "Zusatzdienste + Pulse/PVE-UPS · geschlossen/aufklappbar"
    ui_kv "Code setzen" "pve-dashboard-set-code"
    ui_kv "Links" "pve-dashboard-link list"
    ui_kv "API-Test" "curl http://127.0.0.1:9105/api/current"
    ui_section_end
    echo
fi

if (( INSTALL_PULSE )); then
    ui_section "Pulse · fertig eingerichtet"
    ui_kv "Web" "https://${PULSE_IP}/"
    ui_kv "Admin" "$PULSE_ADMIN_USER"
    ui_kv "Zugang" "Passwort/API-Token siehe $PASSWORD_FILE"
    ui_kv "Proxmox" "$([[ "$PULSE_PVE_REGISTERED" -eq 1 ]] && echo automatisch registriert || echo Registrierung prüfen)"
    if (( INSTALL_PBS )); then
        ui_kv "PBS" "$([[ "$PULSE_PBS_REGISTERED" -eq 1 ]] && echo automatisch registriert || echo Registrierung prüfen)"
    fi
    ui_note "API-only ist absichtlich gewählt: kein zusätzlicher Pulse-Agent auf dem PVE-Host."
    ui_note "Agent später nur ergänzen, wenn SMART/Temperaturen/ZFS/Ceph/mdadm aus Pulse benötigt werden."
    ui_section_end
    echo
fi

if (( INSTALL_PBS )); then
    ui_section "PBS · nächster Schritt"
    ui_warn_line "Der 128-GB-LXC ist das PBS-System, nicht dein endgültiger Backup-Datastore."
    ui_note "Webzugriff nativ: https://${PBS_IP}:8007/ · verwaltetes NodeZero-Zertifikat."
    ui_note "NAS/NFS-Datastore anschließend in PBS einrichten."
    ui_section_end
    echo
fi

if (( INSTALL_PVEUPS )); then
    ui_section "PVE-UPS · nächster Schritt"
    ui_note "Webzugriff extern: https://${PVEUPS_IP}/ · HTTP wird auf HTTPS umgeleitet · Backend intern HTTP 8080."
    if (( INSTALL_DASHBOARD )); then
        ui_note "Dashboard-Kurzpfad: https://${DASHBOARD_IP}/usv · Redirect auf die PVE-UPS-Weboberfläche."
    fi
    ui_note "NAS als NUT-Server eintragen · TCP 3493."
    ui_note "Proxmox API-Token konfigurieren."
    ui_note "Zuerst Dry-Run testen, danach ARMED aktivieren."
    ui_section_end
    echo
elif (( PVEUPS_SKIPPED )); then
    ui_section "PVE-UPS"
    ui_warn_line "Installation wurde wegen Community-Scripts-Verfügbarkeitsprüfung übersprungen."
    ui_section_end
    echo
fi

if (( INSTALL_PIHOLE )); then
    ui_section "Pi-hole · DNS"
    ui_note "Wenn der Test erfolgreich ist, kannst du in der Fritz!Box"
    ui_kv "Lokaler DNS" "$PIHOLE_IP"
    ui_section_end
    echo
fi

echo "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${RESET}"
echo "${GREEN}${BOLD}║  ✓  INSTALLER ERFOLGREICH BEENDET                                  ║${RESET}"
echo "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${RESET}"
echo

if (( TUI_AVAILABLE )); then
    tui_msgbox \
        "INSTALLATION ABGESCHLOSSEN" \
        "Alle ausgewählten Installationsschritte wurden beendet.

Passwörter:
${PASSWORD_FILE}

Übersicht:
${OVERVIEW_FILE}

Die verwalteten Weboberflächen nutzen – soweit sinnvoll – HTTPS. HTTP wird auf HTTPS umgeleitet; native Standardports bleiben bei Proxmox/PBS/HA/NPM/Pangolin erhalten."
fi