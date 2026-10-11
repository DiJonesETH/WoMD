-- Зараженные Zombie Survival не видят экранных эффектов организма homigrad: боль, виньетка, шок/контузия,
-- лоботомия (картинки и "залипание" мыши), берсерк, адреналин, подавление огнем, хедкраб на голове.
-- Оригинальные хуки не меняются: поверх них ставится обертка, которая пропускает их, пока играешь за зараженного.

local function IsInfected()
	local ply = LocalPlayer()
	return IsValid(ply) and ply:Alive() and ZS_IsZombie and ZS_IsZombie(ply)
end

-- хуки, которые у зараженного просто не выполняются
local skipped = {
	["Post Post Processing"] = {"berserkEffect", "noradrenalineEffect"},
	["Post Post Pre Post Processing"] = {"organism-effects"},
	["RenderScreenspaceEffects"] = {"berserkEffect", "noradrenalineEffect", "SIB_Suppresss", "hg-headcrab"},
	["HG_CalcView"] = {"InsaneRollCam"},
	["HG.InputMouseApply"] = {"zzzzzzzzzzzzbrain_death"},
}

-- "ItHurts" (боль, виньетка, шок, лоботомия) еще и ведет звуки: его вызываем без организма,
-- тогда он сам глушит звуки и ничего не рисует
local withoutOrganism = {
	["Post Post Processing"] = {"ItHurts"},
}

local function Wrap(event, name, makeWrapper)
	local hooks = hook.GetTable()[event]
	local fn = hooks and hooks[name]
	if not fn or (isfunction(fn) and debug.getinfo(fn, "S").source == debug.getinfo(1, "S").source) then return end

	hook.Add(event, name, makeWrapper(fn))
end

local function WrapAll()
	for event, names in pairs(skipped) do
		for _, name in ipairs(names) do
			Wrap(event, name, function(original)
				return function(...)
					if IsInfected() then return end
					return original(...)
				end
			end)
		end
	end

	for event, names in pairs(withoutOrganism) do
		for _, name in ipairs(names) do
			Wrap(event, name, function(original)
				return function(...)
					if not IsInfected() then return original(...) end

					local ply = LocalPlayer()
					local org = ply.organism
					ply.organism = nil

					local ok, err = pcall(original, ...)
					ply.organism = org

					if not ok then ErrorNoHalt(err .. "\n") end
				end
			end)
		end
	end
end

-- хуки homigrad добавляются при загрузке его файлов; оборачиваем после загрузки и проверяем периодически
-- (обертка узнается по файлу, в котором объявлена, поэтому повторно не оборачивается)
hook.Add("InitPostEntity", "ZS_InfectedNoScreenEffects", WrapAll)
timer.Create("ZS_InfectedNoScreenEffects", 5, 0, WrapAll)
