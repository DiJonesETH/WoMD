-- Разум улья (улучшение стадных феромонов metaboliser, sh_zs_metaboliser.lua): если навык есть хотя бы у одного
-- игрока (GlobalBool ZS_HiveMind), все живые зараженные включают зрение кнопкой фонарика (F).
-- Зрение как у зомби в JetBoom/zombiesurvival: мир затемнен и окрашен в красный, вокруг зараженного тусклый свет,
-- выжившие видны сквозь стены как светящиеся ауры на костях; цвет ауры показывает здоровье (зеленый - цел, красный - ранен)

local glowMat = Material("sprites/light_glow02_add_noz")
local auraBones = {
	"ValveBiped.Bip01_Head1", "ValveBiped.Bip01_Spine2", "ValveBiped.Bip01_Pelvis",
	"ValveBiped.Bip01_L_Hand", "ValveBiped.Bip01_R_Hand",
	"ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_R_Forearm",
	"ValveBiped.Bip01_L_Calf", "ValveBiped.Bip01_R_Calf",
	"ValveBiped.Bip01_L_Foot", "ValveBiped.Bip01_R_Foot",
}
local AURA_RANGE = 3000

local visionOn = false

local function CanUseVision()
	return GetGlobalBool("ZS_HiveMind", false) and IsValid(lply) and lply:Alive() and ZS_IsZombie and ZS_IsZombie(lply)
end

-- F (фонарик) переключает зрение
hook.Add("PlayerBindPress", "ZS_HiveMindVision", function(ply, bind, pressed)
	if not pressed or not string.find(bind, "impulse 100", 1, true) then return end
	if not CanUseVision() then return end

	visionOn = not visionOn
	surface.PlaySound(visionOn and "npc/zombie/zombie_alert1.wav" or "npc/zombie/zombie_voice_idle1.wav")

	return true
end)

local function VisionActive()
	if visionOn and not CanUseVision() then visionOn = false end
	return visionOn
end

hook.Add("RenderScreenspaceEffects", "ZS_HiveMindVision", function()
	if not VisionActive() then return end

	DrawColorModify({
		["$pp_colour_addr"] = 0.08,
		["$pp_colour_addg"] = 0,
		["$pp_colour_addb"] = 0,
		["$pp_colour_brightness"] = -0.05,
		["$pp_colour_contrast"] = 1.3,
		["$pp_colour_colour"] = 0.35,
		["$pp_colour_mulr"] = 0.4,
		["$pp_colour_mulg"] = 0,
		["$pp_colour_mulb"] = 0,
	})
end)

-- тусклый красный свет вокруг зараженного, чтобы видеть в темноте
hook.Add("Think", "ZS_HiveMindVisionLight", function()
	if not VisionActive() then return end

	local light = DynamicLight(lply:EntIndex() + 4096)
	if light then
		light.pos = lply:EyePos()
		light.r, light.g, light.b = 140, 30, 30
		light.brightness = 1
		light.decay = 1000
		light.size = 450
		light.dietime = CurTime() + 0.2
	end
end)

local colAura = Color(255, 255, 255)

-- ауры выживших сквозь стены
hook.Add("PostDrawTranslucentRenderables", "ZS_HiveMindAuras", function(depth, skybox)
	if skybox or not VisionActive() then return end

	local eye = EyePos()
	render.SetMaterial(glowMat)

	for _, ply in player.Iterator() do
		if ply == lply or not ply:Alive() or ply:Team() ~= 0 or ply:IsDormant() then continue end

		local char = hg.GetCurrentCharacter(ply)
		if not IsValid(char) then continue end

		local dist = char:GetPos():Distance(eye)
		if dist > AURA_RANGE then continue end

		local healthFrac = math.Clamp(ply:Health() / math.max(ply:GetMaxHealth(), 1), 0, 1)
		colAura.r = Lerp(healthFrac, 255, 40)
		colAura.g = Lerp(healthFrac, 30, 230)
		colAura.b = 20
		colAura.a = math.Clamp(255 * (1 - dist / AURA_RANGE) + 60, 60, 255)

		local size = 18 + math.sin(CurTime() * 4 + ply:EntIndex()) * 3

		for _, boneName in ipairs(auraBones) do
			local bone = char:LookupBone(boneName)
			local pos = bone and char:GetBonePosition(bone)
			if pos then render.DrawSprite(pos, size, size, colAura) end
		end
	end
end)
