local MODE = MODE

-- Босс-гоном: в начале BossWave случайный живой зараженный превращается в гонома
-- (модель, анимации и звуки - Opposing Force, ассеты из VJ-HLR-Developers/Half-Life-Resurgence; код свой).
-- Босс не падает в регдолл, не получает урон организма (боль, органы, кровь): весь урон снимается
-- с отдельного запаса здоровья ZS_BossHP (здоровье игрока homigrad обрезает до 100). Клиент: cl_zs_boss.lua
MODE.BossWave = 3
MODE.BossHealth = 5000
MODE.BossGrabCooldown = 30
MODE.BossSpitCooldown = 10
MODE.BossSpitDelay = 1.5

-- модель, материалы и звуки гонома скачиваются клиентам при входе (без этого у них ERROR или пустота)
resource.AddFile("models/vj_hlr/opfor/gonome.mdl")
resource.AddFile("materials/models/hl_resurgence/opfor/zombie_gonome.vmt")
resource.AddFile("materials/models/hl_resurgence/opfor/zombie_gonome_head.vmt")
resource.AddSingleFile("materials/models/hl_resurgence/opfor/zombie_gonome_g.vtf")

for _, name in ipairs(file.Find("sound/vj_hlr/gsrc/npc/gonome/*.wav", "GAME")) do
	resource.AddSingleFile("sound/vj_hlr/gsrc/npc/gonome/" .. name)
end

util.AddNetworkString("zs_boss_rise")
util.AddNetworkString("zs_boss_death")

local TEAM_SURVIVORS = 0

local soundsPain = {"vj_hlr/gsrc/npc/gonome/gonome_pain1.wav", "vj_hlr/gsrc/npc/gonome/gonome_pain2.wav", "vj_hlr/gsrc/npc/gonome/gonome_pain3.wav", "vj_hlr/gsrc/npc/gonome/gonome_pain4.wav"}
local soundsIdle = {"vj_hlr/gsrc/npc/gonome/gonome_idle1.wav", "vj_hlr/gsrc/npc/gonome/gonome_idle2.wav", "vj_hlr/gsrc/npc/gonome/gonome_idle3.wav"}
local soundsDeath = {"vj_hlr/gsrc/npc/gonome/gonome_death2.wav", "vj_hlr/gsrc/npc/gonome/gonome_death3.wav", "vj_hlr/gsrc/npc/gonome/gonome_death4.wav"}

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
	ply:SetNWString("PlayerName", "Gonome " .. ply:Nick())

	SetGlobalEntity("ZS_Boss", ply)

	ply:EmitSound("vj_hlr/gsrc/npc/gonome/gonome_jumpattack.wav", 110, 90)
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
		ent:EmitSound(soundsPain[math.random(#soundsPain)], 90, math.random(95, 105))
		ent:SetNWFloat("ZS_GonomeFlinch", CurTime())
	end

	if hp <= 0 then ent:Kill() end

	return true
end

-- удары когтями: анимация атаки гонома (урон когтей x2 задан классом zs_gonome)
hook.Add("ZS_ClawAttack", "ZS_Boss", function(ply, special)
	if not ZS_IsBoss(ply) then return end

	ply:SetNWFloat("ZS_GonomeAttack", CurTime())
	ply:SetNWInt("ZS_GonomeAttackSeq", special and 2 or math.random(1, 2))
	ply:EmitSound("vj_hlr/gsrc/npc/gonome/gonome_melee" .. math.random(2) .. ".wav", 85)
end)

-- E+M1: схватить выжившего и разорвать на части (гильотина громилы, sh_zs_bruiser.lua), раз в BossGrabCooldown секунд
local function BossGrab(ply)
	if (ply.zs_NextBossGrab or 0) > CurTime() then return end
	if not ZS_Guillotine or not ZS_Guillotine(ply, {tearAll = true}) then return end

	ply.zs_NextBossGrab = CurTime() + MODE.BossGrabCooldown

	ply:SetNWFloat("ZS_GonomeAttack", CurTime())
	ply:SetNWInt("ZS_GonomeAttackSeq", 2) -- "схватить и сожрать"
	ply:EmitSound("vj_hlr/gsrc/npc/gonome/gonome_melee2.wav", 95)
end

-- E+M2: плевок кислотой (анимация attack3), сгустки парализуют, как "Парализующие наросты"
local function BossSpit(ply)
	if (ply.zs_NextBossSpit or 0) > CurTime() then return end
	ply.zs_NextBossSpit = CurTime() + MODE.BossSpitCooldown

	ply:SetNWFloat("ZS_GonomeAttack", CurTime())
	ply:SetNWInt("ZS_GonomeAttackSeq", 3)
	ply:EmitSound("vj_hlr/gsrc/npc/gonome/gonome_melee1.wav", 95)

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
		boss:EmitSound(soundsIdle[math.random(#soundsIdle)], 90, math.random(95, 105))
	end
end)

hook.Add("PlayerDeath", "ZS_Boss", function(ply)
	if not ZS_IsBoss(ply) then return end

	ply:SetNWBool("ZS_Boss", false)
	ply:EmitSound(soundsDeath[math.random(#soundsDeath)], 100)

	if GetGlobalEntity("ZS_Boss") == ply then SetGlobalEntity("ZS_Boss", NULL) end

	-- предсмертная анимация гонома (cl_zs_boss.lua)
	net.Start("zs_boss_death")
		net.WriteVector(ply:GetPos())
		net.WriteFloat(ply:EyeAngles().y)
	net.Broadcast()
end)

hook.Add("PlayerSpawn", "ZS_Boss", function(ply)
	ply:SetNWBool("ZS_Boss", false)
end)

-- в начале BossWave боссом становится случайный живой зараженный (если живых нет - первый появившийся)
hook.Add("ZS_WaveStart", "ZS_Boss", function(wave)
	local mode = CurrentRound()
	if not mode or mode.name ~= "zs" or wave ~= mode.BossWave or mode.saved.BossDone then return end

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
	if not BossActive() or not mode.saved.BossPending then return end

	timer.Simple(0.5, function()
		if IsValid(ply) and mode.saved.BossPending and ZS_IsZombie(ply) and mode:MakeBoss(ply) then
			mode.saved.BossPending = nil
		end
	end)
end)

-- zb_begonome: моментально стать боссом (админ)
concommand.Add("zb_begonome", function(ply)
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
