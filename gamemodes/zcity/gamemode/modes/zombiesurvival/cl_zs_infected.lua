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

local GRID_COLS, GRID_ROWS = 3, 5

surface.CreateFont("ZS_SkillName", {font = "Roboto", size = math.max(ScreenScale(7), 16), weight = 700, extended = true})
surface.CreateFont("ZS_SkillDesc", {font = "Roboto", size = math.max(ScreenScale(4.6), 12), weight = 500, extended = true})

-- перенос текста по словам под ширину карточки (с учетом \n)
local function WrapText(text, font, width)
	surface.SetFont(font)

	local lines = {}

	for _, paragraph in ipairs(string.Explode("\n", text or "")) do
		local line = ""

		for _, word in ipairs(string.Explode(" ", paragraph)) do
			local candidate = line == "" and word or (line .. " " .. word)

			if surface.GetTextSize(candidate) > width and line ~= "" then
				lines[#lines + 1] = line
				line = word
			else
				line = candidate
			end
		end

		lines[#lines + 1] = line
	end

	return lines
end
local colLocked = Color(70, 70, 70)
local colLine = Color(200, 200, 200, 90)

-- состояние навыка для отрисовки: owned, available, nopoints, locked
local function SkillState(class, id)
	if mySkills[id] then return "owned" end

	local ok, reason = MODE:CanLearnSkill(mySkills, class, id, lply:GetNWInt("ZS_Points", 0))
	if ok then return "available" end
	if reason == "points" then return "nopoints" end

	return "locked"
end

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

	local pw, ph = parent:GetSize()
	local gap = 16
	local nodeW = (pw - gap * (GRID_COLS + 1)) / GRID_COLS
	local nodeH = (ph - gap * (GRID_ROWS + 1)) / GRID_ROWS

	local function NodeRect(skill)
		local pos = skill.pos or {x = 0, y = 0}
		return gap + pos.x * (nodeW + gap), gap + pos.y * (nodeH + gap)
	end

	-- линии связей между навыками рисуются под карточками
	local oldPaint = parent.Paint
	parent.Paint = function(self, w, h)
		if oldPaint then oldPaint(self, w, h) end

		surface.SetDrawColor(colLine)

		for id, skill in pairs(tree) do
			local x1, y1 = NodeRect(skill)

			for _, list in ipairs({skill.requires or {}, skill.requiresAny or {}}) do
				for _, req in ipairs(list) do
					local other = tree[req]

					if other then
						local x2, y2 = NodeRect(other)
						local lit = mySkills[id] and mySkills[req]

						surface.SetDrawColor(lit and (skill.color or info.color) or colLine)
						surface.DrawLine(x1 + nodeW * 0.5, y1 + nodeH * 0.5, x2 + nodeW * 0.5, y2 + nodeH * 0.5)
					end
				end
			end
		end
	end

	for id, skill in SortedPairs(tree) do
		local x, y = NodeRect(skill)
		local col = skill.color or info.color

		local node = vgui.Create("DButton", parent)
		node:SetPos(x, y)
		node:SetSize(nodeW, nodeH)
		node:SetText("")
		node.DescLines = WrapText(skill.desc, "ZS_SkillDesc", nodeW - 16)

		node.Paint = function(self, nw, nh)
			local state = SkillState(class, id)
			local main = state == "locked" and colLocked or col
			local bg

			if state == "owned" then
				bg = Darken(col, 0.6, 250)
			elseif state == "available" then
				bg = Darken(col, self:IsHovered() and 0.4 or 0.25, 250)
			else
				bg = Darken(main, 0.15, 250)
			end

			draw.RoundedBox(6, 0, 0, nw, nh, bg)
			surface.SetDrawColor(main)
			surface.DrawOutlinedRect(0, 0, nw, nh, (state == "owned" or (state == "available" and self:IsHovered())) and 3 or 1)

			-- название и описание навыка
			draw.SimpleText(skill.name or id, "ZS_SkillName", nw * 0.5, 4, state == "locked" and colGray or col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

			surface.SetFont("ZS_SkillName")
			local _, nameH = surface.GetTextSize("A")
			surface.SetFont("ZS_SkillDesc")
			local _, lineH = surface.GetTextSize("A")

			local y = 6 + nameH
			for _, line in ipairs(self.DescLines) do
				draw.SimpleText(line, "ZS_SkillDesc", 8, y, state == "locked" and colGray or colWhite, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
				y = y + lineH
			end

			local status
			if state == "owned" then
				status = "Learned"
			elseif state == "locked" then
				status = "Locked"
			else
				status = (skill.cost or 0) .. " pts"
			end

			draw.SimpleText(status, "ZS_SkillName", nw - 8, nh - 4, state == "available" and col or colGray, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
		end

		node.DoClick = function()
			if SkillState(class, id) ~= "available" then
				surface.PlaySound("buttons/button10.wav")
				return
			end

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
	local w, h = math.min(ScrW() * 0.9, 1400), ScrH() * 0.94

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
		draw.SimpleText("Damage to survivors: 2 pts per HP  |  Devoured corpse: 100 pts  |  Branches are exclusive  |  I - close", "ZB_InterfaceSmall", pw * 0.5, ph - 16, colGray, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
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
