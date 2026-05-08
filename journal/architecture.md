# Architecture Map

A Mermaid-rendered snapshot of how the crawler's code fits together. This file answers **what** is connected to **what** — for the **why** behind each decision, see [[design.md]].

This doc is hand-maintained. When a class is added/renamed, a signal is rewired, or the turn/event flow changes, update the relevant diagram below. Don't regenerate the whole file — scoped edits keep it auditable. See `CLAUDE.md` § Architecture map for the maintenance contract.

Render in any Mermaid-aware viewer: GitHub, VS Code ("Markdown Preview Mermaid Support"), Obsidian.

---

## 1. High-level architecture

`Game` is the hub. It owns the `Player` for the whole run, loads one `Event` at a time, and drives the passive `GUI` via direct method calls. The `GUI` emits intent signals back up; `Game` decides what they mean. Only `game.gd` holds `var player` — events reach the player *through* `Game`, never directly. See [[detailed/game-flow.md]] and [[detailed/gui-design.md]].

```mermaid
flowchart TD
    Game["Game<br/>turn state machine"]
    Player["Player"]
    Inventory["Inventory"]
    Equipment["Equipment / Weapon<br/>(runtime nodes)"]
    Event["Event<br/>(abstract)"]
    GUI["GUI"]
    WorldMap["WorldMap"]
    WMN["WorldMapNode<br/>subclasses"]
    DC["DialogueConsequences"]
    Enemy["Enemy subclasses<br/>(owned by Event)"]
    SM["SaveManager<br/>(static)"]
    RSD["RunSaveData<br/>(Resource)"]

    Game -->|owns| Player
    Game -->|owns| DC
    Game -->|loads / frees| Event
    Game -->|drives| GUI
    Player -->|owns| Inventory
    Player -.->|spawns child on equip| Equipment
    GUI -->|contains| WorldMap
    WorldMap -->|contains| WMN
    Event -->|spawns / frees| Enemy
    Game -->|write / clear| SM
    SM -->|save / load| RSD

    GUI -. "attack_requested<br/>node_selected<br/>continue_requested<br/>..." .-> Game
    Player -. "turn_ended / damaged<br/>died / leveled_up / ..." .-> Game
    Event -. event_complete .-> Game
    Enemy -. "damaged / died / death_finished<br/>turn_ended / attack" .-> Game
    Inventory -. "slot_changed<br/>bag_changed / ..." .-> GUI

    classDef hub fill:#ffeaa7,stroke:#333,stroke-width:2px
    class Game hub
```

---

## 2. Event class hierarchy

All events inherit `Event` and walk the phase enum `SETUP → RUNNING → RESOLUTION → COMPLETE`. See [[detailed/event-system.md]]. Each emits `event_complete` when done and `Game` reads `event.rewards` off the corpse before freeing it. `BossEvent` is the exception — it emits `boss_defeated` on the last wave so `Game` can branch to the VICTORY state instead of the normal post-event flow.

```mermaid
classDiagram
    class Event {
        <<abstract>>
        +Phase phase
        +Dictionary rewards
        +initialize(data)
        +start()
        #_on_enter(game)
        #_on_exit(game)
        #_advance_phase()
        +signal event_complete
    }
    class CombatEvent {
        +signal enemy_added
        +signal player_attacked
        +signal enemy_turns_complete
        +signal dialogue_trigger_fired
        +signal enemy_turn_started
        +signal enemy_turn_ended
        +signal wave_started
        +signal wave_completed
    }
    class BossEvent {
        +signal boss_defeated
        #_advance_phase() override
    }
    class DialogueEvent {
        +signal dialogue_requested
    }
    class SkillCheckEvent {
        +signal skill_check_requested
        +signal dialogue_requested
    }
    class RestEvent {
        +String heal_expression
        +signal rest_requested
        +get_heal_amount(target)
    }
    class ShopEvent {
        +signal shop_requested
        +signal stock_changed
    }

    Event <|-- CombatEvent
    CombatEvent <|-- BossEvent
    Event <|-- DialogueEvent
    Event <|-- SkillCheckEvent
    Event <|-- RestEvent
    Event <|-- ShopEvent
```

---

## 3. Turn & signal flow

Three flows that cover the combat loop end-to-end. See [[detailed/game-flow.md]] and [[detailed/enemy-system.md]]. The **player turn** is gated by the weapon's attack animation (`turn_ended` doesn't fire until the sprite finishes). The **enemy turn** runs one enemy at a time from a queue `CombatEvent` maintains. **Event completion** is the single exit point — `Game._on_event_complete` applies rewards and frees the event.

`game.gd` also emits a **lifecycle signal bus** at each transition — `player_turn_started/ended`, `enemy_turn_started/ended(enemy)`, `event_started/completed(event)`, `combat_wave_started/completed`, `player_attack_hit`, `enemy_attack_hit`, `player_damaged/healed`, `enemy_damaged/died`, `consumable_used`. These are omitted from the flow below to keep it readable; they fire in parallel with the sequence shown. Statuses, blessings, and equipment procs will subscribe to them in later phases.

```mermaid
sequenceDiagram
    actor User
    participant GUI
    participant Game
    participant Player
    participant Weapon
    participant Enemy
    participant Event as CombatEvent

    rect rgb(230, 245, 255)
    note over User,Weapon: Player turn — attack (with targeting)
    User->>GUI: click action button
    GUI->>Game: attack_requested(name)
    Game->>Game: enter targeting state
    note over Game: indicator shown on target
    User->>GUI: click same button (confirm)
    GUI->>Game: attack_requested(name)
    Game->>Player: set_pending_attack_payload(AttackData, targets)
    Game->>Player: execute_action(name)
    Player-->>Weapon: attack_performed(AttackData, targets)
    Weapon->>Weapon: play "attack" anim
    Game->>Game: apply effects to each target
    Weapon-->>Player: animation_finished
    Player-->>Game: turn_ended
    Game->>Game: state = ENEMY_TURN
    end

    rect rgb(220, 235, 255)
    note over User,Player: Player turn — spell cast
    User->>GUI: click spell button
    GUI->>Game: attack_requested(spell_name)
    Game->>Game: mana check; enter targeting state
    User->>GUI: click same button (confirm)
    GUI->>Game: attack_requested(spell_name)
    Game->>Player: set_pending_spell_payload(SpellData, targets)
    Game->>Player: execute_action(spell_name)
    Player->>Player: spend_mana; emit cast_performed
    Player-->>Game: cast_hit(spell, targets)
    Game->>Game: apply spell effects to each target
    Player-->>Game: turn_ended
    Game->>Game: state = ENEMY_TURN
    end

    rect rgb(255, 240, 230)
    note over Game,Enemy: Enemy turn
    Game->>Enemy: take_turn()
    Enemy->>Enemy: _perform_action()
    Enemy-->>Game: attack(damage)
    Game->>Player: take_damage(damage)
    Player-->>GUI: damaged(amount)
    Enemy-->>Game: turn_ended
    Game->>Game: state = PLAYER_TURN
    end

    rect rgb(235, 255, 235)
    note over Event,Game: Event completion
    Event->>Enemy: await death_finished (all dying enemies)
    Event->>Event: _advance_phase (all enemies dead)
    Event-->>Game: event_complete
    Game->>Game: _apply_rewards(event.rewards)
    Game->>Event: _on_exit / queue_free
    Game->>Game: SaveManager.write(self)
    end
```

---

## 4. Equipment / inventory data model

Equipment is data-driven. See [[detailed/character.md]]. `EquipmentData` is a `Resource` with a `scene: PackedScene` field; on equip, the `Inventory` hands the data to `Game` which instantiates the scene as a child of the `Player`. The runtime node (`Equipment` or `Weapon`) reads its visuals and audio back off the data. `ConsumableData` shares the `EquipmentData` base for the common fields (name, description, sprite, price) even though consumables aren't worn.

Phase 5 added equipment passives: `on_equip_effects` / `on_unequip_effects` (fired by Player on equip/unequip for any item), `proc_effects` (`Array[ProcDef]`, wired to the game lifecycle bus by the scene-backed Equipment node on equip), and `conditional_modifiers` (`Array[ConditionalModifier]`, evaluated in `Player.get_effective_stat` with a re-entrancy guard). See [[design.md]] — Effect System v2.

Phase 6 added `BlessingData` — run-long permanent boons held on `Player._blessings`. `add_blessing` / `remove_blessing` wire/unwire the blessing's `subscriptions` (signal name → Effect, applied to the player) to the game lifecycle bus via `Subscription`. Stat modifiers are summed into `get_effective_stat`. Blessings are granted via `event.rewards["blessings"]` or `PlayerClassData.starting_blessings`.

Phase 7 added the spell system. `SpellData` (resource, mirrors `AttackData`) carries `spell_name`, `mana_cost`, `target_mode`, and `effects: Array[Resource]`. `EquipmentData` gains `spell_cost_multiplier: float = 1.0` and `bonus_prep_slots: int = 0`. `WeaponData` gains `innate_spells: Array[Resource]` — registered as player actions on equip alongside `attacks`, bypassing prep slots. `Enums.Slot` gains `OFFHAND` (value 6). `Player` gains mana (`max_mana`, `mana` derived from SPI like health from CON), a learned-spell roster, a prep-slot-indexed prepared list, and the `_do_cast` action callable. `PlayerClassData` gains `class_mana_bonus`, `starting_prep_slots`, `starting_learned_spells`, `starting_prepared_spells`. Mana restores fully at world-node entry in `_on_world_node_selected`.

```mermaid
classDiagram
    class EquipmentData {
        <<Resource>>
        +String item_name
        +Dictionary stat_modifiers
        +PackedScene scene
        +Enums.Slot slot
        +bool is_ring
        +int price
        +Array on_equip_effects
        +Array on_unequip_effects
        +Array proc_effects
        +Array conditional_modifiers
        +float spell_cost_multiplier
        +int bonus_prep_slots
    }
    class ProcDef {
        <<Resource>>
        +StringName trigger
        +String chance_expression
        +Effect effect
    }
    class ConditionalModifier {
        <<Resource>>
        +Enums.Stat stat
        +String amount_expression
        +String guard_expression
    }
    class WeaponData {
        +AudioStream attack_sfx
        +Array~Resource~ attacks
        +Array~Resource~ innate_spells
    }
    class AttackData {
        <<Resource>>
        +String attack_name
        +TargetMode target_mode
        +Array~Resource~ effects
    }
    class SpellData {
        <<Resource>>
        +String spell_name
        +float mana_cost
        +AttackData.TargetMode target_mode
        +Array~Resource~ effects
    }
    class Effect {
        <<Resource>>
        +apply(source, target)
    }
    class DamageEffect {
        +String damage_expression
    }
    class HealEffect {
        +String heal_expression
    }
    class BuffEffect {
        +Enums.Stat stat
        +String amount_expression
        +int duration
    }
    class ConsumableData {
        +TargetMode target_mode
        +Array~Resource~ effects
    }
    class BlessingData {
        <<Resource>>
        +String display_name
        +Dictionary stat_modifiers
        +Dictionary subscriptions
    }
    class PlayerClassData {
        <<Resource>>
        +Dictionary starting_equipped
        +Array starting_rings
        +Array starting_consumables
        +Array starting_blessings
        +Dictionary growth_rates
        +float class_mana_bonus
        +int starting_prep_slots
        +Array starting_learned_spells
        +Array starting_prepared_spells
    }
    class ShopData {
        <<Resource>>
        +String shop_name
        +Array~EquipmentData~ stock
        +float buy_price_multiplier
        +float sell_price_multiplier
    }
    class Equipment {
        <<Node2D>>
        +EquipmentData data
        +Game _game
        +Subscription _subscription
        +get_modifier(stat) float
        +_on_equipped()
        +_on_unequipped()
    }
    class Weapon {
        +AnimationPlayer anim_player
        +signal animation_finished
    }
    class Inventory {
        <<Node>>
        -Dictionary _equipped
        -Array _rings
        -Array _consumable_belt
        -Array~EquipmentData~ _bag
        +signal slot_changed
        +signal ring_changed
        +signal bag_changed
        +signal consumable_belt_changed
    }

    EquipmentData <|-- WeaponData
    EquipmentData <|-- ConsumableData
    Equipment <|-- Weapon
    EquipmentData ..> Equipment : scene instantiates
    EquipmentData o-- ProcDef : proc_effects
    EquipmentData o-- ConditionalModifier : conditional_modifiers
    ProcDef o-- Effect : effect
    Inventory o-- EquipmentData : stores
    PlayerClassData o-- EquipmentData : starting loadout
    PlayerClassData o-- BlessingData : starting_blessings
    BlessingData o-- Effect : subscriptions
    ShopData o-- EquipmentData : stock
    WeaponData o-- AttackData : attacks
    WeaponData o-- SpellData : innate_spells
    AttackData o-- Effect : effects
    SpellData o-- Effect : effects
    ConsumableData o-- Effect : effects
    Effect <|-- DamageEffect
    Effect <|-- HealEffect
    Effect <|-- BuffEffect
    Effect <|-- StatusEffect
    StatusEffect o-- StatusData
    StatusData o-- Effect : on_apply/on_tick/on_expire
```

---

## 5. Combatant class hierarchy

`Combatant` is a `Node2D`-extending base class shared by `Player` and `Enemy`. It owns the status system (`_active_statuses`, `apply_status`, `remove_status`, `_tick_statuses`) and a virtual `_get_base_stat`. `get_effective_stat` on `Combatant` computes base + active-status stat_modifiers; `Player` overrides to also sum equipment modifiers. `BuffEffect` and `StatusEffect` both call `target.apply_status()` — valid for both combatants. `Player._on_stat_modifiers_changed()` calls `_recalculate_max_health()` so CON statuses update max HP immediately. See [[design.md]] — Effect System v2 (2026-05-02).

`Player.reset_run_state()` is the single owner of per-run teardown (equipment teardown, blessing/status clear, spell roster clear, inventory dungeon-lock reset). Both `initialize()` and `apply_save_dict()` call it first; both game entry points (`_on_character_created`, `_on_continue_requested`) call `Game._reset_run_state()` before touching the player. See [[design.md]] — Run-state reset pattern (2026-05-08).

```mermaid
classDiagram
    class StatusInstance {
        <<Resource>>
        +StatusData data
        +int turns_remaining
        +Node source
    }
    class Combatant {
        <<Node2D>>
        +signal status_applied(data)
        +signal status_ticked(data, turns_remaining)
        +signal status_expired(data)
        -Array~StatusInstance~ _active_statuses
        +get_effective_stat(stat) float
        +apply_status(data, source)
        +remove_status(tag)
        +has_preventing_status() bool
        +get_active_statuses() Array
        +_tick_statuses()
        #_on_stat_modifiers_changed()
        #_get_base_stat(stat) float
    }
    class Player {
        +initialize(name, class_data)
        +reset_run_state()
        +apply_save_dict(d)
        +pass_turn()
        +get_effective_stat(stat) float
        +add_blessing(data)
        +remove_blessing(data)
        +get_blessings() Array
        -Array _blessings
        -Dictionary _blessing_subs
        -Game _game
        #_on_stat_modifiers_changed()
        #_get_base_stat(stat) float
    }
    class Enemy {
        +float defense
        +take_turn()
        #_get_base_stat(stat) float
    }
    class Skeleton {
    }
    class SkeletonLord {
    }

    Combatant o-- StatusInstance : _active_statuses
    StatusInstance o-- StatusData : data
    Combatant <|-- Player
    Combatant <|-- Enemy
    Enemy <|-- Skeleton
    Enemy <|-- SkeletonLord
```
