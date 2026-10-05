MODE.name = "zs"

-- Аирдроп выживших: оповещение и метка на экране, пока ящик лежит на карте

local colAirdrop = Color(255, 70, 50)

net.Receive("zs_airdrop", function()
	surface.PlaySound("ambient/alarms/klaxon1.wav")
	chat.AddText(colAirdrop, "[Airdrop] ", color_white, "Груз сброшен! Ищите красный сигнальный огонь. Ящик исчезнет через 2 минуты.")
end)

hook.Add("HUDPaint", "ZS_AirdropMarker", function()
	if zb.CROUND ~= "zs" or not IsValid(lply) or not lply:Alive() or lply:Team() ~= 0 then return end

	for _, crate in ipairs(ents.FindByClass("zs_airdrop")) do
		local pos = crate:GetPos() + Vector(0, 0, 40)
		local scr = pos:ToScreen()
		if not scr.visible then continue end

		local dist = math.Round(lply:GetPos():Distance(crate:GetPos()) * 0.01905)
		local left = math.max(math.ceil(crate:GetDieTime() - CurTime()), 0)

		draw.SimpleTextOutlined("AIRDROP", "DermaLarge", scr.x, scr.y, colAirdrop, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 2, color_black)
		draw.SimpleTextOutlined(dist .. " м  |  " .. left .. " сек  |  E - забрать груз", "DermaDefaultBold", scr.x, scr.y + 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, color_black)
	end
end)
