# Issue #15: castle toast layout evidence

Repairs the delivered MASTER_PLAN §10 WO-4.4 text-clipping polish and WO-6.4 waterside fishing feedback (ACADEMY_BIBLE §3). Text, reward quantities, fishing timing and catch weights are unchanged.

## Defect (baseline `f975683c`, QA #5)

[QA #5 `fishing-result.png`](../issue-5-school-loop/images/fishing-result.png) shows `Caught a Warded Coin! (x1)` cut off as `Caught a War…` at the right edge. [`archive-initial.png`](../issue-5-school-loop/images/archive-initial.png) shows the same fault on the Common Hall support message. `CastleScene._ready()` set the toast's `position` (`viewport.x / 2 - 260`) **before** `add_child`, so the zero-size parent rect turned it into an offset from the 0.5 anchor. At 1280×720 the label started at x = 640 + 380 = **1020**, at least 520 px wide (HANDOFF gotcha 7).

The new regression test measured the unchanged code at these rects:

| Viewport | Message | Toast rect |
|---|---|---|
| 1280×720 | fishing catch | x 1020, w 520 (right edge 1540) |
| 1280×720 | `No bonds strong enough yet — …` | x 1020, w 714 |
| 640×360 | same support message | x 380, w 714 |
| 800×450 after resize | fishing catch | x 780, w 520 |

## Repair

The toast is anchored `PRESET_TOP_WIDE`, with 40 px side offsets and a top of 60 px. It has centered `AUTOWRAP_WORD_SMART` text, and its height is refitted on every `_toast()`. Anchors keep it centered and in bounds when the viewport resizes.

## Rendered check

`capture_toast.gd` runs the real castle scene in the Waterside under Godot 4.7.2 Forward+ (Vulkan llvmpipe) on a private virtual X display. It does not use the shared QA desktop, and game data is disposable. It waits for the arrival title card to fade, sends a catch through the real `_start_fishing()` → `finished` → `_on_fishing_done` path, then saves the rendered viewport and the toast's laid-out global rect.

```
xvfb-run -a -s "-screen 0 1280x720x24" env CAP_OUT=<out dir> XDG_DATA_HOME=<disposable> \
  godot --path . --resolution 1280x720 -s res://docs/qa/issue-15-toast-layout/capture_toast.gd
```

The folder's `.gdignore` keeps the editor from importing these captures; the script still runs from its `res://` path.

| Capture | Toast global rect | Lines |
|---|---|---|
| [fishing 1280×720](images/toast-fishing-1280x720.png) | (40, 60) 1200×34 | 1 |
| [support 1280×720](images/toast-support-1280x720.png) | (40, 60) 1200×34 | 1 |
| [long mission 1280×720](images/toast-long-1280x720.png) | (40, 60) 1200×34 | 1 |
| [fishing 800×450](images/toast-fishing-800x450.png) | (40, 60) 720×34 | 1 |
| [long mission 800×450](images/toast-long-800x450.png) | (40, 60) 720×71 | 2 (wrapped) |

All captures were inspected: the full text is drawn, centered, and inside the frame.

**Evidence boundary:** these are offscreen renders driven by script, not real keyboard play on the shared desktop. QA #5 is the sole GUI controller and owns the graphical retest. No Neal visual approval is claimed.

**Observation, unchanged:** during the arrival title card (1.5 s hold + 0.45 s fade) the card is drawn over the same top band. A catch can't land that quickly, and this draw order predates the repair.
