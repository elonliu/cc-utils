#!/usr/bin/env bash
# TUI for taskloop — requires fzf and jq
# Usage:
#   tui.sh list        — Show task list in fzf
#   tui.sh preview ID  — Show task details for fzf --preview

DATA_FILE="${TASKLOOP_DATA:-./taskloop-data.json}"

# Reload command used by fzf execute/reload (must be a single string)
RELOAD_CMD="bash '$0' list-raw '$DATA_FILE'"

for cmd in fzf jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd is required but not installed." >&2
    exit 1
  fi
done

status_icon() {
  case "$1" in
    pending) echo "⏳" ;;
    in_progress) echo "🔄" ;;
    completed) echo "✅" ;;
    failed) echo "❌" ;;
    deleted) echo "🗑️" ;;
    *) echo "❓" ;;
  esac
}

format_task() {
  local id="$1" subject="$2" status="$3" type="$4" priority="$5" locked="$6"
  local icon
  icon=$(status_icon "$status")
  local lock_mark=""
  [ "$locked" = "true" ] && lock_mark="🔒"
  local tags=""
  [ -n "$type" ] && tags="$tags [$type]"
  [ -n "$priority" ] && tags="$tags ($priority)"
  echo "  ${icon} #${id} ${subject} ${tags} ${lock_mark}"
}

cmd_list_raw() {
  # Output raw formatted task list (for fzf reload). $1=data_file, rest ignored.
  local df="${2:-$DATA_FILE}"
  if [ ! -f "$df" ]; then
    echo '{"tasks":[]}' > "$df"
  fi
  local output
  output=$(jq -r '.tasks[] | select(.status != "deleted") | [.id, .subject, .status, (.type // ""), (.priority // ""), ((.metadata.locked // false) | tostring)] | @tsv' "$df" 2>/dev/null)
  if [ -z "$output" ]; then
    echo "No tasks in queue."
  else
    echo "$output" | while IFS=$'\t' read -r id subject status type priority locked; do
      format_task "$id" "$subject" "$status" "$type" "$priority" "$locked"
    done
  fi
}

cmd_delete() {
  local line="$1"
  local id
  # Extract task ID from formatted line like "  ⏳ #123 Subject [type] (priority)"
  id=$(echo "$line" | grep -oE '#[0-9]+' | head -1 | tr -d '#')
  if [ -z "$id" ]; then
    echo "Error: could not extract task ID from: $line" >&2
    return 1
  fi
  local tmp="${DATA_FILE}.tmp.$$"
  if jq --arg id "$id" '(.tasks[] | select(.id == $id)).status = "deleted"' "$DATA_FILE" > "$tmp" 2>/dev/null && mv "$tmp" "$DATA_FILE"; then
    echo "Deleted task #$id" >&2
  else
    echo "Error: failed to delete task #$id" >&2
    rm -f "$tmp"
    return 1
  fi
}

cmd_list() {
  if [ ! -f "$DATA_FILE" ]; then
    echo '{"tasks":[]}' > "$DATA_FILE"
  fi

  local tasks
  tasks=$(jq -r '.tasks[] | select(.status != "deleted") | [.id, .subject, .status, (.type // ""), (.priority // ""), ((.metadata.locked // false) | tostring)] | @tsv' "$DATA_FILE" 2>/dev/null)

  if [ -z "$tasks" ]; then
    echo "No tasks in queue."
    return 0
  fi

  echo "$tasks" | while IFS=$'\t' read -r id subject status type priority locked; do
    format_task "$id" "$subject" "$status" "$type" "$priority" "$locked"
  done | fzf --ansi --height 40% --reverse \
    --preview "bash '$0' preview \$(echo {+} | grep -oE '#[0-9]+' | head -1 | tr -d '#')" \
    --bind "enter:accept" \
    --bind "q:abort" \
    --bind "ctrl-d:execute(bash '$0' delete {+})+reload($RELOAD_CMD)" \
    --bind "ctrl-r:reload($RELOAD_CMD)" \
    --prompt="taskloop> " \
    --header="Enter: select | Ctrl-D: delete | Ctrl-R: refresh | q: quit"
}

cmd_preview() {
  local id="$1"
  if [ ! -f "$DATA_FILE" ]; then
    echo "No data file"
    return
  fi
  jq -r --arg id "$id" '
    .tasks[] | select(.id == $id) |
    "ID: \(.id)\nSubject: \(.subject)\nStatus: \(.status)\nType: \(.type // "none")\nPriority: \(.priority // "none")\nLocked: \(.metadata.locked // false)\n\nDescription:\n\(.description // "(none)")"
  ' "$DATA_FILE" 2>/dev/null || echo "Task #$id not found"
}

case "$1" in
  list) cmd_list ;;
  list-raw) cmd_list_raw "$@" ;;
  preview) cmd_preview "$2" ;;
  delete) cmd_delete "$2" ;;
  *) echo "Usage: $0 {list|list-raw|preview|delete}" ;;
esac
