from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNTIME_ROOT = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory"
LAYOUT_PATH = RUNTIME_ROOT / "auto_crafter" / "darktide" / "viewport_layout.lua"
PANEL_PATH = RUNTIME_ROOT / "auto_crafter" / "darktide" / "panel.lua"
OVERLAY_PATH = RUNTIME_ROOT / "auto_crafter" / "darktide" / "view_status_overlay.lua"
HUD_PATH = RUNTIME_ROOT / "auto_crafter" / "darktide" / "hud_element.lua"


def main() -> None:
    layout = LuaRuntime(unpack_returned_tuples=True).execute(
        LAYOUT_PATH.read_text(encoding="utf-8"), name=str(LAYOUT_PATH)
    )
    resolution_matrix = (
        (1920, 1080, 1.0, 1380, 1380, 580),
        (2560, 1440, 4 / 3, 1380, 1380, 580),
        (3440, 1440, 4 / 3, 2040, 1710, 910),
        (5120, 1440, 4 / 3, 3300, 2340, 1540),
        (3840, 2160, 2.0, 1380, 1380, 580),
    )

    for width, height, scale, expected_fallback_x, expected_anchored_x, expected_hud_x in resolution_matrix:
        virtual_width, _ = layout.virtual_size(width, height, scale)
        brunt_canvas_left = (virtual_width - 1920) / 2
        info_box_right = brunt_canvas_left + 1307.5
        panel_x, panel_y = layout.panel_pivot(width, height, scale, 445, 520)
        anchored_x, anchored_y = layout.anchored_panel_pivot(width, height, scale, 445, 520, info_box_right, 0, 72, 110)
        hud_x, hud_y = layout.centered_top_pivot(width, height, scale, 760, 112, 42)
        assert (panel_x, panel_y) == (expected_fallback_x, 110)
        assert (anchored_x, anchored_y) == (expected_anchored_x, 110)
        assert (hud_x, hud_y) == (expected_hud_x, 42)

    panel_source = PANEL_PATH.read_text(encoding="utf-8")
    overlay_source = OVERLAY_PATH.read_text(encoding="utf-8")
    hud_source = HUD_PATH.read_text(encoding="utf-8")
    assert "layout.panel_pivot" in panel_source
    assert "layout.anchored_panel_pivot" in panel_source
    assert "scenegraph.info_box" in panel_source
    assert "self:_update_pivot()" in panel_source
    assert 'horizontal_alignment = "center"' in overlay_source
    assert 'vertical_alignment = "top"' in overlay_source
    assert "widget.offset[1] = horizontal_offset(view)" in overlay_source
    assert "widget.offset[2] = 0" in overlay_source
    assert 'string.find(class_name, "CreditsGoodsVendorView", 1, true)' in overlay_source
    assert "BRUNT_HORIZONTAL_OFFSET = 360" in overlay_source
    assert "status_height(line_count)" in overlay_source
    assert "widget.style.background.size[2] = height" in overlay_source
    assert "widget.style.accent.size[2] = height" in overlay_source
    assert "widget.style.text.size[2] = height - VERTICAL_PADDING" in overlay_source
    assert "table.concat" not in overlay_source
    assert "widget._better_inventory_presentation_revision ~= revision" in overlay_source
    assert "centered_top_pivot" not in overlay_source
    assert 'mod:hook_safe(view_class, "draw"' in overlay_source
    assert 'mod:hook(view_class, "draw"' not in overlay_source
    assert "func(view, dt, t, input_service, layer)" not in overlay_source
    assert "_auto_crafter_status_draw_depth" not in overlay_source
    assert 'require("scripts/mods/BetterInventory' not in overlay_source
    assert 'horizontal_alignment = "center"' in hud_source
    assert 'vertical_alignment = "top"' in hud_source
    assert "status_height(line_count)" in hud_source
    assert "scenegraph.size[2] = height" in hud_source
    assert "widget.style.text.size[2] = height - VERTICAL_PADDING" in hud_source
    assert "table.concat" not in hud_source
    assert "revision ~= self._better_inventory_presentation_revision" in hud_source

    # Draw hooks must measure only BetterInventory's post-draw overlay. Wrapping
    # BaseView.draw makes hook profilers charge the complete native/third-party
    # UI render chain to BetterInventory, even in unrelated views.
    overlay_runtime = LuaRuntime(unpack_returned_tuples=True)
    overlay_runtime.execute(
        r"""
        renderer_begin_calls = 0
        renderer_end_calls = 0
        widget_draw_calls = 0
        normal_hook_calls = 0
        safe_hooks = {}

        UIRenderer = {
            begin_pass = function()
                renderer_begin_calls = renderer_begin_calls + 1
            end,
            end_pass = function()
                renderer_end_calls = renderer_end_calls + 1
            end,
        }
        UIWidget = {
            create_definition = function(definition)
                return definition
            end,
            init = function()
                return {
                    content = { text = "" },
                    style = {
                        background = { size = { 760, 112 } },
                        accent = { size = { 4, 112 } },
                        text = { size = { 736, 104 } },
                    },
                    offset = { 0, 0, 0 },
                }
            end,
            draw = function()
                widget_draw_calls = widget_draw_calls + 1
            end,
        }

        function require(path)
            if path == "scripts/managers/ui/ui_renderer" then
                return UIRenderer
            elseif path == "scripts/managers/ui/ui_widget" then
                return UIWidget
            end
            error("unexpected require: " .. tostring(path))
        end

        test_mod = {}
        function test_mod:hook()
            normal_hook_calls = normal_hook_calls + 1
        end
        function test_mod:hook_safe(object, method, handler)
            safe_hooks[#safe_hooks + 1] = {
                object = object,
                method = method,
                handler = handler,
            }
        end

        BaseView = { draw = function() end }
        ItemGridViewBase = { draw = function() end }
        InventoryView = { draw = function() end }
        VendorInteractionViewBase = { draw = function() end }

        AutoCrafterHelperHudState = {
            enabled = function() return true end,
            visible_context = function() return true end,
            presentation = function()
                return "one\ntwo\nthree\nfour\nfive", 5, 1
            end,
        }
        """
    )
    runtime_overlay = overlay_runtime.execute(overlay_source)
    runtime_globals = overlay_runtime.globals()
    assert runtime_overlay.install(
        runtime_globals.test_mod,
        overlay_runtime.table_from(
            {
                "base": runtime_globals.BaseView,
                "item_grid": runtime_globals.ItemGridViewBase,
                "inventory": runtime_globals.InventoryView,
                "vendor": runtime_globals.VendorInteractionViewBase,
            }
        ),
    ) is True
    assert runtime_globals.normal_hook_calls == 0
    assert len(runtime_globals.safe_hooks) == 4

    inventory_view = overlay_runtime.table_from(
        {
            "__class_name": "InventoryView",
            "_ui_renderer": overlay_runtime.table_from({}),
            "_ui_scenegraph": overlay_runtime.table_from({}),
            "_render_settings": overlay_runtime.table_from({"start_layer": 7}),
        }
    )
    # BaseView is called inside InventoryView.draw, but only the concrete
    # InventoryView post-draw callback may render the overlay.
    runtime_globals.safe_hooks[1].handler(inventory_view, 0.016, 1, None, 10)
    assert runtime_globals.widget_draw_calls == 0
    runtime_globals.safe_hooks[3].handler(inventory_view, 0.016, 1, None, 10)
    assert runtime_globals.renderer_begin_calls == 1
    assert runtime_globals.renderer_end_calls == 1
    assert runtime_globals.widget_draw_calls == 1
    assert inventory_view._render_settings.start_layer == 7
    assert inventory_view._auto_crafter_status_overlay.style.background.size[2] == 138
    assert inventory_view._auto_crafter_status_overlay.content.text == "one\ntwo\nthree\nfour\nfive"

    # Stable presentation revisions retain the already populated widget. A new
    # revision updates text and geometry without rebuilding the widget.
    runtime_globals.safe_hooks[3].handler(inventory_view, 0.016, 1, None, 10)
    assert runtime_globals.widget_draw_calls == 2
    overlay_runtime.execute(
        'AutoCrafterHelperHudState.presentation = function() return "updated", 1, 2 end'
    )
    runtime_globals.safe_hooks[3].handler(inventory_view, 0.016, 1, None, 10)
    assert runtime_globals.widget_draw_calls == 3
    assert inventory_view._auto_crafter_status_overlay.content.text == "updated"
    assert inventory_view._auto_crafter_status_overlay.style.background.size[2] == 112

    unrelated_view = overlay_runtime.table_from({"__class_name": "SocialMenuRosterView"})
    runtime_globals.safe_hooks[1].handler(unrelated_view, 0.016, 1, None, 10)
    assert runtime_globals.widget_draw_calls == 3

    print("Auto Crafter viewport resolution matrix tests passed.")


if __name__ == "__main__":
    main()
