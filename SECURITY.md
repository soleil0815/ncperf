# Security / Sicherheit

**English** · [Deutsch](#deutsch)

## What ncperf does

- It **reads** configuration and status values and **changes nothing** on the system.
- Database and Redis credentials are read from `config.php` and only used locally for the connection. They never appear in the output or the report.
- **No data is sent to third parties.** Network requests only go to your own Nextcloud URL (response times, Serverinfo).
- `--disktest` briefly writes test files to `<datadirectory>/.ncperf-tmp` and deletes them immediately.

## Notes on usage

- The Serverinfo token grants read access to server statistics. Treat it like a password and use a long random value (`openssl rand -hex 32`).
- The report contains your domain, paths and version numbers. Mask them before sharing.
- A token passed with `-t` is briefly visible to other users on the same system in the process list. On multi-user systems use the environment variable instead: `sudo NCPERF_TOKEN=... sh ncperf.sh`.

## Reporting a vulnerability

Please **do not open a public issue**; use GitHub's [“Report a vulnerability”](https://github.com/soleil0815/ncperf/security/advisories/new) instead.

---

## Deutsch

### Was ncperf tut

- Es **liest** Konfiguration und Statuswerte und **ändert nichts** am System.
- Zugangsdaten für Datenbank und Redis werden aus der `config.php` gelesen und nur lokal für die Verbindung genutzt. Sie erscheinen nicht in der Ausgabe oder im Bericht.
- Es werden **keine Daten an Dritte** gesendet. Netzwerkzugriffe gehen nur an die eigene Nextcloud-URL (Antwortzeiten, Serverinfo).
- `--disktest` schreibt kurz Testdateien in `<datadirectory>/.ncperf-tmp` und löscht sie sofort wieder.

### Hinweise zur Nutzung

- Das Serverinfo-Token gewährt Lesezugriff auf Serverstatistiken. Behandle es wie ein Passwort und wähle einen langen Zufallswert (`openssl rand -hex 32`).
- Der Bericht enthält Domain, Pfade und Versionsnummern. Diese Angaben vor dem Teilen unkenntlich machen.
- Ein mit `-t` übergebenes Token ist für andere Benutzer auf demselben System kurz in der Prozessliste sichtbar. Auf Systemen mit mehreren Benutzern besser die Umgebungsvariable nutzen: `sudo NCPERF_TOKEN=... sh ncperf.sh`.

### Sicherheitslücke melden

Bitte **kein öffentliches Issue** anlegen, sondern über die Funktion [„Report a vulnerability“](https://github.com/soleil0815/ncperf/security/advisories/new) von GitHub melden.
