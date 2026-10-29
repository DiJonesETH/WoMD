AddCSLuaFile()

-- Облако ядовитого газа "Тяжелого газа" (улучшение метановой избыточности metaboliser, sh_zs_metaboliser.lua).
-- Висит LifeTime секунд; выжившие внутри получают ожог, теряют кислород и кашляют
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Poison Gas"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

ENT.Radius = 262 -- 5 метров
ENT.LifeTime = 15
ENT.BurnDamage = 4
ENT.OxygenLoss = 6

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
		self:SetNoDraw(false)
		self:SetSolid(SOLID_NONE)
		self:SetMoveType(MOVETYPE_NONE)
		self:DrawShadow(false)

		self.DieTime = CurTime() + self.LifeTime
		self:EmitSound("ambient/gas/steam2.wav", 70, 70)
	end

	function ENT:Think()
		if self.DieTime < CurTime() then
			self:StopSound("ambient/gas/steam2.wav")
			self:Remove()
			return
		end

		local attacker = IsValid(self:GetOwner()) and self:GetOwner() or self
		local pos = self:GetPos()

		for _, ply in player.Iterator() do
			if not ply:Alive() or ply:Team() ~= 0 or ply:GetPos():Distance(pos) > self.Radius then continue end

			local dmg = DamageInfo()
			dmg:SetAttacker(attacker)
			dmg:SetInflictor(self)
			dmg:SetDamage(self.BurnDamage)
			dmg:SetDamageType(DMG_BURN)
			dmg:SetDamagePosition(ply:WorldSpaceCenter())
			hg.GetCurrentCharacter(ply):TakeDamageInfo(dmg)

			-- удушье
			if ply.organism and ply.organism.o2 then
				ply.organism.o2[1] = math.max(ply.organism.o2[1] - self.OxygenLoss, 0)
			end

			ply.zs_CoughUntil = math.max(ply.zs_CoughUntil or 0, CurTime() + 2)
		end

		self:NextThink(CurTime() + 1)
		return true
	end

	function ENT:OnRemove()
		self:StopSound("ambient/gas/steam2.wav")
	end

	return
end

function ENT:Draw() end

function ENT:Think()
	if (self.NextPuff or 0) > CurTime() then return end
	self.NextPuff = CurTime() + 0.15

	local emitter = ParticleEmitter(self:GetPos())
	if not emitter then return end

	for _ = 1, 3 do
		local offset = VectorRand() * self.Radius * 0.7
		offset.z = math.abs(offset.z) * 0.3

		local particle = emitter:Add("particle/smokesprites_000" .. math.random(9), self:GetPos() + offset)
		if particle then
			particle:SetVelocity(VectorRand() * 15 + Vector(0, 0, 5))
			particle:SetDieTime(math.Rand(2, 3.5))
			particle:SetStartAlpha(70)
			particle:SetEndAlpha(0)
			particle:SetStartSize(math.Rand(50, 80))
			particle:SetEndSize(math.Rand(100, 140))
			particle:SetRoll(math.Rand(0, 360))
			particle:SetRollDelta(math.Rand(-0.5, 0.5))
			particle:SetColor(120, 150, 40)
			particle:SetLighting(false)
		end
	end

	emitter:Finish()
end
