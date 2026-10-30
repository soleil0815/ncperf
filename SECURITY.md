# Sicherheit

## Was ncperf tut

- Es **liest** Konfiguration und Statuswerte und **ändert nichts** am System.
- Zugangsdaten für Datenbank und Redis werden aus der `config.php` gelesen und nur lokal für die Verbindung genutzt. Sie erscheinen nicht in der Ausgabe oder im Bericht.
- Es werden **keine Daten an Dritte** gesendet. Netzwerkzugriffe gehen nur an die eigene Nextcloud-URL (Antwortzeiten, Serverinfo).
- `--disktest` schreibt kurz Testdateien in `<datadirectory>/.ncperf-tmp` und löscht sie sofort wieder.

## Hinweise zur Nutzung

- Das Serverinfo-Token gewährt Lesezugriff auf Serverstatistiken. Behandle es wie ein Passwort und wähle einen langen Zufallswert (`openssl rand -hex 32`).
- Der Bericht enthält Domain, Pfade und Versionsnummern. Diese Angaben vor dem Teilen unkenntlich machen.
- Das Token wird beim Aufruf als Kommandozeilen-Argument übergeben und ist damit für andere Benutzer auf demselben System kurz in der Prozessliste sichtbar. Auf Systemen mit mehreren Benutzern besser die Umgebungsvariable nutzen: `sudo NCPERF_TOKEN=... sh ncperf.sh`.

## Sicherheitslücke melden

Bitte **kein öffentliches Issue** anlegen, sondern über die Funktion [„Report a vulnerability“](https://github.com/soleil0815/ncperf/security/advisories/new) von GitHub melden.
