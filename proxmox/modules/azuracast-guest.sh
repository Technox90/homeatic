#!/usr/bin/env bash
# NodeZero AzuraCast guest bootstrap/maintenance, Ubuntu 22.04 (V145)
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
cd /var/azuracast 2>/dev/null || mkdir -p /var/azuracast
cd /var/azuracast

nfs_verify() {
  timeout 35 ls /mnt/music >/dev/null
  [[ "$(findmnt -rn -T /mnt/music -o SOURCE|tail -1)" == "192.168.178.20:/volume1/music" ]]
  [[ "$(findmnt -rn -T /mnt/music -o FSTYPE|tail -1)" == "nfs4" ]]
}
nfs_prepare() {
  apt-get update -qq
  apt-get install -y -qq curl ca-certificates nfs-common gnupg jq
  mkdir -p /mnt/music /etc/systemd/system/docker.service.d
  if ! awk '$1 !~ /^#/ && $2=="/mnt/music"{f=1} END{exit !f}' /etc/fstab; then
    echo "192.168.178.20:/volume1/music /mnt/music nfs4 rw,vers=4.1,_netdev,nofail,x-systemd.automount,x-systemd.mount-timeout=30s,hard,timeo=600,retrans=2 0 0" >>/etc/fstab
  fi
  cat >/usr/local/sbin/azuracast-check-nfs <<'CHECK'
#!/bin/bash
set -Eeuo pipefail
timeout 35 ls /mnt/music >/dev/null
[[ "$(findmnt -rn -T /mnt/music -o SOURCE|tail -1)" == "192.168.178.20:/volume1/music" ]]
[[ "$(findmnt -rn -T /mnt/music -o FSTYPE|tail -1)" == "nfs4" ]]
CHECK
  chmod 0755 /usr/local/sbin/azuracast-check-nfs
  systemctl daemon-reload
  nfs_verify || { echo "NFS fehlt. Synology muss 192.168.178.110 zulassen." >&2; exit 30; }
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
  cat >/etc/systemd/system/docker.service.d/20-azuracast-nfs.conf <<'UNIT'
[Unit]
RequiresMountsFor=/mnt/music
After=network-online.target remote-fs.target
[Service]
ExecStartPre=/usr/local/sbin/azuracast-check-nfs
UNIT
  systemctl daemon-reload
  systemctl enable --now docker
  systemctl restart docker
  docker compose version
}
install_cast() {
  nfs_verify
  if [[ ! -s docker.sh ]]; then
    curl -fsSL --retry 4 https://raw.githubusercontent.com/AzuraCast/AzuraCast/main/docker.sh -o docker.sh.tmp
    test -s docker.sh.tmp
    mv docker.sh.tmp docker.sh
    chmod 0755 docker.sh
  fi
  # The upstream unattended stable channel selector is supported;
  # do not invent .env bootstrap files from a release branch.
  if [[ ! -s .env ]]; then
    yes 'Y' | ./docker.sh setup-release
  fi
  if [[ -e docker-compose.override.yml ]] && ! grep -q '^# nodezero-v145$' docker-compose.override.yml; then
    echo "Fremdes Override vorhanden, wird nicht ueberschrieben." >&2
    return 34
  fi
  cat >docker-compose.override.yml <<'YAML'
# nodezero-v145
services:
  web:
    volumes:
      - /mnt/music:/var/azuracast/stations/home/media:rw
YAML
  local count
  for count in 1 2 3; do
    # Installer updates its docker.sh and may exit early. Check runtime state.
    set +o pipefail
    yes '' | ./docker.sh install
    local rc=$?
    set -o pipefail
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
/usr/local/sbin/azuracast-check-nfs
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
/usr/local/sbin/azuracast-check-nfs
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
    nfs_prepare
    docker_prepare
    install_cast
    timer_prepare
    ;;
  repair)
    nfs_verify
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
    nfs_verify
    ./docker.sh update-self
    yes '' | ./docker.sh update
    ;;
  *) echo "Unbekannte AzuraCast Aktion $1" >&2; exit 2 ;;
esac
