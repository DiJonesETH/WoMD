AddCSLuaFile()

-- Термоядерная бомба Zombie Survival ("ключ к победе", sv_zs_victorykey.lua): статичная капсула, по E открывает кейпад.
-- Верный 4-значный код взводит бомбу: тихий электрический гул, через ArmTime секунд - термоядерный взрыв.
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Thermonuclear Bomb"
ENT.Spawnable = false

ENT.Model = "models/props_combine/headcrabcannister01a.mdl"
ENT.ArmTime = 10
ENT.UseDistance = 150

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "DetonateTime")
end

function ENT:IsArmed()
	return self:GetDetonateTime() > 0
end

if SERVER then
	util.AddNetworkString("zs_bomb_keypad")
	util.AddNetworkString("zs_bomb_code")
	util.AddNetworkString("zs_bomb_result")

	function ENT:Initialize()
		self:SetModel(self.Model)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then phys:EnableMotion(false) end
	end

	-- взрыв и пропы, и игроки не берут
	function ENT:OnTakeDamage() return 0 end

	local function CanUseBomb(ply, bomb)
		return IsValid(ply) and ply:Alive() and ply:Team() == 0 and IsValid(bomb) and bomb:GetClass() == "zs_victory_bomb"
			and not bomb:IsArmed() and ply:GetPos():Distance(bomb:GetPos()) <= bomb.UseDistance
	end

	function ENT:Use(ply)
		if not CanUseBomb(ply, self) then return end

		self:EmitSound("buttons/blip1.wav", 60)

		net.Start("zs_bomb_keypad")
			net.WriteEntity(self)
		net.Send(ply)
	end

	net.Receive("zs_bomb_code", function(len, ply)
		local bomb = net.ReadEntity()
		local code = net.ReadString()

		if (ply.zs_NextBombCode or 0) > CurTime() then return end
		ply.zs_NextBombCode = CurTime() + 0.5

		if not CanUseBomb(ply, bomb) then return end

		local ok = code == bomb.Code

		net.Start("zs_bomb_result")
			net.WriteEntity(bomb)
			net.WriteBool(ok)
		net.Send(ply)

		if not ok then
			bomb:EmitSound("buttons/button10.wav", 65)
			return
		end

		bomb:Arm()
	end)

	function ENT:Arm()
		self:SetDetonateTime(CurTime() + self.ArmTime)
		self:EmitSound("buttons/button9.wav", 65)

		-- тихий электрический гул
		self.Hum = CreateSound(self, "ambient/energy/electric_loop.wav")
		self.Hum:PlayEx(0.35, 70)
		self.Hum:ChangePitch(110, self.ArmTime)

		timer.Create("ZS_VictoryBomb" .. self:EntIndex(), self.ArmTime, 1, function()
			if not IsValid(self) then return end

			local pos = self:GetPos()
			self:Remove()

			if ZS_Thermonuke then ZS_Thermonuke(pos) end
		end)
	end

	function ENT:OnRemove()
		if self.Hum then self.Hum:Stop() end
		timer.Remove("ZS_VictoryBomb" .. self:EntIndex())
	end

	return
end

local colGlow = Color(255, 60, 40)
local matGlow = Material("sprites/light_glow02_add")

function ENT:Draw()
	self:DrawModel()

	-- мигающий индикатор взведенной бомбы
	if self:IsArmed() and math.sin(CurTime() * 20) > 0 then
		render.SetMaterial(matGlow)
		render.DrawSprite(self:WorldSpaceCenter() + self:GetUp() * 12, 24, 24, colGlow)
	end
end
