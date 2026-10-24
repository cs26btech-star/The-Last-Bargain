class_name Player
extends Node2D

const SWING_T := 0.18               # how long an attack animation lasts
## The player. The Fight node tells it what to do; it handles movement and drawing.

var max_hp: float = 100.0
var hp: float = 100.0
var speed_stat: float = 10.0
var move_px: float = 150.0
var ring_c: Vector2 = Vector2.ZERO
var ring_r: float = 300.0
var radius: float = 24.0
var roll_time: float = 0.0
var roll_cd: float = 0.0
var roll_dir: Vector2 = Vector2.RIGHT
var atk_cd: float = 0.0
var swing_time: float = 0.0
var swing_dir: Vector2 = Vector2.RIGHT
var swing_reach: float = 80.0
var invuln: float = 0.0
var shield: bool = false
var aim: Vector2 = Vector2.RIGHT
var walk_t: float = 0.0
var moving: bool = false
var frozen: bool = false
var tint: Color = Color(0.3, 0.5, 1.0)
var weapon_art: String = ""
var weapon_tint: Color = Color.WHITE
var weapon_len: float = 40.0
var hit_flash: float = 0.0
var swing_side: float = 1.0             # flips every attack so cuts go back and forth
var mat: ShaderMaterial


func _ready() -> void:
    # Hit-flash shader: the whole character flashes red-white for a moment when hurt.
    mat = Fx.flash_material()
    mat.set_shader_parameter("flash_color", Color(1.0, 0.45, 0.45))
    material = mat


func tick(delta: float) -> void:
    atk_cd = maxf(0.0, atk_cd - delta)
    roll_cd = maxf(0.0, roll_cd - delta)
    invuln = maxf(0.0, invuln - delta)
    swing_time = maxf(0.0, swing_time - delta)
    hit_flash = maxf(0.0, hit_flash - delta)
    mat.set_shader_parameter("flash", clampf(hit_flash / 0.18, 0.0, 1.0) * 0.8)
    # blink while invulnerable after a hit
    modulate.a = 0.5 if (invuln > 0.0 and int(invuln * 20.0) % 2 == 0) else 1.0
    if frozen:
        queue_redraw()
        return
    var input: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    moving = input != Vector2.ZERO
    if roll_time > 0.0:
        roll_time -= delta
        position += roll_dir * maxf(move_px * 3.0, 380.0) * delta
    else:
        position += input * move_px * delta
    var off: Vector2 = position - ring_c
    var lim: float = ring_r - radius
    if off.length() > lim:
        position = ring_c + off.limit_length(lim)
    if moving:
        walk_t += delta * 8.0
    queue_redraw()


func try_roll() -> void:
    if Game.is_sold("dodge") or roll_cd > 0.0 or roll_time > 0.0 or frozen:
        return
    var input: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    roll_dir = input.normalized() if input != Vector2.ZERO else aim
    roll_time = 0.25
    roll_cd = 1.0


func _draw() -> void:
    # If a custom class pose exists, it includes the held weapon; otherwise use the old separate weapon sprite.
    var pose_state := "attack" if swing_time > 0.0 else ("walk" if moving else "idle")
    var class_pose_name := str(Game.class_id) + "_" + pose_state
    var has_custom_pose: bool = Art.tex(class_pose_name) != null
    var is_spear: bool = weapon_art.find("spear") >= 0
    var is_dagger: bool = weapon_art.find("dagger") >= 0
    # --- attack animation. k runs 0 -> 1 during the swing.
    var swinging: bool = swing_time > 0.0
    var k: float = 0.0
    var a: Vector2 = aim
    if swinging:
        k = 1.0 - swing_time / SWING_T
        a = swing_dir                      # keep the direction the attack was made in
    var push: float = 0.0                  # how far the weapon slides forward
    var rot_off: float = 0.0               # how far the weapon is turned
    var lunge := Vector2.ZERO              # how far the BODY steps forward
    if swinging:
        if is_spear:
            # LUNGE: pull back, then thrust forward hard, then recover
            if k < 0.25:
                push = lerpf(0.0, -10.0, k / 0.25)
            elif k < 0.55:
                push = lerpf(-10.0, 30.0, (k - 0.25) / 0.3)
            else:
                push = lerpf(30.0, 0.0, (k - 0.55) / 0.45)
            lunge = a * maxf(push, 0.0) * 0.8
        else:
            # SLASH: the blade sweeps across in a wide arc, a different way each time
            var e: float = k * k * (3.0 - 2.0 * k)
            var span: float = 1.1 if is_dagger else 1.6
            rot_off = swing_side * lerpf(-span, span, e)
            push = sin(k * PI) * (8.0 if is_dagger else 3.0)
            lunge = a * sin(k * PI) * (11.0 if is_dagger else 7.0)
    if weapon_art != "" and not frozen and not has_custom_pose:
        var wt: Texture2D = Art.tex(weapon_art)
        if wt != null:
            # Fit the weapon to the character's hand instead of drawing the PNG at
            # its raw resolution (which made it look like a floating giant weapon).
            var blade_len: float = clampf(weapon_len, 30.0, 52.0)
            var blade_width: float = 15.0 if is_spear else 19.0
            # fading afterimages of the blade while it sweeps
            if swinging and not is_spear:
                for g in range(1, 4):
                    var kk: float = maxf(k - float(g) * 0.09, 0.0)
                    var ee: float = kk * kk * (3.0 - 2.0 * kk)
                    var ro: float = swing_side * lerpf(-(1.1 if is_dagger else 1.6), (1.1 if is_dagger else 1.6), ee)
                    _draw_weapon(wt, a, 13.0 + push, ro, blade_width, blade_len, Color(weapon_tint.r, weapon_tint.g, weapon_tint.b, 0.28 / float(g)), lunge)
            _draw_weapon(wt, a, 13.0 + push, rot_off, blade_width, blade_len, weapon_tint, lunge)
        else:
            draw_line(lunge + a * 12.0, lunge + a * (12.0 + clampf(weapon_len, 30.0, 52.0) + push), weapon_tint, 5.0)
    # (the swing flash is drawn by the Fx node as a slash / thrust effect)
    # body
    if Game.is_sold("char_sprite"):
        draw_rect(Rect2(-32, -32, 64, 64), Color.WHITE)
    else:
        var art_name: String = class_pose_name if has_custom_pose else "player_idle"
        if not has_custom_pose and moving and int(walk_t) % 2 == 1:
            art_name = "player_walk"
        Art.draw_sprite(self, art_name, lunge, Vector2(76, 76), tint, a.x < 0.0)
    # effects
    if roll_time > 0.0:
        draw_circle(Vector2.ZERO, 36.0, Color(0.8, 0.9, 1.0, 0.22))
        draw_arc(Vector2.ZERO, 36.0, 0.0, TAU, 28, Color(0.8, 0.9, 1.0, 0.5), 3.0)
    if shield:
        draw_arc(Vector2.ZERO, 44.0, 0.0, TAU, 32, Color(0.6, 0.9, 1.0), 4.0)


func _draw_weapon(wt: Texture2D, a: Vector2, base: float, rot: float, wid: float, ln: float, col: Color, body_off: Vector2) -> void:
    draw_set_transform(body_off + a * base, a.angle() + PI / 2.0 + rot, Vector2.ONE)
    draw_texture_rect(wt, Rect2(-wid * 0.5, -ln * 0.72, wid, ln), false, col)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


