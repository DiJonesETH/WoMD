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

			b.GiveElectrodes(ply, item.amount)
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
		local byInfected = IsValid(attacker) and ((attacker:IsPlayer() and attacker:Team() ~= 0) or attacker:IsNPC())
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
	frame:SetSize(math.min(ScrW() - 40, 820), math.min(ScrH() - 40, 560))
	frame:Center()
	frame:SetTitle("")
	frame:MakePopup()
	frame:SetKeyboardInputEnabled(false)

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

	local cats = vgui.Create("DPanel", frame)
	cats:Dock(LEFT)
	cats:DockMargin(6, 40, 6, 6)
	cats:SetWide(170)
	cats.Paint = nil

	local scroll = vgui.Create("DScrollPanel", frame)
	scroll:Dock(FILL)
	scroll:DockMargin(0, 40, 6, 6)

	local layout = vgui.Create("DIconLayout", scroll)
	layout:Dock(FILL)
	layout:SetSpaceX(8)
	layout:SetSpaceY(8)

	local function ShowCategory(cat)
		layout:Clear()

		for _, item in ipairs(cat.items) do
			local card = layout:Add("DButton")
			card:SetSize(148, 160)
			card:SetText("")

			local icon = vgui.Create("DImage", card)
			icon:SetPos(22, 8)
			icon:SetSize(104, 104)
			icon:SetImage(ItemIcon(item))
			icon:SetMouseInputEnabled(false)

			local name = ItemName(item)

			function card:Paint(w, h)
				draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and colHover or colPanel)

				local price = ItemPrice(item)
				local enough = price and ZS_GetSurvivorPoints(LocalPlayer()) >= price
				local priceText = price and (price .. " pts") or ((item.priceText or "?") .. " pts")

				draw.SimpleText(name, "ZS_ShopItem", w * 0.5, 120, color_white, TEXT_ALIGN_CENTER)
				draw.SimpleText(priceText, "ZS_ShopPrice", w * 0.5, 138, enough and colPoints or (price and colNoPoints or colGray), TEXT_ALIGN_CENTER)
			end

			card:SetTooltip(name)

			function card:DoClick()
				net.Start("zs_shop_buy")
					net.WriteEntity(box)
					net.WriteString(item.id)
				net.SendToServer()

				surface.PlaySound("ui/buttonclick.wav")
			end
		end
	end

	for i, cat in ipairs(shop) do
		local btn = vgui.Create("DButton", cats)
		btn:Dock(TOP)
		btn:DockMargin(0, 0, 0, 6)
		btn:SetTall(34)
		btn:SetText("")

		function btn:Paint(w, h)
			draw.RoundedBox(4, 0, 0, w, h, (frame.ZSCategory == cat or self:IsHovered()) and colHover or colPanel)
			draw.SimpleText(cat.name, "ZS_ShopPrice", 12, h * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		function btn:DoClick()
			frame.ZSCategory = cat
			ShowCategory(cat)
		end

		if i == 1 then btn:DoClick() end
	end
end

net.Receive("zs_shop_open", function()
	local box = net.ReadEntity()
	if IsValid(box) then OpenShop(box) end
end)
