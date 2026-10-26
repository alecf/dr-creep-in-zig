//! The Training Castle: one lesson per room, written with the authoring
//! kit.

const author = @import("author.zig");
const castle = @import("castle.zig");
const art = @import("art.zig");
const shapes = @import("shapes.zig");
const Color = @import("machine").Color;
const Run = author.Run;
const Line = author.Line;

/// Every room, in directory order: room 0 is `gatehouse`.
pub const Room = enum {
    gatehouse,
    gallery,
    ladders,
    poles,
    lightning,
    forcefields,
    trapdoors,
    conveyors,
    transmitter,
    keys,
    ray_guns,
    mummy,
    frankenstein,
    frank_trap,
    frank_ride,
    under_fire,
    mummy_storm,
    locked_away,
    two_players,
    way_out,
};

// The pieces most rooms share.
const floor = Run{ .length = 40, .x = 16, .y = 192 };
const upper_left = Run{ .length = 20, .x = 16, .y = 128 };
const upper_right = Run{ .length = 20, .x = 96, .y = 128 };
const ladder_left = Run{ .length = 9, .x = 56, .y = 128 };
const ladder_right = Run{ .length = 9, .x = 112, .y = 128 };

/// Where room `n` of the snake sits on the castle map: five rooms to a
/// row, the rows running right, left, right, left.
fn spot(n: u8) author.Map {
    const row = n / 5;
    const col = if (row % 2 == 0) n % 5 else 4 - n % 5;
    return .{ .x = 56 + 16 * col, .y = 48 + 24 * row, .width = 4, .height = 3 };
}

/// A key of colour `color`, standing at (x, y). Its number is its colour,
/// and its picture the 1984 disk's, $50 plus the colour.
fn key(color: Color, x: u8, y: u8) castle.Key {
    return .{ .number = @intFromEnum(color), .shape = 0x50 + @as(u8, @intFromEnum(color)), .x = x, .y = y };
}

/// A lock for the key of colour `color`, opening the room's door `door`.
fn lock(color: Color, door: u8, x: u8, y: u8) castle.Lock {
    return .{ .number = @intFromEnum(color), .shape = 0x57 + @as(u8, @intFromEnum(color)), .door = door, .x = x, .y = y };
}

/// A room's words: a tall title across the top, then the lesson, a line
/// every 10 rows.
fn says(comptime title: []const u8, comptime lines: []const []const u8) []const Line {
    comptime {
        const x = 16 + (160 - 8 * title.len) / 2 / 4 * 4; // centred, on a byte
        var out: []const Line = &.{.{ .x = x, .y = 8, .color = .yellow, .height = 2, .words = title }};
        for (lines, 0..) |words, i| {
            out = out ++ [_]Line{.{ .x = 20, .y = 32 + 10 * i, .color = .light_grey, .words = words }};
        }
        const done = out[0..out.len].*;
        return &done;
    }
}

/// The castle, as declarations.
pub const plan: author.Castle(Room) = .{
    .start = .{ .room = .gatehouse, .door = 0 },
    .rooms = .{
        .gatehouse = .{
            .color = .red,
            .map = spot(0),
            .door = &.{.{ .x = 156, .y = 160, .to = .gallery }},
            .walkway = &.{floor},
            .bell = &.{.{ .x = 140, .y = 168, .door = 0 }},
            .text = says("THE GATEHOUSE", &.{
                "WELCOME, EXPLORER!",
                "MOST DOORS IN THE",
                "CASTLE ARE SHUT.",
                "TO OPEN ONE, STAND",
                "AT THE BELL BESIDE",
                "IT AND PRESS FIRE.",
                "THEN STAND IN THE",
                "OPEN DOORWAY AND",
                "PUSH UP AND RIGHT.",
            }),
        },
        .gallery = .{
            .color = .orange,
            .map = spot(1),
            .door = &.{
                .{ .x = 16, .y = 160, .to = .gatehouse },
                .{ .x = 132, .y = 160, .to = .ladders },
            },
            .walkway = &.{.{ .length = 35, .x = 16, .y = 192 }}, // it stops short of the wall
            .bell = &.{.{ .x = 112, .y = 168, .door = 1 }},
            .text = says("THE LONG GALLERY", &.{
                "WALKWAYS ARE THE",
                "CASTLE'S FLOORS.",
                "PUSH THE STICK LEFT",
                "OR RIGHT TO WALK.",
                "A WALKWAY'S END IS",
                "AS FAR AS YOU GO.",
                "THE DOOR NEAR THE",
                "FAR END LEADS ON.",
            }),
        },
        .ladders = .{
            .color = .purple,
            .map = spot(2),
            .door = &.{
                .{ .x = 16, .y = 160, .to = .gallery, .to_door = 1 },
                .{ .x = 156, .y = 96, .to = .poles },
            },
            .walkway = &.{ floor, upper_right },
            .ladder = &.{ladder_right},
            .bell = &.{.{ .x = 140, .y = 104, .door = 1 }},
            .text = says("LADDERS", &.{
                "TO CLIMB A LADDER,",
                "STAND AT ITS FOOT",
                "AND PUSH UP. PUSH",
                "DOWN AT THE TOP TO",
                "CLIMB BACK DOWN.",
                "THE WAY ON IS UP.",
            }),
        },
        .poles = .{
            .color = .green,
            .map = spot(3),
            .door = &.{
                .{ .x = 16, .y = 96, .to = .ladders, .to_door = 1 },
                .{ .x = 156, .y = 160, .to = .lightning },
            },
            .walkway = &.{ floor, upper_left },
            .pole = &.{.{ .length = 8, .x = 72, .y = 128 }},
            .bell = &.{.{ .x = 140, .y = 168, .door = 1 }},
            .text = says("SLIDING POLES", &.{
                "A SLIDING POLE IS A",
                "QUICK WAY DOWN.",
                "WALK ONTO IT AND",
                "PUSH DOWN. THERE'S",
                "NO CLIMBING BACK UP",
                "A POLE: LOOK FIRST.",
            }),
        },
        .lightning = .{
            .color = .blue,
            .map = spot(4),
            .door = &.{
                .{ .x = 16, .y = 160, .to = .poles, .to_door = 1 },
                .{ .x = 156, .y = 160, .to = .forcefields },
            },
            .walkway = &.{ floor, upper_left },
            .ladder = &.{ladder_left},
            .bell = &.{.{ .x = 140, .y = 168, .door = 1 }},
            .lightning = &.{
                // Two machines, running, and then the switch that works
                // them both: it names them by their places, 0 and 8.
                .{ .state = castle.lightning_on, .x = 104, .y = 112, .length = 6, .machines = .{ 0, 0, 0, 0 } },
                .{ .state = castle.lightning_on, .x = 124, .y = 112, .length = 6, .machines = .{ 0, 0, 0, 0 } },
                .{ .state = castle.lightning_switch | castle.lightning_on, .x = 28, .y = 104, .length = 0, .machines = .{ 0, 8, 0xFF, 0xFF } },
            },
            .text = says("LIGHTNING", &.{
                "TOUCH LIGHTNING AND",
                "YOU'RE TOAST. THE",
                "SWITCH UPSTAIRS",
                "RUNS BOTH MACHINES.",
                "PUSH DOWN AT IT TO",
                "TURN THEM OFF.",
            }),
        },
        .forcefields = .{
            .color = .cyan,
            .map = spot(5),
            .door = &.{
                .{ .x = 156, .y = 160, .to = .lightning, .to_door = 1 },
                .{ .x = 16, .y = 160, .to = .trapdoors },
            },
            .walkway = &.{floor},
            .bell = &.{.{ .x = 44, .y = 168, .door = 1 }},
            .forcefield = &.{.{ .button_x = 120, .button_y = 160, .field_x = 80, .field_y = 168 }},
            .text = says("FORCEFIELDS", &.{
                "A FORCEFIELD WON'T",
                "LET YOU PAST. ITS",
                "BUTTON SWITCHES IT",
                "OFF, BUT ONLY UNTIL",
                "ITS GAUGE FILLS UP.",
                "PRESS IT, THEN RUN!",
            }),
        },
        .trapdoors = .{
            .color = .brown,
            .map = spot(6),
            .door = &.{
                .{ .x = 156, .y = 160, .to = .forcefields, .to_door = 1 },
                .{ .x = 16, .y = 160, .to = .conveyors },
            },
            .walkway = &.{floor},
            .bell = &.{.{ .x = 44, .y = 168, .door = 1 }},
            // Shut, with its switch beyond it: it opens behind you.
            .trapdoor = &.{.{ .state = 0, .x = 72, .y = 192, .switch_x = 32, .switch_y = 184 }},
            .text = says("TRAPDOORS", &.{
                "THIS TRAPDOOR IS",
                "SHUT. STEP ON ITS",
                "SWITCH AND IT OPENS",
                "BEHIND YOU. STEP ON",
                "IT AGAIN AND IT",
                "SHUTS.",
            }),
        },
        .conveyors = .{
            .color = .pink,
            .map = spot(7),
            .door = &.{
                .{ .x = 156, .y = 160, .to = .trapdoors, .to_door = 1 },
                .{ .x = 16, .y = 160, .to = .transmitter },
            },
            // The floor runs into an open trapdoor, and its switch is on
            // the far side. The high road goes round: up the ladder, along,
            // and down the pole.
            .walkway = &.{ floor, .{ .length = 22, .x = 32, .y = 128 } },
            .ladder = &.{ladder_right},
            .pole = &.{.{ .length = 8, .x = 36, .y = 128 }},
            .bell = &.{.{ .x = 44, .y = 168, .door = 1 }},
            .trapdoor = &.{.{ .state = castle.trapdoor_open, .x = 52, .y = 192, .switch_x = 28, .switch_y = 184 }},
            .conveyor = &.{.{ .state = castle.conveyor_on | castle.conveyor_left, .x = 60, .y = 184, .control_x = 96, .control_y = 160 }},
            .text = says("CONVEYORS", &.{
                "A BELT CARRIES YOU,",
                "WALKING OR NOT. ITS",
                "CONTROL STOPS IT,",
                "THEN STARTS IT THE",
                "OTHER WAY. THIS ONE",
                "RUNS INTO A HOLE!",
            }),
        },
        .transmitter = .{
            .color = .light_blue,
            .map = spot(8),
            .door = &.{
                .{ .x = 156, .y = 160, .to = .conveyors, .to_door = 1 },
                .{ .x = 16, .y = 96, .to = .keys },
            },
            .walkway = &.{ floor, upper_left },
            .pole = &.{.{ .length = 8, .x = 72, .y = 128 }}, // the way down; the booth is the way up
            .bell = &.{.{ .x = 44, .y = 104, .door = 1 }},
            .teleport = .{
                .x = 112,
                .y = 160,
                .target = 1,
                .pads = &.{
                    .{ .x = 60, .y = 120 }, // pad 0, red: upstairs
                    .{ .x = 136, .y = 184 }, // pad 1, cyan: by the door
                },
            },
            .text = says("THE TRANSMITTER", &.{
                "STAND IN THE BOOTH",
                "AND PUSH UP: ITS",
                "LAMP TAKES THE",
                "COLOUR OF EACH PAD",
                "IN TURN. PRESS FIRE",
                "AND YOU'RE THERE.",
            }),
        },
        .keys = .{
            .color = .yellow,
            .map = spot(9),
            .door = &.{
                .{ .x = 156, .y = 160, .to = .transmitter, .to_door = 1 },
                .{ .x = 16, .y = 160, .to = .ray_guns },
            },
            .walkway = &.{ floor, upper_right },
            .ladder = &.{ladder_right},
            .key = &.{key(.green, 168, 112)}, // upstairs, at the walkway's end
            .lock = &.{lock(.green, 1, 44, 168)}, // where door 1's bell would be
            .text = says("KEYS AND LOCKS", &.{
                "SOME DOORS HAVE NO",
                "BELL, ONLY A LOCK.",
                "FIND THE KEY OF THE",
                "SAME COLOUR, STAND",
                "AT IT AND PRESS",
                "FIRE. THEN DO THE",
                "SAME AT THE LOCK.",
            }),
        },
        .ray_guns = .{
            .color = .grey,
            .map = spot(10),
            .door = &.{
                .{ .x = 16, .y = 160, .to = .keys, .to_door = 1 },
                .{ .x = 156, .y = 160, .to = .mummy },
            },
            .walkway = &.{floor},
            .bell = &.{.{ .x = 140, .y = 168, .door = 1 }},
            // Facing right, down the room, from a track that runs from
            // high up to the floor. You come in behind it, by its panel.
            .ray_gun = &.{.{ .state = .{}, .x = 56, .y = 96, .length = 12, .gun_y = 171, .control_x = 40, .control_y = 168 }},
            .text = says("RAY GUNS", &.{
                "A RAY GUN SLIDES UP",
                "AND DOWN ITS TRACK,",
                "AIMING AT YOU. AT",
                "ITS CONTROL PANEL,",
                "YOU DO THE AIMING:",
                "UP, DOWN AND FIRE.",
            }),
        },
        .mummy = .{
            .color = .orange,
            .map = spot(11),
            // You come in upstairs, where the mummy can't follow, past the
            // ankh. His tomb is on the floor below, and the way down is the
            // pole at the far end.
            .door = &.{
                .{ .x = 16, .y = 96, .to = .ray_guns, .to_door = 1 },
                .{ .x = 156, .y = 160, .to = .frankenstein },
            },
            .walkway = &.{ floor, .{ .length = 30, .x = 16, .y = 128 } },
            .pole = &.{.{ .length = 8, .x = 128, .y = 128 }},
            .bell = &.{.{ .x = 140, .y = 168, .door = 1 }},
            .mummy = &.{.{ .state = castle.mummy_tomb, .ankh_x = 48, .ankh_y = 112, .tomb_x = 28, .tomb_y = 168, .x = 0, .y = 0 }},
            .text = says("THE MUMMY", &.{
                "A MUMMY SLEEPS IN",
                "HIS TOMB. PASS THE",
                "ANKH AND HE WAKES.",
                "HE KEEPS TO HIS",
                "FLOOR: LEAD HIM ONE",
                "WAY, RUN THE OTHER.",
            }),
        },
        .frankenstein = .{
            .color = .green,
            .map = spot(12),
            // Upstairs, out of his reach; the pole takes you down to his
            // floor, in front of him.
            .door = &.{
                .{ .x = 16, .y = 96, .to = .mummy, .to_door = 1 },
                .{ .x = 156, .y = 160, .to = .frank_trap },
            },
            .walkway = &.{ floor, upper_left },
            .pole = &.{.{ .length = 8, .x = 88, .y = 128 }},
            .bell = &.{.{ .x = 140, .y = 168, .door = 1 }},
            .frankenstein = &.{.{ .state = .{}, .x = 24, .y = 168, .frank_x = 0, .frank_y = 0, .frame = 0, .way = 0 }},
            .text = says("FRANKENSTEIN", &.{
                "FRANK SLEEPS UNTIL",
                "YOU STAND ON HIS",
                "FLOOR, IN FRONT OF",
                "HIM. THEN HE PACES",
                "IT. GO DOWN BEHIND",
                "HIM, AND RUN!",
            }),
        },
        .frank_trap = .{
            .color = .red,
            .map = spot(13),
            // He's awake already, on the walkway on the right, and the
            // ladder down from it ends on a trapdoor. Its switch is on the
            // floor, reached by the pole from where you come in.
            .door = &.{
                .{ .x = 16, .y = 96, .to = .frankenstein, .to_door = 1 },
                .{ .x = 156, .y = 96, .to = .frank_ride },
            },
            .walkway = &.{ floor, upper_left, upper_right },
            .pole = &.{.{ .length = 8, .x = 80, .y = 128 }},
            .ladder = &.{.{ .length = 9, .x = 124, .y = 128 }},
            .bell = &.{.{ .x = 140, .y = 104, .door = 1 }},
            .trapdoor = &.{.{ .state = 0, .x = 120, .y = 192, .switch_x = 64, .switch_y = 184 }},
            .frankenstein = &.{.{
                .state = .{ .awake = true },
                .x = 100,
                .y = 104,
                .frank_x = 100,
                .frank_y = 107,
                .frame = @intFromEnum(shapes.Id.frank_right_0),
                .way = 0x80, // still, until he chooses
            }},
            .text = says("A TRAP FOR FRANK", &.{
                "FRANK PACES HIS",
                "WALKWAY. GO DOWN,",
                "STEP ON THE SWITCH",
                "AND WAIT: HE'LL",
                "CLIMB DOWN AFTER",
                "YOU, INTO THE HOLE.",
            }),
        },
        .frank_ride = .{
            .color = .purple,
            .map = spot(14),
            // The belt runs right, from his alcove towards the pole, and
            // its control is just past the pole.
            .door = &.{
                .{ .x = 16, .y = 96, .to = .frank_trap, .to_door = 1 },
                .{ .x = 156, .y = 160, .to = .under_fire },
            },
            .walkway = &.{ floor, .{ .length = 25, .x = 16, .y = 128 } },
            .pole = &.{.{ .length = 8, .x = 104, .y = 128 }},
            .bell = &.{.{ .x = 140, .y = 168, .door = 1 }},
            .conveyor = &.{.{ .state = castle.conveyor_on, .x = 56, .y = 184, .control_x = 116, .control_y = 160 }},
            .frankenstein = &.{.{ .state = .{}, .x = 24, .y = 168, .frank_x = 0, .frank_y = 0, .frame = 0, .way = 0 }},
            .text = says("FRANK'S RIDE", &.{
                "CONVEYORS CARRY",
                "MONSTERS TOO. THIS",
                "ONE BRINGS HIM YOUR",
                "WAY. TURN IT ROUND",
                "AND WATCH HIM WALK",
                "ON THE SPOT.",
            }),
        },
        .under_fire = .{
            .color = .cyan,
            .map = spot(15),
            .door = &.{
                .{ .x = 156, .y = 160, .to = .frank_ride, .to_door = 1 },
                .{ .x = 16, .y = 160, .to = .mummy_storm },
            },
            .walkway = &.{ floor, upper_right },
            .ladder = &.{ladder_right},
            .bell = &.{.{ .x = 44, .y = 168, .door = 1 }},
            // The gun faces right, at the field. Its panel is upstairs.
            .forcefield = &.{.{ .button_x = 136, .button_y = 160, .field_x = 88, .field_y = 168 }},
            .ray_gun = &.{.{ .state = .{}, .x = 60, .y = 96, .length = 12, .gun_y = 171, .control_x = 120, .control_y = 104 }},
            .text = says("UNDER FIRE", &.{
                "THE FORCEFIELD IS",
                "YOUR SHIELD. TAKE",
                "IT DOWN AND THE",
                "GUN CAN HIT YOU. SO",
                "SEND THE GUN UP",
                "FIRST, THEN RUN!",
            }),
        },
        .mummy_storm = .{
            .color = .blue,
            .map = spot(16),
            // The mummy is out, on the floor. One machine runs by the way
            // out; the other, off, hangs under the switch upstairs, and the
            // switch flips them both.
            .door = &.{
                .{ .x = 156, .y = 96, .to = .under_fire, .to_door = 1 },
                .{ .x = 16, .y = 160, .to = .locked_away },
            },
            .walkway = &.{ floor, upper_right },
            .ladder = &.{.{ .length = 9, .x = 100, .y = 128 }},
            .bell = &.{.{ .x = 44, .y = 168, .door = 1 }},
            .lightning = &.{
                .{ .state = 0, .x = 124, .y = 136, .length = 3, .machines = .{ 0, 0, 0, 0 } },
                .{ .state = castle.lightning_on, .x = 64, .y = 112, .length = 6, .machines = .{ 0, 0, 0, 0 } },
                .{ .state = castle.lightning_switch, .x = 120, .y = 104, .length = 0, .machines = .{ 0, 8, 0xFF, 0xFF } },
            },
            .mummy = &.{.{ .state = castle.mummy_out, .ankh_x = 104, .ankh_y = 176, .tomb_x = 72, .tomb_y = 168, .x = 78, .y = 171 }},
            .text = says("MUMMY IN A STORM", &.{
                "THE MUMMY IS OUT,",
                "AND A STORM GUARDS",
                "THE DOOR. ONE THROW",
                "OF THE SWITCH MOVES",
                "THE LIGHTNING. WAIT",
                "FOR HIM TO COME",
                "UNDER YOU.",
            }),
        },
        .locked_away = .{
            .color = .pink,
            .map = spot(17),
            .door = &.{
                .{ .x = 156, .y = 160, .to = .mummy_storm, .to_door = 1 },
                .{ .x = 16, .y = 160, .to = .two_players },
            },
            .walkway = &.{ floor, upper_right },
            .pole = &.{.{ .length = 8, .x = 100, .y = 128 }}, // the way down
            .teleport = .{ .x = 128, .y = 160, .pads = &.{.{ .x = 136, .y = 120 }} }, // the way up
            .key = &.{key(.light_blue, 168, 112)},
            .lock = &.{lock(.light_blue, 1, 44, 168)},
            .text = says("LOCKED AWAY", &.{
                "THE KEY IS UP WHERE",
                "NO LADDER GOES. THE",
                "TRANSMITTER GOES",
                "EVERYWHERE.",
            }),
        },
        .two_players = .{
            .color = .light_green,
            .map = spot(18),
            .door = &.{
                .{ .x = 156, .y = 160, .to = .locked_away, .to_door = 1 },
                .{ .x = 16, .y = 160, .to = .way_out },
            },
            .walkway = &.{
                floor,
                .{ .length = 14, .x = 16, .y = 128 },
                .{ .length = 14, .x = 120, .y = 128 },
            },
            .ladder = &.{ ladder_left, .{ .length = 9, .x = 136, .y = 128 } },
            .bell = &.{.{ .x = 44, .y = 168, .door = 1 }},
            .text = says("TWO'S COMPANY", &.{
                "THIS ROOM NEEDS TWO",
                "EXPLORERS. ONE OF",
                "YOU WORKS THE",
                "SWITCH WHILE THE",
                "OTHER MAKES A RUN",
                "FOR IT.",
            }),
        },
        .way_out = .{
            .color = .yellow,
            .map = spot(19),
            .door = &.{
                .{ .x = 156, .y = 160, .to = .two_players, .to_door = 1 },
                .{ .x = 16, .y = 160, .to = .way_out, .exit = true },
            },
            .walkway = &.{floor},
            .bell = &.{.{ .x = 44, .y = 168, .door = 1 }},
            .text = says("THE WAY OUT", &.{
                "THROUGH THE GREEN",
                "DOOR LIES FREEDOM.",
                "RING ITS BELL, STEP",
                "IN, AND THE CLOCK",
                "STOPS. HOW FAST",
                "CAN YOU GET HERE?",
            }),
        },
    },
    .final = .{
        .walkway = &.{floor},
        .text = &.{
            .{ .x = 48, .y = 16, .color = .yellow, .height = 2, .words = "YOU ESCAPED!" },
            .{ .x = 20, .y = 148, .color = .light_grey, .words = "THE TRAINING CASTLE" },
            .{ .x = 56, .y = 160, .color = .light_grey, .words = "IS BEATEN." },
        },
        .image = &.{
            .{ .art = art.trophy, .at = &.{.{ .x = 88, .y = 80 }} },
            .{ .art = art.sparkle, .at = &.{
                .{ .x = 64, .y = 64 },
                .{ .x = 120, .y = 72 },
                .{ .x = 52, .y = 104 },
                .{ .x = 132, .y = 112 },
                .{ .x = 72, .y = 128 },
                .{ .x = 112, .y = 136 },
            } },
        },
    },
};

/// The castle file's bytes, built from the plan while the game compiles.
pub const bytes = author.build(Room, plan);
