#!/usr/bin/env python3
"""Regression tests for V182: no root, real nginx, certbot or guests needed."""
import ast
import json
import os
import re
import shutil
import tempfile
from pathlib import Path
from types import SimpleNamespace
import unittest

SOURCE = Path(__file__).resolve().parents[1] / "tools/proxmox-external-urls"
TREE = ast.parse(SOURCE.read_text())
DEFS = [n for n in TREE.body if isinstance(n, ast.FunctionDef)]
FUNCTIONS = compile(ast.Module(body=DEFS, type_ignores=[]), str(SOURCE), "exec")

def reply(stdout="", stderr="", returncode=0):
    return SimpleNamespace(stdout=stdout, stderr=stderr, returncode=returncode)

def scope():
    ns = dict(re=re, json=json, os=os, shutil=shutil, Path=Path,
              HOST_RE=re.compile(r"^[A-Za-z0-9.-]+\.[A-Za-z]{2,63}$"))
    exec(FUNCTIONS, ns)
    return ns

class ExternalUrlsTest(unittest.TestCase):
    def setUp(self):
        self.ns = scope()
        self.cfg = {"base_domain": "example.de", "services": [
            {"key": "vault", "prefix": "vault", "host": "", "backend": "https://192.0.2.10", "enabled": True},
            {"key": "ha", "prefix": "ha", "host": "", "backend": "", "enabled": False},
            {"key": "kitchenowl", "prefix": "shop", "host": "", "backend": "https://192.0.2.11", "enabled": True},
        ]}
        self.dump = """# configuration file /etc/nginx/conf.d/proxmox-external.conf:
server {
    listen 443 ssl;
    server_name vault.example.de;
    proxy_pass https://192.0.2.99;
}
# configuration file /etc/nginx/sites-enabled/vault.example.de:
server {
    listen 443 ssl;
    server_name vault.example.de;
    location = /admin { return 403; }
    location / { proxy_pass https://192.0.2.10:443; }
}
# configuration file /etc/nginx/sites-enabled/ha.example.de:
server {
    listen 443 ssl;
    server_name ha.example.de;
    location / { proxy_pass http://192.0.2.101:80; }
}
# configuration file /etc/nginx/sites-enabled/acme:
server {
    listen 80;
    server_name
        ha.example.de
        vault.example.de;
    location / { return 308 https://$host$request_uri; }
}
"""
        self.ns.update(ACME_CONF=Path("/etc/nginx/conf.d/proxmox-external-acme.conf"),
                       PROXY_CONF=Path("/etc/nginx/conf.d/proxmox-external.conf"),
                       run=lambda *a, **k: reply(self.dump))
        self.ns["shutil"] = SimpleNamespace(which=lambda n: "/usr/sbin/nginx")

    def test_existing_vhosts_and_import(self):
        ns = self.ns
        existing = ns["existing_vhosts"]()
        self.assertEqual(existing["vault.example.de"]["backend"], "https://192.0.2.10:443")
        self.assertIn("http", existing["ha.example.de"])
        self.assertNotIn("shop.example.de", existing)
        ns["build_catalog"] = lambda saved: [dict(s) for s in self.cfg["services"]]
        ns["refresh_backends"](self.cfg)
        ha = self.cfg["services"][1]
        self.assertTrue(ha["enabled"])
        self.assertEqual(ha["backend"], "http://192.0.2.101:80")
        self.assertTrue(ha["external_managed"])
        self.assertEqual([x["key"] for x in ns["managed_services"](self.cfg)], ["kitchenowl"])
        ns["checklist"] = lambda *a: set()
        ns["configure_selection"](self.cfg["services"], self.cfg["base_domain"])
        self.assertTrue(ha["enabled"])
        self.assertTrue(self.cfg["services"][0]["enabled"])
        self.assertFalse(self.cfg["services"][2]["enabled"])

    def test_generated_vault_admin_guard(self):
        ns = self.ns
        ns["pve_host_ip"] = lambda: "192.0.2.100"
        result = ns["proxy_server"](self.cfg["services"][0], self.cfg, Path("/cert"))
        self.assertIn("location = /admin { return 403; }", result)
        self.assertIn("location ^~ /admin/ { return 403; }", result)

    def test_ha_agent_array_response(self):
        ns = self.ns
        interfaces = [{"ip-addresses": [{"ip-address": "127.0.0.1", "ip-address-type": "ipv4"}]},
                      {"ip-addresses": [{"ip-address": "192.0.2.101", "ip-address-type": "ipv4"}]}]
        def run(args, **kw):
            if args[:2] == ["qm", "list"]: return reply("VMID NAME\n101 haos\n")
            if args[:2] == ["qm", "config"]: return reply("name: haos\n")
            return reply(json.dumps(interfaces))
        ns["run"] = run
        self.assertEqual(ns["ha_backend"](), "http://192.0.2.101:8123")

    def test_acme_keeps_sans_without_duplicate_http(self):
        ns = self.ns
        with tempfile.TemporaryDirectory() as d:
            ns["ACME_CONF"] = Path(d) / "acme.conf"
            ns["ACME_ROOT"] = Path(d)
            ns["cert_domains"] = lambda p: {"old.example.de", "vault.example.de"}
            ns["CERT_NAME"] = "test"
            ns["existing_vhosts"] = lambda: {"vault.example.de": {"http":"manual", "https":"manual"}}
            ns["write_acme"](self.cfg)
            config = ns["ACME_CONF"].read_text()
            self.assertIn("old.example.de", config)
            self.assertIn("shop.example.de", config)
            self.assertNotIn("vault.example.de", config)

    def test_rollback_restores_previous_nginx_and_dns(self):
        ns = self.ns
        with tempfile.TemporaryDirectory() as d:
            for name in ("ACME_CONF", "PROXY_CONF", "DNS_FILE"):
                path = Path(d) / name
                path.write_bytes(b"old-" + name.encode())
                ns[name] = path
            ns["ensure_packages"] = lambda: None
            ns["write_dns"] = lambda cfg: ns["DNS_FILE"].write_text("new")
            ns["write_acme"] = lambda cfg: ns["ACME_CONF"].write_text("new")
            ns["managed_services"] = lambda cfg: [self.cfg["services"][2]]
            ns["ensure_certificate"] = lambda cfg: Path(d)
            def fail(cfg, cert):
                ns["PROXY_CONF"].write_text("new")
                raise RuntimeError("invalid nginx")
            ns["write_proxy"] = fail
            ns["run"] = lambda *a, **k: reply()
            with self.assertRaises(RuntimeError):
                ns["apply"](self.cfg)
            for name in ("ACME_CONF", "PROXY_CONF", "DNS_FILE"):
                self.assertEqual(ns[name].read_bytes(), b"old-" + name.encode())

if __name__ == "__main__":
    unittest.main()
