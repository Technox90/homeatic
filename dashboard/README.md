# Proxmox Dashboard

Ausgelagerte Basisquellen des Proxmox-Dashboards.

## Aktueller Stand

**Dashboard-Stand: V164**

Dateien:

- `collector.py` – sammelt Host-/Hardware-/VM-/LXC-Metriken.
- `app.py` – Flask/Gunicorn API.
- `index.html` – Basis-Frontend.
- `branding-v151.css` – feste Toolbar und generisches Branding-Layout.
- `branding-v151.js` – generisches Branding, Titel, Logo-Fallback und Favicon.
- `assets/logo.png` – neutraler transparenter Logo-Platzhalter.
- `assets/favicon.png` – neutraler transparenter Favicon-Platzhalter.
- `views/` – auswählbare Dashboard-Darstellungen.

## V164

- Boot-Animation: exakt der in den Einstellungen hinterlegte Name, kein zusätzliches Präfix.
- Aktiver Pfad: `/opt/dashboard/`.

## V163

- Neustart und Herunterfahren nutzen skalierbare SVG-Icons statt Schriftzeichen.

## Freigabestand V162

- Freigabestand mit allen V161-Funktionen: individuell konfigurierbare aktive/inaktive Browser-Tab-Titel und priorisierte Update-Hinweise.
- Logo wird bei unveränderten Einstellungen während der laufenden USV-Statusabfragen nicht erneut geladen; bewusste Branding-Aktualisierung bleibt möglich.
- V162 enthält die bisherigen Änderungen kumulativ; der bestehende automatische Update-Zeitplan und die Opt-in-Einstellungen bleiben unverändert.

## Browser-Tab-Anzeige V161

- Browser-Tab-Anzeige in den Dashboard-Einstellungen getrennt für aktive und inaktive Tabs konfigurierbar.
- Standard: aktiv nur Name; inaktiv Name → CPU/RAM → Leistungsaufnahme. Wechsel alle 5 Sekunden, Update-Hinweise alle 3 Sekunden.
- Update-Hinweise haben optional Vorrang; Messwerte und Versionsstatus werden aus bestehenden Abfragen übernommen. Speicherung lokal pro Browser, ohne Änderungen an Logos oder Favicons.

## Branding V160

- Zusammenführung der parallelen V159-Änderungen: `randMenuLogo`, mittiger Titel, Logo bis 350 × 60 px sowie zugängliche mobile Power-Icons.
- Branding-Script erhält eine stabile ID; alte Update-Marker bleiben kompatibel.
- Beide verpflichtenden CI-Prüfungen laufen bei jedem Pull Request auf main, auch bei reinen Dokumentationsänderungen.
- Lokale Logo- und Favicon-Dateien bleiben unverändert.

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
/opt/dashboard/static/assets/logo.png
/opt/dashboard/static/assets/favicon.png
```

Ein normales Dashboard-Update überschreibt diese beiden Dateien **niemals**.

Nur bei einer Erst-/Neuinstallation werden die neutralen Repository-Platzhalter geladen – und auch dann nur, wenn die jeweilige Zieldatei noch nicht vorhanden ist.

Ist `logo.png` leer/transparent oder fehlt, verwendet das Menü automatisch den konfigurierten Text-Fallback.

## Installation

Seit V139 werden die Dashboard-Basisquellen nicht mehr als große Heredocs im Master-Installer gepflegt. Der Installer lädt die Quellen versionsgebunden in den persistenten Downloadbereich und installiert sie nach:

```text
/opt/dashboard/
```

Die vollständige Installations-, Update- und Migrationslogik liegt in:

```text
proxmox/modules/dashboard.sh
```

Dokumentation:

- [Proxmox Installer README](../proxmox/README.md)
- [Versionshistorie](../proxmox/HISTORY.md)
