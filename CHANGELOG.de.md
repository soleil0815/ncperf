# Changelog

**Deutsch** · [English](CHANGELOG.md)

Alle wichtigen Änderungen an ncperf. Versionsnummern nach [Semantic Versioning](https://semver.org/lang/de/).

## 1.3.1 – 2026-10-30

### Behoben
- Native Installationen (z.B. Synology Web Station): Fehlt OPcache nur auf der Kommandozeile, gilt das nicht mehr als kritisch – für Cron ist es unwichtig, den Web-Status zeigt `-t TOKEN`.
- Vorschläge liegen nie unter den aktuellen Werten (z.B. `memory_limit`, `apc.shm_size`, OPcache-Größen).
- `pm.max_children` wird mit mindestens 100 MB je Prozess unter Last gerechnet und auf 8 je CPU-Kern begrenzt (vorher bis 200).
- Vorschlag für `innodb_buffer_pool_size` bei 8 GB RAM oder mehr mindestens 512 MB.

### Neu
- Erkennt die PHP-Version der PHP-FPM-Prozesse (z.B. `php-fpm85`) und warnt, wenn die Kommandozeile eine andere Version nutzt.
- Klare Meldung, wenn der Platzhalter aus der Anleitung (`DEINTOKEN`/`YOURTOKEN`) als Token benutzt wird.
- Synology-Hinweis nennt die erkannte PHP-Version statt fest `php84`.

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
