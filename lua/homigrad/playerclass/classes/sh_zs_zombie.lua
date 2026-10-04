local CLASS = player.RegClass("zs_zombie")

-- Зараженный из режима Zombie Survival: классический зомби без хедкраба, режущие кулаки (см. clawClasses в weapon_hands_sh)
-- NPC-модель models/Zombie/Classic.mdl не подходит: в ней нет костей игрока (Bip01_Neck1 и др.), на которых держатся камера и удары,
-- поэтому используется игровая версия той же модели
local ZOMBIE_MODEL = "models/zcity/player/zombie_classic.mdl"
local BODYGROUP_HEADCRAB = 1

CLASS.CanUseDefaultPhrase = false
CLASS.CanEmitRNDSound = false
CLASS.CanUseGestures = false
CLASS.NoGloves = true

local clr_zombie = Color(90, 20, 20)

function CLASS.On(self)
	if CLIENT then return end

	self:SetNWString("PlayerName", "Infected")
	self:SetNetVar("Accessories", "")

	self:SetModel(ZOMBIE_MODEL)
	self:SetSubMaterial()
	self:SetSkin(0)
	self:SetBodygroup(BODYGROUP_HEADCRAB, 0)
	self:SetPlayerColor(clr_zombie:ToVector())

	hg.SetArmorRestrictions(self, {all = true})

	local hands = self:HasWeapon("weapon_hands_sh") and self:GetWeapon("weapon_hands_sh") or self:Give("weapon_hands_sh")
	if IsValid(hands) then
		self:SelectWeapon("weapon_hands_sh")
	end
end

function CLASS.Off(self)
	if CLIENT then return end

	hg.ClearArmorRestrictions(self)
end

function CLASS.Think(self)
	if CLIENT then return end

	-- зараженные дерутся только руками, кулаки всегда подняты
	local wep = self:GetActiveWeapon()
	if IsValid(wep) and wep:GetClass() ~= "weapon_hands_sh" then
		if self:HasWeapon("weapon_hands_sh") then
			self:SelectWeapon("weapon_hands_sh")
		else
			self:Give("weapon_hands_sh")
			self:SelectWeapon("weapon_hands_sh")
		end
	elseif IsValid(wep) and wep.GetFists and not wep:GetFists() and not (wep.GetCarrying and wep:GetCarrying()) then
		wep:SetFists(true)
	end

	local org = self.organism
	if not org then return end

	org.stamina["max"] = 200
	org.stamina["range"] = 200

	if org.consciousness <= 0.3 then
		org.consciousness = 1
		org.needotrub = false
	end

	org.jawdislocation = false
	org.llegdislocation = false
	org.rlegdislocation = false
	org.rarmdislocation = false
	org.larmdislocation = false
end

local zomb_pain = {"npc/zombie/zombie_die2.wav"}
for i = 1, 6 do
	table.insert(zomb_pain, "npc/zombie/zombie_pain" .. i .. ".wav")
end

local zomb_phrases = {}
for i = 1, 3 do
	table.insert(zomb_phrases, "npc/zombie/zombie_alert" .. i .. ".wav")
end
for i = 1, 14 do
	table.insert(zomb_phrases, "npc/zombie/zombie_voice_idle" .. i .. ".wav")
end

hook.Add("HG_ReplacePhrase", "ZS_ZombiePhrases", function(ply, phrase, muffed, pitch)
	if ply.PlayerClassName == "zs_zombie" then
		local inpain = ply.organism and ply.organism.pain > 30
		local phr = inpain and zomb_pain[math.random(#zomb_pain)] or zomb_phrases[math.random(#zomb_phrases)]

		return ply, phr, not inpain, pitch
	end
end)

hook.Add("HG_CanThoughts", "ZS_ZombieThoughts", function(ply)
	if ply.PlayerClassName == "zs_zombie" then
		return false
	end
end)

hook.Add("PlayerCanPickupWeapon", "ZS_ZombiePickup", function(ply, ent)
	if IsValid(ply) and ply.PlayerClassName == "zs_zombie" and ent:GetClass() ~= "weapon_hands_sh" then
		return false
	end
end)

hook.Add("CanPlayerEnterVehicle", "ZS_ZombieVehicle", function(ply, ent)
	if ply.PlayerClassName == "zs_zombie" then
		return false
	end
end)

hook.Add("PlayerCanLegAttack", "ZS_ZombieKick", function(ply)
	if ply.PlayerClassName == "zs_zombie" then
		return false
	end
end)

if SERVER then
	hook.Add("ZB_CanLootInventory", "ZS_ZombieLoot", function(ply, ent, canloot)
		if ply.PlayerClassName == "zs_zombie" then
			return ply, ent, false
		end
	end)
end

hook.Add("CalcMainActivity", "ZS_ZombieAnims", function(ply, vel)
	if ply.PlayerClassName ~= "zs_zombie" then return end

	local anim = ACT_HL2MP_RUN_ZOMBIE
	if vel:LengthSqr() <= 0 then
		anim = ACT_HL2MP_IDLE_ZOMBIE
	end
	if ply:IsFlagSet(FL_ANIMDUCKING) then
		anim = ACT_HL2MP_WALK_CROUCH_ZOMBIE_01
	end
	if not ply:IsOnGround() and ply:GetMoveType() ~= MOVETYPE_NOCLIP then
		anim = ACT_HL2MP_JUMP_SLAM
	end

	return anim, -1
end)

if CLIENT then
	-- у модели зомби голова опущена вперед, камеру переносим к верху торса (как у headcrabzombie)
	hook.Add("HGAddView", "ZS_ZombieView", function(ply, origin, angles)
		if not ply:Alive() or ply.PlayerClassName ~= "zs_zombie" then return end

		local spine = ply:LookupBone("ValveBiped.Bip01_Spine4")
		if not spine then return end

		local mat = ply:GetBoneMatrix(spine)
		if not mat then return end

		local spineAng = mat:GetAngles()
		origin = origin + spineAng:Right() * -8 + spineAng:Forward() * -2

		return ply, origin, angles
	end)
end
