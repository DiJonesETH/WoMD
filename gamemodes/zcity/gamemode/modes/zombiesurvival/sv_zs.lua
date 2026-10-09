local MODE = MODE

MODE.name = "zs"
MODE.PrintName = "Zombie Survival"

MODE.start_time = 5
MODE.end_time = 10

MODE.ROUND_TIME = 1800

MODE.OverrideSpawn = true
MODE.LootSpawn = true
MODE.LootOnTime = true
MODE.LootDivTime = 500
MODE.ForBigMaps = false
MODE.Chance = 0.03

MODE.Type = MODE.Type or "zs_short"

MODE.InfectedAtStart = 2
MODE.ZombieRespawnDelay = 5
MODE.ZombieCorpseLifeTime = 60 -- через сколько секунд исчезает труп зараженного
MODE.PistolChance = 15
MODE.WelderChance = 35 -- шанс получить сварочный аппарат на старте (один выживший получает его всегда)

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
util.AddNetworkString("zs_music")
util.AddNetworkString("zs_lastman")

resource.AddFile("sound/zbattle/zs/lastwave.mp3")
resource.AddFile("sound/zbattle/zs/roundstart.mp3")

-- музыка на последней волне: 1 - включать, 0 - нет
local lastWaveMusic = CreateConVar("zb_lastwavemusic", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Zombie Survival: play music during the last wave (1/0)", 0, 1)
MODE.LastWaveMusicDelay = 3 -- секунда подготовки последней волны, на которой стартует трек

local function PlayMusic(track)
	net.Start("zs_music")
		net.WriteString(track)
	net.Broadcast()
end

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

-- точки спавна игроков карты: точки Spawnpoint из редактора, иначе стандартные энтити спавна
local playerSpawnClasses = {
	"info_player_start", "info_player_deathmatch", "info_player_combine", "info_player_rebel",
	"info_player_counterterrorist", "info_player_terrorist", "info_player_axis", "info_player_allies",
	"gmod_player_start", "info_player_teamspawn", "info_player_coop", "info_player_human", "info_player_zombie",
}

local function GetPlayerSpawnPoints()
	local points = zb.GetMapPoints("Spawnpoint")
	if points and #points > 0 then
		return zb.TranslatePointsToVectors(points)
	end

	local list = {}
	for _, class in ipairs(playerSpawnClasses) do
		for _, ent in ipairs(ents.FindByClass(class)) do
			list[#list + 1] = ent:GetPos()
		end
	end

	return list
end

-- зараженный появляется на случайной из самых дальних от живых выживших точек спавна игроков
MODE.ZombieSpawnChoices = 3

local function GetZombieSpawnPos(ply)
	local points = GetPlayerSpawnPoints()
	if #points == 0 then return zb:GetRandomSpawn(ply) end

	local survivors = {}
	for _, other in player.Iterator() do
		if other:Alive() and other:Team() == TEAM_SURVIVORS then survivors[#survivors + 1] = other:GetPos() end
	end

	local scored = {}
	for _, pos in ipairs(points) do
		local nearest = math.huge
		for _, spos in ipairs(survivors) do
			nearest = math.min(nearest, pos:DistToSqr(spos))
		end

		-- занятые точки (кто-то стоит вплотную) в конце списка
		local occupied = false
		for _, ent in ipairs(ents.FindInSphere(pos, 32)) do
			if ent:IsPlayer() and ent:Alive() and ent ~= ply then occupied = true break end
		end

		scored[#scored + 1] = {pos = pos, dist = nearest, occupied = occupied}
	end

	table.sort(scored, function(a, b)
		if a.occupied ~= b.occupied then return not a.occupied end
		return a.dist > b.dist
	end)

	local choices = math.min(MODE.ZombieSpawnChoices, #scored)
	return scored[math.random(choices)].pos
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

-- спавн зараженного в обход ожидания (команда zb_begonome); класс выбирается случайно, если его нет
function MODE:ForceSpawnZombie(ply)
	if not ply.zs_Class then
		self.Infected.SetClass(ply, ZS_ZOMBIE_CLASS_ORDER[math.random(#ZS_ZOMBIE_CLASS_ORDER)])
	end

	SpawnZombie(self, ply)
end

local function SetupSurvivor(ply)
	ply:SetupTeam(TEAM_SURVIVORS)
	ApplyAppearance(ply, nil, nil, nil, true)

	ply.zs_Attackers = nil

	-- Z отвечает за проход сквозь баррикады
	ply:SetCanZoom(false)

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

	self.ResetSurvivorPoints()
	SetGlobalEntity("ZS_LastMan", NULL)

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
	self.saved.AirdropWave = 0

	SetPhaseGlobals(0, waves, false, 0)

	self.Infected.Reset()

	hg.UpdateRoundTime(total + self.start_time + 30, CurTime(), CurTime() + self.start_time)

	timer.Remove("ZS_LastWaveMusic")

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

	local welderGiven = false

	for i, ply in ipairs(players) do
		if i <= infectedCount then
			SetupInfectedSpectator(ply)
		else
			SetupSurvivor(ply)

			-- сварочный аппарат для баррикад (sh_zs_barricade.lua)
			if not welderGiven or math.random(100) <= self.WelderChance then
				welderGiven = true
				ply:Give("weapon_zs_arcwelder")
				ZS_BARRICADE.SetElectrodes(ply, ZS_BARRICADE.WelderElectrodes)
			end
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

	if active then
		hook.Run("ZS_WaveStart", wave)
	else
		hook.Run("ZS_PrepStart", wave)

		-- трек последней волны стартует на 3-й секунде ее подготовки
		if wave == mode.saved.Waves and lastWaveMusic:GetBool() then
			timer.Create("ZS_LastWaveMusic", mode.LastWaveMusicDelay, 1, function()
				if zb.ROUND_STATE == 1 and CurrentRound() == mode then
					mode.saved.LastManMusic = nil
					PlayMusic("lastwave")
				end
			end)
		end
	end

	net.Start("zs_phase")
		net.WriteUInt(wave, 8)
		net.WriteBool(active)
	net.Broadcast()
end

function MODE:RoundStart()
	self.saved.StartTime = CurTime()

	-- здоровье всех пропов карты (баррикады, sh_zs_barricade.lua)
	ZS_BARRICADE.SetupProps()

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

	-- термоядерный взрыв (sv_zs_victorykey.lua)
	if self:CheckNukeEnd() then return true end

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
		ply:SetCanZoom(true)
		ZS_BARRICADE.SetGhosting(ply, false)

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

function MODE:PlayerDeath(ply, inflictor, attacker)
	if zb.ROUND_STATE ~= 1 then return end

	ply.zs_NextSpawn = CurTime() + self.ZombieRespawnDelay

	self.Infected.MarkCorpse(ply)

	-- очки за убийство выжившего: убийце и всем, кто его ранил
	if ply:Team() == TEAM_SURVIVORS then
		for zombie in pairs(ply.zs_Attackers or {}) do
			if IsValid(zombie) and ZS_IsZombie(zombie) then
				self.Infected.AddPoints(zombie, self.PointsPerKill)
			end
		end

		ply.zs_Attackers = nil
	end

	if ply:Team() == TEAM_INFECTED then
		self:RemoveZombieCorpse(ply)
		self:RewardZombieKill(ply, attacker)
	elseif ply:Team() == TEAM_SURVIVORS then
		ply:SetTeam(TEAM_INFECTED)

		zb.GiveRole(ply, "Infected", colInfected)

		-- последний выживший погиб: его трек резко обрывается (трек последней волны не трогаем)
		if ply == self.saved.LastMan then
			self.saved.LastMan = nil
			SetGlobalEntity("ZS_LastMan", NULL)

			if self.saved.LastManMusic then
				self.saved.LastManMusic = nil
				PlayMusic("")
			end
		end

		self:CheckLastMan()
	end
end

-- LAST MAN STANDING: когда в живых остается один выживший - оповещение, LastManPoints очков и свой трек
MODE.LastManPoints = 2500

function MODE:CheckLastMan()
	if self.saved.LastManDone or CountAliveSurvivors() ~= 1 then return end

	local last
	for _, ply in ipairs(team.GetPlayers(TEAM_SURVIVORS)) do
		if ply:Alive() then last = ply break end
	end

	if not IsValid(last) then return end

	self.saved.LastManDone = true
	self.saved.LastMan = last

	self.AddSurvivorPoints(last, self.LastManPoints)

	-- зараженные видят последнего выжившего сквозь стены (cl_zs.lua)
	SetGlobalEntity("ZS_LastMan", last)

	net.Start("zs_lastman")
		net.WriteEntity(last)
	net.Broadcast()

	-- на последней волне играет ее трек, его не заменяем
	local wave = GetPhase(self)
	if wave < self.saved.Waves then
		self.saved.LastManMusic = true
		PlayMusic("lastman")
	end
end

-- регдолл погибшего зараженного удаляется через минуту
function MODE:RemoveZombieCorpse(ply)
	local lifeTime = self.ZombieCorpseLifeTime

	timer.Simple(0.1, function()
		if not IsValid(ply) then return end

		local ragdoll = IsValid(ply.RagdollDeath) and ply.RagdollDeath or ply:GetNWEntity("RagdollDeath")
		if not IsValid(ragdoll) then return end

		timer.Simple(lifeTime, function()
			if IsValid(ragdoll) then ragdoll:Remove() end
		end)
	end)
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

-- zb_skipwave: пропустить текущую волну (с ее подготовкой), следующая начнется с подготовки
concommand.Add("zb_skipwave", function(ply)
	if IsValid(ply) and not ply:IsAdmin() then return end

	local mode = CurrentRound()
	if not mode or mode.name ~= "zs" or zb.ROUND_STATE ~= 1 or not mode.saved.StartTime then return end

	local period = mode.PrepTime + mode.WaveTime
	local wave = GetPhase(mode)
	local nextWaveStart = mode.saved.StartTime + wave * period

	mode.saved.StartTime = mode.saved.StartTime - (nextWaveStart - CurTime())
	UpdatePhase(mode)

	PrintMessage(HUD_PRINTTALK, (IsValid(ply) and ply:Nick() or "Console") .. " skipped wave " .. wave .. ".")
end)
