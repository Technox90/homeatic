#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${ROOT}/proxmox/tools/proxmox-auto-updater"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Only load isolated functions; never run the updater itself in CI.
for fn in short_list pushover_prepare_message manual_notification_due mark_manual_notification_sent build_summary send_summary update_proxmox_host update_ct_apt; do
    source <(sed -n "/^${fn}() {/,/^}/p" "$SCRIPT")
done
STATE_DIR="$TMP/state"
LOG_DIR="$TMP/log"
SUMMARYFILE="$LOG_DIR/summary.txt"
LOGFILE="$LOG_DIR/run.txt"
mkdir -p "$STATE_DIR" "$LOG_DIR"
UPDATED_ITEMS=()
MANUAL_ITEMS=()
FAILED_ITEMS=()

[[ "$(short_list $'vim\ngit')" == "2 Pakete (vim, git)" ]]
long="$(printf 'Änderung 😃\n%.0s' {1..200})"
message="$(pushover_prepare_message "$long" "$LOG_DIR/summary.txt")"
(( $(LC_ALL=C printf '%s' "$message" | wc -c) <= 1000 ))
[[ "$message" == *"$LOG_DIR/summary.txt" ]]
[[ "$(pushover_prepare_message "kurz" /tmp/report)" == "kurz" ]]

# A warning is only throttled after successful delivery, not on first attempt.
manual_notification_due "Kernel-Neustart"
[[ ! -e "$STATE_DIR/manual-warning.sha256" ]]
mark_manual_notification_sent "Kernel-Neustart"
if manual_notification_due "Kernel-Neustart"; then exit 1; fi
manual_notification_due "Andere Warnung"

# Verify failure notifications are high-priority and are not mistaken for manual warnings.
pushover_send() { printf '%s|%s\n' "$1" "$3" >> "$TMP/pushover.txt"; return 0; }
UPDATED_ITEMS=("vim-tiny aktualisiert")
FAILED_ITEMS=("Docker fehlgeschlagen")
MANUAL_ITEMS=()
send_summary
grep -q "Fehler (prüfen):" "$SUMMARYFILE"
grep -q "Proxmox Update-Fehler|1" "$TMP/pushover.txt"
if grep -q "Proxmox: Eingreifen noetig" "$TMP/pushover.txt"; then exit 1; fi

# A failed Pushover request must not suppress the next notification attempt.
rm -f "$STATE_DIR/manual-warning.sha256"
pushover_send() { return 1; }
UPDATED_ITEMS=()
FAILED_ITEMS=()
MANUAL_ITEMS=("Neustart erforderlich")
send_summary
[[ ! -e "$STATE_DIR/manual-warning.sha256" ]]

# Mock APT: an automatic dist-upgrade must not remove Proxmox packages.
apt-get() {
    case "$1:${2:-}" in
        update:*) return 0 ;;
        -s:dist-upgrade) printf '%s\n' 'Remv proxmox-ve [9.0]' 'Inst zlib1g [1] (2 Debian:13)' ;;
        -y:dist-upgrade) touch "$TMP/unsafe-host" ;;
    esac
}
add_manual() { MANUAL_ITEMS+=("$1"); }
MANUAL_ITEMS=()
update_proxmox_host
[[ ! -e "$TMP/unsafe-host" ]]
(( ${#MANUAL_ITEMS[@]} == 1 ))

# Mock LXC package operations and reject removals there as well.
pct() {
    if [[ "$1" == exec && "$4" == apt-get && "${5:-}" == -s ]]; then
        echo "Remv libc6 [2]"
    elif [[ "$1" == exec && "$4" == bash ]]; then
        return 0
    else
        touch "$TMP/unsafe-lxc"
    fi
}
MANUAL_ITEMS=()
update_ct_apt 123 Test
[[ ! -e "$TMP/unsafe-lxc" ]]
(( ${#MANUAL_ITEMS[@]} == 1 ))

echo "Proxmox updater offline tests: OK"
