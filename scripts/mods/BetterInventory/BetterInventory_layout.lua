local Layout = {}

local SLOT_SETTING_BY_NAME = {
	slot_primary = "enable_melee_inventory",
	slot_secondary = "enable_ranged_inventory",
}

local function setting(mod, setting_id, fallback)
	local value = mod:get(setting_id)

	if value == nil then
		return fallback
	end

	return value
end

local function pass_by_style_id(pass_template, style_id)
	for i = 1, #pass_template do
		local pass = pass_template[i]

		if pass.style_id == style_id then
			return pass
		end
	end
end

local function set_visibility(pass, visible)
	if pass then
		pass.visibility_function = function()
			return visible
		end
	end
end

local function set_height(pass, height)
	local style = pass and pass.style

	if style then
		style.size = style.size or {}
		style.size[2] = height
	end
end

local function apply_live_item_icon(widget, grid_index, rows, columns, render_target)
	local style = widget and widget.style
	local icon_style = style and style.icon
	local material_values = icon_style and icon_style.material_values

	if not material_values then
		return
	end

	material_values.use_placeholder_texture = 0
	material_values.use_render_target = 1
	material_values.rows = rows
	material_values.columns = columns
	material_values.grid_index = grid_index - 1
	material_values.render_target = render_target
	widget.content.use_placeholder_texture = 0
end

local function configure_icon_loader(item_blueprint, item_size)
	item_blueprint.load_icon = function(parent, widget, element, ui_renderer, dummy_profile, prioritize)
		local content = widget.content
		local item = element and (element.real_item or element.item)

		if not content.icon_load_id and item then
			local render_context = {
				size = {
					item_size[1],
					item_size[2],
				},
			}
			local on_loaded = callback(apply_live_item_icon, widget)

			content.icon_load_id = Managers.ui:load_item_icon(item, on_loaded, render_context, dummy_profile, prioritize)
		end
	end
end

local function configure_text_pass(pass, options)
	if not pass or not pass.style then
		return
	end

	local style = pass.style

	style.horizontal_alignment = options.horizontal_alignment or "left"
	style.vertical_alignment = options.vertical_alignment or "top"
	style.text_horizontal_alignment = options.text_horizontal_alignment or "left"
	style.text_vertical_alignment = options.text_vertical_alignment or "top"
	style.font_size = options.font_size
	style.offset = options.offset
	style.size = options.size
end

Layout.slot_kind = function(view)
	local selected_slot = view and view._selected_slot
	local slot_name = selected_slot and selected_slot.name

	if SLOT_SETTING_BY_NAME[slot_name] then
		return slot_name
	end

	if type(slot_name) == "string" and string.match(slot_name, "^slot_attachment_") then
		return "curio"
	end
end

Layout.is_enabled_for_view = function(mod, view)
	local slot_kind = Layout.slot_kind(view)

	if slot_kind == "curio" then
		return setting(mod, "enable_curio_inventory", true)
	end

	local setting_id = SLOT_SETTING_BY_NAME[slot_kind]

	return setting_id and setting(mod, setting_id, true) or false
end

Layout.item_size = function(mod, grid_width)
	local columns = math.floor(math.max(2, math.min(5, setting(mod, "columns", 3))))
	local spacing = math.max(0, math.min(40, setting(mod, "grid_spacing", 10)))
	local height = math.max(110, math.min(180, setting(mod, "card_height", 110)))
	local width = math.floor((grid_width - spacing * (columns - 1)) / columns)

	return {
		math.max(120, width),
		height,
	}
end

Layout.configure_grid = function(mod, item_grid)
	local spacing = math.max(0, math.min(40, setting(mod, "grid_spacing", 10)))
	local menu_settings = item_grid and item_grid._menu_settings

	if menu_settings then
		menu_settings.grid_spacing = {
			spacing,
			spacing,
		}
	end
end


Layout.configure_item_blueprint = function(mod, item_blueprint, grid_width)
	local item_size = Layout.item_size(mod, grid_width)
	local card_width = item_size[1]
	local card_height = item_size[2]
	local pass_template = table.clone(item_blueprint.pass_template)
	local show_rarity_tag = setting(mod, "show_rarity_tag", true)
	local text_left = show_rarity_tag and 12 or 8
	local text_width = math.max(50, card_width - text_left - 36)
	local darkness = math.max(0, math.min(85, setting(mod, "icon_darkness", 25)))
	local icon_brightness = math.floor(255 * (1 - darkness / 100))

	item_blueprint.size = item_size
	item_blueprint.pass_template = pass_template

	local icon = pass_by_style_id(pass_template, "icon")

	if icon and icon.style then
		icon.style.horizontal_alignment = "left"
		icon.style.vertical_alignment = "top"
		icon.style.size = {
			card_width,
			card_height,
		}
		icon.style.offset = {
			0,
			0,
			4,
		}
		icon.style.uvs = {
			{
				0,
				0,
			},
			{
				1,
				1,
			},
		}
		icon.style.color = {
			255,
			icon_brightness,
			icon_brightness,
			icon_brightness,
		}
	end

	local loading = pass_by_style_id(pass_template, "loading")

	if loading and loading.style then
		loading.style.horizontal_alignment = "center"
		loading.style.vertical_alignment = "center"
		loading.style.size = {
			56,
			56,
		}
		loading.style.offset = {
			0,
			0,
			5,
		}
	end

	configure_text_pass(pass_by_style_id(pass_template, "display_name"), {
		font_size = setting(mod, "item_name_font_size", 16),
		offset = {
			text_left,
			7,
			8,
		},
		size = {
			text_width,
			25,
		},
	})

	local sub_display_name = pass_by_style_id(pass_template, "sub_display_name")

	configure_text_pass(sub_display_name, {
		font_size = setting(mod, "secondary_text_font_size", 13),
		offset = {
			text_left,
			31,
			8,
		},
		size = {
			card_width - text_left - 8,
			22,
		},
	})
	local show_pattern_mark = setting(mod, "show_pattern_mark", true)

	if not show_pattern_mark and sub_display_name then
		sub_display_name.visibility_function = function(content)
			local element = content and content.element
			local item = element and (element.real_item or element.item)

			-- This option controls the weapon pattern/mark line. Curios use the
			-- same pass for their subtype, which remains visible.
			return item and item.item_type == "GADGET"
		end
	end

	local rarity_name = pass_by_style_id(pass_template, "rarity_name")

	configure_text_pass(rarity_name, {
		font_size = setting(mod, "secondary_text_font_size", 13),
		offset = {
			text_left,
			51,
			8,
		},
		size = {
			card_width - text_left - 8,
			22,
		},
	})
	set_visibility(rarity_name, setting(mod, "show_rarity_name", true))

	configure_text_pass(pass_by_style_id(pass_template, "item_level"), {
		font_size = setting(mod, "expertise_font_size", 20),
		horizontal_alignment = "right",
		vertical_alignment = "bottom",
		text_horizontal_alignment = "right",
		text_vertical_alignment = "bottom",
		offset = {
			-8,
			-5,
			9,
		},
		size = {
			card_width - 16,
			28,
		},
	})

	local rarity_tag = pass_by_style_id(pass_template, "rarity_tag")

	if rarity_tag and rarity_tag.style then
		rarity_tag.style.size = {
			5,
			card_height,
		}
	end
	set_visibility(rarity_tag, show_rarity_tag)

	local equipped_icon = pass_by_style_id(pass_template, "equipped_icon")

	if equipped_icon and equipped_icon.style then
		equipped_icon.style.size = {
			28,
			28,
		}
		equipped_icon.style.offset = {
			-2,
			2,
			16,
		}
	end

	for i = 1, #pass_template do
		local pass = pass_template[i]

		if pass.value == "content/ui/materials/symbols/new_item_indicator" and pass.style then
			pass.style.size = {
				62,
				62,
			}
			pass.style.offset = {
				16,
				-16,
				4,
			}
			break
		end
	end

	local favorite_icon = pass_by_style_id(pass_template, "favorite_icon")

	if favorite_icon and favorite_icon.style and setting(mod, "compact_favorite_marker", true) then
		favorite_icon.value = ""
		favorite_icon.style.font_size = 20
		favorite_icon.style.offset = {
			text_left,
			-5,
			16,
		}
		favorite_icon.style.size = {
			30,
			28,
		}
	end

	local salvage_icon = pass_by_style_id(pass_template, "salvage_icon")
	local salvage_circle = pass_by_style_id(pass_template, "salvage_circle")

	if salvage_icon and salvage_icon.style then
		salvage_icon.style.offset = {
			card_width * 0.5 - 27,
			0,
			14,
		}
	end

	if salvage_circle and salvage_circle.style then
		salvage_circle.style.offset = {
			card_width * 0.5 - 50,
			0,
			15,
		}
	end

	local centered_y = card_height * 0.5 - 19

	for _, style_id in ipairs({
		"required_level_background",
		"required_level",
		"warning_message_background",
		"warning_message",
	}) do
		local pass = pass_by_style_id(pass_template, style_id)

		if pass and pass.style then
			pass.style.offset = pass.style.offset or {}
			pass.style.offset[2] = centered_y
		end
	end

	set_height(pass_by_style_id(pass_template, "inner_shadow"), card_height)
	set_height(pass_by_style_id(pass_template, "inner_highlight"), card_height)

	configure_icon_loader(item_blueprint, item_size)

	return item_size
end

return Layout
