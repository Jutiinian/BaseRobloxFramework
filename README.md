# BaseRobloxFramework

A game-agnostic Roblox framework I built around one goal: code that is easy to maintain, easy to extend, and actually enjoyable to work with.

---

## Why This Exists

After working with many different frameworks and codebases over the years, a pattern kept emerging — things would start clean, but over time they'd become brittle, tangled, and hard to reason about. Adding a new feature meant digging through layers of unrelated code. Changing one thing would quietly break another. Eventually the codebase would reach a point where rewriting felt easier than continuing.

This framework is my answer to that. The goal was to build something where the infrastructure stays stable, features stay isolated, and the whole thing never becomes a mess worth throwing away. Code that is easy to maintain today should still be easy to maintain a year from now.

---

## How It Works

The framework is split into two distinct layers:

### Service Layer
The reusable, game-agnostic foundation. These services handle the infrastructure that every Roblox experience needs, written once and built to last:

- **DataService** — Persistent player data using ProfileStore, with server-to-client replication and reactive bindable events
- **StateService** — Replicate state on any Instance to selected clients or locally, with reactive signals and observers
- **InputService** — Action-based input handling within toggleable Contexts, so input is always scoped and manageable
- **MarketService** — Clean abstractions over gamepasses and Developer Products

Each service is fully typed with Luau's `--!strict` mode and documented so that anyone can pick it up without having to read through the implementation.

### Feature Layer
Game-specific modules that consume the Service Layer. Features are self-contained — each one owns a single responsibility and uses services underneath without caring how they work internally.

**In this base framework, the Feature Layer is intentionally left empty.** Only an example feature is included to demonstrate the pattern. Features are added per-game when the framework is actually used — keeping the base clean and unopinionated.

---

## Why Two Layers

The biggest source of pain in most Roblox codebases is that everything is connected to everything. One change ripples outward in unexpected ways. Features depend on other features. Services are tangled into game logic.

Separating infrastructure from game-specific code solves this. The Service Layer is stable and rarely needs to change. The Feature Layer is where all the creative, game-specific work lives — and because features only depend on services, not on each other, they stay isolated and easy to reason about. Adding something new never means untangling something old.

---

## Tooling

This project uses the following Roblox development workflow:

- **Rojo** — syncs the `src/` directory to Roblox Studio
- **Wally** — package management for Luau dependencies
- **Rokit** — tool version management
- **Selene** — Luau linting
- **StyLua** — code formatting
- **Luau-LSP** — full type checking and intellisense in VS Code
- **Zap** — typed, structured networking

---

## Setup

Quick start:
```sh
rokit install
sh scripts/process-remotes.sh
sh scripts/process-tree.sh
sh scripts/install-packages.sh
rojo serve
```

Then connect via the Rojo plugin in Roblox Studio.

---

## Status

The Service Layer is stable and actively maintained. The Feature Layer is intentionally empty in this base — meant to grow per-game as the framework is put to use.