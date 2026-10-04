MODE.name = "zs"

local MODE = MODE

-- Меню выбора класса зараженного, дерево навыков (клавиша I), очки и прогресс поедания трупа

local UI = {}
MODE.InfectedUI = UI

local colWhite = Color(255, 255, 255)
local colGray = Color(170, 170, 170)
local colDark = Color(15, 15, 15, 235)

local mySkills = {}

net.Receive("zs_skills", function()
	mySkills = net.ReadTable() or {}
end)

local function Darken(col, mul, a)
	return Color(col.r * mul, col.g * mul, col.b * mul, a or 255)
end

function UI.GetClass()
	local class = IsValid(lply) and lply:GetNWString("ZS_Class", "") or ""
	return class ~= "" and class or nil
end

-- выбор класса

local classMenu

function UI.OpenClassMenu()
	if IsValid(classMenu) then return end
	if UI.GetClass() then return end

	local w, h = math.min(ScrW() * 0.8, 1000), math.min(ScrH() * 0.6, 460)

	classMenu = vgui.Create("DFrame")
	classMenu:SetSize(w, h)
	classMenu:Center()
	classMenu:SetTitle("")
	classMenu:ShowCloseButton(true)
	classMenu:SetDraggable(false)
	classMenu:MakePopup()

	classMenu.Paint = function(self, pw, ph)
		draw.RoundedBox(8, 0, 0, pw, ph, colDark)
		draw.SimpleText("Choose your infection", "ZB_InterfaceMediumLarge", pw * 0.5, 30, colWhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("The choice is permanent until the end of the round", "ZB_InterfaceSmall", pw * 0.5, 62, colGray, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local pad = 16
	local cardW = (w - pad * 4) / 3
	local cardH = h - 100 - pad

	for i, class in ipairs(ZS_ZOMBIE_CLASS_ORDER) do
		local info = ZS_ZOMBIE_CLASSES[class]

		local card = vgui.Create("DButton", classMenu)
		card:SetPos(pad + (i - 1) * (cardW + pad), 90)
		card:SetSize(cardW, cardH)
		card:SetText("")

		card.Paint = function(self, cw, ch)
			local hovered = self:IsHovered()

			draw.RoundedBox(8, 0, 0, cw, ch, Darken(info.color, hovered and 0.45 or 0.25, 240))
			surface.SetDrawColor(info.color)
			surface.DrawOutlinedRect(0, 0, cw, ch, hovered and 3 or 1)

			draw.SimpleText(info.name, "ZB_InterfaceMediumLarge", cw * 0.5, 36, info.color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			local lines = {
				info.desc,
				"",
				"Speed: x" .. info.speed,
				"Damage taken: x" .. info.damageTaken,
				"Claw damage: x" .. info.meleeMul,
			}

			for j, line in ipairs(lines) do
				draw.SimpleText(line, "ZB_InterfaceSmall", cw * 0.5, 80 + j * 22, colWhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			draw.SimpleText("Click to choose", "ZB_InterfaceMedium", cw * 0.5, ch - 30, hovered and colWhite or colGray, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		card.DoClick = function()
			net.Start("zs_chooseclass")
				net.WriteString(class)
			net.SendToServer()

			surface.PlaySound("npc/zombie/zombie_alert" .. math.random(3) .. ".wav")
			classMenu:Close()
		end
	end
end

net.Receive("zs_openclassmenu", UI.OpenClassMenu)

-- дерево навыков

local skillMenu

local function BuildSkillGrid(parent, class, info)
	local tree = MODE.SkillTrees[class] or {}

	if table.IsEmpty(tree) then
		local empty = vgui.Create("DPanel", parent)
		empty:Dock(FILL)
		empty.Paint = function(self, pw, ph)
			draw.SimpleText("No skills yet", "ZB_InterfaceMediumLarge", pw * 0.5, ph * 0.5 - 14, Darken(info.color, 0.8), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText("Skills for this class will appear here", "ZB_InterfaceSmall", pw * 0.5, ph * 0.5 + 18, colGray, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		return
	end

	local nodeW, nodeH, gap = 170, 70, 30

	for id, skill in SortedPairs(tree) do
		local pos = skill.pos or {x = 0, y = 0}

		local node = vgui.Create("DButton", parent)
		node:SetPos(20 + pos.x * (nodeW + gap), 20 + pos.y * (nodeH + gap))
		node:SetSize(nodeW, nodeH)
		node:SetText("")
		node:SetTooltip(skill.desc or "")

		node.Paint = function(self, nw, nh)
			local owned = mySkills[id]
			local bg = owned and Darken(info.color, 0.7, 240) or Darken(info.color, self:IsHovered() and 0.35 or 0.2, 240)

			draw.RoundedBox(6, 0, 0, nw, nh, bg)
			surface.SetDrawColor(info.color)
			surface.DrawOutlinedRect(0, 0, nw, nh, owned and 2 or 1)

			draw.SimpleText(skill.name or id, "ZB_InterfaceMedium", nw * 0.5, nh * 0.35, colWhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(owned and "Learned" or ((skill.cost or 0) .. " pts"), "ZB_InterfaceSmall", nw * 0.5, nh * 0.72, owned and colWhite or colGray, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		node.DoClick = function()
			if mySkills[id] then return end

			net.Start("zs_buyskill")
				net.WriteString(id)
			net.SendToServer()
		end
	end
end

function UI.ToggleSkillTree()
	if IsValid(skillMenu) then
		skillMenu:Close()
		return
	end

	local class = UI.GetClass()
	if not class then return end

	local info = ZS_ZOMBIE_CLASSES[class]
	local w, h = math.min(ScrW() * 0.7, 900), math.min(ScrH() * 0.7, 600)

	skillMenu = vgui.Create("DFrame")
	skillMenu:SetSize(w, h)
	skillMenu:Center()
	skillMenu:SetTitle("")
	skillMenu:SetDraggable(false)
	skillMenu:MakePopup()
	skillMenu:SetKeyboardInputEnabled(false)

	skillMenu.Paint = function(self, pw, ph)
		draw.RoundedBox(8, 0, 0, pw, ph, colDark)
		draw.RoundedBoxEx(8, 0, 0, pw, 60, Darken(info.color, 0.55, 255), true, true, false, false)
		surface.SetDrawColor(info.color)
		surface.DrawOutlinedRect(0, 0, pw, ph, 2)

		draw.SimpleText(info.name .. " skill tree", "ZB_InterfaceMediumLarge", 20, 30, colWhite, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("Points: " .. lply:GetNWInt("ZS_Points", 0), "ZB_InterfaceMediumLarge", pw - 50, 30, colWhite, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		draw.SimpleText("Damage to survivors: 1 pt per HP  |  Eating a corpse: 100 pts  |  I - close", "ZB_InterfaceSmall", pw * 0.5, ph - 16, colGray, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local body = vgui.Create("DPanel", skillMenu)
	body:SetPos(10, 70)
	body:SetSize(w - 20, h - 110)
	body.Paint = function(self, pw, ph)
		draw.RoundedBox(6, 0, 0, pw, ph, Darken(info.color, 0.08, 220))
	end

	BuildSkillGrid(body, class, info)
end

hook.Add("PlayerButtonDown", "ZS_SkillTreeKey", function(ply, button)
	if button ~= KEY_I or not IsFirstTimePredicted() then return end
	if ply ~= LocalPlayer() or zb.CROUND ~= "zs" then return end
	if IsValid(vgui.GetKeyboardFocus()) or gui.IsGameUIVisible() then return end

	UI.ToggleSkillTree()
end)

-- HUD

function UI.DrawHUD(x, y)
	local class = UI.GetClass()

	if class then
		local info = ZS_ZOMBIE_CLASSES[class]
		local w, h = ScreenScale(110), ScreenScale(18)

		draw.RoundedBox(6, x, y, w, h, Darken(info.color, 0.3, 170))
		draw.SimpleText(info.name .. "  |  " .. lply:GetNWInt("ZS_Points", 0) .. " pts  [I]", "ZB_InterfaceMedium", x + ScreenScale(5), y + h * 0.5, info.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	-- прогресс поедания
	local eatEnd = lply:GetNWFloat("ZS_EatEnd", 0)

	if lply:Alive() and eatEnd > 0 and IsValid(lply:GetNWEntity("ZS_EatTarget")) then
		local frac = 1 - math.Clamp((eatEnd - CurTime()) / MODE.EatTime, 0, 1)
		local bw, bh = ScrW() * 0.25, ScreenScale(8)
		local bx, by = ScrW() * 0.5 - bw * 0.5, ScrH() * 0.65
		local col = class and ZS_ZOMBIE_CLASSES[class].color or colWhite

		draw.RoundedBox(4, bx, by, bw, bh, colDark)
		draw.RoundedBox(4, bx, by, bw * frac, bh, col)
		draw.SimpleText("Devouring...", "ZB_InterfaceMedium", ScrW() * 0.5, by - ScreenScale(8), colWhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end
