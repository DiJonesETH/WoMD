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

MODE.PointsPerDamage = 1 -- очков за 1 хп урона по выжившим
MODE.PointsPerCorpse = 100 -- очков за съеденный труп
MODE.EatTime = 6
MODE.EatDistance = 90
MODE.SkeletonModel = "models/player/skeleton.mdl"

-- Деревья навыков классов зараженных. Формат навыка:
-- MODE.SkillTrees.zs_bruiser.some_skill = {
-- 	name = "Name", desc = "Description", cost = 100,
-- 	short = "Короткая строка на карточке", -- необязательно
-- 	requires = {"other_skill"}, -- нужны все, необязательно
-- 	requiresAny = {"a", "b"}, -- нужен любой из, необязательно
-- 	branch = "left", -- навыки разных веток одного дерева взаимоисключающие
-- 	auto = true, -- выдается бесплатно при выборе класса
-- 	color = Color(...), -- свой цвет карточки, необязательно
-- 	pos = {x = 0, y = 0}, -- место в сетке дерева (3 колонки x 5 рядов, y = 0 сверху)
-- 	OnBuy = function(ply) end, -- серверный эффект, необязательно
-- }
-- Эффекты навыков: sh_zs_agile.lua, sh_zs_bruiser.lua
MODE.SkillTrees = {
	zs_bruiser = {
		anabolism = {
			name = "Анаболизм",
			desc = "Организм зараженного тратит энергию на синтез живой массы.\n+ Вы заметно повышаете свою выживаемость и силу\n- Ваша скорость снижается",
			short = "+живучесть, +сила, -скорость",
			cost = 0,
			auto = true,
			pos = {x = 1, y = 4},
		},
		carcinoma = {
			name = "Карцинома",
			desc = "Вирус наращивает опухоли на теле зараженного.\n+ Вы получаете пассивную регенерацию здоровья\n+ Ваше базовое значение здоровья повышается",
			short = "регенерация, +здоровье",
			cost = 200,
			branch = "left",
			requires = {"anabolism"},
			pos = {x = 0, y = 3},
		},
		strong_legs = {
			name = "Крепкие ноги",
			desc = "Мышцы ног зараженного укрепляются.\n+ Вас невозможно сбить с ног",
			short = "не падает в регдолл",
			cost = 300,
			branch = "left",
			requires = {"carcinoma"},
			pos = {x = 0, y = 2},
		},
		mass_impulse = {
			name = "Импульс массы",
			desc = "Зараженный делает продолжительную пробежку вперед.\n+ Нажмите E+M1 чтобы резко пробежать вперед\n(сбивает выживших на пути)",
			short = "E+M1: таран вперед",
			cost = 600,
			branch = "left",
			requires = {"strong_legs"},
			pos = {x = 0, y = 1},
		},
		throw = {
			name = "Бросок",
			desc = "Зараженный получает возможность с силой бросать предметы.\n+ Хватайте предмет на M2 и, удерживая M2, бросайте его на M1",
			short = "M2 - взять, M1 - бросить",
			cost = 200,
			branch = "right",
			requires = {"anabolism"},
			pos = {x = 2, y = 3},
		},
		anabolic_boost = {
			name = "Анаболический форсаж",
			desc = "Вирус троекратно усиливает набор мышечной массы.\n+ Ваши удары сбивают людей с ног, ломают укрепления\n(сильнее бьют по большим пропам и рвут скотч)",
			short = "удары сбивают с ног и ломают",
			cost = 300,
			branch = "right",
			requires = {"throw"},
			pos = {x = 2, y = 2},
		},
		guillotine = {
			name = "Гильотина",
			desc = "Зараженный способен на близком расстоянии ампутировать случайную конечность (в том числе и голову).\n+ Нажмите E+M2 впритык к игроку чтобы оторвать его конечность\n(работает только один раз за жизнь)",
			short = "E+M2: оторвать конечность (1 раз)",
			cost = 600,
			branch = "right",
			requires = {"anabolic_boost"},
			pos = {x = 2, y = 1},
		},
		fibrodysplasia = {
			name = "Фибродисплазия",
			desc = "Вирус заменяет живую ткань тела на костную массу.\n+ Вы становитесь неуязвимы к пистолетным и ружейным калибрам (защита как у Kevlar IIIA)\n+ Удары наносят массивный тупой урон\n- Вы становитесь еще медленнее",
			short = "броня IIIA, тупой урон, медленнее",
			cost = 1000,
			requiresAny = {"mass_impulse", "guillotine"},
			color = Color(230, 180, 40),
			pos = {x = 1, y = 0},
		},
	},
	zs_agile = {
		autophagy = {
			name = "Аутофагия",
			desc = "Организм зараженного перерабатывает его тело для получения энергии.\n+ Вы заметно повышаете свою скорость и стамину\n- Ваша выживаемость снижается",
			short = "+скорость, +стамина, -живучесть",
			cost = 0,
			auto = true,
			pos = {x = 1, y = 4},
		},
		dash = {
			name = "Рывок",
			desc = "Стимуляция вирусом надпочечников позволяет зараженному делать мощные рывки.\n+ Нажмите E+M1 чтобы совершить рывок и сбить противника с ног",
			short = "E+M1: рывок, сбивает с ног",
			cost = 200,
			branch = "left",
			requires = {"autophagy"},
			pos = {x = 0, y = 3},
		},
		clinging_claws = {
			name = "Цепкие когти",
			desc = "Мышцы рук и кистей зараженного укрепляются.\n+ Теперь вы можете залезать на стены, а также зависать на них\n(у стены: прыжок - лезть вверх, присед - зависнуть)",
			short = "лазание и зависание на стенах",
			cost = 300,
			branch = "left",
			requires = {"dash"},
			pos = {x = 0, y = 2},
		},
		lethal_grab = {
			name = "Летальный захват",
			desc = "Зараженный впадает в яростную атаку на упавших игроков.\n+ Схватившись двумя руками за выжившего в регдолле, вы наносите серию беспорядочных режущих ударов до самой смерти\n(находясь в регдолле, схватите упавшего выжившего обеими руками - удары пойдут сами)",
			short = "захват двумя руками в регдолле",
			cost = 600,
			branch = "left",
			requires = {"clinging_claws"},
			pos = {x = 0, y = 1},
		},
		hyperdontia = {
			name = "Гипердонтия",
			desc = "Вирус видоизменяет структуру челюсти и зубов зараженного.\n+ Нажмите E+M1 чтобы совершить укус, наносящий глубокий проникающий урон",
			short = "E+M1: проникающий укус",
			cost = 200,
			branch = "right",
			requires = {"autophagy"},
			pos = {x = 2, y = 3},
		},
		foot_growths = {
			name = "Стопные наросты",
			desc = "Вирус развивает хрящевые наросты на стопах зараженного.\n+ Ваше передвижение бесшумно",
			short = "бесшумные шаги",
			cost = 300,
			branch = "right",
			requires = {"hyperdontia"},
			pos = {x = 2, y = 2},
		},
		autolysis = {
			name = "Автолиз",
			desc = "Организм зараженного экстремально истощается, уменьшаясь в размерах в несколько раз.\n+ Вы становитесь в 2 раза меньше, ваша плоть гниет, снижая контрастность в темноте",
			short = "в 2 раза меньше, черная плоть",
			cost = 600,
			branch = "right",
			requires = {"foot_growths"},
			pos = {x = 2, y = 1},
		},
		homeostasis = {
			name = "Высший гомеостаз",
			desc = "Организм зараженного лишается критически важных органов, все функции работают на максимальную мощность.\n+ Вас ЗНАЧИТЕЛЬНО сложнее убить, смерть мозга считается фатальной\n+ Скорость всех действий значительно увеличена",
			short = "без боли и органов, быстрее",
			cost = 1000,
			requiresAny = {"lethal_grab", "autolysis"},
			color = Color(230, 180, 40),
			pos = {x = 1, y = 0},
		},
	},
	zs_metaboliser = {},
}

-- все id навыков всех деревьев (для сброса)
function MODE:GetAllSkillIds()
	local ids = {}

	for _, tree in pairs(self.SkillTrees) do
		for id in pairs(tree) do
			ids[id] = true
		end
	end

	return ids
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
