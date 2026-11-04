# Security

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

