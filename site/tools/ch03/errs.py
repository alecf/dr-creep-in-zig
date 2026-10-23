# Reproduce every compile error the chapter quotes; write errs.json.
import os, shutil, subprocess, json, re
S = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CH3 = '/home/user/dr-creep-in-zig/site/code/ch03/'
W = S + '/errs2'; shutil.rmtree(W, ignore_errors=True); os.makedirs(W)
shutil.copytree('/home/user/dr-creep-in-zig/site/code/machine', W + '/machine', ignore=shutil.ignore_patterns('.zig-cache', 'zig-out'))
cases = {
 'back': ('training.zig', '.{ .x = 16, .y = 160, .to = .gatehouse },', '.{ .x = 16, .y = 160, .to = .ladders },'),
 'ladder': ('training.zig', 'const ladder_right = Run{ .length = 9,', 'const ladder_right = Run{ .length = 8,'),
 'zero': ('training.zig', 'const floor = Run{ .length = 40,', 'const floor = Run{ .length = 0,'),
 'overlap': ('training.zig', '.bell = &.{.{ .x = 140, .y = 168, .door = 0 }},', '.bell = &.{.{ .x = 148, .y = 168, .door = 0 }},'),
 'keys': ('training.zig', '"FIRE. THEN DO THE",', '"UP. THEN TRY THE LOCK.",'),
 'typo': ('training.zig', '.to = .gallery }', '.to = .galery }'),
}
out = {}
for k, (f, a, b) in cases.items():
    d = W + '/' + k; os.makedirs(d)
    for x in ['build.zig', 'build.zig.zon']: shutil.copy(CH3 + x, d)
    shutil.copytree(CH3 + 'src', d + '/src')
    p = d + '/src/' + f; s = open(p).read(); assert a in s, k; open(p, 'w').write(s.replace(a, b, 1))
    r = subprocess.run(['zig', 'build'], cwd=d, capture_output=True, text=True)
    line = next(l for l in r.stderr.split('\n') if 'error:' in l)
    out[k] = line.split('error: ', 1)[1]
    print(k, '|', line[line.index('src/'):] if 'src/' in line else line)
json.dump(out, open(S + '/errs.json', 'w'), indent=1)
