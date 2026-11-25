#!/usr/bin/env python3
import runpy
from pathlib import Path
import tempfile

m=runpy.run_path("proxmox/tools/proxmox-migrate-layout",run_name="migration_test")
assert m["rewrite"]("/opt/nodezero/dashboard/static/index.html")=="/opt/dashboard/static/index.html"
assert m["nginx_rewrite"]("ssl_certificate /etc/letsencrypt/live/nodezero-external/fullchain.pem;")=="ssl_certificate /etc/letsencrypt/live/nodezero-external/fullchain.pem;"
assert m["nginx_rewrite"]("root /var/www/nodezero-acme;")=="root /var/www/proxmox-acme;"
with tempfile.TemporaryDirectory() as d:
    root=Path(d)
    backup=root/"backup"
    backup.mkdir()
    a,b=root/"old",root/"new"
    a.mkdir()
    (a/"logo.png").write_bytes(b"personal-logo")
    tx=m["Transaction"](backup)
    tx.move(a,b)
    assert not a.exists() and (b/"logo.png").read_bytes()==b"personal-logo"
    assert not tx.rollback()
    assert (a/"logo.png").read_bytes()==b"personal-logo" and not b.exists()
print("migration tests passed")
