# Changelog

[Deutsch](CHANGELOG.de.md) · **English**

All notable changes to ncperf. Version numbers follow [Semantic Versioning](https://semver.org/).

## 1.3.1 – 2026-10-30

### Fixed
- Native installations (e.g. Synology Web Station): OPcache missing on the command line is no longer reported as critical – it is irrelevant for cron; the web status is shown with `-t TOKEN`.
- Suggestions never go below the current values (e.g. `memory_limit`, `apc.shm_size`, OPcache sizes).
- `pm.max_children` is calculated with at least 100 MB per process under load and capped at 8 per CPU core (previously up to 200).
- `innodb_buffer_pool_size` suggestion at least 512 MB on systems with 8 GB RAM or more.

### Added
- Detects the PHP version of the PHP-FPM processes (e.g. `php-fpm85`) and warns if the command line uses a different version.
- Clear message when the token placeholder from the docs (`YOURTOKEN`/`DEINTOKEN`) is used.
- Synology note shows the detected PHP version instead of a fixed `php84`.

## 1.3.0 – 2026-10-30

### Added
- Output in English and German, chosen from the system language (`LANG`), switchable with `-l/--lang de|en` or `NCPERF_LANG`.
- Option `-V/--version`.
- Bilingual documentation (`README.md` English, `README.de.md` German).

### Fixed
- Docs: `sudo` discards variables set via `export` (`NCPERF_TOKEN`, `NCPERF_LANG`) – correct call and how to verify added.
- Responses with HTTP error codes (e.g. 401, 404, 500) in the response-time test are no longer rated "OK".

## 1.2.0 – 2026-10-30

### Added
- Option `-t/--token`: reads the PHP values the web server really uses via the Nextcloud Serverinfo app (e.g. the Synology Web Station PHP profile).
- Comparison table "Web (profile)" vs. "CLI (cron)" with differences marked.
- OPcache and APCu runtime values: fill level, hit rate, interned strings buffer, number of cached scripts.
- Warning when APCu or Redis is configured but not loaded in the web profile.
- Warning when cron/occ uses a different PHP version than the web server.
- Token alternatively via the environment variable `NCPERF_TOKEN`.

### Changed
- The project is now called **ncperf** (formerly nc-perfcheck).

## 1.1.0 – 2026-10-30

### Changed
- Rewritten in POSIX `sh`; runs with dash, BusyBox ash and bash.

### Fixed
- A wrong path with `-p` is reported clearly; no report is saved after an abort.

## 1.0.0 – 2026-10-30

### Added
- First version: checks system, Nextcloud, PHP, PHP-FPM, database (MariaDB/MySQL, PostgreSQL), Redis and web response times.
- Automatic detection of Docker containers and native installations.
- Suggested settings based on RAM, CPU and database size.
- Optional storage test (`--disktest`).
