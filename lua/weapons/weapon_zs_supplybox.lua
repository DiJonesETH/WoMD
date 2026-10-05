if SERVER then AddCSLuaFile() end

-- Базовый предмет ящика снабжения выживших (Zombie Survival). ЛКМ - поставить, Q/R - вращать.
-- Пока предмет в руках, показывается призрак ящика с контуром (зеленый - можно поставить, красный - нельзя)
SWEP.Base = "weapon_base"
SWEP.PrintName = "Supply Box"
SWEP.Category = "ZCity Other"
SWEP.Instructions = "LMB - place the box\nQ / R - rotate"
SWEP.Spawnable = false
SWEP.AdminOnly = true

SWEP.BoxType = "arsenal"
SWEP.IsZSSupplyBox = true

SWEP.ViewModel = ""
SWEP.WorldModel = ""
SWEP.HoldType = "duel"
SWEP.UseHands = false
SWEP.DrawCrosshair = false

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.PlaceDistance = 120
SWEP.RotateSpeed = 120

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)

	local info = ZS_SUPPLY_BOXES and ZS_SUPPLY_BOXES[self.BoxType]
	if info then
		self.PrintName = info.name
		self.Instructions = info.desc .. "\n\nLMB - place the box\nQ / R - rotate"
	end
end

-- точка установки: земля перед игроком
function SWEP:GetPlacement(yawOffset)
	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	local eye = owner:EyePos()
	local tr = util.TraceLine({
		start = eye,
		endpos = eye + owner:GetAimVector() * self.PlaceDistance,
		filter = {owner, owner.FakeRagdoll},
		mask = MASK_SOLID,
	})

	if not tr.Hit or tr.HitNormal.z < 0.7 then return end

	return tr.HitPos, Angle(0, owner:EyeAngles().y + (yawOffset or 0), 0)
end

function SWEP:SecondaryAttack() end
function SWEP:Reload() end

if SERVER then
	util.AddNetworkString("zs_placebox")

	function SWEP:PrimaryAttack() end

	net.Receive("zs_placebox", function(len, ply)
		local yaw = net.ReadFloat()

		local wep = ply:GetActiveWeapon()
		if not IsValid(wep) or not wep.IsZSSupplyBox or not ply:Alive() then return end
		if (wep.NextPlace or 0) > CurTime() then return end
		wep.NextPlace = CurTime() + 0.5

		local pos, ang = wep:GetPlacement(yaw)
		if not pos then return end

		if not ZS_CanPlaceSupplyBox(wep.BoxType, pos) then
			if ply.Notify then ply:Notify("Такой же ящик уже стоит ближе 5 метров", 0, "zs_supplybox", 3) end
			return
		end

		local box = ents.Create("zs_supply_box")
		box:SetBoxType(wep.BoxType)
		box:SetAngles(ang)
		box:SetPos(pos)
		box:Spawn()

		-- ставим ящик дном на землю
		box:SetPos(pos - Vector(0, 0, box:OBBMins().z))

		box:EmitSound("physics/metal/metal_box_impact_hard" .. math.random(3) .. ".wav", 70)

		ply:StripWeapon(wep:GetClass())
	end)
else
	-- в руках персонажа ящик не рисуется
	function SWEP:DrawWorldModel() end
	function SWEP:DrawWorldModelTranslucent() end

	function SWEP:PrimaryAttack()
		if not IsFirstTimePredicted() then return end

		self:SetNextPrimaryFire(CurTime() + 0.5)

		net.Start("zs_placebox")
			net.WriteFloat(self.YawOffset or 0)
		net.SendToServer()
	end

	function SWEP:Think()
		if self:GetOwner() ~= LocalPlayer() or IsValid(vgui.GetKeyboardFocus()) then return end

		local dir = (input.IsKeyDown(KEY_R) and 1 or 0) - (input.IsKeyDown(KEY_Q) and 1 or 0)
		self.YawOffset = ((self.YawOffset or 0) + dir * self.RotateSpeed * FrameTime()) % 360
	end

	function SWEP:GetGhost()
		local info = ZS_SUPPLY_BOXES[self.BoxType]
		if not info then return end

		if not IsValid(self.Ghost) then
			self.Ghost = ClientsideModel(info.model, RENDERGROUP_TRANSLUCENT)
			if not IsValid(self.Ghost) then return end

			self.Ghost:SetNoDraw(true)
			self.Ghost:SetRenderMode(RENDERMODE_TRANSCOLOR)
		end

		return self.Ghost
	end

	function SWEP:UpdateGhost()
		local ghost = self:GetGhost()
		if not IsValid(ghost) then return end

		local pos, ang = self:GetPlacement(self.YawOffset)
		self.GhostValid = pos ~= nil and ZS_CanPlaceSupplyBox(self.BoxType, pos)

		if not pos then
			ghost.ShouldShow = false
			return ghost
		end

		ghost:SetAngles(ang)
		ghost:SetPos(pos - Vector(0, 0, ghost:OBBMins().z))
		ghost.ShouldShow = true

		return ghost
	end

	function SWEP:OnRemove()
		if IsValid(self.Ghost) then self.Ghost:Remove() end
	end

	function SWEP:Holster()
		if IsValid(self.Ghost) then self.Ghost:Remove() end
		return true
	end

	local colOk, colBad = Color(80, 255, 80), Color(255, 60, 60)
	local wireframe = Material("models/wireframe")

	local function GetHeldBox()
		local ply = LocalPlayer()
		if not IsValid(ply) or not ply:Alive() then return end

		local wep = ply:GetActiveWeapon()
		if IsValid(wep) and wep.IsZSSupplyBox then return wep end
	end

	hook.Add("PostDrawTranslucentRenderables", "ZS_SupplyBoxGhost", function(depth, skybox)
		if skybox then return end

		local wep = GetHeldBox()
		if not wep then return end

		local ghost = wep:UpdateGhost()
		if not IsValid(ghost) or not ghost.ShouldShow then return end

		local col = wep.GhostValid and colOk or colBad

		-- контур ящика: материал models/wireframe
		render.MaterialOverride(wireframe)
		render.SetColorModulation(col.r / 255, col.g / 255, col.b / 255)
		ghost:DrawModel()
		render.SetColorModulation(1, 1, 1)
		render.MaterialOverride()
	end)

	function SWEP:DrawHUD()
		local text = self.GhostValid and "ЛКМ - поставить, Q / R - повернуть" or "Здесь поставить нельзя"
		draw.SimpleTextOutlined(text, "DermaLarge", ScrW() * 0.5, ScrH() * 0.8, self.GhostValid and colOk or colBad, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)
	end
end
