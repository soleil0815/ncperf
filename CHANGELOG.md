# Changelog

Alle wichtigen Änderungen an ncperf. Versionsnummern nach [Semantic Versioning](https://semver.org/lang/de/).

## [1.2.0] – 2026-10-30

### Neu
- Option `-t/--token`: liest über die Nextcloud-App Serverinfo die PHP-Werte, die der Webserver wirklich nutzt (z.B. das PHP-Profil der Synology Web Station).
- Vergleichstabelle „Web (Profil)“ und „CLI (Cron)“ mit Markierung von Unterschieden.
- Laufzeitwerte von OPcache und APCu: Füllstand, Trefferquote, Interned-Strings-Puffer, Anzahl gecachter Skripte.
- Warnung, wenn APCu oder Redis konfiguriert, im Web-Profil aber nicht geladen sind.
- Warnung, wenn Cron/occ eine andere PHP-Version nutzt als der Webserver.
- Token alternativ über die Umgebungsvariable `NCPERF_TOKEN`.

### Geändert
- Projekt heißt jetzt **ncperf** (vorher nc-perfcheck).

## 1.1.0 – 2026-10-30

### Geändert
- Komplett auf POSIX `sh` umgestellt; läuft mit dash, BusyBox ash und bash.

### Behoben
- Falscher Pfad mit `-p` wird klar gemeldet; bei Abbruch wird kein Bericht mehr gespeichert.

## 1.0.0 – 2026-10-30

### Neu
- Erste Version: Prüfung von System, Nextcloud, PHP, PHP-FPM, Datenbank (MariaDB/MySQL, PostgreSQL), Redis und Web-Antwortzeiten.
- Automatische Erkennung von Docker-Containern und nativen Installationen.
- Vorschläge für passende Einstellungen anhand von RAM, CPU und Datenbankgröße.
- Optionaler Speichertest (`--disktest`).

[1.2.0]: https://github.com/soleil0815/ncperf/releases/tag/v1.2.0
