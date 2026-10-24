class_name Art
extends RefCounted
## Picture loader. Looks for a PNG in this order:
##   1. res://art_mine/<name>.png        YOUR drawings (put them here)
##   2. res://art_mine/<base name>.png   your drawing of the "base" picture (see ASSET_LIST.txt)
##   3. res://art/<name>.png             the old placeholder pictures
##   4. res://art/<base name>.png
## Anything missing is drawn as a coloured box or a placeholder, so the game always runs.
## To ship with NO placeholder art at all, delete the PNGs inside art/.

static var _cache: Dictionary = {}


## "Base" picture a slot falls back to, so you can draw ONE picture and it is used in every slot
## that shares it (until you draw a more specific file). Returns "" when there is no base.
static func fallback_name(n: String) -> String:
    if n.begins_with("item_"):
        for w in ["sword", "spear", "dagger"]:
            if n.ends_with("_" + w):
                return "held_" + w
        match n:
            "item_d_swift", "item_d_vital", "item_d_attack", "item_a_weak", "item_a_frail", "item_a_slow":
                return "icon_potion"
            "item_d_hellfire":
                return "icon_flame"
            "item_d_suppress":
                return "icon_crown"
            "item_d_judgement", "item_a_judgement":
                return "icon_gavel"
            "item_d_ultimate":
                return "icon_skull"
            "item_a_blessing":
                return "icon_halo"
            "item_a_protect":
                return "icon_shield"
            "item_a_ultimate":
                return "icon_wing"
        return ""
    # Keep character portraits, wing sprites, and beacons as distinct assets.
    # Never substitute a beacon for a character/wing image.
    if n == "figure_lore_archangel":
        return "figure_shop_angel"
    if n.begins_with("ui_panel_"):
        return "ui_panel"
    if n.begins_with("ui_button_"):
        return "ui_button"
    if n.begins_with("ui_hpbar_"):
        return "ui_hpbar"
    return ""


static func tex(art_name: String) -> Texture2D:
    if _cache.has(art_name):
        return _cache[art_name]
    var names: Array = [art_name]
    var fb: String = fallback_name(art_name)
    if fb != "":
        names.append(fb)
    var t: Texture2D = null
    for folder in ["art_mine", "art"]:
        for n in names:
            var path: String = "res://%s/%s.png" % [folder, n]
            if ResourceLoader.exists(path):
                t = load(path)
                break
        if t != null:
            break
    _cache[art_name] = t
    return t


## Draws a sprite centred on pos. Call only from inside a _draw() function.
static func draw_sprite(ci: CanvasItem, art_name: String, pos: Vector2, size: Vector2,
        placeholder: Color, flip: bool = false, tint: Color = Color.WHITE) -> void:
    var t: Texture2D = tex(art_name)
    if t != null:
        var rect := Rect2(pos - size / 2.0, size)
        if flip:
            rect = Rect2(pos + Vector2(size.x / 2.0, -size.y / 2.0), Vector2(-size.x, size.y))
        ci.draw_texture_rect(t, rect, false, tint)
    else:
        var r := Rect2(pos - size / 2.0, size)
        ci.draw_rect(r, placeholder)
        ci.draw_rect(r, Color.BLACK, false, 3.0)
