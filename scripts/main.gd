extends Node
## Screen manager: title -> class select -> name -> (shop -> fight) x4 -> ending.

const FightScript = preload("res://scripts/fight.gd")

const MYTHIC_FONT: Font = preload("res://fonts/EBGaramond.ttf")

var current: Node = null
var chosen_class: String = "swordmaster"
var name_edit: LineEdit = null


func _ready() -> void:
    _apply_mythic_theme()
    _start_music()
    _show_title()


func _apply_mythic_theme() -> void:
    # A bundled serif face gives the interface an older, mythic tone without relying on OS fonts.
    var font_path := "res://fonts/EBGaramond.ttf"
    if not ResourceLoader.exists(font_path):
        return
    var font = load(font_path)
    var theme := Theme.new()
    theme.default_font = font
    theme.default_font_size = 18
    get_tree().root.theme = theme


func _start_music() -> void:
    AudioManager.play_music_named(["bgm"])

func _swap(node: Node) -> void:
    get_tree().paused = false
    if current != null:
        remove_child(current)
        current.queue_free()
    current = node
    add_child(node)


func _screen() -> Control:
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var bg := ColorRect.new()
    bg.color = Color("100d18")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(bg)
    # Decorative dark-fantasy frame used across title, class, name and ending screens.
    var deco := Control.new()
    deco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(deco)
    var top := ColorRect.new()
    top.color = Color("b83245")
    top.position = Vector2(24, 20)
    top.size = Vector2(1232, 3)
    top.mouse_filter = Control.MOUSE_FILTER_IGNORE
    deco.add_child(top)
    var bottom := ColorRect.new()
    bottom.color = Color("d9a93a")
    bottom.position = Vector2(24, 697)
    bottom.size = Vector2(1232, 3)
    bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
    deco.add_child(bottom)
    for x in [24.0, 1252.0]:
        var rail := ColorRect.new()
        rail.color = Color("39213e")
        rail.position = Vector2(x, 23)
        rail.size = Vector2(3, 674)
        rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
        deco.add_child(rail)
    return root


func _centered(root: Control, separation: int = 24) -> VBoxContainer:
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(center)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", separation)
    center.add_child(box)
    return box


func _centered_label(text: String, size: int, color: Color = Color.WHITE) -> Label:
    var l := UI.label(text, size, color)
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    return l


func _big_button(text: String, cb: Callable) -> Button:
    var b := UI.button(text, cb, 30)
    UiSkin.style_button(b, "demon", "menu")
    b.custom_minimum_size = Vector2(340, 66)
    b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    return b


# ---------------------------------------------------------------- screens

func _show_title() -> void:
    AudioManager.play_music_named(["bgm"])
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(TitleBg.new())
    var box := _centered(root, 12)
    box.modulate.a = 0.0
    # small spaced-out tagline
    var spaced := FontVariation.new()
    spaced.base_font = MYTHIC_FONT
    spaced.spacing_glyph = 5
    var tag := _centered_label("THE RING DEMANDS A PRICE", 20, Color("e0646f"))
    tag.add_theme_font_override("font", spaced)
    box.add_child(tag)
    # big glowing title
    var title_font := FontVariation.new()
    title_font.base_font = MYTHIC_FONT
    title_font.spacing_glyph = 4
    var title := _centered_label(GameData.TITLE, 84, Color("f0cf7a"))
    title.add_theme_font_override("font", title_font)
    title.add_theme_color_override("font_outline_color", Color(0.12, 0.03, 0.08))
    title.add_theme_constant_override("outline_size", 14)
    title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
    title.add_theme_constant_override("shadow_offset_y", 6)
    box.add_child(title)
    box.add_child(_divider())
    var intro := _centered_label(GameData.INTRO, 22, Color("e4dce8"))
    intro.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
    intro.add_theme_constant_override("shadow_offset_y", 2)
    box.add_child(intro)
    box.add_child(_spacer(6.0))
    box.add_child(_big_button("START", _show_class_select))
    box.add_child(_big_button("INFO & ACKNOWLEDGEMENTS", _show_info))
    var fsb := UI.button(DisplayControl.label_text(), func(): DisplayControl.toggle(), 20)
    UiSkin.style_button(fsb, "demon", "menu")
    fsb.custom_minimum_size = Vector2(260, 46)
    fsb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    DisplayControl.changed.connect(_refresh_fs_button.bind(fsb))
    box.add_child(fsb)
    box.add_child(_centered_label(GameData.CREDITS, 16, Color(0.82, 0.76, 0.86)))
    _swap(root)
    # fade the menu in and let the title shimmer
    var fade: Tween = box.create_tween()
    fade.tween_property(box, "modulate:a", 1.0, 0.9)
    var shimmer: Tween = title.create_tween().set_loops()
    shimmer.tween_property(title, "modulate", Color(1.12, 1.06, 0.92), 1.5)
    shimmer.tween_property(title, "modulate", Color(1, 1, 1), 1.5)


func _refresh_fs_button(btn) -> void:
    if is_instance_valid(btn):
        btn.text = DisplayControl.label_text()


func _spacer(h: float) -> Control:
    var c := Control.new()
    c.custom_minimum_size = Vector2(0, h)
    return c


## Gold line - diamond - gold line.
func _divider() -> Control:
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 12)
    for side in range(3):
        if side == 1:
            var holder := Control.new()
            holder.custom_minimum_size = Vector2(16, 16)
            var d := ColorRect.new()
            d.color = Color("e5c16a")
            d.size = Vector2(10, 10)
            d.position = Vector2(3, 3)
            d.pivot_offset = Vector2(5, 5)
            d.rotation = PI / 4.0
            holder.add_child(d)
            row.add_child(holder)
        else:
            var line := ColorRect.new()
            line.color = Color(0.85, 0.65, 0.3, 0.8)
            line.custom_minimum_size = Vector2(190, 2)
            line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
            row.add_child(line)
    return row


func _show_info() -> void:
    var root := _screen()
    var outer := VBoxContainer.new()
    outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    outer.add_theme_constant_override("separation", 14)
    outer.offset_left = 90
    outer.offset_top = 35
    outer.offset_right = -90
    outer.offset_bottom = -35
    root.add_child(outer)

    outer.add_child(_centered_label("HOW TO PLAY", 46, Color.GOLD))
    var info := RichTextLabel.new()
    info.bbcode_enabled = true
    info.fit_content = false
    info.scroll_active = true
    info.custom_minimum_size = Vector2(0, 430)
    info.size_flags_vertical = Control.SIZE_EXPAND_FILL
    info.add_theme_font_override("normal_font", MYTHIC_FONT)
    info.add_theme_font_override("bold_font", MYTHIC_FONT)
    info.add_theme_font_size_override("normal_font_size", 22)
    info.add_theme_color_override("default_color", Color(0.93, 0.93, 0.97))
    info.text = "[b]YOUR GOAL[/b]\nSurvive four boss fights. Sell parts of your own stats and inventory for coins, then spend those coins to prepare for the next fight. Every sale has a cost.\n\n[b]CONTROLS[/b]\nW / A / S / D — Move\nMouse — Aim\nLeft mouse button (click or hold) — Attack\nSpace — Dodge roll\nKeys 1–6 — Select an item or use a skill\nE — Interact with a nearby Angel or Demon beacon during preparation\nC — Open the Storekeeper’s catalogue during preparation\nEnter — Start the boss fight\n\n[b]PREPARATION PHASE[/b]\nWalk to the purple Demon beacon on the left or the white Angel beacon on the right and press E. Press C to sell stats/items through the catalogue. When you are ready, press Enter to begin the round.\n\n[b]ACKNOWLEDGEMENTS[/b]\n" + GameData.CREDITS + "\nBuilt with the Godot Engine (MIT licence). Interface font: EB Garamond (SIL Open Font License).\nSound effects are omitted from this submission build.\n" + GameData.MUSIC_CREDITS
    outer.add_child(info)
    var back := _big_button("BACK TO TITLE", _show_title)
    outer.add_child(back)
    _swap(root)


func _show_class_select() -> void:
    var root := _screen()
    var box := _centered(root, 30)
    box.add_child(_centered_label("CHOOSE YOUR CLASS", 48, Color("e5c16a")))
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 20)
    box.add_child(row)
    for id in ["swordmaster", "spearman", "assassin"]:
        var c: Dictionary = GameData.CLASSES[id]
        var p := UI.panel(Color("1c1425"))
        row.add_child(p)
        var col := VBoxContainer.new()
        col.add_theme_constant_override("separation", 10)
        p.add_child(col)
        col.add_child(UI.label(str(c["name"]), 32, Color(str(c["color"]))))
        col.add_child(UI.label(str(c["blurb"]), 16))
        var stat_text: String = "Attack %d    HP %d\nSpeed %d    Mastery %d\nWeapon: %s" % [
            c["atk"], int(c["hp"]) * 10, c["speed"], c["mastery"], str(c["weapon"]).capitalize()]
        col.add_child(UI.label(stat_text, 20))
        var choose_btn := UI.button("CHOOSE", func(): _choose_class(id), 26)
        UiSkin.style_button(choose_btn, "demon", "choose")
        col.add_child(choose_btn)
    _swap(root)


func _choose_class(id: String) -> void:
    chosen_class = id
    var root := _screen()
    var box := _centered(root, 24)
    box.add_child(_centered_label("WHAT IS YOUR NAME?", 48, Color.GOLD))
    name_edit = LineEdit.new()
    name_edit.max_length = 10
    name_edit.placeholder_text = "Enter your name"
    name_edit.custom_minimum_size = Vector2(400, 60)
    name_edit.add_theme_font_override("font", MYTHIC_FONT)
    name_edit.add_theme_font_size_override("font_size", 30)
    name_edit.add_theme_color_override("font_color", Color("f7e8ee"))
    name_edit.add_theme_color_override("font_placeholder_color", Color("ad9aaa"))
    var name_style := StyleBoxFlat.new()
    name_style.bg_color = Color("1c1425")
    name_style.border_color = Color("b83245")
    name_style.set_border_width_all(2)
    name_style.set_content_margin_all(10)
    name_edit.add_theme_stylebox_override("normal", name_style)
    name_edit.text_submitted.connect(func(_t): _start_run())
    box.add_child(name_edit)
    box.add_child(_big_button("ENTER THE RING", _start_run))
    _swap(root)
    name_edit.grab_focus()


func _start_run() -> void:
    var uname: String = name_edit.text if name_edit != null else ""
    if uname.strip_edges() == "":
        uname = "Hero"
    Game.new_run(chosen_class, uname)
    _show_lore(true)


func _show_lore(first_time: bool) -> void:
    var root := _screen()
    var outer := VBoxContainer.new()
    outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    outer.offset_left = 64
    outer.offset_top = 38
    outer.offset_right = -64
    outer.offset_bottom = -38
    outer.add_theme_constant_override("separation", 18)
    root.add_child(outer)
    var heading := _centered_label("THE ARENA HAS CHOSEN", 42, Color("e5c16a"))
    outer.add_child(heading)
    var story_row := HBoxContainer.new()
    story_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
    story_row.add_theme_constant_override("separation", 24)
    outer.add_child(story_row)
    _add_lore_portrait(story_row, "figure_lore_demonking", Color("d44752"), "THE DEMON KING")
    var panel := PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color("17111f")
    panel_style.border_color = Color("8c6533")
    panel_style.set_border_width_all(2)
    panel_style.set_content_margin_all(22)
    panel.add_theme_stylebox_override("panel", panel_style)
    story_row.add_child(panel)
    var prose := RichTextLabel.new()
    prose.bbcode_enabled = true
    prose.fit_content = true
    prose.size_flags_vertical = Control.SIZE_EXPAND_FILL
    prose.add_theme_font_override("normal_font", MYTHIC_FONT)
    prose.add_theme_font_override("bold_font", MYTHIC_FONT)
    prose.add_theme_font_size_override("normal_font_size", 21)
    prose.add_theme_color_override("default_color", Color("eee5ee"))
    if first_time:
        prose.text = """[center][color=#d9b4ff][b]A FINAL CHANCE. A FINAL PRICE.[/b][/color][/center]

You were cast into the Colosseum with one promise: survive four trials, and your sentence may be lifted. The crowd wants blood. The gates will not open for the defeated.

[color=#f0d17b][b]THE ARCHANGEL HAS TAKEN AN INTEREST IN YOU.[/b][/color]
A distant light watches your struggle. Her boons may keep you standing—but salvation is never free.

[color=#e66a79][b]THE DEMON KING HAS ALSO NOTICED YOU.[/b][/color]
He offers power without mercy. Sell what you can bear to lose, and make every bargain count.

[color=#9be15d][b]BEWARE THE ROT.[/b][/color]
Demon bargains leave a rot behind. It spreads through what you own, and wolves carry it too.

[color=#e5c16a][b]THE HOUSE COLLECTS RENT.[/b][/color] From round 2 you owe the Storekeeper coins before every fight. The prize money will not cover it. You will have to sell.

[center]The shrines beside the arena are your shops. Approach one and press [b]E[/b]. Press [b]C[/b] to open the catalogue. Prepare before pressing [b]Enter[/b].[/center]"""
    else:
        var next_boss: String = str(GameData.BOSSES[Game.round_index]["name"])
        prose.text = """[center][color=#d9b4ff][b]THE CROWD DEMANDS ANOTHER TRIAL.[/b][/color][/center]

Your wounds have been mended, but the next gate is opening. The beings watching from beyond the veil have not lost interest.

[color=#f0d17b][b]VISIT THE SHRINES BEFORE YOU FIGHT.[/b][/color]
The Archangel's boons and the Demon King's bargains can change your fate. Sell carefully, spend wisely, and inspect your equipment.

[color=#e5c16a][b]RENT DUE BEFORE THIS FIGHT: %d coins.[/b][/color] Sell something if you are short.%s

[center]Next opponent: [b]%s[/b]
Approach a beacon and press [b]E[/b]. Press [b]C[/b] for the catalogue, then [b]Enter[/b] when ready.[/center]""" % [Game.rent_due(), _rot_lore(), next_boss]
    panel.add_child(prose)
    _add_lore_portrait(story_row, "figure_lore_archangel", Color("e5c16a"), "THE ARCHANGEL")
    var continue_btn := _big_button("ENTER THE PREPARATION PHASE", _show_fight)
    outer.add_child(continue_btn)
    _swap(root)


func _add_lore_portrait(parent: HBoxContainer, art_name: String, accent: Color, caption: String) -> void:
    var column := VBoxContainer.new()
    column.custom_minimum_size = Vector2(190, 0)
    column.size_flags_vertical = Control.SIZE_EXPAND_FILL
    column.add_theme_constant_override("separation", 8)
    parent.add_child(column)
    var frame := PanelContainer.new()
    frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
    frame.custom_minimum_size = Vector2(190, 330)
    var style := StyleBoxFlat.new()
    style.bg_color = Color("110d18")
    style.border_color = accent
    style.set_border_width_all(3)
    style.set_content_margin_all(8)
    frame.add_theme_stylebox_override("panel", style)
    column.add_child(frame)
    var portrait := TextureRect.new()
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
    portrait.texture = Art.tex(art_name)
    frame.add_child(portrait)
    # Portrait art is optional; the frame remains valid if a texture is missing.
    var label := _centered_label(caption, 16, accent)
    column.add_child(label)


func _show_fight() -> void:
    var fight = FightScript.new()
    fight.finished.connect(_on_fight_finished)
    fight.quit_to_title.connect(_show_title)
    _swap(fight)


func _on_fight_finished(won: bool) -> void:
    if won:
        Game.add_coins(int(GameData.BOSS_DROPS[Game.round_index]))
    var receipt: String = Game.build_receipt(won, str(GameData.BOSSES[Game.round_index]["name"]))
    if won and Game.round_index < GameData.BOSSES.size() - 1:
        _show_receipt(receipt, func():
            Game.finish_round()
            # Full healing between rounds is intentional for the chosen run rules.
            _show_lore(false))
    else:
        _show_receipt(receipt, func(): _show_ending(won))


func _rot_lore() -> String:
    if Game.infected.is_empty():
        return ""
    var names: Array = []
    for id in Game.infected:
        names.append(Game.name_of(id))
    return "\n[color=#9be15d][b]ROT:[/b] %s is rotting. Sell it before it is eaten.[/color]" % ", ".join(PackedStringArray(names))


## The Storekeeper's receipt after every fight: what you signed, what you sold, and what it did.
func _show_receipt(text: String, next: Callable) -> void:
    AudioManager.play_sfx("open", -17.0, 0.01)
    var root := _screen()
    var outer := VBoxContainer.new()
    outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    outer.offset_left = 120
    outer.offset_top = 38
    outer.offset_right = -120
    outer.offset_bottom = -38
    outer.add_theme_constant_override("separation", 16)
    root.add_child(outer)
    outer.add_child(_centered_label("THE STOREKEEPER'S RECEIPT", 40, Color("e5c16a")))
    var panel := PanelContainer.new()
    panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var style := StyleBoxFlat.new()
    style.bg_color = Color("17111f")
    style.border_color = Color("8c6533")
    style.set_border_width_all(2)
    style.set_content_margin_all(22)
    panel.add_theme_stylebox_override("panel", style)
    outer.add_child(panel)
    var rt := RichTextLabel.new()
    rt.bbcode_enabled = true
    rt.scroll_active = true
    rt.size_flags_vertical = Control.SIZE_EXPAND_FILL
    rt.add_theme_font_override("normal_font", MYTHIC_FONT)
    rt.add_theme_font_override("bold_font", MYTHIC_FONT)
    rt.add_theme_font_size_override("normal_font_size", 20)
    rt.add_theme_color_override("default_color", Color("eee5ee"))
    rt.text = text
    panel.add_child(rt)
    outer.add_child(_big_button("CONTINUE", next))
    _swap(root)


func _show_ending(won: bool) -> void:
    var root := _screen()
    var box := _centered(root, 28)
    if not won:
        AudioManager.play_sfx("defeat", -3.0, 0.0)
    AudioManager.play_music_named(["ending_win" if won else "ending_lose", "bgm"])
    if won:
        box.add_child(_centered_label("YOU WIN", 80, Color.GOLD))
        box.add_child(_centered_label("You beat all four bosses.\nYou sold %d coins' worth of yourself to do it." % Game.sold_value, 28))
    else:
        box.add_child(_centered_label("BAD ENDING", 80, Color("e34b5a")))
        box.add_child(_centered_label("You fell in the ring.\nEverything you sold is gone, but the arena always takes you back...", 28))
    # the ledger: cause and effect, round by round
    var lines: Array = []
    lines.append("[color=#e5c16a][b]THE LEDGER[/b][/color]")
    for l in Game.ledger:
        lines.append("- " + str(l))
    lines.append("[color=#e66a79]Lost along the way:[/color] " + Game.lost_summary())
    var led := RichTextLabel.new()
    led.bbcode_enabled = true
    led.scroll_active = true
    led.custom_minimum_size = Vector2(900, 190)
    led.add_theme_font_override("normal_font", MYTHIC_FONT)
    led.add_theme_font_override("bold_font", MYTHIC_FONT)
    led.add_theme_font_size_override("normal_font_size", 18)
    led.add_theme_color_override("default_color", Color("d9cfe0"))
    led.text = "\n".join(PackedStringArray(lines))
    box.add_child(led)
    box.add_child(_big_button("PLAY AGAIN", _show_class_select))
    _swap(root)
