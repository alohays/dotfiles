#!/bin/sh

segment_wrap() {
  color=$1
  icon=$2
  text=$3
  [ -n "$text" ] || return 0
  printf '#[fg=%s,bg=colour235,nobold]#[fg=colour255,bg=%s]%s %s#[default]' "$color" "$color" "$icon" "$text"
}

cpu_segment() {
  case $(uname -s) in
    Darwin)
      command -v top >/dev/null 2>&1 || return 0
      usage=$(top -l 2 -n 0 | awk '/^CPU usage:/ { sub(/%/ ,"", $3); sub(/%/, "", $5); value=$3+$5 } END { if (value != "") printf "%d%%", value }')
      ;;
    Linux)
      usage=$(awk '{ print $1 }' /proc/loadavg 2>/dev/null || true)
      [ -n "$usage" ] && usage="load $usage"
      ;;
    *) usage= ;;
  esac
  segment_wrap colour160 '󰻠' "$usage"
}

ram_segment() {
  case $(uname -s) in
    Darwin)
      command -v vm_stat >/dev/null 2>&1 || return 0
      used=$(vm_stat | awk '/Pages active|Pages wired down/ {gsub("\\.", "", $3); pages += $3} END { if (pages) printf "%.1fG", pages * 4096 / 1024 / 1024 / 1024 }')
      ;;
    Linux)
      command -v free >/dev/null 2>&1 || return 0
      used=$(free -m | awk '/^Mem:/ { printf "%.1fG", ($3+$5)/1024 }')
      ;;
    *) used= ;;
  esac
  segment_wrap colour94 '󰍛' "$used"
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
