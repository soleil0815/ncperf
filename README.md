# ncperf – Performance analysis for Nextcloud

[![ShellCheck](https://github.com/soleil0815/ncperf/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/soleil0815/ncperf/actions/workflows/shellcheck.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![POSIX sh](https://img.shields.io/badge/shell-POSIX%20sh-green.svg)

[Deutsch](README.de.md) · **English**

A single shell script (POSIX `sh`) that checks a Nextcloud instance for performance problems and suggests **settings that fit exactly this system**.

- runs on **Linux servers** and **Synology** (DSM)
- detects **Docker** (official image, AIO, linuxserver) and **native installations** (including Web Station) on its own
- needs no Bash and no extra tools, just the usual basics (`awk`, `sed`, `grep`, `curl`)
- **changes nothing** on the system and sends no data anywhere
- output in **English or German** (chosen automatically from the system language)

---

## Installation

There is nothing to install: download the script to the server or Synology and run it.

```sh
# download directly on the server
curl -fsSLO https://raw.githubusercontent.com/soleil0815/ncperf/main/ncperf.sh

# or via Git
git clone https://github.com/soleil0815/ncperf.git && cd ncperf
```

Alternatively download `ncperf.sh` on your own computer and copy it to the server with `scp` or File Station.

> As with any script that runs as root: have a quick look at it before the first run. It is a single, readable file.

## Quick start

The script must run **as root or with `sudo`**, otherwise it cannot read the configuration.

```sh
sudo sh ncperf.sh
```

The script finds Nextcloud by itself, reads its configuration and prints a report. It also saves the report as `ncperf_<date>_<time>.txt` in the current folder.

### Recommended call

For meaningful results pass everything explicitly: the token (see [below](#recommended-real-web-php-values-with-a-token)), the PHP binary for native installations, and the language.

```sh
# Synology with Web Station (adjust PHP version)
sudo sh ncperf.sh -t YOURTOKEN --php /usr/local/bin/php84 --lang en

# Docker (Linux or Synology)
sudo sh ncperf.sh -t YOURTOKEN --lang en
```

> **Careful with environment variables:** `sudo` usually discards the variables of your session. An `NCPERF_TOKEN` or `NCPERF_LANG` set earlier with `export` does **not** reach `sudo sh ncperf.sh`. The script then runs without a token (command-line values only) and in the default language. Put the variables right after `sudo` instead: `sudo NCPERF_TOKEN=YOURTOKEN NCPERF_LANG=en sh ncperf.sh` – or use the options `-t` and `--lang`.

**How to tell that everything arrived:** in the report the PHP section is called **"PHP – web (profile) and CLI (cron/occ)"** and shows a table. If it says "PHP (CLI values – FPM/Apache may differ)" instead, no token was used.

### Language

The output follows the system language (`LANG`): German for `de_*`, English otherwise. Over SSH and with `sudo` the language is often not set. The option is the most reliable way:

```sh
sudo sh ncperf.sh --lang en      # or --lang de
# or as a variable – right after sudo, not via export:
sudo NCPERF_LANG=en sh ncperf.sh
```

> **Synology:** first enable the SSH service under *Control Panel › Terminal & SNMP*. Then log in via SSH, run `sudo -i` (admin password) and start the script.

---

## Recommended: real web PHP values with a token

Without further options the script reads the PHP values of the **command line**. That is the PHP that cron and `occ` use. Nextcloud in the browser, however, runs through PHP-FPM or Apache – on Synology with the **Web Station PHP profile**. Version, extensions and settings can be completely different there.

With a token the script uses Nextcloud's Serverinfo app to fetch the values the web server **really** uses. This includes runtime data from OPcache and APCu: how full the memory is and how often the cache hits.

### 1. Set the token once

Pick a long random string (e.g. `openssl rand -hex 32`). Treat it like a password: it grants read access to server statistics.

```sh
# Synology, Nextcloud directly in Web Station (adjust PHP version and path):
sudo -u http /usr/local/bin/php84 /volume1/web/nextcloud/occ config:app:set serverinfo token --value YOURTOKEN

# Linux, native installation:
sudo -u www-data php /var/www/nextcloud/occ config:app:set serverinfo token --value YOURTOKEN

# Docker (adjust container name):
sudo docker exec -u www-data nextcloud php occ config:app:set serverinfo token --value YOURTOKEN
```

There is no field for the token in the web interface; it can only be set with `occ`. If the Serverinfo app is disabled: `occ app:enable serverinfo`.

### 2. Run with the token

```sh
sudo sh ncperf.sh -t YOURTOKEN
```

To keep the token out of the process list, pass it as an environment variable instead:

```sh
sudo NCPERF_TOKEN=YOURTOKEN sh ncperf.sh
```

The PHP section then shows a table **Web (profile)** vs. **CLI (cron)**. Differences are marked with `≠`.

---

## All options

| Option | Meaning |
|---|---|
| `-t, --token TOKEN` | Serverinfo token for the real web PHP values (see above), alternatively environment variable `NCPERF_TOKEN` |
| `-u, --url URL` | Nextcloud address, e.g. `https://cloud.example.com`. Default is `overwrite.cli.url` from the configuration |
| `-c, --container NAME` | Docker container, if several Nextcloud containers are running |
| `-p, --path PATH` | Nextcloud directory (where `occ` lives), if it is not found |
| `--php BINARY` | PHP binary for native installations, e.g. `/usr/local/bin/php84` |
| `--disktest` | Additionally measure storage speed in the data directory |
| `-o, --output FILE` | Save the report under this name |
| `--no-report` | Do not save a report, only display it |
| `-l, --lang de\|en` | Output language, alternatively environment variable `NCPERF_LANG` |
| `-V, --version` | Show version |
| `-h, --help` | Show help |

### Typical calls

```sh
# Synology with Web Station and PHP 8.4
sudo sh ncperf.sh --php /usr/local/bin/php84 -t YOURTOKEN

# Docker on Linux or Synology, specific container
sudo sh ncperf.sh -c nextcloud -t YOURTOKEN

# Nextcloud in an unusual location, URL set manually
sudo sh ncperf.sh -p /srv/www/cloud -u https://cloud.example.com

# Full check including storage test
sudo sh ncperf.sh -t YOURTOKEN --disktest
```

**About `--php`:** without it, the script uses the first PHP it finds, starting with a plain `php`. On Synology this can be a different version than your profile's. `ls /usr/local/bin/php*` shows which versions are installed.

**About `-u`:** if `overwrite.cli.url` only contains `localhost` or an internal address, the response-time test does not measure the real path. Use the address you open Nextcloud with in the browser.

---

## What is checked

| Area | Content |
|---|---|
| **System** | OS or DSM version, CPU, RAM, swap, load, SSD/HDD, free space in the data directory, CPU benchmark (with `--disktest` also write speed and small-file test) |
| **Nextcloud** | Version, debug and maintenance mode, log level and log file size, caches (APCu/Redis), file locking, Redis latency and memory, background jobs and last cron run, number of apps, previews, built-in setup checks |
| **PHP** | Version, `memory_limit`, OPcache, JIT, APCu, extensions, PHP-FPM processes and pool. With a token also the real web values and OPcache/APCu usage |
| **Database** | Type and version, size, response time per query. MariaDB/MySQL: buffer pool, hit rate, `transaction_isolation`, binlog, temporary tables. PostgreSQL: `shared_buffers`, cache hit rate |
| **Web** | Response times of `status.php` and the login page (5 measurements each), HTTP/2, compression |

The script reads the database and Redis credentials from `config.php` and only uses them locally. The report contains no passwords.

---

## Reading the report

Every line has a marker:

| Marker | Meaning |
|---|---|
| `[ OK ]` | fine |
| `[INFO]` | note, no action needed |
| `[WARN]` | slows things down or is unfavourable, should be adjusted |
| `[CRIT]` | slows things down a lot or is broken, fix first (German: `[KRIT]`) |

At the end there are two sections:

- **Suggested values for this system:** concrete settings for PHP, PHP-FPM, database, Nextcloud and Redis. They are calculated from RAM, CPU cores and database size and can be applied directly.
- **Summary:** all problems as a numbered list, critical ones first. Work through it from top to bottom.

---

## Recommended workflow

1. **Measure the current state:** `sudo sh ncperf.sh -t YOURTOKEN`. Keep the report.
2. **Fix critical items first**, then the warnings.
3. **Change only a few things at a time**, so you can see what helps.
4. **Restart services**, otherwise the script measures the old values:
   - Synology Web Station: save the PHP profile, restart Web Station or the service
   - Linux: `systemctl restart php8.x-fpm` (or Apache), and MariaDB/PostgreSQL after database changes
   - Docker: `docker compose restart`
5. **Measure again** and compare the reports, especially response times and OPcache values.

> Runtime values such as OPcache, APCu and database hit rates only become meaningful once Nextcloud has been used for a while after a restart. Right after a restart they are empty or low.

---

## Where to change the values

| What | Linux | Synology (Web Station) | Docker (official image) |
|---|---|---|---|
| PHP (web) | `/etc/php/8.x/fpm/php.ini` or `conf.d/` | *Web Station › Script Language Settings › edit PHP profile* | mount your own `.ini` into `/usr/local/etc/php/conf.d/` or use environment variables such as `PHP_MEMORY_LIMIT` |
| PHP (cron/CLI) | `/etc/php/8.x/cli/php.ini` | start cron in *Task Scheduler* with the right binary, e.g. `/usr/local/bin/php84` | same as web |
| PHP-FPM pool | `/etc/php/8.x/fpm/pool.d/www.conf` | in the PHP profile (FPM settings) | FPM image only: `/usr/local/etc/php-fpm.d/` |
| Nextcloud | `config/config.php` | `config/config.php` | `config/config.php` in the volume |
| MariaDB | `/etc/mysql/mariadb.conf.d/` | MariaDB 10 package: `/var/packages/MariaDB10/etc/my.cnf` | `command:` or your own `.cnf` in the DB container |

Paths may differ slightly depending on distribution and version.

---

## FAQ

**Wrong language / PHP values don't match my profile**
Usually the token or language did not arrive, typically because they were set with `export` and `sudo` discarded them. Use the options `-t` and `--lang`, or put the variables right after `sudo` (see [Recommended call](#recommended-call)). For native installations also pass your profile's PHP with `--php`.

**"No Nextcloud found"**
Set the path with `-p` (the directory containing `occ`) or the container with `-c`.

**"config.php not readable" / "PHP collector returned no data"**
Run with `sudo` or as root. For native installations, set the PHP binary with `--php` if needed.

**"Serverinfo rejected the token"**
Check the token: `occ config:app:get serverinfo token`.

**"Serverinfo not reachable at …"**
The URL is wrong or not reachable from the server. Set the correct address with `-u`.

**"OPcache status not readable"**
`opcache.restrict_api` is set in the PHP configuration. Only the runtime values are missing then; everything else works.

**Many `≠` in the PHP table**
Web profile and command line are configured differently. For browser speed the *Web* column counts, for cron and `occ` the *CLI* column. Most important: both should use the same PHP version, and the extensions for the configured caches (APCu, Redis) should be loaded in both.

**Does `--disktest` change anything?**
It briefly creates test files in `.ncperf-tmp` inside the data directory (256 MB plus 500 small files) and deletes them immediately. Nothing else is touched.

---

## Requirements

- Linux or Synology DSM 7 with SSH access and `sudo`/root
- Nextcloud with PHP CLI (with Docker: available in the container)
- `curl` for the response-time test and the Serverinfo request
- supported databases: MariaDB/MySQL, PostgreSQL (SQLite is detected and reported as a problem)

## Reporting bugs and contributing

Bugs, ideas and improvements are welcome as an [issue](https://github.com/soleil0815/ncperf/issues) or pull request – in English or German.

Helpful for bug reports: system (Linux distribution or DSM version), installation type (Docker, native, Web Station) and the report. **Mask your domain and internal addresses in the report first.**

Contributions should stay POSIX `sh` compatible (no Bash extensions). Please add every new message in both languages: `ok "Deutsch" "English"`, and for `warn`/`crit` also the recommendation in both languages. Every push is automatically checked with ShellCheck, `dash` and BusyBox `sh`.

## Disclaimer

The script only reads and changes nothing. The suggested values are guidelines calculated from RAM, CPU cores and database size. Review them before applying, make a backup first and ideally test changes outside of production. Use at your own risk.

## License

[MIT](LICENSE) – free to use, modify and distribute, including commercially. The license notice must be kept.

*Nextcloud is a trademark of Nextcloud GmbH; Synology and DSM are trademarks of Synology Inc. This project is not affiliated with these companies.*
