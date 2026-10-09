if SERVER then AddCSLuaFile() end

-- Азотная граната Zombie Survival на основе РГД-5 (те же модель и анимации броска)
SWEP.Base = "weapon_hg_rgd_tpik"
SWEP.PrintName = "Liquid Nitrogen Grenade"
SWEP.Instructions = [[An RGD-5 body filled with liquid nitrogen. It bursts on impact with no shrapnel or blast, releasing a cloud of liquid nitrogen that quickly dissipates. Infected caught in the cloud freeze in place for 3 seconds.

LMB - High ready
While high ready:
RMB to remove spoon.
Reload to insert pin back.

RMB - Low ready
While low ready:
LMB to remove spoon.
Reload to insert pin back.
]]
SWEP.Category = "ZCity Other"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.ENT = "ent_zs_grenade_nitrogen"
