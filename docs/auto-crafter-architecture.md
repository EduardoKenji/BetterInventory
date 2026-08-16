# Auto Crafter Helper architecture

## Composition boundary

`BetterInventory_auto_crafter.lua` is the composition root. It loads modules through the host mod loader, validates their public contracts, injects them into the controller and panel, and disables the affected capability when a required module is unavailable. Core modules do not load BetterInventory or Darktide modules themselves.

This boundary is the extraction point for a future standalone mod: a standalone entry point can reuse `auto_crafter/core`, then provide its own settings, clock, reporting, selection, backend, context, and UI adapters.

## Layers and ownership

| Layer | Modules | Ownership |
| --- | --- | --- |
| Composition | `BetterInventory_auto_crafter.lua` | Module loading, dependency validation, lifecycle routing, notifications, Games Lantern orchestration |
| Core policies | `core/candidate_policy.lua`, `core/mastery_policy.lua`, `core/planner.lua` | Deterministic calculations and validation without game API access |
| Core controller | `core/controller.lua` | Generation tokens, async-operation ownership, reconciliation, probe/catalog scheduling, shutdown |
| Core workflows | `core/phase3_workflow.lua`, `core/phase4_workflow.lua`, `core/inventory_workflow.lua`, `core/imported_queue_workflow.lua` | Methods installed onto one controller instance through an explicit service table |
| Darktide adapters | `darktide/backend.lua`, `darktide/context.lua` | Game services, account mutations, authoritative snapshots, character/view validity |
| Darktide UI | `darktide/panel.lua`, `darktide/panel_blueprints.lua`, HUD/overlay/viewport modules | View state and lifecycle separated from widget-pass definitions |
| Games Lantern adapters | `games_lantern/*` | Clipboard, parsing, resolution, transport, queue state, selection coordination |

## Async and mutation invariants

- The controller remains the sole owner of active generations and destructive workflow state.
- Every account mutation continues through the backend and shared account-operation guard.
- Character, selection, and authoritative-snapshot reconciliation remain fail closed.
- Workflow installers copy only the service functions/constants they use. They do not retain the transient composition table.
- `shutdown`, context changes, and view transitions clear snapshots, queues, imported jobs, workflow state, pending references, and settled backend-operation caches.

## Performance rules

- Pure policies stay allocation-conscious and operate on supplied tables; they do not poll or retain runtime objects.
- Per-frame work remains amortized by existing probe, idle-poll, presentation, and Games Lantern transport intervals.
- Workflow execution remains sequential where account ordering matters. No parallel mutation path is introduced by module composition.
- Panel blueprint definitions are loaded once and shared; panel instances retain only the definitions required to render.
- Every nested Auto Crafter Lua module is declared in `runtime-module-ownership.json` and enforced at 100,000 bytes by `tests/check_architecture.py`.

## Standalone host contract

A future host should supply the same injected ports used by the current composition root:

- backend reads/mutations and account-operation arbitration;
- current-character and runtime/view validity;
- settings get/set, monotonic clock, reporting, and logging;
- current Brunt offer selection and manual mark selection;
- optional Games Lantern clipboard, transport, resolver, queue, and selection adapters;
- optional Darktide panel/HUD presentation.

Core construction and UI construction deliberately fail with an error result when their required modules are missing or incomplete. This makes packaging mistakes visible without allowing a partially wired destructive workflow to run.
