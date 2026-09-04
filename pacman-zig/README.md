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

The new controller currently provides Pac-Man input/movement and a basic
ghost chase loop using direct local EPICS database reads/writes. The map is a
bounded default waveform and may be overwritten through
`PACMAN:PACMAN_PLAY_FIELD`; porting the legacy maze literal, full ghost path
selection, PNG waveform handling, food, fruit, and game-engine state machine
remains follow-up work.
