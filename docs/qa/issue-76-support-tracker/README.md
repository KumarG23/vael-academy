# Issue #76 — Journal support tracker

Functional runtime acceptance for MASTER_PLAN §§1–2, §6 WO-9.7 and §10 GH-76; ACADEMY_BIBLE §3 (Common Hall and relationships). This reads existing earned support state and authored Kai chains. It adds no support rules, dialogue, titles, art, relationships, or canon. No contradiction with the owning documents was found.

## Runtime provenance

- **Production source:** `b99e1befa1e10ecc73878e9840614932f323694c` (accepted #72 integrated by a normal merge; GH-76 production source unchanged).
- **Renderer:** Godot 4.7.2 stable, Vulkan Forward+ on llvmpipe (LLVM 20.1.2, 256-bit). Desktop was 1280×720; the maximized game client measured 1280×669. The compact window was resized to 800×480. Captures show the in-game campus behind the Journal and omit desktop decorations.
- **Checkpoint:** byte-for-byte source `docs/qa/issue-5-school-loop/emberwing-return-save.json`, SHA-256 `681e0c32af7483a6b48abdfe2c0c612ee65cf5450352d62ca5a8a431275b1fe4` (native Emberwing Week 2 campus return).
- **Fixture:** source copied to a disposable profile and only these existing `campaign.support_save` values changed; fixture JSON SHA-256 before first launch: `a6d28485199a88c2cd64aa0b2b9048c6bc78081eb074238e9d90aaa1a9b52719`.

| Existing field | Checkpoint | Fixture |
| --- | --- | --- |
| `points.kai_kael` | 10 | 60 |
| `points.kai_liora` | 0 | 20 |
| `ranks.kai_kael` | empty | B |
| `ranks.kai_liora` | empty | C |
| `viewed` | `{}` | `kai_kael:C=true`, `kai_kael:B=false`, `kai_liora:C=false` |

These are fixture values for display coverage; no rank is claimed as naturally earned. No other fixture field was changed.

## Real input and results

1. Launched the shipped Title screen with the original renderer and selected **Load Game → Slot 0** using the keyboard.
2. Pressed J and navigated with six Right inputs to Supports. The default and compact views show current roster companions Kael and Liora, ranks B/C, Kael C **Viewed**, Kael B **Unviewed**, and Liora C **Unviewed**. No future conversation title or prose appears. Compact Down navigation selects Liora.
3. Used the existing Journal **System → Save — Slot 1** action. The game displayed “Saved to slot 1”. Closed the Journal with J and exited normally with Alt+F4.
4. Started a fresh Title process, selected **Load Game → Slot 0**, then reopened Supports with J and Right inputs. The same ranks and viewed states appeared. The normal System-saved file SHA-256 was `4933870a3953587e78419a0a58f3ce9ada9b4aafa5219bf015cc33fa31a67d2a`; the file remained byte-identical after the fresh load and subsequent read-only navigation.
5. Closed Journal and walked through the existing **The Great Hall → The Common Hall** doors. At the existing “Gather by the fire (bonds)” point, opened the archive with Return. It listed **Kai + Kael C ✓**, **Kai + Kael B**, and **Kai + Liora C**. No entry was selected, replayed, or completed; the viewed receipt did not change. Closed the menu and exited with Alt+F4.

All graphical game, input, and capture jobs ended before the desktop was explicitly released to issue #81. This is bounded functional acceptance, not a whole-school replay or Neal visual/taste approval.

## Captures

- [Supports, default window](images/support-default.png)
- [Supports, compact window](images/support-compact.png)
- [Compact companion navigation on Liora](images/support-compact-scrolled.png)
- [Supports after normal Save → fresh Title load](images/reloaded-default.png)
- [Existing Common Hall archive with viewed receipt](images/common-hall-archive.png)
