AddCSLuaFile()

-- Генератор выживших Zombie Survival (появляется раз за раунд, sv_zs_generator.lua).
-- Канистры бензина (пропы), поднесенные к генератору, заливаются в бак (до MaxFuel).
-- По E открывается окно с баком и шнуром стартера: шнур тянут мышью в сторону, отпущенный он возвращается.
-- Каждый рывок - попытка завода; с полным баком генератор заводится с шансом StartChance.
-- Завел - получи случайный ящик (арсенал, тех., медицина, лотерея) и Reward очков выжившего.
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Generator"
ENT.Spawnable = false

ENT.Model = "models/props_vehicles/generatortrailer01.mdl"
ENT.MaxFuel = 2
ENT.StartChance = 30
ENT.Reward = 300
ENT.RewardBoxes = {"weapon_zs_box_arsenal", "weapon_zs_box_tech", "weapon_zs_box_medical", "weapon_zs_box_lottery"}
ENT.FuelRadius = 90
ENT.PullCooldown = 0.8

-- канистры бензина
ZS_GENERATOR_FUEL = {
	["models/props_junk/gascan001a.mdl"] = true,
	["models/props_junk/metalgascan.mdl"] = true,
}

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "Fuel")
	self:NetworkVar("Bool", 0, "Running")
end

if SERVER then
	util.AddNetworkString("zs_generator_open")
	util.AddNetworkString("zs_generator_pull")

	function ENT:Initialize()
		self:SetModel(self.Model)

		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then phys:EnableMotion(false) end
	end

	-- канистра рядом с генератором заливается в бак
	function ENT:Think()
		if self:GetFuel() < self.MaxFuel then
			for _, ent in ipairs(ents.FindInSphere(self:WorldSpaceCenter(), self.FuelRadius)) do
				if ent:GetClass() == "prop_physics" and ZS_GENERATOR_FUEL[string.lower(ent:GetModel() or "")] and not ent.zs_Poured then
					ent.zs_Poured = true
					ent:Remove()

					self:SetFuel(self:GetFuel() + 1)
					self:EmitSound("ambient/water/water_splash" .. math.random(3) .. ".wav", 70, 80)

					if self:GetFuel() >= self.MaxFuel then break end
				end
			end
		end

		self:NextThink(CurTime() + 0.5)
		return true
	end

	local function CanUse(ply, gen)
		return IsValid(ply) and ply:Alive() and ply:Team() == 0 and IsValid(gen) and gen:GetClass() == "zs_generator"
			and ply:GetPos():Distance(gen:GetPos()) <= ZS_SHOP_DISTANCE + 60
	end

	function ENT:Use(ply)
		if not CanUse(ply, self) then return end

		net.Start("zs_generator_open")
			net.WriteEntity(self)
		net.Send(ply)
	end

	function ENT:StartEngine(ply)
		self:SetRunning(true)

		self.EngineSound = CreateSound(self, "vehicles/v8/v8_start_loop1.wav")
		self.EngineSound:PlayEx(0.8, 100)

		-- награда тому, кто завел
		local box = self.RewardBoxes[math.random(#self.RewardBoxes)]
		ply:Give(box)

		if ZS_GetSurvivorPoints then
			ply:SetNWInt("ZS_SPoints", ZS_GetSurvivorPoints(ply) + self.Reward)
		end

		local stored = weapons.GetStored(box)
		ply:ChatPrint("[Generator] It's running! You got a " .. (stored and stored.PrintName or box) .. " and " .. self.Reward .. " SP")
	end

	net.Receive("zs_generator_pull", function(len, ply)
		local gen = net.ReadEntity()
		if not CanUse(ply, gen) or gen:GetRunning() then return end

		if (gen.NextPull or 0) > CurTime() then return end
		gen.NextPull = CurTime() + gen.PullCooldown

		gen:EmitSound("vehicles/v8/v8_stop1.wav", 80, math.random(95, 105))

		if gen:GetFuel() >= gen.MaxFuel and math.random(100) <= gen.StartChance then
			gen:StartEngine(ply)
		end
	end)

	function ENT:OnRemove()
		if self.EngineSound then self.EngineSound:Stop() end
	end

	return
end

------------------------------------------------------------------ клиент

function ENT:Draw()
	self:DrawModel()

	if LocalPlayer():GetPos():DistToSqr(self:GetPos()) > 300 * 300 then return end

	local pos = self:GetPos() + Vector(0, 0, self:OBBMaxs().z + 14)
	local ang = Angle(0, LocalPlayer():EyeAngles().y - 90, 90)
	local status = self:GetRunning() and "Running" or ("Fuel: " .. self:GetFuel() .. " / " .. self.MaxFuel .. "  |  E - start")

	cam.Start3D2D(pos, ang, 0.08)
		draw.SimpleTextOutlined("Generator", "DermaLarge", 0, 0, Color(240, 200, 60), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)
		draw.SimpleTextOutlined(status, "DermaDefaultBold", 0, 30, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
	cam.End3D2D()
end

local colBack = Color(18, 18, 20, 245)
local colPanel = Color(32, 32, 36, 255)
local colFuel = Color(230, 150, 40)
local colBody = Color(70, 80, 60)
local colRope = Color(200, 190, 160)
local colHandle = Color(200, 60, 40)
local colOk = Color(120, 220, 120)

local genFrame

local function OpenGenerator(gen)
	if IsValid(genFrame) then genFrame:Remove() end

	local frame = vgui.Create("DFrame")
	genFrame = frame
	frame:SetSize(560, 340)
	frame:Center()
	frame:SetTitle("")
	frame:MakePopup()
	frame:SetKeyboardInputEnabled(false)

	-- шнур: от стартера (anchorX) до ручки; ручку тянут вправо до maxPull, отпущенная она возвращается
	local anchorX, ropeY, restLen, maxPull = 150, 230, 40, 300
	frame.Pull = 0
	frame.Dragging = false

	function frame:Paint(w, h)
		draw.RoundedBox(6, 0, 0, w, h, colBack)
		draw.SimpleText("GENERATOR", "ZS_ShopTitle", 16, 12, Color(240, 200, 60))

		if not IsValid(gen) then return end

		-- бак
		local fuel, maxFuel = gen:GetFuel(), gen.MaxFuel
		draw.SimpleText("Fuel", "ZS_ShopPrice", 16, 60, color_white)
		for i = 1, maxFuel do
			draw.RoundedBox(4, 70 + (i - 1) * 60, 56, 52, 26, i <= fuel and colFuel or colPanel)
		end
		draw.SimpleText(fuel >= maxFuel and "Full - pull the cord" or "Bring gas cans to the generator", "ZS_ShopItem", 200, 69, fuel >= maxFuel and colOk or color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if gen:GetRunning() then
			draw.SimpleText("The generator is running!", "ZS_ShopTitle", w * 0.5, 160, colOk, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			return
		end

		-- корпус со стартером
		draw.RoundedBox(6, 20, ropeY - 60, anchorX - 20, 120, colBody)
		draw.RoundedBox(20, anchorX - 30, ropeY - 20, 40, 40, colPanel)

		-- шнур и ручка
		local handleX = anchorX + restLen + self.Pull
		surface.SetDrawColor(colRope)
		surface.DrawRect(anchorX, ropeY - 2, handleX - anchorX, 4)
		draw.RoundedBox(6, handleX, ropeY - 22, 18, 44, colHandle)

		draw.SimpleText("Drag the handle to the right and release", "ZS_ShopItem", w * 0.5, h - 24, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	function frame:OnMousePressed(code)
		if code ~= MOUSE_LEFT or not IsValid(gen) or gen:GetRunning() then return end

		local mx, my = self:CursorPos()
		local handleX = anchorX + restLen + self.Pull

		if mx >= handleX - 10 and mx <= handleX + 30 and math.abs(my - ropeY) <= 30 then
			self.Dragging = true
			self.GrabOffset = mx - handleX
			self.Pulled = false
			self:MouseCapture(true)
		end
	end

	function frame:OnMouseReleased(code)
		if code ~= MOUSE_LEFT or not self.Dragging then return end

		self.Dragging = false
		self:MouseCapture(false)
	end

	function frame:Think()
		local ply = LocalPlayer()
		if not IsValid(gen) or not ply:Alive() or ply:Team() ~= 0 or ply:GetPos():Distance(gen:GetPos()) > ZS_SHOP_DISTANCE + 60 then
			self:Remove()
			return
		end

		if self.Dragging then
			local mx = self:CursorPos()
			self.Pull = math.Clamp(mx - self.GrabOffset - anchorX - restLen, 0, maxPull)

			-- дернули до конца - рывок стартера
			if self.Pull >= maxPull * 0.9 and not self.Pulled then
				self.Pulled = true

				net.Start("zs_generator_pull")
					net.WriteEntity(gen)
				net.SendToServer()
			end
		else
			-- отпущенный шнур наматывается обратно
			self.Pull = math.Approach(self.Pull, 0, FrameTime() * 1400)
		end
	end
end

net.Receive("zs_generator_open", function()
	local gen = net.ReadEntity()
	if IsValid(gen) then OpenGenerator(gen) end
end)
