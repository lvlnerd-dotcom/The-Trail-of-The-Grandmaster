class_name MerchantCatalog
extends RefCounted

## MerchantCatalog: Authoritative database of the 25 persistent merchant personalities,
## specialties, attitudes, and 250+ dialogue lines for Trail of the Grandmaster.

enum Specialty {
	POTION_APOTHECARY,
	WEAPON_ARMORY,
	MAGIC_SCRIBES,
	UNIQUE_CURIOS,
	GENERAL_OUTFITTER
}

enum Attitude {
	ROOTING_FOR_PLAYER,
	BITTER_CYNIC,
	ECCENTRIC_SCHOLAR,
	SHREWD_OPPORTUNIST,
	WEARY_VETERAN
}

static func get_specialty_name(specialty: Specialty) -> String:
	match specialty:
		Specialty.POTION_APOTHECARY: return "Potion Apothecary"
		Specialty.WEAPON_ARMORY: return "Weapon & Armor Armory"
		Specialty.MAGIC_SCRIBES: return "Magic Scribes & Focuses"
		Specialty.UNIQUE_CURIOS: return "Unique Curios & Relics"
		Specialty.GENERAL_OUTFITTER: return "General Outfitter"
		_: return "General Trader"

static func get_attitude_name(attitude: Attitude) -> String:
	match attitude:
		Attitude.ROOTING_FOR_PLAYER: return "Encouraging Ally"
		Attitude.BITTER_CYNIC: return "Bitter Cynic"
		Attitude.ECCENTRIC_SCHOLAR: return "Eccentric Scholar"
		Attitude.SHREWD_OPPORTUNIST: return "Shrewd Opportunist"
		Attitude.WEARY_VETERAN: return "Weary Veteran"
		_: return "Neutral"

static var _catalog_cache: Dictionary = {}

static func get_catalog() -> Dictionary:
	if not _catalog_cache.is_empty():
		return _catalog_cache
	
	_catalog_cache = {
		# =========================================================================
		# 1. POTION APOTHECARY (5 Merchants)
		# =========================================================================
		"apothecary_althea": {
			"merchant_id": "apothecary_althea",
			"display_name": "Althea the Herbalist",
			"title": "Herbalist of the Sunken Glades",
			"shop_type": Specialty.POTION_APOTHECARY,
			"attitude": Attitude.ROOTING_FOR_PLAYER,
			"dialogue_pool": [
				"May the roots hold strong beneath your boots, wanderer.",
				"Take a breath. Even the darkest crypt has sunpetals waiting to bloom.",
				"Drink deep of this vial when your pulse falters; it was brewed with care.",
				"I harvest my moss from the upper waterfalls. Pure water makes potent draughts.",
				"You look so tired, friend. Let my remedies mend what the depths have broken.",
				"Do not lose heart; many before you faltered, but I see quiet resolve in your eyes.",
				"Keep bandages close to your skin. Infection kills swifter than dragon claws.",
				"The Grandmaster once honored healers. Remember that mercy is a form of strength.",
				"Every leaf has a secret tongue; listen to the earth when stone begins to creak.",
				"Return to me whole, traveller. The dungeon takes far too many bright souls."
			]
		},
		"apothecary_ignatius": {
			"merchant_id": "apothecary_ignatius",
			"display_name": "Brother Ignatius",
			"title": "Field Surgeon of the Broken Chalice",
			"shop_type": Specialty.POTION_APOTHECARY,
			"attitude": Attitude.WEARY_VETERAN,
			"dialogue_pool": [
				"I have stitched more gaping bellies than I care to recall. Mind your flanks.",
				"Tourniquets first, prayers second. The gods respect clean bandages.",
				"Pain is simply proof that you have not yet bled into the stones. Buy an elixir.",
				"Seen a crusade collapse in an hour because fools drank uninspected swamp water.",
				"Silver flasks keep the draft cold. Drink it in one gulp or choke on the bile.",
				"Thirty years patching vanguard sellswords. None of them died rich.",
				"Take the trauma kit. You will curse my name if you find yourself sewing flesh with twine.",
				"The dungeon air stinks of gangrene and rot. Keep your nostrils covered.",
				"Do not weep for the blood you leave behind; just make sure you have enough left to walk.",
				"Rest your boots a moment. The grave waits patiently; no need to sprint into it."
			]
		},
		"apothecary_celandine": {
			"merchant_id": "apothecary_celandine",
			"display_name": "Celandine",
			"title": "Alchemical Synthesist & Reagent Collector",
			"shop_type": Specialty.POTION_APOTHECARY,
			"attitude": Attitude.ECCENTRIC_SCHOLAR,
			"dialogue_pool": [
				"Fascinating! The crystalline residue on your sleeve... did it hum when it crystallized?",
				"Mix sunpetal with pulverized spider venom and what do you get? A rather spectacular detonation!",
				"Mortars must be carved from basalt; marble absorbs the volatile ethers!",
				"Careful with that purple vial! It is either panacea or an instantaneous liquefier.",
				"I wonder what physiological transformation occurs when one drinks three elixirs at once...",
				"The subterranean flora here defies all orthodox botanical taxonomies!",
				"Bring me any strange moss you scrape from the collapsed vaults! I pay handsomely!",
				"Smell that? Acetic fumes with a touch of brimstone. Perfect temperature for distillation.",
				"Science is merely the art of burning things until they yield their secrets.",
				"If your teeth turn translucent after sipping, do not panic; it is entirely temporary!"
			]
		},
		"apothecary_varek": {
			"merchant_id": "apothecary_varek",
			"display_name": "Varek the Brewer",
			"title": "Purveyor of Distilled Fortitude",
			"shop_type": Specialty.POTION_APOTHECARY,
			"attitude": Attitude.SHREWD_OPPORTUNIST,
			"dialogue_pool": [
				"Gold upfront, stranger. Elixirs spoil when customers expire before settlement.",
				"A sip of this will keep you on your feet long enough to kill whatever bit you.",
				"Best prices north of the Abyss. Go ahead, check with the goblins; see what they charge.",
				"Supply and demand, my friend. Down here, blood is cheap, but glass and alcohol are dear.",
				"Special discount on antidotes for adventurers who look like they've already been stung.",
				"I do not ask where your coin comes from, and you do not ask how I get fresh mountain herbs.",
				"A dead warrior buys no brews. Therefore, keeping you alive is my primary commercial interest.",
				"Need an extra kick? My double-distilled draught burns going down, but it burns the fever out.",
				"No refunds once the wax seal is broken. Policy is policy, even ten leagues under stone.",
				"Stock up now. Next floor the price doubles on account of hazard transit."
			]
		},
		"apothecary_marna": {
			"merchant_id": "apothecary_marna",
			"display_name": "Old Marna",
			"title": "Crone of the Cavern Well",
			"shop_type": Specialty.POTION_APOTHECARY,
			"attitude": Attitude.BITTER_CYNIC,
			"dialogue_pool": [
				"Another brave fool come to fill an unmarked grave. Buy your salve and begone.",
				"They all think they are different. Then the poison reaches their marrow.",
				"Do not look at me with those pleading eyes. Gold on the slab, or bleed out on the floor.",
				"I swept up the bones of three heroes this morning. They were prettier than you.",
				"Drink it or do not. The worms will chew on you either way.",
				"You want sympathy? Seek a priest. I trade in bitter weeds and cold tinctures.",
				"The ceiling will cave in one of these days, and I will laugh from beneath the rubble.",
				"Youth is a disease that only time and cold steel seem able to cure.",
				"Hurry up. My cauldron is boiling and your indecision is giving me a headache.",
				"Do not bother asking for credit. Ghosts never settle their tabs."
			]
		},

		# =========================================================================
		# 2. WEAPON ARMORY (5 Merchants)
		# =========================================================================
		"armory_thorin": {
			"merchant_id": "armory_thorin",
			"display_name": "Master Thorin",
			"title": "Dwarven Bladesmith of the Iron Bastion",
			"shop_type": Specialty.WEAPON_ARMORY,
			"attitude": Attitude.WEARY_VETERAN,
			"dialogue_pool": [
				"Feel that balance? Steel folded thirty times over dragon-coal. It won't fail you.",
				"Armor isn't made to make you immortal; it's made to give you time to make a second mistake.",
				"I've forged swords for princes who died in their silken beds. A good blade deserves a dungeon.",
				"Keep the bevel clean and wipe off monster grease after every skirmish.",
				"A dull axe is more dangerous to the wielder than the fiend before him.",
				"Rivers of ore once ran through these lower halls. Now it's just rust and forgotten tombs.",
				"Heavier plate means slower strides, but when a stone mace drops, you'll thank the weight.",
				"No fancy filigree here, lad. Just honest iron that bites deep.",
				"Treat your shield like your right lung. You won't breathe long without it.",
				"Stand tall. The steel remembers the hammer, and you must remember your grip."
			]
		},
		"armory_ronald": {
			"merchant_id": "armory_ronald",
			"display_name": "Captain Ronald",
			"title": "Former Commander of the Highwatch Guard",
			"shop_type": Specialty.WEAPON_ARMORY,
			"attitude": Attitude.ROOTING_FOR_PLAYER,
			"dialogue_pool": [
				"Keep your guard raised, champion! The realm needs heroes who survive their expeditions.",
				"This shield took a minotaur horn in my youth and held. It will protect you just as true.",
				"Discipline turns a crude iron bar into a weapon of liberation. Carry yourself with honor.",
				"I see the spark of a true grandmaster in your stance. Let us equip you accordingly.",
				"Never strike out of anger; strike with measured resolve and unwavering focus.",
				"If you face overwhelming foes, fall back to a doorway. Chokepoints equalize all odds.",
				"Here, inspect this breastplate. It was polished in honor of the silver sun.",
				"You fight for everyone who stayed on the surface, praying for peace.",
				"Take pride in every scratch upon your armor; they are badges of resilience.",
				"Victory favors those who prepare their steel before the horns sound."
			]
		},
		"armory_kaelen": {
			"merchant_id": "armory_kaelen",
			"display_name": "Kaelen the Smith",
			"title": "Experimental Metallurgist & Armorer",
			"shop_type": Specialty.WEAPON_ARMORY,
			"attitude": Attitude.ECCENTRIC_SCHOLAR,
			"dialogue_pool": [
				"Note the curvature along this crossguard—it redistributes kinetic shock along the tang!",
				"I quenched this broadsword in troll blood; its tensile resilience increased by eighteen percent!",
				"Armor is an applied exercise in geometry and kinetic dissipation, wouldn't you agree?",
				"Have you considered how balance points shift dynamically as an edge sustains microscopic abrasions?",
				"Look closely at the rivets on this pauldrons! Telescoping laminar plates for unhindered mobility!",
				"I've been calculating the strike harmonics of various pommel weights against carapace...",
				"Never judge a weapon by its weight alone; its moment of inertia dictates true combat velocity!",
				"If you encounter anomalous star-metal on the lower tiers, bring fragments directly to me!",
				"Perfection is unattainable, but an edge honed to five microns is tantalizingly close.",
				"Test the flexibility! Bend the tip! Marvel at that restorative spring tension!"
			]
		},
		"armory_valeria": {
			"merchant_id": "armory_valeria",
			"display_name": "Valeria Iron-Eye",
			"title": "Veteran Pit-Fighter & Arms Dealer",
			"shop_type": Specialty.WEAPON_ARMORY,
			"attitude": Attitude.BITTER_CYNIC,
			"dialogue_pool": [
				"Drop the fancy postures. A sword is just a cold piece of iron meant to open a throat.",
				"You think you're going to reach the Grandmaster with that soft grip? Laughable.",
				"Gold first. I don't give advice to dead meat on credit.",
				"Seen better fighters than you chopped into feed by goblin cooks.",
				"You want armor that gleams? Go dance at a court. You want armor that stops arrows? Buy this.",
				"Every weapon in my rack has tasted blood. None of the prior owners are complaining.",
				"When the beast lunges, don't scream. Drive your steel through its palate.",
				"The only thing worse than a broken sword is an amateur who doesn't know how to thrust.",
				"Pick a piece or move on. I don't run an exhibition for tourists.",
				"Survival down here isn't glorious. It's ugly, noisy, and soaked in crimson."
			]
		},
		"armory_grimnir": {
			"merchant_id": "armory_grimnir",
			"display_name": "Grimnir",
			"title": "Quartermaster of the Sunken Fortress",
			"shop_type": Specialty.WEAPON_ARMORY,
			"attitude": Attitude.SHREWD_OPPORTUNIST,
			"dialogue_pool": [
				"Finest salvage in the descent, guaranteed straight from the hands of departed champions.",
				"A keen blade is an investment, friend. One that pays instant dividends in monster hides.",
				"You won't find this craftsmanship on the surface. Dungeon steel has a certain... temperament.",
				"Armor too expensive? Consider the alternative cost: funeral pyres and weeping relatives.",
				"Trade in your nicked dagger; I'll give you a fair price toward a proper claymore.",
				"Business is booming down here. People are always in urgent need of protection.",
				"I don't sell scrap. Every piece has been tested against dwarven anvil tolerances.",
				"Buy two shields and I might throw in a whetstone. Or not. Margins are tight.",
				"He who hesitates to buy good steel ends up as loot for the next adventurer.",
				"Cash on delivery. Even if the roof falls in, my prices remain rock solid."
			]
		},

		# =========================================================================
		# 3. MAGIC SCRIBES (5 Merchants)
		# =========================================================================
		"scribes_caspar": {
			"merchant_id": "scribes_caspar",
			"display_name": "Archmage Caspar",
			"title": "Scholar of the Astral Leyline",
			"shop_type": Specialty.MAGIC_SCRIBES,
			"attitude": Attitude.ECCENTRIC_SCHOLAR,
			"dialogue_pool": [
				"Ah! The dimensional resonance vibrating around your aura is simply magnificent!",
				"Do you feel the leylines pulsing through the bedrock? They hum in F-sharp minor!",
				"Careful with that grimoire! The ink was bound with basilisk bile; it tends to lick fingers.",
				"Identification scrolls are merely mirrors that reveal an object's metaphysical identity.",
				"To cast a spell is to rewrite the grammar of existence for a single glorious syllable.",
				"I transcribed this ward during an earthquake. Notice the slight jitter in the runic ligature?",
				"Mana is not liquid, young apprentice; it is unhurried intention waiting for articulation.",
				"Spellbooks require love, respect, and a light dusting of powdered sapphire every full moon.",
				"If you hear chanting from an empty corridor, do chime in; arcane harmonies love company!",
				"Do not fear the arcane recoil. A slight tingling in the teeth is merely sign of progress!"
			]
		},
		"scribes_elenor": {
			"merchant_id": "scribes_elenor",
			"display_name": "Scribe Elenor",
			"title": "Curator of the Radiant Archives",
			"shop_type": Specialty.MAGIC_SCRIBES,
			"attitude": Attitude.ROOTING_FOR_PLAYER,
			"dialogue_pool": [
				"Knowledge is a light that no dungeon gloom can extinguish, seeker.",
				"Take this scroll of warding. May it stand like a citadel between you and the dark.",
				"Every rune I copy is penned with prayers for those who brave the depths.",
				"The Grandmaster's library was said to span three dimensions. You carry their lineage.",
				"Do not hesitate to read your scrolls when cornered; words have delivered kingdoms.",
				"I preserve the sacred texts so that tomorrow will remember what courage looks like.",
				"Focus your mind when the shadows whisper. Radiance responds to clear devotion.",
				"Identification brings clarity, and clarity scatters all creeping terrors.",
				"May your spells strike true and your mana wells never run dry.",
				"Walk with grace, seeker. The light of the Grandmaster watches over our parchment."
			]
		},
		"scribes_morvath": {
			"merchant_id": "scribes_morvath",
			"display_name": "Morvath the Bound",
			"title": "Exiled Inscriptor of the Void",
			"shop_type": Specialty.MAGIC_SCRIBES,
			"attitude": Attitude.BITTER_CYNIC,
			"dialogue_pool": [
				"Magic is a leash, and the void holds the other end. Remember that before you cast.",
				"You seek power in parchment? A puddle of acid dissolves a grimoire just as easily as bone.",
				"They burned my academy because I asked what lay beyond the stars. Fools.",
				"Take your incantations. When your mind fractures under the strain, don't say Morvath didn't warn you.",
				"Every spell you cast carves a tiny hollow into your soul. Eventually, something moves in.",
				"Gold is meaningless to me, but the binding circles require mortal tribute to stay intact.",
				"Do not look too closely at the margin glosses. Some words cannot be unread.",
				"You think yourself a sorcerer because you can spark a spark? The Abyss laughs at you.",
				"Buy the scroll or leave. The voices in the binding parchment are growing restless.",
				"The Grandmaster was an arrogant scholar who learned too late that silence is the only truth."
			]
		},
		"scribes_zephyr": {
			"merchant_id": "scribes_zephyr",
			"display_name": "Zephyr",
			"title": "Wandering Arcane Broker",
			"shop_type": Specialty.MAGIC_SCRIBES,
			"attitude": Attitude.SHREWD_OPPORTUNIST,
			"dialogue_pool": [
				"Spells for every occasion: fire for trolls, ice for tempers, teleportation for cowards!",
				"A single identification scroll can reveal a legendary relic or save you from a cursed helm.",
				"My prices reflect the extreme rarity of high-tier arcane parchment in subterranean zones.",
				"Why risk your skin in melee when a syllable can turn a beast to smoldering ash?",
				"Fresh ink imported directly from the surface academies! Guaranteed 0% fizzle variance!",
				"Looking for arcane focuses? My wands are calibrated to within half a micro-thaum.",
				"Smart adventurers invest in divine scrolls before entering the lower catacombs.",
				"A spellbook in the hand is worth ten swords in the dirt. Choose your art, friend.",
				"No haggle on the grimoires; genuine arcane knowledge carries a fixed premium.",
				"Master the incantation, conquer the dungeon. Simple arithmetic, really."
			]
		},
		"scribes_lyndra": {
			"merchant_id": "scribes_lyndra",
			"display_name": "Lyndra",
			"title": "Veteran Battle-Mage of the Obsidian Spire",
			"shop_type": Specialty.MAGIC_SCRIBES,
			"attitude": Attitude.WEARY_VETERAN,
			"dialogue_pool": [
				"Cast swiftly, move constantly. A stationary wizard is merely a charred corpse.",
				"I lost three apprentices to careless somatic gestures. Keep your wrist rigid.",
				"Never rely on a single element. Monsters learn faster than most scholars admit.",
				"When mana runs low, draw your sidearm. Magic is no substitute for basic survival instinct.",
				"These scrolls saved my battalion twice during the Siege of Greycrag.",
				"Wards are good, but situational awareness is the only impenetrable shield.",
				"Identify your gear before putting it on your head. Cursed crowns are a dreadful way to go.",
				"The arcane arts demand discipline, not melodrama. Speak cleanly and breathe.",
				"I've buried archmages who thought their spells made them gods. Iron proved otherwise.",
				"Take what you need. The lower levels harbor entities that eat magical energy for breakfast."
			]
		},

		# =========================================================================
		# 4. UNIQUE CURIOS (5 Merchants)
		# =========================================================================
		"curios_zora": {
			"merchant_id": "curios_zora",
			"display_name": "Madame Zora",
			"title": "Mystic Diviner & Relic Keeper",
			"shop_type": Specialty.UNIQUE_CURIOS,
			"attitude": Attitude.ECCENTRIC_SCHOLAR,
			"dialogue_pool": [
				"The cards whispered of your arrival three floors above... or was that the ceiling shifting?",
				"Touch this amulet! Can you hear the faint lament of the dynasty that forged it?",
				"Rings carry memory in their bands. This one remembers a duel fought under twin moons.",
				"A curio is not chosen by the buyer; the object whispers when its master approaches.",
				"Destiny is a tapestry of tangled thread; these trinkets merely help untangle the knots.",
				"Do you see the faint violet glimmer inside this gemstone? A trapped constellation, perhaps?",
				"Never insult a mirror found in a crypt. It might decide to keep your reflection.",
				"Thieves' tools are merely keys that the universe forgot to label properly.",
				"The past is buried here in layers of dust and gold. What treasure shall we resurrect?",
				"Listen closely to the crystal's hum... it says your journey has only just begun."
			]
		},
		"curios_barnaby": {
			"merchant_id": "curios_barnaby",
			"display_name": "\"Lucky\" Barnaby",
			"title": "Fortune's Darling & Gambler of the Depths",
			"shop_type": Specialty.UNIQUE_CURIOS,
			"attitude": Attitude.ROOTING_FOR_PLAYER,
			"dialogue_pool": [
				"Hey there, partner! Today's your lucky day—and mine, if you buy something shiny!",
				"I survived three cave-ins, two pit traps, and a beholder gaze. Luck is a muscle, friend!",
				"Slip this ring on your finger and watch how often the enemy's spear misses by an inch.",
				"You've got that winner's stride! I can spot a grandmaster in the making a mile away.",
				"Every locked chest down here is just a present waiting for the right set of lockpicks.",
				"Don't worry about the odds; the house always loses if you stay on your feet long enough!",
				"I found this curio in a dragon's molar! Well, a very small dragon, but the story's true!",
				"Fortune smiles on the bold, but she laughs out loud at those who bring thieves' tools.",
				"Take this charm with you. It brought me out of the spider pits; it'll carry you through.",
				"Roll the dice, take the leap, and let's make the Grandmaster sweat!"
			]
		},
		"curios_silas": {
			"merchant_id": "curios_silas",
			"display_name": "Silas the Collector",
			"title": "Antiquarian of Forbidden Artifacts",
			"shop_type": Specialty.UNIQUE_CURIOS,
			"attitude": Attitude.SHREWD_OPPORTUNIST,
			"dialogue_pool": [
				"Every item on my velvet cloth has a pedigree written in blood and golden sovereigns.",
				"Rings of protection, amulets of might... true luxury for the discriminating survivalist.",
				"I do not sell cheap baubles. These are authentic artifacts salvaged from sealed royal vaults.",
				"A skilled rogue with my precision lockpicks can bypass horrors that would crush an army.",
				"Value is subjective, my dear customer, but staying alive is universal.",
				"Notice the hallmark on this band? The crest of the First Astral Dynasty. Priceless.",
				"Looking to part with rare curios you found in the crypts? My appraisal is brutally honest.",
				"Security requires an upfront investment. Don't skimp when purchasing magical wards.",
				"The Grandmaster collected wonders from across ten realms. I merely distribute them.",
				"No touches without gold on the scale. These artifacts are extremely delicate and potent."
			]
		},
		"curios_fenwick": {
			"merchant_id": "curios_fenwick",
			"display_name": "Fenwick",
			"title": "Pawn Broker of Lost Souls",
			"shop_type": Specialty.UNIQUE_CURIOS,
			"attitude": Attitude.BITTER_CYNIC,
			"dialogue_pool": [
				"Dead men's trinkets, that's all this is. Soon someone will buy your boots off me.",
				"You think a magic ring will save you from a falling portcullis? Good luck with that.",
				"Buy the lockpicks. At least when you trigger the poison needle, you'll die in privacy.",
				"Everything here was looted from a corpse. Yours will furnish next week's inventory.",
				"Don't ask about the previous owner. The bloodstains are already scrubbed off.",
				"Shiny toys for terrified children walking in the dark.",
				"You want power? Should have stayed in the sunlight where food grows.",
				"Here. Take this amulet. It failed the last three people who wore it, but maybe you're lucky.",
				"Make your bid or get out of my light. The damp down here is rusting my joints.",
				"The only curio that truly matters is an exit door, and I don't sell those."
			]
		},
		"curios_raven": {
			"merchant_id": "curios_raven",
			"display_name": "Raven",
			"title": "Shadow Operative & Relic Smuggler",
			"shop_type": Specialty.UNIQUE_CURIOS,
			"attitude": Attitude.WEARY_VETERAN,
			"dialogue_pool": [
				"Keep your voice low. Sound carries along these stonework tunnels.",
				"A good set of lockpicks makes less noise than a drawn blade. Choose the quiet path.",
				"I've slipped through traps that pulverized entire squads. Patience is the greatest relic.",
				"Check the tension on the tumblers before you torque. A snapped pick is a death sentence.",
				"Curios aren't jewelry; they are tactical leverage against impossible circumstances.",
				"Trust the shadows, but never trust an open door in an unmapped vault.",
				"I stole this ring from a cultist priest while he was in the middle of a sermon.",
				"Surviving the descent is about avoiding fights you don't need to win.",
				"Take the tools and tread softly. The deeper halls have ears in every brick.",
				"We work in silence so the world above never has to learn what crawls below."
			]
		},

		# =========================================================================
		# 5. GENERAL OUTFITTER (5 Merchants)
		# =========================================================================
		"outfitter_fallow": {
			"merchant_id": "outfitter_fallow",
			"display_name": "Fallow the Peddler",
			"title": "Subterranean Caravan Master",
			"shop_type": Specialty.GENERAL_OUTFITTER,
			"attitude": Attitude.SHREWD_OPPORTUNIST,
			"dialogue_pool": [
				"Need arrows? Rations? A spare belt? Fallow has everything a traveler requires!",
				"Never run dry on ammunition down here, friend! Teeth and claws don't wait for reloads!",
				"I haul my packs through collapsing corridors so you can enjoy retail convenience in hell!",
				"Bundle discount on quivers today! Buy thirty broadheads and shoot with confidence!",
				"The best warrior is an equipped warrior. Empty quivers make very hollow graves.",
				"Throwing knives, sling stones, crossbow quarrels—name your caliber, I've got the stock!",
				"Don't forget torches. You can't shoot what you can't see, unless you enjoy shooting shadows.",
				"Fair prices, sturdy goods, and zero questions asked about dungeon permits.",
				"Trade your salvage for cold hard ammo. You can't shoot a gold coin at a ghoul!",
				"A pleasure doing business! Come back when your quiver starts looking slim!"
			]
		},
		"outfitter_berta": {
			"merchant_id": "outfitter_berta",
			"display_name": "Berta",
			"title": "Expedition Provisioner & Quartermistress",
			"shop_type": Specialty.GENERAL_OUTFITTER,
			"attitude": Attitude.ROOTING_FOR_PLAYER,
			"dialogue_pool": [
				"Here now, darling, let's get you properly supplied. Nobody explores on an empty quiver!",
				"Take plenty of arrows! A straight shot from safety beats a desperate brawl any day.",
				"I packed these rations myself; dried venison and salted oats to keep your vigor up.",
				"You have a strong back and honest eyes. The Grandmaster's trials won't break you!",
				"Check your fletchings before you notch; a warped feather flies wild.",
				"If your bowstring snaps, come right back; I always keep spare sinew in the cart.",
				"Eat well, sleep when the corridor is secure, and keep your quiver brimming.",
				"Every hero in the ballads had a good quartermaster backing them up. Today, that's me!",
				"Don't you dare give up down there. I expect you back to tell me about the lower halls!",
				"Blessings on your journey, wanderer. May your shafts strike center and true!"
			]
		},
		"outfitter_pip": {
			"merchant_id": "outfitter_pip",
			"display_name": "Pip",
			"title": "Apprentice Scavenger & Munitions Tinkerer",
			"shop_type": Specialty.GENERAL_OUTFITTER,
			"attitude": Attitude.ECCENTRIC_SCHOLAR,
			"dialogue_pool": [
				"I balanced these throwing knives to rotate exactly 2.5 times over four tiles! Precision aerodynamics!",
				"Look at this crossbow bolt head—spiral grooves to induce rotational stability during flight!",
				"Have you tried weighing your ammunition? Variance exceeding half a gram ruins your grouping!",
				"I invented a new quiver lining made of oiled bat leather; draws are fifty percent quieter!",
				"Everything in my stall is cataloged by weight, velocity potential, and aerodynamic drag!",
				"Don't just loose arrows blindly! Calculate the trajectory against subterranean draft currents!",
				"If you find any odd feather plumes on giant bats, save them! They make marvelous fletchings!",
				"Munitions are an exact science! A single dented point drops penetration by thirty percent!",
				"I'm testing a new alloy for sling stones—twice the density for double the kinetic punch!",
				"Take a bundle! Tell me how the penetration felt against skeletal armor plates!"
			]
		},
		"outfitter_gareth": {
			"merchant_id": "outfitter_gareth",
			"display_name": "Gareth",
			"title": "Former Scout of the Ranger Corps",
			"shop_type": Specialty.GENERAL_OUTFITTER,
			"attitude": Attitude.WEARY_VETERAN,
			"dialogue_pool": [
				"Count your arrows after every encounter. Running dry in a corridor is how rangers die.",
				"Aim for the throat or the joints. Thick dungeon hides shrug off center-mass shots.",
				"Keep your bow unstrung during heavy damp or the wood will lose its spring.",
				"I've survived on dried pemmican and cavern moss for weeks. Good provisions save lives.",
				"Throwing axes require commitment. If you hesitate midway through the cast, you miss.",
				"Always keep five arrows in your hand, not in the quiver, when clearing narrow turns.",
				"The wind down here comes from the collapse zones. Learn to read the drafts.",
				"Gear that is simple and rugged outlasts flashy toys every single time.",
				"Buy what you can carry, but don't overburden your stride. Speed is a scout's shield.",
				"Stay sharp. The moment you think you're safe is when the ceiling opens up."
			]
		},
		"outfitter_dunstan": {
			"merchant_id": "outfitter_dunstan",
			"display_name": "Honest Dunstan",
			"title": "Merchant of Last Resort",
			"shop_type": Specialty.GENERAL_OUTFITTER,
			"attitude": Attitude.BITTER_CYNIC,
			"dialogue_pool": [
				"They call me Honest Dunstan because I'm the only one who admits my arrows are overpriced.",
				"What are you going to do, walk back to the surface for a cheaper quiver? Didn't think so.",
				"Iron points, wood shafts, feathers from who-knows-what. They fly, they kill. Take them.",
				"Don't whine about the price. Ammunition is cheaper than a funeral.",
				"I sell gear to dead men walking. If you survive, feel free to complain to management.",
				"You want warranties in a collapsed catacomb? You're funnier than you look.",
				"Buy the bolts or wrestle the ogres with your bare hands. Makes no difference to my ledger.",
				"Another day, another doomed adventurer buying fifty arrows to shoot at stone walls.",
				"Drop the coin and take the bundle. I'm packing up before the floor rattles again.",
				"May your aim be better than your judgment in choosing to descend here."
			]
		}
	}
	
	return _catalog_cache

static func get_merchant(merchant_id: String) -> Dictionary:
	var cat = get_catalog()
	if cat.has(merchant_id):
		return cat[merchant_id]
	return {}

static func get_merchants_by_specialty(specialty: Specialty) -> Array[Dictionary]:
	var cat = get_catalog()
	var results: Array[Dictionary] = []
	for m_id in cat.keys():
		var m_data = cat[m_id] as Dictionary
		if int(m_data.get("shop_type", -1)) == int(specialty):
			results.append(m_data)
	return results

static func get_random_merchant_for_specialty(specialty: Specialty) -> Dictionary:
	var list = get_merchants_by_specialty(specialty)
	if list.is_empty():
		return {}
	return list[randi() % list.size()]

static func get_random_dialogue(merchant_id: String) -> String:
	var m = get_merchant(merchant_id)
	if m.is_empty():
		return "Wares for trade, stranger."
	var pool = m.get("dialogue_pool", []) as Array
	if pool.is_empty():
		return "Wares for trade, stranger."
	return String(pool[randi() % pool.size()])
