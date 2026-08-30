local function optional_require(path)
	local ok, module = pcall(require, path)

	return ok and module or nil
end
local GameCreditsGoodsVendorView = optional_require("scripts/ui/views/credits_goods_vendor_view/credits_goods_vendor_view")
local GameMarksVendorView = optional_require("scripts/ui/views/marks_vendor_view/marks_vendor_view")
local SearchHooks = {}

local function method_available(target, method_name)
	return type(target) == "table" and type(target[method_name]) == "function"
end

local function ensure_class_method(target, method_name)
	if type(target) ~= "table" then
		return false
	end

	local super = rawget(target, "super") or target.super
	local inherited = super and super[method_name]
	local own = rawget(target, method_name)

	if type(own) ~= "function" then
		if type(inherited) ~= "function" then
			return false
		end
	elseif own ~= inherited then
		return true
	end

	local owner = target
	local fallback = inherited

	rawset(owner, method_name, function(self, ...)
		local parent = rawget(owner, "super") or owner.super
		local parent_method = parent and parent[method_name] or fallback

		return parent_method(self, ...)
	end)

	return true
end

SearchHooks.install = function(dependencies)
	dependencies = type(dependencies) == "table" and dependencies or {}
	local mod = dependencies.mod
	local Features = dependencies.Features
	local SearchUI = dependencies.SearchUI
	local RuntimeLifecycle = dependencies.RuntimeLifecycle
	local ItemGridViewBase = dependencies.ItemGridViewBase
	local CraftingMechanicusModifyView = dependencies.CraftingMechanicusModifyView
	local CreditsGoodsVendorView = dependencies.CreditsGoodsVendorView or GameCreditsGoodsVendorView
	local MarksVendorView = dependencies.MarksVendorView or GameMarksVendorView
	local VendorViewBase = dependencies.VendorViewBase
	local ViewElementGrid = dependencies.ViewElementGrid
	local release_item_grid_view_runtime = dependencies.release_item_grid_view_runtime

	if type(mod) ~= "table" or type(Features) ~= "table" or type(SearchUI) ~= "table" then
		return false
	end

	if method_available(ItemGridViewBase, "_present_layout_by_slot_filter") then
		mod:hook(ItemGridViewBase, "_present_layout_by_slot_filter", function(func, view, slot_filter, item_type_filter, optional_display_name)
			local search_supported = type(SearchUI.supported) ~= "function" or SearchUI.supported(view)
			local search_enabled = search_supported and (type(SearchUI.enabled) ~= "function" or SearchUI.enabled(mod, view))

			if search_enabled then
				if type(Features.search_capture_presentation) == "function" then
					Features.search_capture_presentation(mod, view, slot_filter, item_type_filter, optional_display_name)
				end
				if type(SearchUI.sync_query) == "function" then
					SearchUI.sync_query(mod, Features, view)
				end
			elseif search_supported and type(Features.search_release) == "function" then
				Features.search_release(view)
			end

			return func(view, slot_filter, item_type_filter, optional_display_name)
		end)
	end

	if method_available(ItemGridViewBase, "_filter_by_filter_option") then
		mod:hook(ItemGridViewBase, "_filter_by_filter_option", function(func, view, entry, ...)
			local native_result = func(view, entry, ...)

			if view._better_inventory_search_filter_active and type(Features.search_filter_result) == "function" then
				return Features.search_filter_result(view, entry, native_result)
			end

			return native_result
		end)
	end

	if method_available(ItemGridViewBase, "_cb_on_present") then
		-- Grid presentation replaces widget instances. Reapply dim state once
		-- after new cards exist; no frame-level widget scan required.
		mod:hook_safe(ItemGridViewBase, "_cb_on_present", function(view)
			if view._better_inventory_search_rank_active and type(Features.search_apply_widget_alpha) == "function" then
				Features.search_apply_widget_alpha(view)
			end
		end)
	end

	local function update_search(view, _, time, input_service)
		if RuntimeLifecycle and type(RuntimeLifecycle.adopt_managed_grid) == "function" then
			RuntimeLifecycle.adopt_managed_grid(view)
		end
		if type(SearchUI.update_view) == "function" then
			SearchUI.update_view(mod, Features, view, time, input_service)
		end
	end

	local function install_view_update_hook(view_class)
		if ensure_class_method(view_class, "update") then
			mod:hook_safe(view_class, "update", update_search)
		end
	end

	-- InventoryWeaponsView and CreditsVendorView already have BetterInventory
	-- post-update hooks in the main runtime. Fold search into those callbacks and
	-- install a single explicit callback only for the other supported views.
	-- This removes the search-owned ItemGridViewBase.update wrapper from every
	-- settled inventory frame while retaining hot-reload query reconciliation.
	install_view_update_hook(CraftingMechanicusModifyView)
	install_view_update_hook(CreditsGoodsVendorView)
	install_view_update_hook(MarksVendorView)

	local function install_view_input_hook(view_class)
		if not method_available(view_class, "_handle_input") then
			return
		end

		mod:hook(view_class, "_handle_input", function(func, view, input_service, ...)
			if type(SearchUI.handle_view_input) == "function" and SearchUI.handle_view_input(mod, view, input_service) then
				return
			end

			return func(view, input_service, ...)
		end)
	end

	install_view_input_hook(CraftingMechanicusModifyView)
	install_view_input_hook(VendorViewBase)

	-- Darktide's class() copies superclass functions into child tables. Melk's
	-- class therefore retains its own VendorViewBase._handle_input reference;
	-- hooking VendorViewBase later does not affect it. Own and hook the exact
	-- MarksVendorView seam so ESC and outside-click focus release run in-game and
	-- after Ctrl+Shift+R.
	if ensure_class_method(MarksVendorView, "_handle_input") then
		install_view_input_hook(MarksVendorView)
	end

	-- Melk retains copied lifecycle methods too, so base-class cleanup hooks do
	-- not reach either the native or GlobalStore Marks view.
	if type(release_item_grid_view_runtime) == "function" then
		if ensure_class_method(MarksVendorView, "on_exit") then
			mod:hook_safe(MarksVendorView, "on_exit", release_item_grid_view_runtime)
		end
		if ensure_class_method(MarksVendorView, "destroy") then
			mod:hook_safe(MarksVendorView, "destroy", release_item_grid_view_runtime)
		end
	end

	if method_available(ViewElementGrid, "cb_on_grid_entry_left_pressed") then
		mod:hook_safe(ViewElementGrid, "cb_on_grid_entry_left_pressed", function(item_grid)
			if type(SearchUI.defocus) == "function" then
				SearchUI.defocus(item_grid and item_grid._parent)
			end
		end)
	end

	return true
end

return SearchHooks
