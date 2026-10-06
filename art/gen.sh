#!/bin/zsh
# Generates the biome backgrounds with Codex image generation (run once; outputs are committed).
cd "$(dirname "$0")"
STYLE="chunky low-resolution pixel art, limited muted palette with dithering, cozy RPG world-map feel, soft top-down-ish landscape. Square 1024x1024. No text, no UI, no characters, no logos. Keep the upper-left and center area calm and low-contrast so white text can be placed on top; put detail near the edges and bottom. Original artwork."
gen() { codex exec --skip-git-repo-check "just with image generation ( nothing else ). Generate ONE image and save/copy the final PNG to exactly this path: $PWD/raw-$1.png . Subject: $2. Style: $STYLE" > "codex-$1.log" 2>&1 & }
gen meadow "A sunny grassy meadow with winding dirt path, wildflowers, a small stone bridge and a tiny village roof in the distance"
gen forest "A dense pixel-art forest with tall pines and oaks, mossy ground, a campfire clearing and fireflies"
gen coast "A harbor coastline: teal sea with little pixel wave marks, wooden docks, a small sailboat, sandy shore"
gen mountain "Snowy mountain pass with frosty pines, icy blue rocks, a winding trail and a distant peak"
gen desert "Warm desert canyon with sand dunes, red rock mesas, cacti and a distant oasis"
wait
