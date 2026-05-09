---
name: create-event
description: Interactive questionnaire to create a new game event JSON file for the crawler roguelike. Handles combat, dialogue, skill_check, rest, and boss types. Saves to resources/events/<type>/ and resources/dialogue/ as needed.
model: claude-haiku-4-5-20251001
---

# Create Event

Generate one or more JSON files for a game event. Ask each group, then write the file(s).

## Event types and output files

| Type        | Primary file                              | Secondary file(s)                          |
|-------------|-------------------------------------------|---------------------------------------------|
| combat      | resources/events/combat/<name>.json       | —                                           |
| dialogue    | resources/events/dialogue/<name>.json     | resources/dialogue/<name>.json              |
| skill_check | resources/events/skill_check/<name>.json  | —                                           |
| rest        | resources/events/rest/<name>.json         | —                                           |
| boss        | resources/events/boss/<name>.json         | resources/dialogue/<stem>.json (per trigger)|

## Available enemy scenes

```
res://scenes/skeleton.tscn
res://scenes/skeleton_lord.tscn
```

---

## Questionnaire

**Q1. Event type** — combat / dialogue / skill_check / rest / boss? [combat]

Then follow the section for the chosen type below.

---

### COMBAT

**Q2.** Event name (snake_case)?
**Q3.** Number of waves? [2]
**Q4.** For each wave: enemy scene (skeleton / skeleton_lord) and count?
**Q5.** Should any wave trigger a dialogue on enemy clear? If yes: which wave (1-indexed) and dialogue file stem? [no]
**Q6.** Rewards — experience and gold? [30, 10]

Output: `resources/events/combat/<name>.json`

```json
{
    "name": "<name>",
    "waves": [
        { "enemies": [{ "scene": "res://scenes/skeleton.tscn", "count": 2 }] },
        { "enemies": [{ "scene": "res://scenes/skeleton.tscn", "count": 3 }] }
    ],
    "rewards": {
        "experience": 30,
        "gold": 10
    }
}
```

For a wave with dialogue trigger on clear, add `"on_clear_trigger": "on_mid"` to that wave object.

---

### DIALOGUE

**Q2.** Event name and file stem (snake_case)?
**Q3.** Speaker name(s) — comma-separated, or null for narration?
**Q4.** Opening line (spoken or narration)?
**Q5.** Number of top-level player choices? [2]
**Q6.** For each choice, walk the branch recursively:
  - Choice text → speaker response text → further choices or terminal?
  - Any rewards on this node (experience, gold)?
  - Any consequence (set_flag: value)?

Continue until all paths end in a terminal node (choices: []).

Output two files:

`resources/events/dialogue/<name>.json`:
```json
{
    "name": "<name>",
    "dialogue": "res://resources/dialogue/<name>.json"
}
```

`resources/dialogue/<name>.json`:
```json
{
    "name": "<name>",
    "nodes": {
        "0": {
            "speaker": "Name or null",
            "text": "Opening line.",
            "consequence": null,
            "choices": [
                { "text": "Choice A", "next": "0-0" },
                { "text": "Choice B", "next": "0-1" }
            ]
        },
        "0-0": {
            "speaker": "Name",
            "text": "Response to A.",
            "consequence": { "action": "set_flag", "value": "flag_name" },
            "choices": [],
            "rewards": { "experience": 15, "gold": 3 }
        },
        "0-1": {
            "speaker": null,
            "text": "Narrated response to B.",
            "consequence": null,
            "choices": []
        }
    }
}
```

Node ID rules:
- Root node: `"0"`
- Children of "0": `"0-0"`, `"0-1"`, `"0-2"`
- Children of "0-1": `"0-1-0"`, `"0-1-1"`
- Terminal nodes have `"choices": []`
- `"consequence"` is null or `{ "action": "set_flag", "value": "<flag>" }`
- `"rewards"` is optional — only include on nodes where rewards are given

---

### SKILL_CHECK

**Q2.** Event name and label shown to the player (e.g. "Sneak past the guard")?
**Q3.** Stat to test — STR / DEF / CON / AGI / SPI / LCK? [AGI]
**Q4.** Rewards on success (experience, gold)? [15, 0]
**Q5.** Rewards on failure? [none]
**Q6.** on_success and on_failure event trigger strings (or empty)? ["", ""]

Output: `resources/events/skill_check/<name>.json`

```json
{
    "name": "<name>",
    "label": "<label shown to player>",
    "stat": "AGILITY",
    "rewards_on_success": { "experience": 15, "gold": 0 },
    "rewards_on_failure": {},
    "on_success": "",
    "on_failure": ""
}
```

Stat name strings: STRENGTH, DEFENSE, CONSTITUTION, AGILITY, SPIRIT, LUCK

---

### REST

**Q2.** Event name?
**Q3.** Heal amount — choose a preset or enter a custom expression.
  Presets:
    quarter_heal  →  "max_health * 0.25"
    half_heal     →  "max_health * 0.5"
    spirit_heal   →  "spirit * 4 + max_health * 0.1"
  Or enter a custom expression using: health, max_health, strength, defense, constitution, agility, spirit, luck
  [quarter_heal]

Output: `resources/events/rest/<name>.json`

```json
{
    "heal_expression": "max_health * 0.25"
}
```

---

### BOSS

**Q2.** Boss event name?
**Q3.** Number of waves? [4]
**Q4.** Which wave index triggers mid-fight dialogue on clear (1-indexed)? [3]
**Q5.** Enemy scenes per wave (skeleton / skeleton_lord and count)?
**Q6.** Dialogue file stems — intro (on start), mid (on that wave clear), victory (on final clear). Or "none" for any. [none, none, none]
**Q7.** If providing dialogue stems: walk the content of each dialogue file (same branching process as the DIALOGUE type above).
**Q8.** Rewards — experience and gold? [150, 75]

Output: `resources/events/boss/<name>.json`

```json
{
    "waves": [
        { "enemies": [{ "scene": "res://scenes/skeleton.tscn", "count": 1 }] },
        { "enemies": [{ "scene": "res://scenes/skeleton.tscn", "count": 2 }] },
        {
            "enemies": [{ "scene": "res://scenes/skeleton.tscn", "count": 2 }],
            "on_clear_trigger": "on_mid"
        },
        { "enemies": [{ "scene": "res://scenes/skeleton_lord.tscn", "count": 1 }] }
    ],
    "dialogue_triggers": {
        "on_start": "res://resources/dialogue/<intro_stem>.json",
        "on_mid": "res://resources/dialogue/<mid_stem>.json",
        "on_victory": "res://resources/dialogue/<victory_stem>.json"
    },
    "rewards": {
        "experience": 150,
        "gold": 75
    }
}
```

Omit any dialogue_trigger key if the user said "none" for that trigger.
If dialogue content was provided, write each as a separate `resources/dialogue/<stem>.json` file (same node format as the DIALOGUE type above).

---

## After writing

List each file path written. Ask if the user wants to create another event or a different content type.
