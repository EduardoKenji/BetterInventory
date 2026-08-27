local SearchRuntime = {}

local DEFAULT_PRESENT_DELAY = 0.08
local DEFAULT_DIM_ALPHA = 0.4

local function weak_key_table()
	return setmetatable({}, {
		__mode = "k",
	})
end

local function safe_call(callback, ...)
	if type(callback) ~= "function" then
		return nil
	end

	local ok, first, second = pcall(callback, ...)

	if ok then
		return first, second
	end

	return nil
end

local function item_from(entry)
	if type(entry) ~= "table" then
		return nil
	end

	return entry.real_item or entry.item or entry
end

local function copy_array(values)
	local copy = {}

	if type(values) == "table" then
		for index = 1, #values do
			copy[index] = values[index]
		end
	end

	return copy
end

local function query_is_active(state)
	return state and state.compiled and state.compiled.empty ~= true and state.compiled.fail_open ~= true
end

local function result_for(state, key)
	if key ~= nil and state.result_generations[key] == state.generation then
		return state.results[key], true
	end

	return nil, false
end

local function set_result(state, key, matched)
	if key ~= nil then
		state.result_generations[key] = state.generation
		state.results[key] = matched
	end
end

local function memory_key(runtime, view, family)
	local character = safe_call(runtime.dependencies.character_id, view)

	if character == nil or character == "" then
		return nil
	end

	return tostring(character) .. "\31" .. tostring(family or "inventory")
end

local function mode(runtime)
	local configured = safe_call(runtime.dependencies.mode)

	return configured == "hide" and "hide" or "dim"
end

local function remember_enabled(runtime)
	return safe_call(runtime.dependencies.remember_query) == true
end

local function family_for(runtime, view)
	local family = safe_call(runtime.dependencies.view_family, view)

	return type(family) == "string" and family ~= "" and family or nil
end

local function restore_widget_alpha(state, widget)
	local owned = state.owned_widget_alpha[widget]

	if not owned then
		return false
	end

	local content = widget and widget.content

	if type(content) == "table" and content.alpha_multiplier == owned.applied then
		content.alpha_multiplier = owned.original
	end

	state.owned_widget_alpha[widget] = nil

	return true
end

local function restore_all_widget_alpha(state)
	for widget in pairs(state.owned_widget_alpha) do
		restore_widget_alpha(state, widget)
	end
end

local function compile_state(runtime, state)
	local aliases = safe_call(runtime.dependencies.rarity_aliases, state.index) or {}
	state.compiled = runtime.dependencies.query.compile(state.query, {
		chips = state.chips,
		rarity_aliases = aliases,
	})
	state.error = state.compiled and state.compiled.error or nil
end

local function state_for(runtime, view, create)
	if type(view) ~= "table" then
		return nil
	end

	local state = runtime.states[view]

	if state or not create then
		return state
	end

	local family = family_for(runtime, view)

	if not family then
		return nil
	end

	local character = safe_call(runtime.dependencies.character_id, view)

	if character ~= nil and character ~= "" then
		character = tostring(character)

		if runtime.last_character_id and runtime.last_character_id ~= character then
			runtime.memory = {}
		end

		runtime.last_character_id = character
	end

	state = {
		chips = {},
		compiled = nil,
		counts = {
			matched = 0,
			total = 0,
		},
		error = nil,
		family = family,
		faulted = false,
		index = runtime.dependencies.new_index(view, family),
		last_present_arguments = nil,
		owned_widget_alpha = weak_key_table(),
		pending_present_at = nil,
		query = "",
		generation = 0,
		result_generations = weak_key_table(),
		results = weak_key_table(),
	}

	if remember_enabled(runtime) then
		local key = memory_key(runtime, view, family)
		local remembered = key and runtime.memory[key]

		if remembered then
			state.query = remembered.query or ""
			state.chips = copy_array(remembered.chips)
		end
	end

	compile_state(runtime, state)
	runtime.states[view] = state

	return state
end

local function entry_matches(runtime, state, entry, view)
	local item = item_from(entry)

	if type(item) ~= "table" then
		return true
	end

	local record, projected = runtime.dependencies.project(state.index, item, {
		entry = entry,
		family = state.family,
		view = view,
	})

	if projected ~= true then
		return true
	end

	return runtime.dependencies.query.matches(state.compiled, record) == true
end

local function scan(runtime, view, state)
	state.generation = state.generation + 1
	state.counts.matched = 0
	state.counts.total = 0

	if not query_is_active(state) then
		return state.counts
	end

	local layout = view._offer_items_layout

	if type(layout) ~= "table" then
		return state.counts
	end

	for index = 1, #layout do
		local entry = layout[index]
		local item = item_from(entry)

		if type(item) == "table" then
			local matched = entry_matches(runtime, state, entry, view)
			set_result(state, entry, matched)
			set_result(state, item, matched)
			state.counts.total = state.counts.total + 1

			if matched then
				state.counts.matched = state.counts.matched + 1
			end
		end
	end

	return state.counts
end

local function schedule_present(runtime, state, now)
	state.pending_present_at = (tonumber(now) or safe_call(runtime.dependencies.time) or 0) + runtime.present_delay
end

SearchRuntime.new = function(dependencies)
	dependencies = type(dependencies) == "table" and dependencies or {}

	assert(type(dependencies.query) == "table", "search query dependency is required")
	assert(type(dependencies.new_index) == "function", "search index factory is required")
	assert(type(dependencies.project) == "function", "search projector is required")

	return {
		dependencies = dependencies,
		dim_alpha = tonumber(dependencies.dim_alpha) or DEFAULT_DIM_ALPHA,
		memory = {},
		last_character_id = nil,
		present_delay = tonumber(dependencies.present_delay) or DEFAULT_PRESENT_DELAY,
		states = weak_key_table(),
	}
end

SearchRuntime.register = function(runtime, view)
	return state_for(runtime, view, true)
end

SearchRuntime.capture_presentation = function(runtime, view, slot_filter, item_type_filter, display_name)
	local state = state_for(runtime, view, true)

	if not state then
		return false
	end

	state.last_present_arguments = {
		display_name,
		item_type_filter,
		slot_filter,
	}
	scan(runtime, view, state)

	return true
end

SearchRuntime.set_query = function(runtime, view, query, chips, now)
	local state = state_for(runtime, view, true)

	if not state then
		return false
	end

	state.query = type(query) == "string" and query or tostring(query or "")
	state.chips = copy_array(chips)
	compile_state(runtime, state)
	scan(runtime, view, state)
	schedule_present(runtime, state, now)
	SearchRuntime.apply_widget_alpha(runtime, view)

	return state.compiled.valid == true, state.error
end

SearchRuntime.refresh = function(runtime, view, now)
	local state = state_for(runtime, view, false)

	if not state then
		return false
	end

	scan(runtime, view, state)
	schedule_present(runtime, state, now)
	SearchRuntime.apply_widget_alpha(runtime, view)

	return true
end

SearchRuntime.native_filter = function(runtime, view, entry, native_result)
	if native_result ~= true then
		return false
	end

	local state = state_for(runtime, view, false)

	if not query_is_active(state) or mode(runtime) ~= "hide" then
		return true
	end

	local result, found = result_for(state, entry)

	if not found then
		result, found = result_for(state, item_from(entry))
	end

	if not found then
		result = entry_matches(runtime, state, entry, view)
		set_result(state, entry, result)
	end

	return result == true
end

SearchRuntime.rank = function(runtime, view, entry)
	local state = state_for(runtime, view, false)

	if not query_is_active(state) or mode(runtime) ~= "dim" then
		return 0
	end

	local result, found = result_for(state, entry)

	if not found then
		result, found = result_for(state, item_from(entry))
	end

	if not found then
		result = entry_matches(runtime, state, entry, view)
		set_result(state, entry, result)
	end

	return result == true and 1 or 0
end

SearchRuntime.apply_widget_alpha = function(runtime, view)
	local state = state_for(runtime, view, false)

	if not state then
		return false
	end

	local active = query_is_active(state) and mode(runtime) == "dim"
	local item_grid = view and view._item_grid
	local widgets = item_grid and (item_grid._all_grid_widgets or item_grid._grid_widgets)

	if type(widgets) ~= "table" then
		if not active then
			restore_all_widget_alpha(state)
		end

		return false
	end

	for index = 1, #widgets do
		local widget = widgets[index]
		local content = widget and widget.content
		local entry = content and content.entry
		local matched, found = result_for(state, entry)

		if not found and entry then
			matched, found = result_for(state, item_from(entry))
		end

		if active and matched == false then
			local owned = state.owned_widget_alpha[widget]

			if not owned and type(content) == "table" then
				local original = tonumber(content.alpha_multiplier) or 1
				owned = {
					applied = original * runtime.dim_alpha,
					original = original,
				}
				state.owned_widget_alpha[widget] = owned
			end

			if owned and content.alpha_multiplier == owned.original then
				content.alpha_multiplier = owned.applied
			end
		else
			restore_widget_alpha(state, widget)
		end
	end

	if not active then
		restore_all_widget_alpha(state)
	end

	return true
end

SearchRuntime.update = function(runtime, view, now)
	local state = state_for(runtime, view, false)

	if not state or state.faulted or not state.pending_present_at then
		return false
	end

	now = tonumber(now) or safe_call(runtime.dependencies.time) or 0

	if now < state.pending_present_at then
		return false
	end

	state.pending_present_at = nil
	local arguments = state.last_present_arguments

	if not arguments then
		return false
	end

	local ok = safe_call(runtime.dependencies.present, view, arguments[3], arguments[2], arguments[1])

	if ok == nil then
		state.faulted = true
		return false
	end

	return true
end

SearchRuntime.invalidate = function(runtime, view, value, now)
	local state = state_for(runtime, view, false)

	if not state then
		return false
	end

	safe_call(runtime.dependencies.invalidate, state.index, value)

	return SearchRuntime.refresh(runtime, view, now)
end

SearchRuntime.invalidate_all = function(runtime, view, now)
	local state = state_for(runtime, view, false)

	if not state then
		return false
	end

	safe_call(runtime.dependencies.invalidate_all, state.index)

	return SearchRuntime.refresh(runtime, view, now)
end

SearchRuntime.release = function(runtime, view)
	local state = state_for(runtime, view, false)

	if not state then
		return false
	end

	if remember_enabled(runtime) then
		local key = memory_key(runtime, view, state.family)

		if key then
			runtime.memory[key] = {
				chips = copy_array(state.chips),
				query = state.query,
			}
		end
	end

	restore_all_widget_alpha(state)
	safe_call(runtime.dependencies.release_index, state.index)
	state.results = weak_key_table()
	state.result_generations = weak_key_table()
	state.last_present_arguments = nil
	runtime.states[view] = nil

	return true
end

SearchRuntime.clear_memory = function(runtime)
	runtime.memory = {}
end

SearchRuntime.release_all = function(runtime)
	local views = {}

	for view in pairs(runtime.states) do
		views[#views + 1] = view
	end

	for index = 1, #views do
		SearchRuntime.release(runtime, views[index])
	end

	return #views
end

SearchRuntime.state = function(runtime, view)
	return state_for(runtime, view, false)
end

SearchRuntime.query = function(runtime, view)
	local state = state_for(runtime, view, false)

	return state and state.query or ""
end

SearchRuntime.chips = function(runtime, view)
	local state = state_for(runtime, view, false)

	return copy_array(state and state.chips)
end

SearchRuntime.counts = function(runtime, view)
	local state = state_for(runtime, view, false)

	return state and state.counts.matched or 0, state and state.counts.total or 0
end

SearchRuntime.is_active = function(runtime, view)
	return query_is_active(state_for(runtime, view, false))
end

return SearchRuntime
