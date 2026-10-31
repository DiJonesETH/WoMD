AddCSLuaFile()

-- Мясная петля кокона (улучшение гнезда metaboliser, lua/entities/zs_nest.lua): выживший, наступивший на петлю,
-- застревает на SnareTime секунд (движение режет SetupMove в sh_zs_metaboliser.lua). Выжившие могут ее разрушить
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Meat Snare"
ENT.Spawnable = false

ENT.Model = "models/props_phx/normal_tire.mdl" -- шина PHX (есть в GMod), лежит плашмя и обтянута мясом
ENT.Material = "models/flesh"
ENT.MaxHealth = 80
ENT.Radius = 32
ENT.SnareTime = 2.5
ENT.Cooldown = 6
ENT.Scale = 1.1

if SERVER then
	function ENT:Initialize()
		self:SetModel(self.Model)
		self:SetMaterial(self.Material)
		self:SetColor(Color(160, 70, 70))
		self:SetModelScale(self.Scale, 0)
		-- ось колеса - локальная Y: поворот по roll кладет шину плашмя
		self:SetAngles(Angle(0, math.Rand(0, 360), 90))

		self:SetSolid(SOLID_BBOX)
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON) -- проходима, но пули и удары попадают
		self:SetCollisionBounds(Vector(-self.Radius, -self.Radius, 0), Vector(self.Radius, self.Radius, 10))
		self:SetMoveType(MOVETYPE_NONE)

		self:SetHealth(self.MaxHealth)
		self:SetMaxHealth(self.MaxHealth)

		self.NextSnare = 0
	end

	function ENT:Think()
		if self.NextSnare <= CurTime() then
			for _, ply in player.Iterator() do
				if ply:Alive() and ply:Team() == 0 and not IsValid(ply.FakeRagdoll) and ply:GetPos():Distance(self:GetPos()) <= self.Radius then
					self.NextSnare = CurTime() + self.Cooldown

					ply:SetNWFloat("ZS_SnaredUntil", CurTime() + self.SnareTime)
					ply:EmitSound("npc/barnacle/barnacle_tongue_pull" .. math.random(3) .. ".wav", 75, 110)
					break
				end
			end
		end

		self:NextThink(CurTime() + 0.1)
		return true
	end

	function ENT:OnTakeDamage(dmg)
		local attacker = dmg:GetAttacker()
		if IsValid(attacker) and attacker:IsPlayer() and attacker:Team() ~= 0 then return 0 end

		self:SetHealth(self:Health() - dmg:GetDamage())
		self:EmitSound("physics/flesh/flesh_squishy_impact_hard" .. math.random(4) .. ".wav", 65)

		if self:Health() <= 0 then
			local effect = EffectData()
			effect:SetOrigin(self:GetPos())
			util.Effect("BloodImpact", effect)

			self:Remove()
		end

		return dmg:GetDamage()
	end

	return
end

function ENT:Draw()
	-- петля шевелится
	local scale = 1 + math.sin(CurTime() * 3 + self:EntIndex()) * 0.06
	local mat = Matrix()
	mat:Scale(Vector(scale, scale, scale))

	self:EnableMatrix("RenderMultiply", mat)
	self:DrawModel()
end
