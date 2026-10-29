AddCSLuaFile()

-- Волдырь мясного мицелия (навык metaboliser "Мясной мицелий"): дышит, лечит зараженных рядом,
-- раз в 40 секунд выращивает новый волдырь (до 5 в колонии). Выжившим его нужно разрушить, как гнездо
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Flesh Blister"
ENT.Spawnable = false

ENT.Model = "models/hunter/misc/sphere075x075.mdl"
ENT.Material = "models/flesh"
ENT.Radius = 262 -- 5 метров
ENT.GrowInterval = 40
ENT.MaxColony = 5
ENT.MaxHealth = 150

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

		self:SetHealth(self.MaxHealth)
		self:SetMaxHealth(self.MaxHealth)

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

	-- новый волдырь на земле в 80-160 юнитах от точки pos (колония общая)
	function ZS_SpawnBlisterNear(pos, owner, colony, filter)
		for _ = 1, 6 do
			local dir = Angle(0, math.Rand(0, 360), 0):Forward()
			local start = pos + dir * math.Rand(80, 160) + Vector(0, 0, 60)

			local tr = util.TraceLine({start = start, endpos = start - Vector(0, 0, 200), filter = filter, mask = MASK_SOLID_BRUSHONLY})

			if tr.Hit and tr.HitNormal.z > 0.6 then
				local blister = ents.Create("zs_blister")
				blister:SetPos(tr.HitPos)
				blister:SetOwner(owner)
				blister.Colony = colony
				blister:Spawn()

				blister:EmitSound("physics/flesh/flesh_squishy_impact_hard" .. math.random(4) .. ".wav", 70, 80)
				return blister
			end
		end
	end

	function ENT:HasErgot()
		local owner = self:GetOwner()
		return IsValid(owner) and ZS_HasSkill(owner, "ergot")
	end

	function ENT:Grow()
		if ColonySize(self.Colony) >= self.MaxColony then return end

		ZS_SpawnBlisterNear(self:GetPos(), self:GetOwner(), self.Colony, self)
	end

	function ENT:Think()
		local time = CurTime()

		if self.NextTick <= time then
			self.NextTick = time + 1

			local pos = self:GetPos()

			for _, ply in player.Iterator() do
				if not ply:Alive() or ply:GetPos():Distance(pos) > self.Radius then continue end

				-- Спорынья (улучшение мясного мицелия): кашель, замедление и размытое зрение у выживших рядом
				if ply:Team() == 0 and self:HasErgot() then
					ply.zs_CoughUntil = math.max(ply.zs_CoughUntil or 0, time + 3)
					ply:SetNWFloat("ZS_SporedUntil", time + 2)
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
		self:EmitSound("physics/flesh/flesh_squishy_impact_hard" .. math.random(4) .. ".wav", 70)

		if self:Health() <= 0 then
			local effect = EffectData()
			effect:SetOrigin(self:GetPos())
			util.Effect("BloodImpact", effect)

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
