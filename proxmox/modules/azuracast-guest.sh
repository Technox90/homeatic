#!/usr/bin/env bash
# NodeZero AzuraCast guest bootstrap/maintenance, Ubuntu 22.04 (V145)
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
cd /var/azuracast 2>/dev/null || mkdir -p /var/azuracast
cd /var/azuracast

# Host-side installer sends root-only sanitized Bash variables here.
[[ -r /etc/nodezero/azuracast-media.conf ]] || {
  echo "AzuraCast media config missing" >&2; exit 25;
}
source /etc/nodezero/azuracast-media.conf
: "$AZURA_MEDIA_TYPE" "$AZURA_MEDIA_MOUNT"
media_guard() {
  case "$AZURA_MEDIA_TYPE" in
    local)
      [[ -d /var/azuracast/stations/home/media ]] ||
          mkdir -p /var/azuracast/stations/home/media
      ;;
    nfs|smb|disk)
      timeout 35 ls "$AZURA_MEDIA_MOUNT" >/dev/null || return 1
      local source fstype
      source="$(findmnt -rn -T "$AZURA_MEDIA_MOUNT" -o SOURCE|tail -1)"
      fstype="$(findmnt -rn -T "$AZURA_MEDIA_MOUNT" -o FSTYPE|tail -1)"
      case "$AZURA_MEDIA_TYPE" in
        nfs) [[ "$fstype" == nfs4 &&
               "$source" == "$AZURA_MEDIA_SERVER:$AZURA_MEDIA_SHARE" ]] ;;
        smb) [[ "$fstype" == cifs &&
               "$source" == "//$AZURA_MEDIA_SERVER/$AZURA_MEDIA_SHARE" ]] ;;
        disk)
          [[ "$fstype" == ext4 && -s /etc/nodezero/azuracast-disk-uuid ]] || return 1
          [[ "$(blkid -o value -s UUID /dev/sdb)" == "$(cat /etc/nodezero/azuracast-disk-uuid)" ]] ;;
      esac
      ;;
    *) echo "Invalid media type: $AZURA_MEDIA_TYPE" >&2; return 1 ;;
  esac
}
media_prepare() {
  apt-get update -qq
  apt-get install -y -qq curl ca-certificates nfs-common cifs-utils gnupg jq
  mkdir -p /etc/nodezero /etc/systemd/system/docker.service.d
  if [[ "$AZURA_MEDIA_TYPE" == local ]]; then
    mkdir -p /var/azuracast/stations/home/media
    return 0
  fi
  [[ "$AZURA_MEDIA_MOUNT" == /mnt/* && "$AZURA_MEDIA_MOUNT" != *..* &&
    "$AZURA_MEDIA_MOUNT" != *' '* ]] || {
    echo "Invalid VM media mountpoint" >&2; return 30;
  }
  mkdir -p "$AZURA_MEDIA_MOUNT"
  local entry='' existing=''
  existing="$(awk -v p="$AZURA_MEDIA_MOUNT" '$1 !~ /^#/ && $2==p{print;exit}' /etc/fstab)"
  case "$AZURA_MEDIA_TYPE" in
    nfs)
      entry="$AZURA_MEDIA_SERVER:$AZURA_MEDIA_SHARE $AZURA_MEDIA_MOUNT nfs4 rw,vers=4.1,_netdev,nofail,x-systemd.automount,x-systemd.mount-timeout=30s,hard,timeo=600,retrans=2 0 0"
      ;;
    smb)
      [[ -s /etc/nodezero/azuracast-smb.credentials ]] ||
        { echo "SMB credentials missing" >&2; return 31; }
      chmod 600 /etc/nodezero/azuracast-smb.credentials
      entry="//$AZURA_MEDIA_SERVER/$AZURA_MEDIA_SHARE $AZURA_MEDIA_MOUNT cifs rw,credentials=/etc/nodezero/azuracast-smb.credentials,vers=3.0,uid=1000,gid=1000,_netdev,nofail,x-systemd.automount,x-systemd.mount-timeout=30s 0 0"
      ;;
    disk)
      [[ -b /dev/sdb ]] ||
        { echo "Dedicated SCSI1 media disk not present" >&2; return 31; }
      [[ "$(findmnt -n -o SOURCE /)" != /dev/sdb* ]] ||
        { echo "Refusing to use the root filesystem disk" >&2; return 31; }
      if ! blkid -s UUID -o value /dev/sdb >/dev/null 2>&1; then
        [[ "$AZURA_MEDIA_DISK_NEW" == 1 &&
           ! -e /etc/nodezero/azuracast-disk-uuid ]] ||
          { echo "Blank disk is not an authorized new media disk" >&2; return 32; }
        [[ "$(lsblk -nr -o NAME /dev/sdb|wc -l)" -eq 1 ]] ||
          { echo "Media disk contains partitions; no formatting" >&2; return 32; }
        mkfs.ext4 -F -L AZURACAST_MEDIA /dev/sdb
      fi
      local uuid
      uuid="$(blkid -s UUID -o value /dev/sdb)"
      [[ -n "$uuid" ]] || return 32
      if [[ -s /etc/nodezero/azuracast-disk-uuid ]]; then
        [[ "$uuid" == "$(cat /etc/nodezero/azuracast-disk-uuid)" ]] ||
          { echo "Media disk UUID mismatch" >&2; return 32; }
      else
        echo "$uuid" >/etc/nodezero/azuracast-disk-uuid
      fi
      entry="UUID=$uuid $AZURA_MEDIA_MOUNT ext4 defaults,nofail,x-systemd.device-timeout=30s 0 2"
      ;;
    *) return 33 ;;
  esac
  if [[ -n "$existing" && "$existing" != "$entry" ]]; then
    echo "Existing non-matching /etc/fstab entry; refusing overwrite" >&2
    return 34
  fi
  [[ -n "$existing" ]] || printf '%s\n' "$entry" >>/etc/fstab
  cat >/usr/local/sbin/azuracast-check-media <<'CHECK'
#!/bin/bash
set -Eeuo pipefail
source /etc/nodezero/azuracast-media.conf
timeout 35 ls "$AZURA_MEDIA_MOUNT" >/dev/null
source="$(findmnt -rn -T "$AZURA_MEDIA_MOUNT" -o SOURCE | tail -1)"
fs="$(findmnt -rn -T "$AZURA_MEDIA_MOUNT" -o FSTYPE | tail -1)"
case "$AZURA_MEDIA_TYPE" in
 nfs) [[ "$fs" == nfs4 && "$source" == "$AZURA_MEDIA_SERVER:$AZURA_MEDIA_SHARE" ]] ;;
 smb) [[ "$fs" == cifs && "$source" == "//$AZURA_MEDIA_SERVER/$AZURA_MEDIA_SHARE" ]] ;;
 disk) [[ "$fs" == ext4 && "$source" == /dev/sdb* ||
          "$fs" == ext4 && "$source" == UUID=* ]] ;;
 *) exit 1 ;;
esac
CHECK
  chmod 0755 /usr/local/sbin/azuracast-check-media
  systemctl daemon-reload
  if [[ "$AZURA_MEDIA_TYPE" == disk ]]; then
    mount "$AZURA_MEDIA_MOUNT" || return 34
  fi
  media_guard || {
    echo "Media storage not mounted; stop before Docker writes" >&2; return 35;
  }
  [[ "$AZURA_MEDIA_SUBDIR" == . ]] ||
    [[ -d "$AZURA_MEDIA_MOUNT/$AZURA_MEDIA_SUBDIR" ]] || {
      echo "Media subdirectory missing; no remote directories created" >&2
      return 35
    }
}
docker_prepare() {
  install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  . /etc/os-release
  printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu %s stable\n' \
    "$(dpkg --print-architecture)" "$VERSION_CODENAME" >/etc/apt/sources.list.d/docker.list
  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
  if [[ "$AZURA_MEDIA_TYPE" != local ]]; then
    cat >/etc/systemd/system/docker.service.d/20-azuracast-media.conf <<UNIT
[Unit]
RequiresMountsFor=$AZURA_MEDIA_MOUNT
After=network-online.target remote-fs.target
[Service]
ExecStartPre=/usr/local/sbin/azuracast-check-media
UNIT
  fi
  systemctl daemon-reload
  systemctl enable --now docker
  systemctl restart docker
  docker compose version
}
install_cast() {
  media_guard
  if [[ ! -s docker.sh ]]; then
    curl -fsSL --retry 4 https://raw.githubusercontent.com/AzuraCast/AzuraCast/main/docker.sh -o docker.sh.tmp
    test -s docker.sh.tmp
    mv docker.sh.tmp docker.sh
    chmod 0755 docker.sh
  fi
  # The upstream unattended stable channel selector is supported;
  # do not invent .env bootstrap files from a release branch.
  if [[ ! -s .env ]]; then
    # Supported unattended Stable-channel selection. Avoid yes/SIGPIPE
    # masking the upstream tool's actual exit code.
    local release_rc=0
    yes 'Y' | ./docker.sh setup-release || release_rc="${PIPESTATUS[1]}"
    [[ "$release_rc" -eq 0 ]] ||
      { echo "Stable-Kanal Auswahl fehlgeschlagen (RC=$release_rc)" >&2; return 36; }
  fi
  if [[ -e docker-compose.override.yml ]] && ! grep -q '^# nodezero-v145$' docker-compose.override.yml; then
    echo "Fremdes Override vorhanden, wird nicht ueberschrieben." >&2
    return 34
  fi
  if [[ "$AZURA_MEDIA_TYPE" != local ]]; then
    local media_source="$AZURA_MEDIA_MOUNT"
    if [[ "$AZURA_MEDIA_SUBDIR" != . ]]; then
      media_source="$AZURA_MEDIA_MOUNT/$AZURA_MEDIA_SUBDIR"
    fi
    # Avoid writing into a missing, unmounted or empty local directory.
    media_guard || return 34
    cat >docker-compose.override.yml <<YAML
# nodezero-v145
services:
  web:
    volumes:
      - $media_source:/var/azuracast/stations/home/media:rw
YAML
  fi
  local count
  for count in 1 2 3; do
    # Installer updates its docker.sh and may exit early. Check runtime state.
    local rc=0
    yes '' | ./docker.sh install || rc="${PIPESTATUS[1]}"
    if docker compose ps --status running --services | grep -Fxq web; then break; fi
    [[ $count -lt 3 ]] || { echo "AzuraCast-Install fehlgeschlagen ($rc)"; return 35; }
    sleep 10
  done
  docker compose config -q
}
timer_prepare() {
  mkdir -p /home/log/azuracast
  cat >/usr/local/sbin/azuracast-default-sync.sh <<'SYNC'
#!/bin/bash
set -Eeuo pipefail
exec 9>/run/azuracast-default-sync.lock
flock -n 9 || exit 0
/usr/local/sbin/azuracast-check-media
cd /var/azuracast
./docker.sh cli sync:run medium >>/home/log/azuracast/default-sync.log 2>&1
if [[ ! -s stations/home/playlists/playlist_default.m3u ]]; then
 echo "[$(date -Is)] WARN: default playlist M3U not populated" >>/home/log/azuracast/default-sync.log
fi
SYNC
  cat >/usr/local/sbin/azuracast-media-check.sh <<'SYNC'
#!/bin/bash
set -Eeuo pipefail
exec 9>/run/azuracast-media-check.lock
flock -n 9 || exit 0
/usr/local/sbin/azuracast-check-media
cd /var/azuracast
./docker.sh cli azuracast:sync:task check_media --force >>/home/log/azuracast/media-check.log 2>&1
SYNC
  chmod 0755 /usr/local/sbin/azuracast-{default-sync,media-check}.sh
  cat >/etc/systemd/system/azuracast-default-sync.service <<'UNIT'
[Unit]
Description=AzuraCast playlist synchronization
Requires=docker.service
After=docker.service
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/azuracast-default-sync.sh
UNIT
  cat >/etc/systemd/system/azuracast-default-sync.timer <<'UNIT'
[Unit]
Description=AzuraCast playlist synchronization every five minutes
[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
Persistent=true
[Install]
WantedBy=timers.target
UNIT
  cat >/etc/systemd/system/azuracast-media-check.service <<'UNIT'
[Unit]
Description=AzuraCast NAS media rescan
Requires=docker.service
After=docker.service
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/azuracast-media-check.sh
UNIT
  cat >/etc/systemd/system/azuracast-media-check.timer <<'UNIT'
[Unit]
Description=Hourly NAS music rescan
[Timer]
OnBootSec=10min
OnCalendar=hourly
Persistent=true
[Install]
WantedBy=timers.target
UNIT
  systemctl daemon-reload
  systemctl enable --now azuracast-default-sync.timer azuracast-media-check.timer
}
case "$1" in
  install)
    media_prepare
    docker_prepare
    install_cast
    timer_prepare
    ;;
  repair)
    media_guard
    docker compose config -q
    docker compose up -d
    timer_prepare
    ;;
  status)
    nfs_verify && findmnt -T /mnt/music
    docker compose ps
    systemctl list-timers --all 'azuracast-*'
    ;;
  mount) nfs_verify && findmnt -T /mnt/music ;;
  import) /usr/local/sbin/azuracast-media-check.sh ;;
  playlist) /usr/local/sbin/azuracast-default-sync.sh ;;
  timer-on) systemctl enable --now azuracast-default-sync.timer ;;
  timer-off) systemctl disable --now azuracast-default-sync.timer ;;
  logs) docker compose logs --tail=120 web ;;
  update)
    media_guard
    ./docker.sh update-self
    rc=0
    yes '' | ./docker.sh update || rc="${PIPESTATUS[1]}"
    exit "$rc"
    ;;
  *) echo "Unbekannte AzuraCast Aktion $1" >&2; exit 2 ;;
esac
