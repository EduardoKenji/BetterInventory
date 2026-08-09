local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")

local MINIMUM_HEIGHT = 112
local LINE_HEIGHT = 26
local VERTICAL_PADDING = 8

local function status_height(line_count)
	return math.max(MINIMUM_HEIGHT, VERTICAL_PADDING + math.max(0, tonumber(line_count) or 0) * LINE_HEIGHT)
end

local definitions = {
	scenegraph_definition = {
		screen = UIWorkspaceSettings.screen,
		status = {
			parent = "screen",
			horizontal_alignment = "center",
			vertical_alignment = "top",
			size = { 760, MINIMUM_HEIGHT },
			position = { 0, 42, 80 },
		},
	},
	widget_definitions = {
		status = UIWidget.create_definition({
			{
				pass_type = "rect",
				style = { color = { 150, 14, 25, 20 }, offset = { 0, 0, 0 } },
			},
			{
				pass_type = "rect",
				style = { color = { 220, 164, 139, 69 }, size = { 4, nil }, offset = { 0, 0, 1 } },
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
					text_color = { 255, 225, 225, 210 },
					vertical_alignment = "top",
					offset = { 12, 4, 2 },
					size = { 736, MINIMUM_HEIGHT - VERTICAL_PADDING },
				},
			},
		}, "status"),
	},
}

local HudElementBetterInventoryAutoCrafter = class("HudElementBetterInventoryAutoCrafter", "HudElementBase")

local function visible_context()
	local managers = rawget(_G, "Managers")
	local state = managers and managers.state
	local game_mode = state and state.game_mode
	local ok, mode = pcall(game_mode and game_mode.game_mode_name or function () end, game_mode)

	if not ok or mode ~= "hub" and mode ~= "hub_singleplay" then
		return false
	end

	local party = managers and managers.party_immaterium
	local matchmaking_ok, matchmaking = pcall(party and party.is_in_matchmaking or function () return false end, party)

	return not matchmaking_ok or matchmaking ~= true
end

HudElementBetterInventoryAutoCrafter.init = function (self, parent, draw_layer, start_scale)
	HudElementBetterInventoryAutoCrafter.super.init(self, parent, draw_layer, start_scale, definitions)
	self._visible = false
end

HudElementBetterInventoryAutoCrafter.update = function (self, dt, t, ui_renderer, render_settings, input_service)
	local bridge = rawget(_G, "AutoCrafterHelperHudState")
	local enabled = bridge and type(bridge.enabled) == "function" and bridge.enabled() == true and visible_context()
	local lines = enabled and type(bridge.lines) == "function" and bridge.lines() or nil
	local text = type(lines) == "table" and table.concat(lines, "\n") or ""
	local line_count = type(lines) == "table" and #lines or 0
	local height = status_height(line_count)
	local scenegraph = self._ui_scenegraph and self._ui_scenegraph.status
	local widget = self._widgets_by_name.status

	self._visible = text ~= ""
	if scenegraph and scenegraph.size then
		scenegraph.size[2] = height
	end
	widget.style.text.size[2] = height - VERTICAL_PADDING
	widget.content.text = text
	widget.visible = self._visible
	HudElementBetterInventoryAutoCrafter.super.update(self, dt, t, ui_renderer, render_settings, input_service)
end

HudElementBetterInventoryAutoCrafter.draw = function (self, dt, t, ui_renderer, render_settings, input_service)
	if self._visible then
		HudElementBetterInventoryAutoCrafter.super.draw(self, dt, t, ui_renderer, render_settings, input_service)
	end
end

return HudElementBetterInventoryAutoCrafter
