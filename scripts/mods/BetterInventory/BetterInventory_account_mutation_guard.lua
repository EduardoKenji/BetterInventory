local Promise = require("scripts/foundation/utilities/promise")

local Guard = {}
local auto_crafter
local host_mod
local owned_call_depth = 0
local pack_values = table.pack or function(...)
	return { n = select("#", ...), ... }
end
local unpack_values = table.unpack or unpack

local SERVICE_MUTATIONS = {
	{
		path = "scripts/managers/data_service/services/store_service",
		methods = { "purchase_item", "purchase_item_with_wallet" },
		prefix = "store",
	},
	{
		path = "scripts/managers/data_service/services/crafting_service",
		methods = {
			"add_weapon_expertise",
			"extract_weapon_mastery",
			"replace_perk_in_weapon",
			"replace_trait_in_weapon",
			"reset_sticker_book",
			"upgrade_weapon_rarity",
		},
		prefix = "crafting",
	},
	{
		path = "scripts/managers/data_service/services/mastery_service",
		methods = { "claim_levels_by_new_exp", "purchase_traits" },
		prefix = "mastery",
	},
	{
		path = "scripts/managers/data_service/services/gear_service",
		methods = { "delete_gear_batch" },
		prefix = "gear",
	},
	{
		path = "scripts/utilities/items",
		methods = { "set_item_id_as_favorite" },
		prefix = "items",
	},
}

local function log(level, message)
	local logger = host_mod and host_mod[level]

	if type(logger) == "function" then
		pcall(logger, host_mod, "[AutoCrafterGuard] " .. tostring(message))
	end
end

local function notify(message)
	local managers = rawget(_G, "Managers")
	local event_manager = managers and managers.event

	if event_manager and type(event_manager.trigger) == "function" then
		pcall(event_manager.trigger, event_manager, "event_add_notification_message", "custom", {
			line_1 = "Auto Crafter Helper",
			line_2 = message,
		})
	end
end

local function rejected(kind)
	return Promise.rejected({
		code = "better_inventory_auto_crafter_busy",
		description = "Auto Crafter has an account request in flight; " .. tostring(kind) .. " was blocked until it settles",
	})
end

function Guard.configure(dependencies)
	dependencies = dependencies or {}
	host_mod = dependencies.mod or host_mod
	auto_crafter = dependencies.auto_crafter or auto_crafter
end

function Guard.with_owned_call(callback)
	if type(callback) ~= "function" then
		error("owned account mutation callback is unavailable")
	end

	owned_call_depth = owned_call_depth + 1
	local results = pack_values(pcall(callback))
	owned_call_depth = math.max(0, owned_call_depth - 1)

	if not results[1] then
		error(results[2])
	end

	return unpack_values(results, 2, results.n)
end

function Guard.is_owned_call()
	return owned_call_depth > 0
end

function Guard.intercept(kind, original, service, ...)
	if type(original) ~= "function" then
		return rejected(kind)
	end

	local busy = false

	if auto_crafter and type(auto_crafter.is_busy) == "function" then
		local busy_ok, resolved_busy = pcall(auto_crafter.is_busy)
		busy = busy_ok and resolved_busy == true
	end

	if Guard.is_owned_call() or not busy then
		return original(service, ...)
	end

	local snapshot_ok, snapshot = pcall(type(auto_crafter.snapshot) == "function" and auto_crafter.snapshot or function() return {} end)
	snapshot = snapshot_ok and type(snapshot) == "table" and snapshot or {}
	local mutation_inflight = snapshot.operation_inflight == true or snapshot.operation_quarantined == true or (tonumber(snapshot.auxiliary_inflight_count) or 0) > 0

	if not mutation_inflight and type(auto_crafter.interrupt_for_external_mutation) == "function" then
		local interrupt_ok, interrupted = pcall(auto_crafter.interrupt_for_external_mutation, kind)
		local after_ok, after_busy = pcall(auto_crafter.is_busy)

		if interrupt_ok and interrupted == true and after_ok and after_busy ~= true then
			log("warning", "Stopped Auto Crafter before external " .. tostring(kind) .. ".")
			notify("Auto Crafter stopped before your " .. tostring(kind) .. " request.")

			return original(service, ...)
		end
	end

	log("warning", "Blocked external " .. tostring(kind) .. " while an Auto Crafter request is unresolved.")
	notify("Wait for the current Auto Crafter request to settle before " .. tostring(kind) .. ".")

	return rejected(kind)
end

function Guard.install_hooks(mod)
	if not mod or type(mod.hook) ~= "function" then
		return false
	end

	local installed = 0

	for _, definition in ipairs(SERVICE_MUTATIONS) do
		local ok, service_class = pcall(require, definition.path)

		if ok and type(service_class) == "table" then
			for _, method_name in ipairs(definition.methods) do
				if type(service_class[method_name]) == "function" then
					local kind = definition.prefix .. "." .. method_name
					local hook_ok, hook_error = pcall(mod.hook, mod, service_class, method_name, function(original, service, ...)
						return Guard.intercept(kind, original, service, ...)
					end)

					if hook_ok then
						installed = installed + 1
					else
						log("error", "Could not hook " .. kind .. ": " .. tostring(hook_error))
					end
				end
			end
		end
	end

	log("info", string.format("Installed %d account-mutation interception hook(s).", installed))

	return installed > 0
end


Guard.SERVICE_MUTATIONS = SERVICE_MUTATIONS

return Guard
