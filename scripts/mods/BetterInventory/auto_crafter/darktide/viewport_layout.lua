local ViewportLayout = {}

local REFERENCE_WIDTH = 1920
local REFERENCE_HEIGHT = 1080
local PANEL_RIGHT_INSET = 95
local PANEL_TOP_INSET = 110
local SAFE_INSET = 12

local function positive_number(value, fallback)
	value = tonumber(value)

	return value and value > 0 and value or fallback
end

function ViewportLayout.default_scale(width, height)
	width = positive_number(width, REFERENCE_WIDTH)
	height = positive_number(height, REFERENCE_HEIGHT)

	return math.min(width / REFERENCE_WIDTH, height / REFERENCE_HEIGHT)
end

function ViewportLayout.virtual_size(width, height, render_scale)
	width = positive_number(width, REFERENCE_WIDTH)
	height = positive_number(height, REFERENCE_HEIGHT)
	render_scale = positive_number(render_scale, ViewportLayout.default_scale(width, height))

	return width / render_scale, height / render_scale
end

function ViewportLayout.panel_pivot(width, height, render_scale, panel_width, panel_height)
	local virtual_width, virtual_height = ViewportLayout.virtual_size(width, height, render_scale)
	panel_width = positive_number(panel_width, 445)
	panel_height = positive_number(panel_height, 520)
	local x = math.max(SAFE_INSET, virtual_width - panel_width - PANEL_RIGHT_INSET)
	local maximum_y = math.max(SAFE_INSET, virtual_height - panel_height - SAFE_INSET)
	local y = math.min(PANEL_TOP_INSET, maximum_y)

	return math.floor(x + 0.5), math.floor(y + 0.5)
end

function ViewportLayout.anchored_panel_pivot(width, height, render_scale, panel_width, panel_height, anchor_right, canvas_top, horizontal_gap, top_inset)
	local virtual_width, virtual_height = ViewportLayout.virtual_size(width, height, render_scale)
	panel_width = positive_number(panel_width, 445)
	panel_height = positive_number(panel_height, 520)
	anchor_right = tonumber(anchor_right)
	canvas_top = tonumber(canvas_top)
	horizontal_gap = tonumber(horizontal_gap) or 72
	top_inset = tonumber(top_inset) or PANEL_TOP_INSET

	if not anchor_right or not canvas_top then
		return ViewportLayout.panel_pivot(width, height, render_scale, panel_width, panel_height)
	end

	local maximum_x = math.max(SAFE_INSET, virtual_width - panel_width - SAFE_INSET)
	local maximum_y = math.max(SAFE_INSET, virtual_height - panel_height - SAFE_INSET)
	local x = math.max(SAFE_INSET, math.min(maximum_x, anchor_right + horizontal_gap))
	local y = math.max(SAFE_INSET, math.min(maximum_y, canvas_top + top_inset))

	return math.floor(x + 0.5), math.floor(y + 0.5)
end

function ViewportLayout.centered_top_pivot(width, height, render_scale, widget_width, widget_height, top_inset)
	local virtual_width, virtual_height = ViewportLayout.virtual_size(width, height, render_scale)
	widget_width = positive_number(widget_width, 760)
	widget_height = positive_number(widget_height, 112)
	top_inset = math.max(0, tonumber(top_inset) or 42)
	local x = math.max(0, (virtual_width - widget_width) * 0.5)
	local y = math.min(top_inset, math.max(0, virtual_height - widget_height))

	return math.floor(x + 0.5), math.floor(y + 0.5)
end

ViewportLayout.PANEL_RIGHT_INSET = PANEL_RIGHT_INSET
ViewportLayout.PANEL_TOP_INSET = PANEL_TOP_INSET
ViewportLayout.REFERENCE_HEIGHT = REFERENCE_HEIGHT
ViewportLayout.REFERENCE_WIDTH = REFERENCE_WIDTH

return ViewportLayout
