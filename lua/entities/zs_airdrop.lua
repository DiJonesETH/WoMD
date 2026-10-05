AddCSLuaFile()

-- Аирдроп выживших (Zombie Survival): ящик медленно опускается на парашюте с красным сигнальным огнем,
-- каждый выживший по E получает свой личный лут (ZS_GiveAirdropLoot в режиме), через 2 минуты ящик исчезает
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Airdrop"
ENT.Spawnable = false

ENT.Model = "models/props_junk/wood_crate002a.mdl"
ENT.ParachuteModel = "models/props_phx/construct/metal_dome360.mdl"
ENT.FallSpeed = 180
ENT.LifeTime = 120

local colFlare = Color(255, 30, 20)

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "Falling")
	self:NetworkVar("Float", 0, "DieTime")
end

if SERVER then
	function ENT:Initialize()
		self:SetModel(self.Model)
		self:SetMaterial("models/props_pipes/guttermetal01a")
		self:SetColor(Color(90, 110, 80))

		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetMass(200)
			phys:Wake()
		end

		self:SetDieTime(CurTime() + self.LifeTime)
		self.Opened = {}

		-- красный сигнальный огонь на ящике
		local flare = ents.Create("env_flare")
		if IsValid(flare) then
			flare:SetPos(self:GetPos() + Vector(0, 0, self:OBBMaxs().z))
			flare:SetKeyValue("scale", "6")
			flare:SetKeyValue("duration", tostring(self.LifeTime + 5))
			flare:SetParent(self)
			flare:Spawn()
			flare:Activate()
			self.Flare = flare
		end
	end

	-- падает, если стартовал в небе; иначе сразу лежит на земле
	function ENT:StartFalling()
		self:SetFalling(true)
	end

	function ENT:Land()
		if not self:GetFalling() then return end

		self:SetFalling(false)
		self:EmitSound("physics/wood/wood_crate_impact_hard" .. math.random(4) .. ".wav", 90)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then phys:EnableMotion(false) end
	end

	function ENT:PhysicsCollide(data)
		if self:GetFalling() and data.HitNormal.z < -0.5 then
			self:Land()
		end
	end

	function ENT:Think()
		if self:GetDieTime() < CurTime() then
			self:Remove()
			return
		end

		if self:GetFalling() then
			local phys = self:GetPhysicsObject()

			if IsValid(phys) then
				phys:SetVelocity(Vector(0, 0, -self.FallSpeed))
				phys:SetAngles(Angle(0, phys:GetAngles().y, 0))
				phys:AddAngleVelocity(-phys:GetAngleVelocity())
			end

			local tr = util.TraceLine({start = self:GetPos(), endpos = self:GetPos() - Vector(0, 0, self:OBBMaxs().z + 8), filter = self, mask = MASK_SOLID})
			if tr.Hit then self:Land() end
		end

		self:NextThink(CurTime())
		return true
	end

	function ENT:Use(ply)
		if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() or ply:Team() ~= 0 then return end

		local id = ply:SteamID64() or ply:EntIndex()
		if self.Opened[id] then
			ZS_NotifyOnce(ply, "airdrop_taken", "You have already taken your cargo from this crate")
			return
		end

		self.Opened[id] = true
		self:EmitSound("items/ammocrate_open.wav", 70)

		if ZS_GiveAirdropLoot then
			ZS_GiveAirdropLoot(ply, self)
		end
	end

	function ENT:OnRemove()
		if IsValid(self.Flare) then self.Flare:Remove() end
	end
else
	local glow = Material("sprites/light_glow02_add")
	local ropeMat = Material("cable/rope")

	function ENT:GetParachute()
		if not IsValid(self.Parachute) then
			self.Parachute = ClientsideModel(self.ParachuteModel, RENDERGROUP_OPAQUE)
			if not IsValid(self.Parachute) then return end

			self.Parachute:SetNoDraw(true)
			self.Parachute:SetMaterial("models/debug/debugwhite")
			self.Parachute:SetModelScale(1.1, 0)
		end

		return self.Parachute
	end

	function ENT:Draw()
		self:DrawModel()

		local top = self:GetPos() + Vector(0, 0, self:OBBMaxs().z)

		-- сигнальный огонь
		render.SetMaterial(glow)
		render.DrawSprite(top + Vector(0, 0, 6), 48 + math.sin(CurTime() * 20) * 8, 48, colFlare)

		if not self:GetFalling() then return end

		local chute = self:GetParachute()
		if not IsValid(chute) then return end

		local chutePos = top + Vector(0, 0, 110)
		chute:SetPos(chutePos)
		chute:SetAngles(Angle(0, CurTime() * 10 % 360, 0))

		render.SetColorModulation(0.75, 0.75, 0.65)
		chute:DrawModel()
		render.SetColorModulation(1, 1, 1)

		-- стропы
		render.SetMaterial(ropeMat)
		local mins, maxs = self:OBBMins(), self:OBBMaxs()
		for _, corner in ipairs({Vector(mins.x, mins.y, maxs.z), Vector(maxs.x, mins.y, maxs.z), Vector(mins.x, maxs.y, maxs.z), Vector(maxs.x, maxs.y, maxs.z)}) do
			local from = self:LocalToWorld(corner)
			local dir = (from - top):GetNormalized()
			render.DrawBeam(from, chutePos + Vector(dir.x, dir.y, 0) * 45, 1, 0, 1, color_white)
		end
	end

	function ENT:Think()
		local light = DynamicLight(self:EntIndex())
		if light then
			light.pos = self:GetPos() + Vector(0, 0, self:OBBMaxs().z + 10)
			light.r, light.g, light.b = 255, 30, 20
			light.brightness = 3
			light.decay = 1000
			light.size = 300
			light.dietime = CurTime() + 0.2
		end
	end

	function ENT:OnRemove()
		if IsValid(self.Parachute) then self.Parachute:Remove() end
	end
end
