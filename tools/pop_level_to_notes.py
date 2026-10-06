#!/usr/bin/env python3
"""
One-way study extractor for SDLPoP 1.23 level files.

Purpose: parse the unpacked room-level structs under
SDLPoP-1.23/data/LEVELS/res20NN.bin and emit *study notes*, not game data.

This is for behavioral study only (plan section 2.3):
- It helps a human understand the original room grammar.
- It does NOT produce playable level data for Echoes of Time.
- It does NOT copy any sprite/audio/text/level layout into the project.

Output goes into untracked study/ only. It must never be committed as game data.
"""

import struct
import sys
from pathlib import Path

# SDLPoP 1.23 level_type layout (measured from the port, not ported).
# sizeof(level_type) == 2305 per the port's compile-time assert.
# Offsets below are the author's reading of that layout; they are structural facts
# about the unpack format, cited here as the unpack spec so the tool can be audited.


class LevelType:
    """Parsed view of one res20NN.bin file."""

    LEVEL_SIZE = 2305

    @classmethod
    def from_bytes(cls, data: bytes) -> "LevelType":
        if len(data) not in (2304, 2305):
            raise ValueError(f"Unexpected length {len(data)}; expected 2304 or 2305")
        return cls(data)

    def __init__(self, data: bytes) -> None:
        self._data = data

    def fg(self, room: int, tile: int) -> int:
        if not (0 <= room < 24 and 0 <= tile < 30):
            raise ValueError("room/tile out of range")
        return self._data[room * 30 + tile]

    def bg(self, room: int, tile: int) -> int:
        if not (0 <= room < 24 and 0 <= tile < 30):
            raise ValueError("room/tile out of range")
        return self._data[720 + room * 30 + tile]

    def roomlinks(self, room: int) -> tuple:
        if not (0 <= room < 24):
            raise ValueError("room out of range")
        base = 1696 + room * 4
        left = self._data[base]
        right = self._data[base + 1]
        up = self._data[base + 2]
        down = self._data[base + 3]
        return (left, right, up, down)

    def used_rooms(self) -> int:
        return self._data[1696 - 4]

    # Start-of-level / guard fields are near the end of the struct.
    # The exact offsets for those are left as a citation target, not exposed as
    # gameplay data here, because they are not needed for the study overlay.

    def level_rooms(self) -> list:
        """Return the ordered rows of tiles (tiletype only) for used rooms."""
        used = min(self.used_rooms(), 24)
        rooms = []
        for r in range(used):
            row = []
            for t in range(30):
                row.append(self.fg(r, t))
            rooms.append(row)
        return rooms


TILE_NAMES = {
    0: "empty",
    1: "floor",
    2: "spike",
    3: "pillar",
    4: "gate",
    5: "drop_button",
    6: "tapestry_bottom",
    7: "potion",
    8: "bigpillar_bottom",
    9: "bigpillar_top",
    10: "unknown_10",
    11: "loose_floor",
    12: "tapestry_top",
    13: "mirror",
    14: "debris",
    15: "raise_button",
    16: "exit_door_left",
    17: "exit_door_right",
    18: "chomper",
    19: "torch",
    20: "wall",
    21: "skeleton",
    22: "sword",
    23: "balcony_left",
    24: "balcony_right",
    25: "lattice_pillar",
    26: "lattice_down",
    27: "lattice_small",
    28: "lattice_left",
    29: "lattice_right",
    30: "torch_with_debris",
}


def tile_label(t: int) -> str:
    return TILE_NAMES.get(t, f"tile_{t}")


def room_lines(rooms: list) -> list:
    out = []
    for r, row in enumerate(rooms):
        nums = " ".join(f"{t:2d}" for t in row)
        labels = " ".join(tile_label(t)[:8].ljust(8) for t in row)
        out.append(f"room {r:2d} | cols 0..9 (tile id per col) | {nums}")
        out.append(f"         | {labels}")
        out.append("")
    return out


def write_study_page(index: int, level: LevelType, path: Path) -> None:
    used = level.used_rooms()
    lines = [f"# study/level_{index:02d}.txt — SDLPoP 1.23 level {index:02d} (res20{index:02d}.bin)\n"]
    lines.append("# Study note only. Not playable level data. Not for commit as game data.\n")
    lines.append(f"# Unpack size: {len(level._data)} bytes (level_type == 2305 in SDLPoP).\n")
    lines.append(f"# Used rooms: {used}\n\n")

    # Room grid: 10 cols x 3 rows per room, fg tile ids.
    rooms = level.level_rooms()
    lines.append(f"## Room tiles (10 cols x 3 rows, 24 rooms max, {used} used)\n\n")
    for r in range(used):
        rows = []
        for row in range(3):
            row_tiles = [level.fg(r, col) for col in range(10)]
            rows.append(" ".join(f"{t:2d}" for t in row_tiles))
        labels = " ".join(tile_label(level.fg(r, c))[:10] for c in range(10))
        lines.append(f"room {r:2d} fg:")
        for row in rows:
            lines.append(f"   {row}")
        lines.append(f"   labels: {labels}\n")
    lines.append("")

    # Modifiers (bg) for the first used room, so a human can see the difference
    # between floor and button/spike/loose states.
    lines.append(f"## Modifier bytes (bg) for room 0 (study sample)\n\n")
    for row in range(3):
        row_tiles = [level.bg(0, col) for col in range(10)]
        lines.append("   " + " ".join(f"{t:2d}" for t in row_tiles))
    lines.append("")
    lines.append("# bg interpretation is position-dependent (floor / button / spike / loose).\n")
    lines.append("# See SDLPoP src for the exact rules; this file lists the raw bytes only.\n\n")

    # Room links.
    lines.append("## Room links (left right up down) per room\n\n")
    for r in range(used):
        l, ri, u, d = level.roomlinks(r)
        lines.append(f"room {r:2d}: left={l} right={ri} up={u} down={d}\n")
    lines.append("# 0 means no link in that direction.\n")

    path.write_text("".join(lines))


def main(argv: list[str]) -> int:
    if len(argv) < 4:
        print("Usage: pop_level_to_notes.py <SDLPoP_dir> <res_2000..2015> first_index", file=sys.stderr)
        return 2

    sdlpop_dir = Path(argv[1])
    levels_dir = sdlpop_dir / "data" / "LEVELS"
    if not levels_dir.is_dir():
        print(f"Not a level directory: {levels_dir}", file=sys.stderr)
        return 1

    first_index = int(argv[3])
    out_dir = Path("study")
    out_dir.mkdir(exist_ok=True)

    for i in range(16):
        path = levels_dir / f"res20{i:02d}.bin"
        if not path.exists():
            continue
        data = path.read_bytes()
        level = LevelType.from_bytes(data)
        write_study_page(first_index + i, level, out_dir / f"level_{first_index + i:02d}.txt")
        print(f"wrote study/level_{first_index + i:02d}.txt")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
