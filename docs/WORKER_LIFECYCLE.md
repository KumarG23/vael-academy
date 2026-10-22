# Worker ownership regression (#13)

The lead must return while native developers continue: `TEAM_WORKFLOW.md` “Roles and delivery” / “Minimal runtime”, AGENTS.md's separate-worktree/native-session rules, and HANDOFF.md's active GitHub workflow own this change. MASTER_PLAN.md §2 rules 5/8/9 and §10 govern scope, verification and state reporting. No game source, story, visuals or bible content changes; the parent school-slice goal does not authorize new canon.

## Reproduction and evidence

Run from a checkout with Python 3, git, tmux and a reachable Linux user systemd manager:

```sh
VAEL_TEAM_LIFECYCLE=1 python3 -m unittest discover -s tools/team_tests -v
```

The two opt-in lifecycle cases create disposable local Git repositories/remotes, issue worktrees, unique transient oneshot services, tmux sockets and harmless waiting Python workers. They run the real `team.py` CLI, lead, start, session persistence, native-result handling and status code. GitHub and native provider commands are fixture substitutes; no inference or network service is used. The legacy case substitutes the prior direct-tmux launch on an isolated socket. Cleanup only targets these test units/sockets. Without the opt-in flag these two cases skip; without a user manager they explicitly skip even when requested. Ordinary helper regressions still run in CI.

Verified on 2026-10-22 with systemd 255 and tmux 3.4:

| Arrangement | Lead result | Server ownership after dispatch | Workers after lead exit |
|---|---|---|---|
| Prior direct tmux launch | Successful, returns promptly | Short-lived lead service | Server and both workers die; no worker exit receipts |
| Scoped private tmux server | Successful, returns promptly | Separate `vael-team-dispatch-*.scope` | Both workers survive and remain visible in `status` |

The survival regression also fails against the actual pre-fix launcher source, at the assertion that the server must be outside the lead cgroup. The repaired run additionally proves that duplicate dispatch preserves an uncommitted file; one successful worker persists its confirmed native session ID and exit 0; the second remains alive, then reports a terminal provider failure as exit 1 and a blocked fixture issue. After the final session finishes, the server exits and the owning scope becomes inactive. No scope status is mistaken for native success. All 37 helper/lifecycle tests pass with the opt-in flag (35 ordinary checks plus two real lifecycle cases).

Ubuntu's tmux may move pane processes into separate `tmux-spawn-*.scope` units. The probe records the **server** PID/cgroup before the parent exits, as well as checking actual worker liveness afterward. A pane being outside the lead's cgroup alone does not establish survival: killing its tmux server can still terminate it through the terminal. These isolated results reproduce the reported mechanism; they do not prove the cause of every historical interrupted worker log.

## Operator rollout and verification (Jarvis, after review/merge)

No installed unit change, daemon reload, enablement or service restart is required. The checked-in and installed lead keep `Type=oneshot` and `KillMode=control-group`. The developer has not deployed this code or activated production services. Let the ordinary clean-main update deliver the reviewed commit; preserve any existing work rather than resetting a checkout. Existing running sessions remain on their original socket/cgroup and are counted until they finish naturally. This code does not relocate them or remove the temporary workaround.

1. Verify the approved commit is present in the clean lead checkout and run the provider-free command above. Expect 37 passing tests with no lifecycle skips on the supported host. Review failures locally; do not upload raw logs, environment data or private paths.
2. Let the next normal lead pass dispatch authorized work using `/usr/bin/python3 tools/team.py start ISSUE PROFILE`. Do not start extra production workers merely to test, or stop the active lead/workers. Confirm `/usr/bin/python3 tools/team.py status` includes the running issue and preserves the three-worker limit.
3. Inspect locally while that new worker is alive:

   ```sh
   team_state=${VAEL_TEAM_STATE:-$HOME/.local/state/vael-team}
   server_pid=$(tmux -S "$team_state/tmux.sock" display-message -p '#{pid}')
   cat "/proc/$server_pid/cgroup"
   systemctl --user show vael-team-lead.service -p KillMode -p ActiveState -p Result
   ```

   The server's cgroup should end in `vael-team-dispatch-*.scope`, outside `vael-team-lead.service`. After the successful lead pass finishes naturally, expect `Result=success`, the default control-group cleanup, and the worker still visible/alive. Wait for normal native completion and inspect its private exit receipt/session metadata. Report only sanitized results and reviewed commit identity publicly.
4. After all sessions on the new socket complete, its server/scope should disappear naturally. Later work creates another owned server. Do not stop an owning scope to test cleanup against real workers: stopping it terminates all sessions sharing that server.

## Limits

This fixes lead-pass lifetime, not reboot, logout/user-manager shutdown, OOM, operator termination or provider failure. Existing branches/session recovery and block/pause paths handle their existing cases. Missing user systemd support fails dispatch explicitly. Legacy default-socket sessions retain their prior ownership; the fix protects newly launched workers on the private socket. Manual servers on arbitrary other sockets are outside launcher accounting, as before. No game import/GUT, graphical QA, production provider run or Neal visual/story approval is claimed for this tooling-only change. Exact-head lead review and passing PR CI are still required before merge.
