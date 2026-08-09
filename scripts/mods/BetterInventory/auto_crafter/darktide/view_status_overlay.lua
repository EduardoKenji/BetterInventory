local UIRenderer = require("scripts/managers/ui/ui_renderer")
local UIWidget = require("scripts/managers/ui/ui_widget")

local Overlay = {}

local WIDGET_DEFINITION = UIWidget.create_definition({
	{
		pass_type = "rect",
		style = {
			color = { 150, 14, 25, 20 },
			offset = { 0, 0, 0 },
		},
	},
	{
		pass_type = "rect",
		style = {
			color = { 220, 164, 139, 69 },
			offset = { 0, 0, 1 },
			size = { 4, nil },
		},
	},
	{
		pass_type = "text",
		value = "",
		value_id = "text",
		style = {
			font_size = 21,
			font_type = "proxima_nova_bold",
			horizontal_alignment = "center",
			offset = { 12, 0, 2 },
			size = { 736, 104 },
			text_color = { 255, 225, 225, 210 },
			vertical_alignment = "center",
		},
	},
}, "screen", nil, {
	760,
	112,
})

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

local function status_text(view)
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

	return type(lines) == "table" and #lines > 0 and table.concat(lines, "\n") or nil
end

function Overlay.install(mod, view_classes)
	if not mod or type(view_classes) ~= "table" then
		return false
	end

	local installed = false

	for _, view_class in ipairs(view_classes) do
		if view_class and type(view_class.draw) == "function" then
			mod:hook(view_class, "draw", function(func, view, dt, t, input_service, layer)
				local results = { func(view, dt, t, input_service, layer) }
				local text = status_text(view)
				local ui_renderer = view._ui_default_renderer or view._ui_renderer

				if text and ui_renderer and view._ui_scenegraph and view._render_settings then
					local widget = view._auto_crafter_status_overlay

					if not widget then
						widget = UIWidget.init("auto_crafter_status_overlay", WIDGET_DEFINITION)
						view._auto_crafter_status_overlay = widget
					end

					local screen = view._ui_scenegraph.screen
					local screen_width = screen and screen.size and tonumber(screen.size[1]) or 1920

					widget.content.text = text
					widget.offset[1] = math.max(0, (screen_width - 760) * 0.5)
					-- The root screen scenegraph uses top-aligned widget coordinates in
					-- these views. Mirroring the HUD element's 42 px inset keeps the
					-- status at the top instead of pinning it near the bottom.
					widget.offset[2] = 42
					widget.offset[3] = 0

					local render_settings = view._render_settings
					local previous_layer = render_settings.start_layer

					render_settings.start_layer = (tonumber(layer) or tonumber(previous_layer) or 0) + 200
					UIRenderer.begin_pass(ui_renderer, view._ui_scenegraph, input_service, dt, render_settings)
					UIWidget.draw(widget, ui_renderer)
					UIRenderer.end_pass(ui_renderer)
					render_settings.start_layer = previous_layer
				end

				return unpack(results)
			end)
			installed = true
		end
	end

	return installed
end

return Overlay
