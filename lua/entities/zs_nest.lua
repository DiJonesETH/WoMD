AddCSLuaFile()

-- Гнездо зараженных (навык metaboliser "Гнездо"): точка спавна, на которую можно навестись в наблюдателе и нажать E
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Infected Nest"
ENT.Spawnable = false

ENT.Model = "models/hunter/misc/sphere2x2.mdl"
ENT.Material = "models/flesh"
ENT.MaxHealth = 400

-- приплюснутый купол шириной ~95 и высотой ~36 юнитов (половина роста игрока)
ENT.HeightScale = 0.38
ENT.HalfWidth = 46
ENT.HalfHeight = 18

if SERVER then
	function ENT:Initialize()
		self:SetModel(self.Model)
		self:SetMaterial(self.Material)
		self:SetColor(Color(170, 90, 90))

		local mins = Vector(-self.HalfWidth, -self.HalfWidth, -self.HalfHeight)
		local maxs = Vector(self.HalfWidth, self.HalfWidth, self.HalfHeight)

		self:PhysicsInitBox(mins, maxs)
		self:SetCollisionBounds(mins, maxs)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_BBOX)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then phys:EnableMotion(false) end

		self:SetHealth(self.MaxHealth)
		self:SetMaxHealth(self.MaxHealth)
	end

	-- точка появления зараженного рядом с гнездом
	function ENT:GetSpawnPos()
		local ang = math.Rand(0, 360)
		local offset = Angle(0, ang, 0):Forward() * (self.HalfWidth + 24)

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
		mat:Scale(Vector(scale, scale, scale * self.HeightScale))

		self:EnableMatrix("RenderMultiply", mat)
		self:SetRenderBounds(Vector(-self.HalfWidth, -self.HalfWidth, -self.HalfHeight) * 1.2, Vector(self.HalfWidth, self.HalfWidth, self.HalfHeight) * 1.2)
		self:DrawModel()
	end
end
