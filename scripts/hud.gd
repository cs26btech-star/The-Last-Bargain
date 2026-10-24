extends CanvasLayer
## Street-Fighter style HUD. Every part hides itself when the player has sold it.

const BAR_W = 400.0
const BAR_H = 26.0

var fight = null
var root: Control
var p_name: Label
var p_bg: ColorRect
var p_fill: ColorRect
var p_frame: NinePatchRect = null
var e_name: Label
var e_bg: ColorRect
var e_fill: ColorRect
var e_frame: NinePatchRect = null
var timer_label: Label
var coins_label: Label
var controls_label: Label
var cat_btn: Button
var start_btn: Button
var prompt_label: Label
var slot_bgs: Array = []
var slot_labels: Array = []
var toast_label: Label
var flash_rect: ColorRect
var toast_t: float = 0.0
var pause_panel: Control
var rent_label: Label
var rot_t: float = 0.0
var rot_tick: bool = false
var rot_acc: float = 0.0
var _rot_base: Dictionary = {}      # node -> its normal position
var _rot_groups: Dictionary = {}    # sellable id -> nodes that show it


func setup(f) -> void:
    fight = f
    process_mode = Node.PROCESS_MODE_ALWAYS
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    _build()


func _build() -> void:
    # left: player
    p_name = UI.label(Game.username, 24, Color("f3e3b0"))
    p_name.position = Vector2(20, 6)
    root.add_child(p_name)
    p_bg = ColorRect.new()
    p_bg.color = Color(0.16, 0.05, 0.2)
    p_bg.position = Vector2(20, 40)
    p_bg.size = Vector2(BAR_W, BAR_H)
    root.add_child(p_bg)
    p_fill = ColorRect.new()
    p_fill.color = Color(0.2, 0.85, 0.3)
    p_fill.position = Vector2(20, 40)
    p_fill.size = Vector2(BAR_W, BAR_H)
    root.add_child(p_fill)
    p_frame = UiSkin.bar_frame(Vector2(BAR_W + 24.0, BAR_H + 18.0), "player")
    if p_frame != null:
        p_frame.position = Vector2(8, 31)
        root.add_child(p_frame)
    # right: enemy
    e_name = UI.label("", 24, Color("f3e3b0"))
    e_name.position = Vector2(800, 6)
    e_name.size = Vector2(BAR_W, 32)
    e_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    root.add_child(e_name)
    e_bg = ColorRect.new()
    e_bg.color = Color(0.16, 0.05, 0.2)
    e_bg.position = Vector2(800, 40)
    e_bg.size = Vector2(BAR_W, BAR_H)
    root.add_child(e_bg)
    e_fill = ColorRect.new()
    e_fill.color = Color(0.9, 0.3, 0.25)
    e_fill.position = Vector2(800, 40)
    e_fill.size = Vector2(BAR_W, BAR_H)
    root.add_child(e_fill)
    e_frame = UiSkin.bar_frame(Vector2(BAR_W + 24.0, BAR_H + 18.0), "enemy")
    if e_frame != null:
        e_frame.position = Vector2(788, 31)
        root.add_child(e_frame)
    # middle: timer
    timer_label = UI.label("0", 34, Color("d9a93a"))
    timer_label.position = Vector2(590, 8)
    timer_label.size = Vector2(100, 44)
    timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root.add_child(timer_label)
    # coins
    coins_label = UI.label("", 22, Color("d9a93a"))
    coins_label.position = Vector2(20, 76)
    root.add_child(coins_label)
    controls_label = UI.label("WASD MOVE  ·  MOUSE AIM  ·  HOLD LMB / J / K TO ATTACK  ·  SPACE TO DODGE", 13, Color("d5c6a8"))
    controls_label.position = Vector2(300, 78)
    controls_label.size = Vector2(680, 24)
    controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    controls_label.add_theme_color_override("font_shadow_color", Color("100d18"))
    controls_label.add_theme_constant_override("shadow_offset_x", 1)
    controls_label.add_theme_constant_override("shadow_offset_y", 1)
    root.add_child(controls_label)
    # prep buttons
    cat_btn = UI.button("CATALOGUE  [C]", func(): fight.open_catalogue(), 20)
    UiSkin.style_button(cat_btn, "demon", "catalogue")
    cat_btn.position = Vector2(20, 112)
    cat_btn.size = Vector2(250, 46)
    root.add_child(cat_btn)
    start_btn = UI.button("START ROUND  [Enter]", func(): fight.start_round(), 20)
    UiSkin.style_button(start_btn, "demon", "start")
    start_btn.position = Vector2(1000, 112)
    start_btn.size = Vector2(260, 46)
    root.add_child(start_btn)
    rent_label = UI.label("", 22, Color("d9a93a"))
    rent_label.position = Vector2(960, 162)
    rent_label.size = Vector2(300, 30)
    rent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    root.add_child(rent_label)
    prompt_label = UI.label("", 30, Color("d9a93a"))
    prompt_label.position = Vector2(340, 590)
    prompt_label.size = Vector2(600, 44)
    prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    prompt_label.visible = false
    root.add_child(prompt_label)
    # menu button: three dashes (never sellable)
    var mb := Button.new()
    mb.focus_mode = Control.FOCUS_NONE
    mb.position = Vector2(1218, 8)
    mb.size = Vector2(50, 42)
    mb.pressed.connect(_open_pause)
    root.add_child(mb)
    for i in 3:
        var line := ColorRect.new()
        line.color = Color("d9a93a")
        line.position = Vector2(11, 11 + i * 9)
        line.size = Vector2(28, 4)
        line.mouse_filter = Control.MOUSE_FILTER_IGNORE
        mb.add_child(line)
    # inventory bar
    for i in 6:
        var bg := ColorRect.new()
        bg.position = Vector2(328 + i * 104, 646)
        bg.size = Vector2(100, 64)
        bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
        root.add_child(bg)
        var l := UI.label("", 12, Color("f3e3b0"))
        l.size = Vector2(100, 64)
        l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        l.clip_text = true
        l.mouse_filter = Control.MOUSE_FILTER_IGNORE
        bg.add_child(l)
        slot_bgs.append(bg)
        slot_labels.append(l)
    # toast + flash
    toast_label = UI.label("", 34, Color.WHITE)
    toast_label.position = Vector2(140, 170)
    toast_label.size = Vector2(1000, 50)
    toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    toast_label.visible = false
    root.add_child(toast_label)
    flash_rect = ColorRect.new()
    flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    flash_rect.color = Color(1, 1, 1, 0)
    flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(flash_rect)
    _build_pause()
    _setup_rot_groups()


func _build_pause() -> void:
    pause_panel = Control.new()
    pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    pause_panel.visible = false
    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.7)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    pause_panel.add_child(dim)
    var c := CenterContainer.new()
    c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    pause_panel.add_child(c)
    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 16)
    c.add_child(vb)
    vb.add_child(UI.label("PAUSED", 48, Color("d9a93a")))
    var rb := UI.button("RESUME", _close_pause, 28)
    UiSkin.style_button(rb, "demon", "pause_resume")
    vb.add_child(rb)
    var fsb := UI.button(DisplayControl.label_text(), func(): DisplayControl.toggle(), 28)
    UiSkin.style_button(fsb, "demon", "pause_fullscreen")
    DisplayControl.changed.connect(_refresh_fs_button.bind(fsb))
    vb.add_child(fsb)
    var qb := UI.button("QUIT TO TITLE", _quit, 28)
    UiSkin.style_button(qb, "demon", "pause_quit")
    vb.add_child(qb)
    root.add_child(pause_panel)


func _refresh_fs_button(btn) -> void:
    if is_instance_valid(btn):
        btn.text = DisplayControl.label_text()


func _open_pause() -> void:
    pause_panel.visible = true
    get_tree().paused = true


func _close_pause() -> void:
    pause_panel.visible = false
    get_tree().paused = false


func _quit() -> void:
    get_tree().paused = false
    fight.quit_to_title.emit()


func toast(text: String, secs: float = 1.6) -> void:
    toast_label.text = text
    toast_label.visible = true
    toast_t = secs


func set_prompt(text: String) -> void:
    prompt_label.text = text
    prompt_label.visible = text != ""


func flash_screen(col: Color, dur: float) -> void:
    flash_rect.color = col
    var tw: Tween = create_tween()
    tw.tween_property(flash_rect, "color:a", 0.0, dur)


func _slot_text(i: int) -> String:
    var it = Game.inventory[i]
    if it == null:
        return "%d\n-" % (i + 1)
    if it["kind"] == "weapon":
        return "%d\n%s\n%d" % [i + 1, it["name"], it["dur"]]
    if it["kind"] == "skill":
        return "%d\n%s" % [i + 1, it["name"]]
    return "%d\nFists" % (i + 1)


## Which nodes belong to which sellable HUD piece (so rot can make them glitch).
func _setup_rot_groups() -> void:
    _rot_groups = {
        "hud_hp_bar": [p_bg, p_fill, p_frame],
        "hud_enemy_bar": [e_bg, e_fill, e_frame],
        "hud_timer": [timer_label],
        "hud_name_player": [p_name],
        "hud_name_enemy": [e_name],
        "hud_coins": [coins_label],
        "hud_inventory": slot_bgs,
    }
    for id in _rot_groups:
        for n in _rot_groups[id]:
            if n != null:
                _rot_base[n] = n.position


func _garble(s: String) -> String:
    var rng := RandomNumberGenerator.new()
    rng.seed = int(rot_t * 8.0) * 7919 + s.hash()
    var glyphs: String = "#@%&?<>01"
    var out: String = ""
    for i in range(s.length()):
        if s[i] != " " and rng.randf() < 0.35:
            out += glyphs[rng.randi() % glyphs.length()]
        else:
            out += s[i]
    return out


## Contagion: rotten pieces flicker green/purple, shake and scramble their text.
func _apply_rot(delta: float) -> void:
    rot_t += delta
    rot_acc += delta
    rot_tick = false
    if rot_acc >= 0.1:
        rot_acc = 0.0
        rot_tick = true
    for id in _rot_groups:
        var sick: bool = Game.infected.has(id) and not Game.is_sold(id)
        for n in _rot_groups[id]:
            if n == null:
                continue
            if sick:
                if rot_tick:
                    n.modulate = Color(randf_range(0.5, 0.9), randf_range(0.9, 1.5), randf_range(0.3, 0.8), randf_range(0.45, 1.0))
                    if n != p_fill and n != e_fill:
                        n.position = _rot_base[n] + Vector2(randf_range(-4.0, 4.0), randf_range(-3.0, 3.0))
            else:
                n.modulate = Color.WHITE
                if n != e_fill and n != p_fill:
                    n.position = _rot_base[n]
    p_name.text = _garble(Game.username) if Game.infected.has("hud_name_player") else Game.username
    if Game.infected.has("hud_name_enemy"):
        e_name.text = _garble(e_name.text)
    if Game.infected.has("hud_timer"):
        timer_label.text = _garble(timer_label.text)
    if Game.infected.has("hud_coins"):
        coins_label.text = _garble(coins_label.text)


func _process(delta: float) -> void:
    if fight == null or fight.player == null:
        return
    var p = fight.player
    var prep: bool = fight.phase == "prep"
    cat_btn.visible = prep
    start_btn.visible = prep
    # player side
    var show_bar: bool = not Game.is_sold("hud_hp_bar")
    p_bg.visible = show_bar
    p_fill.visible = show_bar
    if p_frame != null:
        p_frame.visible = show_bar
    p_fill.size.x = BAR_W * clampf(p.hp / p.max_hp, 0.0, 1.0)
    p_name.visible = not Game.is_sold("hud_name_player")
    # enemy side
    var tot: float = 0.0
    var mx: float = 0.0
    for e in fight.enemies:
        tot += e.hp
        mx += e.max_hp
    var ratio: float = tot / mx if mx > 0.0 else 0.0
    e_fill.size.x = BAR_W * ratio
    e_fill.position.x = e_bg.position.x + BAR_W - e_fill.size.x
    var show_e: bool = not Game.is_sold("hud_enemy_bar")
    e_bg.visible = show_e
    e_fill.visible = show_e
    if e_frame != null:
        e_frame.visible = show_e
    e_name.text = ("Next: " + fight.boss_name) if prep else fight.boss_name
    e_name.visible = not Game.is_sold("hud_name_enemy")
    # timer + coins
    timer_label.text = "%d" % int(fight.elapsed)
    timer_label.visible = not Game.is_sold("hud_timer")
    coins_label.text = "Coins: %d" % Game.coins
    coins_label.visible = not Game.is_sold("hud_coins")
    # inventory
    var show_inv: bool = not Game.is_sold("hud_inventory")
    for i in 6:
        slot_bgs[i].visible = show_inv
        slot_labels[i].text = _slot_text(i)
        if i == Game.selected_slot:
            slot_bgs[i].color = Color(0.45, 0.3, 0.1, 0.95)
        else:
            slot_bgs[i].color = Color(0.16, 0.05, 0.2, 0.92)
    _apply_rot(delta)
    # rent
    var rent: int = Game.rent_due()
    rent_label.visible = prep and rent > 0
    rent_label.text = "RENT DUE: %d coins" % rent
    rent_label.add_theme_color_override("font_color", Color("ff6b6b") if Game.coins < rent else Color("d9a93a"))
    # toast fade
    if toast_t > 0.0:
        toast_t -= delta
        if toast_t <= 0.0:
            toast_label.visible = false
