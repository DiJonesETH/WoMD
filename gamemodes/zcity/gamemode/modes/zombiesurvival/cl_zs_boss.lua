-- Босс-гоном на клиенте (сервер: sv_zs_boss.lua).
-- Скелет гонома из Half-Life (Bip01 ...) не совпадает с ValveBiped, поэтому bonemerge невозможен: модель гонома -
-- отдельная "кукла" поверх скрытой модели игрока, ее анимации (ходьба, бег, атаки, прыжок, вздрагивание)
-- выбираются по движению и действиям игрока.

local GONOME_MODEL = "models/vj_hlr/opfor/gonome.mdl"
local colBoss = Color(200, 170, 40)
local colBar = Color(200, 40, 30)
local colBack = Color(0, 0, 0, 200)

local puppets = {}

local function GetPuppet(ply)
	local puppet = puppets[ply]

	if not IsValid(puppet) then
		puppet = ClientsideModel(GONOME_MODEL, RENDERGROUP_OPAQUE)
		if not IsValid(puppet) then return end

		puppets[ply] = puppet
	end

	return puppet
end

local function RemovePuppet(ply)
	if IsValid(puppets[ply]) then puppets[ply]:Remove() end
	puppets[ply] = nil
end

-- последовательность и ее время: разовые анимации (атака, вздрагивание) по времени начала, циклы - по CurTime
local function PlaySeq(puppet, name, start, rate, loop)
	local seq = puppet:LookupSequence(name)
	if seq < 0 then return end

	if puppet:GetSequence() ~= seq then puppet:ResetSequence(seq) end

	local duration = math.max(puppet:SequenceDuration(seq), 0.01)
	local t = (CurTime() - (start or 0)) * (rate or 1) / duration

	puppet:SetCycle(loop and t % 1 or math.Clamp(t, 0, 1))
	return duration / (rate or 1)
end

local function OneShotLeft(ply, key, seqName, puppet)
	local start = ply:GetNWFloat(key, 0)
	local seq = puppet:LookupSequence(seqName)
	if seq < 0 or start <= 0 then return end

	if CurTime() - start < puppet:SequenceDuration(seq) then return start end
end

local function Animate(ply, puppet)
	local vel = ply:GetVelocity():Length2D()

	local attackSeq = "attack" .. ply:GetNWInt("ZS_GonomeAttackSeq", 1)
	local attackStart = OneShotLeft(ply, "ZS_GonomeAttack", attackSeq, puppet)
	if attackStart then return PlaySeq(puppet, attackSeq, attackStart, 1.4) end

	local flinchStart = OneShotLeft(ply, "ZS_GonomeFlinch", "small_flinch", puppet)
	if flinchStart then return PlaySeq(puppet, "small_flinch", flinchStart) end

	if not ply:OnGround() then
		local seq = puppet:LookupSequence("jump1")
		if puppet:GetSequence() ~= seq then puppet:ResetSequence(seq) end
		puppet:SetCycle(0.35)
		return
	end

	if vel > 150 then return PlaySeq(puppet, "runshort", 0, vel / 260, true) end
	if vel > 10 then return PlaySeq(puppet, "walk", 0, math.max(vel / 90, 0.4), true) end

	PlaySeq(puppet, "idle1", 0, 1, true)
end

hook.Add("Think", "ZS_BossPuppets", function()
	for ply, puppet in pairs(puppets) do
		if not IsValid(ply) or not ZS_IsBoss(ply) or not ply:Alive() then RemovePuppet(ply) end
	end

	for _, ply in player.Iterator() do
		if not ZS_IsBoss(ply) or not ply:Alive() then continue end

		local puppet = GetPuppet(ply)
		if not IsValid(puppet) then continue end

		-- свою модель в первом лице не рисуем
		local firstPerson = ply == LocalPlayer() and GetViewEntity() == ply and not (hg_thirdperson and hg_thirdperson:GetBool())
		puppet:SetNoDraw(firstPerson or ply:IsDormant())

		puppet:SetPos(ply:GetPos())
		puppet:SetAngles(Angle(0, ply:EyeAngles().y, 0))
		Animate(ply, puppet)
	end
end)

-- появление босса
local riseText, riseEnd = nil, 0

net.Receive("zs_boss_rise", function()
	local ply = net.ReadEntity()

	riseText = "A GONOME HAS RISEN"
	riseEnd = CurTime() + 4

	chat.AddText(colBar, "[Boss] ", color_white, (IsValid(ply) and ply:Nick() or "Someone") .. " has turned into a Gonome!")
	surface.PlaySound("vj_hlr/gsrc/npc/gonome/gonome_idle" .. math.random(3) .. ".wav")
end)

-- предсмертная анимация: модель доигрывает смерть и остается лежать
local deathSeqs = {"diebackward", "dieforward", "diesimple"}

net.Receive("zs_boss_death", function()
	local pos, yaw = net.ReadVector(), net.ReadFloat()

	local corpse = ClientsideModel(GONOME_MODEL, RENDERGROUP_OPAQUE)
	if not IsValid(corpse) then return end

	corpse:SetPos(pos)
	corpse:SetAngles(Angle(0, yaw, 0))

	local name = deathSeqs[math.random(#deathSeqs)]
	local start = CurTime()

	local hookName = "ZS_BossCorpse" .. tostring(corpse)
	hook.Add("Think", hookName, function()
		if not IsValid(corpse) then hook.Remove("Think", hookName) return end
		PlaySeq(corpse, name, start)
	end)

	timer.Simple(20, function()
		hook.Remove("Think", hookName)
		if IsValid(corpse) then corpse:Remove() end
	end)
end)

-- полоска здоровья босса для всех
hook.Add("HUDPaint", "ZS_BossHealth", function()
	local boss = GetGlobalEntity("ZS_Boss")

	if IsValid(boss) and ZS_IsBoss(boss) and boss:Alive() then
		local hp, maxHp = boss:GetNWInt("ZS_BossHP", 0), math.max(boss:GetNWInt("ZS_BossMaxHP", 1), 1)
		local w, h = math.min(ScrW() * 0.4, 600), 14
		local x, y = ScrW() * 0.5 - w * 0.5, 40

		draw.SimpleTextOutlined("GONOME", "DermaLarge", ScrW() * 0.5, y - 6, colBoss, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 2, color_black)
		draw.RoundedBox(2, x - 2, y - 2, w + 4, h + 4, colBack)
		draw.RoundedBox(2, x, y, w * math.Clamp(hp / maxHp, 0, 1), h, colBar)
		draw.SimpleTextOutlined(hp .. " / " .. maxHp, "DermaDefaultBold", ScrW() * 0.5, y + h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
	end

	if riseText and riseEnd > CurTime() then
		local alpha = math.Clamp((riseEnd - CurTime()) / 1, 0, 1) * 255
		draw.SimpleTextOutlined(riseText, "ZB_HomicideMediumLarge", ScrW() * 0.5, ScrH() * 0.3, ColorAlpha(colBar, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, ColorAlpha(color_black, alpha))
	end
end)
