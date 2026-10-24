extends Control
## Opens over the ring. mode: "sell" (the Storekeeper's catalogue), "demon" or "angel".
## Demon + catalogue = purple and gold. Angel = white and gold. Same frames for all.

signal closed
signal changed

var mode: String = "sell"
var look: String = "demon"
var colors: Dictionary = {}
var list_box: VBoxContainer
var coins_label: Label
var msg_label: Label
var stat_n: Dictionary = {"atk": 1, "hp": 1, "speed": 1, "mastery": 1}


func _ready() -> void:
    look = "angel" if mode == "angel" else "demon"
    colors = UiSkin.colors(look)
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.72)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(dim)
    # The catalogue is a utility screen, not a character shop. Keep the Angel
    # and Demon portraits in their own beacon windows, but remove the old
    # hooded SHOPKEEPER placeholder from the catalogue entirely.
    if mode != "sell":
        var fig: Control = UiSkin.figure(_figure_slot(), look, Vector2(380, 380))
        fig.position = Vector2(30, 200)
        add_child(fig)
    var frame: Control = UiSkin.frame(look, Vector2(800, 610), _panel_slot())
    frame.position = Vector2(240 if mode == "sell" else 430, 55)
    add_child(frame)

    var title_text: String = "THE STOREKEEPER'S CATALOGUE"
    if mode == "demon":
        title_text = "DEMON BEACON"
    elif mode == "angel":
        title_text = "ANGEL BEACON"
    var title := _lbl(title_text, 32, colors["accent"])
    title.position = Vector2(44, 34)
    frame.add_child(title)
    coins_label = _lbl("", 26, colors["text"])
    coins_label.position = Vector2(580, 38)
    frame.add_child(coins_label)
    msg_label = _lbl(" ", 16, colors["sub"])
    msg_label.position = Vector2(44, 82)
    frame.add_child(msg_label)

    var scroll := ScrollContainer.new()
    scroll.position = Vector2(40, 112)
    scroll.size = Vector2(720, 410)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    frame.add_child(scroll)
    list_box = VBoxContainer.new()
    list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list_box.add_theme_constant_override("separation", 10)
    scroll.add_child(list_box)

    var close := _btn("CLOSE  [E]", func(): closed.emit(), 22)
    close.position = Vector2(300, 540)
    close.size = Vector2(200, 46)
    frame.add_child(close)
    rebuild()


func _panel_slot() -> String:
    # Each window has its own frame picture: ui_panel_demon / ui_panel_angel / ui_panel_catalogue
    return "catalogue" if mode == "sell" else mode


func _figure_slot() -> String:
    # figure_shop_demon / figure_shop_angel / figure_catalogue (placeholders until you draw them)
    if mode == "angel":
        return "figure_shop_angel"
    if mode == "demon":
        return "figure_shop_demon"
    return "figure_catalogue"


func _lbl(text: String, size: int = 18, col: Color = Color.WHITE) -> Label:
    return UI.label(text, size, col)


func _btn(text: String, cb: Callable, size: int = 18) -> Button:
    var b := UI.button(text, cb, size)
    UiSkin.style_button(b, look, "shop_catalogue" if mode == "sell" else "shop_" + mode)
    return b


func _say(text: String) -> void:
    msg_label.text = text


func _changed() -> void:
    changed.emit()
    rebuild()


func rebuild() -> void:
    coins_label.text = "Coins: %d" % Game.coins
    UI.clear(list_box)
    if mode == "sell":
        _build_sell()
    elif mode == "demon":
        _build_side("demon", GameData.DEMON_ITEMS)
    else:
        _build_side("angel", GameData.ANGEL_ITEMS)


# ---------------------------------------------------------------- catalogue (sell)

func _build_sell() -> void:
    if Game.round_index >= 1:
        list_box.add_child(UI.wrap(_lbl("Everything you sold is GONE FOREVER.", 16, Color(0.85, 0.2, 0.2))))
    _group("HUD")
    _group("Character")
    _stats_section()
    _ring_section()
    _group("Beacons")


func _header(text: String) -> void:
    list_box.add_child(_lbl(text, 18, colors["accent"]))


func _group(group: String) -> void:
    _header(group.to_upper())
    for it in GameData.SELL_ITEMS:
        if it["group"] == group:
            _sell_row(it)


func _sell_row(it: Dictionary) -> void:
    var id: String = it["id"]
    var price: int = Game.sell_price_now(id)
    if id == "bare_hands" and not GameData.BARE_HANDS_SELLABLE:
        return
    if Game.is_sold(id):
        if Game.round_index >= 1:
            list_box.add_child(_lbl("%s - SOLD, gone forever" % it["name"], 15, colors["sub"]))
        return
    if id == "wooden_weapon" and Game.find_wooden() == -1:
        return
    var row := HBoxContainer.new()
    var rotten: bool = Game.infected.has(id)
    var name_l := _lbl(str(it["name"]) + ("   [ROTTING: %d round(s) left, half price]" % int(Game.infected[id]) if rotten else ""), 18, Color("9be15d") if rotten else colors["text"])
    name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(name_l)
    row.add_child(_btn("SELL +%d" % price, func(): _sell(id), 18))
    list_box.add_child(row)


func _sell(id: String) -> void:
    var g: int = Game.sell_simple(id)
    AudioManager.play_sfx("sell" if g > 0 else "deny", -13.0, 0.02)
    if g > 0:
        _say("+%d coins" % g)
    _changed()


func _stats_section() -> void:
    _header("STATS (sell any amount)")
    for stat in ["atk", "hp", "speed", "mastery"]:
        var mx: int = Game.stat_max_sell(stat)
        var cur: int = int(Game.stats[stat])
        var lbl: String = "%s %d" % [GameData.STAT_NAMES[stat], cur]
        if mx <= 0:
            list_box.add_child(_lbl(lbl + "  (minimum)", 16, colors["sub"]))
            continue
        var n: int = clampi(int(stat_n[stat]), 1, mx)
        stat_n[stat] = n
        var price: int = int(GameData.STAT_SELL[stat]["price"])
        var row := HBoxContainer.new()
        var l := _lbl(lbl, 17, colors["text"])
        l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(l)
        row.add_child(_btn("-", func(): _step(stat, -1), 18))
        row.add_child(_lbl(" %d " % n, 18, colors["text"]))
        row.add_child(_btn("+", func(): _step(stat, 1), 18))
        row.add_child(_btn("SELL +%d" % (n * price), func(): _sell_stat(stat, n), 18))
        list_box.add_child(row)


func _step(stat: String, d: int) -> void:
    stat_n[stat] = int(stat_n[stat]) + d
    rebuild()


func _sell_stat(stat: String, n: int) -> void:
    var g: int = Game.sell_stat(stat, n)
    AudioManager.play_sfx("sell" if g > 0 else "deny", -13.0, 0.02)
    if g > 0:
        _say("+%d coins" % g)
    _changed()


func _ring_section() -> void:
    _header("ARENA")
    var p: int = Game.ring_next_price()
    if p < 0:
        list_box.add_child(_lbl("Ring space  (already at minimum)", 16, colors["sub"]))
        return
    var row := HBoxContainer.new()
    var l := _lbl("Ring space (step %d of %d)" % [Game.ring_steps_sold + 1, GameData.RING_STEP_PRICES.size()], 18, colors["text"])
    l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(l)
    row.add_child(_btn("SELL +%d" % p, _sell_ring, 18))
    list_box.add_child(row)


func _sell_ring() -> void:
    var g: int = Game.sell_ring_step()
    AudioManager.play_sfx("sell" if g > 0 else "deny", -13.0, 0.02)
    if g > 0:
        _say("+%d coins" % g)
    _changed()


# ---------------------------------------------------------------- beacon shops

func _build_side(side: String, items: Array) -> void:
    if Game.side_price_mult(side) > 1.0:
        var warn: String = "ANGEL'S WRATH: prices x1.2" if side == "angel" else "THE DEMON SNEERS: prices x1.2"
        list_box.add_child(UI.wrap(_lbl(warn, 16, Color(0.85, 0.3, 0.1))))
    if Game.round_side != "" and Game.round_side != side:
        list_box.add_child(UI.wrap(_lbl("You already used the other beacon this round.", 15, Color(0.85, 0.3, 0.1))))
    for item in items:
        _item_row(side, item)


func _item_row(side: String, item: Dictionary) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    row.add_child(UiSkin.icon_tile(UiSkin.item_art(item), look, 60.0))
    var mid := VBoxContainer.new()
    mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    mid.add_child(_lbl(Game.display_name(item), 20, colors["text"]))
    mid.add_child(UI.wrap(_lbl(Game.item_text(side, item), 13, colors["sub"])))
    row.add_child(mid)
    var price: int = Game.item_price(side, item)
    var reason: String = Game.buy_block_reason(side, item)
    var btn_text: String = "BUY %d" % price
    if Game.bought.has(item["id"]):
        btn_text = "OWNED"
    var b := _btn(btn_text, func(): _buy(side, item), 18)
    b.disabled = reason != ""
    b.tooltip_text = reason
    b.custom_minimum_size = Vector2(110, 44)
    b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    row.add_child(b)
    list_box.add_child(row)


func _buy(side: String, item: Dictionary) -> void:
    if Game.buy(side, item):
        AudioManager.play_sfx("buy", -13.0, 0.02)
        _say("Bought %s" % Game.display_name(item))
    else:
        AudioManager.play_sfx("deny", -14.0, 0.02)
    _changed()
