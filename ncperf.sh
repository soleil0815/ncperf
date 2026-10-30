#!/bin/sh
# =============================================================================
#  ncperf – Nextcloud performance analysis / Nextcloud-Performance-Analyse
#  https://github.com/soleil0815/ncperf   ·   License/Lizenz: MIT
#
#  POSIX sh (sh/dash/ash/bash) · Linux & Synology · native or Docker
#  Read-only: changes nothing on the system. / Ändert nichts am System.
#
#  Usage / Aufruf:   sudo sh ncperf.sh [options]      ->  sh ncperf.sh --help
# =============================================================================
VERSION="1.3.1"

CONTAINER=""; NCPATH=""; URL=""; PHPBIN=""; DISKTEST=0; TOKEN="${NCPERF_TOKEN:-}"
REPORT="ncperf_$(date +%Y%m%d_%H%M).txt"; RUNS=5

# ---------- Sprache / language ----------------------------------------------
case "${NCPERF_LANG:-${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}}" in
  de*|DE*) LNG=de ;;
  *) LNG=en ;;
esac
# m DE EN  -> Text in der aktuellen Sprache / text in the current language
m() { if [ "$LNG" = de ]; then printf '%s' "$1"; else printf '%s' "$2"; fi; }

ESC=$(printf '\033')
if [ -t 1 ]; then R="${ESC}[31m"; Y="${ESC}[33m"; G="${ESC}[32m"; B="${ESC}[36m"; W="${ESC}[1m"; N="${ESC}[0m"
else R=""; Y=""; G=""; B=""; W=""; N=""; fi

# die DE EN
die() { printf '%s%s:%s %s\n' "$R" "$(m Fehler Error)" "$N" "$(m "$1" "$2")"; [ -n "${TMP:-}" ] && : > "$TMP/failed"; exit 1; }
need() { [ "$1" -ge 2 ] || die "Option $2 braucht einen Wert." "Option $2 requires a value."; }

usage() {
  if [ "$LNG" = de ]; then cat <<'EOF'
ncperf – Nextcloud-Performance-Analyse (Linux & Synology, nativ oder Docker)
Ändert nichts am System. Als root bzw. mit sudo starten.

Aufruf:
  sudo sh ncperf.sh                        automatische Erkennung
  sudo sh ncperf.sh -t TOKEN               mit echten Web-PHP-Werten (empfohlen)
  sudo sh ncperf.sh -c nextcloud           bestimmten Docker-Container prüfen
  sudo sh ncperf.sh -p /var/www/nextcloud  Installationspfad angeben

Optionen:
  -t, --token TOKEN     Serverinfo-Token: PHP-Werte, die der Webserver wirklich
                        nutzt (z.B. Web-Station-Profil). Einmalig setzen mit
                        occ config:app:set serverinfo token --value TOKEN
                        Alternativ: Umgebungsvariable NCPERF_TOKEN
  -u, --url URL         Adresse der Nextcloud (Standard: overwrite.cli.url)
  -c, --container NAME  Docker-Container mit Nextcloud
  -p, --path PFAD       Nextcloud-Verzeichnis (dort liegt "occ")
      --php BINARY      PHP-Programm (nativ), z.B. /usr/local/bin/php84
      --disktest        Speichertest im Datenverzeichnis
  -o, --output DATEI    Bericht speichern (Standard: ncperf_<Datum>.txt)
      --no-report       Keinen Bericht speichern
  -l, --lang de|en      Sprache (Standard: Systemsprache, sonst Englisch;
                        alternativ Umgebungsvariable NCPERF_LANG)
  -V, --version         Version anzeigen
  -h, --help            Diese Hilfe
EOF
  else cat <<'EOF'
ncperf – Nextcloud performance analysis (Linux & Synology, native or Docker)
Read-only: changes nothing on the system. Run as root or with sudo.

Usage:
  sudo sh ncperf.sh                        auto-detect everything
  sudo sh ncperf.sh -t TOKEN               include real web PHP values (recommended)
  sudo sh ncperf.sh -c nextcloud           check a specific Docker container
  sudo sh ncperf.sh -p /var/www/nextcloud  set the installation path

Options:
  -t, --token TOKEN     Serverinfo token: PHP values the web server really uses
                        (e.g. a Synology Web Station profile). Set once with
                        occ config:app:set serverinfo token --value TOKEN
                        Alternatively: environment variable NCPERF_TOKEN
  -u, --url URL         Nextcloud address (default: overwrite.cli.url)
  -c, --container NAME  Docker container running Nextcloud
  -p, --path PATH       Nextcloud directory (where "occ" lives)
      --php BINARY      PHP binary (native), e.g. /usr/local/bin/php84
      --disktest        Storage test in the data directory
  -o, --output FILE     Save report (default: ncperf_<date>.txt)
      --no-report       Do not save a report
  -l, --lang de|en      Language (default: system language, else English;
                        alternatively environment variable NCPERF_LANG)
  -V, --version         Show version
  -h, --help            This help
EOF
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    -l|--lang)      need $# "$1"; case "$2" in de*|DE*) LNG=de ;; en*|EN*) LNG=en ;;
                      *) die "Unbekannte Sprache: $2 (de oder en)" "Unknown language: $2 (de or en)" ;; esac; shift 2 ;;
    -c|--container) need $# "$1"; CONTAINER="$2"; shift 2 ;;
    -p|--path)      need $# "$1"; NCPATH="${2%/}"; shift 2 ;;
    -u|--url)       need $# "$1"; URL="${2%/}"; shift 2 ;;
    --php)          need $# "$1"; PHPBIN="$2"; shift 2 ;;
    --disktest)     DISKTEST=1; shift ;;
    -t|--token)     need $# "$1"; TOKEN="$2"; shift 2 ;;
    -o|--output)    need $# "$1"; REPORT="$2"; shift 2 ;;
    --no-report)    REPORT=""; shift ;;
    -V|--version)   echo "ncperf $VERSION"; exit 0 ;;
    -h|--help)      HELP=1; shift ;;
    *) die "Unbekannte Option: $1 (siehe --help)" "Unknown option: $1 (see --help)" ;;
  esac
done
[ "${HELP:-0}" = 1 ] && { usage; exit 0; }

TMP=$(mktemp -d 2>/dev/null) || { TMP="/tmp/ncperf.$$"; mkdir -p "$TMP" || exit 1; }
trap 'rm -rf "$TMP"' EXIT INT TERM
: > "$TMP/crit"; : > "$TMP/warn"

# ---------- Hilfsfunktionen / helpers ----------------------------------------
# section DE EN | ok DE EN | info DE EN | warn DE EN [EMPF_DE REC_EN] | crit ...
section() { printf '\n%s== %s ==%s\n' "$W" "$(m "$1" "$2")" "$N"; }
ok()   { printf '  %s[ OK ]%s %s\n' "$G" "$N" "$(m "$1" "$2")"; }
info() { printf '  %s[INFO]%s %s\n' "$B" "$N" "$(m "$1" "$2")"; }
warn() { printf '  %s[WARN]%s %s\n' "$Y" "$N" "$(m "$1" "$2")"
         if [ $# -ge 4 ]; then m "$3" "$4"; else m "$1" "$2"; fi >> "$TMP/warn"; echo >> "$TMP/warn"; }
crit() { printf '  %s[%s]%s %s\n' "$R" "$(m KRIT CRIT)" "$N" "$(m "$1" "$2")"
         if [ $# -ge 4 ]; then m "$3" "$4"; else m "$1" "$2"; fi >> "$TMP/crit"; echo >> "$TMP/crit"; }

is_on()  { case "$1" in 1|on|On|ON|true|True|TRUE|yes|Yes|YES) return 0 ;; esac; return 1; }
is_num() { case "$1" in ''|-|*[!0-9-]*|?*-*) return 1 ;; esac; return 0; }
gt()     { awk -v a="$1" -v b="$2" 'BEGIN{exit !(a+0>b+0)}'; }   # a > b (Kommazahlen/decimals)
# PHP-Kurzschreibweise / PHP shorthand (512M, 1G, 128K, bytes) -> MB ; -1 = unlimited
to_mb() {
  _s=$(printf '%s' "$1" | tr -d ' ' | tr 'a-z' 'A-Z')
  case "$_s" in
    '') echo 0 ;;
    -1) echo -1 ;;
    *G) _s=${_s%G}; is_num "$_s" && echo $((_s*1024)) || echo 0 ;;
    *M) _s=${_s%M}; is_num "$_s" && echo "$_s" || echo 0 ;;
    *K) _s=${_s%K}; is_num "$_s" && echo $((_s/1024)) || echo 0 ;;
    *)  is_num "$_s" && echo $((_s/1048576)) || echo 0 ;;
  esac
}
hum() { awk -v b="${1:-0}" 'BEGIN{split("B KB MB GB TB",u);i=1;while(b>=1024&&i<5){b/=1024;i++};printf "%.1f %s",b,u[i]}'; }
# Wert aus den gesammelten Daten / value from collected data
v() { awk -v k="$1" 'index($0,k"=")==1{print substr($0,length(k)+2); exit}' "$TMP/data"; }

# ---------- PHP-Sammler / PHP collector (runs inside the Nextcloud environment)
cat > "$TMP/collector.php" <<'PHP'
<?php
error_reporting(0); ini_set('display_errors', '0');
$nc = $argv[1] ?? '/var/www/html'; $disk = ($argv[2] ?? '') === 'disk';
function out($k, $v) { if (is_bool($v)) $v = $v ? 'true' : 'false'; if (is_array($v)) $v = json_encode($v);
  echo $k, '=', str_replace(["\n", "\r"], ' ', (string)$v), "\n"; }
out('php.version', PHP_VERSION);
foreach (['memory_limit','max_execution_time','upload_max_filesize','post_max_size','output_buffering',
  'opcache.enable','opcache.enable_cli','opcache.memory_consumption','opcache.interned_strings_buffer',
  'opcache.max_accelerated_files','opcache.revalidate_freq','opcache.validate_timestamps','opcache.save_comments',
  'opcache.jit','opcache.jit_buffer_size','apc.enabled','apc.enable_cli','apc.shm_size','realpath_cache_size'] as $i)
  out("ini.$i", ini_get($i));
foreach (['apcu','redis','memcached','Zend OPcache','imagick','igbinary','intl','gmp','bcmath','sysvsem'] as $e)
  out('ext.' . str_replace(' ', '_', $e), extension_loaded($e));
$t = microtime(true); $x = 0; for ($i = 0; $i < 300000; $i++) { $x += strlen(md5((string)$i)) % 7; $a[$i % 100] = $x; }
out('bench.cpu_ms', round((microtime(true) - $t) * 1000));

$CONFIG = [];
if (!@include "$nc/config/config.php") { out('error', 'config_unreadable'); exit; }
$cfg = $CONFIG;
foreach (glob("$nc/config/*.config.php") ?: [] as $f) { $CONFIG = []; @include $f; if (is_array($CONFIG)) $cfg = array_merge($cfg, $CONFIG); }
foreach (['version','dbtype','dbhost','memcache.local','memcache.distributed','memcache.locking','filelocking.enabled',
  'loglevel','debug','logfile','log_type','log_rotate_size','datadirectory','maintenance','enable_previews','preview_max_x',
  'preview_max_y','preview_imaginary_url','overwrite.cli.url','filesystem_check_changes','installed'] as $k)
  out("cfg.$k", array_key_exists($k, $cfg) ? $cfg[$k] : '');
out('cfg.redis.host', $cfg['redis']['host'] ?? ''); out('cfg.redis.port', $cfg['redis']['port'] ?? '');

function hp($h, $port) { $sock = ''; $p = $port;
  if ($h !== '' && $h[0] === '/') return ['', '', $h];
  if (strpos($h, ':') !== false) { [$h, $r] = explode(':', $h, 2); if (ctype_digit($r)) $p = $r; else $sock = $r; }
  return [$h ?: 'localhost', $p, $sock]; }

$type = $cfg['dbtype'] ?? 'sqlite'; $pre = $cfg['dbtableprefix'] ?? 'oc_'; $db = $cfg['dbname'] ?? 'nextcloud';
try {
  if ($type === 'mysql' || $type === 'pgsql') {
    [$h, $p, $s] = hp($cfg['dbhost'] ?? 'localhost', (string)($cfg['dbport'] ?? ''));
    if ($type === 'mysql') $dsn = $s ? "mysql:unix_socket=$s;dbname=$db" : "mysql:host=$h" . ($p ? ";port=$p" : '') . ";dbname=$db";
    else $dsn = 'pgsql:host=' . ($s ? dirname($s) : $h) . ($p ? ";port=$p" : '') . ";dbname=$db";
    $pdo = new PDO($dsn, $cfg['dbuser'] ?? '', $cfg['dbpassword'] ?? '', [PDO::ATTR_TIMEOUT => 5, PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
    $t = microtime(true); for ($i = 0; $i < 50; $i++) $pdo->query('SELECT 1')->fetchAll();
    out('db.latency_ms', round((microtime(true) - $t) * 1000 / 50, 2));
    $q = function ($sql) use ($pdo) { try { return $pdo->query($sql)->fetchAll(PDO::FETCH_NUM); } catch (Throwable $e) { return []; } };
    if ($type === 'mysql') {
      out('db.version', $q('SELECT VERSION()')[0][0] ?? '');
      foreach ($q("SHOW VARIABLES WHERE Variable_name IN ('innodb_buffer_pool_size','innodb_log_file_size','innodb_redo_log_capacity',
        'innodb_flush_log_at_trx_commit','max_connections','tmp_table_size','transaction_isolation','tx_isolation','binlog_format',
        'log_bin','innodb_io_capacity','performance_schema','query_cache_type','innodb_flush_method')") as $r) out('my.' . $r[0], $r[1]);
      foreach ($q("SHOW GLOBAL STATUS WHERE Variable_name IN ('Innodb_buffer_pool_read_requests','Innodb_buffer_pool_reads',
        'Threads_connected','Max_used_connections','Slow_queries','Uptime','Created_tmp_disk_tables','Created_tmp_tables')") as $r) out('my.' . $r[0], $r[1]);
      out('db.size', $q("SELECT SUM(data_length+index_length) FROM information_schema.tables WHERE table_schema=DATABASE()")[0][0] ?? '');
      out('db.filecache_rows', $q("SELECT table_rows FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name='{$pre}filecache'")[0][0] ?? '');
    } else {
      out('db.version', $q('SHOW server_version')[0][0] ?? '');
      foreach (['shared_buffers','effective_cache_size','work_mem','maintenance_work_mem','max_connections','random_page_cost'] as $n) {
        $r = $q("SELECT current_setting('$n'), CASE WHEN '$n' IN ('max_connections','random_page_cost') THEN 0 ELSE pg_size_bytes(current_setting('$n')) END");
        out("pg.$n", $r[0][0] ?? ''); out("pg.{$n}_bytes", $r[0][1] ?? ''); }
      out('db.size', $q('SELECT pg_database_size(current_database())')[0][0] ?? '');
      out('db.filecache_rows', $q("SELECT reltuples::bigint FROM pg_class WHERE relname='{$pre}filecache'")[0][0] ?? '');
      out('pg.hit_ratio', $q('SELECT round(sum(blks_hit)*100.0/nullif(sum(blks_hit)+sum(blks_read),0),2) FROM pg_stat_database WHERE datname=current_database()')[0][0] ?? '');
    }
  }
} catch (Throwable $e) { out('db.error', $e->getMessage()); }

if (extension_loaded('redis') && !empty($cfg['redis']['host'])) {
  try {
    $rc = $cfg['redis']; $r = new Redis(); $h = $rc['host'];
    $p = ($h[0] === '/') ? 0 : (int)($rc['port'] ?? 6379);
    $r->connect($h, $p, 3.0);
    if (!empty($rc['password'])) $r->auth(!empty($rc['user']) ? [$rc['user'], $rc['password']] : $rc['password']);
    if (isset($rc['dbindex'])) $r->select((int)$rc['dbindex']);
    $t = microtime(true); for ($i = 0; $i < 100; $i++) $r->ping(); out('redis.latency_ms', round((microtime(true) - $t) * 10, 3));
    $in = $r->info();
    foreach (['redis_version','used_memory','used_memory_human','maxmemory','maxmemory_policy','evicted_keys','keyspace_hits','keyspace_misses'] as $k)
      out("redis.$k", $in[$k] ?? '');
  } catch (Throwable $e) { out('redis.error', $e->getMessage()); }
}

if ($disk && !empty($cfg['datadirectory']) && is_writable($cfg['datadirectory'])) {
  $d = rtrim($cfg['datadirectory'], '/') . '/.ncperf-tmp'; @mkdir($d);
  $buf = random_bytes(1048576); $f = fopen("$d/big", 'w'); $t = microtime(true);
  for ($i = 0; $i < 256; $i++) fwrite($f, $buf);
  fflush($f); if (function_exists('fsync')) fsync($f); fclose($f);
  out('disk.write_mbs', round(256 / (microtime(true) - $t), 1)); @unlink("$d/big");
  $t = microtime(true);
  for ($i = 0; $i < 500; $i++) { file_put_contents("$d/s$i", $buf[0] . $i); }
  for ($i = 0; $i < 500; $i++) { @unlink("$d/s$i"); }
  out('disk.smallfiles_ms', round((microtime(true) - $t) * 1000)); @rmdir($d);
}
PHP

# ---------- Serverinfo-Auswertung / serverinfo parser (web PHP) -----------
cat > "$TMP/webparse.php" <<'PHP'
$j = json_decode($raw, true);
function out($k, $v) { if (is_bool($v)) $v = $v ? 'true' : 'false'; echo $k, '=', str_replace(["\n", "\r"], ' ', (string)$v), "\n"; }
$mb = function ($b) { return is_numeric($b) ? ($b < 0 ? -1 : round($b / 1048576)) : ''; };
$d = $j['ocs']['data'] ?? null;
if (!is_array($d) || !isset($d['server']['php'])) { out('web.error', 'nodata'); exit; }
$p = $d['server']['php'];
out('web.webserver', $d['server']['webserver'] ?? '');
out('web.php.version', $p['version'] ?? '');
out('web.memory_limit_mb', $mb($p['memory_limit'] ?? ''));
out('web.max_execution_time', $p['max_execution_time'] ?? '');
out('web.upload_max_mb', $mb($p['upload_max_filesize'] ?? ''));
if (!empty($p['extensions']) && is_array($p['extensions'])) {
  $l = array_map('strtolower', $p['extensions']); out('web.ext_known', true);
  foreach (['apcu','redis','imagick','igbinary','intl','gmp','bcmath'] as $e) out("web.ext.$e", in_array($e, $l));
}
$o = $p['opcache'] ?? [];
if (is_array($o) && $o) {
  out('web.opcache.enabled', !empty($o['opcache_enabled'])); out('web.opcache.full', !empty($o['cache_full']));
  $m = $o['memory_usage'] ?? []; $u = $m['used_memory'] ?? 0; $f = $m['free_memory'] ?? 0; $w = $m['wasted_memory'] ?? 0; $t = $u + $f + $w;
  if ($t > 0) { out('web.opcache.mem_mb', round($t / 1048576)); out('web.opcache.free_pct', round($f * 100 / $t, 1)); out('web.opcache.wasted_pct', round($w * 100 / $t, 1)); }
  $s = $o['interned_strings_usage'] ?? [];
  if (!empty($s['buffer_size'])) { out('web.opcache.str_mb', round($s['buffer_size'] / 1048576)); out('web.opcache.str_free_pct', round(($s['free_memory'] ?? 0) * 100 / $s['buffer_size'], 1)); }
  $st = $o['opcache_statistics'] ?? [];
  out('web.opcache.scripts', $st['num_cached_scripts'] ?? ''); out('web.opcache.max_keys', $st['max_cached_keys'] ?? '');
  out('web.opcache.hits', $st['hits'] ?? ''); out('web.opcache.hit_rate', isset($st['opcache_hit_rate']) ? round($st['opcache_hit_rate'], 2) : '');
  $jt = $o['jit'] ?? []; out('web.jit.on', !empty($jt['enabled']) && !empty($jt['on'])); out('web.jit.mb', isset($jt['buffer_size']) ? round($jt['buffer_size'] / 1048576) : '');
} else out('web.opcache.enabled', 'unknown');
$a = $p['apcu'] ?? [];
if (!empty($a['cache']) && is_array($a['cache'])) {
  $c = $a['cache']; out('web.apcu.hits', $c['num_hits'] ?? 0); out('web.apcu.misses', $c['num_misses'] ?? 0);
  $sm = $a['sma'] ?? []; $tot = ($sm['num_seg'] ?? 1) * ($sm['seg_size'] ?? 0);
  if ($tot > 0) { out('web.apcu.mb', round($tot / 1048576)); out('web.apcu.free_pct', round(($sm['avail_mem'] ?? 0) * 100 / $tot, 1)); }
}
PHP

# =============================================================================
main() {
# ---------- Umgebung erkennen / detect environment ---------------------------
DOCKER=""
for d in docker /usr/local/bin/docker /usr/bin/docker; do
  if command -v "$d" >/dev/null 2>&1; then DOCKER=$(command -v "$d"); break; fi
done
CPATHS="/var/www/html /app/www/public /config/www/nextcloud"
CANDIDATES="/var/www/html /var/www/nextcloud /var/www/html/nextcloud /app/www/public /config/www/nextcloud \
/usr/share/nginx/nextcloud /usr/share/webapps/nextcloud /srv/nextcloud /srv/www/nextcloud \
/volume1/web/nextcloud /volume2/web/nextcloud /volume1/docker/nextcloud/html /var/snap/nextcloud/current/nextcloud"

if [ -z "$NCPATH" ] && [ -z "$CONTAINER" ] && [ -n "$DOCKER" ]; then
  for c in $($DOCKER ps --format '{{.Names}}' 2>/dev/null); do
    for p in $CPATHS; do
      if $DOCKER exec "$c" test -f "$p/occ" 2>/dev/null; then CONTAINER="$c"; NCPATH="$p"; break 2; fi
    done
  done
fi
if [ -n "$CONTAINER" ]; then
  [ -z "$DOCKER" ] && die "docker wurde nicht gefunden." "docker not found."
  if [ -z "$NCPATH" ]; then
    for p in $CPATHS; do
      if $DOCKER exec "$CONTAINER" test -f "$p/occ" 2>/dev/null; then NCPATH="$p"; break; fi
    done
    [ -z "$NCPATH" ] && die "Im Container '$CONTAINER' wurde keine Nextcloud gefunden (-p angeben)." \
                            "No Nextcloud found in container '$CONTAINER' (use -p)."
  fi
fi
if [ -z "$NCPATH" ]; then
  for p in $CANDIDATES; do
    if [ -f "$p/occ" ] && [ -f "$p/config/config.php" ]; then NCPATH="$p"; break; fi
  done
fi
[ -z "$NCPATH" ] && die "Keine Nextcloud gefunden. Bitte mit -p PFAD oder -c CONTAINER angeben." \
                        "No Nextcloud found. Please use -p PATH or -c CONTAINER."
inx "test -f '$NCPATH/occ' && test -f '$NCPATH/config/config.php'" 2>/dev/null || \
  die "Unter '$NCPATH' liegt keine Nextcloud (occ/config.php fehlt)." "No Nextcloud at '$NCPATH' (occ/config.php missing)."

WEBUSER=$(inx "stat -c %U '$NCPATH/config/config.php' 2>/dev/null || ls -ld '$NCPATH/config/config.php' | awk '{print \$3}'")
[ -z "$WEBUSER" ] && die "config.php nicht lesbar – bitte als root/sudo starten." "config.php not readable – please run as root/sudo."

if [ -z "$CONTAINER" ]; then
  if [ -z "$PHPBIN" ]; then
    for b in php php84 php83 php82 php81 /usr/local/bin/php84 /usr/local/bin/php83 /usr/local/bin/php82 /usr/local/bin/php81; do
      if command -v "$b" >/dev/null 2>&1; then PHPBIN=$(command -v "$b"); break; fi
    done
  fi
  [ -z "$PHPBIN" ] && die "Kein PHP-Binary gefunden (--php angeben)." "No PHP binary found (use --php)."
  SUDO=""
  if [ "$(id -un)" != "$WEBUSER" ]; then
    command -v sudo >/dev/null 2>&1 || die "sudo fehlt – bitte als Benutzer '$WEBUSER' starten." "sudo missing – please run as user '$WEBUSER'."
    SUDO="sudo -u $WEBUSER"
  fi
fi

# ---------- Daten sammeln / collect data -------------------------------------
printf '%sncperf v%s – Nextcloud Performance-Check%s  –  %s\n' "$W" "$VERSION" "$N" "$(date "$(m '+%d.%m.%Y %H:%M' '+%Y-%m-%d %H:%M')")"
if [ -n "$CONTAINER" ]; then echo "$(m "Docker-Container: $CONTAINER  |  Pfad: $NCPATH  |  Benutzer: $WEBUSER" "Docker container: $CONTAINER  |  Path: $NCPATH  |  User: $WEBUSER")"
else echo "$(m "Nativ: $NCPATH  |  PHP: $PHPBIN  |  Benutzer: $WEBUSER" "Native: $NCPATH  |  PHP: $PHPBIN  |  User: $WEBUSER")"; fi
m "Sammle Daten … (kann 30–60 Sekunden dauern)" "Collecting data … (may take 30–60 seconds)"; echo

DARG=""; [ "$DISKTEST" = 1 ] && DARG="disk"
run_php "$NCPATH" $DARG < "$TMP/collector.php" > "$TMP/data" 2>/dev/null
[ -z "$(v php.version)" ] && die "PHP-Sammler lieferte keine Daten (Rechte? PHP-Binary?)." "PHP collector returned no data (permissions? PHP binary?)."
[ "$(v error)" = "config_unreadable" ] && die "config.php konnte nicht gelesen werden." "config.php could not be read."

[ -z "$URL" ] && URL=$(v cfg.overwrite.cli.url); URL=${URL%/}
WEBMSG_DE=""; WEBMSG_EN=""
webmsg() { WEBMSG_DE="$1"; WEBMSG_EN="$2"; }
if [ -n "$TOKEN" ]; then
  if [ -z "$URL" ]; then webmsg "Kein Abruf der Web-Werte: URL fehlt (mit -u angeben)." "Web values not fetched: URL missing (use -u)."
  elif ! command -v curl >/dev/null 2>&1; then webmsg "Kein Abruf der Web-Werte: curl fehlt." "Web values not fetched: curl missing."
  else
    SIC=$(curl -sk --max-time 30 -o "$TMP/si.json" -w '%{http_code}' -H "NC-Token: $TOKEN" -H 'OCS-APIRequest: true' \
      "$URL/ocs/v2.php/apps/serverinfo/api/v1/info?format=json&skipApps=true&skipUpdate=true" 2>/dev/null)
    case "$SIC" in
      200) { printf '<?php\n$raw = <<<'"'"'NCPCJSONEND'"'"'\n'; cat "$TMP/si.json"; printf '\nNCPCJSONEND;\n'; cat "$TMP/webparse.php"; } \
             | run_php >> "$TMP/data" 2>/dev/null
           [ -n "$(v web.error)" ] && webmsg "Web-Werte nicht auswertbar: Antwort enthält keine PHP-Daten." "Web values not usable: response contains no PHP data." ;;
      401|403) case "$TOKEN" in
                 DEINTOKEN|YOURTOKEN|TOKEN|GEHEIM|DEIN_TOKEN|YOUR_TOKEN)
                   webmsg "'$TOKEN' ist der Platzhalter aus der Anleitung – dein echtes Token angeben (occ config:app:get serverinfo token)." \
                          "'$TOKEN' is the placeholder from the docs – use your real token (occ config:app:get serverinfo token)." ;;
                 *) webmsg "Serverinfo lehnt das Token ab – Token prüfen (occ config:app:get serverinfo token)." \
                      "Serverinfo rejected the token – check it (occ config:app:get serverinfo token)." ;;
               esac ;;
      404) webmsg "Serverinfo-App nicht gefunden – aktivieren mit: occ app:enable serverinfo" \
                  "Serverinfo app not found – enable it with: occ app:enable serverinfo" ;;
      000|'') webmsg "Serverinfo unter $URL nicht erreichbar (URL mit -u prüfen)." "Serverinfo not reachable at $URL (check URL with -u)." ;;
      *) webmsg "Serverinfo antwortet mit HTTP $SIC." "Serverinfo responded with HTTP $SIC." ;;
    esac
  fi
fi

# ---------- System -----------------------------------------------------------
section "System" "System"
SYNO=0
if [ -f /etc.defaults/VERSION ]; then
  SYNO=1
  DSMV=$(sed -n 's/^productversion="\{0,1\}\([^"]*\)"\{0,1\}/\1/p' /etc.defaults/VERSION)
  DSMB=$(sed -n 's/^buildnumber="\{0,1\}\([^"]*\)"\{0,1\}/\1/p' /etc.defaults/VERSION)
  HW=$(cat /proc/sys/kernel/syno_hw_version 2>/dev/null || echo '?')
  info "Synology DSM ${DSMV:-?} (Build ${DSMB:-?}), Modell: $HW" "Synology DSM ${DSMV:-?} (build ${DSMB:-?}), model: $HW"
else
  OSN=$(sed -n 's/^PRETTY_NAME="\{0,1\}\([^"]*\)"\{0,1\}/\1/p' /etc/os-release 2>/dev/null); OSN=${OSN:-$(uname -sr)}
  info "OS: $OSN" "OS: $OSN"
fi
CORES=$(grep -c ^processor /proc/cpuinfo)
CPUN=$(awk -F: '/model name/{sub(/^ */,"",$2); print $2; exit}' /proc/cpuinfo)
info "CPU: $CPUN – $CORES Kerne" "CPU: $CPUN – $CORES cores"
MEMT=$(awk '/^MemTotal/{print int($2/1024)}' /proc/meminfo); MEMA=$(awk '/^MemAvailable/{print int($2/1024)}' /proc/meminfo)
SWT=$(awk '/^SwapTotal/{print int($2/1024)}' /proc/meminfo); SWF=$(awk '/^SwapFree/{print int($2/1024)}' /proc/meminfo)
RAM=$MEMT
if [ -n "$CONTAINER" ]; then
  LIM=$($DOCKER inspect -f '{{.HostConfig.Memory}}' "$CONTAINER" 2>/dev/null)
  if is_num "$LIM" && [ "$LIM" -gt 0 ]; then RAM=$((LIM/1048576)); info "Container-RAM-Limit: ${RAM} MB" "Container RAM limit: ${RAM} MB"; fi
fi
if [ "$MEMT" -lt 2048 ]; then
  warn "RAM: ${MEMT} MB gesamt, ${MEMA} MB frei – sehr knapp" "RAM: ${MEMT} MB total, ${MEMA} MB free – very low" \
       "RAM aufrüsten (mind. 4 GB für Nextcloud + DB + Redis)." "Add RAM (at least 4 GB for Nextcloud + DB + Redis)."
else ok "RAM: ${MEMT} MB gesamt, ${MEMA} MB verfügbar" "RAM: ${MEMT} MB total, ${MEMA} MB available"; fi
if [ "$SWT" -gt 0 ]; then SWU=$((SWT-SWF)); P=$((SWU*100/SWT))
  if [ "$P" -gt 20 ]; then
    warn "Swap: ${SWU} MB von ${SWT} MB belegt (${P}%)" "Swap: ${SWU} MB of ${SWT} MB used (${P}%)" \
         "System swappt – RAM zu knapp oder pm.max_children/Buffer zu hoch." "System is swapping – too little RAM or pm.max_children/buffers too high."
  else ok "Swap: ${SWU} MB von ${SWT} MB belegt" "Swap: ${SWU} MB of ${SWT} MB used"; fi
fi
LOAD=$(cut -d' ' -f2 /proc/loadavg)
if gt "$LOAD" "$CORES"; then
  warn "Load (5 min): $LOAD bei $CORES Kernen – überlastet" "Load (5 min): $LOAD on $CORES cores – overloaded" \
       "CPU-Last zu hoch: Hintergrundjobs/Vorschaubilder/Indexierung prüfen." "CPU load too high: check background jobs/previews/indexing."
else ok "Load (5 min): $LOAD bei $CORES Kernen" "Load (5 min): $LOAD on $CORES cores"; fi
HDD=0; SSD=0
for q in /sys/block/*/queue/rotational; do
  [ -f "$q" ] || continue
  n=$(basename "$(dirname "$(dirname "$q")")")
  case "$n" in loop*|ram*|zram*|md*|dm-*|synoboot*) continue ;; esac
  if [ "$(cat "$q")" = 1 ]; then HDD=$((HDD+1)); else SSD=$((SSD+1)); fi
done
info "Laufwerke: $SSD SSD/NVMe, $HDD HDD" "Drives: $SSD SSD/NVMe, $HDD HDD"
DATADIR=$(v cfg.datadirectory)
if [ -n "$DATADIR" ]; then
  read -r DSZ DAV <<EOF
$(inx "df -Pk '$DATADIR' 2>/dev/null | awk 'NR==2{print \$2, \$4}'")
EOF
  if is_num "$DSZ" && [ "$DSZ" -gt 0 ]; then PF=$((DAV*100/DSZ)); FREEH=$(hum $((DAV*1024)))
    if [ "$PF" -lt 10 ]; then
      crit "Datenverzeichnis: nur ${PF}% frei ($FREEH)" "Data directory: only ${PF}% free ($FREEH)" \
           "Speicherplatz im Datenverzeichnis freigeben/erweitern." "Free up or extend space in the data directory."
    else ok "Datenverzeichnis: ${PF}% frei ($FREEH)" "Data directory: ${PF}% free ($FREEH)"; fi
  fi
fi
BMS=$(v bench.cpu_ms)
[ -n "$BMS" ] && info "PHP-CPU-Benchmark: $BMS ms (weniger = schneller; zum Vergleich deiner Systeme)" "PHP CPU benchmark: $BMS ms (lower = faster; for comparing your systems)"
if [ "$DISKTEST" = 1 ]; then
  WMB=$(v disk.write_mbs)
  [ -n "$WMB" ] && info "Schreibrate Datenverzeichnis: $WMB MB/s" "Write speed data directory: $WMB MB/s"
  SF=$(v disk.smallfiles_ms)
  if is_num "$SF"; then
    if [ "$SF" -gt 3000 ]; then
      warn "500 kleine Dateien schreiben/löschen: ${SF} ms – langsam" "Write/delete 500 small files: ${SF} ms – slow" \
           "Kleindatei-Performance schwach: SSD (Cache) für Datenverzeichnis/DB erwägen." "Weak small-file performance: consider SSD (cache) for data directory/DB."
    else ok "500 kleine Dateien schreiben/löschen: ${SF} ms" "Write/delete 500 small files: ${SF} ms"; fi
  fi
fi

# ---------- Nextcloud --------------------------------------------------------
section "Nextcloud" "Nextcloud"
info "Version: $(v cfg.version)  |  Datenbank: $(v cfg.dbtype)" "Version: $(v cfg.version)  |  Database: $(v cfg.dbtype)"
is_on "$(v cfg.maintenance)" && warn "Wartungsmodus ist aktiv" "Maintenance mode is active" \
  "Wartungsmodus deaktivieren: occ maintenance:mode --off" "Disable maintenance mode: occ maintenance:mode --off"
is_on "$(v cfg.debug)" && crit "Debug-Modus ist aktiv" "Debug mode is active" \
  "'debug' => false in config.php setzen (bremst stark)." "Set 'debug' => false in config.php (slows things down a lot)."
LL=$(v cfg.loglevel); is_num "$LL" || LL=2
if [ "$LL" -lt 2 ]; then
  warn "Loglevel $LL (sehr ausführlich)" "Log level $LL (very verbose)" \
       "'loglevel' => 2 setzen (Warnungen) – weniger Schreiblast." "Set 'loglevel' => 2 (warnings) – less write load."
else ok "Loglevel $LL" "Log level $LL"; fi
is_on "$(v cfg.filesystem_check_changes)" && warn "filesystem_check_changes ist aktiv" "filesystem_check_changes is active" \
  "'filesystem_check_changes' => 0 setzen, sofern niemand am Nextcloud vorbei Dateien ändert." \
  "Set 'filesystem_check_changes' => 0 unless files are changed outside of Nextcloud."

LC=$(v cfg.memcache.local); LK=$(v cfg.memcache.locking); DC=$(v cfg.memcache.distributed)
if [ -z "$LC" ]; then
  crit "Kein lokaler Cache (memcache.local)" "No local cache (memcache.local)" \
       "APCu installieren und 'memcache.local' => '\\OC\\Memcache\\APCu' setzen." "Install APCu and set 'memcache.local' => '\\OC\\Memcache\\APCu'."
else ok "memcache.local: $LC" "memcache.local: $LC"
  case "$LC" in *APCu*)
    is_on "$(v ext.apcu)" || crit "APCu konfiguriert, aber in PHP-CLI nicht geladen (Cron/occ)" "APCu configured but not loaded in PHP CLI (cron/occ)" \
      "PHP-Erweiterung apcu für die Kommandozeile aktivieren (Cron/occ)." "Enable the apcu PHP extension for the command line (cron/occ)."
    [ -n "$(v web.php.version)" ] || is_on "$(v ini.apc.enable_cli)" || \
      warn "apc.enable_cli ist aus – Cron/occ können fehlschlagen" "apc.enable_cli is off – cron/occ may fail" \
           "apc.enable_cli=1 in der PHP-CLI-Konfiguration setzen." "Set apc.enable_cli=1 in the PHP CLI configuration." ;;
  esac
fi
case "$LK" in
  *Redis*) ok "Dateisperren über Redis" "File locking via Redis" ;;
  *) FL=$(v cfg.filelocking.enabled)
     if [ -z "$FL" ] || is_on "$FL"; then
       warn "Dateisperren laufen über die Datenbank" "File locking uses the database" \
            "Redis installieren und 'memcache.locking' => '\\OC\\Memcache\\Redis' setzen (entlastet die DB deutlich)." \
            "Install Redis and set 'memcache.locking' => '\\OC\\Memcache\\Redis' (takes a lot of load off the DB)."
     fi ;;
esac
if [ -n "$DC" ]; then ok "memcache.distributed: $DC" "memcache.distributed: $DC"
else info "Kein verteilter Cache (bei einem Server ok; Redis empfohlen)" "No distributed cache (fine for a single server; Redis recommended)"; fi

# Redis
if [ -n "$(v cfg.redis.host)" ]; then
  RERR=$(v redis.error)
  if [ -n "$RERR" ]; then
    crit "Redis nicht erreichbar: $RERR" "Redis not reachable: $RERR" "Redis-Verbindung (Host/Port/Passwort) prüfen." "Check the Redis connection (host/port/password)."
  elif [ -n "$(v redis.redis_version)" ]; then
    RV=$(v redis.redis_version); RL=$(v redis.latency_ms); RM=$(v redis.used_memory_human)
    if gt "$RL" 1; then
      warn "Redis $RV: Latenz ${RL} ms" "Redis $RV: latency ${RL} ms" \
           "Redis-Latenz hoch: Redis lokal/per Unix-Socket anbinden." "High Redis latency: connect Redis locally/via Unix socket."
    else ok "Redis $RV: Latenz ${RL} ms, Speicher $RM" "Redis $RV: latency ${RL} ms, memory $RM"; fi
    EV=$(v redis.evicted_keys)
    if is_num "$EV" && [ "$EV" -gt 0 ]; then RMAX=$(hum "$(v redis.maxmemory)")
      warn "Redis hat $EV Schlüssel verdrängt" "Redis evicted $EV keys" \
           "Redis maxmemory erhöhen (aktuell $RMAX; 0 = unbegrenzt)." "Increase Redis maxmemory (currently $RMAX; 0 = unlimited)."
    fi
    H=$(v redis.keyspace_hits); M=$(v redis.keyspace_misses)
    if is_num "$H" && is_num "$M" && [ $((H+M)) -gt 1000 ]; then
      info "Redis-Trefferquote: $((H*100/(H+M)))%" "Redis hit rate: $((H*100/(H+M)))%"; fi
  fi
fi

# Hintergrundjobs, Apps, Vorschaubilder / background jobs, apps, previews
BJ=$(occ config:app:get core backgroundjobs_mode); BJ=${BJ:-ajax}
if [ "$BJ" = "cron" ]; then ok "Hintergrundjobs: cron" "Background jobs: cron"
else warn "Hintergrundjobs: $BJ" "Background jobs: $BJ" \
  "Hintergrundjobs auf 'Cron' umstellen (occ background:cron) und System-Cron alle 5 Min einrichten." \
  "Switch background jobs to 'Cron' (occ background:cron) and set up a system cron every 5 min."; fi
LCRON=$(occ config:app:get core lastcron)
if is_num "$LCRON" && [ "$LCRON" -gt 0 ]; then AGE=$((($(date +%s)-LCRON)/60))
  if [ "$AGE" -gt 60 ]; then
    crit "Letzter Cron-Lauf vor $AGE Minuten" "Last cron run $AGE minutes ago" \
         "Cron läuft nicht – Cronjob prüfen (*/5 * * * * php -f $NCPATH/cron.php)." "Cron is not running – check the cron job (*/5 * * * * php -f $NCPATH/cron.php)."
  elif [ "$AGE" -gt 15 ]; then
    warn "Letzter Cron-Lauf vor $AGE Minuten" "Last cron run $AGE minutes ago" \
         "Cron läuft unregelmäßig/zu langsam – Intervall und Laufzeit prüfen." "Cron runs irregularly/too slowly – check interval and run time."
  else ok "Letzter Cron-Lauf vor $AGE Minuten" "Last cron run $AGE minutes ago"; fi
fi
APPS=$(occ app:list --shipped=false | awk '/^Enabled:/{e=1;next}/^Disabled:/{e=0}e&&/^ *- /{n++}END{print n+0}')
info "Zusätzlich installierte (aktive) Apps: $APPS" "Additionally installed (enabled) apps: $APPS"
[ "$APPS" -gt 30 ] && warn "Viele Zusatz-Apps aktiv ($APPS)" "Many additional apps enabled ($APPS)" \
  "Ungenutzte Apps deaktivieren – jede App verlängert die Ladezeit." "Disable unused apps – every app adds load time."
EP=$(v cfg.enable_previews)
if [ -z "$EP" ] || is_on "$EP"; then
  PX=$(v cfg.preview_max_x)
  if [ -z "$PX" ] || { is_num "$PX" && [ "$PX" -gt 2048 ]; }; then
    info "Vorschaubilder: max. Größe ${PX:-4096 (Standard)} – 'preview_max_x/_y' => 2048 spart Platz und CPU" \
         "Previews: max. size ${PX:-4096 (default)} – 'preview_max_x/_y' => 2048 saves space and CPU"
  else ok "Vorschaubilder: max. ${PX}x$(v cfg.preview_max_y)" "Previews: max. ${PX}x$(v cfg.preview_max_y)"; fi
  [ -n "$(v cfg.preview_imaginary_url)" ] && ok "Imaginary für Vorschaubilder aktiv" "Imaginary enabled for previews"
fi

# Logdatei / log file
LF=$(v cfg.logfile); [ -z "$LF" ] && LF="${DATADIR}/nextcloud.log"
LT=$(v cfg.log_type)
if [ -z "$LT" ] || [ "$LT" = "file" ]; then
  LSZ=$(inx "stat -c %s '$LF' 2>/dev/null || wc -c < '$LF' 2>/dev/null" | tr -d ' ')
  if is_num "$LSZ" && [ "$LSZ" -gt 0 ]; then
    ERR=$(inx "tail -n 5000 '$LF' 2>/dev/null | grep -c '\"level\":[34]'"); LSH=$(hum "$LSZ")
    if [ "$LSZ" -gt 104857600 ]; then
      warn "Logdatei: $LSH" "Log file: $LSH" \
           "Logdatei verkleinern/rotieren ('log_rotate_size' => 104857600)." "Shrink/rotate the log file ('log_rotate_size' => 104857600)."
    else ok "Logdatei: $LSH" "Log file: $LSH"; fi
    if is_num "$ERR" && [ "$ERR" -gt 50 ]; then
      warn "$ERR Fehler in den letzten 5000 Logzeilen" "$ERR errors in the last 5000 log lines" \
           "Logfehler ansehen (Einstellungen › Protokollierung) – wiederkehrende Fehler kosten Leistung." \
           "Review log errors (Settings › Logging) – recurring errors cost performance."
    else info "Fehler in den letzten 5000 Logzeilen: ${ERR:-0}" "Errors in the last 5000 log lines: ${ERR:-0}"; fi
  fi
fi

# Selbstprüfung von Nextcloud / Nextcloud setup checks
occ setupchecks > "$TMP/sc"
if [ -s "$TMP/sc" ]; then
  grep -E '⚠|✗|✘|❌|×' "$TMP/sc" | head -25 > "$TMP/sc2"
  if [ -s "$TMP/sc2" ]; then m "  Hinweise der Nextcloud-Selbstprüfung:" "  Nextcloud setup check findings:"; echo; sed 's/^ */      /' "$TMP/sc2"
  else ok "Nextcloud-Selbstprüfung ohne Warnungen" "Nextcloud setup checks without warnings"; fi
fi

# ---------- PHP --------------------------------------------------------------
HAVEWEB=0; [ -n "$(v web.php.version)" ] && HAVEWEB=1
CLIML=$(to_mb "$(v ini.memory_limit)")
yn() { if is_on "$1"; then m ja yes; elif [ -z "$1" ]; then echo "?"; else m nein no; fi; }
row() { if [ "$2" = "$3" ] || [ "$2" = "?" ]; then MK=""; else MK="${Y}≠${N}"; fi
        printf '    %-22s %-16s %-16s %s\n' "$1" "$2" "$3" "$MK"; }

if [ "$HAVEWEB" = 1 ]; then
  section "PHP – Web (Profil) und CLI (Cron/occ)" "PHP – web (profile) and CLI (cron/occ)"
  WS=$(v web.webserver); [ -n "$WS" ] && info "Webserver: $WS" "Web server: $WS"
  printf '    %-22s %-16s %-16s\n' "" "$(m "Web (Profil)" "Web (profile)")" "CLI (Cron)"
  row "$(m PHP-Version "PHP version")" "$(v web.php.version)" "$(v php.version)"
  row "memory_limit (MB)" "$(v web.memory_limit_mb)" "$CLIML"
  if [ "$(v web.ext_known)" = "true" ]; then
    for e in apcu redis imagick igbinary intl gmp bcmath; do row "$(m Erweiterung Extension) $e" "$(yn "$(v "web.ext.$e")")" "$(yn "$(v "ext.$e")")"; done
  fi
  m "    (≠ = Profil und Kommandozeile unterscheiden sich)" "    (≠ = profile and command line differ)"; echo; echo
  PV=$(v web.php.version)
  WML=$(v web.memory_limit_mb)
  if is_num "$WML" && [ "$WML" != "-1" ] && [ "$WML" -lt 512 ]; then
    warn "Web: memory_limit = ${WML} MB" "Web: memory_limit = ${WML} MB" \
         "Im PHP-Profil memory_limit auf 512M (oder mehr) setzen." "Set memory_limit to 512M (or more) in the PHP profile."
  else ok "Web: memory_limit = ${WML} MB" "Web: memory_limit = ${WML} MB"; fi
  if is_num "$CLIML" && [ "$CLIML" != "-1" ] && [ "$CLIML" -lt 512 ]; then CMLS=$(v ini.memory_limit)
    warn "CLI: memory_limit = $CMLS – Cron/occ können abbrechen" "CLI: memory_limit = $CMLS – cron/occ may abort" \
         "PHP-CLI memory_limit auf 512M setzen (für Cron/occ)." "Set PHP CLI memory_limit to 512M (for cron/occ)."; fi
  UMB=$(v web.upload_max_mb)
  is_num "$UMB" && [ "$UMB" -lt 512 ] && info "Web: Upload-Grenze nur ${UMB} MB (große Dateien werden in Stücken hochgeladen – meist ok)" \
                                              "Web: upload limit only ${UMB} MB (large files are uploaded in chunks – usually fine)"
  if [ "$(v web.ext_known)" = "true" ]; then
    case "$LC" in *APCu*) is_on "$(v web.ext.apcu)" || crit "Web: APCu konfiguriert, aber im Profil nicht geladen" "Web: APCu configured but not loaded in the profile" \
      "Im PHP-Profil die Erweiterung apcu aktivieren." "Enable the apcu extension in the PHP profile." ;; esac
    case "$LK$DC" in *Redis*) is_on "$(v web.ext.redis)" || crit "Web: Redis konfiguriert, aber im Profil nicht geladen" "Web: Redis configured but not loaded in the profile" \
      "Im PHP-Profil die Erweiterung redis aktivieren." "Enable the redis extension in the PHP profile." ;; esac
    for e in imagick intl gmp bcmath; do is_on "$(v "web.ext.$e")" || info "Web: PHP-Erweiterung '$e' im Profil nicht geladen" "Web: PHP extension '$e' not loaded in the profile"; done
  fi
  # OPcache zur Laufzeit / at runtime
  OE=$(v web.opcache.enabled)
  if [ "$OE" = "unknown" ]; then info "Web: OPcache-Status nicht lesbar (opcache.restrict_api gesetzt oder OPcache fehlt)" "Web: OPcache status not readable (opcache.restrict_api set or OPcache missing)"
  elif ! is_on "$OE"; then crit "Web: OPcache ist aus" "Web: OPcache is off" \
    "Im PHP-Profil OPcache aktivieren – größter Einzel-Performancegewinn." "Enable OPcache in the PHP profile – the biggest single performance gain."
  else
    OMB=$(v web.opcache.mem_mb); OFP=$(v web.opcache.free_pct); OWP=$(v web.opcache.wasted_pct)
    OSM=$(v web.opcache.str_mb); OSF=$(v web.opcache.str_free_pct)
    OSC=$(v web.opcache.scripts); OMK=$(v web.opcache.max_keys); OHR=$(v web.opcache.hit_rate); OHI=$(v web.opcache.hits)
    ok "Web: OPcache aktiv – ${OMB} MB, ${OFP}% frei, Trefferquote ${OHR}%" "Web: OPcache active – ${OMB} MB, ${OFP}% free, hit rate ${OHR}%"
    if is_on "$(v web.opcache.full)"; then
      crit "Web: OPcache ist voll" "Web: OPcache is full" \
           "opcache.memory_consumption im Profil erhöhen (aktuell ${OMB} MB)." "Increase opcache.memory_consumption in the profile (currently ${OMB} MB)."
    elif gt 10 "$OFP"; then
      warn "Web: OPcache fast voll (${OFP}% frei von ${OMB} MB)" "Web: OPcache almost full (${OFP}% free of ${OMB} MB)" \
           "opcache.memory_consumption im Profil erhöhen (aktuell ${OMB} MB)." "Increase opcache.memory_consumption in the profile (currently ${OMB} MB)."
    fi
    gt "$OWP" 10 && info "Web: ${OWP}% des OPcache sind verschwendet (wird beim nächsten PHP-Neustart frei)" "Web: ${OWP}% of OPcache is wasted (freed on next PHP restart)"
    if [ -n "$OSF" ] && gt 10 "$OSF"; then
      warn "Web: Interned-Strings-Puffer fast voll (${OSF}% frei von ${OSM} MB)" "Web: interned strings buffer almost full (${OSF}% free of ${OSM} MB)" \
           "opcache.interned_strings_buffer im Profil erhöhen (aktuell ${OSM}, empfohlen 32)." "Increase opcache.interned_strings_buffer in the profile (currently ${OSM}, recommended 32)."
    elif [ -n "$OSM" ]; then ok "Web: Interned-Strings-Puffer ${OSM} MB, ${OSF}% frei" "Web: interned strings buffer ${OSM} MB, ${OSF}% free"; fi
    if is_num "$OSC" && is_num "$OMK" && [ "$OMK" -gt 0 ] && [ $((OSC*100/OMK)) -gt 90 ]; then
      warn "Web: $OSC von $OMK möglichen Skripten im OPcache" "Web: $OSC of $OMK possible scripts in OPcache" \
           "opcache.max_accelerated_files im Profil erhöhen (z.B. 20000)." "Increase opcache.max_accelerated_files in the profile (e.g. 20000)."; fi
    if is_num "$OHI" && [ "$OHI" -gt 10000 ] && gt 95 "$OHR"; then
      warn "Web: OPcache-Trefferquote nur ${OHR}%" "Web: OPcache hit rate only ${OHR}%" \
           "OPcache zu klein oder wird zu oft geleert – Größe und revalidate_freq prüfen." "OPcache too small or reset too often – check size and revalidate_freq."; fi
    if is_on "$(v web.jit.on)"; then ok "Web: JIT aktiv ($(v web.jit.mb) MB)" "Web: JIT active ($(v web.jit.mb) MB)"
    else info "Web: JIT aus (optional: opcache.jit=1255, opcache.jit_buffer_size=64M)" "Web: JIT off (optional: opcache.jit=1255, opcache.jit_buffer_size=64M)"; fi
  fi
  # APCu zur Laufzeit / at runtime
  AMB=$(v web.apcu.mb)
  if [ -n "$AMB" ]; then
    AFP=$(v web.apcu.free_pct); AH=$(v web.apcu.hits); AM=$(v web.apcu.misses)
    AHR="?"; is_num "$AH" && is_num "$AM" && [ $((AH+AM)) -gt 0 ] && AHR=$((AH*100/(AH+AM)))
    if gt 10 "$AFP"; then
      warn "Web: APCu fast voll (${AFP}% frei von ${AMB} MB)" "Web: APCu almost full (${AFP}% free of ${AMB} MB)" \
           "apc.shm_size im Profil erhöhen (aktuell ${AMB}M)." "Increase apc.shm_size in the profile (currently ${AMB}M)."
    else ok "Web: APCu ${AMB} MB, ${AFP}% frei, Trefferquote ${AHR}%" "Web: APCu ${AMB} MB, ${AFP}% free, hit rate ${AHR}%"; fi
  fi
  echo
  m "  CLI (für Cron/occ):" "  CLI (for cron/occ):"; echo
  case "$LC" in *APCu*) is_on "$(v ini.apc.enable_cli)" || warn "CLI: apc.enable_cli ist aus – Cron/occ können fehlschlagen" "CLI: apc.enable_cli is off – cron/occ may fail" \
    "apc.enable_cli=1 in der PHP-CLI-Konfiguration setzen." "Set apc.enable_cli=1 in the PHP CLI configuration." ;; esac
  CPV=$(v php.version)
  if [ "$PV" != "$CPV" ]; then PVN=$(printf '%s' "${PV%.*}" | tr -d .)
    warn "CLI nutzt PHP $CPV, Web nutzt PHP $PV" "CLI uses PHP $CPV, web uses PHP $PV" \
         "Cron/occ mit derselben PHP-Version wie das Profil ausführen (Synology: /usr/local/bin/php$PVN, Debian/Ubuntu: php${PV%.*})." \
         "Run cron/occ with the same PHP version as the profile (Synology: /usr/local/bin/php$PVN, Debian/Ubuntu: php${PV%.*})."
  else ok "CLI und Web nutzen dieselbe PHP-Version" "CLI and web use the same PHP version"; fi
else
  section "PHP (CLI-Werte – FPM/Apache können abweichen)" "PHP (CLI values – FPM/Apache may differ)"
  if [ -n "$WEBMSG_DE" ]; then warn "$WEBMSG_DE" "$WEBMSG_EN"
  else info "Tipp: Mit -t TOKEN siehst du die Werte, die der Webserver (z.B. Web-Station-Profil) wirklich nutzt." \
            "Tip: with -t TOKEN you see the values the web server (e.g. Web Station profile) really uses."; fi
  PV=$(v php.version); CMLS=$(v ini.memory_limit)
  if [ "$CLIML" != "-1" ] && [ "$CLIML" -lt 512 ]; then
    warn "memory_limit = $CMLS" "memory_limit = $CMLS" "PHP memory_limit auf 512M (oder mehr) setzen." "Set PHP memory_limit to 512M (or more)."
  else ok "memory_limit = $CMLS" "memory_limit = $CMLS"; fi
  if ! is_on "$(v ext.Zend_OPcache)" && [ -z "$CONTAINER" ]; then
    info "OPcache ist in der Kommandozeile nicht geladen – für Cron unwichtig. Ob OPcache im Webserver aktiv ist, zeigt nur der Aufruf mit -t TOKEN." \
         "OPcache is not loaded on the command line – irrelevant for cron. Whether OPcache is active in the web server is only shown with -t TOKEN."
  elif ! is_on "$(v ext.Zend_OPcache)"; then crit "OPcache nicht geladen" "OPcache not loaded" \
    "OPcache aktivieren – größter Einzel-Performancegewinn für PHP." "Enable OPcache – the biggest single performance gain for PHP."
  elif [ -n "$CONTAINER" ] || is_on "$(v ini.opcache.enable)"; then
    OM=$(v ini.opcache.memory_consumption); OI=$(v ini.opcache.interned_strings_buffer); OF=$(v ini.opcache.max_accelerated_files)
    if is_num "$OM" && [ "$OM" -lt 128 ]; then warn "opcache.memory_consumption = $OM" "opcache.memory_consumption = $OM" \
      "opcache.memory_consumption auf mind. 128 (besser 256) erhöhen." "Increase opcache.memory_consumption to at least 128 (better 256)."; fi
    if is_num "$OI" && [ "$OI" -lt 16 ]; then warn "opcache.interned_strings_buffer = $OI" "opcache.interned_strings_buffer = $OI" \
      "opcache.interned_strings_buffer auf 16–32 erhöhen." "Increase opcache.interned_strings_buffer to 16–32."; fi
    if is_num "$OF" && [ "$OF" -lt 10000 ]; then warn "opcache.max_accelerated_files = $OF" "opcache.max_accelerated_files = $OF" \
      "opcache.max_accelerated_files auf 10000–20000 erhöhen." "Increase opcache.max_accelerated_files to 10000–20000."; fi
    ORF=$(v ini.opcache.revalidate_freq)
    ok "OPcache: ${OM} MB, Strings ${OI} MB, Dateien ${OF}, revalidate_freq $ORF" "OPcache: ${OM} MB, strings ${OI} MB, files ${OF}, revalidate_freq $ORF"
    is_on "$(v ini.opcache.save_comments)" || crit "opcache.save_comments ist aus" "opcache.save_comments is off" \
      "opcache.save_comments=1 setzen (von Nextcloud benötigt)." "Set opcache.save_comments=1 (required by Nextcloud)."
    J=$(v ini.opcache.jit); JB=$(to_mb "$(v ini.opcache.jit_buffer_size)")
    case "$J" in off|0|disable|'') JOFF=1 ;; *) JOFF=0 ;; esac
    if [ "$JB" -le 0 ] || [ "$JOFF" = 1 ]; then info "OPcache-JIT inaktiv (optional: opcache.jit=1255, opcache.jit_buffer_size=64M)" "OPcache JIT inactive (optional: opcache.jit=1255, opcache.jit_buffer_size=64M)"
    else ok "OPcache-JIT: $J, Puffer ${JB} MB" "OPcache JIT: $J, buffer ${JB} MB"; fi
  else crit "OPcache ist deaktiviert" "OPcache is disabled" "opcache.enable=1 setzen." "Set opcache.enable=1."; fi
  is_on "$(v ext.apcu)" && info "APCu-Speicher: $(v ini.apc.shm_size)" "APCu memory: $(v ini.apc.shm_size)"
  for e in redis imagick igbinary intl gmp bcmath; do is_on "$(v "ext.$e")" || info "PHP-Erweiterung '$e' nicht geladen" "PHP extension '$e' not loaded"; done
fi
if awk -v v="${PV%.*}" 'BEGIN{exit !(v+0<8.2)}'; then
  warn "PHP $PV" "PHP $PV" "Auf PHP 8.3/8.4 aktualisieren (spürbar schneller, länger unterstützt)." "Upgrade to PHP 8.3/8.4 (noticeably faster, supported longer)."
else ok "PHP $PV" "PHP $PV"; fi

# PHP-FPM / Webserver-Prozesse / web server processes
inx 'for p in /proc/[0-9]*; do c=$(cat $p/comm 2>/dev/null); case "$c" in php-fpm*|apache2|httpd|nginx|frankenphp) echo "$c $(awk "/VmRSS/{print \$2}" $p/status 2>/dev/null)";; esac; done' 2>/dev/null \
  | awk '{n[$1]++; s[$1]+=$2} END{for(k in n) print k, n[k], int(s[k]/n[k])}' > "$TMP/procs"
FPMR=0
while read -r PNAME PN PAVG; do
  [ -z "$PNAME" ] && continue
  info "Prozesse $PNAME: $PN, Ø $((PAVG/1024)) MB RAM" "Processes $PNAME: $PN, avg $((PAVG/1024)) MB RAM"
  case "$PNAME" in php-fpm*) FPMR=$PAVG
    FV=$(printf '%s' "$PNAME" | sed -n 's/^php-fpm\([0-9]\)\.\{0,1\}\([0-9]\{1,2\}\)$/\1.\2/p')
    [ -n "$FV" ] && FPMVS="${FPMVS:+$FPMVS }$FV" ;;
  esac
done < "$TMP/procs"
CPVMM=$(v php.version); CPVMM=${CPVMM%.*}
if [ "$HAVEWEB" = 0 ] && [ -n "${FPMVS:-}" ]; then
  case " $FPMVS " in
    *" $CPVMM "*) ;;
    *) case "$FPMVS" in
         *" "*) warn "PHP-FPM läuft mit PHP $FPMVS, die Kommandozeile mit PHP $CPVMM" "PHP-FPM runs PHP $FPMVS, the command line PHP $CPVMM" \
                     "Prüfen, welches PHP dein Nextcloud-Profil nutzt (-t TOKEN zeigt es), und Cron/occ/ncperf mit derselben Version starten (--php)." \
                     "Check which PHP your Nextcloud profile uses (-t TOKEN shows it) and run cron/occ/ncperf with the same version (--php)." ;;
         *) FVN=$(printf '%s' "$FPMVS" | tr -d .)
            warn "Webserver nutzt offenbar PHP $FPMVS (php-fpm$FVN), die Kommandozeile PHP $CPVMM" "Web server apparently uses PHP $FPMVS (php-fpm$FVN), the command line PHP $CPVMM" \
                 "Cron/occ und ncperf mit derselben Version starten (Synology: --php /usr/local/bin/php$FVN, Debian/Ubuntu: php$FPMVS)." \
                 "Run cron/occ and ncperf with the same version (Synology: --php /usr/local/bin/php$FVN, Debian/Ubuntu: php$FPMVS)." ;;
       esac ;;
  esac
fi
inx 'for f in /etc/php/*/fpm/pool.d/*.conf /usr/local/etc/php-fpm.d/*.conf /etc/php-fpm.d/*.conf /etc/php*/php-fpm.d/*.conf /usr/local/etc/php*/php-fpm.d/*.conf; do [ -f "$f" ] && grep -hE "^[[:space:]]*pm(\.[a-z_]+)?[[:space:]]*=" "$f"; done' > "$TMP/pool" 2>/dev/null
if [ -s "$TMP/pool" ]; then
  PMM=$(awk -F= '$1~/^[ \t]*pm[ \t]*$/{gsub(/[ \t]/,"",$2);x=$2}END{print x}' "$TMP/pool")
  PMC=$(awk -F= '$1~/pm\.max_children/{gsub(/[ \t]/,"",$2);x=$2}END{print x}' "$TMP/pool")
  info "PHP-FPM: pm=$PMM, pm.max_children=$PMC" "PHP-FPM: pm=$PMM, pm.max_children=$PMC"
  if is_num "$PMC" && [ "$PMC" -le 5 ]; then
    warn "pm.max_children = $PMC (Standardwert, zu niedrig)" "pm.max_children = $PMC (default, too low)" \
         "pm.max_children anheben (siehe Vorschläge unten) – sonst Warteschlangen bei mehreren Nutzern." \
         "Raise pm.max_children (see suggestions below) – otherwise requests queue up with several users."; fi
fi

# ---------- Datenbank / database ---------------------------------------------
section "Datenbank" "Database"
DBT=$(v cfg.dbtype)
DBSZ=$(v db.size); is_num "$DBSZ" || DBSZ=0
if [ "$DBT" = "sqlite3" ] || [ "$DBT" = "sqlite" ] || [ -z "$DBT" ]; then
  crit "SQLite wird verwendet" "SQLite is used" \
       "Auf MariaDB/MySQL oder PostgreSQL migrieren (occ db:convert-type) – SQLite ist nur für Tests." \
       "Migrate to MariaDB/MySQL or PostgreSQL (occ db:convert-type) – SQLite is for testing only."
elif [ -n "$(v db.error)" ]; then
  info "Direkte DB-Prüfung nicht möglich: $(v db.error)" "Direct DB check not possible: $(v db.error)"
else
  DBV=$(v db.version); DBH=$(hum "$DBSZ"); FCR=$(v db.filecache_rows)
  info "$DBT $DBV, Größe $DBH, Dateieinträge ca. $FCR" "$DBT $DBV, size $DBH, file entries approx. $FCR"
  DL=$(v db.latency_ms)
  if gt "$DL" 10; then
    crit "DB-Latenz ${DL} ms pro Abfrage" "DB latency ${DL} ms per query" \
         "DB-Latenz sehr hoch: DB auf denselben Host/Unix-Socket, Netzwerk prüfen." "DB latency very high: put DB on the same host/Unix socket, check network."
  elif gt "$DL" 2; then
    warn "DB-Latenz ${DL} ms pro Abfrage" "DB latency ${DL} ms per query" \
         "DB-Latenz erhöht: lokale Verbindung/Unix-Socket nutzen." "DB latency elevated: use a local connection/Unix socket."
  else ok "DB-Latenz ${DL} ms pro Abfrage" "DB latency ${DL} ms per query"; fi
  if [ "$DBT" = "mysql" ]; then
    BP=$(v my.innodb_buffer_pool_size)
    if is_num "$BP"; then BPH=$(hum "$BP")
      if [ "$DBSZ" -gt 0 ] && [ "$BP" -lt "$DBSZ" ]; then
        warn "innodb_buffer_pool_size $BPH < DB-Größe $DBH" "innodb_buffer_pool_size $BPH < DB size $DBH" \
             "innodb_buffer_pool_size erhöhen (siehe Vorschläge)." "Increase innodb_buffer_pool_size (see suggestions)."
      else ok "innodb_buffer_pool_size $BPH" "innodb_buffer_pool_size $BPH"; fi
    fi
    RQ=$(v my.Innodb_buffer_pool_read_requests); RD=$(v my.Innodb_buffer_pool_reads)
    if is_num "$RQ" && is_num "$RD" && [ "$RQ" -gt 1000000 ]; then
      HR=$(awk -v a="$RQ" -v b="$RD" 'BEGIN{printf "%.2f",(1-b/a)*100}')
      if gt 99 "$HR"; then
        warn "Buffer-Pool-Trefferquote $HR %" "Buffer pool hit rate $HR %" \
             "Buffer-Pool zu klein – innodb_buffer_pool_size erhöhen." "Buffer pool too small – increase innodb_buffer_pool_size."
      else ok "Buffer-Pool-Trefferquote $HR %" "Buffer pool hit rate $HR %"; fi
    fi
    TI=$(v my.transaction_isolation); [ -z "$TI" ] && TI=$(v my.tx_isolation)
    if [ -n "$TI" ] && [ "$TI" != "READ-COMMITTED" ]; then
      warn "transaction_isolation = $TI" "transaction_isolation = $TI" \
           "MariaDB/MySQL: transaction_isolation = READ-COMMITTED setzen (Nextcloud-Empfehlung)." "MariaDB/MySQL: set transaction_isolation = READ-COMMITTED (Nextcloud recommendation)."
    elif [ -n "$TI" ]; then ok "transaction_isolation = $TI" "transaction_isolation = $TI"; fi
    BLF=$(v my.binlog_format)
    if is_on "$(v my.log_bin)" && [ "$BLF" != "ROW" ]; then
      warn "Binlog aktiv mit Format $BLF" "Binlog active with format $BLF" "binlog_format = ROW setzen." "Set binlog_format = ROW."; fi
    [ "$(v my.innodb_flush_log_at_trx_commit)" = "1" ] && info "innodb_flush_log_at_trx_commit=1 (sicher; '2' ist schneller bei minimalem Risiko)" \
                                                              "innodb_flush_log_at_trx_commit=1 (safe; '2' is faster with minimal risk)"
    TD=$(v my.Created_tmp_disk_tables); TT=$(v my.Created_tmp_tables)
    if is_num "$TD" && is_num "$TT" && [ "$TT" -gt 1000 ] && [ $((TD*100/TT)) -gt 25 ]; then
      warn "$((TD*100/TT))% der temporären Tabellen landen auf der Platte" "$((TD*100/TT))% of temporary tables go to disk" \
           "tmp_table_size und max_heap_table_size erhöhen (z.B. 64M)." "Increase tmp_table_size and max_heap_table_size (e.g. 64M)."; fi
    SQ=$(v my.Slow_queries); if is_num "$SQ" && [ "$SQ" -gt 0 ]; then info "Langsame Abfragen seit Start: $SQ" "Slow queries since start: $SQ"; fi
  elif [ "$DBT" = "pgsql" ]; then
    SB=$(v pg.shared_buffers_bytes); SBS=$(v pg.shared_buffers)
    if is_num "$SB" && [ "$RAM" -ge 4096 ] && [ "$SB" -le 134217728 ]; then
      warn "shared_buffers = $SBS (Standard)" "shared_buffers = $SBS (default)" \
           "PostgreSQL shared_buffers auf ca. 25% des RAM erhöhen." "Increase PostgreSQL shared_buffers to about 25% of RAM."
    else ok "shared_buffers = $SBS" "shared_buffers = $SBS"; fi
    PGI="effective_cache_size = $(v pg.effective_cache_size), work_mem = $(v pg.work_mem), random_page_cost = $(v pg.random_page_cost)"
    info "$PGI" "$PGI"
    PH=$(v pg.hit_ratio)
    if [ -n "$PH" ] && gt 99 "$PH"; then
      warn "Cache-Trefferquote $PH %" "Cache hit rate $PH %" "shared_buffers/RAM für PostgreSQL erhöhen." "Increase shared_buffers/RAM for PostgreSQL."
    elif [ -n "$PH" ]; then ok "Cache-Trefferquote $PH %" "Cache hit rate $PH %"; fi
  fi
fi

# ---------- HTTP -------------------------------------------------------------
section "Web-Antwortzeiten" "Web response times"
if [ -z "$URL" ] || ! command -v curl >/dev/null 2>&1; then
  info "Kein HTTP-Test (URL mit -u angeben bzw. curl installieren)" "No HTTP test (use -u URL or install curl)"
else
  info "URL: $URL ($RUNS Durchläufe)" "URL: $URL ($RUNS runs)"; REACH=0; HV="-"
  for ep in status.php index.php/login; do
    : > "$TMP/http"; i=0
    while [ "$i" -lt "$RUNS" ]; do
      curl -sk -o /dev/null --max-time 20 -w '%{http_code} %{time_connect} %{time_starttransfer} %{time_total} %{http_version}\n' "$URL/$ep" >> "$TMP/http" 2>/dev/null
      i=$((i+1))
    done
    read -r CODE TTFB TOT HV2 <<EOF
$(awk '$1>0{n++; t+=$3; s+=$4; c=$1; h=$5} END{if(n) printf "%s %.3f %.3f %s", c, t/n, s/n, h; else print "000 0 0 -"}' "$TMP/http")
EOF
    if [ "$CODE" = "000" ]; then info "/$ep nicht erreichbar" "/$ep not reachable"; continue; fi
    case "$CODE" in
      2*|3*) ;;
      *) warn "/$ep antwortet mit HTTP $CODE" "/$ep responds with HTTP $CODE" \
              "URL prüfen (-u) – /$ep sollte HTTP 200 liefern." "Check the URL (-u) – /$ep should return HTTP 200."
         continue ;;
    esac
    REACH=1; HV=$HV2
    MDE="/$ep: HTTP $CODE, Ø Antwortbeginn ${TTFB}s, Ø gesamt ${TOT}s"
    MEN="/$ep: HTTP $CODE, avg time to first byte ${TTFB}s, avg total ${TOT}s"
    if gt "$TTFB" 1.5; then
      crit "$MDE" "$MEN" "Seiten antworten sehr langsam (/$ep) – Cache/OPcache/DB-Punkte oben zuerst beheben." \
                         "Pages respond very slowly (/$ep) – fix the cache/OPcache/DB items above first."
    elif gt "$TTFB" 0.5; then
      warn "$MDE" "$MEN" "Antwortzeit /$ep über 0,5 s – Caching und PHP-Einstellungen prüfen." \
                         "Response time /$ep above 0.5 s – check caching and PHP settings."
    else ok "$MDE" "$MEN"; fi
  done
  if [ "$REACH" = 1 ]; then
    case "$HV" in
      1|1.0|1.1) warn "Server antwortet nur mit HTTP/$HV" "Server only answers with HTTP/$HV" \
                      "HTTP/2 im Webserver/Reverse-Proxy aktivieren." "Enable HTTP/2 in the web server/reverse proxy." ;;
      -|'') ;;
      *) ok "HTTP/$HV" "HTTP/$HV" ;;
    esac
    ENC=$(curl -sk -o /dev/null -D - --max-time 20 -H 'Accept-Encoding: br, gzip' "$URL/index.php/login" 2>/dev/null | tr -d '\r' | awk -F': ' 'tolower($1)=="content-encoding"{print $2}')
    if [ -n "$ENC" ]; then ok "Komprimierung: $ENC" "Compression: $ENC"
    else warn "Keine Komprimierung der Antworten" "Responses are not compressed" "gzip/brotli im Webserver aktivieren." "Enable gzip/brotli in the web server."; fi
  fi
fi

# ---------- Vorschläge / suggestions -----------------------------------------
section "Passende Werte für dieses System (${RAM} MB RAM, $CORES Kerne)" "Suggested values for this system (${RAM} MB RAM, $CORES cores)"
DBLOCAL=1
case "$(v cfg.dbhost)" in ""|localhost*|127.0.0.1*|/*) ;; *) [ -z "$CONTAINER" ] && DBLOCAL=0 ;; esac
# Leerlauf-RSS unterschätzt die Last: mind. 100 MB je Prozess ansetzen / idle RSS underestimates load
PER=$((FPMR/1024)); [ "$PER" -lt 100 ] && PER=100
if [ "$DBLOCAL" = 1 ]; then SHARE=40; else SHARE=60; fi
CMAX=$((CORES*8)); [ "$CMAX" -lt 16 ] && CMAX=16
CH=$((RAM*SHARE/100/PER)); [ "$CH" -lt 4 ] && CH=4; [ "$CH" -gt "$CMAX" ] && CH=$CMAX
SS=$((CH/4)); [ "$SS" -lt 2 ] && SS=2
MS=$((CH/2)); [ "$MS" -lt 4 ] && MS=4
if [ "$RAM" -le 2048 ]; then OPM=128; OPI=16; APCN=32; RMX=128
elif [ "$RAM" -le 8192 ]; then OPM=256; OPI=32; APCN=64; RMX=256
else OPM=512; OPI=64; APCN=128; RMX=512; fi
# aktuelle Werte nie nach unten vorschlagen / never suggest less than the current value
maxof() { if is_num "$2" && [ "$2" -gt "$1" ]; then echo "$2"; else echo "$1"; fi; }
if [ "$HAVEWEB" = 1 ]; then CML=$(v web.memory_limit_mb); COM=$(v web.opcache.mem_mb); COI=$(v web.opcache.str_mb); CAP=$(v web.apcu.mb)
else CML=$CLIML; COM=$(v ini.opcache.memory_consumption); COI=$(v ini.opcache.interned_strings_buffer); CAP=$(to_mb "$(v ini.apc.shm_size)"); fi
SML=$(maxof 512 "$CML"); OPM=$(maxof "$OPM" "$COM"); OPI=$(maxof "$OPI" "$COI"); APCN=$(maxof "$APCN" "$CAP")
cat <<EOF
  $(m "PHP (php.ini bzw. bei Synology: Web Station › PHP-Profil):" "PHP (php.ini or on Synology: Web Station › PHP profile):")
    memory_limit = ${SML}M
    opcache.enable = 1
    opcache.memory_consumption = $OPM
    opcache.interned_strings_buffer = $OPI
    opcache.max_accelerated_files = 20000
    opcache.revalidate_freq = 60
    opcache.save_comments = 1
    opcache.jit = 1255
    opcache.jit_buffer_size = 64M
    apc.shm_size = ${APCN}M
    apc.enable_cli = 1

  $(m "PHP-FPM (Pool www.conf), Annahme ${PER} MB je Prozess unter Last, ${SHARE}% des RAM, höchstens 8 je CPU-Kern:" "PHP-FPM (pool www.conf), assuming ${PER} MB per process under load, ${SHARE}% of RAM, at most 8 per CPU core:")
    pm = dynamic
    pm.max_children = $CH
    pm.start_servers = $SS
    pm.min_spare_servers = $SS
    pm.max_spare_servers = $MS
    pm.max_requests = 500
EOF
if [ "$DBT" = "mysql" ]; then
  BPS=$((DBSZ*3/2/1048576)); MAXBP=$((RAM*30/100)); [ "$BPS" -gt "$MAXBP" ] && BPS=$MAXBP
  BMIN=256; [ "$RAM" -ge 8192 ] && BMIN=512
  [ "$BPS" -lt "$BMIN" ] && BPS=$BMIN; BPS=$(((BPS+127)/128*128))
  ILF=$((BPS/4)); [ "$ILF" -lt 64 ] && ILF=64
  cat <<EOF

  MariaDB/MySQL (my.cnf, [mysqld]):
    innodb_buffer_pool_size = ${BPS}M
    innodb_log_file_size = ${ILF}M
    innodb_flush_log_at_trx_commit = 2
    innodb_flush_method = O_DIRECT
    transaction_isolation = READ-COMMITTED
    binlog_format = ROW
    tmp_table_size = 64M
    max_heap_table_size = 64M
    max_connections = $((CH+50))
EOF
elif [ "$DBT" = "pgsql" ]; then
  SBM=$((RAM/4)); [ "$SBM" -gt 8192 ] && SBM=8192
  RPC="4.0"; [ "$HDD" -eq 0 ] && RPC="1.1"
  if [ "$RAM" -ge 8192 ]; then WM=32; MWM=512; else WM=16; MWM=128; fi
  cat <<EOF

  PostgreSQL (postgresql.conf):
    shared_buffers = ${SBM}MB
    effective_cache_size = $((RAM/2))MB
    work_mem = ${WM}MB
    maintenance_work_mem = ${MWM}MB
    random_page_cost = $RPC
    max_connections = $((CH+50))
EOF
fi
cat <<EOF

  Nextcloud (config.php):
    'memcache.local' => '\\OC\\Memcache\\APCu',
    'memcache.distributed' => '\\OC\\Memcache\\Redis',
    'memcache.locking' => '\\OC\\Memcache\\Redis',
    'preview_max_x' => 2048,
    'preview_max_y' => 2048,
    'loglevel' => 2,
    'log_rotate_size' => 104857600,

  Redis (redis.conf): maxmemory ${RMX}mb, maxmemory-policy allkeys-lru
EOF
if [ "$SYNO" = 1 ]; then
  SPV=""; [ "$HAVEWEB" = 1 ] && SPV=$(v web.php.version) && SPV=${SPV%.*}
  case "${FPMVS:-}" in ''|*" "*) ;; *) [ -z "$SPV" ] && SPV=$FPMVS ;; esac
  [ -z "$SPV" ] && SPV=$CPVMM
  SPN=$(printf '%s' "$SPV" | tr -d .)
  echo
  if [ "$LNG" = de ]; then
    echo "  Synology-Hinweise: Datenbank und Docker-Volumes möglichst auf SSD/NVMe-Volume legen;"
    echo "  Cron über DSM-Aufgabenplaner (alle 5 Min) als Benutzer '$WEBUSER' ausführen;"
    echo "  bei Web Station die PHP-Werte im PHP-Profil setzen; Cron mit demselben PHP wie das Profil"
    echo "  starten (z.B. /usr/local/bin/php$SPN -f $NCPATH/cron.php)."
  else
    echo "  Synology notes: keep the database and Docker volumes on an SSD/NVMe volume if possible;"
    echo "  run cron via DSM Task Scheduler (every 5 min) as user '$WEBUSER';"
    echo "  with Web Station set PHP values in the PHP profile; start cron with the same PHP as the"
    echo "  profile (e.g. /usr/local/bin/php$SPN -f $NCPATH/cron.php)."
  fi
fi

# ---------- Zusammenfassung / summary ----------------------------------------
section "Zusammenfassung" "Summary"
NCRIT=$(grep -c . "$TMP/crit"); NWARN=$(grep -c . "$TMP/warn")
if [ "$NCRIT" -eq 0 ] && [ "$NWARN" -eq 0 ]; then ok "Keine Probleme gefunden." "No problems found."
else
  printf '  %s%d %s%s, %s%d %s%s – %s\n' "$R" "$NCRIT" "$(m kritisch critical)" "$N" "$Y" "$NWARN" "$(m Warnungen warnings)" "$N" \
    "$(m "in dieser Reihenfolge angehen:" "tackle them in this order:")"
  i=1; CL=$(m KRIT CRIT)
  while IFS= read -r msg; do [ -z "$msg" ] && continue; printf '  %2d. %s[%s]%s %s\n' "$i" "$R" "$CL" "$N" "$msg"; i=$((i+1)); done < "$TMP/crit"
  while IFS= read -r msg; do [ -z "$msg" ] && continue; printf '  %2d. %s[WARN]%s %s\n' "$i" "$Y" "$N" "$msg"; i=$((i+1)); done < "$TMP/warn"
fi
}
# =============================================================================

# Befehle in der Nextcloud-Umgebung / commands in the Nextcloud environment
inx() { if [ -n "$CONTAINER" ]; then $DOCKER exec "$CONTAINER" sh -c "$1"; else sh -c "$1"; fi; }
run_php() {
  if [ -n "$CONTAINER" ]; then $DOCKER exec -i -u "$WEBUSER" "$CONTAINER" php -- "$@"
  else $SUDO "$PHPBIN" -- "$@"; fi
}
occ() {
  if [ -n "$CONTAINER" ]; then $DOCKER exec -u "$WEBUSER" "$CONTAINER" php "$NCPATH/occ" "$@" 2>/dev/null
  else $SUDO "$PHPBIN" "$NCPATH/occ" "$@" 2>/dev/null; fi
}

if [ -n "$REPORT" ]; then
  main 2>&1 | tee "$TMP/out"
  [ -f "$TMP/failed" ] && exit 1
  sed "s/${ESC}\[[0-9;]*m//g" "$TMP/out" > "$REPORT" && printf '\n%s: %s\n' "$(m "Bericht gespeichert" "Report saved")" "$REPORT"
else
  main
fi
