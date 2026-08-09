local AutoCrafter = {}

local mod
local controller
local panel
local hud_lines = {}
local presentation_dirty = true
local presentation_elapsed = 0
local presentation_snapshot
local PRESENTATION_CLOCK_INTERVAL = 0.25

local function monotonic_now()
	local application = rawget(_G, "Application")

	if application and type(application.time_since_launch) == "function" then
		local ok, value = pcall(application.time_since_launch)

		return ok and tonumber(value) or nil
	end

	return nil
end

local function format_elapsed(seconds)
	local total = math.max(0, math.floor((tonumber(seconds) or 0) + 0.5))
	local hours = math.floor(total / 3600)
	local minutes = math.floor(total % 3600 / 60)
	local remaining = total % 60

	if hours > 0 then
		return string.format("%dh %02dm %02ds", hours, minutes, remaining)
	end

	if minutes > 0 then
		return string.format("%dm %02ds", minutes, remaining)
	end

	return string.format("%ds", remaining)
end

local function format_number(value)
	local text = tostring(math.max(0, math.floor((tonumber(value) or 0) + 0.5)))
	local changed

	repeat
		text, changed = string.gsub(text, "^(-?%d+)(%d%d%d)", "%1,%2")
	until changed == 0

	return text
end

local function format_resource_costs(costs)
	costs = costs or {}

	return string.format(
		"Invested: %s Ordo Dockets | %s Plasteel | %s Diamantine",
		format_number(costs.credits),
		format_number(costs.plasteel),
		format_number(costs.diamantine)
	)
end

local function localize(setting_id, fallback)
	if not mod or type(mod.localize) ~= "function" then
		return fallback or setting_id
	end

	local ok, text = pcall(mod.localize, mod, setting_id)

	return ok and text or fallback or setting_id
end

local function setting(setting_id, default_value)
	if not mod or type(mod.get) ~= "function" then
		return default_value
	end

	local ok, value = pcall(mod.get, mod, setting_id)

	if not ok or value == nil then
		return default_value
	end

	return value
end

local function log(level, message)
	if not mod then
		return
	end

	local logger = mod[level]

	if type(logger) == "function" then
		pcall(logger, mod, message)
	end
end

local function notification_enabled()
	return setting("auto_crafter_show_probe_notifications", true) ~= false
end

local function notify(title, description)
	if not notification_enabled() then
		return false
	end

	local managers = rawget(_G, "Managers")
	local event_manager = managers and managers.event

	if not event_manager or type(event_manager.trigger) ~= "function" then
		return false
	end

	local ok = pcall(event_manager.trigger, event_manager, "event_add_notification_message", "custom", {
		line_1 = title,
		line_2 = description,
	})

	return ok
end

local function format_probe(snapshot)
	local store = snapshot and snapshot.store or {}
	local wallets = snapshot and snapshot.wallets or {}
	local currencies = wallets.currencies or {}
	local credits = currencies.credits and currencies.credits.amount
	local plasteel = currencies.plasteel and currencies.plasteel.amount
	local diamantine = currencies.diamantine and currencies.diamantine.amount

	return string.format(
		"Offers %s | Gear %s | Dockets %s | Plasteel %s | Diamantine %s",
		tostring(store.offer_count or 0),
		tostring((snapshot.gear and snapshot.gear.item_count) or 0),
		tostring(credits or "?"),
		tostring(plasteel or "?"),
		tostring(diamantine or "?")
	)
end

local function format_plan(plan)
	if not plan then
		return "Read-only planner is waiting for probe data."
	end

	local preflight = plan.preflight and plan.preflight.summary or "preflight unavailable"
	local estimate = plan.estimate and plan.estimate.summary or "estimate unavailable"

	return string.format("%s | %s | %s", preflight, estimate, plan.mode_note or "sequential requests")
end

local function format_catalog(catalog)
	if not catalog or catalog.available ~= true then
		return "Weapon trait discovery unavailable: " .. tostring(catalog and catalog.reason or "unknown reason")
	end

	return string.format(
		"Selected weapon catalogue | Perks %s | Blessings %s",
		tostring(catalog.perk_count or 0),
		tostring(catalog.blessing_count or 0)
	)
end

local function game_localize(key)
	if type(key) ~= "string" or key == "" then
		return nil
	end

	local fn = rawget(_G, "Localize")

	if type(fn) ~= "function" then
		return nil
	end

	local ok, value = pcall(fn, key)

	return ok and type(value) == "string" and value ~= key and value or nil
end

local function readable_stat_name(candidate)
	local localized = game_localize(candidate and candidate.dump_stat_label)

	if localized then
		return localized
	end

	local stat_id = tostring(candidate and candidate.dump_stat_id or "stat")
	local readable = string.gsub(stat_id, "^.*[/_]m%d+[_/]", "")
	readable = string.gsub(readable, "_stat$", "")
	readable = string.gsub(readable, "_", " ")
	readable = string.gsub(readable, "(%a)([%w']*)", function(first, rest)
		return string.upper(first) .. rest
	end)

	return readable
end

local function format_candidate(candidate)
	if not candidate then
		return "weapon details unavailable"
	end

	return string.format(
		"%s — %s %s, item level %s",
		tostring(candidate.display_name or candidate.mastery_id or "weapon"),
		readable_stat_name(candidate),
		tostring(candidate.dump_stat or "?"),
		tostring(candidate.expertise_level or candidate.base_item_level or "?")
	)
end

local function search_stop_message(reason)
	local messages = {
		operation_failed = "Crafting stopped because a game operation failed.",
		run_configuration_changed = "Crafting stopped because its configuration changed.",
		search_blocked = "Crafting could not continue with current settings.",
		search_docket_cap = "Stopped after reaching Ordo dockets limit.",
		search_insufficient_dockets = "Stopped because available Ordo dockets are insufficient.",
		search_max_purchases = "Stopped after reaching weapon purchase limit.",
		search_offer_missing = "Stopped because frozen Brunt weapon offer became unavailable.",
		user_stopped = "Crafting stopped by user.",
	}

	return messages[reason] or "Crafting stopped for safety."
end

local function progress_milestone(value, interval)
	local count = tonumber(value) or 0

	return count == 1 or count > 0 and count % interval == 0
end

local function rebuild_hud_lines(snapshot)
	local lines = {}
	local search = snapshot and snapshot.search
	local phase3 = snapshot and snapshot.phase3
	local phase4 = snapshot and snapshot.phase4
	local last_error = snapshot and snapshot.last_error

	if last_error then
		lines[#lines + 1] = "AUTO CRAFTER FAILED: " .. tostring(last_error)
		lines[#lines + 1] = string.format("Stopped at %s%s", tostring(snapshot.phase or "unknown phase"), snapshot.operation_kind and " (" .. tostring(snapshot.operation_kind) .. ")" or "")
		lines[#lines + 1] = "Weapon preserved at last confirmed step. Check BetterInventory log for full trace."
		lines[#lines + 1] = string.format("Elapsed: %d seconds", math.max(0, math.floor(tonumber(snapshot.run_elapsed_seconds) or 0)))
		hud_lines = lines

		return
	end

	if search and search.running and not search.result then
		lines[#lines + 1] = "Searching for perfect dump-stat weapon"
	end

	if phase3 and phase3.running then
		local level = phase3.current and tonumber(phase3.current.mastery_level)
		lines[#lines + 1] = level and string.format("Leveling weapon mastery to 20 (%d/20)", level) or "Leveling weapon mastery to 20"
	end

	if phase4 and phase4.running then
		local item = phase4.current_item or {}
		if phase4.consecrate and (tonumber(item.rarity) or 0) < 5 then
			lines[#lines + 1] = "Consecrating weapon to Transcendent"
		end
		if phase4.expertise and (tonumber(item.expertise_level) or 0) < 500 then
			lines[#lines + 1] = string.format("Upgrading weapon level to 500 (%s/500)", tostring(item.expertise_level or "?"))
		end
		local points_spent = tonumber(phase4.blessing_points_spent)
		local points_total = tonumber(phase4.blessing_points_total)
		local allocating_points = phase4.allocate_mastery and (points_total == nil or points_spent == nil or points_spent < points_total)

		if allocating_points then
			lines[#lines + 1] = points_spent and points_total and points_total > 0 and string.format("Allocating mastery blessing points (%d/%d)", points_spent, points_total) or "Allocating mastery blessing points"
		elseif phase4.targets and (next(phase4.targets.perks or {}) ~= nil or next(phase4.targets.traits or {}) ~= nil) then
			lines[#lines + 1] = "Applying selected perks and blessings"
		end
	elseif phase4 and phase4.elapsed_seconds ~= nil then
		local now = monotonic_now()
		local recently_completed = not phase4.completed_at or not now or now - phase4.completed_at <= 12

		if recently_completed then
			lines[#lines + 1] = "Crafting complete in " .. format_elapsed(phase4.elapsed_seconds)
			lines[#lines + 1] = format_resource_costs(phase4.resource_costs or snapshot and snapshot.resource_costs)
		end
	end

	local run_active = search and search.running or phase3 and phase3.running or phase4 and phase4.running or snapshot and snapshot.mastery and snapshot.mastery.running

	if run_active then
		lines[#lines + 1] = "Step: " .. tostring(snapshot and snapshot.phase or "unknown")
		lines[#lines + 1] = format_resource_costs(snapshot and snapshot.resource_costs)
		lines[#lines + 1] = string.format("Elapsed: %d seconds", math.max(0, math.floor(tonumber(snapshot and snapshot.run_elapsed_seconds) or 0)))
	end

	hud_lines = lines
end

local function reporter(ui_panel)
	return {
		emit = function(_, kind, payload)
			presentation_dirty = true

			if kind == "probe_started" then
				if ui_panel then
					ui_panel:set_phase("probe_inflight")
				end

				log("info", "Auto Crafter Helper read-only probe started.")
				notify(localize("auto_crafter_notification_title", "Auto Crafter Helper"), localize("auto_crafter_probe_started", "Read-only probe started."))
			elseif kind == "probe_complete" then
				if ui_panel then
					ui_panel:set_phase("probe_complete", payload)
				end

				log("info", "Auto Crafter Helper read-only probe complete: " .. format_probe(payload))
				notify(localize("auto_crafter_notification_title", "Auto Crafter Helper"), format_probe(payload))
			elseif kind == "probe_failed" then
				if ui_panel then
					ui_panel:set_phase("probe_failed")
				end

				log("error", "Auto Crafter Helper read-only probe failed: " .. tostring(payload and payload.error))
				notify(localize("auto_crafter_notification_title", "Auto Crafter Helper"), string.format("%s: %s", localize("auto_crafter_probe_failed", "Read-only probe failed"), tostring(payload and payload.error)))
			elseif kind == "catalog_discovery_started" then
				if ui_panel then
					ui_panel:set_phase("trait_discovery")
				end

				log("info", "Auto Crafter Helper selected-weapon perk/blessing discovery started.")
			elseif kind == "catalog_discovery_complete" then
				if ui_panel then
					ui_panel:set_phase("probe_complete")
				end

				log("info", "Auto Crafter Helper " .. format_catalog(payload and payload.catalog))
				notify(localize("auto_crafter_notification_title", "Auto Crafter Helper"), format_catalog(payload and payload.catalog))
			elseif kind == "catalog_discovery_failed" then
				if ui_panel then
					ui_panel:set_phase("trait_discovery_failed")
				end

				local discovery_error = payload and payload.error
				local message = discovery_error and "Weapon trait discovery unavailable: " .. tostring(discovery_error) or format_catalog(payload and payload.catalog)
				log("error", "Auto Crafter Helper " .. message)
				notify(localize("auto_crafter_notification_title", "Auto Crafter Helper"), message)
			elseif kind == "plan_preview" then
				log("info", "Auto Crafter Helper read-only plan preview: " .. format_plan(payload and payload.plan))
				notify(localize("auto_crafter_notification_title", "Auto Crafter Helper"), format_plan(payload and payload.plan))
			elseif kind == "mutation_blocked" then
				if ui_panel then
					ui_panel:set_phase("mutation_blocked")
				end

				notify(localize("auto_crafter_notification_title", "Auto Crafter Helper"), "Mutation blocked: " .. tostring(payload and payload.reason or "preflight failed"))
			elseif kind == "purchase_search_started" then
				if ui_panel then
					ui_panel:set_phase(payload and payload.phase3 and "phase3_search_purchase" or "search_purchase")
				end

				local search = payload and payload.search or {}
				local target = search.target_offer or {}
				local cap = search.cap_by_dockets and string.format(" Ordo dockets limit: %s.", tostring(search.docket_cap or "?")) or ""
				notify(localize("auto_crafter_notification_title", "Auto Crafter Helper"), string.format("Started buying %s. Target: %s %s.%s", tostring(target.display_name or "selected weapon"), readable_stat_name({dump_stat_id = search.dump_stat}), tostring(search.target_dump or "?"), cap))
			elseif kind == "purchase_result" then
				if ui_panel then
					ui_panel:set_phase(payload and payload.search and payload.search.phase3 and "phase3_search_purchase" or "search_purchase")
				end

				local search = payload and payload.search or {}

				if progress_milestone(search.purchases, 10) then
					notify(localize("auto_crafter_notification_title", "Auto Crafter Helper"), string.format("Purchased %s weapons. Spent %s Ordo dockets. Best result: %s", tostring(search.purchases or "?"), tostring(search.spent or "?"), format_candidate(search.best)))
				end
			elseif kind == "purchase_search_complete" then
				if ui_panel then
					ui_panel:set_phase("search_complete")
				end

				local prefix = payload and payload.reused_inventory and "Using matching inventory weapon: " or "Found matching weapon: "
				notify(localize("auto_crafter_notification_title", "Auto Crafter Helper"), prefix .. format_candidate(payload and payload.candidate))
			elseif kind == "candidate_favorited" then
				notify(localize("auto_crafter_notification_title", "Auto Crafter Helper"), "Saved matching weapon as favorite: " .. tostring(payload and payload.candidate and payload.candidate.display_name or "weapon"))
			elseif kind == "purchase_search_stopped" then
				if ui_panel then
					ui_panel:set_phase(tostring(payload and payload.reason or "search_stopped"))
				end

				notify(localize("auto_crafter_notification_title", "Auto Crafter Helper"), search_stop_message(payload and payload.reason))
			elseif kind == "phase3_fodder_started" then
				if ui_panel then
					ui_panel:set_phase("phase3_fodder_preflight")
				end

			elseif kind == "phase3_fodder_complete" then
				if ui_panel then
					ui_panel:set_phase("phase3_fodder_complete")
				end
			elseif kind == "phase3_candidate_deferred" then
				if ui_panel then
					ui_panel:set_phase("phase3_candidate_deferred")
				end
			elseif kind == "phase3_deferred_cleanup_complete" then
				if ui_panel then
					ui_panel:set_phase("phase3_deferred_cleanup_complete")
				end

				notify(localize("auto_crafter_notification_title", "Auto Crafter Helper"), string.format("Discarded %d unused purchased weapon(s) after mastery reached level 20.", tonumber(payload and payload.count) or 0))
			elseif kind == "phase3_complete" then
				if ui_panel then
					ui_panel:set_phase("phase3_complete")
				end
			elseif kind == "phase3_stopped" then
				if ui_panel then
					ui_panel:set_phase(tostring(payload and payload.reason or "phase3_stopped"))
				end

				local reason = tostring(payload and payload.reason or "phase3_stopped")

				if string.sub(reason, 1, #"phase3_") == "phase3_" then
					notify(localize("auto_crafter_notification_title", "Auto Crafter Helper"), search_stop_message(reason))
				end
			elseif kind == "mastery_operation_started" then
				if ui_panel then
					ui_panel:set_phase("mastery_preflight")
				end

			elseif kind == "mastery_upgrade_complete" or kind == "mastery_sacrifice_complete" or kind == "mastery_sync_started" or kind == "mastery_poll_result" or kind == "mastery_operation_complete" or kind == "mastery_sync_timeout" then
				if ui_panel then
					ui_panel:set_phase(kind)
				end
			elseif kind == "mastery_level_increased" then
				local current = payload and payload.current or {}
				local current_level = tonumber(current.mastery_level)
				local maximum_level = tonumber(current.mastery_max_level) or 20

				if ui_panel then
					ui_panel:set_phase("mastery_level_increased")
				end

				if current_level then
					notify(localize("auto_crafter_notification_title", "Auto Crafter Helper"), string.format("Weapon mastery reached level %d/%d.", current_level, maximum_level))
				end
			elseif kind == "phase4_started" then
				if ui_panel then
					ui_panel:set_phase("phase4_preflight")
				end
			elseif kind == "phase4_expertise_milestone" then
				local level = tonumber(payload and payload.level)
				if level and level % 100 == 0 then
					notify(localize("auto_crafter_notification_title", "Auto Crafter Helper"), string.format("Weapon level reached %d/500.", level))
				end
			elseif kind == "phase4_complete" then
				if ui_panel then
					ui_panel:set_phase("phase4_complete")
				end
				local elapsed = format_elapsed(payload and payload.elapsed_seconds)
				notify(localize("auto_crafter_notification_title", "Auto Crafter Helper"), "Final weapon crafting complete in " .. elapsed .. ". " .. format_resource_costs(payload and payload.resource_costs) .. ". " .. format_candidate(payload and payload.candidate))
			elseif kind == "operation_failed" then
				if ui_panel then
					ui_panel:set_phase("operation_failed")
				end

				log("error", "Auto Crafter Helper operation failed: " .. tostring(payload and payload.error))
				notify(localize("auto_crafter_notification_title", "Auto Crafter Helper"), "Operation failed: " .. tostring(payload and payload.error))
			elseif kind == "context_exit" then
				log("info", "Auto Crafter Helper stopped read-only work: " .. tostring(payload and payload.reason or "context exit"))
			end
		end,
	}
end

local function settings_adapter()
	return {
		get = function(_, setting_id)
			return setting(setting_id)
		end,
		set = function(_, setting_id, value)
			if not mod or type(mod.set) ~= "function" then
				return false
			end

			local ok = pcall(mod.set, mod, setting_id, value, true)

			return ok
		end,
	}
end

local function clock_adapter()
	return {
		now = monotonic_now,
	}
end

function AutoCrafter.configure(dependencies)
	dependencies = dependencies or {}
	mod = dependencies.mod or mod

	if not mod or type(mod.io_dofile) ~= "function" then
		log("error", "Auto Crafter Helper could not initialize: host mod loader unavailable.")

		return false
	end

	local ok_controller, Controller = pcall(mod.io_dofile, mod, "BetterInventory/scripts/mods/BetterInventory/auto_crafter/core/controller")
	local ok_planner, Planner = pcall(mod.io_dofile, mod, "BetterInventory/scripts/mods/BetterInventory/auto_crafter/core/planner")
	local ok_backend, Backend = pcall(mod.io_dofile, mod, "BetterInventory/scripts/mods/BetterInventory/auto_crafter/darktide/backend")
	local ok_context, Context = pcall(mod.io_dofile, mod, "BetterInventory/scripts/mods/BetterInventory/auto_crafter/darktide/context")
	local ok_panel, Panel = pcall(mod.io_dofile, mod, "BetterInventory/scripts/mods/BetterInventory/auto_crafter/darktide/panel")
	local ok_viewport_layout, ViewportLayout = pcall(mod.io_dofile, mod, "BetterInventory/scripts/mods/BetterInventory/auto_crafter/darktide/viewport_layout")
	local ok_layout_content, LayoutContent = pcall(mod.io_dofile, mod, "BetterInventory/scripts/mods/BetterInventory/BetterInventory_layout_content")

	if not ok_controller or type(Controller) ~= "table" or type(Controller.new) ~= "function" then
		log("error", "Auto Crafter Helper controller unavailable; feature disabled.")

		return false
	end

	if not ok_planner or type(Planner) ~= "table" or type(Planner.build) ~= "function" then
		log("error", "Auto Crafter Helper planner unavailable; feature disabled.")

		return false
	end

	if not ok_backend or type(Backend) ~= "table" or type(Backend.new) ~= "function" then
		log("error", "Auto Crafter Helper backend unavailable; feature disabled.")

		return false
	end

	if not ok_context or type(Context) ~= "table" or type(Context.new) ~= "function" then
		log("error", "Auto Crafter Helper context adapter unavailable; feature disabled.")

		return false
	end

	if not ok_panel or type(Panel) ~= "table" or type(Panel.new) ~= "function" then
		log("error", "Auto Crafter Helper diagnostic panel unavailable; continuing without UI.")
		Panel = nil
	end

	if not ok_viewport_layout or type(ViewportLayout) ~= "table" or type(ViewportLayout.panel_pivot) ~= "function" then
		log("error", "Auto Crafter Helper viewport layout unavailable; panel disabled.")
		Panel = nil
	end

	local backend = Backend.new()
	local context = Context.new({
		is_brunt_view = dependencies.is_brunt_view,
	})

	panel = Panel and Panel.new({
		ViewElementGrid = dependencies.ViewElementGrid,
		viewport_layout = ViewportLayout,
		compact_perk_label = function(entry, label)
			if not ok_layout_content or type(LayoutContent) ~= "table" or type(LayoutContent.compact_weapon_perk_description) ~= "function" then
				return label
			end

			return LayoutContent.compact_weapon_perk_description(mod, {
				description = label,
				id = entry and entry.trait,
			}, "heavy")
		end,
		get_selected_offer = dependencies.get_selected_offer,
		select_offer = dependencies.select_offer,
		settings = settings_adapter(),
		preview_plan = function()
			return controller and controller:preview_plan() or false
		end,
		start_purchase_search = function()
			return controller and controller:start_purchase_search() or false
		end,
		stop_active_run = function()
			return controller and controller:stop_active_run() or false
		end,
		localize = function(setting_id)
			return localize(setting_id, setting_id)
		end,
		logger = {
			info = function(_, message) log("info", message) end,
			error = function(_, message) log("error", message) end,
		},
	}) or nil

	controller = Controller.new({
		backend = backend,
		planner = Planner,
		context = context,
		get_selected_offer = dependencies.get_selected_offer,
		reporter = reporter(panel),
		logger = {
			info = function(_, message) log("info", message) end,
			error = function(_, message) log("error", message) end,
		},
		settings = settings_adapter(),
		clock = clock_adapter(),
	})
	presentation_dirty = true
	presentation_elapsed = 0
	presentation_snapshot = nil

	return true
end

function AutoCrafter.on_brunt_view_ready(view)
	presentation_dirty = true

	if not setting("auto_crafter_enable", false) then
		if panel then
			panel:detach()
		end

		return false
	end

	if panel then
		panel:attach(view)
	end

	return controller and controller:on_brunt_view_ready(view) or false
end

function AutoCrafter.on_view_closed(view)
	presentation_dirty = true

	if panel then
		panel:detach()
	end

	return controller and controller:on_view_closed(view) or false
end

function AutoCrafter.on_context_exit(reason)
	presentation_dirty = true

	if controller then
		controller:on_context_exit(reason)
	end

	if panel then
		panel:detach()
	end
end

function AutoCrafter.on_setting_changed(setting_id)
	presentation_dirty = true

	if not setting("auto_crafter_enable", false) and panel then
		panel:detach()
	end

	return controller and controller:on_setting_changed(setting_id) or false
end

function AutoCrafter.update(dt)
	if panel then
		panel:update(dt)
	end

	if controller then
		controller:update(dt)
		presentation_elapsed = presentation_elapsed + math.max(tonumber(dt) or 0, 0)
		local cached = presentation_snapshot
		local run_active = cached and (cached.search and cached.search.running or cached.phase3 and cached.phase3.running or cached.phase4 and cached.phase4.running or cached.mastery and cached.mastery.running)
		local completion_visible = cached and not cached.last_error and cached.phase4 and not cached.phase4.running and cached.phase4.elapsed_seconds ~= nil and #hud_lines > 0
		local clock_due = presentation_elapsed >= PRESENTATION_CLOCK_INTERVAL and (run_active or completion_visible)

		if presentation_dirty or cached == nil or clock_due then
			local snapshot = controller:snapshot()
			presentation_snapshot = snapshot
			presentation_dirty = false
			presentation_elapsed = 0
			rebuild_hud_lines(snapshot)

			if panel and type(panel.sync_controller_snapshot) == "function" then
				panel:sync_controller_snapshot(snapshot)
			end
		end
	end
end

function AutoCrafter.hud_lines()
	return hud_lines
end

function AutoCrafter.snapshot()
	return controller and controller:snapshot() or {
		phase = "unavailable",
	}
end

function AutoCrafter.shutdown()
	hud_lines = {}
	presentation_dirty = true
	presentation_elapsed = 0
	presentation_snapshot = nil
	if panel then
		panel:detach()
		panel = nil
	end

	if controller then
		controller:shutdown()
		controller = nil
	end
end

return AutoCrafter
