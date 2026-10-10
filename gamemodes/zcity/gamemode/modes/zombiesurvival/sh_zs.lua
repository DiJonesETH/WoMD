local MODE = MODE

MODE.name = "zs"
MODE.PrintName = "Zombie Survival"
MODE.Description = "Survivors must hold out through every wave of the infected. Anyone who dies joins the infection."

MODE.TEAM_SURVIVORS = 0
MODE.TEAM_INFECTED = 1

MODE.PrepTime = 60 -- подготовка перед/между волнами
MODE.WaveTime = 180 -- длительность одной волны

-- короткий и длинный подрежимы
MODE.Types = MODE.Types or {}
MODE.Types.zs_short = {
	PrintName = "Short",
	Waves = 6,
	Chance = 0.03,
}
MODE.Types.zs_long = {
	PrintName = "Long",
	Waves = 12,
	Chance = 0.02,
}

-- текущая фаза раунда, синхронизируется через глобальные переменные
function MODE:GetWaveInfo()
	return GetGlobalInt("ZS_Wave", 0), GetGlobalInt("ZS_Waves", 0), GetGlobalBool("ZS_WaveActive", false), GetGlobalFloat("ZS_PhaseEnd", 0)
end

MODE.PointsPerDamage = 0.5 -- очков за 1 хп урона по стоящему выжившему
MODE.PointsPerCorpse = 100 -- очков за съеденный труп
MODE.EatTime = 6
MODE.EatDistance = 90
MODE.SkeletonModel = "models/player/skeleton.mdl"

-- Деревья навыков классов зараженных. Формат навыка:
-- MODE.SkillTrees.zs_bruiser.some_skill = {
-- 	name = "Name", desc = "Description", cost = 100, -- desc целиком выводится на карточке
-- 	short = "Short line", -- необязательно, не отображается
-- 	requires = {"other_skill"}, -- нужны все, необязательно
-- 	requiresAny = {"a", "b"}, -- нужен любой из, необязательно
-- 	branch = "left", -- навыки разных веток одного дерева взаимоисключающие
-- 	auto = true, -- выдается бесплатно при выборе класса
-- 	color = Color(...), -- свой цвет карточки, необязательно
-- 	pos = {x = 0, y = 0}, -- место в сетке дерева (3 колонки x 5 рядов, y = 0 сверху)
-- 	OnBuy = function(ply) end, -- серверный эффект, необязательно
-- }
-- Эффекты навыков: sh_zs_agile.lua, sh_zs_bruiser.lua, sh_zs_metaboliser.lua
MODE.SkillTrees = {
	zs_bruiser = {
		anabolism = {
			name = "Anabolism",
			desc = "The infected's body spends energy synthesizing living mass.\n+ Your survivability and strength rise noticeably\n- Your speed drops",
			short = "+survivability, +strength, -speed",
			cost = 0,
			auto = true,
			pos = {x = 1, y = 4},
		},
		carcinoma = {
			name = "Carcinoma",
			desc = "The virus grows tumors on the infected's body.\n+ You gain passive health regeneration\n+ Your base health increases",
			short = "regeneration, +health",
			cost = 200,
			branch = "left",
			requires = {"anabolism"},
			pos = {x = 0, y = 3},
		},
		strong_legs = {
			name = "Strong Legs",
			desc = "The infected's leg muscles grow stronger.\n+ You can't be knocked down",
			short = "can't be knocked down",
			cost = 300,
			branch = "left",
			requires = {"carcinoma"},
			pos = {x = 0, y = 2},
		},
		mass_impulse = {
			name = "Mass Impulse",
			desc = "The infected makes a long sprint forward.\n+ Press E+M1 to sprint forward sharply, smashing props and doors in your way",
			short = "E+M1: charge, smash props and doors",
			cost = 600,
			branch = "left",
			requires = {"strong_legs"},
			pos = {x = 0, y = 1},
		},
		traumatic_slap = {
			name = "Traumatic Slap",
			desc = "The infected gains the ability to strike with tremendous force.\n+ Press E+M1 next to a survivor to slap them aside and knock them down",
			short = "E+M1: slap a survivor aside",
			cost = 200,
			branch = "right",
			requires = {"anabolism"},
			pos = {x = 2, y = 3},
		},
		anabolic_boost = {
			name = "Anabolic Boost",
			desc = "The virus triples the growth of muscle mass.\n+ Your hits knock people down and break fortifications",
			short = "hits knock down and break",
			cost = 300,
			branch = "right",
			requires = {"traumatic_slap"},
			pos = {x = 2, y = 2},
		},
		guillotine = {
			name = "Guillotine",
			desc = "At close range the infected can amputate a random limb (including the head).\n+ Press E+M2 right next to a player to grab them by a limb, lift them up and tear it off after 2 seconds (works only once per life)",
			short = "E+M2: grab and tear off a limb (once)",
			cost = 600,
			branch = "right",
			requires = {"anabolic_boost"},
			pos = {x = 2, y = 1},
		},
		fibrodysplasia = {
			name = "Fibrodysplasia",
			desc = "The virus replaces the body's living tissue with bone mass.\n+ You become immune to pistol and rifle calibers.\n+ Your hits deal massive blunt damage.\n- You become even slower",
			short = "IIIA armor, blunt damage, slower",
			cost = 1000,
			requiresAny = {"mass_impulse", "guillotine"},
			color = Color(230, 180, 40),
			pos = {x = 1, y = 0},
		},
	},
	zs_agile = {
		autophagy = {
			name = "Autophagy",
			desc = "The infected's organism consumes its own body for energy.\n+ Your speed and stamina rise noticeably\n- Your survivability drops",
			short = "+speed, +stamina, -survivability",
			cost = 0,
			auto = true,
			pos = {x = 1, y = 4},
		},
		dash = {
			name = "Dash",
			desc = "The virus stimulates the adrenal glands, letting the infected make powerful dashes.\n+ Press E+M1 to dash and knock an enemy down",
			short = "E+M1: dash, knocks down",
			cost = 200,
			branch = "left",
			requires = {"autophagy"},
			pos = {x = 0, y = 3},
		},
		clinging_claws = {
			name = "Clinging Claws",
			desc = "The infected's arm and hand muscles grow stronger.\n+ You can now climb walls and hang on them.",
			short = "climb and cling to walls",
			cost = 300,
			branch = "left",
			requires = {"dash"},
			pos = {x = 0, y = 2},
		},
		lethal_grab = {
			name = "Lethal Grab",
			desc = "The infected goes into a furious attack on downed players.\n+ Grabbing a ragdolled survivor with both hands, you deal a series of frenzied slashing hits until they die.",
			short = "two-handed grab in ragdoll",
			cost = 600,
			upgrade = {
				id = "lethal_dash",
				name = "Lethal Dash",
				desc = "If your Dash knocks a survivor down, you instantly fall on them in ragdoll, grab them with both hands and deal a series of hits.",
			},
			branch = "left",
			requires = {"clinging_claws"},
			pos = {x = 0, y = 1},
		},
		hyperdontia = {
			name = "Hyperdontia",
			desc = "The virus reshapes the infected's jaw and teeth.\n+ Press E+M1 to bite, dealing deep penetrating damage.",
			short = "E+M1: penetrating bite",
			cost = 200,
			branch = "right",
			requires = {"autophagy"},
			pos = {x = 2, y = 3},
		},
		foot_growths = {
			name = "Foot Growths",
			desc = "The virus grows cartilage on the infected's feet.\n+ Your movement is silent",
			short = "silent footsteps",
			cost = 300,
			branch = "right",
			requires = {"hyperdontia"},
			pos = {x = 2, y = 2},
		},
		autolysis = {
			name = "Autolysis",
			desc = "The infected's organism becomes extremely exhausted and shrinks.\n+ You become a quarter smaller, and your rotting flesh makes you harder to see in the dark",
			short = "3/4 size, black flesh",
			cost = 600,
			branch = "right",
			requires = {"foot_growths"},
			pos = {x = 2, y = 1},
		},
		homeostasis = {
			name = "Higher Homeostasis",
			desc = "The infected's organism loses its vital organs, and every function runs at full power.\n+ You are MUCH harder to kill, only brain death is fatal\n+ All your actions are much faster",
			short = "no pain or organs, faster",
			cost = 1000,
			requiresAny = {"lethal_grab", "autolysis"},
			color = Color(230, 180, 40),
			pos = {x = 1, y = 0},
		},
	},
	zs_metaboliser = {
		nutrient_medium = {
			name = "Nutrient Medium",
			desc = "The infected's organism turns into a bioreactor that attracts other infected.\n+ Once per life you can spawn one infected NPC next to you, press CTRL+R\n- Base health and damage are reduced.",
			short = "CTRL+R: NPC zombie, -health, -damage",
			cost = 0,
			auto = true,
			pos = {x = 1, y = 4},
		},
		ballistic_growths = {
			name = "Ballistic Growths",
			desc = "The virus grows sharp spikes under pressure.\n+ Press E+M1 to shoot a spike once per life",
			short = "E+M1: spike (once per life)",
			cost = 200,
			upgrade = {
				id = "paralyzing_growths",
				name = "Paralyzing Growths",
				desc = "2 seconds after the spike hits a survivor, their muscles are paralyzed: they fall into a stiff ragdoll for 7 seconds.",
			},
			branch = "left",
			requires = {"nutrient_medium"},
			pos = {x = 0, y = 3},
		},
		reflux = {
			name = "Reflux",
			desc = "The infected's gastric juices turn into a mix of aggressive acids.\n+ Press E+M2 to release a stream of acid that causes burns",
			short = "E+M2: acid stream",
			cost = 300,
			branch = "left",
			requires = {"ballistic_growths"},
			pos = {x = 0, y = 2},
		},
		methane = {
			name = "Methane Excess",
			desc = "The infected fills with flammable gases.\n+ After death your body explodes, dousing everyone within 5 meters in acid",
			short = "acid explosion on death",
			cost = 600,
			branch = "left",
			requires = {"reflux"},
			pos = {x = 0, y = 1},
		},
		nest = {
			name = "Nest",
			desc = "The infected grows putrid mass to build a nest.\n+ Once per round you can build a nest for your team to spawn at, press E+M1.",
			short = "E+M1: nest (once per wave)",
			cost = 200,
			branch = "right",
			requires = {"nutrient_medium"},
			pos = {x = 2, y = 3},
		},
		meat_mycelium = {
			name = "Meat Mycelium",
			desc = "The infected spreads spores of meat mycelium that react sharply to their surroundings and regenerate flesh.\n+ You can place 1 blister per round. The blister multiplies up to 5 and heals infected within 5 meters, and it explodes when survivors are in that radius. Press E+M2",
			short = "E+M2: blister (once per wave)",
			cost = 300,
			branch = "right",
			requires = {"nest"},
			pos = {x = 2, y = 2},
		},
		bacterial_seeding = {
			name = "Bacterial Seeding",
			desc = "The infected pumps beneficial bacteria into others.\n+ Press R on an ally to start healing",
			short = "R on ally: heal",
			cost = 600,
			branch = "right",
			requires = {"meat_mycelium"},
			pos = {x = 2, y = 1},
		},
		herd_pheromones = {
			name = "Herd Pheromones",
			desc = "The infected secretes compounds that attract other infected.\n+ You can spawn three fast zombies per life.\n+ Hitting a player reveals their location.",
			short = "CTRL+R: 3 fast zombies, mark",
			cost = 1000,
			requiresAny = {"methane", "bacterial_seeding"},
			color = Color(230, 180, 40),
			pos = {x = 1, y = 0},
		},
	},
}

-- все id навыков всех деревьев (для сброса)
function MODE:GetAllSkillIds()
	local ids = {}

	for _, tree in pairs(self.SkillTrees) do
		for id, skill in pairs(tree) do
			ids[id] = true
			if skill.upgrade then ids[skill.upgrade.id] = true end
		end
	end

	return ids
end

-- Улучшение навыка: доступно только для изученного навыка с полем upgrade, стоит в UpgradeCostMul раз дороже навыка.
-- Улучшение хранится как отдельный навык upgrade.id (ZS_HasSkill(ply, upgrade.id)).
MODE.UpgradeCostMul = 2

function MODE:GetUpgradeCost(skill)
	return (skill.cost or 0) * self.UpgradeCostMul
end

function MODE:CanUpgradeSkill(owned, class, id, points)
	local tree = self.SkillTrees[class]
	local skill = tree and tree[id]
	if not skill or not skill.upgrade then return false, "none" end
	if owned[skill.upgrade.id] then return false, "owned" end
	if not owned[id] then return false, "requires" end
	if points and points < self:GetUpgradeCost(skill) then return false, "points" end

	return true
end

-- можно ли купить навык; reason - причина отказа
function MODE:CanLearnSkill(owned, class, id, points)
	local tree = self.SkillTrees[class]
	local skill = tree and tree[id]
	if not skill then return false, "unknown" end
	if owned[id] then return false, "owned" end

	for _, req in ipairs(skill.requires or {}) do
		if not owned[req] then return false, "requires" end
	end

	if skill.requiresAny then
		local any = false
		for _, req in ipairs(skill.requiresAny) do
			if owned[req] then any = true break end
		end
		if not any then return false, "requires" end
	end

	if skill.branch then
		for otherId in pairs(owned) do
			local other = tree[otherId]
			if other and other.branch and other.branch ~= skill.branch then return false, "branch" end
		end
	end

	if points and points < (skill.cost or 0) then return false, "points" end

	return true
end

function MODE:GetPlayerZombieClass(ply)
	local class = ply:GetNWString("ZS_Class", "")
	return class ~= "" and class or nil
end
