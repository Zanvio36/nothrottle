#!/system/bin/sh
# nothrottle guard: two-stage thermal safety.
#   soft limit -> let clocks drop (soften), vendor thermal stays off
#   hard limit -> full stock restore
# args: <soc_hard_millidegC> <bat_hard_millidegC> <nothrottle_dir> [logdir] [soc_soft_millidegC]
SOC_LIMIT=${1:-80000}
BAT_LIMIT=${2:-47000}
DIR=${3:-.}
LOGDIR=${4:-$DIR}
SOFT_LIMIT=${5:-}

find_zone() {
  for z in /sys/class/thermal/thermal_zone*; do
    [ -f "$z/type" ] || continue
    [ "$(cat "$z/type" 2>/dev/null)" = "$1" ] && { printf '%s' "$z"; return 0; }
  done
  return 1
}

SOCZ=$(find_zone soc_max)
[ -z "$SOCZ" ] && SOCZ=$(find_zone soc_thermal)
[ -z "$SOCZ" ] && SOCZ=/sys/class/thermal/thermal_zone0
BATZ=$(find_zone battery)
softened=0

while :; do
  soc=$(cat "$SOCZ/temp" 2>/dev/null)
  bat=""
  [ -n "$BATZ" ] && bat=$(cat "$BATZ/temp" 2>/dev/null)

  case "$soc" in ''|*[!0-9]*) soc=0 ;; esac
  case "$bat" in ''|*[!0-9]*) bat=0 ;; esac

  if [ -n "$SOFT_LIMIT" ] && [ "$softened" = "0" ] && [ "$soc" -ge "$SOFT_LIMIT" ]; then
    echo "$(date) SOFTEN soc=$soc soft=$SOFT_LIMIT" >> "$LOGDIR/nothrottle.log"
    NOTHROTTLE_FROM_GUARD=1 sh "$DIR/nothrottle" soften >> "$LOGDIR/nothrottle.log" 2>&1
    softened=1
  fi

  if [ "$soc" -ge "$SOC_LIMIT" ] || { [ -n "$BATZ" ] && [ "$bat" -ge "$BAT_LIMIT" ]; }; then
    echo "$(date) TRIGGER soc=$soc bat=$bat limits=$SOC_LIMIT/$BAT_LIMIT soft=${SOFT_LIMIT:-none}" >> "$LOGDIR/nothrottle.log"
    NOTHROTTLE_FROM_GUARD=1 sh "$DIR/nothrottle" restore >> "$LOGDIR/nothrottle.log" 2>&1
    exit 0
  fi
  sleep 20
done
