local MODE = MODE

-- Аирдроп выживших: со второй волны в каждую подготовку с неба падает ящик (lua/entities/zs_airdrop.lua).
-- Каждому выжившему ящик предлагает свои 3 предмета (первый с шансом 20% - специальный: ящик снабжения,
-- трупосжигатель или турель). По E открывается окно, где игрок берет нужное, а ненужное оставляет.

util.AddNetworkString("zs_airdrop")
util.AddNetworkString("zs_airdrop_menu")
util.AddNetworkString("zs_airdrop_take")

MODE.AirdropFromWave = 2
MODE.AirdropSkyOffset = 80
MODE.AirdropMaxDropHeight = 3000
MODE.AirdropMinDist = 300 -- ящик падает в этом радиусе от кого-нибудь из живых выживших
MODE.AirdropMaxDist = 2000

local TEAM_SURVIVORS = 0

-- Шанс специального предмета (ящика снабжения) в первом слоте; если не выпал - там обычный предмет
MODE.AirdropSpecialChance = 20

-- Обычный лут: шансы в процентах (сумма всегда 100), меняются линейно от первого аирдропа (p = 0)
-- до последней волны режима (p = 1), поэтому короткий режим (6 волн) проходит ту же прогрессию быстрее длинного (12 волн):
--            p = 0 -> p = 1
-- пистолеты    30  ->  35
-- медицина     22  ->  13
-- ближний бой  22  ->   5
-- броня        10  ->  14
-- ружья        10  ->  14
-- винтовки      6  ->  19
local lootCategories = {
	pistol = {
		chance = {30, 35},
		items = {"weapon_glock17", "weapon_makarov", "weapon_m9beretta", "weapon_hk_usp", "weapon_px4beretta", "weapon_cz75", "weapon_deagle", "weapon_revolver2"},
	},
	medicine = {
		chance = {22, 13},
		items = ZS_MEDICAL_ITEMS,
	},
	melee = {
		chance = {22, 5},
		items = {"weapon_hg_crowbar", "weapon_bat", "weapon_hatchet", "weapon_tomahawk", "weapon_hg_axe", "weapon_hg_sledgehammer", "weapon_leadpipe"},
	},
	armor = {
		chance = {10, 14},
		items = {"vest3", "vest4", "helmet1", "helmet2"},
		armor = true,
	},
	shotgun = {
		chance = {10, 14},
		items = {"weapon_doublebarrel_short", "weapon_doublebarrel", "weapon_remington870", "weapon_xm1014"},
	},
	rifle = {
		chance = {6, 19},
		items = {"weapon_mp5", "weapon_mp7", "weapon_sks", "weapon_kar98", "weapon_draco", "weapon_ar15", "weapon_akm", "weapon_sr25"},
	},
}

local specialItems = {"weapon_zs_box_arsenal", "weapon_zs_box_medical", "weapon_zs_box_tech", "weapon_zs_box_incinerator"}

for _, id in ipairs(ZS_TURRET_ORDER or {}) do
	specialItems[#specialItems + 1] = ZS_TURRETS[id].weapon
end

-- прогрессия 0..1: первый аирдроп (волна AirdropFromWave) -> последняя волна режима
local function GetProgress()
	local mode = CurrentRound()
	local first = mode and mode.AirdropFromWave or 2
	local wave = GetGlobalInt("ZS_Wave", first)
	local waves = GetGlobalInt("ZS_Waves", 6)

	if waves <= first then return 1 end

	return math.Clamp((wave - first) / (waves - first), 0, 1)
end

local function CategoryChance(cat, progress)
	return Lerp(progress, cat.chance[1], cat.chance[2])
end

local function PickCategory(progress)
	local roll = math.Rand(0, 100)

	for _, cat in SortedPairs(lootCategories) do
		roll = roll - CategoryChance(cat, progress)
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

-- выдача предмета из аирдропа; возвращает true или nil с причиной отказа
local function GiveLootItem(ply, crate, item)
	if item.armor then
		local ent = ents.Create("ent_armor_" .. item.class)
		if not IsValid(ent) then return nil, "Can't take this right now" end

		ent:SetPos(crate:GetPos() + Vector(math.Rand(-20, 20), math.Rand(-20, 20), crate:OBBMaxs().z + 10))
		ent:Spawn()

		return true
	end

	if ply:HasWeapon(item.class) then return nil, "You already have this" end

	local wep = ply:Give(item.class)
	if not IsValid(wep) then return nil, "Can't take this right now" end

	if wep:GetPrimaryAmmoType() >= 0 and wep:GetMaxClip1() > 0 then
		ply:GiveAmmo(wep:GetMaxClip1() * 2, wep:GetPrimaryAmmoType(), true)
	end

	return true
end

-- 3 предмета, которые ящик предлагает игроку
local function RollLoot()
	local mode = CurrentRound()
	local progress = GetProgress()
	local items = {}
	local regular = 3

	-- слот специального предмета с шансом AirdropSpecialChance, иначе обычный предмет
	if math.random(100) <= (mode and mode.AirdropSpecialChance or 20) then
		local special = specialItems[math.random(#specialItems)]
		items[#items + 1] = {class = special, name = ItemName(special), special = true}
		regular = 2
	end

	for _ = 1, regular do
		local cat = PickCategory(progress)
		local class = cat.items[math.random(#cat.items)]
		items[#items + 1] = {class = class, name = ItemName(class), armor = cat.armor}
	end

	return items
end

local function PlayerKey(ply)
	return ply:SteamID64() or tostring(ply:EntIndex())
end

local function CanUseCrate(ply, crate)
	return IsValid(ply) and ply:Alive() and ply:Team() == TEAM_SURVIVORS and IsValid(crate) and crate:GetClass() == "zs_airdrop"
		and ply:GetPos():Distance(crate:GetPos()) <= ZS_SHOP_DISTANCE
end

local function SendMenu(ply, crate, items)
	net.Start("zs_airdrop_menu")
		net.WriteEntity(crate)
		net.WriteUInt(#items, 4)

		for _, item in ipairs(items) do
			net.WriteString(item.class)
			net.WriteString(item.name)
			net.WriteBool(item.armor or false)
			net.WriteBool(item.special or false)
			net.WriteBool(item.taken or false)
		end
	net.Send(ply)
end

-- E на ящике: окно выбора; предметы игрока бросаются один раз и ждут его, пока ящик не исчезнет
function ZS_OpenAirdrop(ply, crate)
	if not CanUseCrate(ply, crate) then return end

	crate.Offers = crate.Offers or {}

	local key = PlayerKey(ply)
	crate.Offers[key] = crate.Offers[key] or RollLoot()

	SendMenu(ply, crate, crate.Offers[key])
end

net.Receive("zs_airdrop_take", function(len, ply)
	local crate = net.ReadEntity()
	local index = net.ReadUInt(4)

	if (ply.zs_NextAirdropTake or 0) > CurTime() then return end
	ply.zs_NextAirdropTake = CurTime() + 0.2

	if not CanUseCrate(ply, crate) or not crate.Offers then return end

	local items = crate.Offers[PlayerKey(ply)]
	local item = items and items[index]
	if not item or item.taken then return end

	local ok, reason = GiveLootItem(ply, crate, item)
	if not ok then
		if ply.Notify then ply:Notify(reason, 0, "zs_airdrop", 3) else ply:ChatPrint(reason) end
		return
	end

	item.taken = true
	ply:EmitSound("items/ammo_pickup.wav", 60)

	SendMenu(ply, crate, items)
end)

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

-- точки сброса поближе к живым выжившим, чтобы ящик можно было найти за время подготовки
local function NearSurvivors(points, mode)
	local survivors = {}
	for _, ply in player.Iterator() do
		if ply:Team() == TEAM_SURVIVORS and ply:Alive() then survivors[#survivors + 1] = ply:GetPos() end
	end

	if #survivors == 0 then return points end

	local minDist, maxDist = mode.AirdropMinDist ^ 2, mode.AirdropMaxDist ^ 2
	local near = {}

	for _, point in ipairs(points) do
		for _, pos in ipairs(survivors) do
			local dist = point:DistToSqr(pos)
			if dist >= minDist and dist <= maxDist then
				near[#near + 1] = point
				break
			end
		end
	end

	return #near > 0 and near or points
end

local function FindDropPos(mode)
	local points = NearSurvivors(GetCandidatePoints(), mode)
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

	print("[ZS] Airdrop spawned at " .. tostring(pos) .. " (wave " .. GetGlobalInt("ZS_Wave", 0) .. ")")

	if fromSky then
		crate:StartFalling()
	end

	-- оповещение в чат всем: выжившим - где искать, зараженным - что у выживших пополнение
	local survivors = {}
	for _, ply in player.Iterator() do
		if ply:Team() == TEAM_SURVIVORS then
			survivors[#survivors + 1] = ply
			ply:ChatPrint("[Airdrop] Supplies dropped! Look for the red flare. The crate disappears in 2 minutes.")
		else
			ply:ChatPrint("[Airdrop] The survivors received a supply drop. Look for the red flare.")
		end
	end

	net.Start("zs_airdrop")
		net.WriteVector(pos)
	net.Send(survivors)
end

hook.Add("ZS_PrepStart", "ZS_Airdrop", function(wave)
	local mode = CurrentRound()
	if not mode or mode.name ~= "zs" or wave < mode.AirdropFromWave then return end

	-- один ящик на подготовку
	mode.saved.AirdropWave = mode.saved.AirdropWave or 0
	if mode.saved.AirdropWave >= wave then return end
	mode.saved.AirdropWave = wave

	mode:SpawnAirdrop()
end)

-- для теста: zb_zsairdrop
concommand.Add("zb_zsairdrop", function(ply)
	if IsValid(ply) and not ply:IsAdmin() then return end

	local mode = CurrentRound()
	if mode and mode.SpawnAirdrop then mode:SpawnAirdrop() end
end)
