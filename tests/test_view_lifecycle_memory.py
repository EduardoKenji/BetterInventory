from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNTIME_ROOT = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory"
DARKTIDE_ROOT = PROJECT_ROOT.parents[1] / "Darktide-Source-Code"


def read_runtime(name: str) -> str:
    return (RUNTIME_ROOT / name).read_text(encoding="utf-8")


def main() -> None:
    runtime = read_runtime("BetterInventory_runtime.lua")
    overview = read_runtime("BetterInventory_character_overview_ui.lua")
    features = read_runtime("BetterInventory_features.lua")
    armoury_panel = read_runtime("BetterInventory_armoury_panel.lua")
    domains = read_runtime("BetterInventory_feature_domains.lua")
    sessions = read_runtime("BetterInventory_view_session.lua")
    equipment = read_runtime("BetterInventory_equipment_persistence.lua")
    auto_crafter = read_runtime("BetterInventory_auto_crafter.lua")
    automatic_discard = read_runtime("BetterInventory_discard_automatic.lua")
    curio_acquisition = read_runtime("BetterInventory_curio_acquisition.lua")
    backend = read_runtime("auto_crafter/darktide/backend.lua")

    # Every view-owned registry has an explicit normal close path and an
    # abnormal destroy/disable fallback. Repeated close calls are safe no-ops.
    assert 'mod:hook_safe(InventoryWeaponsView, "on_exit"' in runtime
    assert 'ensure_class_method(InventoryWeaponsView, "destroy")' in runtime
    assert "arm_equipped_compound_shield_guard(view, context)" in runtime
    assert "Layout.safe_inventory_maximum_columns" in runtime
    assert "configuration.maximum_columns = safe_maximum_columns" in runtime
    assert "view._better_inventory_compound_shield_column_cap" in runtime
    assert "wrap_character_overview_compound_icon_lifecycle" not in overview
    assert "replace_live_compound_icon" not in overview
    assert 'mod:hook_safe(CreditsVendorView, "on_exit"' in runtime
    assert 'ensure_class_method(CreditsVendorView, "destroy")' in runtime
    assert 'ensure_class_method(CreditsGoodsVendorView, "on_exit")' in runtime
    assert 'ensure_class_method(CreditsGoodsVendorView, "destroy")' in runtime
    assert 'ensure_class_method(ItemGridViewBase, "on_exit")' in runtime
    assert 'ensure_class_method(ItemGridViewBase, "destroy")' in runtime
    assert 'ensure_class_method(InventoryBackgroundView, "on_exit")' in runtime
    assert 'ensure_class_method(InventoryBackgroundView, "destroy")' in runtime
    assert 'ensure_class_method(InventoryView, "on_exit")' in overview
    assert 'ensure_class_method(InventoryView, "destroy")' in overview
    assert "OverviewUI.unregister_view(view)" in overview
    assert "character_overview_view_retired(view)" in overview
    assert "ui_manager.is_view_closing" in overview
    assert "ui_manager.view_instance" in overview
    assert "Features.release_inventory_options_panel(view)" in features
    assert "armoury_panel.release(view)" in features
    assert "registered_armoury_views[view] = nil" in armoury_panel
    assert "Domains.markers.release_grid(item_grid)" in domains
    assert 'Features.close_all_view_sessions("mod_disable")' in runtime
    assert "CharacterOverviewUI.release_all_views()" in runtime
    assert "FeatureDomains.markers.release_all()" in runtime
    assert "EquipmentPersistence.on_view_closed(view)" in runtime
    assert "EquipmentPersistence.reset()" in runtime
    assert "Features.request_inventory_resort(view)" in runtime
    assert "Features.flush_inventory_resort(mod, Layout, view)" in runtime
    assert "release_transient_item_caches()" in runtime
    assert "CharacterOverviewUI.needs_update()" in runtime
    assert "FeatureDomains.markers.needs_update()" in runtime
    assert "local auto_crafter_needs_update" in runtime
    assert "content.better_inventory_curio_fit_initialized ~= true" in overview
    assert "fit_curio_text(widget, ui_renderer, false)" in overview
    assert "session.cleanup = nil" in sessions
    assert "session.cleanup_order = nil" in sessions
    assert "session.fields = nil" in sessions
    assert "view = view," not in sessions
    assert "if view and active_brunt_view ~= view then" in auto_crafter
    assert "active_brunt_view = nil" in auto_crafter
    assert "games_lantern_queue = nil" in auto_crafter
    assert "games_lantern_import = nil" in auto_crafter
    assert "runtime_context = nil" in auto_crafter
    assert "OverviewUI.needs_update" in overview
    assert "view._better_inventory_sort_priority_cache = nil" in read_runtime(
        "BetterInventory_feature_sorting.lua"
    )
    assert "function backend:release_read_cache()" in backend
    assert "self._raw_gear = {}" in backend
    assert "self._purchase_wallets = {}" in backend
    assert "AUTOMATIC_DISCARD_READ_TIMEOUT = 45" in automatic_discard
    assert 'or enabled(mod) and is_morningstar()' in automatic_discard
    assert 'return enabled(mod) and (is_morningstar()' in curio_acquisition

    # Preserve Potty's measured CPU fix: BetterInventory must not own shared
    # native update/draw chains. GSC compatibility uses one safe post-update
    # callback bounded to Darktide's handful of loadout slots; no grid scan or
    # wrapping hook is allowed.
    assert 'mod:hook_safe(ViewElementGrid, "update"' not in runtime
    assert 'mod:hook_safe(InventoryView, "update"' in overview
    assert 'mod:hook(InventoryView, "update"' not in overview
    assert "MAX_CHARACTER_OVERVIEW_LOADOUT_WIDGETS = 8" in overview
    assert "math.min(#widgets, MAX_CHARACTER_OVERVIEW_LOADOUT_WIDGETS)" in overview
    assert "pairs(widgets)" not in overview
    assert 'mod:hook(InventoryWeaponsView, "update"' not in runtime

    # ViewElementGrid is shared with profile presets, cosmetics, and third-party
    # preview panels. Unsupported grids must bypass BetterInventory before any
    # blueprint cloning, callback wrapping, or marker/material attachment.
    assert "local resolve_grid_scope = grid_scope and grid_scope.resolve" in runtime
    assert "Domains.grid_scope.resolve = function" in domains
    assert "if not view then\n\t\treturn func(item_grid, layout, content_blueprints, ...)" in runtime
    assert "resolve_grid_scope(item_grid, active_grid_view, active_grid_configuration)" in runtime

    # Quick Level Mastery's vendor alignment may be revisited every frame, but
    # stable geometry must not force a scenegraph/world-position query at 60 Hz.
    assert "QUICK_LEVEL_ALIGNMENT_PROBE_INTERVAL = 15" in domains
    assert "_better_inventory_quick_level_alignment_probe" in domains
    assert "if not inputs_changed and not probe_due then" in domains
    assert "pairs({ view._item_grid" not in features

    # Local Darktide source confirms native request containers already release
    # store/Hadron work. BetterInventory should only release its own references.
    vendor_path = DARKTIDE_ROOT / "scripts/ui/views/vendor_view_base/vendor_view_base.lua"
    inventory_path = DARKTIDE_ROOT / "scripts/ui/views/inventory_weapons_view/inventory_weapons_view.lua"
    hadron_path = DARKTIDE_ROOT / "scripts/ui/views/crafting_mechanicus_modify_view/crafting_mechanicus_modify_view.lua"
    if vendor_path.is_file() and inventory_path.is_file() and hadron_path.is_file():
        vendor = vendor_path.read_text(encoding="utf-8")
        inventory = inventory_path.read_text(encoding="utf-8")
        hadron = hadron_path.read_text(encoding="utf-8")
        assert "self._promise_container:delete()" in vendor
        assert "self._store_promise:cancel()" in inventory
        assert "self._inventory_promise:cancel()" in hadron

    print("BetterInventory view lifecycle memory checks passed.")


if __name__ == "__main__":
    main()
