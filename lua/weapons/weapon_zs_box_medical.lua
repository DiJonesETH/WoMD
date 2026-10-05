if SERVER then AddCSLuaFile() end

-- ящик снабжения выживших, см. weapon_zs_supplybox.lua и sh_zs_supplyboxes.lua
SWEP.Base = "weapon_zs_supplybox"
SWEP.BoxType = "medical"
SWEP.Spawnable = true
SWEP.AdminOnly = true
SWEP.WorldModel = ZS_SUPPLY_BOXES and ZS_SUPPLY_BOXES.medical and ZS_SUPPLY_BOXES.medical.model or "models/props/de_prodigy/ammo_can_01.mdl"
