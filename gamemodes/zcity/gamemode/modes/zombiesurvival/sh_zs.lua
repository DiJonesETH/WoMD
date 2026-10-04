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

-- Деревья навыков классов зараженных (пока без навыков). Формат навыка:
-- MODE.SkillTrees.zs_bruiser.some_skill = {
-- 	name = "Name", desc = "Description", cost = 100,
-- 	requires = {"other_skill"}, -- необязательно
-- 	pos = {x = 0, y = 0}, -- место в сетке дерева
-- 	OnBuy = function(ply) end, -- серверный эффект, необязательно
-- }
MODE.SkillTrees = MODE.SkillTrees or {
	zs_bruiser = {},
	zs_agile = {},
	zs_metaboliser = {},
}

function MODE:GetPlayerZombieClass(ply)
	local class = ply:GetNWString("ZS_Class", "")
	return class ~= "" and class or nil
end
