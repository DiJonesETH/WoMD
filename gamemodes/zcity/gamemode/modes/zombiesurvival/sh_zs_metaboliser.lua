local MODE = MODE

-- Эффекты навыков дерева metaboliser (описания и цены: MODE.SkillTrees.zs_metaboliser в sh_zs.lua)
-- Сущности: lua/entities/zs_acid_glob.lua, zs_nest.lua, zs_blister.lua

local TEAM_SURVIVORS = 0
local MARK_TIME = 5

local function IsLivingSurvivor(ply)
	return IsValid(ply) and ply:IsPlayer() and ply:Alive() and ply:Team() == TEAM_SURVIVORS
end

if CLIENT then
	-- Стадные феромоны: отмеченный ударом выживший виден зараженным сквозь стены
	local markMat = Material("models/debug/debugwhite")

	hook.Add("PostDrawTranslucentRenderables", "ZS_PheromoneMarks", function(depth, skybox)
		if skybox or not IsValid(lply) then return end
		if lply:Team() == TEAM_SURVIVORS or lply:Team() == TEAM_SPECTATOR then return end

		local marked
		for _, ply in player.Iterator() do
			if ply:GetNWFloat("ZS_MarkedUntil", 0) > CurTime() and IsLivingSurvivor(ply) then
				marked = marked or {}
				marked[#marked + 1] = hg.GetCurrentCharacter(ply)
			end
		end

		if not marked then return end

		cam.IgnoreZ(true)
		render.MaterialOverride(markMat)
		render.SetColorModulation(0.3, 1, 0.3)
		render.SetBlend(0.6)

		for _, ent in ipairs(marked) do
			if IsValid(ent) then ent:DrawModel() end
		end

		render.SetBlend(1)
		render.SetColorModulation(1, 1, 1)
		render.MaterialOverride()
		cam.IgnoreZ(false)
	end)

	return
end

local function IsLivingZombie(ply)
	return IsValid(ply) and ply:IsPlayer() and ply:Alive() and ZS_IsZombie(ply)
end

local function IsMetaboliser(ply)
	return IsLivingZombie(ply) and ply.PlayerClassName == "zs_metaboliser"
end

-- лечение организма как регенерация карциномы у bruiser
function ZS_HealOrganism(ply, amount)
	local org = ply.organism
	if not org then return end

	org.blood = math.Approach(org.blood, 5000, amount * 60)
	org.pain = math.max((org.pain or 0) - amount * 2, 0)
	org.internalBleed = math.max((org.internalBleed or 0) - amount * 0.6, 0)

	for _, wound in pairs(org.wounds or {}) do
		wound[1] = math.max(wound[1] - amount * 0.6, 0)
	end

	for _, wound in pairs(org.arterialwounds or {}) do
		wound[1] = math.max(wound[1] - amount * 0.6, 0)
	end

	local regen = amount / 60
	for _, key in ipairs({"lleg", "rleg", "larm", "rarm", "chest", "pelvis", "liver", "stomach", "intestines", "heart"}) do
		if isnumber(org[key]) then org[key] = math.max(org[key] - regen, 0) end
	end

	ply:SetHealth(math.min(ply:Health() + amount, ply:GetMaxHealth()))
end

-- кислота: сгустки zs_acid_glob
function ZS_SpawnAcidGlob(owner, pos, vel)
	local glob = ents.Create("zs_acid_glob")
	if not IsValid(glob) then return end

	glob:SetPos(pos)
	glob:SetOwner(IsValid(owner) and owner:IsPlayer() and owner or NULL)
	glob:Spawn()

	local phys = glob:GetPhysicsObject()
	if IsValid(phys) then phys:SetVelocity(vel) end

	return glob
end

function ZS_SpawnAcidBurst(owner, pos, count, speed)
	for i = 1, count do
		local dir = Angle(math.Rand(-60, -10), (360 / count) * i + math.Rand(-10, 10), 0):Forward()
		ZS_SpawnAcidGlob(owner, pos, dir * speed * math.Rand(0.6, 1.2))
	end
end

local function Notify(ply, text)
	if ply.Notify then ply:Notify(text, 0, "zs_metaboliser", 4) else ply:ChatPrint(text) end
end

-- модификаторы: питательная среда снижает здоровье и урон
local function StatsDefaults(ply)
	ply:SetNWBool("ZS_Green", false)
end

hook.Add("ZS_ClearSkillEffects", "ZS_MetaboliserSkills", StatsDefaults)

hook.Add("ZS_ApplySkillEffects", "ZS_MetaboliserSkills", function(ply)
	if ply.zs_Class ~= "zs_metaboliser" then return end

	local damageTaken, melee, maxHealth = 1, 1, 100

	if ZS_HasSkill(ply, "nutrient_medium") then
		damageTaken = 1.35
		melee = 0.7
		maxHealth = 70
	end

	ply:SetNWFloat("ZS_SpeedMul", 1)
	ply:SetNWFloat("ZS_AttackMul", 1)
	ply:SetNWBool("ZS_Green", ZS_HasSkill(ply, "herd_pheromones"))
	ply.zs_DamageTakenMul = damageTaken
	ply.zs_StaminaMax = nil

	local info = ZS_ZOMBIE_CLASSES[ply.zs_Class]
	ply.MeleeDamageMul = (info and info.meleeMul or 1) * melee

	if ply:Alive() and ZS_IsZombie(ply) then
		ply:SetMaxHealth(maxHealth)
		ply:SetHealth(math.min(ply:Health(), maxHealth))
	end
end)

-- одноразовые способности: за жизнь и за раунд
hook.Add("PlayerSpawn", "ZS_MetaboliserLifeReset", function(ply)
	ply.zs_NutrientUsed = nil
	ply.zs_SpikeUsed = nil
end)

-- гнездо и волдырь доступны заново в каждой волне
hook.Add("ZS_WaveStart", "ZS_MetaboliserWaveReset", function()
	for _, ply in player.Iterator() do
		ply.zs_NestUsed = nil
		ply.zs_BlisterUsed = nil
	end
end)

hook.Add("ZS_RoundReset", "ZS_MetaboliserRoundReset", function(ply)
	ply.zs_NestUsed = nil
	ply.zs_BlisterUsed = nil
	ply.zs_CoughUntil = nil
	ply:SetNWFloat("ZS_MarkedUntil", 0)
end)

-- NPC-зомби без хедкрабов, союзные зараженным
local npcs = {}

local function UpdateNPCRelations(npc)
	for _, ply in player.Iterator() do
		npc:AddEntityRelationship(ply, IsLivingSurvivor(ply) and D_HT or D_LI, 99)
	end
end

local function SpawnZombieNPC(class, pos, owner)
	local npc = ents.Create(class)
	if not IsValid(npc) then return end

	npc:SetPos(pos)
	npc:SetAngles(Angle(0, math.Rand(0, 360), 0))
	npc:Spawn()
	npc:Activate()

	-- без хедкраба: и визуально, и при смерти он не выпрыгивает
	npc:SetSaveValue("m_fIsHeadless", true)
	for i = 1, npc:GetNumBodyGroups() - 1 do
		npc:SetBodygroup(i, 0)
	end

	npc.zs_Owner = owner
	npcs[npc] = true
	UpdateNPCRelations(npc)

	return npc
end

local function FindSpawnSpot(ply, dist)
	for _ = 1, 8 do
		local dir = Angle(0, ply:EyeAngles().y + math.Rand(-70, 70), 0):Forward()
		local start = ply:GetPos() + Vector(0, 0, 40)

		local tr = util.TraceHull({
			start = start,
			endpos = start + dir * dist,
			mins = Vector(-16, -16, 0),
			maxs = Vector(16, 16, 64),
			filter = ply,
			mask = MASK_NPCSOLID,
		})

		if not tr.StartSolid and tr.Fraction > 0.5 then
			local down = util.TraceLine({start = tr.HitPos, endpos = tr.HitPos - Vector(0, 0, 200), mask = MASK_NPCSOLID_BRUSHONLY})
			return down.HitPos + Vector(0, 0, 2)
		end
	end

	return ply:GetPos() + ply:GetForward() * 40
end

local nextRelations = 0
hook.Add("Think", "ZS_MetaboliserNPCs", function()
	if nextRelations > CurTime() then return end
	nextRelations = CurTime() + 1

	for npc in pairs(npcs) do
		if IsValid(npc) then UpdateNPCRelations(npc) else npcs[npc] = nil end
	end
end)

-- Баллистические наросты: шип с уроном и пробитием 9x19 Parabellum
local SPIKE_DAMAGE, SPIKE_PENETRATION, SPIKE_RANGE = 25, 3.8, 3000

do
	local ammo = hg.ammotypes and hg.ammotypes["9x19mmparabellum"]
	local bullet = ammo and ammo.BulletSettings
	if bullet then
		SPIKE_DAMAGE = bullet.Damage or SPIKE_DAMAGE
		SPIKE_PENETRATION = bullet.Penetration or SPIKE_PENETRATION
	end
end

-- Парализующие наросты (улучшение баллистических наростов): через PARALYZE_DELAY секунд после попадания шипа
-- выживший падает в регдолл с парализованными мышцами (все кости регдолла сварены между собой) на PARALYZE_TIME секунд
local PARALYZE_DELAY, PARALYZE_TIME = 2, 7

local function Unparalyze(victim)
	if not IsValid(victim) then return end

	for _, cons in ipairs(victim.zs_ParalyzeWelds or {}) do
		if IsValid(cons) then cons:Remove() end
	end

	victim.zs_ParalyzeWelds = nil
	victim.zs_ParalyzedUntil = nil
end

local function Petrify(victim)
	if not IsLivingSurvivor(victim) then return end

	if not IsValid(victim.FakeRagdoll) then hg.Fake(victim) end

	local ragdoll = victim.FakeRagdoll
	if not IsValid(ragdoll) then return end

	Unparalyze(victim)

	local welds = {}
	for i = 1, ragdoll:GetPhysicsObjectCount() - 1 do
		local cons = constraint.Weld(ragdoll, ragdoll, 0, i, 0, false, false)
		if IsValid(cons) then welds[#welds + 1] = cons end
	end

	victim.zs_ParalyzeWelds = welds
	victim.zs_ParalyzedUntil = CurTime() + PARALYZE_TIME

	timer.Create("ZS_Paralyze" .. victim:EntIndex(), PARALYZE_TIME, 1, function()
		Unparalyze(victim)
	end)
end

-- паралич выжившего через PARALYZE_DELAY секунд (также кислота босса-гонома, zs_acid_glob.zs_Paralyze)
function ZS_ParalyzeSurvivor(victim)
	if not IsLivingSurvivor(victim) or victim.zs_ParalyzePending then return end
	victim.zs_ParalyzePending = true

	victim:EmitSound("npc/barnacle/barnacle_digesting" .. math.random(2) .. ".wav", 65, 140)

	timer.Simple(PARALYZE_DELAY, function()
		if not IsValid(victim) then return end
		victim.zs_ParalyzePending = nil
		Petrify(victim)
	end)
end

local function ParalyzeHit(ply, ent)
	local victim = IsValid(ent) and (ent:IsPlayer() and ent or hg.RagdollOwner(ent))
	if not ZS_HasSkill(ply, "paralyzing_growths") then return end

	ZS_ParalyzeSurvivor(victim)
end

-- парализованный не может встать
hook.Add("Should Fake Up", "ZS_ParalyzingGrowths", function(ply)
	if (ply.zs_ParalyzedUntil or 0) > CurTime() then return false end
end)

hook.Add("PlayerDeath", "ZS_ParalyzingGrowths", Unparalyze)
hook.Add("PlayerSpawn", "ZS_ParalyzingGrowths", Unparalyze)

local function FireSpike(ply)
	if ply.zs_SpikeUsed then return end
	ply.zs_SpikeUsed = true

	local eye = ply:EyePos()
	local aim = ply:GetAimVector()

	ply:LagCompensation(true)
	local tr = util.TraceLine({
		start = eye,
		endpos = eye + aim * SPIKE_RANGE,
		filter = {ply, ply.FakeRagdoll},
		mask = MASK_SHOT,
	})
	ply:LagCompensation(false)

	local effect = EffectData()
	effect:SetStart(eye + aim * 10)
	effect:SetOrigin(tr.HitPos)
	effect:SetScale(4000)
	util.Effect("Tracer", effect)

	ply:EmitSound("npc/zombie_poison/pz_throw2.wav", 80, 130)
	sound.Play("weapons/crossbow/hitbod" .. math.random(2) .. ".wav", tr.HitPos, 70)

	local ent = tr.Entity
	if not IsValid(ent) then
		util.Decal("YellowBlood", tr.HitPos + tr.HitNormal, tr.HitPos - tr.HitNormal)
		return
	end

	local dmg = DamageInfo()
	dmg:SetAttacker(ply)
	dmg:SetInflictor(IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon() or ply)
	dmg:SetDamage(SPIKE_DAMAGE)
	dmg:SetDamageType(DMG_BULLET)
	dmg:SetDamageForce(aim * 300)
	dmg:SetDamagePosition(tr.HitPos)

	PenetrationGlobal = SPIKE_PENETRATION
	ent:TakeDamageInfo(dmg)
	PenetrationGlobal = nil

	ParalyzeHit(ply, ent)
end

-- Рефлюкс: 2 секунды струи кислоты
local REFLUX_TIME, REFLUX_INTERVAL, REFLUX_COOLDOWN, REFLUX_SPEED = 2, 0.08, 12, 750

local function Reflux(ply)
	if (ply.zs_NextReflux or 0) > CurTime() then return end
	ply.zs_NextReflux = CurTime() + REFLUX_COOLDOWN

	ply:EmitSound("npc/zombie_poison/pz_throw3.wav", 80, 90)

	local name = "ZS_Reflux_" .. ply:EntIndex()
	timer.Create(name, REFLUX_INTERVAL, math.floor(REFLUX_TIME / REFLUX_INTERVAL), function()
		if not IsMetaboliser(ply) then timer.Remove(name) return end

		local aim = ply:GetAimVector()
		local spread = VectorRand() * 0.06
		local pos = ply:EyePos() + aim * 16 - Vector(0, 0, 6)

		ZS_SpawnAcidGlob(ply, pos, (aim + spread) * REFLUX_SPEED + ply:GetVelocity() * 0.5)

		if math.random(3) == 1 then
			ply:EmitSound("physics/flesh/flesh_squishy_impact_hard" .. math.random(4) .. ".wav", 65, math.random(130, 150))
		end
	end)
end

-- Метановая избыточность: после смерти тело взрывается, обливая кислотой всех в радиусе 5 метров
local METHANE_RADIUS, METHANE_DAMAGE = 262, 20

local function MethaneExplode(ply, pos)
	for _, victim in player.Iterator() do
		if not IsLivingSurvivor(victim) or victim:GetPos():Distance(pos) > METHANE_RADIUS then continue end

		local dmg = DamageInfo()
		dmg:SetAttacker(ply)
		dmg:SetInflictor(ply)
		dmg:SetDamage(METHANE_DAMAGE)
		dmg:SetDamageType(DMG_BURN)
		dmg:SetDamagePosition(victim:GetPos() + victim:OBBCenter())
		hg.GetCurrentCharacter(victim):TakeDamageInfo(dmg)
	end

	-- плотный выброс кислоты: три кольца с разной дальностью
	ZS_SpawnAcidBurst(ply, pos, 30, 520)
	ZS_SpawnAcidBurst(ply, pos, 24, 360)
	ZS_SpawnAcidBurst(ply, pos, 18, 200)

	sound.Play("physics/flesh/flesh_bloody_break.wav", pos, 90, 80)
	sound.Play("npc/antlion_grub/squashed.wav", pos, 85, 90)

	local effect = EffectData()
	effect:SetOrigin(pos)
	effect:SetColor(BLOOD_COLOR_YELLOW)
	util.Effect("BloodImpact", effect)
end

hook.Add("PlayerDeath", "ZS_MetaboliserMethane", function(ply)
	if zb.ROUND_STATE ~= 1 then return end
	if ply.PlayerClassName ~= "zs_metaboliser" or not ZS_HasSkill(ply, "methane") then return end

	local fallback = ply:GetPos() + ply:OBBCenter()

	-- взрыв в точке трупа (регдолл создается в момент смерти)
	timer.Simple(0, function()
		if not IsValid(ply) then return end

		local ragdoll = IsValid(ply.RagdollDeath) and ply.RagdollDeath or ply:GetNWEntity("RagdollDeath")
		local pos = IsValid(ragdoll) and ragdoll:WorldSpaceCenter() or fallback

		MethaneExplode(ply, pos)
	end)
end)

-- Гнездо и мясной мицелий: точка на земле перед игроком
local function GroundSpot(ply, dist)
	local eye = ply:EyePos()

	local tr = util.TraceLine({start = eye, endpos = eye + ply:GetAimVector() * dist, filter = {ply, ply.FakeRagdoll}, mask = MASK_SOLID_BRUSHONLY})
	local down = util.TraceLine({start = tr.HitPos - ply:GetAimVector() * 16, endpos = tr.HitPos - Vector(0, 0, 200), mask = MASK_SOLID_BRUSHONLY})

	if down.Hit and down.HitNormal.z > 0.6 then
		return down.HitPos
	end
end

local function BuildNest(ply)
	if ply.zs_NestUsed then
		ZS_NotifyOnce(ply, "nest_used", "You can build a nest only once per wave")
		return
	end

	local pos = GroundSpot(ply, 120)
	if not pos then
		Notify(ply, "You can't build a nest here")
		return
	end

	ply.zs_NestUsed = true

	local nest = ents.Create("zs_nest")
	nest:SetPos(pos + Vector(0, 0, nest.HalfHeight - 4))
	nest:SetOwner(ply)
	nest:Spawn()

	nest:EmitSound("physics/flesh/flesh_bloody_break.wav", 75, 70)
	Notify(ply, "Nest built")
end

local function PlaceBlister(ply)
	if ply.zs_BlisterUsed then
		ZS_NotifyOnce(ply, "blister_used", "You can grow a blister only once per wave")
		return
	end

	local pos = GroundSpot(ply, 100)
	if not pos then
		Notify(ply, "You can't grow a blister here")
		return
	end

	ply.zs_BlisterUsed = true

	local blister = ents.Create("zs_blister")
	blister:SetPos(pos)
	blister:SetOwner(ply)
	blister:Spawn()

	blister:EmitSound("physics/flesh/flesh_squishy_impact_hard" .. math.random(4) .. ".wav", 70, 80)
end

-- Бактериальный посев: R на союзника - лечение в течение 15 секунд
local SEED_TIME, SEED_COOLDOWN, SEED_RANGE = 15, 20, 120
local seeded = {}

local function BacterialSeeding(ply)
	if (ply.zs_NextSeed or 0) > CurTime() then return end

	local eye = ply:EyePos()
	local tr = util.TraceHull({
		start = eye,
		endpos = eye + ply:GetAimVector() * SEED_RANGE,
		mins = Vector(-8, -8, -8),
		maxs = Vector(8, 8, 8),
		filter = {ply, ply.FakeRagdoll},
		mask = MASK_SHOT,
	})

	local ent = tr.Entity
	local ally = IsValid(ent) and (ent:IsPlayer() and ent or hg.RagdollOwner(ent))
	if not IsLivingZombie(ally) then return end

	ply.zs_NextSeed = CurTime() + SEED_COOLDOWN
	seeded[ally] = CurTime() + SEED_TIME

	ply:EmitSound("npc/barnacle/barnacle_gulp" .. math.random(2) .. ".wav", 70)
	Notify(ply, "Seeding: your ally heals for " .. SEED_TIME .. " sec.")
end

-- Питательная среда и стадные феромоны (CTRL+R)
-- CTRL+R раз за жизнь: один обычный зомби, а со стадными феромонами вместо него три быстрых
local function SpawnNutrientNPC(ply)
	if ply.zs_NutrientUsed then return end
	ply.zs_NutrientUsed = true

	if ZS_HasSkill(ply, "herd_pheromones") then
		for _ = 1, 3 do
			if not IsValid(SpawnZombieNPC("npc_fastzombie", FindSpawnSpot(ply, 100), ply)) then
				SpawnZombieNPC("npc_zombie", FindSpawnSpot(ply, 100), ply)
			end
		end

		ply:EmitSound("npc/fast_zombie/fz_scream1.wav", 85)
	else
		SpawnZombieNPC("npc_zombie", FindSpawnSpot(ply, 80), ply)
		ply:EmitSound("npc/zombie/zombie_alert" .. math.random(3) .. ".wav", 80)
	end
end

hook.Add("KeyPress", "ZS_MetaboliserAbilities", function(ply, key)
	if zb.ROUND_STATE ~= 1 or not IsMetaboliser(ply) or IsValid(ply.FakeRagdoll) then return end

	if key == IN_RELOAD then
		if ply:KeyDown(IN_DUCK) then
			if ZS_HasSkill(ply, "nutrient_medium") then SpawnNutrientNPC(ply) end
		elseif ZS_HasSkill(ply, "bacterial_seeding") then
			BacterialSeeding(ply)
		end

		return
	end

	if not ply:KeyDown(IN_USE) then return end

	if key == IN_ATTACK then
		if ZS_HasSkill(ply, "ballistic_growths") then
			FireSpike(ply)
		elseif ZS_HasSkill(ply, "nest") then
			BuildNest(ply)
		end
	elseif key == IN_ATTACK2 then
		if ZS_HasSkill(ply, "reflux") then
			Reflux(ply)
		elseif ZS_HasSkill(ply, "meat_mycelium") then
			PlaceBlister(ply)
		end
	end
end)

-- Стадные феромоны: удар когтями ставит метку на выжившего
hook.Add("HomigradDamage", "ZS_MetaboliserPheromoneMark", function(ent, dmgInfo)
	local attacker = dmgInfo:GetAttacker()
	if not IsMetaboliser(attacker) or not ZS_HasSkill(attacker, "herd_pheromones") then return end

	local victim = IsValid(ent) and (ent:IsPlayer() and ent or hg.RagdollOwner(ent))
	if IsLivingSurvivor(victim) then
		victim:SetNWFloat("ZS_MarkedUntil", CurTime() + MARK_TIME)
	end
end)

-- лечение посевом и кашель от взрыва волдыря
local nextTick = 0
hook.Add("Think", "ZS_MetaboliserTick", function()
	if nextTick > CurTime() then return end
	nextTick = CurTime() + 1

	for ally, untilTime in pairs(seeded) do
		if not IsLivingZombie(ally) or untilTime < CurTime() then
			seeded[ally] = nil
		else
			ZS_HealOrganism(ally, 1.5)
		end
	end

	for _, ply in player.Iterator() do
		if not ply.zs_CoughUntil then continue end

		if ply.zs_CoughUntil < CurTime() or not ply:Alive() then
			ply.zs_CoughUntil = nil
			continue
		end

		if (ply.zs_NextCough or 0) > CurTime() then continue end
		ply.zs_NextCough = CurTime() + math.Rand(2, 4)

		local female = ThatPlyIsFemale and ThatPlyIsFemale(ply)
		ply:EmitSound((female and "zcitysnd/female/cough_" or "zcitysnd/male/cough_") .. math.random(1, 6) .. ".mp3", 75)
		ply:ViewPunch(Angle(4, math.Rand(-1, 1), 0))

		if ply.organism and ply.organism.o2 then
			ply.organism.o2[1] = math.max(ply.organism.o2[1] - 2, 0)
		end
	end
end)
