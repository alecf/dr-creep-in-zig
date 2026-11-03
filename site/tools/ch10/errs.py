# Reproduce every compile error the chapter quotes, from the reader's project
# at the point the chapter quotes it (snapshots kept by rebuild.py); write
# errs.json. Run rebuild.py first.
import os, shutil, subprocess, json
S = os.environ.get('WORK', '/tmp/claude-0/-home-claude-dr-creep-in-zig/792f76de-5ad6-5ca5-bfb5-7d7dced7c491/scratchpad/ch10')
W = S + '/errs'; shutil.rmtree(W, ignore_errors=True); os.makedirs(W)
shutil.copytree('/home/claude/dr-creep-in-zig/site/code/machine', W + '/machine', ignore=shutil.ignore_patterns('.zig-cache', 'zig-out'))
cases = {
 # right after listing A5: the table has a note too many ("Build now")
 'b7': 'at-A5',
}
out = {}
for k, snap in cases.items():
    d = W + '/' + k
    shutil.copytree(S + '/' + snap, d)
    r = subprocess.run(['/usr/local/bin/zig', 'build'], cwd=d, capture_output=True, text=True)
    errors = [l for l in r.stderr.split('\n') if ': error: ' in l]
    assert r.returncode != 0 and len(errors) == 1, (k, r.stderr[-2000:])
    out[k] = errors[0].split('error: ', 1)[1]
    print(k, '|', errors[0])
json.dump(out, open(S + '/errs.json', 'w'), indent=1)
