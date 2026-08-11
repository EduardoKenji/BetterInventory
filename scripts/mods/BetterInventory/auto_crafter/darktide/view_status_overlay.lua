local UIRenderer = require("scripts/managers/ui/ui_renderer")
local UIWidget = require("scripts/managers/ui/ui_widget")

local Overlay = {}

local WIDTH = 760
local MINIMUM_HEIGHT = 112
local LINE_HEIGHT = 26
local VERTICAL_PADDING = 8
local TOP_INSET = 42
local BRUNT_HORIZONTAL_OFFSET = 360

local function status_height(line_count)
	return math.max(MINIMUM_HEIGHT, VERTICAL_PADDING + math.max(0, tonumber(line_count) or 0) * LINE_HEIGHT)
end

local WIDGET_DEFINITION = UIWidget.create_definition({
	{
		pass_type = "rect",
		style_id = "background",
		style = {
			color = { 150, 14, 25, 20 },
			horizontal_alignment = "center",
			offset = { 0, TOP_INSET, 0 },
			size = { WIDTH, MINIMUM_HEIGHT },
			vertical_alignment = "top",
		},
	},
	{
		pass_type = "rect",
		style_id = "accent",
		style = {
			color = { 220, 164, 139, 69 },
			horizontal_alignment = "center",
			offset = { -(WIDTH - 4) * 0.5, TOP_INSET, 1 },
			size = { 4, MINIMUM_HEIGHT },
			vertical_alignment = "top",
		},
	},
	{
		pass_type = "text",
		style_id = "text",
		value = "",
		value_id = "text",
		style = {
			font_size = 21,
			font_type = "proxima_nova_bold",
			horizontal_alignment = "center",
			offset = { 0, TOP_INSET + 4, 2 },
			size = { WIDTH - 24, MINIMUM_HEIGHT - VERTICAL_PADDING },
			text_color = { 255, 225, 225, 210 },
			vertical_alignment = "top",
		},
	},
}, "screen")

local function supported_view(view)
	local class_name = tostring(view and view.__class_name or "")

	if string.find(class_name, "Vendor", 1, true) then
		return true
	end

	if string.find(class_name, "Inventory", 1, true) and not string.find(class_name, "Background", 1, true) then
		return true
	end

	return string.find(class_name, "Crafting", 1, true) ~= nil
end

local function horizontal_offset(view)
	local class_name = tostring(view and view.__class_name or "")

	-- Brunt's Custom Armoury owns a wide panel on the left side of the screen.
	-- Move only this vendor overlay clear of that panel; other views stay centered.
	if string.find(class_name, "CreditsGoodsVendorView", 1, true) then
		return BRUNT_HORIZONTAL_OFFSET
	end

	return 0
end

local function status_lines(view)
	if not supported_view(view) then
		return nil
	end

	local bridge = rawget(_G, "AutoCrafterHelperHudState")

	if not bridge or type(bridge.enabled) ~= "function" or bridge.enabled() ~= true then
		return nil
	end

	if type(bridge.visible_context) == "function" and bridge.visible_context() ~= true then
		return nil
	end

	local lines = type(bridge.lines) == "function" and bridge.lines() or nil

	return type(lines) == "table" and #lines > 0 and lines or nil
end

local function draw_status_overlay(view, dt, t, input_service, layer)
	local lines = status_lines(view)
	local text = lines and table.concat(lines, "\n") or nil
	local ui_renderer = view and (view._ui_default_renderer or view._ui_renderer)

	if not text or not ui_renderer or not view._ui_scenegraph or not view._render_settings then
		return false
	end

	local widget = view._auto_crafter_status_overlay

	if not widget then
		widget = UIWidget.init("auto_crafter_status_overlay", WIDGET_DEFINITION)
		view._auto_crafter_status_overlay = widget
	end

	widget.content.text = text
	local height = status_height(#lines)
	widget.style.background.size[2] = height
	widget.style.accent.size[2] = height
	widget.style.text.size[2] = height - VERTICAL_PADDING
	widget.offset[1] = horizontal_offset(view)
	widget.offset[2] = 0
	widget.offset[3] = 0

	local render_settings = view._render_settings
	local previous_layer = render_settings.start_layer

	render_settings.start_layer = (tonumber(layer) or tonumber(previous_layer) or 0) + 200
	UIRenderer.begin_pass(ui_renderer, view._ui_scenegraph, input_service, dt, render_settings)
	UIWidget.draw(widget, ui_renderer)
	UIRenderer.end_pass(ui_renderer)
	render_settings.start_layer = previous_layer

	return true
end

local function is_inventory_view(view)
	return tostring(view and view.__class_name or "") == "InventoryView"
end

local function install_post_draw(mod, view_class, predicate)
	if not view_class or type(view_class.draw) ~= "function" then
		return false
	end

	-- A normal wrapping hook would execute Darktide's complete native draw chain
	-- inside BetterInventory's callback. Hook profilers would then charge every
	-- widget, element, and third-party draw below it to BetterInventory. A safe
	-- hook runs only this small post-draw overlay callback after native rendering.
	mod:hook_safe(view_class, "draw", function(view, dt, t, input_service, layer)
		if not predicate or predicate(view) then
			draw_status_overlay(view, dt, t, input_service, layer)
		end
	end)

	return true
end

function Overlay.install(mod, view_classes)
	if not mod or type(view_classes) ~= "table" then
		return false
	end

	local installed = false
	local base_view = view_classes.base or view_classes[1]
	local item_grid_view = view_classes.item_grid or view_classes[2]
	local inventory_view = view_classes.inventory or view_classes[3]
	local vendor_view = view_classes.vendor or view_classes[4]

	-- InventoryView calls BaseView.draw before drawing its offscreen grid and
	-- loadout widgets. Let its concrete post-draw hook own the overlay so it is
	-- rendered once and remains above those later passes.
	installed = install_post_draw(mod, base_view, function(view)
		return not is_inventory_view(view)
	end) or installed
	installed = install_post_draw(mod, item_grid_view) or installed
	installed = install_post_draw(mod, inventory_view, is_inventory_view) or installed
	installed = install_post_draw(mod, vendor_view) or installed

	return installed
end

return Overlay
