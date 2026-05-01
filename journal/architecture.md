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

    Game -->|owns| Player
    Game -->|owns| DC
    Game -->|loads / frees| Event
    Game -->|drives| GUI
    Player -->|owns| Inventory
    Player -.->|spawns child on equip| Equipment
    GUI -->|contains| WorldMap
    WorldMap -->|contains| WMN
    Event -->|spawns / frees| Enemy

    GUI -. "attack_requested<br/>node_selected<br/>dialogue_complete<br/>..." .-> Game
    Player -. "turn_ended / damaged<br/>died / leveled_up / ..." .-> Game
    Event -. event_complete .-> Game
    Enemy -. "damaged / died<br/>turn_ended / attack" .-> Game
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
        +signal rest_requested
        +get_heal_amount(max_hp)
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
    note over User,Weapon: Player turn (with targeting)
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
    Event->>Event: _advance_phase (all enemies dead)
    Event-->>Game: event_complete
    Game->>Game: _apply_rewards(event.rewards)
    Game->>Event: _on_exit / queue_free
    end
```

---

## 4. Equipment / inventory data model

Equipment is data-driven. See [[detailed/character.md]]. `EquipmentData` is a `Resource` with a `scene: PackedScene` field; on equip, the `Inventory` hands the data to `Game` which instantiates the scene as a child of the `Player`. The runtime node (`Equipment` or `Weapon`) reads its visuals and audio back off the data. `ConsumableData` shares the `EquipmentData` base for the common fields (name, description, sprite, price) even though consumables aren't worn.

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
    }
    class WeaponData {
        +AudioStream attack_sfx
        +Array~Resource~ attacks
    }
    class AttackData {
        <<Resource>>
        +String attack_name
        +TargetMode target_mode
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
    class PlayerClassData {
        <<Resource>>
        +Dictionary starting_equipped
        +Array starting_rings
        +Array starting_consumables
        +Dictionary growth_rates
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
        +get_modifier(stat) float
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
    Inventory o-- EquipmentData : stores
    PlayerClassData o-- EquipmentData : starting loadout
    ShopData o-- EquipmentData : stock
    WeaponData o-- AttackData : attacks
    AttackData o-- Effect : effects
    ConsumableData o-- Effect : effects
    Effect <|-- DamageEffect
    Effect <|-- HealEffect
    Effect <|-- BuffEffect
```
