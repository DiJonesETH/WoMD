local MODE = MODE

-- Генератор выживших: в начале каждого раунда в случайной точке карты появляется генератор (lua/entities/zs_generator.lua).
-- Чтобы его завести, нужно принести две канистры бензина и дергать шнур стартера.
-- Если на карте меньше GeneratorCans канистр, недостающие появляются в других случайных точках.

MODE.GeneratorCans = 2

local function GroundPoint(pos)
	local tr = util.TraceHull({
		start = pos + Vector(0, 0, 40),
		endpos = pos - Vector(0, 0, 200),
		mins = Vector(-16, -16, 0),
		maxs = Vector(16, 16, 16),
		mask = MASK_SOLID_BRUSHONLY,
	})

	if tr.Hit and not tr.StartSolid then return tr.HitPos end
end

local function RandomGround(points, avoid)
	for _ = 1, 30 do
		local pos = GroundPoint(points[math.random(#points)])
		if pos and (not avoid or pos:Distance(avoid) > 500) then return pos end
	end
end

local function CountCans()
	local count = 0

	for _, ent in ipairs(ents.FindByClass("prop_physics*")) do
		if ZS_GENERATOR_FUEL and ZS_GENERATOR_FUEL[string.lower(ent:GetModel() or "")] then count = count + 1 end
	end

	return count
end

function MODE:SpawnGenerator()
	for _, old in ipairs(ents.FindByClass("zs_generator")) do old:Remove() end

	local points = ZS_GetMapPoints and ZS_GetMapPoints() or {}
	if #points == 0 then return end

	local pos = RandomGround(points)
	if not pos then return end

	local gen = ents.Create("zs_generator")
	if not IsValid(gen) then return end

	gen:SetPos(pos)
	gen:SetAngles(Angle(0, math.Rand(0, 360), 0))
	gen:Spawn()
	gen:SetPos(pos - Vector(0, 0, gen:OBBMins().z))

	print("[ZS] Generator spawned at " .. tostring(pos))

	-- канистры бензина, если на карте их не хватает
	for _ = CountCans() + 1, self.GeneratorCans do
		local canPos = RandomGround(points, pos)
		if canPos then
			local can = ents.Create("prop_physics")
			can:SetModel("models/props_junk/gascan001a.mdl")
			can:SetPos(canPos + Vector(0, 0, 16))
			can:Spawn()
		end
	end
end

-- один генератор на раунд: появляется в начале подготовки к первой волне
hook.Add("ZS_PrepStart", "ZS_Generator", function(wave)
	local mode = CurrentRound()
	if not mode or mode.name ~= "zs" or wave ~= 1 then return end

	mode:SpawnGenerator()
end)

-- для теста: zb_zsgenerator
concommand.Add("zb_zsgenerator", function(ply)
	if IsValid(ply) and not ply:IsAdmin() then return end

	local mode = CurrentRound()
	if mode and mode.SpawnGenerator then mode:SpawnGenerator() end
end)
