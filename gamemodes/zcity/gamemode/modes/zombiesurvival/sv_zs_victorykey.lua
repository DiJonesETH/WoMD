local MODE = MODE

-- "Ключ к победе": с шансом VictoryKeyChance в начале раунда в случайном месте карты появляется термоядерная бомба
-- (lua/entities/zs_victory_bomb.lua), а в другом случайном месте - записка с 4-значным кодом (zs_victory_note.lua).
-- Верный код взводит бомбу; через 10 секунд термоядерный взрыв (эффекты по мотивам ent_jack_gmod_eznuke_big из
-- Jackarunda/gmod) испаряет всех игроков и пропы, раунд заканчивается.
MODE.VictoryKeyChance = 1 -- процентов
MODE.VictoryNoteMinDist = 600 -- записка не ближе к бомбе

util.AddNetworkString("zs_victorykey_msg")
util.AddNetworkString("zs_thermonuke")

local WINNER_NUKE = 2

-- случайные точки на земле: навмеш, иначе точки RandomSpawns, иначе спавны игроков
local function RandomGroundPoints()
	local list = {}

	for _, area in ipairs(navmesh.GetAllNavAreas()) do
		if area:GetSizeX() > 48 and area:GetSizeY() > 48 and not area:IsUnderwater() then
			list[#list + 1] = area:GetCenter()
		end
	end

	if #list > 0 then return list end

	local points = zb.GetMapPoints("RandomSpawns")
	if points and #points > 0 then return zb.TranslatePointsToVectors(points) end

	for _, ent in ipairs(ents.FindByClass("info_player_*")) do
		list[#list + 1] = ent:GetPos()
	end

	return list
end

local function GroundAt(pos)
	local tr = util.TraceLine({start = pos + Vector(0, 0, 32), endpos = pos - Vector(0, 0, 256), mask = MASK_SOLID_BRUSHONLY})
	return tr.Hit and tr.HitPos or pos
end

local function SpawnVictoryKey()
	local points = RandomGroundPoints()
	if #points == 0 then return end

	for _, ent in ipairs(ents.FindByClass("zs_victory_*")) do ent:Remove() end

	local code = string.format("%04d", math.random(0, 9999))

	local bombPos = GroundAt(points[math.random(#points)])
	local bomb = ents.Create("zs_victory_bomb")
	if not IsValid(bomb) then return end

	-- капсула воткнута в землю, как после падения
	bomb:SetPos(bombPos + Vector(0, 0, 20))
	bomb:SetAngles(Angle(-60, math.Rand(0, 360), 0))
	bomb:Spawn()
	bomb.Code = code

	local far = {}
	for _, pos in ipairs(points) do
		if pos:Distance(bombPos) >= MODE.VictoryNoteMinDist then far[#far + 1] = pos end
	end
	if #far == 0 then far = points end

	local note = ents.Create("zs_victory_note")
	if IsValid(note) then
		note:SetPos(GroundAt(far[math.random(#far)]) + Vector(0, 0, 2))
		note:SetAngles(Angle(0, math.Rand(0, 360), 90))
		note:Spawn()
		note.Code = code
	end

	net.Start("zs_victorykey_msg")
	net.Broadcast()

	print("[ZS] Victory key spawned at " .. tostring(bombPos) .. ", code " .. code)

	return code
end

hook.Add("ZS_PrepStart", "ZS_VictoryKey", function(wave)
	local mode = CurrentRound()
	if not mode or mode.name ~= "zs" or wave ~= 1 or mode.saved.VictoryKeyRolled then return end

	mode.saved.VictoryKeyRolled = true

	if math.Rand(0, 100) < mode.VictoryKeyChance then
		SpawnVictoryKey()
	end
end)

-- zb_victorykey: заспавнить бомбу и записку (код сразу пишется админу)
concommand.Add("zb_victorykey", function(ply)
	if IsValid(ply) and not ply:IsAdmin() then return end

	local mode = CurrentRound()
	if not mode or mode.name ~= "zs" or zb.ROUND_STATE ~= 1 then
		if IsValid(ply) then ply:ChatPrint("Zombie Survival round is not running") end
		return
	end

	local code = SpawnVictoryKey()
	local text = code and ("[ZS] Victory key spawned. Code: " .. code) or "[ZS] No place found for the victory key"

	if IsValid(ply) then ply:ChatPrint(text) else print(text) end
end)

-- все, что испаряется: пропы, регдоллы, постройки и предметы режима
local vaporizeClasses = {"prop_physics*", "prop_ragdoll", "zs_*", "func_physbox", "weapon_*"}

function ZS_Thermonuke(pos)
	local mode = CurrentRound()

	net.Start("zs_thermonuke")
		net.WriteVector(pos)
	net.Broadcast()

	util.ScreenShake(pos, 1000, 15, 15, 50000)

	-- раскаты взрыва на 10 секунд, как у eznuke_big
	for i = 0, 100 do
		timer.Simple(i / 10, function()
			for _, ply in player.Iterator() do
				ply:EmitSound("ambient/explosions/explode_" .. math.random(9) .. ".wav", 60, 80 - i / 2)
			end
		end)
	end

	if mode and mode.name == "zs" then mode.saved.NukeDone = true end

	-- испаряются все игроки и пропы
	for _, ply in player.Iterator() do
		if ply:Alive() then ply:Kill() end
	end

	timer.Simple(0.1, function()
		for _, class in ipairs(vaporizeClasses) do
			for _, ent in ipairs(ents.FindByClass(class)) do
				if IsValid(ent) and not (ent:IsWeapon() and IsValid(ent:GetOwner())) then ent:Remove() end
			end
		end
	end)
end

-- вызывается из MODE:ShouldRoundEnd (sv_zs.lua)
function MODE:CheckNukeEnd()
	if self.saved.NukeDone then
		self.saved.Winner = WINNER_NUKE
		return true
	end
end
