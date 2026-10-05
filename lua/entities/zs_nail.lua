AddCSLuaFile()

-- Гвоздь баррикады Zombie Survival (порт prop_nail из JetBoom/zombiesurvival), логика в lua/homigrad/sh_zs_barricade.lua
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Nail"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_OPAQUE

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "BaseEntity")
end

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/crossbow_bolt.mdl")
		self:SetModelScale(0.75)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_NONE)
	end

	-- гвоздь пропадает вместе со сваркой (cons:DeleteOnRemove) или с пропом
	function ENT:OnRemove()
		if self.ZSRemoving or not ZS_BARRICADE or not ZS_BARRICADE.RemoveNail then return end

		ZS_BARRICADE.RemoveNail(self, true)
	end
else
	function ENT:OnRemove()
		local normal = self:GetForward() * -1
		local pos = self:GetPos() + normal

		sound.Play("physics/metal/metal_box_impact_bullet" .. math.random(3) .. ".wav", pos, 75, math.random(90, 110))

		local grav = Vector(0, 0, -300)
		local emitter = ParticleEmitter(pos)
		if not emitter then return end

		for _ = 1, math.random(16, 24) do
			local dir = (VectorRand() * 0.6 + normal):GetNormalized()
			local particle = emitter:Add("effects/spark", pos + dir)
			if particle then
				particle:SetVelocity(dir * math.Rand(16, 100))
				particle:SetDieTime(math.Rand(0.5, 1))
				particle:SetStartAlpha(255)
				particle:SetEndAlpha(255)
				particle:SetStartSize(math.Rand(0.4, 1.5))
				particle:SetEndSize(0)
				particle:SetCollide(true)
				particle:SetBounce(0.8)
				particle:SetGravity(grav)
			end
		end

		emitter:Finish()
	end
end
