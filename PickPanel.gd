extends Panel
# ============================================================================
#  PickPanel.gd  —  panel de selección de UN jugador (scenes/ui/PickPanel.tscn)
# ----------------------------------------------------------------------------
#  Controles (acciones del Input Map):  izquierda/derecha = cambiar personaje,
#  ataque = confirmar, especial = cancelar.
#  El estilo (marco, acento, chip del especial, insignia "listo") se crea por
#  código en _build_style() y se tiñe con CharacterData.color en _refresh().
#  El texto de ayuda de las teclas (Hint) se arma con Keybinds, así que
#  muestra las teclas actuales aunque se hayan cambiado en el menú Controles.
#  Todos los textos tienen caja fija + clip_text: si algo no cabe se recorta,
#  nunca se monta sobre el texto vecino (lo vigila tools/test_ui_layout.gd).
# ============================================================================

export var player_id := 1

var index := 0
var is_ready := false
var dummy := false
var _arrows := []


func setup(id: int, character: String) -> void:
	player_id = id
	index = max(Game.ORDER.find(character), 0)
	$Header.text = "JUGADOR %d" % id
	_update_hint()
	if not Keybinds.is_connected("changed", self, "_update_hint"):
		Keybinds.connect("changed", self, "_update_hint")
	_build_style()
	_build_touch()
	_refresh()


func _update_hint() -> void:
	if dummy:
		return
	if Net.touch_enabled():                                  # en el celular no hay teclas que mostrar
		$Hint.text = "Toca ◄ ► para elegir  ·  toca LISTO para confirmar"
		return
	var p = "p%d_" % player_id
	$Hint.text = "◄ %s   %s ►    golpe %s    especial %s" % [Keybinds.key_name(p + "left"),
		Keybinds.key_name(p + "right"), Keybinds.key_name(p + "attack"), Keybinds.key_name(p + "special")]


# Controles táctiles de la pantalla de personajes: flechas sobre el retrato y tocar LISTO para confirmar /
# cambiar. Con mouse también funcionan. Así se elige personaje sin teclado (celular).
func _build_touch() -> void:
	_arrow(-1, Vector2(28, 178))
	_arrow(1, Vector2(196, 178))
	$ReadyBadge.connect("gui_input", self, "_on_badge_input")


func _arrow(d: int, pos: Vector2) -> void:
	var b := Button.new()
	b.text = "◄" if d < 0 else "►"
	b.rect_position = pos
	b.rect_min_size = Vector2(64, 64)
	b.rect_size = Vector2(64, 64)
	b.add_font_override("font", preload("res://resources/font_med.tres"))
	b.focus_mode = Control.FOCUS_NONE
	b.connect("pressed", self, "_on_arrow", [d])
	add_child(b)
	_arrows.append(b)


func _on_arrow(d: int) -> void:
	if not is_ready and not dummy:
		_move(d)


func _on_badge_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == BUTTON_LEFT and not dummy:
		_set_ready(not is_ready)


func lock_as_dummy() -> void:
	dummy = true
	is_ready = true
	for b in _arrows:
		b.visible = false
	$Header.text = "MUÑECO (P2)"
	$Hint.text = ""
	_refresh()


func set_index(i: int) -> void:
	if i != index:
		index = i
		_refresh()


func character_id() -> String:
	return Game.ORDER[index]


func _process(_delta: float) -> void:
	if dummy:
		return
	var p = "p%d_" % player_id
	if not is_ready:
		if Input.is_action_just_pressed(p + "left"):
			_move(-1)
		elif Input.is_action_just_pressed(p + "right"):
			_move(1)
		elif Input.is_action_just_pressed(p + "attack"):
			_set_ready(true)
	elif Input.is_action_just_pressed(p + "special"):
		_set_ready(false)


func _move(d: int) -> void:
	index = (index + d + Game.ORDER.size()) % Game.ORDER.size()
	$SfxMove.play()
	_refresh()


func _set_ready(v: bool) -> void:
	is_ready = v
	if v:
		$SfxConfirm.play()
	else:
		$SfxBack.play()
	_refresh()


# ----------------------------------------------------------------- estilos
func _build_style() -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.1, 0.16, 0.92)
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(3)
	sb.shadow_size = 10
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.anti_aliasing = true
	add_stylebox_override("panel", sb)

	var chip = StyleBoxFlat.new()
	chip.set_corner_radius_all(16)
	chip.anti_aliasing = true
	$SpecialChip.add_stylebox_override("panel", chip)

	var frame = StyleBoxFlat.new()
	frame.set_corner_radius_all(18)
	frame.set_border_width_all(3)
	frame.anti_aliasing = true
	$PortraitFrame.add_stylebox_override("panel", frame)

	var badge = StyleBoxFlat.new()
	badge.set_corner_radius_all(20)
	badge.set_border_width_all(2)
	badge.anti_aliasing = true
	$ReadyBadge.add_stylebox_override("panel", badge)


func _refresh() -> void:
	var data = Game.CHARACTERS[Game.ORDER[index]]
	var c: Color = data.color

	get_stylebox("panel").border_color = c
	$AccentBar.color = c

	var frame = $PortraitFrame.get_stylebox("panel")
	frame.bg_color = Color(c.r, c.g, c.b, 0.16)
	frame.border_color = c
	$PortraitFrame/Portrait.texture = data.portrait

	$CharName.text = data.display_name
	$CharName.add_color_override("font_color", c)

	var chip = $SpecialChip.get_stylebox("panel")
	chip.bg_color = Color(c.r, c.g, c.b, 0.22)
	$SpecialChip/SpecialName.text = "★ " + data.special_name
	$SpecialChip/SpecialName.add_color_override("font_color", c.lightened(0.45))

	$Desc.text = data.description
	$Dots.text = _dots_text()

	var badge = $ReadyBadge.get_stylebox("panel")
	if is_ready:
		badge.bg_color = Color(0.3, 0.75, 0.42, 0.95)
		badge.border_color = Color(0.55, 0.95, 0.65, 1)
	else:
		badge.bg_color = Color(1, 1, 1, 0.07)
		badge.border_color = Color(1, 1, 1, 0.3)
	$ReadyBadge/ReadyLabel.text = "¡LISTO!" if is_ready else "elige y confirma"
	$ReadyBadge/ReadyLabel.add_color_override("font_color", Color(1, 1, 1, 1) if is_ready else Color(1, 1, 1, 0.7))


func _dots_text() -> String:
	var s = ""
	for i in range(Game.ORDER.size()):
		s += "●  " if i == index else "○  "
	return s.strip_edges()
