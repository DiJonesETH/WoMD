AddCSLuaFile()

-- Гнездо зараженных (навык metaboliser "Гнездо"): точка спавна, на которую можно навестись в наблюдателе и нажать E
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Infected Nest"
ENT.Spawnable = false

ENT.Model = "models/hunter/misc/sphere2x2.mdl"
ENT.Material = "models/flesh"
ENT.MaxHealth = 400
ENT.CocoonHealth = 1200 -- Кокон (улучшение гнезда): прочнее и окружен мясными петлями (zs_meat_loop.lua)
ENT.CocoonSnares = 4

-- приплюснутый купол шириной ~95 и высотой ~36 юнитов (половина роста игрока)
ENT.HeightScale = 0.38
ENT.HalfWidth = 46
ENT.HalfHeight = 18
ENT.Blisters = 2 -- волдырей вокруг нового гнезда
ENT.SpawnCooldown = 2 -- из гнезда выходит один зараженный раз в SpawnCooldown секунд

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "Cocoon")
end

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

		local health = self.zs_Cocoon and self.CocoonHealth or self.MaxHealth
		self:SetCocoon(self.zs_Cocoon or false)
		self:SetHealth(health)
		self:SetMaxHealth(health)

		if self.zs_Cocoon then
			self:SetColor(Color(130, 50, 60))
			timer.Simple(0, function()
				if IsValid(self) then self:SpawnSnares() end
			end)
		end

		-- вокруг гнезда сразу вырастают волдыри мясного мицелия (lua/entities/zs_blister.lua)
		timer.Simple(0, function()
			if not IsValid(self) or not ZS_SpawnBlisterNear then return end

			local colony = {}
			for _ = 1, self.Blisters do
				ZS_SpawnBlisterNear(self:GetPos(), self:GetOwner(), colony, self)
			end
		end)
	end

	-- мясные петли по кругу вокруг кокона
	function ENT:SpawnSnares()
		self.Snares = {}

		for i = 1, self.CocoonSnares do
			local dir = Angle(0, (360 / self.CocoonSnares) * i + math.Rand(-20, 20), 0):Forward()
			local start = self:GetPos() + dir * math.Rand(90, 150) + Vector(0, 0, 40)
			local tr = util.TraceLine({start = start, endpos = start - Vector(0, 0, 200), filter = self, mask = MASK_SOLID_BRUSHONLY})

			if tr.Hit and tr.HitNormal.z > 0.6 then
				local snare = ents.Create("zs_meat_loop")
				if IsValid(snare) then
					snare:SetPos(tr.HitPos + Vector(0, 0, 1))
					snare:SetOwner(self:GetOwner())
					snare:Spawn()
					self.Snares[#self.Snares + 1] = snare
				end
			end
		end
	end

	function ENT:OnRemove()
		for _, snare in ipairs(self.Snares or {}) do
			if IsValid(snare) then snare:Remove() end
		end
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
		-- кокон - вытянутый плотный мешок, а не приплюснутый купол
		mat:Scale(Vector(scale, scale, scale * (self:GetCocoon() and self.HeightScale * 2.2 or self.HeightScale)))

		self:EnableMatrix("RenderMultiply", mat)
		local tall = self:GetCocoon() and 3 or 1.2
		self:SetRenderBounds(Vector(-self.HalfWidth * 1.2, -self.HalfWidth * 1.2, -self.HalfHeight * tall), Vector(self.HalfWidth * 1.2, self.HalfWidth * 1.2, self.HalfHeight * tall))
		self:DrawModel()
	end
end
