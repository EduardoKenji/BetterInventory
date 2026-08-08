"""Load the production localization aggregator with real shard tables."""

from __future__ import annotations

from pathlib import Path


SHARD_SUFFIXES = ("core", "features", "zh_cn")


def load_localization(lua: object, localization_path: Path) -> object:
    runtime_root = localization_path.parent
    shards = {
        f"BetterInventory_localization_{suffix}": lua.execute(
            (runtime_root / f"BetterInventory_localization_{suffix}.lua").read_text(
                encoding="utf-8"
            ),
            name=str(runtime_root / f"BetterInventory_localization_{suffix}.lua"),
        )
        for suffix in SHARD_SUFFIXES
    }
    lua.globals().better_inventory_localization_shards = lua.table_from(shards)
    lua.execute(
        r'''
        better_inventory_previous_get_mod = rawget(_G, "get_mod")
        function get_mod(name)
            if name == "BetterInventory" then
                return {
                    io_dofile = function(_, path)
                        local shard_name = string.match(path, "([^/]+)$")
                        return better_inventory_localization_shards[shard_name]
                    end,
                }
            end

            return better_inventory_previous_get_mod and better_inventory_previous_get_mod(name)
        end
        ''',
    )
    localization = lua.execute(
        localization_path.read_text(encoding="utf-8"),
        name=str(localization_path),
    )
    previous_get_mod = lua.globals().better_inventory_previous_get_mod
    lua.globals().get_mod = previous_get_mod
    return localization
