local mod = get_mod("BetterInventory")

local function no_op_module(module, module_name)
	if type(module) == "table" then
		return module
	end

	mod:error("Failed to load %s; its features are disabled until the next successful reload.", module_name)

	local no_op = function()
		return false
	end

	return setmetatable({}, {
		__index = function(fallback, key)
			rawset(fallback, key, no_op)

			return no_op
		end,
	})
end

local CraftingMechanicusModifyView = require("scripts/ui/views/crafting_mechanicus_modify_view/crafting_mechanicus_modify_view")
local CreditsVendorView = require("scripts/ui/views/credits_vendor_view/credits_vendor_view")
local InventoryView = require("scripts/ui/views/inventory_view/inventory_view")
local InventoryViewContentBlueprints = require("scripts/ui/views/inventory_view/inventory_view_content_blueprints")
local ItemGridViewBase = require("scripts/ui/views/item_grid_view_base/item_grid_view_base")
local ItemGridViewBaseDefinitions = require("scripts/ui/views/item_grid_view_base/item_grid_view_base_definitions")
local InventoryWeaponsView = require("scripts/ui/views/inventory_weapons_view/inventory_weapons_view")
local ViewElementGrid = require("scripts/ui/view_elements/view_element_grid/view_element_grid")
local ItemBlueprintGenerator = require("scripts/ui/view_content_blueprints/item_blueprints")
local Text = require("scripts/utilities/ui/text")
local Layout = mod:io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_layout")
local Features = no_op_module(mod:io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_features"), "BetterInventory_features.lua")
local CurioAcquisition = no_op_module(mod:io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_curio_acquisition"), "BetterInventory_curio_acquisition.lua")
local ItemCustomization = no_op_module(mod:io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_item_customization"), "BetterInventory_item_customization.lua")

if type(Features.set_curio_acquisition_provider) == "function" then
	Features.set_curio_acquisition_provider(CurioAcquisition)
end

if type(Layout.set_item_customization_provider) == "function" then
	Layout.set_item_customization_provider(ItemCustomization)
end

if type(ItemCustomization.install) == "function" then
	ItemCustomization.install(mod, InventoryWeaponsView, Layout)
end
local unpack_values = table.unpack or unpack
local active_grid_view
local active_grid_configuration
local INVENTORY_GRID_CONFIGURATION = {
	blueprint_key = "item",
}
local HADRON_GRID_CONFIGURATION = {
	blueprint_key = "item",
	maximum_columns = 3,
}
local ARMOURY_GRID_CONFIGURATION = {
	blueprint_key = "store_item",
	maximum_columns = 3,
	store_item = true,
}
local GLOBAL_STORE_SERVICE = "get_all_characters_store_custom"
local GLOBAL_STORE_GRID_CONFIGURATION = {
	blueprint_key = "store_item",
	global_store = true,
	-- GlobalStore is a vendor view, not an inventory tab. Keep its compact
	-- cards capped at three columns even when a legacy profile still contains
	-- a four- or five-column `columns` value.
	maximum_columns = 3,
	store_item = true,
}
local GLOBAL_STORE_NATIVE_CONFIGURATION = {
	blueprint_key = "store_item",
	global_store = true,
	native_single_column = true,
	store_item = true,
}
local CHARACTER_OVERVIEW_WEAPON_WIDGET_TYPE = "better_inventory_character_overview_weapon"
local CHARACTER_OVERVIEW_CURIO_WIDGET_TYPE = "better_inventory_character_overview_curio"
local CHARACTER_OVERVIEW_EMPTY_CURIO_WIDGET_TYPE = "better_inventory_character_overview_empty_curio"
local CHARACTER_OVERVIEW_WEAPON_HEIGHT = 130
local CHARACTER_OVERVIEW_BLUEPRINTS = type(ItemBlueprintGenerator) == "function" and ItemBlueprintGenerator({
	600,
	CHARACTER_OVERVIEW_WEAPON_HEIGHT,
}) or nil

local function pack_values(...)
	return {
		n = select("#", ...),
		...,
	}
end

local function shallow_copy(source)
	local copy = {}

	for key, value in pairs(source or {}) do
		copy[key] = value
	end

	return copy
end

local function is_armoury_requisition_view(view)
	-- GlobalStore and similar mods reuse CreditsVendorView with a custom store
	-- service and add their own card footer content. Restrict BetterInventory's
	-- Armoury geometry to Darktide's native Requisition route.
	return view and view.__class_name == "CreditsVendorView" and view._optional_store_service == nil
end

local function is_global_store_view(view)
	return view and view.__class_name == "CreditsVendorView" and view._optional_store_service == GLOBAL_STORE_SERVICE
end

local function is_hadron_view(view)
	return view and view.__class_name == "CraftingMechanicusModifyView"
end

local function character_overview_weapon_kind(config)
	local slot_name = config and config.slot and config.slot.name

	if slot_name == "slot_primary" then
		return "melee"
	elseif slot_name == "slot_secondary" then
		return "ranged"
	end
end

local function character_overview_curio_slot(config)
	local slot_name = config and config.slot and config.slot.name

	return config and config.widget_type == "gadget_item_slot" and type(slot_name) == "string" and string.match(slot_name, "^slot_attachment_") ~= nil
end

local function mark_character_overview_requirement_met(widget)
	local content = widget and widget.content

	if content then
		-- InventoryView's native item-slot blueprints do not populate the
		-- requirement fields used by the detailed item pass. These are already
		-- equipped overview items, so the warning/lock overlay must stay hidden.
		content.level_requirement_met = true
		content.required_level = nil
	end
end

local function configure_character_overview_weapon_passes(blueprint)
	local weapon_name_left = 0

	for _, pass in ipairs(blueprint and blueprint.pass_template or {}) do
		if pass.style_id == "display_name" and pass.style and pass.style.offset then
			weapon_name_left = pass.style.offset[1] or 0

			break
		end
	end

	for _, pass in ipairs(blueprint and blueprint.pass_template or {}) do
		local style_id = pass.style_id
		local style = pass.style

		if type(style_id) == "string" and style then
			style.offset = style.offset or {
				0,
				0,
				0,
			}

			local move_up = 0
			local move_down = 0
			local foreground = false

			-- The native overview reserves a blank quality/mark row. Reuse that
			-- row for the first perk and pull the remaining detail rows upward.
			if string.find(style_id, "better_inventory_weapon_perk_", 1, true) == 1 or string.find(style_id, "better_inventory_blessing_", 1, true) == 1 then
				-- Overview-only compact pass: use the reserved quality/mark row and
				-- keep both blessing rows clear of the native frame overlay.
				move_up = 9
				foreground = true
				style.offset[1] = math.max(style.offset[1] or 0, weapon_name_left)
			elseif string.find(style_id, "better_inventory_weapon_modifier_", 1, true) == 1 or string.sub(style_id, 1, 4) == "qlc_" then
				foreground = true
			elseif style_id == "better_inventory_quick_look_card_dump_stat" then
				move_down = 6
				foreground = true
			elseif style_id == "item_level" then
				-- The weapon item-level pass is top-aligned (despite its
				-- bottom-aligned text), so reducing this positive adjustment moves
				-- it upward.
				move_down = 4
				foreground = true
			end

			if move_up > 0 then
				-- Bottom-aligned passes move upward with a more positive Y offset;
				-- top-aligned modifier passes move upward with a smaller Y offset.
				if style.vertical_alignment == "bottom" then
					style.offset[2] = (style.offset[2] or 0) - move_up
				else
					style.offset[2] = (style.offset[2] or 0) - move_up
				end
			end

			if move_down > 0 then
				if style.vertical_alignment == "bottom" then
					style.offset[2] = (style.offset[2] or 0) - move_down
				else
					style.offset[2] = (style.offset[2] or 0) + move_down
				end
			end

			if foreground then
				-- The native loadout frame is drawn at a higher Z layer than the
				-- item widget. Keep only the information passes above that frame;
				-- the card background and weapon art remain underneath it.
				style.offset[3] = math.max(style.offset[3] or 0, 31)
			end
		end
	end
end

local function move_character_overview_weapon_icon(blueprint)
	for _, pass in ipairs(blueprint and blueprint.pass_template or {}) do
		if pass.style_id == "icon" and pass.style then
			local style = pass.style
			style.offset = style.offset or {
				0,
				0,
				0,
			}

			-- Weapon icons use the card's top-aligned coordinate space. A smaller
			-- Y offset raises them; retain the opposite adjustment for a blueprint
			-- that supplies a bottom-aligned icon style.
			if style.vertical_alignment == "bottom" then
				style.offset[2] = (style.offset[2] or 0) + 6
			else
				style.offset[2] = (style.offset[2] or 0) - 6
			end

			return
		end
	end
end

local function character_overview_weapon_blueprint()
	local native_blueprint = InventoryViewContentBlueprints.item_slot
	local detailed_blueprint = CHARACTER_OVERVIEW_BLUEPRINTS and CHARACTER_OVERVIEW_BLUEPRINTS.item

	if type(native_blueprint) ~= "table" or type(detailed_blueprint) ~= "table" or not detailed_blueprint.pass_template then
		return
	end

	-- InventoryView's native item-slot blueprint owns the live icon lifecycle and
	-- equipment refresh. Keep those callbacks, but give them the same pass set
	-- and geometry as BetterInventory's detailed single-column inventory card.
	local blueprint = table.clone(detailed_blueprint)
	blueprint.size = table.clone(native_blueprint.size or detailed_blueprint.size)
	blueprint.size[2] = CHARACTER_OVERVIEW_WEAPON_HEIGHT
	blueprint.pass_template = table.clone(detailed_blueprint.pass_template)
	blueprint.init = native_blueprint.init
	blueprint.update = native_blueprint.update
	blueprint.destroy = native_blueprint.destroy
	-- configure_native_item_blueprint wraps update_data to refresh the detailed
	-- text/stat passes after the equipped item changes. The native item-slot
	-- blueprint has no update_data callback, so provide a harmless seam first.
	blueprint.update_data = function()
		return
	end

	Layout.configure_native_item_blueprint(mod, blueprint, blueprint.size[1], {
		native_single_column = true,
		character_overview = true,
	})
	configure_character_overview_weapon_passes(blueprint)
	move_character_overview_weapon_icon(blueprint)

	local configured_init = blueprint.init

	blueprint.init = function(parent, widget, element, callback_name, secondary_callback_name, ui_renderer, double_click_callback, template)
		if configured_init then
			configured_init(parent, widget, element, callback_name, secondary_callback_name, ui_renderer, double_click_callback, template)
		end

		mark_character_overview_requirement_met(widget)
	end

	local native_update = blueprint.update

	blueprint.update = function(parent, widget, input_service, dt, t, ui_renderer)
		local content = widget and widget.content
		local element = content and content.element
		local previous_item = element and element.item

		if native_update then
			native_update(parent, widget, input_service, dt, t, ui_renderer)
		end

		mark_character_overview_requirement_met(widget)

		local slot = element and element.slot
		local current_item = slot and parent.equipped_item_in_slot and parent:equipped_item_in_slot(slot.name)

		if element and current_item ~= previous_item then
			element.item = current_item

			if blueprint.update_data then
				blueprint.update_data(parent, widget, element)
			end
		end
	end

	return blueprint
end

local function character_overview_curio_blueprint()
	local native_blueprint = InventoryViewContentBlueprints.gadget_item_slot
	local detailed_blueprint = CHARACTER_OVERVIEW_BLUEPRINTS and CHARACTER_OVERVIEW_BLUEPRINTS.item

	if type(native_blueprint) ~= "table" or type(detailed_blueprint) ~= "table" or not detailed_blueprint.pass_template then
		return
	end

	local blueprint = table.clone(detailed_blueprint)
	blueprint.size = table.clone(native_blueprint.size or {
		193,
		250,
	})
	-- Keep the overview Curio compact; its native decorative frame leaves a
	-- relatively short readable region, so avoid expanding into the lower frame.
	blueprint.size[2] = 250
	blueprint.pass_template = table.clone(detailed_blueprint.pass_template)
	blueprint.init = native_blueprint.init
	blueprint.update = native_blueprint.update
	blueprint.destroy = native_blueprint.destroy
	blueprint.update_data = function()
		return
	end

	Layout.configure_native_item_blueprint(mod, blueprint, blueprint.size[1], {
		native_single_column = true,
		character_overview = true,
	})

	local curio_font_scale = math.max(50, math.min(150, tonumber(mod:get("character_overview_curio_font_size_percent")) or 110)) / 100
	local curio_name_mode = mod:get("character_overview_curio_name_mode")

	if mod:get("name_it_force_curio_name_in_detailed_mode") ~= false then
		curio_name_mode = "two_lines"
	end

	if curio_name_mode ~= "one_line" and curio_name_mode ~= "two_lines" then
		curio_name_mode = mod:get("character_overview_show_curio_names") == true and "one_line" or "none"
	end

	local curio_name_line_limit = curio_name_mode == "two_lines" and 2 or curio_name_mode == "one_line" and 1 or 0
	local show_curio_name = curio_name_line_limit > 0

	for index = 1, #blueprint.pass_template do
		local style = blueprint.pass_template[index].style

		if style and type(style.font_size) == "number" then
			style.font_size = math.max(1, math.floor(style.font_size * curio_font_scale + 0.5))
		end
	end

	local configured_init = blueprint.init

	blueprint.init = function(parent, widget, element, callback_name, secondary_callback_name, ui_renderer, double_click_callback, template)
		if configured_init then
			configured_init(parent, widget, element, callback_name, secondary_callback_name, ui_renderer, double_click_callback, template)
		end

		mark_character_overview_requirement_met(widget)
	end

	local card_width = blueprint.size[1]
	local icon = nil
	local display_name = nil
	local sub_display_name = nil
	local rarity_name = nil
	local item_level = nil
	local curio_stat_passes = {}

	for index = 1, #blueprint.pass_template do
		local pass = blueprint.pass_template[index]

		if pass.style_id == "icon" then
			icon = pass
		elseif pass.style_id == "display_name" then
			display_name = pass
		elseif pass.style_id == "sub_display_name" then
			sub_display_name = pass
		elseif pass.style_id == "rarity_name" then
			rarity_name = pass
		elseif pass.style_id == "item_level" then
			item_level = pass
		elseif type(pass.style_id) == "string" then
			local curio_stat_index = tonumber(string.match(pass.style_id, "^better_inventory_curio_stat_(%d+)$"))

			if curio_stat_index then
				curio_stat_passes[curio_stat_index] = pass
			end
		end
	end

	local primary_curio_style = curio_stat_passes[1] and curio_stat_passes[1].style
	local curio_name_font_size = primary_curio_style and primary_curio_style.font_size or math.max(1, math.floor(16 * curio_font_scale + 0.5))
	-- Reserve selected title lines plus a fixed gap before all four stats.
	local curio_name_block_height = curio_name_font_size * curio_name_line_limit + 11
	local curio_stat_base_offsets = {}
	local curio_stat_line_heights = {}

	if show_curio_name and display_name and display_name.style then
		display_name.visibility_function = function(content)
			return content and type(content.display_name) == "string" and content.display_name ~= ""
		end
		display_name.style.horizontal_alignment = "left"
		display_name.style.vertical_alignment = "top"
		display_name.style.text_horizontal_alignment = "left"
		display_name.style.text_vertical_alignment = "top"
		display_name.style.word_wrap = false
		display_name.style.font_size = curio_name_font_size
		display_name.style.text_color = {
			255,
			220,
			230,
			210,
		}
		display_name.style.default_color = table.clone(display_name.style.text_color)
		display_name.style.hover_color = table.clone(display_name.style.text_color)
		display_name.style.offset = {
			16,
			7,
			12,
		}
		display_name.style.size = {
			math.max(40, card_width - 56),
			curio_name_block_height,
		}

		for index = 1, 4 do
			local stat_style = curio_stat_passes[index] and curio_stat_passes[index].style

			if stat_style and stat_style.offset then
				stat_style.offset[2] = (stat_style.offset[2] or 0) + curio_name_block_height
			end
		end
	end

	for index = 1, 4 do
		local stat_style = curio_stat_passes[index] and curio_stat_passes[index].style

		if stat_style and stat_style.offset then
			curio_stat_base_offsets[index] = stat_style.offset[2] or 0
			curio_stat_line_heights[index] = (stat_style.font_size or 13) + 5
			stat_style.word_wrap = false
		end
	end

	-- Keep the overview's tall Curio frame, but use the same compact landscape
	-- icon treatment and bottom-right item level as the detailed inventory card.
	if icon and icon.style then
		local icon_width = math.floor(math.min(card_width - 8, 188) * 1.5 + 0.5)

		icon.style.horizontal_alignment = "center"
		icon.style.vertical_alignment = "top"
		icon.style.size = {
			icon_width,
			math.floor(icon_width * 0.5 + 0.5),
		}
		icon.style.offset = {
			0,
			67,
			4,
		}
	end

	if not show_curio_name and display_name then
		display_name.visibility_function = function()
			return false
		end
	end

	for _, pass in ipairs({ sub_display_name, rarity_name }) do
		if pass then
			pass.visibility_function = function()
				return false
			end
		end
	end

	local function fit_curio_text(widget, ui_renderer)
		local style = show_curio_name and widget and widget.style and widget.style.display_name
		local content = widget and widget.content

		if style and content then
			style.font_size = curio_name_font_size

			local displayed_name = content.display_name

			if type(displayed_name) == "string" and displayed_name ~= "" and displayed_name ~= content.better_inventory_fitted_curio_name then
				content.better_inventory_full_display_name = string.gsub(displayed_name, "[\r\n]+", " ")
			end

			local full_name = content.better_inventory_full_display_name or displayed_name
			local maximum_width = style.size and style.size[1]

			if ui_renderer and type(full_name) == "string" and full_name ~= "" and type(maximum_width) == "number" then
				local minimum_font_size = 8
				local wrapped_rows

				while style.font_size > minimum_font_size do
					wrapped_rows = Text.word_wrap(ui_renderer, full_name, style, maximum_width)

					if not wrapped_rows or #wrapped_rows <= curio_name_line_limit then
						break
					end

					style.font_size = style.font_size - 1
				end

				wrapped_rows = Text.word_wrap(ui_renderer, full_name, style, maximum_width)

				local fitted_name

				if wrapped_rows and #wrapped_rows <= curio_name_line_limit then
					fitted_name = table.concat(wrapped_rows, "\n")
				elseif curio_name_line_limit == 1 then
					fitted_name = Text.crop_text_width(ui_renderer, full_name, style, maximum_width)
				else
					local fitted_rows = {}

					for index = 1, curio_name_line_limit do
						fitted_rows[index] = wrapped_rows and wrapped_rows[index] or ""
					end

					fitted_rows[curio_name_line_limit] = Text.crop_text_width(ui_renderer, fitted_rows[curio_name_line_limit] .. "…", style, maximum_width)
					fitted_name = table.concat(fitted_rows, "\n")
				end

				content.display_name = fitted_name
				content.better_inventory_fitted_curio_name = fitted_name
			end
		end

		if not content or not ui_renderer then
			return
		end

		local cumulative_extra_height = 0

		for index = 1, 4 do
			local content_id = "better_inventory_curio_stat_" .. index
			local full_content_id = "better_inventory_overview_full_curio_stat_" .. index
			local fitted_content_id = "better_inventory_overview_fitted_curio_stat_" .. index
			local stat_style = widget.style and widget.style[content_id]
			local displayed_value = content[content_id]

			if stat_style and type(displayed_value) == "string" and displayed_value ~= "" then
				if displayed_value ~= content[fitted_content_id] then
					local full_value = content["better_inventory_full_curio_stat_" .. index] or displayed_value

					content[full_content_id] = string.gsub(full_value, "[\r\n]+", " ")
				end

				local full_value = content[full_content_id] or displayed_value
				local maximum_width = stat_style.better_inventory_max_text_width or stat_style.size and stat_style.size[1]
				local wrapped_rows = maximum_width and Text.word_wrap(ui_renderer, full_value, stat_style, maximum_width)
				local line_count = math.max(1, wrapped_rows and #wrapped_rows or 1)
				local fitted_value = wrapped_rows and table.concat(wrapped_rows, "\n") or full_value
				local line_height = curio_stat_line_heights[index] or (stat_style.font_size or 13) + 5

				stat_style.offset[2] = (curio_stat_base_offsets[index] or 0) + cumulative_extra_height
				stat_style.size[2] = line_height * line_count
				content[content_id] = fitted_value
				content[fitted_content_id] = fitted_value
				cumulative_extra_height = cumulative_extra_height + (line_count - 1) * line_height
			elseif stat_style then
				stat_style.offset[2] = (curio_stat_base_offsets[index] or 0) + cumulative_extra_height
				stat_style.size[2] = curio_stat_line_heights[index] or stat_style.size[2]
			end
		end
	end

	local overview_init = blueprint.init

	blueprint.init = function(parent, widget, element, callback_name, secondary_callback_name, ui_renderer, double_click_callback, template)
		overview_init(parent, widget, element, callback_name, secondary_callback_name, ui_renderer, double_click_callback, template)
		fit_curio_text(widget, ui_renderer)
	end

	if item_level and item_level.style then
		item_level.style.horizontal_alignment = "right"
		item_level.style.vertical_alignment = "bottom"
		item_level.style.text_horizontal_alignment = "right"
		item_level.style.text_vertical_alignment = "bottom"
		item_level.style.offset = {
			-8,
			-8,
			12,
		}
		item_level.style.size = {
			card_width - 16,
			30,
		}
	end

	local native_update = blueprint.update

	blueprint.update = function(parent, widget, input_service, dt, t, ui_renderer)
		local content = widget and widget.content
		local element = content and content.element
		local previous_item = element and element.item

		if native_update then
			native_update(parent, widget, input_service, dt, t, ui_renderer)
		end

		mark_character_overview_requirement_met(widget)
		fit_curio_text(widget, ui_renderer)

		local slot = element and element.slot
		local current_item = slot and parent.equipped_item_in_slot and parent:equipped_item_in_slot(slot.name)

		if element and current_item ~= previous_item then
			element.item = current_item

			if blueprint.update_data then
				blueprint.update_data(parent, widget, element)
			end
		end
	end

	return blueprint
end

local function character_overview_empty_curio_blueprint()
	local native_blueprint = InventoryViewContentBlueprints.gadget_item_slot

	if type(native_blueprint) ~= "table" or type(native_blueprint.pass_template) ~= "table" then
		return
	end

	local blueprint = table.clone(native_blueprint)

	blueprint.pass_template = table.clone(native_blueprint.pass_template)

	-- Keep Darktide's empty/locked slot artwork and behavior, but suppress the
	-- native empty label (commonly localized as "n/a"). Locked-slot messages and
	-- symbols remain visible until the slot unlocks.
	for _, pass in ipairs(blueprint.pass_template) do
		if pass.pass_type == "text" then
			local native_visibility = pass.visibility_function

			pass.visibility_function = function(content, style)
				if content and content.unlocked and not content.item then
					return false
				end

				return native_visibility == nil or native_visibility(content, style)
			end
		end
	end

	return blueprint
end

local function is_armoury_sort_view(view)
	return is_armoury_requisition_view(view) or is_global_store_view(view)
end

-- Darktide class tables can contain the exact same inherited function object.
-- Give each target class its own forwarder before DMF hooks it, preventing
-- duplicate-hook detection and keeping every view in the normal hook chain.
local function ensure_class_method(class, method)
	if type(class) ~= "table" then
		return false
	end

	local super = rawget(class, "super") or class.super
	local inherited_method = super and super[method]
	local own_method = rawget(class, method)

	if type(own_method) == "function" and own_method ~= inherited_method then
		return true
	end

	if type(inherited_method) ~= "function" then
		return false
	end

	local owner = class
	local fallback = inherited_method

	rawset(owner, method, function(self, ...)
		local parent = rawget(owner, "super") or owner.super
		local parent_method = parent and parent[method] or fallback

		return parent_method(self, ...)
	end)

	return true
end

local COLOR_PRESETS = {
	red = {
		235,
		85,
		85,
	},
	light_blue = {
		105,
		200,
		235,
	},
	sky_blue = {
		144,
		213,
		255,
	},
	purple = {
		190,
		105,
		230,
	},
	pink = {
		255,
		94,
		132,
	},
	orange = {
		235,
		155,
		60,
	},
	yellow = {
		235,
		205,
		80,
	},
	green = {
		105,
		210,
		120,
	},
	light_green = {
		190,
		210,
		180,
	},
	terminal_green = {
		113,
		126,
		103,
	},
	neutral = {
		220,
		230,
		210,
	},
}
local COLOR_TARGETS = {
	{
		prefix = "weapon_perk_text_color",
		default_preset = "light_green",
	},
	{
		prefix = "weapon_blessing_text_color",
		default_preset = "light_blue",
	},
	{
		prefix = "weapon_modifier_lowest_color",
		default_preset = "pink",
	},
	{
		prefix = "curio_secondary_text_color",
		default_preset = "neutral",
	},
	{
		prefix = "curio_health_color",
		default_preset = "red",
	},
	{
		prefix = "curio_toughness_color",
		default_preset = "light_blue",
	},
	{
		prefix = "curio_wound_color",
		default_preset = "purple",
	},
	{
		prefix = "curio_stamina_color",
		default_preset = "yellow",
	},
}
local color_target_by_setting_id = {}
local option_dependency_entries = {}

for i = 1, #COLOR_TARGETS do
	local target = COLOR_TARGETS[i]

	target.preset_id = target.prefix .. "_preset"
	target.channel_ids = {
		target.prefix .. "_r",
		target.prefix .. "_g",
		target.prefix .. "_b",
	}
	color_target_by_setting_id[target.preset_id] = {
		target = target,
		is_preset = true,
	}

	for channel = 1, 3 do
		color_target_by_setting_id[target.channel_ids[channel]] = {
			target = target,
			is_preset = false,
		}
	end
end

local function apply_color_preset(target)
	local preset_id = mod:get(target.preset_id) or target.default_preset
	local color = COLOR_PRESETS[preset_id]

	if not color then
		return
	end

	for channel = 1, 3 do
		mod:set(target.channel_ids[channel], color[channel], false)
	end
end

local function set_option_enabled(entry, enabled, reason)
	if not entry then
		return
	end

	entry.disabled = not enabled
	entry.disabled_by = enabled and nil or {
		reason,
	}
end

local function refresh_option_dependencies()
	local grid_enabled = mod:get("enable_grid_layout") ~= false
	local single_column_enabled = not grid_enabled
	local automatic_height = mod:get("automatic_card_height") ~= false
	local native_reason = mod:localize("option_requires_grid_layout")
	local single_column_reason = mod:localize("option_requires_single_column_mode")

	for _, setting_id in ipairs({
		"melee_columns",
		"ranged_columns",
		"curio_columns",
		"expand_inventory_window",
		"grid_spacing",
		"automatic_card_height",
		"enable_hadron_entreat_grid",
		"enable_armoury_requisition_grid",
		"enable_global_store_grid",
	}) do
		set_option_enabled(option_dependency_entries[setting_id], grid_enabled, native_reason)
	end

	-- These view-specific switches are the single-column counterparts to the
	-- grid integrations above. They remain available only when the global grid
	-- layout is disabled, so each vendor can mirror the detailed inventory card
	-- independently without changing the grid-mode controls.
	set_option_enabled(option_dependency_entries.enable_hadron_single_column_mirror, single_column_enabled, single_column_reason)
	set_option_enabled(option_dependency_entries.enable_armoury_single_column_mirror, single_column_enabled, single_column_reason)

	local card_height_enabled = grid_enabled and not automatic_height
	local card_height_reason = grid_enabled and mod:localize("option_disabled_by_automatic_height") or native_reason

	set_option_enabled(option_dependency_entries.card_height, card_height_enabled, card_height_reason)

	local window_expansion_enabled = grid_enabled and mod:get("expand_inventory_window") ~= false
	local curio_expansion_enabled = window_expansion_enabled and mod:get("expand_curio_inventory_window") ~= false
	local expansion_reason = grid_enabled and mod:localize("option_requires_window_expansion") or native_reason
	local weapon_columns = math.max(Layout.columns(mod, 5, "melee"), Layout.columns(mod, 5, "ranged"))
	local weapon_width_threshold = mod:get("weapon_extra_width_column_threshold") == "five_only" and 5 or 4
	local weapon_extra_width_enabled = window_expansion_enabled and weapon_columns >= weapon_width_threshold
	local weapon_extra_width_reason = not window_expansion_enabled and expansion_reason or mod:localize("option_requires_weapon_extra_width_threshold")
	local curio_target_reason = not window_expansion_enabled and expansion_reason or not curio_expansion_enabled and mod:localize("option_requires_curio_expansion") or nil
	local armoury_grid_enabled = grid_enabled and mod:get("enable_armoury_requisition_grid") ~= false
	local global_store_grid_enabled = grid_enabled and mod:get("enable_global_store_grid") ~= false
	local global_store_integration_enabled = mod:get("enable_global_store_integration") ~= false
	local global_store_native_enabled = global_store_integration_enabled and not grid_enabled
	local armoury_expansion_enabled = armoury_grid_enabled and mod:get("expand_armoury_requisition_window") ~= false
	local armoury_reason = grid_enabled and mod:localize("option_requires_armoury_grid") or native_reason
	local armoury_target_reason = armoury_grid_enabled and mod:localize("option_requires_armoury_expansion") or armoury_reason
	local weapon_perks_enabled = mod:get("show_weapon_perks") == true
	local weapon_perk_ranks_enabled = weapon_perks_enabled and mod:get("show_weapon_perk_rank_symbols") == true
	local weapon_blessing_mode = mod:get("weapon_blessing_display_mode")
	local weapon_blessing_icons_enabled = weapon_blessing_mode == "icons"
	local weapon_blessing_ranked_text_enabled = weapon_blessing_mode == "ranked_text"
	local weapon_blessing_text_enabled = weapon_blessing_mode == "text" or weapon_blessing_ranked_text_enabled
	local weapon_blessings_enabled = weapon_blessing_mode ~= "off"
	local single_column_blessing_icons_enabled = single_column_enabled and weapon_blessing_text_enabled and mod:get("single_column_blessing_icons_on_right") ~= false
	local blessing_icon_controls_enabled = weapon_blessing_icons_enabled or single_column_blessing_icons_enabled
	local blessing_icon_controls_reason = single_column_enabled and weapon_blessing_text_enabled and mod:localize("option_requires_single_column_blessing_icons") or mod:localize("option_requires_weapon_blessings")
	local weapon_rank_symbols_enabled = weapon_perk_ranks_enabled or weapon_blessing_ranked_text_enabled
	local weapon_perk_blessing_sections_enabled = weapon_perks_enabled and weapon_blessings_enabled
	local detailed_curio_profile = mod:get("curio_display_profile") == "detailed"
	local quick_discard_enabled = mod:get("enable_experimental_quick_discard") == true
	local quick_discard_reason = mod:localize("option_requires_experimental_quick_discard")
	local automatic_curio_enabled = mod:get("enable_automatic_curio_acquisition") == true
	local automatic_curio_reason = mod:localize("option_requires_automatic_curio_acquisition")
	local automatic_curio_character_mode = mod:get("automatic_curio_target_mode") == "characters"
	local automatic_curio_classes_enabled = automatic_curio_enabled and not automatic_curio_character_mode
	local automatic_curio_characters_enabled = automatic_curio_enabled and automatic_curio_character_mode
	local automatic_curio_classes_reason = automatic_curio_enabled and mod:localize("option_requires_automatic_curio_classes_mode") or automatic_curio_reason
	local automatic_curio_characters_reason = automatic_curio_enabled and mod:localize("option_requires_automatic_curio_characters_mode") or automatic_curio_reason
	local inventory_options_panel_enabled = mod:get("enable_inventory_options_panel_prototype") == true
	local inventory_options_panel_reason = mod:localize("option_requires_inventory_options_panel_prototype")
	local quick_look_card_grid_enabled = grid_enabled and mod:get("enable_quick_look_card_grid_integration") ~= false
	local quick_look_card_grid_reason = grid_enabled and mod:localize("option_requires_quick_look_card_grid_integration") or native_reason
	local quick_look_card_single_column_enabled = single_column_enabled and mod:get("enable_quick_look_card_single_column_integration") ~= false
	local quick_look_card_single_column_reason = single_column_enabled and mod:localize("option_requires_quick_look_card_single_column_integration") or single_column_reason
	local weapon_modifier_lowest_color_enabled = quick_look_card_grid_enabled or quick_look_card_single_column_enabled
	local weapon_modifier_lowest_color_reason = grid_enabled and quick_look_card_grid_reason or quick_look_card_single_column_reason
	local quick_look_card_above_power = quick_look_card_grid_enabled and mod:get("quick_look_card_grid_stat_position") ~= "name_left" and mod:get("quick_look_card_grid_stat_position") ~= "name_right"
	local quick_look_card_bottom_padding_reason = quick_look_card_grid_enabled and mod:localize("option_requires_quick_look_card_above_power") or quick_look_card_grid_reason

	set_option_enabled(option_dependency_entries.expand_curio_inventory_window, window_expansion_enabled, expansion_reason)
	set_option_enabled(option_dependency_entries.weapon_extra_width_column_threshold, window_expansion_enabled, expansion_reason)
	set_option_enabled(option_dependency_entries.five_column_weapon_extra_width, weapon_extra_width_enabled, weapon_extra_width_reason)
	set_option_enabled(option_dependency_entries.curio_target_card_width, curio_expansion_enabled, curio_target_reason)
	set_option_enabled(option_dependency_entries.expand_armoury_requisition_window, armoury_grid_enabled, armoury_reason)
	set_option_enabled(option_dependency_entries.enable_armoury_requisition_sorting_panel, armoury_grid_enabled, armoury_reason)
	set_option_enabled(option_dependency_entries.brighten_armoury_item_levels, armoury_grid_enabled, armoury_reason)
	set_option_enabled(option_dependency_entries.three_column_weapon_name_font_size, armoury_grid_enabled, armoury_reason)
	set_option_enabled(option_dependency_entries.armoury_requisition_target_card_width, armoury_expansion_enabled, armoury_target_reason)
	local global_store_integration_reason = grid_enabled and mod:localize("option_requires_global_store_integration") or native_reason
	local global_store_reason = global_store_integration_enabled and grid_enabled and mod:localize("option_requires_global_store_grid") or global_store_integration_reason
	set_option_enabled(option_dependency_entries.enable_global_store_integration, true)
	set_option_enabled(option_dependency_entries.enable_global_store_grid, global_store_integration_enabled and grid_enabled, global_store_integration_reason)
	set_option_enabled(option_dependency_entries.enable_global_store_sorting_panel, global_store_integration_enabled and global_store_grid_enabled, global_store_reason)
	local global_store_layout_enabled = global_store_integration_enabled and (global_store_grid_enabled or global_store_native_enabled)
	set_option_enabled(option_dependency_entries.global_store_character_photo_size_percent, global_store_layout_enabled, global_store_reason)
	set_option_enabled(option_dependency_entries.global_store_price_row_padding, global_store_layout_enabled, global_store_reason)
	set_option_enabled(option_dependency_entries.global_store_character_info_gap, global_store_layout_enabled, global_store_reason)
	set_option_enabled(option_dependency_entries.global_store_character_class_icon_size, global_store_layout_enabled, global_store_reason)
	set_option_enabled(option_dependency_entries.global_store_character_name_font_size, global_store_layout_enabled, global_store_reason)
	set_option_enabled(option_dependency_entries.global_store_compact_character_names, global_store_layout_enabled, global_store_reason)
	set_option_enabled(option_dependency_entries.global_store_single_column_modifier_horizontal_position, global_store_native_enabled, global_store_integration_reason)
	set_option_enabled(option_dependency_entries.global_store_single_column_modifier_vertical_position, global_store_native_enabled, global_store_integration_reason)
	local character_overview_curio_enabled = mod:get("enable_character_overview_curio_details") ~= false
	set_option_enabled(option_dependency_entries.character_overview_curio_name_mode, character_overview_curio_enabled, mod:localize("option_requires_character_overview_curio_details"))
	set_option_enabled(option_dependency_entries.character_overview_curio_font_size_percent, character_overview_curio_enabled, mod:localize("option_requires_character_overview_curio_details"))
	set_option_enabled(option_dependency_entries.weapon_perk_compression, weapon_perks_enabled, mod:localize("option_requires_weapon_perks"))
	set_option_enabled(option_dependency_entries.show_weapon_perk_rank_symbols, weapon_perks_enabled, mod:localize("option_requires_weapon_perks"))
	set_option_enabled(option_dependency_entries.weapon_perk_rank_icon_size, weapon_rank_symbols_enabled, mod:localize("option_requires_rank_symbols"))
	set_option_enabled(option_dependency_entries.remove_weapon_perk_plus_signs, weapon_perks_enabled, mod:localize("option_requires_weapon_perks"))
	set_option_enabled(option_dependency_entries.weapon_perk_text_color_preset, weapon_perks_enabled, mod:localize("option_requires_weapon_perks"))
	set_option_enabled(option_dependency_entries.weapon_perk_text_color_r, weapon_perks_enabled, mod:localize("option_requires_weapon_perks"))
	set_option_enabled(option_dependency_entries.weapon_perk_text_color_g, weapon_perks_enabled, mod:localize("option_requires_weapon_perks"))
	set_option_enabled(option_dependency_entries.weapon_perk_text_color_b, weapon_perks_enabled, mod:localize("option_requires_weapon_perks"))
	set_option_enabled(option_dependency_entries.weapon_perk_text_opacity, weapon_perks_enabled, mod:localize("option_requires_weapon_perks"))
	set_option_enabled(option_dependency_entries.weapon_perk_vertical_spacing, weapon_perks_enabled, mod:localize("option_requires_weapon_perks"))
	set_option_enabled(option_dependency_entries.blessing_text_item_level_separation, weapon_blessing_text_enabled, mod:localize("option_requires_weapon_blessing_text"))
	set_option_enabled(option_dependency_entries.auto_fit_long_blessing_names, weapon_blessing_text_enabled, mod:localize("option_requires_weapon_blessing_text"))
	set_option_enabled(option_dependency_entries.truncate_long_blessing_names, weapon_blessing_text_enabled, mod:localize("option_requires_weapon_blessing_text"))
	set_option_enabled(option_dependency_entries.weapon_blessing_text_color_preset, weapon_blessing_text_enabled, mod:localize("option_requires_weapon_blessing_text"))
	set_option_enabled(option_dependency_entries.weapon_blessing_text_color_r, weapon_blessing_text_enabled, mod:localize("option_requires_weapon_blessing_text"))
	set_option_enabled(option_dependency_entries.weapon_blessing_text_color_g, weapon_blessing_text_enabled, mod:localize("option_requires_weapon_blessing_text"))
	set_option_enabled(option_dependency_entries.weapon_blessing_text_color_b, weapon_blessing_text_enabled, mod:localize("option_requires_weapon_blessing_text"))
	set_option_enabled(option_dependency_entries.weapon_blessing_text_opacity, weapon_blessing_text_enabled, mod:localize("option_requires_weapon_blessing_text"))
	set_option_enabled(option_dependency_entries.weapon_blessing_text_vertical_spacing, weapon_blessing_text_enabled, mod:localize("option_requires_weapon_blessing_text"))
	set_option_enabled(option_dependency_entries.weapon_blessing_text_bottom_padding, weapon_blessing_text_enabled, mod:localize("option_requires_weapon_blessing_text"))
	set_option_enabled(option_dependency_entries.blessing_icon_size, blessing_icon_controls_enabled, blessing_icon_controls_reason)
	set_option_enabled(option_dependency_entries.blessing_icon_spacing, blessing_icon_controls_enabled, blessing_icon_controls_reason)
	set_option_enabled(option_dependency_entries.weapon_perk_blessing_spacing, weapon_perk_blessing_sections_enabled, mod:localize("option_requires_perk_and_blessing_sections"))
	set_option_enabled(option_dependency_entries.curio_secondary_stat_font_size, detailed_curio_profile, mod:localize("option_requires_detailed_curio_profile"))
	set_option_enabled(option_dependency_entries.curio_primary_secondary_spacing, detailed_curio_profile, mod:localize("option_requires_detailed_curio_profile"))
	set_option_enabled(option_dependency_entries.single_column_layout_group, single_column_enabled, single_column_reason)
	set_option_enabled(option_dependency_entries.single_column_weapon_name_font_size, single_column_enabled, single_column_reason)
	set_option_enabled(option_dependency_entries.single_column_blessing_icons_on_right, single_column_enabled and weapon_blessing_text_enabled, not single_column_enabled and single_column_reason or mod:localize("option_requires_weapon_blessing_text"))
	set_option_enabled(option_dependency_entries.quick_look_card_single_column_font_size, quick_look_card_single_column_enabled, quick_look_card_single_column_reason)
	set_option_enabled(option_dependency_entries.quick_look_card_single_column_label_value_gap, quick_look_card_single_column_enabled, quick_look_card_single_column_reason)
	set_option_enabled(option_dependency_entries.quick_look_card_single_column_horizontal_position, quick_look_card_single_column_enabled, quick_look_card_single_column_reason)
	set_option_enabled(option_dependency_entries.quick_look_card_single_column_vertical_position, quick_look_card_single_column_enabled, quick_look_card_single_column_reason)
	set_option_enabled(option_dependency_entries.quick_look_card_grid_stat_position, quick_look_card_grid_enabled, quick_look_card_grid_reason)
	set_option_enabled(option_dependency_entries.quick_look_card_grid_font_size, quick_look_card_grid_enabled, quick_look_card_grid_reason)
	set_option_enabled(option_dependency_entries.quick_look_card_grid_bottom_padding, quick_look_card_above_power, quick_look_card_bottom_padding_reason)
	set_option_enabled(option_dependency_entries.weapon_modifier_lowest_color_preset, weapon_modifier_lowest_color_enabled, weapon_modifier_lowest_color_reason)
	set_option_enabled(option_dependency_entries.weapon_modifier_lowest_color_r, weapon_modifier_lowest_color_enabled, weapon_modifier_lowest_color_reason)
	set_option_enabled(option_dependency_entries.weapon_modifier_lowest_color_g, weapon_modifier_lowest_color_enabled, weapon_modifier_lowest_color_reason)
	set_option_enabled(option_dependency_entries.weapon_modifier_lowest_color_b, weapon_modifier_lowest_color_enabled, weapon_modifier_lowest_color_reason)
	set_option_enabled(option_dependency_entries.weapon_modifier_lowest_color_opacity, weapon_modifier_lowest_color_enabled, weapon_modifier_lowest_color_reason)
	set_option_enabled(option_dependency_entries.name_it_force_curio_name_in_detailed_mode, detailed_curio_profile, mod:localize("option_requires_detailed_curio_profile"))
	set_option_enabled(option_dependency_entries.curio_content_name_it_curio_name, detailed_curio_profile, mod:localize("option_requires_detailed_curio_profile"))
	local custom_item_colors_enabled = mod:get("enable_custom_item_name_and_colors") ~= false
	local custom_item_colors_reason = mod:localize("option_requires_custom_item_name_and_colors")

	set_option_enabled(option_dependency_entries.enable_custom_item_name_and_colors, true)
	set_option_enabled(option_dependency_entries.custom_item_name_keybind, custom_item_colors_enabled, custom_item_colors_reason)
	set_option_enabled(option_dependency_entries.custom_item_name_color_keybind, custom_item_colors_enabled, custom_item_colors_reason)
	set_option_enabled(option_dependency_entries.custom_item_background_color_keybind, custom_item_colors_enabled, custom_item_colors_reason)
	set_option_enabled(option_dependency_entries.custom_item_skip_confirmation_prompts, custom_item_colors_enabled, custom_item_colors_reason)
	set_option_enabled(option_dependency_entries.custom_item_preserve_card_shading, custom_item_colors_enabled, custom_item_colors_reason)
	set_option_enabled(option_dependency_entries.custom_item_override_weapon_information_color, custom_item_colors_enabled, custom_item_colors_reason)
	set_option_enabled(option_dependency_entries.custom_item_override_weapon_rarity_keyword_color, custom_item_colors_enabled, custom_item_colors_reason)
	set_option_enabled(option_dependency_entries.custom_item_override_weapon_information_name_color, custom_item_colors_enabled, custom_item_colors_reason)

	for _, setting_id in ipairs({
		"curio_information_width_percent",
		"curio_preview_height_percent",
		"inventory_options_panel_width",
		"inventory_options_panel_max_height",
		"inventory_options_panel_row_spacing",
		"inventory_options_panel_padding_top",
		"inventory_options_panel_padding_bottom",
		"inventory_options_panel_padding_left",
		"inventory_options_panel_padding_right",
	}) do
		set_option_enabled(option_dependency_entries[setting_id], inventory_options_panel_enabled, inventory_options_panel_reason)
	end

	for _, setting_id in ipairs({
		"quick_discard_mode",
		"quick_discard_rarity",
		"quick_discard_max_item_level",
		"quick_discard_protect_above_equipped_level",
		"quick_discard_include_melee",
		"quick_discard_include_ranged",
		"quick_discard_include_curios",
		"quick_discard_protect_perfect_weapons",
		"quick_discard_protect_high_level_curios",
		"quick_discard_keep_health_curios",
		"quick_discard_keep_toughness_curios",
		"quick_discard_keep_wound_curios",
		"quick_discard_keep_stamina_curios",
		"quick_discard_show_type_breakdown",
		"quick_discard_show_summary_notification",
	}) do
		set_option_enabled(option_dependency_entries[setting_id], quick_discard_enabled, quick_discard_reason)
	end

	local automatic_discard_enabled = quick_discard_enabled and mod:get("quick_discard_mode") == "automatic"
	local automatic_discard_reason = quick_discard_enabled and mod:localize("option_requires_automatic_discard_mode") or quick_discard_reason

	set_option_enabled(option_dependency_entries.quick_discard_skip_automatic_confirmation, automatic_discard_enabled, automatic_discard_reason)
	set_option_enabled(option_dependency_entries.quick_discard_disable_no_eligible_notification, automatic_discard_enabled, automatic_discard_reason)

	local curio_protection_enabled = quick_discard_enabled and mod:get("quick_discard_protect_high_level_curios") ~= false

	set_option_enabled(option_dependency_entries.quick_discard_curio_protection_level, curio_protection_enabled, quick_discard_enabled and mod:localize("option_requires_curio_discard_protection") or quick_discard_reason)

	for _, setting_id in ipairs({
		"automatic_curio_min_item_level",
		"automatic_curio_min_health",
		"automatic_curio_min_toughness",
		"automatic_curio_diagnostic_logging",
		"automatic_curio_disable_no_eligible_notification",
		"automatic_curio_target_mode",
		"automatic_curio_buy_health",
		"automatic_curio_buy_toughness",
		"automatic_curio_buy_stamina",
		"automatic_curio_buy_wounds",
	}) do
		set_option_enabled(option_dependency_entries[setting_id], automatic_curio_enabled, automatic_curio_reason)
	end

	set_option_enabled(option_dependency_entries.automatic_curio_classes_group, automatic_curio_classes_enabled, automatic_curio_classes_reason)
	set_option_enabled(option_dependency_entries.automatic_curio_characters_group, automatic_curio_characters_enabled, automatic_curio_characters_reason)

	for _, setting_id in ipairs({
		"automatic_curio_class_veteran",
		"automatic_curio_class_zealot",
		"automatic_curio_class_psyker",
		"automatic_curio_class_ogryn",
		"automatic_curio_class_adamant",
		"automatic_curio_class_broker",
		"automatic_curio_class_cryptic",
	}) do
		set_option_enabled(option_dependency_entries[setting_id], automatic_curio_classes_enabled, automatic_curio_classes_reason)
	end

	for _, entry in ipairs(option_dependency_entries.automatic_curio_character_entries or {}) do
		local slot_available = entry._better_inventory_curio_character_available == true
		local slot_reason = slot_available and automatic_curio_characters_reason or mod:localize("automatic_curio_character_slot_empty_reason")

		set_option_enabled(entry, automatic_curio_characters_enabled and slot_available, slot_reason)
	end

	local automatic_health_enabled = automatic_curio_enabled and mod:get("automatic_curio_buy_health") ~= false
	local automatic_toughness_enabled = automatic_curio_enabled and mod:get("automatic_curio_buy_toughness") ~= false

	set_option_enabled(option_dependency_entries.automatic_curio_min_health, automatic_health_enabled, automatic_curio_enabled and mod:localize("option_requires_automatic_curio_health") or automatic_curio_reason)
	set_option_enabled(option_dependency_entries.automatic_curio_min_toughness, automatic_toughness_enabled, automatic_curio_enabled and mod:localize("option_requires_automatic_curio_toughness") or automatic_curio_reason)
end

local function bind_option_dependencies(options_templates)
	local settings = options_templates and options_templates.settings

	if type(settings) ~= "table" then
		return
	end

	local category_name = mod:get_readable_name()
	local setting_by_title = {}
	local curio_buyer_subsection_titles = {
		[mod:localize("automatic_curio_types_group")] = true,
		[mod:localize("automatic_curio_classes_group")] = true,
		[mod:localize("automatic_curio_characters_group")] = true,
	}
	local class_group_title = mod:localize("automatic_curio_classes_group")
	local character_group_title = mod:localize("automatic_curio_characters_group")
	local class_group_entry
	local character_group_entry

	for _, setting_id in ipairs({
		"melee_columns",
		"ranged_columns",
		"curio_columns",
		"three_column_weapon_name_font_size",
		"expand_inventory_window",
		"weapon_extra_width_column_threshold",
		"five_column_weapon_extra_width",
		"grid_spacing",
		"automatic_card_height",
		"card_height",
		"expand_curio_inventory_window",
		"curio_target_card_width",
		"enable_hadron_entreat_grid",
		"enable_hadron_single_column_mirror",
		"enable_armoury_requisition_grid",
		"enable_armoury_single_column_mirror",
		"enable_armoury_requisition_sorting_panel",
		"brighten_armoury_item_levels",
		"expand_armoury_requisition_window",
		"armoury_requisition_target_card_width",
		"enable_global_store_integration",
		"enable_global_store_grid",
		"enable_global_store_sorting_panel",
		"global_store_character_photo_size_percent",
		"global_store_price_row_padding",
		"global_store_character_info_gap",
		"global_store_character_class_icon_size",
		"global_store_character_name_font_size",
		"global_store_compact_character_names",
		"global_store_single_column_modifier_horizontal_position",
		"global_store_single_column_modifier_vertical_position",
		"character_overview_curio_name_mode",
		"character_overview_curio_font_size_percent",
		"weapon_perk_compression",
		"show_weapon_perk_rank_symbols",
		"weapon_perk_rank_icon_size",
		"remove_weapon_perk_plus_signs",
		"weapon_perk_text_color_preset",
		"weapon_perk_text_color_r",
		"weapon_perk_text_color_g",
		"weapon_perk_text_color_b",
		"weapon_perk_text_opacity",
		"weapon_perk_vertical_spacing",
		"blessing_text_item_level_separation",
		"auto_fit_long_blessing_names",
		"truncate_long_blessing_names",
		"weapon_blessing_text_color_preset",
		"weapon_blessing_text_color_r",
		"weapon_blessing_text_color_g",
		"weapon_blessing_text_color_b",
		"weapon_blessing_text_opacity",
		"weapon_blessing_text_vertical_spacing",
		"weapon_blessing_text_bottom_padding",
		"blessing_icon_size",
		"blessing_icon_spacing",
		"weapon_perk_blessing_spacing",
		"curio_secondary_stat_font_size",
		"curio_primary_secondary_spacing",
		"single_column_layout_group",
		"single_column_weapon_name_font_size",
		"single_column_blessing_icons_on_right",
		"quick_look_card_single_column_font_size",
		"quick_look_card_single_column_label_value_gap",
		"quick_look_card_single_column_horizontal_position",
		"quick_look_card_single_column_vertical_position",
		"quick_look_card_grid_stat_position",
		"quick_look_card_grid_font_size",
		"quick_look_card_grid_bottom_padding",
		"weapon_modifier_lowest_color_preset",
		"weapon_modifier_lowest_color_r",
		"weapon_modifier_lowest_color_g",
		"weapon_modifier_lowest_color_b",
		"weapon_modifier_lowest_color_opacity",
		"name_it_force_curio_name_in_detailed_mode",
		"curio_content_name_it_curio_name",
		"enable_custom_item_name_and_colors",
		"custom_item_name_keybind",
		"custom_item_name_color_keybind",
		"custom_item_background_color_keybind",
		"custom_item_skip_confirmation_prompts",
		"custom_item_preserve_card_shading",
		"custom_item_override_weapon_information_color",
		"custom_item_override_weapon_rarity_keyword_color",
		"custom_item_override_weapon_information_name_color",
		"curio_information_width_percent",
		"curio_preview_height_percent",
		"inventory_options_panel_width",
		"inventory_options_panel_max_height",
		"inventory_options_panel_row_spacing",
		"inventory_options_panel_padding_top",
		"inventory_options_panel_padding_bottom",
		"inventory_options_panel_padding_left",
		"inventory_options_panel_padding_right",
		"quick_discard_mode",
		"quick_discard_skip_automatic_confirmation",
		"quick_discard_rarity",
		"quick_discard_max_item_level",
		"quick_discard_protect_above_equipped_level",
		"quick_discard_include_melee",
		"quick_discard_include_ranged",
		"quick_discard_include_curios",
		"quick_discard_protect_perfect_weapons",
		"quick_discard_protect_high_level_curios",
		"quick_discard_curio_protection_level",
		"quick_discard_keep_health_curios",
		"quick_discard_keep_toughness_curios",
		"quick_discard_keep_wound_curios",
		"quick_discard_keep_stamina_curios",
		"quick_discard_show_type_breakdown",
		"quick_discard_show_summary_notification",
		"quick_discard_disable_no_eligible_notification",
		"automatic_curio_min_item_level",
		"automatic_curio_min_health",
		"automatic_curio_min_toughness",
		"automatic_curio_diagnostic_logging",
		"automatic_curio_disable_no_eligible_notification",
		"automatic_curio_target_mode",
		"automatic_curio_buy_health",
		"automatic_curio_buy_toughness",
		"automatic_curio_buy_stamina",
		"automatic_curio_buy_wounds",
		"automatic_curio_class_veteran",
		"automatic_curio_class_zealot",
		"automatic_curio_class_psyker",
		"automatic_curio_class_ogryn",
		"automatic_curio_class_adamant",
		"automatic_curio_class_broker",
		"automatic_curio_class_cryptic",
	}) do
		local title = mod:localize(setting_id)
		local existing = setting_by_title[title]

		if existing == nil then
			setting_by_title[title] = setting_id
		elseif type(existing) == "table" then
			existing[#existing + 1] = setting_id
		else
			setting_by_title[title] = {
				existing,
				setting_id,
			}
		end
	end

	option_dependency_entries = {
		automatic_curio_character_entries = {},
	}

	for i = 1, #settings do
		local entry = settings[i]

		-- DMF preserves indentation for ordinary nested controls but drops it from
		-- nested group-header templates. Restore the two buyer subheadings to the
		-- same depth as their schema nodes so they do not look like peer sections.
		if type(entry) == "table" and entry.category == category_name and entry.widget_type == "group_header" and curio_buyer_subsection_titles[entry.display_name] then
			entry.indentation_level = 2

			if entry.display_name == class_group_title then
				class_group_entry = entry
			elseif entry.display_name == character_group_title then
				character_group_entry = entry
			end
		end

		local setting_id = type(entry) == "table" and entry.category == category_name and setting_by_title[entry.display_name]

		if type(setting_id) == "table" then
			-- Two view-local controls intentionally share the same label. Consume
			-- duplicate titles in schema order so both dependency entries bind
			-- correctly instead of the later one overwriting the earlier one.
			setting_id = table.remove(setting_id, 1)
		end

		if setting_id then
			option_dependency_entries[setting_id] = entry
		elseif type(entry) == "table" and entry._better_inventory_curio_character_slot_index then
			option_dependency_entries.automatic_curio_character_entries[#option_dependency_entries.automatic_curio_character_entries + 1] = entry
		end
	end

	-- Keep the final DMF template and rendered-widget arrays structurally
	-- identical. Alf's generalized tabs pair them by numeric index, so hiding
	-- mode-dependent entries through validation functions shifts every later
	-- section. PlayerAssist uses the stable pattern too: keep entries present and
	-- express dependencies exclusively through disabled state.
	option_dependency_entries.automatic_curio_classes_group = class_group_entry
	option_dependency_entries.automatic_curio_characters_group = character_group_entry

	refresh_option_dependencies()
end

local function migrate_grid_column_settings()
	if mod:get("_grid_columns_v1_migrated") then
		return
	end

	local legacy_columns = tonumber(mod:get("columns"))
	local dedicated_setting_ids = {
		"melee_columns",
		"ranged_columns",
		"curio_columns",
	}

	if legacy_columns then
		legacy_columns = math.max(2, math.min(5, math.floor(legacy_columns)))
		local has_dedicated_customization = false

		for _, setting_id in ipairs(dedicated_setting_ids) do
			local configured_columns = tonumber(mod:get(setting_id))

			if configured_columns and configured_columns ~= 3 then
				has_dedicated_customization = true

				break
			end
		end

		-- A legacy profile has no way to express per-category values. Preserve
		-- its old global choice only when all three new controls still have their
		-- defaults; once any slider is customized, leave every dedicated value
		-- untouched.
		if not has_dedicated_customization then
			for _, setting_id in ipairs(dedicated_setting_ids) do
				mod:set(setting_id, legacy_columns, false)
			end
		end
	end

	mod:set("_grid_columns_v1_migrated", true, false)
end

function mod.on_enabled()
	ItemCustomization.on_enabled(mod)

	-- DMF requires unique setting IDs. Keep Curio content's mirror row aligned
	-- with the established Name It setting, which remains authoritative across
	-- upgrades and preserves the user's existing choice.
	local name_it_curio_name_value = mod:get("name_it_force_curio_name_in_detailed_mode")

	if name_it_curio_name_value == nil then
		name_it_curio_name_value = true
	end

	if mod:get("curio_content_name_it_curio_name") ~= name_it_curio_name_value then
		mod:set("curio_content_name_it_curio_name", name_it_curio_name_value, false)
	end

	-- DMF preserves saved values when a default changes. Apply the new compact
	-- card defaults once for installs that already initialized the old values;
	-- all three settings remain freely configurable afterward.
	if not mod:get("_compact_card_defaults_v1_migrated") then
		mod:set("append_mark_to_name", true)
		mod:set("show_pattern_mark", false)
		mod:set("show_rarity_name", false)
		mod:set("_compact_card_defaults_v1_migrated", true)
	end

	migrate_grid_column_settings()

	-- Replace the unreleased Curio-name checkboxes with one mode selector while
	-- preserving the currently enabled one-line presentation for test profiles.
	if not mod:get("_character_overview_curio_name_mode_v1_migrated") then
		if mod:get("character_overview_show_curio_names") == true then
			mod:set("character_overview_curio_name_mode", "one_line")
		end

		mod:set("_character_overview_curio_name_mode_v1_migrated", true)
	end

	if not mod:get("_curio_compression_mode_v1_migrated") then
		local previous_compact_setting = mod:get("compact_curio_stat_text")

		if previous_compact_setting == false then
			mod:set("curio_stat_compression", "none")
		elseif previous_compact_setting == true then
			mod:set("curio_stat_compression", "compression")
		end

		mod:set("_curio_compression_mode_v1_migrated", true)
	end

	-- Heavy Compression supersedes Compression as the default. Preserve an
	-- explicit No compression choice while upgrading the former default once.
	if not mod:get("_curio_heavy_default_v1_migrated") then
		local compression_mode = mod:get("curio_stat_compression")

		if compression_mode == nil or compression_mode == "compression" then
			mod:set("curio_stat_compression", "heavy")
		end

		mod:set("_curio_heavy_default_v1_migrated", true)
	end

	-- Move only the former defaults so deliberately customized icon sizes stay
	-- untouched on existing installations.
	if not mod:get("_inventory_icon_size_defaults_v2_migrated") then
		local blessing_size = mod:get("blessing_icon_size")
		local perk_rank_size = mod:get("weapon_perk_rank_icon_size")

		if blessing_size == nil or blessing_size == 34 then
			mod:set("blessing_icon_size", 36)
		end

		if perk_rank_size == nil or perk_rank_size == 18 then
			mod:set("weapon_perk_rank_icon_size", 17)
		end

		mod:set("_inventory_icon_size_defaults_v2_migrated", true)
	end

	-- Replace the former blessing checkbox with a configurable display mode while
	-- preserving an explicit disabled choice from existing installations.
	if not mod:get("_weapon_blessing_display_mode_v1_migrated") then
		local previous_show_blessings = mod:get("show_weapon_blessings")

		if previous_show_blessings ~= nil then
			mod:set("weapon_blessing_display_mode", previous_show_blessings == false and "off" or "icons")
		end

		mod:set("_weapon_blessing_display_mode_v1_migrated", true)
	end

	for i = 1, #COLOR_TARGETS do
		apply_color_preset(COLOR_TARGETS[i])
	end

	-- The character rows themselves are part of the static DMF schema. Refresh
	-- their saved operative labels and backend-ID selection bindings before the
	-- user can open Mod Options; live discovery will refresh them again.
	if type(CurioAcquisition.refresh_character_options) == "function" then
		CurioAcquisition.refresh_character_options(mod)
	end

	-- Arm discovery independently of GameplayStateRun event ordering. On a true
	-- first install there is no persisted roster, so the pending request waits
	-- harmlessly until the player reaches the Morningstar and then replaces the
	-- static Character N labels without requiring a reload.
	if type(CurioAcquisition.request_profile_discovery) == "function" then
		CurioAcquisition.request_profile_discovery(true)
	end

	refresh_option_dependencies()
end

function mod.on_all_mods_loaded()
	ItemCustomization.on_all_mods_loaded(mod)
end

function mod.on_setting_changed(setting_id)
	local color_change = color_target_by_setting_id[setting_id]
	local automatic_curio_setting = type(setting_id) == "string" and string.sub(setting_id, 1, 16) == "automatic_curio_"

	ItemCustomization.on_setting_changed(mod, setting_id)

	if setting_id == "name_it_force_curio_name_in_detailed_mode" then
		mod:set("curio_content_name_it_curio_name", mod:get(setting_id), false)
	elseif setting_id == "curio_content_name_it_curio_name" then
		mod:set("name_it_force_curio_name_in_detailed_mode", mod:get(setting_id), false)
	end

	if color_change then
		if color_change.is_preset then
			apply_color_preset(color_change.target)
		else
			mod:set(color_change.target.preset_id, "custom", false)
		end
	end

	if setting_id == "enable_grid_layout" or setting_id == "melee_columns" or setting_id == "ranged_columns" or setting_id == "curio_columns" or setting_id == "automatic_card_height" or setting_id == "expand_inventory_window" or setting_id == "weapon_extra_width_column_threshold" or setting_id == "expand_curio_inventory_window" or setting_id == "enable_hadron_single_column_mirror" or setting_id == "enable_armoury_requisition_grid" or setting_id == "enable_armoury_single_column_mirror" or setting_id == "enable_armoury_requisition_sorting_panel" or setting_id == "brighten_armoury_item_levels" or setting_id == "three_column_weapon_name_font_size" or setting_id == "expand_armoury_requisition_window" or setting_id == "enable_global_store_integration" or setting_id == "enable_global_store_grid" or setting_id == "enable_global_store_sorting_panel" or setting_id == "global_store_character_photo_size_percent" or setting_id == "global_store_price_row_padding" or setting_id == "global_store_character_info_gap" or setting_id == "global_store_character_class_icon_size" or setting_id == "global_store_character_name_font_size" or setting_id == "global_store_compact_character_names" or setting_id == "global_store_single_column_modifier_horizontal_position" or setting_id == "global_store_single_column_modifier_vertical_position" or setting_id == "enable_character_overview_melee_mirror" or setting_id == "enable_character_overview_ranged_mirror" or setting_id == "enable_character_overview_curio_details" or setting_id == "character_overview_curio_name_mode" or setting_id == "weapon_blessing_display_mode" or setting_id == "show_weapon_perks" or setting_id == "show_weapon_perk_rank_symbols" or setting_id == "single_column_blessing_icons_on_right" or setting_id == "curio_display_profile" or setting_id == "enable_inventory_options_panel_prototype" or setting_id == "enable_experimental_quick_discard" or setting_id == "quick_discard_mode" or setting_id == "quick_discard_protect_high_level_curios" or setting_id == "enable_automatic_curio_acquisition" or automatic_curio_setting or setting_id == "enable_quick_look_card_single_column_integration" or setting_id == "enable_quick_look_card_grid_integration" or setting_id == "quick_look_card_grid_stat_position" or setting_id == "enable_custom_item_name_and_colors" then
		refresh_option_dependencies()
	end

	if setting_id == "prioritize_equipped_favorites" or setting_id == "prioritize_perfect_roll_weapons" then
		Features.sync_inventory_sort_setting(mod, Layout)
	end

	if type(setting_id) == "string" and string.sub(setting_id, 1, 14) == "quick_discard_" then
		Features.sync_quick_discard_settings(mod, Layout)
	end

	if setting_id == "enable_automatic_curio_acquisition" or automatic_curio_setting then
		CurioAcquisition.on_setting_changed(mod, setting_id)
		Features.sync_curio_acquisition_settings(mod, Layout)
	end
end

function mod.on_game_state_changed(status, state_name)
	if state_name ~= "GameplayStateRun" then
		return
	end

	if status == "enter" then
		Features.begin_morningstar_auto_discard(mod)
		CurioAcquisition.begin_morningstar_pass(mod)
	elseif status == "exit" then
		Features.cancel_morningstar_auto_discard()
		CurioAcquisition.cancel()
	end
end

function mod.update(dt)
	ItemCustomization.update_runtime(mod, dt)
	Features.update_morningstar_auto_discard(mod, dt)
	CurioAcquisition.update(mod, dt, Features.morningstar_auto_discard_is_busy(mod))
end

function mod.on_disabled()
	ItemCustomization.on_disabled(mod)
	Features.cancel_morningstar_auto_discard()
	CurioAcquisition.cancel()
	Features.disable_inventory_views()
end

local dmf_mod = get_mod("DMF")

if dmf_mod and type(dmf_mod.create_mod_options_settings) == "function" then
	mod:hook_safe(dmf_mod, "create_mod_options_settings", function(_, options_templates)
		if type(CurioAcquisition.inject_character_options) == "function" then
			CurioAcquisition.inject_character_options(mod, options_templates)
		end

		bind_option_dependencies(options_templates)
	end)
end

mod:hook(ItemGridViewBase, "init", function(func, view, definitions, settings, context)
	if view.__class_name == "InventoryWeaponsView" then
		local adjusted_definitions = Features.add_inventory_sort_toggle_definition(mod, Layout, definitions, view)
		local expansion = 0

		if Layout.is_enabled_for_view(mod, view) then
			adjusted_definitions, expansion = Layout.expanded_view_definitions(mod, adjusted_definitions, view)
		end

		view._better_inventory_grid_expansion = expansion

		return func(view, adjusted_definitions, settings, context)
	end

	if is_armoury_requisition_view(view) and mod:get("enable_grid_layout") ~= false and mod:get("enable_armoury_requisition_grid") ~= false then
		local slot_kind = Layout.store_slot_kind and Layout.store_slot_kind(view)
		local adjusted_definitions, expansion = Layout.expanded_armoury_view_definitions(mod, definitions, ItemGridViewBaseDefinitions, nil, slot_kind)

		view._better_inventory_armoury_grid_expansion = expansion

		return func(view, adjusted_definitions, settings, context)
	end

	if is_global_store_view(view) and mod:get("enable_grid_layout") ~= false and mod:get("enable_global_store_integration") ~= false and mod:get("enable_global_store_grid") ~= false then
		local slot_kind = Layout.store_slot_kind and Layout.store_slot_kind(view)
		local adjusted_definitions, expansion

		if Layout.expanded_global_store_view_definitions then
			adjusted_definitions, expansion = Layout.expanded_global_store_view_definitions(mod, definitions, ItemGridViewBaseDefinitions, slot_kind)
		else
			adjusted_definitions, expansion = Layout.expanded_armoury_view_definitions(mod, definitions, ItemGridViewBaseDefinitions, "enable_global_store_grid", slot_kind)
		end

		view._better_inventory_armoury_grid_expansion = expansion

		return func(view, adjusted_definitions, settings, context)
	end

	return func(view, definitions, settings, context)
end)

if ensure_class_method(InventoryWeaponsView, "_setup_sort_options") then
	mod:hook(InventoryWeaponsView, "_setup_sort_options", function(func, view, ...)
		local result = func(view, ...)

		Features.configure_inventory_sort_options(mod, Layout, view)
		Features.setup_inventory_options_panel(mod, Layout, view, ViewElementGrid)
		Features.bind_inventory_sort_toggle(mod, Layout, view)

		return result
	end)
end

if ensure_class_method(CreditsVendorView, "_setup_sort_options") then
	mod:hook(CreditsVendorView, "_setup_sort_options", function(func, view, ...)
		local result = func(view, ...)

		if is_armoury_requisition_view(view) then
			Features.configure_armoury_sort_options(mod, view)

			if mod:get("enable_armoury_requisition_grid") ~= false and mod:get("enable_armoury_requisition_sorting_panel") ~= false then
				Features.setup_armoury_native_sort_panel(mod, Layout, view, ViewElementGrid)
			end
		elseif is_global_store_view(view) and mod:get("enable_global_store_integration") ~= false then
			Features.configure_global_store_sort_options(mod, view)

			if mod:get("enable_global_store_grid") ~= false and mod:get("enable_global_store_sorting_panel") ~= false then
				Features.setup_armoury_native_sort_panel(mod, Layout, view, ViewElementGrid)
			end
		end

		return result
	end)
end

mod:hook_safe(InventoryWeaponsView, "cb_on_favorite_pressed", function(view)
	if mod:get("prioritize_equipped_favorites") ~= false then
		Features.resort_inventory(mod, Layout, view)
	end
end)

mod:hook_safe(InventoryWeaponsView, "_equip_item", function(view)
	if mod:get("prioritize_equipped_favorites") ~= false then
		Features.resort_inventory(mod, Layout, view)
	end
end)

mod:hook_safe(InventoryWeaponsView, "update", function(view)
	Features.update_inventory_sort_toggle(mod, Layout, view)
end)

mod:hook_safe(InventoryWeaponsView, "on_exit", function(view)
	Features.unregister_inventory_view(view)
end)

if ensure_class_method(CreditsVendorView, "update") then
	mod:hook_safe(CreditsVendorView, "update", function(view)
		if is_armoury_sort_view(view) then
			Features.update_armoury_native_sort_panel(view)
		end
	end)
end

if ensure_class_method(CreditsVendorView, "on_exit") then
	mod:hook_safe(CreditsVendorView, "on_exit", function(view)
		Features.unregister_armoury_view(view)
	end)
end

mod:hook(InventoryWeaponsView, "_setup_item_grid_materials", function(func, view, ...)
	func(view, ...)

	local expansion = view._better_inventory_grid_expansion or 0

	if expansion <= 0 then
		return
	end

	for _, widget_name in ipairs({
		"grid_divider_top",
		"grid_divider_bottom",
	}) do
		local widget = view:_grid_widget_by_name(widget_name)
		local texture_style = widget and widget.style and widget.style.texture
		local texture_size = texture_style and texture_style.size

		if texture_size and texture_size[1] then
			texture_size[1] = texture_size[1] + expansion
		end
	end
end)

local function present_grid_with_configuration(func, view, layout, on_present_callback, configuration)
	local previous_active_view = active_grid_view
	local previous_configuration = active_grid_configuration

	active_grid_view = view
	active_grid_configuration = configuration

	local results = pack_values(pcall(func, view, layout, on_present_callback))
	local success = results[1]
	local result_count = results.n

	active_grid_view = previous_active_view
	active_grid_configuration = previous_configuration

	if not success then
		error(results[2])
	end

	return unpack_values(results, 2, result_count)
end

if ensure_class_method(InventoryWeaponsView, "present_grid_layout") then
	mod:hook(InventoryWeaponsView, "present_grid_layout", function(func, view, layout, on_present_callback)
		if not Layout.is_enabled_for_view(mod, view) then
			return func(view, layout, on_present_callback)
		end

		-- Mark only this call, then continue through the complete DMF hook chain.
		-- The grid hook below transforms whichever blueprints reach the base view,
		-- including changes made by compatible sorting or information mods.
		local configuration = table.clone(INVENTORY_GRID_CONFIGURATION)
		configuration.slot_kind = Layout.slot_kind(view)

		return present_grid_with_configuration(func, view, layout, on_present_callback, configuration)
	end)
end

-- The character overview uses InventoryView's individual item-slot widgets
-- instead of ViewElementGrid. Swap only its primary/secondary weapon slots to
-- the detailed inventory card while retaining Darktide's native icon loading,
-- equipment refresh and click callbacks. The optional scenegraph ID is present
-- only for individual-layout widgets, so inventory grid tabs remain untouched.
if ensure_class_method(InventoryView, "_create_entry_widget_from_config") then
	mod:hook(InventoryView, "_create_entry_widget_from_config", function(func, view, config, suffix, callback_name, secondary_callback_name, optional_scenegraph_id)
		local weapon_kind = optional_scenegraph_id and character_overview_weapon_kind(config)
		local curio_slot = optional_scenegraph_id and character_overview_curio_slot(config)
		local setting_id = weapon_kind == "melee" and "enable_character_overview_melee_mirror" or weapon_kind == "ranged" and "enable_character_overview_ranged_mirror" or curio_slot and "enable_character_overview_curio_details"
		-- Visible Equipment 1.32 injects primary/secondary placement entries that
		-- deliberately reuse slot_primary/slot_secondary. Preserve its dedicated
		-- widget type when compatibility is enabled so our ordinary weapon-slot
		-- detection cannot replace it. Native Loadout entries remain eligible for
		-- BetterInventory's detailed cards; this guard targets Cosmetics placements.
		local visible_equipment_placement = config and config.widget_type == "gear_placement_slot"
		local visible_equipment_mod = visible_equipment_placement and get_mod("visible_equipment")
		local visible_equipment_active = visible_equipment_mod and (type(visible_equipment_mod.is_enabled) ~= "function" or visible_equipment_mod:is_enabled())
		local preserve_visible_equipment_placement = visible_equipment_active

		if view and view.__class_name == "InventoryView" and not preserve_visible_equipment_placement and setting_id and mod:get(setting_id) ~= false then
			local equipped_item = view.equipped_item_in_slot and view:equipped_item_in_slot(config.slot.name)
			local empty_curio_slot = curio_slot and equipped_item == nil
			local blueprint = empty_curio_slot and character_overview_empty_curio_blueprint() or curio_slot and character_overview_curio_blueprint() or character_overview_weapon_blueprint()
			local widget_type = empty_curio_slot and CHARACTER_OVERVIEW_EMPTY_CURIO_WIDGET_TYPE or curio_slot and CHARACTER_OVERVIEW_CURIO_WIDGET_TYPE or CHARACTER_OVERVIEW_WEAPON_WIDGET_TYPE

			if blueprint then
				InventoryViewContentBlueprints[widget_type] = blueprint

				local adapted_config = table.clone(config)
				adapted_config.widget_type = widget_type
				adapted_config.item = equipped_item

				return func(view, adapted_config, suffix, callback_name, secondary_callback_name, optional_scenegraph_id)
			end
		end

		return func(view, config, suffix, callback_name, secondary_callback_name, optional_scenegraph_id)
	end)
end

local function present_additional_grid(func, view, layout, on_present_callback, setting_id, configuration)
	if mod:get("enable_grid_layout") == false or mod:get(setting_id) == false then
		return func(view, layout, on_present_callback)
	end

	local active_configuration = table.clone(configuration)

	if Layout.store_slot_kind then
		-- Hadron, Armoury and GlobalStore expose the same native category tabs.
		-- Their cards honor the matching category slider, while each vendor
		-- configuration's maximum_columns keeps non-inventory views capped at
		-- three.
		active_configuration.slot_kind = Layout.store_slot_kind(view, layout)
	end

	return present_grid_with_configuration(func, view, layout, on_present_callback, active_configuration)
end

-- "Entreat Hadron" opens this modern ItemGridViewBase subclass. The separate
-- sacrifice flow uses CraftingMechanicusBarterItemsView and is intentionally
-- outside this hook.
if ensure_class_method(CraftingMechanicusModifyView, "present_grid_layout") then
	mod:hook(CraftingMechanicusModifyView, "present_grid_layout", function(func, view, layout, on_present_callback)
		return present_additional_grid(func, view, layout, on_present_callback, "enable_hadron_entreat_grid", HADRON_GRID_CONFIGURATION)
	end)
end

-- The Armoury landing page maps "Requisition Weapons & Curios" and GlobalStore's
-- Multi-Operative Supply to CreditsVendorView service routes. CreditsGoodsVendorView
-- (Brunt's Armoury) is deliberately not hooked by these settings.
if ensure_class_method(CreditsVendorView, "present_grid_layout") then
	mod:hook(CreditsVendorView, "present_grid_layout", function(func, view, layout, on_present_callback)
		if is_global_store_view(view) and mod:get("enable_global_store_integration") ~= false then
			return present_additional_grid(func, view, layout, on_present_callback, "enable_global_store_grid", GLOBAL_STORE_GRID_CONFIGURATION)
		end

		if not is_armoury_requisition_view(view) then
			return func(view, layout, on_present_callback)
		end

		return present_additional_grid(func, view, layout, on_present_callback, "enable_armoury_requisition_grid", ARMOURY_GRID_CONFIGURATION)
	end)
end

mod:hook(CreditsVendorView, "on_enter", function(func, view, ...)
	local result = func(view, ...)

	if not is_armoury_sort_view(view) then
		return result
	end

	local expansion = view._better_inventory_armoury_grid_expansion or 0
	local item_grid = view._item_grid

	if expansion > 0 and item_grid and type(item_grid.update_dividers) == "function" then
		item_grid:update_dividers("content/ui/materials/frames/item_list_top_hollow", {
			652 + expansion,
			118,
		}, {
			0,
			-18,
			20,
		}, "content/ui/materials/frames/details_lower_armoury", {
			674 + expansion,
			80,
		}, {
			0,
			0,
			20,
		})
	end

	return result
end)

local function normalize_global_store_widgets(item_grid)
	for _, entry_data in pairs(item_grid and item_grid._widgets_by_entry_id or {}) do
		local widget = entry_data and entry_data.widget
		local portrait = widget and widget.style and widget.style.portrait

		if portrait then
			-- GlobalStore's callback expands the portrait for its native full-width
			-- cards. Keep it at the configured size after BetterInventory remaps
			-- the card into a compact grid.
			local portrait_size = 34

			if Layout.global_store_character_photo_size then
				portrait_size = Layout.global_store_character_photo_size(mod)
			end

			portrait.size = {
				portrait_size,
				portrait_size,
			}
		end

		local content = widget and widget.content
		local character_info = widget and widget.style and widget.style.character_info_text
		local class_icon = widget and widget.style and widget.style.character_class_icon_text

		if content and character_info and class_icon then
			-- GlobalStore supplies one combined string (class glyph + name). Split
			-- it once so BetterInventory can size the glyph and name independently.
			-- Keep the parsed name as a marker so repeated normalization does not
			-- strip the first word from an already-split character name.
			local raw_info = content.character_info_text
			local parsed_name = content.better_inventory_global_store_character_name

			if type(raw_info) == "string" and raw_info ~= "" and raw_info ~= parsed_name then
				local icon_text, name_text = string.match(raw_info, "^(%S+)%s+(.+)$")

				if icon_text and name_text then
					name_text = string.match(name_text, "^%s*(.-)%s*$") or name_text
					content.character_class_icon_text = icon_text
					content.character_info_text = name_text
					content.better_inventory_global_store_character_name = name_text
				end
			end
		end
	end
end

-- MyFavorites attaches its input hotspot to grid item widgets. Blueprint styles
-- are cloned during widget construction, so retain the actual runtime hotspot
-- style on shared content. configure_favorite_marker's working favorite-icon
-- callback then moves both the visible icon and its click target together.
if ensure_class_method(ViewElementGrid, "_create_entry_widget_from_config") then
	mod:hook(ViewElementGrid, "_create_entry_widget_from_config", function(func, item_grid, config, suffix, callback_name, secondary_callback_name, double_click_callback_name)
		local widget, alignment_widget = func(item_grid, config, suffix, callback_name, secondary_callback_name, double_click_callback_name)

		if widget and widget.content and widget.style and widget.style.myfav_hotspot then
			widget.content.better_inventory_myfavorites_hotspot_style = widget.style.myfav_hotspot

			for index = 1, #(widget.passes or {}) do
				local pass = widget.passes[index]

				if pass.style_id == "equipped_icon" then
					widget.content.better_inventory_equipped_icon_visibility_function = pass.visibility_function

					break
				end
			end
		end

		return widget, alignment_widget
	end)
end

local function synchronize_myfavorites_marker(widget)
	local content = widget and widget.content
	local styles = widget and widget.style
	local hotspot_style = content and content.better_inventory_myfavorites_hotspot_style
	local favorite_style = styles and styles.favorite_icon

	if not hotspot_style or not hotspot_style.offset or hotspot_style.horizontal_alignment ~= "right" or hotspot_style.vertical_alignment ~= "top" then
		return
	end

	local equipped_visible = content.equipped == true
	local visibility_function = content.better_inventory_equipped_icon_visibility_function

	if not equipped_visible and type(visibility_function) == "function" then
		local ok, visible = pcall(visibility_function, content, styles and styles.equipped_icon)

		equipped_visible = ok and visible == true
	end

	local offset_y = equipped_visible and 33 or 7

	hotspot_style.offset[2] = offset_y

	if favorite_style and favorite_style.offset then
		favorite_style.offset[2] = offset_y
	end
end

-- Synchronize independently of favorite_icon visibility. This is required for
-- unfavorited items: equipping, unequipping, or adding/removing them from an
-- inactive loadout can move Equipped Icon+'s marker while the favorite text
-- pass is hidden. The input hotspot must still be ready at the correct place.
if ensure_class_method(ViewElementGrid, "_update_grid_widgets") then
	mod:hook(ViewElementGrid, "_update_grid_widgets", function(func, item_grid, ...)
		local results = pack_values(func(item_grid, ...))
		local widgets = item_grid and item_grid._grid_widgets

		for index = 1, #(widgets or {}) do
			synchronize_myfavorites_marker(widgets[index])
		end

		return unpack_values(results, 1, results.n)
	end)
end

mod:hook(ViewElementGrid, "present_grid_layout", function(func, item_grid, layout, content_blueprints, ...)
	content_blueprints = Features.compact_inventory_curio_stats_blueprints(mod, item_grid, content_blueprints)

	local view = active_grid_view or item_grid and item_grid._parent
	local configuration = active_grid_configuration

	if not configuration and is_global_store_view(view) and mod:get("enable_global_store_integration") ~= false then
		configuration = mod:get("enable_grid_layout") ~= false and mod:get("enable_global_store_grid") ~= false and table.clone(GLOBAL_STORE_GRID_CONFIGURATION) or GLOBAL_STORE_NATIVE_CONFIGURATION

		if configuration.store_item and Layout.store_slot_kind then
			configuration.slot_kind = Layout.store_slot_kind(view, layout)
		end
	end

	-- When the global grid is disabled, the Hadron and Requisition routes keep
	-- their native one-column geometry. Opt-in mirror settings reuse the exact
	-- detailed single-column blueprint used by inventory instead of the compact
	-- native card. This fallback runs only for those two views and never changes
	-- inventory, GlobalStore, or any multi-column configuration.
	if not configuration and mod:get("enable_grid_layout") == false then
		if is_hadron_view(view) and mod:get("enable_hadron_single_column_mirror") ~= false then
			configuration = {
				blueprint_key = "item",
				native_single_column = true,
			}
		elseif is_armoury_requisition_view(view) and mod:get("enable_armoury_single_column_mirror") ~= false then
			configuration = {
				blueprint_key = "store_item",
				native_single_column = true,
				store_item = true,
			}
		end
	end

	local definitions = view and view._definitions
	local grid_settings = definitions and definitions.grid_settings
	local grid_size = grid_settings and grid_settings.grid_size
	local blueprint_key = configuration and configuration.blueprint_key
	local item_blueprint = blueprint_key and content_blueprints and content_blueprints[blueprint_key]

	-- Restrict the global grid seam to the exact active view and blueprint.
	-- Missing fields mean the game contract changed, so pass through.
	if not view or item_grid ~= view._item_grid or not grid_size or not grid_size[1] or not item_blueprint or not item_blueprint.pass_template then
		return func(item_grid, layout, content_blueprints, ...)
	end

	local local_blueprints = shallow_copy(content_blueprints)
	local local_item_blueprint = table.clone(item_blueprint)
	local callback_arguments = pack_values(...)

	local_blueprints[blueprint_key] = local_item_blueprint

	Layout.configure_item_blueprint(mod, local_item_blueprint, grid_size[1], configuration)
	Layout.configure_grid(mod, item_grid)

	if configuration.global_store and type(callback_arguments[5]) == "function" then
		local on_present_callback = callback_arguments[5]

		callback_arguments[5] = function(...)
			local callback_results = pack_values(on_present_callback(...))

			-- GlobalStore's callback resizes portraits after the grid callback
			-- runs. Normalize again afterward so entry and tab changes use the
			-- same configured size as the initial presentation.
			normalize_global_store_widgets(item_grid)

			return unpack_values(callback_results, 1, callback_results.n)
		end
	end

	local results = pack_values(func(item_grid, layout, local_blueprints, unpack_values(callback_arguments, 1, callback_arguments.n)))

	if configuration.global_store then
		normalize_global_store_widgets(item_grid)
	end

	return unpack_values(results, 1, results.n)
end)
