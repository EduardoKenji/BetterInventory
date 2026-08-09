from pathlib import Path

from lupa import LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNTIME_ROOT = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory"
LAYOUT_PATH = RUNTIME_ROOT / "auto_crafter" / "darktide" / "viewport_layout.lua"
PANEL_PATH = RUNTIME_ROOT / "auto_crafter" / "darktide" / "panel.lua"
OVERLAY_PATH = RUNTIME_ROOT / "auto_crafter" / "darktide" / "view_status_overlay.lua"
HUD_PATH = RUNTIME_ROOT / "auto_crafter" / "darktide" / "hud_element.lua"


def main() -> None:
    layout = LuaRuntime(unpack_returned_tuples=True).execute(
        LAYOUT_PATH.read_text(encoding="utf-8")
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
    assert "BRUNT_HORIZONTAL_OFFSET = 190" in overlay_source
    assert "centered_top_pivot" not in overlay_source
    assert "view._auto_crafter_status_draw_depth == 0" in overlay_source
    assert 'require("scripts/mods/BetterInventory' not in overlay_source
    assert 'horizontal_alignment = "center"' in hud_source
    assert 'vertical_alignment = "top"' in hud_source

    print("Auto Crafter viewport resolution matrix tests passed.")


if __name__ == "__main__":
    main()
