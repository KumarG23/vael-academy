# CP-5 rejected model sources — not used in runtime

Neal rejected the generic clothed model because it did not look like Kai and
redirected work to the existing illustrations. These original licensed source
subsets preserve provenance for `assets/art_review/cp5_model_rejected/` only.

- **Quaternius Universal Base Characters Standard**:
  https://quaternius.com/packs/universalbasecharacters.html
  / https://quaternius.itch.io/universal-base-characters . Original archive SHA256
  `fdbf1804c90dfc1ea03e992bff7da2dfd1a79318e13270a660180f9308455f40`.
  Retained male Superhero geometry, SimpleParted hair geometry, eye texture and
  `License_Standard.txt` (CC0). The free tier does not include the Teen model.
- **Quaternius Modular Character Outfits — Fantasy Standard**:
  https://quaternius.com/packs/modularcharacteroutfitsfantasy.html
  / https://quaternius.itch.io/modular-character-outfits-fantasy . Downloaded
  October 15, archive SHA256
  `c3468b18871cc8c8f05ab14df7712baf22cb9f389cbd870babf130e595187f70`.
  Retained Male_Peasant and Male_Ranger geometry, original license/readme (CC0).
  The free tier contains Peasant/Ranger; the Noble outfit is not included.

GLTF originals have `.gltf.txt` suffixes to prevent import of unused references;
they retain the creator's JSON unchanged. Only the geometry BIN files and eye
texture needed by the experiment are retained. Other original texture references
are intentionally not installed. The disabled builder in the rejection archive
used solid custom materials plus the creator's eye texture and ignored other
texture references. Original animation rig/CC0 license remains separately in
`assets/source/authored_motion/`.

The disabled builder maps each source mesh into the accepted target bind pose
using weighted target-rest × source-inverse-bind transforms, remapping joints
by name and leaving target bones/animations unchanged. This technical fit did
not make the adult/angular source head resemble Kai's approved illustration.
No generic model is loaded by the current art-motion proof. No purchase or new
account was created.
