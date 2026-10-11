local MODE = MODE

-- Босс-палач (Executioner, внутренний класс zs_gonome): в начале BossWave случайный живой зараженный превращается в палача -
-- громилу из мяса ростом ~2.2 м (класс zs_gonome в sh_zs_zombie.lua), с пониженным голосом громилы.
-- Босс не падает в регдолл, не получает урон организма (боль, органы, кровь): весь урон снимается
-- с отдельного запаса здоровья ZS_BossHP (здоровье игрока homigrad обрезает до 100). Клиент: cl_zs_boss.lua
MODE.BossWave = 3
MODE.BossHealth = 5000
MODE.BossGrabCooldown = 30
MODE.BossSpitCooldown = 10
MODE.BossSpitDelay = 1.5

-- zb_executioner 0 выключает появление палача на BossWave (zb_beexecutioner для теста работает всегда)
local bossEnabled = CreateConVar("zb_executioner", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Zombie Survival: spawn the Executioner boss on the boss wave", 0, 1)

util.AddNetworkString("zs_boss_rise")

local TEAM_SURVIVORS = 0

-- голос босса - звуки громилы, пониженные (класс zs_gonome в sh_zs_zombie.lua)
local function BossSound(ply, kind)
	return ZS_ZombieSound(ply, kind)
end

local function BossPitch()
	local info = ZS_BOSS_CLASSES.zs_gonome
	return math.random(info.soundPitch - 5, info.soundPitch + 5)
end

local function BossActive()
	local mode = CurrentRound()
	return zb.ROUND_STATE == 1 and mode and mode.name == "zs"
end

function MODE:MakeBoss(ply)
	if not IsValid(ply) or not ply:Alive() or not ZS_IsZombie(ply) then return false end

	if IsValid(ply.FakeRagdoll) and hg.FakeUp then hg.FakeUp(ply, true) end

	-- отдельный вид (класс zs_gonome, sh_zs_zombie.lua): навыки и эффекты прежнего класса снимаются,
	-- выбранный класс (ply.zs_Class) остается для следующего возрождения
	ply:SetPlayerClass("zs_gonome")

	ply:SetNWBool("ZS_Boss", true)
	ply:SetNWInt("ZS_BossHP", self.BossHealth)
	ply:SetNWInt("ZS_BossMaxHP", self.BossHealth)
	ply:SetNWString("PlayerName", "Executioner " .. ply:Nick())

	SetGlobalEntity("ZS_Boss", ply)

	ply:EmitSound("npc/zombie_poison/pz_alert1.wav", 110, BossPitch())
	util.ScreenShake(ply:GetPos(), 6, 30, 1.5, 1500)

	net.Start("zs_boss_rise")
		net.WriteEntity(ply)
	net.Broadcast()

	return true
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

	if IsValid(attacker) and attacker:IsPlayer() and attacker:Team() == TEAM_SURVIVORS then
		ent.zs_LastSurvivorHit = attacker
		ent.zs_LastSurvivorHitTime = CurTime()
	end

	local hp = ent:GetNWInt("ZS_BossHP", 0) - damage
	ent:SetNWInt("ZS_BossHP", math.max(math.ceil(hp), 0))

	if (ent.zs_NextBossPain or 0) < CurTime() then
		ent.zs_NextBossPain = CurTime() + 0.8
		local snd = BossSound(ent, "pain")
		if snd then ent:EmitSound(snd, 90, BossPitch()) end
	end

	if hp <= 0 then ent:Kill() end

	return true
end

-- удары когтями: рык (урон когтей x2 задан классом zs_gonome)
hook.Add("ZS_ClawAttack", "ZS_Boss", function(ply, special)
	if not ZS_IsBoss(ply) then return end

	ply:EmitSound("npc/zombie_poison/pz_warn" .. math.random(2) .. ".wav", 85, BossPitch())
end)

-- E+M1: схватить выжившего и разорвать на части (гильотина громилы, sh_zs_bruiser.lua), раз в BossGrabCooldown секунд
local function BossGrab(ply)
	if (ply.zs_NextBossGrab or 0) > CurTime() then return end
	if not ZS_Guillotine or not ZS_Guillotine(ply, {tearAll = true}) then return end

	ply.zs_NextBossGrab = CurTime() + MODE.BossGrabCooldown

	ply:EmitSound("npc/zombie_poison/pz_throw2.wav", 95, BossPitch())
end

-- E+M2: плевок кислотой (анимация attack3), сгустки парализуют, как "Парализующие наросты"
local function BossSpit(ply)
	if (ply.zs_NextBossSpit or 0) > CurTime() then return end
	ply.zs_NextBossSpit = CurTime() + MODE.BossSpitCooldown

	ply:EmitSound("npc/zombie_poison/pz_throw3.wav", 95, BossPitch())

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

hook.Add("KeyPress", "ZS_BossAbilities", function(ply, key)
	if not ZS_IsBoss(ply) or not ply:Alive() or not ply:KeyDown(IN_USE) then return end

	if key == IN_ATTACK then
		BossGrab(ply)
	elseif key == IN_ATTACK2 then
		BossSpit(ply)
	end
end)

-- рычание раз в несколько секунд
timer.Create("ZS_BossIdle", 4, 0, function()
	local boss = GetGlobalEntity("ZS_Boss")
	if IsValid(boss) and ZS_IsBoss(boss) and boss:Alive() and math.random(3) == 1 then
		local snd = BossSound(boss, "idle")
		if snd then boss:EmitSound(snd, 90, BossPitch()) end
	end
end)

hook.Add("PlayerDeath", "ZS_Boss", function(ply)
	if not ZS_IsBoss(ply) then return end

	ply:SetNWBool("ZS_Boss", false)
	if GetGlobalEntity("ZS_Boss") == ply then SetGlobalEntity("ZS_Boss", NULL) end
end)

hook.Add("PlayerSpawn", "ZS_Boss", function(ply)
	ply:SetNWBool("ZS_Boss", false)
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

-- zb_beexecutioner: моментально стать боссом (админ)
concommand.Add("zb_beexecutioner", function(ply)
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

	timer.Simple(0.3, function()
		if IsValid(ply) then mode:MakeBoss(ply) end
	end)
end)
