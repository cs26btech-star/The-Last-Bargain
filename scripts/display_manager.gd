extends Node
## Fullscreen / windowed switching. Autoload "DisplayControl".
## F11 (or Alt+Enter) works everywhere, even while the game is paused.
## The game now STARTS IN FULLSCREEN automatically (not in a web browser, where fullscreen needs a click).

signal changed


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    if not OS.has_feature("web"):
        call_deferred("_start_fullscreen")


func _start_fullscreen() -> void:
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
    changed.emit()


func is_fullscreen() -> bool:
    var m: int = DisplayServer.window_get_mode()
    return m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func label_text() -> String:
    return "WINDOWED  [F11]" if is_fullscreen() else "FULLSCREEN  [F11]"


func toggle() -> void:
    if is_fullscreen():
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
        _fit_window()
    else:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
    changed.emit()


## Back in a window: use 1280x720 (or smaller on small screens) and centre it.
func _fit_window() -> void:
    var scr: int = DisplayServer.window_get_current_screen()
    var sz: Vector2i = DisplayServer.screen_get_size(scr)
    var w: int = mini(1280, int(float(sz.x) * 0.9))
    var h: int = int(float(w) * 9.0 / 16.0)
    if h > int(float(sz.y) * 0.9):
        h = int(float(sz.y) * 0.9)
        w = int(float(h) * 16.0 / 9.0)
    DisplayServer.window_set_size(Vector2i(w, h))
    DisplayServer.window_set_position(DisplayServer.screen_get_position(scr) + (sz - Vector2i(w, h)) / 2)


func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
            toggle()
            get_viewport().set_input_as_handled()
