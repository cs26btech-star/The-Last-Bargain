# The Last Bargain

A top-down boss-rush for Godot 4. Four fights, one ring, and nothing you sell ever comes back.
Between fights you SELL parts of yourself (your health bar, your dodge, your own sprite, even the shrines) to the Storekeeper for coins, then spend the coins at the Demon or Angel beacon. Every deal changes the next fight.

Made for the Glitch member selection (Game Development).

## Themes
- **Contracts**: every beacon item is a bargain with a price, and from round 2 the Storekeeper demands rent before each fight. Boss prize money never covers it, so you must sell.
- **Chain Reactions (cause and effect)**: every deal and every sale changes the next fight. After each round the Storekeeper hands you a receipt that shows exactly what your choices caused.
- **Contagion**: demon bargains leave rot behind. Rot spreads from one interface piece to the next, makes it flicker and scramble, halves its sale price and eats it after two rounds. Wolves can infect you mid-fight.
- and ofc beacons are there quite helpfuleven 

## Controls
| Action | Key |
|---|---|
| Move | W A S D or arrow keys |
| Aim | Mouse |
| Attack | Left mouse button (hold to keep attacking), or J / K |
| Dodge roll | Space (you take no damage while rolling) |
| Pick weapon / use skill | 1 to 6 |
| Open a shrine's shop (preparation) | E near the beacon |
| Storekeeper's catalogue (sell things) | C |
| Start the fight | Enter |
| Pause | Esc |
| Fullscreen / window | F11 (the game starts in fullscreen) |
| Music check (if you hear no music) | F9 |

## Run it
1. Install Godot 4.2 or newer (standard version, not .NET).
2. Project Manager > Import > select `project.godot`.
3. Press F5. For the most reliable sound and fullscreen, run it as a separate game window (not the embedded editor view).



## Folders
- `scripts/game_data.gd` every number and text: stats, prices, bosses, credits.
- `scripts/` the rest of the code (`fight.gd` = the ring and the fights, `enemy.gd` = boss behaviour, `fx.gd` = particles and slashes).
- `art/` every picture the game uses, one file per spot (see `ASSET_LIST.txt`). `art_mine/` is checked first.
- `audio/` sound effects and music (see `AUDIO_README.txt`).

## Credits
- Engine: Godot (MIT licence).
- Font: EB Garamond (SIL Open Font License).
- Music, all CC0 from opengameart.org: *Dungeon Ambience* by yd, *Dark Cavern Ambient* by Paul Wortmann, *Boss Battle Music* by Juhani Junkala, *Chiptune Battle Music* by pmiller, *Boss Battle #2 [Symphonic Metal]* by nene.
- Sound effects: generated from sine waves and noise by `tools/make_sfx.py`.
- Artwork/audio compliance: review every included asset against the event brief before submission. The brief prohibits AI-generated or AI-assisted assets in the final product; remove any asset that does not comply. Keep a record of third-party asset licenses and credits.
- Development note: AI assistance was used during development. Describe the extent accurately if asked by the organizers.
well ifk godot code man first time gamedev so i had to do smt and cropping bruh its impossible im never getting this right  shouldve just done eerything on a black background instead bruh the game looks so weird if i had another day bruh .
