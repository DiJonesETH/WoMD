AddCSLuaFile()

-- Сгусток кислоты зараженного metaboliser (навыки "Рефлюкс", "Метановая избыточность", взрыв волдыря)
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Acid"
ENT.Spawnable = false

ENT.Damage = 6
ENT.CutChance = 20 -- шанс пореза в процентах
ENT.CutDamage = 5
ENT.SplashRadius = 48
ENT.LifeTime = 6

local GIB_MODELS = {
	"models/gibs/antlion_gib_small_1.mdl",
	"models/gibs/antlion_gib_small_2.mdl",
}
local FALLBACK_MODEL = "models/hunter/misc/sphere025x025.mdl"
local colAcid = Color(225, 210, 40)

if SERVER then
	function ENT:Initialize()
		local mdl = GIB_MODELS[math.random(#GIB_MODELS)]
		self:SetModel(util.IsValidModel(mdl) and mdl or FALLBACK_MODEL)
		self:SetModelScale(util.IsValidModel(mdl) and 0.7 or 0.35, 0)
		self:SetColor(colAcid)

		self:PhysicsInitSphere(3, "flesh")
		self:SetCollisionGroup(COLLISION_GROUP_PROJECTILE)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetMass(1)
			phys:EnableGravity(true)
			phys:Wake()
		end

		self.DieTime = CurTime() + self.LifeTime
	end

	-- ожог выжившим рядом с точкой попадания
	function ENT:Splash(pos, normal)
		normal = normal or vector_up

		util.Decal("YellowBlood", pos + normal * 4, pos - normal * 8)

		local effect = EffectData()
		effect:SetOrigin(pos)
		effect:SetNormal(normal)
		effect:SetColor(BLOOD_COLOR_YELLOW)
		util.Effect("BloodImpact", effect)

		sound.Play("physics/flesh/flesh_squishy_impact_hard" .. math.random(4) .. ".wav", pos, 60, math.random(110, 130), 0.6)

		local attacker = IsValid(self:GetOwner()) and self:GetOwner() or self
		local hit = {}

		for _, ent in ipairs(ents.FindInSphere(pos, self.SplashRadius)) do
			local victim = ent:IsPlayer() and ent or hg.RagdollOwner(ent)
			if not IsValid(victim) or not victim:IsPlayer() or not victim:Alive() or victim:Team() ~= 0 or hit[victim] then continue end

			hit[victim] = true

			-- кислота босса-гонома парализует, как "Парализующие наросты"
			if self.zs_Paralyze and ZS_ParalyzeSurvivor then ZS_ParalyzeSurvivor(victim) end

			local char = hg.GetCurrentCharacter(victim)

			-- ожог: именно тип урона DMG_BURN
			local dmg = DamageInfo()
			dmg:SetAttacker(attacker)
			dmg:SetInflictor(self)
			dmg:SetDamage(self.Damage)
			dmg:SetDamageType(DMG_BURN)
			dmg:SetDamagePosition(pos)
			char:TakeDamageInfo(dmg)

			-- с шансом частичка оставляет порез (режущий урон дает кровоточащую рану)
			if math.random(100) <= self.CutChance and IsValid(char) then
				local cut = DamageInfo()
				cut:SetAttacker(attacker)
				cut:SetInflictor(self)
				cut:SetDamage(self.CutDamage)
				cut:SetDamageType(DMG_SLASH)
				cut:SetDamagePosition(pos)
				char:TakeDamageInfo(cut)
			end
		end
	end

	function ENT:PhysicsCollide(data)
		if self.Splashed then return end
		if IsValid(data.HitEntity) and data.HitEntity:GetClass() == self:GetClass() then return end

		self.Splashed = true
		self:Splash(data.HitPos, -data.HitNormal)

		SafeRemoveEntityDelayed(self, 0)
	end

	function ENT:Think()
		if self.DieTime < CurTime() then
			self:Remove()
		end

		self:NextThink(CurTime() + 0.5)
		return true
	end
else
	local glow = Material("sprites/light_glow02_add")

	function ENT:Draw()
		self:DrawModel()

		render.SetMaterial(glow)
		render.DrawSprite(self:GetPos(), 14, 14, colAcid)
	end
end
