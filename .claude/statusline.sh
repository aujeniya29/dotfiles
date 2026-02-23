#!/usr/bin/env bash
# Claude Code statusline — single line, theme-aware (reads ~/.config/theme)
# Receives JSON session data on stdin.

set -euo pipefail

input=$(cat)
val() { echo "$input" | jq -r "$1 // empty"; }

# --- Theme-aware colors ---
theme=$(cat ~/.config/theme 2>/dev/null || echo "macchiato")
if [[ "$theme" == "latte" ]]; then
  # Light mode: dark text, muted separators
  sep="\033[38;5;248m\033[0m"
  txt="\033[38;5;237m"
  dim="\033[38;5;245m"
  grn="\033[38;5;28m"
  ylw="\033[38;5;130m"
  red="\033[38;5;160m"
  add="\033[38;5;28m"
  del="\033[38;5;160m"
else
  # Dark mode: light text, subtle separators
  sep="\033[38;5;240m\033[0m"
  txt="\033[38;5;252m"
  dim="\033[38;5;245m"
  grn="\033[38;5;114m"
  ylw="\033[38;5;220m"
  red="\033[38;5;203m"
  add="\033[38;5;114m"
  del="\033[38;5;203m"
fi
rst="\033[0m"

# --- Directory (~ shorthand) ---
cwd=$(val '.cwd')
short_dir="${cwd/#$HOME/\~}"

# --- Model ---
model=$(val '.model.display_name')

# --- Git branch ---
branch=""
if command -v git &>/dev/null; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
        || git -C "$cwd" rev-parse --short HEAD 2>/dev/null \
        || true)
fi

# --- Context window bar ---
pct=$(echo "$input" | jq '.context_window.used_percentage // 0')
pct_int=${pct%.*}
bar_w=12
filled=$(( pct_int * bar_w / 100 ))
empty=$(( bar_w - filled ))

if (( pct_int >= 90 )); then bar_color="$red"
elif (( pct_int >= 70 )); then bar_color="$ylw"
else bar_color="$grn"; fi

bar="${bar_color}"
for (( i=0; i<filled; i++ )); do bar+="█"; done
for (( i=0; i<empty; i++ )); do bar+="░"; done
bar+="${rst} ${pct_int}%"

# --- Lines added/removed ---
lines_add=$(echo "$input" | jq '.cost.total_lines_added // 0')
lines_del=$(echo "$input" | jq '.cost.total_lines_removed // 0')
lines="${add}+${lines_add}${rst}/${del}-${lines_del}${rst}"

# --- Duration ---
duration_ms=$(echo "$input" | jq '.cost.total_duration_ms // 0')
duration_s=$(( ${duration_ms%.*} / 1000 ))
if (( duration_s >= 60 )); then
  dur="$(( duration_s / 60 ))m$(( duration_s % 60 ))s"
else
  dur="${duration_s}s"
fi

# --- Build line ---
parts=()
parts+=("${txt}${short_dir}${rst}")
[[ -n "$branch" ]] && parts+=("${dim} ${branch}${rst}")
parts+=("${txt}${model}${rst}")
parts+=("${bar}")
parts+=("${lines}")
parts+=("${dim}${dur}${rst}")

# Join with separator
line=""
for i in "${!parts[@]}"; do
  (( i > 0 )) && line+=" ${sep} "
  line+="${parts[$i]}"
done

printf '%b' "$line"
