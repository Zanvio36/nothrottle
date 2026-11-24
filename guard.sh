#!/system/bin/sh
# nothrottle guard: restore stock when SOC or battery temperature is too high.
# args: <soc_limit_millidegC> <bat_limit_millidegC> <nothrottle_dir>
SOC_LIMIT=${1:-80000}
BAT_LIMIT=${2:-47000}
DIR=${3:-.}
LOGDIR=${4:-$DIR}

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

while :; do
  soc=$(cat "$SOCZ/temp" 2>/dev/null)
  bat=""
  [ -n "$BATZ" ] && bat=$(cat "$BATZ/temp" 2>/dev/null)

  case "$soc" in ''|*[!0-9]*) soc=0 ;; esac
  case "$bat" in ''|*[!0-9]*) bat=0 ;; esac

  if [ "$soc" -ge "$SOC_LIMIT" ] || { [ -n "$BATZ" ] && [ "$bat" -ge "$BAT_LIMIT" ]; }; then
    echo "$(date) TRIGGER soc=$soc bat=$bat limits=$SOC_LIMIT/$BAT_LIMIT" >> "$LOGDIR/nothrottle.log"
    NOTHROTTLE_FROM_GUARD=1 sh "$DIR/nothrottle" restore >> "$LOGDIR/nothrottle.log" 2>&1
    exit 0
  fi
  sleep 20
done
