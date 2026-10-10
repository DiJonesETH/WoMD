if SERVER then AddCSLuaFile() end

-- Сварочный аппарат Zombie Survival: механика гвоздей из JetBoom/zombiesurvival (weapon_zs_hammer),
-- только вместо гвоздя - точка сварки zs_weld, которая варится 3 секунды и тратит электрод.
-- Зажать ЛКМ на пропе - приварить его к тому, что за ним; зажать ПКМ на баррикаде - чинить; R - срезать точку сварки.
-- Модель собрана из примитивов (горелка в руке, аппарат за спиной, кабель между ними), анимация процедурная.
SWEP.PrintName = "Arc Welder"
SWEP.Instructions = "A portable arc welder for building barricades.\n\nHold LMB on a prop to weld it to whatever is behind it (3 seconds, uses an electrode).\nHold RMB on a barricade to repair it.\nR - cut a weld off.\nHold Z - pass through barricades."
SWEP.Category = "ZCity Other"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.Slot = 4
SWEP.SlotPos = 1

SWEP.ViewModel = ""
SWEP.WorldModel = "models/hunter/blocks/cube025x025x025.mdl"
SWEP.UseHands = false
SWEP.HoldType = "pistol"
SWEP.DrawCrosshair = false
SWEP.DrawAmmo = false

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "Electrodes" -- электроды (ZS_BARRICADE.ElectrodeAmmo)
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = true
SWEP.Secondary.Ammo = "none"

SWEP.WeldRange = 64
SWEP.WeldDrift = 10 -- насколько можно сдвинуть прицел во время сварки

local function ZSB() return ZS_BARRICADE end

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)
end

function SWEP:Deploy()
	self:SetHoldType(self.HoldType)
	self.DeployTime = CurTime()
	return true
end

function SWEP:PrimaryAttack() end
function SWEP:SecondaryAttack() end

function SWEP:IsWelding()
	return self:GetNW2Bool("Welding", false)
end

if SERVER then
	local function Message(ply, text)
		ply:PrintMessage(HUD_PRINTCENTER, text)
	end

	local function WeldTrace(owner, dist)
		local eye = owner:EyePos()
		return util.TraceLine({
			start = eye,
			endpos = eye + owner:GetAimVector() * dist,
			filter = {owner, owner.FakeRagdoll},
			mask = MASK_SOLID,
		})
	end

	local function CanWeldEntity(ent, bone)
		return IsValid(ent) and util.IsValidPhysicsObject(ent, bone or 0)
			and ent:GetMoveType() == MOVETYPE_VPHYSICS
			and not ent:IsPlayer() and not ent:IsNPC() and not ent:IsRagdoll() and not ent:IsWeapon()
			and not ent.NoNails
	end

	local function TooDamaged(ent)
		return ZSB().GetMaxHealth(ent) > 0 and ZSB().GetHealth(ent) <= 0
	end

	local function Full(ent)
		local b = ZSB()
		return b.IsNailed(ent) and (#b.GetNails(ent) >= b.MaxNailsPerProp or b.PropsInContraption(ent) >= b.MaxPropsInBarricade)
	end

	-- проверки как у молотка JetBoom; возвращает цель сварки или nil (с сообщением игроку)
	function SWEP:FindWeldTarget(quiet)
		local owner = self:GetOwner()
		local b = ZSB()

		local tr = WeldTrace(owner, self.WeldRange)
		local trent = tr.Entity

		if not CanWeldEntity(trent, tr.PhysicsBone) or tr.Fraction == 0 or Full(trent) then return end
		if not b.IsNailed(trent) and not trent:GetPhysicsObject():IsMoveable() then return end

		local function Fail(text)
			if not quiet then Message(owner, text) end
		end

		if tr.MatType == MAT_GRATE or tr.MatType == MAT_CLIP then return Fail("Impossible") end
		if tr.MatType == MAT_GLASS then return Fail("You can't weld glass") end

		local count = 0
		for _, weld in ipairs(b.GetNails(trent)) do
			if weld.ZSDeployer == owner then
				count = count + 1
				if count >= b.MaxNailsPerPlayer then return Fail("You can't put more welds on this object") end
			end

			if weld:GetParent() == trent and weld:GetPos():DistToSqr(tr.HitPos) <= 81 then
				return Fail("Too close to another weld")
			end
		end

		if TooDamaged(trent) then return Fail("This object is too damaged to be used") end

		local aim = owner:GetAimVector()
		local tr2 = util.TraceLine({start = tr.HitPos, endpos = tr.HitPos + aim * 24, filter = {owner, trent}, mask = MASK_SOLID})
		if tr2.HitSky then return end

		local ent = tr2.Entity
		local toWorld = tr2.HitWorld
		if not toWorld and not (CanWeldEntity(ent, tr2.PhysicsBone) and (b.IsNailed(ent) or ent:GetPhysicsObject():IsMoveable())) then
			return Fail("There is nothing behind it to weld to")
		end

		if tr2.MatType == MAT_GRATE or tr2.MatType == MAT_CLIP then return Fail("Impossible") end
		if tr2.MatType == MAT_GLASS then return Fail("You can't weld glass") end

		if not toWorld then
			if Full(ent) then return end
			if TooDamaged(ent) then return Fail("This object is too damaged to be used") end
		end

		return {
			ent = trent,
			bone = tr.PhysicsBone or 0,
			attach = toWorld and game.GetWorld() or ent,
			attachBone = tr2.PhysicsBone or 0,
			localPos = trent:WorldToLocal(tr.HitPos),
			hitPos = tr.HitPos,
			normal = tr.HitNormal,
			aim = aim,
		}
	end

	function SWEP:SetWeldState(welding, pos, endTime)
		self:SetNW2Bool("Welding", welding)
		if pos then self:SetNW2Vector("WeldPos", pos) end
		self:SetNW2Float("WeldEnd", endTime or 0)

		local owner = self:GetOwner()

		if welding then
			if not self.LoopSound and IsValid(owner) then
				self.LoopSound = CreateSound(owner, "ambient/energy/electric_loop.wav")
				self.LoopSound:PlayEx(0.6, 140)
			end
		else
			if self.LoopSound then
				self.LoopSound:Stop()
				self.LoopSound = nil
			end

			self.WeldTarget = nil
		end
	end

	function SWEP:FinishWeld(target)
		local owner = self:GetOwner()
		local b = ZSB()

		-- за 3 секунды все могло поменяться: проверяем заново
		local fresh = self:FindWeldTarget()
		if not fresh or fresh.ent ~= target.ent or fresh.attach ~= target.attach then return end
		if b.GetElectrodes(owner) <= 0 then return end

		local cons
		for _, old in pairs(constraint.FindConstraints(fresh.ent, "Weld")) do
			if old.Ent1 == fresh.attach or old.Ent2 == fresh.attach then
				cons = old.Constraint
				break
			end
		end

		cons = cons or constraint.Weld(fresh.ent, fresh.attach, fresh.bone, fresh.attachBone, 0, true)
		if not IsValid(cons) then return end

		local weld = ents.Create("zs_weld")
		if not IsValid(weld) then return end

		weld:SetPos(fresh.hitPos + fresh.normal * 0.5)
		weld:SetAngles(fresh.normal:Angle())
		weld:SetParent(fresh.ent)
		weld:Spawn()
		weld:SetBaseEntity(fresh.ent)
		weld.ZSDeployer = owner

		cons:DeleteOnRemove(weld)
		b.AttachNail(weld, fresh.ent, fresh.attach, cons)
		b.SetElectrodes(owner, b.GetElectrodes(owner) - 1)

		sound.Play("ambient/energy/zap" .. math.random(1, 3) .. ".wav", fresh.hitPos, 70, math.random(110, 125))
		util.Decal("FadingScorch", fresh.hitPos + fresh.normal, fresh.hitPos - fresh.normal)
	end

	function SWEP:RepairThink(owner)
		local b = ZSB()
		local tr = WeldTrace(owner, self.WeldRange)
		local ent = tr.Entity

		if not b.IsNailed(ent) then
			self:SetWeldState(false)
			return
		end

		local health, maxHealth = b.GetHealth(ent), b.GetMaxHealth(ent)
		local repairs = b.GetRepairs(ent)

		if health <= 0 or health >= maxHealth or repairs <= 0.01 then
			if self:IsWelding() then
				self:SetWeldState(false)
				if health > 0 and health < maxHealth then Message(owner, "This barricade can't be repaired anymore") end
			end
			return
		end

		self:SetWeldState(true, tr.HitPos, 0)

		if (self.NextRepair or 0) > CurTime() then return end
		self.NextRepair = CurTime() + b.RepairInterval

		b.SetHealth(ent, math.min(maxHealth, health + math.min(repairs, b.RepairPerHit)))
		b.SetRepairs(ent, math.max(repairs - (b.GetHealth(ent) - health), 0))

		local effect = EffectData()
		effect:SetOrigin(tr.HitPos)
		effect:SetNormal(tr.HitNormal)
		effect:SetMagnitude(1)
		util.Effect("zs_nailrepaired", effect, true, true)
	end

	function SWEP:WeldThink(owner)
		local b = ZSB()
		local target = self.WeldTarget

		if not target then
			if (self.NextWeldTry or 0) > CurTime() then return end
			self.NextWeldTry = CurTime() + 0.5

			if b.GetElectrodes(owner) <= 0 then
				Message(owner, "No electrodes left")
				return
			end

			target = self:FindWeldTarget()
			if not target then return end

			self.WeldTarget = target
			self.WeldEnd = CurTime() + b.WeldTime
			self:SetWeldState(true, target.hitPos, self.WeldEnd)
			owner:EmitSound("ambient/energy/zap" .. math.random(5, 9) .. ".wav", 70, 120)
			return
		end

		-- прицел должен оставаться на точке сварки
		local tr = WeldTrace(owner, self.WeldRange)
		if not IsValid(target.ent) or tr.Entity ~= target.ent or tr.HitPos:DistToSqr(target.ent:LocalToWorld(target.localPos)) > self.WeldDrift ^ 2 then
			self:SetWeldState(false)
			return
		end

		if (self.NextSparkSound or 0) < CurTime() then
			self.NextSparkSound = CurTime() + math.Rand(0.15, 0.4)
			sound.Play("ambient/energy/spark" .. math.random(6) .. ".wav", tr.HitPos, 65, math.random(100, 130), 0.6)
			owner:ViewPunch(Angle(math.Rand(-0.3, 0.3), math.Rand(-0.3, 0.3), 0))
		end

		if CurTime() >= self.WeldEnd then
			self:FinishWeld(target)
			self:SetWeldState(false)
			self.NextWeldTry = CurTime() + 0.6
		end
	end

	function SWEP:Think()
		local owner = self:GetOwner()
		if not IsValid(owner) then return end

		local blocked = not owner:Alive() or IsValid(owner.FakeRagdoll) or ZSB().IsGhosting(owner)

		if not blocked and owner:KeyDown(IN_ATTACK) then
			self:WeldThink(owner)
		elseif not blocked and owner:KeyDown(IN_ATTACK2) then
			self.WeldTarget = nil
			self:RepairThink(owner)
		elseif self:IsWelding() then
			self:SetWeldState(false)
		end
	end

	-- R: срезать ближайшую к прицелу точку сварки (электрод не возвращается)
	function SWEP:Reload()
		local owner = self:GetOwner()
		if not IsValid(owner) or IsValid(owner.FakeRagdoll) or ZSB().IsGhosting(owner) or self:IsWelding() then return end
		if (self.NextCut or 0) > CurTime() then return end

		local tr = WeldTrace(owner, self.WeldRange)
		local trent = tr.Entity
		if not ZSB().IsNailed(trent) then return end

		local best, bestDist
		for _, weld in ipairs(ZSB().GetNails(trent)) do
			local dist = weld:GetPos():DistToSqr(tr.HitPos)
			if not bestDist or dist < bestDist then best, bestDist = weld, dist end
		end

		if not best then return end

		self.NextCut = CurTime() + 1
		ZSB().RemoveNail(best)
		trent:SetPhysicsAttacker(owner)
		owner:EmitSound("ambient/energy/zap" .. math.random(1, 3) .. ".wav", 70, 90)
	end

	function SWEP:Holster()
		self:SetWeldState(false)
		return true
	end

	function SWEP:OnRemove()
		self:SetWeldState(false)
	end

	function SWEP:OnDrop()
		self:SetWeldState(false)
	end

	return
end

------------------------------------------------------------------ клиент: модель, анимация, эффекты

function SWEP:Reload() end

local CUBE = 11.86 -- размер models/hunter/blocks/cube025x025x025.mdl

local matShiny = Material("models/shiny")
local matPlain = Material("models/debug/debugwhite")

-- горелка: X - вперед к соплу, Z - вверх; рукоять как у пистолета, сопло загнуто вниз
local torchParts = {
	{pos = Vector(0, 0, -2.2), ang = Angle(15, 0, 0), size = Vector(2.4, 2.0, 6.5), col = {0.1, 0.1, 0.11}, mat = matPlain}, -- рукоять
	{pos = Vector(2.2, 0, 0.1), ang = Angle(15, 0, 0), size = Vector(0.6, 0.5, 1.8), col = {0.75, 0.1, 0.08}, mat = matShiny}, -- курок
	{pos = Vector(2.6, 0, 2.3), ang = Angle(0, 0, 0), size = Vector(8.5, 2.5, 2.6), col = {0.15, 0.15, 0.16}, mat = matShiny}, -- корпус
	{pos = Vector(-1.5, 0, 3.7), ang = Angle(0, 0, 0), size = Vector(2.5, 1.6, 0.6), col = {0.85, 0.65, 0.1}, mat = matShiny}, -- кнопка/шильдик
	{pos = Vector(10.3, 0, 1.4), ang = Angle(15, 0, 0), size = Vector(7, 1.1, 1.1), col = {0.8, 0.5, 0.25}, mat = matShiny}, -- медная шея
	{pos = Vector(14.4, 0, 0.3), ang = Angle(15, 0, 0), size = Vector(2.2, 1.7, 1.7), col = {0.55, 0.55, 0.58}, mat = matShiny}, -- сопло
	{pos = Vector(0.6, 0, -6.2), ang = Angle(15, 0, 0), size = Vector(1.6, 1.6, 1.8), col = {0.05, 0.05, 0.05}, mat = matPlain}, -- ввод кабеля
}
local torchTip = Vector(15.6, 0, -0.1)
local torchCable = Vector(0.9, 0, -7.2)

-- аппарат за спиной: X - назад от спины, Z - вверх
local boxParts = {
	{pos = Vector(0, 0, 0), ang = Angle(0, 0, 0), size = Vector(6, 11, 13), col = {0.85, 0.62, 0.08}, mat = matShiny}, -- корпус
	{pos = Vector(3.05, 0, 2), ang = Angle(0, 0, 0), size = Vector(0.3, 8, 6), col = {0.08, 0.08, 0.08}, mat = matPlain}, -- панель
	{pos = Vector(3.3, -2, 3), ang = Angle(0, 0, 0), size = Vector(0.6, 2, 2), col = {0.85, 0.85, 0.85}, mat = matShiny}, -- ручка тока
	{pos = Vector(3.3, 2.2, 3.5), ang = Angle(0, 0, 0), size = Vector(0.4, 1, 1), col = {0.9, 0.15, 0.1}, mat = matPlain}, -- лампа
	{pos = Vector(0, 0, 7.4), ang = Angle(0, 0, 0), size = Vector(1.2, 7, 1.2), col = {0.08, 0.08, 0.08}, mat = matPlain}, -- ручка
	{pos = Vector(0, 0, -7), ang = Angle(0, 0, 0), size = Vector(6.4, 11.4, 1.2), col = {0.08, 0.08, 0.08}, mat = matPlain}, -- днище
}
local boxCable = Vector(3.2, 3.5, -4.5)

-- положение горелки относительно кисти (ValveBiped.Bip01_R_Hand)
SWEP.TorchPos = Vector(3.5, 1.4, -2.6)
SWEP.TorchAng = Angle(0, 0, 180)
SWEP.TorchShiftLeft = 3 -- дополнительный сдвиг горелки влево относительно взгляда игрока

local function MakePart(part)
	local ent = ClientsideModel("models/hunter/blocks/cube025x025x025.mdl", RENDERGROUP_OPAQUE)
	if not IsValid(ent) then return end

	ent:SetNoDraw(true)

	local m = Matrix()
	m:Scale(part.size / CUBE)
	ent:EnableMatrix("RenderMultiply", m)

	return ent
end

function SWEP:GetParts(key, list)
	self.ZSParts = self.ZSParts or {}
	local parts = self.ZSParts[key]

	if not parts then
		parts = {}
		for i, part in ipairs(list) do parts[i] = MakePart(part) end
		self.ZSParts[key] = parts
	end

	return parts
end

local function DrawParts(ents_, list, basePos, baseAng)
	for i, part in ipairs(list) do
		local ent = ents_[i]
		if IsValid(ent) then
			local pos, ang = LocalToWorld(part.pos, part.ang, basePos, baseAng)
			ent:SetPos(pos)
			ent:SetAngles(ang)
			ent:SetupBones()

			render.MaterialOverride(part.mat)
			render.SetColorModulation(part.col[1], part.col[2], part.col[3])
			ent:DrawModel()
		end
	end

	render.SetColorModulation(1, 1, 1)
	render.MaterialOverride()
end

-- провисающий кабель от горелки к аппарату
local matCable = Material("cable/cable2")
local function DrawCable(from, to)
	local mid = (from + to) * 0.5 - Vector(0, 0, 12)

	render.SetMaterial(matCable)
	render.StartBeam(11)
	for i = 0, 10 do
		local t = i / 10
		local p = from * (1 - t) ^ 2 + mid * 2 * t * (1 - t) + to * t ^ 2
		render.AddBeam(p, 1, t * 4, color_white)
	end
	render.EndBeam()
end

-- процедурная анимация горелки: подъем при доставании, покачивание, дрожь и "плетение" шва при сварке
function SWEP:AnimateTorch(pos, ang)
	local t = CurTime()
	local deploy = math.Clamp((t - (self.DeployTime or 0)) / 0.4, 0, 1)
	deploy = 1 - (1 - deploy) ^ 3

	local pitch = (1 - deploy) * 55 + math.sin(t * 1.3) * 1.2
	local yaw = math.sin(t * 0.9) * 0.8
	local offset = Vector(0, 0, 0)

	if self:IsWelding() then
		pitch = pitch + math.Rand(-1.2, 1.2)
		yaw = yaw + math.Rand(-1.2, 1.2)
		offset.y = math.sin(t * 9) * 0.35
		offset.z = math.cos(t * 9) * 0.35
		self.LastWeld = t
	elseif self.LastWeld and t - self.LastWeld < 0.35 then
		-- отдергивание горелки после сварки
		pitch = pitch - (1 - (t - self.LastWeld) / 0.35) * 12
	end

	ang:RotateAroundAxis(ang:Right(), -pitch)
	ang:RotateAroundAxis(ang:Up(), yaw)
	pos = pos + ang:Right() * offset.y + ang:Up() * offset.z

	return pos, ang
end

local matGlow = Material("sprites/light_glow02_add")
local matArc = Material("sprites/physbeam")
local colArc = Color(170, 200, 255)
local colSpark = Color(255, 240, 200)

function SWEP:DrawWeldEffects(tip)
	local weldPos = self:GetNW2Vector("WeldPos")
	local flicker = math.Rand(0.6, 1)

	-- дуга от сопла к точке сварки и слепящее свечение
	render.SetMaterial(matArc)
	render.DrawBeam(tip, weldPos, 1.5 * flicker, 0, 1, colArc)

	render.SetMaterial(matGlow)
	render.DrawSprite(weldPos, 40 * flicker, 40 * flicker, colArc)
	render.DrawSprite(weldPos, 12 * flicker, 12 * flicker, colSpark)

	local light = DynamicLight(self:EntIndex())
	if light then
		light.pos = weldPos
		light.r, light.g, light.b = 170, 200, 255
		light.brightness = 3 * flicker
		light.decay = 2000
		light.size = 220
		light.dietime = CurTime() + 0.1
	end

	if (self.NextSparks or 0) > CurTime() then return end
	self.NextSparks = CurTime() + 0.05

	local emitter = ParticleEmitter(weldPos)
	if not emitter then return end

	local grav = Vector(0, 0, -400)
	for _ = 1, math.random(3, 6) do
		local dir = (VectorRand() + Vector(0, 0, 0.6)):GetNormalized()
		local particle = emitter:Add("effects/spark", weldPos + dir)
		if particle then
			particle:SetVelocity(dir * math.Rand(60, 180))
			particle:SetDieTime(math.Rand(0.3, 0.8))
			particle:SetStartAlpha(255)
			particle:SetEndAlpha(255)
			particle:SetStartSize(math.Rand(0.5, 1.2))
			particle:SetEndSize(0)
			particle:SetStartLength(math.Rand(3, 6))
			particle:SetEndLength(0)
			particle:SetCollide(true)
			particle:SetBounce(0.4)
			particle:SetGravity(grav)
		end
	end

	emitter:Finish()
end

function SWEP:DrawWelder(torchPos, torchAng, boxPos, boxAng)
	local torch = self:GetParts("torch", torchParts)
	local box = self:GetParts("box", boxParts)

	DrawParts(torch, torchParts, torchPos, torchAng)
	DrawParts(box, boxParts, boxPos, boxAng)

	DrawCable(LocalToWorld(torchCable, angle_zero, torchPos, torchAng), LocalToWorld(boxCable, angle_zero, boxPos, boxAng))

	if self:IsWelding() then
		self:DrawWeldEffects(LocalToWorld(torchTip, angle_zero, torchPos, torchAng))
	end
end

-- в руках рисует homigrad (lua/homigrad/fake/sh_render.lua), брошенное оружие - сам движок
function SWEP:DrawWorldModel2()
	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	local renderGuy = hg.GetCurrentCharacter(owner)
	if not IsValid(renderGuy) then return end

	local hand = renderGuy:LookupBone("ValveBiped.Bip01_R_Hand")
	local spine = renderGuy:LookupBone("ValveBiped.Bip01_Spine2")
	if not hand or not spine then return end

	local handMatrix = renderGuy:GetBoneMatrix(hand)
	local spineMatrix = renderGuy:GetBoneMatrix(spine)
	if not handMatrix or not spineMatrix then return end

	local torchPos, torchAng = LocalToWorld(self.TorchPos, self.TorchAng, handMatrix:GetTranslation(), handMatrix:GetAngles())
	torchPos = torchPos - owner:EyeAngles():Right() * self.TorchShiftLeft
	torchPos, torchAng = self:AnimateTorch(torchPos, torchAng)

	local yaw = renderGuy:IsPlayer() and owner:GetAngles().y or spineMatrix:GetAngles().y
	local boxAng = Angle(0, yaw + 180, 0)
	local boxPos = spineMatrix:GetTranslation() + boxAng:Forward() * 7

	self:DrawWelder(torchPos, torchAng, boxPos, boxAng)
end

function SWEP:DrawWorldModel()
	if IsValid(self:GetOwner()) then return end

	local pos, ang = self:GetPos(), self:GetAngles()
	local boxAng = Angle(ang)
	local torchAng = Angle(ang)
	torchAng:RotateAroundAxis(torchAng:Forward(), 90)

	self:DrawWelder(pos + ang:Right() * 10 + ang:Up() * 2, torchAng, pos + ang:Up() * 7, boxAng)
end

function SWEP:OnRemove()
	for _, parts in pairs(self.ZSParts or {}) do
		for _, ent in pairs(parts) do
			if IsValid(ent) then ent:Remove() end
		end
	end
end

-- HUD: электроды и прогресс сварки, вспышка при сварке своими глазами
local colOk, colBad, colBack = Color(140, 200, 255), Color(255, 80, 80), Color(0, 0, 0, 180)

function SWEP:DrawHUD()
	local owner = self:GetOwner()
	if not IsValid(owner) or not ZS_BARRICADE then return end

	local electrodes = ZS_BARRICADE.GetElectrodes(owner)
	draw.SimpleTextOutlined("Electrodes: " .. electrodes, "DermaLarge", ScrW() - 40, ScrH() - 120, electrodes > 0 and colOk or colBad, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER, 2, color_black)

	if not self:IsWelding() then return end

	local flash = math.Rand(0.04, 0.12)
	surface.SetDrawColor(220, 235, 255, 255 * flash)
	surface.DrawRect(0, 0, ScrW(), ScrH())

	local weldEnd = self:GetNW2Float("WeldEnd", 0)
	if weldEnd <= 0 then return end

	local frac = math.Clamp(1 - (weldEnd - CurTime()) / ZS_BARRICADE.WeldTime, 0, 1)
	local w, h = 200, 10
	local x, y = ScrW() * 0.5 - w * 0.5, ScrH() * 0.5 + 90

	draw.RoundedBox(0, x - 2, y - 2, w + 4, h + 4, colBack)
	draw.RoundedBox(0, x, y, w * frac, h, colOk)
	draw.SimpleTextOutlined("Welding...", "DermaDefaultBold", ScrW() * 0.5, y + h + 12, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
end
