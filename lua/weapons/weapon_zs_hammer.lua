if SERVER then AddCSLuaFile() end

-- Молоток плотника Zombie Survival (порт weapon_zs_hammer из JetBoom/zombiesurvival) на базе молотка Z-City.
-- ЛКМ - удар, по прибитому пропу - починка баррикады; ПКМ - прибить проп к тому, что за ним; R - вытащить гвоздь.
SWEP.Base = "weapon_hammer"
SWEP.PrintName = "Carpenter's Hammer"
SWEP.Instructions = "A simple but extremely useful tool for making barricades.\n\nRMB - hammer in a nail. It attaches the prop to whatever is behind it.\nR - take a nail out.\nLMB - attack, or repair a damaged barricade.\nHold Z - pass through barricades."
SWEP.Category = "Weapons - Melee"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.DamagePrimary = 15
SWEP.DamageType = DMG_CLUB

local weppos, wepang = Vector(-2, 4.5, -11), Angle(14, -90, 90)

-- только тупая сторона: R занята гвоздями
function SWEP:ThinkAdd()
	self.weaponPos = LerpFT(0.4, self.weaponPos, weppos)
	self.weaponAng = LerpFT(0.3, self.weaponAng, wepang)
end

function SWEP:InitAdd()
	if CLIENT then return end
	self.AmmoGive = ZS_BARRICADE and ZS_BARRICADE.HammerNails or 16
end

function SWEP:CanPrimaryAttack()
	return self:GetNextPrimaryFire() < CurTime()
end

if CLIENT then
	function SWEP:SecondaryAttack() end
	function SWEP:Reload() end

	function SWEP:DrawHUD()
		local owner = self:GetOwner()
		if not IsValid(owner) then return end

		local nails = owner:GetAmmoCount(self.Ammo)
		draw.SimpleTextOutlined("Nails: " .. nails, "DermaLarge", ScrW() - 40, ScrH() - 120, nails > 0 and Color(140, 255, 140) or Color(255, 80, 80), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER, 2, color_black)
	end

	return
end

local function Message(ply, text)
	ply:PrintMessage(HUD_PRINTCENTER, text)
end

local function MeleeTrace(owner, dist)
	local eye = owner:EyePos()
	return util.TraceLine({
		start = eye,
		endpos = eye + owner:GetAimVector() * dist,
		filter = {owner, owner.FakeRagdoll},
		mask = MASK_SOLID,
	})
end

local function CanNailEntity(ent, bone)
	return IsValid(ent) and util.IsValidPhysicsObject(ent, bone or 0)
		and ent:GetMoveType() == MOVETYPE_VPHYSICS
		and not ent:IsPlayer() and not ent:IsNPC() and not ent:IsRagdoll() and not ent:IsWeapon()
		and not ent.NoNails
end

local function TooDamaged(ent)
	return ZS_BARRICADE.GetMaxHealth(ent) > 0 and ZS_BARRICADE.GetHealth(ent) <= 0
end

local function BadMaterial(owner, tr)
	if tr.MatType == MAT_GRATE or tr.MatType == MAT_CLIP then
		Message(owner, "Impossible")
		return true
	end

	if tr.MatType == MAT_GLASS then
		Message(owner, "You can't put nails in glass")
		return true
	end
end

local function Full(ent)
	return ZS_BARRICADE.IsNailed(ent) and (#ZS_BARRICADE.GetNails(ent) >= ZS_BARRICADE.MaxNailsPerProp or ZS_BARRICADE.PropsInContraption(ent) >= ZS_BARRICADE.MaxPropsInBarricade)
end

function SWEP:SecondaryAttack()
	local owner = self:GetOwner()
	if not IsValid(owner) or IsValid(owner.FakeRagdoll) or ZS_BARRICADE.IsGhosting(owner) then return end
	if (self.ZSNextNail or 0) > CurTime() then return end
	if owner:GetAmmoCount(self.Ammo) <= 0 then return end

	local tr = MeleeTrace(owner, 64)
	local trent = tr.Entity

	if not CanNailEntity(trent, tr.PhysicsBone) or tr.Fraction == 0 or Full(trent) then return end
	if not ZS_BARRICADE.IsNailed(trent) and not trent:GetPhysicsObject():IsMoveable() then return end
	if BadMaterial(owner, tr) then return end

	local count = 0
	for _, nail in ipairs(ZS_BARRICADE.GetNails(trent)) do
		if nail.ZSDeployer == owner then
			count = count + 1
			if count >= ZS_BARRICADE.MaxNailsPerPlayer then return end
		end
	end

	for _, nail in ipairs(ZS_BARRICADE.GetNails(trent)) do
		if nail:GetParent() == trent and nail:GetPos():DistToSqr(tr.HitPos) <= 81 then
			Message(owner, "Too close to another nail")
			return
		end
	end

	if TooDamaged(trent) then
		Message(owner, "This object is too damaged to be used")
		return
	end

	local aim = owner:GetAimVector()
	local tr2 = util.TraceLine({start = tr.HitPos, endpos = tr.HitPos + aim * 24, filter = {owner, trent}, mask = MASK_SOLID})
	if tr2.HitSky then return end

	local ent = tr2.Entity
	local toWorld = tr2.HitWorld
	if not toWorld and not (CanNailEntity(ent, tr2.PhysicsBone) and (ZS_BARRICADE.IsNailed(ent) or ent:GetPhysicsObject():IsMoveable())) then return end
	if BadMaterial(owner, tr2) then return end

	if not toWorld then
		if Full(ent) then return end

		if TooDamaged(ent) then
			Message(owner, "This object is too damaged to be used")
			return
		end
	end

	local attach = toWorld and game.GetWorld() or ent

	-- одна сварка на пару пропов, все гвозди между ними держатся на ней
	local cons
	for _, old in pairs(constraint.FindConstraints(trent, "Weld")) do
		if old.Ent1 == attach or old.Ent2 == attach then
			cons = old.Constraint
			break
		end
	end

	cons = cons or constraint.Weld(trent, attach, tr.PhysicsBone or 0, tr2.PhysicsBone or 0, 0, true)
	if not IsValid(cons) then return end

	self.ZSNextNail = CurTime() + 1
	self:SetNextPrimaryFire(CurTime() + 1)
	owner:SetAmmo(owner:GetAmmoCount(self.Ammo) - 1, self.Ammo)

	local nail = ents.Create("zs_nail")
	if not IsValid(nail) then return end

	nail:SetPos(tr.HitPos - aim * 8)
	nail:SetAngles(aim:Angle())
	nail:SetParent(trent)
	nail:Spawn()
	nail:SetBaseEntity(trent)
	nail.ZSDeployer = owner

	cons:DeleteOnRemove(nail)
	ZS_BARRICADE.AttachNail(nail, trent, attach, cons)

	sound.Play("snd_jack_hmcd_hammerhit.wav", tr.HitPos, 65, math.random(90, 110))
	owner:ViewPunch(Angle(3, 0, 0))
	owner:SetAnimation(PLAYER_ATTACK1)
	self:PlayAnim("attack", 0.6, false, nil, false, true)
end

-- R: вытащить ближайший к прицелу гвоздь, он возвращается в запас
function SWEP:Reload()
	local owner = self:GetOwner()
	if not IsValid(owner) or IsValid(owner.FakeRagdoll) or ZS_BARRICADE.IsGhosting(owner) then return end
	if (self.ZSNextNail or 0) > CurTime() then return end

	local tr = MeleeTrace(owner, 64)
	local trent = tr.Entity
	if not ZS_BARRICADE.IsNailed(trent) then return end

	local best, bestDist
	for _, nail in ipairs(ZS_BARRICADE.GetNails(trent)) do
		local dist = nail:GetPos():DistToSqr(tr.HitPos)
		if not bestDist or dist < bestDist then
			best, bestDist = nail, dist
		end
	end

	if not best then return end

	self.ZSNextNail = CurTime() + (#ZS_BARRICADE.GetNails(trent) > 2 and 0.5 or 1)
	self:SetNextPrimaryFire(self.ZSNextNail)

	ZS_BARRICADE.RemoveNail(best)
	trent:SetPhysicsAttacker(owner)

	owner:GiveAmmo(1, self.Ammo, true)
	owner:EmitSound("physics/metal/metal_solid_impact_bullet" .. math.random(4) .. ".wav", 65)
	owner:SetAnimation(PLAYER_ATTACK1)
	self:PlayAnim("attack", 0.6, false, nil, false, true)
end

-- удар по прибитому пропу чинит баррикаду (тратится запас починки)
function SWEP:PrimaryAttackAdd(ent, tr)
	if not ZS_BARRICADE.IsNailed(ent) or (self.ZSNextRepair or 0) > CurTime() then return end
	self.ZSNextRepair = CurTime() + 0.5

	local health, maxHealth = ZS_BARRICADE.GetHealth(ent), ZS_BARRICADE.GetMaxHealth(ent)
	local repairs = ZS_BARRICADE.GetRepairs(ent)
	if health <= 0 or health >= maxHealth or repairs <= 0.01 then return end

	ZS_BARRICADE.SetHealth(ent, math.min(maxHealth, health + math.min(repairs, ZS_BARRICADE.RepairPerHit)))
	ZS_BARRICADE.SetRepairs(ent, math.max(repairs - (ZS_BARRICADE.GetHealth(ent) - health), 0))

	ent:EmitSound("npc/dog/dog_servo" .. math.random(7, 8) .. ".wav", 70, math.random(100, 105))

	if tr then
		local effect = EffectData()
		effect:SetOrigin(tr.HitPos)
		effect:SetNormal(tr.HitNormal)
		effect:SetMagnitude(1)
		util.Effect("zs_nailrepaired", effect, true, true)
	end
end
