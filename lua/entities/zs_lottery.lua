AddCSLuaFile()

-- Лотерейный ящик выживших Zombie Survival (ставится как ящик снабжения, sh_zs_supplyboxes.lua).
-- По E открывается окно: за SpinPrice очков выжившего прокручивается лента наград как кейс в Counter-Strike.
-- Награду выбирает сервер и выдает, когда лента остановится. Веса наград - ZS_LOTTERY_REWARDS.
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Lottery Box"
ENT.Spawnable = false

ENT.MaxHealth = 300
ENT.SpinPrice = 200
ENT.SpinTime = 6 -- секунд крутится лента

-- weight - вес выпадения (доля = вес / сумма весов)
ZS_LOTTERY_REWARDS = {
	{id = "common", name = "Melee, food or medicine", weight = 60, color = Color(75, 105, 255)},
	{id = "pistol", name = "Pistol", weight = 20, color = Color(136, 71, 255)},
	{id = "welder", name = "Arc welder", weight = 15, color = Color(211, 44, 230)},
	{id = "death", name = "Death", weight = 10, color = Color(20, 20, 20)},
	{id = "rifle", name = "Rifle", weight = 10, color = Color(235, 75, 75)},
}

local rewardById = {}
for _, reward in ipairs(ZS_LOTTERY_REWARDS) do rewardById[reward.id] = reward end

-- предметы наград берутся из магазинов (sh_zs_supplyboxes.lua) при первом обращении
local pools

local function ShopCategory(name)
	for _, cat in ipairs(ZS_SHOPS and ZS_SHOPS.arsenal or {}) do
		if cat.name == name then
			local list = {}
			for _, item in ipairs(cat.items) do
				if item.class then list[#list + 1] = item.class end
			end
			return list
		end
	end

	return {}
end

local function GetPools()
	if pools then return pools end

	local common = ShopCategory("Melee")
	table.Add(common, {"weapon_bigconsumable", "weapon_smallconsumable"})
	table.Add(common, ZS_MEDICAL_ITEMS or {})

	local rifles = ShopCategory("Carbines")
	table.Add(rifles, ShopCategory("Assault Rifles"))
	table.Add(rifles, ShopCategory("Marksman Rifles"))

	pools = {
		common = common,
		pistol = ShopCategory("Pistols"),
		welder = {"weapon_zs_arcwelder"},
		death = {""},
		rifle = rifles,
	}

	return pools
end

local function RollReward()
	local total = 0
	for _, reward in ipairs(ZS_LOTTERY_REWARDS) do total = total + reward.weight end

	local roll = math.Rand(0, total)
	for _, reward in ipairs(ZS_LOTTERY_REWARDS) do
		roll = roll - reward.weight
		if roll <= 0 then return reward end
	end

	return ZS_LOTTERY_REWARDS[1]
end

local function RandomItem(id)
	local pool = GetPools()[id]
	return pool[math.random(#pool)] or ""
end

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "BoxType")
end

if SERVER then
	util.AddNetworkString("zs_lottery_open")
	util.AddNetworkString("zs_lottery_spin")
	util.AddNetworkString("zs_lottery_result")

	function ENT:Initialize()
		self:SetBoxType("lottery")

		local info = ZS_SUPPLY_BOXES.lottery
		self:SetModel(info.model)

		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then phys:EnableMotion(false) end

		self:SetHealth(self.MaxHealth)
		self:SetMaxHealth(self.MaxHealth)
	end

	local function CanSpin(ply, box)
		return IsValid(ply) and ply:Alive() and ply:Team() == 0 and IsValid(box) and box:GetClass() == "zs_lottery"
			and ply:GetPos():Distance(box:GetPos()) <= ZS_SHOP_DISTANCE
	end

	function ENT:Use(ply)
		if not CanSpin(ply, self) then return end

		net.Start("zs_lottery_open")
			net.WriteEntity(self)
		net.Send(ply)
	end

	local function GiveWeapon(ply, class)
		if ply:HasWeapon(class) then
			local wep = ply:GetWeapon(class)
			if wep:GetPrimaryAmmoType() >= 0 and wep:GetMaxClip1() > 0 then
				ply:GiveAmmo(wep:GetMaxClip1() * 2, wep:GetPrimaryAmmoType(), true)
			end
			return
		end

		local wep = ply:Give(class)
		if IsValid(wep) and wep:GetPrimaryAmmoType() >= 0 and wep:GetMaxClip1() > 0 then
			ply:GiveAmmo(wep:GetMaxClip1() * 2, wep:GetPrimaryAmmoType(), true)
		end
	end

	local function GrantReward(ply, reward, class)
		if reward.id == "death" then
			-- выстрел дробовика и взорванная голова
			ply:EmitSound("zcitysnd/sound/weapons/firearms/shtg_remington870/remington_fire_01.wav", 100, 100, 1, CHAN_WEAPON)
			if hg.ExplodeHead then hg.ExplodeHead(ply) else ply:Kill() end
			return
		end

		if reward.id == "welder" then
			GiveWeapon(ply, "weapon_zs_arcwelder")
			if ZS_BARRICADE then ply:GiveAmmo(5, ZS_BARRICADE.ElectrodeAmmo, true) end
			return
		end

		GiveWeapon(ply, class)
	end

	net.Receive("zs_lottery_spin", function(len, ply)
		local box = net.ReadEntity()

		if (ply.zs_NextBuy or 0) > CurTime() then return end
		ply.zs_NextBuy = CurTime() + 0.2

		if not CanSpin(ply, box) then return end
		if (ply.zs_LotteryUntil or 0) > CurTime() then return end

		local points = ZS_GetSurvivorPoints(ply)
		if points < box.SpinPrice then
			if ply.Notify then ply:Notify("Not enough survivor points", 0, "zs_shop", 3) end
			return
		end

		ply:SetNWInt("ZS_SPoints", points - box.SpinPrice)
		ply.zs_LotteryUntil = CurTime() + box.SpinTime + 0.5

		local reward = RollReward()
		local class = reward.id ~= "death" and RandomItem(reward.id) or ""

		box:EmitSound("ui/buttonclickrelease.wav", 60)

		net.Start("zs_lottery_spin")
			net.WriteEntity(box)
			net.WriteString(reward.id)
			net.WriteString(class)
		net.Send(ply)

		timer.Simple(box.SpinTime, function()
			if not IsValid(ply) or not ply:Alive() or ply:Team() ~= 0 then return end

			GrantReward(ply, reward, class)

			net.Start("zs_lottery_result")
				net.WriteString(reward.id)
			net.Send(ply)
		end)
	end)

	function ENT:OnTakeDamage(dmg)
		-- ломать ящик могут только зараженные (игроки или их NPC)
		local attacker = dmg:GetAttacker()
		local byInfected = IsValid(attacker) and ((attacker:IsPlayer() and attacker:Team() ~= 0) or attacker:IsNPC())
		if not byInfected then return 0 end

		self:SetHealth(self:Health() - dmg:GetDamage())
		self:EmitSound("physics/metal/metal_box_impact_hard" .. math.random(3) .. ".wav", 70)

		if self:Health() <= 0 then
			local effect = EffectData()
			effect:SetOrigin(self:GetPos())
			util.Effect("cball_explode", effect)

			self:Remove()
		end

		return dmg:GetDamage()
	end

	return
end

------------------------------------------------------------------ клиент

function ENT:Draw()
	self:DrawModel()

	if LocalPlayer():GetPos():DistToSqr(self:GetPos()) > 250 * 250 then return end

	local info = ZS_SUPPLY_BOXES.lottery
	local pos = self:GetPos() + Vector(0, 0, self:OBBMaxs().z + 12)
	local ang = Angle(0, LocalPlayer():EyeAngles().y - 90, 90)

	cam.Start3D2D(pos, ang, 0.08)
		draw.SimpleTextOutlined(info.name, "DermaLarge", 0, 0, info.color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)
		draw.SimpleTextOutlined("E - spin (" .. self.SpinPrice .. " SP)", "DermaDefaultBold", 0, 30, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
	cam.End3D2D()
end

local colBack = Color(18, 18, 20, 245)
local colPanel = Color(32, 32, 36, 255)
local colHover = Color(52, 52, 58, 255)
local colPoints = Color(120, 220, 120)
local colNoPoints = Color(220, 90, 80)
local colMarker = Color(255, 200, 40)

local CARD_W, CARD_GAP, STRIP_LEN, WIN_INDEX = 130, 6, 60, 52

local iconCache = {}
local function ItemIcon(class)
	if class == "" then return "icon16/bomb.png" end
	if iconCache[class] then return iconCache[class] end

	local stored = weapons.GetStored(class)
	local path = stored and stored.IconOverride or ("entities/" .. class .. ".png")
	if Material(path):IsError() then path = "icon16/gun.png" end

	iconCache[class] = path
	return path
end

local function ItemName(id, class)
	if id == "death" then return "DEATH" end

	local stored = weapons.GetStored(class)
	return stored and stored.PrintName and language.GetPhrase(stored.PrintName) or class
end

local function RandomCard()
	local reward = RollReward()
	return {id = reward.id, class = reward.id == "death" and "" or RandomItem(reward.id)}
end

local lotteryFrame

local function OpenLottery(box)
	if IsValid(lotteryFrame) then lotteryFrame:Remove() end

	local frame = vgui.Create("DFrame")
	lotteryFrame = frame
	frame:SetSize(math.min(ScrW() - 40, 760), 330)
	frame:Center()
	frame:SetTitle("")
	frame:MakePopup()
	frame:SetKeyboardInputEnabled(false)

	-- лента карточек: до прокрутки случайная, при прокрутке WIN_INDEX-я карточка - выигрыш
	frame.Strip = {}
	for i = 1, STRIP_LEN do frame.Strip[i] = RandomCard() end
	frame.Offset = 0

	function frame:Paint(w, h)
		draw.RoundedBox(6, 0, 0, w, h, colBack)
		draw.SimpleText("LOTTERY BOX", "ZS_ShopTitle", 16, 12, colMarker)
		draw.SimpleText("SP: " .. ZS_GetSurvivorPoints(LocalPlayer()), "ZS_ShopTitle", w - 50, 12, colPoints, TEXT_ALIGN_RIGHT)

		-- лента
		local x0, y0, stripW, cardH = 16, 60, w - 32, 150

		if self.SpinStart then
			local frac = math.Clamp((CurTime() - self.SpinStart) / box.SpinTime, 0, 1)
			local ease = 1 - (1 - frac) ^ 3
			self.Offset = ease * self.SpinTarget
		end

		local sx, sy = self:LocalToScreen(x0, y0)
		render.SetScissorRect(sx, sy, sx + stripW, sy + cardH, true)

		for i, card in ipairs(self.Strip) do
			local x = x0 + (i - 1) * (CARD_W + CARD_GAP) - self.Offset
			if x + CARD_W >= x0 and x <= x0 + stripW then
				local reward = rewardById[card.id]

				draw.RoundedBox(4, x, y0, CARD_W, cardH, colPanel)
				draw.RoundedBox(0, x, y0 + cardH - 8, CARD_W, 8, reward.color)

				surface.SetDrawColor(255, 255, 255)
				surface.SetMaterial(Material(ItemIcon(card.class)))
				surface.DrawTexturedRect(x + (CARD_W - 96) * 0.5, y0 + 10, 96, 96)

				draw.SimpleText(ItemName(card.id, card.class), "ZS_ShopItem", x + CARD_W * 0.5, y0 + 120, card.id == "death" and colNoPoints or color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end

		render.SetScissorRect(0, 0, 0, 0, false)

		-- указатель по центру
		local cx = x0 + stripW * 0.5
		surface.SetDrawColor(colMarker)
		surface.DrawRect(cx - 1, y0 - 6, 3, cardH + 12)

		if self.ResultText then
			draw.SimpleText(self.ResultText, "ZS_ShopTitle", w * 0.5, 232, self.ResultColor or color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	function frame:Think()
		local ply = LocalPlayer()
		if not IsValid(box) or not ply:Alive() or ply:Team() ~= 0 or ply:GetPos():Distance(box:GetPos()) > ZS_SHOP_DISTANCE then
			if not self.SpinStart then self:Remove() end
		end

		-- щелчки при проходе карточек под указателем
		if self.SpinStart then
			local index = math.floor(self.Offset / (CARD_W + CARD_GAP))
			if index ~= self.LastTick then
				self.LastTick = index
				surface.PlaySound("ui/buttonrollover.wav")
			end
		end
	end

	local btn = vgui.Create("DButton", frame)
	btn:SetSize(260, 50)
	btn:SetPos((frame:GetWide() - 260) * 0.5, 262)
	btn:SetText("")

	function btn:Paint(w, h)
		local spinning = frame.SpinStart and CurTime() - frame.SpinStart < box.SpinTime + 0.5
		local enough = ZS_GetSurvivorPoints(LocalPlayer()) >= box.SpinPrice

		draw.RoundedBox(4, 0, 0, w, h, (self:IsHovered() and not spinning) and colHover or colPanel)
		draw.SimpleText(spinning and "Spinning..." or ("SPIN - " .. box.SpinPrice .. " SP"), "ZS_ShopPrice", w * 0.5, h * 0.5, spinning and color_white or (enough and colPoints or colNoPoints), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	function btn:DoClick()
		if frame.SpinStart and CurTime() - frame.SpinStart < box.SpinTime + 0.5 then return end

		net.Start("zs_lottery_spin")
			net.WriteEntity(box)
		net.SendToServer()

		surface.PlaySound("ui/buttonclick.wav")
	end

	return frame
end

net.Receive("zs_lottery_open", function()
	local box = net.ReadEntity()
	if IsValid(box) then OpenLottery(box) end
end)

net.Receive("zs_lottery_spin", function()
	local box = net.ReadEntity()
	local id, class = net.ReadString(), net.ReadString()
	if not IsValid(box) then return end

	local frame = IsValid(lotteryFrame) and lotteryFrame or OpenLottery(box)

	-- новая лента, выигрыш на WIN_INDEX; остановка в случайной точке карточки
	frame.Strip = {}
	for i = 1, STRIP_LEN do frame.Strip[i] = RandomCard() end
	frame.Strip[WIN_INDEX] = {id = id, class = class}

	local stripW = frame:GetWide() - 32
	frame.SpinTarget = (WIN_INDEX - 1) * (CARD_W + CARD_GAP) + CARD_W * math.Rand(0.15, 0.85) - stripW * 0.5
	frame.SpinStart = CurTime()
	frame.Offset = 0
	frame.LastTick = nil
	frame.ResultText = nil
end)

net.Receive("zs_lottery_result", function()
	local id = net.ReadString()
	if not IsValid(lotteryFrame) then return end

	local reward = rewardById[id]
	local card = lotteryFrame.Strip[WIN_INDEX]

	lotteryFrame.ResultText = id == "death" and "DEATH" or ("You got: " .. ItemName(id, card and card.class or ""))
	lotteryFrame.ResultColor = id == "death" and colNoPoints or (reward and reward.color)

	surface.PlaySound(id == "death" and "buttons/button10.wav" or "garrysmod/save_load1.wav")
end)
