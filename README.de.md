# ncperf – Performance-Analyse für Nextcloud

[![ShellCheck](https://github.com/soleil0815/ncperf/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/soleil0815/ncperf/actions/workflows/shellcheck.yml)
[![Lizenz: MIT](https://img.shields.io/badge/Lizenz-MIT-blue.svg)](LICENSE)
![POSIX sh](https://img.shields.io/badge/shell-POSIX%20sh-green.svg)

**Deutsch** · [English](README.md)

Ein einzelnes Shell-Skript (POSIX `sh`), das eine Nextcloud-Instanz auf Performance prüft und **passende Einstellungen für genau dieses System** vorschlägt.

- läuft auf **Linux-Servern** und **Synology** (DSM)
- erkennt **Docker** (offizielles Image, AIO, linuxserver) und **native Installationen** (auch Web Station) selbst
- braucht keine Bash und keine Zusatzprogramme, nur die übliche Grundausstattung (`awk`, `sed`, `grep`, `curl`)
- **ändert nichts** am System und schickt keine Daten irgendwohin
- Ausgabe auf **Deutsch oder Englisch** (automatisch nach Systemsprache)

---

## Installation

Es gibt nichts zu installieren: Das Skript auf den Server bzw. die Synology laden und starten.

```sh
# direkt auf dem Server herunterladen
curl -fsSLO https://raw.githubusercontent.com/soleil0815/ncperf/main/ncperf.sh

# oder per Git
git clone https://github.com/soleil0815/ncperf.git && cd ncperf
```

Alternativ `ncperf.sh` auf dem eigenen Rechner herunterladen und per `scp` oder über die File Station auf den Server kopieren.

> Wie bei jedem Skript, das mit Root-Rechten läuft: Schau es dir vor dem ersten Start kurz an. Es ist eine einzige, lesbare Datei.

## Schnellstart

```sh
sudo sh ncperf.sh
```

Das war's. Das Skript sucht die Nextcloud selbst, liest die Konfiguration und gibt einen Bericht aus. Gleichzeitig speichert es den Bericht als `ncperf_<Datum>_<Uhrzeit>.txt` im aktuellen Ordner.

### Sprache

Die Ausgabe richtet sich nach der Systemsprache (`LANG`): Deutsch bei `de_*`, sonst Englisch. Über SSH ist die Sprache oft nicht gesetzt, dann kommt Englisch. So erzwingst du Deutsch:

```sh
sudo sh ncperf.sh --lang de
# oder dauerhaft, z.B. in ~/.profile:
export NCPERF_LANG=de
```

> **Synology:** Zuerst unter *Systemsteuerung › Terminal & SNMP* den SSH-Dienst aktivieren. Dann per SSH anmelden und `sudo -i` eingeben (Admin-Passwort), anschließend das Skript starten.

---

## Empfohlen: echte Web-PHP-Werte mit Token

Ohne weitere Angaben liest das Skript die PHP-Werte der **Kommandozeile**. Das ist das PHP, mit dem auch Cron und `occ` laufen. Die Nextcloud im Browser läuft aber über PHP-FPM bzw. Apache, auf der Synology mit dem **PHP-Profil der Web Station**. Dort können Version, Erweiterungen und Einstellungen ganz anders sein.

Mit einem Token holt sich das Skript über die Serverinfo-App von Nextcloud die Werte, die der Webserver **wirklich** nutzt. Dazu gehören Laufzeitdaten von OPcache und APCu: wie voll der Speicher ist und wie oft der Cache trifft.

### 1. Token einmalig setzen

Denk dir ein langes, zufälliges Wort aus (z. B. mit `openssl rand -hex 32`). Behandle es wie ein Passwort: Damit lassen sich Serverstatistiken abrufen.

```sh
# Synology, Nextcloud direkt in der Web Station (PHP-Version und Pfad anpassen):
sudo -u http /usr/local/bin/php84 /volume1/web/nextcloud/occ config:app:set serverinfo token --value DEINTOKEN

# Linux, native Installation:
sudo -u www-data php /var/www/nextcloud/occ config:app:set serverinfo token --value DEINTOKEN

# Docker (Containername anpassen):
sudo docker exec -u www-data nextcloud php occ config:app:set serverinfo token --value DEINTOKEN
```

Für das Token gibt es kein Feld in der Weboberfläche, es geht nur über `occ`. Falls die Serverinfo-App deaktiviert ist: `occ app:enable serverinfo`.

### 2. Mit Token prüfen

```sh
sudo sh ncperf.sh -t DEINTOKEN
```

Damit das Token nicht in der Prozessliste auftaucht, geht es auch als Umgebungsvariable:

```sh
sudo NCPERF_TOKEN=DEINTOKEN sh ncperf.sh
```

Im PHP-Abschnitt erscheint dann eine Tabelle **Web (Profil)** und **CLI (Cron)**. Unterschiede sind mit `≠` markiert.

---

## Alle Optionen

| Option | Bedeutung |
|---|---|
| `-t, --token TOKEN` | Serverinfo-Token für die echten Web-PHP-Werte (siehe oben), alternativ Umgebungsvariable `NCPERF_TOKEN` |
| `-u, --url URL` | Adresse der Nextcloud, z. B. `https://cloud.example.de`. Standard ist `overwrite.cli.url` aus der Konfiguration |
| `-c, --container NAME` | Docker-Container, falls mehrere Nextcloud-Container laufen |
| `-p, --path PFAD` | Nextcloud-Verzeichnis (dort liegt `occ`), falls es nicht gefunden wird |
| `--php BINARY` | PHP-Programm für native Installationen, z. B. `/usr/local/bin/php84` |
| `--disktest` | Zusätzlich die Geschwindigkeit des Speichers im Datenverzeichnis messen |
| `-o, --output DATEI` | Bericht unter diesem Namen speichern |
| `--no-report` | Keinen Bericht speichern, nur anzeigen |
| `-l, --lang de\|en` | Sprache der Ausgabe, alternativ Umgebungsvariable `NCPERF_LANG` |
| `-V, --version` | Version anzeigen |
| `-h, --help` | Hilfe anzeigen |

### Typische Aufrufe

```sh
# Synology mit Web Station und PHP 8.4
sudo sh ncperf.sh --php /usr/local/bin/php84 -t DEINTOKEN

# Docker auf Linux oder Synology, bestimmter Container
sudo sh ncperf.sh -c nextcloud -t DEINTOKEN

# Nextcloud an ungewöhnlichem Ort, URL von Hand angeben
sudo sh ncperf.sh -p /srv/www/cloud -u https://cloud.example.de

# Komplettprüfung inkl. Speichertest
sudo sh ncperf.sh -t DEINTOKEN --disktest
```

**Tipp zu `--php`:** Ohne Angabe nimmt das Skript das erste PHP, das es findet, zuerst ein einfaches `php`. Auf der Synology kann das eine andere Version sein als die deines Profils. Welche Versionen installiert sind, zeigt `ls /usr/local/bin/php*`.

**Tipp zu `-u`:** Steht in `overwrite.cli.url` nur `localhost` oder eine interne Adresse, misst der Test der Antwortzeiten nicht die echte Strecke. Gib dann die Adresse an, unter der du die Nextcloud im Browser öffnest.

---

## Was geprüft wird

| Bereich | Inhalt |
|---|---|
| **System** | Betriebssystem bzw. DSM-Version, CPU, RAM, Swap, Last, SSD/HDD, freier Platz im Datenverzeichnis, CPU-Benchmark (mit `--disktest` auch Schreibrate und Kleindatei-Test) |
| **Nextcloud** | Version, Debug- und Wartungsmodus, Loglevel und Größe der Logdatei, Caches (APCu/Redis), Dateisperren, Redis-Latenz und -Speicher, Hintergrundjobs und letzter Cron-Lauf, Anzahl Apps, Vorschaubilder, eingebaute Selbstprüfung |
| **PHP** | Version, `memory_limit`, OPcache, JIT, APCu, Erweiterungen, PHP-FPM-Prozesse und -Pool. Mit Token zusätzlich die echten Web-Werte und die Auslastung von OPcache/APCu |
| **Datenbank** | Typ und Version, Größe, Antwortzeit pro Abfrage. MariaDB/MySQL: Buffer-Pool, Trefferquote, `transaction_isolation`, Binlog, temporäre Tabellen. PostgreSQL: `shared_buffers`, Cache-Trefferquote |
| **Web** | Antwortzeiten von `status.php` und Login-Seite (je 5 Messungen), HTTP/2, Komprimierung |

Die Zugangsdaten für Datenbank und Redis liest das Skript aus der `config.php` und benutzt sie nur lokal. Im Bericht stehen keine Passwörter.

---

## Den Bericht lesen

Jede Zeile hat eine Markierung:

| Markierung | Bedeutung |
|---|---|
| `[ OK ]` | passt |
| `[INFO]` | Hinweis, kein Handlungsbedarf |
| `[WARN]` | bremst oder ist ungünstig, sollte angepasst werden |
| `[KRIT]` | bremst deutlich oder ist fehlerhaft, zuerst beheben (auf Englisch: `[CRIT]`) |

Am Ende stehen zwei Abschnitte:

- **Passende Werte für dieses System:** konkrete Einstellungen für PHP, PHP-FPM, Datenbank, Nextcloud und Redis. Sie sind aus RAM, CPU-Kernen und Datenbankgröße berechnet und lassen sich direkt übernehmen.
- **Zusammenfassung:** alle Probleme als nummerierte Liste, kritische zuerst. Arbeite sie von oben nach unten ab.

---

## Empfohlenes Vorgehen

1. **Ist-Zustand messen:** `sudo sh ncperf.sh -t DEINTOKEN`. Den Bericht aufheben.
2. **Kritische Punkte zuerst** beheben, dann die Warnungen.
3. **Immer nur wenige Dinge auf einmal ändern**, damit du siehst, was wirkt.
4. **Dienste neu starten**, sonst misst das Skript die alten Werte:
   - Synology Web Station: PHP-Profil speichern, Web Station bzw. Dienst neu starten
   - Linux: `systemctl restart php8.x-fpm` (bzw. Apache), bei Datenbank-Änderungen auch MariaDB/PostgreSQL
   - Docker: `docker compose restart`
5. **Erneut messen** und die Berichte vergleichen, vor allem die Antwortzeiten und die Werte zu OPcache.

> Laufzeitwerte wie Trefferquoten von OPcache, APCu und Datenbank sind erst aussagekräftig, wenn die Nextcloud nach einem Neustart eine Weile benutzt wurde. Direkt nach dem Neustart sind sie leer bzw. niedrig.

---

## Wo man die Werte ändert

| Was | Linux | Synology (Web Station) | Docker (offizielles Image) |
|---|---|---|---|
| PHP (Web) | `/etc/php/8.x/fpm/php.ini` bzw. `conf.d/` | *Web Station › Skriptspracheneinstellungen › PHP-Profil bearbeiten* | eigene `.ini` nach `/usr/local/etc/php/conf.d/` mounten oder Umgebungsvariablen wie `PHP_MEMORY_LIMIT` |
| PHP (Cron/CLI) | `/etc/php/8.x/cli/php.ini` | Cron im *Aufgabenplaner* mit dem richtigen Binary starten, z. B. `/usr/local/bin/php84` | gleich wie Web |
| PHP-FPM-Pool | `/etc/php/8.x/fpm/pool.d/www.conf` | im PHP-Profil (FPM-Einstellungen) | nur bei FPM-Image: `/usr/local/etc/php-fpm.d/` |
| Nextcloud | `config/config.php` | `config/config.php` | `config/config.php` im Volume |
| MariaDB | `/etc/mysql/mariadb.conf.d/` | MariaDB-10-Paket: `/var/packages/MariaDB10/etc/my.cnf` | `command:` oder eigene `.cnf` im DB-Container |

Die Pfade können je nach Distribution und Version leicht abweichen.

---

## Häufige Fragen

**„Keine Nextcloud gefunden“**
Pfad mit `-p` angeben (das Verzeichnis, in dem `occ` liegt) oder den Container mit `-c`.

**„config.php nicht lesbar“ / „PHP-Sammler lieferte keine Daten“**
Mit `sudo` bzw. als root starten. Bei nativer Installation ggf. das PHP-Programm mit `--php` angeben.

**„Serverinfo lehnt das Token ab“**
Token prüfen: `occ config:app:get serverinfo token`.

**„Serverinfo unter … nicht erreichbar“**
Die URL stimmt nicht oder ist vom Server aus nicht erreichbar. Mit `-u` die richtige Adresse angeben.

**„OPcache-Status nicht lesbar“**
In der PHP-Konfiguration ist `opcache.restrict_api` gesetzt. Dann fehlen nur die Laufzeitwerte, der Rest funktioniert.

**Viele `≠` in der PHP-Tabelle**
Web-Profil und Kommandozeile sind unterschiedlich eingerichtet. Für die Geschwindigkeit im Browser zählt die Spalte *Web*, für Cron und `occ` die Spalte *CLI*. Wichtig ist vor allem, dass beide dieselbe PHP-Version nutzen und dass die Erweiterungen für die konfigurierten Caches (APCu, Redis) in beiden geladen sind.

**Ändert `--disktest` etwas?**
Es legt kurz Testdateien im Ordner `.ncperf-tmp` im Datenverzeichnis an (256 MB plus 500 kleine Dateien) und löscht sie sofort wieder. Sonst bleibt alles unverändert.

---

## Voraussetzungen

- Linux oder Synology DSM 7 mit SSH-Zugang und `sudo`/root
- Nextcloud mit PHP-Kommandozeile (bei Docker: im Container vorhanden)
- `curl` für den Test der Antwortzeiten und den Abruf über Serverinfo
- unterstützte Datenbanken: MariaDB/MySQL, PostgreSQL (SQLite wird erkannt und als Problem gemeldet)

## Fehler melden und mitmachen

Fehler, Ideen und Verbesserungen gern als [Issue](https://github.com/soleil0815/ncperf/issues) oder Pull Request.

Hilfreich bei Fehlermeldungen: System (Linux-Distribution bzw. DSM-Version), Installationsart (Docker, nativ, Web Station) und der Bericht. **Vorher Domain und interne Adressen im Bericht unkenntlich machen.**

Beiträge sollten POSIX-`sh`-kompatibel bleiben (keine Bash-Erweiterungen). Neue Meldungen bitte immer in beiden Sprachen anlegen: `ok "Deutsch" "English"`, bei `warn`/`crit` zusätzlich die Empfehlung in beiden Sprachen. Jeder Push wird automatisch mit ShellCheck sowie `dash` und BusyBox `sh` geprüft.

## Haftung

Das Skript liest nur und ändert nichts. Die vorgeschlagenen Werte sind Richtwerte, berechnet aus RAM, CPU-Kernen und Datenbankgröße. Prüfe sie vor dem Übernehmen, mach vorher eine Sicherung und teste Änderungen am besten zuerst außerhalb des Produktivbetriebs. Nutzung auf eigene Verantwortung.

## Lizenz

[MIT](LICENSE) – frei nutzbar, veränderbar und weitergebbar, auch kommerziell. Der Lizenzhinweis muss erhalten bleiben.

*Nextcloud ist eine Marke der Nextcloud GmbH, Synology und DSM sind Marken der Synology Inc. Dieses Projekt steht in keiner Verbindung zu diesen Unternehmen.*
