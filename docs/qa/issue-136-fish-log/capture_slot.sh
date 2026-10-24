#!/usr/bin/env bash
set -euo pipefail

project=${GODOT_SLOT_PROJECT:?run inside the task-owned Godot slot}
artifact_dir=${GODOT_SLOT_ARTIFACTS:?run inside the task-owned Godot slot}
qa_dir="$project/docs/qa/issue-136-fish-log"
image_dir="$qa_dir/images"
checkpoint="$project/docs/qa/issue-5-school-loop/emberwing-return-save.json"
profile_root="$XDG_DATA_HOME/godot/app_userdata/Vael Academy"
save_dir="$profile_root/saves"
common_dir=$(git -C "$project" rev-parse --git-common-dir)
exec 9>"$common_dir/vael-godot-heavy.lock"
flock -x 9
mkdir -p "$image_dir" "$artifact_dir"
fullscreen=0

capture() {
	local label=$1 width=$2 height=$3 window=$4
	if [[ "$width" == 1280 && "$height" == 720 ]]; then
		if [[ "$fullscreen" == 0 ]]; then
			xdotool key --clearmodifiers alt+F11
			fullscreen=1
		fi
	else
		if [[ "$fullscreen" == 1 ]]; then
			xdotool key --clearmodifiers alt+F11
			fullscreen=0
		fi
		xdotool windowsize --sync "$window" "$width" "$height"
		xdotool windowmove --sync "$window" 0 0
	fi
	sleep 1
	{
		printf '%s requested=%sx%s ' "$label" "$width" "$height"
		xwininfo -id "$window" | awk '/Width:|Height:/ { printf "%s ", $2 } END { print "" }'
	} >> "$artifact_dir/window-sizes.txt"
	ffmpeg -hide_banner -loglevel error -y -f x11grab -video_size 1280x720 -i "$DISPLAY" \
		-frames:v 1 "$image_dir/$label.png"
}

seed_slot() {
	local mode=$1
	rm -rf "$profile_root"
	mkdir -p "$save_dir"
	python3 - "$checkpoint" "$save_dir/slot_0.json" "$mode" <<'PY'
import json, sys
source, target, mode = sys.argv[1:]
payload = json.load(open(source, encoding="utf-8"))
if mode == "empty":
    payload["campaign"]["fish_log"] = {}
elif mode == "supplemental":
    payload["campaign"]["fish_log"] = {
        "Lakeperch": 1,
        "Silver Dace": 123456789,
        "Unknown Accepted Save Catch With a Deliberately Long Name": 4,
        "Vael Kingfish": 2,
        "Warded Coin": 3,
    }
with open(target, "w", encoding="utf-8") as output:
    json.dump(payload, output, indent="\t")
    output.write("\n")
PY
}

run_case() {
	local mode=$1
	fullscreen=0
	seed_slot "$mode"
	local before
	before=$(sha256sum "$save_dir/slot_0.json" | cut -d' ' -f1)
	local log="$artifact_dir/$mode-game.log"
	(
		cd "$project"
		exec godot --path "$project" --windowed --resolution 1280x720 >"$log" 2>&1
	) &
	local game_pid=$!
	local window=""
	for _ in $(seq 1 100); do
		window=$(xdotool search --onlyvisible --name 'Vael Academy' 2>/dev/null | tail -1 || true)
		if [[ -n "$window" ]]; then break; fi
		sleep 0.2
	done
	if [[ -z "$window" ]]; then
		cat "$log"
		kill "$game_pid" 2>/dev/null || true
		wait "$game_pid" 2>/dev/null || true
		return 1
	fi
	xdotool windowactivate --sync "$window"
	# Start unmaximized at a size that fits below the XFWM title bar. Exact
	# 1280×720 captures use EWMH fullscreen; compact captures use windowed size.
	xdotool key --clearmodifiers alt+F10
	xdotool windowsize --sync "$window" 1152 648
	xdotool windowmove --sync "$window" 0 0
	sleep 2
	# Title → Load Game → the one seeded slot. These are real window key events.
	xdotool key --clearmodifiers Down
	sleep 0.25
	xdotool key --clearmodifiers Return
	sleep 0.5
	xdotool key --clearmodifiers Return
	sleep 5
	xdotool key --clearmodifiers j
	xdotool key --clearmodifiers --repeat 5 --delay 180 Right
	sleep 1
	if [[ "$mode" == "checkpoint" ]]; then
		capture checkpoint-fish-default 1280 720 "$window"
		capture checkpoint-fish-800 800 450 "$window"
		capture checkpoint-fish-640 640 360 "$window"
		capture checkpoint-fish-restore 1280 720 "$window"
	elif [[ "$mode" == "empty" ]]; then
		capture empty-fish-default 1280 720 "$window"
		capture empty-fish-800 800 450 "$window"
		capture empty-fish-640 640 360 "$window"
		capture empty-fish-restore 1280 720 "$window"
	else
		capture supplemental-first-default 1280 720 "$window"
		# Up from the first row wraps to the final row; Down returns to first.
		xdotool key --clearmodifiers Up
		sleep 0.35
		capture supplemental-wrap-final 1280 720 "$window"
		xdotool key --clearmodifiers Down
		xdotool key --clearmodifiers Down
		sleep 0.35
		# Select the large saved quantity (Silver Dace) in the sorted list.
		capture supplemental-large-count-640 640 360 "$window"
		capture supplemental-large-count-800 800 450 "$window"
		capture supplemental-large-count-restore 1280 720 "$window"
		xdotool key --clearmodifiers Down
		sleep 0.35
		capture supplemental-long-name-640 640 360 "$window"
		capture supplemental-long-name-800 800 450 "$window"
		capture supplemental-long-name-restore 1280 720 "$window"
	fi
	# J/Escape returns to exploration; ordinary movement remains available.
	xdotool key --clearmodifiers Escape
	sleep 0.5
	xdotool key --clearmodifiers --repeat 3 --delay 120 Right
	sleep 0.5
	capture "$mode-exploration-after-close" 1280 720 "$window"
	local after
	after=$(sha256sum "$save_dir/slot_0.json" | cut -d' ' -f1)
	printf '%s slot_sha256_before=%s slot_sha256_after=%s settings_exists=%s autosave_exists=%s\n' \
		"$mode" "$before" "$after" \
		"$(test -e "$profile_root/settings.cfg" && echo yes || echo no)" \
		"$(test -e "$save_dir/autosave.json" && echo yes || echo no)" >> "$artifact_dir/file-provenance.txt"
	# Close normally through the window manager, then verify process exit.
	xdotool key --clearmodifiers alt+F4 || true
	for _ in $(seq 1 50); do
		kill -0 "$game_pid" 2>/dev/null || break
		sleep 0.2
	done
	if kill -0 "$game_pid" 2>/dev/null; then
		kill -TERM "$game_pid"
	fi
	wait "$game_pid" || true
	if rg -n 'SCRIPT ERROR|Parse Error|Failed to load script' "$log"; then
		return 1
	fi
}

run_case checkpoint
run_case empty
run_case supplemental
sha256sum "$checkpoint" > "$artifact_dir/source-checkpoint.sha256"
sha256sum "$image_dir"/*.png > "$artifact_dir/capture-sha256.txt"
