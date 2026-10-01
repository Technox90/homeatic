#!/usr/bin/env bash
# AzuraCast media/resource configuration (sourced by proxmox.sh).
azura_config_file() { echo /home/Data/proxmox-installer/azuracast-110.conf; }
azura_secret_file() { echo /root/passwort/azuracast-110-smb-credentials; }
azura_load_config() {
  AZURA_CIDR=192.168.178.110/24
  if [[ -r "$(azura_config_file)" ]]; then source "$(azura_config_file)"; fi
  AZURA_IP="$(cut -d/ -f1 <<< "$AZURA_CIDR")"
}
azura_configure_v145() {
  (( INSTALL_AZURACAST )) || return 0
  # Existing AzuraCast installations must keep their original sizing/media
  # configuration. Never rewrite mount credentials or persist a changed IP.
  if qm status 110 >/dev/null 2>&1 || pct status 110 >/dev/null 2>&1; then
    if qm config 110 2>/dev/null | grep -Fxq 'name: azuracast' &&
       [[ -s "$(azura_config_file)" ]]; then
      azura_load_config
      azura_note_v145 "Bestehende VM 110: gespeicherte Konfiguration beibehalten."
      return 0
    fi
    echo "VM/CT-ID 110 bereits belegt oder keine originale AzuraCast-Konfiguration gespeichert." >&2
    return 1
  fi
  header "AZURACAST · RESSOURCEN / MEDIENVERWALTUNG"
  AZURA_CORES="$(get_cpu_cores "AzuraCast CPU-Kerne" 4)"
  AZURA_MEMORY="$(get_ram_mb "AzuraCast RAM in GB" 4)"
  AZURA_DISK="$(get_disk_gb "AzuraCast Systemdisk (GB)" 64 64)"
  AZURA_CIDR="$(get_value "AzuraCast IP/CIDR" 192.168.178.110/24)"
  AZURA_GATEWAY="$(get_value "AzuraCast Gateway" "$GATEWAY")"
  AZURA_DNS="$(get_value "AzuraCast DNS-Server" "$GATEWAY")"
  python3 - "$AZURA_CIDR" "$AZURA_GATEWAY" "$AZURA_DNS" <<'PY'
import ipaddress,sys
assert ipaddress.ip_interface(sys.argv[1]).version == 4
assert ipaddress.ip_address(sys.argv[2]).version == 4
assert ipaddress.ip_address(sys.argv[3]).version == 4
PY
  AZURA_IP="$(cut -d/ -f1 <<< "$AZURA_CIDR")"
  AZURA_MEDIA_TYPE=nfs
  AZURA_MEDIA_SERVER=''
  AZURA_MEDIA_SHARE=''
  AZURA_MEDIA_SUBDIR='.'
  AZURA_MEDIA_MOUNT=/mnt/music
  AZURA_MEDIA_DISK_GB=0
  AZURA_MEDIA_DISK_STORAGE="$DISK_STORAGE"
  AZURA_MEDIA_DISK_NEW=0
  if (( OPTIMAL_INSTALL )); then
    AZURA_MEDIA_TYPE=nfs
  elif (( TUI_AVAILABLE )); then
    AZURA_MEDIA_TYPE="$(whiptail --backtitle "$TUI_BACKTITLE" \
        --title "AZURACAST · MUSIKSPEICHER" \
        --menu "Wo befindet sich deine Musikbibliothek?" 19 96 6 \
        nfs "NAS · NFS-Freigabe (Synology/Linux)" \
        smb "Netzwerk · SMB/CIFS (NAS/Windows)" \
        local "Lokal · Systemdisk der VM" \
        disk "Extra-Disk · virtuelles Medium auf Proxmox-Storage" \
        3>&1 1>&2 2>&3)" || return 1
  else
    AZURA_MEDIA_TYPE="$(get_value_interactive "Musikspeicher (nfs/smb/local/disk)" nfs)"
  fi
  setup_profile_capture_value_v64 "AzuraCast Musikspeicher" "$AZURA_MEDIA_TYPE"
  case "$AZURA_MEDIA_TYPE" in
    nfs)
      AZURA_MEDIA_SERVER="$(get_value "AzuraCast NFS-Server (IP/Name)" 192.168.178.20)"
      AZURA_MEDIA_SHARE="$(get_value "AzuraCast NFS-Exportpfad" /volume1/music)"
      AZURA_MEDIA_MOUNT="$(get_value "AzuraCast Mountpunkt in VM" /mnt/music)"
      AZURA_MEDIA_SUBDIR="$(get_value "AzuraCast Unterordner (Punkt = alle)" .)"
      [[ "$AZURA_MEDIA_SHARE" == /* ]] || return 1 ;;
    smb)
      AZURA_MEDIA_SERVER="$(get_value "AzuraCast SMB-Server (IP/Name)" 192.168.178.20)"
      AZURA_MEDIA_SHARE="$(get_value "AzuraCast SMB-Freigabe" music)"
      AZURA_MEDIA_MOUNT="$(get_value "AzuraCast Mountpunkt in VM" /mnt/music)"
      AZURA_MEDIA_SUBDIR="$(get_value "AzuraCast Unterordner (Punkt = alle)" .)"
      local user pass domain secret
      user="$(get_value "AzuraCast SMB-Benutzer" azuracast)"
      domain="$(get_value "AzuraCast SMB-Domaene (optional)" "")"
      if (( TUI_AVAILABLE )); then
        pass="$(whiptail --title "AZURACAST SMB" \
            --passwordbox "SMB-Passwort (wird nicht protokolliert)" 12 86 \
            3>&1 1>&2 2>&3)" || return 1
      else
        read -r -s -p "SMB-Passwort: " pass
        echo >&2
      fi
      [[ -n "$pass" && "$pass" != *$'\n'* &&
         "$user" != *$'\n'* && "$domain" != *$'\n'* ]] || return 1
      secret="$(azura_secret_file)"
      mkdir -p /root/passwort /home/passwort
      (umask 077; printf 'username=%s\npassword=%s\n' "$user" "$pass"
       [[ -z "$domain" ]] || printf 'domain=%s\n' "$domain") > "$secret"
      chmod 600 "$secret"
      cp -f "$secret" "/home/passwort/$(basename "$secret")"
      chmod 600 "/home/passwort/$(basename "$secret")"
      unset pass
      [[ "$AZURA_MEDIA_SHARE" =~ ^[A-Za-z0-9._-]+$ ]] || return 1 ;;
    local)
      AZURA_MEDIA_MOUNT=/var/azuracast/stations/home/media ;;
    disk)
      AZURA_MEDIA_MOUNT="$(get_value "AzuraCast zweite Disk Mountpunkt" /mnt/music)"
      AZURA_MEDIA_DISK_GB="$(get_disk_gb "AzuraCast Musik-Disk GB" 500 100)"
      AZURA_MEDIA_DISK_STORAGE="$(get_value "AzuraCast Musik-Disk Storage" "$DISK_STORAGE")"
      pvesm status --content images | awk -v s="$AZURA_MEDIA_DISK_STORAGE" \
        'NR>1&&$1==s&&$3=="active"{ok=1}END{exit !ok}' || return 1
      AZURA_MEDIA_DISK_NEW=1 ;;
    *) return 1 ;;
  esac
  if [[ "$AZURA_MEDIA_TYPE" != local ]]; then
    [[ "$AZURA_MEDIA_MOUNT" == /mnt/* &&
      "$AZURA_MEDIA_MOUNT" != *..* &&
      "$AZURA_MEDIA_MOUNT" != *:* &&
      "$AZURA_MEDIA_MOUNT" != *' '* ]] || return 1
    [[ "$AZURA_MEDIA_SUBDIR" != /* &&
      "$AZURA_MEDIA_SUBDIR" != *..* &&
      "$AZURA_MEDIA_SUBDIR" != *:* &&
      "$AZURA_MEDIA_SUBDIR" != *'#'* ]] || return 1
    if [[ "$AZURA_MEDIA_TYPE" == nfs || "$AZURA_MEDIA_TYPE" == smb ]]; then
      [[ "$AZURA_MEDIA_SERVER" =~ ^[A-Za-z0-9.-]+$ &&
         "$AZURA_MEDIA_SHARE" != *..* &&
         "$AZURA_MEDIA_SHARE" != *'#'* &&
         "$AZURA_MEDIA_SHARE" != *' '* ]] || return 1
    fi
  fi
  local config key
  config="$(azura_config_file)"
  install -d -m 0700 "$(dirname "$config")"
  (umask 077; for key in AZURA_CORES AZURA_MEMORY AZURA_DISK AZURA_CIDR \
      AZURA_GATEWAY AZURA_DNS AZURA_MEDIA_TYPE AZURA_MEDIA_MOUNT \
      AZURA_MEDIA_SERVER AZURA_MEDIA_SHARE AZURA_MEDIA_SUBDIR \
      AZURA_MEDIA_DISK_GB AZURA_MEDIA_DISK_STORAGE AZURA_MEDIA_DISK_NEW; do
      declare -n ref="$key"
      printf '%s=%q\n' "$key" "$ref"
    done) > "$config.tmp"
  mv -f "$config.tmp" "$config"
  chmod 600 "$config"
  azura_note_v145 "VM: $AZURA_CORES CPU, $AZURA_MEMORY MB RAM, $AZURA_DISK GB, IP $AZURA_CIDR"
  azura_note_v145 "Musik: $AZURA_MEDIA_TYPE · $AZURA_MEDIA_MOUNT"
}

azura_send_media_config_v145() {
  azura_load_config
  azura_ssh_v145 'sudo install -d -m 0700 /etc/nodezero' || return 1
  (local key
   for key in AZURA_MEDIA_TYPE AZURA_MEDIA_MOUNT AZURA_MEDIA_SERVER \
       AZURA_MEDIA_SHARE AZURA_MEDIA_SUBDIR AZURA_MEDIA_DISK_NEW; do
     declare -n ref="$key"
     printf '%s=%q\n' "$key" "$ref"
   done
  ) | azura_ssh_v145 'sudo tee /etc/nodezero/azuracast-media.conf >/dev/null && sudo chmod 600 /etc/nodezero/azuracast-media.conf' ||
       return 1
  if [[ "$AZURA_MEDIA_TYPE" == smb ]]; then
    [[ -s "$(azura_secret_file)" ]] || return 1
    azura_ssh_v145 'sudo tee /etc/nodezero/azuracast-smb.credentials >/dev/null && sudo chmod 600 /etc/nodezero/azuracast-smb.credentials' <"$(azura_secret_file)" ||
        return 1
  fi
}
