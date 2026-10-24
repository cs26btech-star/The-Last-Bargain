class_name Enemy
extends Node2D
## One script for every boss. The Fight node fills in the stats from GameData.BOSSES.
##
## Attack states:  chase -> windup -> (lunge | jump_up -> hang -> fall) -> cooldown -> chase
##  THE BOUNCER (slime)   : Goo Charge (lane) and Leap Slam (jumps into the air, then crashes down)
##  THE HUNGRY PACK       : Pounce (long) and Hooked Leap (short)
##  THE PICKPOCKET        : vanishes, reappears behind you, then Blink-Dash or Twin Slash
##  THE STOREKEEPER       : Coin Fan volley and Judgement Pulse
## Visual effects are made by the Fx node (scripts/fx.gd). Telegraphs are drawn in _draw().

const AIR_HEIGHT := 150.0

var kind: String = ""
var max_hp: float = 100.0
var hp: float = 100.0
var atk: float = 10.0
var speed_stat: float = 10.0
var move_px: float = 150.0
var radius: float = 40.0
var size: Vector2 = Vector2(128, 128)
var art_name: String = ""
var color: Color = Color.RED
var tint: Color = Color.WHITE
var windup_time: float = 0.5
var attack_range: float = 90.0
var base_cd: float = 1.2
var target: Player = null
var fight = null
var ring_c: Vector2 = Vector2.ZERO
var ring_r: float = 300.0
var dead: bool = false
var state: String = "chase"
var timer: float = 0.0
var slow_time: float = 0.0
var flash: float = 0.0
var lunge_dir: Vector2 = Vector2.ZERO
var lunge_hit: bool = false
var cycle_t: float = 0.0
var ghost: bool = false
var throw_t: float = 2.5
var attack_variant: int = 0
var combo_left: int = 0

# --- animation / effects state
var z: float = 0.0                      # height above the floor (slime leap)
var sc: Vector2 = Vector2.ONE           # squash and stretch
var anim_t: float = 0.0
var windup_total: float = 0.5
var lunge_mult: float = 3.0
var lunge_from: Vector2 = Vector2.ZERO
var slam_locked: bool = false
var tint_col: Color = Color.WHITE
var tint_amt: float = 0.0
var fx_acc: float = 0.0
var trail_acc: float = 0.0
var ghost_acc: float = 0.0
var trail: Array = []
var body: Node2D
var body_mat: ShaderMaterial
# --- phase 2 (below half health the boss ENRAGES)
var phase2: bool = false
var aura_t: float = 0.0
var volley2_t: float = -1.0
var vanish_at: float = 6.0
var appear_at: float = 9.0


func _ready() -> void:
    # The body is its own child node so the hit-flash SHADER only tints the sprite,
    # not the shadow and the telegraph shapes drawn underneath it.
    body = Node2D.new()
    body_mat = Fx.flash_material()
    body.material = body_mat
    add_child(body)
    body.draw.connect(_draw_body)


func is_airborne() -> bool:
    return z > 24.0


func take_damage(amount: float) -> void:
    if dead:
        return
    hp -= amount
    flash = 0.12
    if fight != null:
        fight.fx.dmg_number(position + Vector2(0.0, -size.y * 0.55), amount, Color(1.0, 0.96, 0.75))
    if target != null and (state == "chase" or state == "cooldown"):
        var away: Vector2 = (position - target.position).normalized()
        position += away * (12.0 if kind == "wolf" else 6.0)
    if hp <= 0.0:
        hp = 0.0
        dead = true
        visible = false
        if fight != null:
            AudioManager.play_sfx("boss_die", -2.0, 0.05)
            fight.fx.death_burst(position, _fx_col(), kind == "storekeeper" or kind == "bouncer")
            fight.shake(9.0 if kind == "storekeeper" or kind == "bouncer" else 3.0)
            if kind == "wolf":
                fight.on_wolf_defeated(self)


func _cooldown() -> float:
    # The boss table's cooldown is real seconds.
    return base_cd


## Main colour of each boss's effects.
func _fx_col() -> Color:
    match kind:
        "bouncer":
            return Color(0.30, 0.65, 1.0)
        "wolf":
            return Color(1.0, 0.28, 0.18)
        "pickpocket":
            return Color(0.75, 0.35, 1.0)
        "storekeeper":
            return Color(1.0, 0.78, 0.25)
    return Color(1, 1, 1)


## Lighter accent colour.
func _fx_col2() -> Color:
    match kind:
        "bouncer":
            return Color(0.78, 0.95, 1.0)
        "wolf":
            return Color(1.0, 0.62, 0.25)
        "pickpocket":
            return Color(1.0, 0.7, 1.0)
        "storekeeper":
            return Color(1.0, 0.95, 0.6)
    return Color(1, 1, 1)


## x = speed multiplier, y = duration of the lunge in seconds.
func _lunge_params() -> Vector2:
    if kind == "bouncer":
        return Vector2(4.0, 0.42)
    if kind == "wolf":
        return Vector2(3.0, 0.30 if attack_variant == 0 else 0.22)
    if kind == "pickpocket":
        return Vector2(6.0, 0.16)
    return Vector2(3.0, 0.3)


func _lunge_length() -> float:
    var lp: Vector2 = _lunge_params()
    return move_px * lp.x * lp.y


func _slam_radius() -> float:
    return attack_range * 1.5 + target.radius


func tick(delta: float) -> void:
    if dead:
        return
    anim_t += delta
    flash = maxf(0.0, flash - delta)
    slow_time = maxf(0.0, slow_time - delta)
    var spd: float = move_px * (0.5 if slow_time > 0.0 else 1.0)
    var to_p: Vector2 = target.position - position
    var dist: float = to_p.length()
    var dir: Vector2 = to_p.normalized()
    sc = sc.lerp(Vector2.ONE, 1.0 - exp(-10.0 * delta))
    tint_amt = maxf(0.0, tint_amt - delta * 4.0)

    if not phase2 and hp > 0.0 and hp <= max_hp * 0.5:
        _enrage()
    if phase2:
        _enraged_aura(delta)
    if volley2_t > 0.0:
        volley2_t -= delta
        if volley2_t <= 0.0:
            _second_volley()

    if kind == "pickpocket":
        _pickpocket_cycle(delta)

    match state:
        "chase":
            _tick_chase(delta, spd, dist, dir)
        "windup":
            _tick_windup(delta, dist, dir)
        "lunge":
            _tick_lunge(delta, spd)
        "jump_up", "hang", "fall":
            _tick_slam(delta, spd)
        "cooldown":
            timer -= delta
            if timer <= 0.0:
                state = "chase"

    var off: Vector2 = position - ring_c
    var lim: float = ring_r - radius * 0.5
    if off.length() > lim:
        position = ring_c + off.limit_length(lim)
    for t in trail:
        t["life"] = float(t["life"]) - delta
    trail = trail.filter(func(t): return float(t["life"]) > 0.0)
    _update_body_material()
    queue_redraw()
    body.queue_redraw()


## Half health: the boss gets angry. More damage, faster attacks, and a new trick.
func _enrage() -> void:
    phase2 = true
    atk *= 1.25
    base_cd *= 0.75
    windup_time *= 0.92
    move_px *= 1.12
    if kind == "pickpocket":
        vanish_at = 4.0
        appear_at = 6.5
    flash = 0.2
    var f = fight.fx
    if kind == "wolf":
        f.ring(position, 10.0, 80.0, 0.4, Color(1.0, 0.25, 0.2), 6.0)
        return
    f.ring(position, 20.0, 190.0, 0.6, Color(1.0, 0.25, 0.2), 10.0)
    f.ring(position, 8.0, 110.0, 0.4, Color(1.0, 0.8, 0.4), 5.0)
    f.sparks(position, Color(1.0, 0.5, 0.2), 24, 480.0)
    f.text(position + Vector2(0.0, -size.y * 0.7), "ENRAGED!", Color(1.0, 0.35, 0.3), 34)
    fight.shake(8.0)
    AudioManager.play_sfx("demon_skill", -4.0)


func _enraged_aura(delta: float) -> void:
    tint_col = Color(1.0, 0.3, 0.2)
    tint_amt = maxf(tint_amt, 0.14 + 0.06 * sin(anim_t * 6.0))
    aura_t += delta
    if aura_t >= 0.09:
        aura_t = 0.0
        fight.fx.spawn(position + Vector2(randf_range(-size.x * 0.4, size.x * 0.4), size.y * 0.3), Vector2(randf_range(-15.0, 15.0), randf_range(-90.0, -40.0)), Color(1.0, 0.35, 0.2), 0.6, 4.0, true, "circle", 1.0)


func _second_volley() -> void:
    # Storekeeper, phase 2: a second, offset volley aimed fresh at you
    var d: Vector2 = (target.position - position).normalized()
    for a in [-0.375, -0.225, -0.075, 0.075, 0.225, 0.375]:
        fight.spawn_projectile(position, d.rotated(a), atk * 0.5)
    AudioManager.play_sfx("coin_fire", -4.0)
    fight.fx.sparks(position + d * 40.0, _fx_col2(), 12, 400.0, d, 0.7, 0.3)
    fight.fx.ring(position, 10.0, 75.0, 0.28, _fx_col(), 6.0)


func _begin_windup(dir: Vector2) -> void:
    state = "windup"
    windup_total = windup_time
    if kind == "bouncer" and attack_variant == 1:
        windup_total = windup_time * 0.65   # the crouch; the leap itself adds more warning
    timer = windup_total
    lunge_dir = dir
    AudioManager.play_attack_cue(kind)


func _tick_chase(delta: float, spd: float, dist: float, dir: Vector2) -> void:
    if ghost:
        position += dir * spd * 1.3 * delta
        return
    if dist > radius + target.radius * 0.5:
        position += dir * spd * delta
    if kind == "storekeeper":
        throw_t -= delta
        if throw_t <= 0.0:
            throw_t = 2.65
            _begin_windup(dir)
    elif dist <= attack_range:
        _begin_windup(dir)


func _tick_windup(delta: float, dist: float, dir: Vector2) -> void:
    timer -= delta
    # Aim follows you, but locks for the last 0.2 s so a sidestep or roll works.
    if timer > 0.2:
        lunge_dir = dir
    var prog: float = 1.0 - clampf(timer / maxf(windup_total, 0.01), 0.0, 1.0)
    _windup_fx(delta, prog)
    if timer <= 0.0:
        _execute_attack(dist)


## Squash, colour glow and particles while a boss winds up.
func _windup_fx(delta: float, prog: float) -> void:
    fx_acc += delta
    var emit: bool = fx_acc >= 0.05
    if emit:
        fx_acc = 0.0
    tint_col = _fx_col2()
    tint_amt = 0.12 + 0.4 * prog * (0.65 + 0.35 * sin(anim_t * 24.0))
    var f = fight.fx
    match kind:
        "bouncer":
            sc = Vector2(1.0 + 0.2 * prog, 1.0 - 0.26 * prog)
            if emit:
                f.puff(position + Vector2(randf_range(-40.0, 40.0), 28.0), _fx_col(), 1, 40.0, 0.5, 5.0)
                if attack_variant == 1:
                    f.goo(position + Vector2(randf_range(-30.0, 30.0), 20.0), _fx_col(), 1, 70.0, Vector2.UP, 0.8, 4.0)
        "wolf":
            sc = Vector2(1.0 + 0.12 * prog, 1.0 - 0.18 * prog)
            if emit:
                var fl: float = -1.0 if target.position.x < position.x else 1.0
                f.glow_dots(position + Vector2(fl * size.x * 0.30, -size.y * 0.12), Color(1.0, 0.2, 0.1), 1, 15.0, 0.25, 4.0)
                f.puff(position + Vector2(0.0, size.y * 0.3) - lunge_dir * 20.0, Color(0.6, 0.55, 0.5), 1, 60.0, 0.4, 4.0)
        "pickpocket":
            if emit:
                f.puff(position + Vector2(randf_range(-14.0, 14.0), 10.0), _fx_col(), 1, 30.0, 0.5, 6.0)
                f.sparks(position + lunge_dir * 26.0, _fx_col2(), 1, 90.0, Vector2.ZERO, PI, 0.18)
        "storekeeper":
            sc = Vector2(1.0 - 0.04 * prog, 1.0 + 0.05 * prog)
            if emit:
                # coins and light stream INTO the Storekeeper while he charges
                var ang: float = randf() * TAU
                var from: Vector2 = position + Vector2.RIGHT.rotated(ang) * 135.0
                var vel: Vector2 = (position - from).normalized() * 270.0
                if attack_variant == 0:
                    f.spawn(from, vel, Color(1.0, 0.8, 0.2), 0.5, 7.0, false, "coin", 0.0)
                else:
                    f.spawn(from, vel, Color(1.0, 0.85, 0.35), 0.5, 5.0, true, "circle", 0.0)


func _execute_attack(dist: float) -> void:
    match kind:
        "wolf":
            _start_lunge()
        "bouncer":
            if attack_variant == 0:
                _start_lunge()
            else:
                _start_leap()
        "pickpocket":
            if attack_variant == 0:
                _start_lunge()
            else:
                _twin_slash(dist)
        "storekeeper":
            if attack_variant == 0:
                _fan_volley()
            else:
                _judgement(dist)
            attack_variant = 1 - attack_variant
            state = "cooldown"
            timer = _cooldown() + 0.25
        _:
            if dist <= attack_range + target.radius + 20.0:
                fight.damage_player(atk)
            state = "cooldown"
            timer = _cooldown()


# ------------------------------------------------------------------ lunges (charge / pounce / dash)

func _start_lunge() -> void:
    var lp: Vector2 = _lunge_params()
    state = "lunge"
    timer = lp.y
    lunge_mult = lp.x
    lunge_hit = false
    lunge_from = position
    trail_acc = 0.0
    var f = fight.fx
    var feet: Vector2 = position + Vector2(0.0, size.y * 0.3)
    match kind:
        "bouncer":
            AudioManager.play_sfx("charge", -4.0)
            f.puff(feet, Color(0.55, 0.78, 1.0), 10, 170.0, 0.5, 8.0)
            f.ring(feet, 10.0, 80.0, 0.3, _fx_col(), 5.0)
            f.goo(feet, _fx_col(), 8, 220.0, -lunge_dir, 0.6, 6.0)
            fight.shake(3.0)
        "wolf":
            AudioManager.play_sfx("pounce", -8.0, 0.12)
            f.puff(feet, Color(0.6, 0.55, 0.5), 8, 150.0, 0.45, 6.0)
            f.sparks(feet, _fx_col2(), 5, 220.0, -lunge_dir, 0.5, 0.2)
        "pickpocket":
            AudioManager.play_sfx("dash", -4.0)
            f.ring(position, 6.0, 55.0, 0.2, _fx_col(), 5.0)
            f.puff(position, _fx_col(), 6, 120.0, 0.4, 7.0)


func _tick_lunge(delta: float, spd: float) -> void:
    timer -= delta
    position += lunge_dir * spd * lunge_mult * delta
    trail_acc += delta
    if trail_acc >= 0.03:
        trail_acc = 0.0
        trail.append({"p": position, "life": 0.22})
        var f = fight.fx
        var feet: Vector2 = position + Vector2(0.0, size.y * 0.3)
        match kind:
            "bouncer":
                f.goo(feet, _fx_col(), 2, 90.0, -lunge_dir, 0.9, 6.0)
                f.glow_dots(position, _fx_col2(), 1, 40.0, 0.3, 6.0)
            "wolf":
                f.puff(feet, Color(0.6, 0.55, 0.5), 1, 70.0, 0.35, 5.0)
                f.sparks(position, Color(1.0, 0.4, 0.2), 1, 120.0, -lunge_dir, 0.4, 0.2)
            "pickpocket":
                f.glow_dots(position, _fx_col(), 2, 60.0, 0.35, 6.0)
    if not lunge_hit and position.distance_to(target.position) <= radius + target.radius + 12.0:
        lunge_hit = true
        var dmg: float = atk * (1.25 if kind == "bouncer" else 1.0)
        fight.damage_player(dmg, position, 36.0 if kind == "wolf" else 55.0)
        _hit_flair()
        if kind == "pickpocket":
            timer = minf(timer, 0.03)
    if timer <= 0.0:
        _end_lunge()


## Boss-specific look of a hit on the player.
func _hit_flair() -> void:
    var f = fight.fx
    var p: Vector2 = target.position
    match kind:
        "bouncer":
            f.goo(p, _fx_col(), 12, 300.0, lunge_dir, 1.0, 7.0)
            f.ring(p, 8.0, 80.0, 0.3, _fx_col2(), 6.0)
            fight.shake(6.0)
        "wolf":
            # three claw marks
            var n: Vector2 = lunge_dir.orthogonal()
            for i in range(3):
                var o: Vector2 = n * (float(i) - 1.0) * 16.0
                f.streak(p + o - lunge_dir * 30.0 - n * 8.0, p + o + lunge_dir * 30.0 + n * 8.0, 0.25, Color(1.0, 0.3, 0.2, 0.9), 6.0)
            f.sparks(p, _fx_col2(), 8, 300.0, lunge_dir, 0.8, 0.25)
            fight.shake(4.0)
            fight.try_infect(GameData.WOLF_INFECT_CHANCE)
        "pickpocket":
            f.streak(lunge_from, p, 0.25, Color(0.85, 0.5, 1.0, 0.85), 10.0)
            f.sparks(p, _fx_col2(), 12, 380.0)
            fight.shake(4.0)


func _end_lunge() -> void:
    if kind == "pickpocket":
        fight.fx.streak(lunge_from, position, 0.3, Color(0.8, 0.45, 1.0, 0.7), 12.0)
        fight.fx.streak(lunge_from, position, 0.2, Color(1, 1, 1, 0.9), 3.0)
    if kind in ["wolf", "bouncer", "pickpocket"]:
        attack_variant = 1 - attack_variant
    if kind == "bouncer":
        sc = Vector2(1.3, 0.78)
        fight.fx.puff(position + Vector2(0.0, size.y * 0.3), Color(0.55, 0.78, 1.0), 8, 130.0, 0.45, 7.0)
    state = "cooldown"
    timer = _cooldown()


# ------------------------------------------------------------------ slime leap + slam

func _start_leap() -> void:
    state = "jump_up"
    timer = 0.38
    slam_locked = false
    AudioManager.play_sfx("jump", -3.0)
    var feet: Vector2 = position + Vector2(0.0, size.y * 0.3)
    fight.fx.puff(feet, Color(0.55, 0.78, 1.0), 12, 170.0, 0.5, 8.0)
    fight.fx.ring(feet, 10.0, 90.0, 0.35, _fx_col(), 6.0)
    fight.fx.goo(feet, _fx_col(), 8, 200.0, Vector2.ZERO, PI, 6.0)
    fight.shake(2.0)


func _tick_slam(delta: float, spd: float) -> void:
    var to_t: Vector2 = target.position - position
    var track: Vector2 = Vector2.ZERO
    if to_t.length() > 8.0:
        track = to_t.normalized()
    match state:
        "jump_up":
            timer -= delta
            var k: float = 1.0 - clampf(timer / 0.38, 0.0, 1.0)
            z = AIR_HEIGHT * (1.0 - (1.0 - k) * (1.0 - k))
            position += track * spd * 1.4 * delta
            sc = Vector2(0.9, 1.15)
            if timer <= 0.0:
                state = "hang"
                timer = 0.7
        "hang":
            timer -= delta
            z = AIR_HEIGHT + sin(anim_t * 12.0) * 3.0
            sc = Vector2(0.92, 1.1)
            if timer > 0.45:
                position += track * spd * 1.6 * delta        # still following you
            elif not slam_locked:
                slam_locked = true                           # landing spot is now fixed
                fight.fx.ring(position, 8.0, _slam_radius(), 0.25, Color(1.0, 0.4, 0.3), 4.0)
            if timer <= 0.0:
                state = "fall"
                timer = 0.14
        "fall":
            timer -= delta
            var k2: float = 1.0 - clampf(timer / 0.14, 0.0, 1.0)
            z = AIR_HEIGHT * (1.0 - k2 * k2)
            sc = Vector2(0.85, 1.3)
            if timer <= 0.0:
                z = 0.0
                _slam_impact()


func _slam_impact() -> void:
    state = "cooldown"
    if phase2 and combo_left == 0:
        combo_left = 1                # enraged: a SECOND slam follows almost at once
        attack_variant = 1
        timer = 0.45
    else:
        combo_left = 0
        timer = _cooldown() + 0.35    # the slime is stuck and VULNERABLE for this time
        attack_variant = 0
    sc = Vector2(1.45, 0.65)
    var r: float = _slam_radius()
    var f = fight.fx
    AudioManager.play_sfx("slam", -1.0, 0.03)
    f.ring(position, 12.0, r, 0.45, Color(0.6, 0.85, 1.0), 11.0)
    f.ring(position, 6.0, r * 0.7, 0.35, Color(1, 1, 1), 5.0)
    f.puff(position, Color(0.45, 0.7, 1.0), 26, 330.0, 0.7, 11.0)
    f.goo(position, _fx_col(), 18, 380.0, Vector2.ZERO, PI, 8.0)
    f.sparks(position, _fx_col2(), 18, 440.0)
    f.glow_dots(position, Color(0.5, 0.8, 1.0), 10, 260.0, 0.5, 8.0)
    fight.shake(11.0)
    if position.distance_to(target.position) <= r:
        fight.damage_player(atk * 1.25, position, 80.0)


# ------------------------------------------------------------------ pickpocket

func _twin_slash(dist: float) -> void:
    var f = fight.fx
    AudioManager.play_sfx("twin_slash", -3.0)
    var a: float = lunge_dir.angle()
    f.crescent(position, a + 0.7, 0.95, 72.0, 0.2, _fx_col(), 16.0)
    f.crescent(position, a - 0.7, 0.95, 72.0, 0.2, _fx_col2(), 16.0, 0.07)
    f.sparks(position + lunge_dir * 55.0, _fx_col2(), 10, 340.0, lunge_dir, 0.9, 0.25)
    f.ring(position, 8.0, 90.0, 0.25, _fx_col(), 5.0)
    fight.shake(3.0)
    if dist <= attack_range + target.radius + 34.0:
        fight.damage_player(atk, position, 45.0)
        var p: Vector2 = target.position
        f.streak(p + Vector2(-34, -34), p + Vector2(34, 34), 0.22, Color(0.9, 0.45, 1.0, 0.9), 7.0)
        f.streak(p + Vector2(-34, 34), p + Vector2(34, -34), 0.22, Color(0.9, 0.45, 1.0, 0.9), 7.0)
    attack_variant = 0
    state = "cooldown"
    timer = _cooldown()


## 6 s visible, 3 s invisible, then reappears behind the player and attacks.
func _pickpocket_cycle(delta: float) -> void:
    cycle_t += delta
    var f = fight.fx
    if not ghost and cycle_t >= vanish_at and state == "chase":
        ghost = true
        AudioManager.play_sfx("vanish", -4.0)
        f.puff(position, _fx_col(), 16, 200.0, 0.7, 10.0)
        f.ring(position, 8.0, 80.0, 0.35, _fx_col(), 6.0)
        f.sparks(position, _fx_col2(), 10, 300.0)
    elif ghost and cycle_t >= appear_at:
        ghost = false
        cycle_t = 0.0
        var behind: Vector2 = target.position - target.aim * 70.0
        position = ring_c + (behind - ring_c).limit_length(ring_r - radius)
        _begin_windup((target.position - position).normalized())
        AudioManager.play_sfx("appear", -3.0)
        f.puff(position, _fx_col(), 16, 220.0, 0.7, 10.0)
        f.ring(position, 8.0, 110.0, 0.4, _fx_col2(), 7.0)
        f.sparks(position, Color(1, 1, 1), 14, 420.0)
        fight.shake(3.0)
    elif ghost:
        # a faint purple shimmer so a careful player can still track him
        ghost_acc += delta
        if ghost_acc >= 0.14:
            ghost_acc = 0.0
            f.puff(position, Color(_fx_col().r, _fx_col().g, _fx_col().b, 0.5), 1, 25.0, 0.55, 7.0)


# ------------------------------------------------------------------ storekeeper

func _fan_volley() -> void:
    var f = fight.fx
    AudioManager.play_sfx("coin_fire", -3.0)
    fight.spawn_projectile(position, lunge_dir.rotated(-0.30), atk * 0.48)
    fight.spawn_projectile(position, lunge_dir.rotated(-0.15), atk * 0.58)
    fight.spawn_projectile(position, lunge_dir, atk * 0.68)
    fight.spawn_projectile(position, lunge_dir.rotated(0.15), atk * 0.58)
    fight.spawn_projectile(position, lunge_dir.rotated(0.30), atk * 0.48)
    f.sparks(position + lunge_dir * 40.0, _fx_col2(), 16, 420.0, lunge_dir, 0.7, 0.3)
    f.ring(position, 10.0, 75.0, 0.28, _fx_col(), 6.0)
    f.coins(position + lunge_dir * 30.0, 7, 260.0, lunge_dir, 0.8)
    f.glow_dots(position + lunge_dir * 40.0, _fx_col(), 6, 150.0, 0.3, 8.0)
    sc = Vector2(1.12, 0.9)
    fight.shake(3.0)
    if phase2:
        volley2_t = 0.55


func _judgement(dist: float) -> void:
    var r: float = attack_range * 1.9 + target.radius
    var f = fight.fx
    AudioManager.play_sfx("judgement", -2.0, 0.03)
    f.ring(position, 20.0, r, 0.5, _fx_col(), 11.0)
    f.ring(position, 8.0, r * 0.6, 0.35, Color(1.0, 0.95, 0.7), 5.0)
    f.glow_dots(position, _fx_col(), 26, 360.0, 0.7, 7.0)
    f.coins(position, 14, 340.0)
    f.sparks(position, _fx_col2(), 22, 480.0)
    sc = Vector2(1.18, 0.86)
    fight.shake(8.0)
    if dist <= r:
        fight.damage_player(atk * 1.15, position, 90.0)


# ------------------------------------------------------------------ drawing

func _update_body_material() -> void:
    var amt: float = 0.0
    var col: Color = tint_col
    if flash > 0.0:
        amt = clampf(flash / 0.12, 0.0, 1.0) * 0.85
        col = Color(1, 1, 1)
    else:
        amt = clampf(tint_amt, 0.0, 0.7)
    body_mat.set_shader_parameter("flash", amt)
    body_mat.set_shader_parameter("flash_color", col)


## Shadow, afterimages and attack warnings (drawn UNDER the sprite).
func _draw() -> void:
    if dead or ghost:
        return
    # soft floor shadow; it stays on the ground and shrinks while the slime is in the air
    var sh: float = 1.0 - clampf(z / 260.0, 0.0, 0.5)
    draw_set_transform(Vector2(0.0, size.y * 0.38), 0.0, Vector2(1.0, 0.32))
    draw_circle(Vector2.ZERO, size.x * 0.40 * sh, Color(0, 0, 0, 0.38 * sh))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    # afterimages
    if kind != "storekeeper" or Art.tex(art_name) != null:
        var flip: bool = target != null and target.position.x < position.x
        var c2: Color = _fx_col2()
        for t in trail:
            var lp: Vector2 = (t["p"] as Vector2) - position
            var a: float = clampf(float(t["life"]) / 0.22, 0.0, 1.0)
            Art.draw_sprite(self, art_name, lp, size, color, flip, Color(c2.r, c2.g, c2.b, 0.35 * a))
    if state == "windup" or state == "jump_up" or state == "hang" or state == "fall":
        _draw_telegraph()


func _draw_telegraph() -> void:
    var prog: float = 1.0 - clampf(timer / maxf(windup_total, 0.01), 0.0, 1.0)
    var pulse: float = 0.5 + 0.5 * sin(anim_t * 14.0)
    match kind:
        "bouncer":
            if state == "windup" and attack_variant == 0:
                _tele_lane(Color(0.30, 0.65, 1.0), 82.0, _lunge_length(), prog, pulse)
            elif attack_variant == 1:
                _tele_slam(prog, pulse)
        "wolf":
            if state == "windup":
                var length: float = _lunge_length()
                _tele_lane(Color(1.0, 0.25, 0.18), 34.0, length, prog, pulse)
                var n: Vector2 = lunge_dir.orthogonal()
                for i in range(3):
                    var o: Vector2 = n * (float(i) - 1.0) * 16.0
                    draw_line(lunge_dir * length + o - lunge_dir * 24.0 - n * 6.0, lunge_dir * length + o + lunge_dir * 24.0 + n * 6.0, Color(1.0, 0.7, 0.5, 0.4 + 0.5 * prog), 4.0)
                # glowing eyes
                var fl: float = -1.0 if target.position.x < position.x else 1.0
                var eye: Vector2 = Vector2(fl * size.x * 0.30, -size.y * 0.12)
                draw_circle(eye, 9.0, Color(1.0, 0.2, 0.1, 0.25 + 0.35 * pulse))
                draw_circle(eye, 4.0, Color(1.0, 0.7, 0.4, 0.95))
        "pickpocket":
            if state == "windup":
                if attack_variant == 0:
                    _tele_lane(Color(0.75, 0.35, 1.0), 24.0, _lunge_length(), prog, pulse)
                else:
                    var r: float = attack_range + target.radius + 34.0
                    draw_circle(Vector2.ZERO, r, Color(0.7, 0.3, 1.0, 0.07 + 0.18 * prog))
                    draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(0.9, 0.55, 1.0, 0.55 + 0.35 * pulse), 4.0)
                    var a: float = lunge_dir.angle()
                    draw_arc(Vector2.ZERO, r * 0.72, a + 0.7 - 0.95, a + 0.7 + 0.95, 14, Color(1.0, 0.75, 1.0, 0.45 + 0.4 * prog), 7.0)
                    draw_arc(Vector2.ZERO, r * 0.72, a - 0.7 - 0.95, a - 0.7 + 0.95, 14, Color(1.0, 0.75, 1.0, 0.45 + 0.4 * prog), 7.0)
        "storekeeper":
            if state == "windup":
                _tele_storekeeper(prog, pulse)


## A glowing lane with moving chevrons showing where a lunge will go.
func _tele_lane(col: Color, half_w: float, length: float, prog: float, pulse: float) -> void:
    var d: Vector2 = lunge_dir
    var n: Vector2 = d.orthogonal()
    var pts := PackedVector2Array([n * half_w, n * half_w + d * length, -n * half_w + d * length, -n * half_w])
    draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.10 + 0.25 * prog))
    var edge := Color(minf(col.r + 0.5, 1.0), minf(col.g + 0.5, 1.0), minf(col.b + 0.5, 1.0), 0.35 + 0.45 * pulse)
    draw_line(n * half_w, n * half_w + d * length, edge, 3.0)
    draw_line(-n * half_w, -n * half_w + d * length, edge, 3.0)
    draw_line(n * half_w + d * length, -n * half_w + d * length, edge, 3.0)
    for i in range(4):
        var s: float = fposmod(anim_t * 260.0 + float(i) * length / 4.0, length)
        var c: Vector2 = d * s
        var al: float = 0.6 * (1.0 - s / length) * (0.4 + prog)
        draw_line(c + n * half_w * 0.5 - d * 14.0, c, Color(1, 1, 1, al), 4.0)
        draw_line(c - n * half_w * 0.5 - d * 14.0, c, Color(1, 1, 1, al), 4.0)
    draw_arc(d * length, radius, 0.0, TAU, 28, edge, 3.0)


## Landing zone of the slime's leap. The disc fills up until the impact.
func _tele_slam(prog: float, pulse: float) -> void:
    var r: float = _slam_radius()
    var col := Color(0.35, 0.7, 1.0)
    var fill: float = 0.0
    match state:
        "windup":
            fill = prog * 0.3
        "jump_up":
            fill = 0.3 + 0.2 * (1.0 - clampf(timer / 0.38, 0.0, 1.0))
        "hang":
            fill = 0.5 + 0.4 * (1.0 - clampf(timer / 0.7, 0.0, 1.0))
        "fall":
            fill = 1.0
    var locked: bool = slam_locked or state == "fall"
    draw_circle(Vector2.ZERO, r, Color(col.r, col.g, col.b, 0.10 + (0.08 if locked else 0.0)))
    draw_circle(Vector2.ZERO, r * fill, Color(col.r, col.g, col.b, 0.24))
    var edge := Color(1.0, 0.4, 0.35, 0.6 + 0.35 * pulse) if locked else Color(0.8, 0.95, 1.0, 0.6)
    draw_arc(Vector2.ZERO, r, 0.0, TAU, 56, edge, 4.0)
    for k in range(6):
        var ang: float = float(k) * TAU / 6.0 + 0.3
        draw_line(Vector2.RIGHT.rotated(ang) * r * 0.2, Vector2.RIGHT.rotated(ang) * r * maxf(fill, 0.25), Color(1, 1, 1, 0.3), 2.0)


func _tele_storekeeper(prog: float, pulse: float) -> void:
    var gold := Color(1.0, 0.78, 0.25)
    if attack_variant == 0:
        # five lanes (exactly the five coins) inside a golden fan
        var pts := PackedVector2Array([Vector2.ZERO])
        for i in range(9):
            pts.append(lunge_dir.rotated(lerpf(-0.30, 0.30, float(i) / 8.0)) * 270.0)
        draw_colored_polygon(pts, Color(gold.r, gold.g, gold.b, 0.07 + 0.18 * prog))
        for a in [-0.30, -0.15, 0.0, 0.15, 0.30]:
            draw_line(Vector2.ZERO, lunge_dir.rotated(a) * 270.0, Color(1.0, 0.88, 0.4, 0.5 + 0.35 * pulse), 3.0)
    else:
        # golden judgement sigil: it fills up, then bursts
        var r: float = attack_range * 1.9 + target.radius
        draw_circle(Vector2.ZERO, r, Color(gold.r, gold.g, gold.b, 0.07))
        draw_circle(Vector2.ZERO, r * prog, Color(gold.r, gold.g, gold.b, 0.22))
        draw_arc(Vector2.ZERO, r, 0.0, TAU, 56, Color(1.0, 0.85, 0.4, 0.6 + 0.3 * pulse), 5.0)
        draw_arc(Vector2.ZERO, r * 0.62, 0.0, TAU, 40, Color(1.0, 0.85, 0.4, 0.5), 2.0)
        var rot: float = anim_t * 0.8
        for tri in range(2):
            var pts2 := PackedVector2Array()
            for k in range(4):
                var ang: float = rot + float(k % 3) * TAU / 3.0 + float(tri) * PI / 3.0
                pts2.append(Vector2.RIGHT.rotated(ang) * r * 0.62)
            draw_polyline(pts2, Color(1.0, 0.85, 0.4, 0.7), 3.0)
        for k2 in range(8):
            var ang2: float = rot * 0.5 + float(k2) * TAU / 8.0
            draw_line(Vector2.RIGHT.rotated(ang2) * r * 0.62, Vector2.RIGHT.rotated(ang2) * r, Color(1.0, 0.85, 0.4, 0.35), 2.0)


## The sprite itself (drawn by the child node, which carries the flash SHADER).
func _draw_body() -> void:
    if dead or ghost:
        return
    var flip: bool = target != null and target.position.x < position.x
    var bob: float = sin(anim_t * 5.0) * 0.02
    var s := Vector2(sc.x, sc.y + bob)
    if kind == "storekeeper" and Art.tex(art_name) == null:
        # no boss_storekeeper.png yet: use the built-in hooded silhouette
        body.draw_set_transform(Vector2(0.0, size.y * 0.45 * (1.0 - s.y)) + Vector2(0.0, -z), 0.0, s)
        _draw_storekeeper_boss(flip)
        body.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    else:
        var sz := Vector2(size.x * s.x, size.y * s.y)
        var pos := Vector2(0.0, size.y * 0.5 - sz.y * 0.5 - z)    # feet stay planted; z lifts the slime
        Art.draw_sprite(body, art_name, pos, sz, color, flip, tint)


func _draw_storekeeper_boss(flip: bool) -> void:
    # Purpose-built boss silhouette: a hooded collector, not the shop counter sprite.
    var sx: float = -1.0 if flip else 1.0
    body.draw_colored_polygon(PackedVector2Array([Vector2(-34, -30), Vector2(-22, -52), Vector2(0, -62), Vector2(22, -52), Vector2(34, -30), Vector2(45, 48), Vector2(22, 58), Vector2(-22, 58), Vector2(-45, 48)]), Color("211725"))
    body.draw_colored_polygon(PackedVector2Array([Vector2(-28, -34), Vector2(-18, -52), Vector2(0, -59), Vector2(18, -52), Vector2(28, -34), Vector2(17, -18), Vector2(-17, -18)]), Color("51402d"))
    body.draw_colored_polygon(PackedVector2Array([Vector2(-18, -36), Vector2(0, -49), Vector2(18, -36), Vector2(12, -18), Vector2(-12, -18)]), Color("100e16"))
    body.draw_circle(Vector2(-8, -30), 4.0, Color("ffd45a"))
    body.draw_circle(Vector2(8, -30), 4.0, Color("ffd45a"))
    body.draw_line(Vector2(-22, 4), Vector2(-43 * sx, 26), Color("b88a42"), 7.0)
    body.draw_line(Vector2(22, 4), Vector2(43 * sx, 26), Color("b88a42"), 7.0)
    body.draw_rect(Rect2(-13, -4, 26, 42), Color("5b2b36"))
    body.draw_rect(Rect2(-13, -4, 26, 42), Color("d6ad55"), false, 2.0)
    body.draw_circle(Vector2(0, 16), 5.0, Color("f4d57c"))
