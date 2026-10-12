if SERVER then AddCSLuaFile() end

-- лотерейный ящик выживших, см. weapon_zs_supplybox.lua и lua/entities/zs_lottery.lua
SWEP.Base = "weapon_zs_supplybox"
SWEP.BoxType = "lottery"
SWEP.Spawnable = true
SWEP.AdminOnly = true
SWEP.WorldModel = ""
