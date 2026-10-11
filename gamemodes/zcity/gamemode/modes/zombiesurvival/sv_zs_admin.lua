local MODE = MODE

-- Админские команды Zombie Survival (игрок - часть ника, SteamID, SteamID64 или #userid):
--   zb_zsteam <игрок> <survivor|infected>          - перевести игрока в команду
--   zb_zsclass <игрок> <bruiser|agile|metaboliser> - сменить класс зараженного (навыки сбрасываются)
--   zb_zsresetskills <игрок>                       - обнулить дерево навыков (очки остаются)
--   zb_makeexecutioner <игрок>                     - превратить игрока в палача (Executioner)

local TEAM_SURVIVORS, TEAM_INFECTED = 0, 1

local classAliases = {
	bruiser = "zs_bruiser",
	agile = "zs_agile",
	metaboliser = "zs_metaboliser",
	metabolizer = "zs_metaboliser",
}

local function Reply(ply, text)
	if IsValid(ply) then ply:ChatPrint(text) else print(text) end
end

local function FindPlayer(caller, query)
	if not query or query == "" then
		Reply(caller, "Specify a player (part of the name, SteamID or #userid)")
		return
	end

	local id = string.match(query, "^#(%d+)$")
	if id then
		local ply = Player(tonumber(id))
		if IsValid(ply) then return ply end
	end

	for _, ply in player.Iterator() do
		if ply:SteamID() == query or ply:SteamID64() == query then return ply end
	end

	local found = player.GetListByName(query)
	if #found == 1 then return found[1] end

	if #found == 0 then
		Reply(caller, "No player matches \"" .. query .. "\"")
	else
		local names = {}
		for _, ply in ipairs(found) do names[#names + 1] = ply:Nick() .. " (#" .. ply:UserID() .. ")" end
		Reply(caller, "Several players match \"" .. query .. "\": " .. table.concat(names, ", "))
	end
end

-- общая проверка: админ (или консоль сервера) и идет раунд Zombie Survival
local function AdminCommand(name, usage, func)
	concommand.Add(name, function(caller, cmd, args)
		if IsValid(caller) and not caller:IsAdmin() then
			Reply(caller, "You don't have access")
			return
		end

		local mode = CurrentRound()
		if zb.ROUND_STATE ~= 1 or not mode or mode.name ~= "zs" then
			Reply(caller, "Zombie Survival round is not running")
			return
		end

		local target = FindPlayer(caller, args[1])
		if not target then
			Reply(caller, "Usage: " .. name .. " " .. usage)
			return
		end

		func(mode, caller, target, args)
	end)
end

local function Announce(caller, text)
	PrintMessage(HUD_PRINTTALK, "[ZS] " .. (IsValid(caller) and caller:Nick() or "Console") .. " " .. text)
end

AdminCommand("zb_zsteam", "<player> <survivor|infected>", function(mode, caller, target, args)
	local team_ = string.lower(args[2] or "")

	if team_ == "survivor" or team_ == "survivors" or team_ == "human" then
		target:SetPlayerClass()
		target:SetTeam(TEAM_SURVIVORS)
		target:UnSpectate()
		target:Spawn()

		hg.CreateInv(target)
		mode:SetupSurvivor(target)

		Announce(caller, "moved " .. target:Nick() .. " to the survivors")
	elseif team_ == "infected" or team_ == "zombie" or team_ == "zombies" then
		mode:SetupInfectedSpectator(target)
		target.zs_NextSpawn = 0
		mode:CheckLastMan()

		Announce(caller, "moved " .. target:Nick() .. " to the infected")
	else
		Reply(caller, "Usage: zb_zsteam <player> <survivor|infected>")
	end
end)

AdminCommand("zb_zsclass", "<player> <bruiser|agile|metaboliser>", function(mode, caller, target, args)
	local class = classAliases[string.lower(args[2] or "")]
	if not class then
		Reply(caller, "Usage: zb_zsclass <player> <bruiser|agile|metaboliser>")
		return
	end

	mode.Infected.ClearSkills(target)
	target.zs_Class = nil
	mode.Infected.SetClass(target, class)
	mode.Infected.SendSkills(target)

	-- живой зараженный сразу перерождается в новом классе на том же месте (босс остается боссом)
	if target:Alive() and ZS_IsZombie(target) and not ZS_IsBoss(target) then
		local pos, ang = target:GetPos(), target:EyeAngles()

		if IsValid(target.FakeRagdoll) and hg.FakeUp then hg.FakeUp(target, true) end

		mode:SpawnZombie(target)
		target:SetPos(pos)
		target:SetEyeAngles(ang)
	end

	Announce(caller, "set the infected class of " .. target:Nick() .. " to " .. ZS_ZOMBIE_CLASSES[class].name)
end)

AdminCommand("zb_zsresetskills", "<player>", function(mode, caller, target)
	mode.Infected.ClearSkills(target)

	-- стартовые навыки класса возвращаются
	if target.zs_Class then
		local class = target.zs_Class
		target.zs_Class = nil
		mode.Infected.SetClass(target, class)
	end

	mode.Infected.SendSkills(target)

	Announce(caller, "reset the skill tree of " .. target:Nick())
end)

AdminCommand("zb_makeexecutioner", "<player>", function(mode, caller, target)
	if not (target:Alive() and ZS_IsZombie(target)) then
		if target:Alive() then target:KillSilent() end

		target:SetTeam(TEAM_INFECTED)
		mode:ForceSpawnZombie(target)
	end

	timer.Simple(0.3, function()
		if IsValid(target) and mode:MakeBoss(target) then
			Announce(caller, "turned " .. target:Nick() .. " into the Executioner")
			mode:CheckLastMan()
		end
	end)
end)
