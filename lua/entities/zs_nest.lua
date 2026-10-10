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
ENT.SpawnCooldown = 2 -- из гнезда выходит один зараженный раз в SpawnCooldown секунд

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
		-- игроки проходят сквозь гнездо (зараженные появляются прямо в нем), пули и удары по нему попадают
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then phys:EnableMotion(false) end

		self:SetHealth(self.MaxHealth)
		self:SetMaxHealth(self.MaxHealth)
	end

	-- зараженный появляется ровно в точке, где поставлено гнездо (на земле под его центром)
	function ENT:GetSpawnPos()
		return self:GetPos() - Vector(0, 0, self.HalfHeight - 4)
	end

	function ENT:CanSpawn()
		return (self.zs_NextSpawn or 0) <= CurTime()
	end

	function ENT:OnSpawned()
		self.zs_NextSpawn = CurTime() + self.SpawnCooldown
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
