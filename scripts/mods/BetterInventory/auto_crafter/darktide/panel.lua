local UISoundEvents = require("scripts/settings/ui/ui_sound_events")

local Panel = {}

local PANEL_REFERENCE = "auto_crafter_diagnostic_panel"
local PANEL_WIDTH = 500
local PANEL_HEIGHT = 650
local PANEL_X = 1280
local PANEL_Y = 110
local ROW_HEIGHT = 36
local ROW_SPACING = 4
local MAX_OFFER_ROWS = 10

local function safe_call(fn, ...)
	if type(fn) ~= "function" then
		return false, "method unavailable"
	end

	return pcall(fn, ...)
end

local function value_text(value, fallback)
	if value == nil or value == "" then
		return fallback or "?"
	end

	return tostring(value)
end

local function wallet_amount(snapshot, currency)
	local wallets = snapshot and snapshot.wallets
	local currencies = wallets and wallets.currencies
	local entry = currencies and currencies[currency]

	return entry and entry.amount
end

local function row_passes(width)
	local label_width = width - 210

	return {
		{
			content_id = "hotspot",
			pass_type = "hotspot",
			content = {
				on_hover_sound = UISoundEvents.default_mouse_hover,
				on_pressed_sound = UISoundEvents.default_click,
			},
			style = {
				size = {
					width,
					ROW_HEIGHT,
				},
			},
			visibility_function = function(content)
				return content.selectable == true
			end,
		},
		{
			pass_type = "rect",
			style_id = "header_background",
			style = {
				color = Color.terminal_corner_selected(150, true),
				size = {
					width,
					ROW_HEIGHT,
				},
				offset = {
					0,
					0,
					0,
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
				color = Color.terminal_corner_selected(110, true),
				size = {
					width,
					ROW_HEIGHT,
				},
				offset = {
					0,
					0,
					0,
				},
			},
			visibility_function = function(content)
				return content.header ~= true and content.selected == true
			end,
		},
		{
			pass_type = "rect",
			style_id = "normal_background",
			style = {
				color = Color.terminal_background(160, true),
				size = {
					width,
					ROW_HEIGHT,
				},
				offset = {
					0,
					0,
					0,
				},
			},
			visibility_function = function(content)
				return content.header ~= true and content.selected ~= true
			end,
		},
		{
			pass_type = "text",
			style_id = "label",
			value_id = "label",
			style = {
				font_size = 17,
				font_type = "proxima_nova_bold",
				horizontal_alignment = "left",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "center",
				vertical_alignment = "center",
				text_color = Color.terminal_text_body(255, true),
				offset = {
					12,
					0,
					2,
				},
				size = {
					label_width,
					ROW_HEIGHT,
				},
			},
		},
		{
			pass_type = "text",
			style_id = "detail",
			value_id = "detail",
			style = {
				font_size = 15,
				font_type = "proxima_nova_medium",
				horizontal_alignment = "right",
				text_horizontal_alignment = "right",
				text_vertical_alignment = "center",
				vertical_alignment = "center",
				text_color = Color.terminal_text_body_sub_header(255, true),
				offset = {
					label_width,
					0,
					2,
				},
				size = {
					width - label_width - 12,
					ROW_HEIGHT,
				},
			},
		},
	}
end

local BLUEPRINTS = {
	auto_crafter_row = {
		size_function = function(_, entry)
			return entry.size
		end,
		pass_template_function = function(_, entry)
			return row_passes(entry.size[1])
		end,
		init = function(_, widget, entry)
			for key, value in pairs(entry.initial_content or {}) do
				widget.content[key] = type(value) == "table" and table.clone(value) or value
			end

			widget.content.entry = entry

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

local function offer_key(offer)
	return offer and (offer.offer_id or offer.master_id or offer.display_name)
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
		_localize = dependencies.localize,
		_logger = dependencies.logger,
		_ViewElementGrid = dependencies.ViewElementGrid,
		_panel = nil,
		_view = nil,
		_snapshot = nil,
		_phase = "idle",
		_selected_offer_id = nil,
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
				hotspot = {},
				label = label or "",
				selectable = options.selectable == true,
				selected = false,
			},
			pass_template = nil,
			size = {
				PANEL_WIDTH - 20,
				ROW_HEIGHT,
			},
			widget_type = "auto_crafter_row",
		}

		if options.offer then
			entry.offer = options.offer
			entry.bind = function(widget)
				widget.content.hotspot.pressed_callback = function()
					self._selected_offer_id = offer_key(options.offer)
				end
			end
			entry.refresh = function(widget)
				widget.content.selected = self._selected_offer_id ~= nil and self._selected_offer_id == offer_key(options.offer)
			end
		end

		return entry
	end

	function self:_entries(snapshot)
		local store = snapshot and snapshot.store or {}
		local offers = store.offers or {}
		local selected = self._selected_offer_id and "selected" or localize("auto_crafter_panel_no_target", "no target selected")
		local entries = {
			self:_entry(localize("auto_crafter_panel_title", "Auto Crafter Helper"), localize("auto_crafter_panel_read_only", "READ-ONLY"), {
				header = true,
			}),
			self:_entry(localize("auto_crafter_panel_status", "Status"), self._phase or value_text(snapshot and snapshot.phase, "idle")),
			self:_entry(localize("auto_crafter_panel_offers", "Offers"), value_text(store.offer_count, "?")),
			self:_entry(localize("auto_crafter_panel_wallet", "Wallet"), string.format("%s / %s / %s", value_text(wallet_amount(snapshot, "credits")), value_text(wallet_amount(snapshot, "plasteel")), value_text(wallet_amount(snapshot, "diamantine")))),
			self:_entry(localize("auto_crafter_panel_gear", "Gear"), value_text(snapshot and snapshot.gear and snapshot.gear.item_count, "?")),
			self:_entry(localize("auto_crafter_panel_target", "Target"), selected),
			self:_entry(localize("auto_crafter_panel_offer_list", "Weapon offers (click to select)"), "", {
				header = true,
			}),
		}

		local shown = 0

		for index, offer in ipairs(offers) do
			if shown >= MAX_OFFER_ROWS then
				break
			end

			if offer then
				shown = shown + 1
				table.insert(entries, self:_entry(offer_label(offer, index), offer_detail(offer), {
					offer = offer,
					selectable = true,
				}))
			end
		end

		if shown == 0 then
			table.insert(entries, self:_entry(localize("auto_crafter_panel_no_offers", "No weapon offers exposed yet."), ""))
		elseif tonumber(store.offer_count) and tonumber(store.offer_count) > shown then
			table.insert(entries, self:_entry(localize("auto_crafter_panel_more", "More offers available"), tostring(store.offer_count - shown) .. " not shown"))
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

		local present_ok, present_error = safe_call(self._panel.present_grid_layout, self._panel, entries, BLUEPRINTS)

		if not present_ok then
			log("error", "Auto Crafter diagnostic panel could not present layout: " .. tostring(present_error))
		end

		return present_ok
	end

	function self:set_phase(phase, snapshot)
		self._phase = phase or self._phase

		return self:render(snapshot)
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
		self._phase = "view_ready"
		self._selected_offer_id = nil

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
		self._phase = "idle"
		self._selected_offer_id = nil
	end

	return self
end

Panel.PANEL_REFERENCE = PANEL_REFERENCE

return Panel
