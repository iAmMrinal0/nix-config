#!/usr/bin/env bash
# tnas-health remote payload — runs ON the TrueNAS box as root (piped over
# ssh by the tnas-health wrapper; see default.nix). Read-only throughout:
# midclt queries + smartctl/zpool reads, nothing is mutated.
#
# Baseline it audits against:
#   - every pool ONLINE, 0 errors, <80% full
#   - a scrub task per data pool, last scrub <45 days old
#   - SMART tests scheduled: at least one SHORT and one LONG task, all disks
#     covered (TrueNAS creates NO smart tests by default — only the scrub)
#   - per-disk SMART: passed, 0 reallocated/pending/uncorrectable sectors,
#     recent self-test on record
#   - alerts have a delivery path (email or an alert service)
#   - HDDs not set to spin down (fights scheduled tests and scrubs)
set -uo pipefail

R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[1m'; N=$'\e[0m'
WARNS=0; FAILS=0
ok()   { printf ' %s[ OK ]%s %s\n' "$G" "$N" "$1"; }
warn() { printf ' %s[WARN]%s %s\n' "$Y" "$N" "$1"; WARNS=$((WARNS + 1)); }
fail() { printf ' %s[FAIL]%s %s\n' "$R" "$N" "$1"; FAILS=$((FAILS + 1)); }
hdr()  { printf '\n%s== %s ==%s\n' "$B" "$1" "$N"; }

mc() { midclt call "$@" 2>/dev/null; }

command -v midclt >/dev/null || { echo "midclt not found — not a TrueNAS box?" >&2; exit 3; }
command -v jq >/dev/null || { echo "jq not found on the NAS" >&2; exit 3; }

printf '%s%s — TrueNAS %s — %s%s\n' "$B" "$(hostname)" \
  "$(cat /etc/version 2>/dev/null || echo '?')" "$(date '+%Y-%m-%d %H:%M')" "$N"

# ---------------------------------------------------------------- pools
hdr "Pool health"
zx=$(zpool status -x 2>/dev/null)
if [ "$zx" = "all pools are healthy" ]; then
  ok "$zx"
else
  fail "zpool status -x reports problems:"
  printf '%s\n' "$zx" | sed 's/^/        /'
fi

while read -r name size alloc cap frag health; do
  capn=${cap%\%}
  line="$name: $health, ${cap} full ($alloc of $size, frag $frag)"
  if [ "$health" != "ONLINE" ]; then
    fail "$line"
  elif [ "$capn" -ge 85 ]; then
    fail "$line — ZFS performance drops sharply on near-full pools"
  elif [ "$capn" -ge 80 ]; then
    warn "$line — keep pools below 80%"
  else
    ok "$line"
  fi

  errline=$(zpool status "$name" | grep -m1 'errors:')
  case "$errline" in
    *"No known data errors"*) : ;;
    *) fail "$name $errline" ;;
  esac

  scan=$(zpool status "$name" | sed -n 's/^[[:space:]]*scan: //p' | head -1)
  case "$scan" in
    *"in progress"*)
      ok "$name: scrub in progress" ;;
    *" on "*)
      when=$(date -d "${scan##* on }" +%s 2>/dev/null || echo 0)
      days=$(( ($(date +%s) - when) / 86400 ))
      if [ "$when" = 0 ]; then
        warn "$name: could not parse last scrub date ($scan)"
      elif [ "$days" -gt 45 ]; then
        warn "$name: last scrub ${days}d ago — should run every ~35 days"
      else
        ok "$name: last scrub ${days}d ago (${scan%% on *})"
      fi ;;
    *)
      warn "$name: never scrubbed ($scan)" ;;
  esac
done < <(zpool list -H -o name,size,alloc,cap,frag,health)

# -------------------------------------------------------- scrub schedule
hdr "Scrub schedule"
scrubs=$(mc pool.scrub.query)
if [ -z "$scrubs" ]; then
  warn "pool.scrub.query failed — check schedules in the GUI (Data Protection)"
else
  for pool in $(zpool list -H -o name | grep -v '^boot-pool$'); do
    t=$(jq -r --arg p "$pool" \
      '[.[] | select(.pool_name == $p)][0] // empty | "\(.enabled) threshold \(.threshold)d (cron \(.schedule.minute) \(.schedule.hour) \(.schedule.dom) \(.schedule.month) \(.schedule.dow))"' \
      <<<"$scrubs")
    case "$t" in
      true*)  ok "$pool: scrub task enabled, ${t#true }" ;;
      false*) fail "$pool: scrub task exists but is DISABLED" ;;
      *)      fail "$pool: no scrub task — add one (Data Protection → Scrub Tasks)" ;;
    esac
  done
fi

# ------------------------------------------------------ SMART scheduling
hdr "SMART test schedule"
svc=$(mc service.query '[["service","=","smart"]]')
if [ -n "$svc" ] && [ "$(jq length <<<"$svc")" -gt 0 ]; then
  if [ "$(jq -r '.[0].enable and .[0].state == "RUNNING"' <<<"$svc")" = "true" ]; then
    ok "smartd service enabled and running"
  else
    fail "smartd service not running/enabled ($(jq -r '.[0] | "\(.state), enable=\(.enable)"' <<<"$svc"))"
  fi
else
  ok "no smartd service entry (removed in 25.04+ — fine)"
fi

tests=$(mc smart.test.query)
disks=$(mc disk.query)
if [ -z "$tests" ]; then
  # 25.10 (Goldeye) dropped the smart.test API: scheduled tests are now plain
  # cron jobs running `midclt call disk.smart_test TYPE '["disks"]'` (created
  # by middleware migration f15312414057). Normalize those back into the old
  # task shape so the checks below work on both.
  tests=$(mc cronjob.query | jq '[.[]
    | select(.enabled and (.command | test("midclt call disk\\.smart_test")))
    | {type: (.command | capture("disk\\.smart_test +(?<t>[A-Z]+)").t),
       disks: (try (.command | capture("(?<j>\\[.*\\])").j | fromjson) catch []),
       schedule}
    | .all_disks = (.disks == ["*"])]' 2>/dev/null)
fi
[ -z "$disks" ] && { warn "disk.query failed — disk coverage not checked"; disks="[]"; }
if [ -z "$tests" ]; then
  fail "could not read the SMART test schedule (smart.test.query and cronjob.query both failed)"
else
  for type in SHORT LONG; do
    t=$(jq -r --arg t "$type" \
      '[.[] | select(.type == $t)] | if length == 0 then "none"
       else .[0] | "cron \(.schedule.minute // "0") \(.schedule.hour) \(.schedule.dom) \(.schedule.month) \(.schedule.dow)\(if .all_disks then " (all disks)" else "" end)" end' \
      <<<"$tests")
    if [ "$t" = "none" ]; then
      fail "no $type SMART test scheduled — on 25.10+ add a cron job: midclt call disk.smart_test $type '[\"*\"]'"
    else
      ok "$type test scheduled: $t"
    fi
  done

  # every real disk covered by at least one test task, and SMART enabled on it
  uncovered=$(jq -rn --argjson tests "$tests" --argjson disks "$disks" '
    ($tests | map(select(.all_disks)) | length > 0) as $all
    | ([$tests[].disks[]?] | unique) as $covered
    | $disks[] | select(.type != null)
    | select(($all | not) and ((.identifier as $i | $covered | index($i)) | not))
    | .name')
  if [ -n "$uncovered" ]; then
    warn "disks not covered by any SMART test task: $(echo "$uncovered" | tr '\n' ' ')"
  else
    ok "all disks covered by the scheduled tests"
  fi

  smartoff=$(jq -r '.[] | select(.togglesmart == false) | .name' <<<"$disks")
  [ -n "$smartoff" ] && warn "SMART disabled on: $(echo "$smartoff" | tr '\n' ' ')"

  spindown=$(jq -r '.[] | select(.type == "HDD" and .hddstandby != "ALWAYS ON") | "\(.name)(\(.hddstandby))"' <<<"$disks")
  [ -n "$spindown" ] && warn "HDD standby/spindown set on: $(echo "$spindown" | tr '\n' ' ') — spindown fights scheduled tests and adds start/stop wear"
fi

# -------------------------------------------------------- per-disk SMART
hdr "Disk SMART data"
for dev in $(jq -r '.[] | select(.bus != "USB") | .name' <<<"${disks:-[]}" 2>/dev/null || lsblk -dno NAME | grep -E '^(sd|nvme)'); do
  j=$(smartctl -a -j "/dev/$dev" 2>/dev/null)
  if [ -z "$j" ] || [ "$(jq -r '.smart_status != null' <<<"$j")" != "true" ]; then
    warn "$dev: smartctl returned no SMART status"
    continue
  fi
  model=$(jq -r '.model_name // .device.name // "?"' <<<"$j")
  temp=$(jq -r '.temperature.current // "?"' <<<"$j")
  passed=$(jq -r '.smart_status.passed' <<<"$j")
  poh=$(jq -r '.power_on_time.hours // 0' <<<"$j")

  if jq -e '.nvme_smart_health_information_log' <<<"$j" >/dev/null; then
    read -r cw media used <<<"$(jq -r '.nvme_smart_health_information_log | "\(.critical_warning) \(.media_errors) \(.percentage_used)"' <<<"$j")"
    line="$dev ($model): ${temp}°C, ${poh}h powered on, ${used}% worn, media errors $media"
    if [ "$passed" != "true" ] || [ "$cw" != "0" ]; then
      fail "$line — SMART NOT healthy (critical_warning=$cw)"
    elif [ "$media" != "0" ]; then
      warn "$line"
    else
      ok "$line"
    fi
    last=$(jq -r '.nvme_self_test_log.table[0] // empty | "\(.self_test_result.string) @\(.power_on_hours)h"' <<<"$j")
  else
    attr() { jq -r --argjson id "$1" '[.ata_smart_attributes.table[]? | select(.id == $id)][0].raw.value // 0' <<<"$j"; }
    realloc=$(attr 5); reported=$(attr 187); pending=$(attr 197); offunc=$(attr 198); crc=$(attr 199)
    line="$dev ($model): ${temp}°C, ${poh}h powered on, realloc $realloc, pending $pending, uncorrectable $offunc, CRC $crc"
    if [ "$passed" != "true" ]; then
      fail "$line — overall SMART health FAILED, replace this disk"
    elif [ "$pending" -gt 0 ] || [ "$offunc" -gt 0 ] || [ "$reported" -gt 0 ]; then
      fail "$line — pending/uncorrectable sectors are pre-failure signs"
    elif [ "$realloc" -gt 0 ]; then
      warn "$line — reallocated sectors present; watch for growth"
    elif [ "$crc" -gt 0 ]; then
      warn "$line — CRC errors are usually a cable/backplane issue, not the disk"
    else
      ok "$line"
    fi
    last=$(jq -r '.ata_smart_self_test_log.standard.table[0] // empty | "\(.status.string) @\(.lifetime_hours)h"' <<<"$j")
  fi

  if [ -z "$last" ]; then
    warn "$dev: no self-test has ever run"
  else
    at=${last##*@}; at=${at%h}
    age=$(( poh - at ))
    # lifetime_hours wraps at 65536 on many ATA disks; ignore nonsense ages
    if [ "$age" -ge 0 ] && [ "$age" -lt 65536 ] && [ "$age" -gt 336 ]; then
      warn "$dev: last self-test ${age}h (~$((age / 24))d of uptime) ago (${last%% @*}) — should be <2 weeks"
    else
      ok "$dev: last self-test: ${last%% @*} (${age}h ago)"
    fi
  fi
done

# -------------------------------------------------------------- alerting
hdr "Alerts"
alerts=$(mc alert.list)
if [ -n "$alerts" ]; then
  active=$(jq '[.[] | select(.dismissed == false)]' <<<"$alerts")
  n=$(jq length <<<"$active")
  if [ "$n" -eq 0 ]; then
    ok "no active alerts"
  else
    warn "$n active alert(s):"
    jq -r '.[] | "        [\(.level)] \(.formatted // .text)"' <<<"$active" | cut -c1-160
  fi
fi

mailfrom=$(mc mail.config | jq -r '.fromemail // ""')
alertsvcs=$(mc alertservice.query | jq '[.[] | select(.enabled == true)] | length' 2>/dev/null || echo 0)
if [ -n "$mailfrom" ] || [ "${alertsvcs:-0}" -gt 0 ]; then
  ok "alert delivery configured (email from '${mailfrom:-—}', $alertsvcs alert service(s) enabled)"
else
  fail "no email and no alert service configured — a dying disk will be silent until you look at the GUI"
fi

# ------------------------------------------------------------- snapshots
hdr "Snapshot tasks"
snaps=$(mc pool.snapshottask.query)
if [ -n "$snaps" ]; then
  n=$(jq '[.[] | select(.enabled == true)] | length' <<<"$snaps")
  if [ "$n" -eq 0 ]; then
    warn "no enabled periodic snapshot tasks — app configs/datasets have no point-in-time protection"
  else
    ok "$n enabled snapshot task(s):"
    jq -r '.[] | select(.enabled == true)
      | [.dataset,
         ((.naming_schema | split("%")[0]) + "…"),
         "keep \(.lifetime_value) \(.lifetime_unit)",
         (if .recursive then "recursive" else "-" end),
         "cron \(.schedule.minute // "0") \(.schedule.hour // "*") \(.schedule.dom // "*") \(.schedule.month // "*") \(.schedule.dow // "*")"]
      | @tsv' <<<"$snaps" | sort | { column -t -s"$(printf '\t')" 2>/dev/null || cat; } | sed 's/^/        /'
    # Two tasks with the same naming schema on one dataset prune each other:
    # retention matches snapshots BY SCHEMA, so the shorter lifetime silently
    # deletes the longer tier's history (and same-minute runs collide on name).
    dups=$(jq -r '[.[] | select(.enabled == true) | {d: .dataset, s: (.naming_schema | split("%")[0])}]
      | group_by(.d + "|" + .s) | map(select(length > 1) | .[0] | "\(.d)(\(.s)…)") | .[]' <<<"$snaps")
    [ -n "$dups" ] && warn "same naming schema on multiple tasks for: $(echo "$dups" | tr '\n' ' ')— shortest lifetime wins, longer tiers get pruned"
  fi
fi

# ------------------------------------------------------------- schedules
# The GUI splits these across Data Protection (scrub/snapshot/cloudsync) and
# System → Advanced → Cron Jobs; merge them into one timetable, sorted by
# hour then minute.
hdr "Scheduled tasks (min hour dom month dow)"
sched() {
  jq -r --arg t "$1" --arg n "$2" '.[] | select(.enabled != false)
    | .schedule as $s
    | [($s.minute // "0"), ($s.hour // "*"), ($s.dom // "*"), ($s.month // "*"), ($s.dow // "*"), $t, (.[$n] // .command // "" | tostring | .[0:70])]
    | @tsv' 2>/dev/null
}
{
  mc cronjob.query | sched cron description
  mc pool.scrub.query | sched scrub pool_name
  mc pool.snapshottask.query | sched snapshot dataset
  mc cloudsync.query | sched cloudsync description
} | sort -t"$(printf '\t')" -k2,2n -k1,1n | { column -t -s"$(printf '\t')" 2>/dev/null || cat; } | sed 's/^/   /'

# ---------------------------------------------------------------- summary
printf '\n%s== Summary: ' "$B"
if [ "$FAILS" -gt 0 ]; then printf '%s%d FAIL%s, ' "$R" "$FAILS" "$B"; fi
if [ "$WARNS" -gt 0 ]; then printf '%s%d WARN%s ' "$Y" "$WARNS" "$B"; fi
if [ "$FAILS" -eq 0 ] && [ "$WARNS" -eq 0 ]; then printf 'all checks passed '; fi
printf '==%s\n' "$N"
[ "$FAILS" -gt 0 ] && exit 2
[ "$WARNS" -gt 0 ] && exit 1
exit 0
