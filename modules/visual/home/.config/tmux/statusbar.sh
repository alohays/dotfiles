#!/bin/sh

segment_wrap() {
  color=$1
  icon=$2
  text=$3
  [ -n "$text" ] || return 0
  printf '#[fg=%s,bg=colour235,nobold]#[fg=colour255,bg=%s]%s %s#[default]' "$color" "$color" "$icon" "$text"
}

_gradient_color() {
  pct=$1
  if [ "$pct" -gt 80 ]; then
    printf '%s' 'colour196'
  elif [ "$pct" -gt 50 ]; then
    printf '%s' 'colour220'
  else
    printf '%s' 'colour76'
  fi
}

cpu_segment() {
  case $(uname -s) in
    Darwin)
      # Use ps to sum CPU% across all processes — much lighter than top -l 2.
      # Normalize by CPU count since ps reports per-core percentages.
      _ncpu=$(sysctl -n hw.ncpu 2>/dev/null || printf 1)
      usage=$(ps -A -o %cpu | awk -v ncpu="$_ncpu" '{ sum += $1 } END { v = sum / ncpu; printf "%d", (v > 100 ? 100 : v) }')
      ;;
    Linux)
      usage=$(awk '{ v = $1 * 100 / '"$(nproc 2>/dev/null || printf 1)"'; printf "%d", (v > 100 ? 100 : v) }' /proc/loadavg 2>/dev/null || true)
      ;;
    *) usage= ;;
  esac
  [ -n "$usage" ] || return 0
  color=$(_gradient_color "$usage")
  segment_wrap "$color" '󰻠' "${usage}%"
}

ram_segment() {
  pct=0
  case $(uname -s) in
    Darwin)
      command -v vm_stat >/dev/null 2>&1 || return 0
      eval "$(vm_stat | awk '/Pages active|Pages wired down|Pages free|Pages inactive/ {gsub("\\.", "", $NF); k=tolower($2); sub(/:/, "", k); v[k]+=$NF} END {
        total=v["active"]+v["wired"]+v["free"]+v["inactive"]
        used_val=v["active"]+v["wired"]
        if (total>0) printf "pct=%d used_display=%.1fG", used_val*100/total, used_val*4096/1024/1024/1024
      }')"
      ;;
    Linux)
      command -v free >/dev/null 2>&1 || return 0
      eval "$(free -m | awk '/^Mem:/ { if ($2>0) printf "pct=%d used_display=%.1fG", ($3+$5)*100/$2, ($3+$5)/1024 }')"
      ;;
    *) return 0 ;;
  esac
  [ -n "${used_display:-}" ] || return 0
  color=$(_gradient_color "$pct")
  segment_wrap "$color" '󰍛' "$used_display"
}

case "${1:-}" in
  cpu)
    cpu_segment
    ;;
  ram)
    ram_segment
    ;;
  *)
    exit 0
    ;;
esac
