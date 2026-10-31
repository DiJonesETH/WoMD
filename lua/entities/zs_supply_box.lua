AddCSLuaFile()

-- Установленный ящик снабжения выживших (арсенальный, медицинский, технический), см. sh_zs_supplyboxes.lua.
-- Заморожен на месте, ломается только зараженными, по E открывает магазин, где выжившие тратят очки
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Supply Box"
ENT.Spawnable = false

ENT.MaxHealth = 300

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "BoxType")
end

if SERVER then
	util.AddNetworkString("zs_shop_open")
	util.AddNetworkString("zs_shop_buy")

	function ENT:Initialize()
		local info = ZS_SUPPLY_BOXES[self:GetBoxType()] or ZS_SUPPLY_BOXES.arsenal

		self:SetModel(info.model)
		self:SetColor(info.color)

		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then phys:EnableMotion(false) end

		self:SetHealth(self.MaxHealth)
		self:SetMaxHealth(self.MaxHealth)
	end

	local function Notify(ply, text)
		if ply.Notify then ply:Notify(text, 0, "zs_shop", 3) else ply:ChatPrint(text) end
	end

	local function CanShop(ply, box)
		return IsValid(ply) and ply:Alive() and ply:Team() == 0 and IsValid(box) and box:GetClass() == "zs_supply_box"
			and ply:GetPos():Distance(box:GetPos()) <= ZS_SHOP_DISTANCE
	end

	function ENT:Use(ply)
		if not CanShop(ply, self) then return end

		self:EmitSound("items/ammocrate_open.wav", 65)

		net.Start("zs_shop_open")
			net.WriteEntity(self)
		net.Send(ply)
	end

	-- выдача товара; возвращает цену или nil с причиной отказа
	local buyFuncs = {
		weapon = function(ply, item)
			if ply:HasWeapon(item.class) then return nil, "You already have this" end

			local wep = ply:Give(item.class)
			if not IsValid(wep) then return nil, "Can't take this right now" end

			-- оружие с одним запасным магазином
			if wep:GetPrimaryAmmoType() >= 0 and wep:GetMaxClip1() > 0 then
				ply:GiveAmmo(wep:GetMaxClip1(), wep:GetPrimaryAmmoType(), true)
			end

			return item.price
		end,

		ammo_held = function(ply, item, price)
			local wep = ply:GetActiveWeapon()
			local _, amount = ZS_HeldAmmoPrice(wep)
			if not price or not amount then return nil, "Hold a firearm in your hands" end

			ply:GiveAmmo(amount, wep:GetPrimaryAmmoType(), true)
			return price
		end,

		attachment = function(ply, item)
			hg.GiveAttachment(ply, item.att)
			return item.price
		end,

		armor = function(ply, item)
			for _, worn in pairs(ply.armors or {}) do
				if worn == item.armor then return nil, "You already wear this" end
			end

			hg.AddArmor(ply, item.armor)

			for _, worn in pairs(ply.armors or {}) do
				if worn == item.armor then return item.price end
			end

			return nil, "You can't wear this right now"
		end,

		ammo = function(ply, item)
			ply:GiveAmmo(item.amount, item.ammo, true)
			return item.price
		end,

		electrodes = function(ply, item)
			local b = ZS_BARRICADE
			if b.GetElectrodes(ply) >= b.MaxElectrodes then return nil, "You can't carry more electrodes" end

			ply:GiveAmmo(item.amount, b.ElectrodeAmmo, true)
			return item.price
		end,
	}

	local function ItemPrice(ply, item)
		if item.kind == "ammo_held" then return (ZS_HeldAmmoPrice(ply:GetActiveWeapon())) end
		return item.price
	end

	net.Receive("zs_shop_buy", function(len, ply)
		local box = net.ReadEntity()
		local id = net.ReadString()

		if (ply.zs_NextBuy or 0) > CurTime() then return end
		ply.zs_NextBuy = CurTime() + 0.2

		if not CanShop(ply, box) then return end

		local item = ZS_FindShopItem(box:GetBoxType(), id)
		if not item then return end

		local price = ItemPrice(ply, item)
		local points = ZS_GetSurvivorPoints(ply)

		if price and points < price then
			Notify(ply, "Not enough survivor points")
			return
		end

		local paid, reason = buyFuncs[item.kind](ply, item, price)
		if not paid then
			Notify(ply, reason or "Can't buy this")
			return
		end

		ply:SetNWInt("ZS_SPoints", points - paid)
		ply:EmitSound("items/ammo_pickup.wav", 60)
	end)

	function ENT:OnTakeDamage(dmg)
		-- ломать ящики могут только зараженные (игроки или их NPC)
		local attacker = dmg:GetAttacker()
		local byInfected = IsValid(attacker) and ((attacker:IsPlayer() and attacker:Team() ~= 0) or attacker:IsNPC() or attacker:IsNextBot())
		if not byInfected then return 0 end

		self:SetHealth(self:Health() - dmg:GetDamage())
		self:EmitSound("physics/wood/wood_crate_impact_hard" .. math.random(4) .. ".wav", 70)

		if self:Health() <= 0 then
			self:EmitSound("physics/wood/wood_crate_break" .. math.random(5) .. ".wav", 80)

			local effect = EffectData()
			effect:SetOrigin(self:GetPos())
			util.Effect("cball_explode", effect)

			self:Remove()
		end

		return dmg:GetDamage()
	end

	return
end

function ENT:Draw()
	self:DrawModel()

	if LocalPlayer():GetPos():DistToSqr(self:GetPos()) > 250 * 250 then return end

	local info = ZS_SUPPLY_BOXES[self:GetBoxType()]
	if not info then return end

	local pos = self:GetPos() + Vector(0, 0, self:OBBMaxs().z + 12)
	local ang = Angle(0, LocalPlayer():EyeAngles().y - 90, 90)

	cam.Start3D2D(pos, ang, 0.08)
		draw.SimpleTextOutlined(info.name, "DermaLarge", 0, 0, info.color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)
		draw.SimpleTextOutlined("E - shop", "DermaDefaultBold", 0, 30, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
	cam.End3D2D()
end

------------------------------------------------------------------ интерфейс магазина

surface.CreateFont("ZS_ShopTitle", {font = "Roboto", size = 28, weight = 800, extended = true})
surface.CreateFont("ZS_ShopItem", {font = "Roboto", size = 16, weight = 600, extended = true})
surface.CreateFont("ZS_ShopPrice", {font = "Roboto", size = 18, weight = 800, extended = true})

local colBack = Color(18, 18, 20, 245)
local colPanel = Color(32, 32, 36, 255)
local colHover = Color(52, 52, 58, 255)
local colPoints = Color(120, 220, 120)
local colNoPoints = Color(220, 90, 80)
local colGray = Color(170, 170, 170)

-- иконка как в Q-меню: IconOverride оружия или entities/<класс>.png
local iconCache = {}
local function ItemIcon(item)
	if item.icon then return item.icon end
	if item.armor then return hg.armorIcons and hg.armorIcons[item.armor] or "icon16/shield.png" end
	if item.att then
		local icon = hg.attachmentsIcons and hg.attachmentsIcons[item.att]
		return icon and not Material(icon):IsError() and icon or "icon16/cog.png"
	end
	if iconCache[item.class] then return iconCache[item.class] end

	local stored = weapons.GetStored(item.class)
	local path = stored and stored.IconOverride or ("entities/" .. item.class .. ".png")
	if Material(path):IsError() then path = "icon16/gun.png" end

	iconCache[item.class] = path
	return path
end

local function ItemName(item)
	if item.name then return item.name end
	if item.armor then return hg.armorNames and hg.armorNames[item.armor] or item.armor end
	if item.att then return hg.attachmentslaunguage and hg.attachmentslaunguage[item.att] or item.att end

	local stored = weapons.GetStored(item.class)
	return stored and stored.PrintName and language.GetPhrase(stored.PrintName) or item.class
end

local function ItemPrice(item)
	if item.kind == "ammo_held" then return (ZS_HeldAmmoPrice(LocalPlayer():GetActiveWeapon())) end
	return item.price
end

local shopFrame

local function OpenShop(box)
	if IsValid(shopFrame) then shopFrame:Remove() end

	local boxType = box:GetBoxType()
	local shop = ZS_SHOPS[boxType]
	local info = ZS_SUPPLY_BOXES[boxType]
	if not shop or not info then return end

	local frame = vgui.Create("DFrame")
	shopFrame = frame
	frame:SetSize(math.min(ScrW() - 40, 900), math.min(ScrH() - 40, 640))
	frame:Center()
	frame:SetTitle("")
	frame:MakePopup()
	frame:SetKeyboardInputEnabled(true) -- поиск по имени

	function frame:Paint(w, h)
		draw.RoundedBox(6, 0, 0, w, h, colBack)
		draw.SimpleText(info.name, "ZS_ShopTitle", 16, 12, info.color)
		draw.SimpleText("SURVIVOR POINTS: " .. ZS_GetSurvivorPoints(LocalPlayer()), "ZS_ShopTitle", w - 50, 12, colPoints, TEXT_ALIGN_RIGHT)
	end

	function frame:Think()
		local ply = LocalPlayer()
		if not IsValid(box) or not ply:Alive() or ply:Team() ~= 0 or ply:GetPos():Distance(box:GetPos()) > ZS_SHOP_DISTANCE then
			self:Remove()
		end
	end

	-- левая колонка: вкладки магазина или калибры (у арсенала), сверху - поиск по имени
	local left = vgui.Create("DPanel", frame)
	left:Dock(LEFT)
	left:DockMargin(6, 40, 6, 6)
	left:SetWide(190)
	left.Paint = nil

	local search = vgui.Create("DTextEntry", left)
	search:Dock(TOP)
	search:DockMargin(0, 0, 0, 6)
	search:SetTall(28)
	search:SetPlaceholderText("Search by name...")
	search:SetUpdateOnType(true)

	local hasWeapons = false
	for _, cat in ipairs(shop) do
		for _, item in ipairs(cat.items) do
			if item.kind == "weapon" then hasWeapons = true break end
		end
	end

	-- переключатель "вкладки / калибры" (только если в магазине есть оружие)
	local modeBar
	if hasWeapons then
		modeBar = vgui.Create("DPanel", left)
		modeBar:Dock(TOP)
		modeBar:DockMargin(0, 0, 0, 6)
		modeBar:SetTall(28)
		modeBar.Paint = nil
	end

	local cats = vgui.Create("DScrollPanel", left)
	cats:Dock(FILL)

	local scroll = vgui.Create("DScrollPanel", frame)
	scroll:Dock(FILL)
	scroll:DockMargin(0, 40, 6, 6)

	-- полоса прокрутки справа в цветах магазина
	local vbar = scroll:GetVBar()
	vbar:SetWide(10)
	vbar:SetHideButtons(true)
	function vbar:Paint(w, h) draw.RoundedBox(4, 0, 0, w, h, colPanel) end
	function vbar.btnGrip:Paint(w, h) draw.RoundedBox(4, 0, 0, w, h, colHover) end

	-- сетка растет вниз по содержимому (Dock TOP), поэтому длинные вкладки прокручиваются
	local layout = vgui.Create("DIconLayout", scroll)
	layout:Dock(TOP)
	layout:DockMargin(0, 0, 4, 0)
	layout:SetSpaceX(8)
	layout:SetSpaceY(8)

	-- оружие, которого нет на сервере (не установлен аддон), не показывается
	local function Available(item)
		return item.kind ~= "weapon" or weapons.GetStored(item.class) ~= nil
	end

	local function ItemCaliber(item)
		if item.kind ~= "weapon" then return end

		local wep = weapons.Get(item.class)
		local ammo = wep and wep.Primary and wep.Primary.Ammo
		if isstring(ammo) and ammo ~= "" and string.lower(ammo) ~= "none" then return ammo end
	end

	local function AllItems()
		local list, seen = {}, {}

		for _, cat in ipairs(shop) do
			for _, item in ipairs(cat.items) do
				if not seen[item.id] and Available(item) then
					seen[item.id] = true
					list[#list + 1] = item
				end
			end
		end

		return list
	end

	local function ShowItems(items)
		layout:Clear()

		for _, item in ipairs(items) do
			if not Available(item) then continue end

			local card = layout:Add("DButton")
			card:SetSize(148, 160)
			card:SetText("")

			local icon = vgui.Create("DImage", card)
			icon:SetPos(22, 8)
			icon:SetSize(104, 104)
			icon:SetImage(ItemIcon(item))
			icon:SetMouseInputEnabled(false)

			local name = ItemName(item)
			local caliber = ItemCaliber(item)

			function card:Paint(w, h)
				draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and colHover or colPanel)

				local price = ItemPrice(item)
				local enough = price and ZS_GetSurvivorPoints(LocalPlayer()) >= price
				local priceText = price and (price .. " pts") or ((item.priceText or "?") .. " pts")

				draw.SimpleText(name, "ZS_ShopItem", w * 0.5, 120, color_white, TEXT_ALIGN_CENTER)
				draw.SimpleText(priceText, "ZS_ShopPrice", w * 0.5, 138, enough and colPoints or (price and colNoPoints or colGray), TEXT_ALIGN_CENTER)
			end

			card:SetTooltip(caliber and (name .. "\n" .. caliber) or name)

			function card:DoClick()
				net.Start("zs_shop_buy")
					net.WriteEntity(box)
					net.WriteString(item.id)
				net.SendToServer()

				surface.PlaySound("ui/buttonclick.wav")
			end
		end

		scroll:GetVBar():SetScroll(0)
	end

	local function AddListButton(title, count, onClick, isActive)
		local btn = cats:Add("DButton")
		btn:Dock(TOP)
		btn:DockMargin(0, 0, 0, 6)
		btn:SetTall(34)
		btn:SetText("")

		function btn:Paint(w, h)
			draw.RoundedBox(4, 0, 0, w, h, (isActive() or self:IsHovered()) and colHover or colPanel)
			draw.SimpleText(title, "ZS_ShopPrice", 12, h * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			if count then draw.SimpleText(count, "ZS_ShopItem", w - 10, h * 0.5, colGray, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER) end
		end

		btn.DoClick = onClick
		return btn
	end

	local mode = "tabs"
	local BuildList

	local function ShowTabs()
		cats:Clear()

		local first
		for _, cat in ipairs(shop) do
			local count = 0
			for _, item in ipairs(cat.items) do
				if Available(item) then count = count + 1 end
			end

			if count > 0 then
				local btn = AddListButton(cat.name, nil, function()
					frame.ZSCategory = cat
					search:SetText("")
					ShowItems(cat.items)
				end, function() return frame.ZSCategory == cat end)

				first = first or btn
			end
		end

		if first then first:DoClick() end
	end

	-- калибры: все оружие магазина, сгруппированное по патронам (Primary.Ammo)
	local function ShowCalibers()
		cats:Clear()

		local byCaliber, names = {}, {}
		for _, item in ipairs(AllItems()) do
			local caliber = ItemCaliber(item)
			if caliber then
				if not byCaliber[caliber] then
					byCaliber[caliber] = {}
					names[#names + 1] = caliber
				end
				table.insert(byCaliber[caliber], item)
			end
		end

		table.sort(names)

		local first
		for _, caliber in ipairs(names) do
			local items = byCaliber[caliber]
			table.sort(items, function(a, b) return (ItemPrice(a) or 0) < (ItemPrice(b) or 0) end)

			local btn = AddListButton(caliber, #items, function()
				frame.ZSCategory = caliber
				search:SetText("")
				ShowItems(items)
			end, function() return frame.ZSCategory == caliber end)

			first = first or btn
		end

		if first then first:DoClick() end
	end

	BuildList = function()
		if mode == "calibers" then ShowCalibers() else ShowTabs() end
	end

	if modeBar then
		for i, info in ipairs({{"tabs", "Categories"}, {"calibers", "Calibers"}}) do
			local btn = vgui.Create("DButton", modeBar)
			btn:Dock(i == 1 and LEFT or FILL)
			btn:SetWide(94)
			btn:DockMargin(0, 0, i == 1 and 4 or 0, 0)
			btn:SetText("")

			function btn:Paint(w, h)
				draw.RoundedBox(4, 0, 0, w, h, (mode == info[1] or self:IsHovered()) and colHover or colPanel)
				draw.SimpleText(info[2], "ZS_ShopItem", w * 0.5, h * 0.5, mode == info[1] and colPoints or color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			function btn:DoClick()
				if mode == info[1] then return end
				mode = info[1]
				BuildList()
			end
		end
	end

	-- поиск по имени (и классу) по всему магазину
	function search:OnValueChange(text)
		text = string.Trim(string.lower(text or ""))

		if text == "" then
			BuildList()
			return
		end

		frame.ZSCategory = nil

		local found = {}
		for _, item in ipairs(AllItems()) do
			if string.find(string.lower(ItemName(item)), text, 1, true) or string.find(string.lower(item.class or item.id or ""), text, 1, true) then
				found[#found + 1] = item
			end
		end

		ShowItems(found)
	end

	BuildList()
end

net.Receive("zs_shop_open", function()
	local box = net.ReadEntity()
	if IsValid(box) then OpenShop(box) end
end)
