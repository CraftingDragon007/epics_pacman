# Zig Pacman IOC

This is an embedded EPICS Base IOC implemented in Zig. It loads the existing
record definitions from `../pacman-softIoc` so that the SNL IOC and the Zig
IOC share the same PV names, but it does not load or link the State Notation
Language module.

```sh
cd pacman-zig
zig build run
```

The current build targets the installed EPICS Base 7 package at
`/usr/lib/epics`; its generated standard-record registrar is compiled from
the package's matching debug source. This is necessary because the distro does
not ship that registrar in a linkable library. Only one IOC using the `PACMAN`
prefix and CA server port may run at a time.

The controller provides Pac-Man input/movement and a modular, tile-based ghost
AI using direct local EPICS database reads/writes. Blinky, Pinky, Inky, and
Clyde have distinct classic-inspired targets, with house release,
scatter/chase cycles, frightened movement, return-home routing, portals, and
directional animation. The canonical maze is published to
`PACMAN:PACMAN_PLAY_FIELD` on startup.

PNG waveform handling, food/fruit presentation, collision/life handling, and
level-specific arcade timing remain follow-up work.
