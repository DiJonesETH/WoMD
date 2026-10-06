-- Баррикады режима Zombie Survival (по образцу JetBoom/zombiesurvival):
-- - у каждого пропа есть здоровье (ZSPropHealth), поврежденный проп краснеет и ломается;
-- - сварочный аппарат weapon_zs_arcwelder приваривает пропы точками сварки zs_weld (механика гвоздей JetBoom),
--   у приваренного пропа отдельное здоровье баррикады, его бьют только зараженные, а выжившие чинят сваркой
--   (запас починки ограничен); сварка тратит электроды;
-- - выживший, удерживая Z (+zoom), проходит сквозь прибитые пропы.

ZS_BARRICADE = ZS_BARRICADE or {}
local ZSB = ZS_BARRICADE

ZSB.HealthMin = 50
ZSB.HealthMax = 1100 * 0.85
ZSB.HealthMassFactor = 3 * 0.85
ZSB.HealthVolumeFactor = 4 * 0.85
ZSB.RepairCapacity = 1.25 -- запас починки = макс. здоровье * RepairCapacity
ZSB.ExtraHealthPerNail = 75 -- бонус за 2-й, 3-й и 4-й гвоздь
ZSB.MaxNailsPerProp = 8 -- "гвозди" здесь - точки сварки
ZSB.MaxNailsPerPlayer = 4 -- точек сварки одного игрока в одном пропе
ZSB.MaxPropsInBarricade = 8
ZSB.RepairPerHit = 10
ZSB.WeldTime = 3 -- секунд на одну точку сварки
ZSB.WelderElectrodes = 10 -- электродов в комплекте со сварочным аппаратом
ZSB.MaxElectrodes = 40
ZSB.RepairInterval = 0.5 -- починка сваркой: RepairPerHit здоровья раз в RepairInterval секунд
ZSB.PropHealthMax = 2500

local TEAM_SURVIVORS = 0

function ZSB.IsNailed(ent)
	return IsValid(ent) and ent:GetNW2Bool("ZS_Nailed", false)
end

function ZSB.GetHealth(ent)
	return ent:GetNW2Float("ZSB_HP", 0)
end

function ZSB.GetMaxHealth(ent)
	return ent:GetNW2Float("ZSB_MaxHP", 0)
end

function ZSB.GetRepairs(ent)
	return ent:GetNW2Float("ZSB_Repairs", 0)
end

function ZSB.GetMaxRepairs(ent)
	return ZSB.GetMaxHealth(ent) * ZSB.RepairCapacity
end

-- электроды сварочного аппарата
function ZSB.GetElectrodes(ply)
	return ply:GetNW2Int("ZS_Electrodes", 0)
end

function ZSB.IsGhosting(ply)
	return ply:GetNW2Bool("ZS_Ghost", false)
end

-- выживший в режиме прохода не сталкивается с прибитыми пропами
hook.Add("ShouldCollide", "ZS_BarricadeGhosting", function(ent1, ent2)
	if ent1:IsPlayer() then
		if ZSB.IsGhosting(ent1) and ZSB.IsNailed(ent2) then return false end
	elseif ent2:IsPlayer() then
		if ZSB.IsGhosting(ent2) and ZSB.IsNailed(ent1) then return false end
	end
end)

-- в режиме прохода нельзя атаковать
hook.Add("StartCommand", "ZS_BarricadeGhosting", function(ply, cmd)
	if ZSB.IsGhosting(ply) then
		cmd:RemoveKey(IN_ATTACK)
		cmd:RemoveKey(IN_ATTACK2)
	end
end)

-- проверка столкновений включается у прибитых пропов (на клиенте тоже, иначе предсказание движения разойдется)
hook.Add("EntityNetworkedVarChanged", "ZS_BarricadeCollision", function(ent, name, old, new)
	if name == "ZS_Nailed" and new then
		ent:SetCustomCollisionCheck(true)
		ent:CollisionRulesChanged()
	elseif name == "ZS_Ghost" and ent:IsPlayer() then
		ent:CollisionRulesChanged()
	end
end)

if SERVER then
	local function Active()
		local mode = CurrentRound and CurrentRound()
		return zb and zb.ROUND_STATE == 1 and mode and mode.name == "zs"
	end
	ZSB.Active = Active

	function ZSB.SetElectrodes(ply, n)
		ply:SetNW2Int("ZS_Electrodes", math.Clamp(math.floor(n), 0, ZSB.MaxElectrodes))
	end

	function ZSB.GiveElectrodes(ply, n)
		ZSB.SetElectrodes(ply, ZSB.GetElectrodes(ply) + n)
	end

	function ZSB.SetHealth(ent, v) ent:SetNW2Float("ZSB_HP", v) end
	function ZSB.SetMaxHealth(ent, v) ent:SetNW2Float("ZSB_MaxHP", v) end
	function ZSB.SetRepairs(ent, v) ent:SetNW2Float("ZSB_Repairs", v) end

	function ZSB.GetVolume(ent)
		local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
		return (maxs.x - mins.x) + (maxs.y - mins.y) + (maxs.z - mins.z)
	end

	function ZSB.DefaultHealth(ent)
		local mass = 2
		local phys = ent:GetPhysicsObject()
		if IsValid(phys) then mass = phys:GetMass() end

		return math.Clamp(mass * ZSB.HealthMassFactor + ZSB.GetVolume(ent) * ZSB.HealthVolumeFactor, ZSB.HealthMin, ZSB.HealthMax)
	end

	function ZSB.GetNails(ent)
		local tab = {}

		for _, nail in ipairs(ent.ZSNails or {}) do
			if IsValid(nail) then tab[#tab + 1] = nail end
		end

		return tab
	end

	function ZSB.UpdateNailed(ent)
		if not IsValid(ent) or ent:IsWorld() then return end

		local nailed = #ZSB.GetNails(ent) > 0
		if nailed then ent:SetCustomCollisionCheck(true) end

		ent:SetNW2Bool("ZS_Nailed", nailed)
		ent:CollisionRulesChanged()
	end

	function ZSB.PropsInContraption(ent)
		local all = constraint.GetAllConstrainedEntities(ent)
		return all and table.Count(all) or 1
	end

	-- 2-й, 3-й и 4-й гвоздь увеличивают максимальное здоровье баррикады
	function ZSB.RecalculateNailBonuses(ent)
		local maxHealth = ZSB.GetMaxHealth(ent)
		if maxHealth <= 0 then return end

		local repairsFrac = ZSB.GetRepairs(ent) / ZSB.GetMaxRepairs(ent)
		local extra = math.Clamp(#ZSB.GetNails(ent) - 1, 0, 3)

		ent.ZSOriginalMaxHealth = ent.ZSOriginalMaxHealth or maxHealth

		local newMax = ent.ZSOriginalMaxHealth + extra * ZSB.ExtraHealthPerNail
		ZSB.SetMaxHealth(ent, newMax)
		ZSB.SetHealth(ent, ZSB.GetHealth(ent) / maxHealth * newMax)
		ZSB.SetRepairs(ent, repairsFrac * ZSB.GetMaxRepairs(ent))
	end

	function ZSB.AttachNail(nail, baseEnt, attachEnt, cons)
		nail.ZSBase = baseEnt
		nail.ZSAttach = attachEnt
		nail.ZSConstraint = cons

		for _, ent in ipairs({baseEnt, attachEnt}) do
			if IsValid(ent) and not ent:IsWorld() then
				ent.ZSNails = ent.ZSNails or {}
				table.insert(ent.ZSNails, nail)
			end
		end

		if ZSB.GetHealth(baseEnt) <= 0 then
			local health = ZSB.DefaultHealth(baseEnt)
			ZSB.SetMaxHealth(baseEnt, health)
			ZSB.SetHealth(baseEnt, health)
			ZSB.SetRepairs(baseEnt, ZSB.GetMaxRepairs(baseEnt))
		end

		ZSB.RecalculateNailBonuses(baseEnt)
		ZSB.UpdateNailed(baseEnt)
		ZSB.UpdateNailed(attachEnt)
	end

	local function RemoveFromList(ent, nail)
		if not IsValid(ent) or ent:IsWorld() or not ent.ZSNails then return end

		for i = #ent.ZSNails, 1, -1 do
			if ent.ZSNails[i] == nail or not IsValid(ent.ZSNails[i]) then
				table.remove(ent.ZSNails, i)
			end
		end

		ZSB.RecalculateNailBonuses(ent)
		ZSB.UpdateNailed(ent)
	end

	-- снимает гвоздь; сварка между пропами удаляется вместе с последним гвоздем на ней
	function ZSB.RemoveNail(nail, removing)
		if not IsValid(nail) or nail.ZSRemoving then return end
		nail.ZSRemoving = true

		local cons = nail.ZSConstraint
		local others = 0

		for _, other in ipairs(ents.FindByClass("zs_weld")) do
			if other ~= nail and not other.ZSRemoving and other.ZSConstraint == cons then
				others = others + 1
			end
		end

		local base, attach = nail.ZSBase, nail.ZSAttach

		-- снятые с сильно поврежденной баррикады пропы остаются поврежденными
		if others == 0 and IsValid(base) and base.ZSPropHealth and ZSB.GetHealth(base) > 0 and ZSB.GetRepairs(base) / ZSB.GetMaxRepairs(base) < 0.5 then
			base.ZSPropHealth = math.min(base.ZSPropHealth, ZSB.GetHealth(base))
			ZSB.TintProp(base)
		end

		if others == 0 and IsValid(cons) then
			cons:Remove()
		end

		if not removing then nail:Remove() end

		RemoveFromList(base, nail)
		RemoveFromList(attach, nail)
	end

	function ZSB.TintProp(ent)
		if not ent.ZSPropHealth or not ent.ZSPropTotalHealth then return end

		local frac = math.Clamp(ent.ZSPropHealth / ent.ZSPropTotalHealth, 0, 1)
		local col = ent:GetColor()
		col.r = 255
		col.g = 255 * frac
		col.b = 255 * frac
		ent:SetColor(col)
	end

	local function BreakProp(ent)
		local effect = EffectData()
		effect:SetOrigin(ent:GetPos())
		util.Effect("Explosion", effect, true, true)

		ent:Fire("break")

		-- проп без модели обломков просто исчезает
		timer.Simple(0.1, function()
			if IsValid(ent) then ent:Remove() end
		end)
	end

	-- здоровье обычных пропов (как GM:SetupProps у JetBoom)
	function ZSB.SetupProp(ent)
		if not IsValid(ent) or ent.ZSPropSetup or not string.StartWith(ent:GetClass(), "prop_physics") then return end
		ent.ZSPropSetup = true

		if ent:GetMaxHealth() <= 1 and ent:Health() == 0 then
			local health = math.min(ZSB.PropHealthMax, math.ceil((ent:OBBMins():Length() + ent:OBBMaxs():Length()) * 10))
			ent.ZSPropHealth = health
			ent.ZSPropTotalHealth = health
		else
			ent:SetHealth(math.ceil(ent:Health() * 3))
			ent:SetMaxHealth(ent:Health())
		end
	end

	function ZSB.SetupProps()
		for _, ent in ipairs(ents.FindByClass("prop_physics*")) do
			ZSB.SetupProp(ent)
		end
	end

	hook.Add("OnEntityCreated", "ZS_BarricadePropHealth", function(ent)
		timer.Simple(0, function()
			if IsValid(ent) and Active() then ZSB.SetupProp(ent) end
		end)
	end)

	local function DamageBarricade(ent, dmginfo)
		local attacker = dmginfo:GetAttacker()

		-- баррикады ломают только зараженные и окружение (огонь, взрывы), физические удары не считаются
		if IsValid(attacker) and attacker:IsPlayer() and not (ZS_IsZombie and ZS_IsZombie(attacker)) or dmginfo:IsDamageType(DMG_CRUSH) then
			dmginfo:SetDamage(0)
			return true
		end

		local damage = dmginfo:GetDamage()
		if damage <= 0 then return true end

		ZSB.SetHealth(ent, ZSB.GetHealth(ent) - damage)
		dmginfo:SetDamage(0)

		if (ent.ZSNextStrain or 0) < CurTime() then
			ent.ZSNextStrain = CurTime() + math.min(damage * 0.025, 1)
			local frac = ZSB.GetHealth(ent) / math.max(ZSB.GetMaxHealth(ent), 1)
			ent:EmitSound("physics/metal/metal_box_impact_hard" .. math.random(3) .. ".wav", math.Clamp(damage * 2.5, 60, 80), math.min(255, 150 + (1 - frac) * 100))
		end

		if ZSB.GetHealth(ent) <= 0 then
			ZSB.SetHealth(ent, 0)

			for _, nail in ipairs(ZSB.GetNails(ent)) do
				ZSB.RemoveNail(nail)
			end

			if ZSB.GetVolume(ent) < 100 then BreakProp(ent) end
		end

		return true
	end

	hook.Add("EntityTakeDamage", "ZS_BarricadeDamage", function(ent, dmginfo)
		if not Active() or ent:IsPlayer() or ent:IsNPC() then return end

		if ZSB.IsNailed(ent) and ZSB.GetHealth(ent) > 0 then
			return DamageBarricade(ent, dmginfo)
		end

		if not ent.ZSPropHealth or ent.ZSPropBroken then return end
		if dmginfo:IsDamageType(DMG_CRUSH) then return end

		ent.ZSPropHealth = ent.ZSPropHealth - dmginfo:GetDamage()

		if ent.ZSPropHealth <= 0 then
			ent.ZSPropBroken = true
			BreakProp(ent)
		else
			ZSB.TintProp(ent)
		end
	end)

	-- проход сквозь баррикады: Z на земле включает, режим держится, пока зажата Z или игрок стоит внутри баррикады
	function ZSB.SetGhosting(ply, b)
		if ZSB.IsGhosting(ply) == b then return end

		ply:SetNW2Bool("ZS_Ghost", b)
		ply:CollisionRulesChanged()
	end

	function ZSB.InsideBarricade(ply)
		local mins, maxs = ply:WorldSpaceAABB()
		mins.x, mins.y = mins.x + 1, mins.y + 1
		maxs.x, maxs.y = maxs.x - 1, maxs.y - 1

		for _, ent in ipairs(ents.FindInBox(mins, maxs)) do
			if ZSB.IsNailed(ent) then return true end
		end

		return false
	end

	local function CanGhost(ply)
		return Active() and ply:Alive() and ply:Team() == TEAM_SURVIVORS and not IsValid(ply.FakeRagdoll)
	end

	hook.Add("KeyPress", "ZS_BarricadeGhosting", function(ply, key)
		if key ~= IN_ZOOM or not CanGhost(ply) then return end

		if ply:IsOnGround() or (IsValid(ply:GetPhysicsObject()) and ply:GetPhysicsObject():IsPenetrating()) then
			ZSB.SetGhosting(ply, true)
		end
	end)

	hook.Add("PlayerPostThink", "ZS_BarricadeGhosting", function(ply)
		if not ZSB.IsGhosting(ply) then return end

		if not CanGhost(ply) or not ply:KeyDown(IN_ZOOM) and not ZSB.InsideBarricade(ply) then
			ZSB.SetGhosting(ply, false)
		end
	end)

	hook.Add("PlayerSpawn", "ZS_BarricadeGhosting", function(ply)
		ZSB.SetGhosting(ply, false)
	end)

	-- электроды пропадают со смертью
	hook.Add("PostPlayerDeath", "ZS_Electrodes", function(ply)
		ZSB.SetElectrodes(ply, 0)
	end)
else
	local colBack = Color(0, 0, 0, 180)
	local colRepairs = Color(100, 170, 215)
	local colText = Color(240, 240, 240)

	-- здоровье баррикады под прицелом
	hook.Add("HUDPaint", "ZS_BarricadeHealth", function()
		local ply = LocalPlayer()
		if not IsValid(ply) or not ply:Alive() then return end

		if ZSB.IsGhosting(ply) then
			draw.SimpleTextOutlined("Passing through barricades", "DermaDefaultBold", ScrW() * 0.5, ScrH() * 0.75, colText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
		end

		local tr = ply:GetEyeTrace()
		local ent = tr.Entity
		if not ZSB.IsNailed(ent) or tr.HitPos:DistToSqr(tr.StartPos) > 256 * 256 then return end

		local maxHealth = ZSB.GetMaxHealth(ent)
		if maxHealth <= 0 then return end

		local frac = math.Clamp(ZSB.GetHealth(ent) / maxHealth, 0, 1)
		local repairsFrac = math.Clamp(ZSB.GetRepairs(ent) / math.max(ZSB.GetMaxRepairs(ent), 1), 0, 1)

		local w, h = 160, 8
		local x, y = ScrW() * 0.5 - w * 0.5, ScrH() * 0.5 + 40

		draw.RoundedBox(0, x - 2, y - 2, w + 4, h * 2 + 7, colBack)
		draw.RoundedBox(0, x, y, w * frac, h, Color(200 - frac * 200, frac * 200, 0))
		draw.RoundedBox(0, x, y + h + 3, w * repairsFrac, h * 0.5, colRepairs)

		draw.SimpleTextOutlined(math.floor(ZSB.GetHealth(ent)) .. " / " .. math.floor(maxHealth), "DermaDefault", ScrW() * 0.5, y + h * 2 + 14, colText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
	end)
end
