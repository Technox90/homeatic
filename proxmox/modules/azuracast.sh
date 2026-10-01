#!/usr/bin/env bash
# NodeZero V145 - AzuraCast Proxmox VM lifecycle.
# Sourced by the existing Proxmox master installer.
azura_error_v145() { printf 'AZURACAST FEHLER: %s\n' "$*" >&2; return 1; }
azura_note_v145() { printf 'AZURACAST: %s\n' "$*"; }
azura_check_id_v145() {
  if pct status 110 >/dev/null 2>&1; then
    azura_error_v145 "CT 110 existiert bereits. Kein Ueberschreiben."
    return 1
  fi
  if qm status 110 >/dev/null 2>&1; then
    qm config 110 | grep -Fxq 'name: azuracast' ||
       { azura_error_v145 "VM 110 ist bereits anderweitig belegt"; return 1; }
    return 2
  fi
  return 0
}
azura_cloud_image_v145() {
  local url="https://cloud-images.ubuntu.com/releases/server/jammy/release"
  local img="/home/img/os/ubuntu-22.04-server-cloudimg-amd64.img"
  local sums="/home/img/os/azuracast-SHA256SUMS"
  local expected
  install -d -m 0755 /home/img/os
  curl -fsSL --retry 3 "$url/SHA256SUMS" -o "$sums" || return 1
  expected="$(awk '$2=="ubuntu-22.04-server-cloudimg-amd64.img" || $2=="*ubuntu-22.04-server-cloudimg-amd64.img"{print $1;exit}' "$sums")"
  [[ "$expected" =~ ^[0-9a-fA-F]{64}$ ]] ||
      { azura_error_v145 "Ubuntu-SHA256SUMS ungueltig"; return 1; }
  if [[ ! -s "$img" ]] || [[ "$(sha256sum "$img"|awk '{print $1}')" != "$expected" ]]; then
    rm -f "$img.part"
    curl -fSL --retry 4 --retry-delay 4 \
       "$url/ubuntu-22.04-server-cloudimg-amd64.img" -o "$img.part" || return 1
    echo "$expected  $img.part" | sha256sum -c - || return 1
    mv -f "$img.part" "$img"
  fi
  echo "$expected  $img" | sha256sum -c - >/dev/null
}
azura_ssh_v145() {
  ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
   -o ConnectTimeout=10 -i /root/passwort/azuracast-110-ed25519 \
   azura@192.168.178.110 "$@"
}
azura_wait_v145() {
  local attempt
  for attempt in $(seq 1 90); do
    if qm guest ping 110 >/dev/null 2>&1 &&
       azura_ssh_v145 'cloud-init status --wait >/dev/null 2>&1' 2>/dev/null; then
      return 0
    fi
    sleep 10
  done
  azura_error_v145 "SSH/Cloud-Init nach 15 Minuten nicht verfuegbar"
}
azura_create_vm_v145() {
  local key="/root/passwort/azuracast-110-ed25519"
  local pub
  local unused
  install -d -m 0700 /root/passwort /home/passwort
  install -d -m 0755 /home/img/snippets
  azura_cloud_image_v145 || return 1
  if [[ ! -s "$key" ]]; then
    ssh-keygen -q -t ed25519 -N '' -f "$key" -C 'azuracast-110'
    chmod 0600 "$key"
  fi
  cp -an "$key" "$key.pub" /home/passwort/
  pub="$(cat "$key.pub")"
  cat >/home/img/snippets/azuracast-110-user.yaml <<EOF
#cloud-config
hostname: azuracast
timezone: Europe/Berlin
ssh_pwauth: false
disable_root: true
users:
  - name: azura
    groups: [sudo, adm]
    shell: /bin/bash
    lock_passwd: true
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - "$pub"
package_update: true
package_upgrade: true
packages: [qemu-guest-agent, openssh-server, curl, nfs-common, ca-certificates, gnupg, jq]
runcmd:
  - [ systemctl, enable, --now, qemu-guest-agent ]
  - [ systemctl, enable, --now, ssh ]
EOF
  chmod 0600 /home/img/snippets/azuracast-110-user.yaml
  qm create 110 --name azuracast --ostype l26 --machine q35 --cpu host \
    --cores 4 --memory 4096 --balloon 0 --scsihw virtio-scsi-single \
    --net0 "virtio,bridge=$BRIDGE" --agent enabled=1 \
    --serial0 socket --vga serial0 --onboot 1
  qm disk import 110 /home/img/os/ubuntu-22.04-server-cloudimg-amd64.img "$DISK_STORAGE" || return 1
  unused="$(qm config 110|awk -F': ' '/^unused0:/{print $2;exit}')"
  [[ -n "$unused" ]] || return 1
  qm set 110 --scsi0 "$unused,discard=on,ssd=1,iothread=1"
  qm resize 110 scsi0 64G
  qm set 110 --ide2 "$DISK_STORAGE:cloudinit" \
    --cicustom 'user=image-cache:snippets/azuracast-110-user.yaml' \
    --ipconfig0 "ip=192.168.178.110/24,gw=$GATEWAY" \
    --nameserver 192.168.178.1 --boot 'order=scsi0'
  qm start 110
}
azura_guest_tool_v145() {
  # Source is pinned to an immutable repo commit, not live main.
  local ref="$AZURACAST_MODULE_REF"
  local root="/home/downloads/nodezero/modules/$ref"
  local tool="$root/azuracast-guest.sh"
  install -d -m 0700 "$root"
  if [[ ! -s "$tool" ]]; then
    curl -fsSL --retry 3 \
      "https://raw.githubusercontent.com/Technox90/homeatic/$ref/proxmox/modules/azuracast-guest.sh" \
      -o "$tool.tmp" || return 1
    mv -f "$tool.tmp" "$tool"
  fi
  bash -n "$tool" || return 1
  azura_ssh_v145 'cat > /tmp/azuracast-guest.sh' < "$tool" || return 1
  azura_ssh_v145 'sudo install -m 0755 /tmp/azuracast-guest.sh /usr/local/sbin/azuracast-nodezero && rm /tmp/azuracast-guest.sh'
}
azura_action_v145() {
  qm config 110 2>/dev/null | grep -Fxq 'name: azuracast' ||
    { azura_error_v145 "Keine verifizierte AzuraCast-VM 110"; return 1; }
  azura_ssh_v145 "sudo /usr/local/sbin/azuracast-nodezero $1"
}
install_azuracast_v145() {
  local check=0
  azura_check_id_v145 || check=$?
  if [[ "$check" -eq 2 ]]; then
    azura_note_v145 "VM 110 existiert bereits; nicht neu installieren."
    azura_note_v145 "Status/Reparatur ueber EXTRAS-Wartungsmenue."
    return 0
  fi
  [[ "$check" -eq 0 ]] || return 1
  install -d -m 0700 /home/log/azuracast
  azura_create_vm_v145 || return 1
  azura_wait_v145 || return 1
  azura_guest_tool_v145 || return 1
  azura_action_v145 install > >(tee -a /home/log/azuracast/install.log) \
     2> >(tee -a /home/log/azuracast/error.log >&2) || return 1
  azura_note_v145 "Basis-VM, Docker, NAS, Timer bereit unter http://192.168.178.110"
  azura_note_v145 "Admin-Initialisierung und Playlist-Mapping werden erst nach gueltigen API-Rechten/Schemacheck freigegeben."
}
azuracast_menu_v145() {
  local selection
  while :; do
    if command -v whiptail >/dev/null && [[ -t 0 ]]; then
      selection="$(whiptail --backtitle "$TUI_BACKTITLE" \
       --title 'EXTRAS · AZURACAST' --menu 'VM 110' 21 90 11 \
       1 'Status' 2 'NAS-Mount pruefen' 3 'Medien importieren' \
       4 'Playlist synchronisieren' 5 'Timer aktivieren' \
       6 'Timer deaktivieren' 7 'Update' 8 'Reparatur' \
       9 'Logs' 10 'Unterbrochene Installation fortsetzen' \
       Z 'Zurueck' 3>&1 1>&2 2>&3)" || return 0
    else
      printf >&2 '\nAZURACAST: 1 Status 2 NAS 3 Import 4 Playlist 5 Timer AN 6 AUS 7 Update 8 Reparatur 9 Logs 10 Fortsetzen Z Zurueck\nAuswahl: '
      read -r selection || return 0
    fi
    case "$selection" in
      1) azura_action_v145 status || true ;;
      2) azura_action_v145 mount || true ;;
      3) azura_action_v145 import || true ;;
      4) azura_action_v145 playlist || true ;;
      5) azura_action_v145 timer-on || true ;;
      6) azura_action_v145 timer-off || true ;;
      7) azura_action_v145 update || true ;;
      8) azura_action_v145 repair || true ;;
      9) azura_action_v145 logs || true ;;
      10) azura_wait_v145 && azura_guest_tool_v145 && azura_action_v145 install || true ;;
      Z|z) return 0 ;;
      *) echo 'Ungueltige Auswahl.' ;;
    esac
  done
}
