# Pictures and sound clips for Chapter 10, from the stage runs kept by
# rebuild.py (rb-*.wav): a picture of the waltz's notes, and MP3s to play.
import wave, subprocess
import numpy as np
from PIL import Image, ImageDraw
S = '/tmp/claude-0/-home-claude-dr-creep-in-zig/792f76de-5ad6-5ca5-bfb5-7d7dced7c491/scratchpad/ch10/'
O = '/home/claude/dr-creep-in-zig/site/chapters/images/'

def samples(tag):
    w = wave.open(S + 'rb-%s.wav' % tag)
    assert w.getframerate() == 44100 and w.getnchannels() == 1
    return np.frombuffer(w.readframes(w.getnframes()), dtype='<i2').astype(np.float32) / 32768

# The waltz: its first four bars, as a picture of pitch against time. Each
# column is one frame (882 samples); each row a quarter of a semitone,
# from A1 (55 Hz) to A6 (1,760 Hz), on a log scale like a keyboard.
s = samples('C')
first, frames = 1, 4 * 3 * 2 * 8 * 256 // 0xB0 + 4  # four bars of six units of 8 ticks, at $B0
W, H = 768, 240
lo, hi = 55.0, 1760.0
rows = np.array([lo * (hi / lo) ** (1 - (y + 0.5) / H) for y in range(H)])
N = 8192
win = np.hanning(N)
img = np.zeros((H, frames))
for f in range(frames):
    c = (first + f) * 882 + 441
    seg = s[max(0, c - N // 2):c + N // 2]
    seg = np.pad(seg, (0, N - len(seg)))
    spec = np.abs(np.fft.rfft(seg * win))
    img[:, f] = np.interp(rows, np.fft.rfftfreq(N, 1 / 44100), spec)
db = 20 * np.log10(img / img.max() + 1e-9)
cols = np.clip((db + 48) / 48, 0, 1)  # the loudest 48 dB, the rest dark
rgb = np.stack([16 + cols ** 1.6 * 239, 16 + cols ** 1.1 * 214, 40 + cols * 100], axis=-1).astype(np.uint8)
pic = Image.fromarray(rgb).resize((W - 40, H), Image.BILINEAR)
out = Image.new('RGB', (W, H + 20), (16, 16, 40))
out.paste(pic, (40, 0))
d = ImageDraw.Draw(out)
for name, hz in [('A2', 110), ('A3', 220), ('A4', 440), ('A5', 880)]:
    y = int(H * (1 - np.log(hz / lo) / np.log(hi / lo)))
    d.line([(34, y), (39, y)], fill=(200, 200, 220))
    d.text((4, y - 6), name, fill=(200, 200, 220))
for bar in range(5):
    x = 40 + int((W - 40) * bar * (6 * 8 * 256 / 0xB0) / frames)
    d.line([(x, H), (x, H + 6)], fill=(200, 200, 220))
    if bar < 4: d.text((x + 4, H + 6), 'bar %d' % (bar + 1), fill=(200, 200, 220))
out.save(O + '10-waltz.png')
print('waltz', frames, 'frames')

# The clips: the experiment's A4, the waltz once round, the map's chime
# after the waltz, and the Boss Battle.
for name, tag, start, length in [('note', 'A', 0, 3), ('waltz', 'C', 0, 24), ('chime', 'D', 5, 3),
                                 ('boss', 'E', 0, 76)]:
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-ss', str(start), '-t', str(length), '-i', S + 'rb-%s.wav' % tag,
                    '-ac', '1', '-ar', '44100', '-codec:a', 'libmp3lame', '-q:a', '6', O + '10-%s.mp3' % name], check=True)
    print(name, tag)
