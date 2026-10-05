local MODE = MODE

-- Аирдроп выживших: со второй волны в каждую подготовку с неба падает ящик (lua/entities/zs_airdrop.lua).
-- Каждый выживший получает из него свой лут: 1 специальный предмет (ящик снабжения) и 2 обычных.

util.AddNetworkString("zs_airdrop")

MODE.AirdropFromWave = 2
MODE.AirdropSkyOffset = 80
MODE.AirdropMaxDropHeight = 3000

local TEAM_SURVIVORS = 0

-- обычный лут; вес винтовок и ружей растет с номером волны
local lootCategories = {
	pistol = {
		weight = function(wave) return 30 end,
		items = {"weapon_glock17", "weapon_makarov", "weapon_m9beretta", "weapon_hk_usp", "weapon_px4beretta", "weapon_cz75", "weapon_deagle", "weapon_revolver2"},
	},
	medicine = {
		weight = function(wave) return 25 end,
		items = ZS_MEDICAL_ITEMS,
	},
	melee = {
		weight = function(wave) return 20 end,
		items = {"weapon_hg_crowbar", "weapon_bat", "weapon_hatchet", "weapon_tomahawk", "weapon_hg_axe", "weapon_hg_sledgehammer", "weapon_leadpipe"},
	},
	armor = {
		weight = function(wave) return 10 + wave end,
		items = {"vest3", "vest4", "helmet1", "helmet2"},
		armor = true,
	},
	shotgun = {
		weight = function(wave) return 4 + wave * 2 end,
		items = {"weapon_doublebarrel_short", "weapon_doublebarrel", "weapon_remington870", "weapon_xm1014"},
	},
	rifle = {
		weight = function(wave) return math.max(wave - 1, 0) * 4 end,
		items = {"weapon_mp5", "weapon_mp7", "weapon_sks", "weapon_kar98", "weapon_draco", "weapon_ar15", "weapon_akm", "weapon_sr25"},
	},
}

local specialItems = {"weapon_zs_box_arsenal", "weapon_zs_box_medical", "weapon_zs_box_tech"}

local function PickCategory(wave)
	local total = 0
	for _, cat in pairs(lootCategories) do
		total = total + cat.weight(wave)
	end

	local roll = math.Rand(0, total)
	for _, cat in SortedPairs(lootCategories) do
		roll = roll - cat.weight(wave)
		if roll <= 0 then return cat end
	end

	return lootCategories.pistol
end

local function ItemName(class)
	local stored = weapons.GetStored(class)
	if stored and stored.PrintName then return stored.PrintName end

	local armorName = hg.armorNames and hg.armorNames[class]
	return armorName or class
end

local function GiveLootItem(ply, crate, cat, class)
	if cat.armor then
		local ent = ents.Create("ent_armor_" .. class)
		if IsValid(ent) then
			ent:SetPos(crate:GetPos() + Vector(math.Rand(-20, 20), math.Rand(-20, 20), crate:OBBMaxs().z + 10))
			ent:Spawn()
		end

		return ItemName(class)
	end

	local wep = ply:Give(class)

	if IsValid(wep) and wep:GetPrimaryAmmoType() >= 0 and wep:GetMaxClip1() > 0 then
		ply:GiveAmmo(wep:GetMaxClip1() * 2, wep:GetPrimaryAmmoType(), true)
	end

	return ItemName(class)
end

function ZS_GiveAirdropLoot(ply, crate)
	local wave = GetGlobalInt("ZS_Wave", 1)
	local got = {}

	local special = specialItems[math.random(#specialItems)]
	ply:Give(special)
	got[#got + 1] = ItemName(special)

	for _ = 1, 2 do
		local cat = PickCategory(wave)
		got[#got + 1] = GiveLootItem(ply, crate, cat, cat.items[math.random(#cat.items)])
	end

	ply:ChatPrint("Груз: " .. table.concat(got, ", "))
end

-- точка сброса: над случайной точкой карты, где сверху открытое небо
local function GetCandidatePoints()
	local points = zb.GetMapPoints("RandomSpawns")
	if points and #points > 0 then
		return zb.TranslatePointsToVectors(points)
	end

	local list = {}
	for _, area in ipairs(navmesh.GetAllNavAreas()) do
		if area:GetSizeX() > 64 and area:GetSizeY() > 64 then
			list[#list + 1] = area:GetCenter()
		end
	end

	if #list > 0 then return list end

	local pos = zb:GetRandomSpawn()
	return pos and {pos} or {}
end

local function FindDropPos(mode)
	local points = GetCandidatePoints()
	if #points == 0 then return end

	for _ = 1, 25 do
		local ground = points[math.random(#points)]

		local tr = util.TraceLine({
			start = ground + Vector(0, 0, 32),
			endpos = ground + Vector(0, 0, 16384),
			mask = MASK_SOLID_BRUSHONLY,
		})

		if tr.HitSky then
			local height = math.min(tr.HitPos.z - mode.AirdropSkyOffset, ground.z + mode.AirdropMaxDropHeight)
			return Vector(ground.x, ground.y, height), true
		end
	end

	-- открытого неба нет: просто кладем ящик в случайное место карты
	return points[math.random(#points)] + Vector(0, 0, 24), false
end

function MODE:SpawnAirdrop()
	local pos, fromSky = FindDropPos(self)
	if not pos then return end

	local crate = ents.Create("zs_airdrop")
	if not IsValid(crate) then return end

	crate:SetPos(pos)
	crate:SetAngles(Angle(0, math.Rand(0, 360), 0))
	crate:Spawn()

	if fromSky then
		crate:StartFalling()
	end

	local survivors = {}
	for _, ply in player.Iterator() do
		if ply:Team() == TEAM_SURVIVORS then survivors[#survivors + 1] = ply end
	end

	net.Start("zs_airdrop")
		net.WriteVector(pos)
	net.Send(survivors)
end

hook.Add("ZS_PrepStart", "ZS_Airdrop", function(wave)
	local mode = CurrentRound()
	if not mode or mode.name ~= "zs" or wave < mode.AirdropFromWave then return end

	mode:SpawnAirdrop()
end)

-- для теста: zb_zsairdrop
concommand.Add("zb_zsairdrop", function(ply)
	if IsValid(ply) and not ply:IsAdmin() then return end

	local mode = CurrentRound()
	if mode and mode.SpawnAirdrop then mode:SpawnAirdrop() end
end)
