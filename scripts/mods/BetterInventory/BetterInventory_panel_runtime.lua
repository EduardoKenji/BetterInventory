local PanelRuntime = {}

-- Panel entries and controller helpers only touch the supplied view/widget
-- objects. They do not own panel lifecycle or feature settings.
local function panel_entry(view, control_id, height, pass_template, initial_content, bind, refresh, controller_targets)
	local geometry = view._better_inventory_options_panel_geometry

	if type(controller_targets) == "table" and #controller_targets > 0 then
		initial_content = initial_content or {}
		initial_content.hotspot = initial_content.hotspot or {}

		if #controller_targets == 1 then
			pass_template[#pass_template + 1] = {
				pass_type = "rect",
				style_id = "better_inventory_controller_focus",
				style = {
					color = Color.terminal_corner_selected(55, true),
					offset = {
						0,
						0,
						2,
					},
					size = {
						geometry.content_width,
						height,
					},
				},
				visibility_function = function(content)
					local hotspot = content.hotspot

					return hotspot and (hotspot.is_selected or hotspot.is_focused) or false
				end,
			}
		else
			-- The grid selects a full-row proxy hotspot so vertical navigation and
			-- scrolling continue to work. Multi-control rows must visualize only
			-- the embedded hotspot selected with left/right, not that proxy row.
			for target_index = 1, #controller_targets do
				local target_id = controller_targets[target_index]
				local target_style

				for pass_index = 1, #pass_template do
					local pass = pass_template[pass_index]

					if pass.content_id == target_id then
						target_style = pass.style
						break
					end
				end

				if target_style then
					local target_offset = table.clone(target_style.offset or { 0, 0, 0 })
					local focus_style = table.clone(target_style)

					target_offset[3] = math.max(2, (tonumber(target_offset[3]) or 0) - 3)
					focus_style.color = Color.terminal_corner_selected(75, true)
					focus_style.offset = target_offset
					focus_style.size = table.clone(target_style.size or { geometry.content_width, height })
					pass_template[#pass_template + 1] = {
						pass_type = "rect",
						style_id = "better_inventory_controller_focus_" .. tostring(target_index),
						style = focus_style,
						visibility_function = function(content)
							local hotspot = content[target_id]

							return hotspot and (hotspot.is_selected or hotspot.is_focused) or false
						end,
					}
				end
			end
		end
	end

	return {
		controller_targets = controller_targets,
		control_id = control_id,
		initial_content = initial_content,
		pass_template = pass_template,
		bind = bind,
		refresh = refresh,
		size = {
			geometry.content_width,
			height,
		},
		view = view,
		widget_type = "better_inventory_control",
	}
end

local function clone_lantern_value(value, seen, depth)
	if type(value) ~= "table" then
		return value
	end

	seen = seen or {}
	depth = depth or 0

	-- Initialized UI styles can contain engine-added parent/back references.
	-- table.clone follows those references until DMF hits its duplicate-depth
	-- guard. The hosted row needs only plain style/content data, so omit cycles
	-- and unexpectedly deep runtime branches instead of cloning widget internals.
	if seen[value] or depth >= 8 then
		return
	end

	seen[value] = true

	local copy = {}

	for key, child in pairs(value) do
		if type(key) ~= "table" then
			local cloned_child = clone_lantern_value(child, seen, depth + 1)

			if cloned_child ~= nil then
				copy[key] = cloned_child
			end
		end
	end

	seen[value] = nil

	return copy
end

local function lantern_proxy_definition(view)
	local state = view._lantern_weapon_panel
	local source_widget = state and state.widget
	local source_passes = source_widget and source_widget.passes
	local source_content = source_widget and source_widget.content
	local source_styles = source_widget and source_widget.style
	local geometry = view._better_inventory_options_panel_geometry
	local background_style = source_styles and source_styles.background
	local source_width = background_style and background_style.size and tonumber(background_style.size[1])

	if type(source_passes) ~= "table" or type(source_content) ~= "table" or type(source_styles) ~= "table" or not geometry or not source_width then
		return
	end

	local background_offset = background_style.offset or {}
	local base_z = tonumber(background_offset[3]) or 0
	local center_x = math.max(0, (geometry.content_width - source_width) * 0.5)
	local pass_template = {}
	local initial_content = {}
	local value_ids = {}

	for index = 1, #source_passes do
		local source_pass = source_passes[index]
		local style_id = source_pass and source_pass.style_id
		local source_style = style_id and source_styles[style_id]

		if source_pass and source_pass.pass_type and style_id and type(source_style) == "table" then
			local style = clone_lantern_value(source_style)
			local offset = style.offset or {
				0,
				0,
				base_z,
			}

			style.offset = offset
			offset[1] = (tonumber(offset[1]) or 0) + center_x
			offset[3] = (tonumber(offset[3]) or base_z) - base_z

			local pass = {
				pass_type = source_pass.pass_type,
				style_id = style_id,
				style = style,
			}
			local value_id = source_pass.value_id

			if value_id then
				local value = clone_lantern_value(source_content[value_id])

				pass.value_id = value_id
				pass.value = clone_lantern_value(value)
				initial_content[value_id] = value
				value_ids[#value_ids + 1] = value_id
			end

			local content_id = source_pass.content_id

			if content_id then
				pass.content_id = content_id
				pass.content = clone_lantern_value(source_content[content_id] or {})
				initial_content[content_id] = clone_lantern_value(source_content[content_id] or {})
			end

			pass_template[#pass_template + 1] = pass
		end
	end

	if #pass_template == 0 then
		return
	end

	return pass_template, initial_content, value_ids
end

local function panel_lantern_entry(view)
	local geometry = view._better_inventory_options_panel_geometry
	local height = math.max(120, tonumber(view._better_inventory_lantern_panel_height) or 120)
	local pass_template, initial_content, value_ids = lantern_proxy_definition(view)

	if not pass_template then
		return
	end

	return {
		control_id = "better_inventory_lantern_section",
		initial_content = initial_content,
		pass_template = pass_template,
		refresh = function(widget)
			local state = view._lantern_weapon_panel
			local source_content = state and state.widget and state.widget.content

			if not source_content then
				return
			end

			for index = 1, #value_ids do
				local value_id = value_ids[index]

				widget.content[value_id] = clone_lantern_value(source_content[value_id])
			end
		end,
		size = {
			geometry.content_width,
			height,
		},
		view = view,
		widget_type = "better_inventory_lantern_section",
	}
end

local function controller_element_state(element)
	if not element then
		return
	end

	local state = {}

	if type(element.input_disabled) == "function" then
		state.input_disabled = element:input_disabled()
	end

	if type(element.selected_grid_index) == "function" then
		state.selected_index = element:selected_grid_index()
	end

	return state
end

local function clear_controller_element_selection(element)
	if element and type(element.select_grid_index) == "function" then
		element:select_grid_index()
	end
end

local function disable_controller_element(element)
	if not element then
		return
	end

	if type(element.disable_input) == "function" then
		element:disable_input(true)
	end

	clear_controller_element_selection(element)
end

local function restore_controller_element(element, state)
	if not element or not state then
		return
	end

	if type(element.disable_input) == "function" and state.input_disabled ~= nil then
		element:disable_input(state.input_disabled)
	end

	if type(element.select_grid_index) == "function" then
		element:select_grid_index(state.selected_index)
	end
end

local function set_inventory_options_panel_controller_focus(view, focused)
	local panel = view and view._better_inventory_options_panel
	local item_grid = view and view._item_grid

	if not panel or not item_grid then
		return false
	end

	if focused then
		if view._better_inventory_options_panel_controller_focused == true then
			return true
		end

		view._better_inventory_options_panel_controller_restore = {
			discard = controller_element_state(view._discard_items_element),
			item_grid = controller_element_state(item_grid),
			weapon_options = controller_element_state(view._weapon_options_element),
		}
		view._better_inventory_options_panel_controller_focused = true

		disable_controller_element(item_grid)
		disable_controller_element(view._weapon_options_element)
		disable_controller_element(view._discard_items_element)

		if type(panel.disable_input) == "function" then
			panel:disable_input(false)
		end

		if type(panel.select_first_index) == "function" then
			panel:select_first_index()
		end

		return true
	end

	local restore = view._better_inventory_options_panel_controller_restore or {}

	view._better_inventory_options_panel_controller_focused = false
	view._better_inventory_options_panel_controller_restore = nil
	view._better_inventory_options_panel_controller_target = nil
	clear_controller_element_selection(panel)
	restore_controller_element(item_grid, restore.item_grid)
	restore_controller_element(view._weapon_options_element, restore.weapon_options)
	restore_controller_element(view._discard_items_element, restore.discard)

	return false
end

local function release_inventory_options_panel(view, panel_reference)
	if not view then
		return false
	end

	local panel = view._better_inventory_options_panel
	local owned = panel ~= nil

	if view._better_inventory_options_panel_controller_focused == true then
		pcall(set_inventory_options_panel_controller_focus, view, false)
	end

	if panel and type(view._remove_element) == "function" then
		pcall(view._remove_element, view, panel_reference or "better_inventory_options_panel")
	end

	view._better_inventory_options_panel = nil
	view._better_inventory_options_panel_geometry = nil
	view._better_inventory_options_panel_mod = nil
	view._better_inventory_options_panel_widgets = nil
	view._better_inventory_options_panel_collapsed = nil
	view._better_inventory_options_panel_visible = nil
	view._better_inventory_options_panel_height = nil
	view._better_inventory_options_panel_pivot_x = nil
	view._better_inventory_options_panel_pivot_y = nil
	view._better_inventory_options_panel_structure_key = nil
	view._better_inventory_options_panel_controller_focused = nil
	view._better_inventory_options_panel_controller_restore = nil
	view._better_inventory_options_panel_controller_target = nil

	return owned
end

PanelRuntime.panel_entry = panel_entry
PanelRuntime.panel_lantern_entry = panel_lantern_entry
PanelRuntime.controller_element_state = controller_element_state
PanelRuntime.clear_controller_element_selection = clear_controller_element_selection
PanelRuntime.restore_controller_element = restore_controller_element
PanelRuntime.set_inventory_options_panel_controller_focus = set_inventory_options_panel_controller_focus
PanelRuntime.release_inventory_options_panel = release_inventory_options_panel
PanelRuntime.update_inventory_options_panel_controller_selection = update_inventory_options_panel_controller_selection

return PanelRuntime
