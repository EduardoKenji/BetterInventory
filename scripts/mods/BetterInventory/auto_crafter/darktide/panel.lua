local UISoundEvents = require("scripts/settings/ui/ui_sound_events")

local Panel = {}

local PANEL_REFERENCE = "auto_crafter_diagnostic_panel"
local PANEL_WIDTH = 445
local PANEL_HEIGHT = 520
local PANEL_X = 1380
local PANEL_Y = 110
local ROW_HEIGHT = 32
local SECTION_ROW_HEIGHT = 40
local ROW_SPACING = 4
local MAX_OFFER_ROWS = 10
local MAX_SELECTION_ATTEMPTS = 240
local SECTION_PLANNER = "planner"
local SECTION_MELEE = "melee"
local SECTION_RANGED = "ranged"

local function safe_call(fn, ...)
	if type(fn) ~= "function" then
		return false, "method unavailable"
	end

	return pcall(fn, ...)
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

local function wallet_amount(snapshot, currency)
	local wallets = snapshot and snapshot.wallets
	local currencies = wallets and wallets.currencies
	local entry = currencies and currencies[currency]

	return entry and entry.amount
end

local function row_passes(width, height)
	local label_width = width - 210

	local function selected(content)
		return content.header ~= true and content.selected == true
	end

	local function not_selected(content)
		return content.header ~= true and content.selected ~= true
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
			style_id = "header_background",
			style = {
				color = Color.terminal_background(210, true),
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
			visibility_function = function(content)
				return content.header == true
			end,
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
			style_id = "header_label",
			value_id = "label",
			style = {
				font_size = 18,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_header(255, true),
				offset = {
					10,
					0,
					4,
				},
				size = {
					width - 50,
					height,
				},
			},
			visibility_function = function(content)
				return content.header == true
			end,
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
					label_width,
					0,
					4,
				},
				size = {
					width - label_width - 34,
					height,
				},
			},
			visibility_function = function(content)
				return content.section_header ~= true and content.selected ~= true
			end,
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
					label_width,
					0,
					4,
				},
				size = {
					width - label_width - 34,
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
		{
			pass_type = "text",
			style_id = "chevron",
			value_id = "chevron",
			style = {
				font_size = 18,
				font_type = "proxima_nova_bold",
				horizontal_alignment = "right",
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_header(255, true),
				offset = {
					0,
					0,
					4,
				},
				size = {
					40,
					height,
				},
			},
			visibility_function = function(content)
				return content.section_header == true
			end,
		},
	}
end

local BLUEPRINTS = {
	auto_crafter_row = {
		size_function = function(_, entry)
			return entry.size
		end,
		pass_template_function = function(_, entry)
			return row_passes(entry.size[1], entry.size[2])
		end,
		init = function(parent, widget, entry, callback_name)
			for key, value in pairs(entry.initial_content or {}) do
				widget.content[key] = type(value) == "table" and table.clone(value) or value
			end

			widget.content.entry = entry
			widget.content.element = entry

			if callback_name and widget.content.hotspot then
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
		_preview_plan = dependencies.preview_plan,
		_settings = dependencies.settings or {},
		_localize = dependencies.localize,
		_logger = dependencies.logger,
		_ViewElementGrid = dependencies.ViewElementGrid,
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
		_section_collapsed = {
			[SECTION_PLANNER] = false,
			[SECTION_MELEE] = true,
			[SECTION_RANGED] = true,
		},
		_pending_offer = nil,
		_pending_offer_attempts = 0,
		_layout_pending = false,
	}

	local function localize(setting_id, fallback)
		if type(self._localize) ~= "function" then
			return fallback or setting_id
		end

		local ok, text = pcall(self._localize, setting_id)

		return ok and text or fallback or setting_id
	end

	local function log(level, message)
		local logger = self._logger and self._logger[level]

		if type(logger) == "function" then
			pcall(logger, self._logger, message)
		end
	end

	function self:_entry(label, detail, options)
		options = options or {}

		local entry = {
			initial_content = {
				detail = detail or "",
				header = options.header == true,
				hotspot = {
					disabled = options.selectable ~= true,
				},
				label = label or "",
				selectable = options.selectable == true,
				section_header = options.section_header == true,
				section_id = options.section_id,
				selected = false,
				chevron = "",
			},
			pass_template = nil,
			size = {
				PANEL_WIDTH - 20,
				options.header and SECTION_ROW_HEIGHT or ROW_HEIGHT,
			},
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
					self._layout_pending = true
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
					selected_display_name = offer.display_name

					break
				end
			end
		end

		if selected_display_name then
			return offers, selected_display_name
		end

		return offers, selected_offer and localize("auto_crafter_panel_selected_weapon", "Selected weapon") or localize("auto_crafter_panel_no_target", "no weapon selected")
	end

	function self:_setting(setting_id, default_value)
		local get = self._settings and self._settings.get

		if type(get) ~= "function" then
			return default_value
		end

		local ok, value = pcall(get, self._settings, setting_id)

		return ok and value ~= nil and value or default_value
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

	function self:_planner_target_text()
		local _, current_weapon = self:_selected_offers(self._snapshot)

		return current_weapon or localize("auto_crafter_panel_no_target", "no weapon selected")
	end

	function self:_planner_dump_stat_text()
		local value = self:_setting("auto_crafter_target_dump_stat", "damage")

		if value == "auto" then
			return localize("auto_crafter_dump_stat_auto", "Auto-discover (future)")
		end

		return localize("auto_crafter_dump_stat_damage", "Damage")
	end

	function self:_planner_request_mode_text()
		local value = self:_setting("auto_crafter_request_mode", "sequential")

		if value == "parallel_reads" then
			return localize("auto_crafter_request_mode_parallel_reads", "Parallel reads")
		elseif value == "experimental_parallel_mutations" then
			return localize("auto_crafter_request_mode_experimental", "Experimental parallel mutations")
		end

		return localize("auto_crafter_request_mode_sequential", "Sequential (recommended)")
	end

	function self:_planner_fallback_text()
		return self:_setting("auto_crafter_best_candidate_fallback", false) == true and localize("auto_crafter_value_on", "On") or localize("auto_crafter_value_off", "Off")
	end

	function self:_split_offers(offers)
		local grouped = {
			[SECTION_MELEE] = {},
			[SECTION_RANGED] = {},
		}

		for _, offer in ipairs(offers or {}) do
			if offer then
				local section_id = offer.weapon_category == SECTION_RANGED and SECTION_RANGED or SECTION_MELEE

				grouped[section_id][#grouped[section_id] + 1] = offer
			end
		end

		return grouped
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
		local offers, selected_weapon = self:_selected_offers(snapshot)
		local grouped_offers = self:_split_offers(offers)
		local selected = selected_weapon or localize("auto_crafter_panel_no_target", "no weapon selected")
		local plan = self._plan or snapshot and snapshot.plan
		local entries = {
			self:_entry(localize("auto_crafter_panel_title", "Auto Crafter Helper"), localize("auto_crafter_panel_read_only", "READ-ONLY"), {
				header = true,
			}),
			self:_entry(localize("auto_crafter_panel_status", "Status"), self._phase or value_text(snapshot and snapshot.phase, "idle"), {
				refresh = function(widget)
					widget.content.detail = self._phase or value_text(self._controller_state and self._controller_state.phase, "idle")
				end,
			}),
			self:_entry(localize("auto_crafter_panel_offers", "Offers"), value_text(store.offer_count, "?")),
			self:_entry(localize("auto_crafter_panel_wallet", "Wallet"), string.format("%s / %s / %s", value_text(wallet_amount(snapshot, "credits")), value_text(wallet_amount(snapshot, "plasteel")), value_text(wallet_amount(snapshot, "diamantine")))),
			self:_entry(localize("auto_crafter_panel_gear", "Gear"), value_text(snapshot and snapshot.gear and snapshot.gear.item_count, "?")),
			self:_entry(localize("auto_crafter_panel_target", "Target"), selected, {
				refresh = function(widget)
					local _, current_weapon = self:_selected_offers(self._snapshot)

					widget.content.detail = current_weapon or localize("auto_crafter_panel_no_target", "no weapon selected")
				end,
			}),
			self:_entry(localize("auto_crafter_panel_planner", "Planner configuration"), localize("auto_crafter_panel_read_only", "READ-ONLY"), {
				header = true,
				selectable = true,
				section_header = true,
				section_id = SECTION_PLANNER,
			}),
		}

		if not self._section_collapsed[SECTION_PLANNER] then
			table.insert(entries, self:_entry(localize("auto_crafter_panel_planner_target", "Planner target"), self:_planner_target_text(), {
				refresh = function(widget)
					widget.content.detail = self:_planner_target_text()
				end,
			}))
			table.insert(entries, self:_entry(localize("auto_crafter_panel_dump_stat", "Dump stat"), self:_planner_dump_stat_text(), {
				selectable = true,
				action = function()
					self:_cycle_setting("auto_crafter_target_dump_stat", { "damage", "auto" }, "damage")
				end,
				refresh = function(widget)
					widget.content.detail = self:_planner_dump_stat_text()
				end,
			}))
			table.insert(entries, self:_entry(localize("auto_crafter_panel_dump_target", "Dump target"), integer_text(self:_setting("auto_crafter_dump_stat_target", 60)), {
				refresh = function(widget)
					widget.content.detail = integer_text(self:_setting("auto_crafter_dump_stat_target", 60))
				end,
			}))
			table.insert(entries, self:_entry(localize("auto_crafter_panel_docket_cap", "Docket cap"), integer_text(self:_setting("auto_crafter_docket_cap", 1000000)), {
				selectable = true,
				action = function()
					self:_cycle_setting("auto_crafter_docket_cap", { 100000, 200000, 300000, 500000, 1000000 }, 1000000)
				end,
				refresh = function(widget)
					widget.content.detail = integer_text(self:_setting("auto_crafter_docket_cap", 1000000))
				end,
			}))
			table.insert(entries, self:_entry(localize("auto_crafter_panel_max_purchases", "Max purchases"), integer_text(self:_setting("auto_crafter_max_purchases", 100)), {
				selectable = true,
				action = function()
					self:_cycle_setting("auto_crafter_max_purchases", { 10, 25, 50, 100, 250, 500 }, 100)
				end,
				refresh = function(widget)
					widget.content.detail = integer_text(self:_setting("auto_crafter_max_purchases", 100))
				end,
			}))
			table.insert(entries, self:_entry(localize("auto_crafter_panel_best_fallback", "Best-candidate fallback"), self:_planner_fallback_text(), {
				selectable = true,
				action = function()
					self:_set_setting("auto_crafter_best_candidate_fallback", not (self:_setting("auto_crafter_best_candidate_fallback", false) == true))
				end,
				refresh = function(widget)
					widget.content.detail = self:_planner_fallback_text()
				end,
			}))
			table.insert(entries, self:_entry(localize("auto_crafter_panel_request_mode", "Request mode"), self:_planner_request_mode_text(), {
				selectable = true,
				action = function()
					self:_cycle_setting("auto_crafter_request_mode", { "sequential", "parallel_reads", "experimental_parallel_mutations" }, "sequential")
				end,
				refresh = function(widget)
					widget.content.detail = self:_planner_request_mode_text()
				end,
			}))
			table.insert(entries, self:_entry(localize("auto_crafter_panel_estimate", "Estimate"), plan and plan.estimate and plan.estimate.summary or localize("auto_crafter_panel_waiting", "waiting for probe"), {
				refresh = function(widget)
					local current_plan = self._plan

					widget.content.detail = current_plan and current_plan.estimate and current_plan.estimate.summary or localize("auto_crafter_panel_waiting", "waiting for probe")
				end,
			}))
			table.insert(entries, self:_entry(localize("auto_crafter_panel_preflight", "Preflight"), plan and plan.preflight and plan.preflight.summary or localize("auto_crafter_panel_waiting", "waiting for probe"), {
				refresh = function(widget)
					local current_plan = self._plan

					widget.content.detail = current_plan and current_plan.preflight and current_plan.preflight.summary or localize("auto_crafter_panel_waiting", "waiting for probe")
				end,
			}))
			table.insert(entries, self:_entry(localize("auto_crafter_panel_preview", "Preview plan"), localize("auto_crafter_panel_read_only_preview", "READ-ONLY; no mutations"), {
				selectable = true,
				action = function()
					if type(self._preview_plan) == "function" then
						self._preview_plan()
					end
				end,
			}))
		end

		table.insert(entries, self:_entry(localize("auto_crafter_panel_offer_list", "Weapon offers"), string.format("%s / %s", tostring(#offers), value_text(store.offer_count, "?")), {
			header = true,
		}))

		for _, section_id in ipairs({ SECTION_MELEE, SECTION_RANGED }) do
			local section_offers = grouped_offers[section_id]
			local section_label = section_id == SECTION_RANGED and localize("auto_crafter_panel_ranged_weapons", "Ranged Weapons") or localize("auto_crafter_panel_melee_weapons", "Melee Weapons")

			table.insert(entries, self:_entry(section_label, tostring(#section_offers), {
				header = true,
				selectable = true,
				section_header = true,
				section_id = section_id,
			}))

			if not self._section_collapsed[section_id] then
				local shown = 0

				for index, offer in ipairs(section_offers) do
					if shown >= MAX_OFFER_ROWS then
						break
					end

					shown = shown + 1
					table.insert(entries, self:_entry(offer_label(offer, index), offer_detail(offer), {
						offer = offer,
						selectable = true,
					}))
				end

				if shown == 0 then
					table.insert(entries, self:_entry(localize("auto_crafter_panel_no_offers", "No weapon offers exposed yet."), ""))
				elseif #section_offers > shown then
					table.insert(entries, self:_entry(localize("auto_crafter_panel_more", "More offers available"), tostring(#section_offers - shown) .. " not shown"))
				end
			end
		end

		return entries
	end

	function self:render(snapshot)
		self._snapshot = snapshot or self._snapshot

		if not self._panel or type(self._panel.present_grid_layout) ~= "function" then
			return false
		end

		local entries = self:_entries(self._snapshot)

		local height_ok = safe_call(self._panel.update_grid_height, self._panel, PANEL_HEIGHT, PANEL_HEIGHT)

		if not height_ok then
			log("error", "Auto Crafter diagnostic panel could not set its grid height.")
		end

		local function on_row_clicked(_, entry)
			if entry and entry.offer then
				self:_select_offer_from_row(entry.offer)
			end
		end

		local present_ok, present_error = safe_call(self._panel.present_grid_layout, self._panel, entries, BLUEPRINTS, on_row_clicked)

		if not present_ok then
			log("error", "Auto Crafter diagnostic panel could not present layout: " .. tostring(present_error))
		end

		return present_ok
	end

	function self:set_phase(phase, snapshot)
		self._phase = phase or self._phase

		return self:render(snapshot)
	end

	function self:sync_controller_snapshot(state)
		if type(state) ~= "table" then
			return false
		end

		self._controller_state = state
		self._phase = state.phase or self._phase
		self._snapshot = state.data or self._snapshot
		self._plan = state.plan

		return true
	end

	function self:update()
		if not self._view or self._view._destroyed or type(self._get_selected_offer) ~= "function" then
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

		if self._layout_pending then
			self._layout_pending = false
			self:render()
		end
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
			bottom_chin = 10,
			edge_padding = 0,
			enable_gamepad_scrolling = true,
			grid_size = {
				PANEL_WIDTH,
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
			top_padding = 10,
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
		self._section_collapsed = {
			[SECTION_PLANNER] = false,
			[SECTION_MELEE] = true,
			[SECTION_RANGED] = true,
		}
		self._pending_offer = nil
		self._pending_offer_attempts = 0
		self._layout_pending = false

		if type(panel.set_pivot_offset) == "function" then
			panel:set_pivot_offset(PANEL_X, PANEL_Y)
		end

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
		self._section_collapsed = {
			[SECTION_PLANNER] = false,
			[SECTION_MELEE] = true,
			[SECTION_RANGED] = true,
		}
		self._pending_offer = nil
		self._pending_offer_attempts = 0
		self._layout_pending = false
	end

	return self
end

Panel.PANEL_REFERENCE = PANEL_REFERENCE

return Panel
