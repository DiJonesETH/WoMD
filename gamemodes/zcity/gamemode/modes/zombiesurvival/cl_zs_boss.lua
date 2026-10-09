-- Босс-гоном на клиенте (сервер: sv_zs_boss.lua).
-- Скелет гонома из Half-Life (Bip01 ...) не совпадает с ValveBiped, поэтому bonemerge невозможен: модель гонома -
-- отдельная "кукла" поверх скрытой модели игрока, ее анимации (ходьба, бег, атаки, прыжок, вздрагивание)
-- выбираются по движению и действиям игрока.

local GONOME_MODEL = "models/vj_hlr/opfor/gonome.mdl"
local colBoss = Color(200, 170, 40)
local colBar = Color(200, 40, 30)
local colBack = Color(0, 0, 0, 200)

local puppets = {}

-- последовательность с плавным временем: циклы накапливают cycle по времени кадра (скорость анимации
-- меняется без скачков), разовые анимации (атака, вздрагивание) идут от момента начала
local function SetSeq(puppet, name)
	local seq = puppet:LookupSequence(name)
	if seq < 0 then return end

	if puppet.zs_Seq ~= seq then
		puppet.zs_Seq = seq
		puppet.zs_Cycle = 0
		puppet:ResetSequence(seq)
	end

	return seq
end

local function LoopSeq(puppet, name, rate, dt)
	local seq = SetSeq(puppet, name)
	if not seq then return end

	local duration = math.max(puppet:SequenceDuration(seq), 0.01)
	puppet.zs_Cycle = (puppet.zs_Cycle + dt * rate / duration) % 1
	puppet:SetCycle(puppet.zs_Cycle)
end

local function OneShotSeq(puppet, name, start, rate)
	local seq = SetSeq(puppet, name)
	if not seq then return end

	local duration = math.max(puppet:SequenceDuration(seq), 0.01)
	puppet:SetCycle(math.Clamp((CurTime() - start) * (rate or 1) / duration, 0, 1))
end

-- идет ли еще разовая анимация с NW-временем начала key
local function OneShotActive(ply, puppet, key, name, rate)
	local start = ply:GetNWFloat(key, 0)
	local seq = puppet:LookupSequence(name)
	if start <= 0 or seq < 0 then return end

	if (CurTime() - start) * (rate or 1) < puppet:SequenceDuration(seq) then return start end
end

local function Animate(ply, puppet, dt)
	-- сглаженная скорость и гистерезис между шагом и бегом: без мерцания анимаций
	puppet.zs_Vel = Lerp(math.min(dt * 8, 1), puppet.zs_Vel or 0, ply:GetVelocity():Length2D())
	local vel = puppet.zs_Vel

	local attackSeq = "attack" .. ply:GetNWInt("ZS_GonomeAttackSeq", 1)
	local attackStart = OneShotActive(ply, puppet, "ZS_GonomeAttack", attackSeq, 1.4)
	if attackStart then return OneShotSeq(puppet, attackSeq, attackStart, 1.4) end

	local flinchStart = OneShotActive(ply, puppet, "ZS_GonomeFlinch", "small_flinch")
	if flinchStart then return OneShotSeq(puppet, "small_flinch", flinchStart) end

	if not ply:OnGround() then
		SetSeq(puppet, "jump1")
		puppet:SetCycle(0.35)
		return
	end

	local running = vel > 170 or (puppet.zs_Running and vel > 130)
	puppet.zs_Running = running

	if running then return LoopSeq(puppet, "runshort", math.Clamp(vel / 260, 0.6, 1.6), dt) end
	if vel > 12 then return LoopSeq(puppet, "walk", math.Clamp(vel / 90, 0.5, 1.8), dt) end

	LoopSeq(puppet, "idle1", 1, dt)
end

-- позиция и анимация обновляются прямо перед отрисовкой (интерполированная позиция игрока), один раз за кадр
local function PuppetRender(self)
	local ply = self.zs_Owner

	if IsValid(ply) and self.zs_Frame ~= FrameNumber() then
		self.zs_Frame = FrameNumber()

		local dt = math.min(RealTime() - (self.zs_LastTime or RealTime()), 0.1)
		self.zs_LastTime = RealTime()

		self.zs_Yaw = self.zs_Yaw and math.ApproachAngle(self.zs_Yaw, ply:EyeAngles().y, dt * 540) or ply:EyeAngles().y

		self:SetPos(ply:GetPos())
		self:SetAngles(Angle(0, self.zs_Yaw, 0))
		Animate(ply, self, dt)
		self:SetupBones()
	end

	self:DrawModel()
end

local function GetPuppet(ply)
	local puppet = puppets[ply]

	if not IsValid(puppet) then
		puppet = ClientsideModel(GONOME_MODEL, RENDERGROUP_OPAQUE)
		if not IsValid(puppet) then return end

		puppet.zs_Owner = ply
		puppet.RenderOverride = PuppetRender
		puppet:SetPos(ply:GetPos())
		puppets[ply] = puppet
	end

	return puppet
end

local function RemovePuppet(ply)
	if IsValid(puppets[ply]) then puppets[ply]:Remove() end
	puppets[ply] = nil
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
	end
end)

-- классическая камера от первого лица: от глаз игрока (высота гонома - его view offset), без камеры homigrad по кости
hook.Add("HG_OverrideView", "ZS_BossView", function(ply, view)
	if not ZS_IsBoss(ply) or not ply:Alive() or (hg_thirdperson and hg_thirdperson:GetBool()) then return end

	view.origin = ply:EyePos()
	view.angles = ply:EyeAngles()
	view.drawviewer = false

	return view
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
		OneShotSeq(corpse, name, start)
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
