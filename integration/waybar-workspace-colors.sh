#!/usr/bin/env bash
# waybar-workspace-colors.sh — Generate CSS for top-bar workspace coloring
# based on agent session state. Source the generated CSS in your top waybar.

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LIB_DIR="$PROJECT_ROOT/lib"
OUTPUT_FILE="$SCRIPT_DIR/waybar-import.css"

source "$LIB_DIR/state.sh"

state_init

css=""

for session in $(state_list_sessions); do
    workspace="$(state_read_session "$session" "workspace" 2>/dev/null || echo "")"
    state="$(state_read_session "$session" "state" 2>/dev/null || echo "idle")"
    idle_since="$(state_read_session "$session" "idle_since" 2>/dev/null || echo "")"

    if [[ -z "$workspace" ]]; then
        continue
    fi

    now="$(date +%s)"

    if [[ "$state" == "working" ]]; then
        color="#f0a050"
    elif [[ -n "$idle_since" ]] && (( now - idle_since > 600 )); then
        color="#e06060"
    else
        color="#60c060"
    fi

    css+="
#workspaces button.workspace-${workspace} {
    color: ${color};
    border-bottom: 2px solid ${color};
}
"
done

echo "$css" > "$OUTPUT_FILE"

# Signal top waybar to reload styles (SIGUSR2)
pkill -SIGUSR2 -f "waybar.*top" 2>/dev/null || true
