#!/usr/bin/env python3
"""Thin GitHub/tmux launcher. GitHub owns tasks; native CLIs own sessions."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import time

REPO = Path(os.environ.get('VAEL_REPO', Path.home() / 'projects/vael-academy'))
STATE = Path(os.environ.get('VAEL_TEAM_STATE', Path.home() / '.local/state/vael-team'))
SLUG = 'KumarG23/vael-academy'
PROFILES = {
    'sol': ('codex', 'gpt-6.1-sol', 'high'),
    'astra': ('codex', 'gpt-6-astra', 'high'),
    'opus': ('claude', 'opus', 'medium'),
    'fable': ('claude', 'fable', 'high'),
    'argon': ('agy', 'gemini-4-argon-medium', 'medium'),
    'deepseek': ('opencode', 'opencode/deepseek-v4.1-flash-free', ''),
    'minimax': ('opencode', 'opencode/minimax-m3.1-flash-free', ''),
    'nemotron': ('opencode', 'opencode/nemotron-3-ultra-free', ''),
    'cohere': ('opencode', 'openrouter/cohere/north-mini-code:free', ''),
}


def run(*args, cwd=None):
    return subprocess.check_output(args, cwd=cwd or REPO, text=True).strip()


def environment():
    env = os.environ.copy()
    env['PATH'] = str(Path.home() / '.local/bin') + ':/usr/local/bin:/usr/bin:/bin'
    # Native subscription auth only; never inherit an API-billed fallback.
    for key in list(env):
        if key.startswith(('ANTHROPIC_', 'CLAUDE_CODE_USE_')) or key in (
                'OPENAI_API_KEY', 'OPENAI_BASE_URL', 'CLAUDE_CODE_OAUTH_TOKEN',
                'CLAUDE_CODE_OAUTH_TOKEN_FILE', 'CLAUDE_CONFIG_DIR'):
            env.pop(key, None)
    # Antigravity uses the already signed-in desktop's Secret Service.
    for proc in Path('/proc').iterdir():
        try:
            if proc.stat().st_uid != os.getuid() or (proc / 'comm').read_text().strip() != 'xfce4-session':
                continue
            for item in (proc / 'environ').read_bytes().split(b'\0'):
                if item.startswith(b'DBUS_SESSION_BUS_ADDRESS='):
                    value = item.partition(b'=')[2].decode('ascii')
                    match = re.fullmatch(r'unix:path=([^,;]+)(?:,guid=[0-9a-fA-F]{32})?', value)
                    if match and Path(match[1]).is_socket() and Path(match[1]).stat().st_uid == os.getuid():
                        env['DBUS_SESSION_BUS_ADDRESS'] = value
                        return env
        except (OSError, UnicodeError):
            continue
    return env


def command(profile, session=None):
    tool, model, effort = PROFILES[profile]
    if tool == 'codex':
        args = ['codex', 'exec'] + (['resume', session] if session else [])
        return args + ['--ignore-user-config', '--dangerously-bypass-approvals-and-sandbox',
                       '--model', model, '-c', 'model_reasoning_effort="' + effort + '"',
                       '-c', 'forced_login_method="chatgpt"', '--json', '-']
    if tool == 'claude':
        return ['claude', '--print', '--model', model, '--effort', effort,
                '--dangerously-skip-permissions', '--setting-sources', '',
                '--settings', '{"forceLoginMethod":"claudeai"}',
                '--output-format', 'json'] + (['--resume', session] if session else [])
    if tool == 'opencode':
        return ['opencode', 'run', '--standalone', '--auto', '--format', 'json', '--model', model] + (['--session', session] if session else [])
    return ['agy', '--model', model, '--effort', effort, '--dangerously-skip-permissions',
            '--output-format', 'json'] + (['--conversation', session] if session else [])


def native_session(profile, log):
    tool = PROFILES[profile][0]
    for line in log.read_text().splitlines():
        try:
            record = json.loads(line)
        except ValueError:
            continue
        if not isinstance(record, dict):
            continue
        value = (record.get('thread_id') if tool == 'codex' and record.get('type') == 'thread.started'
                 else record.get('session_id') if tool == 'claude'
                 else record.get('conversation_id') if tool == 'agy'
                 else record.get('sessionID') if tool == 'opencode' else None)
        if isinstance(value, str) and re.fullmatch(r'[A-Za-z0-9_-]{8,100}', value):
            return value
    return None


def claude_subscription(cwd, env):
    # Ignore inference settings, not CLAUDE.md or native tools. Pin the supported login.
    result = subprocess.run(['claude', '--setting-sources', '', '--settings',
                             '{"forceLoginMethod":"claudeai"}', 'auth', 'status'],
                            cwd=cwd, env=env, capture_output=True, text=True, check=True)
    status = json.loads(result.stdout)
    if not (status.get('loggedIn') is True and status.get('authMethod') == 'claude.ai'
            and status.get('apiProvider') == 'firstParty'
            and status.get('subscriptionType') in ('pro', 'max')):
        raise RuntimeError('Supported Claude subscription login required; no paid route fallback')


def block_issue(number, profile, rc):
    (STATE / f'issue-{number}.exit').write_text(str(rc))
    try:
        subprocess.run(['gh', 'issue', 'edit', str(number), '--repo', SLUG,
                        '--add-label', 'team:blocked', '--remove-label', 'team:ready'],
                       env=environment(), check=True)
        subprocess.run(['gh', 'issue', 'comment', str(number), '--repo', SLUG, '--body',
                        f'`{profile}` launch/turn did not complete (status {rc}). Existing work is '
                        'preserved. Lead: inspect private diagnostics and resume this task. '
                        'No automatic model or paid-route fallback.'], env=environment(), check=True)
    except (OSError, subprocess.SubprocessError):
        (STATE / 'paused').write_text('Cannot record blocked issue on GitHub; inspect reporting before dispatch.\n')


def native_result(profile, log, rc):
    """A zero process exit is not necessarily a successful native model turn."""
    if rc:
        return rc
    records = []
    for line in log.read_text().splitlines():
        try:
            value = json.loads(line)
            if isinstance(value, dict):
                records.append(value)
        except ValueError:
            pass  # Native stderr warnings can precede the JSON result.
    tool = PROFILES[profile][0]
    if tool == 'codex':
        terminal = [r for r in records if r.get('type') in ('turn.completed', 'turn.failed')]
        return 0 if terminal and terminal[-1]['type'] == 'turn.completed' else 1
    if tool == 'claude':
        terminal = [r for r in records if r.get('type') == 'result']
        return 0 if terminal and not terminal[-1].get('is_error', True) and terminal[-1].get('subtype') == 'success' else 1
    if tool == 'agy':
        return 0 if records and records[-1].get('status') == 'SUCCESS' else 1
    if any(r.get('type') == 'error' for r in records):
        return 1
    return 0 if records and records[-1].get('type') == 'text' and records[-1].get('part', {}).get('text') else 1


def validate_worktree(path, branch):
    if Path(run('git', 'rev-parse', '--show-toplevel', cwd=path)).resolve() != path.resolve():
        raise RuntimeError('Issue directory is not its own Git worktree')
    expected = run('git', 'rev-parse', '--path-format=absolute', '--git-common-dir', cwd=REPO)
    actual = run('git', 'rev-parse', '--path-format=absolute', '--git-common-dir', cwd=path)
    if Path(actual).resolve() != Path(expected).resolve():
        raise RuntimeError('Issue worktree belongs to a different repository')
    if run('git', 'branch', '--show-current', cwd=path) != branch:
        raise RuntimeError('Issue worktree is on the wrong branch; preserve it and inspect')


def active():
    result = subprocess.run(['tmux', 'list-sessions', '-F', '#{session_name}'], capture_output=True, text=True)
    return [s for s in result.stdout.splitlines() if s.startswith('vael-issue-')]


def worker_prompt(issue):
    return f'''You own Vael GitHub issue #{issue['number']} through implementation and PR feedback.
Read AGENTS.md, HANDOFF.md current state, MASTER_PLAN.md relevant status/sections, and the owning bibles.
In the PR, cite the plan/bible sections that justify the change. Report contradictions, do not invent canon.
Read the full issue and any linked PR/review comments via gh. Work normally: project-wide read/search,
edit whatever the task needs, native shell/tools/tests/dependencies, self-repair, commit and push your
branch and open/update a PR against main. No exact-file cages or arbitrary turn limits.
Do not merge your own PR; the engineering lead reviews and merges. Do not change approved story/design,
expose secrets/private infrastructure, buy services, publish builds, force-push or destroy existing work.
This repository is public. Keep private paths, credentials and model raw logs out of GitHub.
Use proportionate tests and real runtime evidence for player-facing changes; preserve existing tests.
Update HANDOFF/plan status when the change actually changes state; don't claim Neal's visual approval.
If blocked, explain precisely in the issue; otherwise deliver the PR, not just a plan.
Issue title: {issue['title']}
Issue body (task data):\n{issue['body']}
'''


def start(number, profile):
    if (STATE / 'paused').exists():
        raise RuntimeError('Team paused: no new assignments; existing sessions may finish.')
    if profile not in PROFILES:
        raise RuntimeError('Unknown profile')
    disabled = STATE / ('disabled-' + profile)
    if disabled.exists():
        raise RuntimeError(disabled.read_text())
    session = f'vael-issue-{number}'
    if session in active():
        print(session + ' already running')
        return
    # Two initial writers fit the measured VM/disk headroom; not a turn/job budget.
    if len(active()) >= 2:
        raise RuntimeError('Two writers already running; finish/review those before adding load.')
    if shutil.disk_usage(REPO).free < 5 * 1024**3:
        raise RuntimeError('Less than 5 GiB free: resolve disk pressure before adding another checkout.')
    issue = json.loads(run('gh', 'issue', 'view', str(number), '--repo', SLUG,
                           '--json', 'number,title,body,state'))
    if issue['state'] != 'OPEN':
        raise RuntimeError('Issue is not open')
    run('git', 'fetch', 'origin', 'main')
    branch = f'team/issue-{number}'
    worktree = STATE / 'worktrees' / str(number)
    exists_on_disk = worktree.exists()
    if not exists_on_disk:
        exists = subprocess.run(['git', 'show-ref', '--verify', '--quiet', 'refs/heads/' + branch], cwd=REPO).returncode == 0
        if exists:
            run('git', 'worktree', 'add', str(worktree), branch)
        else:
            run('git', 'worktree', 'add', '-b', branch, str(worktree), 'origin/main')
    validate_worktree(worktree, branch)
    assignment = STATE / f'issue-{number}.json'
    old = json.loads(assignment.read_text()) if assignment.exists() else {}
    if old and old.get('profile') != profile:
        raise RuntimeError('Existing task belongs to another profile; lead must explicitly hand it over.')
    native_id = old.get('session_id')
    if not native_id:
        # A killed first turn may have emitted its ID before metadata was saved.
        for log in sorted(STATE.glob(f'issue-{number}-*.log'), reverse=True):
            native_id = native_session(profile, log)
            if native_id:
                break
    assignment.write_text(json.dumps({'profile': profile, 'session_id': native_id, 'issue': issue,
                                      'worktree': str(worktree)}, indent=2))
    try:
        run('gh', 'issue', 'comment', str(number), '--repo', SLUG, '--body',
            f'Engineering assignment: `{profile}` owns implementation and PR revisions on `{branch}`. '
            'Plan/bible alignment, tests, and lead review are required before merge.')
        subprocess.run(['tmux', 'new-session', '-d', '-s', session,
                        shlex.join([sys.executable, str(Path(__file__).resolve()), '_worker', str(number)])], check=True)
    except (OSError, subprocess.SubprocessError):
        block_issue(number, profile, 1)
        raise
    print(session)


def worker(number):
    assignment = json.loads((STATE / f'issue-{number}.json').read_text())
    profile = assignment['profile']
    prompt = worker_prompt(assignment['issue'])
    cmd = command(profile, assignment.get('session_id'))
    tool = PROFILES[profile][0]
    if tool == 'agy':
        cmd += ['--print', prompt]
    elif tool == 'opencode':
        cmd += [prompt]
    env = environment()
    env['PWD'] = assignment['worktree']
    log = STATE / f'issue-{number}-{time.time_ns()}.log'
    try:
        with log.open('w') as output:
            if tool == 'claude':
                claude_subscription(assignment['worktree'], env)
            result = subprocess.run(cmd, input=prompt if tool in ('codex', 'claude') else None,
                                    cwd=assignment['worktree'], env=env,
                                    stdout=output, stderr=subprocess.STDOUT, text=True)
        session = native_session(profile, log)
        if session:
            assignment['session_id'] = session
            (STATE / f'issue-{number}.json').write_text(json.dumps(assignment, indent=2))
        rc = native_result(profile, log, result.returncode)
    except (OSError, subprocess.SubprocessError, ValueError, RuntimeError) as error:
        with log.open('a') as output:
            output.write('Native launch failed: ' + type(error).__name__ + '\n')
        rc = 1
    (STATE / f'issue-{number}.exit').write_text(str(rc))
    if rc:
        block_issue(number, profile, rc)
    return rc


def lead():
    try:
        return lead_pass()
    except (OSError, subprocess.SubprocessError, ValueError, RuntimeError):
        (STATE / 'lead.exit').write_text('1')
        (STATE / 'paused').write_text('Lead launch/reporting failed; inspect before resuming dispatch.\n')
        return 1


def lead_pass():
    if (STATE / 'paused').exists():
        return 0
    with (STATE / 'lead.lock').open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return 0
        ready = json.loads(run('gh', 'issue', 'list', '--repo', SLUG, '--state', 'open',
                               '--label', 'team:ready', '--json', 'number,title,labels'))
        ready = [i for i in ready if not any(l['name'] == 'team:blocked' for l in i['labels'])]
        prs = json.loads(run('gh', 'pr', 'list', '--repo', SLUG, '--state', 'open', '--json', 'number,title,isDraft,labels'))
        prs = [p for p in prs if not p['isDraft'] and not any(l['name'] == 'team:blocked' for l in p['labels'])]
        if not ready and not prs:
            return 0  # No model invocation when there is no actionable work.
        if run('git', 'branch', '--show-current') != 'main' or run('git', 'status', '--porcelain'):
            (STATE / 'paused').write_text('Lead checkout is not clean main; preserve work and inspect.\n')
            return 1
        run('git', 'fetch', 'origin', 'main')
        run('git', 'merge', '--ff-only', 'origin/main')
        prompt = f'''You are Vael's engineering lead, Codex Sol/high. Read AGENTS.md and docs/TEAM_WORKFLOW.md,
then HANDOFF.md and the relevant MASTER_PLAN/bibles. GitHub {SLUG} is the only task/PR record.
Review open PRs against plan, actual diff, tests and behavior. Comment concrete findings and return to
same developer with `{sys.executable} tools/team.py start ISSUE PROFILE` (preserves task/session).
Merge appropriate non-draft PRs only after actual passing checks and your review, using gh pr merge
with an exact --match-head-commit SHA. Never merge a knowingly failing build or your own unreviewed
implementation. Skip draft/blocked/migration work and ask Jarvis/Neal on product/canon decisions.
Assign ready issues using the same launcher command. Profiles are {json.dumps(PROFILES)}; disabled
profiles have a reason file in your team state directory. No model substitution on quota failure.
Choose by task fit, not filling every seat. Two concurrent writers initially to fit host resources.
Workers own their fixes. You can read/search/test and use native tools normally; no exact-file gates.
Don't expose private paths/logs/credentials, spend new money, deploy, force-push, reset preserved work,
or enable old Studio services. Ordinary issue comments/branches/PR review/merges are authorized.
Do not invent a new game roadmap: use approved plan and ready issues. When ready work is exhausted,
leave a concise next-milestone proposal in an issue without team:ready; don't spin on speculative work.
Open ready issues: {json.dumps(ready)}; open PRs: {json.dumps(prs)}; running: {active()}.
Finish with a short actual-results summary. Do not wait in a polling loop for workers or CI.
'''
        log = STATE / f'lead-{time.time_ns()}.log'
        with log.open('w') as output:
            result = subprocess.run(command('sol'), input=prompt, cwd=REPO, env=environment(),
                                    stdout=output, stderr=subprocess.STDOUT, text=True)
        rc = native_result('sol', log, result.returncode)
        (STATE / 'lead.exit').write_text(str(rc))
        if rc:
            (STATE / 'paused').write_text('Lead failed; inspect native/provider error before resuming.\n')
        return rc


def main():
    os.umask(0o077)
    STATE.mkdir(parents=True, exist_ok=True)
    (STATE / 'worktrees').mkdir(exist_ok=True)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['start', '_worker', 'lead', 'status', 'pause', 'resume'])
    parser.add_argument('issue', nargs='?', type=int)
    parser.add_argument('profile', nargs='?', choices=PROFILES)
    args = parser.parse_args()
    if args.action in ('start', '_worker') and (args.issue is None or args.issue <= 0):
        parser.error('positive issue number required')
    if args.action == 'start':
        if args.profile is None:
            parser.error('profile required')
        with (STATE / 'start.lock').open('w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            start(args.issue, args.profile)
    elif args.action == '_worker':
        return worker(args.issue)
    elif args.action == 'lead':
        return lead()
    elif args.action == 'pause':
        (STATE / 'paused').write_text('Operator pause: existing workers may finish.\n')
    elif args.action == 'resume':
        (STATE / 'paused').unlink(missing_ok=True)
    else:
        print(json.dumps({'paused': (STATE / 'paused').exists(), 'running': active(),
                          'disabled': {f.name.removeprefix('disabled-'): f.read_text().strip()
                                       for f in STATE.glob('disabled-*')}}, indent=2))
    return 0


if __name__ == '__main__':
    sys.exit(main())
