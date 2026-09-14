# Migration reference

Frozen JavaScript inputs used for the full Godot port, captured from the original working tree including its pending gameplay/magic edits. These files support balance/map parity and offline effect baking; the Godot game never loads them. Keeping the inputs here makes regeneration work from a clean checkout without committing changes to the root prototype.

The import tools use this snapshot by default. Pass `--current-source` to read `js/` instead when intentionally bringing further prototype changes across. Original high-resolution art remains under the repository's `assets/art/` paths.
