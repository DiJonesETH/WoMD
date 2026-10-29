-- Боссы на клиенте (сервер: sv_zs_boss.lua): оповещение о появлении, полоска здоровья, щупальце василиска.
-- Модели боссов рисует общая система моделей зараженных (sh_zs_zombie.lua).

local colBoss = Color(200, 170, 40)
local colBar = Color(200, 40, 30)
local colBack = Color(0, 0, 0, 200)

-- появление босса
local riseText, riseEnd = nil, 0

net.Receive("zs_boss_rise", function()
	local ply = net.ReadEntity()
	local name = net.ReadString()

	riseText = "THE " .. string.upper(name) .. " HAS RISEN"
	riseEnd = CurTime() + 4

	chat.AddText(colBar, "[Boss] ", color_white, (IsValid(ply) and ply:Nick() or "Someone") .. " has turned into the " .. name .. "!")
	surface.PlaySound("npc/zombie_poison/pz_alert2.wav")
end)

-- полоска здоровья босса для всех
hook.Add("HUDPaint", "ZS_BossHealth", function()
	local boss = GetGlobalEntity("ZS_Boss")

	if IsValid(boss) and ZS_IsBoss(boss) and boss:Alive() then
		local hp, maxHp = boss:GetNWInt("ZS_BossHP", 0), math.max(boss:GetNWInt("ZS_BossMaxHP", 1), 1)
		local w, h = math.min(ScrW() * 0.4, 600), 14
		local x, y = ScrW() * 0.5 - w * 0.5, 40

		local info = ZS_BOSS_CLASSES[boss.PlayerClassName]
		draw.SimpleTextOutlined(info and string.upper(info.name) or "BOSS", "DermaLarge", ScrW() * 0.5, y - 6, colBoss, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 2, color_black)
		draw.RoundedBox(2, x - 2, y - 2, w + 4, h + 4, colBack)
		draw.RoundedBox(2, x, y, w * math.Clamp(hp / maxHp, 0, 1), h, colBar)
		draw.SimpleTextOutlined(hp .. " / " .. maxHp, "DermaDefaultBold", ScrW() * 0.5, y + h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
	end

	if riseText and riseEnd > CurTime() then
		local alpha = math.Clamp((riseEnd - CurTime()) / 1, 0, 1) * 255
		draw.SimpleTextOutlined(riseText, "ZB_HomicideMediumLarge", ScrW() * 0.5, ScrH() * 0.3, ColorAlpha(colBar, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, ColorAlpha(color_black, alpha))
	end
end)

-- щупальце василиска: мясной жгут от босса до цели (регдолла выжившего) или до точки промаха
local tentacles = {}
local tentacleMat = Material("cable/cable2")
local colTentacle = Color(150, 40, 40)

net.Receive("zs_boss_tentacle", function()
	local boss, target, hitPos, duration = net.ReadEntity(), net.ReadEntity(), net.ReadVector(), net.ReadFloat()
	if not IsValid(boss) then return end

	tentacles[boss] = {target = target, hitPos = hitPos, endTime = CurTime() + duration}
end)

hook.Add("PostDrawTranslucentRenderables", "ZS_BossTentacle", function(depth, skybox)
	if skybox then return end

	for boss, t in pairs(tentacles) do
		if not IsValid(boss) or t.endTime < CurTime() then
			tentacles[boss] = nil
			continue
		end

		local from = boss:WorldSpaceCenter() + Vector(0, 0, 16)
		local to = IsValid(t.target) and t.target:WorldSpaceCenter() or t.hitPos

		render.SetMaterial(tentacleMat)
		render.StartBeam(8)
		for i = 0, 7 do
			local frac = i / 7
			local wave = math.sin(frac * math.pi * 3 + CurTime() * 20) * 4 * (1 - frac)
			render.AddBeam(LerpVector(frac, from, to) + Vector(0, 0, wave), 6 - frac * 3, frac * 4, colTentacle)
		end
		render.EndBeam()
	end
end)
