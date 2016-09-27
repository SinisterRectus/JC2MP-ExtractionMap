local black = Color.Black
local white = Color.White
local zero = Vector2.Zero
local one = Vector2.One
local format = string.format
local deg = math.deg

class 'ExtractionMap'

function ExtractionMap:__init()

	self.text_scale = 0.015
	self.text_size = Render.Height * self.text_scale

	self.players = {}

	self.extraction_enabled = true
	self.extraction_speed = 5000 -- meters per second

	self.world_fadeout_delay = 2000 -- milliseconds
	self.map_fadeout_delay = 2000 -- milliseconds
	self.world_fadein_delay = 2000 -- milliseconds

	self.render = false -- Do not change
	self.labels = 0 -- Do not change

	self.actions = { -- Action to block while map is open
		[3] = true,
		[4] = true,
		[5] = true,
		[6] = true,
		[11] = true,
		[12] = true,
		[13] = true,
		[14] = true,
		[17] = true,
		[18] = true,
		[105] = true,
		[137] = true,
		[138] = true,
		[139] = true
	}

	self.map = Image.Create(AssetLocation.Game, 'pda_map_dif.dds')
	self.marker = Image.Create(AssetLocation.Game, "hud_icon_objective_dif.dds")
	self.waypoint = Image.Create(AssetLocation.Game, "hud_icon_waypoint_dif.dds")
	self.heli = Image.Create(AssetLocation.Game, "hud_icon_heli_orange_dif.dds")

	self:ResolutionChange({size = Render.Size})

	Events:Subscribe("MouseUp", self, self.MouseUp)
	Events:Subscribe("KeyUp", self, self.ToggleMap)
	Events:Subscribe("PostRender", self, self.PostRender)
	Events:Subscribe("ResolutionChange", self, self.ResolutionChange)
	Events:Subscribe("LocalPlayerInput", self, self.InputBlock)

	Network:Subscribe("PlayerUpdate", self, self.PlayerUpdate)

end

function ExtractionMap:ToggleMap(args)

	if self.extraction_sequence then return end

	local k = args.key

	if not self.render and k == VirtualKey.F2 and Game:GetState() == GUIState.Game then
		Mouse:SetVisible(true)
		self.render = true
		Events:Fire("MapShown") -- Can be used to communicate with other modules
		Network:Send("MapShown")
	elseif self.render and (k == VirtualKey.Escape or k == VirtualKey.F1 or k == VirtualKey.F2) then
		Mouse:SetVisible(false)
		self.render = false
		Events:Fire("MapHidden") -- Can be used to communicate with other modules
		Network:Send("MapHidden")
	end

end

function ExtractionMap:MouseUp(args)

	if self.extraction_sequence or not self.render or Game:GetState() ~= GUIState.Game then return end

	if self.extraction_enabled and args.button == 1 then

		if not LocalPlayer:InVehicle() then
			local position = self:MapToWorld(Mouse:GetPosition())
			if position.x >= -16384 and position.x <= 16383 and position.z >= -16384 and position.z <= 16383 then
				self.previous_position = LocalPlayer:GetPosition()
				self.next_position = position
				self.extraction_delay = Vector3.Distance(self.previous_position, self.next_position) / self.extraction_speed
				self.extraction_sequence = Events:Subscribe("PreTick", self, self.ExtractionSequence)
				self.world_fadeout_timer = Timer()
				Game:FireEvent("ply.makeinvulnerable")
				Mouse:SetVisible(false)
			end
		else
			Chat:Print("You cannot be extracted while in a vehicle.", Color.Silver)
		end

	elseif args.button == 3 then

		local _, valid = Waypoint:GetPosition()
		if valid then
			Waypoint:Remove()
		else
			Waypoint:SetPosition(self:MapToWorld(Mouse:GetPosition()))
		end

	elseif args.button == 2 then

		self.labels = self.labels < 2 and self.labels + 1 or 0

	end

end

function ExtractionMap:ExtractionSequence()

	if not self.extraction_sequence then return end

	if self.world_fadeout_timer then

		if self.world_fadeout_timer:GetMilliseconds() > self.world_fadeout_delay then
			Network:Send("InitialTeleport", {position = self.next_position})
			self.world_fadeout_timer = nil
			self.extraction_timer = Timer()
			self.teleporting = true
		end

	elseif self.teleporting then

		if LocalPlayer:GetPosition() ~= self.previous_position then
			self.teleporting = false
			self.loading = true
		end

	elseif self.loading then

		if LocalPlayer:GetLinearVelocity() ~= Vector3.Zero then
			self.loading = false
		end

	end

	if self.extraction_timer then

		if self.extraction_timer:GetSeconds() > self.extraction_delay then
			self.extraction_timer = nil
			self.map_fadeout_timer = Timer()
		end

	elseif self.map_fadeout_timer then

		local dt = self.map_fadeout_timer:GetMilliseconds()
		local delay = self.map_fadeout_delay
		local alpha = math.clamp(1 - dt / delay, 0, 1)
		self.map:SetAlpha(alpha)
		self.marker:SetAlpha(alpha)
		self.waypoint:SetAlpha(alpha)
		if dt > delay then self.map_fadeout_timer = nil end

	end


	if not self.world_fadeout_timer and not self.world_fadein_timer and not self.teleporting and not self.loading and not self.extraction_timer and not self.map_fadeout_timer then

		self.world_fadein_timer = Timer()
		local ray = Physics:Raycast(Vector3(self.next_position.x, 2100, self.next_position.z), Vector3.Down, 0, 2100)
		Network:Send("CorrectedTeleport", {position = ray.position})

	end

	if self.world_fadein_timer then

		if self.world_fadein_timer:GetMilliseconds() > self.world_fadein_delay then
			Events:Unsubscribe(self.extraction_sequence)
			Game:FireEvent("ply.makevulnerable")
			Events:Fire("HideMap")
			self.map:SetAlpha(1)
			self.marker:SetAlpha(1)
			self.waypoint:SetAlpha(1)
			self.render = false
			self.world_fadein_timer = nil
			self.extraction_sequence = nil
			self.extraction_render = nil
			self.previous_position = nil
			self.next_position = nil
		end

	end

end

function ExtractionMap:MapToWorld(position)
	local x = 32768 * (position.x - self.map:GetPosition().x) / self.map:GetSize().x - 16384
	local z = 32768 * (position.y - self.map:GetPosition().y) / self.map:GetSize().y - 16384
	return Vector3(x, Physics:GetTerrainHeight(Vector2(x, z)), z)
end

function ExtractionMap:WorldToMap(position)
	local x = self.map:GetSize().x * (position.x + 16384) / 32768 + self.map:GetPosition().x
	local y = self.map:GetSize().y * (position.z + 16384) / 32768 + self.map:GetPosition().y
	return Vector2(x, y)
end

function ExtractionMap:YawToHeading(yaw)
	return yaw < 0 and -yaw or 360 - yaw
end

function ExtractionMap:PostRender()

	if Game:GetState() ~= GUIState.Game then return end

	local size = Render.Size

	if self.extraction_sequence then

		if self.world_fadeout_timer then
			local dt = self.world_fadeout_timer:GetMilliseconds()
			local delay = self.world_fadeout_delay
			if dt < delay then
				Render:FillArea(zero, size, self:ColorA(black, 255 * (dt / delay)))
			end
		end

		if self.teleporting or self.loading or self.extraction_timer or self.map_fadeout_timer then
			Render:FillArea(zero, size, black)
		end

		if self.world_fadein_timer then
			local dt = self.world_fadein_timer:GetMilliseconds()
			local delay = self.world_fadein_delay
			if dt < delay then
				Render:FillArea(zero, size, self:ColorA(black, 255 * (1 - dt / delay)))
			end
		end

	end

	if self.render then

		self.map:Draw()

		if not self.extraction_sequence then

			local text_size = self.text_size
			local labels = self.labels

			for _, player in pairs(self.players) do

				if player.id ~= LocalPlayer:GetId() then

					local position = self:WorldToMap(player.pos)
					local str = player.name
					Render:FillCircle(position, size.y * 0.005, self:ColorA(player.col, 220))
					Render:DrawCircle(position, size.y * 0.005, black)

					if labels == 2 then
						if player.veh then
							str = format(
								"%s\n%s\n%i km/h : %i m : %i°",
								player.name,
								player.veh,
								player.vel:Length() * 3.6,
								player.pos.y + 200,
								self:YawToHeading(deg(player.ang.yaw))
							)
						else
							str = format("%s\nOn-Foot", player.name)
						end
					end

					if labels ~= 0 then
						Render:FillArea(position + size * 0.003, Vector2(Render:GetTextWidth(str, text_size), Render:GetTextHeight(str, text_size)), self:ColorA(black, 128))
						Render:DrawText(position + size * 0.003 + one, str, self:ColorA(black, 128), text_size)
						Render:DrawText(position + size * 0.003, str, player.col, text_size)
					end

				end

			end

			local str = "Left-click for extraction.    Middle-click to set waypoint.    Right-click to toggle labels."
			local str_size = Render:GetTextSize(str, text_size)
			Render:DrawText(Vector2(0.5 * size.x - 0.5 * str_size.x, 0 + 0.5 * str_size.y), str, white, text_size)

		end

		if self.extraction_timer then
			local position = math.lerp(self:WorldToMap(self.previous_position), self:WorldToMap(self.next_position), self.extraction_timer:GetSeconds() / self.extraction_delay)
			self.heli:SetPosition(position - 0.5 * self.heli:GetSize())
			self.heli:Draw()
		else
			self.marker:SetPosition(self:WorldToMap(LocalPlayer:GetPosition()) - 0.5 * self.marker:GetSize())
			self.marker:Draw()
			local waypoint, exist = Waypoint:GetPosition()
			if exist then
				self.waypoint:SetPosition(self:WorldToMap(waypoint) - 0.5 * self.waypoint:GetSize())
				self.waypoint:Draw()
			end
		end

	end

end

function ExtractionMap:ColorA(color, alpha)
	color.a = alpha
	return color
end

function ExtractionMap:PlayerUpdate(args)
	self.players = args
end

function ExtractionMap:ResolutionChange(args)
	self.text_size = args.size.y * self.text_scale
	self.map:SetSize(Vector2(args.size.y, args.size.y))
	self.waypoint:SetSize(one * args.size.y * 0.04)
	self.marker:SetSize(one * args.size.y * 0.04)
	self.heli:SetSize(one * args.size.y * 0.04)
	self.map:SetPosition(Vector2(0.5 * args.size.x - 0.5 * self.map:GetSize().x, 0))
end

function ExtractionMap:InputBlock(args)
	if self.render and self.actions[args.input] or self.extraction_sequence then
		return false
	end
end

ExtractionMap = ExtractionMap()
