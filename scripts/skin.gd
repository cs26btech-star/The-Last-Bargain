class_name UiSkin
extends RefCounted
## Looks for the shop windows. "demon" = purple + gold, "angel" = white + gold.
## Uses art/ui_panel.png, ui_button.png, ui_hpbar.png when they exist, flat colours otherwise.

const GOLD = Color("d9a93a")

# Character portraits load from the art folder when available.


static func colors(look: String) -> Dictionary:
    if look == "angel":
        return {
            "bg": Color("f7f2e6"), "tile": Color("fffaf0"), "border": GOLD,
            "text": Color("352817"), "sub": Color("766343"), "accent": Color("b58a2b"),
            "btn": Color("eee2c4"), "btn_hover": Color("fff5d9"), "btn_down": Color("d7c69b"),
        }
    return {
        "bg": Color("160b19"), "tile": Color("241020"), "border": Color("b83245"),
        "text": Color("f7e8ee"), "sub": Color("c7a9b9"), "accent": Color("e34b5a"),
        "btn": Color("3a1730"), "btn_hover": Color("57213f"), "btn_down": Color("25101f"),
    }


static func flat_box(bg: Color, border: Color, width: int = 2) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = bg
    sb.border_color = border
    sb.set_border_width_all(width)
    sb.set_content_margin_all(6)
    return sb


## A fixed-size window: coloured fill + the gold frame art on top.
static func frame(look: String, size: Vector2, slot: String = "") -> Control:
    var c: Dictionary = colors(look)
    var root := Control.new()
    root.custom_minimum_size = size
    root.size = size
    var fill := ColorRect.new()
    fill.color = c["bg"]
    fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(fill)
    var t: Texture2D = Art.tex("ui_panel_" + slot)
    if t != null:
        var np := NinePatchRect.new()
        np.texture = t
        np.draw_center = false
        np.patch_margin_left = 34
        np.patch_margin_right = 34
        np.patch_margin_top = 34
        np.patch_margin_bottom = 34
        np.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        np.mouse_filter = Control.MOUSE_FILTER_IGNORE
        root.add_child(np)
    else:
        var p := Panel.new()
        p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        p.add_theme_stylebox_override("panel", flat_box(Color(0, 0, 0, 0), GOLD, 5))
        p.mouse_filter = Control.MOUSE_FILTER_IGNORE
        root.add_child(p)
    return root


static func _tex_box(t: Texture2D, mod: Color) -> StyleBoxTexture:
    var sb := StyleBoxTexture.new()
    sb.texture = t
    sb.set_texture_margin_all(18.0)
    sb.set_content_margin_all(8.0)
    sb.modulate_color = mod
    return sb


static func style_button(b: Button, look: String, slot: String = "") -> void:
    var c: Dictionary = colors(look)
    b.add_theme_color_override("font_color", c["text"])
    b.add_theme_color_override("font_hover_color", c["text"])
    b.add_theme_color_override("font_pressed_color", c["text"])
    b.add_theme_color_override("font_disabled_color", c["sub"])
    var t: Texture2D = Art.tex("ui_button_" + slot)
    if look == "demon" and t != null:
        b.add_theme_stylebox_override("normal", _tex_box(t, Color(1, 1, 1)))
        b.add_theme_stylebox_override("hover", _tex_box(t, Color(1.4, 1.25, 1.5)))
        b.add_theme_stylebox_override("pressed", _tex_box(t, Color(0.65, 0.65, 0.65)))
        b.add_theme_stylebox_override("disabled", _tex_box(t, Color(0.45, 0.45, 0.45, 0.85)))
    else:
        b.add_theme_stylebox_override("normal", flat_box(c["btn"], GOLD, 2))
        b.add_theme_stylebox_override("hover", flat_box(c["btn_hover"], GOLD, 2))
        b.add_theme_stylebox_override("pressed", flat_box(c["btn_down"], GOLD, 2))
        b.add_theme_stylebox_override("disabled", flat_box(c["btn"].darkened(0.15), c["sub"], 2))


## Art name for a shop item's icon.
## Every shop item has its OWN file: item_<id>.png (potions, skills) or
## item_<id>_<sword|spear|dagger>.png (weapons, one per class weapon).
static func item_art(item: Dictionary) -> String:
    var id: String = str(item["id"])
    if item["kind"] == "weapon":
        return "item_%s_%s" % [id, str(GameData.CLASSES[Game.class_id]["weapon"])]
    return "item_" + id


## A small framed tile with an icon inside (the "item frame").
static func icon_tile(art_name: String, look: String, px: float) -> Control:
    var c: Dictionary = colors(look)
    var root := Control.new()
    root.custom_minimum_size = Vector2(px, px)
    var bg := Panel.new()
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.add_theme_stylebox_override("panel", flat_box(c["tile"], GOLD, 2))
    root.add_child(bg)
    var t: Texture2D = Art.tex(art_name)
    if t != null:
        var tr := TextureRect.new()
        tr.texture = t
        tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 5)
        tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        root.add_child(tr)
    else:
        var q := Label.new()
        q.text = "?"
        q.add_theme_color_override("font_color", GOLD)
        q.add_theme_font_size_override("font_size", 26)
        q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        q.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        root.add_child(q)
    return root


## The large picture shown on the left side of a shop window.
static func figure(slot: String, look: String, size: Vector2) -> Control:
    var t: Texture2D = Art.tex(slot)
    if t != null:
        var tr := TextureRect.new()
        tr.texture = t
        tr.custom_minimum_size = size
        tr.size = size
        tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        return tr
    var c: Dictionary = colors(look)
    var root := Control.new()
    root.custom_minimum_size = size
    root.size = size
    var bg := Panel.new()
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.add_theme_stylebox_override("panel", flat_box(c["tile"], GOLD, 4))
    root.add_child(bg)
    # Simple hooded-figure fallback if the portrait image is unavailable.
    var body := ColorRect.new()
    body.color = c["btn"]
    body.size = Vector2(size.x * 0.46, size.y * 0.36)
    body.position = Vector2(size.x * 0.27, size.y * 0.50)
    root.add_child(body)
    var head := ColorRect.new()
    head.color = c["btn_down"]
    head.size = Vector2(size.x * 0.28, size.y * 0.26)
    head.position = Vector2(size.x * 0.36, size.y * 0.22)
    root.add_child(head)
    return root


## Gold frame drawn on top of an HP bar. Returns null if the art is missing.
static func bar_frame(size: Vector2, slot: String = "player") -> NinePatchRect:
    var t: Texture2D = Art.tex("ui_hpbar_" + slot)
    if t == null:
        return null
    var np := NinePatchRect.new()
    np.texture = t
    np.draw_center = false
    np.patch_margin_left = 30
    np.patch_margin_right = 30
    np.patch_margin_top = 14
    np.patch_margin_bottom = 14
    np.size = size
    np.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return np
