"""Pins the equipped and new-item highlight pass builders in layout_cards.lua.

The golden hashes were captured before the two builders were merged onto shared
helpers, so any drift in the generated passes (colors, sizes, z offsets, layer
counts, callbacks) fails here. Set BETTER_INVENTORY_WRITE_GOLDEN=1 to rewrite it.
"""

import hashlib
import itertools
import json
import os
from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNTIME_ROOT = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory"
GOLDEN_PATH = PROJECT_ROOT / "tests" / "fixtures" / "highlight_builders_golden.json"

HARNESS = r"""
local function stub_module()
	return setmetatable({}, { __index = function() return nil end })
end

function require() return stub_module() end

settings = {}
test_mod = {
	get = function(_, id) return settings[id] end,
	io_dofile = function(_, path)
		if path:find("layout_content", 1, true) then return TestLayoutContent end
		return stub_module()
	end,
}
function get_mod() return test_mod end
Application = { time_since_launch = function() return 1 end }

function describe_value(value, depth)
	local kind = type(value)

	if kind == "function" then
		return "<function>"
	elseif kind ~= "table" then
		return value
	end

	local keys = {}

	for key in pairs(value) do
		keys[#keys + 1] = key
	end

	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)

	local out = {}

	for _, key in ipairs(keys) do
		out[#out + 1] = { tostring(key), describe_value(value[key]) }
	end

	return out
end

local function probe(pass)
	local result = {}
	local contents = {
		{ equipped = true },
		{ equipped = false },
		{},
		{ element = { new_item_marker = true } },
		{ element = {} },
	}

	if pass.visibility_function then
		result.visibility = {}

		for index, content in ipairs(contents) do
			result.visibility[index] = pass.visibility_function(content) and true or false
		end
	end

	if pass.change_function then
		result.change = {}

		for _, case in ipairs({
			{ select = false, hover = false },
			{ select = true, hover = false },
			{ select = false, hover = true },
		}) do
			local removed = 0
			local element = { new_item_marker = true, item = {}, remove_new_marker_callback = function() removed = removed + 1 end }
			local content = { element = element, hotspot = { is_selected = case.select, is_hover = case.hover } }
			local style = { color = { 7, 1, 2, 3 } }

			pass.change_function(content, style)
			result.change[#result.change + 1] = { style.color[1], element.new_item_marker == nil, removed }
		end
	end

	return result
end

function build(builder_name, setting_values)
	settings = setting_values
	local template = {
		{ pass_type = "texture", style_id = "keep" },
		{ pass_type = "texture", value = "content/ui/materials/symbols/new_item_indicator", style = {}, visibility_function = function() return true end },
		{ pass_type = "texture", style_id = "better_inventory_equipped_highlight" },
		{ pass_type = "texture", style_id = "better_inventory_equipped_highlight_layer_2" },
		{ pass_type = "texture", style_id = "better_inventory_new_item_highlight" },
		{ pass_type = "texture", style_id = "better_inventory_new_item_highlight_layer_9" },
	}
	-- Seed the pulse alpha so the pulsing change callbacks write a known value.
	test_mod._better_inventory_pulsing_dash_alpha = 99
	TestCards[builder_name](test_mod, template, 320, 120)

	local out = {}

	for index, pass in ipairs(template) do
		local entry = describe_value(pass)
		out[index] = { entry, probe(pass) }
	end

	return out
end
"""


def lua_to_python(value):
    if hasattr(value, "items"):
        return {str(key): lua_to_python(child) for key, child in value.items()}
    return value


def scenarios():
    equipped_modes = [True, False, None, "bogus", "off", "soft_glow", "animated_dashes", "pulsing_dashes", "solid_border"]
    new_modes = [None, "bogus", "native", "soft_glow", "animated_dashes", "pulsing_dashes", "solid_border"]

    for mode, widths, color in itertools.product(
        equipped_modes, [(None, None, None), (1, 1, 5), (4, 3, 0)], [None, (10, 20, 30), (999, -5, 12.6)]
    ):
        values = {}
        if mode is not None:
            values["highlight_equipped_items"] = mode
        animated, solid, intensity = widths
        if animated is not None:
            values["equipped_highlight_animated_border_width"] = animated
            values["equipped_highlight_solid_border_width"] = solid
            values["equipped_highlight_glow_intensity"] = 40 if intensity == 5 else 250
        if color is not None:
            values["equipped_highlight_color_r"], values["equipped_highlight_color_g"], values["equipped_highlight_color_b"] = color
        yield "configure_equipped_highlight", values

    for mode, ack, widths, color in itertools.product(
        new_modes, [None, "hover", "select", "bogus"], [(None, None, None), (1, 1, 5), (4, 3, 0)], [None, (10, 20, 30), (999, -5, 12.6)]
    ):
        values = {}
        if mode is not None:
            values["new_item_highlight_mode"] = mode
        if ack is not None:
            values["new_item_acknowledge_mode"] = ack
        animated, solid, intensity = widths
        if animated is not None:
            values["new_item_highlight_animated_border_width"] = animated
            values["new_item_highlight_solid_border_width"] = solid
            values["new_item_highlight_glow_intensity"] = 40 if intensity == 5 else 250
        if color is not None:
            values["new_item_highlight_color_r"], values["new_item_highlight_color_g"], values["new_item_highlight_color_b"] = color
        yield "configure_new_item_highlight", values


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(HARNESS)
    lua.globals().TestLayoutContent = lua.execute(
        (RUNTIME_ROOT / "BetterInventory_layout_content.lua").read_text(encoding="utf-8"),
        name="layout_content",
    )
    lua.globals().TestCards = lua.execute(
        (RUNTIME_ROOT / "BetterInventory_layout_cards.lua").read_text(encoding="utf-8"),
        name="layout_cards",
    )
    build = lua.globals().build
    results = []

    for builder, values in scenarios():
        output = build(builder, lua.table_from(values))
        canonical = json.dumps(lua_to_python(output), sort_keys=True)
        results.append(
            {
                "builder": builder,
                "settings": values,
                "sha256": hashlib.sha256(canonical.encode("utf-8")).hexdigest()[:16],
            }
        )

    if os.environ.get("BETTER_INVENTORY_WRITE_GOLDEN") == "1":
        GOLDEN_PATH.parent.mkdir(parents=True, exist_ok=True)
        GOLDEN_PATH.write_text(json.dumps(results, indent=1, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
        print("golden written", len(results))
        return

    expected = json.loads(GOLDEN_PATH.read_text(encoding="utf-8"))
    actual = json.loads(json.dumps(results, sort_keys=True))
    assert len(actual) == len(expected)
    for index, (got, want) in enumerate(zip(actual, expected)):
        assert got == want, (index, got["builder"], got["settings"])
    print("BetterInventory highlight builder tests passed.")


if __name__ == "__main__":
    main()
