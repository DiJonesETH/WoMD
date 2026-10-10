AddCSLuaFile()

-- Турель выживших Zombie Survival (настройки видов: lua/homigrad/sh_zs_turrets.lua).
-- Медленно поворачивается (с электрическим звуком сервопривода) к ближайшему видимому зараженному в секторе
-- 180 градусов перед собой и стреляет ему в грудь пулями homigrad. Лазерный прицел рисует клиент.
-- Ломается только зараженными. По E - окно состояния с покупкой починки, зарядки и боезапаса.
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Turret"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH -- непрозрачная модель и прозрачный лазер

ENT.MaxHealth = 400
ENT.MaxBattery = 100
ENT.Range = 2500
ENT.Arc = 90 -- половина сектора обстрела
ENT.TurnSpeed = 70 -- градусов в секунду по горизонтали
ENT.PitchSpeed = 50
ENT.MaxPitch = 50
ENT.AimTolerance = 4 -- стреляет, когда прицел отклонен от цели не больше чем на столько градусов
ENT.IdleDrain = 1 / 6 -- расход аккумулятора в секунду в ожидании (100% хватает на 10 минут)
ENT.ActiveDrain = 0.5 -- расход при наведении на цель (100% хватает на 3-4 минуты боя)

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "BoxType")
	self:NetworkVar("Int", 0, "Ammo")
	self:NetworkVar("Float", 0, "Battery")
	self:NetworkVar("Float", 1, "ReloadEnd")
	self:NetworkVar("Float", 2, "AimPitch")
	self:NetworkVar("Bool", 0, "HasTarget")
end

function ENT:GetConfig()
	return ZS_TURRETS[self:GetBoxType()] or ZS_TURRETS.turret_smg
end

function ENT:IsReloading()
	return self:GetReloadEnd() > CurTime()
end

function ENT:IsPowered()
	return self:GetBattery() > 0
end

-- ствол турели: точка вылета пули и начала лазера
function ENT:GetMuzzle()
	local id = self:LookupAttachment("eyes")
	local att = id and id > 0 and self:GetAttachment(id)
	if att then return att.Pos end

	return self:LocalToWorld(Vector(12, 0, 46))
end

function ENT:GetAimDir()
	return Angle(self:GetAimPitch(), self:GetAngles().y, 0):Forward()
end

-- грудь цели (зараженный или его регдолл)
local function ChestPos(ent)
	local bone = ent:LookupBone("ValveBiped.Bip01_Spine2")
	local pos = bone and ent:GetBonePosition(bone)

	return pos or ent:WorldSpaceCenter()
end

if SERVER then
	util.AddNetworkString("zs_turret_open")
	util.AddNetworkString("zs_turret_buy")

	function ENT:Initialize()
		self:SetModel(ZS_TURRET_MODEL)

		-- коллизия - коробка, она не зависит от поворота турели
		local mins, maxs = self:OBBMins(), self:OBBMaxs()
		local half = math.max(maxs.x - mins.x, maxs.y - mins.y) * 0.35
		self:SetSolid(SOLID_BBOX)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetCollisionBounds(Vector(-half, -half, mins.z), Vector(half, half, maxs.z))
		self:SetUseType(SIMPLE_USE)

		local seq = self:LookupSequence("idlealert")
		if seq < 0 then seq = self:LookupSequence("idle") end
		if seq >= 0 then self:ResetSequence(seq) end

		self:SetHealth(self.MaxHealth)
		self:SetMaxHealth(self.MaxHealth)
		self:SetAmmo(self:GetConfig().maxAmmo)
		self:SetBattery(self.MaxBattery)

		self.BaseYaw = self:GetAngles().y
		self.AimYaw = 0
		self.NextFire = 0
		self.NextSearch = 0
		self.LastThink = CurTime()

		self:EmitSound("npc/turret_floor/deploy.wav", 70)
	end

	-- стрелок для зачета убийств: выживший, поставивший турель
	function ENT:GetShooter()
		local ply = self.ZSDeployer
		if IsValid(ply) and ply:IsPlayer() and ply:Team() == 0 then return ply end

		return self
	end

	local function IsTargetable(ply)
		return IsValid(ply) and ply:IsPlayer() and ply:Alive() and ZS_IsZombie and ZS_IsZombie(ply)
	end

	-- видна ли цель из ствола (первое, во что попадает луч - сам зараженный или его регдолл)
	function ENT:CanSee(ply, body, chest)
		local tr = util.TraceLine({
			start = self:GetMuzzle(),
			endpos = chest,
			filter = self,
			mask = MASK_SHOT,
		})

		if not tr.Hit then return true end

		local hit = tr.Entity
		return hit == ply or hit == body or (IsValid(hit) and hg.RagdollOwner and hg.RagdollOwner(hit) == ply)
	end

	-- угол на точку относительно направления установки турели
	function ENT:RelativeAngles(pos)
		local ang = (pos - self:GetMuzzle()):Angle()
		return math.AngleDifference(ang.y, self.BaseYaw), math.NormalizeAngle(ang.p)
	end

	function ENT:FindTarget()
		local best, bestBody, bestDist

		for _, ply in player.Iterator() do
			if not IsTargetable(ply) then continue end

			local body = IsValid(ply.FakeRagdoll) and ply.FakeRagdoll or ply
			local chest = ChestPos(body)
			local dist = chest:DistToSqr(self:GetPos())

			if dist <= self.Range ^ 2 and (not bestDist or dist < bestDist) then
				local yaw, pitch = self:RelativeAngles(chest)

				if math.abs(yaw) <= self.Arc and math.abs(pitch) <= self.MaxPitch and self:CanSee(ply, body, chest) then
					best, bestBody, bestDist = ply, body, dist
				end
			end
		end

		return best, bestBody
	end

	function ENT:ServoSound(moving)
		if moving then
			if not self.Servo then
				self.Servo = CreateSound(self, "npc/roller/mine/rmine_moveslow_loop1.wav")
				self.Servo:PlayEx(0.6, 140)
			end
		elseif self.Servo then
			self.Servo:FadeOut(0.2)
			self.Servo = nil
		end
	end

	function ENT:Shoot(cfg)
		local settings = hg.ammotypeshuy and hg.ammotypeshuy[cfg.ammo] and hg.ammotypeshuy[cfg.ammo].BulletSettings or {}
		local muzzle = self:GetMuzzle()

		local bullet = {
			Src = muzzle,
			Dir = self:GetAimDir(),
			Spread = Vector(cfg.spread, cfg.spread, 0),
			Num = settings.NumBullet or 1,
			Damage = settings.Damage or 25,
			Force = (settings.Force or 25) / 1.5,
			Penetration = settings.Penetration or 5,
			Diameter = settings.Diameter or 5,
			MaxPenLen = 100,
			penetrated = 0,
			AmmoType = cfg.ammo,
			Attacker = self:GetShooter(),
			Inflictor = self,
			Filter = {self},
			Tracer = 1,
			TracerName = "Tracer",
			DisableLagComp = true,
		}

		-- дробь: каждая дробина - отдельная пуля homigrad
		local pellets = bullet.Num
		bullet.Num = 1

		for _ = 1, pellets do
			self:FireLuaBullets(table.Copy(bullet))
		end

		self:SetAmmo(self:GetAmmo() - 1)
		self:EmitSound(cfg.sound, 85, math.random(95, 105), 1, CHAN_WEAPON)

		local effect = EffectData()
		effect:SetEntity(self)
		effect:SetOrigin(muzzle)
		effect:SetAngles(self:GetAimDir():Angle())
		effect:SetAttachment(math.max(self:LookupAttachment("eyes") or 0, 0))
		effect:SetScale(1)
		util.Effect("MuzzleEffect", effect, true, true)

		if cfg.cockSound then
			timer.Simple(cfg.cockDelay or 0.5, function()
				if IsValid(self) then self:EmitSound(cfg.cockSound, 70, cfg.cockPitch or 100) end
			end)
		end

		if self:GetAmmo() <= 0 then
			self:EmitSound("npc/turret_floor/die.wav", 70)
		end
	end

	function ENT:Think()
		local now = CurTime()
		local dt = math.min(now - self.LastThink, 0.2)
		self.LastThink = now

		self:NextThink(now)

		local cfg = self:GetConfig()

		-- перезарядка после покупки боезапаса
		if self.PendingReload and not self:IsReloading() then
			self.PendingReload = nil
			self:SetAmmo(cfg.maxAmmo)
			self:EmitSound("npc/turret_floor/deploy.wav", 70)
		end

		local canWork = self:IsPowered() and not self:IsReloading() and self:GetAmmo() > 0

		if not canWork then
			self.Target, self.TargetBody = nil, nil
			self:SetHasTarget(false)
			self:ServoSound(false)
			return true
		end

		self:SetBattery(math.max(self:GetBattery() - (self.Target and self.ActiveDrain or self.IdleDrain) * dt, 0))

		if self.NextSearch <= now then
			self.NextSearch = now + 0.3
			self.Target, self.TargetBody = self:FindTarget()
			self:SetHasTarget(self.Target ~= nil)
		end

		-- без цели турель возвращается в исходное положение
		local wantYaw, wantPitch = 0, 0
		local target, body = self.Target, self.TargetBody

		if IsTargetable(target) and IsValid(body) then
			wantYaw, wantPitch = self:RelativeAngles(ChestPos(body))
			wantYaw = math.Clamp(wantYaw, -self.Arc, self.Arc)
			wantPitch = math.Clamp(wantPitch, -self.MaxPitch, self.MaxPitch)
		else
			target = nil
		end

		local oldYaw, oldPitch = self.AimYaw, self:GetAimPitch()
		self.AimYaw = math.Approach(oldYaw, wantYaw, self.TurnSpeed * dt)
		local pitch = math.Approach(oldPitch, wantPitch, self.PitchSpeed * dt)

		self:SetAimPitch(pitch)
		self:SetAngles(Angle(0, self.BaseYaw + self.AimYaw, 0))
		self:SetPoseParameter("aim_pitch", pitch)
		self:SetPoseParameter("aim_yaw", 0)

		self:ServoSound(math.abs(self.AimYaw - oldYaw) + math.abs(pitch - oldPitch) > 0.01)

		if target and self.NextFire <= now and math.abs(wantYaw - self.AimYaw) <= self.AimTolerance and math.abs(wantPitch - pitch) <= self.AimTolerance then
			self.NextFire = now + cfg.fireDelay
			self:Shoot(cfg)
		end

		return true
	end

	function ENT:Use(ply)
		if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() or ply:Team() ~= 0 then return end

		net.Start("zs_turret_open")
			net.WriteEntity(self)
		net.Send(ply)
	end

	local function Notify(ply, text)
		if ply.Notify then ply:Notify(text, 0, "zs_turret", 3) else ply:ChatPrint(text) end
	end

	-- покупки в окне турели; возвращают цену или nil с причиной отказа
	local buyFuncs = {
		repair = function(turret)
			if turret:Health() >= turret:GetMaxHealth() then return nil, "The turret is not damaged" end

			turret:SetHealth(turret:GetMaxHealth())
			turret:EmitSound("ambient/energy/zap" .. math.random(1, 3) .. ".wav", 70)
			return ZS_TURRET_REPAIR_PRICE
		end,

		battery = function(turret)
			if turret:GetBattery() >= turret.MaxBattery then return nil, "The battery is full" end

			turret:SetBattery(turret.MaxBattery)
			turret:EmitSound("items/battery_pickup.wav", 70)
			return ZS_TURRET_BATTERY_PRICE
		end,

		ammo = function(turret, cfg)
			if turret:IsReloading() then return nil, "The turret is already reloading" end
			if turret:GetAmmo() >= cfg.maxAmmo then return nil, "The turret is fully loaded" end

			turret:SetReloadEnd(CurTime() + cfg.reload)
			turret.PendingReload = true
			turret:EmitSound("npc/turret_floor/retract.wav", 70)
			return cfg.ammoPrice
		end,
	}

	local prices = {
		repair = function() return ZS_TURRET_REPAIR_PRICE end,
		battery = function() return ZS_TURRET_BATTERY_PRICE end,
		ammo = function(cfg) return cfg.ammoPrice end,
	}

	net.Receive("zs_turret_buy", function(len, ply)
		local turret = net.ReadEntity()
		local what = net.ReadString()

		if (ply.zs_NextBuy or 0) > CurTime() then return end
		ply.zs_NextBuy = CurTime() + 0.2

		if not IsValid(turret) or turret:GetClass() ~= "zs_turret" or not buyFuncs[what] then return end
		if not ply:Alive() or ply:Team() ~= 0 or ply:GetPos():Distance(turret:GetPos()) > ZS_SHOP_DISTANCE then return end

		local cfg = turret:GetConfig()
		local points = ZS_GetSurvivorPoints(ply)

		if points < prices[what](cfg) then
			Notify(ply, "Not enough survivor points")
			return
		end

		local paid, reason = buyFuncs[what](turret, cfg)
		if not paid then
			Notify(ply, reason)
			return
		end

		ply:SetNWInt("ZS_SPoints", points - paid)
		ply:EmitSound("items/ammo_pickup.wav", 60)
	end)

	function ENT:OnTakeDamage(dmg)
		-- ломать турели могут только зараженные (игроки или их NPC)
		local attacker = dmg:GetAttacker()
		local byInfected = IsValid(attacker) and ((attacker:IsPlayer() and attacker:Team() ~= 0) or attacker:IsNPC())
		if not byInfected then return 0 end

		self:SetHealth(self:Health() - dmg:GetDamage())
		self:EmitSound("physics/metal/metal_box_impact_hard" .. math.random(3) .. ".wav", 70)

		if self:Health() <= 0 then
			local effect = EffectData()
			effect:SetOrigin(self:WorldSpaceCenter())
			util.Effect("Explosion", effect, true, true)

			self:Remove()
		end

		return dmg:GetDamage()
	end

	function ENT:OnRemove()
		if self.Servo then self.Servo:Stop() end
	end

	return
end

------------------------------------------------------------------ клиент: модель, лазер, подпись

local laserMat = Material("cable/redlaser")
local dotMat = Material("sprites/light_glow02_add")
local colLaser = Color(255, 30, 30)

function ENT:Draw()
	self:SetPoseParameter("aim_pitch", self:GetAimPitch())
	self:SetPoseParameter("aim_yaw", 0)
	self:InvalidateBoneCache()
	self:DrawModel()

	if LocalPlayer():GetPos():DistToSqr(self:GetPos()) > 250 * 250 then return end

	local cfg = self:GetConfig()
	local pos = self:GetPos() + Vector(0, 0, self:OBBMaxs().z + 10)
	local ang = Angle(0, LocalPlayer():EyeAngles().y - 90, 90)

	cam.Start3D2D(pos, ang, 0.08)
		draw.SimpleTextOutlined(cfg.name, "DermaLarge", 0, 0, cfg.color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)
		draw.SimpleTextOutlined("E - status", "DermaDefaultBold", 0, 30, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
	cam.End3D2D()
end

-- лазерный прицел: луч из ствола до первого препятствия и точка на нем
function ENT:DrawTranslucent()
	if not self:IsPowered() then return end

	local start = self:GetMuzzle()
	local tr = util.TraceLine({
		start = start,
		endpos = start + self:GetAimDir() * self.Range,
		filter = self,
		mask = MASK_SHOT,
	})

	render.SetMaterial(laserMat)
	render.DrawBeam(start, tr.HitPos, 1.5, 0, 1, colLaser)

	render.SetMaterial(dotMat)
	render.DrawSprite(tr.HitPos, 8, 8, colLaser)
end

------------------------------------------------------------------ окно состояния

local colBack = Color(18, 18, 20, 245)
local colPanel = Color(32, 32, 36, 255)
local colHover = Color(52, 52, 58, 255)
local colPoints = Color(120, 220, 120)
local colNoPoints = Color(220, 90, 80)
local colBarBack = Color(10, 10, 12)
local colHealth = Color(200, 60, 50)
local colBattery = Color(80, 170, 255)
local colAmmo = Color(230, 190, 60)

local turretFrame

local function DrawBar(x, y, w, h, frac, col, text)
	draw.RoundedBox(4, x, y, w, h, colBarBack)
	draw.RoundedBox(4, x, y, w * math.Clamp(frac, 0, 1), h, col)
	draw.SimpleTextOutlined(text, "ZS_ShopItem", x + w * 0.5, y + h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
end

local function OpenTurret(turret)
	if IsValid(turretFrame) then turretFrame:Remove() end

	local cfg = turret:GetConfig()

	local frame = vgui.Create("DFrame")
	turretFrame = frame
	frame:SetSize(460, 330)
	frame:Center()
	frame:SetTitle("")
	frame:MakePopup()
	frame:SetKeyboardInputEnabled(false)

	function frame:Paint(w, h)
		draw.RoundedBox(6, 0, 0, w, h, colBack)
		draw.SimpleText(cfg.name, "ZS_ShopTitle", 16, 12, cfg.color)
		draw.SimpleText("SP: " .. ZS_GetSurvivorPoints(LocalPlayer()), "ZS_ShopTitle", w - 50, 12, colPoints, TEXT_ALIGN_RIGHT)

		if not IsValid(turret) then return end

		local x, bw = 16, w - 32

		local hp, maxHp = math.max(turret:Health(), 0), math.max(turret:GetMaxHealth(), 1)
		DrawBar(x, 56, bw, 24, hp / maxHp, colHealth, "Durability: " .. hp .. " / " .. maxHp)

		local battery = turret:GetBattery()
		DrawBar(x, 90, bw, 24, battery / turret.MaxBattery, colBattery, "Battery: " .. math.ceil(battery) .. "%")

		local ammoText
		if turret:IsReloading() then
			ammoText = "Reloading... " .. math.ceil(turret:GetReloadEnd() - CurTime()) .. "s"
		else
			ammoText = "Ammo: " .. turret:GetAmmo() .. " / " .. cfg.maxAmmo .. " (" .. cfg.ammo .. ")"
		end
		DrawBar(x, 124, bw, 24, turret:IsReloading() and 0 or turret:GetAmmo() / cfg.maxAmmo, colAmmo, ammoText)

		local status = not turret:IsPowered() and "No power" or (turret:IsReloading() and "Reloading" or (turret:GetAmmo() <= 0 and "Out of ammo" or (turret:GetHasTarget() and "Engaging target" or "Searching")))
		draw.SimpleText("Status: " .. status, "ZS_ShopPrice", x, 160, color_white)
	end

	function frame:Think()
		local ply = LocalPlayer()
		if not IsValid(turret) or not ply:Alive() or ply:Team() ~= 0 or ply:GetPos():Distance(turret:GetPos()) > ZS_SHOP_DISTANCE then
			self:Remove()
		end
	end

	local buttons = {
		{id = "repair", name = "Repair", price = ZS_TURRET_REPAIR_PRICE},
		{id = "battery", name = "Charge battery", price = ZS_TURRET_BATTERY_PRICE},
		{id = "ammo", name = "Buy ammo (reload " .. cfg.reload .. "s)", price = cfg.ammoPrice},
	}

	local bw = (460 - 32 - 16) / 3

	for i, info in ipairs(buttons) do
		local btn = vgui.Create("DButton", frame)
		btn:SetPos(16 + (i - 1) * (bw + 8), 200)
		btn:SetSize(bw, 110)
		btn:SetText("")

		function btn:Paint(w, h)
			draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and colHover or colPanel)

			local enough = ZS_GetSurvivorPoints(LocalPlayer()) >= info.price
			local lines = string.Explode(" (", info.name)

			draw.SimpleText(lines[1], "ZS_ShopItem", w * 0.5, 30, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			if lines[2] then draw.SimpleText("(" .. lines[2], "ZS_ShopItem", w * 0.5, 50, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end
			draw.SimpleText(info.price .. " pts", "ZS_ShopPrice", w * 0.5, 82, enough and colPoints or colNoPoints, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		function btn:DoClick()
			net.Start("zs_turret_buy")
				net.WriteEntity(turret)
				net.WriteString(info.id)
			net.SendToServer()

			surface.PlaySound("ui/buttonclick.wav")
		end
	end
end

net.Receive("zs_turret_open", function()
	local turret = net.ReadEntity()
	if IsValid(turret) then OpenTurret(turret) end
end)
