"""CP-9 original synthesized cues; reuses the project's deterministic writer."""
from pathlib import Path
import importlib.util
import math

source = Path(__file__).resolve().parents[1] / "combat_audio" / "generate.py"
spec = importlib.util.spec_from_file_location("combat_audio", source)
audio = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audio)

audio.render("defense_cue", 0.10, 91, lambda t, u, n, low:
             (audio.sine(880, t) + 0.3 * audio.sine(1320, t))
             * min(1, t / 0.003) * (1 - u) ** 3)
audio.render("defense_block", 0.26, 92, lambda t, u, n, low:
             (0.3 * n * math.exp(-t * 40) + audio.sine(733, t) * math.exp(-t * 20)
              + 0.3 * audio.sine(1723, t) * math.exp(-t * 24))
             * min(1, t / 0.002) * (1 - u))
audio.render("defense_dodge", 0.18, 93, lambda t, u, n, low:
             (low + 0.1 * n) * math.sin(math.pi * u) ** 1.5)
