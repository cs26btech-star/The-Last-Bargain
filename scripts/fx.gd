class_name Fx
extends Node2D
## All particles, rings, slashes and floating numbers. Nothing here needs an image:
## every effect is drawn from code. Effects marked "add" use ADDITIVE blending, which
## makes them glow on the dark arena floor. This file also holds the hit-flash SHADER.
##
## Quick reference (used from enemy.gd and fight.gd):
##   puff / goo / glow_dots / sparks / coins   = bursts of particles
##   ring / crescent / streak / text           = shapes that expand and fade
##   player_slash / hit_impact / dmg_number / death_burst / skill_strike = ready-made combos

const FONT: Font = preload("res://fonts/EBGaramond.ttf")
const MAX_PARTS := 800

var parts: Array = []
var rings: Array = []
var slashes: Array = []
var streaks: Array = []
var texts: Array = []
var stars: Array = []
var glow: Node2D


## The hit-flash SHADER. "flash" 0..1 mixes the sprite toward "flash_color".
## Used for white hit flashes and for the coloured glow bosses get while winding up an attack.
static func flash_material() -> ShaderMaterial:
    var sh := Shader.new()
    sh.code = "shader_type canvas_item;\nuniform float flash : hint_range(0.0, 1.0) = 0.0;\nuniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);\nvoid fragment() {\n    vec4 c = COLOR;\n    COLOR = vec4(mix(c.rgb, flash_color.rgb, flash), c.a);\n}\n"
    var m := ShaderMaterial.new()
    m.shader = sh
    return m


func _ready() -> void:
    z_index = 20
    glow = Node2D.new()
    var mat := CanvasItemMaterial.new()
    mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    glow.material = mat
    add_child(glow)
    glow.draw.connect(_draw_glow)


# ------------------------------------------------------------------ primitives

func spawn(p: Vector2, v: Vector2, col: Color, life: float, size: float, add: bool = true,
        shape: String = "circle", drag: float = 2.0, grav: Vector2 = Vector2.ZERO) -> void:
    if parts.size() >= MAX_PARTS:
        return
    parts.append({"p": p, "v": v, "col": col, "life": life, "max": life, "size": size,
        "add": add, "shape": shape, "drag": drag, "g": grav, "spin": randf() * TAU})


func _emit(p: Vector2, col: Color, count: int, spd: float, life: float, size: float, add: bool,
        shape: String, dir: Vector2, spread: float, drag: float) -> void:
    for i in count:
        var ang: float = randf() * TAU
        if dir != Vector2.ZERO:
            ang = dir.angle() + randf_range(-spread, spread)
        var s: float = spd * randf_range(0.35, 1.0)
        var l: float = life * randf_range(0.6, 1.2)
        spawn(p, Vector2.RIGHT.rotated(ang) * s, col, l, size * randf_range(0.6, 1.2), add, shape, drag)


## Soft smoke / dust (normal blending, grows while fading).
func puff(p: Vector2, col: Color, count: int = 8, spd: float = 120.0, life: float = 0.5, size: float = 7.0) -> void:
    _emit(p, col, count, spd, life, size, false, "smoke", Vector2.ZERO, PI, 3.0)


## Solid droplets (slime goo, debris).
func goo(p: Vector2, col: Color, count: int = 10, spd: float = 260.0, dir: Vector2 = Vector2.ZERO,
        spread: float = PI, size: float = 7.0) -> void:
    _emit(p, col, count, spd, 0.6, size, false, "circle", dir, spread, 3.0)


## Glowing dots.
func glow_dots(p: Vector2, col: Color, count: int = 10, spd: float = 160.0, life: float = 0.5, size: float = 5.0) -> void:
    _emit(p, col, count, spd, life, size, true, "circle", Vector2.ZERO, PI, 2.5)


## Glowing streak sparks. Give dir + spread for a cone, leave dir empty for all directions.
func sparks(p: Vector2, col: Color, count: int = 10, spd: float = 320.0, dir: Vector2 = Vector2.ZERO,
        spread: float = PI, life: float = 0.3, size: float = 3.0) -> void:
    _emit(p, col, count, spd, life, size, true, "line", dir, spread, 4.0)


## Spinning gold coins (the Storekeeper's thing).
func coins(p: Vector2, count: int = 6, spd: float = 260.0, dir: Vector2 = Vector2.ZERO, spread: float = PI) -> void:
    _emit(p, Color(1.0, 0.8, 0.2), count, spd, 0.8, 8.0, false, "coin", dir, spread, 1.5)


func ring(p: Vector2, r0: float, r1: float, dur: float, col: Color, width: float = 6.0, add: bool = true) -> void:
    rings.append({"p": p, "r0": r0, "r1": r1, "life": dur, "max": dur, "col": col, "w": width, "add": add})


## A curved slash. ang = middle direction, half = half the arc (radians), r = radius.
func crescent(p: Vector2, ang: float, half: float, r: float, dur: float, col: Color,
        thick: float = 18.0, delay: float = 0.0, add: bool = true) -> void:
    slashes.append({"p": p, "ang": ang, "half": half, "r": r, "life": dur, "max": dur,
        "col": col, "thick": thick, "delay": delay, "add": add})


func streak(a: Vector2, b: Vector2, dur: float, col: Color, width: float = 8.0, add: bool = true) -> void:
    streaks.append({"a": a, "b": b, "life": dur, "max": dur, "col": col, "w": width, "add": add})


## A starburst (the classic fighting-game hit spark). It pops out fast and fades.
func star(p: Vector2, r: float, dur: float, col: Color, points: int = 8, rot: float = 0.0, add: bool = true) -> void:
    stars.append({"p": p, "r": r, "life": dur, "max": dur, "col": col, "n": points, "rot": rot, "add": add})


func text(p: Vector2, txt: String, col: Color, size: int = 28) -> void:
    texts.append({"p": p, "txt": txt, "life": 0.8, "max": 0.8, "col": col, "size": size})


# ------------------------------------------------------------------ ready-made combos

## The player's weapon swing. Sword = wide crescent, spear = thrust streak,
## dagger = two quick cuts, hands = small shock ring.
## hit = false is a MISS (whiff): the swing is drawn thin and pale, with no sparks, like in old fighting games.
## side alternates -1 / +1 so sword and dagger cuts go back and forth.
func player_slash(pos: Vector2, aim: Vector2, wtype: String, reach: float, arc_deg: float, col: Color,
        hit: bool = true, side: float = 1.0) -> void:
    var ang: float = aim.angle()
    var k: float = 1.0 if hit else 0.42          # strength of the swing trail
    var th: float = 1.0 if hit else 0.55         # thickness
    var bright: Color = col.lightened(0.55)
    bright.a = k
    var white := Color(1, 1, 1, 0.95 * k)
    if not hit:
        bright = Color(0.82, 0.86, 0.95, 0.42)
    match wtype:
        "spear":
            var a: Vector2 = pos + aim * 18.0
            var b: Vector2 = pos + aim * reach
            streak(a, b, 0.18, Color(bright.r, bright.g, bright.b, 0.55 * k), 16.0 * th)
            streak(a, b, 0.12, white, 5.0 * th)
            # speed lines either side of the thrust
            var n: Vector2 = aim.orthogonal()
            streak(a + n * 10.0, b - aim * 20.0 + n * 12.0, 0.14, Color(1, 1, 1, 0.5 * k), 2.0)
            streak(a - n * 10.0, b - aim * 20.0 - n * 12.0, 0.14, Color(1, 1, 1, 0.5 * k), 2.0)
            if hit:
                glow_dots(b, bright, 4, 90.0, 0.2, 6.0)
                sparks(b, bright, 6, 260.0, aim, 0.5, 0.22)
        "dagger":
            var half: float = deg_to_rad(arc_deg) * 0.85
            crescent(pos, ang - 0.30 * side, half, reach * 0.9, 0.14, bright, 12.0 * th)
            crescent(pos, ang + 0.30 * side, half, reach * 0.8, 0.14, white, 9.0 * th, 0.05)
            if hit:
                sparks(pos + aim * reach * 0.8, bright, 4, 200.0, aim, 0.6, 0.18)
        "hands":
            ring(pos + aim * 32.0, 6.0, 38.0, 0.16, bright, 4.0 * th)
            puff(pos + aim * 30.0, Color(0.9, 0.8, 0.7, 0.6), 3, 60.0, 0.25, 5.0)
        _:
            var half2: float = deg_to_rad(arc_deg)
            crescent(pos, ang + 0.15 * side, half2, reach * 0.95, 0.20, bright, 24.0 * th)
            crescent(pos, ang + 0.15 * side, half2 * 0.9, reach * 0.8, 0.14, white, 10.0 * th, 0.02)
            if hit:
                sparks(pos + aim * reach * 0.85, bright, 5, 240.0, aim, 0.7, 0.2)
    if not hit:
        # wind puffs: the swing met nothing
        puff(pos + aim * reach * 0.7, Color(0.8, 0.82, 0.9, 0.45), 3, 70.0, 0.3, 5.0)


## When a player hit lands. from_dir = direction the hit travelled.
func hit_impact(pos: Vector2, from_dir: Vector2, col: Color, big: bool = false) -> void:
    var bright: Color = col.lightened(0.5)
    var n: int = 16 if big else 9
    # classic fighting-game hit spark: coloured starburst + white core + speed lines
    var rot: float = randf() * PI
    star(pos, 100.0 if big else 64.0, 0.22, Color(bright.r, bright.g, bright.b, 0.85), 8, rot)
    star(pos, 60.0 if big else 38.0, 0.15, Color(1, 1, 1, 1.0), 8, rot + 0.2)
    var lines: int = 10 if big else 6
    for i in range(lines):
        var d: Vector2 = Vector2.RIGHT.rotated(rot + float(i) * TAU / float(lines))
        streak(pos + d * 24.0, pos + d * randf_range(54.0, 92.0 if big else 70.0), 0.15, Color(1, 1, 1, 0.9), 3.5)
    sparks(pos, bright, n, 380.0, from_dir, 0.9, 0.28)
    glow_dots(pos, Color(1, 1, 1, 0.9), 3, 60.0, 0.16, 10.0 if big else 7.0)
    ring(pos, 4.0, 56.0 if big else 36.0, 0.22, bright, 5.0)
    var perp: Vector2 = from_dir.orthogonal() * (26.0 if big else 18.0)
    streak(pos - perp, pos + perp, 0.1, Color(1, 1, 1, 0.9), 5.0)


## The player dodged a hit.
func dodge(pos: Vector2) -> void:
    ring(pos, 10.0, 62.0, 0.3, Color(0.7, 0.9, 1.0), 4.0)
    sparks(pos, Color(0.8, 0.95, 1.0), 6, 220.0)
    text(pos + Vector2(0.0, -44.0), "DODGE", Color(0.7, 0.92, 1.0), 22)


func dmg_number(pos: Vector2, amount: float, col: Color, size: int = 26) -> void:
    var jitter := Vector2(randf_range(-14.0, 14.0), randf_range(-6.0, 6.0))
    text(pos + jitter, str(int(round(amount))), col, size)


## Something got hurt: sparks + red number.
func player_hurt(pos: Vector2, amount: float) -> void:
    sparks(pos, Color(1.0, 0.25, 0.2), 14, 340.0)
    glow_dots(pos, Color(1.0, 0.3, 0.25), 6, 140.0, 0.35, 8.0)
    ring(pos, 6.0, 52.0, 0.25, Color(1.0, 0.3, 0.25), 6.0)
    dmg_number(pos + Vector2(0, -34), amount, Color(1.0, 0.35, 0.3), 30)


func death_burst(pos: Vector2, col: Color, big: bool) -> void:
    var bright: Color = col.lightened(0.4)
    ring(pos, 10.0, 170.0 if big else 90.0, 0.55, bright, 9.0)
    ring(pos, 6.0, 110.0 if big else 60.0, 0.4, Color(1, 1, 1), 4.0)
    puff(pos, col, 24 if big else 10, 260.0, 0.8, 11.0)
    sparks(pos, bright, 30 if big else 12, 460.0)
    glow_dots(pos, bright, 16 if big else 6, 300.0, 0.7, 8.0)


## Skills (hellfire, judgement, ...) striking something.
func skill_strike(pos: Vector2, col: Color, big: bool) -> void:
    ring(pos, 10.0, 170.0 if big else 95.0, 0.45, col, 9.0)
    ring(pos, 4.0, 100.0 if big else 55.0, 0.3, Color(1, 1, 1), 4.0)
    glow_dots(pos, col, 20, 320.0, 0.6, 7.0)
    sparks(pos, Color(1, 1, 1), 16, 440.0)
    puff(pos, col, 10, 170.0, 0.6, 9.0)


# ------------------------------------------------------------------ update

func _process(delta: float) -> void:
    for q in parts:
        q["life"] = float(q["life"]) - delta
        var v: Vector2 = q["v"]
        var g: Vector2 = q["g"]
        v += g * delta
        v *= maxf(0.0, 1.0 - float(q["drag"]) * delta)
        q["v"] = v
        var pp: Vector2 = q["p"]
        q["p"] = pp + v * delta
        q["spin"] = float(q["spin"]) + delta * 14.0
    for r in rings:
        r["life"] = float(r["life"]) - delta
    for s in slashes:
        if float(s["delay"]) > 0.0:
            s["delay"] = float(s["delay"]) - delta
        else:
            s["life"] = float(s["life"]) - delta
    for s in streaks:
        s["life"] = float(s["life"]) - delta
    for st in stars:
        st["life"] = float(st["life"]) - delta
    for t in texts:
        t["life"] = float(t["life"]) - delta
        var tp: Vector2 = t["p"]
        t["p"] = tp + Vector2(0.0, -42.0) * delta
    parts = parts.filter(func(q): return float(q["life"]) > 0.0)
    rings = rings.filter(func(r): return float(r["life"]) > 0.0)
    slashes = slashes.filter(func(s): return float(s["life"]) > 0.0)
    streaks = streaks.filter(func(s): return float(s["life"]) > 0.0)
    texts = texts.filter(func(t): return float(t["life"]) > 0.0)
    stars = stars.filter(func(s): return float(s["life"]) > 0.0)
    queue_redraw()
    glow.queue_redraw()


# ------------------------------------------------------------------ drawing

func _draw() -> void:
    _draw_all(self, false)
    for t in texts:
        var a: float = clampf(float(t["life"]) / float(t["max"]) * 1.6, 0.0, 1.0)
        var col: Color = t["col"]
        var p: Vector2 = t["p"] - Vector2(60.0, 0.0)
        var sz: int = int(t["size"])
        draw_string_outline(FONT, p, str(t["txt"]), HORIZONTAL_ALIGNMENT_CENTER, 120.0, sz, 6, Color(0, 0, 0, a * 0.9))
        draw_string(FONT, p, str(t["txt"]), HORIZONTAL_ALIGNMENT_CENTER, 120.0, sz, Color(col.r, col.g, col.b, a))


func _draw_glow() -> void:
    _draw_all(glow, true)


func _draw_all(ci: CanvasItem, want_add: bool) -> void:
    for q in parts:
        if bool(q["add"]) == want_add:
            _draw_part(ci, q)
    for r in rings:
        if bool(r["add"]) == want_add:
            var t: float = 1.0 - clampf(float(r["life"]) / float(r["max"]), 0.0, 1.0)
            var e: float = 1.0 - pow(1.0 - t, 3.0)
            var rad: float = lerpf(float(r["r0"]), float(r["r1"]), e)
            var col: Color = r["col"]
            var w: float = float(r["w"])
            var p: Vector2 = r["p"]
            ci.draw_arc(p, rad, 0.0, TAU, 56, Color(col.r, col.g, col.b, col.a * (1.0 - t) * 0.28), w * 2.4)
            ci.draw_arc(p, rad, 0.0, TAU, 56, Color(col.r, col.g, col.b, col.a * (1.0 - t)), maxf(1.0, w * (1.0 - t * 0.6)))
    for s in slashes:
        if bool(s["add"]) == want_add and float(s["delay"]) <= 0.0:
            _draw_crescent(ci, s)
    for st in stars:
        if bool(st["add"]) == want_add:
            var ts: float = 1.0 - clampf(float(st["life"]) / float(st["max"]), 0.0, 1.0)
            var es: float = 1.0 - pow(1.0 - ts, 3.0)
            var rr: float = float(st["r"]) * (0.35 + 0.65 * es)
            var sc: Color = st["col"]
            var npt: int = int(st["n"])
            var spts := PackedVector2Array()
            for i in range(npt * 2):
                var ang: float = float(st["rot"]) + float(i) * PI / float(npt)
                var rad: float = rr if i % 2 == 0 else rr * 0.34
                spts.append((st["p"] as Vector2) + Vector2.RIGHT.rotated(ang) * rad)
            ci.draw_colored_polygon(spts, Color(sc.r, sc.g, sc.b, sc.a * (1.0 - ts * ts)))
    for s in streaks:
        if bool(s["add"]) == want_add:
            var t2: float = clampf(float(s["life"]) / float(s["max"]), 0.0, 1.0)
            var c2: Color = s["col"]
            ci.draw_line(s["a"], s["b"], Color(c2.r, c2.g, c2.b, c2.a * t2), maxf(1.0, float(s["w"]) * t2))


func _draw_part(ci: CanvasItem, q: Dictionary) -> void:
    var t: float = clampf(float(q["life"]) / float(q["max"]), 0.0, 1.0)
    var col: Color = q["col"]
    var c := Color(col.r, col.g, col.b, col.a * t)
    var p: Vector2 = q["p"]
    var sz: float = float(q["size"])
    match str(q["shape"]):
        "line":
            var v: Vector2 = q["v"]
            var d: Vector2 = v.normalized() * (sz * 2.5 + v.length() * 0.05)
            ci.draw_line(p, p - d, c, maxf(1.5, sz * 0.6))
        "coin":
            var w: float = maxf(0.2, absf(cos(float(q["spin"]))))
            ci.draw_set_transform(p, 0.0, Vector2(w, 1.0))
            ci.draw_circle(Vector2.ZERO, sz, c)
            ci.draw_arc(Vector2.ZERO, sz, 0.0, TAU, 12, Color(1.0, 0.95, 0.6, c.a), 1.5)
            ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
        "smoke":
            ci.draw_circle(p, sz * (1.0 + (1.0 - t) * 1.6), Color(col.r, col.g, col.b, col.a * t * 0.55))
        _:
            ci.draw_circle(p, sz * (0.4 + 0.6 * t), c)


func _draw_crescent(ci: CanvasItem, s: Dictionary) -> void:
    var t: float = 1.0 - clampf(float(s["life"]) / float(s["max"]), 0.0, 1.0)
    var col: Color = s["col"]
    var p: Vector2 = s["p"]
    var half: float = float(s["half"])
    var r_out: float = float(s["r"]) * (1.0 + 0.12 * t)
    var thick: float = float(s["thick"]) * (1.0 - 0.5 * t)
    var a0: float = float(s["ang"]) - half
    var span: float = 2.0 * half * clampf(t * 5.0 + 0.15, 0.05, 1.0)
    var steps: int = 14
    var pts := PackedVector2Array()
    for i in range(steps + 1):
        var u: float = float(i) / float(steps)
        pts.append(p + Vector2.RIGHT.rotated(a0 + span * u) * r_out)
    for i in range(steps, -1, -1):
        var u2: float = float(i) / float(steps)
        pts.append(p + Vector2.RIGHT.rotated(a0 + span * u2) * (r_out - thick * sin(PI * u2)))
    ci.draw_colored_polygon(pts, Color(col.r, col.g, col.b, col.a * (1.0 - t)))
