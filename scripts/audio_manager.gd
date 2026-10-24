extends Node
## Audio helper. Everything is optional: a missing file is simply silent.
##
## Sound effects are intentionally omitted from this build to comply with the competition asset rules.
## MUSIC          res://audio/<name>.ogg  (.mp3 and .wav also work, so you do not even have to convert)
##   bgm                 title, class select, story cards
##   prep                preparation / shopping phase
##   battle              Bouncer and Wolves (and any boss without its own track)
##   battle_pickpocket   Pickpocket
##   battle_storekeeper  Storekeeper
##   battle_bouncer / battle_wolf   optional own tracks for those two
##   ending_win / ending_lose       optional ending-screen music
##
## The file finder is forgiving: "Prep.OGG", "prep.ogg.ogg" (Windows hiding the extension) and "prep (1).ogg" all count as "prep".
## NOTHING PLAYING? Press F9 in the game: it lists every music name and says FOUND / MISSING / BROKEN.
## (The same list is printed in Godot's Output panel when the game starts.)

const MAX_VOICES := 24
const MUSIC_DB := -10.0
const MUSIC_KEYS := ["bgm", "prep", "battle", "battle_bouncer", "battle_wolf", "battle_pickpocket", "battle_storekeeper", "ending_win", "ending_lose"]
const EXTS := ["ogg", "mp3", "wav"]

var music_player: AudioStreamPlayer
var current_music_path: String = ""
var _cache: Dictionary = {}
var _audio_cache: Array = []
var _report_label: Label = null


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS     # music keeps playing in the pause menu, clicks work while paused
    music_player = AudioStreamPlayer.new()
    music_player.name = "MusicPlayer"
    music_player.volume_db = MUSIC_DB
    add_child(music_player)
    call_deferred("_print_report")


func play_click() -> void:
    # Intentionally silent: generated click effects are excluded from the submission build.
    pass


func play_hit() -> void:
    pass # Generated hit effects are excluded from the submission build.


func play_attack_cue(kind: String) -> void:
    pass # Generated boss cues are excluded from the submission build.


## Sound effects are intentionally silent in this submission build.
func play_sfx(sfx_name: String, volume_db: float = -6.0, jitter: float = 0.06) -> void:
    pass # Generated sound effects are excluded from the submission build.


## Plays the first music name from the list that has a usable file, e.g. ["battle_wolf", "battle", "bgm"].
func play_music_named(names: Array) -> void:
    for n in names:
        var path: String = _find_music_file(str(n))
        if path != "" and _get_stream(path) != null:
            play_music(path)
            return
    # nothing found: keep whatever is playing


func play_music(path: String) -> void:
    if current_music_path == path and music_player.playing:
        return
    current_music_path = path
    music_player.stop()
    music_player.stream = null
    var stream: AudioStream = _get_stream(path)
    if stream == null:
        return
    _set_loop(stream)
    music_player.stream = stream
    music_player.volume_db = MUSIC_DB
    music_player.play()


func _set_loop(stream: AudioStream) -> void:
    if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
        stream.set("loop", true)
    elif stream is AudioStreamWAV:
        var bps: int = 2 if stream.format == AudioStreamWAV.FORMAT_16_BITS else 1
        var ch: int = 2 if stream.stereo else 1
        stream.loop_begin = 0
        stream.loop_end = int(float(stream.data.size()) / float(bps * ch))
        stream.loop_mode = AudioStreamWAV.LOOP_FORWARD


# ---------------------------------------------------------------- finding music files

## Every .ogg / .mp3 / .wav in res://audio (also works in an exported game, where files show up as .import).
func _audio_files() -> Array:
    var out: Array = []
    var dir := DirAccess.open("res://audio")
    if dir != null:
        for f in dir.get_files():
            var n: String = f
            if n.ends_with(".import"):
                n = n.trim_suffix(".import")
            elif n.ends_with(".remap"):
                n = n.trim_suffix(".remap")
            if EXTS.has(n.get_extension().to_lower()):
                var path: String = "res://audio/" + n
                if not out.has(path):
                    out.append(path)
    out.sort()
    _audio_cache = out
    return out


## "Prep.OGG.ogg" -> "prep"   "battle (1).ogg" -> "battle"
func _stem(file_name: String) -> String:
    var s: String = file_name.to_lower()
    var changed: bool = true
    while changed:
        changed = false
        for ext in [".import", ".remap", ".ogg", ".mp3", ".wav"]:
            if s.ends_with(ext):
                s = s.trim_suffix(ext)
                changed = true
    var paren: int = s.find(" (")
    if paren > 0 and s.ends_with(")"):
        s = s.substr(0, paren)
    return s.strip_edges()


func _find_music_file(key: String) -> String:
    _audio_cache.clear() # rescan so newly-added/imported tracks are detected during development
    for ext in EXTS:
        var p: String = "res://audio/%s.%s" % [key, ext]
        if ResourceLoader.exists(p):
            return p
    var best: String = ""
    var best_rank: int = 99
    for path in _audio_files():
        if _stem(str(path).get_file()) == key:
            var rank: int = EXTS.find(str(path).get_extension().to_lower())
            if rank < best_rank:
                best = str(path)
                best_rank = rank
    return best


# ---------------------------------------------------------------- the F9 music check

func report_text() -> String:
    var lines: PackedStringArray = []
    lines.append("MUSIC CHECK   (F9 closes this)")
    for k in MUSIC_KEYS:
        var p: String = _find_music_file(str(k))
        var state: String = "MISSING (silent)"
        if p != "":
            if _get_stream(p) != null:
                state = "FOUND   " + p.get_file()
            else:
                state = "BROKEN  " + p.get_file() + "   Godot cannot read it. Re-export a real .ogg, then open the Godot editor once so it imports."
        lines.append(str(k).rpad(20) + state)
    lines.append("")
    var now: String = "nothing"
    if current_music_path != "":
        now = current_music_path.get_file()
    lines.append("Playing now: " + now)
    var names: PackedStringArray = []
    for p2 in _audio_files():
        if not str(p2).get_file().begins_with("sfx_"):
            names.append(str(p2).get_file())
    lines.append("Music-like files in res://audio: " + (", ".join(names) if not names.is_empty() else "none"))
    return "\n".join(lines)


func _print_report() -> void:
    print(report_text())


func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
        _toggle_report()


func _toggle_report() -> void:
    if _report_label != null:
        _report_label.get_parent().queue_free()
        _report_label = null
        return
    var layer := CanvasLayer.new()
    layer.layer = 100
    add_child(layer)
    _report_label = Label.new()
    _report_label.text = report_text()
    _report_label.position = Vector2(24.0, 24.0)
    _report_label.add_theme_font_size_override("font_size", 16)
    _report_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.7))
    _report_label.add_theme_color_override("font_outline_color", Color.BLACK)
    _report_label.add_theme_constant_override("outline_size", 6)
    layer.add_child(_report_label)


# ---------------------------------------------------------------- loading

func _get_stream(path: String) -> AudioStream:
    if _cache.has(path):
        return _cache[path]
    var stream: AudioStream = null
    if ResourceLoader.exists(path):
        var res = load(path)
        if res is AudioStream:
            stream = res
        else:
            push_warning("Audio: %s exists but could not be loaded as audio." % path)
    _cache[path] = stream
    return stream


func _play_optional(path: String, volume_db: float) -> void:
    # Load sound effects only when used. Missing audio is intentionally harmless.
    var stream: AudioStream = _get_stream(path)
    if stream == null or get_child_count() > MAX_VOICES:
        return
    var player := AudioStreamPlayer.new()
    player.stream = stream
    player.volume_db = volume_db
    add_child(player)
    player.finished.connect(player.queue_free)
    player.play()
