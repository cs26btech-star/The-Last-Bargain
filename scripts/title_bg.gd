class_name TitleBg
extends Control
## The animated backdrop of the title screen, drawn entirely from code:
## night sky, torch-lit colosseum arches, a glowing arena floor with turning runes,
## the two beacons, rising embers and drifting coins.

const W := 1280.0
const H := 720.0

var t: float = 0.0
var embers: Array = []
var coins: Array = []


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    for i in range(70):
        embers.append({"x": randf() * W, "y": randf() * H, "s": randf_range(18.0, 60.0),
            "r": randf_range(1.2, 3.6), "ph": randf() * TAU, "gold": randf() < 0.5})
    for i in range(9):
        coins.append({"x": randf() * W, "y": randf() * H, "v": randf_range(22.0, 50.0),
            "ph": randf() * TAU, "sz": randf_range(7.0, 13.0)})


func _process(delta: float) -> void:
    t += delta
    for e in embers:
        e["y"] = float(e["y"]) - float(e["s"]) * delta
        if float(e["y"]) < -10.0:
            e["y"] = H + 10.0
            e["x"] = randf() * W
    for c in coins:
        c["y"] = float(c["y"]) + float(c["v"]) * delta
        if float(c["y"]) > H + 20.0:
            c["y"] = -20.0
            c["x"] = randf() * W
    queue_redraw()


func _draw() -> void:
    # night sky
    var top := Color(0.035, 0.025, 0.07)
    var bot := Color(0.16, 0.08, 0.17)
    draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, H), Vector2(0, H)]),
        PackedColorArray([top, top, bot, bot]))
    # soft glow behind the title
    for i in range(9):
        draw_circle(Vector2(W * 0.5, 215.0), 470.0 - float(i) * 48.0, Color(0.75, 0.25, 0.33, 0.022))
    draw_circle(Vector2(W * 0.5, 215.0), 150.0, Color(0.95, 0.75, 0.35, 0.035 + 0.01 * sin(t * 1.5)))
    _draw_wall()
    _draw_floor()
    _draw_beacon(Vector2(170.0, 520.0), "beacon_demon", Color(0.8, 0.2, 0.45))
    _draw_beacon(Vector2(1110.0, 520.0), "beacon_angel", Color(1.0, 0.85, 0.45))
    # embers
    for e in embers:
        var col := Color(1.0, 0.82, 0.4) if bool(e["gold"]) else Color(1.0, 0.32, 0.3)
        var a: float = 0.25 + 0.4 * (0.5 + 0.5 * sin(t * 3.0 + float(e["ph"])))
        var p := Vector2(float(e["x"]) + sin(t * 0.8 + float(e["ph"])) * 14.0, float(e["y"]))
        draw_circle(p, float(e["r"]) * 2.6, Color(col.r, col.g, col.b, a * 0.18))
        draw_circle(p, float(e["r"]), Color(col.r, col.g, col.b, a))
    # drifting coins
    for c in coins:
        var p2 := Vector2(float(c["x"]) + sin(t * 0.6 + float(c["ph"])) * 30.0, float(c["y"]))
        var w: float = maxf(0.15, absf(cos(t * 3.0 + float(c["ph"]))))
        draw_set_transform(p2, 0.0, Vector2(w, 1.0))
        draw_circle(Vector2.ZERO, float(c["sz"]), Color(0.95, 0.75, 0.2, 0.55))
        draw_arc(Vector2.ZERO, float(c["sz"]), 0.0, TAU, 14, Color(1.0, 0.93, 0.6, 0.7), 1.5)
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    _draw_vignette()
    _draw_frame()


## Row of dark arches with a few warm torches.
func _draw_wall() -> void:
    draw_rect(Rect2(0.0, 430.0, W, 290.0), Color(0.065, 0.045, 0.085))
    draw_rect(Rect2(0.0, 424.0, W, 8.0), Color(0.16, 0.11, 0.17))
    for i in range(12):
        var cx: float = 58.0 + float(i) * 106.0
        draw_rect(Rect2(cx - 32.0, 470.0, 64.0, 90.0), Color(0.025, 0.015, 0.04))
        draw_circle(Vector2(cx, 470.0), 32.0, Color(0.025, 0.015, 0.04))
        if i % 3 == 1:
            var f: float = 0.6 + 0.4 * sin(t * 7.0 + float(i) * 1.7)
            draw_circle(Vector2(cx, 505.0), 34.0, Color(1.0, 0.5, 0.15, 0.05 * f))
            draw_circle(Vector2(cx, 505.0), 14.0, Color(1.0, 0.6, 0.2, 0.12 * f))
            draw_circle(Vector2(cx, 505.0), 4.0, Color(1.0, 0.85, 0.5, 0.8 * f))


## Elliptical arena floor with gold rings and slowly turning rune marks.
func _draw_floor() -> void:
    var c := Vector2(W * 0.5, 655.0)
    draw_set_transform(c, 0.0, Vector2(1.0, 0.2))
    draw_circle(Vector2.ZERO, 600.0, Color(0.09, 0.06, 0.1))
    draw_circle(Vector2.ZERO, 560.0, Color(0.15, 0.11, 0.15))
    draw_circle(Vector2.ZERO, 540.0, Color(0.1, 0.07, 0.11))
    draw_arc(Vector2.ZERO, 560.0, 0.0, TAU, 96, Color(0.85, 0.65, 0.3, 0.7), 5.0)
    draw_arc(Vector2.ZERO, 430.0, 0.0, TAU, 96, Color(0.7, 0.3, 0.4, 0.45), 4.0)
    draw_arc(Vector2.ZERO, 300.0, 0.0, TAU, 96, Color(0.85, 0.65, 0.3, 0.35), 3.0)
    for i in range(36):
        var a: float = t * 0.12 + float(i) * TAU / 36.0
        var d := Vector2.RIGHT.rotated(a)
        draw_line(d * 535.0, d * 556.0, Color(0.95, 0.75, 0.4, 0.55), 4.0)
    for i in range(12):
        var a2: float = -t * 0.2 + float(i) * TAU / 12.0
        var d2 := Vector2.RIGHT.rotated(a2)
        draw_line(d2 * 420.0, d2 * 440.0, Color(0.9, 0.4, 0.5, 0.5), 4.0)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_beacon(pos: Vector2, art_name: String, glow: Color) -> void:
    var pulse: float = 0.5 + 0.5 * sin(t * 2.0 + pos.x)
    for i in range(6):
        draw_circle(pos + Vector2(0.0, -60.0), 170.0 - float(i) * 26.0, Color(glow.r, glow.g, glow.b, 0.03 + 0.012 * float(i) + 0.012 * pulse))
    draw_rect(Rect2(pos.x - 52.0, pos.y + 88.0, 104.0, 20.0), Color(0.09, 0.06, 0.11))
    draw_rect(Rect2(pos.x - 52.0, pos.y + 88.0, 104.0, 20.0), Color(0.72, 0.54, 0.28), false, 2.0)
    Art.draw_sprite(self, art_name, pos + Vector2(0.0, sin(t * 1.6 + pos.x) * 4.0), Vector2(120.0, 200.0), glow)


func _draw_vignette() -> void:
    var dark := Color(0, 0, 0, 0.7)
    var clear := Color(0, 0, 0, 0.0)
    draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(260, 0), Vector2(260, H), Vector2(0, H)]), PackedColorArray([dark, clear, clear, dark]))
    draw_polygon(PackedVector2Array([Vector2(W - 260.0, 0), Vector2(W, 0), Vector2(W, H), Vector2(W - 260.0, H)]), PackedColorArray([clear, dark, dark, clear]))
    draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, 150), Vector2(0, 150)]), PackedColorArray([dark, dark, clear, clear]))
    draw_polygon(PackedVector2Array([Vector2(0, H - 120.0), Vector2(W, H - 120.0), Vector2(W, H), Vector2(0, H)]), PackedColorArray([clear, clear, dark, dark]))


## Double gold-and-crimson frame with diamonds in the corners.
func _draw_frame() -> void:
    draw_rect(Rect2(18, 18, W - 36.0, H - 36.0), Color(0.85, 0.65, 0.3, 0.55), false, 2.0)
    draw_rect(Rect2(26, 26, W - 52.0, H - 52.0), Color(0.72, 0.2, 0.28, 0.4), false, 1.0)
    for p in [Vector2(18, 18), Vector2(W - 18.0, 18), Vector2(18, H - 18.0), Vector2(W - 18.0, H - 18.0)]:
        draw_colored_polygon(PackedVector2Array([p + Vector2(0, -9), p + Vector2(9, 0), p + Vector2(0, 9), p + Vector2(-9, 0)]), Color(0.9, 0.7, 0.35, 0.9))
