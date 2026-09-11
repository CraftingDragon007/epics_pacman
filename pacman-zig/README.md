# Zig Pacman IOC

This is an embedded EPICS Base IOC implemented in Zig. It loads the existing
record definitions from `../pacman-softIoc` so that the SNL IOC and the Zig
IOC share the same PV names, but it does not load or link the State Notation
Language module.

```sh
cd pacman-zig
zig build run
```

## Configuring EPICS Base

Pass the EPICS Base location and host architecture as Zig build options:

```sh
zig build run -Depics-base=/opt/epics/base-7.0.9 -Depics-host-arch=linux-x86_64
```

If your shell already defines the usual EPICS variables, pass them through
directly:

```sh
zig build run -Depics-base="$EPICS_BASE" -Depics-host-arch="$EPICS_HOST_ARCH"
```

The executable receives the selected Base path at compile time, so it loads
the matching `dbd/base.dbd` at runtime too. This replaces the previous
`/usr/lib/epics` hard-code.

EPICS Base normally generates `softIoc_registerRecordDeviceDriver.cpp` in its
source/build tree. If it is not located at
`$EPICS_BASE/modules/database/src/std/O.$EPICS_HOST_ARCH/`, point the build at
it explicitly:

```sh
zig build run \
  -Depics-base=/opt/epics/base-7.0.9 \
  -Depics-host-arch=linux-x86_64 \
  -Depics-registrar=/opt/epics/base-7.0.9/modules/database/src/std/O.linux-x86_64/softIoc_registerRecordDeviceDriver.cpp
```

The default remains `/usr/lib/epics` and its matching registrar source. Only
one IOC using the `PACMAN` prefix and CA server port may run at a time.

The controller provides Pac-Man input/movement and a modular, tile-based ghost
AI using direct local EPICS database reads/writes. Blinky, Pinky, Inky, and
Clyde have distinct classic-inspired targets, with house release,
scatter/chase cycles, frightened movement, return-home routing, portals, and
directional animation. The canonical maze is published to
`PACMAN:PACMAN_PLAY_FIELD` on startup.

PNG waveform handling, food/fruit presentation, collision/life handling, and
level-specific arcade timing remain follow-up work.
