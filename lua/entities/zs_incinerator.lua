AddCSLuaFile()

-- Бочка-трупосжигатель выживших Zombie Survival (спецпредмет аирдропа, ставится как ящик снабжения).
-- Заправляется пропами газовых баллонов и канистр, брошенными в бочку. Вмещает два трупа:
-- когда оба внутри и есть топливо, трупы горят IncinerateTime секунд (тратится одна заправка).
-- Сожженный труп уже не съесть зараженным.
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Corpse Incinerator"
ENT.Spawnable = false

ENT.MaxHealth = 400
ENT.MaxCorpses = 2
ENT.MaxFuel = 4
ENT.IncinerateTime = 100

-- пропы-топливо: газовые баллоны и канистры
ZS_INCINERATOR_FUEL = {
	["models/props_junk/propane_tank001a.mdl"] = true,
	["models/props_junk/propanecanister001a.mdl"] = true,
	["models/props_c17/canister01a.mdl"] = true,
	["models/props_c17/canister02a.mdl"] = true,
	["models/props_c17/canister_propane01a.mdl"] = true,
	["models/props_junk/gascan001a.mdl"] = true,
	["models/props_junk/metalgascan.mdl"] = true,
}

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "Fuel")
	self:NetworkVar("Int", 1, "Corpses")
	self:NetworkVar("Float", 0, "BurnEnd")
end

function ENT:GetBoxType()
	return "incinerator"
end

function ENT:IsBurning()
	return self:GetBurnEnd() > CurTime()
end

-- центр горловины бочки
function ENT:GetMouth()
	return self:LocalToWorld(Vector(0, 0, self:OBBMaxs().z))
end

if SERVER then
	function ENT:Initialize()
		self:SetModel(ZS_SUPPLY_BOXES.incinerator.model)
		self:SetColor(ZS_SUPPLY_BOXES.incinerator.color)

		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_VPHYSICS)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then phys:EnableMotion(false) end

		self:SetHealth(self.MaxHealth)
		self:SetMaxHealth(self.MaxHealth)
	end

	-- труп: регдолл погибшего (не "упавший" живой игрок)
	local function IsCorpse(ent)
		if not IsValid(ent) or ent:GetClass() ~= "prop_ragdoll" then return false end

		local owner = hg.RagdollOwner(ent)
		return not (IsValid(owner) and owner:Alive() and owner.FakeRagdoll == ent)
	end

	local function IsFuel(ent)
		return IsValid(ent) and string.StartWith(ent:GetClass(), "prop_physics") and ZS_INCINERATOR_FUEL[string.lower(ent:GetModel() or "")]
	end

	function ENT:Consume(ent)
		ent:Remove()
	end

	function ENT:StartBurning()
		self:SetFuel(self:GetFuel() - 1)
		self:SetBurnEnd(CurTime() + self.IncinerateTime)

		self:EmitSound("ambient/fire/ignite.wav", 80)

		self.FireSound = CreateSound(self, "ambient/fire/fire_med_loop1.wav")
		self.FireSound:PlayEx(0.8, 100)
	end

	function ENT:StopBurning()
		self:SetCorpses(0)
		self:SetBurnEnd(0)

		if self.FireSound then
			self.FireSound:Stop()
			self.FireSound = nil
		end

		self:EmitSound("ambient/fire/mtov_flame2.wav", 70)
	end

	function ENT:Think()
		if self.Burning and not self:IsBurning() then
			self.Burning = nil
			self:StopBurning()
		end

		local mouth = self:GetMouth()

		for _, ent in ipairs(ents.FindInSphere(mouth, 32)) do
			if IsFuel(ent) and self:GetFuel() < self.MaxFuel then
				self:Consume(ent)
				self:SetFuel(self:GetFuel() + 1)
				self:EmitSound("physics/metal/metal_barrel_impact_hard" .. math.random(3) .. ".wav", 75)
			elseif IsCorpse(ent) and not self:IsBurning() and self:GetCorpses() < self.MaxCorpses then
				self:Consume(ent)
				self:SetCorpses(self:GetCorpses() + 1)
				self:EmitSound("physics/body/body_medium_impact_soft" .. math.random(7) .. ".wav", 75)
			end
		end

		if not self:IsBurning() and self:GetCorpses() >= self.MaxCorpses and self:GetFuel() > 0 then
			self.Burning = true
			self:StartBurning()
		end

		self:NextThink(CurTime() + 0.2)
		return true
	end

	function ENT:OnTakeDamage(dmg)
		-- ломать бочку могут только зараженные (игроки или их NPC)
		local attacker = dmg:GetAttacker()
		local byInfected = IsValid(attacker) and ((attacker:IsPlayer() and attacker:Team() ~= 0) or attacker:IsNPC())
		if not byInfected then return 0 end

		self:SetHealth(self:Health() - dmg:GetDamage())
		self:EmitSound("physics/metal/metal_barrel_impact_hard" .. math.random(3) .. ".wav", 70)

		if self:Health() <= 0 then
			local effect = EffectData()
			effect:SetOrigin(self:GetPos())
			util.Effect("Explosion", effect)

			self:Remove()
		end

		return dmg:GetDamage()
	end

	function ENT:OnRemove()
		if self.FireSound then self.FireSound:Stop() end
	end

	return
end

local colLabel = Color(200, 90, 40)
local colFire = Color(255, 150, 60)

function ENT:Draw()
	self:DrawModel()

	if self:IsBurning() then self:FireEffects() end

	if LocalPlayer():GetPos():DistToSqr(self:GetPos()) > 250 * 250 then return end

	local pos = self:GetMouth() + Vector(0, 0, 20)
	local ang = Angle(0, LocalPlayer():EyeAngles().y - 90, 90)

	local status
	if self:IsBurning() then
		status = "Burning: " .. math.ceil(self:GetBurnEnd() - CurTime()) .. " s"
	elseif self:GetFuel() <= 0 then
		status = "Needs fuel: throw in gas cylinders or canisters"
	else
		status = "Throw in corpses"
	end

	cam.Start3D2D(pos, ang, 0.08)
		draw.SimpleTextOutlined("Corpse Incinerator", "DermaLarge", 0, 0, colLabel, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)
		draw.SimpleTextOutlined("Fuel: " .. self:GetFuel() .. " / " .. self.MaxFuel .. "    Corpses: " .. self:GetCorpses() .. " / " .. self.MaxCorpses, "DermaDefaultBold", 0, 30, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
		draw.SimpleTextOutlined(status, "DermaDefaultBold", 0, 48, self:IsBurning() and colFire or color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
	cam.End3D2D()
end

-- пламя и дым из горловины, оранжевый свет
function ENT:FireEffects()
	local mouth = self:GetMouth()

	local light = DynamicLight(self:EntIndex())
	if light then
		light.pos = mouth + Vector(0, 0, 16)
		light.r, light.g, light.b = 255, 130, 40
		light.brightness = 3 + math.sin(CurTime() * 12) * 0.5
		light.decay = 1000
		light.size = 260
		light.dietime = CurTime() + 0.2
	end

	if (self.NextFire or 0) > CurTime() then return end
	self.NextFire = CurTime() + 0.05

	local emitter = ParticleEmitter(mouth)
	if not emitter then return end

	for _ = 1, 2 do
		local particle = emitter:Add("particles/flamelet" .. math.random(5), mouth + VectorRand() * 8)
		if particle then
			particle:SetVelocity(Vector(math.Rand(-10, 10), math.Rand(-10, 10), math.Rand(60, 110)))
			particle:SetDieTime(math.Rand(0.4, 0.8))
			particle:SetStartAlpha(230)
			particle:SetEndAlpha(0)
			particle:SetStartSize(math.Rand(10, 16))
			particle:SetEndSize(2)
			particle:SetRoll(math.Rand(0, 360))
			particle:SetRollDelta(math.Rand(-2, 2))
		end
	end

	if math.random(3) == 1 then
		local smoke = emitter:Add("particle/smokesprites_000" .. math.random(9), mouth + Vector(0, 0, 30))
		if smoke then
			smoke:SetVelocity(Vector(math.Rand(-15, 15), math.Rand(-15, 15), math.Rand(40, 70)))
			smoke:SetDieTime(math.Rand(2, 3.5))
			smoke:SetStartAlpha(90)
			smoke:SetEndAlpha(0)
			smoke:SetStartSize(12)
			smoke:SetEndSize(50)
			smoke:SetColor(40, 40, 40)
			smoke:SetRoll(math.Rand(0, 360))
		end
	end

	emitter:Finish()
end
