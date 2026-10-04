MODE.name = "zs"

local MODE = MODE

local TEAM_SURVIVORS = 0
local WINNER_NONE = 3

local colSurvivor = Color(60, 160, 220)
local colInfected = Color(170, 25, 25)
local colPrep = Color(230, 200, 60)
local colWhite = Color(255, 255, 255)
local colShadow = Color(0, 0, 0, 200)
local colBG = Color(0, 0, 0, 150)

local announce = {text = "", color = colWhite, time = 0}
local classMenuShown = false

local function Announce(text, color)
	announce.text = text
	announce.color = color
	announce.time = CurTime()
end

net.Receive("zs_start", function()
	local waves = net.ReadUInt(8)

	classMenuShown = false

	zb.RemoveFade()
	Announce("Zombie Survival - " .. waves .. " waves", colInfected)
end)

net.Receive("zs_phase", function()
	local wave = net.ReadUInt(8)
	local active = net.ReadBool()

	if active then
		surface.PlaySound("ambient/alarms/warningbell1.wav")
		Announce("Wave " .. wave .. " has begun!", colInfected)
	else
		surface.PlaySound("buttons/bell1.wav")
		Announce("Preparation before wave " .. wave, colPrep)
	end
end)

net.Receive("zs_roundend", function()
	local winner = net.ReadUInt(2)
	local wave = net.ReadUInt(8)
	local waves = net.ReadUInt(8)

	classMenuShown = false

	surface.PlaySound("ambient/alarms/warningbell1.wav")

	if winner == WINNER_NONE then
		Announce("Round ended", colWhite)
	elseif winner == TEAM_SURVIVORS then
		Announce("Survivors held out through all " .. waves .. " waves!", colSurvivor)
	else
		Announce("The infection wins! Survivors fell on wave " .. wave .. "/" .. waves, colInfected)
	end
end)

local function FormatTime(seconds)
	seconds = math.max(math.ceil(seconds), 0)

	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function DrawRoundInfo()
	local wave, waves, active, phaseEnd = MODE:GetWaveInfo()
	if waves <= 0 then return end

	local x, y = ScreenScale(8), ScreenScale(8)
	local w, h = ScreenScale(110), ScreenScale(32)

	draw.RoundedBox(6, x, y, w, h, colBG)

	local title = "Wave " .. math.max(wave, 1) .. " / " .. waves
	draw.SimpleText(title, "ZB_InterfaceMediumLarge", x + ScreenScale(5), y + ScreenScale(3), colWhite, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	local status, color
	if zb.ROUND_STATE ~= 1 or phaseEnd <= 0 then
		status, color = "Waiting", colWhite
	elseif active then
		status, color = "Wave: " .. FormatTime(phaseEnd - CurTime()), colInfected
	else
		status, color = "Preparation: " .. FormatTime(phaseEnd - CurTime()), colPrep
	end

	draw.SimpleText(status, "ZB_InterfaceMedium", x + ScreenScale(5), y + ScreenScale(17), color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

local function DrawRespawnHint()
	if lply:Alive() or zb.ROUND_STATE ~= 1 then return end

	local team_ = lply:Team()
	if team_ == TEAM_SPECTATOR or team_ == TEAM_SURVIVORS then return end

	local _, _, active = MODE:GetWaveInfo()
	local text = active and "Press E to rise as an infected" or "Infected can't spawn during preparation"

	if not MODE.InfectedUI.GetClass() then
		text, active = "Press E to choose your infection", true
	end

	draw.SimpleText(text, "ZB_InterfaceMediumLarge", ScrW() * 0.5 + 2, ScrH() * 0.85 + 2, colShadow, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(text, "ZB_InterfaceMediumLarge", ScrW() * 0.5, ScrH() * 0.85, active and colInfected or colPrep, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local function DrawAnnounce()
	local elapsed = CurTime() - announce.time
	if elapsed > 5 then return end

	local alpha = math.Clamp(5 - elapsed, 0, 1) * 255
	local col = ColorAlpha(announce.color, alpha)

	draw.SimpleText(announce.text, "ZB_HomicideMediumLarge", ScrW() * 0.5 + 2, ScrH() * 0.2 + 2, ColorAlpha(colShadow, alpha * 0.8), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(announce.text, "ZB_HomicideMediumLarge", ScrW() * 0.5, ScrH() * 0.2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function MODE:HUDPaint()
	DrawRoundInfo()
	DrawRespawnHint()
	DrawAnnounce()

	MODE.InfectedUI.DrawHUD(ScreenScale(8), ScreenScale(44))
end

local useWasDown = false

function MODE:Think()
	if not IsValid(lply) or lply:Alive() then
		useWasDown = false
		return
	end

	local useDown = lply:KeyDown(IN_USE)
	local infected = zb.ROUND_STATE == 1 and lply:Team() ~= TEAM_SPECTATOR and lply:Team() ~= TEAM_SURVIVORS

	if useDown and not useWasDown then
		if infected and not MODE.InfectedUI.GetClass() then
			MODE.InfectedUI.OpenClassMenu()
		else
			net.Start("zs_requestspawn")
			net.SendToServer()
		end
	end

	-- в начале подраунда меню выбора класса открывается само
	if infected and not MODE.InfectedUI.GetClass() and not classMenuShown then
		classMenuShown = true
		MODE.InfectedUI.OpenClassMenu()
	end

	useWasDown = useDown
end
