local LayoutContent = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_layout_content")

local Layout = {}
local content = LayoutContent

local Cards = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_layout_cards")

local Geometry = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_layout_geometry")
local Blueprints = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_layout_blueprints")

for name, value in pairs(Geometry) do
	Layout[name] = value
end

Layout.configure_native_item_blueprint = Blueprints.configure_native_item_blueprint
Layout.configure_item_blueprint = Blueprints.configure_item_blueprint
Layout.ImageLayout = Blueprints.ImageLayout
Layout.MaterialSafety = Blueprints.MaterialSafety

Layout.set_item_customization_provider = function(provider)
	content.set_item_customization_provider(provider)
	Cards.set_item_customization_provider(provider)
	Geometry.set_item_customization_provider(provider)
	Blueprints.set_item_customization_provider(provider)
end
Layout.set_custom_tier_provider = function(provider)
	Cards.set_custom_tier_provider(provider)
	Geometry.set_custom_tier_provider(provider)
	Blueprints.set_custom_tier_provider(provider)
end
Layout.clear_runtime_caches = content.clear_runtime_caches
Layout.compact_curio_perk_search_terms = content.compact_curio_perk_search_terms
Layout.curio_trait_search_terms = content.curio_trait_search_terms
Layout.compact_weapon_perk_search_terms = content.compact_weapon_perk_search_terms
Layout.direct_weapon_comparing_stats = content.direct_weapon_comparing_stats
Layout.projected_weapon_modifier_records = content.projected_weapon_modifier_records
Layout.curio_secondary_color = content.curio_secondary_color
Layout.update_highlight_animation = Cards.update_highlight_animation
Layout.remove_weapon_stats_wkc_listing_overlays = Cards.remove_weapon_stats_wkc_listing_overlays
Layout.cap_brunt_wkc_listing_overlay_sizes = Cards.cap_brunt_wkc_listing_overlay_sizes
Layout.install_brunt_wkc_listing_hook = Cards.install_brunt_wkc_listing_hook
Layout.synchronize_rarity_tag_color = content.synchronize_rarity_tag_color
Layout.apply_item_customization_style = content.apply_item_customization_style
Layout.restore_item_customization_style = content.restore_item_customization_style
Layout.apply_weapon_information_customization = content.apply_weapon_information_customization
Layout.refresh_item_customization = content.refresh_item_customization
Layout.reapply_tracked_item_customization_style = content.reapply_tracked_item_customization_style
Layout.invalidate_item_customization_tracking = content.invalidate_item_customization_tracking

return Layout
