-- Confirmed Curio Buyer receipts only. Persist before POST; reconcile rarity
-- after interruptions instead of replaying a potentially accepted mutation.
local MasterItems = require("scripts/backend/master_items")
local CraftingSettings = require("scripts/settings/item/crafting_settings")
local Consecration = {}
local dependencies = {}
local SETTING = "automatic_curio_consecrate_transcendent"
local JOURNAL = "_automatic_curio_consecration_queue"
local OWNER = "curio_consecration"
local request
local elapsed = 0
local poll_interval = 2
local notices = {}

local function valid_id(value)
	return type(value) == "string" and value ~= "" and #value <= 128
end

local function journal(mod)
	local value = mod:get(JOURNAL)
	return type(value) == "table" and value or {}
end

local function persist(mod, value)
	mod:set(JOURNAL, value, false)
	local dmf = get_mod("DMF")
	assert(dmf and type(dmf.save_unsaved_settings_to_file) == "function", "Curio consecration persistence unavailable")
	dmf.save_unsaved_settings_to_file()
	-- DMF logs serialization failures without throwing or returning a status.
	local saved = Application.user_setting("mods_settings", mod:get_name(), JOURNAL)
	assert(type(saved) == "table" and table.equals(value, saved), "Curio consecration recovery record was not saved")
end

local function notice(mod, key, text)
	poll_interval = 30
	if notices[key] == text then return end
	notices[key] = text
	if type(mod.warning) == "function" then pcall(mod.warning, mod, "%s", text) end
	local events = Managers and Managers.event
	if events and type(events.trigger) == "function" then
		pcall(events.trigger, events, "event_add_notification_message", "custom", {
			line_1 = mod:localize("automatic_curio_consecrate_transcendent"), line_2 = text,
		})
	end
end

local function finish(current)
	if current.finished then return end
	current.finished = true
	pcall(dependencies.release, OWNER, current.lease)
	if request == current then request = nil end
end

function Consecration.configure(options)
	dependencies = options or {}
end

function Consecration.cancel()
	elapsed = 0
	poll_interval = 2
	if request then
		request.cancelled = true
		-- A native POST cannot be cancelled or have its lock timed out.
		if not request.writing then
			local current = request
			finish(current)
			if current.read and type(current.read.cancel) == "function" then pcall(current.read.cancel, current.read) end
		end
	end
end

function Consecration.busy()
	return request ~= nil
end

function Consecration.mutation_inflight()
	return request ~= nil and request.writing == true
end

function Consecration.enqueue(mod, account, character, items)
	if not valid_id(account) or account == "default" or not valid_id(character) then return end
	local data = journal(mod)
	local entries = type(data[account]) == "table" and data[account] or {}
	data[account] = entries
	local changed = false
	local sequence = 0
	for _, entry in pairs(entries) do
		sequence = math.max(sequence, type(entry) == "table" and tonumber(entry.sequence) or 0)
	end
	for _, receipt in ipairs(type(items) == "table" and items or {}) do
		local nested = type(receipt) == "table" and (receipt.item or receipt.gear)
		local id = type(receipt) == "string" and receipt or type(receipt) == "table" and (receipt.uuid or receipt.gear_id or receipt.gearId or type(nested) == "table" and (nested.uuid or nested.gear_id))
		if valid_id(id) and entries[id] == nil then
			sequence = sequence + 1
			entries[id] = { character = character, sequence = sequence }
			changed = true
		end
	end
	if changed then persist(mod, data) end
end

local function current_context(mod)
	if mod:get("enable_automatic_curio_acquisition") ~= true or mod:get(SETTING) == false then return end
	if dependencies.context then
		local ok, context, account = pcall(dependencies.context)
		if ok then return context, account end
	end
end

local function is_current(mod, current)
	return request == current and not current.cancelled and current_context(mod) == current.context
end

function Consecration.update(mod, dt, blocked)
	local context, account = current_context(mod)
	if not context or blocked then Consecration.cancel(); return end
	if request then
		request.age = request.age + dt
		if request.context ~= context or not request.writing and request.age >= 30 then Consecration.cancel() end
		return
	end
	elapsed = elapsed + dt
	if elapsed < poll_interval then return end
	elapsed = 0
	poll_interval = 2
	local guard = dependencies.guard
	if not valid_id(account) or account == "default" or not guard or type(guard.has_pending) ~= "function" or type(guard.scope) ~= "function" or guard.has_pending() then return end
	local data = journal(mod)
	local entries = data[account]
	if type(entries) ~= "table" then return end
	local ids = {}
	for id, entry in pairs(entries) do
		if valid_id(id) and type(entry) == "table" and valid_id(entry.character) then ids[#ids + 1] = id end
	end
	if #ids == 0 then return end
	table.sort(ids, function(a, b)
		local left, right = tonumber(entries[a].sequence) or 0, tonumber(entries[b].sequence) or 0
		return left == right and a < b or left < right
	end)
	local id = ids[1]
	local entry = entries[id]
	local interfaces = Managers and Managers.backend and Managers.backend.interfaces
	local service = Managers and Managers.data_service and Managers.data_service.crafting
	if not interfaces or not interfaces.gear or not interfaces.wallet or not service then return end
	local scope = guard.scope()
	if type(scope) ~= "table" or type(scope.with_owned_call) ~= "function" then return end
	local lease = dependencies.acquire and dependencies.acquire(OWNER)
	if not lease then return end
	local current = { context = context, age = 0, lease = lease, scope = scope }
	request = current
	local function save_entry(value)
		-- Read again: a purchase receipt can arrive during our asynchronous read.
		local latest = journal(mod)
		latest[account] = type(latest[account]) == "table" and latest[account] or {}
		latest[account][id] = value
		if value == nil then notices[id] = nil end
		persist(mod, latest)
	end
	local ok, chain = pcall(function()
		-- Bypass UI read caches without cancelling another consumer's GET.
		current.read = interfaces.gear:fetch()
		return current.read:next(function(gear)
			if not is_current(mod, current) then return end
			assert(type(gear) == "table", "Curio inventory unavailable")
			local raw = gear[id]
			if not raw then save_entry(nil); return end
			if tostring(raw.characterId or raw.character_id) ~= entry.character then
				save_entry(nil); return
			end
			local item = MasterItems.get_item_instance(raw, id)
			assert(item and item.item_type == "GADGET", "Queued item is not a Curio")
			local rarity = tonumber(item.rarity)
			assert(rarity and rarity == math.floor(rarity) and rarity >= 1 and rarity <= 5, "Curio rarity unavailable")
			if rarity == 5 then save_entry(nil); notices[id] = nil; return end
			if entry.attempted_rarity ~= nil then
				if type(entry.attempted_rarity) ~= "number" or rarity <= entry.attempted_rarity then
					notice(mod, id, mod:localize("automatic_curio_consecrate_uncertain")); return
				end
				entry.attempted_rarity = nil
				save_entry(entry)
			end
			local recipe = CraftingSettings.recipes.upgrade_item
			assert(recipe.can_craft({ item = item }), "Curio cannot be consecrated")
			local costs = recipe.get_costs({ item = item })
			assert(type(costs) == "table" and #costs > 0, "Curio costs unavailable")
			local totals = {}
			for _, cost in ipairs(costs) do
				assert(type(cost.type) == "string" and type(cost.amount) == "number" and cost.amount >= 0 and cost.amount < math.huge and cost.amount == math.floor(cost.amount), "Invalid Curio costs")
				totals[cost.type] = (totals[cost.type] or 0) + cost.amount
			end
			current.read = interfaces.wallet:account_wallets()
			return current.read:next(function(wallets)
				if not is_current(mod, current) then return end
				assert(type(wallets) == "table", "Curio wallets unavailable")
				local balances = {}
				for _, wallet in ipairs(wallets) do
					local balance = wallet.balance
					if balance then balances[balance.type] = tonumber(balance.amount) end
				end
				for currency, amount in pairs(totals) do
					if not balances[currency] or balances[currency] ~= balances[currency] or balances[currency] < amount then
						notice(mod, id, mod:localize("automatic_curio_consecrate_materials")); return
					end
				end
				if guard.has_pending() or not is_current(mod, current) then return end
				entry.attempted_rarity = rarity
				save_entry(entry)
				current.writing = true
				return current.scope.with_owned_call(function()
					return service:upgrade_gadget_rarity(id, costs)
				end)
			end)
		end)
	end)
	if not ok or not chain or type(chain.next) ~= "function" then
		finish(current)
		notice(mod, id, mod:localize("automatic_curio_consecrate_failed"))
		return
	end
	chain:next(function() finish(current) end, function()
		finish(current)
		notice(mod, id, mod:localize("automatic_curio_consecrate_failed"))
	end)
end

return Consecration
