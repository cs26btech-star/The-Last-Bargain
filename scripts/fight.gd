extends Node2D
## One round. PREP phase: walk to the beacons (E), open the catalogue (C), press Enter to start.
## FIGHT phase: the boss spawns and you fight.

signal finished(won: bool)
signal quit_to_title

const HudScript = preload("res://scripts/hud.gd")
const MYTHIC_FONT: Font = preload("res://fonts/EBGaramond.ttf")
const OverlayScript = preload("res://scripts/shop_overlay.gd")
const INTERACT_RANGE = 150.0
const PREP_RADIUS = 540.0

var player: Player
var enemies: Array = []
var projectiles: Array = []
var hud = null
var overlay: Control = null
var phase: String = "prep"          # prep / fight
var near_side: String = ""
var intro_done: bool = true
var elapsed: float = 0.0
var fight_self: Dictionary = {}
var fight_boss: Dictionary = {}
var boss_data: Dictionary = {}
var boss_name: String = ""
var ring_c: Vector2 = GameData.RING_CENTER
var ring_r: float = 300.0
var holding: bool = false
var end_result: int = 0             # 0 = still fighting, 1 = won, -1 = lost
var end_timer: float = 0.0
var done: bool = false
var fx: Fx = null                   # particles / slashes / damage numbers (scripts/fx.gd)
var shake_amt: float = 0.0          # screen shake, in pixels
var hitstop: float = 0.0            # tiny freeze when a hit lands
var dodge_cd: float = 0.0           # so the DODGE message does not spam


func _ready() -> void:
    boss_data = GameData.BOSSES[Game.round_index]
    boss_name = str(boss_data["name"])
    ring_r = Game.ring_radius()
    fight_self = {"atk": 1.0, "hp": 1.0, "speed": 1.0}
    fight_boss = {"atk": 1.0, "hp": 1.0, "speed": 1.0}
    fx = Fx.new()
    add_child(fx)
    _spawn_player()
    hud = HudScript.new()
    hud.setup(self)
    add_child(hud)
    hud.toast("ROUND %d  -  prepare yourself" % [Game.round_index + 1], 2.5)
    AudioManager.play_music_named(["prep", "bgm"])


func beacon_pos(side: String) -> Vector2:
    if side == "demon":
        return Vector2(130.0, ring_c.y)
    return Vector2(1150.0, ring_c.y)


func _spawn_player() -> void:
    player = Player.new()
    add_child(player)
    player.tint = Color(str(Game.class_data()["color"]))
    player.ring_c = ring_c
    player.ring_r = PREP_RADIUS
    _apply_player_stats()
    var dest: Vector2 = ring_c + Vector2(0.0, ring_r * 0.5)
    player.position = dest
    if Game.round_index == 0:
        # the player falls into the ring at the very start
        intro_done = false
        player.position = Vector2(dest.x, -80.0)
        player.frozen = true
        var tw: Tween = create_tween()
        tw.tween_property(player, "position", dest, 0.7)
        tw.tween_callback(_intro_finished)


func _intro_finished() -> void:
    intro_done = true
    if overlay == null:
        player.frozen = false


func _apply_player_stats() -> void:
    var max_hp: float = float(Game.stats["hp"]) * 10.0 * float(fight_self["hp"])
    player.max_hp = max_hp
    player.hp = max_hp
    var spd: float = float(Game.stats["speed"]) * float(fight_self["speed"])
    player.speed_stat = spd
    player.move_px = spd * GameData.SPEED_PX


## Called by the HUD button or the Enter key.
func start_round() -> void:
    if phase != "prep" or overlay != null or not intro_done:
        return
    if not Game.pay_rent():
        AudioManager.play_sfx("deny", -4.0)
        hud.toast("RENT DUE: %d coins. Sell something!" % Game.rent_due(), 2.4)
        return
    phase = "fight"
    var m: Dictionary = Game.fight_mults()
    fight_self = m["self"]
    fight_boss = m["boss"]
    ring_r = Game.ring_radius()
    _apply_player_stats()
    player.ring_r = ring_r
    player.position = ring_c + Vector2(0.0, ring_r * 0.5)
    near_side = ""
    hud.set_prompt("")
    _spawn_enemies()
    AudioManager.play_sfx("round_start", -3.0, 0.0)
    AudioManager.play_music_named(["battle_" + str(boss_data["id"]), "battle"])
    hud.toast("ROUND %d: %s" % [Game.round_index + 1, boss_name], 2.2)


func open_catalogue() -> void:
    if phase == "prep":
        _open_overlay("sell")


func _open_overlay(mode: String) -> void:
    if overlay != null or not intro_done:
        return
    AudioManager.play_sfx("open", -17.0, 0.01)
    overlay = OverlayScript.new()
    overlay.mode = mode
    overlay.changed.connect(_on_shop_changed)
    overlay.closed.connect(_close_overlay)
    hud.add_child(overlay)
    player.frozen = true
    holding = false
    hud.set_prompt("")


func _close_overlay() -> void:
    if overlay != null:
        overlay.queue_free()
        overlay = null
    if intro_done:
        player.frozen = false


func _on_shop_changed() -> void:
    ring_r = Game.ring_radius()


func _spawn_enemies() -> void:
    var store_mult: float = 1.0
    if boss_data["id"] == "storekeeper":
        # Selling a lot should make the final boss tougher, not mathematically impossible.
        store_mult = minf(1.6, 1.0 + float(Game.sold_value) / 400.0)
    var count: int = int(boss_data["count"])
    # bosses get tougher every round (see GameData.ROUND_HP_SCALE / ROUND_ATK_SCALE / DIFFICULTY)
    var ri: int = clampi(Game.round_index, 0, GameData.ROUND_HP_SCALE.size() - 1)
    var hp_scale: float = 1.0 + (float(GameData.ROUND_HP_SCALE[ri]) - 1.0) * GameData.DIFFICULTY
    var atk_scale: float = 1.0 + (float(GameData.ROUND_ATK_SCALE[ri]) - 1.0) * GameData.DIFFICULTY
    for i in count:
        var e := Enemy.new()
        e.kind = str(boss_data["id"])
        e.max_hp = float(boss_data["hp"]) * float(fight_boss["hp"]) * store_mult * hp_scale
        e.hp = e.max_hp
        e.atk = float(boss_data["atk"]) * float(fight_boss["atk"]) * store_mult * atk_scale
        e.speed_stat = float(boss_data["speed"]) * float(fight_boss["speed"]) * store_mult
        e.move_px = e.speed_stat * GameData.SPEED_PX
        e.radius = float(boss_data["radius"])
        e.size = Vector2(float(boss_data["w"]), float(boss_data["h"]))
        e.art_name = str(boss_data["art"])
        e.color = Color(str(boss_data["color"]))
        e.tint = Color(str(boss_data["tint"]))
        e.windup_time = float(boss_data["windup"])
        e.attack_range = float(boss_data["range"])
        e.base_cd = float(boss_data["cd"])
        e.target = player
        e.fight = self
        e.ring_c = ring_c
        e.ring_r = ring_r
        if count == 1:
            e.position = ring_c + Vector2(0.0, -ring_r * 0.55)
        else:
            var ang: float = TAU * float(i) / float(count) - PI / 2.0
            e.position = ring_c + Vector2(cos(ang), sin(ang)) * ring_r * 0.6
        add_child(e)
        enemies.append(e)


## Every defeated wolf makes the surviving pack more aggressive. The stacking
## bonuses cap at roughly 1.5x attack speed, so the last wolf is scary but fair.
var wolves_defeated: int = 0

func on_wolf_defeated(fallen: Enemy) -> void:
    wolves_defeated = mini(wolves_defeated + 1, 4)
    for other in enemies:
        if other == fallen or other.dead or other.kind != "wolf":
            continue
        # Four kills produce ~1.52x attack frequency, plus a modest damage bump.
        other.base_cd = maxf(1.42, other.base_cd * 0.90)
        other.windup_time = maxf(0.43, other.windup_time * 0.94)
        other.atk *= 1.04
        # Apply the faster rhythm immediately if the wolf is already recovering.
        if other.state == "cooldown":
            other.timer = minf(other.timer, other.base_cd)
        fx.text(other.position + Vector2(0.0, -other.size.y * 0.7), "PACK ENRAGED", Color(1.0, 0.35, 0.25), 18)
        fx.ring(other.position, 8.0, 48.0, 0.28, Color(1.0, 0.22, 0.15), 4.0)


func _physics_process(delta: float) -> void:
    if done:
        return
    # screen shake: the whole arena jitters for a moment
    if shake_amt > 0.05:
        position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_amt
        shake_amt = maxf(0.0, shake_amt - 45.0 * delta)
    else:
        position = Vector2.ZERO
    dodge_cd = maxf(0.0, dodge_cd - delta)
    var to_mouse: Vector2 = get_local_mouse_position() - player.position
    if to_mouse.length() > 1.0:
        player.aim = to_mouse.normalized()
    _update_player_weapon()
    player.tick(delta)
    if player.roll_time > 0.0:
        # dodge-roll dust trail
        fx.puff(player.position + Vector2(0.0, 18.0), Color(0.85, 0.88, 1.0, 0.7), 1, 30.0, 0.3, 8.0)
    if phase == "prep":
        player.position.y = clampf(player.position.y, 110.0, 640.0)
        _update_near_side()
    else:
        if end_result == 0:
            elapsed += delta
            if Input.is_action_just_pressed("roll"):
                var was_rolling: bool = player.roll_time > 0.0
                player.try_roll()
                if player.roll_time > 0.0 and not was_rolling:
                    AudioManager.play_sfx("roll", -7.0)
                    fx.ring(player.position, 8.0, 50.0, 0.25, Color(0.85, 0.92, 1.0), 4.0)
                    fx.puff(player.position + Vector2(0.0, 18.0), Color(0.85, 0.88, 1.0, 0.8), 6, 120.0, 0.4, 8.0)
            if hitstop > 0.0:
                hitstop -= delta        # tiny freeze so hits feel heavy
            else:
                if holding or Input.is_key_pressed(KEY_J) or Input.is_key_pressed(KEY_K):
                    _player_attack()
                for e in enemies:
                    e.tick(delta)
                _separate()
                _update_projectiles(delta)
        _check_end(delta)
    queue_redraw()


## Contagion: a wolf bite can infect one of your UI pieces right now.
func try_infect(chance: float) -> void:
    if randf() > chance:
        return
    var id: String = Game.infect_random("bite")
    if id == "":
        return
    hud.toast("INFECTED: %s" % Game.name_of(id), 1.8)
    AudioManager.play_sfx("appear", -4.0)
    fx.ring(player.position, 10.0, 70.0, 0.45, Color(0.6, 1.0, 0.3), 5.0)
    fx.puff(player.position, Color(0.5, 0.9, 0.3, 0.7), 10, 120.0, 0.6, 8.0)


func shake(amount: float) -> void:
    shake_amt = maxf(shake_amt, amount)


func _update_near_side() -> void:
    near_side = ""
    if overlay != null or not intro_done:
        hud.set_prompt("")
        return
    for side in ["demon", "angel"]:
        if Game.is_sold("beacon_" + side):
            continue
        if player.position.distance_to(beacon_pos(side)) <= INTERACT_RANGE:
            near_side = side
    if near_side == "demon":
        hud.set_prompt("PRESS E TO TRADE — DEMON SHOP")
    elif near_side == "angel":
        hud.set_prompt("PRESS E TO TRADE — ANGEL SHOP")
    else:
        hud.set_prompt("")


func _update_player_weapon() -> void:
    player.weapon_art = ""
    if Game.selected_slot < 0:
        return
    var w = Game.inventory[Game.selected_slot]
    if w != null and w["kind"] == "weapon":
        player.weapon_art = "held_" + str(w["wtype"])
        player.weapon_tint = Color(str(w["tint"]))
        player.weapon_len = 32.0 + float(Game.class_data()["reach"]) * 40.0
    else:
        player.weapon_len = 22.0
        player.weapon_tint = Color(0.9, 0.75, 0.6)


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        holding = event.pressed
        if event.pressed and phase == "fight":
            _player_attack()
    elif event is InputEventKey and event.pressed and not event.echo:
        var kc: int = int(event.keycode)
        # J is a keyboard attack alternative; Space remains dodge.
        if kc == KEY_J or kc == KEY_K:
            if phase == "fight":
                _player_attack()
            return
        if kc >= int(KEY_1) and kc <= int(KEY_6):
            _use_slot(kc - int(KEY_1))
        elif phase == "prep":
            if kc == KEY_E or kc == KEY_ESCAPE:
                if overlay != null:
                    _close_overlay()
                elif kc == KEY_E and near_side != "":
                    _open_overlay(near_side)
            elif kc == KEY_C and overlay == null:
                open_catalogue()
            elif (kc == KEY_ENTER or kc == KEY_KP_ENTER) and overlay == null:
                start_round()


func _use_slot(idx: int) -> void:
    if Game.is_sold("hud_inventory") or end_result != 0 or overlay != null:
        return
    var item = Game.inventory[idx]
    if item == null:
        return
    if item["kind"] == "skill":
        if phase != "fight":
            return
        _use_skill(str(item["skill"]))
        Game.inventory[idx] = null
    else:
        Game.selected_slot = idx


func _player_attack() -> void:
    if phase != "fight" or end_result != 0 or player.frozen or player.atk_cd > 0.0 or player.roll_time > 0.0:
        return
    if Game.selected_slot < 0:
        return
    var w = Game.inventory[Game.selected_slot]
    if w == null:
        return
    var cdata: Dictionary = Game.class_data()
    var is_weapon: bool = w["kind"] == "weapon"
    var reach_b: float = float(cdata["reach"]) if is_weapon else 0.7
    var arc_deg: float = float(cdata["arc"]) if is_weapon else 60.0
    var weapon_type: String = str(w.get("wtype", "")) if is_weapon else "hands"
    # Moderate, consistent reach: spear is longer, but never screen-wide.
    # The target-radius allowance below makes narrow thrusts register reliably.
    var reach_px: float = 42.0 + reach_b * 62.0
    if weapon_type == "spear" or str(cdata.get("weapon", "")) == "spear":
        reach_px = maxf(reach_px, 142.0)
        arc_deg = maxf(arc_deg, 32.0)
    elif weapon_type == "sword" or str(cdata.get("weapon", "")) == "sword":
        reach_px = maxf(reach_px, 112.0)
    elif weapon_type == "dagger" or str(cdata.get("weapon", "")) == "dagger":
        reach_px = maxf(reach_px, 88.0)
    player.atk_cd = Game.attack_cooldown(player.speed_stat)
    player.swing_time = Player.SWING_T
    player.swing_dir = player.aim
    player.swing_reach = reach_px
    player.swing_side = -player.swing_side
    AudioManager.play_sfx("swing_" + weapon_type, -8.0, 0.08)
    var slash_col: Color = Color(0.9, 0.8, 0.7)
    if is_weapon:
        slash_col = Color(str(w["tint"]))
    # (the slash / whiff effect is spawned after the hit check below, so a MISS looks different)
    var dmg: float = Game.damage_per_hit(w, float(fight_self["atk"]))
    var landed_hit: bool = false
    var big_hit: bool = false
    for e in enemies:
        if e.dead or e.is_airborne():
            continue        # the slime cannot be hit while it is in the air
        var to_e: Vector2 = e.position - player.position
        var dist_to_enemy: float = to_e.length()
        if dist_to_enemy <= reach_px + e.radius:
            var diff: float = absf(angle_difference(to_e.angle(), player.aim.angle()))
            # Account for the enemy's collision radius so long/narrow weapons do not
            # visually touch a target but miss by a few pixels.
            var target_angle_allowance: float = asin(clampf(e.radius / maxf(dist_to_enemy, e.radius), 0.0, 1.0))
            if diff <= deg_to_rad(arc_deg) + target_angle_allowance or dist_to_enemy <= e.radius + 28.0:
                e.take_damage(dmg)
                landed_hit = true
                if e.radius > 40.0 or dmg >= 30.0:
                    big_hit = true
                var hit_dir: Vector2 = to_e.normalized()
                fx.hit_impact(e.position - hit_dir * e.radius * 0.7, hit_dir, slash_col, e.radius > 40.0)
    fx.player_slash(player.position, player.aim, weapon_type, reach_px, arc_deg, slash_col, landed_hit, player.swing_side)
    if landed_hit:
        AudioManager.play_hit()
        AudioManager.play_sfx("hit_heavy" if big_hit else "hit_light", -4.0, 0.07)
        hitstop = 0.06 if big_hit else 0.04
        shake(4.0 if big_hit else 2.5)
    if is_weapon:
        w["dur"] = int(w["dur"]) - 1
        if int(w["dur"]) <= 0:
            Game.inventory[Game.selected_slot] = null
            Game.selected_slot = 0
            hud.toast("Your weapon broke!", 1.5)


func _use_skill(skill: String) -> void:
    match skill:
        "hellfire":
            AudioManager.play_sfx("fire", -3.0)
            _hit_nearest(60.0, Color(1.0, 0.45, 0.1))
            hud.toast("HELLFIRE!", 1.2)
        "judgement":
            AudioManager.play_sfx("holy", -4.0)
            _hit_nearest(80.0, Color(1.0, 0.9, 0.4))
            hud.toast("HOLY JUDGEMENT!", 1.2)
        "ultimate":
            AudioManager.play_sfx("judgement", -3.0)
            _hit_nearest(150.0, Color(1.0, 1.0, 0.85))
            hud.toast("ANGEL'S ULTIMATE!", 1.2)
        "suppress":
            AudioManager.play_sfx("freeze", -4.0)
            for e in enemies:
                e.slow_time = 5.0
                fx.ring(e.position, 10.0, 120.0, 0.6, Color(0.4, 0.6, 1.0), 7.0)
                fx.puff(e.position, Color(0.5, 0.65, 1.0), 8, 120.0, 0.7, 9.0)
            fx.ring(player.position, 20.0, 520.0, 0.7, Color(0.5, 0.35, 0.9), 8.0)
            hud.toast("SUPPRESSED!", 1.2)
        "protect":
            player.shield = true
            AudioManager.play_sfx("protect", -4.0)
            fx.ring(player.position, 10.0, 70.0, 0.5, Color(0.6, 0.9, 1.0), 6.0)
            fx.glow_dots(player.position, Color(0.6, 0.9, 1.0), 14, 140.0, 0.6, 5.0)
            hud.toast("Protected!", 1.2)
        "blessing":
            player.hp = minf(player.max_hp, player.hp + 50.0)
            AudioManager.play_sfx("heal", -4.0)
            for i in range(16):
                fx.spawn(player.position + Vector2(randf_range(-26.0, 26.0), randf_range(0.0, 24.0)), Vector2(0.0, randf_range(-120.0, -50.0)), Color(0.6, 1.0, 0.6), 0.9, 5.0, true, "circle", 0.5)
            fx.ring(player.position, 10.0, 60.0, 0.5, Color(0.7, 1.0, 0.7), 5.0)
            fx.dmg_number(player.position + Vector2(0.0, -40.0), 50.0, Color(0.5, 1.0, 0.5))
            hud.toast("Blessed! +50 HP", 1.2)
        "fake":
            # The two high-cost Demon skills must have a real, visible effect.
            AudioManager.play_sfx("demon_skill", -2.0)
            _hit_nearest(220.0, Color(0.9, 0.1, 0.2))
            shake(12.0)
            hud.flash_screen(Color(1.0, 0.2, 0.2, 0.45), 0.35)
            hud.toast("THE DEMON KING PASSES JUDGEMENT: 220 DAMAGE", 1.8)


func _hit_nearest(dmg: float, col: Color = Color.WHITE) -> void:
    var best = null
    var best_d: float = 999999.0
    for e in enemies:
        if e.dead:
            continue
        var d: float = e.position.distance_to(player.position)
        if d < best_d:
            best_d = d
            best = e
    if best != null:
        best.take_damage(dmg)
        fx.skill_strike(best.position, col, dmg >= 150.0)
        shake(5.0)
        AudioManager.play_hit()


## from_pos + knock push the player away from the source of the hit.
func damage_player(amount: float, from_pos: Vector2 = Vector2.ZERO, knock: float = 0.0) -> void:
    if end_result != 0:
        return
    if player.roll_time > 0.0:
        if dodge_cd <= 0.0:
            dodge_cd = 0.5
            fx.dodge(player.position)
            AudioManager.play_sfx("dodge", -8.0)
        return
    if player.invuln > 0.0:
        return
    if player.shield:
        AudioManager.play_sfx("block", -4.0)
        player.shield = false
        player.invuln = 0.4
        fx.ring(player.position, 10.0, 80.0, 0.35, Color(0.6, 0.9, 1.0), 7.0)
        fx.sparks(player.position, Color(0.7, 0.95, 1.0), 14, 380.0)
        hud.toast("Blocked!", 1.0)
        return
    player.hp -= amount
    player.invuln = 0.5
    player.hit_flash = 0.18
    AudioManager.play_sfx("hurt", -3.0)
    fx.player_hurt(player.position, amount)
    shake(clampf(amount * 0.4, 3.0, 12.0))
    hitstop = 0.05
    if knock > 0.0:
        player.position += (player.position - from_pos).normalized() * knock
    hud.flash_screen(Color(1, 0, 0, 0.25), 0.2)


func spawn_projectile(from: Vector2, dir: Vector2, dmg: float) -> void:
    projectiles.append({"pos": from, "vel": dir * 320.0, "dmg": dmg, "life": 3.0})


func _update_projectiles(delta: float) -> void:
    for p in projectiles:
        var pos: Vector2 = p["pos"]
        var vel: Vector2 = p["vel"]
        pos += vel * delta
        p["pos"] = pos
        p["life"] = float(p["life"]) - delta
        # sparkle trail behind each coin
        if randf() < 0.6:
            fx.spawn(pos, Vector2(randf_range(-25.0, 25.0), randf_range(-25.0, 25.0)), Color(1.0, 0.78, 0.25), 0.28, 4.0, true, "circle", 3.0)
        if pos.distance_to(player.position) <= player.radius + 10.0:
            damage_player(float(p["dmg"]), pos, 25.0)
            AudioManager.play_sfx("coin_hit", -6.0)
            fx.coins(pos, 5, 220.0)
            fx.sparks(pos, Color(1.0, 0.9, 0.5), 8, 320.0)
            p["life"] = 0.0
    projectiles = projectiles.filter(func(p): return float(p["life"]) > 0.0)


func _separate() -> void:
    for i in enemies.size():
        for j in range(i + 1, enemies.size()):
            var a: Enemy = enemies[i]
            var b: Enemy = enemies[j]
            if a.dead or b.dead:
                continue
            var d: Vector2 = b.position - a.position
            var min_d: float = (a.radius + b.radius) * 0.8
            var l: float = d.length()
            if l < min_d and l > 0.01:
                var push: Vector2 = d / l * (min_d - l) * 0.5
                a.position -= push
                b.position += push


func _check_end(delta: float) -> void:
    if end_result == 0:
        if player.hp <= 0.0:
            player.hp = 0.0
            end_result = -1
            end_timer = 1.2
            fx.death_burst(player.position, Color(1.0, 0.3, 0.3), true)
            AudioManager.play_sfx("player_die", -2.0, 0.0)
            shake(10.0)
            hud.toast("YOU DIED", 1.5)
            return
        var alive: int = 0
        for e in enemies:
            if not e.dead:
                alive += 1
        if alive == 0:
            end_result = 1
            end_timer = 1.5
            AudioManager.play_sfx("victory", -3.0, 0.0)
            hud.toast("VICTORY!", 1.5)
    else:
        end_timer -= delta
        if end_timer <= 0.0:
            done = true
            finished.emit(end_result == 1)


func _draw() -> void:
    # A decorated, dark-fantasy arena instead of an empty black void.
    draw_rect(Rect2(Vector2.ZERO, GameData.SCREEN), Color("100d18"))
    # Roman colosseum: tiered pale-stone seating surrounds the dark fighting floor.
    draw_rect(Rect2(Vector2.ZERO, GameData.SCREEN), Color("17131b"))
    # Screen-filling stepped colosseum seating: wide elliptical terraces occupy
    # the corners too, while the central fighting floor remains circular and readable.
    var tier_colors := [Color("5c4b42"), Color("897466"), Color("b5a18a"), Color("746153"), Color("d0bda1"), Color("51413b"), Color("392d30")]
    for i in range(7):
        var outer_rx: float = 960.0 - float(i) * 72.0
        var outer_ry: float = 590.0 - float(i) * 45.0
        var inner_rx: float = outer_rx - 48.0
        var inner_ry: float = outer_ry - 31.0
        draw_set_transform(ring_c, 0.0, Vector2(outer_rx / 400.0, outer_ry / 400.0))
        draw_circle(Vector2.ZERO, 400.0, tier_colors[i])
        draw_set_transform(ring_c, 0.0, Vector2(inner_rx / 400.0, inner_ry / 400.0))
        draw_circle(Vector2.ZERO, 400.0, Color("342a2b"))
        draw_set_transform(ring_c, 0.0, Vector2(outer_rx / 400.0, outer_ry / 400.0))
        draw_arc(Vector2.ZERO, 398.0, 0.0, TAU, 128, Color("e0cba9"), 2.0)
        draw_set_transform(ring_c, 0.0, Vector2(inner_rx / 400.0, inner_ry / 400.0))
        draw_arc(Vector2.ZERO, 398.0, 0.0, TAU, 128, Color("211b22"), 3.0)
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
        # Repeated radial dividers read as rows of individual stone seats.
        for seat in range(64):
            var a: float = TAU * float(seat) / 64.0
            var p1: Vector2 = ring_c + Vector2(cos(a) * inner_rx, sin(a) * inner_ry)
            var p2: Vector2 = ring_c + Vector2(cos(a) * outer_rx, sin(a) * outer_ry)
            draw_line(p1, p2, Color("3c3030"), 2.0)
    # Marble arena floor with gold boundary and engraved inner rings.
    draw_circle(ring_c, ring_r + 35.0, Color("251d2a"))
    draw_circle(ring_c, ring_r + 22.0, Color("b18b4c"))
    draw_circle(ring_c, ring_r + 12.0, Color("5d4938"))
    draw_circle(ring_c, ring_r + 4.0, Color("c9b99e"))
    draw_circle(ring_c, ring_r, Color("302a31"))
    draw_circle(ring_c, ring_r - 10.0, Color("383039"))
    draw_arc(ring_c, ring_r - 18.0, 0.0, TAU, 96, Color("473348"), 2.0)
    draw_arc(ring_c, ring_r * 0.72, 0.0, TAU, 96, Color("302438"), 2.0)
    # Small gold markers around the arena edge.
    for i in 24:
        var a: float = TAU * float(i) / 24.0
        var inner: Vector2 = ring_c + Vector2(cos(a), sin(a)) * (ring_r - 8.0)
        var outer: Vector2 = ring_c + Vector2(cos(a), sin(a)) * (ring_r + 7.0)
        draw_line(inner, outer, Color("b78a48"), 3.0)
    # Themed side wings frame each beacon without placeholder captions.
    _draw_beacon_wing("demon", Vector2(238, ring_c.y), Color("6b233f"), Color("d44752"))
    _draw_beacon_wing("angel", Vector2(1042, ring_c.y), Color("f2ead5"), Color("d8b65c"))
    _draw_beacon("demon", Color("8b2e60"))
    _draw_beacon("angel", Color("fff4d6"))
    # Storekeeper's thrown coins: spinning, glowing
    for p in projectiles:
        var pp: Vector2 = p["pos"]
        var spin: float = float(p["life"]) * 16.0
        draw_circle(pp, 22.0, Color(1.0, 0.7, 0.15, 0.14))
        draw_circle(pp, 15.0, Color(1.0, 0.8, 0.2, 0.25))
        draw_set_transform(pp, 0.0, Vector2(maxf(0.25, absf(cos(spin))), 1.0))
        draw_circle(Vector2.ZERO, 10.0, Color("f2c230"))
        draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 16, Color("fff0a0"), 2.0)
        draw_circle(Vector2.ZERO, 4.0, Color("c8901a"))
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_beacon_wing(side: String, pos: Vector2, fill: Color, trim: Color) -> void:
    if Game.is_sold("beacon_" + side):
        return
    var rect := Rect2(pos - Vector2(48, 82), Vector2(96, 164))
    draw_rect(rect, fill)
    draw_rect(rect, trim, false, 4.0)
    draw_rect(Rect2(rect.position + Vector2(6, 6), rect.size - Vector2(12, 12)), Color("110d18"), false, 2.0)
    var art_name: String = "wing_demon" if side == "demon" else "wing_angel"
    Art.draw_sprite(self, art_name, pos + Vector2(0, -2), Vector2(86, 150), Color.WHITE)
    for corner in [rect.position + Vector2(5, 5), rect.position + Vector2(rect.size.x - 5, 5), rect.position + Vector2(5, rect.size.y - 5), rect.position + rect.size - Vector2(5, 5)]:
        draw_circle(corner, 3.0, trim)

func _draw_beacon(side: String, col: Color) -> void:
    if Game.is_sold("beacon_" + side):
        return
    var pos: Vector2 = beacon_pos(side)
    if phase == "prep" and near_side == side:
        draw_arc(pos, 100.0, 0.0, TAU, 40, Color("f0c76b"), 4.0)
    # Small pedestal beneath the existing beacon art.
    draw_rect(Rect2(pos.x - 47.0, pos.y + 65.0, 94.0, 18.0), Color("201522"))
    draw_rect(Rect2(pos.x - 47.0, pos.y + 65.0, 94.0, 18.0), Color("b78a48"), false, 2.0)
    Art.draw_sprite(self, "beacon_" + side, pos, Vector2(96, 160), col)
