local SearchRuntime = {}

local DEFAULT_PRESENT_DELAY = 0.08
local DEFAULT_DIM_ALPHA = 0.4
local DEFAULT_WARM_BATCH_SIZE = 16

local function weak_key_table()
	return setmetatable({}, {
		__mode = "k",
	})
end

local function clear_table(values)
	for key in pairs(values) do
		values[key] = nil
	end
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

	local item = entry.real_item or entry.item

	if type(item) == "table" then
		return item
	end

	if entry.gear_id ~= nil or entry.item_type ~= nil then
		return entry
	end
end

local function query_is_active(state)
	return state and state.compiled and state.compiled.empty ~= true and state.compiled.fail_open ~= true
end

local function result_for(state, key)
	if key ~= nil then
		local rank = state.ranks[key]

		if rank ~= nil then
			return rank > 0, true, rank
		end
	end

	return nil, false
end

local function set_result(state, key, matched, rank)
	if key ~= nil then
		state.ranks[key] = matched == true and (tonumber(rank) or 1) or 0
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

local function sync_hot_path_flags(runtime, view, state)
	local active = query_is_active(state) and state.results_ready == true

	view._better_inventory_search_rank_active = active and true or nil
	view._better_inventory_search_filter_active = active and mode(runtime) == "hide" and true or nil
end

local function remember_enabled(runtime)
	return safe_call(runtime.dependencies.remember_query) == true
end

local function family_for(runtime, view)
	local family = safe_call(runtime.dependencies.view_family, view)

	return type(family) == "string" and family ~= "" and family or nil
end

local function restore_widget_alpha(state, widget)
	local original = state.owned_widget_alpha[widget]

	if original == nil then
		return false
	end

	local content = widget and widget.content

	if type(content) == "table" and content.alpha_multiplier == original * state.dim_alpha then
		content.alpha_multiplier = original
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
		rarity_aliases = aliases,
	})
	state.error = state.compiled and state.compiled.error or nil
end

local function recover_presentation_context(runtime, view, state)
	if state.presentation_kind then
		return true
	end

	local context = safe_call(runtime.dependencies.presentation_context, view)

	if type(context) ~= "table" then
		return false
	end

	if context.kind == "external" then
		state.presentation_kind = "external"
		return true
	elseif context.kind ~= "native" then
		return false
	end

	local arguments = state.last_present_arguments or {}
	arguments[1] = context.display_name
	arguments[2] = context.item_type_filter
	arguments[3] = context.slot_filter
	state.last_present_arguments = arguments
	state.presentation_kind = "native"

	return true
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
		compiled = nil,
		dim_alpha = runtime.dim_alpha,
		error = nil,
		family = family,
		faulted = false,
		index = runtime.dependencies.new_index(view, family),
		last_present_arguments = nil,
		owned_widget_alpha = weak_key_table(),
		pending_present_at = nil,
		presentation_kind = nil,
		projection_context = {},
		query = "",
		ranks = weak_key_table(),
		results_ready = false,
		warm_cursor = nil,
	}

	if remember_enabled(runtime) then
		local key = memory_key(runtime, view, family)
		local remembered = key and runtime.memory[key]

		if remembered then
			state.query = remembered.query or ""
		end
	end

	compile_state(runtime, state)
	runtime.states[view] = state

	return state
end

local function entry_result(runtime, state, entry, view, prioritize_equipped, resolved_item, trust_projection_cache)
	local item = resolved_item or item_from(entry)

	if type(item) ~= "table" then
		return true, 1
	end

	-- These are Better Inventory-owned, fail-soft modules. Avoid two protected
	-- calls per item in the settled-query scan; their external data access is
	-- already guarded at the projection boundary.
	local context = state.projection_context
	context.entry = entry
	context.family = state.family
	context.trust_cache = trust_projection_cache == true
	context.view = view
	local record, projected = runtime.dependencies.project(state.index, item, context)
	context.entry = nil
	context.trust_cache = nil
	context.view = nil

	if projected ~= true then
		return true, 1
	end

	local matched = runtime.dependencies.query.matches(state.compiled, record) == true
	if prioritize_equipped == nil then
		prioritize_equipped = safe_call(runtime.dependencies.prioritize_equipped) ~= false
	end

	local rank = runtime.dependencies.query.rank(state.compiled, record, matched, prioritize_equipped)

	return matched, tonumber(rank) or (matched and 1 or 0)
end

local function scan(runtime, view, state, source_layout, trust_projection_cache)
	-- Keep exactly one result generation. Native presentation can replace layout
	-- entry identities, and weak keys are not collected until Lua's next GC.
	-- Clearing in place prevents successive settled queries from retaining every
	-- prior generation while also avoiding a fresh result-table allocation.
	clear_table(state.ranks)
	state.results_ready = false
	state.warm_cursor = nil

	if not query_is_active(state) then
		state.results_ready = true
		sync_hot_path_flags(runtime, view, state)
		return
	end

	local layout = source_layout or view._offer_items_layout

	if type(layout) ~= "table" then
		return
	end

	local prioritize_equipped = safe_call(runtime.dependencies.prioritize_equipped) ~= false

	for index = 1, #layout do
		local entry = layout[index]
		local item = item_from(entry)

		if type(item) == "table" then
			local matched, rank = entry_result(runtime, state, entry, view, prioritize_equipped, item, trust_projection_cache)
			-- Darktide's comparator, native filter, and widget content all retain
			-- the presented layout entry. Store one weak-key result per entry; direct
			-- item layouts naturally use the item itself as that same key.
			set_result(state, entry, matched, rank)
		end
	end

	state.results_ready = true
	sync_hot_path_flags(runtime, view, state)
end

local function warm_projection_cache(runtime, view, state)
	local cursor = state and state.warm_cursor

	if not cursor then
		return true
	end

	local layout = view and view._offer_items_layout

	if type(layout) ~= "table" or cursor > #layout then
		state.warm_cursor = nil
		return true
	end

	local last_index = math.min(cursor + runtime.warm_batch_size - 1, #layout)
	local projection_context = state.projection_context

	for index = cursor, last_index do
		local entry = layout[index]
		local item = item_from(entry)

		if type(item) == "table" then
			projection_context.entry = entry
			projection_context.family = state.family
			projection_context.view = view
			runtime.dependencies.project(state.index, item, projection_context)
			projection_context.entry = nil
			projection_context.view = nil
		end
	end

	state.warm_cursor = last_index < #layout and last_index + 1 or nil

	return state.warm_cursor == nil
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
		warm_batch_size = math.max(1, math.floor(tonumber(dependencies.warm_batch_size) or DEFAULT_WARM_BATCH_SIZE)),
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

	local arguments = state.last_present_arguments or {}
	arguments[1] = display_name
	arguments[2] = item_type_filter
	arguments[3] = slot_filter
	state.last_present_arguments = arguments
	state.presentation_kind = "native"
	if not state.compiled then
		compile_state(runtime, state)
	end
	local reuse_results = state.reuse_next_capture_results == true and state.results_ready == true
	state.reuse_next_capture_results = nil

	if not reuse_results then
		scan(runtime, view, state)
	end
	if not query_is_active(state) and type(view._offer_items_layout) == "table" and #view._offer_items_layout > 0 then
		state.warm_cursor = 1
		view._better_inventory_search_needs_update = true
	end

	return true
end

local function insert_external_entries(result, external_entries)
	for index = 1, #external_entries do
		local external = external_entries[index]
		local insertion_index = math.min(external.index, #result + 1)

		table.insert(result, insertion_index, external.entry)
	end
end

SearchRuntime.compose_layout = function(runtime, view, layout)
	local state = state_for(runtime, view, true)

	if not state or type(layout) ~= "table" then
		return layout
	end

	state.last_present_arguments = nil
	state.presentation_kind = "external"
	if not state.compiled then
		compile_state(runtime, state)
	end
	scan(runtime, view, state, layout)

	if not query_is_active(state) then
		return layout
	end

	local matches = {}
	local unmatched = {}
	local external_entries = {}
	local hide = mode(runtime) == "hide"

	for index = 1, #layout do
		local entry = layout[index]
		local item = item_from(entry)

		if not item then
			external_entries[#external_entries + 1] = {
				entry = entry,
				index = index,
			}
		else
			local matched = result_for(state, entry)

			if matched == nil then
				matched = result_for(state, item)
			end

			if matched == true then
				matches[#matches + 1] = entry
			elseif not hide then
				unmatched[#unmatched + 1] = entry
			end
		end
	end

	for index = 1, #unmatched do
		matches[#matches + 1] = unmatched[index]
	end
	insert_external_entries(matches, external_entries)

	return matches
end

SearchRuntime.set_query = function(runtime, view, query, now)
	local state = state_for(runtime, view, true)

	if not state then
		return false
	end

	query = type(query) == "string" and query or tostring(query or "")

	-- Native input polling can repeat the same value around focus and hot-reload
	-- transitions. Keep those duplicates allocation-free and do not extend the
	-- coalescing deadline when the effective query did not change.
	if state.query == query then
		return state.compiled == nil or state.compiled.valid == true, state.error
	end

	state.query = query
	recover_presentation_context(runtime, view, state)
	-- Do not parse or scan the full inventory for every character in a quickly
	-- typed or pasted query. The existing 80 ms deadline now coalesces parsing,
	-- projection, matching, alpha updates, and sorting as one settled-query
	-- transaction. Until then, ranks fail open instead of mixing the new source
	-- with the previous generation's compiled clauses and results.
	state.compiled = nil
	state.error = nil
	state.results_ready = false
	view._better_inventory_search_rank_active = nil
	view._better_inventory_search_filter_active = nil
	view._better_inventory_search_needs_update = true
	schedule_present(runtime, state, now)
	if query == "" then
		SearchRuntime.apply_widget_alpha(runtime, view)
	end

	return true, nil
end

SearchRuntime.refresh = function(runtime, view, now)
	local state = state_for(runtime, view, false)

	if not state then
		return false
	end

	if not state.compiled then
		compile_state(runtime, state)
	end
	scan(runtime, view, state)
	view._better_inventory_search_needs_update = true
	schedule_present(runtime, state, now)
	SearchRuntime.apply_widget_alpha(runtime, view)

	return true
end

SearchRuntime.native_filter = function(runtime, view, entry, native_result)
	if native_result ~= true then
		return false
	end

	local state = state_for(runtime, view, false)

	if not query_is_active(state) or state.results_ready ~= true or mode(runtime) ~= "hide" then
		return true
	end

	local result, found = result_for(state, entry)

	if not found then
		result, found = result_for(state, item_from(entry))
	end

	if not found then
		local rank
		result, rank = entry_result(runtime, state, entry, view)
		set_result(state, entry, result, rank)
	end

	return result == true
end

SearchRuntime.rank = function(runtime, view, entry)
	local state = state_for(runtime, view, false)

	if not query_is_active(state) or state.results_ready ~= true then
		return 0
	end

	local result, found, rank = result_for(state, entry)

	if not found then
		result, found, rank = result_for(state, item_from(entry))
	end

	if not found then
		result, rank = entry_result(runtime, state, entry, view)
		set_result(state, entry, result, rank)
	end

	return result == true and rank or 0
end

SearchRuntime.apply_widget_alpha = function(runtime, view)
	local state = state_for(runtime, view, false)

	if not state then
		return false
	end

	local active = query_is_active(state) and state.results_ready == true and mode(runtime) == "dim"
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
		-- ViewElementGrid uses `content.element` for live Darktide cards. Some
		-- integrations expose the same layout entry as `content.entry`.
		local entry = content and (content.entry or content.element)
		local matched, found = result_for(state, entry)

		if not found and entry then
			matched, found = result_for(state, item_from(entry))
		end

		if active and matched == false then
			local original = state.owned_widget_alpha[widget]

			if original == nil and type(content) == "table" then
				original = tonumber(content.alpha_multiplier) or 1
				state.owned_widget_alpha[widget] = original
			end

			if original ~= nil and content.alpha_multiplier == original then
				content.alpha_multiplier = original * runtime.dim_alpha
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

	if not state or state.faulted then
		if view then
			view._better_inventory_search_rank_active = nil
			view._better_inventory_search_filter_active = nil
			view._better_inventory_search_needs_update = nil
		end
		return false
	end

	if not state.pending_present_at then
		if state.warm_cursor then
			warm_projection_cache(runtime, view, state)
		end
		if not state.warm_cursor then
			view._better_inventory_search_needs_update = nil
		end
		return false
	end

	now = tonumber(now) or safe_call(runtime.dependencies.time) or 0

	if now < state.pending_present_at then
		warm_projection_cache(runtime, view, state)
		return false
	end

	-- Never combine the final cache-warming batch with the full match pass in
	-- one frame. A cold 128-item inventory is therefore bounded to sixteen rich
	-- projections per frame, while already-warm inventories proceed directly.
	if state.warm_cursor then
		warm_projection_cache(runtime, view, state)
		return false
	end

	state.pending_present_at = nil
	if not state.compiled then
		compile_state(runtime, state)
	end
	if state.results_ready ~= true then
		scan(runtime, view, state, nil, true)
	end
	local current_mode = mode(runtime)
	local ok

	-- Dim/promote keeps every card. Prefer a synchronous ViewElementGrid
	-- reorder that preserves widget identities, loaded icons, and card-owned
	-- resources. Hide mode still needs the native filter transaction, and the
	-- first dim commit after hide must rebuild full membership once.
	if current_mode == "dim" and state.committed_mode ~= "hide" then
		ok = safe_call(runtime.dependencies.reorder, view)
	end

	if ok ~= true then
		if state.presentation_kind == "external" then
			ok = safe_call(runtime.dependencies.present_external, view)
		else
			local arguments = state.last_present_arguments

			if not arguments then
				return false
			end

			state.reuse_next_capture_results = true
			ok = safe_call(runtime.dependencies.present, view, arguments[3], arguments[2], arguments[1])
			state.reuse_next_capture_results = nil
		end
	end

	if ok == nil then
		state.faulted = true
		view._better_inventory_search_rank_active = nil
		view._better_inventory_search_filter_active = nil
		view._better_inventory_search_needs_update = nil
		return false
	end

	state.committed_mode = current_mode
	SearchRuntime.apply_widget_alpha(runtime, view)
	view._better_inventory_search_needs_update = nil
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
				query = state.query,
			}
		end
	end

	restore_all_widget_alpha(state)
	safe_call(runtime.dependencies.release_grid, view)
	safe_call(runtime.dependencies.release_index, state.index)
	state.ranks = weak_key_table()
	state.last_present_arguments = nil
	state.presentation_kind = nil
	state.projection_context = nil
	state.reuse_next_capture_results = nil
	view._better_inventory_search_rank_active = nil
	view._better_inventory_search_filter_active = nil
	view._better_inventory_search_needs_update = nil
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

SearchRuntime.is_active = function(runtime, view)
	return query_is_active(state_for(runtime, view, false))
end

return SearchRuntime
