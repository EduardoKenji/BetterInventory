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
        (1920, 1080, 1.0, 1380, 580),
        (2560, 1440, 4 / 3, 1380, 580),
        (3440, 1440, 4 / 3, 2040, 910),
        (5120, 1440, 4 / 3, 3300, 1540),
        (3840, 2160, 2.0, 1380, 580),
    )

    for width, height, scale, expected_panel_x, expected_hud_x in resolution_matrix:
        panel_x, panel_y = layout.panel_pivot(width, height, scale, 445, 520)
        hud_x, hud_y = layout.centered_top_pivot(width, height, scale, 760, 112, 42)
        assert (panel_x, panel_y) == (expected_panel_x, 110)
        assert (hud_x, hud_y) == (expected_hud_x, 42)

    panel_source = PANEL_PATH.read_text(encoding="utf-8")
    overlay_source = OVERLAY_PATH.read_text(encoding="utf-8")
    hud_source = HUD_PATH.read_text(encoding="utf-8")
    assert "layout.panel_pivot" in panel_source
    assert "self:_update_pivot()" in panel_source
    assert "ViewportLayout.centered_top_pivot" in overlay_source
    assert "pcall(mod.io_dofile" in overlay_source
    assert 'require("scripts/mods/BetterInventory' not in overlay_source
    assert 'horizontal_alignment = "center"' in hud_source
    assert 'vertical_alignment = "top"' in hud_source

    print("Auto Crafter viewport resolution matrix tests passed.")


if __name__ == "__main__":
    main()
