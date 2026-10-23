# Reproduce every compile error the chapter quotes; write errs.json.
import os, shutil, subprocess, json
S = os.environ.get('WORK', '/tmp/claude-0/-home-user-dr-creep-in-zig/948f64c0-9633-5eb4-8fdd-90338878ada9/scratchpad/ch04-tools')
NEW = '/home/user/dr-creep-in-zig/site/code/ch04/'
W = S + '/errs'; shutil.rmtree(W, ignore_errors=True); os.makedirs(W)
shutil.copytree('/home/user/dr-creep-in-zig/site/code/machine', W + '/machine', ignore=shutil.ignore_patterns('.zig-cache', 'zig-out'))
cases = {
 # the player region grows into the game region (before game and room move up)
 'overlap': [('map.zig', '.name = "game", .first = 0x0207, .last = 0x0208', '.name = "game", .first = 0x0206, .last = 0x0207'),
             ('map.zig', '.name = "room", .first = 0x0209, .last = 0x0209', '.name = "room", .first = 0x0208, .last = 0x0208')],
 # the Training Castle's pole as Chapter 3 left it, under the new rule
 'pole': [('training.zig', '.pole = &.{.{ .length = 8, .x = 72, .y = 128 }},', '.pole = &.{.{ .length = 9, .x = 72, .y = 128 }},')],
 # shifting by a u8
 'shift': [('player.zig', 'return @as(u8, 1) << @intCast(way);', 'return @as(u8, 1) << way;')],
}
out = {}
for k, edits in cases.items():
    d = W + '/' + k; os.makedirs(d)
    for x in ['build.zig', 'build.zig.zon']: shutil.copy(NEW + x, d)
    shutil.copytree(NEW + 'src', d + '/src')
    for f, a, b in edits:
        p = d + '/src/' + f; s = open(p).read(); assert a in s, (k, a); open(p, 'w').write(s.replace(a, b, 1))
    r = subprocess.run(['zig', 'build'], cwd=d, capture_output=True, text=True)
    line = next(l for l in r.stderr.split('\n') if 'error:' in l)
    out[k] = line.split('error: ', 1)[1]
    print(k, '|', line[line.index('src/'):] if 'src/' in line else line)
json.dump(out, open(S + '/errs.json', 'w'), indent=1)
