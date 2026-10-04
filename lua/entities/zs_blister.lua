AddCSLuaFile()

-- Волдырь мясного мицелия (навык metaboliser "Мясной мицелий"): дышит, лечит зараженных рядом,
-- раз в 40 секунд выращивает новый волдырь (до 5 в колонии), взрывается кислотой рядом с выжившими
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Flesh Blister"
ENT.Spawnable = false

ENT.Model = "models/hunter/misc/sphere075x075.mdl"
ENT.Material = "models/flesh"
ENT.Radius = 262 -- 5 метров
ENT.GrowInterval = 40
ENT.MaxColony = 5
ENT.CoughTime = 40
ENT.ExplodeDamage = 15

if SERVER then
	function ENT:Initialize()
		self:SetModel(self.Model)
		self:SetMaterial(self.Material)
		self:SetColor(Color(200, 110, 110))

		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_VPHYSICS)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then phys:EnableMotion(false) end

		self:SetHealth(60)

		self.Colony = self.Colony or {}
		self.Colony[self] = true
		self.NextGrow = CurTime() + self.GrowInterval
		self.NextTick = 0
	end

	local function ColonySize(colony)
		local count = 0

		for ent in pairs(colony) do
			if IsValid(ent) then count = count + 1 else colony[ent] = nil end
		end

		return count
	end

	function ENT:Grow()
		if ColonySize(self.Colony) >= self.MaxColony then return end

		for _ = 1, 6 do
			local dir = Angle(0, math.Rand(0, 360), 0):Forward()
			local start = self:GetPos() + dir * math.Rand(80, 160) + Vector(0, 0, 60)

			local tr = util.TraceLine({start = start, endpos = start - Vector(0, 0, 200), filter = self, mask = MASK_SOLID_BRUSHONLY})

			if tr.Hit and tr.HitNormal.z > 0.6 then
				local blister = ents.Create("zs_blister")
				blister:SetPos(tr.HitPos)
				blister:SetOwner(self:GetOwner())
				blister.Colony = self.Colony
				blister:Spawn()

				blister:EmitSound("physics/flesh/flesh_squishy_impact_hard" .. math.random(4) .. ".wav", 70, 80)
				return
			end
		end
	end

	function ENT:Explode()
		if self.Exploded then return end
		self.Exploded = true

		local pos = self:GetPos() + Vector(0, 0, 16)

		self:EmitSound("physics/flesh/flesh_bloody_break.wav", 85)

		local attacker = IsValid(self:GetOwner()) and self:GetOwner() or self

		for _, ply in player.Iterator() do
			if not ply:Alive() or ply:Team() ~= 0 then continue end
			if ply:GetPos():Distance(pos) > self.Radius then continue end

			local dmg = DamageInfo()
			dmg:SetAttacker(attacker)
			dmg:SetInflictor(self)
			dmg:SetDamage(self.ExplodeDamage)
			dmg:SetDamageType(DMG_BURN)
			dmg:SetDamagePosition(ply:GetPos() + ply:OBBCenter())
			hg.GetCurrentCharacter(ply):TakeDamageInfo(dmg)

			ply.zs_CoughUntil = CurTime() + self.CoughTime
		end

		if ZS_SpawnAcidBurst then
			ZS_SpawnAcidBurst(attacker, pos, 16, 350)
		end

		self:Remove()
	end

	function ENT:Think()
		local time = CurTime()

		if self.NextTick <= time then
			self.NextTick = time + 1

			local pos = self:GetPos()

			for _, ply in player.Iterator() do
				if not ply:Alive() or ply:GetPos():Distance(pos) > self.Radius then continue end

				if ply:Team() == 0 then
					self:Explode()
					return
				elseif ZS_IsZombie(ply) and ZS_HealOrganism then
					ZS_HealOrganism(ply, 1.5)
				end
			end
		end

		if self.NextGrow <= time then
			self.NextGrow = time + self.GrowInterval
			self:Grow()
		end

		self:NextThink(time + 0.5)
		return true
	end

	function ENT:OnTakeDamage(dmg)
		local attacker = dmg:GetAttacker()
		if IsValid(attacker) and attacker:IsPlayer() and attacker:Team() ~= 0 then return 0 end

		self:SetHealth(self:Health() - dmg:GetDamage())

		if self:Health() <= 0 then
			self:EmitSound("physics/flesh/flesh_bloody_break.wav", 75)
			self:Remove()
		end

		return dmg:GetDamage()
	end
else
	function ENT:Draw()
		-- "дыхание": модель немного сжимается и раздувается обратно
		local scale = 1 + math.sin(CurTime() * 2.5 + self:EntIndex()) * 0.08
		local mat = Matrix()
		mat:Scale(Vector(scale, scale, scale))

		self:EnableMatrix("RenderMultiply", mat)
		self:DrawModel()
	end
end
