# Changelog

**Deutsch** · [English](CHANGELOG.md)

Alle wichtigen Änderungen an ncperf. Versionsnummern nach [Semantic Versioning](https://semver.org/lang/de/).

## 1.3.0 – 2026-10-30

### Neu
- Ausgabe auf Deutsch und Englisch, automatisch nach Systemsprache (`LANG`), umschaltbar mit `-l/--lang de|en` oder `NCPERF_LANG`.
- Option `-V/--version`.
- Dokumentation zweisprachig (`README.md` Englisch, `README.de.md` Deutsch).

### Behoben
- Anleitung: `sudo` verwirft per `export` gesetzte Variablen (`NCPERF_TOKEN`, `NCPERF_LANG`) – richtiger Aufruf und Kontrollhinweis ergänzt.
- Antworten mit HTTP-Fehlercodes (z.B. 401, 404, 500) beim Test der Antwortzeiten werden nicht mehr als „OK“ gewertet.

## 1.2.0 – 2026-10-30

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
