extends Node
## Autoload "Game": the state of one playthrough plus all the rules.

signal coins_changed

var class_id: String = "swordmaster"
var username: String = "Hero"
var coins: int = 0
var round_index: int = 0
var stats: Dictionary = {}
var sold: Dictionary = {}
var sold_value: int = 0
var ring_steps_sold: int = 0
var inventory: Array = []
var selected_slot: int = 1
var round_side: String = ""
var last_side: String = ""
var self_mult: Dictionary = {}
var boss_mult: Dictionary = {}
var bought: Dictionary = {}
var infected: Dictionary = {}       # id -> rounds left before the rot eats it
var rot_points: int = 0             # demon deals this round; each leaves rot next round
var round_deals: Array = []         # [{name, side, price, you, boss}]
var round_sold: Array = []          # ["Timer +15", ...]
var round_events: Array = []        # rent, rot, ... for the receipt
var ledger: Array = []              # one plain line per round, shown on the ending screen
var sold_names: Array = []          # everything lost this run, for the ending


func _ready() -> void:
    _setup_inputs()
    _reset_round_state()


func _setup_inputs() -> void:
    var map: Dictionary = {
        "move_up": [KEY_W, KEY_UP],
        "move_down": [KEY_S, KEY_DOWN],
        "move_left": [KEY_A, KEY_LEFT],
        "move_right": [KEY_D, KEY_RIGHT],
        "roll": [KEY_SPACE],
    }
    for action in map:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
        for k in map[action]:
            var ev := InputEventKey.new()
            ev.physical_keycode = k
            InputMap.action_add_event(action, ev)


func _reset_round_state() -> void:
    self_mult = {"atk": 1.0, "hp": 1.0, "speed": 1.0}
    boss_mult = {"atk": 1.0, "hp": 1.0, "speed": 1.0}
    bought = {}
    round_side = ""


func class_data() -> Dictionary:
    return GameData.CLASSES[class_id]


# ---------------------------------------------------------------- run setup

func new_run(cls: String, uname: String) -> void:
    class_id = cls
    username = uname.strip_edges()
    if username == "":
        username = "Hero"
    coins = 0
    round_index = 0
    var c: Dictionary = GameData.CLASSES[cls]
    stats = {"atk": c["atk"], "hp": c["hp"], "speed": c["speed"], "mastery": c["mastery"]}
    sold = {}
    sold_value = 0
    ring_steps_sold = 0
    infected = {}
    rot_points = 0
    round_deals = []
    round_sold = []
    round_events = []
    ledger = []
    sold_names = []
    inventory = [
        {"kind": "hands", "name": "Fists"},
        make_weapon({"tier": "Wooden", "wmult": 1.0}, true),
        null, null, null, null,
    ]
    selected_slot = 1
    last_side = ""
    _reset_round_state()


func make_weapon(item: Dictionary, wooden: bool = false) -> Dictionary:
    var wt: String = GameData.CLASSES[class_id]["weapon"]
    var tier: String = item.get("tier", "Basic")
    return {
        "kind": "weapon",
        "wooden": wooden,
        "tier": tier,
        "name": "%s %s" % [tier, wt.capitalize()],
        "wtype": wt,
        "wmult": float(item.get("wmult", 1.0)),
        "dur": 100,
        "self": item.get("self", {}),
        "rule": item.get("rule", {}),
        "tint": GameData.TIER_COLORS.get(tier, "#ffffff"),
    }


func add_coins(n: int) -> void:
    coins += n
    coins_changed.emit()


func _gain(n: int) -> void:
    coins += n
    sold_value += n
    coins_changed.emit()


func finish_round() -> void:
    last_side = round_side
    var news: Array = _advance_rot()
    _reset_round_state()
    round_deals = []
    round_sold = []
    round_events = news        # rot news belongs to the NEXT round's receipt
    round_index += 1


# ---------------------------------------------------------------- inventory

func free_slot() -> int:
    for i in range(1, 6):
        if inventory[i] == null:
            return i
    return -1


func find_wooden() -> int:
    for i in inventory.size():
        var it = inventory[i]
        if it != null and it.get("wooden", false):
            return i
    return -1


func first_weapon_slot() -> int:
    for i in range(0, 6):
        if inventory[i] != null and inventory[i]["kind"] != "skill":
            return i
    return -1


# ---------------------------------------------------------------- selling

func is_sold(id: String) -> bool:
    return sold.has(id)


## Returns the coins gained (0 if nothing was sold).
func sell_simple(id: String) -> int:
    if is_sold(id):
        return 0
    var price: int = GameData.sell_price(id)
    if price < 0:
        return 0
    price = sell_price_now(id)
    if id == "wooden_weapon":
        var idx: int = find_wooden()
        if idx == -1:
            return 0
        inventory[idx] = null
        if selected_slot == idx:
            selected_slot = 0
    elif id == "bare_hands":
        if not GameData.BARE_HANDS_SELLABLE:
            return 0
        inventory[0] = null
        if selected_slot == 0:
            selected_slot = first_weapon_slot()
    sold[id] = true
    infected.erase(id)
    round_sold.append("%s  +%d" % [name_of(id), price])
    sold_names.append(name_of(id))
    _gain(price)
    return price


func stat_max_sell(stat: String) -> int:
    var floor_v: int = int(GameData.STAT_SELL[stat]["floor"])
    return maxi(0, int(stats[stat]) - floor_v)


func sell_stat(stat: String, n: int) -> int:
    n = clampi(n, 0, stat_max_sell(stat))
    if n <= 0:
        return 0
    stats[stat] = int(stats[stat]) - n
    var gained: int = n * int(GameData.STAT_SELL[stat]["price"])
    round_sold.append("%d point(s) of %s  +%d" % [n, GameData.STAT_NAMES[stat], gained])
    sold_names.append("%d %s" % [n, GameData.STAT_NAMES[stat]])
    _gain(gained)
    return gained


func ring_radius() -> float:
    var area: float = GameData.RING_AREA[ring_steps_sold]
    return GameData.RING_DIAMETER / 2.0 * sqrt(area)


## -1 when the ring cannot shrink any more.
func ring_next_price() -> int:
    if ring_steps_sold >= GameData.RING_STEP_PRICES.size():
        return -1
    return int(GameData.RING_STEP_PRICES[ring_steps_sold])


func sell_ring_step() -> int:
    var p: int = ring_next_price()
    if p < 0:
        return 0
    ring_steps_sold += 1
    round_sold.append("Ring space  +%d" % p)
    sold_names.append("ring space")
    _gain(p)
    return p


# ---------------------------------------------------------------- buying

func side_price_mult(side: String) -> float:
    var other: String = "angel" if side == "demon" else "demon"
    if last_side == other:
        return 1.2
    return 1.0


func item_price(side: String, item: Dictionary) -> int:
    return int(round(float(item["price"]) * side_price_mult(side)))


func display_name(item: Dictionary) -> String:
    if item["kind"] == "weapon":
        var wt: String = GameData.CLASSES[class_id]["weapon"]
        return "%s %s" % [item["tier"], wt.capitalize()]
    return str(item["name"])


func buy_block_reason(side: String, item: Dictionary) -> String:
    if is_sold("beacon_" + side):
        return "Beacon gone"
    if round_side != "" and round_side != side:
        return "You used the other beacon this round"
    if bought.has(item["id"]):
        return "Already bought"
    if coins < item_price(side, item):
        return "Not enough coins"
    if (item["kind"] == "weapon" or item["kind"] == "skill") and free_slot() == -1:
        return "Inventory full"
    return ""


func buy(side: String, item: Dictionary) -> bool:
    if buy_block_reason(side, item) != "":
        return false
    var paid: int = item_price(side, item)
    coins -= paid
    round_side = side
    bought[item["id"]] = true
    round_deals.append({"name": display_name(item), "side": side, "price": paid,
        "you": _you_text(item), "boss": _boss_text(item)})
    if side == "demon":
        rot_points += 1
    if item["kind"] == "weapon":
        # weapon effects are applied while it is equipped (see fight_mults)
        inventory[free_slot()] = make_weapon(item)
    else:
        if item["kind"] == "skill":
            inventory[free_slot()] = {"kind": "skill", "name": item["name"], "skill": item["skill"]}
        _apply_self(item.get("self", {}))
        _apply_rule(item.get("rule", {}))
    coins_changed.emit()
    return true


func _apply_self(d: Dictionary) -> void:
    for k in d:
        self_mult[k] = float(self_mult[k]) * float(d[k])


## The (1+x)/2 rule: a multiplier x on one stat changes the boss's other two stats.
func _apply_rule(r: Dictionary) -> void:
    if r.is_empty():
        return
    var f: float = (1.0 + float(r["x"])) / 2.0
    for s in ["atk", "hp", "speed"]:
        if s != r["stat"]:
            boss_mult[s] = float(boss_mult[s]) * f


func item_text(side: String, item: Dictionary) -> String:
    var lines: Array = [str(item["desc"])]
    var parts: Array = []
    if item["kind"] == "weapon":
        parts.append("Weapon: x%s damage" % str(item["wmult"]))
    var sf: Dictionary = item.get("self", {})
    for k in sf:
        parts.append("You: %s x%s" % [k, str(sf[k])])
    if side == "angel" or GameData.SHOW_BOSS_EFFECT_FOR_DEMON:
        var r: Dictionary = item.get("rule", {})
        if not r.is_empty():
            var f: float = (1.0 + float(r["x"])) / 2.0
            if not is_equal_approx(f, 1.0):
                var others: Array = []
                for s in ["atk", "hp", "speed"]:
                    if s != r["stat"]:
                        others.append(s)
                parts.append("Enemy: %s x%s" % [" & ".join(PackedStringArray(others)), str(snappedf(f, 0.01))])
    if not parts.is_empty():
        lines.append("  |  ".join(PackedStringArray(parts)))
    return "\n".join(PackedStringArray(lines))


# ---------------------------------------------------------------- fighting

## Multipliers for the coming fight: shop buffs plus the equipped weapon's effects.
func fight_mults() -> Dictionary:
    var sm: Dictionary = self_mult.duplicate()
    var bm: Dictionary = boss_mult.duplicate()
    if selected_slot >= 0:
        var w = inventory[selected_slot]
        if w != null and w["kind"] == "weapon":
            var ws: Dictionary = w["self"]
            for k in ws:
                sm[k] = float(sm[k]) * float(ws[k])
            var r: Dictionary = w["rule"]
            if not r.is_empty():
                var f: float = (1.0 + float(r["x"])) / 2.0
                for s in ["atk", "hp", "speed"]:
                    if s != r["stat"]:
                        bm[s] = float(bm[s]) * f
    return {"self": sm, "boss": bm}


func attack_cooldown(speed: float) -> float:
    return 0.78 * 10.0 / maxf(speed, 1.0)


## Damage of one hit. Own-class weapon: mastery/10. Other weapons: 60%. Fists: 100%.
func damage_per_hit(weapon, atk_mult: float) -> float:
    var atk: float = float(stats["atk"]) * atk_mult
    if weapon == null or weapon["kind"] != "weapon":
        return atk
    var cls_weapon: String = GameData.CLASSES[class_id]["weapon"]
    var factor: float = 0.6
    if weapon["wtype"] == cls_weapon:
        factor = float(stats["mastery"]) / 10.0
    return atk * float(weapon["wmult"]) * factor


# ---------------------------------------------------------------- Contracts: rent

func rent_due() -> int:
    if round_index >= GameData.RENT.size():
        return 0
    return int(GameData.RENT[round_index])


## Everything you could still turn into coins (so the Storekeeper can tell if you are broke for good).
func total_sellable_value() -> int:
    var t: int = 0
    for it in GameData.SELL_ITEMS:
        var id: String = it["id"]
        if is_sold(id):
            continue
        if id == "bare_hands" and not GameData.BARE_HANDS_SELLABLE:
            continue
        if id == "wooden_weapon" and find_wooden() == -1:
            continue
        t += sell_price_now(id)
    for s in ["atk", "hp", "speed", "mastery"]:
        t += stat_max_sell(s) * int(GameData.STAT_SELL[s]["price"])
    var steps: int = ring_steps_sold
    while steps < GameData.RING_STEP_PRICES.size():
        t += int(GameData.RING_STEP_PRICES[steps])
        steps += 1
    return t


## Called when the player presses START. True = the round may begin.
func pay_rent() -> bool:
    var rent: int = rent_due()
    if rent <= 0:
        return true
    if coins >= rent:
        coins -= rent
        coins_changed.emit()
        round_events.append("You paid the Storekeeper's rent: %d coins." % rent)
        return true
    if coins + total_sellable_value() < rent:
        round_events.append("You had nothing left to pay rent with. The Storekeeper forgave it.")
        return true
    return false


# ---------------------------------------------------------------- Contagion: rot

func name_of(id: String) -> String:
    for it in GameData.SELL_ITEMS:
        if it["id"] == id:
            return str(it["name"])
    return id


func sell_price_now(id: String) -> int:
    var p: int = GameData.sell_price(id)
    if p > 0 and infected.has(id):
        return maxi(1, int(round(float(p) * GameData.ROT_SELL_FACTOR)))
    return p


## Infects one random clean piece. Returns its id ("" if nothing is left to infect).
func infect_random(source: String = "") -> String:
    var pool: Array = []
    for id in GameData.INFECTABLE:
        if not is_sold(id) and not infected.has(id):
            pool.append(id)
    if pool.is_empty():
        return ""
    var pick: String = str(pool[randi() % pool.size()])
    infected[pick] = GameData.ROT_ROUNDS
    var why: String = " (a wolf bit you)" if source == "bite" else (" (it spread)" if source == "spread" else " (a demon deal left it behind)")
    round_events.append("ROT: %s is infected%s." % [name_of(pick), why])
    return pick


## End of a round: old rot is eaten, rot spreads, demon deals leave new rot.
func _advance_rot() -> Array:
    var start: int = round_events.size()
    for id in infected.keys():
        infected[id] = int(infected[id]) - 1
        if int(infected[id]) <= 0:
            infected.erase(id)
            if not is_sold(id):
                sold[id] = true
                sold_names.append(name_of(id) + " (eaten by rot)")
                round_events.append("ROT: %s was eaten by the rot and is gone for nothing." % name_of(id))
    for id in infected.keys():
        if randf() < GameData.ROT_SPREAD_CHANCE:
            infect_random("spread")
    var fresh: int = mini(rot_points, 2)
    for i in range(fresh):
        infect_random("deal")
    rot_points = 0
    var news: Array = round_events.slice(start)
    for e in news:
        ledger.append("Before round %d: %s" % [round_index + 2, e])
    return news


# ---------------------------------------------------------------- Cause and Effect: receipts

func _you_text(item: Dictionary) -> String:
    var parts: Array = []
    if item["kind"] == "weapon":
        parts.append("weapon x%s damage" % str(item["wmult"]))
    var sf: Dictionary = item.get("self", {})
    for k in sf:
        parts.append("your %s x%s" % [k, str(sf[k])])
    if item["kind"] == "skill":
        parts.append("one-use skill")
    if parts.is_empty():
        return "nothing special"
    return ", ".join(PackedStringArray(parts))


func _boss_text(item: Dictionary) -> String:
    var r: Dictionary = item.get("rule", {})
    if r.is_empty():
        return ""
    var f: float = (1.0 + float(r["x"])) / 2.0
    if is_equal_approx(f, 1.0):
        return ""
    var others: Array = []
    for s in ["atk", "hp", "speed"]:
        if s != r["stat"]:
            others.append(s)
    return "the enemy's %s x%s" % [" and ".join(PackedStringArray(others)), str(snappedf(f, 0.01))]


## BBCode text for the settlement screen. Call BEFORE finish_round().
func build_receipt(won: bool, boss_name: String) -> String:
    var L: Array = []
    var title: String = "ROUND %d  -  %s" % [round_index + 1, "VICTORY" if won else "YOU FELL"]
    L.append("[center][color=#e5c16a][b]%s[/b][/color]\n[color=#bdb0c9]%s[/color][/center]\n" % [title, boss_name])
    L.append("[color=#e66a79][b]DEALS YOU SIGNED[/b][/color]")
    if round_deals.is_empty():
        L.append("  none. You trusted nobody.")
    for d in round_deals:
        var line: String = "  - %s (%s, %d coins): you got %s." % [d["name"], d["side"], d["price"], d["you"]]
        if str(d["boss"]) != "":
            line += "  [color=#ff8a8a]Cost: %s.[/color]" % d["boss"]
        L.append(line)
    var bm: Dictionary = boss_mult
    var worse: Array = []
    for k in ["atk", "hp", "speed"]:
        if not is_equal_approx(float(bm[k]), 1.0):
            worse.append("%s x%s" % [k.to_upper(), str(snappedf(float(bm[k]), 0.01))])
    if not worse.is_empty():
        L.append("  [color=#ffb36b]CAUSE AND EFFECT: because of your deals, %s fought with %s.[/color]" % [boss_name, ", ".join(PackedStringArray(worse))])
    L.append("\n[color=#e66a79][b]WHAT YOU SOLD THIS ROUND[/b][/color]")
    if round_sold.is_empty():
        L.append("  nothing yet.")
    for s in round_sold:
        L.append("  - %s" % s)
    var lost: Array = []
    for id in sold:
        if GameData.SOLD_CONSEQUENCE.has(id):
            lost.append(str(GameData.SOLD_CONSEQUENCE[id]))
    if not lost.is_empty():
        L.append("  [color=#ffb36b]CAUSE AND EFFECT:[/color] " + "  ".join(PackedStringArray(lost)))
    if not round_events.is_empty():
        L.append("\n[color=#9be15d][b]RENT AND ROT[/b][/color]")
        for e in round_events:
            L.append("  - %s" % e)
    if not infected.is_empty():
        var names: Array = []
        for id in infected:
            names.append("%s (%d round(s) left)" % [name_of(id), int(infected[id])])
        L.append("  [color=#9be15d]Still rotting: %s. Sell them before the rot eats them.[/color]" % ", ".join(PackedStringArray(names)))
    # plain one-line summary for the final ledger
    var summary: String = "Round %d (%s): signed %d deal(s), sold %d thing(s)" % [round_index + 1, "won" if won else "lost", round_deals.size(), round_sold.size()]
    if not worse.is_empty():
        summary += ", the boss got " + ", ".join(PackedStringArray(worse))
    ledger.append(summary + ".")
    return "\n".join(PackedStringArray(L))


## Short list of everything lost, for the ending screen.
func lost_summary() -> String:
    if sold_names.is_empty():
        return "You kept everything."
    return ", ".join(PackedStringArray(sold_names))
