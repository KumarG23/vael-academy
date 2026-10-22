# Issue #40 — castle calendar resize retest

Focused real-window retest of the current-week/event label in the castle, using
the native Emberwing Week 2 return fixture from the issue #5 QA set. The fixture
was copied into disposable player data; no player save was changed.

## Basis

- MASTER_PLAN §1 (school slice), §6 (WO-4.4 clipping polish and WO-7.1
  calendar), and §10 (GH-40 status).
- ACADEMY_BIBLE §4 (calendar and traditions): the current week/event remains
  visible as campus context. This retest does not define the semester schedule
  or resolve the separate calendar mapping in issue #30.
- Code under test: `3cb3e789b8dc12d09945fbe8d30894ddde3bda1f` (PR #47).
  The following evidence commit adds this receipt and captures only.

## Run and observations

Godot 4.7.2, Forward+ renderer, and a real Godot window with real X11 resize
operations. The unchanged native save loaded through Title → Load Game. Its
label read `Week 2 — Term begins` before, during, and after resizing the same
castle scene. The window client was resized in order:

| Client size | Result | Capture |
| --- | --- | --- |
| 1280×720 | Label visible at upper right | [initial](images/calendar-1280.png) |
| 800×450 | Full label visible at upper right | [small](images/calendar-800.png) |
| 640×360 | Full label visible at upper right | [smallest](images/calendar-640.png) |
| 1280×720 | Full label visible after restore | [restored](images/calendar-1280-restored.png) |

The shared graphical desktop framebuffer is 1280×720. The 1280 captures show
the portion of that client visible inside the framebuffer; the date label is
fully within the captured area. The automated live-viewport test separately
checks exact laid-out bounds at all four sizes, including the full 1280×720
viewport.

This was a display-only retest; it did not trigger campaign progression. No
calendar/event text or toast behavior was changed. Issue #30 remains unresolved.
No story or calendar decisions are introduced here.
