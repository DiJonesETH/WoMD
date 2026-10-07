local MODE = MODE

-- Эффекты навыков дерева agile (описания и цены: MODE.SkillTrees.zs_agile в sh_zs.lua)

local TEAM_SURVIVORS = 0

local DEFAULT_HULL_MINS, DEFAULT_HULL_MAXS = Vector(-10, -10, 0), Vector(10, 10, 72)
local DEFAULT_DUCK_MINS, DEFAULT_DUCK_MAXS = Vector(-10, -10, 0), Vector(10, 10, 36)
local DEFAULT_VIEW, DEFAULT_VIEW_DUCKED = Vector(0, 0, 64), Vector(0, 0, 38)
local AUTOLYSIS_SCALE = 0.5

local function IsLivingZombie(ply)
	return IsValid(ply) and ply:IsPlayer() and ply:Alive() and ZS_IsZombie(ply)
end

local function IsLivingSurvivor(ply)
	return IsValid(ply) and ply:IsPlayer() and ply:Alive() and ply:Team() == TEAM_SURVIVORS
end

-- Автолиз: уменьшение модели и хитбокса. Хитбокс не синхронизируется по сети, поэтому выставляется в обоих реалмах
local function SetSmall(ply, small)
	local scale = small and AUTOLYSIS_SCALE or 1

	ply:SetModelScale(scale, 0)
	ply:SetHull(DEFAULT_HULL_MINS * scale, DEFAULT_HULL_MAXS * scale)
	ply:SetHullDuck(DEFAULT_DUCK_MINS * scale, DEFAULT_DUCK_MAXS * scale)
	ply:SetViewOffset(DEFAULT_VIEW * scale)
	ply:SetViewOffsetDucked(DEFAULT_VIEW_DUCKED * scale)

	ply.zs_Small = small or nil
end

local nextSizeCheck = 0
hook.Add("Think", "ZS_AgileAutolysisSize", function()
	if nextSizeCheck > CurTime() then return end
	nextSizeCheck = CurTime() + 0.25

	for _, ply in player.Iterator() do
		local wantSmall = IsLivingZombie(ply) and ZS_HasSkill(ply, "autolysis")

		if wantSmall then
			-- homigrad возвращает стандартный хитбокс при спавне и вставании, поэтому проверяем постоянно
			if not ply.zs_Small or ply:GetViewOffset().z > DEFAULT_VIEW.z * AUTOLYSIS_SCALE + 1 then
				SetSmall(ply, true)
			end
		elseif ply.zs_Small then
			SetSmall(ply, false)
		end
	end
end)

-- Стопные наросты (бесшумные шаги) обрабатываются в HG_PlayerFootstep в sh_zs_zombie.lua

-- Цепкие когти: у стены в воздухе прыжок - лезть вверх, присед - зависнуть
local CLIMB_SPEED = 190

hook.Add("Move", "ZS_AgileClingingClaws", function(ply, mv)
	if not ZS_HasSkill(ply, "clinging_claws") or not ply:Alive() or not ZS_IsZombie(ply) then return end
	if ply:OnGround() or ply:GetMoveType() ~= MOVETYPE_WALK or IsValid(ply.FakeRagdoll) then return end

	local climb, hang = mv:KeyDown(IN_JUMP), mv:KeyDown(IN_DUCK)
	if not climb and not hang then return end

	local scale = ply:GetModelScale()
	local forward = Angle(0, mv:GetAngles().y, 0):Forward()
	local start = mv:GetOrigin() + Vector(0, 0, 36 * scale)

	local tr = util.TraceHull({
		start = start,
		endpos = start + forward * 24 * scale,
		mins = Vector(-6, -6, -6) * scale,
		maxs = Vector(6, 6, 6) * scale,
		filter = ply,
		mask = MASK_PLAYERSOLID,
	})

	if not tr.Hit or (IsValid(tr.Entity) and tr.Entity:IsPlayer()) then return end

	local vel = mv:GetVelocity()

	if climb then
		vel = Vector(vel.x * 0.3, vel.y * 0.3, CLIMB_SPEED)
	else
		-- компенсируем гравитацию этого тика, чтобы висеть на месте
		vel = Vector(0, 0, GetConVar("sv_gravity"):GetFloat() * engine.TickInterval() * 0.5)
	end

	mv:SetVelocity(vel)
end)

if CLIENT then return end

local function StatsDefaults(ply)
	ply:SetNWFloat("ZS_SpeedMul", 1)
	ply:SetNWFloat("ZS_AttackMul", 1)
	ply:SetNWBool("ZS_Black", false)

	ply.zs_DamageTakenMul = nil
	ply.zs_StaminaMax = nil
end

-- пересчет модификаторов от навыков; вызывается при покупке и при каждом спавне зараженного
hook.Add("ZS_ApplySkillEffects", "ZS_AgileSkills", function(ply)
	if ply.zs_Class ~= "zs_agile" then return end

	StatsDefaults(ply)

	local speed, attack, damageTaken, stamina = 1, 1, 1, 200

	if ZS_HasSkill(ply, "autophagy") then
		speed = speed * 1.15
		stamina = 300
		damageTaken = damageTaken * 1.2
	end

	if ZS_HasSkill(ply, "homeostasis") then
		speed = speed * 1.1
		attack = attack * 0.6
		damageTaken = damageTaken * 0.5
	end

	ply:SetNWFloat("ZS_SpeedMul", speed)
	ply:SetNWFloat("ZS_AttackMul", attack)
	ply:SetNWBool("ZS_Black", ZS_HasSkill(ply, "autolysis"))

	ply.zs_DamageTakenMul = damageTaken
	ply.zs_StaminaMax = stamina
end)

hook.Add("ZS_ClearSkillEffects", "ZS_AgileSkills", StatsDefaults)

-- Высший гомеостаз: без боли и органов, убивает только смерть мозга
-- (по образцу regenerationberserk из sv_organism.lua, который включает weapon_fury13, но без постепенности)
local numberOrgans = {
	"heart", "liver", "stomach", "intestines", "trachea", "pneumothorax", "chest", "pelvis", "jaw",
	"spine1", "spine2", "spine3", "lleg", "rleg", "larm", "rarm",
	"arteria", "rarmartery", "larmartery", "rlegartery", "llegartery", "spineartery",
}

local zeroStats = {
	"pain", "avgpain", "painadd", "hurt", "hurtadd", "shock", "shock_turn", "immobilization", "disorientation",
	"stun", "bleed", "internalBleed", "hemotransfusionshock", "CO", "fear", "fearadd", "wantToVomit", "hungry",
}

local function ApplyHomeostasis(org)
	for _, key in ipairs(numberOrgans) do
		if isnumber(org[key]) then org[key] = 0 end
	end

	for _, key in ipairs(zeroStats) do
		if isnumber(org[key]) then org[key] = 0 end
	end

	for _, key in ipairs({"lungsL", "lungsR"}) do
		local lung = org[key]
		if istable(lung) then lung[1], lung[2] = 0, 0 end
	end

	for _, wound in pairs(org.wounds or {}) do wound[1] = 0 end
	for _, wound in pairs(org.arterialwounds or {}) do wound[1] = 0 end

	org.blood = 5000
	org.heartstop = false
	org.lungsfunction = true
	org.pulse = 70
	org.heartbeat = 70
	org.temperature = 36.7

	if org.o2 then org.o2[1] = org.o2.range or 30 end
	if org.stamina then org.stamina[1] = org.stamina.max or org.stamina[1] end

	org.consciousness = 1
	org.otrub = false
	org.needotrub = false
	org.needfake = false
	org.critical = false
	org.incapacitated = false

	org.llegdislocation = false
	org.rlegdislocation = false
	org.larmdislocation = false
	org.rarmdislocation = false
	org.jawdislocation = false
	-- org.brain и org.skull не трогаем: смерть мозга остается фатальной
end

local function HasHomeostasis(ply)
	return IsLivingZombie(ply) and ZS_HasSkill(ply, "homeostasis") and ply.organism
end

hook.Add("Org Think", "ZS_AgileHomeostasis", function(owner, org)
	local ply = IsValid(owner) and (owner:IsPlayer() and owner or hg.RagdollOwner(owner))
	if HasHomeostasis(ply) then ApplyHomeostasis(ply.organism) end
end)

-- сразу после урона, чтобы боль и шок не успевали сработать до следующего тика организма
hook.Add("HomigradDamage", "ZS_AgileHomeostasis", function(ent)
	local ply = IsValid(ent) and (ent:IsPlayer() and ent or hg.RagdollOwner(ent))
	if HasHomeostasis(ply) then ApplyHomeostasis(ply.organism) end
end)

hook.Add("Think", "ZS_AgileHomeostasis", function()
	for _, ply in player.Iterator() do
		if HasHomeostasis(ply) then ApplyHomeostasis(ply.organism) end
	end
end)

-- E+M1: рывок (левая ветка) или укус (правая ветка)
local DASH_COOLDOWN, DASH_TIME, DASH_FORCE = 6, 0.8, 650
local BITE_COOLDOWN, BITE_DAMAGE, BITE_RANGE, BITE_PENETRATION = 4, 40, 70, 12

local function Dash(ply)
	if (ply.zs_NextDash or 0) > CurTime() then return end
	ply.zs_NextDash = CurTime() + DASH_COOLDOWN

	local dir = ply:GetAimVector()
	dir.z = math.Clamp(dir.z, -0.1, 0.4)
	dir:Normalize()

	ply:SetVelocity(dir * DASH_FORCE + Vector(0, 0, ply:OnGround() and 180 or 60))
	-- как у ванильного fast zombie: звук прыжка и крик
	ply:EmitSound("npc/fast_zombie/leap1.wav", 80, math.random(95, 105))
	ply:EmitSound("npc/fast_zombie/fz_scream1.wav", 85, math.random(95, 105))

	ply.zs_DashUntil = CurTime() + DASH_TIME
	ply.zs_DashDir = dir
	ply.zs_DashHit = {}
end

-- Летальный рывок (улучшение летального захвата): если рывок сбил выжившего, зараженный сам падает в регдолл,
-- хватается за него обеими руками (свои сварки, а не хваты управления регдоллом) и наносит серию ударов
local LETHAL_DASH_TIME, LETHAL_DASH_INTERVAL = 3, 0.3
local lethalDashes = {}

local function ReleaseLethalDash(ply)
	local grab = lethalDashes[ply]
	lethalDashes[ply] = nil
	if not grab then return end

	for _, cons in ipairs(grab.welds) do
		if IsValid(cons) then cons:Remove() end
	end

	if IsValid(grab.victim) then grab.victim.zs_LethalDashBy = nil end
end

local function PhysBoneByName(ragdoll, name)
	local bone = ragdoll:LookupBone(name)
	return bone and ragdoll:TranslateBoneToPhysBone(bone)
end

local function StartLethalDash(ply, victim)
	if lethalDashes[ply] or not ZS_HasSkill(ply, "lethal_dash") then return end

	timer.Simple(0, function()
		if not IsLivingZombie(ply) or not IsLivingSurvivor(victim) or lethalDashes[ply] then return end

		local target = victim.FakeRagdoll
		if not IsValid(target) then return end

		if not IsValid(ply.FakeRagdoll) then hg.Fake(ply) end

		local ragdoll = ply.FakeRagdoll
		if not IsValid(ragdoll) then return end

		local torso = PhysBoneByName(target, "ValveBiped.Bip01_Spine2") or 0
		local torsoPhys = target:GetPhysicsObjectNum(torso)
		if not IsValid(torsoPhys) then return end

		-- руки зараженного ложатся на грудь выжившего и привариваются к ней
		local welds = {}
		for i, hand in ipairs({"ValveBiped.Bip01_L_Hand", "ValveBiped.Bip01_R_Hand"}) do
			local handBone = PhysBoneByName(ragdoll, hand)
			local handPhys = handBone and ragdoll:GetPhysicsObjectNum(handBone)

			if IsValid(handPhys) then
				handPhys:SetPos(torsoPhys:GetPos() + torsoPhys:GetAngles():Right() * (i == 1 and -5 or 5))

				local cons = constraint.Weld(ragdoll, target, handBone, torso, 0, false, false)
				if IsValid(cons) then welds[#welds + 1] = cons end
			end
		end

		lethalDashes[ply] = {
			victim = victim,
			target = target,
			welds = welds,
			untilTime = CurTime() + LETHAL_DASH_TIME,
			nextHit = CurTime(),
		}

		victim.zs_LethalDashBy = ply
		ply:EmitSound("npc/fast_zombie/fz_frenzy1.wav", 85, math.random(95, 105))
	end)
end

local function LethalDashThink(ply)
	local grab = lethalDashes[ply]
	if not grab then return end

	local target = grab.target
	if CurTime() > grab.untilTime or not IsValid(ply.FakeRagdoll) or not IsLivingSurvivor(grab.victim) or grab.victim.FakeRagdoll ~= target then
		ReleaseLethalDash(ply)
		return
	end

	if grab.nextHit > CurTime() then return end
	grab.nextHit = CurTime() + LETHAL_DASH_INTERVAL * ply:GetNWFloat("ZS_AttackMul", 1)

	local phys = target:GetPhysicsObjectNum(math.random(0, target:GetPhysicsObjectCount() - 1))
	local pos = IsValid(phys) and phys:GetPos() or target:GetPos()

	local dmg = DamageInfo()
	dmg:SetAttacker(ply)
	dmg:SetInflictor(IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon() or ply)
	dmg:SetDamage(math.random(6, 12))
	dmg:SetDamageType(DMG_SLASH)
	dmg:SetDamageForce(VectorRand() * 50)
	dmg:SetDamagePosition(pos)
	target:TakeDamageInfo(dmg)

	sound.Play("npc/zombie/claw_strike" .. math.random(3) .. ".wav", pos, 70, math.random(90, 110))
	util.Decal("Blood", pos + Vector(0, 0, 8), pos - Vector(0, 0, 16))
end

-- во время серии ударов ни зараженный, ни выживший не встают
hook.Add("Should Fake Up", "ZS_LethalDash", function(ply)
	if lethalDashes[ply] or IsValid(ply.zs_LethalDashBy) then return false end
end)

hook.Add("PlayerDeath", "ZS_LethalDash", function(ply)
	ReleaseLethalDash(ply)
	if IsValid(ply.zs_LethalDashBy) then ReleaseLethalDash(ply.zs_LethalDashBy) end
end)

local function DashThink(ply)
	if not ply.zs_DashUntil then return end

	if ply.zs_DashUntil < CurTime() or not ply:Alive() or IsValid(ply.FakeRagdoll) then
		ply.zs_DashUntil = nil
		return
	end

	local center = ply:GetPos() + ply:OBBCenter()

	for _, victim in ipairs(ents.FindInSphere(center, 48)) do
		if not IsLivingSurvivor(victim) or ply.zs_DashHit[victim] or IsValid(victim.FakeRagdoll) then continue end

		ply.zs_DashHit[victim] = true

		local dmg = DamageInfo()
		dmg:SetAttacker(ply)
		dmg:SetInflictor(ply)
		dmg:SetDamage(10)
		dmg:SetDamageType(DMG_CLUB)
		dmg:SetDamageForce(ply.zs_DashDir * 2000)
		dmg:SetDamagePosition(victim:GetPos() + victim:OBBCenter())
		victim:TakeDamageInfo(dmg)

		hg.Fake(victim)

		local ragdoll = victim.FakeRagdoll
		if IsValid(ragdoll) then
			for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
				local phys = ragdoll:GetPhysicsObjectNum(i)
				if IsValid(phys) then phys:AddVelocity(ply.zs_DashDir * 350) end
			end
		end

		victim:EmitSound("physics/body/body_medium_impact_hard" .. math.random(6) .. ".wav", 75)

		if IsValid(victim.FakeRagdoll) then
			ply.zs_DashUntil = nil
			StartLethalDash(ply, victim)
			return
		end
	end
end

local function Bite(ply)
	if (ply.zs_NextBite or 0) > CurTime() then return end
	ply.zs_NextBite = CurTime() + BITE_COOLDOWN

	local eye = ply:EyePos()

	ply:LagCompensation(true)
	local tr = util.TraceHull({
		start = eye,
		endpos = eye + ply:GetAimVector() * BITE_RANGE,
		mins = Vector(-6, -6, -6),
		maxs = Vector(6, 6, 6),
		filter = {ply, ply.FakeRagdoll},
		mask = MASK_SHOT,
	})
	ply:LagCompensation(false)

	local ent = tr.Entity
	local victim = IsValid(ent) and (ent:IsPlayer() and ent or hg.RagdollOwner(ent))

	if not IsLivingSurvivor(victim) then
		ply:EmitSound("npc/zombie/claw_miss" .. math.random(2) .. ".wav", 70)
		return
	end

	local dmg = DamageInfo()
	dmg:SetAttacker(ply)
	dmg:SetInflictor(IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon() or ply)
	dmg:SetDamage(BITE_DAMAGE)
	dmg:SetDamageType(DMG_SLASH)
	dmg:SetDamageForce(ply:GetAimVector() * 100)
	dmg:SetDamagePosition(tr.HitPos)

	-- глубокое проникновение: homigrad берет пробитие из PenetrationGlobal для одного удара
	PenetrationGlobal = BITE_PENETRATION
	ent:TakeDamageInfo(dmg)
	PenetrationGlobal = nil

	ply:EmitSound("npc/headcrab/headbite.wav", 75, math.random(85, 95))
	util.Decal("Blood", tr.HitPos + tr.HitNormal, tr.HitPos - tr.HitNormal)
end

hook.Add("KeyPress", "ZS_AgileAbilities", function(ply, key)
	if key ~= IN_ATTACK or not ply:KeyDown(IN_USE) then return end
	if zb.ROUND_STATE ~= 1 or not IsLivingZombie(ply) or IsValid(ply.FakeRagdoll) then return end

	if ZS_HasSkill(ply, "dash") then
		Dash(ply)
	elseif ZS_HasSkill(ply, "hyperdontia") then
		Bite(ply)
	end
end)

-- Летальный захват: зараженный в регдолле держит обеими руками регдолл живого выжившего - удары идут автоматически
-- (хваты рук - weld-констрейнты ConsLH/ConsRH регдолла, см. fake/sv_control.lua)
local GRAB_INTERVAL = 0.25

local function GetGrabbedSurvivor(ply)
	local ragdoll = ply.FakeRagdoll
	if not IsValid(ragdoll) then return end

	local left, right = ragdoll.ConsLH, ragdoll.ConsRH
	if not IsValid(left) or not IsValid(right) then return end

	local target = left.Ent2
	if not IsValid(target) or target ~= right.Ent2 or target:GetClass() ~= "prop_ragdoll" then return end

	local victim = hg.RagdollOwner(target)
	if IsLivingSurvivor(victim) and victim.FakeRagdoll == target then
		return victim, target
	end
end

local function GrabThink(ply)
	if not ZS_HasSkill(ply, "lethal_grab") then return end

	local victim, target = GetGrabbedSurvivor(ply)
	if not victim then return end

	if (ply.zs_NextGrabHit or 0) > CurTime() then return end
	ply.zs_NextGrabHit = CurTime() + GRAB_INTERVAL * ply:GetNWFloat("ZS_AttackMul", 1)

	local phys = target:GetPhysicsObjectNum(math.random(0, target:GetPhysicsObjectCount() - 1))
	local pos = IsValid(phys) and phys:GetPos() or target:GetPos()

	local dmg = DamageInfo()
	dmg:SetAttacker(ply)
	dmg:SetInflictor(IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon() or ply)
	dmg:SetDamage(math.random(6, 12))
	dmg:SetDamageType(DMG_SLASH)
	dmg:SetDamageForce(VectorRand() * 50)
	dmg:SetDamagePosition(pos)
	target:TakeDamageInfo(dmg)

	sound.Play("npc/zombie/claw_strike" .. math.random(3) .. ".wav", pos, 70, math.random(90, 110))
	util.Decal("Blood", pos + Vector(0, 0, 8), pos - Vector(0, 0, 16))
end

local nextAbilityThink = 0
hook.Add("Think", "ZS_AgileAbilitiesThink", function()
	if nextAbilityThink > CurTime() then return end
	nextAbilityThink = CurTime() + 0.05

	if zb.ROUND_STATE ~= 1 then return end

	for _, ply in player.Iterator() do
		if not IsLivingZombie(ply) then
			ply.zs_DashUntil = nil
			continue
		end

		DashThink(ply)
		GrabThink(ply)
		LethalDashThink(ply)
	end
end)
