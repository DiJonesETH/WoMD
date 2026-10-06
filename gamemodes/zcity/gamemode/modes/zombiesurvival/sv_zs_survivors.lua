local MODE = MODE

-- Очки выживших (SURVIVOR POINTS): тратятся в магазинах ящиков снабжения (lua/entities/zs_supply_box.lua).
-- 1 очко в секунду живым выжившим и SurvivorKillPoints за убийство зараженного.
MODE.SurvivorPassivePoints = 1
MODE.SurvivorKillPoints = 50
MODE.SurvivorKillCreditTime = 15 -- секунд: урон выжившего по зараженному засчитывает убийство

local TEAM_SURVIVORS = 0

function MODE.AddSurvivorPoints(ply, amount)
	amount = math.floor(amount)
	if amount <= 0 then return end

	ply:SetNWInt("ZS_SPoints", ply:GetNWInt("ZS_SPoints", 0) + amount)
end

function MODE.ResetSurvivorPoints()
	for _, ply in player.Iterator() do
		ply:SetNWInt("ZS_SPoints", 0)
	end
end

timer.Create("ZS_SurvivorPassivePoints", 1, 0, function()
	local mode = CurrentRound()
	if zb.ROUND_STATE ~= 1 or not mode or mode.name ~= "zs" or not mode.saved.StartTime then return end

	for _, ply in player.Iterator() do
		if ply:Alive() and ply:Team() == TEAM_SURVIVORS then
			mode.AddSurvivorPoints(ply, mode.SurvivorPassivePoints)
		end
	end
end)

-- последний выживший, ранивший зараженного: ему засчитывается убийство, даже если зараженный умер позже
hook.Add("HomigradDamage", "ZS_SurvivorKillCredit", function(ent, dmgInfo)
	local mode = CurrentRound()
	if zb.ROUND_STATE ~= 1 or not mode or mode.name ~= "zs" then return end

	local attacker = dmgInfo:GetAttacker()
	if not IsValid(attacker) or not attacker:IsPlayer() or attacker:Team() ~= TEAM_SURVIVORS then return end

	local victim = IsValid(ent) and (ent:IsPlayer() and ent or hg.RagdollOwner(ent))
	if not IsValid(victim) or not victim:IsPlayer() or not ZS_IsZombie(victim) then return end

	victim.zs_LastSurvivorHit = attacker
	victim.zs_LastSurvivorHitTime = CurTime()
end)

-- вызывается из MODE:PlayerDeath (sv_zs.lua) для погибшего зараженного
function MODE:RewardZombieKill(ply, attacker)
	local killer = IsValid(attacker) and attacker:IsPlayer() and attacker:Team() == TEAM_SURVIVORS and attacker

	if not killer and IsValid(ply.zs_LastSurvivorHit) and CurTime() - (ply.zs_LastSurvivorHitTime or 0) <= self.SurvivorKillCreditTime then
		killer = ply.zs_LastSurvivorHit
	end

	ply.zs_LastSurvivorHit = nil

	if not killer or not killer:Alive() or killer:Team() ~= TEAM_SURVIVORS then return end

	self.AddSurvivorPoints(killer, self.SurvivorKillPoints)
	killer:ChatPrint("+" .. self.SurvivorKillPoints .. " survivor points: " .. ply:Name() .. " killed")
end
