local MODE = MODE

-- Эффекты навыков дерева bruiser (описания и цены: MODE.SkillTrees.zs_bruiser в sh_zs.lua)
-- Тупой урон когтей реализован в weapon_hands_sh.lua

local TEAM_SURVIVORS = 0

local function IsLivingZombie(ply)
	return IsValid(ply) and ply:IsPlayer() and ply:Alive() and ZS_IsZombie(ply)
end

local function IsLivingSurvivor(ply)
	return IsValid(ply) and ply:IsPlayer() and ply:Alive() and ply:Team() == TEAM_SURVIVORS
end

-- Импульс массы: продолжительный таран вперед (движение предсказывается на клиенте)
local IMPULSE_TIME, IMPULSE_SPEED, IMPULSE_COOLDOWN = 2.5, 480, 10

hook.Add("Move", "ZS_BruiserMassImpulse", function(ply, mv)
	if ply:GetNWFloat("ZS_ImpulseUntil", 0) < CurTime() or not ply:Alive() or not ZS_IsZombie(ply) then return end
	if ply:GetMoveType() ~= MOVETYPE_WALK or not ply:OnGround() then return end

	local forward = Angle(0, mv:GetAngles().y, 0):Forward()
	local vel = mv:GetVelocity()

	mv:SetVelocity(Vector(forward.x * IMPULSE_SPEED, forward.y * IMPULSE_SPEED, vel.z))
end)

if CLIENT then return end

-- модификаторы от навыков; вызывается при покупке и при каждом спавне зараженного
local function StatsDefaults(ply)
	ply:SetNWBool("ZS_Gray", false)
	ply:SetNWBool("ZS_BigArms", false)
	ply:SetNWBool("ZS_BluntClaws", false)
	ply:SetNWFloat("ZS_ImpulseUntil", 0)

	ply.zs_BulletArmor = nil
end

hook.Add("ZS_ClearSkillEffects", "ZS_BruiserSkills", StatsDefaults)

hook.Add("ZS_ApplySkillEffects", "ZS_BruiserSkills", function(ply)
	if ply.zs_Class ~= "zs_bruiser" then return end

	StatsDefaults(ply)

	local speed, damageTaken, melee, maxHealth = 1, 1, 1, 100

	if ZS_HasSkill(ply, "anabolism") then
		speed = speed * 0.9
		damageTaken = damageTaken * 0.8
		melee = melee * 1.2
	end

	if ZS_HasSkill(ply, "carcinoma") then
		damageTaken = damageTaken * 0.85
		maxHealth = 150
	end

	if ZS_HasSkill(ply, "anabolic_boost") then
		ply:SetNWBool("ZS_BigArms", true)
	end

	if ZS_HasSkill(ply, "fibrodysplasia") then
		speed = speed * 0.85
		melee = melee * 1.5

		ply:SetNWBool("ZS_Gray", true)
		ply:SetNWBool("ZS_BluntClaws", true)

		-- данные бронежилета Kevlar IIIA (vest3)
		ply.zs_BulletArmor = hg.armor and hg.armor.torso and hg.armor.torso.vest3 and hg.armor.torso.vest3.protection or 8
	end

	ply:SetNWFloat("ZS_SpeedMul", speed)
	ply:SetNWFloat("ZS_AttackMul", 1)
	ply.zs_DamageTakenMul = damageTaken
	ply.zs_StaminaMax = nil

	local info = ZS_ZOMBIE_CLASSES[ply.zs_Class]
	ply.MeleeDamageMul = (info and info.meleeMul or 1) * melee

	if ply:Alive() and ZS_IsZombie(ply) then
		ply:SetMaxHealth(maxHealth)
		ply:SetHealth(math.max(ply:Health(), maxHealth))
	end
end)

-- Карцинома: пассивная регенерация
local function HealOrganism(org, amount)
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
end

local nextRegen = 0
hook.Add("Think", "ZS_BruiserCarcinoma", function()
	if nextRegen > CurTime() then return end
	nextRegen = CurTime() + 1

	for _, ply in player.Iterator() do
		if IsLivingZombie(ply) and ZS_HasSkill(ply, "carcinoma") and ply.organism then
			HealOrganism(ply.organism, 1.5)
			ply:SetHealth(math.min(ply:Health() + 2, ply:GetMaxHealth()))
		end
	end
end)

-- Крепкие ноги: hg.Fake (падение в регдолл от урона, взрывов, оглушения) для зомби с навыком не срабатывает.
-- Оборачиваем саму функцию, а не хук, чтобы не зависеть от порядка хуков
local function PatchFake()
	if not hg or not hg.Fake or hg.ZS_OrigFake then return end

	hg.ZS_OrigFake = hg.Fake
	hg.Fake = function(ply, ...)
		if IsValid(ply) and ply:IsPlayer() and ply:Alive() and ZS_HasSkill(ply, "strong_legs") then
			return
		end

		return hg.ZS_OrigFake(ply, ...)
	end
end

-- Фибродисплазия: пули с пробитием не выше защиты Kevlar IIIA не наносят урона.
-- Оборачиваем хук homigrad-damage, чтобы проверка гарантированно шла до расчета урона организма
local function GetBulletPenetration(dmgInfo)
	if not dmgInfo:IsBulletDamage() then return end

	local attacker = dmgInfo:GetAttacker()
	local inf = dmgInfo:GetInflictor()

	if not IsValid(inf) or inf:IsPlayer() then
		inf = IsValid(attacker) and attacker:IsPlayer() and attacker:GetActiveWeapon() or inf
	end

	if not IsValid(inf) then return end
	inf = IsValid(inf.weapon) and inf.weapon or inf

	local bullet = inf.bullet
	return bullet and bullet.Penetration or inf.Penetration
end

local function BulletImmune(ent, dmgInfo)
	local ply = IsValid(ent) and (ent:IsPlayer() and ent or hg.RagdollOwner(ent))
	if not IsLivingZombie(ply) or not ply.zs_BulletArmor then return false end

	local pen = GetBulletPenetration(dmgInfo)
	if not pen or pen > ply.zs_BulletArmor then return false end

	local pos = dmgInfo:GetDamagePosition()
	sound.Play("physics/concrete/concrete_impact_bullet" .. math.random(4) .. ".wav", pos, 70, math.random(90, 110))

	local effect = EffectData()
	effect:SetOrigin(pos)
	effect:SetNormal(-dmgInfo:GetDamageForce():GetNormalized())
	util.Effect("Impact", effect)

	return true
end

local function PatchDamage()
	local hooks = hook.GetTable().EntityTakeDamage
	local orig = hooks and hooks["homigrad-damage"]
	if not orig or hg.ZS_OrigDamageHook == orig or hg.ZS_DamageWrapper == orig then return end

	hg.ZS_OrigDamageHook = orig
	hg.ZS_DamageWrapper = function(ent, dmgInfo)
		if BulletImmune(ent, dmgInfo) then return true end
		return hg.ZS_OrigDamageHook(ent, dmgInfo)
	end

	hook.Add("EntityTakeDamage", "homigrad-damage", hg.ZS_DamageWrapper)
end

PatchFake()
PatchDamage()
hook.Add("InitPostEntity", "ZS_BruiserPatches", function()
	PatchFake()
	PatchDamage()
end)

-- Анаболический форсаж: удары сбивают выживших с ног, сильнее бьют по пропам и рвут скотч
local function IsClawHit(attacker, dmgInfo)
	local inf = dmgInfo:GetInflictor()
	return IsValid(inf) and inf:IsWeapon() and inf:GetClass() == "weapon_hands_sh" and inf:GetOwner() == attacker
end

hook.Add("EntityTakeDamage", "ZS_BruiserAnabolicBoost", function(ent, dmgInfo)
	local attacker = dmgInfo:GetAttacker()
	if not IsLivingZombie(attacker) or not ZS_HasSkill(attacker, "anabolic_boost") then return end
	if not IsClawHit(attacker, dmgInfo) then return end

	local victim = ent:IsPlayer() and ent or hg.RagdollOwner(ent)

	if IsLivingSurvivor(victim) then
		if not IsValid(victim.FakeRagdoll) then
			timer.Simple(0, function()
				if IsLivingSurvivor(victim) and not IsValid(victim.FakeRagdoll) then
					hg.Fake(victim)
				end
			end)
		end

		return
	end

	if ent:IsPlayer() or ent:IsRagdoll() then return end

	-- укрепления: пропы, двери, скотч
	dmgInfo:ScaleDamage(4)

	if ent.DuctTape and next(ent.DuctTape) then
		local key = next(ent.DuctTape)
		local duct = ent.DuctTape[key]

		if IsValid(duct[1]) then duct[1]:Remove() end
		ent.DuctTape[key] = nil

		ent:EmitSound("tapetear.mp3", 75)
	end

	local phys = ent:GetPhysicsObject()
	if IsValid(phys) and phys:IsMotionEnabled() then
		phys:ApplyForceOffset(attacker:GetAimVector() * math.min(phys:GetMass(), 400) * 300, dmgInfo:GetDamagePosition())
	end
end)

-- E+M1: импульс массы, E+M2: гильотина
local GUILLOTINE_RANGE = 60
local guillotineLimbs = {"lleg", "rleg", "larm", "rarm", "head"}

local function MassImpulse(ply)
	if (ply.zs_NextImpulse or 0) > CurTime() then return end
	ply.zs_NextImpulse = CurTime() + IMPULSE_COOLDOWN

	ply:SetNWFloat("ZS_ImpulseUntil", CurTime() + IMPULSE_TIME)
	ply.zs_ImpulseHit = {}

	ply:EmitSound("npc/zombie_poison/pz_alert" .. math.random(2) .. ".wav", 85, math.random(90, 100))
end

-- удар о стену на скорости: каменная крошка, вмятина и толчок вокруг, как у берсерка (fury13, sv_util.lua)
local function ImpulseWallHit(ply, tr, speed)
	ply:SetNWFloat("ZS_ImpulseUntil", 0)

	local effect = EffectData()
	effect:SetStart(tr.HitPos)
	effect:SetMagnitude(speed / 200)
	effect:SetNormal(tr.HitNormal)
	util.Effect("zippy_impact_concrete", effect)

	for _, ent in ipairs(ents.FindInSphere(tr.HitPos, speed / 7)) do
		if ent == ply then continue end

		if ent:IsPlayer() and ent:IsOnGround() then
			ent:SetVelocity(tr.HitNormal * speed / 5)
			ent:SetGroundEntity(NULL)
		end

		local phys = ent:GetPhysicsObject()
		if IsValid(phys) then
			phys:AddVelocity(tr.HitNormal * speed * 2 / 5)
			phys:Wake()
		end
	end

	ply:EmitSound("physics/concrete/boulder_impact_hard" .. math.random(4) .. ".wav", 85)
	util.Decal("Rollermine.Crater", tr.HitPos + tr.HitNormal, tr.HitPos - tr.HitNormal, ply)
	util.ScreenShake(tr.HitPos, 8, 40, 0.6, 400)
end

-- пропы и двери на пути импульса сносятся
local IMPULSE_PROP_DAMAGE, IMPULSE_PROP_PUSH = 150, 700

local function ImpulseSmash(ply, ent, forward)
	if hgIsDoor and hgIsDoor(ent) then
		if hgBlastThatDoor then hgBlastThatDoor(ent, forward * 600 + ply:GetVelocity()) end
		ent:EmitSound("physics/wood/wood_crate_break" .. math.random(5) .. ".wav", 85)
		return
	end

	if not string.StartWith(ent:GetClass(), "prop_physics") and not string.StartWith(ent:GetClass(), "func_breakable") then return end

	local dmg = DamageInfo()
	dmg:SetAttacker(ply)
	dmg:SetInflictor(ply)
	dmg:SetDamage(IMPULSE_PROP_DAMAGE)
	dmg:SetDamageType(DMG_CLUB)
	dmg:SetDamageForce(forward * 5000)
	dmg:SetDamagePosition(ent:WorldSpaceCenter())
	ent:TakeDamageInfo(dmg)

	if not IsValid(ent) then return end

	local phys = ent:GetPhysicsObject()
	if IsValid(phys) and phys:IsMotionEnabled() then
		phys:AddVelocity(forward * IMPULSE_PROP_PUSH + Vector(0, 0, 150))
		phys:Wake()
	end

	ent:EmitSound("physics/wood/wood_plank_impact_hard" .. math.random(5) .. ".wav", 80)
end

local function ImpulseThink(ply)
	if ply:GetNWFloat("ZS_ImpulseUntil", 0) < CurTime() then return end

	local center = ply:GetPos() + ply:OBBCenter()
	local forward = Angle(0, ply:EyeAngles().y, 0):Forward()

	for _, ent in ipairs(ents.FindInSphere(center + forward * 32, 48)) do
		if ent == ply or ent:IsPlayer() or ent:IsNPC() or ent:IsRagdoll() or ply.zs_ImpulseHit[ent] then continue end

		ply.zs_ImpulseHit[ent] = true
		ImpulseSmash(ply, ent, forward)
	end

	local speed = ply:GetVelocity():Length2D()
	if speed > 300 then
		local tr = util.TraceLine({
			start = center,
			endpos = center + forward * 40,
			mask = MASK_SOLID_BRUSHONLY,
			filter = ply,
		})

		if tr.HitWorld and not tr.HitSky and tr.HitNormal.z < 0.5 then
			ImpulseWallHit(ply, tr, speed)
			return
		end
	end

	for _, victim in ipairs(ents.FindInSphere(center + forward * 20, 48)) do
		if not IsLivingSurvivor(victim) or ply.zs_ImpulseHit[victim] or IsValid(victim.FakeRagdoll) then continue end

		ply.zs_ImpulseHit[victim] = true

		local dmg = DamageInfo()
		dmg:SetAttacker(ply)
		dmg:SetInflictor(ply)
		dmg:SetDamage(15)
		dmg:SetDamageType(DMG_CLUB)
		dmg:SetDamageForce(forward * 3000)
		dmg:SetDamagePosition(victim:GetPos() + victim:OBBCenter())
		victim:TakeDamageInfo(dmg)

		hg.Fake(victim)

		local ragdoll = victim.FakeRagdoll
		if IsValid(ragdoll) then
			for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
				local phys = ragdoll:GetPhysicsObjectNum(i)
				if IsValid(phys) then phys:AddVelocity(forward * 450 + Vector(0, 0, 150)) end
			end
		end

		victim:EmitSound("physics/body/body_medium_impact_hard" .. math.random(6) .. ".wav", 80)
	end
end

-- Травматическая пощечина: удар отбрасывает выжившего в сторону и роняет его в регдолл
local SLAP_RANGE, SLAP_COOLDOWN, SLAP_FORCE = 70, 6, 650

local function TraumaticSlap(ply)
	if (ply.zs_NextSlap or 0) > CurTime() then return end

	local eye = ply:EyePos()

	ply:LagCompensation(true)
	local tr = util.TraceHull({
		start = eye,
		endpos = eye + ply:GetAimVector() * SLAP_RANGE,
		mins = Vector(-10, -10, -10),
		maxs = Vector(10, 10, 10),
		filter = {ply, ply.FakeRagdoll},
		mask = MASK_SHOT,
	})
	ply:LagCompensation(false)

	local ent = tr.Entity
	local victim = IsValid(ent) and (ent:IsPlayer() and ent or hg.RagdollOwner(ent))
	if not IsLivingSurvivor(victim) then return end

	ply.zs_NextSlap = CurTime() + SLAP_COOLDOWN

	-- в сторону: вправо или влево от зараженного, немного вперед и вверх
	local side = ply:GetRight() * (math.random(2) == 1 and 1 or -1)
	local push = side * SLAP_FORCE + ply:GetForward() * 150 + Vector(0, 0, 220)

	local dmg = DamageInfo()
	dmg:SetAttacker(ply)
	dmg:SetInflictor(ply)
	dmg:SetDamage(10)
	dmg:SetDamageType(DMG_CLUB)
	dmg:SetDamageForce(push * 10)
	dmg:SetDamagePosition(tr.HitPos)
	victim:TakeDamageInfo(dmg)

	if not IsValid(victim.FakeRagdoll) then hg.Fake(victim) end

	local ragdoll = victim.FakeRagdoll
	if IsValid(ragdoll) then
		for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
			local phys = ragdoll:GetPhysicsObjectNum(i)
			if IsValid(phys) then phys:AddVelocity(push) end
		end
	else
		victim:SetVelocity(push)
	end

	ply:EmitSound("npc/zombie/claw_strike" .. math.random(3) .. ".wav", 85, math.random(80, 90))
	victim:EmitSound("physics/body/body_medium_impact_hard" .. math.random(6) .. ".wav", 80)
	ply:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_GMOD_GESTURE_RANGE_ZOMBIE, true)
end

local function Guillotine(ply)
	if ply.zs_GuillotineUsed then return end

	local eye = ply:EyePos()

	ply:LagCompensation(true)
	local tr = util.TraceHull({
		start = eye,
		endpos = eye + ply:GetAimVector() * GUILLOTINE_RANGE,
		mins = Vector(-8, -8, -8),
		maxs = Vector(8, 8, 8),
		filter = {ply, ply.FakeRagdoll},
		mask = MASK_SHOT,
	})
	ply:LagCompensation(false)

	local ent = tr.Entity
	local victim = IsValid(ent) and (ent:IsPlayer() and ent or hg.RagdollOwner(ent))
	if not IsLivingSurvivor(victim) or not victim.organism then return end

	local org = victim.organism
	local available = {}

	for _, limb in ipairs(guillotineLimbs) do
		if not org[limb .. "amputated"] then available[#available + 1] = limb end
	end

	if #available == 0 then return end

	ply.zs_GuillotineUsed = true

	local limb = available[math.random(#available)]

	if limb == "head" then
		hg.ExplodeHead(hg.GetCurrentCharacter(victim))
	else
		hg.organism.AmputateLimb(org, limb)
	end

	ply:EmitSound("npc/zombie_poison/pz_throw" .. math.random(2, 3) .. ".wav", 85)
	ply:EmitSound("physics/flesh/flesh_bloody_break.wav", 80, math.random(90, 110))
end

hook.Add("KeyPress", "ZS_BruiserAbilities", function(ply, key)
	if not ply:KeyDown(IN_USE) then return end
	if zb.ROUND_STATE ~= 1 or not IsLivingZombie(ply) or IsValid(ply.FakeRagdoll) then return end

	if key == IN_ATTACK and ZS_HasSkill(ply, "mass_impulse") then
		MassImpulse(ply)
	elseif key == IN_ATTACK and ZS_HasSkill(ply, "traumatic_slap") then
		TraumaticSlap(ply)
	elseif key == IN_ATTACK2 and ZS_HasSkill(ply, "guillotine") then
		Guillotine(ply)
	end
end)

-- гильотина работает один раз за жизнь
hook.Add("PlayerSpawn", "ZS_BruiserGuillotineReset", function(ply)
	ply.zs_GuillotineUsed = nil
	ply:SetNWFloat("ZS_ImpulseUntil", 0)
end)

local nextAbilityThink = 0
hook.Add("Think", "ZS_BruiserAbilitiesThink", function()
	if nextAbilityThink > CurTime() then return end
	nextAbilityThink = CurTime() + 0.05

	for _, ply in player.Iterator() do
		if IsLivingZombie(ply) and ply.zs_ImpulseHit then
			ImpulseThink(ply)
		end
	end
end)

-- броня фибродисплазии не должна доставаться выжившим: у зомби нет настоящего бронежилета,
-- защита считается по данным vest3 (см. BulletImmune)
