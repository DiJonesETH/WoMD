AddCSLuaFile()

-- Гнездо зараженных (навык metaboliser "Гнездо"): точка спавна, на которую можно навестись в наблюдателе и нажать E
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Infected Nest"
ENT.Spawnable = false

ENT.Model = "models/hunter/misc/sphere1x1.mdl"
ENT.Material = "models/flesh"
ENT.MaxHealth = 400

if SERVER then
	function ENT:Initialize()
		self:SetModel(self.Model)
		self:SetMaterial(self.Material)
		self:SetColor(Color(170, 90, 90))

		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_VPHYSICS)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then phys:EnableMotion(false) end

		self:SetHealth(self.MaxHealth)
		self:SetMaxHealth(self.MaxHealth)
	end

	-- точка появления зараженного рядом с гнездом
	function ENT:GetSpawnPos()
		local ang = math.Rand(0, 360)
		local offset = Angle(0, ang, 0):Forward() * 50

		local tr = util.TraceHull({
			start = self:GetPos() + offset + Vector(0, 0, 40),
			endpos = self:GetPos() + offset - Vector(0, 0, 80),
			mins = Vector(-10, -10, 0),
			maxs = Vector(10, 10, 10),
			filter = self,
		})

		return tr.HitPos + Vector(0, 0, 4)
	end

	function ENT:OnTakeDamage(dmg)
		local attacker = dmg:GetAttacker()
		if IsValid(attacker) and attacker:IsPlayer() and attacker:Team() ~= 0 then return 0 end

		self:SetHealth(self:Health() - dmg:GetDamage())
		self:EmitSound("physics/flesh/flesh_squishy_impact_hard" .. math.random(4) .. ".wav", 70)

		if self:Health() <= 0 then
			local effect = EffectData()
			effect:SetOrigin(self:GetPos())
			util.Effect("BloodImpact", effect)

			self:EmitSound("physics/flesh/flesh_bloody_break.wav", 80)
			self:Remove()
		end

		return dmg:GetDamage()
	end
else
	function ENT:Draw()
		-- гнездо медленно пульсирует
		local scale = 1 + math.sin(CurTime() * 1.5 + self:EntIndex()) * 0.04
		local mat = Matrix()
		mat:Scale(Vector(scale, scale, scale * 0.6))

		self:EnableMatrix("RenderMultiply", mat)
		self:DrawModel()
	end
end
