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
      _cache="${TMPDIR:-/tmp}/.tmux_cpu_cache"
      _lock="${TMPDIR:-/tmp}/.tmux_cpu_cache.lock"
      # Read previous cached reading (empty on first run → segment hidden once)
      usage=$(cat "$_cache" 2>/dev/null)
      # Clean stale lock (>10s — top normally finishes in ~2s)
      if [ -d "$_lock" ] && [ "$(( $(date +%s) - $(stat -f %m "$_lock" 2>/dev/null || echo 0) ))" -gt 10 ]; then
        rmdir "$_lock" 2>/dev/null
      fi
      # Refresh cache in background (atomic via mkdir lock)
      if mkdir "$_lock" 2>/dev/null; then
        {
          top -l 2 -n 0 2>/dev/null \
            | awk '/^CPU usage:/ { sub(/%/,"", $3); sub(/%/,"", $5); v=$3+$5 } END { if (v!="") printf "%d", v }' \
            > "$_cache"
          rmdir "$_lock" 2>/dev/null
        } &
      fi
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
