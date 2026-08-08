local AutoCrafter = {}

local mod
local controller

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

local function reporter()
	return {
		emit = function(_, kind, payload)
			if kind == "probe_started" then
				notify(localize("auto_crafter_notification_title", "Auto Crafter Helper"), localize("auto_crafter_probe_started", "Read-only probe started."))
			elseif kind == "probe_complete" then
				notify(localize("auto_crafter_notification_title", "Auto Crafter Helper"), format_probe(payload))
			elseif kind == "probe_failed" then
				notify(localize("auto_crafter_notification_title", "Auto Crafter Helper"), string.format("%s: %s", localize("auto_crafter_probe_failed", "Read-only probe failed"), tostring(payload and payload.error)))
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
	}
end

local function clock_adapter()
	return {
		now = function()
			local application = rawget(_G, "Application")

			if application and type(application.time_since_launch) == "function" then
				local ok, value = pcall(application.time_since_launch)

				return ok and value or nil
			end
		end,
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
	local ok_backend, Backend = pcall(mod.io_dofile, mod, "BetterInventory/scripts/mods/BetterInventory/auto_crafter/darktide/backend")
	local ok_context, Context = pcall(mod.io_dofile, mod, "BetterInventory/scripts/mods/BetterInventory/auto_crafter/darktide/context")

	if not ok_controller or type(Controller) ~= "table" or type(Controller.new) ~= "function" then
		log("error", "Auto Crafter Helper controller unavailable; feature disabled.")

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

	local backend = Backend.new()
	local context = Context.new({
		is_brunt_view = dependencies.is_brunt_view,
	})

	controller = Controller.new({
		backend = backend,
		context = context,
		reporter = reporter(),
		logger = {
			info = function(_, message) log("info", message) end,
			error = function(_, message) log("error", message) end,
		},
		settings = settings_adapter(),
		clock = clock_adapter(),
	})

	return true
end

function AutoCrafter.on_brunt_view_ready(view)
	return controller and controller:on_brunt_view_ready(view) or false
end

function AutoCrafter.on_view_closed(view)
	return controller and controller:on_view_closed(view) or false
end

function AutoCrafter.on_context_exit(reason)
	if controller then
		controller:on_context_exit(reason)
	end
end

function AutoCrafter.on_setting_changed(setting_id)
	return controller and controller:on_setting_changed(setting_id) or false
end

function AutoCrafter.update(dt)
	if controller then
		controller:update(dt)
	end
end

function AutoCrafter.snapshot()
	return controller and controller:snapshot() or {
		phase = "unavailable",
	}
end

function AutoCrafter.shutdown()
	if controller then
		controller:shutdown()
		controller = nil
	end
end

return AutoCrafter
