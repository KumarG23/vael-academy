# Issue #68 — earned catches in the Academy Journal

## Runtime evidence

- **Source:** `651e3336120928a35938c69df2f8c947b1b9bbec` (`GH-68: Display earned catches in Academy Journal`).
- **Fixture:** fresh disposable game profile with no prior slot save. Launched the shipped title, chose Dev Jump → Campus, walked through the visible Waterside door, approached the existing “Cast a line” point, completed the normal timing minigame with real keyboard input, and caught one Silver Dace. Opened Journal → Fish Log and observed `Silver Dace ×1`. Used Journal → System → Save — Slot 1, quit the process, launched a fresh process, loaded Slot 1 from the title screen, and reopened Fish Log; the same `Silver Dace ×1` remained visible. No fixture data was injected and no campaign/save values were edited outside normal gameplay.
- **Renderer:** Godot 4.7.2 stable, Vulkan Forward+ on llvmpipe (LLVM 20.1.2, 256-bit). Desktop capture resolution was 1280×720. The default game viewport was 1152×648; compact viewport was resized to 800×480. Images are cropped to the game client viewport, excluding desktop decorations.
- **Inspection:** empty state at default size; earned catch before save; same saved catch after fresh-process load; populated Fish Log at compact size. The compact tab row wraps and the log label/count remain readable inside the Journal.

## Captures

- [Empty log, default viewport](images/empty-default.png)
- [Earned catch, default viewport](images/earned-default.png)
- [Slot 1 after fresh load, default viewport](images/reloaded-default.png)
- [Slot 1 after fresh load, compact viewport](images/reloaded-compact.png)

Automated production-path tests additionally cover multiple names/counts, Warded Coin, unknown saved keys, empty state, navigation/close input consumption, state and RNG invariance, and Campaign/SaveSystem round trip. This runtime pass demonstrates one existing normal fishing result and one normal slot save/load path; it does not claim coverage of every catch outcome or Neal's visual approval.
