local ArmouryPanel = {}

function ArmouryPanel.new(dependencies)
	local features = dependencies.features
	local registered_armoury_views = dependencies.registered_views
	local is_armoury_sort_view = dependencies.is_armoury_sort_view
	local item_sorting_is_enabled = dependencies.item_sorting_is_enabled
	local item_sorting_custom_option_start = dependencies.item_sorting_custom_option_start
	local item_sorting_options_signature = dependencies.item_sorting_options_signature
	local inventory_sort_toggle_passes = dependencies.inventory_sort_toggle_passes
	local armoury_native_sort_option_passes = dependencies.armoury_native_sort_option_passes
	local panel_section_header_passes = dependencies.panel_section_header_passes
	local controller_element_state = dependencies.controller_element_state
	local clear_controller_element_selection = dependencies.clear_controller_element_selection
	local restore_controller_element = dependencies.restore_controller_element
	local ARMOURY_NATIVE_SORT_PANEL_REFERENCE = dependencies.ARMOURY_NATIVE_SORT_PANEL_REFERENCE
	local ARMOURY_NATIVE_SORT_PANEL_WIDTH = dependencies.ARMOURY_NATIVE_SORT_PANEL_WIDTH
	local ARMOURY_NATIVE_SORT_PANEL_HEIGHT = dependencies.ARMOURY_NATIVE_SORT_PANEL_HEIGHT
	local ARMOURY_NATIVE_SORT_PANEL_MIN_HEIGHT = dependencies.ARMOURY_NATIVE_SORT_PANEL_MIN_HEIGHT
	local ARMOURY_NATIVE_SORT_PANEL_TOP = dependencies.ARMOURY_NATIVE_SORT_PANEL_TOP
	local ARMOURY_NATIVE_SORT_PANEL_RIGHT_MARGIN = dependencies.ARMOURY_NATIVE_SORT_PANEL_RIGHT_MARGIN
	local ARMOURY_NATIVE_SORT_PANEL_WEAPON_GAP = dependencies.ARMOURY_NATIVE_SORT_PANEL_WEAPON_GAP
	local ARMOURY_NATIVE_SORT_PANEL_WALLET_GAP = dependencies.ARMOURY_NATIVE_SORT_PANEL_WALLET_GAP
	local ARMOURY_NATIVE_SORT_PANEL_ROW_HEIGHT = dependencies.ARMOURY_NATIVE_SORT_PANEL_ROW_HEIGHT
	local ARMOURY_NATIVE_SORT_PANEL_ROW_SPACING = dependencies.ARMOURY_NATIVE_SORT_PANEL_ROW_SPACING
	local ARMOURY_NATIVE_SORT_PANEL_PADDING = dependencies.ARMOURY_NATIVE_SORT_PANEL_PADDING
	local ARMOURY_NATIVE_SORT_CHECKBOX_LEFT_PADDING = dependencies.ARMOURY_NATIVE_SORT_CHECKBOX_LEFT_PADDING
	local INVENTORY_VIRTUAL_CANVAS_WIDTH = dependencies.INVENTORY_VIRTUAL_CANVAS_WIDTH
	local ARMOURY_NATIVE_SORT_BLUEPRINTS = dependencies.ARMOURY_NATIVE_SORT_BLUEPRINTS

local function armoury_controller_focus_passes(pass_template, height)
	pass_template[#pass_template + 1] = {
		pass_type = "rect",
		style_id = "better_inventory_armoury_controller_focus",
		style = {
			color = Color.terminal_corner_selected(55, true),
			offset = {
				0,
				0,
				2,
			},
			size = {
				ARMOURY_NATIVE_SORT_PANEL_WIDTH,
				height,
			},
		},
		visibility_function = function(content)
			local hotspot = content.hotspot

			return hotspot and (hotspot.is_selected or hotspot.is_focused) or false
		end,
	}

	return pass_template
end

local function armoury_native_sort_entry(view, option, option_index)
	local selected_sort_index = view._selected_sort_option_index or 1

	return {
		initial_content = {
			hotspot = {},
			label = option.display_name or tostring(option_index),
			selected = selected_sort_index == option_index,
		},
		option_index = option_index,
		option = option,
		pass_template = armoury_controller_focus_passes(armoury_native_sort_option_passes(ARMOURY_NATIVE_SORT_PANEL_WIDTH), ARMOURY_NATIVE_SORT_PANEL_ROW_HEIGHT),
		size = {
			ARMOURY_NATIVE_SORT_PANEL_WIDTH,
			ARMOURY_NATIVE_SORT_PANEL_ROW_HEIGHT,
		},
		view = view,
		widget_type = "better_inventory_armoury_native_sort",
		bind = function(widget)
			widget.content.hotspot.pressed_callback = function()
				local item_grid = view._item_grid

				if item_grid and type(item_grid.trigger_sort_index) == "function" then
					item_grid:trigger_sort_index(option_index)
				elseif type(view.cb_on_sort_button_pressed) == "function" then
					view:cb_on_sort_button_pressed(option)
				end
			end
		end,
		refresh = function(widget)
			widget.content.selected = (view._selected_sort_option_index or 1) == option_index
		end,
	}
end

local function armoury_native_sort_toggle_passes()
	local passes = inventory_sort_toggle_passes()
	local checkbox_style_ids = {
		checkbox_background = true,
		checkbox_frame = true,
		checkmark = true,
	}

	for index = 1, #passes do
		local pass = passes[index]

		if checkbox_style_ids[pass.style_id] then
			local style = pass.style or {}
			local offset = style.offset or {
				0,
				0,
				0,
			}

			offset[1] = (offset[1] or 0) + ARMOURY_NATIVE_SORT_CHECKBOX_LEFT_PADDING
			style.offset = offset
			pass.style = style
		end
	end

	return passes
end

local function armoury_native_sort_header_entry(mod, layout, view, section_id, label)
	return {
		initial_content = {
			chevron = view._better_inventory_armoury_native_sort_collapsed[section_id] and ">" or "v",
			hotspot = {},
			label = label,
		},
		option_index = "header_" .. section_id,
		pass_template = armoury_controller_focus_passes(panel_section_header_passes(ARMOURY_NATIVE_SORT_PANEL_WIDTH), 40),
		size = {
			ARMOURY_NATIVE_SORT_PANEL_WIDTH,
			40,
		},
		view = view,
		widget_type = "better_inventory_armoury_native_sort",
		bind = function(widget)
			widget.content.hotspot.pressed_callback = function()
				local collapsed = view._better_inventory_armoury_native_sort_collapsed

				collapsed[section_id] = not collapsed[section_id]
				view._better_inventory_armoury_native_sort_rebuild_pending = true
			end
		end,
		refresh = function(widget)
			widget.content.chevron = view._better_inventory_armoury_native_sort_collapsed[section_id] and ">" or "v"
		end,
	}
end

local function armoury_native_sort_priority_entry(mod, layout, view, setting_id, label)
	return {
		initial_content = {
			checked = setting_id == "prioritize_equipped_favorites" and mod:get(setting_id) ~= false or mod:get(setting_id) == true,
			hotspot = {},
			label = label,
		},
		option_index = "priority_" .. setting_id,
		pass_template = armoury_controller_focus_passes(armoury_native_sort_toggle_passes(), 38),
		size = {
			ARMOURY_NATIVE_SORT_PANEL_WIDTH,
			38,
		},
		view = view,
		widget_type = "better_inventory_armoury_native_sort",
		bind = function(widget)
			widget.content.hotspot.pressed_callback = function()
				mod:set(setting_id, not widget.content.checked, false)
				features.sync_inventory_sort_setting(mod, layout)
			end
		end,
		refresh = function(widget)
			widget.content.checked = setting_id == "prioritize_equipped_favorites" and mod:get(setting_id) ~= false or mod:get(setting_id) == true
		end,
	}
end




local function scenegraph_rect(owner, scenegraph_id)
	if type(owner) ~= "table" or type(owner._scenegraph_size) ~= "function" then
		return nil
	end

	local world_position = owner.scenegraph_world_position or owner._scenegraph_world_position

	if type(world_position) ~= "function" then
		return nil
	end

	if type(owner._force_update_scenegraph) == "function" then
		pcall(owner._force_update_scenegraph, owner)
	end

	local position_success, position = pcall(world_position, owner, scenegraph_id)
	local size_success, width, height = pcall(owner._scenegraph_size, owner, scenegraph_id)

	if not position_success or not size_success or type(position) ~= "table" or type(position[1]) ~= "number" or type(position[2]) ~= "number" or type(width) ~= "number" or type(height) ~= "number" then
		return nil
	end

	return {
		x = position[1],
		y = position[2],
		width = width,
		height = height,
	}
end

local function armoury_native_sort_panel_position(view)
	local canvas_width = INVENTORY_VIRTUAL_CANVAS_WIDTH
	local canvas_position = {
		0,
		0,
	}
	local scenegraph = view and view._ui_scenegraph
	local canvas = scenegraph and scenegraph.canvas

	if canvas and type(canvas.size) == "table" and type(canvas.size[1]) == "number" then
		canvas_width = canvas.size[1]
	end

	if view and type(view._scenegraph_world_position) == "function" then
		local success, position = pcall(view._scenegraph_world_position, view, "canvas")

		if success and type(position) == "table" then
			canvas_position = position
		end
	end

	local fallback_x = canvas_position[1] + canvas_width - ARMOURY_NATIVE_SORT_PANEL_RIGHT_MARGIN - ARMOURY_NATIVE_SORT_PANEL_WIDTH
	local fallback_y = canvas_position[2] + ARMOURY_NATIVE_SORT_PANEL_TOP
	local weapon_rect = scenegraph_rect(view and view._weapon_stats, "grid_background")

	if not weapon_rect then
		return fallback_x, fallback_y
	end

	local x = weapon_rect.x + weapon_rect.width + ARMOURY_NATIVE_SORT_PANEL_WEAPON_GAP
	local y = weapon_rect.y
	local parent = view and view._context and view._context.parent
	local wallet_frame = scenegraph_rect(parent, "corner_top_right")

	if wallet_frame then
		y = math.max(y, wallet_frame.y + wallet_frame.height + ARMOURY_NATIVE_SORT_PANEL_WALLET_GAP)
	end

	return x, y
end

local function armoury_native_sort_entries(mod, layout, view)
	local collapsed = view._better_inventory_armoury_native_sort_collapsed
	local sort_options = view._sort_options or {}
	local first_item_sorting_option = item_sorting_custom_option_start(view)
	local entries = {
		armoury_native_sort_header_entry(mod, layout, view, "sorting", mod:localize("inventory_sorting_inventory_label")),
	}

	if not collapsed.sorting then
		entries[#entries + 1] = armoury_native_sort_priority_entry(mod, layout, view, "prioritize_equipped_favorites", mod:localize("prioritize_equipped_favorites_inventory_label"))
		entries[#entries + 1] = armoury_native_sort_priority_entry(mod, layout, view, "prioritize_perfect_roll_weapons", mod:localize("prioritize_perfect_roll_weapons_inventory_label"))
	end

	if item_sorting_is_enabled() then
		entries[#entries + 1] = armoury_native_sort_header_entry(mod, layout, view, "item_sorting", mod:localize("item_sorting_mod_header"))

		if not collapsed.item_sorting then
			for option_index = first_item_sorting_option, #sort_options do
				entries[#entries + 1] = armoury_native_sort_entry(view, sort_options[option_index], option_index)
			end
		end
	end

	-- Native sorting is a sibling section, not part of the custom-priority
	-- section. Keep its header (and its own collapsed state) visible when the
	-- Sorting section is collapsed.
	entries[#entries + 1] = armoury_native_sort_header_entry(mod, layout, view, "native_sorting", mod:localize("armoury_native_sorting_header"))

	if not collapsed.native_sorting then
		for option_index = 1, first_item_sorting_option - 1 do
			entries[#entries + 1] = armoury_native_sort_entry(view, sort_options[option_index], option_index)
		end
	end

	return entries
end

local function armoury_native_sort_panel_height(entries)
	local content_height = 0

	for index = 1, #entries do
		content_height = content_height + entries[index].size[2]
	end

	content_height = content_height + math.max(#entries - 1, 0) * ARMOURY_NATIVE_SORT_PANEL_ROW_SPACING

	return math.max(ARMOURY_NATIVE_SORT_PANEL_MIN_HEIGHT, content_height + ARMOURY_NATIVE_SORT_PANEL_PADDING * 2 + 31)
end

local function rebuild_armoury_native_sort_panel(view)
	features.count_diagnostic("panel_rebuilds")
	local panel = view and view._better_inventory_armoury_native_sort_panel

	if not panel or view._destroyed then
		return false
	end

	local entries = armoury_native_sort_entries(view._better_inventory_armoury_sort_mod, view._better_inventory_armoury_sort_layout, view)
	local panel_height = math.min(ARMOURY_NATIVE_SORT_PANEL_HEIGHT, armoury_native_sort_panel_height(entries))

	panel:update_grid_height(panel_height, panel_height)
	panel:present_grid_layout(entries, ARMOURY_NATIVE_SORT_BLUEPRINTS)

	return true
end

local function armoury_input_legend(view)
	local parent = view and (view._parent or view._context and view._context.parent)

	if not parent then
		return nil
	end

	if parent._input_legend_element then
		return parent._input_legend_element
	end

	if type(parent._element) == "function" then
		local success, legend = pcall(parent._element, parent, "input_legend")

		if success then
			return legend
		end
	end
end

local function setup_armoury_controller_focus_legend(mod, view)
	local focus_action = mod:get("inventory_options_controller_focus_keybind")

	if view._better_inventory_armoury_controller_legend_id and view._better_inventory_armoury_controller_legend_action == focus_action then
		return true
	end

	local previous_legend = view._better_inventory_armoury_controller_legend
	local previous_id = view._better_inventory_armoury_controller_legend_id

	if previous_legend and previous_id and type(previous_legend.remove_entry) == "function" then
		pcall(previous_legend.remove_entry, previous_legend, previous_id)
	end

	view._better_inventory_armoury_controller_legend = nil
	view._better_inventory_armoury_controller_legend_id = nil
	view._better_inventory_armoury_controller_legend_action = nil

	local legend = focus_action and focus_action ~= "off" and armoury_input_legend(view)

	if not legend or type(legend.add_entry) ~= "function" then
		return false
	end

	local success, legend_id = pcall(legend.add_entry, legend, "better_inventory_toggle_panel_focus", focus_action, function()
		return view._using_cursor_navigation == false and view._better_inventory_armoury_native_sort_panel ~= nil
	end, nil, "right_alignment")

	if not success or not legend_id then
		return false
	end

	view._better_inventory_armoury_controller_legend = legend
	view._better_inventory_armoury_controller_legend_id = legend_id
	view._better_inventory_armoury_controller_legend_action = focus_action

	return true
end

local function set_armoury_controller_focus(view, focused)
	local panel = view and view._better_inventory_armoury_native_sort_panel
	local item_grid = view and view._item_grid

	if not panel or not item_grid then
		return false
	end

	if focused then
		if view._better_inventory_armoury_controller_focused == true then
			return true
		end

		view._better_inventory_armoury_controller_restore = controller_element_state(item_grid)
		view._better_inventory_armoury_controller_focused = true

		if type(item_grid.disable_input) == "function" then
			item_grid:disable_input(true)
		end

		clear_controller_element_selection(item_grid)

		if type(panel.disable_input) == "function" then
			panel:disable_input(false)
		end

		if type(panel.select_first_index) == "function" then
			panel:select_first_index()
		end

		return true
	end

	view._better_inventory_armoury_controller_focused = false
	clear_controller_element_selection(panel)
	restore_controller_element(item_grid, view._better_inventory_armoury_controller_restore)
	view._better_inventory_armoury_controller_restore = nil

	return false
end

local function capture_armoury_sort_panel_controller_focus(mod, view, input_service)
	if not is_armoury_sort_view(view) then
		return false
	end

	local panel = view._better_inventory_armoury_native_sort_panel
	local focused = view._better_inventory_armoury_controller_focused == true

	if view._using_cursor_navigation ~= false or not panel or panel._visible == false then
		if focused then
			set_armoury_controller_focus(view, false)
		end

		return false
	end

	local focus_action = mod:get("inventory_options_controller_focus_keybind")

	if focus_action and focus_action ~= "off" and input_service and type(input_service.get) == "function" and input_service:get(focus_action) then
		focused = set_armoury_controller_focus(view, not focused)
	end

	if focused then
		local item_grid = view._item_grid

		if item_grid and type(item_grid.disable_input) == "function" then
			item_grid:disable_input(true)
		end

		if type(panel.selected_grid_index) == "function" and not panel:selected_grid_index() and type(panel.select_first_index) == "function" then
			panel:select_first_index()
		end
	end

	return focused
end

local function armoury_sort_panel_controller_focused(view)
	return view and view._better_inventory_armoury_controller_focused == true
end

local function update_armoury_native_sort_panel(view)
	local panel = view and view._better_inventory_armoury_native_sort_panel

	if not panel or view._destroyed then
		return false
	end

	local sorting_mod = features._sorting.mod()
	local item_sorting_enabled_flag = sorting_mod and sorting_mod.enabled

	if view._better_inventory_composition_item_sorting_enabled ~= item_sorting_enabled_flag then
		features.invalidate_view_composition(view)
		view._better_inventory_composition_item_sorting_enabled = item_sorting_enabled_flag
	end

	local probe_count = (view._better_inventory_composition_probe_count or 0) + 1
	local probe_due = probe_count >= 15
	local input_changed = features.composition_inputs_changed(view, "armoury", not view._better_inventory_composition_dirty and not view._better_inventory_armoury_native_sort_rebuild_pending and not probe_due)

	if not view._better_inventory_composition_dirty and not input_changed and not view._better_inventory_armoury_native_sort_rebuild_pending and not probe_due then
		view._better_inventory_composition_probe_count = probe_count

		return true
	end

	view._better_inventory_composition_probe_count = 0

	setup_armoury_controller_focus_legend(view._better_inventory_armoury_sort_mod, view)

	local item_sorting_active = item_sorting_is_enabled()
	local item_sorting_signature = item_sorting_options_signature(view)

	if view._better_inventory_item_sorting_active ~= item_sorting_active or view._better_inventory_item_sorting_signature ~= item_sorting_signature then
		view._better_inventory_item_sorting_active = item_sorting_active
		view._better_inventory_item_sorting_signature = item_sorting_signature
		view._better_inventory_armoury_native_sort_rebuild_pending = true
	end

	if view._better_inventory_armoury_native_sort_rebuild_pending then
		view._better_inventory_armoury_native_sort_rebuild_pending = false
		rebuild_armoury_native_sort_panel(view)
	end

	local x, y = armoury_native_sort_panel_position(view)

	if type(panel.set_pivot_offset) == "function" and (view._better_inventory_armoury_native_sort_pivot_x ~= x or view._better_inventory_armoury_native_sort_pivot_y ~= y) then
		features.count_diagnostic("pivot_writes")
		panel:set_pivot_offset(x, y)
		view._better_inventory_armoury_native_sort_pivot_x = x
		view._better_inventory_armoury_native_sort_pivot_y = y
	end

	view._better_inventory_composition_dirty = false

	return true
end

local function setup_armoury_native_sort_panel(mod, layout, view, ViewElementGrid)
	if not is_armoury_sort_view(view) or view._better_inventory_armoury_native_sort_panel then
		return false
	end

	local sort_options = view._sort_options

	if type(sort_options) ~= "table" or (#sort_options == 0 and not item_sorting_is_enabled()) or type(ViewElementGrid) ~= "table" or type(view._add_element) ~= "function" then
		return false
	end

	local menu_settings = {
		bottom_chin = ARMOURY_NATIVE_SORT_PANEL_PADDING,
		edge_padding = 0,
		enable_gamepad_scrolling = true,
		grid_size = {
			ARMOURY_NATIVE_SORT_PANEL_WIDTH,
			ARMOURY_NATIVE_SORT_PANEL_HEIGHT,
		},
		grid_spacing = {
			0,
			ARMOURY_NATIVE_SORT_PANEL_ROW_SPACING,
		},
		ignore_blur = true,
		mask_size = {
			ARMOURY_NATIVE_SORT_PANEL_WIDTH,
			ARMOURY_NATIVE_SORT_PANEL_HEIGHT,
		},
		reset_selection_on_navigation_change = false,
		scrollbar_width = 7,
		title_height = 0,
		top_padding = ARMOURY_NATIVE_SORT_PANEL_PADDING,
		use_is_focused_for_navigation = false,
		use_select_on_focused = true,
		use_terminal_background = true,
	}
	local success, panel = pcall(view._add_element, view, ViewElementGrid, ARMOURY_NATIVE_SORT_PANEL_REFERENCE, 25, menu_settings)

	if not success or not panel then
		if type(mod.error) == "function" then
			mod:error("BetterInventory Armoury native-sort panel could not initialize: " .. tostring(panel))
		end

		if type(view._remove_element) == "function" then
			pcall(view._remove_element, view, ARMOURY_NATIVE_SORT_PANEL_REFERENCE)
		end

		return false
	end

	view._better_inventory_armoury_native_sort_panel = panel
	view._better_inventory_armoury_native_sort_widgets = {}
	view._better_inventory_armoury_native_sort_collapsed = {
		item_sorting = false,
		native_sorting = false,
		sorting = false,
	}
	view._better_inventory_item_sorting_active = item_sorting_is_enabled()
	view._better_inventory_item_sorting_signature = item_sorting_options_signature(view)
	view._better_inventory_armoury_native_sort_rebuild_pending = false
	view._better_inventory_armoury_sort_layout = layout
	view._better_inventory_armoury_sort_mod = mod
	view._better_inventory_composition_dirty = true
	view._better_inventory_composition_probe_count = 0
	registered_armoury_views[view] = true
	if type(panel.disable_input) == "function" then
		panel:disable_input(false)
	end

	if type(panel.set_visibility) == "function" then
		panel:set_visibility(true)
	end

	local entries = armoury_native_sort_entries(mod, layout, view)

	panel:update_grid_height(ARMOURY_NATIVE_SORT_PANEL_HEIGHT, ARMOURY_NATIVE_SORT_PANEL_HEIGHT)
	panel:present_grid_layout(entries, ARMOURY_NATIVE_SORT_BLUEPRINTS)
	features.update_armoury_native_sort_panel(view)

	return true
end

local function release_armoury_native_sort_panel(view)
	if not view then
		return false
	end

	local panel = view._better_inventory_armoury_native_sort_panel
	local owned = panel ~= nil

	if view._better_inventory_armoury_controller_focused == true then
		pcall(set_armoury_controller_focus, view, false)
	end

	local legend = view._better_inventory_armoury_controller_legend
	local legend_id = view._better_inventory_armoury_controller_legend_id

	if legend and legend_id and type(legend.remove_entry) == "function" then
		pcall(legend.remove_entry, legend, legend_id)
	end

	if panel and type(view._remove_element) == "function" then
		pcall(view._remove_element, view, ARMOURY_NATIVE_SORT_PANEL_REFERENCE)
	end

	view._better_inventory_armoury_controller_focused = nil
	view._better_inventory_armoury_controller_legend = nil
	view._better_inventory_armoury_controller_legend_action = nil
	view._better_inventory_armoury_controller_legend_id = nil
	view._better_inventory_armoury_controller_restore = nil
	view._better_inventory_armoury_native_sort_collapsed = nil
	view._better_inventory_armoury_native_sort_panel = nil
	view._better_inventory_armoury_native_sort_pivot_x = nil
	view._better_inventory_armoury_native_sort_pivot_y = nil
	view._better_inventory_armoury_native_sort_rebuild_pending = nil
	view._better_inventory_armoury_native_sort_widgets = nil
	view._better_inventory_armoury_sort_layout = nil
	view._better_inventory_armoury_sort_mod = nil
	view._better_inventory_item_sorting_active = nil
	view._better_inventory_item_sorting_signature = nil
	view._better_inventory_composition_dirty = nil
	view._better_inventory_composition_probe_count = nil
	registered_armoury_views[view] = nil

	return owned
end



	return {
		capture = capture_armoury_sort_panel_controller_focus,
		focused = armoury_sort_panel_controller_focused,
		release = release_armoury_native_sort_panel,
		scenegraph_rect = scenegraph_rect,
		set_focus = set_armoury_controller_focus,
		setup = setup_armoury_native_sort_panel,
		update = update_armoury_native_sort_panel,
	}
end

return ArmouryPanel
