#!/usr/bin/env python3
"""GH-75 real X11 input driver; requires explicit desktop ownership.
Usage: drive.py OUTPUT_DIR RUN normal|hold|release map|illustrated|popup
State comes from the read-only reporter. No game handler is called.
DISPLAY/XAUTHORITY are inherited from the operator environment.
"""
import json, os, subprocess, sys, time
G, RUN, MODE = sys.argv[1:4]
J = f"{G}/{RUN}.jsonl"
ENV = dict(os.environ)
ORIGIN = tuple(map(int, ENV.get("QA_CAPTURE_ORIGIN", "0,0").split(",")))
def x(*a):
    if a[0] == "mousemove":
        a = (a[0], str(int(a[1]) + ORIGIN[0]), str(int(a[2]) + ORIGIN[1]))
    subprocess.run(["xdotool", *a], env=ENV, check=True)
def key(k, hold=0.08, gap=0.2):
    x("keydown", k); time.sleep(hold); x("keyup", k); time.sleep(gap)
def shot(name):
    subprocess.run(["ffmpeg","-loglevel","error","-y","-f","x11grab","-video_size",ENV.get("QA_CAPTURE_SIZE", "1280x720"),"-i",ENV["DISPLAY"] + "+" + str(ORIGIN[0]) + "," + str(ORIGIN[1]),"-frames:v","1",f"{G}/{RUN}-{name}.png"], env=ENV, check=True)
def records():
    try: return [json.loads(l) for l in open(J)]
    except FileNotFoundError: return []
def state():
    st = [r for r in records() if r["kind"] == "state"]
    return st[-1]["data"] if st else None
def wait(pred, timeout=30, step=0.03):
    end = time.time() + timeout
    while time.time() < end:
        s = state()
        if s is not None and pred(s): return s
        time.sleep(step)
    raise SystemExit(f"timeout waiting; last={state()}")
def unit(s, uid): return next((u for u in s["units"] if u[0] == uid), None)
def cursor_to(cell):
    s = state(); cx, cy = s["cursor"]
    for _ in range(abs(cell[0]-cx)): key("Right" if cell[0] > cx else "Left")
    for _ in range(abs(cell[1]-cy)): key("Down" if cell[1] > cy else "Up")
    wait(lambda s: s["cursor"] == list(cell), 5)
def choose(action):
    s = wait(lambda s: s["menu"] and action in s["menu_actions"], 10)
    for _ in range(s["menu_actions"].index(action)): key("Down")
    key("Return")
def click_unit(uid):
    # A compact window can pan the camera after pointer hover. Follow the live
    # screen position until it settles before the native click, as a player can.
    for _ in range(30):
        before = unit(state(), uid)[9]
        x("mousemove", str(before[0]), str(before[1])); time.sleep(0.1)
        after = unit(state(), uid)[9]
        if max(abs(after[i] - before[i]) for i in (0, 1)) <= 2:
            x("click", "1")
            return
    raise SystemExit("camera did not settle for pointer continuation")

def playback(label):
    wait(lambda s: s["armed"], 15)
    if MODE != "normal":
        x("keydown", "space")
        wait(lambda s: s["speed"] == 2.0, 3)
    time.sleep(0.15)
    shot(label + "-hint")
    if MODE == "release":
        x("keyup", "space")
        wait(lambda s: s["speed"] == 1.0, 3)
        shot(label + "-released")
    wait(lambda s: not s["busy"] and not s["armed"] and not s["level_up"], 40)
    x("keyup", "space")
    time.sleep(1.0)
    shot(label + "-after")

def exchange(label):
    key("Return", hold=0.04, gap=0.01)
    playback(label)

ROUTE = sys.argv[4]
if ROUTE == 'map':
    wait(lambda s: True, 30) if False else None
    time.sleep(6)
    key("Down"); key("Return"); time.sleep(0.8); key("Return")            # Title → Load Game → Slot 0
    wait(lambda s: s["round"] == 3 and not s["busy"], 30); time.sleep(1.5); shot("00-loaded")
    # 1) Kael attacks Marlow (map strikes; illustrated pair unavailable — Serra yielded natively)
    cursor_to((3, 12)); key("Return"); wait(lambda s: s["selected"] == "kael", 5)
    cursor_to((8, 12)); key("Return")
    choose("attack"); time.sleep(0.4)
    s = state()
    if s["menu"] and s["menu_context"] == "attack_weapon": key("Return")
    wait(lambda s: s["phase"] == 3 and s["cursor"] == [9, 12], 5); shot("01-forecast")
    exchange("02-attack")
    # 2) Next ordinary command: Wren heals Perrin (real map heal)
    cursor_to((3, 13)); key("Return"); wait(lambda s: s["selected"] == "wren", 5)
    cursor_to((3, 11)); key("Return")
    choose("heal"); wait(lambda s: s["phase"] == 3, 5); time.sleep(0.3)
    wait(lambda s: s["cursor"] == [3, 10], 5); shot("03-heal-target")
    exchange("04-heal")
    # 3) Pointer then keyboard continuation: click Liora (selects + range), Esc cancels
    click_unit("liora")
    wait(lambda s: s["selected"] == "liora" and s["phase"] == 1, 5); time.sleep(0.4); shot("05-pointer-select")
    key("Escape"); wait(lambda s: s["phase"] == 0 and s["selected"] == "", 5)
    key("Next"); time.sleep(0.6); shot("06-keyboard-continue")
    print("done", RUN)
elif ROUTE == 'illustrated':
    time.sleep(6)
    s = wait(lambda s: s["round"] == 1 and not s["busy"], 30); time.sleep(1.0); shot("00-fixture")
    cursor_to((8, 12)); key("Return"); wait(lambda s: s["selected"] == "kai", 5)
    key("Return")                                            # stay in place
    choose("attack"); time.sleep(0.4)
    s = state()
    if s["menu"] and s["menu_context"] in ("attack_weapon", "magic_spell"): key("Return")
    wait(lambda s: s["phase"] == 3 and s["cursor"] == [9, 12], 5); shot("01-forecast")
    key("Return")                                            # commit -> boss quote first
    end = time.time() + 60
    while time.time() < end and not state()["armed"]:
        if state()["dialogue"]:
            key("Return", gap=0.5)
        else:
            time.sleep(0.05)
    playback("02-stage")
    # next ordinary command: Kael moves one cell and Waits (keyboard), then pointer select/cancel
    cursor_to((3, 12)); key("Return"); wait(lambda s: s["selected"] == "kael", 5)
    cursor_to((4, 12)); key("Return"); choose("wait")
    wait(lambda s: s["phase"] == 0 and not s["busy"], 10); time.sleep(0.6); shot("04-next-command")
    click_unit("liora")
    wait(lambda s: s["selected"] == "liora", 5); time.sleep(0.4); shot("05-pointer-select")
    key("Escape"); wait(lambda s: s["phase"] == 0, 5)
    print("done", RUN)
elif ROUTE == 'popup':
    time.sleep(6)
    wait(lambda s: s["round"] == 1 and not s["busy"], 30); time.sleep(1.0)
    cursor_to((8, 10)); key("Return"); wait(lambda s: s["selected"] == "kael", 5)
    key("Return"); choose("attack"); time.sleep(0.4)
    s = state()
    if s["menu"] and s["menu_context"] in ("attack_weapon", "magic_spell"): key("Return")
    wait(lambda s: s["phase"] == 3 and s["cursor"] == [9, 10], 5); shot("01-forecast")
    key("Return")
    playback("02-popup")
    cursor_to((2, 12)); key("Return"); wait(lambda s: s["selected"] == "kai", 5)
    key("Return"); choose("wait"); wait(lambda s: s["phase"] == 0 and not s["busy"], 10); time.sleep(0.5); shot("04-next-command")
    click_unit("liora")
    wait(lambda s: s["selected"] == "liora", 5); shot("05-pointer-select")
    key("Escape"); wait(lambda s: s["phase"] == 0, 5)
    print("done", RUN)
