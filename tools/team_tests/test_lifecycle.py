"""Opt-in, provider-free user-systemd regression; only disposable units/sockets/repos.

Run: VAEL_TEAM_LIFECYCLE=1 python3 -m unittest discover -s tools/team_tests -v
No production services, native providers, GUI, worktrees or GitHub are used.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest
import uuid

SOURCE = Path(__file__).resolve().parents[1] / 'team.py'


@unittest.skipUnless(os.environ.get('VAEL_TEAM_LIFECYCLE') == '1',
                     'set VAEL_TEAM_LIFECYCLE=1 for isolated user-systemd probes')
class LifecycleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        for binary in ('systemd-run', 'systemctl', 'tmux', 'git'):
            if not shutil.which(binary):
                raise unittest.SkipTest(binary + ' unavailable')
        result = subprocess.run(['systemctl', '--user', 'show', 'default.target', '-p', 'LoadState'],
                                capture_output=True)
        if result.returncode:
            raise unittest.SkipTest('user systemd manager unavailable')

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='vael-lifecycle-')
        self.root = Path(self.tmp.name)
        self.repo = self.root / 'repo'
        self.state = self.root / 'state'
        self.bin = self.root / 'bin'
        for directory in (self.repo, self.state, self.bin):
            directory.mkdir()
        self.unit = 'vael-lifecycle-test-' + uuid.uuid4().hex + '.service'
        self.env = dict(os.environ, VAEL_REPO=str(self.repo), VAEL_TEAM_STATE=str(self.state),
                        PATH=str(self.bin) + ':' + os.environ['PATH'])
        # Register before any launch; never touch the real default tmux socket.
        self.addCleanup(self.cleanup)
        self.fixture()

    def call(self, *args, **kwargs):
        return subprocess.run(args, cwd=self.repo, env=self.env, check=True,
                              capture_output=True, text=True, timeout=20, **kwargs)

    def cleanup(self):
        subprocess.run(['systemctl', '--user', 'stop', self.unit], capture_output=True, timeout=10)
        # Only discover/stop the scope that owns this fixture's unique socket.
        receipt = self.state / 'server.json'
        if receipt.exists():
            scope = json.loads(receipt.read_text())['cgroup'].strip().split('/')[-1]
            if scope.startswith('vael-team-dispatch-') and scope.endswith('.scope'):
                subprocess.run(['systemctl', '--user', 'stop', scope], capture_output=True, timeout=10)
        for socket in (self.state / 'tmux.sock', self.state / 'legacy.sock'):
            subprocess.run(['/usr/bin/tmux', '-S', str(socket), 'kill-server'],
                           capture_output=True, timeout=5)
        self.tmp.cleanup()

    def fixture(self):
        self.call('git', 'init', '-q', '-b', 'main')
        self.call('git', '-c', 'user.name=Lifecycle Test', '-c', 'user.email=test@example.invalid',
                  'commit', '-q', '--allow-empty', '-m', 'seed')
        self.call('git', 'init', '-q', '--bare', str(self.root / 'remote.git'))
        self.call('git', 'remote', 'add', 'origin', str(self.root / 'remote.git'))
        self.call('git', 'push', '-q', 'origin', 'main')
        # The CLI/lead/start/worker implementations are real. Only external
        # GitHub/provider calls and the old default socket are fixture substitutes.
        (self.repo / 'tools').mkdir()
        (self.repo / 'tools/team.py').write_text(f'''import importlib.util, os, pathlib, shlex, subprocess, sys
spec=importlib.util.spec_from_file_location('tested_team', {str(SOURCE)!r})
team=importlib.util.module_from_spec(spec); spec.loader.exec_module(team)
team.__file__=__file__
team.environment=lambda: os.environ.copy()
team.command=lambda profile, session=None: ['/usr/bin/python3', {str(self.root / 'provider.py')!r}, session or 'fresh']
if os.environ.get('LEGACY_LAUNCH') == '1':
    def legacy(number, worktree):
        subprocess.run(['tmux','-S',str(team.STATE/'legacy.sock'),'-f','/dev/null','new-session','-d','-s',f'vael-issue-{{number}}',shlex.join([sys.executable,__file__,'_worker',str(number)])],check=True)
    team.launch_worker=legacy
sys.exit(team.main())
''')
        # Ignore fixture tools in the lead's clean-main check.
        (self.repo / '.git/info/exclude').write_text('tools/\n')
        self.executable('tmux', '''#!/usr/bin/python3
import os,sys
args=sys.argv[1:]
if args[:2]==['-L','default']:
    args=['-S',os.environ['VAEL_TEAM_STATE']+'/legacy.sock',*args[2:]]
elif '-S' not in args and '-L' not in args:
    args=['-S',os.environ['VAEL_TEAM_STATE']+'/legacy.sock',*args]
os.execv('/usr/bin/tmux',['tmux',*args])
''')
        self.executable('gh', '''#!/usr/bin/python3
import json,os,pathlib,sys
args=sys.argv[1:]; state=pathlib.Path(os.environ['VAEL_TEAM_STATE'])
if args[:2]==['issue','list']: print(json.dumps([{'number':7,'title':'Fixture','labels':[]}]))
elif args[:2]==['pr','list']: print('[]')
elif args[:2]==['issue','view']: print(json.dumps({'number':int(args[2]),'title':'Fixture','body':'Harmless lifecycle test','state':'OPEN'}))
elif args[:2] in (['issue','edit'],['issue','comment']):
    with (state/'github.jsonl').open('a') as f: f.write(json.dumps(args)+'\\n')
else: sys.exit(99)
''')
        # The lead's real subscription preflight runs against this stub, never real auth.
        self.executable('claude', '''#!/usr/bin/python3
import json,sys
if sys.argv[-2:]!=['auth','status']: sys.exit(99)
print(json.dumps({'loggedIn':True,'authMethod':'claude.ai','apiProvider':'firstParty','subscriptionType':'max'}))
''')
        (self.root / 'provider.py').write_text('''import json,os,pathlib,re,subprocess,sys,time
state=pathlib.Path(os.environ['VAEL_TEAM_STATE']); prompt=sys.stdin.read()
def wait(path):
    end=time.monotonic()+15
    while not path.exists():
        if time.monotonic()>end: raise RuntimeError('fixture handshake timeout')
        time.sleep(.02)
if prompt.startswith('You are Vael'):
    for number in (7,8):
        subprocess.run(['/usr/bin/python3','tools/team.py','start',str(number),'sol'],check=True)
        wait(state/f'{number}.ready')
    socket=state/'tmux.sock'
    if not socket.exists(): socket=state/'legacy.sock'
    pid=subprocess.check_output(['tmux','-S',str(socket),'display-message','-p','#{pid}'],text=True).strip()
    (state/'server.json').write_text(json.dumps({'pid':int(pid),'cgroup':pathlib.Path('/proc/'+pid+'/cgroup').read_text()}))
    print(json.dumps({'type':'result','subtype':'success','is_error':False}),flush=True)
else:
    number=int(re.search(r'issue #(\\d+)',prompt)[1])
    print(json.dumps({'type':'thread.started','thread_id':f'fixture-session-{number}'}),flush=True)
    (state/f'{number}.ready').write_text(str(os.getpid()))
    wait(state/f'{number}.release')
    failed=(state/f'{number}.fail').exists()
    print(json.dumps({'type':'turn.failed' if failed else 'turn.completed'}),flush=True)
''')

    def executable(self, name, text):
        file = self.bin / name
        file.write_text(text)
        file.chmod(0o700)

    def wait_for(self, predicate):
        end = time.monotonic() + 8
        while not predicate():
            if time.monotonic() > end:
                self.fail('isolated lifecycle condition did not arrive')
            time.sleep(.02)

    def alive(self, pid):
        try:
            return Path(f'/proc/{pid}/stat').read_text().split()[2] != 'Z'
        except FileNotFoundError:
            return False

    def launch_lead(self, legacy=False):
        if legacy:
            self.env['LEGACY_LAUNCH'] = '1'
        before = time.monotonic()
        self.call('systemd-run', '--user', '--quiet', '--collect', '--unit=' + self.unit,
                  '--property=Type=oneshot', '--property=TimeoutStartSec=20',
                  '--working-directory=' + str(self.repo),
                  '/usr/bin/env', *[f'{key}={self.env[key]}' for key in
                                   ('VAEL_REPO', 'VAEL_TEAM_STATE', 'PATH', 'LEGACY_LAUNCH') if key in self.env],
                  '/usr/bin/python3', 'tools/team.py', 'lead')
        self.elapsed = time.monotonic() - before
        self.assertLess(self.elapsed, 8, 'lead waited for long-lived workers')
        self.assertEqual((self.state / 'lead.exit').read_text(), '0')
        self.assertEqual(self.call('systemctl', '--user', 'show', self.unit,
                                   '-p', 'ActiveState', '--value').stdout.strip(), 'inactive')
        return json.loads((self.state / 'server.json').read_text())

    def test_prior_launch_loses_workers_on_successful_lead_exit(self):
        server = self.launch_lead(legacy=True)
        self.assertIn(self.unit, server['cgroup'])
        self.wait_for(lambda: not self.alive(server['pid']))
        for number in (7, 8):
            pid = int((self.state / f'{number}.ready').read_text())
            self.wait_for(lambda: not self.alive(pid))
            self.assertFalse((self.state / f'issue-{number}.exit').exists())
        print(f'legacy lifecycle: lead returned successfully in {self.elapsed:.3f}s; '
              'server and both workers died without exit receipts')

    def test_cli_workers_survive_lead_then_report_success_failure_and_cleanup(self):
        server = self.launch_lead()
        self.assertNotIn(self.unit, server['cgroup'])
        self.assertIn('/vael-team-dispatch-', server['cgroup'])
        for number in (7, 8):
            self.assertTrue(self.alive(int((self.state / f'{number}.ready').read_text())))
        status = json.loads(self.call('/usr/bin/python3', 'tools/team.py', 'status').stdout)
        self.assertEqual(status['running'], ['vael-issue-7', 'vael-issue-8'])
        # Preserve the existing checkout and refuse a duplicate, even after the lead exited.
        work = self.state / 'worktrees/7/unfinished.txt'
        work.write_text('preserved')
        self.call('/usr/bin/python3', 'tools/team.py', 'start', '7', 'sol')
        self.assertEqual(work.read_text(), 'preserved')
        (self.state / '7.release').touch()
        self.wait_for(lambda: (self.state / 'issue-7.exit').exists())
        self.assertEqual((self.state / 'issue-7.exit').read_text(), '0')
        self.assertEqual(json.loads((self.state / 'issue-7.json').read_text())['session_id'],
                         'fixture-session-7')
        self.assertTrue(self.alive(server['pid']))  # Second worker still owns the server.
        (self.state / '8.fail').touch()
        (self.state / '8.release').touch()
        self.wait_for(lambda: (self.state / 'issue-8.exit').exists())
        self.assertEqual((self.state / 'issue-8.exit').read_text(), '1')
        self.wait_for(lambda: '--add-label' in (self.state / 'github.jsonl').read_text())
        self.assertIn('team:blocked', (self.state / 'github.jsonl').read_text())
        self.assertEqual(work.read_text(), 'preserved')
        self.wait_for(lambda: not self.alive(server['pid']))
        scope = server['cgroup'].strip().split('/')[-1]
        self.wait_for(lambda: self.call('systemctl', '--user', 'show', scope,
                                        '-p', 'ActiveState', '--value').stdout.strip() == 'inactive')
        self.assertEqual(json.loads(self.call('/usr/bin/python3', 'tools/team.py', 'status').stdout)['running'], [])
        print(f'fixed lifecycle: lead returned successfully in {self.elapsed:.3f}s; '
              'both workers survived, reported terminal results, and scope cleaned up')
