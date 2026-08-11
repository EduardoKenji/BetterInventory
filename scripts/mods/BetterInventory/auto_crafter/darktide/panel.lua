local UISoundEvents = require("scripts/settings/ui/ui_sound_events")

local Panel = {}

local PANEL_REFERENCE = "auto_crafter_diagnostic_panel"
local PANEL_WIDTH = 445
local PANEL_HEIGHT = 520
local ANCHORED_PANEL_GAP = 72
local ROW_HEIGHT = 32
local COMPACT_ROW_HEIGHT = 26
local STATUS_ROW_HEIGHT = 50
local CURRENCY_ROW_HEIGHT = 58
local QUEUE_JOB_ROW_HEIGHT = 110
local STAT_GRID_BUTTON_HEIGHT = 30
local STAT_GRID_GAP = 6
local STAT_GRID_HEIGHT = STAT_GRID_BUTTON_HEIGHT * 2 + STAT_GRID_GAP
local TRAIT_GRID_GAP = 5
local PERK_GRID_COLUMNS = 4
local PERK_GRID_BUTTON_HEIGHT = 38
local BLESSING_GRID_COLUMNS = 3
local BLESSING_GRID_BUTTON_HEIGHT = 54
local BLESSING_ICON_SIZE = 30
local BLESSING_ICON_MATERIAL = "content/ui/materials/icons/traits/traits_container"
local SECTION_ROW_HEIGHT = 40
local ROW_SPACING = 8
local CONTENT_HORIZONTAL_PADDING = 12
local CONTENT_VERTICAL_PADDING = 10
local STEPPER_CONTROLS_WIDTH = 182
local STEPPER_VALUE_WIDTH = 114
local MAX_OFFER_ROWS = 10
local MAX_SELECTION_ATTEMPTS = 240
local IDLE_POLL_INTERVAL = 0.1
local CURRENCY_ICONS = {
	credits = "content/ui/materials/mission_board/currencies/credits_small_digital",
	diamantine = "content/ui/materials/mission_board/currencies/diamantine_small_digital",
	plasteel = "content/ui/materials/mission_board/currencies/plasteel_small_digital",
}
local SECTION_PLANNER = "planner"
local SECTION_QUEUE = "games_lantern_queue"
local SECTION_MARKS = "marks"
local SECTION_WORKFLOW = "workflow"
local SECTION_RESUMING = "resuming"
local SECTION_TRAITS = "traits"
local SECTION_ESTIMATES = "estimates"

local function default_section_state()
	return {
		[SECTION_QUEUE] = false,
		[SECTION_PLANNER] = false,
		[SECTION_MARKS] = false,
		[SECTION_TRAITS] = true,
		[SECTION_WORKFLOW] = false,
		[SECTION_RESUMING] = false,
		[SECTION_ESTIMATES] = false,
	}
end
local TRAIT_TARGET_PAIRS = {
	auto_crafter_perk_1_target = "auto_crafter_perk_2_target",
	auto_crafter_perk_2_target = "auto_crafter_perk_1_target",
	auto_crafter_blessing_1_target = "auto_crafter_blessing_2_target",
	auto_crafter_blessing_2_target = "auto_crafter_blessing_1_target",
}
local DEFAULT_PERK_IDS = {
	melee = {
		"weapon_trait_melee_common_wield_increased_resistant_damage",
		"weapon_trait_melee_common_wield_increased_super_armor_damage",
	},
	ranged = {
		"weapon_trait_ranged_common_wield_increased_armored_damage",
		"weapon_trait_ranged_common_wield_increased_berserker_damage",
	},
}

local function clean_single_line(value)
	if type(value) ~= "string" then
		return ""
	end

	value = string.gsub(value, "{#[^}]*}", "")
	value = string.gsub(value, "%s+", " ")
	value = string.gsub(value, "^%s+", "")
	value = string.gsub(value, "%s+$", "")

	return value
end

local function weapon_name_with_mark(display_name, mark_name)
	local family = clean_single_line(display_name)
	local mark = clean_single_line(mark_name)
	mark = string.gsub(mark, "%s*[•·]%s*", " ")
	mark = string.gsub(mark, "%s+", " ")

	if family == "" then
		return mark
	end
	if mark == "" or string.find(string.lower(family), string.lower(mark), 1, true) then
		return family
	end

	return mark .. " " .. family
end

Panel.weapon_name_with_mark = weapon_name_with_mark

local function dispatch_trait_press(hotspot, left_callback, right_callback)
	if hotspot and hotspot.on_right_pressed and right_callback then
		right_callback()

		return true
	elseif hotspot and hotspot.on_pressed and left_callback then
		left_callback()

		return true
	end

	return false
end

Panel.dispatch_trait_press = dispatch_trait_press

local function safe_call(fn, ...)
	if type(fn) ~= "function" then
		return false, "method unavailable"
	end

	return pcall(fn, ...)
end

local function keyboard_key_down(name)
	local keyboard = rawget(_G, "Keyboard")
	if not keyboard or type(keyboard.button_index) ~= "function" then
		return false
	end

	local index_ok, index = pcall(keyboard.button_index, name)
	if not index_ok or index == nil then
		index_ok, index = pcall(keyboard.button_index, keyboard, name)
	end

	if not index_ok or index == nil then
		return false
	end

	-- Chords need held state.  Keyboard.pressed() is true only on the first
	-- frame, so Ctrl is normally no longer "pressed" when V arrives.
	if type(keyboard.button) == "function" then
		local ok, value = pcall(keyboard.button, index)
		if not ok then
			ok, value = pcall(keyboard.button, keyboard, index)
		end

		if ok then
			return value == true or (tonumber(value) or 0) > 0
		end
	end

	if type(keyboard.pressed) == "function" then
		local ok, pressed = pcall(keyboard.pressed, index)

		if not ok then
			ok, pressed = pcall(keyboard.pressed, keyboard, index)
		end

		return ok and pressed == true or false
	end

	return false
end

local function ctrl_v_down()
	if not keyboard_key_down("v") then
		return false
	end

	return keyboard_key_down("left ctrl") or keyboard_key_down("right ctrl") or keyboard_key_down("left_control") or keyboard_key_down("right_control")
end

local function safe_member(object, key)
	if type(object) ~= "table" and type(object) ~= "userdata" then
		return nil
	end

	local ok, value = pcall(function()
		return object[key]
	end)

	return ok and value or nil
end

local function value_text(value, fallback)
	if value == nil or value == "" then
		return fallback or "?"
	end

	return tostring(value)
end

local function integer_text(value, fallback)
	local number = tonumber(value)

	if not number then
		return fallback or "?"
	end

	local text = tostring(math.floor(number))
	local changed

	repeat
		text, changed = string.gsub(text, "^(%-?%d+)(%d%d%d)", "%1,%2")
	until changed == 0

	return text
end

local STAT_LABEL_PATTERNS = {
	{ "cleave_damage_and_targets", "Cleave Damage & Targets" },
	{ "armor_pierce", "Penetration" },
	{ "armour_pierce", "Penetration" },
	{ "first_target", "First Target" },
	{ "cleave_targets", "Cleave Targets" },
	{ "cleave_damage", "Cleave Damage" },
	{ "reload_speed", "Reload Speed" },
	{ "warp_resist", "Warp Resistance" },
	{ "heat_management", "Heat Management" },
	{ "charge_speed", "Charge Speed" },
	{ "power_output", "Power Output" },
	{ "explosion_damage", "Explosion Damage" },
	{ "explosion_ap", "Explosion Penetration" },
	{ "first_saw_damage", "First Target" },
	{ "finesse", "Finesse" },
	{ "mobility", "Mobility" },
	{ "stability", "Stability" },
	{ "defence", "Defenses" },
	{ "defense", "Defenses" },
	{ "control", "Control" },
	{ "critical", "Critical Bonus" },
	{ "crit", "Critical Bonus" },
	{ "damage", "Damage" },
	{ "dps", "Damage" },
	{ "ammo", "Ammo" },
	{ "range", "Range" },
	{ "power", "Power" },
	{ "burn", "Burn" },
	{ "vent", "Vent Speed" },
	{ "arc", "Arc" },
}

local function localized_game_text(localization_key)
	if type(localization_key) ~= "string" or localization_key == "" then
		return nil
	end

	local localize_function = rawget(_G, "Localize")

	if type(localize_function) ~= "function" then
		return nil
	end

	local ok, value = pcall(localize_function, localization_key)

	if not ok or type(value) ~= "string" or value == "" or value == localization_key then
		return nil
	end

	return value
end

local function display_stat_name(stat_name, display_name_key)
	local localized = localized_game_text(display_name_key)

	if localized then
		return localized
	end

	local raw_name = string.lower(tostring(stat_name or "?"))

	for _, definition in ipairs(STAT_LABEL_PATTERNS) do
		if string.find(raw_name, definition[1], 1, true) then
			return definition[2]
		end
	end

	local semantic_name = string.match(raw_name, "_p%d+_m%d+_(.+)_stat$") or string.match(raw_name, "_p%d+_(.+)_stat$") or string.match(raw_name, "^(.+)_stat$") or raw_name
	semantic_name = string.gsub(semantic_name, "_", " ")
	semantic_name = string.gsub(semantic_name, "(%a)([%w']*)", function (first, rest)
		return string.upper(first) .. rest
	end)

	return semantic_name
end

local function wallet_amount(snapshot, currency)
	local wallets = snapshot and snapshot.wallets
	local currencies = wallets and wallets.currencies
	local entry = currencies and currencies[currency]

	return entry and entry.amount
end

local function offer_row_passes(width, height)
	local label_width = width - 220
	local detail_x = width - 200

	local function selected(content)
		return content.selected == true
	end

	local function not_selected(content)
		return content.selected ~= true
	end

	return {
		{
			content_id = "hotspot",
			pass_type = "hotspot",
			content = {
				on_hover_sound = UISoundEvents.default_mouse_hover,
				on_pressed_sound = UISoundEvents.default_click,
			},
		},
		{
			pass_type = "rect",
			style_id = "selected_background",
			style = {
				color = Color.terminal_corner_selected(90, true),
				offset = {
					0,
					0,
					1,
				},
				size = {
					width,
					height,
				},
			},
			visibility_function = selected,
		},
		{
			pass_type = "rect",
			style_id = "normal_background",
			style = {
				color = Color.terminal_background(220, true),
				offset = {
					0,
					0,
					1,
				},
				size = {
					width,
					height,
				},
			},
			visibility_function = not_selected,
		},
		{
			pass_type = "texture",
			style_id = "frame",
			value = "content/ui/materials/frames/frame_tile_2px",
			style = {
				color = Color.terminal_frame(255, true),
				offset = {
					0,
					0,
					3,
				},
				size = {
					width,
					height,
				},
			},
		},
		{
			pass_type = "text",
			style_id = "label",
			value_id = "label",
			style = {
				font_size = 15,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_body(255, true),
				offset = {
					12,
					0,
					4,
				},
				size = {
					label_width,
					height,
				},
			},
			visibility_function = not_selected,
		},
		{
			pass_type = "text",
			style_id = "selected_label",
			value_id = "label",
			style = {
				font_size = 15,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "center",
				text_color = Color.terminal_corner_selected(255, true),
				offset = {
					12,
					0,
					4,
				},
				size = {
					label_width,
					height,
				},
			},
			visibility_function = selected,
		},
		{
			pass_type = "text",
			style_id = "detail",
			value_id = "detail",
			style = {
				font_size = 14,
				font_type = "proxima_nova_medium",
				text_horizontal_alignment = "right",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_body_sub_header(255, true),
				offset = {
					detail_x,
					0,
					4,
				},
				size = {
					width - detail_x - 34,
					height,
				},
			},
			visibility_function = not_selected,
		},
		{
			pass_type = "text",
			style_id = "selected_detail",
			value_id = "detail",
			style = {
				font_size = 14,
				font_type = "proxima_nova_medium",
				text_horizontal_alignment = "right",
				text_vertical_alignment = "center",
				text_color = Color.terminal_corner_selected(255, true),
				offset = {
					detail_x,
					0,
					4,
				},
				size = {
					width - detail_x - 34,
					height,
				},
			},
			visibility_function = selected,
		},
		{
			pass_type = "text",
			style_id = "selected_mark",
			value = "✓",
			style = {
				font_size = 16,
				font_type = "proxima_nova_bold",
				horizontal_alignment = "right",
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				text_color = Color.terminal_corner_selected(255, true),
				offset = {
					-4,
					0,
					5,
				},
				size = {
					28,
					height,
				},
			},
			visibility_function = selected,
		},
	}
end

local function title_passes(width)
	return {
		{ pass_type = "rect", style = { color = Color.terminal_background(210, true), size = { width, SECTION_ROW_HEIGHT }, offset = { 0, 0, 1 } } },
		{ pass_type = "texture", value = "content/ui/materials/frames/frame_tile_2px", style = { color = Color.terminal_frame(255, true), size = { width, SECTION_ROW_HEIGHT }, offset = { 0, 0, 2 } } },
		{ pass_type = "text", value_id = "label", style = { font_size = 18, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "center", text_color = Color.terminal_text_header(255, true), size = { width - 190, SECTION_ROW_HEIGHT }, offset = { 10, 0, 3 } } },
		{ pass_type = "text", value_id = "detail", style = { font_size = 13, font_type = "proxima_nova_medium", text_horizontal_alignment = "right", text_vertical_alignment = "center", text_color = Color.terminal_text_body_sub_header(255, true), size = { 170, SECTION_ROW_HEIGHT }, offset = { width - 180, 0, 3 } } },
	}
end

local function summary_line_passes(width)
	return {
		{ pass_type = "text", value_id = "label", style = { font_size = 15, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "center", text_color = Color.terminal_text_body(255, true), size = { 120, COMPACT_ROW_HEIGHT } } },
		{ pass_type = "text", value_id = "detail", style = { font_size = 14, font_type = "proxima_nova_medium", text_horizontal_alignment = "right", text_vertical_alignment = "center", text_color = Color.terminal_text_body_sub_header(255, true), size = { width - 128, COMPACT_ROW_HEIGHT }, offset = { 128, 0, 1 } } },
	}
end

local function status_block_passes(width)
	return {
		{ pass_type = "text", value_id = "label", style = { font_size = 15, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "top", text_color = Color.terminal_text_body(255, true), size = { width, 18 } } },
		{ pass_type = "text", value_id = "detail", style = { font_size = 13, font_type = "proxima_nova_medium", text_horizontal_alignment = "left", text_vertical_alignment = "top", text_color = Color.terminal_text_body_sub_header(255, true), size = { width, 30 }, offset = { 0, 18, 1 } } },
	}
end

local function queue_job_passes(width, height, highlighted)
	height = height or QUEUE_JOB_ROW_HEIGHT
	local border_color = highlighted and Color.terminal_corner_selected(255, true) or Color.terminal_frame(255, true)
	local label_color = highlighted and Color.terminal_corner_selected(255, true) or Color.terminal_text_header(255, true)

	return {
		{ pass_type = "rect", style = { color = Color.terminal_background(220, true), size = { width, height }, offset = { 0, 0, 1 } } },
		{ pass_type = "texture", value = "content/ui/materials/frames/frame_tile_2px", style = { color = border_color, size = { width, height }, offset = { 0, 0, 2 } } },
		{ pass_type = "text", value_id = "label", style = { font_size = 15, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "top", text_color = label_color, size = { width - 16, 20 }, offset = { 8, 5, 3 } } },
		{ pass_type = "text", value_id = "detail", style = { font_size = 12, font_type = "proxima_nova_medium", text_horizontal_alignment = "left", text_vertical_alignment = "top", text_color = Color.terminal_text_body(255, true), size = { width - 16, height - 28 }, offset = { 8, 25, 3 } } },
	}
end

local function currency_row_passes(width)
	local segment_width = width / 3
	local passes = {
		{ pass_type = "text", value_id = "label", style = { font_size = 14, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "top", text_color = Color.terminal_text_body(255, true), size = { width, 20 } } },
	}
	local currencies = { "credits", "plasteel", "diamantine" }

	for index, currency in ipairs(currencies) do
		local x = (index - 1) * segment_width

		passes[#passes + 1] = { pass_type = "texture", value = CURRENCY_ICONS[currency], style = { size = { 24, 24 }, offset = { x, 27, 2 } } }
		passes[#passes + 1] = { pass_type = "text", value_id = currency, style = { font_size = 14, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "center", text_color = Color.terminal_text_body_sub_header(255, true), size = { segment_width - 28, 30 }, offset = { x + 28, 24, 3 } } }
	end

	return passes
end

local function section_header_passes(width)
	return {
		{ content_id = "hotspot", pass_type = "hotspot", content = { on_hover_sound = UISoundEvents.default_mouse_hover, on_pressed_sound = UISoundEvents.default_click } },
		{ pass_type = "rect", style = { color = Color.terminal_background(210, true), size = { width, SECTION_ROW_HEIGHT }, offset = { 0, 0, 1 } } },
		{ pass_type = "texture", value = "content/ui/materials/frames/frame_tile_2px", style = { color = Color.terminal_frame(255, true), size = { width, SECTION_ROW_HEIGHT }, offset = { 0, 0, 2 } } },
		{ pass_type = "text", value_id = "label", style = { font_size = 18, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "center", text_color = Color.terminal_text_header(255, true), size = { width - 115, SECTION_ROW_HEIGHT }, offset = { 10, 0, 3 } } },
		{ pass_type = "text", value_id = "detail", style = { font_size = 14, font_type = "proxima_nova_medium", text_horizontal_alignment = "right", text_vertical_alignment = "center", text_color = Color.terminal_text_body_sub_header(255, true), size = { 50, SECTION_ROW_HEIGHT }, offset = { width - 94, 0, 3 } } },
		{ pass_type = "text", style_id = "chevron", value_id = "chevron", style = { font_size = 18, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_text_header(255, true), size = { 40, SECTION_ROW_HEIGHT }, offset = { width - 40, 0, 4 } } },
	}
end

local function compact_selector_passes(width)
	local selector_width = 235
	local selector_x = width - selector_width
	return {
		{ pass_type = "text", value_id = "label", style = { font_size = 15, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "center", text_color = Color.terminal_text_body(255, true), size = { selector_x - 8, COMPACT_ROW_HEIGHT } } },
		{ content_id = "hotspot", pass_type = "hotspot", content = { on_hover_sound = UISoundEvents.default_mouse_hover, on_pressed_sound = UISoundEvents.default_click }, style = { size = { selector_width, COMPACT_ROW_HEIGHT }, offset = { selector_x, 0, 5 } } },
		{ pass_type = "rect", style = { color = Color.terminal_background(220, true), size = { selector_width, COMPACT_ROW_HEIGHT }, offset = { selector_x, 0, 1 } } },
		{ pass_type = "texture", value = "content/ui/materials/frames/frame_tile_2px", style = { color = Color.terminal_frame(255, true), size = { selector_width, COMPACT_ROW_HEIGHT }, offset = { selector_x, 0, 2 } } },
		{ pass_type = "text", value_id = "detail", style = { font_size = 15, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_text_body(255, true), size = { selector_width, COMPACT_ROW_HEIGHT }, offset = { selector_x, 0, 3 } } },
	}
end

local function compact_checkbox_passes(width, height)
	height = height or COMPACT_ROW_HEIGHT
	local checkbox_y = 2
	local function enabled(content) return content.enabled == true end
	local function disabled(content) return content.enabled ~= true end
	return {
		{ content_id = "hotspot", pass_type = "hotspot", content = { on_hover_sound = UISoundEvents.default_mouse_hover, on_pressed_sound = UISoundEvents.default_click } },
		{ pass_type = "rect", style = { color = Color.terminal_background(220, true), size = { 22, 22 }, offset = { 0, checkbox_y, 1 } } },
		{ pass_type = "texture", value = "content/ui/materials/frames/frame_tile_2px", style = { color = Color.terminal_frame(255, true), size = { 22, 22 }, offset = { 0, checkbox_y, 2 } } },
		{ pass_type = "text", style_id = "selected_mark", value = "✓", style = { font_size = 17, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_corner_selected(255, true), size = { 22, 22 }, offset = { 0, 2, 3 } }, visibility_function = function(content) return content.checked == true end },
		{ pass_type = "text", value_id = "label", style = { font_size = 15, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "center", text_color = Color.terminal_text_body(255, true), size = { width - 28, height }, offset = { 28, 0, 3 } }, visibility_function = enabled },
		{ pass_type = "text", value_id = "label", style = { font_size = 15, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "center", text_color = Color.terminal_text_body_sub_header(150, true), size = { width - 28, height }, offset = { 28, 0, 3 } }, visibility_function = disabled },
	}
end

local function compact_stepper_passes(width)
	local controls_x = width - STEPPER_CONTROLS_WIDTH
	return {
		{ pass_type = "text", value_id = "label", style = { font_size = 15, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "center", text_color = Color.terminal_text_body(255, true), size = { controls_x - 8, COMPACT_ROW_HEIGHT } } },
		{ content_id = "decrease_hotspot", pass_type = "hotspot", content = { on_hover_sound = UISoundEvents.default_mouse_hover, on_pressed_sound = UISoundEvents.default_click }, style = { size = { 32, COMPACT_ROW_HEIGHT }, offset = { controls_x, 0, 5 } } },
		{ pass_type = "text", value = "<", style = { font_size = 16, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_text_header(255, true), size = { 32, COMPACT_ROW_HEIGHT }, offset = { controls_x, 0, 3 } } },
		{ pass_type = "rect", style = { color = Color.terminal_background(220, true), size = { STEPPER_VALUE_WIDTH, COMPACT_ROW_HEIGHT }, offset = { controls_x + 34, 0, 1 } } },
		{ pass_type = "texture", value = "content/ui/materials/frames/frame_tile_2px", style = { color = Color.terminal_frame(255, true), size = { STEPPER_VALUE_WIDTH, COMPACT_ROW_HEIGHT }, offset = { controls_x + 34, 0, 2 } } },
		{ pass_type = "text", value_id = "detail", style = { font_size = 15, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_text_body(255, true), size = { STEPPER_VALUE_WIDTH, COMPACT_ROW_HEIGHT }, offset = { controls_x + 34, 0, 3 } } },
		{ content_id = "increase_hotspot", pass_type = "hotspot", content = { on_hover_sound = UISoundEvents.default_mouse_hover, on_pressed_sound = UISoundEvents.default_click }, style = { size = { 32, COMPACT_ROW_HEIGHT }, offset = { controls_x + 150, 0, 5 } } },
		{ pass_type = "text", value = ">", style = { font_size = 16, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_text_header(255, true), size = { 32, COMPACT_ROW_HEIGHT }, offset = { controls_x + 150, 0, 3 } } },
	}
end

local function enum_stepper_passes(width)
	-- Long vanilla perk descriptions need more room than stat/request enums.
	-- Keep one line at common UI scales while retaining a usable label column.
	local controls_width = 320
	local controls_x = width - controls_width
	local value_width = controls_width - 68
	return {
		{ pass_type = "text", value_id = "label", style = { font_size = 15, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "center", text_color = Color.terminal_text_body(255, true), size = { controls_x - 8, COMPACT_ROW_HEIGHT } } },
		{ content_id = "decrease_hotspot", pass_type = "hotspot", content = { on_hover_sound = UISoundEvents.default_mouse_hover, on_pressed_sound = UISoundEvents.default_click }, style = { size = { 32, COMPACT_ROW_HEIGHT }, offset = { controls_x, 0, 5 } } },
		{ pass_type = "text", value = "<", style = { font_size = 16, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_text_header(255, true), size = { 32, COMPACT_ROW_HEIGHT }, offset = { controls_x, 0, 3 } } },
		{ pass_type = "rect", style = { color = Color.terminal_background(220, true), size = { value_width, COMPACT_ROW_HEIGHT }, offset = { controls_x + 34, 0, 1 } } },
		{ pass_type = "texture", value = "content/ui/materials/frames/frame_tile_2px", style = { color = Color.terminal_frame(255, true), size = { value_width, COMPACT_ROW_HEIGHT }, offset = { controls_x + 34, 0, 2 } } },
		{ pass_type = "text", value_id = "detail", style = { font_size = 13, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_text_body(255, true), size = { value_width, COMPACT_ROW_HEIGHT }, offset = { controls_x + 34, 0, 3 } } },
		{ content_id = "increase_hotspot", pass_type = "hotspot", content = { on_hover_sound = UISoundEvents.default_mouse_hover, on_pressed_sound = UISoundEvents.default_click }, style = { size = { 32, COMPACT_ROW_HEIGHT }, offset = { controls_x + controls_width - 32, 0, 5 } } },
		{ pass_type = "text", value = ">", style = { font_size = 16, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_text_header(255, true), size = { 32, COMPACT_ROW_HEIGHT }, offset = { controls_x + controls_width - 32, 0, 3 } } },
	}
end

local function stat_grid_passes(width, entry)
	local count = math.min(#(entry and entry.stat_buttons or {}), 5)
	local passes = {
		{
			pass_type = "logic",
			value = function(_, _, _, content)
				for index = 1, content.stat_count or 0 do
					local hotspot = content["stat_hotspot_" .. tostring(index)]
					local stat_button = entry and entry.stat_buttons and entry.stat_buttons[index]

					if hotspot and hotspot.on_pressed and stat_button and entry.stat_pressed_callback then
						entry.stat_pressed_callback(stat_button.name)

						break
					end
				end
			end,
		},
	}
	local function selected(index)
		return function(content)
			return (content.stat_count or 0) >= index and content.selected_stat_index == index
		end
	end
	local function not_selected(index)
		return function(content)
			return (content.stat_count or 0) >= index and content.selected_stat_index ~= index
		end
	end
	local function hovered(index)
		return function(content)
			local hotspot = content["stat_hotspot_" .. tostring(index)]

			return (content.stat_count or 0) >= index and hotspot and hotspot.is_hover == true and content.selected_stat_index ~= index
		end
	end

	for index = 1, count do
		local columns = index <= 3 and 3 or 2
		local column = index <= 3 and index - 1 or index - 4
		local row = index <= 3 and 0 or 1
		local button_width = (width - STAT_GRID_GAP * (columns - 1)) / columns
		local x = column * (button_width + STAT_GRID_GAP)
		local y = row * (STAT_GRID_BUTTON_HEIGHT + STAT_GRID_GAP)
		local hotspot_id = "stat_hotspot_" .. tostring(index)
		local label_id = "stat_label_" .. tostring(index)

		passes[#passes + 1] = { content_id = hotspot_id, pass_type = "hotspot", content = { on_hover_sound = UISoundEvents.default_mouse_hover, on_pressed_sound = UISoundEvents.default_click }, style = { size = { button_width, STAT_GRID_BUTTON_HEIGHT }, offset = { x, y, 6 } } }
		passes[#passes + 1] = { pass_type = "rect", style = { color = Color.terminal_corner_selected(110, true), size = { button_width, STAT_GRID_BUTTON_HEIGHT }, offset = { x, y, 1 } }, visibility_function = selected(index) }
		passes[#passes + 1] = { pass_type = "rect", style = { color = Color.terminal_background(220, true), size = { button_width, STAT_GRID_BUTTON_HEIGHT }, offset = { x, y, 1 } }, visibility_function = not_selected(index) }
		passes[#passes + 1] = { pass_type = "rect", style = { color = Color.terminal_corner_selected(55, true), size = { button_width, STAT_GRID_BUTTON_HEIGHT }, offset = { x, y, 2 } }, visibility_function = hovered(index) }
		passes[#passes + 1] = { pass_type = "texture", value = "content/ui/materials/frames/frame_tile_2px", style = { color = Color.terminal_frame(255, true), size = { button_width, STAT_GRID_BUTTON_HEIGHT }, offset = { x, y, 2 } } }
		passes[#passes + 1] = { pass_type = "text", value_id = label_id, style = { font_size = 13, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_corner_selected(255, true), size = { button_width - 8, STAT_GRID_BUTTON_HEIGHT }, offset = { x + 4, y, 3 } }, visibility_function = selected(index) }
		passes[#passes + 1] = { pass_type = "text", value_id = label_id, style = { font_size = 13, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_text_body(255, true), size = { button_width - 8, STAT_GRID_BUTTON_HEIGHT }, offset = { x + 4, y, 3 } }, visibility_function = not_selected(index) }
	end

	return passes
end

Panel.stat_grid_passes = stat_grid_passes

local function trait_grid_passes(width, entry)
	local count = entry.trait_count or 0
	local columns = entry.trait_columns or PERK_GRID_COLUMNS
	local button_height = entry.trait_button_height or PERK_GRID_BUTTON_HEIGHT
	local show_icons = entry.trait_icons == true
	local button_width = (width - TRAIT_GRID_GAP * (columns - 1)) / columns
	local passes = {
		{
			pass_type = "logic",
			value = function(_, _, _, content)
				local left_callbacks = content.trait_left_callbacks or {}
				local right_callbacks = content.trait_right_callbacks or {}

				for index = 1, content.trait_count or 0 do
					local hotspot = content["trait_hotspot_" .. tostring(index)]

					if dispatch_trait_press(hotspot, left_callbacks[index], right_callbacks[index]) then
						break
					end
				end
			end,
		},
	}

	for index = 1, count do
		local column = (index - 1) % columns
		local row = math.floor((index - 1) / columns)
		local x = column * (button_width + TRAIT_GRID_GAP)
		local y = row * (button_height + TRAIT_GRID_GAP)
		local hotspot_id = "trait_hotspot_" .. tostring(index)
		local label_id = "trait_label_" .. tostring(index)
		local icon_id = "trait_icon_" .. tostring(index)
		local function target_one(content)
			return content.trait_target_1_index == index
		end
		local function target_two(content)
			return content.trait_target_2_index == index
		end
		local function unselected(content)
			return content.trait_target_1_index ~= index and content.trait_target_2_index ~= index
		end
		local function has_icon(content)
			return show_icons and type(content[icon_id]) == "string" and content[icon_id] ~= ""
		end
		local text_x = show_icons and BLESSING_ICON_SIZE + 7 or 4
		local text_width = button_width - text_x - 4

		passes[#passes + 1] = { content_id = hotspot_id, pass_type = "hotspot", content = { on_hover_sound = UISoundEvents.default_mouse_hover, on_pressed_sound = UISoundEvents.default_click }, style = { size = { button_width, button_height }, offset = { x, y, 6 } } }
		passes[#passes + 1] = { pass_type = "rect", style = { color = Color.terminal_corner_selected(120, true), size = { button_width, button_height }, offset = { x, y, 1 } }, visibility_function = target_one }
		passes[#passes + 1] = { pass_type = "rect", style = { color = { 180, 65, 165, 75 }, size = { button_width, button_height }, offset = { x, y, 1 } }, visibility_function = target_two }
		passes[#passes + 1] = { pass_type = "rect", style = { color = Color.terminal_background(220, true), size = { button_width, button_height }, offset = { x, y, 1 } }, visibility_function = unselected }
		passes[#passes + 1] = { pass_type = "texture", value = "content/ui/materials/frames/frame_tile_2px", style = { color = Color.terminal_frame(255, true), size = { button_width, button_height }, offset = { x, y, 2 } } }
		if show_icons then
			passes[#passes + 1] = { pass_type = "texture", style_id = icon_id, value = BLESSING_ICON_MATERIAL, style = { color = Color.white(255, true), material_values = { frame = "", icon = "" }, size = { BLESSING_ICON_SIZE, BLESSING_ICON_SIZE }, offset = { x + 5, y + (button_height - BLESSING_ICON_SIZE) / 2, 3 } }, visibility_function = has_icon }
		end
		passes[#passes + 1] = { pass_type = "text", value_id = label_id, style = { font_size = show_icons and 12 or 11, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_text_header(255, true), size = { text_width, button_height }, offset = { x + text_x, y, 4 } } }
	end

	return passes
end

local function action_button_passes(width)
	local function enabled(content) return content.enabled == true end
	local function disabled(content) return content.enabled ~= true end
	return {
		{ content_id = "hotspot", pass_type = "hotspot", content = { on_hover_sound = UISoundEvents.default_mouse_hover, on_pressed_sound = UISoundEvents.default_click } },
		{ pass_type = "rect", style = { color = Color.terminal_corner_selected(110, true), size = { width, ROW_HEIGHT }, offset = { 0, 0, 1 } }, visibility_function = enabled },
		{ pass_type = "rect", style = { color = Color.terminal_background(220, true), size = { width, ROW_HEIGHT }, offset = { 0, 0, 1 } }, visibility_function = disabled },
		{ pass_type = "texture", value = "content/ui/materials/frames/frame_tile_2px", style = { color = Color.terminal_frame(255, true), size = { width, ROW_HEIGHT }, offset = { 0, 0, 2 } } },
		{ pass_type = "text", value_id = "label", style = { font_size = 16, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "center", text_color = Color.terminal_text_header(255, true), size = { width - 20, ROW_HEIGHT }, offset = { 10, 0, 3 } } },
	}
end

local BLUEPRINTS = {
	auto_crafter_row = {
		size_function = function(_, entry)
			return entry.size
		end,
		pass_template_function = function(_, entry)
			local width = entry.size[1]
			local variant = entry.variant

			if variant == "title" then
				return title_passes(width)
			elseif variant == "status" then
				return status_block_passes(width)
			elseif variant == "queue_job" then
				return queue_job_passes(width, entry.size[2], entry.initial_content and entry.initial_content.queue_current == true)
			elseif variant == "currency" then
				return currency_row_passes(width)
			elseif variant == "section" then
				return section_header_passes(width)
			elseif variant == "selector" then
				return compact_selector_passes(width)
			elseif variant == "checkbox" then
				return compact_checkbox_passes(width, entry.size[2])
			elseif variant == "stepper" then
				return compact_stepper_passes(width)
			elseif variant == "enum_stepper" then
				return enum_stepper_passes(width)
			elseif variant == "stat_grid" then
				return stat_grid_passes(width, entry)
			elseif variant == "trait_grid" then
				return trait_grid_passes(width, entry)
			elseif variant == "action" then
				return action_button_passes(width)
			elseif variant == "offer" then
				return offer_row_passes(width, entry.size[2])
			end

			return summary_line_passes(width)
		end,
		init = function(parent, widget, entry, callback_name)
			for key, value in pairs(entry.initial_content or {}) do
				widget.content[key] = type(value) == "table" and table.clone(value) or value
			end

			widget.content.entry = entry
			widget.content.element = entry

			if callback_name and widget.content.hotspot and entry.offer then
				widget.content.hotspot.pressed_callback = callback(parent, callback_name, widget, entry)
			end

			if entry.bind then
				entry.bind(widget)
			end

			if entry.refresh then
				entry.refresh(widget)
			end
		end,
		update = function(_, widget)
			local entry = widget.content.entry

			if entry and entry.refresh then
				entry.refresh(widget)
			end
		end,
	},
}

local function offer_label(offer, index)
	return value_text(offer and offer.display_name, value_text(offer and offer.master_id, "Offer " .. tostring(index)))
end

local function offer_selection_key(offer)
	if not offer then
		return nil
	end

	if offer.offer_id ~= nil then
		return "offer:" .. tostring(offer.offer_id)
	end

	if offer.master_id ~= nil then
		return "master:" .. tostring(offer.master_id)
	end

	if offer.display_name ~= nil then
		return "name:" .. tostring(offer.display_name)
	end

	return nil
end

local function offer_detail(offer)
	local price = offer and offer.price_amount
	local price_text = price and tostring(price) or "price ?"
	local pattern = offer and offer.parent_pattern

	return price_text .. " | " .. value_text(pattern, "pattern ?")
end

function Panel.new(dependencies)
	dependencies = dependencies or {}

	local self = {
		_get_selected_offer = dependencies.get_selected_offer,
		_select_offer = dependencies.select_offer,
		_select_manual_mark = dependencies.select_manual_mark,
		_get_selected_manual_mark = dependencies.get_selected_manual_mark,
		_preview_plan = dependencies.preview_plan,
		_start_purchase_search = dependencies.start_purchase_search,
		_stop_active_run = dependencies.stop_active_run,
		_games_lantern_queue_snapshot = dependencies.games_lantern_queue_snapshot,
		_games_lantern_import_snapshot = dependencies.games_lantern_import_snapshot,
		_games_lantern_paste = dependencies.games_lantern_paste,
		_games_lantern_clear = dependencies.games_lantern_clear,
		_games_lantern_select_choice = dependencies.games_lantern_select_choice,
		_get_games_lantern_cost_authority = dependencies.games_lantern_cost_authority,
		_start_games_lantern_queue = dependencies.start_games_lantern_queue,
		_queue_craft_armed = false,
		_queue_craft_confirmation_signature = nil,
		_queue_craft_confirmation_text = nil,
		_queue_snapshot_cache = nil,
		_import_snapshot_cache = nil,
		_presentation_snapshots_dirty = true,
		_settings = dependencies.settings or {},
		_localize = dependencies.localize,
		_compact_perk_label = dependencies.compact_perk_label,
		_logger = dependencies.logger,
		_ViewElementGrid = dependencies.ViewElementGrid,
		_viewport_layout = dependencies.viewport_layout,
		_panel = nil,
		_view = nil,
		_snapshot = nil,
		_controller_state = nil,
		_plan = nil,
		_phase = "idle",
		_selected_offer_id = nil,
		_selected_offer_key = nil,
		_selected_offer = nil,
		_selected_offer_master_id = nil,
		_section_collapsed = default_section_state(),
		_pending_offer = nil,
		_pending_offer_attempts = 0,
		_idle_poll_elapsed = 0,
		_layout_pending = false,
		_layout_defer_frames = 0,
		_trait_catalog_key = nil,
		_queue_signature = nil,
		_ctrl_v_down = false,
		_pivot_x = nil,
		_pivot_y = nil,
	}

	local function localize(setting_id, fallback)
		if type(self._localize) ~= "function" then
			return fallback or setting_id
		end

		local ok, text = pcall(self._localize, setting_id)

		if not ok or type(text) ~= "string" or text == "" or text == setting_id or text == "<" .. tostring(setting_id) .. ">" then
			return fallback or setting_id
		end

		return text
	end

	local function log(level, message)
		local logger = self._logger and self._logger[level]

		if type(logger) == "function" then
			pcall(logger, self._logger, message)
		end
	end

	function self:_queue_layout(frames)
		self._layout_pending = true
		self._layout_defer_frames = math.max(self._layout_defer_frames or 0, tonumber(frames) or 1)
		self._presentation_snapshots_dirty = true
	end

	function self:_entry(label, detail, options)
		options = options or {}
		local variant = options.variant or "summary"
		local height = options.height or COMPACT_ROW_HEIGHT

		if variant == "title" or variant == "section" then
			height = SECTION_ROW_HEIGHT
		elseif variant == "status" then
			height = STATUS_ROW_HEIGHT
		elseif variant == "queue_job" then
			height = options.height or QUEUE_JOB_ROW_HEIGHT
		elseif variant == "currency" then
			height = CURRENCY_ROW_HEIGHT
		elseif variant == "stat_grid" then
			height = STAT_GRID_HEIGHT
		elseif variant == "trait_grid" then
			local columns = options.trait_columns or PERK_GRID_COLUMNS
			local button_height = options.trait_button_height or PERK_GRID_BUTTON_HEIGHT
			local rows = math.max(1, math.ceil(#(options.trait_options or {}) / columns))

			height = rows * button_height + (rows - 1) * TRAIT_GRID_GAP
		elseif variant == "offer" or variant == "action" then
			height = ROW_HEIGHT
		end

		local entry = {
			initial_content = {
				checked = options.checked == true,
				detail = detail or "",
				enabled = options.enabled ~= false,
				hotspot = {
					disabled = options.selectable ~= true or variant == "action" and options.enabled == false,
				},
				label = label or "",
				selectable = options.selectable == true,
				section_header = options.section_header == true,
				section_id = options.section_id,
				selected = false,
				selected_stat_index = 0,
				queue_current = options.queue_current == true,
				stat_count = 0,
				stat_pressed_callbacks = {},
				trait_count = #(options.trait_options or {}),
				trait_left_callbacks = {},
				trait_right_callbacks = {},
				trait_target_1_index = 0,
				trait_target_2_index = 0,
				chevron = "",
				credits = options.credits or "—",
				plasteel = options.plasteel or "—",
				diamantine = options.diamantine or "—",
			},
			pass_template = nil,
			size = {
				PANEL_WIDTH - CONTENT_HORIZONTAL_PADDING * 2,
				height,
			},
			variant = variant,
			trait_button_height = options.trait_button_height,
			trait_columns = options.trait_columns,
			trait_count = #(options.trait_options or {}),
			trait_icons = options.trait_icons == true,
			stat_buttons = options.stat_buttons,
			stat_pressed_callback = options.stat_buttons and function(stat_name)
				self:_set_setting("auto_crafter_target_dump_stat", stat_name)
			end or nil,
			widget_type = "auto_crafter_row",
		}

		if options.section_header then
			entry.bind = function(widget)
				local function toggle_section()
					local section_id = options.section_id

					if not section_id then
						return
					end

					self._section_collapsed[section_id] = not self._section_collapsed[section_id]
					self:_queue_layout(1)
				end

				widget.content.hotspot.pressed_callback = toggle_section
			end
			entry.refresh = function(widget)
				local collapsed = self._section_collapsed[options.section_id] == true

				widget.content.chevron = collapsed and ">" or "v"
			end
		elseif options.offer then
			entry.offer = options.offer
			entry.refresh = function(widget)
				widget.content.selected = self._selected_offer_key ~= nil and self._selected_offer_key == offer_selection_key(options.offer)
			end
		end

		if options.action then
			entry.bind = function(widget)
				widget.content.hotspot.pressed_callback = function()
					options.action()
				end
			end
		end

		if options.decrease or options.increase then
			entry.bind = function(widget)
				if widget.content.decrease_hotspot then
					widget.content.decrease_hotspot.pressed_callback = options.decrease
				end
				if widget.content.increase_hotspot then
					widget.content.increase_hotspot.pressed_callback = options.increase
				end
			end
		end

		if options.stat_buttons then
			entry.refresh = function(widget)
				local selected_name = self:_planner_selected_dump_stat()

				widget.content.stat_count = #options.stat_buttons

				for index, button in ipairs(options.stat_buttons) do
					widget.content["stat_label_" .. tostring(index)] = button.label
				end

				widget.content.selected_stat_index = 0

				for index, button in ipairs(options.stat_buttons) do
					if button.name == selected_name then
						widget.content.selected_stat_index = index

						break
					end
				end
			end
		end

		if options.trait_options then
			entry.bind = function(widget)
				widget.content.trait_left_callbacks = {}
				widget.content.trait_right_callbacks = {}

				for index, option in ipairs(options.trait_options) do
					local value = option.value

					widget.content.trait_left_callbacks[index] = function()
						self:_set_trait_target(options.target_1_setting, value)
					end
					widget.content.trait_right_callbacks[index] = function()
						self:_set_trait_target(options.target_2_setting, value)
					end
				end
			end
			entry.refresh = function(widget)
				local target_1 = self:_setting(options.target_1_setting, "keep")
				local target_2 = self:_setting(options.target_2_setting, "keep")

				widget.content.trait_count = #options.trait_options
				widget.content.trait_target_1_index = 0
				widget.content.trait_target_2_index = 0

				for index, option in ipairs(options.trait_options) do
					widget.content["trait_label_" .. tostring(index)] = option.short_label or option.label
					widget.content["trait_icon_" .. tostring(index)] = option.icon or ""
					local icon_style = widget.style and widget.style["trait_icon_" .. tostring(index)]

					if icon_style and icon_style.material_values then
						icon_style.material_values.icon = option.icon or ""
						icon_style.material_values.frame = option.frame or ""
					end

					if option.value == target_1 then
						widget.content.trait_target_1_index = index
					end
					if option.value == target_2 then
						widget.content.trait_target_2_index = index
					end
				end
			end
		end

		if options.refresh then
			entry.refresh = options.refresh
		end

		return entry
	end

	function self:_selected_offers(snapshot)
		local store = snapshot and snapshot.store or {}
		local offers = store.offers or {}
		local selected_offer = self._selected_offer

		local selected_display_name

		if selected_offer then
			for _, offer in ipairs(offers) do
				local offer_matches = selected_offer.offer_id and offer.offer_id == selected_offer.offer_id or selected_offer.master_id and offer.master_id == selected_offer.master_id

				if offer_matches then
					local selected_mark
					local selected_ok, selected_master_id = safe_call(self._get_selected_manual_mark)

					if not selected_ok or selected_master_id == nil then
						selected_master_id = offer.master_id
					end
					for _, mark in ipairs(offer.marks or {}) do
						if mark.master_id == selected_master_id then
							selected_mark = mark

							break
						end
					end
					selected_display_name = weapon_name_with_mark(
						selected_mark and selected_mark.display_name or offer.display_name,
						selected_mark and selected_mark.sub_display_name or offer.sub_display_name
					)

					break
				end
			end
		end

		if selected_display_name then
			return offers, selected_display_name
		end

		return offers, selected_offer and localize("auto_crafter_panel_selected_weapon", "Selected weapon") or localize("auto_crafter_panel_no_target", "no weapon selected")
	end

	function self:_selected_store_offer(snapshot)
		local selected_offer = self._selected_offer

		for _, offer in ipairs(snapshot and snapshot.store and snapshot.store.offers or {}) do
			local matches = selected_offer and (selected_offer.offer_id and offer.offer_id == selected_offer.offer_id or selected_offer.master_id and offer.master_id == selected_offer.master_id)

			if matches then
				return offer
			end
		end

		return nil
	end

	function self:_games_lantern_queue()
		if self._queue_snapshot_cache == nil then self:_refresh_games_lantern_snapshots() end

		return self._queue_snapshot_cache
	end

	function self:_games_lantern_import()
		if self._import_snapshot_cache == nil then self:_refresh_games_lantern_snapshots() end

		return self._import_snapshot_cache
	end

	function self:_refresh_games_lantern_snapshots()
		local queue_ok, queue = safe_call(self._games_lantern_queue_snapshot)
		local import_ok, import_state = safe_call(self._games_lantern_import_snapshot)
		self._queue_snapshot_cache = queue_ok and type(queue) == "table" and queue or false
		self._import_snapshot_cache = import_ok and type(import_state) == "table" and import_state or false
		self._presentation_snapshots_dirty = false

		return self._queue_snapshot_cache, self._import_snapshot_cache
	end

	function self:invalidate_games_lantern_snapshots()
		self._presentation_snapshots_dirty = true

		return true
	end

	function self:_games_lantern_queue_signature(queue)
		if type(queue) ~= "table" then
			return "none"
		end

		return table.concat({
			tostring(queue.queue_id or ""),
			tostring(queue.state or "empty"),
			tostring(queue.current_index or 0),
			tostring(queue.job_count or 0),
			tostring(queue.last_error or ""),
		}, "|")
	end

	function self:_games_lantern_import_signature(import_state)
		if type(import_state) ~= "table" then return "none" end
		local choices = import_state.choice_request or {}

		return table.concat({
			tostring(import_state.state or "idle"),
			tostring(import_state.last_error or ""),
			tostring(#(choices.melee or {})),
			tostring(#(choices.ranged or {})),
		}, "|")
	end

	function self:_games_lantern_job_detail(job)
		job = job or {}
		local perks = {}
		local blessings = {}

		for _, target in ipairs(job.perks or {}) do
			perks[#perks + 1] = value_text(target.label or target.display_name, target.id or "?")
		end

		for _, target in ipairs(job.blessings or {}) do
			blessings[#blessings + 1] = value_text(target.label or target.display_name, target.id or "?")
		end

		return string.format(
			"Dump stat: %s %s\nPerk 1: %s\nPerk 2: %s\nBlessings: %s",
			value_text(job.dump_stat_label or job.dump_stat, "?"),
			integer_text(job.dump_target, "?"),
			value_text(perks[1], "?"),
			value_text(perks[2], "?"),
			#blessings > 0 and table.concat(blessings, " / ") or "?"
		)
	end

	function self:_manual_queue_detail(plan)
		plan = plan or {}
		local dump_stat = self:_planner_dump_stat_text()
		local dump_target = integer_text(plan.dump_target or self:_setting("auto_crafter_dump_stat_target", 60))
		local perks = {
			self:_target_policy_text("auto_crafter_perk_1_target"),
			self:_target_policy_text("auto_crafter_perk_2_target"),
		}
		local blessings = {
			self:_target_policy_text("auto_crafter_blessing_1_target"),
			self:_target_policy_text("auto_crafter_blessing_2_target"),
		}

		return string.format("Dump stat: %s %s\nPerk 1: %s\nPerk 2: %s\nBlessings: %s", dump_stat, dump_target, value_text(perks[1], "?"), value_text(perks[2], "?"), table.concat(blessings, " / "))
	end

	function self:_games_lantern_queue_target(queue)
		if type(queue) ~= "table" or type(queue.jobs) ~= "table" or #queue.jobs ~= 2 then
			return nil
		end

		local names = {}
		for index, job in ipairs(queue.jobs) do
			local offer = job.offer or {}
			local name = value_text(job.display_name, weapon_name_with_mark(offer.display_name, offer.sub_display_name))
			if job.status == "complete" then
				name = name .. " [complete]"
			elseif job.current then
				name = name .. " [current]"
			end
			names[index] = name
		end

		return "Queued (" .. names[1] .. " => " .. names[2] .. ")"
	end

	function self:_games_lantern_cost_authority()
		if type(self._get_games_lantern_cost_authority) ~= "function" then
			return nil
		end
		local ok, authority = pcall(self._get_games_lantern_cost_authority)
		if not ok or type(authority) ~= "table" or type(authority.aggregate) ~= "table" or authority.signature == nil then
			return nil
		end
		local value = authority.aggregate

		return authority, string.format("Projected authority: %s-%s Dockets | %s-%s Plasteel | %s-%s Diamantine. Press again to confirm.", integer_text(value.dockets_min), integer_text(value.dockets_max), integer_text(value.plasteel_min), integer_text(value.plasteel_max), integer_text(value.diamantine_min), integer_text(value.diamantine_max))
	end

	function self:_request_games_lantern_paste(queue_owned)
		if type(self._games_lantern_paste) ~= "function" then
			return false, "paste_unavailable"
		end

		local ok, pasted, reason = pcall(self._games_lantern_paste, queue_owned == true)

		if not ok then
			log("error", "Games Lantern paste failed: " .. tostring(pasted))
		end

		return ok and pasted == true, ok and reason or pasted
	end

	function self:_setting(setting_id, default_value)
		local get = self._settings and self._settings.get

		if type(get) ~= "function" then
			return default_value
		end

		local ok, value = pcall(get, self._settings, setting_id)

		if not ok or value == nil then
			return default_value
		end

		return value
	end

	function self:_set_setting(setting_id, value)
		local set = self._settings and self._settings.set

		if type(set) ~= "function" then
			return false
		end

		local ok, result = pcall(set, self._settings, setting_id, value)

		return ok and result ~= false
	end

	function self:_cycle_setting(setting_id, values, default_value)
		local current = self:_setting(setting_id, default_value)
		local next_index = 1

		for index, value in ipairs(values) do
			if value == current then
				next_index = index % #values + 1

				break
			end
		end

		self:_set_setting(setting_id, values[next_index])
	end

	function self:_adjust_numeric_setting(setting_id, default_value, minimum, maximum, step)
		local current = tonumber(self:_setting(setting_id, default_value)) or default_value
		self:_set_setting(setting_id, math.max(minimum, math.min(maximum, current + step)))
	end

	function self:_step_enum_setting(setting_id, values, default_value, direction)
		local current = self:_setting(setting_id, default_value)
		local current_index = 1

		for index, value in ipairs(values) do
			if value == current then
				current_index = index
				break
			end
		end

		local next_index = (current_index - 1 + direction) % #values + 1
		self:_set_setting(setting_id, values[next_index])
	end

	function self:_planner_target_text()
		local _, current_weapon = self:_selected_offers(self._snapshot)

		return current_weapon or localize("auto_crafter_panel_no_target", "no weapon selected")
	end

	function self:_planner_dump_stat_text()
		return self:_planner_dump_stat_label(self:_planner_selected_dump_stat())
	end

	function self:_planner_selected_dump_stat()
		local configured = self:_setting("auto_crafter_target_dump_stat", "damage")
		local candidates = self._plan and self._plan.dump_stat_candidates or {}

		for _, candidate in ipairs(candidates) do
			if type(candidate) == "table" and candidate.name == configured then
				return configured
			end
		end

		return self._plan and self._plan.resolved_dump_stat or configured
	end

	function self:_planner_dump_stat_label(stat_name)
		local candidates = self._plan and self._plan.dump_stat_candidates or {}

		for _, candidate in ipairs(candidates) do
			if type(candidate) == "table" and candidate.name == stat_name then
				return display_stat_name(stat_name, candidate.display_name_key)
			end
		end

		return display_stat_name(stat_name)
	end

	function self:_planner_dump_stat_options()
		local options = {}
		local seen = {}
		local plan = self._plan
		local candidates = plan and plan.dump_stat_candidates or {}

		for _, candidate in ipairs(candidates or {}) do
			local name = type(candidate) == "table" and candidate.name or candidate

			if name and not seen[name] then
				options[#options + 1] = name
				seen[name] = true
			end
		end

		return options
	end

	function self:_planner_dump_stat_buttons()
		local buttons = {}
		local candidates = self._plan and self._plan.dump_stat_candidates or {}

		for index = 1, math.min(#candidates, 5) do
			local candidate = candidates[index]
			local name = type(candidate) == "table" and candidate.name or candidate

			if name then
				buttons[#buttons + 1] = {
					label = self:_planner_dump_stat_label(name),
					name = name,
				}
			end
		end

		return buttons
	end

	function self:_step_planner_dump_stat(direction)
		local values = self:_planner_dump_stat_options()

		if #values == 0 then
			return
		end

		local current = self:_setting("auto_crafter_target_dump_stat", "damage")
		local resolved = self._plan and self._plan.resolved_dump_stat
		local current_index

		for index, value in ipairs(values) do
			if value == current or resolved and value == resolved then
				current_index = index

				break
			end
		end

		current_index = current_index or 1
		local next_index = (current_index - 1 + direction) % #values + 1

		self:_set_setting("auto_crafter_target_dump_stat", values[next_index])
	end

	function self:_planner_fallback_text()
		return self:_setting("auto_crafter_best_candidate_fallback", true) == true and localize("auto_crafter_value_on", "On") or localize("auto_crafter_value_off", "Off")
	end

	function self:_estimate_acquisition_text()
		local estimate = self._plan and self._plan.estimate

		if not estimate or not estimate.dockets_floor then
			return localize("auto_crafter_panel_waiting", "waiting for probe")
		end

		return string.format("%s each | %s-%s purchases | budget %s", integer_text(estimate.dockets_floor), integer_text(estimate.purchase_count_floor), integer_text(estimate.purchase_count_cap, "uncapped"), integer_text(estimate.dockets_cap, "uncapped"))
	end

	function self:_estimate_base_level_text()
		local estimate = self._plan and self._plan.estimate

		if not estimate then
			return localize("auto_crafter_panel_waiting", "waiting for probe")
		end

		return string.format("%s-%s starting base item level", integer_text(estimate.base_level_min), integer_text(estimate.base_level_max))
	end

	function self:_estimate_currency_values(phase_name)
		local estimate = self._plan and self._plan.estimate or {}
		local phase = phase_name == "total" and estimate or estimate.phases and estimate.phases[phase_name] or {}
		local function range_text(minimum, maximum)
			if minimum == nil or maximum == nil then
				return "—"
			end

			return minimum == maximum and integer_text(minimum) or integer_text(minimum) .. "-" .. integer_text(maximum)
		end

		return phase.dockets_min and range_text(phase.dockets_min, phase.dockets_max) or "-", range_text(phase.plasteel_min, phase.plasteel_max), range_text(phase.diamantine_min, phase.diamantine_max)
	end

	function self:_estimate_mastery_text()
		local mastery = self._plan and self._plan.estimate and self._plan.estimate.phases and self._plan.estimate.phases.mastery

		if not mastery then
			return self:_setting("auto_crafter_level_mastery_20", true) == true and localize("auto_crafter_panel_waiting", "waiting for probe") or localize("auto_crafter_panel_disabled", "disabled")
		end

		return string.format("%s-%s Redeemed weapons | %s XP remaining", integer_text(mastery.count_min), integer_text(mastery.count_max), integer_text(mastery.remaining_xp))
	end

	function self:_trait_target_options(setting_id)
		local options = {}
		local catalog = self._plan and self._plan.trait_catalog
		local catalog_kind = string.find(setting_id, "blessing", 1, true) and "blessings" or "perks"
		local seen = {}

		if not catalog or catalog.available ~= true then
			return options
		end

		for _, entry in ipairs(catalog[catalog_kind] or {}) do
			if entry.id then
				local label = clean_single_line(entry.display_name or localized_game_text(entry.display_name_key) or display_stat_name(entry.id))
				local value = catalog_kind == "perks" and entry.tier and string.format("perk:%s:%s", tostring(entry.id), tostring(entry.tier)) or entry.id
				local short_label = label

				if catalog_kind == "perks" and type(self._compact_perk_label) == "function" then
					local compact_ok, compact = pcall(self._compact_perk_label, entry, label)

					short_label = compact_ok and clean_single_line(compact) or label
				end

				if not seen[value] then
					seen[value] = true
					options[#options + 1] = {
						frame = entry.frame,
						icon = entry.icon,
						label = label,
						short_label = short_label ~= "" and short_label or label,
						trait = entry.trait,
						value = value,
					}
				end
			end
		end

		return options
	end

	function self:_target_policy_text(setting_id)
		local value = self:_setting(setting_id)

		for _, option in ipairs(self:_trait_target_options(setting_id)) do
			if option.value == value then
				return option.label
			end
		end

		return localize("auto_crafter_panel_waiting", "waiting for probe")
	end

	function self:_default_trait_target(setting_id, options, excluded_value)
		local target_slot = string.find(setting_id, "_2_target", 1, true) and 2 or 1

		if string.find(setting_id, "perk", 1, true) then
			local category = "melee"

			for _, option in ipairs(options) do
				local identity = option.trait or option.value or ""

				if string.find(identity, "weapon_trait_ranged_", 1, true) then
					category = "ranged"
					break
				end
			end

			local preferred_id = DEFAULT_PERK_IDS[category][target_slot]

			for _, option in ipairs(options) do
				local value_matches = string.find(option.value or "", "perk:" .. preferred_id .. ":", 1, true) == 1

				if option.value ~= excluded_value and (option.trait == preferred_id or value_matches) then
					return option.value
				end
			end
		end

		for _, option in ipairs(options) do
			if option.value ~= excluded_value then
				return option.value
			end
		end

		return nil
	end

	function self:_step_trait_target(setting_id, direction)
		local options = self:_trait_target_options(setting_id)
		local values = {}
		local peer_value = self:_setting(TRAIT_TARGET_PAIRS[setting_id])

		for _, option in ipairs(options) do
			if option.value ~= peer_value then
				values[#values + 1] = option.value
			end
		end

		if #values > 0 then
			self:_step_enum_setting(setting_id, values, values[1], direction)
		end
	end

	function self:_set_trait_target(setting_id, value)
		local options = self:_trait_target_options(setting_id)
		local valid = false

		for _, option in ipairs(options) do
			if option.value == value then
				valid = true
				break
			end
		end

		if not valid then
			return false
		end

		self:_set_setting(setting_id, value)

		local peer_id = TRAIT_TARGET_PAIRS[setting_id]

		if peer_id and self:_setting(peer_id) == value then
			local peer_options = self:_trait_target_options(peer_id)
			local replacement = self:_default_trait_target(peer_id, peer_options, value)

			if replacement then
				self:_set_setting(peer_id, replacement)
			end
		end

		return true
	end

	function self:_reconcile_trait_targets()
		local pairs = {
			{ "auto_crafter_perk_1_target", "auto_crafter_perk_2_target" },
			{ "auto_crafter_blessing_1_target", "auto_crafter_blessing_2_target" },
		}

		for _, pair in ipairs(pairs) do
			for index, setting_id in ipairs(pair) do
				local options = self:_trait_target_options(setting_id)
				local current = self:_setting(setting_id)
				local found = false

				for _, option in ipairs(options) do
					if option.value == current then
						found = true
						break
					end
				end

				if not found and #options > 0 then
					local excluded = index == 2 and self:_setting(pair[1]) or nil
					local replacement = self:_default_trait_target(setting_id, options, excluded)

					if replacement then
						self:_set_setting(setting_id, replacement)
					end
				end
			end

			local first_id = pair[1]
			local second_id = pair[2]
			local first_value = self:_setting(first_id)

			if first_value ~= nil and self:_setting(second_id) == first_value then
				local options = self:_trait_target_options(second_id)
				local replacement = self:_default_trait_target(second_id, options, first_value)

				if replacement then
					self:_set_setting(second_id, replacement)
				end
			end
		end
	end

	function self:_select_offer_from_row(offer)
		if not offer then
			return false
		end

		self._selected_offer = offer
		self._selected_offer_key = offer_selection_key(offer)
		self._selected_offer_id = offer.offer_id
		self._selected_offer_master_id = offer.master_id
		if self._pending_offer ~= offer then
			self._pending_offer_attempts = 0
		end

		self._pending_offer = offer
		self._pending_offer_attempts = self._pending_offer_attempts + 1

		if self._pending_offer_attempts > MAX_SELECTION_ATTEMPTS then
			log("error", "Auto Crafter native offer selection timed out; leaving native selection unchanged.")
			self._pending_offer = nil
			self._pending_offer_attempts = 0

			return false
		end
		if type(self._select_offer) ~= "function" then
			return false
		end

		local ok, selected = pcall(self._select_offer, self._view, offer)

		if not ok then
			log("error", "Auto Crafter native offer selection failed: " .. tostring(selected))

			return false
		end

		if selected == true then
			self._pending_offer = nil
			self._pending_offer_attempts = 0
		end

		return selected == true
	end

	function self:_entries(snapshot)
		local store = snapshot and snapshot.store or {}
		local _, selected_weapon = self:_selected_offers(snapshot)
		local selected = selected_weapon or localize("auto_crafter_panel_no_target", "no weapon selected")
		local plan = self._plan or snapshot and snapshot.plan
		local queue = self:_games_lantern_queue()
		local imported = self:_games_lantern_import()
		local queue_target = self:_games_lantern_queue_target(queue)
		local queue_owned = queue_target ~= nil and queue.state ~= "empty"
		local queue_active = queue_owned and (queue.state == "starting" or queue.state == "selecting" or queue.state == "preflighting" or queue.state == "dispatching" or queue.state == "running" or queue.state == "waiting_next" or queue.state == "stopping" or queue.state == "quarantined" or queue.state == "reconciliation_required")
		local entries = {
			self:_entry(localize("auto_crafter_panel_title", "Auto Crafter Helper"), "", {
				variant = "title",
			}),
			self:_entry(localize("auto_crafter_panel_status", "Status"), self._phase or value_text(snapshot and snapshot.phase, "idle"), {
				refresh = function(widget)
					widget.content.detail = self._phase or value_text(self._controller_state and self._controller_state.phase, "idle")
				end,
			}),
			self:_entry(localize("auto_crafter_panel_wallet", "Resources"), string.format("%s  |  %s  |  %s", integer_text(wallet_amount(snapshot, "credits")), integer_text(wallet_amount(snapshot, "plasteel")), integer_text(wallet_amount(snapshot, "diamantine")))),
			self:_entry(localize("auto_crafter_panel_inventory", "Inventory"), string.format("%s: %s  |  %s: %s", localize("auto_crafter_panel_offers", "Offers"), value_text(store.offer_count, "?"), localize("auto_crafter_panel_gear", "Gear"), value_text(snapshot and snapshot.gear and snapshot.gear.item_count, "?"))),
			self:_entry(localize("auto_crafter_panel_target", "Target"), queue_target or selected, {
				refresh = function(widget)
					local current_queue_target = self:_games_lantern_queue_target(self:_games_lantern_queue())
					local _, current_weapon = self:_selected_offers(self._snapshot)

					widget.content.detail = current_queue_target or current_weapon or localize("auto_crafter_panel_no_target", "no weapon selected")
				end,
			}),
			self:_entry(localize("auto_crafter_show_status_hud", "Show persistent crafting status"), "", {
				checked = self:_setting("auto_crafter_show_status_hud", true) == true,
				selectable = true,
				variant = "checkbox",
				action = function()
					self:_set_setting("auto_crafter_show_status_hud", not (self:_setting("auto_crafter_show_status_hud", true) == true))
				end,
				refresh = function(widget)
					widget.content.checked = self:_setting("auto_crafter_show_status_hud", true) == true
				end,
			}),
			self:_entry(localize("auto_crafter_panel_active_queue", "Active Queue"), imported and imported.state or queue and queue.state or "manual", {
				selectable = false,
				section_header = true,
				section_id = SECTION_QUEUE,
				variant = "section",
			}),
			self:_entry(localize("auto_crafter_panel_planner", "Planner configuration"), "", {
				selectable = true,
				section_header = true,
				section_id = SECTION_PLANNER,
				variant = "section",
			}),
		}
		local queue_jobs = queue and queue.jobs

		if not self._section_collapsed[SECTION_QUEUE] and type(queue_jobs) == "table" and #queue_jobs > 0 then
			for index, job in ipairs(queue_jobs) do
				local offer = job.offer or {}
				local name = value_text(job.display_name, value_text(weapon_name_with_mark(offer.display_name, offer.sub_display_name), value_text(offer.master_id, "Weapon")))

				table.insert(entries, #entries, self:_entry(string.format("%d. %s", index, name), self:_games_lantern_job_detail(job), {
					height = QUEUE_JOB_ROW_HEIGHT,
					queue_job = true,
					queue_index = index,
					queue_current = job.current == true,
					variant = "queue_job",
				}))
			end
		elseif not self._section_collapsed[SECTION_QUEUE] then
			local selected_detail = self:_manual_queue_detail(plan)

			table.insert(entries, #entries, self:_entry("1. " .. selected, selected_detail, {
				height = QUEUE_JOB_ROW_HEIGHT,
				queue_job = true,
				queue_index = 1,
				queue_current = selected_weapon ~= nil,
				variant = "queue_job",
			}))
		end
		if imported and imported.state == "awaiting_weapon_choice" and type(self._games_lantern_select_choice) == "function" and not self._section_collapsed[SECTION_QUEUE] then
			for _, slot in ipairs({ "melee", "ranged" }) do
				local candidates = imported.choice_request and imported.choice_request[slot] or {}
				if #candidates > 1 then
					for _, candidate in ipairs(candidates) do
						local external = candidate.external or {}
						local card_index = external.card_index
						local choice_slot = slot
						local choice_index = card_index
						local name = value_text(candidate.display_name or external.display_name, "Weapon")
						table.insert(entries, #entries, self:_entry(string.format("Choose %s: %s", slot, name), "Games Lantern card " .. tostring(card_index), {
							enabled = true,
							selectable = true,
							variant = "action",
							action = function()
								pcall(self._games_lantern_select_choice, choice_slot, choice_index)
								self:_queue_layout(1)
							end,
						}))
					end
				end
			end
		end

		if type(self._games_lantern_paste) == "function" and not self._section_collapsed[SECTION_QUEUE] and not queue_active then
			table.insert(entries, #entries, self:_entry("Paste Games Lantern build (Ctrl+V)", "", {
				enabled = true,
				selectable = true,
				variant = "action",
				action = function()
					self:_request_games_lantern_paste(queue_owned)
				end,
			}))
			if queue_owned and type(self._games_lantern_clear) == "function" then
				table.insert(entries, #entries, self:_entry("Clear Queue", "", {
					enabled = true,
					selectable = true,
					variant = "action",
					action = function()
						pcall(self._games_lantern_clear)
						self._queue_craft_armed = false
						self._queue_craft_confirmation_signature = nil
						self._queue_craft_confirmation_text = nil
						self:_queue_layout(1)
					end,
				}))
			end
		end
		local function add_checkbox(setting_id, label_id, fallback, default_value, enabled, reflow, height)
			local function is_enabled()
				if queue_active then
					return false
				end
				if type(enabled) == "function" then
					return enabled() == true
				end

				return enabled ~= false
			end
			local initial_enabled = is_enabled()
			table.insert(entries, self:_entry(localize(label_id, fallback), "", {
				checked = self:_setting(setting_id, default_value) == true,
				enabled = initial_enabled,
				height = height,
				selectable = initial_enabled,
				variant = "checkbox",
				action = function()
					self:_set_setting(setting_id, not (self:_setting(setting_id, default_value) == true))
					if reflow then
						self:_queue_layout(1)
					end
				end,
				refresh = function(widget)
					local current_enabled = is_enabled()
					widget.content.checked = self:_setting(setting_id, default_value) == true
					widget.content.enabled = current_enabled
					widget.content.hotspot.disabled = not current_enabled
				end,
			}))
		end
		local function add_target_selector(setting_id, label_id, fallback, enabled, unavailable_text)
			local function is_enabled()
				if queue_owned then
					return false
				end
				if type(enabled) == "function" then
					return enabled() == true
				end

				return enabled ~= false
			end
			local initial_enabled = is_enabled()
			table.insert(entries, self:_entry(localize(label_id, fallback), initial_enabled and self:_target_policy_text(setting_id) or unavailable_text, {
				enabled = initial_enabled,
				selectable = initial_enabled,
				variant = "enum_stepper",
				decrease = function()
					if is_enabled() then
						self:_step_trait_target(setting_id, -1)
					end
				end,
				increase = function()
					if is_enabled() then
						self:_step_trait_target(setting_id, 1)
					end
				end,
				refresh = function(widget)
					local current_enabled = is_enabled()
					widget.content.enabled = current_enabled
					widget.content.detail = current_enabled and self:_target_policy_text(setting_id) or unavailable_text
					if widget.content.decrease_hotspot then
						widget.content.decrease_hotspot.disabled = not current_enabled
					end
					if widget.content.increase_hotspot then
						widget.content.increase_hotspot.disabled = not current_enabled
					end
				end,
			}))
		end

		if not self._section_collapsed[SECTION_PLANNER] then
			table.insert(entries, self:_entry(localize("auto_crafter_panel_planner_target", "Planner target"), queue_target or self:_planner_target_text(), {
				refresh = function(widget)
					widget.content.detail = self:_games_lantern_queue_target(self:_games_lantern_queue()) or self:_planner_target_text()
				end,
			}))
			table.insert(entries, self:_entry(localize("auto_crafter_panel_dump_stat", "Dump stat"), self:_planner_dump_stat_text(), {
				enabled = not queue_owned,
				selectable = not queue_owned,
				variant = "enum_stepper",
				decrease = function()
					self:_step_planner_dump_stat(-1)
				end,
				increase = function()
					self:_step_planner_dump_stat(1)
				end,
				refresh = function(widget)
					widget.content.detail = self:_planner_dump_stat_text()
				end,
			}))
			local stat_buttons = self:_planner_dump_stat_buttons()

			if #stat_buttons > 0 and not queue_owned then
				table.insert(entries, self:_entry("", "", {
					selectable = true,
					stat_buttons = stat_buttons,
					variant = "stat_grid",
				}))
			end
			table.insert(entries, self:_entry(localize("auto_crafter_panel_dump_target", "Dump target"), integer_text(self:_setting("auto_crafter_dump_stat_target", 60)), {
				enabled = not queue_owned,
				selectable = not queue_owned,
				variant = "stepper",
				decrease = function()
					self:_adjust_numeric_setting("auto_crafter_dump_stat_target", 60, 1, 100, -1)
				end,
				increase = function()
					self:_adjust_numeric_setting("auto_crafter_dump_stat_target", 60, 1, 100, 1)
				end,
				refresh = function(widget)
					widget.content.detail = integer_text(self:_setting("auto_crafter_dump_stat_target", 60))
				end,
			}))
			add_checkbox("auto_crafter_cap_by_dockets", "auto_crafter_cap_by_dockets", "Cap perfect-roll weapon acquisition by Ordo dockets", true, nil, true)
			if self:_setting("auto_crafter_cap_by_dockets", true) == true then
				table.insert(entries, self:_entry(localize("auto_crafter_panel_docket_cap", "Ordo dockets cap"), integer_text(self:_setting("auto_crafter_docket_cap", 500000)), {
					enabled = not queue_active,
					selectable = not queue_active,
					variant = "stepper",
					decrease = function()
						if not queue_active then self:_adjust_numeric_setting("auto_crafter_docket_cap", 500000, 0, 10000000, -100000) end
					end,
					increase = function()
						if not queue_active then self:_adjust_numeric_setting("auto_crafter_docket_cap", 500000, 0, 10000000, 100000) end
					end,
					refresh = function(widget)
						widget.content.detail = integer_text(self:_setting("auto_crafter_docket_cap", 500000))
						widget.content.enabled = not queue_active
						if widget.content.decrease_hotspot then widget.content.decrease_hotspot.disabled = queue_active end
						if widget.content.increase_hotspot then widget.content.increase_hotspot.disabled = queue_active end
					end,
				}))
			end
			add_checkbox("auto_crafter_cap_by_max_purchases", "auto_crafter_cap_by_max_purchases", "Cap perfect-roll weapon acquisition by max purchases", false, nil, true)
			if self:_setting("auto_crafter_cap_by_max_purchases", false) == true then
				table.insert(entries, self:_entry(localize("auto_crafter_panel_max_purchases", "Max purchases"), integer_text(self:_setting("auto_crafter_max_purchases", 100)), {
					enabled = not queue_active,
					selectable = not queue_active,
					variant = "stepper",
					decrease = function()
						if not queue_active then self:_adjust_numeric_setting("auto_crafter_max_purchases", 100, 1, 10000, -1) end
					end,
					increase = function()
						if not queue_active then self:_adjust_numeric_setting("auto_crafter_max_purchases", 100, 1, 10000, 1) end
					end,
					refresh = function(widget)
						widget.content.detail = integer_text(self:_setting("auto_crafter_max_purchases", 100))
						widget.content.enabled = not queue_active
						if widget.content.decrease_hotspot then widget.content.decrease_hotspot.disabled = queue_active end
						if widget.content.increase_hotspot then widget.content.increase_hotspot.disabled = queue_active end
					end,
				}))
			end
			table.insert(entries, self:_entry(localize("auto_crafter_panel_best_fallback", "Best-candidate fallback"), self:_planner_fallback_text(), {
				checked = self:_setting("auto_crafter_best_candidate_fallback", true) == true,
				enabled = not queue_active,
				selectable = not queue_active,
				variant = "checkbox",
				action = function()
					if not queue_active then self:_set_setting("auto_crafter_best_candidate_fallback", not (self:_setting("auto_crafter_best_candidate_fallback", true) == true)) end
				end,
				refresh = function(widget)
					widget.content.enabled = not queue_active
					widget.content.hotspot.disabled = queue_active
					widget.content.checked = self:_setting("auto_crafter_best_candidate_fallback", true) == true
				end,
			}))
		end

		table.insert(entries, self:_entry(localize("auto_crafter_panel_marks", "Marks"), "", {
			selectable = true,
			section_header = true,
			section_id = SECTION_MARKS,
			variant = "section",
		}))

		if not self._section_collapsed[SECTION_MARKS] then
			local selected_store_offer = self:_selected_store_offer(snapshot)
			local marks = selected_store_offer and selected_store_offer.marks or {}
			local selected_mark
			local selected_ok, selected_value = safe_call(self._get_selected_manual_mark)

			if selected_ok then
				selected_mark = selected_value
			end
			if selected_mark == nil and selected_store_offer then
				selected_mark = selected_store_offer.master_id
			end

			if #marks == 0 then
				table.insert(entries, self:_entry(localize("auto_crafter_panel_select_weapon", "Select a weapon in Brunt's list."), "", {
					variant = "summary",
				}))
			else
				for _, mark in ipairs(marks) do
					local mark_offer_id = selected_store_offer.offer_id
					local mark_master_id = mark.master_id
					local enabled = not queue_owned and not queue_active and type(self._select_manual_mark) == "function"

					table.insert(entries, self:_entry(value_text(mark.display_name, mark_master_id), value_text(mark.sub_display_name, ""), {
						enabled = enabled,
						selectable = enabled,
						variant = "offer",
						action = function()
							if enabled then
								pcall(self._select_manual_mark, mark_offer_id, mark_master_id)
								self:_queue_layout(1)
							end
						end,
						refresh = function(widget)
							local ok, current = safe_call(self._get_selected_manual_mark)

							widget.content.selected = (ok and current or selected_mark) == mark_master_id
						end,
					}))
				end
			end
		end

		table.insert(entries, self:_entry(localize("auto_crafter_panel_trait_targets", "Perk and blessing targets"), "", {
			selectable = true,
			section_header = true,
			section_id = SECTION_TRAITS,
			variant = "section",
		}))

		if not self._section_collapsed[SECTION_TRAITS] then
			local unavailable = localize("auto_crafter_panel_option_unavailable", "Enable prerequisite options")
			local function perk_targets_enabled()
				return not queue_owned and self:_setting("auto_crafter_level_mastery_20", true) == true and self:_setting("auto_crafter_change_perks", true) == true
			end
			add_target_selector("auto_crafter_perk_1_target", "auto_crafter_perk_1_target", "Perk target 1", perk_targets_enabled, unavailable)
			add_target_selector("auto_crafter_perk_2_target", "auto_crafter_perk_2_target", "Perk target 2", perk_targets_enabled, unavailable)
			add_checkbox("auto_crafter_show_perk_grid", "auto_crafter_show_perk_grid", "Show perk grid", true, perk_targets_enabled, true)
			if self:_setting("auto_crafter_show_perk_grid", true) == true and perk_targets_enabled() then
				local perk_grid_options = self:_trait_target_options("auto_crafter_perk_1_target")

				table.insert(entries, self:_entry("", "", {
					selectable = true,
					target_1_setting = "auto_crafter_perk_1_target",
					target_2_setting = "auto_crafter_perk_2_target",
					trait_button_height = PERK_GRID_BUTTON_HEIGHT,
					trait_columns = PERK_GRID_COLUMNS,
					trait_options = perk_grid_options,
					variant = "trait_grid",
				}))
			end
			local function blessing_targets_enabled()
				return not queue_owned and self:_setting("auto_crafter_level_mastery_20", true) == true and self:_setting("auto_crafter_change_blessings", true) == true
			end
			add_target_selector("auto_crafter_blessing_1_target", "auto_crafter_blessing_1_target", "Blessing target 1", blessing_targets_enabled, unavailable)
			add_target_selector("auto_crafter_blessing_2_target", "auto_crafter_blessing_2_target", "Blessing target 2", blessing_targets_enabled, unavailable)
			add_checkbox("auto_crafter_show_blessing_grid", "auto_crafter_show_blessing_grid", "Show blessing grid", true, blessing_targets_enabled, true)
			if self:_setting("auto_crafter_show_blessing_grid", true) == true and blessing_targets_enabled() then
				local blessing_grid_options = self:_trait_target_options("auto_crafter_blessing_1_target")

				table.insert(entries, self:_entry("", "", {
					selectable = true,
					target_1_setting = "auto_crafter_blessing_1_target",
					target_2_setting = "auto_crafter_blessing_2_target",
					trait_button_height = BLESSING_GRID_BUTTON_HEIGHT,
					trait_columns = BLESSING_GRID_COLUMNS,
					trait_icons = true,
					trait_options = blessing_grid_options,
					variant = "trait_grid",
				}))
			end
		end

		table.insert(entries, self:_entry(localize("auto_crafter_panel_workflow", "Crafting workflow"), "", {
			selectable = true,
			section_header = true,
			section_id = SECTION_WORKFLOW,
			variant = "section",
		}))

		if not self._section_collapsed[SECTION_WORKFLOW] then
			add_checkbox("auto_crafter_favorite_result", "auto_crafter_favorite_result", "Automatically favorite crafted weapon", true)
			add_checkbox("auto_crafter_buy_until_target", "auto_crafter_buy_until_target", "Automatically buy until dump stat target weapon is found", true, nil, nil, 44)
			add_checkbox("auto_crafter_defer_bad_weapon_processing", "auto_crafter_defer_bad_weapon_processing", "Only process bad weapons after finding perfect-rolled weapon", true, function()
				return self:_setting("auto_crafter_level_mastery_20", true) == true
			end, nil, 44)
			add_checkbox("auto_crafter_level_mastery_20", "auto_crafter_level_mastery_20", "Level weapon mastery to 20", true)
			add_checkbox("auto_crafter_allocate_mastery_points", "auto_crafter_allocate_mastery_points", "Allocate mastery points", true, function()
				return self:_setting("auto_crafter_level_mastery_20", true) == true
			end)
			add_checkbox("auto_crafter_consecrate_transcendent", "auto_crafter_consecrate_transcendent", "Automatically consecrate weapon to Transcendent", true, nil, nil, 44)
			add_checkbox("auto_crafter_upgrade_expertise_500", "auto_crafter_upgrade_expertise_500", "Automatically upgrade weapon item level to 500", true, nil, nil, 44)
			add_checkbox("auto_crafter_change_perks", "auto_crafter_change_perks", "Change perks", true, function()
				return self:_setting("auto_crafter_level_mastery_20", true) == true
			end)
			add_checkbox("auto_crafter_change_blessings", "auto_crafter_change_blessings", "Change blessings", true, function()
				return self:_setting("auto_crafter_level_mastery_20", true) == true
			end)
		end

		table.insert(entries, self:_entry(localize("auto_crafter_panel_resuming", "Resuming item options"), "", {
			selectable = true,
			section_header = true,
			section_id = SECTION_RESUMING,
			variant = "section",
		}))

		if not self._section_collapsed[SECTION_RESUMING] then
			add_checkbox("auto_crafter_reuse_inventory_base", "auto_crafter_reuse_inventory_base", "Resume matching dump stat weapon from inventory", true, nil, nil, 44)
			add_checkbox("auto_crafter_include_favorite_inventory_bases", "auto_crafter_include_favorite_inventory_bases", "Include favorited inventory weapons when resuming", true, function()
				return self:_setting("auto_crafter_reuse_inventory_base", true) == true
			end, nil, 44)
			add_checkbox("auto_crafter_craft_duplicate_completed_queued_weapons", "auto_crafter_craft_duplicate_completed_queued_weapons", "Craft duplicates of already completed queued weapons", false, nil, nil, 44)
		end

		table.insert(entries, self:_entry(localize("auto_crafter_panel_estimates", "Estimates"), "", {
			selectable = true,
			section_header = true,
			section_id = SECTION_ESTIMATES,
			variant = "section",
		}))

		if not self._section_collapsed[SECTION_ESTIMATES] then
			table.insert(entries, self:_entry(localize("auto_crafter_panel_estimate", "Search budget"), self:_estimate_acquisition_text(), {
				variant = "status",
				refresh = function(widget)
					widget.content.detail = self:_estimate_acquisition_text()
				end,
			}))
			local function add_estimate_currency(label_id, fallback, phase_name)
				local credits, plasteel, diamantine = self:_estimate_currency_values(phase_name)
				table.insert(entries, self:_entry(localize(label_id, fallback), "", {
					credits = credits,
					diamantine = diamantine,
					plasteel = plasteel,
					variant = "currency",
					refresh = function(widget)
						widget.content.credits, widget.content.plasteel, widget.content.diamantine = self:_estimate_currency_values(phase_name)
					end,
				}))
			end

			add_estimate_currency("auto_crafter_panel_consecrate_cost", "Profane to Transcendent", "consecrate")
			add_estimate_currency("auto_crafter_panel_mastery_cost", "Mastery fodder investment", "mastery")
			add_estimate_currency("auto_crafter_panel_total_cost", "Known crafting investment", "total")
		end

		local import_busy = imported and (imported.state == "fetching" or imported.state == "resolving_catalogues" or imported.state == "awaiting_weapon_choice")
		local craft_enabled = not queue_active and not import_busy
		local craft_label = queue_owned and self._queue_craft_armed and "> CONFIRM TWO-WEAPON CRAFT <" or localize("auto_crafter_panel_preview", "> CLICK HERE TO CRAFT <")
		table.insert(entries, self:_entry(craft_label, queue_owned and self._queue_craft_armed and (self._queue_craft_confirmation_text or "Cost authority unavailable; crafting remains blocked.") or "", {
			enabled = craft_enabled,
			selectable = craft_enabled,
			variant = "action",
			action = function()
				local imported = self:_games_lantern_import()
				local queue = self:_games_lantern_queue()
				local queue_owned = queue and queue.job_count == 2 and queue.state ~= "empty" and queue.state ~= "complete"
				local queue_active = queue_owned and (queue.state == "starting" or queue.state == "selecting" or queue.state == "preflighting" or queue.state == "dispatching" or queue.state == "running" or queue.state == "waiting_next" or queue.state == "stopping" or queue.state == "quarantined" or queue.state == "reconciliation_required")
				local import_busy = imported and (imported.state == "fetching" or imported.state == "resolving_catalogues" or imported.state == "awaiting_weapon_choice")
				if queue_active or import_busy then return end

				if (imported and imported.state == "staged" or queue_owned) and type(self._start_games_lantern_queue) == "function" then
					local authority, authority_text = self:_games_lantern_cost_authority()
					if not authority then
						self._queue_craft_armed = false
						self._queue_craft_confirmation_signature = nil
						self._queue_craft_confirmation_text = nil
						log("error", "Games Lantern craft blocked: aggregate cost authority unavailable")
						self:_queue_layout(1)
						return
					end
					if not self._queue_craft_armed then
						self._queue_craft_armed = true
						self._queue_craft_confirmation_signature = authority.signature
						self._queue_craft_confirmation_text = authority_text
						self:_queue_layout(1)
						return
					end
					if self._queue_craft_confirmation_signature ~= authority.signature then
						self._queue_craft_confirmation_signature = authority.signature
						self._queue_craft_confirmation_text = authority_text
						log("info", "Games Lantern cost authority changed; refreshed confirmation required")
						self:_queue_layout(1)
						return
					end
					local confirmed_signature = self._queue_craft_confirmation_signature
					self._queue_craft_armed = false
					self._queue_craft_confirmation_signature = nil
					self._queue_craft_confirmation_text = nil
					local ok, started, reason = pcall(self._start_games_lantern_queue, true, confirmed_signature)
					if not ok or started ~= true then
						log("error", "Games Lantern craft did not start: " .. tostring(ok and reason or started))
						self:_queue_layout(1)
					end
				elseif type(self._start_purchase_search) == "function" then
					self._start_purchase_search()
				end
			end,
			refresh = function(widget)
				local current_import = self:_games_lantern_import()
				local current_queue = self:_games_lantern_queue()
				local current_owned = current_queue and current_queue.job_count == 2 and current_queue.state ~= "empty" and current_queue.state ~= "complete"
				local current_active = current_owned and (current_queue.state == "starting" or current_queue.state == "selecting" or current_queue.state == "preflighting" or current_queue.state == "dispatching" or current_queue.state == "running" or current_queue.state == "waiting_next" or current_queue.state == "stopping" or current_queue.state == "quarantined" or current_queue.state == "reconciliation_required")
				local current_import_busy = current_import and (current_import.state == "fetching" or current_import.state == "resolving_catalogues" or current_import.state == "awaiting_weapon_choice")
				local current_enabled = not current_active and not current_import_busy
				widget.content.enabled = current_enabled
				widget.content.hotspot.disabled = not current_enabled
				widget.content.detail = current_owned and self._queue_craft_armed and (self._queue_craft_confirmation_text or "Cost authority unavailable; crafting remains blocked.") or ""
			end,
		}))
		local function run_is_active()
			local state = self._controller_state or {}
			local search = state.search
			local phase3 = state.phase3
			local phase4 = state.phase4
			local mastery = state.mastery
			local queue = self:_games_lantern_queue()
			local queue_active = queue and (queue.state == "running" or queue.state == "selecting" or queue.state == "preflighting" or queue.state == "dispatching" or queue.state == "waiting_next" or queue.state == "starting" or queue.state == "stopping" or queue.state == "quarantined" or queue.state == "reconciliation_required")

			return queue_active == true or search and search.running == true or phase3 and phase3.running == true or phase4 and phase4.running == true or mastery and mastery.running == true
		end
		local stop_enabled = run_is_active()
		table.insert(entries, self:_entry(localize("auto_crafter_panel_stop", "> CLICK HERE TO STOP / INTERRUPT <"), "", {
			enabled = stop_enabled,
			selectable = true,
			variant = "action",
			action = function()
				if type(self._stop_active_run) == "function" then
					self._stop_active_run()
				end
			end,
			refresh = function(widget)
				local enabled = run_is_active()

				widget.content.enabled = enabled
				widget.content.hotspot.disabled = not enabled
			end,
		}))
		return entries
	end

	function self:render(snapshot)
		self._snapshot = snapshot or self._snapshot

		if not self._panel or type(self._panel.present_grid_layout) ~= "function" then
			return false
		end

		self:_reconcile_trait_targets()

		local entries = self:_entries(self._snapshot)
		local scroll_offset = 0
		local scroll_ok, current_offset = safe_call(self._panel.length_scrolled, self._panel)

		if scroll_ok then
			scroll_offset = tonumber(current_offset) or 0
		end

		local height_ok = safe_call(self._panel.update_grid_height, self._panel, PANEL_HEIGHT, PANEL_HEIGHT)

		if not height_ok then
			log("error", "Auto Crafter diagnostic panel could not set its grid height.")
		end

		local function on_row_clicked(_, entry)
			if entry and entry.offer then
				self:_select_offer_from_row(entry.offer)
			end
		end

		local function restore_scroll_offset()
			local length_ok, scroll_length = safe_call(self._panel.scroll_length, self._panel)
			scroll_length = length_ok and tonumber(scroll_length) or 0

			if scroll_length and scroll_length > 0 and type(self._panel.set_scrollbar_progress) == "function" then
				local progress = math.max(0, math.min(1, scroll_offset / scroll_length))

				safe_call(self._panel.set_scrollbar_progress, self._panel, progress, true)
			end
		end

		local present_ok, present_error = safe_call(self._panel.present_grid_layout, self._panel, entries, BLUEPRINTS, on_row_clicked, nil, nil, nil, restore_scroll_offset)

		if not present_ok then
			log("error", "Auto Crafter diagnostic panel could not present layout: " .. tostring(present_error))
		end

		return present_ok
	end

	function self:set_phase(phase, snapshot)
		self._phase = phase or self._phase
		self._snapshot = snapshot or self._snapshot
		self:_queue_layout(1)

		return true
	end

	function self:sync_controller_snapshot(state)
		if type(state) ~= "table" then
			return false
		end

		local previous_plan = self._plan
		self._controller_state = state
		self._phase = state.phase or self._phase
		self._snapshot = state.data or self._snapshot
		self._plan = state.plan
		local catalog = self._plan and self._plan.trait_catalog
		local catalog_key = catalog and tostring(catalog.parent_pattern or catalog.item_name or catalog.trait_category) or nil

		if catalog_key ~= self._trait_catalog_key then
			self._trait_catalog_key = catalog_key
			self:_reconcile_trait_targets()
		end

		if previous_plan ~= self._plan then
			self:_queue_layout(1)
		end

		return true
	end

	function self:update(dt)
		if not self._panel or not self._view or self._view._destroyed then
			return
		end

		self._idle_poll_elapsed = (self._idle_poll_elapsed or 0) + math.max(tonumber(dt) or IDLE_POLL_INTERVAL, 0)
		local immediate = self._pending_offer ~= nil or self._layout_pending == true

		if not immediate and self._idle_poll_elapsed < IDLE_POLL_INTERVAL then
			return
		end

		self._idle_poll_elapsed = 0
		self:_update_pivot()
		if self._presentation_snapshots_dirty or self._queue_snapshot_cache == nil or self._import_snapshot_cache == nil then
			self:_refresh_games_lantern_snapshots()
		end
		local ctrl_v = ctrl_v_down()

		if ctrl_v and not self._ctrl_v_down and type(self._games_lantern_paste) == "function" then
			local current_queue = self:_games_lantern_queue()
			local current_owned = current_queue and current_queue.job_count == 2 and current_queue.state ~= "empty" and current_queue.state ~= "complete"
			local current_active = current_owned and (current_queue.state == "starting" or current_queue.state == "selecting" or current_queue.state == "preflighting" or current_queue.state == "dispatching" or current_queue.state == "running" or current_queue.state == "waiting_next" or current_queue.state == "stopping" or current_queue.state == "quarantined" or current_queue.state == "reconciliation_required")

			if not current_active then
				local pasted, paste_error = self:_request_games_lantern_paste(current_owned)

				if pasted ~= true then
					log("info", "Games Lantern Ctrl+V import was not started: " .. tostring(paste_error))
				end
			end
		end

		self._ctrl_v_down = ctrl_v
		local queue = self:_games_lantern_queue()
		local queue_signature = self:_games_lantern_queue_signature(queue)
		local import_signature = self:_games_lantern_import_signature(self:_games_lantern_import())

		if queue_signature ~= self._queue_signature then
			self._queue_signature = queue_signature
			self:_queue_layout(1)
		end
		if import_signature ~= self._import_signature then
			self._import_signature = import_signature
			self:_queue_layout(1)
		end

		if type(self._get_selected_offer) ~= "function" then
			return
		end

		local ok, raw_offer = pcall(self._get_selected_offer, self._view)
		local selected_offer

		if ok and raw_offer then
			selected_offer = {
				offer_id = safe_member(raw_offer, "offerId") or safe_member(raw_offer, "offer_id"),
				master_id = safe_member(raw_offer, "masterId") or safe_member(raw_offer, "master_id"),
			}

			local description = safe_member(raw_offer, "description")
			local choices = safe_member(description, "lootChoices") or safe_member(description, "loot_choices")
			local choice = type(choices) == "table" and choices[1] or nil

			if selected_offer.master_id == nil then
				if type(choice) == "table" then
					selected_offer.master_id = choice.masterId or choice.master_id or choice.id or choice.name
				else
					selected_offer.master_id = choice
				end
			end

			if selected_offer.offer_id == nil and selected_offer.master_id == nil then
				selected_offer = nil
			end
		end

		local selected_key = offer_selection_key(selected_offer)

		if self._pending_offer then
			local native_selected_key = selected_key

			if native_selected_key == offer_selection_key(self._pending_offer) then
				self._pending_offer = nil
				self._pending_offer_attempts = 0
			else
				self:_select_offer_from_row(self._pending_offer)

				return
			end
		end

		if selected_key ~= self._selected_offer_key then
			self._selected_offer = selected_offer
			self._selected_offer_key = selected_key
			self._selected_offer_id = selected_offer and selected_offer.offer_id
			self._selected_offer_master_id = selected_offer and selected_offer.master_id
		end

		if self._layout_pending and (self._layout_defer_frames or 0) > 0 then
			self._layout_defer_frames = self._layout_defer_frames - 1
		elseif self._layout_pending then
			self._layout_pending = false
			self:render()
		end
	end

	function self:_update_pivot()
		local panel = self._panel

		if not panel or type(panel.set_pivot_offset) ~= "function" then
			return false
		end

		local resolution = rawget(_G, "RESOLUTION_LOOKUP") or {}
		local scale_ok, render_scale = safe_call(panel.render_scale, panel)

		if not scale_ok then
			render_scale = resolution.scale
		end

		local layout = self._viewport_layout

		if type(layout) ~= "table" or type(layout.panel_pivot) ~= "function" then
			return false
		end

		local scenegraph = self._view and self._view._ui_scenegraph
		local info_box = scenegraph and scenegraph.info_box
		local canvas = scenegraph and scenegraph.canvas
		local info_position = info_box and info_box.world_position
		local info_size = info_box and info_box.size
		local canvas_position = canvas and canvas.world_position
		local anchor_right = info_position and info_size and tonumber(info_position[1]) and tonumber(info_size[1]) and info_position[1] + info_size[1]
		local canvas_top = canvas_position and tonumber(canvas_position[2])
		local x, y

		if type(layout.anchored_panel_pivot) == "function" and anchor_right and canvas_top then
			x, y = layout.anchored_panel_pivot(resolution.width, resolution.height, render_scale, PANEL_WIDTH, PANEL_HEIGHT, anchor_right, canvas_top, ANCHORED_PANEL_GAP, 110)
		else
			x, y = layout.panel_pivot(resolution.width, resolution.height, render_scale, PANEL_WIDTH, PANEL_HEIGHT)
		end

		if x == self._pivot_x and y == self._pivot_y then
			return false
		end

		panel:set_pivot_offset(x, y)
		self._pivot_x = x
		self._pivot_y = y

		return true
	end

	function self:attach(view)
		if not view or view._destroyed or type(view._add_element) ~= "function" or type(self._ViewElementGrid) ~= "table" then
			return false
		end

		if self._view == view and self._panel then
			self._panel:set_visibility(true)
			return self:render()
		end

		self:detach()

		local menu_settings = {
			bottom_chin = CONTENT_VERTICAL_PADDING,
			edge_padding = CONTENT_HORIZONTAL_PADDING * 2,
			enable_gamepad_scrolling = true,
			grid_size = {
				PANEL_WIDTH - CONTENT_HORIZONTAL_PADDING * 2,
				PANEL_HEIGHT,
			},
			grid_spacing = {
				0,
				ROW_SPACING,
			},
			ignore_blur = true,
			mask_size = {
				PANEL_WIDTH,
				PANEL_HEIGHT,
			},
			reference_name = PANEL_REFERENCE,
			reset_selection_on_navigation_change = false,
			scrollbar_width = 7,
			title_height = 0,
			top_padding = CONTENT_VERTICAL_PADDING,
			use_is_focused_for_navigation = false,
			use_select_on_focused = true,
			use_terminal_background = true,
		}

		local ok, panel = safe_call(view._add_element, view, self._ViewElementGrid, PANEL_REFERENCE, 30, menu_settings)

		if not ok or not panel then
			log("error", "Auto Crafter diagnostic panel could not initialize: " .. tostring(panel))

			return false
		end

		self._view = view
		self._panel = panel
		self._snapshot = nil
		self._controller_state = nil
		self._plan = nil
		self._phase = "view_ready"
		self._selected_offer_id = nil
		self._selected_offer_key = nil
		self._selected_offer = nil
		self._selected_offer_master_id = nil
		self._section_collapsed = default_section_state()
		self._pending_offer = nil
		self._pending_offer_attempts = 0
		self._idle_poll_elapsed = IDLE_POLL_INTERVAL
		self._layout_pending = false
		self._layout_defer_frames = 0
		self._trait_catalog_key = nil
		self._queue_signature = nil
		self._import_signature = nil
		self._queue_craft_armed = false
		self._queue_craft_confirmation_signature = nil
		self._queue_craft_confirmation_text = nil
		self._queue_snapshot_cache = nil
		self._import_snapshot_cache = nil
		self._presentation_snapshots_dirty = true
		self._ctrl_v_down = false


		self:_update_pivot()
		self:_refresh_games_lantern_snapshots()

		if type(panel.disable_input) == "function" then
			panel:disable_input(false)
		end

		if type(panel.set_visibility) == "function" then
			panel:set_visibility(true)
		end

		return self:render()
	end

	function self:detach()
		local view = self._view

		if view and not view._destroyed and type(view._remove_element) == "function" then
			pcall(view._remove_element, view, PANEL_REFERENCE)
		end

		self._view = nil
		self._panel = nil
		self._snapshot = nil
		self._controller_state = nil
		self._plan = nil
		self._phase = "idle"
		self._selected_offer_id = nil
		self._selected_offer_key = nil
		self._selected_offer = nil
		self._selected_offer_master_id = nil
		self._section_collapsed = default_section_state()
		self._pending_offer = nil
		self._pending_offer_attempts = 0
		self._layout_pending = false
		self._layout_defer_frames = 0
		self._trait_catalog_key = nil
		self._queue_signature = nil
		self._import_signature = nil
		self._queue_craft_armed = false
		self._queue_craft_confirmation_signature = nil
		self._queue_craft_confirmation_text = nil
		self._queue_snapshot_cache = nil
		self._import_snapshot_cache = nil
		self._presentation_snapshots_dirty = true
		self._ctrl_v_down = false
		self._pivot_x = nil
		self._pivot_y = nil
	end

	return self
end

Panel.PANEL_REFERENCE = PANEL_REFERENCE

return Panel
