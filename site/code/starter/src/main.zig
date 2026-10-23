//! Your game. The Comet 64 calls `boot` once when it powers on, then
//! `frame` fifty times a second, forever.

const machine = @import("machine");
const Machine = machine.Machine;

// Two VIDEO chip registers. Each holds a colour number (0-15).
const border_color = 0xD020;
const background_color = 0xD021;

pub fn boot(m: *Machine) void {
    m.poke(border_color, 4); // purple
    m.poke(background_color, 0); // black
}

pub fn frame(m: *Machine) void {
    _ = m;
}
