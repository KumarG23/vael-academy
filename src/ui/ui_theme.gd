class_name UITheme
extends RefCounted
## AW-56: ONE look for every panel (Neal: "the UI should be more pixel art
## style"). The gold-filigree noble frame (PixelLab kit, AW-32/35) + navy fill,
## extracted from ChoiceMenu so every window draws through the same helper.
## Also a convention hook for a pixel FONT: drop a file at
## assets/fonts/pixel.ttf and font() serves it everywhere UITheme is used.

const PANEL_PATH := "res://assets/art/ui/panel_noble.png"
const FONT_PATH := "res://assets/fonts/pixel.ttf"
const SRC_MARGIN := 58.0   # ornate corner size in the 256px source frame
const DST_MARGIN := 22.0
const FILL := Color(0.11, 0.12, 0.17, 0.96)
const GOLD := Color(0.86, 0.78, 0.45)

static var _panel: Texture2D = null
static var _panel_checked := false
static var _font: Font = null
static var _font_checked := false


## The navy fill + gold pixel frame. Falls back to a flat bordered rect when the
## kit art is missing (code never blocks on art).
static func draw_panel(ci: CanvasItem, rect: Rect2, fill := FILL, source_margin: float = SRC_MARGIN) -> void:
	if fill.a > 0.0:
		ci.draw_rect(rect.grow(-6.0), fill, true)
	var tex := panel()
	if tex == null:
		ci.draw_rect(rect, GOLD, false, 2.0)
		return
	nine_patch(ci, tex, rect, source_margin)


static func nine_patch(ci: CanvasItem, tex: Texture2D, dest: Rect2, source_margin: float = SRC_MARGIN) -> void:
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var sm := source_margin
	# never let the corners overrun a small panel
	var dm := minf(DST_MARGIN, minf(dest.size.x, dest.size.y) * 0.5)
	var sx := [0.0, sm, tw - sm, tw]
	var sy := [0.0, sm, th - sm, th]
	var dx := [dest.position.x, dest.position.x + dm, dest.position.x + dest.size.x - dm, dest.position.x + dest.size.x]
	var dy := [dest.position.y, dest.position.y + dm, dest.position.y + dest.size.y - dm, dest.position.y + dest.size.y]
	for r in range(3):
		for c in range(3):
			var src := Rect2(sx[c], sy[r], sx[c + 1] - sx[c], sy[r + 1] - sy[r])
			var dst := Rect2(dx[c], dy[r], dx[c + 1] - dx[c], dy[r + 1] - dy[r])
			if dst.size.x > 0.0 and dst.size.y > 0.0:
				ci.draw_texture_rect_region(tex, dst, src)


## Cached-in-a-member textures (gotcha #11: draw commands don't hold refs).
static func panel() -> Texture2D:
	if not _panel_checked:
		_panel_checked = true
		if ResourceLoader.exists(PANEL_PATH):
			_panel = load(PANEL_PATH)
	return _panel


## The UI font — the pixel face when assets/fonts/pixel.ttf exists, else the
## system fallback. Drop the file in and every UITheme surface picks it up.
static func font() -> Font:
	if not _font_checked:
		_font_checked = true
		if ResourceLoader.exists(FONT_PATH):
			_font = load(FONT_PATH)
	return _font if _font != null else ThemeDB.fallback_font
