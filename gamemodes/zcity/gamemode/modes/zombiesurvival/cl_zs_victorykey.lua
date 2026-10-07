-- "Ключ к победе" (sv_zs_victorykey.lua): сообщение, кейпад бомбы, записка с кодом и эффекты термоядерного взрыва

local colRed = Color(255, 40, 40)

net.Receive("zs_victorykey_msg", function()
	chat.AddText(colRed, "The key for the victory is around the map...")
	surface.PlaySound("ambient/alarms/klaxon1.wav")
end)

surface.CreateFont("ZS_KeypadDisplay", {font = "Courier New", size = 48, weight = 800, extended = true})
surface.CreateFont("ZS_KeypadButton", {font = "Roboto", size = 26, weight = 800, extended = true})
surface.CreateFont("ZS_NoteCode", {font = "Courier New", size = 54, weight = 800, extended = true})
surface.CreateFont("ZS_NoteText", {font = "Courier New", size = 20, weight = 600, extended = true, italic = true})

------------------------------------------------------------------ кейпад

local colCase = Color(38, 40, 36, 250)
local colCaseEdge = Color(90, 95, 85)
local colScreen = Color(10, 22, 12)
local colDigits = Color(90, 255, 120)
local colKey = Color(62, 64, 60)
local colKeyHover = Color(85, 88, 82)

local keypad

local function OpenKeypad(bomb)
	if IsValid(keypad) then keypad:Remove() end

	local frame = vgui.Create("DFrame")
	keypad = frame
	frame:SetSize(300, 430)
	frame:Center()
	frame:SetTitle("")
	frame:MakePopup()
	frame:SetKeyboardInputEnabled(false)

	frame.Code = ""
	frame.Status = nil

	function frame:Paint(w, h)
		draw.RoundedBox(10, 0, 0, w, h, colCaseEdge)
		draw.RoundedBox(8, 4, 4, w - 8, h - 8, colCase)

		draw.SimpleText("THERMONUCLEAR DEVICE", "DermaDefaultBold", w * 0.5, 22, colRed, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		draw.RoundedBox(4, 20, 40, w - 40, 70, colScreen)

		local shown = self.Code .. string.rep("_", 4 - #self.Code)
		local col = self.Status == false and colRed or colDigits
		if self.Status == false and self.StatusTime + 1 < CurTime() then
			self.Status = nil
		end

		draw.SimpleText(string.gsub(shown, ".", "%0 "), "ZS_KeypadDisplay", w * 0.5, 75, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	function frame:Think()
		local ply = LocalPlayer()
		if not IsValid(bomb) or bomb:IsArmed() or not ply:Alive() or ply:GetPos():Distance(bomb:GetPos()) > bomb.UseDistance then
			self:Remove()
		end
	end

	local function Press(key)
		surface.PlaySound("buttons/button" .. (key == "ENT" and "9" or "16") .. ".wav")

		if key == "CLR" then
			frame.Code = ""
		elseif key == "ENT" then
			if #frame.Code < 4 then return end

			net.Start("zs_bomb_code")
				net.WriteEntity(bomb)
				net.WriteString(frame.Code)
			net.SendToServer()
		elseif #frame.Code < 4 then
			frame.Code = frame.Code .. key
		end
	end

	local keys = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "CLR", "0", "ENT"}
	local size, gap = 72, 12
	local startX = (300 - size * 3 - gap * 2) * 0.5

	for i, key in ipairs(keys) do
		local col, row = (i - 1) % 3, math.floor((i - 1) / 3)

		local btn = vgui.Create("DButton", frame)
		btn:SetPos(startX + col * (size + gap), 128 + row * (size + gap))
		btn:SetSize(size, size)
		btn:SetText("")

		function btn:Paint(w, h)
			draw.RoundedBox(6, 0, 0, w, h, self:IsHovered() and colKeyHover or colKey)
			draw.SimpleText(key, "ZS_KeypadButton", w * 0.5, h * 0.5, key == "ENT" and colDigits or (key == "CLR" and colRed or color_white), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		function btn:DoClick() Press(key) end
	end
end

net.Receive("zs_bomb_keypad", function()
	local bomb = net.ReadEntity()
	if IsValid(bomb) then OpenKeypad(bomb) end
end)

-- неверный код: экран мигает красным и стирается; верный - кейпад закрывается
net.Receive("zs_bomb_result", function()
	net.ReadEntity()
	local ok = net.ReadBool()

	if not IsValid(keypad) then return end

	if ok then
		keypad:Remove()
	else
		keypad.Status = false
		keypad.StatusTime = CurTime()
		keypad.Code = ""
	end
end)

------------------------------------------------------------------ записка

local colPaper = Color(232, 226, 205)
local colInk = Color(40, 35, 30)

net.Receive("zs_victory_note", function()
	local code = net.ReadString()

	local frame = vgui.Create("DFrame")
	frame:SetSize(420, 340)
	frame:Center()
	frame:SetTitle("")
	frame:MakePopup()
	frame:SetKeyboardInputEnabled(false)

	local lines = {
		"is the code to solve all the problems.",
		"End our suffering.",
		"",
		"Sincerely, D.",
	}

	function frame:Paint(w, h)
		draw.RoundedBox(2, 0, 0, w, h, colPaper)
		surface.SetDrawColor(200, 190, 165)
		for y = 120, h - 20, 26 do surface.DrawLine(20, y, w - 20, y) end

		draw.SimpleText(code, "ZS_NoteCode", w * 0.5, 80, colInk, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		for i, line in ipairs(lines) do
			draw.SimpleText(line, "ZS_NoteText", 30, 110 + i * 26, colInk, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
		end
	end
end)

------------------------------------------------------------------ термоядерный взрыв
-- по мотивам ent_jack_gmod_eznuke_big и клиента JMod (Jackarunda/gmod): вспышка цветокоррекцией,
-- грибовидный дым (eff_zs_thermonuke) и густой серый туман после взрыва

local flashEnd, flashPos, smokeEnd = 0, nil, 0
local FLASH_TIME, SMOKE_TIME = 8, 30

net.Receive("zs_thermonuke", function()
	local pos = net.ReadVector()

	flashPos = pos
	flashEnd = CurTime() + FLASH_TIME
	smokeEnd = CurTime() + SMOKE_TIME

	surface.PlaySound("ambient/explosions/explode_" .. math.random(9) .. ".wav")

	for i = 0, 10 do
		timer.Simple(i, function()
			local effect = EffectData()
			effect:SetOrigin(pos + Vector(0, 0, 100))
			util.Effect("eff_zs_thermonuke", effect)
		end)
	end
end)

hook.Add("RenderScreenspaceEffects", "ZS_ThermonukeFlash", function()
	local frac = (flashEnd - CurTime()) / 10
	if frac <= 0 then return end

	DrawColorModify({
		["$pp_colour_addr"] = frac * 0.5,
		["$pp_colour_addg"] = 0,
		["$pp_colour_addb"] = 0,
		["$pp_colour_brightness"] = frac * 0.5,
		["$pp_colour_contrast"] = 1 + frac * 0.5,
		["$pp_colour_colour"] = 1,
		["$pp_colour_mulr"] = 0,
		["$pp_colour_mulg"] = 0,
		["$pp_colour_mulb"] = 0,
	})
end)

local function SmokeFrac()
	if smokeEnd <= CurTime() then return end
	return ((smokeEnd - CurTime()) / SMOKE_TIME) ^ 0.15
end

hook.Add("SetupWorldFog", "ZS_ThermonukeFog", function()
	local frac = SmokeFrac()
	if not frac then return end

	render.FogMode(MATERIAL_FOG_LINEAR)
	render.FogColor(100, 100, 100)
	render.FogStart(0)
	render.FogEnd(1000)
	render.FogMaxDensity(frac)

	return true
end)

hook.Add("SetupSkyboxFog", "ZS_ThermonukeFog", function(scale)
	local frac = SmokeFrac()
	if not frac then return end

	render.FogMode(MATERIAL_FOG_LINEAR)
	render.FogColor(100, 100, 100)
	render.FogStart(1 * scale)
	render.FogEnd(1500 * scale)
	render.FogMaxDensity(frac)

	return true
end)
