local MODE = MODE

-- Орда: zb_hordeactivate включает (и выключает) появление зомби-некстботов из аддона nextbot_zambies
-- (github.com/StrawWagen/nextbot_zambies, база - termhunter) до конца раунда: сразу и затем каждые HordeInterval
-- секунд HordeMin..HordeMax зомби появляются в случайных точках карты подальше от выживших.
-- Зомби орды дружат с зараженными (не нападают на них и не ранят их), охотятся на выживших и ломают баррикады.
MODE.HordeInterval = 90
MODE.HordeMin = 3
MODE.HordeMax = 8
MODE.HordeMinDist = 900 -- не ближе к живым выжившим

-- weight - вес выпадения: обычные, реже, редкие
MODE.HordeTypes = {
	{class = "terminator_nextbot_zambie", weight = 10}, -- Zombie
	{class = "terminator_nextbot_zambiegrunt", weight = 10}, -- Zombie Grunt
	{class = "terminator_nextbot_zambiefast", weight = 10}, -- Fast Zombie
	{class = "terminator_nextbot_zambiefastgrunt", weight = 4}, -- Zombie Fast Elite
	{class = "terminator_nextbot_zambiephantom", weight = 4}, -- Zombie Phantom
	{class = "terminator_nextbot_zambietank", weight = 4}, -- Zombie Tank
	{class = "terminator_nextbot_zambiegruntelite", weight = 4}, -- Zombie Grunt Elite
	{class = "terminator_nextbot_zambieberserk", weight = 1}, -- Zombie Berserker
	{class = "terminator_nextbot_zambieacidfast", weight = 1}, -- Zombie Acid Fast
	{class = "terminator_nextbot_zambienecro", weight = 1}, -- Zombie Necromancer
}

local TEAM_SURVIVORS = 0
local horde = {}

local function IsHordeBot(ent)
	return IsValid(ent) and ent.zs_Horde == true
end
ZS_IsHordeBot = IsHordeBot

local function HordeRound()
	local mode = CurrentRound()
	return zb.ROUND_STATE == 1 and mode and mode.name == "zs" and mode.saved.StartTime and mode or nil
end

local function PickType(mode)
	local total = 0
	for _, t in ipairs(mode.HordeTypes) do
		if scripted_ents.GetStored(t.class) then total = total + t.weight end
	end
	if total <= 0 then return end

	local roll = math.Rand(0, total)
	for _, t in ipairs(mode.HordeTypes) do
		if scripted_ents.GetStored(t.class) then
			roll = roll - t.weight
			if roll <= 0 then return t.class end
		end
	end
end

local function GroundPoint(pos)
	local tr = util.TraceHull({
		start = pos + Vector(0, 0, 40),
		endpos = pos - Vector(0, 0, 200),
		mins = Vector(-16, -16, 0),
		maxs = Vector(16, 16, 72),
		mask = MASK_NPCSOLID,
	})

	if tr.Hit and not tr.StartSolid then return tr.HitPos + Vector(0, 0, 4) end
end

-- точка подальше от живых выживших
local function FindHordePoint(mode, points)
	local survivors = {}
	for _, ply in player.Iterator() do
		if ply:Alive() and ply:Team() == TEAM_SURVIVORS then survivors[#survivors + 1] = ply:GetPos() end
	end

	local minDist = mode.HordeMinDist ^ 2

	for _ = 1, 30 do
		local pos = GroundPoint(points[math.random(#points)])
		if pos then
			local far = true
			for _, spos in ipairs(survivors) do
				if spos:DistToSqr(pos) < minDist then far = false break end
			end
			if far then return pos end
		end
	end

	return GroundPoint(points[math.random(#points)])
end

-- отношения: зараженные - друзья, выжившие - цель (переназначаются, игроки меняют сторону посреди раунда)
local function UpdateRelations(bot)
	if not bot.AddEntityRelationship then return end

	for _, ply in player.Iterator() do
		local friend = ply:Team() ~= TEAM_SURVIVORS or (ZS_IsZombie and ZS_IsZombie(ply))
		bot:AddEntityRelationship(ply, friend and D_LI or D_HT, friend and 0 or 1000)
	end

	-- NPC зараженных (питательная среда, муравьиные львы разума улья) и зомби орды друг друга не трогают
	for ent in pairs(horde) do
		if IsValid(ent) and ent ~= bot then bot:AddEntityRelationship(ent, D_LI, 0) end
	end

	for _, npc in ipairs(ents.FindByClass("npc_*")) do
		if npc.zs_Owner ~= nil then
			bot:AddEntityRelationship(npc, D_LI, 0)
			if npc.AddEntityRelationship then npc:AddEntityRelationship(bot, D_LI, 0) end
		end
	end
end

function MODE:SpawnHorde()
	local points = ZS_GetMapPoints and ZS_GetMapPoints() or {}
	if #points == 0 then return 0 end

	local spawned = 0

	for _ = 1, math.random(self.HordeMin, self.HordeMax) do
		local class = PickType(self)
		local pos = class and FindHordePoint(self, points)

		if pos then
			local bot = ents.Create(class)
			if IsValid(bot) then
				bot:SetPos(pos + Vector(math.Rand(-24, 24), math.Rand(-24, 24), 0))
				bot:SetAngles(Angle(0, math.Rand(0, 360), 0))
				bot.zs_Horde = true
				bot:Spawn()
				bot:Activate()

				horde[bot] = true
				spawned = spawned + 1

				timer.Simple(0.2, function()
					if IsValid(bot) then UpdateRelations(bot) end
				end)
			end
		end
	end

	print("[ZS] Horde: " .. spawned .. " zombies spawned")
	return spawned
end

timer.Create("ZS_Horde", 1, 0, function()
	for bot in pairs(horde) do
		if not IsValid(bot) then horde[bot] = nil end
	end

	local mode = HordeRound()
	if not mode or not mode.saved.HordeActive then return end

	for bot in pairs(horde) do UpdateRelations(bot) end

	if CurTime() >= (mode.saved.NextHorde or 0) then
		mode.saved.NextHorde = CurTime() + mode.HordeInterval
		mode:SpawnHorde()
	end
end)

-- zb_hordeactivate: включить/выключить орду до конца раунда (админ)
concommand.Add("zb_hordeactivate", function(ply)
	if IsValid(ply) and not ply:IsAdmin() then return end

	local function Reply(text)
		if IsValid(ply) then ply:ChatPrint(text) else print(text) end
	end

	local mode = HordeRound()
	if not mode then
		Reply("Zombie Survival round is not running")
		return
	end

	if not scripted_ents.GetStored("terminator_nextbot_zambie") then
		Reply("The nextbot_zambies addon (and its termhunter base) is not installed on the server")
		return
	end

	mode.saved.HordeActive = not mode.saved.HordeActive
	mode.saved.NextHorde = 0

	PrintMessage(HUD_PRINTTALK, "[ZS] The horde is " .. (mode.saved.HordeActive and "coming: zombies arrive every " .. mode.HordeInterval .. " seconds" or "stopped"))
end)
