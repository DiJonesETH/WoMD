if SERVER then AddCSLuaFile() end

-- Азотная граната Zombie Survival (на основе РГД-5): срабатывает от удара о поверхность, без осколков и взрыва
-- взрывчатки - выпускает быстро исчезающее облако жидкого азота. Зараженные в облаке (с прямой видимостью)
-- замерзают на FreezeTime секунд (lua/homigrad/sh_zs_nitrogen.lua).
ENT.Base = "ent_hg_grenade"
ENT.Spawnable = false
ENT.Model = "models/pwb/weapons/w_rgd5_thrown.mdl"
ENT.NotSpoon = true

ENT.CloudRadius = 220
ENT.FreezeTime = 3
ENT.ArmDelay = 0.15 -- не срабатывает о руку бросившего

if CLIENT then
	function ENT:Draw()
		self:DrawModel()
	end

	return
end

function ENT:Think()
	self:NextThink(CurTime())
	return true
end

function ENT:PhysicsCollide(data)
	if self.Exploded or CurTime() - (self.CreateTime or 0) < self.ArmDelay then return end
	if data.Speed < 20 then return end

	timer.Simple(0, function()
		if IsValid(self) then self:Explode() end
	end)
end

function ENT:Explode()
	if self.Exploded then return end
	self.Exploded = true

	local pos = self:WorldSpaceCenter()

	local effect = EffectData()
	effect:SetOrigin(pos)
	effect:SetRadius(self.CloudRadius)
	util.Effect("eff_zs_nitrogen", effect, true, true)

	sound.Play("ambient/gas/steam2.wav", pos, 80, 120)
	sound.Play("physics/glass/glass_impact_bullet" .. math.random(4) .. ".wav", pos, 75, 80)

	for _, ply in ipairs(ents.FindInSphere(pos, self.CloudRadius)) do
		if ply:IsPlayer() and ply:Alive() and ZS_IsZombie and ZS_IsZombie(ply) then
			local tr = util.TraceLine({start = pos, endpos = ply:WorldSpaceCenter(), mask = MASK_SOLID_BRUSHONLY})
			if not tr.Hit then ZS_Freeze(ply, self.FreezeTime) end
		end
	end

	self:Remove()
end
