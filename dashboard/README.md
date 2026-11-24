# NodeZero Proxmox Dashboard

Ausgelagerte Basisquellen des Proxmox-Dashboards.

## Aktueller Stand

**Dashboard-Branding: V151**

Dateien:

- `collector.py` – sammelt Host-/Hardware-/VM-/LXC-Metriken.
- `app.py` – Flask/Gunicorn API.
- `index.html` – Basis-Frontend.
- `branding-v151.css` – feste Toolbar und generisches Branding-Layout.
- `branding-v151.js` – generisches Branding, Titel, Logo-Fallback und Favicon.
- `assets/logo.png` – neutraler transparenter Logo-Platzhalter.
- `assets/favicon.png` – neutraler transparenter Favicon-Platzhalter.
- `views/` – auswählbare Dashboard-Darstellungen.

## Branding-Regel V151

Die Repository-Bilder sind absichtlich **leer/transparent** und enthalten kein persönliches Branding.

Auf einer installierten Maschine liegen eigene Bilder unter:

```text
/opt/nodezero/dashboard/static/assets/logo.png
/opt/nodezero/dashboard/static/assets/favicon.png
```

Ein normales Dashboard-Update überschreibt diese beiden Dateien **niemals**.

Nur bei einer Erst-/Neuinstallation werden die neutralen Repository-Platzhalter geladen – und auch dann nur, wenn die jeweilige Zieldatei noch nicht vorhanden ist.

Ist `logo.png` leer/transparent oder fehlt, verwendet das Menü automatisch den konfigurierten Text-Fallback.

## Installation

Seit V139 werden die Dashboard-Basisquellen nicht mehr als große Heredocs im Master-Installer gepflegt. Der Installer lädt die Quellen versionsgebunden in den persistenten Downloadbereich und installiert sie nach:

```text
/opt/nodezero/dashboard/
```

Die vollständige Installations-, Update- und Migrationslogik liegt in:

```text
proxmox/modules/dashboard.sh
```

Dokumentation:

- [Proxmox Installer README](../proxmox/README.md)
- [Versionshistorie](../proxmox/HISTORY.md)
