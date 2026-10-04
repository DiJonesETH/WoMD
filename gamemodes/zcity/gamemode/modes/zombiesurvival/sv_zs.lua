local MODE = MODE

MODE.name = "zs"
MODE.PrintName = "Zombie Survival"

MODE.start_time = 5
MODE.end_time = 10

MODE.ROUND_TIME = 1800

MODE.OverrideSpawn = true
MODE.LootSpawn = false
MODE.ForBigMaps = false
MODE.Chance = 0.03

MODE.Type = MODE.Type or "zs_short"

MODE.InfectedAtStart = 2
MODE.ZombieRespawnDelay = 5
MODE.PistolChance = 15

local TEAM_SURVIVORS = 0
local TEAM_INFECTED = 1
local WINNER_NONE = 3

local colSurvivor = Color(60, 160, 220)
local colInfected = Color(150, 20, 20)

local survivorMelee = {
	"weapon_hg_crowbar",
	"weapon_bat",
	"weapon_leadpipe",
	"weapon_hatchet",
	"weapon_hammer",
	"weapon_pocketknife",
	"weapon_hg_shovel",
	"weapon_pan",
	"weapon_tomahawk",
}

local survivorPistols = {
	"weapon_glock17",
	"weapon_makarov",
	"weapon_m9beretta",
	"weapon_hk_usp",
	"weapon_px4beretta",
}

util.AddNetworkString("zs_start")
util.AddNetworkString("zs_phase")
util.AddNetworkString("zs_roundend")
util.AddNetworkString("zs_requestspawn")

function MODE:SetupChances()
	for name, tbl in pairs(self.Types) do
		zb.ModesChances[name] = zb.ModesChances[name] or tbl.Chance
	end
end

function MODE:SubModes()
	return table.GetKeys(self.Types)
end

function MODE:CanLaunch()
	local activePlayers = 0

	for _, ply in player.Iterator() do
		if ply:Team() ~= TEAM_SPECTATOR then
			activePlayers = activePlayers + 1
		end
	end

	return activePlayers >= 3
end

function MODE:GetTeamSpawn()
	return zb.TranslatePointsToVectors(zb.GetMapPoints("HMCD_TDM_T")), zb.TranslatePointsToVectors(zb.GetMapPoints("HMCD_TDM_CT"))
end

local function SetPhaseGlobals(wave, waves, active, phaseEnd)
	SetGlobalInt("ZS_Wave", wave)
	SetGlobalInt("ZS_Waves", waves)
	SetGlobalBool("ZS_WaveActive", active)
	SetGlobalFloat("ZS_PhaseEnd", phaseEnd)
end

-- Таймлайн: [подготовка, волна] x N. Возвращает номер волны, идёт ли волна, время конца фазы и закончились ли все волны.
local function GetPhase(mode)
	local data = mode.saved
	if not data.StartTime then return 0, false, 0, false end

	local period = mode.PrepTime + mode.WaveTime
	local elapsed = CurTime() - data.StartTime

	if elapsed >= data.Waves * period then
		return data.Waves, false, 0, true
	end

	local wave = math.floor(elapsed / period) + 1
	local waveStart = data.StartTime + (wave - 1) * period
	local active = CurTime() >= waveStart + mode.PrepTime
	local phaseEnd = waveStart + (active and period or mode.PrepTime)

	return wave, active, phaseEnd, false
end

local function GetZombieSpawnPos(ply)
	local points = zb.GetMapPoints("RandomSpawns")

	if points and #points > 0 then
		return zb:FurthestFromEveryone(zb.TranslatePointsToVectors(points))
	end

	return zb:GetRandomSpawn(ply)
end

local function SpawnZombie(mode, ply, nest)
	ply:SetTeam(TEAM_INFECTED)
	ply:Spawn()

	hg.CreateInv(ply)
	ply:SetPlayerClass(ply.zs_Class)

	-- гнездо metaboliser - альтернативная точка спавна
	local pos = IsValid(nest) and nest:GetSpawnPos() or GetZombieSpawnPos(ply)
	if pos then
		ply:SetPos(pos)
	end

	local info = ZS_ZOMBIE_CLASSES[ply.zs_Class]
	zb.GiveRole(ply, info.name, info.color)
end

local function SetupSurvivor(ply)
	ply:SetupTeam(TEAM_SURVIVORS)
	ApplyAppearance(ply, nil, nil, nil, true)

	zb.GiveRole(ply, "Survivor", colSurvivor)

	ply:Give("weapon_hands_sh")
	ply:Give("weapon_medkit_sh")

	if math.random(100) <= MODE.PistolChance then
		local gun = ply:Give(survivorPistols[math.random(#survivorPistols)])

		if IsValid(gun) then
			ply:GiveAmmo(gun:GetMaxClip1() * 2, gun:GetPrimaryAmmoType(), true)
		end
	end

	local melee = ply:Give(survivorMelee[math.random(#survivorMelee)])

	if IsValid(melee) then
		ply:SelectWeapon(melee:GetClass())
	end
end

local function SetupInfectedSpectator(ply)
	ply:SetTeam(TEAM_INFECTED)
	ply:SetPlayerClass()
	ply:KillSilent()
	ply:Spectate(OBS_MODE_ROAMING)

	zb.GiveRole(ply, "Infected", colInfected)
end

function MODE:Intermission()
	game.CleanUpMap()

	local _, CROUND = CurrentRound()

	if not self.Types[CROUND] then
		CROUND = table.Random(self:SubModes())
	end

	self.Type = CROUND

	local waves = self.Types[self.Type].Waves
	local total = waves * (self.PrepTime + self.WaveTime)

	self.saved.Waves = waves
	self.saved.StartTime = nil
	self.saved.Wave = 0
	self.saved.Active = false

	SetPhaseGlobals(0, waves, false, 0)

	self.Infected.Reset()

	hg.UpdateRoundTime(total + self.start_time + 30, CurTime(), CurTime() + self.start_time)

	net.Start("zs_start")
		net.WriteUInt(waves, 8)
	net.Broadcast()
end

function MODE:GiveEquipment()
	local players = {}

	for _, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then continue end

		ply.zs_NextSpawn = 0
		players[#players + 1] = ply
	end

	table.Shuffle(players)

	local infectedCount = math.Clamp(self.InfectedAtStart, 0, math.max(#players - 1, 0))

	for i, ply in ipairs(players) do
		if i <= infectedCount then
			SetupInfectedSpectator(ply)
		else
			SetupSurvivor(ply)
		end
	end
end

local function UpdatePhase(mode, force)
	local wave, active, phaseEnd, finished = GetPhase(mode)
	if finished then return end

	if not force and wave == mode.saved.Wave and active == mode.saved.Active then return end

	mode.saved.Wave = wave
	mode.saved.Active = active

	SetPhaseGlobals(wave, mode.saved.Waves, active, phaseEnd)

	net.Start("zs_phase")
		net.WriteUInt(wave, 8)
		net.WriteBool(active)
	net.Broadcast()
end

function MODE:RoundStart()
	self.saved.StartTime = CurTime()

	UpdatePhase(self, true)
end

function MODE:RoundThink()
	UpdatePhase(self)
end

local function CountAliveSurvivors()
	local count = 0

	for _, ply in ipairs(team.GetPlayers(TEAM_SURVIVORS)) do
		if ply:Alive() then
			count = count + 1
		end
	end

	return count
end

function MODE:ShouldRoundEnd()
	if not self.saved.StartTime then return false end

	if CountAliveSurvivors() == 0 then
		self.saved.Winner = TEAM_INFECTED
		return true
	end

	local _, _, _, finished = GetPhase(self)
	if finished then
		self.saved.Winner = TEAM_SURVIVORS
		return true
	end

	return false
end

function MODE:EndRound()
	local winner = self.saved.Winner or WINNER_NONE -- раунд мог быть завершен админом
	local wave, waves = self.saved.Wave or 0, self.saved.Waves or 0

	SetPhaseGlobals(wave, waves, false, 0)

	for _, ply in player.Iterator() do
		if ply:Team() == winner then
			ply:GiveExp(math.random(15, 30))
			ply:GiveSkill(math.Rand(0.1, 0.15))
		end
	end

	timer.Simple(2, function()
		net.Start("zs_roundend")
			net.WriteUInt(winner, 2)
			net.WriteUInt(wave, 8)
			net.WriteUInt(waves, 8)
		net.Broadcast()
	end)
end

function MODE:CanSpawn()
	return false
end

function MODE:PlayerDeath(ply)
	if zb.ROUND_STATE ~= 1 then return end

	ply.zs_NextSpawn = CurTime() + self.ZombieRespawnDelay

	self.Infected.MarkCorpse(ply)

	if ply:Team() == TEAM_SURVIVORS then
		ply:SetTeam(TEAM_INFECTED)

		PrintMessage(HUD_PRINTTALK, ply:Name() .. " has been infected.")
		zb.GiveRole(ply, "Infected", colInfected)
	end
end

local function TrySpawnZombie(mode, ply, nest)
	if zb.ROUND_STATE ~= 1 then return end
	if ply:Alive() then return end

	local team_ = ply:Team()
	if team_ == TEAM_SPECTATOR or team_ == TEAM_SURVIVORS then return end

	local _, active, _, finished = GetPhase(mode)
	if not active or finished then return end
	if (ply.zs_NextSpawn or 0) > CurTime() then return end

	-- класс выбирается один раз на весь подраунд
	if not mode.Infected.EnsureClass(ply) then return end

	SpawnZombie(mode, ply, nest)
end

-- Нажатия мертвых игроков ловит клиент (как выбор цели в наблюдателе в cl_init.lua) и присылает запрос на спавн по E
net.Receive("zs_requestspawn", function(len, ply)
	if (ply.zs_NextRequest or 0) > CurTime() then return end
	ply.zs_NextRequest = CurTime() + 0.5

	local mode = CurrentRound()
	if not mode or mode.name ~= "zs" then return end

	-- наблюдатель может навестись на гнездо зараженных и появиться у него
	local nest = net.ReadEntity()
	if not IsValid(nest) or nest:GetClass() ~= "zs_nest" then nest = nil end

	TrySpawnZombie(mode, ply, nest)
end)

-- боты возрождаются сами
function MODE:PlayerDeathThink(ply)
	if ply:IsBot() then
		TrySpawnZombie(self, ply)
	end
end

function MODE:ZB_JoinSpectators(ply)
	if ply:Alive() then return true end
end
