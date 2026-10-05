AddCSLuaFile()

-- Установленный ящик снабжения выживших (арсенальный, медицинский, технический), см. sh_zs_supplyboxes.lua.
-- Заморожен на месте, ломается только зараженными, по E раз в 2 минуты выдает игроку свои предметы
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Supply Box"
ENT.Spawnable = false

ENT.MaxHealth = 300

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "BoxType")
end

if SERVER then
	function ENT:Initialize()
		local info = ZS_SUPPLY_BOXES[self:GetBoxType()] or ZS_SUPPLY_BOXES.arsenal

		self:SetModel(info.model)
		self:SetColor(info.color)

		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then phys:EnableMotion(false) end

		self:SetHealth(self.MaxHealth)
		self:SetMaxHealth(self.MaxHealth)

		self.NextUse = {}
	end

	local function Notify(ply, text)
		if ply.Notify then ply:Notify(text, 0, "zs_supplybox", 3) else ply:ChatPrint(text) end
	end

	local function GiveItem(ply, class)
		local wep = ply:HasWeapon(class) and ply:GetWeapon(class) or ply:Give(class)
		return wep
	end

	local giveFuncs = {
		-- 3 магазина к калибру оружия в руках
		arsenal = function(ply)
			local wep = ply:GetActiveWeapon()
			local ammoType = IsValid(wep) and wep:GetPrimaryAmmoType() or -1
			local clip = IsValid(wep) and wep:GetMaxClip1() or 0

			if ammoType < 0 or clip <= 0 then
				Notify(ply, "Возьмите в руки огнестрельное оружие")
				return false
			end

			ply:GiveAmmo(clip * 3, ammoType)
			Notify(ply, "Получено 3 магазина (" .. (game.GetAmmoName(ammoType) or "?") .. ")")

			return true
		end,

		-- 3 случайных медицинских предмета
		medical = function(ply)
			for _ = 1, 3 do
				GiveItem(ply, ZS_MEDICAL_ITEMS[math.random(#ZS_MEDICAL_ITEMS)])
			end

			Notify(ply, "Получены медикаменты")
			return true
		end,

		-- скотч, молоток (если его нет) и 32 гвоздя
		tech = function(ply)
			GiveItem(ply, "weapon_ducttape")

			if not ply:HasWeapon("weapon_hammer") then
				ply:Give("weapon_hammer")
			end

			ply:GiveAmmo(32, "Nails")
			Notify(ply, "Получены скотч, молоток и гвозди")

			return true
		end,
	}

	function ENT:Use(ply)
		if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() or ply:Team() ~= 0 then return end

		local id = ply:SteamID64() or ply:EntIndex()
		local left = (self.NextUse[id] or 0) - CurTime()

		if left > 0 then
			ZS_NotifyOnce(ply, "supplybox_cooldown", "Ящик снабжения выдает предметы раз в 2 минуты")
			return
		end

		local give = giveFuncs[self:GetBoxType()]
		if give and give(ply) then
			self.NextUse[id] = CurTime() + ZS_SUPPLY_BOX_COOLDOWN
			self:EmitSound("items/ammocrate_open.wav", 65)
		end
	end

	function ENT:OnTakeDamage(dmg)
		-- ломать ящики могут только зараженные (игроки или их NPC)
		local attacker = dmg:GetAttacker()
		local byInfected = IsValid(attacker) and ((attacker:IsPlayer() and attacker:Team() ~= 0) or attacker:IsNPC())
		if not byInfected then return 0 end

		self:SetHealth(self:Health() - dmg:GetDamage())
		self:EmitSound("physics/wood/wood_crate_impact_hard" .. math.random(4) .. ".wav", 70)

		if self:Health() <= 0 then
			self:EmitSound("physics/wood/wood_crate_break" .. math.random(5) .. ".wav", 80)

			local effect = EffectData()
			effect:SetOrigin(self:GetPos())
			util.Effect("cball_explode", effect)

			self:Remove()
		end

		return dmg:GetDamage()
	end
else
	function ENT:Draw()
		self:DrawModel()

		if LocalPlayer():GetPos():DistToSqr(self:GetPos()) > 250 * 250 then return end

		local info = ZS_SUPPLY_BOXES[self:GetBoxType()]
		if not info then return end

		local pos = self:GetPos() + Vector(0, 0, self:OBBMaxs().z + 12)
		local ang = Angle(0, LocalPlayer():EyeAngles().y - 90, 90)

		cam.Start3D2D(pos, ang, 0.08)
			draw.SimpleTextOutlined(info.name, "DermaLarge", 0, 0, info.color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)
			draw.SimpleTextOutlined("E - взять", "DermaDefaultBold", 0, 30, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
		cam.End3D2D()
	end
end
