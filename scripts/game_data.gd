class_name GameData
extends RefCounted
## Every number and text of the game lives here. Tune freely.

const TITLE = "THE LAST BARGAIN"
const INTRO = "Four fights. One ring.\nSell anything you own for coins.\nSpend them at the Demon and Angel beacons.\nBut nothing you sell ever comes back..."
const CREDITS = "Made by ^_^"
# Shown on the Info screen. Keep one line for every music track you really use (see audio/MUSIC_SHOPPING_LIST.txt).
const MUSIC_CREDITS = "Music (all CC0, from opengameart.org):\n  Dungeon Ambience by yd (title and menus)\n  Dark Cavern Ambient by Paul Wortmann (preparation)\n  Boss Battle Music by Juhani Junkala (Bouncer and Wolves)\n  Chiptune Battle Music by pmiller (Pickpocket)\n  Boss Battle #2 [lb]Symphonic Metal[rb] by nene (Storekeeper)"

const SCREEN = Vector2(1280, 720)
const RING_CENTER = Vector2(640, 385)
const RING_DIAMETER = 630.0
const RING_AREA = [1.0, 0.85, 0.70, 0.55, 0.40, 0.25]
const RING_STEP_PRICES = [20, 25, 30, 35, 40]
const SPEED_PX = 15.0
const BARE_HANDS_SELLABLE = false
const SHOW_BOSS_EFFECT_FOR_DEMON = false
const BOSS_DROPS = [80, 120, 160, 0]

# ---- the three themes (shown on the title and Info screens)
const THEMES_LINE = "Contracts   ·   Cause and Effect   ·   Contagion"

# ---- difficulty. Bosses get tougher each round so "just rolling around" stops working.
# Index = round (0..3). 1.0 = unchanged. DIFFICULTY scales the whole thing: 0 = old game, 1 = default, 1.5 = brutal.
const DIFFICULTY = 1.0
const ROUND_HP_SCALE = [1.0, 1.6, 1.5, 1.3]
const ROUND_ATK_SCALE = [1.0, 2.2, 1.35, 1.5]
# At half health every boss ENRAGES (more damage, faster attacks, a new trick).

# ---- Contracts: the Storekeeper's RENT, due when you press START. Boss drops are 80/120/160,
# so from round 2 you cannot pay it without SELLING something.
const RENT = [0, 110, 160, 220]

# ---- Contagion: demon deals leave ROT. Rotten UI pieces flicker, sell for half, and are eaten
# for nothing after ROT_ROUNDS rounds. Rot spreads, and wolf bites infect you mid-fight.
const ROT_ROUNDS = 2
const ROT_SPREAD_CHANCE = 0.5
const ROT_SELL_FACTOR = 0.5
const WOLF_INFECT_CHANCE = 0.35
const INFECTABLE = ["hud_hp_bar", "hud_enemy_bar", "hud_timer", "hud_name_player", "hud_name_enemy", "hud_coins", "hud_inventory", "char_sprite"]

# What losing each thing actually did to you (shown on the settlement receipt).
const SOLD_CONSEQUENCE = {
    "hud_hp_bar": "You could not see your own health.",
    "hud_enemy_bar": "You could not see how hurt the enemy was.",
    "hud_timer": "You lost track of time.",
    "hud_name_player": "Nobody knew your name.",
    "hud_name_enemy": "The enemy had no name.",
    "hud_coins": "You could not count your coins.",
    "hud_inventory": "You could not use skills or switch weapons.",
    "char_sprite": "You fought as a white box.",
    "dodge": "You could no longer roll.",
    "wooden_weapon": "You gave away your starter weapon.",
    "bare_hands": "You gave away your hands.",
    "beacon_angel": "The Archangel's beacon is gone forever.",
    "beacon_demon": "The Demon King's beacon is gone forever.",
}

const CLASSES = {
    "swordmaster": {
        "name": "Swordmaster", "atk": 11, "hp": 10, "speed": 11, "mastery": 11,
        "weapon": "sword", "reach": 1.2, "arc": 60.0, "color": "#4d80ff",
        "blurb": "Balanced and deadly with a sword.",
    },
    "spearman": {
        "name": "Spearman", "atk": 14, "hp": 10, "speed": 9, "mastery": 11,
        "weapon": "spear", "reach": 2.0, "arc": 25.0, "color": "#4dcc66",
        "blurb": "Hits hard from far away, but slow.",
    },
    "assassin": {
        "name": "Assassin", "atk": 10, "hp": 10, "speed": 14, "mastery": 10,
        "weapon": "dagger", "reach": 0.8, "arc": 45.0, "color": "#b34dcc",
        "blurb": "Very fast, but short reach and low mastery.",
    },
}

const STAT_NAMES = {"atk": "Attack", "hp": "Health", "speed": "Speed", "mastery": "Mastery"}

# price per point sold, and the lowest value you can sell down to
const STAT_SELL = {
    "atk": {"price": 15, "floor": 1},
    "hp": {"price": 12, "floor": 1},
    "speed": {"price": 10, "floor": 1},
    "mastery": {"price": 15, "floor": 6},
}

const SELL_ITEMS = [
    {"id": "hud_hp_bar", "name": "Your HP bar", "price": 50, "group": "HUD"},
    {"id": "hud_enemy_bar", "name": "Enemy HP bar", "price": 40, "group": "HUD"},
    {"id": "hud_timer", "name": "Timer", "price": 15, "group": "HUD"},
    {"id": "hud_name_player", "name": "Your name plate", "price": 10, "group": "HUD"},
    {"id": "hud_name_enemy", "name": "Enemy name plate", "price": 10, "group": "HUD"},
    {"id": "hud_coins", "name": "Coin counter", "price": 25, "group": "HUD"},
    {"id": "hud_inventory", "name": "Inventory bar", "price": 30, "group": "HUD"},
    {"id": "char_sprite", "name": "Your character sprite", "price": 40, "group": "Character"},
    {"id": "dodge", "name": "Dodge roll", "price": 80, "group": "Character"},
    {"id": "wooden_weapon", "name": "Wooden weapon", "price": 30, "group": "Character"},
    {"id": "bare_hands", "name": "Bare hands", "price": 50, "group": "Character"},
    {"id": "beacon_angel", "name": "Angel beacon (and its shop)", "price": 150, "group": "Beacons"},
    {"id": "beacon_demon", "name": "Demon beacon (and its shop)", "price": 250, "group": "Beacons"},
]

# Item fields:
#  kind: weapon / buff / skill
#  wmult: weapon atk multiplier
#  self: multipliers on YOUR stats
#  rule: {"stat": s, "x": x} -> the boss's OTHER two stats become (1+x)/2 times
const DEMON_ITEMS = [
    {"id": "d_basic", "kind": "weapon", "tier": "Basic", "wmult": 1.0, "price": 20,
        "desc": "A plain weapon. Cheap, honest.", "rule": {"stat": "atk", "x": 1.0}},
    {"id": "d_iron", "kind": "weapon", "tier": "Iron", "wmult": 3.0, "price": 120,
        "desc": "Triple the damage. What could go wrong?", "rule": {"stat": "atk", "x": 3.0}},
    {"id": "d_demonic", "kind": "weapon", "tier": "Demonic", "wmult": 5.0, "price": 260,
        "desc": "Forged in the pit. Five times the damage.", "rule": {"stat": "atk", "x": 5.0}},
    {"id": "d_king", "kind": "weapon", "tier": "Demon King's", "wmult": 7.0, "price": 400,
        "desc": "The strongest blade in existence.", "rule": {"stat": "atk", "x": 7.0}},
    {"id": "d_swift", "kind": "buff", "name": "Swift Potion", "price": 60,
        "desc": "Move and strike faster this round.",
        "self": {"speed": 1.5}, "rule": {"stat": "speed", "x": 1.5}},
    {"id": "d_vital", "kind": "buff", "name": "Vitality Potion", "price": 70,
        "desc": "Double your health this round.",
        "self": {"hp": 2.0}, "rule": {"stat": "hp", "x": 2.0}},
    {"id": "d_attack", "kind": "buff", "name": "Attack Potion", "price": 80,
        "desc": "Double your attack this round.",
        "self": {"atk": 2.0}, "rule": {"stat": "atk", "x": 2.0}},
    {"id": "d_hellfire", "kind": "skill", "skill": "hellfire", "icon": "icon_flame", "name": "Hellfire", "price": 90,
        "desc": "One-time use. Burns an enemy for 60 damage.",
        "rule": {"stat": "atk", "x": 1.2}},
    {"id": "d_suppress", "kind": "skill", "skill": "suppress", "icon": "icon_crown", "name": "Demon King's Suppression", "price": 140,
        "desc": "One-time use. Slows every enemy for 5 seconds.",
        "rule": {"stat": "atk", "x": 1.2}},
    {"id": "d_judgement", "kind": "skill", "skill": "fake", "icon": "icon_gavel", "name": "Devil's Judgement", "price": 250,
        "desc": "One-time use. The Devil himself judges your enemy. UNBELIEVABLE POWER!!",
        "rule": {"stat": "atk", "x": 1.2}},
    {"id": "d_ultimate", "kind": "skill", "skill": "fake", "icon": "icon_skull", "name": "Devil's Ultimate", "price": 350,
        "desc": "One-time use. Ends the fight. Probably.",
        "rule": {"stat": "atk", "x": 1.2}},
]

const ANGEL_ITEMS = [
    {"id": "a_basic", "kind": "weapon", "tier": "Basic", "wmult": 1.0, "price": 20,
        "desc": "A plain weapon, blessed by nobody.", "rule": {"stat": "atk", "x": 1.0}},
    {"id": "a_iron", "kind": "weapon", "tier": "Iron", "wmult": 1.5, "price": 100,
        "desc": "Heavy iron. Slows you, weakens the enemy.",
        "self": {"speed": 0.7}, "rule": {"stat": "speed", "x": 0.7}},
    {"id": "a_holy", "kind": "weapon", "tier": "Holy", "wmult": 2.0, "price": 200,
        "desc": "A holy weapon. Costs you some health.",
        "self": {"hp": 0.7}, "rule": {"stat": "hp", "x": 0.7}},
    {"id": "a_arch", "kind": "weapon", "tier": "Archangel's", "wmult": 2.5, "price": 320,
        "desc": "The Archangel's blade. Heavy burden.",
        "self": {"speed": 0.5}, "rule": {"stat": "speed", "x": 0.5}},
    {"id": "a_weak", "kind": "buff", "name": "Contract of Weakness", "price": 50,
        "desc": "Both of you grow weaker.",
        "self": {"atk": 0.7}, "rule": {"stat": "atk", "x": 0.7}},
    {"id": "a_frail", "kind": "buff", "name": "Contract of Frailty", "price": 50,
        "desc": "Both of you grow frail.",
        "self": {"hp": 0.7}, "rule": {"stat": "hp", "x": 0.7}},
    {"id": "a_slow", "kind": "buff", "name": "Contract of Slowness", "price": 50,
        "desc": "Both of you slow down.",
        "self": {"speed": 0.7}, "rule": {"stat": "speed", "x": 0.7}},
    {"id": "a_blessing", "kind": "skill", "skill": "blessing", "icon": "icon_halo", "name": "Holy Blessing", "price": 80,
        "desc": "One-time use. Heals 50 HP.",
        "self": {"speed": 0.9}, "rule": {"stat": "speed", "x": 0.9}},
    {"id": "a_protect", "kind": "skill", "skill": "protect", "icon": "icon_shield", "name": "Angel's Protection", "price": 100,
        "desc": "One-time use. Blocks the next hit.",
        "self": {"speed": 0.9}, "rule": {"stat": "speed", "x": 0.9}},
    {"id": "a_judgement", "kind": "skill", "skill": "judgement", "icon": "icon_gavel", "name": "Holy Judgement", "price": 150,
        "desc": "One-time use. 80 damage to an enemy.",
        "self": {"speed": 0.9}, "rule": {"stat": "speed", "x": 0.9}},
    {"id": "a_ultimate", "kind": "skill", "skill": "ultimate", "icon": "icon_wing", "name": "Angel's Ultimate", "price": 300,
        "desc": "One-time use. 150 damage to an enemy.",
        "self": {"speed": 0.9}, "rule": {"stat": "speed", "x": 0.9}},
]

const TIER_COLORS = {
    "Wooden": "#8b5a2b", "Basic": "#b0b0b0", "Iron": "#d0d4da", "Demonic": "#c0262d",
    "Demon King's": "#6a1b9a", "Holy": "#e6c200", "Archangel's": "#ffffff",
}

# Boss stats. hp/atk/speed are base values before any multipliers.
const BOSSES = [
    # Cooldowns are seconds before the enemy can begin chasing/attacking again.
    # Longer windups also give the player a fairer dodge window.
    {"id": "bouncer", "name": "THE BOUNCER", "count": 1, "hp": 125.0, "atk": 19.0, "speed": 9.5,
        "radius": 50.0, "w": 128.0, "h": 128.0, "art": "boss_bouncer", "color": "#c0392b", "tint": "#ffffff",
        "windup": 0.95, "range": 100.0, "cd": 2.25},
    {"id": "wolf", "name": "THE HUNGRY PACK", "count": 5, "hp": 34.0, "atk": 6.0, "speed": 15.5,
        "radius": 24.0, "w": 64.0, "h": 48.0, "art": "boss_wolf", "color": "#7f8c8d", "tint": "#ffffff",
        "windup": 0.68, "range": 140.0, "cd": 2.15},
    {"id": "pickpocket", "name": "THE PICKPOCKET", "count": 1, "hp": 190.0, "atk": 27.0, "speed": 17.0,
        "radius": 26.0, "w": 64.0, "h": 64.0, "art": "boss_pickpocket", "color": "#2c2c34", "tint": "#555566",
        "windup": 0.82, "range": 75.0, "cd": 2.5},
    {"id": "storekeeper", "name": "THE STOREKEEPER", "count": 1, "hp": 255.0, "atk": 19.0, "speed": 10.5,
        "radius": 50.0, "w": 128.0, "h": 128.0, "art": "boss_storekeeper", "color": "#d4a017", "tint": "#ffffff",
        "windup": 0.72, "range": 100.0, "cd": 1.85},
]


static func sell_price(id: String) -> int:
    for it in SELL_ITEMS:
        if it["id"] == id:
            return int(it["price"])
    return -1
