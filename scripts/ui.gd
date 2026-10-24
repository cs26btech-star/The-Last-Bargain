class_name UI
extends RefCounted
## Small helpers to build menus from code.

const MYTHIC_FONT: Font = preload("res://fonts/EBGaramond.ttf")


static func label(text: String, size: int = 20, color: Color = Color.WHITE) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_override("font", MYTHIC_FONT)
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    return l


static func wrap(l: Label) -> Label:
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return l


static func button(text: String, cb: Callable, size: int = 20) -> Button:
    var b := Button.new()
    b.text = text
    b.add_theme_font_override("font", MYTHIC_FONT)
    b.add_theme_font_override("font_hover", MYTHIC_FONT)
    b.add_theme_font_override("font_pressed", MYTHIC_FONT)
    b.add_theme_font_size_override("font_size", size)
    b.focus_mode = Control.FOCUS_NONE
    b.pressed.connect(func(): AudioManager.play_click())
    b.pressed.connect(cb)
    return b


static func panel(color: Color = Color(0.12, 0.12, 0.18, 1.0)) -> PanelContainer:
    var p := PanelContainer.new()
    var sb := StyleBoxFlat.new()
    sb.bg_color = color
    sb.border_color = Color("b83245")
    sb.set_border_width_all(2)
    sb.set_content_margin_all(12)
    p.add_theme_stylebox_override("panel", sb)
    return p


static func clear(node: Node) -> void:
    for c in node.get_children():
        node.remove_child(c)
        c.queue_free()
