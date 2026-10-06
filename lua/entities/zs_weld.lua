AddCSLuaFile()

-- Точка сварки баррикады Zombie Survival (порт гвоздя prop_nail из JetBoom/zombiesurvival).
-- Держит сварку между пропами, логика в lua/homigrad/sh_zs_barricade.lua.
-- Выглядит как темный наплыв металла, который несколько секунд после сварки светится раскаленным.
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Weld"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

ENT.Model = "models/hunter/blocks/cube025x025x025.mdl"
ENT.CoolTime = 6

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "BaseEntity")
end

if SERVER then
	function ENT:Initialize()
		self:SetModel(self.Model)
		self:SetModelScale(0.12)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_NONE)
		self:DrawShadow(false)
	end

	-- точка пропадает вместе со сваркой (cons:DeleteOnRemove) или с пропом
	function ENT:OnRemove()
		if self.ZSRemoving or not ZS_BARRICADE or not ZS_BARRICADE.RemoveNail then return end

		ZS_BARRICADE.RemoveNail(self, true)
	end

	return
end

local matBead = Material("models/shiny")
local matGlow = Material("sprites/light_glow02_add")
local colHot = Color(255, 140, 40)

function ENT:Initialize()
	self.SpawnTime = CurTime()
end

function ENT:Draw()
	render.MaterialOverride(matBead)
	render.SetColorModulation(0.18, 0.17, 0.16)
	self:DrawModel()
	render.SetColorModulation(1, 1, 1)
	render.MaterialOverride()
end

function ENT:DrawTranslucent()
	local heat = 1 - (CurTime() - (self.SpawnTime or 0)) / self.CoolTime
	if heat <= 0 then return end

	colHot.a = 255 * heat
	render.SetMaterial(matGlow)
	render.DrawSprite(self:GetPos(), 10 * heat + 2, 10 * heat + 2, colHot)
end

function ENT:OnRemove()
	local pos = self:GetPos()

	sound.Play("ambient/energy/spark" .. math.random(6) .. ".wav", pos, 70, math.random(90, 110))

	local emitter = ParticleEmitter(pos)
	if not emitter then return end

	local grav = Vector(0, 0, -300)
	for _ = 1, math.random(12, 18) do
		local dir = VectorRand():GetNormalized()
		local particle = emitter:Add("effects/spark", pos + dir)
		if particle then
			particle:SetVelocity(dir * math.Rand(16, 90))
			particle:SetDieTime(math.Rand(0.4, 0.9))
			particle:SetStartAlpha(255)
			particle:SetEndAlpha(255)
			particle:SetStartSize(math.Rand(0.4, 1.2))
			particle:SetEndSize(0)
			particle:SetCollide(true)
			particle:SetBounce(0.6)
			particle:SetGravity(grav)
		end
	end

	emitter:Finish()
end
