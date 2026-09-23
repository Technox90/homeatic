#!/usr/bin/env python3

import glob
import grp
import json
import math
import os
import re
import sqlite3
import subprocess
import time
from pathlib import Path

import psutil

DB = Path("/var/lib/pve-sensor-dashboard/metrics.db")
POWER_STATE = Path("/var/lib/pve-sensor-dashboard/power-state.json")
RETENTION_DAYS = int(os.environ.get("PVE_MONITOR_RETENTION_DAYS", "35"))

COLUMNS = {
    "ts": "INTEGER PRIMARY KEY",
    "cpu_percent": "REAL",
    "iowait_percent": "REAL",
    "load1": "REAL",
    "load5": "REAL",
    "load15": "REAL",
    "ram_percent": "REAL",
    "ram_used": "INTEGER",
    "ram_total": "INTEGER",
    "swap_percent": "REAL",
    "root_percent": "REAL",
    "root_used": "INTEGER",
    "root_total": "INTEGER",
    "cpu_temp": "REAL",
    "cpu_freq": "REAL",
    "board_temp": "REAL",
    "vrm_temp": "REAL",
    "chipset_temp": "REAL",
    "drive_temp": "REAL",
    "gpu_temp": "REAL",
    "cpu_fan_rpm": "REAL",
    "system_fan_rpm": "REAL",
    "vcore": "REAL",
    "cpu_power_w": "REAL",
    "cpu_core_power_w": "REAL",
    "uncore_power_w": "REAL",
    "dram_power_w": "REAL",
    "gpu_power_w": "REAL",
    "system_power_w": "REAL",
    "gpu_util_percent": "REAL",
    "net_rx_bps": "REAL",
    "net_tx_bps": "REAL",
    "disk_read_bps": "REAL",
    "disk_write_bps": "REAL",
    "net_rx_total": "INTEGER",
    "net_tx_total": "INTEGER",
    "disk_read_total": "INTEGER",
    "disk_write_total": "INTEGER",
    "uptime": "INTEGER",
    "process_count": "INTEGER",
    "vm_running": "INTEGER",
    "vm_total": "INTEGER",
    "ct_running": "INTEGER",
    "ct_total": "INTEGER",
    "pihole_queries_total": "INTEGER",
    "pihole_queries_blocked": "INTEGER",
    "pihole_blocked_percent": "REAL",
}

INSERT_COLS = list(COLUMNS.keys())


def run_text(cmd, timeout=3):
    try:
        return subprocess.check_output(
            cmd,
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=timeout,
        ).strip()
    except Exception:
        return ""


def sane(value, low=-1e9, high=1e9):
    try:
        value = float(value)
        if math.isfinite(value) and low <= value <= high:
            return value
    except Exception:
        pass
    return None


def connect_db():
    DB.parent.mkdir(parents=True, exist_ok=True)
    con = sqlite3.connect(DB, timeout=30)
    con.execute("PRAGMA journal_mode=DELETE")
    con.execute("PRAGMA synchronous=NORMAL")

    defs = ", ".join(f"{k} {v}" for k, v in COLUMNS.items())
    con.execute(f"CREATE TABLE IF NOT EXISTS metrics ({defs})")

    existing = {
        row[1]
        for row in con.execute("PRAGMA table_info(metrics)").fetchall()
    }
    for col, coldef in COLUMNS.items():
        if col not in existing:
            if "PRIMARY KEY" in coldef:
                continue
            con.execute(f"ALTER TABLE metrics ADD COLUMN {col} {coldef}")

    con.execute("CREATE INDEX IF NOT EXISTS idx_metrics_ts ON metrics(ts)")
    con.commit()
    return con


def sensors_json():
    raw = run_text(["sensors", "-j"], timeout=4)
    if not raw:
        return {}
    try:
        return json.loads(raw)
    except Exception:
        return {}


def sensor_values(data):
    values = []
    for chip, chipdata in data.items():
        if not isinstance(chipdata, dict):
            continue
        for feature, featuredata in chipdata.items():
            if not isinstance(featuredata, dict):
                continue
            for key, value in featuredata.items():
                if not key.endswith(("_input", "_average")):
                    continue
                val = sane(value)
                if val is None:
                    continue
                values.append({
                    "chip": str(chip),
                    "feature": str(feature),
                    "key": str(key),
                    "value": val,
                    "text": f"{chip} {feature} {key}".lower(),
                })
    return values


def first_matching(values, kind, keywords, excludes=(), mode="first"):
    found = []
    for item in values:
        key = item["key"].lower()
        text = item["text"]

        if kind == "temp" and not key.startswith("temp"):
            continue
        if kind == "fan" and not key.startswith("fan"):
            continue
        if kind == "voltage" and not key.startswith("in"):
            continue
        if kind == "power" and not key.startswith("power"):
            continue

        if keywords and not any(k in text for k in keywords):
            continue
        if any(k in text for k in excludes):
            continue

        found.append(item["value"])

    if not found:
        return None
    return max(found) if mode == "max" else found[0]


def hardware_sensors():
    data = sensors_json()
    vals = sensor_values(data)

    # CPU-Temperatur separat mit psutil priorisieren.
    cpu_temp = None
    try:
        temps = psutil.sensors_temperatures(fahrenheit=False) or {}
        preferred = []
        for chip, entries in temps.items():
            for entry in entries:
                cur = sane(entry.current, -20, 130)
                if cur is None:
                    continue
                txt = f"{chip} {entry.label or ''}".lower()
                if any(k in txt for k in (
                    "coretemp", "package id", "tctl", "tdie", "cpu"
                )):
                    preferred.append(cur)
        if preferred:
            cpu_temp = max(preferred)
    except Exception:
        pass

    if cpu_temp is None:
        cpu_temp = first_matching(
            vals, "temp",
            ("package", "coretemp", "tctl", "tdie", "cpu temp"),
            ("critical",),
            "max",
        )

    board_temp = first_matching(
        vals, "temp",
        ("systin", "system", "motherboard", "mainboard", "board"),
        ("cpu", "gpu", "nvme", "pch", "vrm"),
    )

    # Fallback für Boards ohne unterstützten Super-I/O-HWMON-Treiber:
    # höchsten plausiblen ACPI-Thermalzonenwert als Mainboard/Systemwert nutzen.
    if board_temp is None:
        acpi_temps = [
            item["value"]
            for item in vals
            if "acpitz" in item["chip"].lower()
            and item["key"].lower().startswith("temp")
            and -10 <= item["value"] <= 100
        ]
        if acpi_temps:
            board_temp = max(acpi_temps)

    vrm_temp = first_matching(
        vals, "temp",
        ("vrm", "mos", "mosfet"),
        (),
        "max",
    )

    chipset_temp = first_matching(
        vals, "temp",
        ("pch", "chipset"),
        (),
        "max",
    )

    drive_temp = first_matching(
        vals, "temp",
        ("nvme", "drivetemp", "composite"),
        (),
        "max",
    )

    cpu_fan = first_matching(
        vals, "fan",
        ("cpu", "cpu_fan", "cpufan"),
    )

    all_fans = [
        x["value"] for x in vals
        if x["key"].lower().startswith("fan") and 0 < x["value"] < 50000
    ]
    system_fan = max(all_fans) if all_fans else None

    vcore = first_matching(
        vals, "voltage",
        ("vcore", "cpu vcore", "core voltage"),
    )

    # AMDGPU kann Leistung/Temp direkt über hwmon liefern.
    amdgpu_power = first_matching(
        vals, "power",
        ("amdgpu",),
        (),
        "max",
    )
    amdgpu_temp = first_matching(
        vals, "temp",
        ("amdgpu", "edge", "junction"),
        (),
        "max",
    )

    return {
        "cpu_temp": cpu_temp,
        "board_temp": board_temp,
        "vrm_temp": vrm_temp,
        "chipset_temp": chipset_temp,
        "drive_temp": drive_temp,
        "cpu_fan_rpm": cpu_fan,
        "system_fan_rpm": system_fan,
        "vcore": vcore,
        "amdgpu_power": amdgpu_power,
        "amdgpu_temp": amdgpu_temp,
    }



def rapl_power(now):
    """
    Liest Intel-RAPL direkt über /sys/class/powercap/intel-rapl:*.

    Wichtig: Die Einträge unter /sys/class/powercap sind auf vielen
    Proxmox-/Debian-Systemen Symlinks. Path.rglob() folgt diesen nicht
    zuverlässig. Deshalb werden die RAPL-Zonen direkt geglobbt.

    package-0 ist bereits das gesamte CPU-Package und darf nicht mit
    core/uncore/dram addiert werden.
    """
    root = Path("/sys/class/powercap")
    if not root.exists():
        return {
            "package": None,
            "core": None,
            "uncore": None,
            "dram": None,
        }

    zones = {}

    for zone in sorted(root.glob("intel-rapl:*")):
        try:
            name_file = zone / "name"
            energy_file = zone / "energy_uj"

            if not name_file.is_file() or not energy_file.is_file():
                continue

            name = name_file.read_text().strip().lower()
            energy = int(energy_file.read_text().strip())

            max_file = zone / "max_energy_range_uj"
            max_range = int(max_file.read_text().strip()) if max_file.is_file() else None

            # Nur die bekannten Zonen aufnehmen.
            if name.startswith("package"):
                key = "package"
            elif name == "core":
                key = "core"
            elif name == "uncore":
                key = "uncore"
            elif name == "dram":
                key = "dram"
            else:
                continue

            # Bei mehreren Packages das erste Package verwenden.
            if key not in zones:
                zones[key] = {
                    "path": str(zone),
                    "energy": energy,
                    "max_range": max_range,
                }

        except Exception:
            continue

    state = {}
    try:
        state = json.loads(POWER_STATE.read_text())
    except Exception:
        pass

    previous = state.get("rapl_zones", {})
    current_state = {}
    result = {
        "package": None,
        "core": None,
        "uncore": None,
        "dram": None,
    }

    for key, zone in zones.items():
        current_state[key] = {
            "path": zone["path"],
            "ts": now,
            "energy": zone["energy"],
        }

        prev = previous.get(key, {})

        if (
            prev.get("path") != zone["path"]
            or prev.get("ts") is None
            or prev.get("energy") is None
        ):
            continue

        dt = now - float(prev["ts"])
        delta = zone["energy"] - int(prev["energy"])

        if delta < 0 and zone["max_range"]:
            delta = (
                int(zone["max_range"])
                - int(prev["energy"])
                + zone["energy"]
            )

        if not (0.2 <= dt <= 300) or delta < 0:
            continue

        watts = (delta / 1_000_000.0) / dt

        if 0 <= watts <= 2000:
            result[key] = round(watts, 2)

    state["rapl_zones"] = current_state

    try:
        POWER_STATE.write_text(json.dumps(state))
    except Exception:
        pass

    return result


def nvidia_data():
    out = run_text([
        "nvidia-smi",
        "--query-gpu=utilization.gpu,temperature.gpu,power.draw",
        "--format=csv,noheader,nounits",
    ], timeout=3)

    if not out:
        return None, None, None

    line = out.splitlines()[0]
    parts = [p.strip() for p in line.split(",")]
    if len(parts) < 3:
        return None, None, None

    util = sane(parts[0], 0, 100)
    temp = sane(parts[1], -20, 130)
    power = sane(parts[2], 0, 2000)
    return util, temp, power


def ipmi_system_power():
    out = run_text(["ipmitool", "dcmi", "power", "reading"], timeout=3)
    if not out:
        return None

    match = re.search(
        r"Instantaneous\s+power\s+reading\s*:\s*([0-9.]+)\s*Watts",
        out,
        re.IGNORECASE,
    )
    if not match:
        return None

    return sane(match.group(1), 0, 10000)


def guest_counts():
    vm_total = vm_running = 0
    ct_total = ct_running = 0

    out = run_text(["qm", "list"], timeout=4)
    lines = [x for x in out.splitlines() if x.strip()]
    for line in lines[1:]:
        cols = line.split()
        if len(cols) >= 3:
            vm_total += 1
            if cols[2].lower() == "running":
                vm_running += 1

    out = run_text(["pct", "list"], timeout=4)
    lines = [x for x in out.splitlines() if x.strip()]
    for line in lines[1:]:
        cols = line.split()
        if len(cols) >= 2:
            ct_total += 1
            if cols[1].lower() == "running":
                ct_running += 1

    return vm_running, vm_total, ct_running, ct_total



def pihole_stats():
    # Pi-hole-Statistik der letzten 24 Stunden aus pihole-FTL.db.
    try:
        ctid = None
        lxc_dir = Path("/etc/pve/lxc")

        if lxc_dir.exists():
            for conf in sorted(lxc_dir.glob("*.conf")):
                try:
                    content = conf.read_text(
                        encoding="utf-8",
                        errors="ignore",
                    )
                except Exception:
                    continue

                if re.search(
                    r"(?m)^hostname:\s*pihole\s*$",
                    content,
                ):
                    ctid = conf.stem
                    break

        if not ctid:
            return None, None, None

        status_text = run_text(
            ["pct", "status", ctid],
            timeout=3,
        )

        if "status: running" not in status_text.lower():
            return None, None, None

        db_path = "/opt/pihole/etc-pihole/pihole-FTL.db"

        # V105: sqlite3 without -readonly creates a missing DB as 0-byte file.
        # During a fresh Pi-hole installation this could race with FTL startup and
        # leave FTL with an invalid database. Therefore only query an existing,
        # non-empty DB and always open it read-only.
        # Probe the schema read-only; an unavailable/not-yet-initialized DB
        # simply means that Pi-hole statistics are not ready yet.
        schema = run_text(
            [
                "pct",
                "exec",
                ctid,
                "--",
                "sqlite3",
                "-readonly",
                db_path,
                "SELECT name FROM sqlite_master WHERE name='queries';",
            ],
            timeout=5,
        )

        if schema.strip() != "queries":
            return None, None, None

        sql = (
            "SELECT "
            "COUNT(*),"
            "COALESCE(SUM(CASE WHEN status IN "
            "(1,4,5,6,7,8,9,10,11,15,16,18) "
            "THEN 1 ELSE 0 END),0) "
            "FROM queries "
            "WHERE timestamp >= strftime('%s','now') - 86400;"
        )

        raw = run_text(
            [
                "pct",
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
            timeout=8,
        )

        if not raw:
            return None, None, None

        parts = raw.splitlines()[-1].strip().split("|")

        if len(parts) != 2:
            return None, None, None

        total = int(parts[0])
        blocked = int(parts[1])

        percent = (
            round((blocked * 100.0) / total, 2)
            if total > 0
            else 0.0
        )

        return total, blocked, percent
    except Exception:
        return None, None, None


def main():
    now = int(time.time())
    con = connect_db()

    cput = psutil.cpu_times_percent(interval=0.35)
    cpu_percent = max(0.0, min(100.0, 100.0 - float(cput.idle)))
    iowait = float(getattr(cput, "iowait", 0.0))
    load1, load5, load15 = os.getloadavg()

    mem = psutil.virtual_memory()
    swap = psutil.swap_memory()
    root = psutil.disk_usage("/")
    net = psutil.net_io_counters()
    dio = psutil.disk_io_counters()

    net_rx_total = int(net.bytes_recv if net else 0)
    net_tx_total = int(net.bytes_sent if net else 0)
    disk_read_total = int(dio.read_bytes if dio else 0)
    disk_write_total = int(dio.write_bytes if dio else 0)

    prev = con.execute(
        "SELECT ts, net_rx_total, net_tx_total, disk_read_total, disk_write_total "
        "FROM metrics ORDER BY ts DESC LIMIT 1"
    ).fetchone()

    rx_bps = tx_bps = rd_bps = wr_bps = 0.0
    if prev and now > prev[0]:
        dt = float(now - prev[0])
        if prev[1] is not None:
            rx_bps = max(0.0, (net_rx_total - prev[1]) / dt)
        if prev[2] is not None:
            tx_bps = max(0.0, (net_tx_total - prev[2]) / dt)
        if prev[3] is not None:
            rd_bps = max(0.0, (disk_read_total - prev[3]) / dt)
        if prev[4] is not None:
            wr_bps = max(0.0, (disk_write_total - prev[4]) / dt)

    freq = psutil.cpu_freq()
    cpu_freq = round(float(freq.current), 0) if freq else None

    hw = hardware_sensors()

    rapl = rapl_power(now)
    cpu_power = rapl.get("package")
    cpu_core_power = rapl.get("core")
    uncore_power = rapl.get("uncore")
    dram_power = rapl.get("dram")

    gpu_util, nvidia_temp, nvidia_power = nvidia_data()
    gpu_temp = nvidia_temp if nvidia_temp is not None else hw["amdgpu_temp"]
    gpu_power = nvidia_power if nvidia_power is not None else hw["amdgpu_power"]

    system_power = ipmi_system_power()

    vm_running, vm_total, ct_running, ct_total = guest_counts()

    pihole_total, pihole_blocked, pihole_percent = pihole_stats()

    values = {
        "ts": now,
        "cpu_percent": round(cpu_percent, 2),
        "iowait_percent": round(iowait, 2),
        "load1": round(load1, 3),
        "load5": round(load5, 3),
        "load15": round(load15, 3),
        "ram_percent": round(mem.percent, 2),
        "ram_used": int(mem.used),
        "ram_total": int(mem.total),
        "swap_percent": round(swap.percent, 2),
        "root_percent": round(root.percent, 2),
        "root_used": int(root.used),
        "root_total": int(root.total),
        "cpu_temp": sane(hw["cpu_temp"], -20, 130),
        "cpu_freq": cpu_freq,
        "board_temp": sane(hw["board_temp"], -20, 130),
        "vrm_temp": sane(hw["vrm_temp"], -20, 160),
        "chipset_temp": sane(hw["chipset_temp"], -20, 160),
        "drive_temp": sane(hw["drive_temp"], -20, 130),
        "gpu_temp": sane(gpu_temp, -20, 160),
        "cpu_fan_rpm": sane(hw["cpu_fan_rpm"], 0, 50000),
        "system_fan_rpm": sane(hw["system_fan_rpm"], 0, 50000),
        "vcore": sane(hw["vcore"], 0, 10),
        "cpu_power_w": sane(cpu_power, 0, 1000),
        "cpu_core_power_w": sane(cpu_core_power, 0, 1000),
        "uncore_power_w": sane(uncore_power, 0, 1000),
        "dram_power_w": sane(dram_power, 0, 1000),
        "gpu_power_w": sane(gpu_power, 0, 2000),
        "system_power_w": sane(system_power, 0, 10000),
        "gpu_util_percent": sane(gpu_util, 0, 100),
        "net_rx_bps": round(rx_bps, 2),
        "net_tx_bps": round(tx_bps, 2),
        "disk_read_bps": round(rd_bps, 2),
        "disk_write_bps": round(wr_bps, 2),
        "net_rx_total": net_rx_total,
        "net_tx_total": net_tx_total,
        "disk_read_total": disk_read_total,
        "disk_write_total": disk_write_total,
        "uptime": max(0, int(now - psutil.boot_time())),
        "process_count": len(psutil.pids()),
        "vm_running": vm_running,
        "vm_total": vm_total,
        "ct_running": ct_running,
        "ct_total": ct_total,
        "pihole_queries_total": pihole_total,
        "pihole_queries_blocked": pihole_blocked,
        "pihole_blocked_percent": pihole_percent,
    }

    placeholders = ",".join("?" for _ in INSERT_COLS)
    cols = ",".join(INSERT_COLS)

    con.execute(
        f"INSERT OR REPLACE INTO metrics ({cols}) VALUES ({placeholders})",
        [values.get(c) for c in INSERT_COLS],
    )

    cutoff = now - RETENTION_DAYS * 86400
    con.execute("DELETE FROM metrics WHERE ts < ?", (cutoff,))
    con.commit()
    con.close()

    try:
        gid = grp.getgrnam("pve-monitor").gr_gid
        os.chown(DB.parent, 0, gid)
        os.chmod(DB.parent, 0o750)
        os.chown(DB, 0, gid)
        os.chmod(DB, 0o640)
        if POWER_STATE.exists():
            os.chown(POWER_STATE, 0, gid)
            os.chmod(POWER_STATE, 0o640)
    except Exception:
        pass


if __name__ == "__main__":
    main()
