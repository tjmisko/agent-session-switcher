#!/usr/bin/env bash
# wm_helper.bash — WM test helpers (Hyprland-specific)
# Provides skip logic and WM assertion functions for real compositor tests.

skip_without_hyprland() {
    # WM tests are true end-to-end tests that launch windows via
    # hyprctl dispatch exec.  Subprocesses spawned that way do NOT
    # inherit the test harness environment (STATE_DIR, TMUX_SOCKET, …),
    # so these tests can only work in a purpose-built environment.
    # Gate on an explicit opt-in flag to avoid false failures.
    if [[ "${RUN_WM_TESTS:-}" != "1" ]]; then
        skip "WM tests disabled (set RUN_WM_TESTS=1 to enable)"
    fi
    if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        skip "Hyprland not running (HYPRLAND_INSTANCE_SIGNATURE unset)"
    fi
    # Remove stub so real hyprctl is used
    rm -f "$STUBS_DIR/hyprctl" 2>/dev/null || true
    if ! command -v hyprctl &>/dev/null; then
        skip "hyprctl not found"
    fi
    if ! hyprctl version &>/dev/null; then
        skip "Hyprland not responding"
    fi
}

# --- WM assertions ---

assert_workspace() {
    local expected_id="$1"
    local actual
    actual="$(hyprctl activeworkspace -j | jq -r '.id')"
    [[ "$actual" == "$expected_id" ]] || {
        echo "Expected workspace $expected_id, got $actual" >&2
        return 1
    }
}

assert_window_class_exists() {
    local class="$1"
    local timeout="${2:-5}"
    wait_for_window "$class" "$timeout"
}

assert_window_fullscreen() {
    local class="$1"
    local fullscreen
    fullscreen="$(hyprctl clients -j | jq -r ".[] | select(.class == \"$class\") | .fullscreen")"
    [[ "$fullscreen" == "1" || "$fullscreen" == "true" ]] || {
        echo "Window $class is not fullscreen (got: $fullscreen)" >&2
        return 1
    }
}

assert_window_not_fullscreen() {
    local class="$1"
    local fullscreen
    fullscreen="$(hyprctl clients -j | jq -r ".[] | select(.class == \"$class\") | .fullscreen")"
    [[ "$fullscreen" == "0" || "$fullscreen" == "false" ]] || {
        echo "Window $class is fullscreen (got: $fullscreen)" >&2
        return 1
    }
}

assert_window_count_on_workspace() {
    local workspace="$1"
    local expected="$2"
    local actual
    actual="$(hyprctl clients -j | jq "[.[] | select(.workspace.id == $workspace)] | length")"
    [[ "$actual" == "$expected" ]] || {
        echo "Expected $expected windows on workspace $workspace, got $actual" >&2
        return 1
    }
}

# --- WM helpers ---

wait_for_window() {
    local class="$1"
    local timeout="${2:-5}"
    local elapsed=0
    while true; do
        local found
        found="$(hyprctl clients -j | jq -r ".[] | select(.class == \"$class\") | .class" 2>/dev/null || echo "")"
        if [[ -n "$found" ]]; then
            return 0
        fi
        sleep 0.2
        elapsed=$(( elapsed + 1 ))
        if (( elapsed > timeout * 5 )); then
            echo "Timed out waiting for window with class $class" >&2
            return 1
        fi
    done
}

wait_for_window_gone() {
    local class="$1"
    local timeout="${2:-5}"
    local elapsed=0
    while true; do
        local found
        found="$(hyprctl clients -j | jq -r ".[] | select(.class == \"$class\") | .class" 2>/dev/null || echo "")"
        if [[ -z "$found" ]]; then
            return 0
        fi
        sleep 0.2
        elapsed=$(( elapsed + 1 ))
        if (( elapsed > timeout * 5 )); then
            echo "Timed out waiting for window $class to disappear" >&2
            return 1
        fi
    done
}

close_window_by_class() {
    local class="$1"
    hyprctl dispatch closewindow "class:$class" 2>/dev/null || true
}

get_workspace_of_window() {
    local class="$1"
    hyprctl clients -j | jq -r ".[] | select(.class == \"$class\") | .workspace.id"
}
