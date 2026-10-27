---
chapter: 12
part: epilogue
title: "All the Castles"
checkpoint: ch11
---

:::mission-briefing
The game is finished. This last stop has no new code, only four things
to do with what you've built. First, slot a castle disk into the Comet
and play the doctor's own castles on your engine. Then look back at
where the 64 KB went and where each frame's cycles went, with real
measurements of the finished game. Then a quest: five details that
only a real castle can settle, and how to check each one. Last, three
Bonus Stages that use everything at once.
:::

## Slot in a castle disk

You know the feeling of putting a new cartridge in an old console and
watching it boot? This is that, except you wrote the game.

Start from the finished game, Chapter 11's checkpoint. If you have a
1984 castle disk as a disk image (a `.d64` file), power on the page
below, and use **Got a castle disk? Slot it in** under the screen. The
page reads the file on your own computer and copies it into the
Comet's drive. Nothing is sent anywhere. Headless, it's one flag:

```
zig build run -- --disk castles.d64 --frames 120
```

The Comet powers on again with the disk in the drive, and on the very
first frame the code from Chapter 11 goes to work. `files.catalog`
reads the directory listing into staging. The menu fills with the
doctor's castles, in the order they were saved on the disk. `files.pick`
loads the first one right over the listing, and the title says its
name.

Press Esc, pick a castle, and press fire. What you see next is
everything you've typed, running at once. Each room is drawn by
`room.draw` from the castle's own bytes, in the same format we matched
in Chapter 3. Every doorbell rings through `doors.ring`. Every mummy
climbs out of its tomb through `mummy.walk`, and every Frankenstein
picks his way through `frankenstein.turn`. The creak of each opening
door is Chapter 10's sound driver.

The pictures are ours. A castle file says *what* goes *where*: a door
at this spot, a ladder this long, a Frankenstein asleep in that alcove.
It doesn't say what a door looks like. That's the shape table's job,
and our shape table holds our art. The exception is an image record: a
picture the castle carries inside its own file. Those appear exactly as
their designer drew them.

Best times and saved games go onto the castle disk. Press **Save the
disk** before you close the page, and slot it back in next time.

**This is the moment the whole tutorial was heading for:** castle data
from 1984, read byte for byte by code you wrote.

## Where the 64 KB went

Chapter 1's memory map had a handful of rows: the stack, the player's
few bytes, the program image and the hardware. The finished game's map
has 33 regions, and the compiler still checks every pair for overlaps. Here is all of
memory, one square for each 256 bytes, drawn by a script from `map.zig`
itself:

:::diagram ep-memory
The finished game's 65,536 bytes. Hover over a square to see who owns it.
:::

Let's read it from the biggest owner down.

**Reserved: 24,221 bytes.** Most of it is the program image, 20,992
bytes at `$0800` set aside for the game's code. Our Comet doesn't count
code bytes, but the space is held back so the budget stays honest. The
stack and the expansion hardware's addresses take the rest.

**The hardware: 12,179 bytes.** The bitmap alone is 8,000. The screen
plane and colour RAM are 1,000 each, and the sprite frames 2,048. The
machine put them there, not us.

**The castle and its files: 16,762 bytes.** That's two 8 KB buffers,
plus the best times and the castle list. Staging holds the castle as it
came off the disk, and the castle buffer holds the game being played.
That's a quarter of the whole machine for two copies of one file, and
it's worth it. A new game is one `m.copy`. A saved game is the castle
buffer written straight to the disk. 1984 gave a castle 8 KB too. The
Training Castle's 20 rooms fill 4,644 bytes of each buffer, so the
paler part is room for the doctor's bigger castles.

**Built-in tables: 8,464 bytes.** The shape table is the big one, 5,325
of its 6,144 bytes. Then come the music (1,029 of 1,280), the sound
effects (267 of 384), the star map (256, full) and the row table (400).
All but the row table were built by the compiler and copied into
place at boot. The row table is worked out at boot.

**The game's working memory: 1,838 bytes.** That's everything the game
*remembers* while it runs: both explorers, 8 actor slots, 32 object
slots, the sound driver, the shell, and the navigation grid. The grid
is 1,000 of those bytes. Take it away and the rest of the game's state
fits in 838 bytes.

**Nobody's: 2,072 bytes,** in eleven scraps. The biggest is
`$0500–$07FF`, 768 bytes. The zero page, all 256 bytes of it, is still
empty.

So memory was tight, but not because of the game's own state. The
screen and the program took more than half before we wrote a line, and
the castle took a quarter. The game lived in the gaps.

### The memory tricks that paid

- **The castle is the save game** (Chapter 9). Everything a game knows
  between rooms lives in the castle header and its records. So saving
  a game needed no file format of its own: Chapter 11 writes the castle
  buffer to the disk, and that's it.
- **Taking turns with the same bytes.** The castle map, the escape and
  GAME OVER share seven bytes, because only one of them is ever on
  screen. The disk's directory listing borrows staging until the first
  castle lands on top of it.
- **Fixed slots instead of allocation.** Eight actors and 32 objects in
  16-byte slots, 640 bytes for everything a room can hold. Nothing is
  ever allocated, so nothing can run out halfway through a room.
- **Building tables while the game compiles.** The shapes, the
  frequency table, the tunes, even the whole master disk are built by
  `comptime` code. They cost bytes, but no cycles at all.

## Where the frame went

Memory was the tight budget. The frame turned out to be the roomy one.
The budget is 19,656 cycles a frame. To measure a room in play, I took
the finished game on one tour of the Training Castle. The N key takes
the explorer into each room in turn, and he stands in the doorway for
six seconds (300 frames). Meanwhile the room's machines run and its
monsters come for him. Here is the busiest frame of each room, split by meter bucket:

:::diagram ep-frame
The busiest frame in play in each room of the Training Castle, by meter
bucket, and each room's average frame. Measured on the finished game.
:::

The busiest frame of the whole tour is in Under Fire: 3,450 cycles,
18% of the budget. Most of it, 2,502 cycles, is in the objects bucket,
where the ray gun moves along its track. The average frame of a room
runs from 497 cycles in the Gatehouse to 1,238 in Mummy in a Storm.
That's between 2.5% and 6.3% of the frame.

Two explorers work harder. Over the Boss Battle's game for two, the
average frame in a room is 953 cycles. The busiest is 5,090, about a
quarter of the budget. That frame comes in the Way Out, with both
explorers on the move (2,500 cycles of actors) as the way-out door is
drawn open (2,146 of objects).

The busiest frame with the display *on* isn't in a room at all. It's
the escape screen adding a piece of the final room: 14,436 cycles, 73%
of the budget, and still inside it.

The really big jobs never try to fit. A frame that draws a room takes
up to 244,096 cycles, more than twelve frames' worth. Power-on, with the disk read,
takes 638,586. Each of those runs with the display blanked, as a
loading pause. In the Boss Battle, 34 loading pauses use 356 of the
3,800 frame slots, about 7 seconds of a 76-second game. Overruns: none.

So the squeeze was never the frame in play. It was drawing and the
disk. If you keep one trick from this whole tutorial, keep Chapter 2's:
when a job is too big for a frame, blank the display and let it take
as long as it needs.

### The frame tricks that paid

The debug switches turn tricks off, so we can measure them on the
finished game.

- **The navigation grid** (Chapter 4). The Q key makes the explorer
  search the castle for his next step instead of reading the grid. On
  the same tour with Q on, the average room frame doubles, from 707 cycles to 1,408, and
  the busiest frame climbs to 5,146. Chapter 4 measured a walking step:
  204 cycles with the grid and 1,626 without. The grid costs 1,000
  bytes, and it pays for them every frame.
- **Tinting instead of redrawing** (Chapter 6). Changing a conveyor's
  colour costs 224 cycles. Redrawing it costs 1,320, and swapping its
  picture 2,972.
- **The sound driver** (Chapter 10) costs 14 cycles a frame when it's
  silent, and its busiest frame in the Boss Battle was 228.
- **The dice** (Chapter 8) cost 24 cycles a roll.

Not every trick earned much. The C key makes every actor check every
object, every turn. Normally an actor checks the objects only when the
hardware says his sprite has touched the background. On the tour, C
moves the average from 707 to 743 cycles, because the
Training Castle's rooms hold only a few objects each. In a room packed
with eight actors and all 32 objects, Chapter 5 worked out it would
cost about 70% of the frame. Checking only on a hit is insurance for
the busiest castles, not a saving you'll see in ours.

## The quest: still to check

Chapter 11 left five details that only a real castle can settle. Two
tools help with all of them.

First, the map shows every room you've been in. To see a whole castle,
start a game, and on the map press N again and again. Each room N flips
to counts as visited, and the castle fills in.

Second, a test can play detective. In a test, `@embedFile` your disk
image and `m.insert` it. Then `files.pick` a castle and `game.start` a
game, and walk any room's records with a `castle.Walker` that starts at
`room.stream(m, n)`. Counting kinds room by room tells you where to
look.

**1. The doors on the map.** Every door record says where its gap
shows on the castle map: which wall, and how far along. Our authoring
kit works that out for itself, in `author.door`. A real castle's
designer set those bytes by hand. Our map draws whatever bytes the
castle has, so the check is by eye. Fill in each castle's map and look
at every gap and arrow. Each gap should sit in a wall, where two rooms
meet. Each arrow should be outside its room, pointing in. If one
isn't, compare the door's bytes with what `author.door` would make.
Either the designer did something our map code doesn't expect, or our
arrow table in `chart.zig` is off.

**2. Two Frankensteins on one floor.** 1984's Frankensteins steer round
each other: each one keeps a mask of the ways another monster is
blocking. Ours don't, because no Training Castle room has two on one
floor. Find a room with two Frankensteins on the same walkway (a test
that counts `.frankenstein` records will find the rooms with two) and
wake them both. If they walk through each other, the mask belongs in
`choose`, in `frankenstein.zig`, which picks his way at each junction.

**3. Ankhs and alcoves.** Our ankh is 16 rows tall, and 1984's is 23.
1984's alcove is narrower and taller, and stands on the walkway. Ours
stands above it. Find rooms with each and look closely. Does an alcove
float above its floor, or a tall ankh poke through a walkway? Press G to
draw the navigation grid over the room: the walkway under an alcove
must still be walkable.

**4. Whose turn is it?** A castle's header says which room each
explorer starts in, and a castle may start them in different rooms.
Then 1984 lets player 2 play on until he meets player 1, where ours
take strict turns. Look for such a castle: a test can compare the two
bytes at `castle.start_room`. Play it for two and watch whose room
comes next. The rule lives in `game.next`, and it's yours to change.

**5. The disk's own tunes.** The castle disk carries its music as files
too, and its tunes use the same commands as our sound driver. Three
things may stand in the way. A tempo byte below `$13` ticks faster than
50 times a second, but our beat can only tick once a frame, so
`sound.step` would have to let the beat carry more than once. A note
may land on B7, one past the top of our frequency table. And 1984's
title tune rests about 11 seconds between plays. To find the files, list
the whole disk with `$` (Chapter 11's "disk directory screen" Bonus
Stage). To find a home for one, look at the memory diagram above: the
music region has 251 bytes to spare, and `$0500–$07FF` has 768.

## Bonus Stages

Three big builds to finish on, with no answer keys. The compiler and
the tests will tell you how you're doing.

:::bonus-stage Recreate a real castle, room by room
Pick one of the doctor's castles and rebuild it with the authoring kit,
the way `training.zig` builds ours. Flip through it with N and P, one
room at a time, and write each room as a `Room` of the plan: its
colour, its place on the map, its doors, walkways, ladders, machines
and monsters.

To check your work, load the real castle in a test, and walk your
room's records and the disk's side by side with `castle.Walker`. Each
kind should have the same records, with the same bytes. Two things
will differ, and both are worth knowing. The kit writes each room's
kinds in tag order, and the designer may not have, so compare record
by record, not the whole file at once. And door map bytes are the
kit's own (quest item 1).

Sometimes the kit will refuse something the designer did. The
designer might hang a machine off the left edge (Chapter 11 fixed the
engine for that), and the kit says it "runs off the screen". When that
happens, the kit is stricter than the engine. Decide whether to loosen
it.
:::

:::bonus-stage Design your own castle
Now the real prize: a castle of your own. Make a new file like
`training.zig`, with an enum of room names, a plan and
`author.build(Room, plan)`. Then add one line to `master.zig`, a
`drive.save` of your castle as a Z file. It's on the menu the next time
the game builds, in disk order.

The kit checks your castle while the game compiles. A castle has at
most 31 rooms, and all of it must fit in 8 KB. Doors must lead to doors
that lead back, and a ladder must start on a walkway. Each mistake is a
compile error that names the room. Three rules from these chapters make
a good castle:

- Show each new idea in a room where it's safe to learn, before a room
  where it can hurt.
- Give the player a moment on arrival, out of harm's way, to read the
  room.
- Make sure every room can still be won after a death, and on a second
  visit. The castle remembers what changed.

Then press **Save the disk** and hand it to a friend. Your castle loads
on anybody's Comet, with its own best times.
:::

:::bonus-stage A new kind of thing
Invent something for the doctor's castles: a spider that drops on its
thread, a bat, a moving floor. A new kind touches a handful of tables,
and the compiler finds every one for you. Add `spider` to the end of
`castle.Kind` and build:

```
src/castle.zig:259:12: error: switch must handle all possibilities
src/castle.zig:107:5: note: unhandled enumeration value: 'spider'
```

That's `framing`, which says how a kind's records are laid out in a
room's stream. Give the spider a record (an `extern struct`) and its
framing, and build again:

```
src/author.zig:321:31: error: no field named 'spider' in struct 'author.Room(training.Room)'
```

The kit's `Room` has a list for every kind. Add one for spiders:

```
src/room.zig:37:70: error: missing struct field: spider
```

The `prepares` table needs a function that sets a spider up in a room.
With that, the game builds. If the spider moves, it's an actor, and
adding it to `actors.Kind` gives

```
src/actors.zig:76:62: error: missing struct field: spider
```

until it has a behaviour: a turn, how it dies, and what it does when it
touches someone. If an explorer can stand in front of its web and do
something, that's an object kind, and `objects.Kind` sends you to its
handlers the same way. Its pictures go in `shapes.Id`:

```
src/shapes.zig:233:46: error: root source file struct 'art' has no member named 'spider'
```

until `art.zig` draws it. The shape table has 819 bytes to spare. If
you outgrow them, the compiler says "the shape table doesn't fit in its
region", and the memory diagram shows where you could move it.

Last, `zig build test` fails once:

```
error: 'castle.test.tag codes turn into kinds and back' failed:
       expected null, found .spider
```

That test knows 1984's tag codes, which stop at `$0836`. Your spider's
tag is `$0839`, a code no 1984 castle contains. That's fine: you've
gone past 1984 now. Change the test to say so, and give the spider a
room in a castle of your own.
:::

## The last door

You started with a purple border. Now there's a castle format from
1984, two explorers, a castle full of machines and monsters, a sound
driver, a disk drive and a menu. It all fits inside 64 KB, it all runs
at 50 frames a second, and you typed every line.

The doctor still isn't home. His castles are all yours.

:::warp-zone
The finished game is Chapter 11's checkpoint,
[`code/ch11/`](../code/ch11/), also as [`ch11.zip`](downloads/ch11.zip),
with the Comet 64 in [`code/machine/`](../code/machine/). The
programmer's reference card,
[`machine/REFERENCE.md`](../code/machine/REFERENCE.md), has every
register you used along the way.
:::
