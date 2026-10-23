# Reproduce every compile error the chapter quotes; write errs.json.
import os, shutil, subprocess, json
S = os.environ.get('WORK', '/tmp/claude-0/-home-user-dr-creep-in-zig/948f64c0-9633-5eb4-8fdd-90338878ada9/scratchpad/ch05-tools')
NEW = '/home/user/dr-creep-in-zig/site/code/ch05/'
W = S + '/errs'; shutil.rmtree(W, ignore_errors=True); os.makedirs(W)
shutil.copytree('/home/user/dr-creep-in-zig/site/code/machine', W + '/machine', ignore=shutil.ignore_patterns('.zig-cache', 'zig-out'))
cases = {
 # a kind left out of the preparers' table
 'missing': [('room.zig', '    .image = image,\n', '')],
}
out = {}
for k, edits in cases.items():
    d = W + '/' + k; os.makedirs(d)
    for x in ['build.zig', 'build.zig.zon']: shutil.copy(NEW + x, d)
    shutil.copytree(NEW + 'src', d + '/src')
    for f, a, b in edits:
        p = d + '/src/' + f; s = open(p).read(); assert a in s, (k, a); open(p, 'w').write(s.replace(a, b, 1))
    if not edits: continue
    r = subprocess.run(['zig', 'build'], cwd=d, capture_output=True, text=True)
    line = next(l for l in r.stderr.split('\n') if 'error:' in l)
    out[k] = line.split('error: ', 1)[1]
    print(k, '|', line[line.index('src/'):] if 'src/' in line else line)
json.dump(out, open(S + '/errs.json', 'w'), indent=1)
