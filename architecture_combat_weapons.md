# Architectural Specification: Weapon & Skill Synergy System (`architecture_combat_weapons.md`)

## 1. Executive Summary & Architectural Overview

This specification defines the data models, mathematical formulas, node responsibilities, and execution flows for **Trail of the Grandmaster's** integrated **Weapon & Skill Synergy System**.

### Core Pillars
1. **Strict Weapon-to-Skill Binding**: Every weapon in the game is explicitly bound to one of **7 Combat Weapon Skills**. Attacking with a weapon (via bump-to-attack in melee, manual line-of-fire in ranged, or weapon active ability) exclusively trains its parent `associated_skill_id`.
2. **Level 25 Milestone — Weapon-Unique Active Abilities**: Reaching **Level 25.0** in a weapon skill unlocks the unique secondary active attack embedded in each weapon of that category. These abilities are first-class citizens on the 10-slot bottom `HotbarBar`.
3. **Level 50 Milestone — Accuracy Attribute Scaling Shift**:
   - From **00.0 to 49.9**, weapon accuracy (`Effective Weapon Skill`) scales strictly off the skill's **Primary Attribute** ($+0.5$ per attribute point).
   - At **50.0+**, the skill either unlocks additive scaling from its **Secondary Attribute** ($+0.5 \times \text{Primary} + 0.5 \times \text{Secondary}$) OR **doubles the effectiveness of its Primary Attribute** ($+1.0 \times \text{Primary}$) if no secondary attribute exists.
4. **Symmetric Dual-Check Hit Chance Formula**:
   $$\text{Hit Chance} = \frac{\text{Attacker Weapon Skill} + 50}{(\text{Defender Skill} + 50) \times 2} + \text{Attacker Mods} - \text{Defender Mods}$$
   where $\text{Defender Skill} = \max(\text{Defender Equipped Weapon Skill},\ \text{Defender Dedicated Defensive Skill})$.

---

## 2. System Architecture & Component Diagram

```mermaid
classDiagram
    class SkillData {
        +SkillId skill_id
        +String skill_name
        +SkillTier tier
        +String primary_attribute
        +String secondary_attribute
        +bool doubles_primary_at_50
        +float level
        +get_accuracy_attribute_bonus(attrs: AttributesData) float
        +get_effective_level_with_attributes(attrs: AttributesData) float
    }

    class WeaponAbilityData {
        +String ability_id
        +String ability_name
        +SkillId required_skill_id
        +float required_skill_level
        +float damage_multiplier
        +float accuracy_bonus
        +float armor_penetration
        +int range_tiles
        +int area_radius
        +int cooldown_turns
        +String special_effect
        +String description
    }

    class ItemData {
        +String item_id
        +String item_name
        +SkillId associated_skill_id
        +Handedness handedness
        +WeaponType weapon_type
        +int base_damage_min
        +int base_damage_max
        +float accuracy_bonus
        +float defense_bonus
        +float backstab_multiplier
        +float poison_chance
        +bool requires_ammo
        +WeaponAbilityData active_ability
    }

    class CombatComponent {
        +calculate_hit_chance(defender: Node2D, weapon: ItemData, ability: WeaponAbilityData) Dictionary
        +execute_attack(defender: Node2D, weapon: ItemData, ability: WeaponAbilityData) Dictionary
        +execute_ranged_attack(origin: Vector2i, target: Vector2i, grid: DungeonGrid, weapon: ItemData, ammo: ItemData, ability: WeaponAbilityData) Dictionary
        +execute_weapon_ability(target_cell: Vector2i, grid: DungeonGrid, weapon: ItemData, ability: WeaponAbilityData) Dictionary
    }

    class HotbarBar {
        +SlotType { EMPTY, SPELL, ITEM, WEAPON_ABILITY }
        +set_slot_weapon_ability(slot_idx: int, weapon: ItemData, ability: WeaponAbilityData)
        +sync_unlocked_weapon_abilities(player: Node2D)
    }

    ItemData *-- WeaponAbilityData : embeds Lv.25 Active
    ItemData --> SkillData : maps via associated_skill_id
    CombatComponent --> ItemData : reads stats & skill binding
    CombatComponent --> SkillData : trains associated_skill_id
    HotbarBar --> WeaponAbilityData : equips & triggers at Lv.25+
```

---

## 3. Skill Categories & Level 50 Attribute Scaling Maps

### 3.1. Enumeration Updates (`SkillData.SkillId`)

In [`scripts/resources/SkillData.gd`](file:///c:/Users/tonyb/OneDrive/Desktop/Trail%20of%20the%20Grandmaster/trail-of-the-grandmaster/scripts/resources/SkillData.gd), the Tier 1 Starting Combat Skills are updated to include all **7 Combat Weapon Skills**:

1. `SWORDSMANSHIP`
2. `BLUNT_WEAPON_FIGHTING` *(replaces `MACE_FIGHTING`; preserve `const MACE_FIGHTING = SkillId.BLUNT_WEAPON_FIGHTING` alias for backward compatibility)*
3. `FINESSE_WEAPON_FIGHTING` *(new Tier 1 Starting Skill)*
4. `POLEARMS`
5. `BRAWLING`
6. `ARCHERY`
7. `THROWING`

### 3.2. Attribute Scaling Matrix (Level 00.0–49.9 vs. Level 50.0+)

| Skill Enum (`SkillId`) | Display Name | Primary Attribute (Lv 0.0–49.9) | Level 50.0+ Scaling Shift Behavior | Formula for $\text{AttrBonus}(L)$ at Lv < 50 vs. Lv $\ge$ 50 |
| :--- | :--- | :---: | :---: | :--- |
| `SWORDSMANSHIP` | **Swordsmanship** | **Strength** (`STR`) | Unlocks **Secondary Dexterity** (`DEX`) | $<50$: $0.5 \cdot \text{STR}$<br>$\ge 50$: $0.5 \cdot \text{STR} + 0.5 \cdot \text{DEX}$ |
| `BLUNT_WEAPON_FIGHTING` | **Blunt Weapon Fighting** | **Strength** (`STR`) | **Doubles Primary Strength** ($2\times \text{STR}$) | $<50$: $0.5 \cdot \text{STR}$<br>$\ge 50$: $1.0 \cdot \text{STR}$ |
| `FINESSE_WEAPON_FIGHTING` | **Finesse Weapon Fighting** | **Dexterity** (`DEX`) | **Doubles Primary Dexterity** ($2\times \text{DEX}$) | $<50$: $0.5 \cdot \text{DEX}$<br>$\ge 50$: $1.0 \cdot \text{DEX}$ |
| `POLEARMS` | **Polearms** | **Constitution** (`CON`) | Unlocks **Secondary Strength** (`STR`) | $<50$: $0.5 \cdot \text{CON}$<br>$\ge 50$: $0.5 \cdot \text{CON} + 0.5 \cdot \text{STR}$ |
| `BRAWLING` | **Brawling** | **Strength** (`STR`) | Unlocks **Secondary Dexterity** (`DEX`) | $<50$: $0.5 \cdot \text{STR}$<br>$\ge 50$: $0.5 \cdot \text{STR} + 0.5 \cdot \text{DEX}$ |
| `ARCHERY` | **Archery** | **Dexterity** (`DEX`) | **Doubles Primary Dexterity** ($2\times \text{DEX}$) | $<50$: $0.5 \cdot \text{DEX}$<br>$\ge 50$: $1.0 \cdot \text{DEX}$ |
| `THROWING` | **Throwing** | **Dexterity** (`DEX`) | Unlocks **Secondary Strength** (`STR`) | $<50$: $0.5 \cdot \text{DEX}$<br>$\ge 50$: $0.5 \cdot \text{DEX} + 0.5 \cdot \text{STR}$ |

### 3.3. GDScript Schema for Scaling Metadata in `SkillData.gd`

```gdscript
const COMBAT_SKILL_SCALING: Dictionary = {
	SkillId.SWORDSMANSHIP: {
		"primary": "strength",
		"secondary": "dexterity",
		"doubles_primary_at_50": false
	},
	SkillId.BLUNT_WEAPON_FIGHTING: {
		"primary": "strength",
		"secondary": "",
		"doubles_primary_at_50": true
	},
	SkillId.FINESSE_WEAPON_FIGHTING: {
		"primary": "dexterity",
		"secondary": "",
		"doubles_primary_at_50": true
	},
	SkillId.POLEARMS: {
		"primary": "constitution",
		"secondary": "strength",
		"doubles_primary_at_50": false
	},
	SkillId.BRAWLING: {
		"primary": "strength",
		"secondary": "dexterity",
		"doubles_primary_at_50": false
	},
	SkillId.ARCHERY: {
		"primary": "dexterity",
		"secondary": "",
		"doubles_primary_at_50": true
	},
	SkillId.THROWING: {
		"primary": "dexterity",
		"secondary": "strength",
		"doubles_primary_at_50": false
	}
}

## Computes effective skill level including the Level 50 Accuracy Scaling Shift.
func get_effective_level_with_attributes(attributes: AttributesData) -> float:
	if not attributes:
		return level
	if COMBAT_SKILL_SCALING.has(skill_id):
		var cfg = COMBAT_SKILL_SCALING[skill_id]
		var pri_val = float(_read_attr(attributes, cfg["primary"]))
		var attr_bonus = pri_val * 0.5
		if level >= 50.0:
			if bool(cfg["doubles_primary_at_50"]):
				attr_bonus = pri_val * 1.0 # Doubles primary attribute effectiveness at Lv 50+
			elif not String(cfg["secondary"]).is_empty():
				var sec_val = float(_read_attr(attributes, cfg["secondary"]))
				attr_bonus += sec_val * 0.5 # Unlocks secondary attribute scaling at Lv 50+
		return level + attr_bonus
	# Non-weapon skills use standard primary attribute scaling
	var std_val = float(_read_attr(attributes, associated_attribute_name))
	return level + (std_val * 0.5)
```

---

## 4. Mathematical Combat & Hit Chance Specification

### 4.1. Exact Hit Chance Formula

$$\text{Hit Chance} = \text{clamp}\left(\frac{\text{Attacker Weapon Skill} + 50}{(\text{Defender Skill} + 50) \times 2} + \text{Attacker Mods} - \text{Defender Mods},\ 0.05,\ 0.95\right)$$

#### Variable Definitions
1. **$\text{Attacker Weapon Skill}$**:
   - Determined strictly from the weapon used in the attack:
     $$\text{atk\_skill\_id} = \begin{cases} \text{weapon.associated\_skill\_id} & \text{if weapon != null} \\ \text{SkillId.BRAWLING} & \text{if unarmed} \end{cases}$$
   - Evaluated via `atk_skills.get_effective_level(atk_skill_id, atk_stats.attributes)` (which incorporates the Level 50 Accuracy Scaling Shift).
2. **$\text{Defender Skill}$ (Crucial Defensive Rule)**:
   - Evaluates **both** the defender's currently equipped weapon skill AND their active dedicated defensive skill (`DODGE` or `PARRY`), taking whichever is higher:
     $$\text{def\_weapon\_skill\_id} = \begin{cases} \text{def\_weapon.associated\_skill\_id} & \text{if defender has equipped MAIN\_HAND weapon} \\ \text{SkillId.BRAWLING} & \text{if defender is unarmed} \end{cases}$$
     $$\text{def\_weapon\_val} = \text{def\_skills.get\_effective\_level}(\text{def\_weapon\_skill\_id},\ \text{def\_stats.attributes})$$
     $$\text{def\_stance\_id} = \text{def\_skills.get\_active\_defensive\_skill\_id}() \quad (\text{DODGE or PARRY})$$
     $$\text{def\_stance\_val} = \text{def\_skills.get\_effective\_level}(\text{def\_stance\_id},\ \text{def\_stats.attributes})$$
     $$\text{Defender Skill} = \max(\text{def\_weapon\_val},\ \text{def\_stance\_val})$$
   - *Design Impact*: Low-skilled enemies (low weapon skill and low dodge/parry) have a low denominator and remain reliably hittable, whereas veteran martial enemies with high weapon mastery can deflect/contest attacks even if their secondary defensive skill is lower.
3. **$\text{Attacker Mods}$**:
   - Sum of `weapon.accuracy_bonus` + `ability.accuracy_bonus` (if executing a Level 25 active weapon ability) + any active buff/shrine accuracy modifiers.
4. **$\text{Defender Mods}$**:
   - Sum of equipped gear defensive bonuses: `offhand.defense_bonus` (e.g. *Main-Gauche* offhand parry boost or buckler block bonus) + `armor.dodge_bonus` + `armor.parry_bonus`.

### 4.2. Strict Weapon Skill Training Rule
- Upon any attack resolution:
  - **Attacker** (on hit): Trains **only** `atk_skill_id` (`weapon.associated_skill_id`) against `task_difficulty = Defender Skill`.
  - **Defender** (on dodge/parry/evade): Trains their active defensive skill (`def_stance_id`) against `task_difficulty = Attacker Weapon Skill`.

---

## 5. Level 25 Milestone: Active Weapon Abilities & Hotbar Integration

### 5.1. `WeaponAbilityData` Resource Schema (`res://scripts/resources/WeaponAbilityData.gd`)

Each weapon carries a `WeaponAbilityData` sub-resource representing its signature technique unlocked at **Skill Level 25.0**:

```gdscript
@tool
class_name WeaponAbilityData
extends Resource

enum ExecutionType {
	MELEE_TARGET,       ## Requires selecting an adjacent hostile tile (range 1 or reach 2)
	RANGED_TARGET,      ## Uses manual Line-of-Fire targeting up to weapon range
	SELF_CLEAVE_AOE,    ## Sweeps all adjacent tiles around the attacker
	LINE_PIERCE         ## Pierces 2 tiles in facing/targeted direction
}

@export var ability_id: String = ""
@export var ability_name: String = ""
@export var required_skill_id: SkillData.SkillId = SkillData.SkillId.SWORDSMANSHIP
@export var required_skill_level: float = 25.0
@export var execution_type: ExecutionType = ExecutionType.MELEE_TARGET
@export var damage_multiplier: float = 1.35
@export var accuracy_bonus: float = 0.10
@export var armor_penetration: float = 0.0
@export var guaranteed_crit: bool = false
@export var range_override: int = -1
@export var area_radius: int = 0
@export var status_effect_id: String = ""      ## e.g. "bleed", "stun", "sunder", "poison", "cripple", "disarm", "knockback"
@export var status_chance: float = 0.0
@export var status_duration: int = 2
@export var cooldown_turns: int = 3
@export var description: String = ""
```

### 5.2. Milestone Check & Hotbar Equip Flow
1. **Unlock Check (`SkillComponent.is_weapon_ability_unlocked(weapon: ItemData) -> bool`)**:
   ```gdscript
   func is_weapon_ability_unlocked(weapon: ItemData) -> bool:
       if not weapon or not weapon.active_ability:
           return false
       var skill = get_skill(weapon.associated_skill_id)
       if not skill:
           return false
       return skill.level >= weapon.active_ability.required_skill_level # 25.0
   ```
2. **Hotbar Slot Extension (`HotbarBar.gd`)**:
   - Add `WEAPON_ABILITY` to `HotbarBar.SlotType`.
   - `HotbarSlot` stores `var weapon: ItemData = null` and `var weapon_ability: WeaponAbilityData = null`.
   - When the player equips a weapon in `InventoryComponent` OR when `SkillComponent` emits `keystone_triggered(skill, 25)` / `skill_advanced`:
     - `HotbarBar.sync_weapon_ability(player)` checks if the player's equipped weapon (or equipped throwing ammo) has an unlocked Level 25 `active_ability`.
     - If unlocked, it automatically populates (or allows assigning via Inventory/Skills UI) the weapon's active ability onto the hotbar with a `[LV25]` / `[ACT]` badge and cooldown indicator.
   - If the player unequips that weapon or swaps to a weapon whose skill is `< 25.0`, the weapon ability slot is automatically cleared/disabled.
3. **Execution Flow**:
   - Pressing the hotbar key (`1`–`0`) for a `WEAPON_ABILITY` slot enters `TargetingSystem` (`TurnState.TARGETING`) with `max_range` equal to the weapon's reach/range (`1` for standard melee, `2` for polearms, `weapon.range_tiles` for archery/throwing).
   - Confirming the target executes `CombatComponent.execute_weapon_ability(...)`, applying the ability's `damage_multiplier`, `accuracy_bonus`, `armor_penetration`, and `status_effect_id`, and training `weapon.associated_skill_id`.

---

## 6. Complete 50-Weapon Base Item Database Manifest (`WeaponManifest.gd`)

### Handedness & Slot Rules (`ItemData.Handedness`)
- `ONE_HANDED` (`1H`): Equips in `MAIN_HAND`; leaves `OFF_HAND` free for shields or offhand parrying daggers (*Main-Gauche*).
- `TWO_HANDED` (`2H`): Equips in `MAIN_HAND`; automatically unequips and locks `OFF_HAND` while worn.
- `VERSATILE` (`1H/2H`): Equips in `MAIN_HAND`; if `OFF_HAND` is empty, grants a **+15% Two-Handed Grip Damage Bonus** (`versatile_two_hand_Verify_mult = 1.15`).
- `OFF_HAND_CAPABLE`: Finesse weapons like *Main-Gauche* can be equipped in `MAIN_HAND` or `OFF_HAND` (providing passive `defense_bonus` to Defender Mods).
- `INTEGRATED_ARMOR`: *Gauntlets (Plate)* occupy `MAIN_HAND` (or grant armed brawling stats while contributing `armor_value`).

---

### 6.1. Swordsmanship Weapons (`SkillId.SWORDSMANSHIP`)
*Primary: Strength | Secondary (Lv 50): Dexterity*

| Item ID | Weapon Name | Grip | Dmg (Min–Max) | Wt (St) | Range | Acc / Def Mod | Special Trait | Lv 25 Active Ability (`WeaponAbilityData`) |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :--- | :--- |
| `sword_short` | **Shortsword** | 1H | 3–8 | 2.0 | 1 | +5% Acc | Agile thrusting blade | **Lunging Thrust**: +15% Acc, 1.35x Dmg, ignores 25% armor |
| `sword_broad` | **Broadsword** | 1H | 4–10 | 3.0 | 1 | +0% | Balanced military edge | **Cleaving Arc**: 1.40x Dmg, inflicts *Bleed* (3 turns) |
| `sword_scimitar` | **Scimitar** | 1H | 3–9 | 2.5 | 1 | +5% Acc | +5% Crit Chance | **Dervish Slash**: Strikes target + adjacent foe for 1.25x Dmg |
| `sword_bastard` | **Bastard Sword** | 1H/2H | 5–11 | 3.5 | 1 | +0% | +15% Dmg if `OFF_HAND` empty | **Half-Sword Pommel**: 1.35x Dmg, 50% armor pen + *Daze* |
| `sword_long` | **Longsword** | 2H | 6–13 | 4.0 | 1 | +5% Acc, +5% Def | Cruciform parry guard | **Mordhau Strike**: 1.50x Dmg, +10% Acc, breaches 40% armor |
| `sword_great` | **Greatsword** | 2H | 8–16 | 6.0 | 1 | -5% Acc | Sweeping momentum | **Whirlwind Sweep**: 3x3 self-centered cleave for 1.30x Dmg |
| `sword_executioner` | **Executioner's Sword** | 2H | 10–20 | 7.5 | 1 | -10% Acc | +50% Dmg vs targets < 35% HP | **Decapitating Verdict**: 1.75x Dmg; guaranteed Crit if target < 50% HP |

---

### 6.2. Blunt Weapon Fighting Weapons (`SkillId.BLUNT_WEAPON_FIGHTING`)
*Primary: Strength | Level 50: Doubles Strength ($2\times \text{STR}$)*

| Item ID | Weapon Name | Grip | Dmg (Min–Max) | Wt (St) | Range | Acc / Def Mod | Special Trait | Lv 25 Active Ability (`WeaponAbilityData`) |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :--- | :--- |
| `blunt_club` | **Club** | 1H | 2–7 | 2.0 | 1 | +0% | Simple heavy cudgel | **Skull Bash**: 1.30x Dmg, 40% chance to *Stun* (1 turn) |
| `blunt_mace` | **Mace** | 1H | 3–9 | 3.0 | 1 | +0% | Ignores 15% target armor | **Armor Dent**: 1.35x Dmg, permanently reduces target armor by 2 |
| `blunt_warhammer` | **Warhammer** | 1H | 4–11 | 3.5 | 1 | +0% | Ignores 30% target armor | **Crushing Blow**: 1.50x Dmg, ignores 60% target armor |
| `blunt_flail` | **Flail** | 1H | 3–12 | 3.5 | 1 | -5% Acc | Bypasses defender shield/parry bonuses | **Chain Entangle**: 1.35x Dmg, negates target Parry/Dodge for 2 turns |
| `blunt_quarterstaff` | **Quarterstaff** | 2H | 4–9 | 2.5 | 1 | +10% Acc, +10% Def | Defensive monk/mage staff | **Vaulting Sweep**: 1.30x Dmg + *Knockback* 1 tile |
| `blunt_iron_mace` | **Iron Mace** | 2H | 7–15 | 5.5 | 1 | -5% Acc | Ignores 25% target armor | **Shattering Impact**: 1.55x Dmg + *Sunder* (50% armor reduction) |
| `blunt_great_maul` | **Great Maul** | 2H | 10–22 | 8.0 | 1 | -10% Acc | Ignores 40% target armor | **Earthshaker Slam**: 1.60x Dmg in 3x3 impact zone, 35% *Stun* |

---

### 6.3. Finesse Weapon Fighting Weapons (`SkillId.FINESSE_WEAPON_FIGHTING`)
*Primary: Dexterity | Level 50: Doubles Dexterity ($2\times \text{DEX}$)*

| Item ID | Weapon Name | Grip | Dmg (Min–Max) | Wt (St) | Range | Acc / Def Mod | Special Trait | Lv 25 Active Ability (`WeaponAbilityData`) |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :--- | :--- |
| `finesse_dagger` | **Dagger** | 1H | 2–5 | 0.8 | 1 | +10% Acc | **2.5x Backstab/Stealth Multiplier** | **Shadow Ambush**: 2.0x Dmg (3.0x if hidden/flanking), +20% Acc |
| `finesse_stiletto` | **Stiletto** | 1H | 2–6 | 0.8 | 1 | +10% Acc | Ignores 50% armor on needle thrust | **Heartseeker Puncture**: 1.40x Dmg, ignores 100% physical armor |
| `finesse_kryss` | **Kryss** | 1H | 3–7 | 1.2 | 1 | +12% Acc | Wavy blade (+10% Crit Damage) | **Serpentine Flurry**: Executes 2 rapid strikes at 0.85x Dmg each |
| `finesse_main_gauche` | **Main-Gauche** | 1H/Off | 2–6 | 1.0 | 1 | +5% Acc, **+12% Def** | Equippable in `OFF_HAND` for +12% Defender Mod | **Bind & Riposte**: 1.25x Dmg + grants +25% Parry/Defense for 2 turns |
| `finesse_kukri` | **Kukri** | 1H | 4–8 | 1.5 | 1 | +5% Acc | Forward-angled chopping edge (+15% Bleed) | **Tendon Slice**: 1.40x Dmg, inflicts *Bleed* and *Cripple* |
| `finesse_assassins_blade` | **Assassin's Blade** | 1H | 4–9 | 1.2 | 1 | +10% Acc | **3.0x Backstab/Stealth Multiplier**, +8% Crit | **Arterial Sever**: Guaranteed Critical Strike (2.0x+ Dmg) + *Bleed* |
| `finesse_kris` | **Kris** | 1H | 3–8 | 1.0 | 1 | +8% Acc | **35% Poison Proc** on every hit | **Envenomed Fang**: 1.35x Dmg, 100% chance to inflict virulent *Poison* (4 turns) |

---

### 6.4. Polearms Weapons (`SkillId.POLEARMS`)
*Primary: Constitution | Secondary (Lv 50): Strength*

| Item ID | Weapon Name | Grip | Dmg (Min–Max) | Wt (St) | Range | Acc / Def Mod | Special Trait | Lv 25 Active Ability (`WeaponAbilityData`) |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :--- | :--- |
| `polearm_spear` | **Spear** | 1H/2H | 3–8 | 2.5 | 2 | +5% Acc | 2-tile reach; +15% Dmg if 2H | **Impaling Lunge**: 2-tile line pierce hitting both tiles for 1.35x Dmg |
| `polearm_halberd` | **Halberd** | 2H | 7–15 | 5.5 | 2 | +0% | 2-tile reach; +20% armor pen | **Hook & Cleave**: 1.50x Dmg at range 2, pulls target 1 tile closer |
| `polearm_glaive` | **Glaive** | 2H | 6–14 | 4.5 | 2 | +5% Acc | Sweeping pole-blade | **Crescent Sweep**: Hits target and flanking tiles for 1.30x Dmg |
| `polearm_trident` | **Trident** | 1H/2H | 4–10 | 3.5 | 2 | +5% Acc, +5% Def | Three-pronged catch (+15% vs 2H) | **Pronged Pin**: 1.35x Dmg, pins/immobilizes target for 2 turns |
| `polearm_naginata` | **Naginata** | 2H | 5–13 | 4.0 | 2 | +8% Acc | +8% Crit Chance at reach | **Fluid Gale Thrust**: +20% Acc, 1.45x Dmg with +15% Crit bonus |
| `polearm_voulge` | **Voulge** | 2H | 8–16 | 5.5 | 2 | -5% Acc | Heavy cleaver head | **Armor Heaver**: 1.55x Dmg, ignores 45% target armor |
| `polearm_billhook` | **Billhook** | 2H | 6–13 | 4.5 | 2 | +5% Acc | Hooked dismounting blade | **Hamstring Hook**: 1.40x Dmg, inflicts *Cripple* (-15% Defender Mod) |

---

### 6.5. Brawling Weapons (`SkillId.BRAWLING`)
*Primary: Strength | Secondary (Lv 50): Dexterity*

| Item ID | Weapon Name | Grip | Dmg (Min–Max) | Wt (St) | Range | Acc / Def Mod | Special Trait | Lv 25 Active Ability (`WeaponAbilityData`) |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :--- | :--- |
| `brawl_cestus` | **Cestus** | 1H | 2–6 | 1.0 | 1 | +8% Acc | Leather battle-glove | **Rapid Jab Combo**: Strikes twice at 0.80x Dmg with +15% Acc |
| `brawl_brass_knuckles` | **Brass Knuckles** | 1H | 3–7 | 1.0 | 1 | +5% Acc | Solid metal fist-load | **Jawbreaker Hook**: 1.40x Dmg, 35% chance to *Stun* |
| `brawl_spiked_knuckles` | **Iron Spiked Knuckles** | 1H | 3–8 | 1.2 | 1 | +5% Acc | +15% Bleed chance | **Lacerating Uppercut**: 1.45x Dmg + guaranteed *Bleed* (3 turns) |
| `brawl_leather_wraps` | **Leather Handwraps** | 1H | 2–5 | 0.4 | 1 | +12% Acc, +5% Def | Featherweight martial wraps | **Counter Palm**: 1.30x Dmg + +15% Dodge/Parry for 2 turns |
| `brawl_weighted_wraps` | **Weighted Boxing Wraps** | 1H | 4–8 | 1.5 | 1 | +5% Acc | Lead-lined impact wraps | **Crushing Body Blow**: 1.45x Dmg, weakens target attack skill by 15% |
| `brawl_nagaraja_claws` | **Nagaraja Claws** | 1H | 4–9 | 1.2 | 1 | +8% Acc | Curved tiger-talons (+20% Poison/Bleed) | **Viper Rend**: 1.50x Dmg, inflicts both *Bleed* and *Poison* |
| `brawl_plate_gauntlets` | **Gauntlets (Plate)** | 1H/Armor | 4–10 | 2.5 | 1 | +0% Acc, **+2 Armor** | Grants +2 Armor Value while equipped in `MAIN_HAND` | **Ironclad Haymaker**: 1.50x Dmg + bonus damage equal to total player Armor |

---

### 6.6. Archery Weapons (`SkillId.ARCHERY`)
*Primary: Dexterity | Level 50: Doubles Dexterity ($2\times \text{DEX}$) | Requires `AMMUNITION` Slot*

| Item ID | Weapon Name | Grip | Dmg (Min–Max) | Wt (St) | Range | Acc / Def Mod | Special Trait | Lv 25 Active Ability (`WeaponAbilityData`) |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :--- | :--- |
| `archery_short_bow` | **Short Bow** | 2H | 3–7 | 1.5 | 5 | +8% Acc | Lightweight skirmish bow | **Snap Shot**: +20% Acc, 1.30x Dmg at up to 5 tiles |
| `archery_longbow` | **Longbow** | 2H | 5–11 | 2.5 | 7 | +5% Acc | Extended 7-tile sniper range | **Pinning Arrow**: 1.40x Dmg at range 7, roots target for 2 turns |
| `archery_composite_bow` | **Composite Bow** | 2H | 5–12 | 2.5 | 6 | +5% Acc | High-Tension (+50% STR Dmg bonus) | **Heart-Piercer**: 1.50x Dmg, ignores 50% target armor |
| `archery_recurve_bow` | **Recurve Bow** | 2H | 4–9 | 2.0 | 6 | +8% Acc | High-Tension (+50% STR Dmg bonus) | **Double Nock**: Fires 2 arrows rapidly at 0.85x Dmg each |
| `archery_light_crossbow` | **Light Crossbow** | 2H | 6–13 | 3.5 | 6 | +10% Acc | Mechanical trigger; ignores 20% armor | **Precision Bolt**: +25% Acc, 1.45x Dmg, +20% Crit chance |
| `archery_heavy_crossbow` | **Heavy Crossbow** | 2H | 9–18 | 6.0 | 7 | +5% Acc | Arbalest; ignores 40% target armor | **Siege Skewer**: 1.65x Dmg, pierces 80% target armor |
| `archery_hand_crossbow` | **Hand Crossbow** | 1H | 4–9 | 1.8 | 4 | +10% Acc | **1H Ranged** (allows `OFF_HAND` shield/dagger) | **Point-Blank Volley**: 1.50x Dmg, guaranteed Crit at distance $\le 2$ |

---

### 6.7. Throwing Weapons (`SkillId.THROWING`)
*Primary: Dexterity | Secondary (Lv 50): Strength | Stackable/Consumable, Uses Inventory Weight when in Backpack*

| Item ID | Weapon Name | Grip | Dmg (Min–Max) | Wt/Unit (St) | Default Stack | Range | Special Trait | Lv 25 Active Ability (`WeaponAbilityData`) |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :--- | :--- |
| `throw_daggers` | **Throwing Daggers** | 1H Stack | 2–6 | 0.15 | 10 | 4 | +10% Acc, high velocity | **Fan of Knives**: Throws 1 dagger at target + adjacent foes (3-tile arc) |
| `throw_javelins` | **Javelins** | 1H Stack | 5–11 | 0.60 | 5 | 5 | Heavy war-dart; ignores 25% armor | **Skewer Throw**: 1.55x Dmg, pierces 60% armor + *Cripple* |
| `throw_axes` | **Throwing Axes** | 1H Stack | 4–10 | 0.50 | 6 | 4 | Francisca cleaver; +15% Bleed | **Splitting Francisca**: 1.50x Dmg, shreds target shield/parry bonus |
| `throw_shuriken` | **Shuriken** | 1H Stack | 2–5 | 0.08 | 15 | 5 | +15% Acc, +10% Crit Chance | **Shadow Star Burst**: Throws 2 shuriken in a single turn at 0.90x Dmg each |
| `throw_chakram` | **Chakram** | 1H | 4–9 | 1.00 | 1 | 5 | **Returning War-Quoit** (does not deplete quantity!) | **Ricochet Disc**: 1.40x Dmg, bounces to 1 additional enemy within 2 tiles |
| `throw_hammers` | **Throwing Hammers** | 1H Stack | 4–9 | 0.55 | 5 | 4 | Ignores 30% armor, 20% Stun | **Concussive Hurl**: 1.45x Dmg + guaranteed 1-turn *Stun* |
| `throw_darts` | **Darts** | 1H Stack | 1–4 | 0.05 | 20 | 5 | +15% Acc, 30% Poison chance | **Neurotoxin Dart**: 1.30x Dmg + potent *Poison* & *Weakness* |
| `throw_alchemist_fire` | **Alchemist Fire Vial** | 1H AoE | 12–20 | 0.40 | 3 | 5 | **3x3 AoE (`area_radius = 1`)** Fire Blast | **Concentrated Napalm**: 1.40x Fire Dmg in 3x3 zone + leaves burning scorch |

---

## 7. Node Logic & Resource Schema Adjustments

### 7.1. `ItemData.gd` Additions
```gdscript
enum Handedness {
	ONE_HANDED,
	TWO_HANDED,
	VERSATILE
}

@export var associated_skill_id: SkillData.SkillId = SkillData.SkillId.SWORDSMANSHIP
@export var handedness: Handedness = Handedness.ONE_HANDED
@export var defense_bonus: float = 0.0          ## Added to Defender Mods when equipped
@export var armor_penetration: float = 0.0      ## Percentage (0.0 to 1.0) of defender armor ignored
@export var backstab_multiplier: float = 1.0    ## Multiplier when attacking from Stealth or flanking
@export var poison_chance: float = 0.0          ## Probability (0.0 to 1.0) to apply poison on hit
@export var bleed_chance: float = 0.0           ## Probability (0.0 to 1.0) to apply bleed on hit
@export var requires_ammo: bool = false         ## True for Archery weapons
@export var is_returning: bool = false          ## True for Chakram (does not consume stack quantity)
@export var active_ability: WeaponAbilityData = null
```

### 7.2. `InventoryComponent.gd` Two-Handed & Defender Mod Support
- **2H Equip Enforcement**:
  - When equipping an item with `handedness == ItemData.Handedness.TWO_HANDED` in `MAIN_HAND`, automatically unequip `OFF_HAND` into the backpack.
  - When equipping an item in `OFF_HAND` while `MAIN_HAND` holds a `TWO_HANDED` weapon, automatically unequip `MAIN_HAND` into the backpack.
- **Defender Mod Aggregation (`get_total_defense_Calling_bonus() -> float`)**:
  - Sums `dodge_bonus`, `parry_bonus`, `block_chance_bonus`, and `defense_bonus` across all equipped items (`MAIN_HAND`, `OFF_HAND`, `BODY`, `HEAD`, `ACCESSORY`, etc.) for the `Defender Mods` term in the Hit Chance formula.

### 7.3. `CombatComponent.gd` Hit Formula & Ability Execution
```gdscript
func calculate_hit_chance(defender: Node2D, weapon: ItemData = null, ability: WeaponAbilityData = null) -> Dictionary:
	var atk_skills = get_skills()
	var atk_stats = get_stats()
	var def_skills = _resolve_skills(defender)
	var def_stats = _resolve_stats(defender)
	var def_inv = _resolve_inventory(defender)

	# 1. Attacker Weapon Skill (Strictly uses weapon.associated_skill_id, or BRAWLING if unarmed)
	var weapon_skill_id = weapon.associated_skill_id if weapon else SkillData.SkillId.BRAWLING
	var weapon_type = weapon.weapon_type if weapon else AttributesData.WeaponType.MELEE

	var atk_skill_val = 10.0
	if atk_skills and atk_stats:
		atk_skill_val = atk_skills.get_effective_level(weapon_skill_id, atk_stats.attributes)

	# 2. Defender Skill (Crucial Rule: max of Defender's Equipped Weapon Skill and Active Defensive Skill)
	var def_weapon_val = 10.0
	var def_stance_val = 10.0
	var def_mode_name = "DODGE"

	if def_skills and def_stats:
		var def_weapon: ItemData = def_inv.get_equipped_weapon() if def_inv else null
		var def_weapon_skill_id = def_weapon.associated_skill_id if def_weapon else SkillData.SkillId.BRAWLING
		def_weapon_val = def_skills.get_effective_level(def_weapon_skill_id, def_stats.attributes)

		var stance_id = def_skills.get_active_defensive_skill_id()
		def_mode_name = "PARRY" if stance_id == SkillData.SkillId.PARRY else "DODGE"
		def_stance_val = def_skills.get_effective_level(stance_id, def_stats.attributes)

	var defender_skill = maxf(def_weapon_val, def_stance_val)
	var defense_used = def_mode_name if def_stance_val >= def_weapon_val else "WEAPON_PARRY"

	# 3. Attacker Mods & Defender Mods
	var attacker_mods = (weapon.accuracy_bonus if weapon else 0.0) + (ability.accuracy_bonus if ability else 0.0)
	var defender_mods = def_inv.get_total_defense_bonus() if def_inv else 0.0

	# 4. Exact Hit Chance Formula:
	# Hit Chance = (Attacker Weapon Skill + 50) / ((Defender Skill + 50) * 2) + Attacker Mods - Defender Mods
	var numerator = atk_skill_val + 50.0
	var denominator = (defender_skill + 50.0) * 2.0
	var raw_chance = (numerator / denominator) + attacker_mods - defender_mods
	var final_chance = clampf(raw_chance, 0.05, 0.95)

	return {
		"hit_chance": final_chance,
		"atk_skill_id": weapon_skill_id,
		"atk_skill_val": atk_skill_val,
		"def_skill_val": defender_skill,
		"def_weapon_val": def_weapon_val,
		"def_stance_val": def_stance_val,
		"attacker_mods": attacker_mods,
		"defender_mods": defender_mods,
		"defense_used": defense_used,
		"weapon_type": weapon_type
	}
```

---

## 8. Step-by-Step Implementation Plan for `@developer`

### Step 1: Resource Layer (`WeaponAbilityData.gd`, `ItemData.gd`, `WeaponManifest.gd`)
1. Create `res://scripts/resources/WeaponAbilityData.gd` defining the Level 25 active ability schema.
2. Extend `res://scripts/resources/ItemData.gd` with `associated_skill_id`, `handedness`, `defense_bonus`, `armor_penetration`, `backstab_multiplier`, `poison_chance`, `bleed_chance`, `requires_ammo`, `is_returning`, and `active_ability`.
3. Create `res://scripts/resources/WeaponManifest.gd` providing factory methods and catalog lookups (`get_all_weapons()`, `create_weapon(item_id)`, `get_weapons_for_skill(skill_id)`) for all **50 base weapons** across the 7 combat skill categories.

### Step 2: Skill & Attribute Scaling Layer (`SkillData.gd`, `SkillComponent.gd`, `CharacterCreationData.gd`)
1. In `res://scripts/resources/SkillData.gd`:
   - Add `BLUNT_WEAPON_FIGHTING` (with `const MACE_FIGHTING = SkillId.BLUNT_WEAPON_FIGHTING` alias) and `FINESSE_WEAPON_FIGHTING` to `SkillId` and `SkillTier.STARTING`.
   - Implement `COMBAT_SKILL_SCALING` and `get_effective_level_with_attributes(attributes: AttributesData)` to enforce the exact Level 50 Accuracy Scaling Shift (`SWORDSMANSHIP`, `BLUNT_WEAPON_FIGHTING`, `FINESSE_WEAPON_FIGHTING`, `POLEARMS`, `BRAWLING`, `ARCHERY`, `THROWING`).
   - Update `get_milestone_info(skill_id, milestone)` so Milestone 25 describes the Weapon-Unique Active Ability unlock and Milestone 50 describes the specific Primary/Secondary Attribute Accuracy Scaling Shift.
2. In `res://scripts/components/SkillComponent.gd`:
   - Register `FINESSE_WEAPON_FIGHTING` and `BLUNT_WEAPON_FIGHTING` in `_init_default_skills()`, setting `POLEARMS` primary attribute to `"constitution"`.
   - Update `get_effective_level()` to delegate to `skill.get_effective_level_with_attributes(attributes)`.
   - Add `is_weapon_ability_unlocked(weapon: ItemData) -> bool`.
3. In `res://scripts/resources/CharacterCreationData.gd`:
   - Update starter equipment mappings to use `WeaponManifest` items (including adding a starter loadout for `FINESSE_WEAPON_FIGHTING` granting a *Dagger* and *Main-Gauche*).

### Step 3: Combat & Inventory Resolution Layer (`InventoryComponent.gd`, `CombatComponent.gd`)
1. In `res://scripts/components/InventoryComponent.gd`:
   - Enforce `TWO_HANDED` equipment slot rules and implement `get_total_defense_bonus() -> float`.
2. In `res://scripts/components/CombatComponent.gd`:
   - Update `calculate_hit_chance()` to implement the exact formula `(Attacker Weapon Skill + 50) / ((Defender Skill + 50) * 2) + Attacker Mods - Defender Mods` using `weapon.associated_skill_id` and `maxf(def_weapon_val, def_stance_val)`.
   - Update `execute_attack()` and `execute_ranged_attack()` to support `VERSATILE` 2H grip bonus (+15% when `OFF_HAND` is empty), armor penetration, backstab multipliers, `is_returning` thrown weapons (*Chakram*), and strict training of `weapon.associated_skill_id`.
   - Implement `execute_weapon_ability()` for Level 25 weapon active attacks.

### Step 4: Hotbar & World Targeting Integration (`HotbarBar.gd`, `World.gd`)
1. In `res://scripts/ui/HotbarBar.gd`:
   - Add `SlotType.WEAPON_ABILITY` and `sync_weapon_abilities()`.
   - Automatically surface the equipped weapon's Level 25 active ability onto the hotbar when the corresponding weapon skill is $\ge 25.0$.
   - Route `SlotType.WEAPON_ABILITY` triggers into manual targeting (`TargetingSystem`) and `CombatComponent.execute_weapon_ability()`.

### Step 5: Automated Unit Testing (`tests/test_phase10_combat_weapons_synergy.gd`)
1. Verify all 7 combat skills and their exact Level 0–49.9 vs. Level 50.0+ attribute scaling formulas.
2. Verify all 50 weapons in `WeaponManifest.gd` strictly associate with their parent `SkillId` and only train that skill on use.
3. Verify the exact Hit Chance formula and Crucial Defensive Rule (`max(Defender Weapon Skill, Defender Defensive Skill)`).
4. Verify Level 25 Active Ability unlock and `HotbarBar` assignment/execution.
