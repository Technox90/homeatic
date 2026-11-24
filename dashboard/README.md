# NodeZero Proxmox Dashboard

Ausgelagerte Basisquellen des Proxmox-Dashboards.

## Aktueller Stand

**Dashboard-Stand: V159**

Dateien:

- `collector.py` – sammelt Host-/Hardware-/VM-/LXC-Metriken.
- `app.py` – Flask/Gunicorn API.
- `index.html` – Basis-Frontend.
- `branding-v151.css` – feste Toolbar und generisches Branding-Layout.
- `branding-v151.js` – generisches Branding, Titel, Logo-Fallback und Favicon.
- `assets/logo.png` – neutraler transparenter Logo-Platzhalter.
- `assets/favicon.png` – neutraler transparenter Favicon-Platzhalter.
- `views/` – auswählbare Dashboard-Darstellungen.

## Branding V159

- Aktive Branding-IDs und CSS-Klassen ohne Versionssuffix; das Logo verwendet `randMenuLogo`.
- Konfigurierter Dashboard-Titel wird auf Desktop und Mobilgeräten mittig angezeigt.
- Manueller und automatischer Updatepfad verwenden dieselben Branding-Quellen; lokale Logos/Favicons bleiben unverändert.

Die bestehenden Dateinamen und internen Update-Marker bleiben aus Kompatibilitätsgründen erhalten.

## Feinschliff V154

Der kombinierte Hamburger-/Logo-Toggle bleibt links angeordnet, wird aber optisch freier dargestellt: größeres Logo, kein sichtbarer Rahmen und transparenter Grundzustand. Die komplette Klickfläche bleibt erhalten.

## Toolbar V153

Die feste obere Leiste ist in drei Bereiche geteilt:

```text
links:  ☰ + Logo
mitte:  LIVE + USV Online
rechts: Neustart + Herunterfahren
```

Der kombinierte Hamburger-/Logo-Button ersetzt den früheren separaten Menübutton und öffnet bzw. schließt das Seitenmenü. Das Seitenmenü selbst besitzt keinen zusätzlichen sichtbaren Kopf oder X-Button mehr.

## Update-Modus V152

Ein bereits aktuelles Dashboard wird bei einem normalen Update in-place aktualisiert. Die vorhandenen `app.py`, `index.html` und `collector.py` werden nicht mehr durch die alte V139-Basis ersetzt. Historische UI-Migrationen werden nur noch als Kompatibilitäts-Bootstrap für alte/unvollständige Installationen oder Neuaufbauten ausgeführt.

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
