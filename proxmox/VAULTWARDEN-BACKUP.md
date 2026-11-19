# Vaultwarden – optionale verschlüsselte Backups auf Root-Server

Diese Anleitung gehört zum bestehenden Proxmox-Installer in `proxmox/proxmox.sh`. Sie gilt nur, wenn beim Einrichten von Vaultwarden die **optionale Backup-Funktion** aktiviert wird. Ohne diese Auswahl wird Vaultwarden normal installiert.

## 1. Root-Server vorbereiten

Auf **jedem** Backup-Root-Server als root (Debian/Ubuntu) einen eingeschränkten Benutzer und ein Verzeichnis anlegen. Beispiel:

```bash
adduser --disabled-password --gecos "" vwbackup
install -d -o vwbackup -g vwbackup -m 700 /srv/vaultwarden-backups
install -d -o vwbackup -g vwbackup -m 700 /home/vwbackup/.ssh
touch /home/vwbackup/.ssh/authorized_keys
chown vwbackup:vwbackup /home/vwbackup/.ssh/authorized_keys
chmod 600 /home/vwbackup/.ssh/authorized_keys
```

Der Backup-Benutzer benötigt **kein sudo** und keinen root-Zugriff. Auf Firewall-Ebene SSH (Port 22, oder angepasster Port) möglichst nur von der ausgehenden IP des Proxmox-Netzes erlauben. Die Root-Server müssen vom LXC per SSH erreichbar sein.

## 2. Vaultwarden im Proxmox-Installer auswählen

Im Apps-Menü Vaultwarden wählen. Der Installer fragt nach **optionalen Offsite-Backups** und zeigt diese Anleitung. Bei Zustimmung werden die üblichen Vaultwarden-Parameter (CT-ID, IP, CPU, RAM, Disk) weiter abgefragt. Anschließend werden die Backup-Ziele im Format

```text
vwbackup@backup1.example.net:/srv/vaultwarden-backups
```

eingegeben. Optional mehrere Ziele durch Kommas trennen, beispielsweise:

```text
vwbackup@backup1.example.net:/srv/vaultwarden-backups,vwbackup@backup2.example.net:/srv/vaultwarden-backups
```

**Keine Passwörter oder geheimen Schlüssel in GitHub eintragen.**

## 3. SSH-Schlüssel hinterlegen

Während der Installation generiert der Installer **im Vaultwarden-LXC** ein separates SSH-Schlüsselpaar und zeigt den öffentlichen Schlüssel an. Diesen auf **jedem** Backup-Root-Server in `/home/vwbackup/.ssh/authorized_keys` als eigene Zeile einfügen. Danach die angezeigte Eingabeaufforderung bestätigen. Der Installer prüft die Verbindung und erstellt auf jedem Ziel ein mit restic verschlüsseltes Repository.

SSH-Hostschlüssel werden angezeigt und müssen **gegen eine unabhängig bekannte Fingerprint-Angabe geprüft** werden. Niemals unüberprüft einen unbekannten Hostschlüssel bestätigen.

## 4. Verschlüsselung, Zeitplan und Wiederherstellung

- Der Backupjob läuft über einen systemd-Timer **alle 15 Minuten**.
- Restic verschlüsselt die Snapshots bereits im LXC, bevor sie auf den Root-Server übertragen werden.
- Es werden konsistente SQLite-Backups sowie weitere Vaultwarden-Dateien gesichert.
- Der Restic-Schlüssel liegt nur lokal im LXC unter `/etc/vaultwarden-backup-restic-password`. **Separat offline sichern!** Ohne diesen Schlüssel ist eine Wiederherstellung unmöglich.
- Der SSH-Schlüssel liegt unter `/etc/vaultwarden-backup-ssh`.
- Einstellungen unter `/etc/vaultwarden-backup.conf`.
- Der Backup-Lauf wird mit `systemctl status vaultwarden-backup.timer` und `journalctl -u vaultwarden-backup.service -n 50` kontrolliert.

Ein erster manueller Test:

```bash
systemctl start vaultwarden-backup.service
journalctl -u vaultwarden-backup.service -n 50 --no-pager
```

Zur Wiederherstellung erst Vaultwarden auf einem **separaten Testsystem stoppen**, mit dem gleichen Restic-Passwort und SSH-Schlüssel `restic -r sftp:USER@HOST:/PFAD snapshots` und `restic restore latest --target /tmp/vw-restore` ausführen. Danach die Daten aus `data/` kontrolliert in das persistente Vaultwarden-Datenvolume übertragen und Container neu starten. **Niemals ungeprüft über ein laufendes Produktivsystem wiederherstellen.** Regelmäßige Test-Restores sind Pflicht.

## 5. Sicherheitsgrenzen

Das ist **Offsite-Backup, kein automatisches Failover**. Beide Root-Server dürfen keine parallel schreibenden Vaultwarden-Instanzen betreiben. Ein Proxmox-/LXC-Ausfall unterbricht Backups und muss aktiv überwacht werden. Bei Verlust des LXC auch den offline hinterlegten Restic-Schlüssel sowie den SSH-Schlüssel für einen Restore bereithalten. Die Sicherung ist erst erfolgreich, wenn ein vollständiger Test-Restore funktioniert.
