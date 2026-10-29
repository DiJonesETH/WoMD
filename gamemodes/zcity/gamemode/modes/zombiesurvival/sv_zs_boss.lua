local MODE = MODE

-- Боссы: в начале BossWave случайный живой зараженный становится боссом своего класса (ZS_BOSS_FOR_CLASS):
--   громила    -> Палач (Executioner, класс zs_gonome): E+M1 захват и разрывание, E+M2 парализующий плевок;
--   agile      -> Василиск (zs_basilisk): E+M1 щупальце притягивает выжившего, E+M2 невидимость до удара/урона,
--                 лазает по стенам (sh_zs_agile.lua), сверхбыстрые удары;
--   metaboliser-> Матриарх (zs_matriarch): E+M1 крик (регенерация и скорость ударов зараженным рядом),
--                 E+M2 струя кислоты.
-- Классы боссов: sh_zs_zombie.lua. Босс не падает в регдолл, не получает урон организма (боль, органы, кровь):
-- весь урон снимается с отдельного запаса здоровья ZS_BossHP (здоровье игрока homigrad обрезает до 100).
-- Клиент: cl_zs_boss.lua
MODE.BossWave = 3

-- Палач
MODE.BossGrabCooldown = 30
MODE.BossSpitCooldown = 10
MODE.BossSpitDelay = 1.5

-- Василиск
MODE.TentacleCooldown = 20
MODE.TentacleRange = 1050 -- ~20 м
MODE.TentaclePullTime = 1.5
MODE.InvisibleCooldown = 30

-- Матриарх
MODE.ScreamCooldown = 15
MODE.ScreamRadius = 1312 -- 25 м
MODE.ScreamTime = 10 -- сколько держится бафф
MODE.ScreamHeal = 3 -- лечение организма в секунду под баффом
MODE.AcidStreamCooldown = 12
MODE.AcidStreamTime = 1.5

-- zb_executioner 0 выключает появление босса на BossWave (zb_beexecutioner для теста работает всегда)
local bossEnabled = CreateConVar("zb_executioner", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Zombie Survival: spawn a boss on the boss wave", 0, 1)

util.AddNetworkString("zs_boss_rise")
util.AddNetworkString("zs_boss_tentacle")

local TEAM_SURVIVORS = 0

local function BossInfo(ply)
	return ZS_BOSS_CLASSES[ply.PlayerClassName]
end

local function BossPitch(ply)
	local info = IsValid(ply) and BossInfo(ply)
	local pitch = info and info.soundPitch or 80
	return math.random(pitch - 5, pitch + 5)
end

local function BossSound(ply, kind)
	return ZS_ZombieSound(ply, kind)
end

local function BossActive()
	local mode = CurrentRound()
	return zb.ROUND_STATE == 1 and mode and mode.name == "zs"
end

-- bossClass не указан - босс по классу зараженного
function MODE:MakeBoss(ply, bossClass)
	if not IsValid(ply) or not ply:Alive() or not ZS_IsZombie(ply) then return false end

	bossClass = bossClass or ZS_BOSS_FOR_CLASS[ply.zs_Class or ply.PlayerClassName] or "zs_gonome"
	local info = ZS_BOSS_CLASSES[bossClass]
	if not info then return false end

	if IsValid(ply.FakeRagdoll) and hg.FakeUp then hg.FakeUp(ply, true) end

	-- отдельный вид: навыки и эффекты прежнего класса снимаются,
	-- выбранный класс (ply.zs_Class) остается для следующего возрождения
	ply:SetPlayerClass(bossClass)

	ply:SetNWBool("ZS_Boss", true)
	ply:SetNWInt("ZS_BossHP", info.bossHealth)
	ply:SetNWInt("ZS_BossMaxHP", info.bossHealth)
	ply:SetNWString("PlayerName", info.name .. " " .. ply:Nick())

	SetGlobalEntity("ZS_Boss", ply)

	local snd = BossSound(ply, "idle")
	if snd then ply:EmitSound(snd, 110, BossPitch(ply)) end
	util.ScreenShake(ply:GetPos(), 6, 30, 1.5, 1500)

	net.Start("zs_boss_rise")
		net.WriteEntity(ply)
		net.WriteString(info.name)
	net.Broadcast()

	return true
end

------------------------------------------------------------------ Василиск: невидимость

local function SetInvisible(ply, invisible)
	if ply:GetNWBool("ZS_Invisible", false) == invisible then return end

	ply:SetNWBool("ZS_Invisible", invisible)
	ply:EmitSound(invisible and "npc/fast_zombie/fz_alert_close1.wav" or "npc/fast_zombie/fz_scream1.wav", 70, BossPitch(ply))
end

-- урон боссу: только в запас здоровья босса, без организма homigrad (вызывается из обертки урона, sh_zs_bruiser.lua)
function ZS_BossDamage(ent, dmgInfo)
	if not IsValid(ent) or not ent:IsPlayer() or not ZS_IsBoss(ent) or not ent:Alive() then return end

	local attacker = dmgInfo:GetAttacker()

	-- без урона от падения, физики и своих
	if dmgInfo:IsDamageType(DMG_FALL + DMG_CRUSH + DMG_DROWN) or IsValid(attacker) and attacker:IsPlayer() and attacker ~= ent and ZS_IsZombie(attacker) then
		return true
	end

	local damage = dmgInfo:GetDamage() * (ZS_MeleeMul and ZS_MeleeMul(ent, dmgInfo) or 1)
	if damage <= 0 then return true end

	-- невидимость пропадает от урона
	SetInvisible(ent, false)

	if IsValid(attacker) and attacker:IsPlayer() and attacker:Team() == TEAM_SURVIVORS then
		ent.zs_LastSurvivorHit = attacker
		ent.zs_LastSurvivorHitTime = CurTime()
	end

	local hp = ent:GetNWInt("ZS_BossHP", 0) - damage
	ent:SetNWInt("ZS_BossHP", math.max(math.ceil(hp), 0))

	if (ent.zs_NextBossPain or 0) < CurTime() then
		ent.zs_NextBossPain = CurTime() + 0.8
		local snd = BossSound(ent, "pain")
		if snd then ent:EmitSound(snd, 90, BossPitch(ent)) end
	end

	if hp <= 0 then ent:Kill() end

	return true
end

hook.Add("ZS_ClawAttack", "ZS_Boss", function(ply, special)
	if not ZS_IsBoss(ply) then return end

	-- невидимость пропадает от удара
	SetInvisible(ply, false)

	-- палач рычит при каждом ударе (урон когтей x2 задан классом)
	if ply.PlayerClassName == "zs_gonome" then
		ply:EmitSound("npc/zombie_poison/pz_warn" .. math.random(2) .. ".wav", 85, BossPitch(ply))
	end
end)

------------------------------------------------------------------ Палач

-- E+M1: схватить выжившего и разорвать на части (гильотина громилы, sh_zs_bruiser.lua)
local function ExecutionerGrab(ply)
	if (ply.zs_NextBossGrab or 0) > CurTime() then return end
	if not ZS_Guillotine or not ZS_Guillotine(ply, {tearAll = true}) then return end

	ply.zs_NextBossGrab = CurTime() + MODE.BossGrabCooldown

	ply:EmitSound("npc/zombie_poison/pz_throw2.wav", 95, BossPitch(ply))
end

-- E+M2: плевок кислотой, сгустки парализуют, как "Парализующие наросты"
local function ExecutionerSpit(ply)
	if (ply.zs_NextBossSpit or 0) > CurTime() then return end
	ply.zs_NextBossSpit = CurTime() + MODE.BossSpitCooldown

	ply:EmitSound("npc/zombie_poison/pz_throw3.wav", 95, BossPitch(ply))

	timer.Simple(MODE.BossSpitDelay, function()
		if not IsValid(ply) or not ply:Alive() or not ZS_IsBoss(ply) or not ZS_SpawnAcidGlob then return end

		local aim = ply:GetAimVector()
		local pos = ply:EyePos() + aim * 20

		for i = 1, 5 do
			local spread = i == 1 and vector_origin or VectorRand() * 0.06
			local glob = ZS_SpawnAcidGlob(ply, pos, (aim + spread + Vector(0, 0, 0.08)):GetNormalized() * 950)
			if IsValid(glob) then
				glob.zs_Paralyze = true
				glob.SplashRadius = 64
			end
		end

		ply:EmitSound("npc/antlion_guard/angry" .. math.random(3) .. ".wav", 80, 140)
	end)
end

------------------------------------------------------------------ Василиск

local function IsLivingSurvivor(ply)
	return IsValid(ply) and ply:IsPlayer() and ply:Alive() and ply:Team() == TEAM_SURVIVORS
end

local function SendTentacle(ply, target, hitPos, duration)
	net.Start("zs_boss_tentacle")
		net.WriteEntity(ply)
		net.WriteEntity(target or NULL)
		net.WriteVector(hitPos)
		net.WriteFloat(duration)
	net.Broadcast()
end

-- тянет регдолл выжившего к василиску TentaclePullTime секунд
local function PullRagdoll(ply, victim)
	local id = "ZS_Tentacle" .. ply:EntIndex()
	local untilTime = CurTime() + MODE.TentaclePullTime

	timer.Create(id, 0.05, 0, function()
		local ragdoll = IsValid(victim) and victim.FakeRagdoll
		if not IsValid(ply) or not ply:Alive() or not IsValid(ragdoll) or CurTime() > untilTime then
			timer.Remove(id)
			return
		end

		local target = ply:WorldSpaceCenter()
		if ragdoll:GetPos():DistToSqr(target) < 70 * 70 then
			timer.Remove(id)
			return
		end

		for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
			local phys = ragdoll:GetPhysicsObjectNum(i)
			if IsValid(phys) then
				phys:SetVelocity((target - phys:GetPos()):GetNormalized() * 650 + Vector(0, 0, 60))
			end
		end
	end)
end

-- E+M1: щупальце в сторону прицела; попало в выжившего - он падает в регдолл и летит к василиску
local function BasiliskTentacle(ply)
	if (ply.zs_NextTentacle or 0) > CurTime() then return end
	ply.zs_NextTentacle = CurTime() + MODE.TentacleCooldown

	SetInvisible(ply, false)

	local eye = ply:EyePos()
	local tr = util.TraceHull({
		start = eye,
		endpos = eye + ply:GetAimVector() * MODE.TentacleRange,
		mins = Vector(-6, -6, -6),
		maxs = Vector(6, 6, 6),
		filter = {ply, ply.FakeRagdoll},
		mask = MASK_SHOT,
	})

	ply:EmitSound("npc/barnacle/barnacle_tongue_pull" .. math.random(3) .. ".wav", 90, 90)

	local hit = tr.Entity
	local victim = IsValid(hit) and (hit:IsPlayer() and hit or hg.RagdollOwner(hit))

	if not IsLivingSurvivor(victim) then
		SendTentacle(ply, nil, tr.HitPos, 0.4)
		return
	end

	if not IsValid(victim.FakeRagdoll) then hg.Fake(victim) end
	if not IsValid(victim.FakeRagdoll) then
		SendTentacle(ply, nil, tr.HitPos, 0.4)
		return
	end

	victim:EmitSound("physics/flesh/flesh_squishy_impact_hard" .. math.random(4) .. ".wav", 80)
	SendTentacle(ply, victim.FakeRagdoll, tr.HitPos, MODE.TentaclePullTime)
	PullRagdoll(ply, victim)
end

-- E+M2: полная невидимость до первого удара или урона
local function BasiliskInvisible(ply)
	if (ply.zs_NextInvisible or 0) > CurTime() or ply:GetNWBool("ZS_Invisible", false) then return end
	ply.zs_NextInvisible = CurTime() + MODE.InvisibleCooldown

	SetInvisible(ply, true)
end

------------------------------------------------------------------ Матриарх

-- E+M1: крик - зараженные в радиусе получают регенерацию и ускоренные удары
local function MatriarchScream(ply)
	if (ply.zs_NextScream or 0) > CurTime() then return end
	ply.zs_NextScream = CurTime() + MODE.ScreamCooldown

	ply:EmitSound("npc/fast_zombie/fz_scream1.wav", 120, 60)
	ply:EmitSound("npc/zombie_poison/pz_call1.wav", 120, 70)
	util.ScreenShake(ply:GetPos(), 4, 20, 1.5, MODE.ScreamRadius)

	local untilTime = CurTime() + MODE.ScreamTime

	for _, ent in ipairs(ents.FindInSphere(ply:GetPos(), MODE.ScreamRadius)) do
		if ent:IsPlayer() and ent:Alive() and ZS_IsZombie(ent) then
			ent:SetNWFloat("ZS_RageUntil", untilTime)
		end
	end
end

-- регенерация под баффом крика
timer.Create("ZS_MatriarchRage", 1, 0, function()
	for _, ply in player.Iterator() do
		if ply:Alive() and ZS_IsZombie(ply) and ply:GetNWFloat("ZS_RageUntil", 0) > CurTime() then
			if ZS_HealOrganism then ZS_HealOrganism(ply, MODE.ScreamHeal) end
			ply:SetHealth(math.min(ply:Health() + 5, ply:GetMaxHealth()))
		end
	end
end)

-- E+M2: огромная струя кислоты в сторону прицела (не парализует)
local function MatriarchAcid(ply)
	if (ply.zs_NextAcidStream or 0) > CurTime() then return end
	ply.zs_NextAcidStream = CurTime() + MODE.AcidStreamCooldown

	ply:EmitSound("npc/zombie_poison/pz_throw3.wav", 100, BossPitch(ply))
	ply:EmitSound("npc/antlion_guard/angry" .. math.random(3) .. ".wav", 90, 120)

	local id = "ZS_AcidStream" .. ply:EntIndex()
	local shots = math.floor(MODE.AcidStreamTime / 0.05)

	timer.Create(id, 0.05, shots, function()
		if not IsValid(ply) or not ply:Alive() or not ZS_IsBoss(ply) or not ZS_SpawnAcidGlob then
			timer.Remove(id)
			return
		end

		local aim = ply:GetAimVector()
		local pos = ply:EyePos() + aim * 24

		for _ = 1, 2 do
			local glob = ZS_SpawnAcidGlob(ply, pos, (aim + VectorRand() * 0.05 + Vector(0, 0, 0.05)):GetNormalized() * math.Rand(900, 1200))
			if IsValid(glob) then glob.SplashRadius = 72 end
		end
	end)
end

------------------------------------------------------------------ способности

local abilities = {
	zs_gonome = {ExecutionerGrab, ExecutionerSpit},
	zs_basilisk = {BasiliskTentacle, BasiliskInvisible},
	zs_matriarch = {MatriarchScream, MatriarchAcid},
}

hook.Add("KeyPress", "ZS_BossAbilities", function(ply, key)
	if not ZS_IsBoss(ply) or not ply:Alive() or not ply:KeyDown(IN_USE) then return end

	local list = abilities[ply.PlayerClassName]
	if not list then return end

	if key == IN_ATTACK then
		list[1](ply)
	elseif key == IN_ATTACK2 then
		list[2](ply)
	end
end)

-- рычание раз в несколько секунд (невидимый василиск молчит)
timer.Create("ZS_BossIdle", 4, 0, function()
	local boss = GetGlobalEntity("ZS_Boss")
	if IsValid(boss) and ZS_IsBoss(boss) and boss:Alive() and not boss:GetNWBool("ZS_Invisible", false) and math.random(3) == 1 then
		local snd = BossSound(boss, "idle")
		if snd then boss:EmitSound(snd, 90, BossPitch(boss)) end
	end
end)

hook.Add("PlayerDeath", "ZS_Boss", function(ply)
	if not ZS_IsBoss(ply) then return end

	ply:SetNWBool("ZS_Boss", false)
	ply:SetNWBool("ZS_Invisible", false)
	if GetGlobalEntity("ZS_Boss") == ply then SetGlobalEntity("ZS_Boss", NULL) end
end)

hook.Add("PlayerSpawn", "ZS_Boss", function(ply)
	ply:SetNWBool("ZS_Boss", false)
	ply:SetNWBool("ZS_Invisible", false)
	ply:SetNWFloat("ZS_RageUntil", 0)
end)

-- в начале BossWave боссом становится случайный живой зараженный (если живых нет - первый появившийся)
hook.Add("ZS_WaveStart", "ZS_Boss", function(wave)
	local mode = CurrentRound()
	if not mode or mode.name ~= "zs" or wave ~= mode.BossWave or mode.saved.BossDone or not bossEnabled:GetBool() then return end

	mode.saved.BossDone = true

	local candidates = {}
	for _, ply in player.Iterator() do
		if ply:Alive() and ZS_IsZombie(ply) then candidates[#candidates + 1] = ply end
	end

	if #candidates == 0 then
		mode.saved.BossPending = true
		return
	end

	mode:MakeBoss(candidates[math.random(#candidates)])
end)

hook.Add("PlayerSpawn", "ZS_BossPending", function(ply)
	local mode = CurrentRound()
	if not BossActive() or not mode.saved.BossPending or not bossEnabled:GetBool() then return end

	timer.Simple(0.5, function()
		if IsValid(ply) and mode.saved.BossPending and ZS_IsZombie(ply) and mode:MakeBoss(ply) then
			mode.saved.BossPending = nil
		end
	end)
end)

-- имя босса из команды (executioner, basilisk, matriarch) -> класс; nil - по классу зараженного
local bossByName = {executioner = "zs_gonome", basilisk = "zs_basilisk", matriarch = "zs_matriarch"}
function MODE:BossClassByName(name)
	return bossByName[string.lower(name or "")]
end

-- zb_beexecutioner [executioner|basilisk|matriarch]: моментально стать боссом (админ)
concommand.Add("zb_beexecutioner", function(ply, cmd, args)
	if not IsValid(ply) or not ply:IsAdmin() then return end

	local mode = CurrentRound()
	if not BossActive() then
		ply:ChatPrint("Zombie Survival round is not running")
		return
	end

	if not (ply:Alive() and ZS_IsZombie(ply)) then
		if ply:Alive() then ply:KillSilent() end

		ply:SetTeam(1)
		mode:ForceSpawnZombie(ply)
	end

	local bossClass = mode:BossClassByName(args[1])

	timer.Simple(0.3, function()
		if IsValid(ply) then mode:MakeBoss(ply, bossClass) end
	end)
end)
