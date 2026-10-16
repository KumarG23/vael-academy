# Spellbooks & Kai's Magic — design note (Neal, 2026-07-09)

*Design capture for the spell-acquisition system. Crownspark (AW-51) is built;
the spellbook economy lands with merchants / the Town of Vael (M10).*

## The premise

Kai's magic **awakened** — that's why he was sent to Vael Academy. His innate
spell is **Crownspark** (First Crown royal magic, school `"crown"`, outside the
anima triangle): a spinning emerald circlet that crowns whatever it strikes.
It's not from a book and never runs out (999 uses). **Control is not immediate:**
the cave gives his mark and involuntary flares; player-usable Crownspark waits
for the later Vision (July 10 lock, reaffirmed VS-1B). The runtime requires
`crownspark_unlocked`, including for older saved inventories. A bound inventory
entry or the `kai_awakened` flag alone never grants control. The Vision scene
itself remains to be authored and wired.

Unlike the mage heirs (who learn by class/level), **Kai learns magic the hard
way: spellbooks.** Each spellbook is a rare, physical item that permanently
teaches Kai one spell. He can learn MANY — his royal blood makes him the
flexible caster — but every book has to be *earned*.

## How spellbooks are acquired (all three routes, by design)

1. **Boss drops** — a really tough boss (chapter bosses, deep arena milestone
   waves) can drop a spellbook. Rare; the chase reward.
2. **Academics** — score **100% on a hard exam** and the faculty awards one
   (feeds the grading system's Coursework loop; makes tests worth sweating).
3. **Coin** — the Vael town merchants stock a few, **really expensive**
   (the gold sink for arena winnings).

## Mechanics sketch (build when merchants land)

- `ItemDef` subtype or flag: `teaches_spell: WeaponDef` (a tome).
- Using the book from the inventory (Journal → Inventory) consumes it and adds
  the tome to Kai's spell list permanently — model as appending to his
  `extra_weapons`-equivalent in `Campaign.unit_states["kai"]` (persisted).
- Only Kai can use them (royal blood gate; heirs politely decline).
- Spell list UI: the battle Magic menu already lists every carried tome (AW-26),
  so learned spells appear there with zero new UI.
- Book pool: start with the element tomes (fire/gale/tide already exist as
  weapons) + rarities like the reason-school tomes. Named/unique spellbooks can
  carry their own FX styles (the CombatRig style system keys off school/id).

## Tuning guardrails

- Kai's MAG is modest (base 4, growth 20 — raised in AW-51 for the awakening):
  he'll never out-nuke Liora; spells are his *reach and flexibility*, not raw power.
- Crownspark: might 7, hit 95, range 1–2 — chip/finisher at range, neutral in
  the triangle (royal magic predates the house elements).
