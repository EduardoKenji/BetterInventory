local AutoCrafter = {}

local mod
local controller
local panel
local games_lantern_queue
local games_lantern_import
local active_brunt_view
local games_lantern_catalog_generation = 0
local runtime_context
local start_games_lantern_queue
local hud_lines = {}
local presentation_dirty = true
local presentation_elapsed = 0
local presentation_snapshot
local controller_faulted = false
local PRESENTATION_CLOCK_INTERVAL = 0.25

local function invalidate_games_lantern_panel()
	if panel and type(panel.invalidate_games_lantern_snapshots) == "function" then
		pcall(panel.invalidate_games_lantern_snapshots, panel)
	end
end

local function monotonic_now()
	local application = rawget(_G, "Application")

	if application and type(application.time_since_launch) == "function" then
		local ok, value = pcall(application.time_since_launch)

		return ok and tonumber(value) or nil
	end

	return nil
end

local function running_under_wine()
	local application = rawget(_G, "Application")
	if not application or type(application.wine_version) ~= "function" then
		return false
	end

	local ok, version = pcall(application.wine_version)
	if not ok then
		ok, version = pcall(application.wine_version, application)
	end

	return ok and version ~= nil and version ~= false
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
		-- DMF loggers treat their first message argument as a string.format
		-- template. Imported build labels legitimately contain percent signs, so
		-- never pass external/runtime text as that template.
		pcall(logger, mod, "%s", tostring(message))
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

			if games_lantern_queue and (kind == "phase4_complete" or kind == "operation_failed" or kind == "operation_quarantined" or kind == "operation_reconciliation_required" or kind == "phase4_stopped" or kind == "purchase_search_stopped" or kind == "probe_complete" or kind == "character_changed") then
				pcall(games_lantern_queue.on_event, games_lantern_queue, kind, payload)
			end

			if kind == "character_changed" then
				if games_lantern_import then
					pcall(games_lantern_import.cancel, games_lantern_import, "character_changed")
				end

				if games_lantern_queue then
					pcall(games_lantern_queue.clear, games_lantern_queue)
				end
			end

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
	local ok_games_lantern_queue, GamesLanternQueue = pcall(mod.io_dofile, mod, "BetterInventory/scripts/mods/BetterInventory/auto_crafter/games_lantern/queue")
	local ok_games_lantern_clipboard, GamesLanternClipboard = pcall(mod.io_dofile, mod, "BetterInventory/scripts/mods/BetterInventory/auto_crafter/games_lantern/clipboard")
	local ok_games_lantern_clipboard_host, GamesLanternClipboardHost = pcall(mod.io_dofile, mod, "BetterInventory/scripts/mods/BetterInventory/auto_crafter/games_lantern/clipboard_host")
	local ok_games_lantern_parser, GamesLanternParser = pcall(mod.io_dofile, mod, "BetterInventory/scripts/mods/BetterInventory/auto_crafter/games_lantern/parser")
	local ok_games_lantern_resolver, GamesLanternResolver = pcall(mod.io_dofile, mod, "BetterInventory/scripts/mods/BetterInventory/auto_crafter/games_lantern/resolver")
	local ok_games_lantern_transport, GamesLanternTransport = pcall(mod.io_dofile, mod, "BetterInventory/scripts/mods/BetterInventory/auto_crafter/games_lantern/transport")
	local ok_games_lantern_transport_win, GamesLanternTransportWin = pcall(mod.io_dofile, mod, "BetterInventory/scripts/mods/BetterInventory/auto_crafter/games_lantern/transport_win")
	local ok_games_lantern_transport_wine, GamesLanternTransportWine = pcall(mod.io_dofile, mod, "BetterInventory/scripts/mods/BetterInventory/auto_crafter/games_lantern/transport_wine")
	local ok_games_lantern_import, GamesLanternImport = pcall(mod.io_dofile, mod, "BetterInventory/scripts/mods/BetterInventory/auto_crafter/games_lantern/import_controller")
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

	if not ok_games_lantern_queue or type(GamesLanternQueue) ~= "table" or type(GamesLanternQueue.new) ~= "function" then
		log("error", "Games Lantern queue unavailable; imported build support disabled.")
		GamesLanternQueue = nil
	end

	local games_lantern_import_available = ok_games_lantern_clipboard and type(GamesLanternClipboard) == "table" and type(GamesLanternClipboard.extract_url) == "function" and ok_games_lantern_clipboard_host and type(GamesLanternClipboardHost) == "table" and type(GamesLanternClipboardHost.read) == "function" and ok_games_lantern_parser and type(GamesLanternParser) == "table" and type(GamesLanternParser.parse) == "function" and ok_games_lantern_resolver and type(GamesLanternResolver) == "table" and type(GamesLanternResolver.resolve_identities) == "function" and type(GamesLanternResolver.attach_catalogs) == "function" and ok_games_lantern_transport and type(GamesLanternTransport) == "table" and type(GamesLanternTransport.new) == "function" and ok_games_lantern_import and type(GamesLanternImport) == "table" and type(GamesLanternImport.new) == "function" and ((not running_under_wine() and ok_games_lantern_transport_win and type(GamesLanternTransportWin) == "table" and type(GamesLanternTransportWin.spawn) == "function") or (running_under_wine() and ok_games_lantern_transport_wine and type(GamesLanternTransportWine) == "table" and type(GamesLanternTransportWine.spawn) == "function"))
	if not games_lantern_import_available then
		log("error", "Games Lantern import modules unavailable; Ctrl+V import disabled.")
	end

	if not ok_panel or type(Panel) ~= "table" or type(Panel.new) ~= "function" then
		log("error", "Auto Crafter Helper diagnostic panel unavailable; continuing without UI.")
		Panel = nil
	end

	if not ok_viewport_layout or type(ViewportLayout) ~= "table" or type(ViewportLayout.panel_pivot) ~= "function" then
		log("error", "Auto Crafter Helper viewport layout unavailable; panel disabled.")
		Panel = nil
	end

	local backend = Backend.new({
		mutation_guard = dependencies.mutation_guard,
	})
	local context = Context.new({
		is_brunt_view = dependencies.is_brunt_view,
	})
	runtime_context = context
	games_lantern_queue = GamesLanternQueue and GamesLanternQueue.new({
		select_job = function(job)
			if not active_brunt_view or type(dependencies.select_offer) ~= "function" then
				return false
			end

			local ok, selected = pcall(dependencies.select_offer, active_brunt_view, job.offer)

			return ok and selected == true
		end,
		configure_job = function(job)
			local ok, configured = pcall(controller.set_imported_job, controller, job)

			return ok and configured == true
		end,
		prepare_job = function(job, index, completed_results, jobs)
			local ok, prepared, reason = pcall(controller.prepare_imported_job, controller, job, index, completed_results, jobs)
			if not ok then
				return false, prepared
			end

			return prepared, reason
		end,
		start_job = function()
			local ok, started = pcall(controller.start_purchase_search, controller)

			return ok and started == true
		end,
		stop_job = function(reason)
			local ok, stopped = pcall(controller.stop_imported_queue_boundary, controller)
			local snapshot = controller and controller:snapshot()
			local active = snapshot and (snapshot.operation_inflight or (snapshot.auxiliary_inflight_count or 0) > 0 or snapshot.search and snapshot.search.running or snapshot.phase3 and snapshot.phase3.running or snapshot.phase4 and snapshot.phase4.running or snapshot.mastery and snapshot.mastery.running)

			return ok and stopped == true or not active, not active and not (snapshot and (snapshot.operation_quarantined or snapshot.reconciliation_required))
		end,
		view_is_valid = function()
			if not active_brunt_view or not runtime_context then
				return false
			end

			local ok, valid = pcall(runtime_context.is_valid_brunt_view, runtime_context, active_brunt_view)

			return ok and valid == true
		end,
		verify_results = function(results, queue_id, jobs)
			local ok, verified, reason = pcall(controller.verify_imported_queue_results, controller, results, jobs)

			return ok and verified == true, ok and reason or verified
		end,
		current_character_id = function()
			return runtime_context and runtime_context:current_character_id() or nil
		end,
		validate_event = function(job, payload)
			if not runtime_context or runtime_context:current_character_id() ~= payload.character_id then
				return false
			end
			local snapshot = controller and controller:snapshot()
			local running_job = snapshot and snapshot.run_imported_job

			return running_job and running_job.queue_id == job.queue_id and running_job.job_id == job.job_id and snapshot.terminal_sequence == payload.terminal_sequence and snapshot.operation_sequence == payload.operation_sequence and snapshot.data and snapshot.data.character_id == payload.character_id
		end,
		report = function(kind, payload)
			presentation_dirty = true
			invalidate_games_lantern_panel()
			log(kind == "queue_failed" and "error" or "info", string.format("Games Lantern queue event=%s queue=%s index=%s next=%s reason=%s", tostring(kind), tostring(payload and payload.queue_id or "?"), tostring(payload and payload.index or "?"), tostring(payload and payload.next_index or "?"), tostring(payload and payload.reason or "none")))

			if kind == "queue_job_skipped" then
				local job = payload and payload.job or {}
				local slot = tostring(job.slot or "queued")
				local weapon = tostring(job.display_name or job.offer and job.offer.display_name or "weapon")
				notify(localize("auto_crafter_notification_title", "Auto Crafter Helper"), string.format("Skipped %s weapon (%s): a perfectly crafted family-equivalent weapon already exists.", slot, weapon))
			elseif kind == "queue_complete" then
				if controller then
					pcall(controller.end_queue_operation, controller)
					pcall(controller.clear_imported_job, controller)
				end

				if games_lantern_import then
					pcall(games_lantern_import.clear, games_lantern_import)
				end
			elseif kind == "queue_failed" or kind == "queue_blocked" or kind == "queue_stopped" then
				if controller then
					pcall(controller.end_queue_operation, controller)
				end
			end
		end,
	}) or nil

	start_games_lantern_queue = function(confirmed, confirmed_signature)
		if not games_lantern_queue or not controller or not games_lantern_import then
			return false
		end

		local import_state = games_lantern_import:snapshot()
		local queue_state = games_lantern_queue:snapshot()
		local queue_can_resume = queue_state and queue_state.job_count == 2 and (queue_state.state == "staged" or queue_state.state == "stopped" or queue_state.state == "failed" or queue_state.state == "blocked")
		local new_import = import_state.state == "staged" and type(import_state.resolved_build) == "table"
		local imported_controller = controller:snapshot().imported_job ~= nil

		if not new_import and not (queue_can_resume and imported_controller) then
			return false
		end
		if confirmed ~= true then
			return false, "aggregate_confirmation_required"
		end
		local preview, preview_reason = controller:preview_imported_queue({ jobs = queue_state.jobs })
		if not preview or preview.signature == nil or preview.signature ~= confirmed_signature then
			log("info", "Games Lantern queue authority changed before dispatch: " .. tostring(preview_reason or "confirmation refresh required"))

			return false, "aggregate_confirmation_stale", preview
		end

		local policy, policy_reason = controller:capture_queue_run_policy()
		if not policy then
			log("error", "Games Lantern queue could not capture run policy: " .. tostring(policy_reason))

			return false
		end

		local acquired, acquire_reason = controller:begin_queue_operation(policy)
		if not acquired then
			log("error", "Games Lantern queue could not acquire account-operation ownership: " .. tostring(acquire_reason))

			return false
		end

		local started, start_reason = games_lantern_queue:start()
		if not started then
			controller:end_queue_operation()
			log("error", "Games Lantern queue did not start: " .. tostring(start_reason))

			return false
		end

		return true
	end

	local function games_lantern_resolution_context()
		local snapshot = controller and controller:snapshot()
		local data = snapshot and snapshot.data or {}
		local store = data.store or {}
		local offers = store.offers or {}
		local identity = runtime_context and runtime_context:current_identity() or nil

		return {
			active_archetype = identity and identity.archetype or nil,
			character_id = identity and identity.character_id or nil,
			identity_reason = identity and identity.reason or "character_context_unavailable",
			identity_stable = identity and identity.stable ~= false or false,
			dump_target = tonumber(setting("auto_crafter_dump_stat_target", 60)) or 60,
			localize_offer_label = game_localize,
			melee_offers = offers,
			ranged_offers = offers,
		}
	end

	local function games_lantern_fetch_catalogs(identity, complete, generation)
		games_lantern_catalog_generation = generation
		local catalogs = {}
		local index = 1
		local settled = false

		local function finish(result, error_value)
			if settled or games_lantern_catalog_generation ~= generation then
				return false
			end

			settled = true

			return complete(result, error_value)
		end

		local function read_next()
			if games_lantern_catalog_generation ~= generation then
				return false
			end

			local job = identity and identity.jobs and identity.jobs[index]
			if not job then
				return finish(catalogs, nil)
			end

			local call_ok, promise = pcall(backend.discover_weapon_catalog, backend, job.offer)
			if not call_ok or not promise or type(promise.next) ~= "function" or type(promise.catch) ~= "function" then
				return finish(nil, call_ok and "catalog discovery returned no Promise" or tostring(promise))
			end

			promise:next(function(catalog)
				if games_lantern_catalog_generation ~= generation then
					return catalog
				end

				if type(catalog) ~= "table" or catalog.available ~= true then
					finish(nil, "trait catalog unavailable for " .. tostring(job.master_id or index))

					return catalog
				end

				local key = job.master_id or job.offer and (job.offer.master_id or job.offer.parent_pattern)
				catalogs[key] = catalog
				index = index + 1
				read_next()

				return catalog
			end):catch(function(error_value)
				finish(nil, tostring(error_value or "catalog discovery failed"))

				return nil
			end)

			return true
		end

		return read_next()
	end

	local function games_lantern_cancel_catalogs(generation)
		if games_lantern_catalog_generation == generation then
			games_lantern_catalog_generation = games_lantern_catalog_generation + 1
		end

		return true
	end

	local function games_lantern_import_allowed()
		if not controller or controller_faulted then
			return false, "controller_unavailable"
		end

		local snapshot_ok, snapshot = pcall(controller.snapshot, controller)

		if not snapshot_ok or type(snapshot) ~= "table" then
			return false, "controller_snapshot_unavailable"
		end

		if snapshot.operation_inflight or snapshot.operation_quarantined or snapshot.reconciliation_required or (tonumber(snapshot.auxiliary_inflight_count) or 0) > 0 then
			return false, "auto_crafter_busy"
		end

		local search = snapshot.search
		local phase3 = snapshot.phase3
		local phase4 = snapshot.phase4
		local mastery = snapshot.mastery

		if search and search.running or phase3 and phase3.running or phase4 and phase4.running or mastery and mastery.running then
			return false, "auto_crafter_busy"
		end

		local queue_snapshot = games_lantern_queue and games_lantern_queue:snapshot()
		local queue_state = queue_snapshot and queue_snapshot.state

		if queue_state == "starting" or queue_state == "selecting" or queue_state == "preflighting" or queue_state == "dispatching" or queue_state == "running" or queue_state == "waiting_next" or queue_state == "stopping" or queue_state == "quarantined" or queue_state == "reconciliation_required" then
			return false, "games_lantern_queue_busy"
		end

		return true
	end

	local function games_lantern_install_queue(build)
		if not games_lantern_queue or not active_brunt_view then
			return false, "Brunt view unavailable"
		end

		local installed_ok, installed, install_reason = pcall(games_lantern_queue.install, games_lantern_queue, build)
		if not installed_ok or installed ~= true then
			return false, installed_ok and install_reason or installed
		end

		local staged_ok, staged, stage_reason = pcall(controller.set_imported_job, controller, build.jobs[1])
		if not staged_ok or staged ~= true then
			pcall(games_lantern_queue.clear, games_lantern_queue)
			pcall(controller.clear_imported_job, controller)

			return false, staged_ok and stage_reason or staged
		end

		return true
	end

	if games_lantern_import_available then
		local adapter = running_under_wine() and GamesLanternTransportWine or GamesLanternTransportWin
		local transport_ok, transport_instance = pcall(GamesLanternTransport.new, {
			adapter = adapter,
			clock = monotonic_now,
			report = function(kind, payload)
				presentation_dirty = true
				log(kind == "transport_failed" and "error" or "info", string.format("Games Lantern transport event=%s generation=%s status=%s bytes=%s reason=%s", tostring(kind), tostring(payload and payload.generation or "?"), tostring(payload and payload.status or "?"), tostring(payload and payload.bytes or "?"), tostring(payload and payload.reason or "none")))
			end,
		})

		if transport_ok and transport_instance then
			games_lantern_import = GamesLanternImport.new({
				clipboard_read = GamesLanternClipboardHost.read,
				clipboard = GamesLanternClipboard,
				transport = transport_instance,
				parser = GamesLanternParser,
				resolver = GamesLanternResolver,
				get_resolution_context = games_lantern_resolution_context,
				fetch_catalogs = games_lantern_fetch_catalogs,
				cancel_catalogs = games_lantern_cancel_catalogs,
				install_queue = games_lantern_install_queue,
				can_import = games_lantern_import_allowed,
				queue_snapshot = function()
					return games_lantern_queue and games_lantern_queue:snapshot() or nil
				end,
				report = function(kind, payload)
					presentation_dirty = true
					invalidate_games_lantern_panel()
					if kind == "import_failed" then
						local reason = tostring(payload and payload.reason)
						local detail = payload and payload.error
						local message = "Games Lantern import failed: " .. reason .. (detail and " (" .. tostring(detail) .. ")" or "")
						log("error", message)
						notify(localize("auto_crafter_notification_title", "Auto Crafter Helper"), message)
					else
						log("info", string.format("Games Lantern import event=%s generation=%s state=%s reason=%s", tostring(kind), tostring(payload and payload.generation or "?"), tostring(payload and payload.state or "?"), tostring(payload and payload.reason or "none")))
					end
				end,
			})
		end
	end

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
		select_manual_mark = function(offer_id, master_id)
			return controller and controller:select_manual_mark(offer_id, master_id) or false
		end,
		get_selected_manual_mark = function()
			return controller and controller:selected_manual_mark() or nil
		end,
		start_purchase_search = function()
			local queue_state = games_lantern_queue and games_lantern_queue:snapshot()
			local queue_owned = queue_state and queue_state.job_count == 2 and queue_state.state ~= "empty" and queue_state.state ~= "complete"

			if queue_owned then
				log("info", "Manual craft ignored while a Games Lantern queue is staged.")

				return false
			end

			return controller and controller:start_purchase_search() or false
		end,
		stop_active_run = function()
			local queue_state = games_lantern_queue and games_lantern_queue:snapshot()
			if queue_state and (queue_state.state == "running" or queue_state.state == "selecting" or queue_state.state == "preflighting" or queue_state.state == "dispatching" or queue_state.state == "waiting_next" or queue_state.state == "starting") then
				return games_lantern_queue:stop("user_stopped")
			end

			return controller and controller:stop_active_run() or false
		end,
		games_lantern_queue_snapshot = function()
			return games_lantern_queue and games_lantern_queue:presentation_snapshot() or nil
		end,
		games_lantern_import_snapshot = function()
			return games_lantern_import and games_lantern_import:presentation_snapshot() or nil
		end,
		games_lantern_paste = function(replace_confirmed)
			local queue_state = games_lantern_queue and games_lantern_queue:snapshot()
			local existing = queue_state and queue_state.job_count == 2 and queue_state.state ~= "empty"
			if existing and replace_confirmed ~= true then
				return false, "replacement_confirmation_required"
			end
			if existing then
				local match_ok, matches, match_reason = pcall(games_lantern_import.clipboard_matches_current, games_lantern_import)
				if not match_ok then
					return false, "clipboard_preflight_failed"
				end
				if matches == true then
					return true, "already_current"
				end
				if match_reason then
					return false, match_reason
				end

				local cleared = games_lantern_queue:clear()
				if not cleared then
					return false, "queue_busy"
				end
				pcall(controller.clear_imported_job, controller)
				pcall(games_lantern_import.clear, games_lantern_import)
			end

			return games_lantern_import and games_lantern_import:paste() or false
		end,
		games_lantern_clear = function()
			local cleared, reason = games_lantern_queue and games_lantern_queue:clear()
			if cleared then
				pcall(controller.clear_imported_job, controller)
				pcall(games_lantern_import.clear, games_lantern_import)
			end

			return cleared == true, reason
		end,
		games_lantern_select_choice = function(slot, card_index)
			return games_lantern_import and games_lantern_import:select_weapon_choice(slot, card_index) or false
		end,
		games_lantern_cost_authority = function()
			local queue_state = games_lantern_queue and games_lantern_queue:snapshot()
			if not queue_state or queue_state.job_count ~= 2 then
				return nil
			end

			return controller:preview_imported_queue({ jobs = queue_state.jobs })
		end,
		start_games_lantern_queue = function(confirmed, confirmed_signature)
			return start_games_lantern_queue and start_games_lantern_queue(confirmed, confirmed_signature) or false
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
		account_operation = dependencies.account_operation,
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
	controller_faulted = false
	presentation_dirty = true
	presentation_elapsed = 0
	presentation_snapshot = nil

	return true
end

function AutoCrafter.on_brunt_view_ready(view)
	active_brunt_view = view
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
	if view and active_brunt_view ~= view then
		return false
	end

	active_brunt_view = nil
	presentation_dirty = true

	if games_lantern_import then
		local import_state = games_lantern_import:snapshot()
		if import_state and (import_state.state == "fetching" or import_state.state == "resolving_catalogues") then
			pcall(games_lantern_import.cancel, games_lantern_import, "brunt_view_closed")
		end
	end

	if games_lantern_queue then
		local queue_state = games_lantern_queue:snapshot()
		if queue_state and (queue_state.state == "starting" or queue_state.state == "selecting" or queue_state.state == "preflighting" or queue_state.state == "waiting_next") then
			pcall(games_lantern_queue.stop, games_lantern_queue, "brunt_view_closed")
		end
	end

	if panel then
		panel:detach()
	end

	return controller and controller:on_view_closed(view) or false
end

function AutoCrafter.on_context_exit(reason)
	active_brunt_view = nil
	presentation_dirty = true

	if games_lantern_queue then
		local queue_state = games_lantern_queue:snapshot()
		if queue_state and (queue_state.state == "running" or queue_state.state == "selecting" or queue_state.state == "preflighting" or queue_state.state == "dispatching" or queue_state.state == "waiting_next" or queue_state.state == "starting") then
			pcall(games_lantern_queue.stop, games_lantern_queue, reason or "context_exit")
		end
	end

	if games_lantern_import then
		pcall(games_lantern_import.cancel, games_lantern_import, reason or "context_exit")
	end

	if controller then
		pcall(controller.on_context_exit, controller, reason)
	end

	if games_lantern_queue then
		pcall(games_lantern_queue.clear, games_lantern_queue)
	end

	if games_lantern_import then
		pcall(games_lantern_import.clear, games_lantern_import)
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
		local active_panel = panel
		local panel_ok, panel_error = pcall(active_panel.update, active_panel, dt)

		if not panel_ok then
			log("error", "Auto Crafter panel update failed and was detached: " .. tostring(panel_error))
			pcall(active_panel.detach, active_panel)
			panel = nil
		end
	end

	if games_lantern_import and games_lantern_import:state() == "fetching" then
		local import_state_before = games_lantern_import:state()
		local import_ok, import_error = pcall(games_lantern_import.update, games_lantern_import)

		if not import_ok then
			log("error", "Games Lantern import update failed: " .. tostring(import_error))
		end
		if games_lantern_import:state() ~= import_state_before then
			invalidate_games_lantern_panel()
		end
	end

	if controller and not controller_faulted then
		local update_ok, update_error = pcall(controller.update, controller, dt)

		if not update_ok then
			controller_faulted = true
			log("error", "Auto Crafter controller update failed; workflow disabled until reload: " .. tostring(update_error))
			pcall(controller.on_context_exit, controller, "controller_update_crash")

			return
		end

		if games_lantern_queue then
			local queue_state = games_lantern_queue:state()
			if queue_state == "selecting" or queue_state == "preflighting" or queue_state == "starting" or queue_state == "waiting_next" then
				local queue_ok, queue_error = pcall(games_lantern_queue.update, games_lantern_queue)

				if not queue_ok then
					log("error", "Games Lantern queue update failed: " .. tostring(queue_error))
				end
				if games_lantern_queue:state() ~= queue_state then
					invalidate_games_lantern_panel()
				end
			end
		end

		presentation_elapsed = presentation_elapsed + math.max(tonumber(dt) or 0, 0)
		local cached = presentation_snapshot
		local run_active = cached and (cached.search and cached.search.running or cached.phase3 and cached.phase3.running or cached.phase4 and cached.phase4.running or cached.mastery and cached.mastery.running)
		local completion_visible = cached and not cached.last_error and cached.phase4 and not cached.phase4.running and cached.phase4.elapsed_seconds ~= nil and #hud_lines > 0
		local clock_due = presentation_elapsed >= PRESENTATION_CLOCK_INTERVAL and (run_active or completion_visible)

		if presentation_dirty or cached == nil or clock_due then
			local snapshot_ok, snapshot = pcall(controller.snapshot, controller)

			if not snapshot_ok then
				log("error", "Auto Crafter snapshot presentation failed: " .. tostring(snapshot))

				return
			end

			presentation_snapshot = snapshot
			presentation_dirty = false
			presentation_elapsed = 0
			local rebuild_ok, rebuild_error = pcall(rebuild_hud_lines, snapshot)

			if not rebuild_ok then
				presentation_dirty = true
				log("error", "Auto Crafter HUD rebuild failed: " .. tostring(rebuild_error))
			end

			if panel and type(panel.sync_controller_snapshot) == "function" then
				local sync_ok, sync_error = pcall(panel.sync_controller_snapshot, panel, snapshot)

				if not sync_ok then
					local active_panel = panel
					log("error", "Auto Crafter panel sync failed and was detached: " .. tostring(sync_error))
					pcall(active_panel.detach, active_panel)
					panel = nil
				end
			end
		end
	end
end

function AutoCrafter.hud_lines()
	return hud_lines
end

function AutoCrafter.snapshot()
	local ok, snapshot = controller and pcall(controller.snapshot, controller)

	return ok and snapshot or {
		phase = "unavailable",
		last_error = controller_faulted and "controller update failed; reload required" or nil,
	}
end

function AutoCrafter.is_busy()
	local import_state = games_lantern_import and games_lantern_import:state()
	local import_busy = import_state == "fetching" or import_state == "resolving_catalogues"
	local queue_state = games_lantern_queue and games_lantern_queue:state()
	local queue_busy = queue_state == "starting" or queue_state == "selecting" or queue_state == "preflighting" or queue_state == "dispatching" or queue_state == "running" or queue_state == "waiting_next" or queue_state == "stopping" or queue_state == "quarantined" or queue_state == "reconciliation_required"
	local controller_busy = controller and controller:is_busy() or false

	return import_busy or queue_busy or controller_busy
end

function AutoCrafter.interrupt_for_external_mutation(kind)
	if not controller or controller_faulted then
		return false
	end

	local snapshot = AutoCrafter.snapshot()
	if snapshot.operation_inflight or snapshot.operation_quarantined or (tonumber(snapshot.auxiliary_inflight_count) or 0) > 0 then
		return false
	end

	local ok, interrupted = pcall(controller.interrupt_for_external_mutation, controller, kind)

	return ok and interrupted == true
end

function AutoCrafter.shutdown()
	hud_lines = {}
	presentation_dirty = true
	presentation_elapsed = 0
	presentation_snapshot = nil
	if games_lantern_import then
		pcall(games_lantern_import.cancel, games_lantern_import, "shutdown")
	end

	if games_lantern_queue then
		local queue_state = games_lantern_queue:snapshot()
		if queue_state and (queue_state.state == "running" or queue_state.state == "selecting" or queue_state.state == "preflighting" or queue_state.state == "dispatching" or queue_state.state == "waiting_next" or queue_state.state == "starting") then
			pcall(games_lantern_queue.stop, games_lantern_queue, "shutdown")
		end

		pcall(games_lantern_queue.clear, games_lantern_queue)
	end

	if games_lantern_import then
		pcall(games_lantern_import.clear, games_lantern_import)
	end

	if panel then
		panel:detach()
		panel = nil
	end

	if controller then
		controller:shutdown()
		controller = nil
	end
	controller_faulted = false
end

return AutoCrafter
