AddCSLuaFile()

-- Записка с кодом от термоядерной бомбы Zombie Survival (sv_zs_victorykey.lua): по E показывает код
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Note"
ENT.Spawnable = false

ENT.Model = "models/props_lab/clipboard.mdl"
ENT.UseDistance = 150

if SERVER then
	util.AddNetworkString("zs_victory_note")

	function ENT:Initialize()
		self:SetModel(self.Model)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then phys:EnableMotion(false) end
	end

	function ENT:OnTakeDamage() return 0 end

	function ENT:Use(ply)
		if not IsValid(ply) or not ply:Alive() or ply:GetPos():Distance(self:GetPos()) > self.UseDistance then return end

		self:EmitSound("physics/cardboard/cardboard_box_impact_soft" .. math.random(7) .. ".wav", 60)

		net.Start("zs_victory_note")
			net.WriteString(self.Code or "????")
		net.Send(ply)
	end
end
