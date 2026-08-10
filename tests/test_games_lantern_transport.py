from pathlib import Path

from lupa import LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
TRANSPORT_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "auto_crafter" / "games_lantern" / "transport.lua"


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    transport_module = lua.execute(TRANSPORT_PATH.read_text(encoding="utf-8"), name=str(TRANSPORT_PATH))
    url = "https://darktide.gameslantern.com/builds/00000000-0000-0000-0000-000000000000"

    assert transport_module._test.canonical_url(url) is True
    assert transport_module._test.canonical_url(url + "/extra") is False
    assert transport_module._test.canonical_url("https://evil.example/builds/00000000-0000-0000-0000-000000000000") is False

    def callback_wrapper(callback):
        return lua.eval("function(callback) return function(...) return callback(...) end end")(callback)

    clock = [0.0]
    responses = [{"done": False}]
    spawned = []
    cleaned = []
    reports = []

    def spawn(raw_url, generation, max_bytes):
        spawned.append((str(raw_url), int(generation), int(max_bytes)))
        return {"generation": int(generation)}

    def poll(handle, generation, max_bytes):
        return responses.pop(0) if responses else {"done": False}

    adapter = lua.table_from(
        {
            "spawn": callback_wrapper(spawn),
            "poll": callback_wrapper(poll),
            "cleanup": callback_wrapper(lambda handle: cleaned.append(handle["generation"]) or True),
        }
    )
    transport = transport_module.new(
        lua.table_from(
            {
                "adapter": adapter,
                "clock": callback_wrapper(lambda: clock[0]),
                "report": callback_wrapper(lambda kind, payload: reports.append(str(kind))),
                "timeout_seconds": 20,
                "max_bytes": 10,
            }
        )
    )

    assert transport.start(transport, url)[0] is True
    assert transport.update(transport) == "running"
    clock[0] = 21
    assert transport.update(transport) == "failed"
    assert transport.snapshot(transport)["last_error"] == "transport_timeout"
    assert cleaned == [1]

    # HTTP errors and oversized bodies fail closed without returning content.
    clock[0] = 0
    responses[:] = [{"done": True, "status": 503, "exit_code": 0, "body": "backend", "bytes": 7}]
    assert transport.start(transport, url)[0] is True
    assert transport.update(transport) == "failed"
    assert transport.snapshot(transport)["last_error"] == "transport_http_status"

    responses[:] = [{"done": True, "status": 200, "exit_code": 0, "body": "01234567890", "bytes": 11}]
    assert transport.start(transport, url)[0] is True
    assert transport.update(transport) == "failed"
    assert transport.snapshot(transport)["last_error"] == "transport_response_too_large"

    responses[:] = [{"done": True, "status": 200, "exit_code": 0, "body": "<ok>", "bytes": 4}]
    assert transport.start(transport, url)[0] is True
    assert transport.update(transport) == "complete"
    result = transport.take_result(transport)
    assert result["status"] == 200
    assert result["body"] == "<ok>"
    assert transport.snapshot(transport)["state"] == "idle"

    # A new paste cancels the old generation, and explicit cancel cleans it.
    assert transport.start(transport, url)[0] is True
    old_generation = transport.snapshot(transport)["generation"]
    assert transport.cancel(transport, "new_paste") is True
    assert transport.snapshot(transport)["state"] == "cancelled"
    assert transport.snapshot(transport)["generation"] > old_generation
    assert "transport_cancelled" in reports

    assert transport.start(transport, "https://darktide.gameslantern.com/builds/bad")[0] is False


if __name__ == "__main__":
    main()
