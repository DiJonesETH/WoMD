MODE.name = "zs"

-- Аирдроп выживших: сирена (текст оповещения сервер пишет в чат, sv_zs_airdrop.lua)

net.Receive("zs_airdrop", function()
	surface.PlaySound("ambient/alarms/klaxon1.wav")
end)

-- окно выбора лута: 3 предмета, игрок берет нужное, ненужное остается в ящике (sv_zs_airdrop.lua)
local colBack = Color(18, 18, 20, 245)
local colPanel = Color(32, 32, 36, 255)
local colHover = Color(52, 52, 58, 255)
local colTake = Color(120, 220, 120)
local colTaken = Color(130, 130, 130)
local colSpecial = Color(240, 200, 30)
local colTitle = Color(255, 70, 50)

local function ItemIcon(item)
	if item.armor then return hg.armorIcons and hg.armorIcons[item.class] or "icon16/shield.png" end

	local stored = weapons.GetStored(item.class)
	local path = stored and stored.IconOverride or ("entities/" .. item.class .. ".png")
	if Material(path):IsError() then path = "icon16/box.png" end

	return path
end

local airdropFrame

local function OpenAirdrop(crate, items)
	local x, y
	if IsValid(airdropFrame) then
		x, y = airdropFrame:GetPos()
		airdropFrame:Remove()
	end

	local frame = vgui.Create("DFrame")
	airdropFrame = frame
	frame:SetSize(3 * 180 + 2 * 10 + 32, 290)
	if x then frame:SetPos(x, y) else frame:Center() end
	frame:SetTitle("")
	frame:MakePopup()
	frame:SetKeyboardInputEnabled(false)

	function frame:Paint(w, h)
		draw.RoundedBox(6, 0, 0, w, h, colBack)
		draw.SimpleText("AIRDROP", "ZS_ShopTitle", 16, 12, colTitle)
		draw.SimpleText("Take what you need, leave the rest", "ZS_ShopItem", w - 40, 20, color_white, TEXT_ALIGN_RIGHT)
	end

	function frame:Think()
		local ply = LocalPlayer()
		if not IsValid(crate) or not ply:Alive() or ply:Team() ~= 0 or ply:GetPos():Distance(crate:GetPos()) > ZS_SHOP_DISTANCE then
			self:Remove()
		end
	end

	for i, item in ipairs(items) do
		local card = vgui.Create("DButton", frame)
		card:SetPos(16 + (i - 1) * 190, 52)
		card:SetSize(180, 220)
		card:SetText("")

		local icon = vgui.Create("DImage", card)
		icon:SetPos(26, 12)
		icon:SetSize(128, 128)
		icon:SetImage(ItemIcon(item))
		icon:SetMouseInputEnabled(false)

		if item.taken then icon:SetImageColor(Color(255, 255, 255, 60)) end

		function card:Paint(w, h)
			draw.RoundedBox(4, 0, 0, w, h, (self:IsHovered() and not item.taken) and colHover or colPanel)

			if item.special then
				draw.SimpleText("SPECIAL", "ZS_ShopItem", w * 0.5, 4, colSpecial, TEXT_ALIGN_CENTER)
			end

			draw.SimpleText(item.name, "ZS_ShopItem", w * 0.5, 156, item.taken and colTaken or color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(item.taken and "Taken" or "Take", "ZS_ShopPrice", w * 0.5, 190, item.taken and colTaken or colTake, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		card:SetTooltip(item.name)

		function card:DoClick()
			if item.taken then return end

			net.Start("zs_airdrop_take")
				net.WriteEntity(crate)
				net.WriteUInt(i, 4)
			net.SendToServer()

			surface.PlaySound("ui/buttonclick.wav")
		end
	end
end

net.Receive("zs_airdrop_menu", function()
	local crate = net.ReadEntity()
	local items = {}

	for i = 1, net.ReadUInt(4) do
		items[i] = {
			class = net.ReadString(),
			name = net.ReadString(),
			armor = net.ReadBool(),
			special = net.ReadBool(),
			taken = net.ReadBool(),
		}
	end

	if IsValid(crate) then OpenAirdrop(crate, items) end
end)
