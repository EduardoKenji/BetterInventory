local OverviewUI = {}
local unpack_values = table.unpack or unpack

local mod
local Layout
local CharacterOverview
local FeatureDomains
local Diagnostics
local InventoryView
local InventoryViewContentBlueprints
local ItemBlueprintGenerator
local Text
local lantern_recommendations_active = function() return false end
local ensure_class_method
local better_inventory_test
local registered_character_overview_views = setmetatable({}, { __mode = "k" })

local GLOBAL_STORE_SERVICE = "get_all_characters_store_custom"
local CHARACTER_OVERVIEW_MELEE_WIDGET_TYPE = "better_inventory_character_overview_melee_weapon"
local CHARACTER_OVERVIEW_RANGED_WIDGET_TYPE = "better_inventory_character_overview_ranged_weapon"
local CHARACTER_OVERVIEW_CURIO_WIDGET_TYPE = "better_inventory_character_overview_curio"
local CHARACTER_OVERVIEW_EMPTY_CURIO_WIDGET_TYPE = "better_inventory_character_overview_empty_curio"
local CHARACTER_OVERVIEW_WEAPON_HEIGHT = 130
local CHARACTER_OVERVIEW_CURIO_TITLE_STAT_PADDING_Y = 6
local CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_CONTENT_SHIFT_Y = 8
local CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_EQUIPPED_ICON_SHIFT_Y = 8
local CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_TITLE_HORIZONTAL_PADDING = 19
local CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_TITLE_SHIFT_X = -1
local CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_ITEM_LEVEL_SHIFT_X = 16
local CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_ITEM_LEVEL_SHIFT_Y = -6
local CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_MARKER_SHIFT_X = 10
local CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_EQUIPPED_ICON_SHIFT_X = 6
local CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_FAVORITE_SHIFT_Y = 10
local CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_TITLE_MARKER_GAP_Y = 40
local character_overview_visual_settings_generation = 0
local CHARACTER_OVERVIEW_VISUAL_SETTING_IDS = {
	show_rarity_tag = true,
	enable_character_overview_melee_mirror = true,
	character_overview_show_melee_rarity_strip = true,
	enable_character_overview_ranged_mirror = true,
	character_overview_show_ranged_rarity_strip = true,
	character_overview_show_only_dump_stat = true,
	character_overview_dump_stat_horizontal_offset = true,
	character_overview_dump_stat_font_scale_percent = true,
	character_overview_dump_stat_color_preset = true,
	character_overview_dump_stat_color_r = true,
	character_overview_dump_stat_color_g = true,
	character_overview_dump_stat_color_b = true,
	enable_character_overview_curio_details = true,
	character_overview_show_curio_rarity_strip = true,
	character_overview_use_native_curio_overlay = true,
	character_overview_curio_name_mode = true,
	character_overview_curio_font_size_percent = true,
	character_overview_show_curio_names = true,
	name_it_force_curio_name_in_detailed_mode = true,
	curio_content_name_it_curio_name = true,
}
local CHARACTER_OVERVIEW_BLUEPRINTS
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

local function pass_by_style_id(pass_template, style_id)
	for index = 1, #(pass_template or {}) do
		local pass = pass_template[index]

		if pass and pass.style_id == style_id then
			return pass
		end
	end
end

local function configure_native_curio_overlay(blueprint, native_blueprint)
	local pass_template = blueprint and blueprint.pass_template
	local native_pass_template = native_blueprint and native_blueprint.pass_template

	if type(pass_template) ~= "table" or type(native_pass_template) ~= "table" then
		return
	end

	if not pass_by_style_id(pass_template, "inner_frame") then
		local native_inner_frame = pass_by_style_id(native_pass_template, "inner_frame")

		if native_inner_frame then
			-- Native pass templates are shared by every Curio slot. Clone the whole
			-- pass so this option cannot mutate Darktide's global template.
			pass_template[#pass_template + 1] = table.clone(native_inner_frame)
		end
	end

	local native_icon = pass_by_style_id(native_pass_template, "icon")
	local icon = pass_by_style_id(pass_template, "icon")

	if native_icon and native_icon.style and icon and icon.style then
		local native_style = native_icon.style
		local icon_style = icon.style

		icon_style.horizontal_alignment = native_style.horizontal_alignment
		icon_style.vertical_alignment = native_style.vertical_alignment

		if native_style.size then
			icon_style.size = table.clone(native_style.size)
		end

		if native_style.offset then
			icon_style.offset = table.clone(native_style.offset)
		end

		if native_style.uvs then
			icon_style.uvs = table.clone(native_style.uvs)
		end
	end
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

local function character_overview_item_content_revision(item)
	return CharacterOverview.content_revision(item)
end

local function character_overview_item_changed(previous_item, current_item)
	return CharacterOverview.changed(previous_item, current_item)
end

local function reset_character_overview_curio_fit_state(widget)
	local content = widget and widget.content

	return CharacterOverview.clear_derived_content(content, 4)
end

local function configure_character_overview_rarity_strip(blueprint, setting_id)
	local rarity_tag = pass_by_style_id(blueprint and blueprint.pass_template, "rarity_tag")

	if not rarity_tag then
		return
	end

	rarity_tag.visibility_function = function(content, style)
		-- `show_rarity_tag` remains the global master switch. The category-specific
		-- Character Overview setting is deliberately evaluated at draw time so a
		-- setting change can update an already-open overview after its layout is
		-- rebuilt, without retaining the widget or view in module state.
		if mod:get("show_rarity_tag") == false or setting_id and mod:get(setting_id) == false then
			return false
		end

		return true
	end
end

local function attach_runtime_marker_styles(widget, item_grid)
	local content = widget and widget.content
	local styles = widget and widget.style

	if not content or not styles then
		return
	end

	if styles.myfav_hotspot then
		content.better_inventory_myfavorites_hotspot_style = styles.myfav_hotspot

		if item_grid then
			item_grid._better_inventory_myfavorites_active = true
			local tracked_widgets = item_grid._better_inventory_myfavorites_widgets

			if not tracked_widgets then
				tracked_widgets = setmetatable({}, { __mode = "k" })
				item_grid._better_inventory_myfavorites_widgets = tracked_widgets
			end

			tracked_widgets[widget] = true
			FeatureDomains.markers.track_grid(item_grid)
			FeatureDomains.markers.invalidate_grid(item_grid)
		end
	end

	for index = 1, #(widget.passes or {}) do
		local pass = widget.passes[index]

		if pass and pass.style_id == "equipped_icon" then
			content.better_inventory_equipped_icon_visibility_function = pass.visibility_function

			break
		end
	end
end

local function is_top_right_style(style)
	return style and style.horizontal_alignment == "right" and style.vertical_alignment == "top"
end

local function is_top_right_marker(pass)
	return is_top_right_style(pass and pass.style)
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

local function character_overview_weapon_blueprint(rarity_strip_setting_id)
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
	configure_character_overview_rarity_strip(blueprint, rarity_strip_setting_id)
	configure_character_overview_weapon_passes(blueprint)
	move_character_overview_weapon_icon(blueprint)

	local configured_init = blueprint.init

	blueprint.init = function(parent, widget, element, callback_name, secondary_callback_name, ui_renderer, double_click_callback, template)
		if type(configured_init) == "function" then
			configured_init(parent, widget, element, callback_name, secondary_callback_name, ui_renderer, double_click_callback, template)
		end

		mark_character_overview_requirement_met(widget)
	end

	local native_update = blueprint.update

	blueprint.update = function(parent, widget, input_service, dt, t, ui_renderer)
		local content = widget and widget.content
		local element = content and content.element
		-- Native overview blueprints treat content.item as the item currently
		-- rendered by this reusable widget. element.item may already point at the
		-- replacement when returning from the child inventory view.
		local previous_item = content and content.item
		local slot = element and element.slot
		local current_item = slot and parent.equipped_item_in_slot and parent:equipped_item_in_slot(slot.name)
		local item_changed = character_overview_item_changed(previous_item, current_item)

		-- Native item-slot update only performs work when the equipped identity or
		-- mark changed. Avoid invoking it through our blueprint on every stable
		-- Character Overview frame; that nested call was charged to BetterInventory
		-- and scaled badly on slower/high-cardinality inventory sessions.
		if not item_changed then
			return
		end

		if type(Layout.restore_item_customization_style) == "function" then
			Layout.restore_item_customization_style(widget)
		end

		if type(native_update) == "function" then
			native_update(parent, widget, input_service, dt, t, ui_renderer)
		end

		mark_character_overview_requirement_met(widget)

		if element then
			element.item = current_item

			if type(blueprint.update_data) == "function" then
				blueprint.update_data(parent, widget, element)
			end
		end
	end

	return blueprint
end

local function normalized_displayed_value(content, displayed_id, fitted_id, full_id, source_id, normalized_values, raw_values, cache_index)
	local displayed_value = content[displayed_id]
	local source_value

	if displayed_value == content[fitted_id] then
		source_value = content[full_id] or source_id and content[source_id] or displayed_value
	else
		source_value = source_id and content[source_id] or displayed_value
	end

	if raw_values[cache_index] ~= source_value then
		raw_values[cache_index] = source_value

		if type(source_value) == "string" then
			normalized_values[cache_index] = string.gsub(source_value, "[\r\n]+", " ")
		else
			normalized_values[cache_index] = source_value
		end
	end

	return normalized_values[cache_index]
end

local function invalidate_myfavorites_grid(item_grid)
	return FeatureDomains.markers.invalidate_grid(item_grid)
end

local function invalidate_myfavorites_view(view)
	return invalidate_myfavorites_grid(view and view._item_grid)
end

local better_inventory_test = type(mod) == "table" and rawget(mod, "_better_inventory_test")

if type(better_inventory_test) == "table" then
	better_inventory_test.normalized_displayed_value = normalized_displayed_value
	better_inventory_test.character_overview_item_changed = character_overview_item_changed
end

local function character_overview_curio_blueprint()
	local native_blueprint = InventoryViewContentBlueprints.gadget_item_slot
	local detailed_blueprint = CHARACTER_OVERVIEW_BLUEPRINTS and CHARACTER_OVERVIEW_BLUEPRINTS.item

	if type(native_blueprint) ~= "table" or type(detailed_blueprint) ~= "table" or not detailed_blueprint.pass_template then
		return
	end

	local blueprint = table.clone(detailed_blueprint)
	local native_curio_overlay_enabled = mod:get("character_overview_use_native_curio_overlay") == true
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
	configure_character_overview_rarity_strip(blueprint, "character_overview_show_curio_rarity_strip")

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
		if type(configured_init) == "function" then
			configured_init(parent, widget, element, callback_name, secondary_callback_name, ui_renderer, double_click_callback, template)
		end

		mark_character_overview_requirement_met(widget)

		if widget and widget.content then
			widget.content.better_inventory_native_curio_overlay_enabled = native_curio_overlay_enabled
		end
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
	local native_marker_min_y

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
				stat_style.offset[2] = (stat_style.offset[2] or 0) + curio_name_block_height + CHARACTER_OVERVIEW_CURIO_TITLE_STAT_PADDING_Y
			end
		end
	end

	if native_curio_overlay_enabled then
		local content_shift_y = CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_CONTENT_SHIFT_Y

		if display_name and display_name.style and display_name.style.offset then
			display_name.style.horizontal_alignment = "center"
			display_name.style.text_horizontal_alignment = "center"
			-- Center alignment already places the title band inside the card. The
			-- horizontal inset belongs in size[1]; offset[1] is only an additive
			-- X delta. Adding the inset here would shift the title right.
			display_name.style.offset[1] = CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_TITLE_SHIFT_X
			display_name.style.offset[2] = (display_name.style.offset[2] or 0) + content_shift_y
			display_name.style.size = display_name.style.size or {
				card_width - CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_TITLE_HORIZONTAL_PADDING * 2,
				curio_name_block_height,
			}
			display_name.style.size[1] = math.max(40, card_width - CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_TITLE_HORIZONTAL_PADDING * 2)
			native_marker_min_y = (display_name.style.offset[2] or 0) + (display_name.style.size[2] or 0) + CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_TITLE_MARKER_GAP_Y
		end

		for index = 1, 4 do
			local stat_style = curio_stat_passes[index] and curio_stat_passes[index].style

			if stat_style and stat_style.offset then
				stat_style.offset[2] = (stat_style.offset[2] or 0) + content_shift_y
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

	-- Apply the native Curio portrait geometry after the normal BetterInventory
	-- geometry pass so the opt-in visual shell is the final authority.
	if native_curio_overlay_enabled then
		configure_native_curio_overlay(blueprint, native_blueprint)

		local equipped_icon = pass_by_style_id(blueprint.pass_template, "equipped_icon")
		local favorite_icon = pass_by_style_id(blueprint.pass_template, "favorite_icon")
		local myfavorites_hotspot = pass_by_style_id(blueprint.pass_template, "myfav_hotspot")

		if equipped_icon and equipped_icon.style and equipped_icon.style.offset and is_top_right_marker(equipped_icon) then
			local equipped_marker_y = (equipped_icon.style.offset[2] or 0) + CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_EQUIPPED_ICON_SHIFT_Y

			if native_marker_min_y then
				equipped_marker_y = math.max(equipped_marker_y, native_marker_min_y)
			end

			equipped_icon.style.offset[1] = (equipped_icon.style.offset[1] or 0) - CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_EQUIPPED_ICON_SHIFT_X
			equipped_icon.style.offset[2] = equipped_marker_y
			equipped_icon.style.better_inventory_native_curio_equipped_min_y = native_marker_min_y
		end

		for _, pass in ipairs({ favorite_icon, myfavorites_hotspot }) do
			if pass and pass.style and pass.style.offset and is_top_right_marker(pass) then
				pass.style.offset[1] = (pass.style.offset[1] or 0) - CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_MARKER_SHIFT_X

				if pass == myfavorites_hotspot then
					local marker_y = (pass.style.offset[2] or 0) + CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_FAVORITE_SHIFT_Y

					if native_marker_min_y then
						marker_y = math.max(marker_y, native_marker_min_y)
					end

					pass.style.offset[2] = marker_y
				end
			end
		end

		if favorite_icon and favorite_icon.style and favorite_icon.style.offset and is_top_right_marker(favorite_icon) then
			local favorite_base_offset_y = favorite_icon.style.offset[2] or 0
			favorite_icon.style.better_inventory_native_curio_favorite_shift_y = CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_FAVORITE_SHIFT_Y
			favorite_icon.style.better_inventory_native_curio_favorite_min_y = native_marker_min_y
			favorite_icon.style.better_inventory_native_curio_favorite_base_y = favorite_base_offset_y

			local marker_y = (favorite_icon.style.offset[2] or 0) + CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_FAVORITE_SHIFT_Y

			if native_marker_min_y then
				marker_y = math.max(marker_y, native_marker_min_y)
			end

			favorite_icon.style.offset[2] = marker_y

			local original_favorite_change_function = favorite_icon.change_function

			favorite_icon.change_function = function(content, style, animations, dt)
				if original_favorite_change_function then
					original_favorite_change_function(content, style, animations, dt)
				else
					style.offset[2] = style.better_inventory_native_curio_favorite_base_y or favorite_base_offset_y
				end

				local marker_y = (style.offset[2] or 0) + CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_FAVORITE_SHIFT_Y
				local favorite_marker_min_y = style.better_inventory_native_curio_favorite_min_y

				if favorite_marker_min_y then
					marker_y = math.max(marker_y, favorite_marker_min_y)
				end

				style.offset[2] = marker_y

				local runtime_hotspot_style = content and content.better_inventory_myfavorites_hotspot_style

				if runtime_hotspot_style and runtime_hotspot_style.offset then
					runtime_hotspot_style.offset[2] = style.offset[2]
				end
			end
		end
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

	local curio_stat_content_ids = {
		"better_inventory_curio_stat_1",
		"better_inventory_curio_stat_2",
		"better_inventory_curio_stat_3",
		"better_inventory_curio_stat_4",
	}
	local curio_stat_full_content_ids = {
		"better_inventory_overview_full_curio_stat_1",
		"better_inventory_overview_full_curio_stat_2",
		"better_inventory_overview_full_curio_stat_3",
		"better_inventory_overview_full_curio_stat_4",
	}
	local curio_stat_fitted_content_ids = {
		"better_inventory_overview_fitted_curio_stat_1",
		"better_inventory_overview_fitted_curio_stat_2",
		"better_inventory_overview_fitted_curio_stat_3",
		"better_inventory_overview_fitted_curio_stat_4",
	}
	local curio_stat_source_content_ids = {
		"better_inventory_full_curio_stat_1",
		"better_inventory_full_curio_stat_2",
		"better_inventory_full_curio_stat_3",
		"better_inventory_full_curio_stat_4",
	}

	local function fit_curio_text(widget, ui_renderer, force)
		local content = widget and widget.content
		local widget_style = widget and widget.style

		if not content or not ui_renderer then
			return
		end

		local title_style = show_curio_name and widget_style and widget_style.display_name
		local title_width = title_style and title_style.size and title_style.size[1]
		local stat_sources = content.better_inventory_curio_fit_stat_sources
		local stat_widths = content.better_inventory_curio_fit_stat_widths
		local normalized_values = content.better_inventory_curio_fit_normalized_values
		local raw_values = content.better_inventory_curio_fit_raw_values

		if type(stat_sources) ~= "table" then
			stat_sources = {}
			content.better_inventory_curio_fit_stat_sources = stat_sources
			force = true
		end

		if type(stat_widths) ~= "table" then
			stat_widths = {}
			content.better_inventory_curio_fit_stat_widths = stat_widths
			force = true
		end

		if type(normalized_values) ~= "table" then
			normalized_values = {}
			content.better_inventory_curio_fit_normalized_values = normalized_values
			force = true
		end

		if type(raw_values) ~= "table" then
			raw_values = {}
			content.better_inventory_curio_fit_raw_values = raw_values
			force = true
		end

		local full_name = title_style and normalized_displayed_value(content, "display_name", "better_inventory_fitted_curio_name", "better_inventory_full_display_name", nil, normalized_values, raw_values, 0)
		local needs_fit = force or content.better_inventory_curio_fit_initialized ~= true

		if title_style and (content.better_inventory_curio_fit_name_source ~= full_name or content.better_inventory_curio_fit_title_width ~= title_width or content.better_inventory_curio_fit_title_font_size ~= curio_name_font_size or content.better_inventory_curio_fit_title_line_limit ~= curio_name_line_limit) then
			needs_fit = true
		end

		for index = 1, 4 do
			local content_id = curio_stat_content_ids[index]
			local fitted_content_id = curio_stat_fitted_content_ids[index]
			local source_content_id = curio_stat_source_content_ids[index]
			local stat_style = widget_style and widget_style[content_id]
			local maximum_width = stat_style and (stat_style.better_inventory_max_text_width or stat_style.size and stat_style.size[1])
			local full_value = normalized_displayed_value(content, content_id, fitted_content_id, curio_stat_full_content_ids[index], source_content_id, normalized_values, raw_values, index)

			if stat_style and (stat_sources[index] ~= full_value or stat_widths[index] ~= maximum_width) then
				needs_fit = true
			end
		end

		if not needs_fit then
			return
		end

		if title_style then
			title_style.font_size = curio_name_font_size

			if type(full_name) == "string" and full_name ~= "" and type(title_width) == "number" then
				local minimum_font_size = 8
				local wrapped_rows

				while title_style.font_size > minimum_font_size do
					wrapped_rows = Text.word_wrap(ui_renderer, full_name, title_style, title_width)

					if not wrapped_rows or #wrapped_rows <= curio_name_line_limit then
						break
					end

					title_style.font_size = title_style.font_size - 1
				end

				wrapped_rows = Text.word_wrap(ui_renderer, full_name, title_style, title_width)

				local fitted_name

				if wrapped_rows and #wrapped_rows <= curio_name_line_limit then
					fitted_name = table.concat(wrapped_rows, "\n")
				elseif curio_name_line_limit == 1 then
					fitted_name = Text.crop_text_width(ui_renderer, full_name, title_style, title_width)
				else
					local fitted_rows = {}

					for index = 1, curio_name_line_limit do
						fitted_rows[index] = wrapped_rows and wrapped_rows[index] or ""
					end

					fitted_rows[curio_name_line_limit] = Text.crop_text_width(ui_renderer, fitted_rows[curio_name_line_limit] .. "…", title_style, title_width)
					fitted_name = table.concat(fitted_rows, "\n")
				end

				content.display_name = fitted_name
				content.better_inventory_fitted_curio_name = fitted_name
			end

			content.better_inventory_full_display_name = full_name
			content.better_inventory_curio_fit_name_source = full_name
			content.better_inventory_curio_fit_title_width = title_width
			content.better_inventory_curio_fit_title_font_size = curio_name_font_size
			content.better_inventory_curio_fit_title_line_limit = curio_name_line_limit
		end

		local cumulative_extra_height = 0

		for index = 1, 4 do
			local content_id = curio_stat_content_ids[index]
			local full_content_id = curio_stat_full_content_ids[index]
			local fitted_content_id = curio_stat_fitted_content_ids[index]
			local source_content_id = curio_stat_source_content_ids[index]
			local stat_style = widget_style and widget_style[content_id]
			local displayed_value = content[content_id]

			if stat_style then
				local full_value = normalized_displayed_value(content, content_id, fitted_content_id, full_content_id, source_content_id, normalized_values, raw_values, index)
				local maximum_width = stat_style.better_inventory_max_text_width or stat_style.size and stat_style.size[1]

				content[full_content_id] = full_value
				stat_sources[index] = full_value
				stat_widths[index] = maximum_width

				if type(displayed_value) == "string" and displayed_value ~= "" and type(full_value) == "string" and maximum_width then
					local wrapped_rows = Text.word_wrap(ui_renderer, full_value, stat_style, maximum_width)
					local line_count = math.max(1, wrapped_rows and #wrapped_rows or 1)
					local fitted_value = wrapped_rows and table.concat(wrapped_rows, "\n") or full_value
					local line_height = curio_stat_line_heights[index] or (stat_style.font_size or 13) + 5

					if stat_style.offset then
						stat_style.offset[2] = (curio_stat_base_offsets[index] or 0) + cumulative_extra_height
					end

					if stat_style.size then
						stat_style.size[2] = line_height * line_count
					end

					content[content_id] = fitted_value
					content[fitted_content_id] = fitted_value
					cumulative_extra_height = cumulative_extra_height + (line_count - 1) * line_height
				elseif stat_style.offset then
					stat_style.offset[2] = (curio_stat_base_offsets[index] or 0) + cumulative_extra_height
				end
			end
		end

		content.better_inventory_curio_fit_initialized = true
	end

	local overview_init = blueprint.init

	blueprint.init = function(parent, widget, element, callback_name, secondary_callback_name, ui_renderer, double_click_callback, template)
		if type(overview_init) == "function" then
			overview_init(parent, widget, element, callback_name, secondary_callback_name, ui_renderer, double_click_callback, template)
		end

		fit_curio_text(widget, ui_renderer, true)
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

		if native_curio_overlay_enabled then
			item_level.style.offset[1] = item_level.style.offset[1] - CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_ITEM_LEVEL_SHIFT_X
			-- item_level is bottom-aligned: positive Y moves it down, so this
			-- native-overlay adjustment is intentionally negative.
			item_level.style.offset[2] = item_level.style.offset[2] + CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_ITEM_LEVEL_SHIFT_Y
		end
		item_level.style.size = {
			card_width - 16,
			30,
		}
	end

	local native_update = blueprint.update

	blueprint.update = function(parent, widget, input_service, dt, t, ui_renderer)
		local content = widget and widget.content
		local element = content and content.element
		-- Use the rendered item, not element.item: the child inventory can replace
		-- the element first while this overview widget still shows the old Curio.
		local previous_item = content and content.item
		local slot = element and element.slot
		local current_item = slot and parent.equipped_item_in_slot and parent:equipped_item_in_slot(slot.name)
		local item_changed = character_overview_item_changed(previous_item, current_item)
		local hotspot = content and content.hotspot

		if hotspot then
			hotspot.disabled = not content.unlocked
		end

		if not item_changed then
			return
		end

		if type(Layout.restore_item_customization_style) == "function" then
			Layout.restore_item_customization_style(widget)
		end

		reset_character_overview_curio_fit_state(widget)

		if type(native_update) == "function" then
			native_update(parent, widget, input_service, dt, t, ui_renderer)
		end

		mark_character_overview_requirement_met(widget)

		if element then
			element.item = current_item

			if type(blueprint.update_data) == "function" then
				blueprint.update_data(parent, widget, element)
			end

			fit_curio_text(widget, ui_renderer, true)
			-- Fitted text can move the native equipped badge. Ask the view-level
			-- synchronizer for one pass; unchanged Curios do no fitting work.
			parent._better_inventory_equipped_icons_dirty = true
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

local function character_overview_native_curio_equipped_marker_y(widget)
	local content = widget and widget.content
	local element = content and content.element
	local slot = element and element.slot
	local slot_name = slot and slot.name
	local native_overlay_enabled = content and content.better_inventory_native_curio_overlay_enabled

	if native_overlay_enabled == nil then
		native_overlay_enabled = mod:get("character_overview_use_native_curio_overlay") == true
	end

	-- Character Overview Curios are the only widgets whose slot names use this
	-- prefix. Keep the runtime correction scoped to those widgets so weapons,
	-- inventory grids, and vendor cards retain their normal marker geometry.
	if native_overlay_enabled ~= true or type(slot_name) ~= "string" or not string.match(slot_name, "^slot_attachment_") then
		return
	end

	local styles = widget.style
	local equipped_style = styles and styles.equipped_icon

	if not is_top_right_style(equipped_style) then
		return
	end

	local title_style = styles and styles.display_name
	local first_stat_style = styles and styles.better_inventory_curio_stat_1
	local title_bottom

	if title_style and title_style.offset and title_style.size then
		title_bottom = (title_style.offset[2] or 0) + (title_style.size[2] or 0)
	end

	-- The marker belongs beside the first stat row, not inside the title band.
	-- Use the live widget styles rather than a cached blueprint coordinate: the
	-- title can be resized for localization/font scale, and another pass hook
	-- may rebuild or adjust the runtime style after widget construction.
	if first_stat_style and first_stat_style.offset then
		local marker_y = (first_stat_style.offset[2] or 0) - 2

		if title_bottom then
			marker_y = math.max(marker_y, title_bottom + 4)
		end

		return marker_y
	end

	if title_bottom then
		return title_bottom + CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_TITLE_MARKER_GAP_Y
	end
end

local function synchronize_character_overview_equipped_icon(widget, lantern_active)
	local equipped_style = widget and widget.style and widget.style.equipped_icon
	local offset = equipped_style and equipped_style.offset
	local content = widget and widget.content

	if not offset or not content then
		return
	end

	if content.better_inventory_equipped_icon_original_y == nil then
		content.better_inventory_equipped_icon_original_y = offset[2] or 2
	end

	local target_y = lantern_active and 34 or content.better_inventory_equipped_icon_original_y
	local native_overlay_enabled = content.better_inventory_native_curio_overlay_enabled == true
	local native_curio_min_y = native_overlay_enabled and equipped_style.better_inventory_native_curio_equipped_min_y
	local native_curio_marker_y = character_overview_native_curio_equipped_marker_y(widget)

	if native_curio_marker_y then
		-- This is the final runtime authority for the native yellow badge. It is
		-- deliberately derived from the visible stat pass so a long/two-line
		-- title cannot overlap it, even if a later callback rewrites offset[2].
		target_y = native_curio_marker_y
	elseif native_overlay_enabled and native_curio_min_y then
		target_y = math.max(target_y, native_curio_min_y)
	end

	offset[2] = target_y
end

local function synchronize_character_overview_equipped_icons(view, force)
	local widgets = view and view._loadout_widgets
	local lantern_active = lantern_recommendations_active()

	if not view then
		return 0
	end

	if force ~= true
		and view._better_inventory_equipped_icons_dirty ~= true
		and view._better_inventory_equipped_icons_widgets == widgets
		and view._better_inventory_equipped_icons_lantern_active == lantern_active then
		return 0
	end

	view._better_inventory_equipped_icons_dirty = false
	view._better_inventory_equipped_icons_widgets = widgets
	view._better_inventory_equipped_icons_lantern_active = lantern_active

	for index = 1, #(widgets or {}) do
		synchronize_character_overview_equipped_icon(widgets[index], lantern_active)
	end

	return #(widgets or {})
end

local function character_overview_curio_transition_type(widget_type, has_item)
	if widget_type == CHARACTER_OVERVIEW_EMPTY_CURIO_WIDGET_TYPE and has_item then
		return CHARACTER_OVERVIEW_CURIO_WIDGET_TYPE
	elseif widget_type == CHARACTER_OVERVIEW_CURIO_WIDGET_TYPE and not has_item then
		return CHARACTER_OVERVIEW_EMPTY_CURIO_WIDGET_TYPE
	end

	return nil
end

local function reconcile_character_overview_curio_widgets(view)
	local widgets = view and view._loadout_widgets
	local active_context = view and view._active_category_tab_context

	for index = 1, #(widgets or {}) do
		local widget = widgets[index]
		local target_type

		if widget and (widget.type == CHARACTER_OVERVIEW_EMPTY_CURIO_WIDGET_TYPE or widget.type == CHARACTER_OVERVIEW_CURIO_WIDGET_TYPE) then
			local content = widget.content
			local element = content and content.element
			local slot = element and element.slot

			if slot and type(view.equipped_item_in_slot) == "function" then
				local equipped_ok, equipped_item = pcall(view.equipped_item_in_slot, view, slot.name)

				if equipped_ok then
					target_type = character_overview_curio_transition_type(widget.type, equipped_item ~= nil)

					if target_type then
						-- Individual-layout widgets are one native lifecycle unit: their
						-- registrations, exclamation widgets, navigation state, callbacks,
						-- and icon resources are created and destroyed together. Rebuilding
						-- only this widget left the live engine on the old placeholder path.
						-- Re-present the current individual layout once, matching the proven
						-- close/reopen behavior while leaving grid layouts untouched.
						if active_context and active_context.is_grid_layout ~= true and type(view._switch_active_layout) == "function" then
							local rebuild_ok = pcall(view._switch_active_layout, view, active_context)

							return rebuild_ok and 1 or 0
						end

						return 0
					end
				end
			end
		end
	end

	return 0
end

local CHARACTER_OVERVIEW_RECONCILE_INTERVAL = 0.25

local function reconcile_character_overview_curio_widgets_if_needed(view, dt)
	if not view then
		return 0
	end

	local widgets = view._loadout_widgets
	local widgets_changed = view._better_inventory_reconcile_widgets ~= widgets
	local elapsed = (view._better_inventory_reconcile_elapsed or 0) + (tonumber(dt) or 0)

	if not widgets_changed and elapsed < CHARACTER_OVERVIEW_RECONCILE_INTERVAL then
		view._better_inventory_reconcile_elapsed = elapsed

		return 0
	end

	view._better_inventory_reconcile_widgets = widgets
	view._better_inventory_reconcile_elapsed = 0

	return reconcile_character_overview_curio_widgets(view)
end

if type(better_inventory_test) == "table" then
	better_inventory_test.character_overview_curio_transition_type = character_overview_curio_transition_type
	better_inventory_test.reconcile_character_overview_curio_widgets = reconcile_character_overview_curio_widgets
	better_inventory_test.reconcile_character_overview_curio_widgets_if_needed = reconcile_character_overview_curio_widgets_if_needed
end

local function refresh_character_overview_visual_layout_if_needed(view)
	if not view then
		return
	end

	if view.better_inventory_character_overview_visual_settings_generation == nil then
		view.better_inventory_character_overview_visual_settings_generation = character_overview_visual_settings_generation

		return
	end

	if view.better_inventory_character_overview_visual_settings_generation == character_overview_visual_settings_generation then
		return
	end

	view.better_inventory_character_overview_visual_settings_generation = character_overview_visual_settings_generation

	local active_context = view._active_category_tab_context

	if active_context and active_context.is_grid_layout ~= true and type(view._switch_active_layout) == "function" then
		-- Reuse Darktide's own layout lifecycle so old widgets, native icon
		-- resources, hotspots, and exclamation widgets are destroyed together.
		view:_switch_active_layout(active_context)
	end
end
OverviewUI.constants = {
	CHARACTER_OVERVIEW_MELEE_WIDGET_TYPE = CHARACTER_OVERVIEW_MELEE_WIDGET_TYPE,
	CHARACTER_OVERVIEW_RANGED_WIDGET_TYPE = CHARACTER_OVERVIEW_RANGED_WIDGET_TYPE,
	CHARACTER_OVERVIEW_CURIO_WIDGET_TYPE = CHARACTER_OVERVIEW_CURIO_WIDGET_TYPE,
	CHARACTER_OVERVIEW_EMPTY_CURIO_WIDGET_TYPE = CHARACTER_OVERVIEW_EMPTY_CURIO_WIDGET_TYPE,
	CHARACTER_OVERVIEW_VISUAL_SETTING_IDS = CHARACTER_OVERVIEW_VISUAL_SETTING_IDS,
}

OverviewUI.configure = function(dependencies)
	dependencies = dependencies or {}
	mod = dependencies.mod
	Layout = dependencies.Layout
	CharacterOverview = dependencies.CharacterOverview
	FeatureDomains = dependencies.FeatureDomains
	Diagnostics = dependencies.Diagnostics
	InventoryView = dependencies.InventoryView
	InventoryViewContentBlueprints = dependencies.InventoryViewContentBlueprints
	ItemBlueprintGenerator = dependencies.ItemBlueprintGenerator
	Text = dependencies.Text
	lantern_recommendations_active = dependencies.lantern_recommendations_active or function() return false end
	better_inventory_test = mod and rawget(mod, "_better_inventory_test")
	CHARACTER_OVERVIEW_BLUEPRINTS = type(ItemBlueprintGenerator) == "function" and ItemBlueprintGenerator({
		600,
		CHARACTER_OVERVIEW_WEAPON_HEIGHT,
	}) or nil

	if type(better_inventory_test) == "table" then
		better_inventory_test.normalized_displayed_value = normalized_displayed_value
		better_inventory_test.character_overview_item_changed = character_overview_item_changed
		better_inventory_test.character_overview_curio_transition_type = character_overview_curio_transition_type
		better_inventory_test.reconcile_character_overview_curio_widgets = reconcile_character_overview_curio_widgets
		better_inventory_test.reconcile_character_overview_curio_widgets_if_needed = reconcile_character_overview_curio_widgets_if_needed
	end

	return OverviewUI
end

OverviewUI.is_visual_setting = function(setting_id)
	return type(setting_id) == "string" and CHARACTER_OVERVIEW_VISUAL_SETTING_IDS[setting_id] == true
end

OverviewUI.bump_visual_settings_generation = function()
	character_overview_visual_settings_generation = character_overview_visual_settings_generation + 1
end

OverviewUI.unregister_view = function(view)
	if not view then
		return false
	end

	local registered = registered_character_overview_views[view] ~= nil

	registered_character_overview_views[view] = nil
	view._better_inventory_equipped_icons_dirty = nil
	view._better_inventory_equipped_icons_widgets = nil
	view._better_inventory_equipped_icons_lantern_active = nil
	view._better_inventory_reconcile_widgets = nil
	view._better_inventory_reconcile_elapsed = nil
	view._auto_crafter_status_overlay = nil

	return registered
end

OverviewUI.release_all_views = function()
	local views = {}

	for view in pairs(registered_character_overview_views) do
		views[#views + 1] = view
	end

	for index = 1, #views do
		OverviewUI.unregister_view(views[index])
	end

	return #views
end

OverviewUI.registered_view_count = function()
	local count = 0

	for _ in pairs(registered_character_overview_views) do
		count = count + 1
	end

	return count
end

OverviewUI.update_registered_views = function(dt)
	local updated = 0

	for view in pairs(registered_character_overview_views) do
		if view._destroyed == true then
			OverviewUI.unregister_view(view)
		else
			local update_ok, update_error = pcall(function()
				refresh_character_overview_visual_layout_if_needed(view)
				reconcile_character_overview_curio_widgets_if_needed(view, dt)
				synchronize_character_overview_equipped_icons(view)
			end)

			if update_ok then
				updated = updated + 1
			else
				-- A third-party inspected/read-only InventoryView can expose a
				-- partially compatible shape. Quarantine that view instead of
				-- throwing from BetterInventory's global frame update forever.
				OverviewUI.unregister_view(view)

				if mod and type(mod.warning) == "function" then
					mod:warning("Character Overview compatibility update disabled for one view: %s", tostring(update_error))
				end
			end
		end
	end

	return updated
end

OverviewUI.install_hooks = function(class_method_guard)
	ensure_class_method = class_method_guard
	if ensure_class_method(InventoryView, "on_exit") then
		mod:hook_safe(InventoryView, "on_exit", function(view)
			OverviewUI.unregister_view(view)
		end)
	end
	if ensure_class_method(InventoryView, "destroy") then
		mod:hook_safe(InventoryView, "destroy", function(view)
			OverviewUI.unregister_view(view)
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
		local visible_equipment_active = false

		if visible_equipment_mod then
			if type(visible_equipment_mod.is_enabled) ~= "function" then
				visible_equipment_active = true
			else
				local enabled_ok, enabled = pcall(visible_equipment_mod.is_enabled, visible_equipment_mod)
				-- If the optional integration cannot answer, preserve its widget
				-- conservatively instead of risking a broken character overview.
				visible_equipment_active = not enabled_ok or enabled == true
			end
		end

		local preserve_visible_equipment_placement = visible_equipment_active
		local adjust_runtime_equipped_icon = view and view.__class_name == "InventoryView" and not preserve_visible_equipment_placement and setting_id ~= nil

		if view and view.__class_name == "InventoryView" and setting_id ~= nil then
			registered_character_overview_views[view] = true
		end

		local function create_widget(resolved_config)
			local results = pack_values(func(view, resolved_config, suffix, callback_name, secondary_callback_name, optional_scenegraph_id))
			attach_runtime_marker_styles(results[1])

			if adjust_runtime_equipped_icon then
				synchronize_character_overview_equipped_icon(results[1], lantern_recommendations_active())
			end

			return unpack_values(results, 1, results.n)
		end

		if view and view.__class_name == "InventoryView" and not preserve_visible_equipment_placement and setting_id and mod:get(setting_id) ~= false then
			local equipped_item = view.equipped_item_in_slot and view:equipped_item_in_slot(config.slot.name)
			local empty_curio_slot = curio_slot and equipped_item == nil
			local rarity_strip_setting_id = weapon_kind == "melee" and "character_overview_show_melee_rarity_strip" or weapon_kind == "ranged" and "character_overview_show_ranged_rarity_strip"
			local blueprint = empty_curio_slot and character_overview_empty_curio_blueprint() or curio_slot and character_overview_curio_blueprint() or character_overview_weapon_blueprint(rarity_strip_setting_id)
			local widget_type = empty_curio_slot and CHARACTER_OVERVIEW_EMPTY_CURIO_WIDGET_TYPE or curio_slot and CHARACTER_OVERVIEW_CURIO_WIDGET_TYPE or weapon_kind == "melee" and CHARACTER_OVERVIEW_MELEE_WIDGET_TYPE or CHARACTER_OVERVIEW_RANGED_WIDGET_TYPE

			if blueprint then
				InventoryViewContentBlueprints[widget_type] = blueprint

			local adapted_config = table.clone(config)
			adapted_config.widget_type = widget_type
			adapted_config.item = equipped_item
			adapted_config.better_inventory_character_overview_callback_name = callback_name
			adapted_config.better_inventory_character_overview_secondary_callback_name = secondary_callback_name
			adapted_config.better_inventory_character_overview_scenegraph_id = optional_scenegraph_id

			return create_widget(adapted_config)
			end
		end

		return create_widget(config)
	end)
end
end

OverviewUI.pack_values = pack_values
OverviewUI.shallow_copy = shallow_copy
OverviewUI.is_armoury_requisition_view = is_armoury_requisition_view
OverviewUI.is_global_store_view = is_global_store_view
OverviewUI.is_hadron_view = is_hadron_view
OverviewUI.character_overview_weapon_kind = character_overview_weapon_kind
OverviewUI.character_overview_curio_slot = character_overview_curio_slot
OverviewUI.pass_by_style_id = pass_by_style_id
OverviewUI.character_overview_item_content_revision = character_overview_item_content_revision
OverviewUI.character_overview_item_changed = character_overview_item_changed
OverviewUI.reset_character_overview_curio_fit_state = reset_character_overview_curio_fit_state
OverviewUI.attach_runtime_marker_styles = attach_runtime_marker_styles
OverviewUI.character_overview_weapon_blueprint = character_overview_weapon_blueprint
OverviewUI.character_overview_curio_blueprint = character_overview_curio_blueprint
OverviewUI.character_overview_empty_curio_blueprint = character_overview_empty_curio_blueprint
OverviewUI.character_overview_native_curio_equipped_marker_y = character_overview_native_curio_equipped_marker_y
OverviewUI.synchronize_character_overview_equipped_icon = synchronize_character_overview_equipped_icon
OverviewUI.synchronize_character_overview_equipped_icons = synchronize_character_overview_equipped_icons
OverviewUI.character_overview_curio_transition_type = character_overview_curio_transition_type
OverviewUI.reconcile_character_overview_curio_widgets = reconcile_character_overview_curio_widgets
OverviewUI.reconcile_character_overview_curio_widgets_if_needed = reconcile_character_overview_curio_widgets_if_needed
OverviewUI.refresh_character_overview_visual_layout_if_needed = refresh_character_overview_visual_layout_if_needed
OverviewUI.invalidate_myfavorites_grid = invalidate_myfavorites_grid
OverviewUI.invalidate_myfavorites_view = invalidate_myfavorites_view

return OverviewUI
