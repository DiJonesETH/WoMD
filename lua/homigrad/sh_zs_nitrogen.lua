-- Заморозка зараженных азотной гранатой Zombie Survival (lua/entities/ent_zs_grenade_nitrogen.lua):
-- замороженный (NWFloat ZS_FrozenUntil) стоит на месте и не атакует, у него на экране синий фильтр

function ZS_IsFrozen(ply)
	return ply:GetNWFloat("ZS_FrozenUntil", 0) > CurTime()
end

hook.Add("Move", "ZS_NitrogenFreeze", function(ply, mv)
	if not ZS_IsFrozen(ply) then return end

	local vel = mv:GetVelocity()
	mv:SetVelocity(Vector(0, 0, math.min(vel.z, 0)))
	mv:SetForwardSpeed(0)
	mv:SetSideSpeed(0)
	mv:SetUpSpeed(0)
end)

hook.Add("StartCommand", "ZS_NitrogenFreeze", function(ply, cmd)
	if not ZS_IsFrozen(ply) then return end

	cmd:RemoveKey(IN_ATTACK)
	cmd:RemoveKey(IN_ATTACK2)
	cmd:RemoveKey(IN_JUMP)
	cmd:RemoveKey(IN_USE)
	cmd:RemoveKey(IN_RELOAD)
end)

if SERVER then
	function ZS_Freeze(ply, time)
		ply:SetNWFloat("ZS_FrozenUntil", CurTime() + time)
		ply:SetVelocity(-ply:GetVelocity())
		ply:EmitSound("physics/glass/glass_sheet_step" .. math.random(4) .. ".wav", 75, 70)
	end

	hook.Add("PlayerSpawn", "ZS_NitrogenFreeze", function(ply)
		ply:SetNWFloat("ZS_FrozenUntil", 0)
	end)

	return
end

-- синий фильтр у замороженного
hook.Add("RenderScreenspaceEffects", "ZS_NitrogenFreeze", function()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then return end

	local left = ply:GetNWFloat("ZS_FrozenUntil", 0) - CurTime()
	if left <= 0 then return end

	local frac = math.Clamp(left / 0.5, 0, 1) -- плавно уходит в последние полсекунды

	DrawColorModify({
		["$pp_colour_addr"] = 0,
		["$pp_colour_addg"] = 0.03 * frac,
		["$pp_colour_addb"] = 0.18 * frac,
		["$pp_colour_brightness"] = 0.02 * frac,
		["$pp_colour_contrast"] = 1,
		["$pp_colour_colour"] = 1 - 0.6 * frac,
		["$pp_colour_mulr"] = 0,
		["$pp_colour_mulg"] = 0,
		["$pp_colour_mulb"] = 0.4 * frac,
	})
end)
