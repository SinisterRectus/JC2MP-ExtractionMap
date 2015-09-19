-- Written by Sinister Rectus - http://www.jc-mp.com/forums/index.php?action=profile;u=73431

class 'Map'

function Map:__init()

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
	
	Events:Subscribe("MouseUp", self, self.Mouseup)
	Events:Subscribe("KeyUp", self, self.ToggleMap)
	Events:Subscribe("PostRender", self, self.PostRender)
	Events:Subscribe("ResolutionChange", self, self.ResolutionChange)
	Events:Subscribe("LocalPlayerInput", self, self.InputBlock)

	Network:Subscribe("PlayerUpdate", self, self.PlayerUpdate)

end

function Map:ToggleMap(args)

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

function Map:Mouseup(args)

	if not self.render or not Game:GetState() == GUIState.Game or self.extraction_sequence then return end
		
	if self.extraction_enabled and args.button == 1 then

		if not LocalPlayer:InVehicle() then
	
			local position = self:MapToWorld(Mouse:GetPosition())
			
			if position.x >= -16384 and position.x <= 16384 and position.z >= -16384 and position.z <= 16384 then

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
	
		local waypoint, exist = Waypoint:GetPosition()
		
		if exist then
			Waypoint:Remove()
		else 
			Waypoint:SetPosition(self:MapToWorld(Mouse:GetPosition()))	
		end
		
	elseif args.button == 2 then
	
		if self.labels == 2 then
			self.labels = 0
		else
			self.labels = self.labels + 1
		end
			
	end

end

function Map:ExtractionSequence()

	if not self.extraction_sequence then return end

	if self.world_fadeout_timer then
		
		if self.world_fadeout_timer:GetMilliseconds() > self.world_fadeout_delay then
			Network:Send("InitialTeleport", {position = self.next_position})
			self.world_fadeout_timer = nil
			self.extraction_timer = Timer()
			self.teleporting = true
		end
		
	end
	
	if self.teleporting then 
	
		if LocalPlayer:GetPosition() ~= self.previous_position then
			self.teleporting = false
			self.loading = true
		end
		
	end
	
	if self.loading then 
		
		if LocalPlayer:GetLinearVelocity() ~= Vector3.Zero then
			self.loading = false
		end
		
	end
	
	if self.extraction_timer then
		
		if self.extraction_timer:GetSeconds() > self.extraction_delay then
			self.extraction_timer = nil
			self.map_fadeout_timer = Timer()
		end
		
	end
	
	if self.map_fadeout_timer then
	
		local dt = self.map_fadeout_timer:GetMilliseconds()
		local delay = self.map_fadeout_delay
	
		self.map:SetAlpha(math.clamp(1 - dt / delay, 0, 1))
		self.marker:SetAlpha(math.clamp(1 - dt / delay, 0, 1))
		self.waypoint:SetAlpha(math.clamp(1 - dt / delay, 0, 1))
	
		if dt > delay then
			self.map_fadeout_timer = nil
		end
		
	end
		
	
	if not self.world_fadeout_timer and not self.world_fadein_timer and not self.teleporting and not self.loading and not self.extraction_timer and not self.map_fadeout_timer then
	
		self.world_fadein_timer = Timer()
		local ray = Physics:Raycast(Vector3(self.next_position.x, 2100, self.next_position.z), Vector3.Down, 0, 2100)
		Network:Send("CorrectedTeleport", {position = ray.position})
		
	end
	
	if self.world_fadein_timer then
	
		local dt = self.world_fadein_timer:GetMilliseconds()
		local delay = self.world_fadein_delay
		
		if dt > delay then

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

function Map:MapToWorld(position)

	local x = 32768 * (position.x - self.map:GetPosition().x) / self.map:GetSize().x - 16384
	local z = 32768 * (position.y - self.map:GetPosition().y) / self.map:GetSize().y - 16384
	
	return Vector3(x, Physics:GetTerrainHeight(Vector2(x, z)), z)

end

function Map:WorldToMap(position)

	local x = self.map:GetSize().x * (position.x + 16384) / 32768 + self.map:GetPosition().x
	local y = self.map:GetSize().y * (position.z + 16384) / 32768 + self.map:GetPosition().y
	
	return Vector2(x, y)

end

function Map:YawToHeading(yaw)
	if yaw < 0 then
		return -yaw
	else
		return 360 - yaw
	end
end

function Map:PostRender()

	if Game:GetState() ~= GUIState.Game then return end
	
	if self.extraction_sequence then
	
		if self.world_fadeout_timer then
		
			local dt = self.world_fadeout_timer:GetMilliseconds()
			local delay = self.world_fadeout_delay
			
			if dt < delay then
				
				Render:FillArea(Vector2.Zero, Render.Size, self:ColorA(Color.Black, 255 * (dt / delay)))
		
			end
			
		end
		
		if self.teleporting or self.loading or self.extraction_timer or self.map_fadeout_timer then
		
			Render:FillArea(Vector2.Zero, Render.Size, Color.Black)
			
		end

		if self.world_fadein_timer then
		
			local dt = self.world_fadein_timer:GetMilliseconds()
			local delay = self.world_fadein_delay
			
			if dt < delay then
		
				Render:FillArea(Vector2.Zero, Render.Size, self:ColorA(Color.Black, 255 * (1 - dt / delay)))
				
			end

		end
	
	end

	if self.render then

		self.map:Draw()

		if not self.extraction_sequence then
		
			for _,player in ipairs(self.players) do
			
				if player.id ~= LocalPlayer:GetId() then

					local position = self:WorldToMap(player.pos)
					local str = player.name
				
					Render:FillCircle(position, Render.Height * 0.005, self:ColorA(player.col, 220))
					Render:DrawCircle(position, Render.Height * 0.005, Color.Black)
					
					if self.labels == 2 then
					
						if player.veh then

							str = string.format(
								"%s\n%s\n%i km/h : %i m : %i°", 
								player.name, 
								player.veh, 
								player.vel:Length() * 3.6, 
								player.pos.y + 200, 
								self:YawToHeading(math.deg(player.ang.yaw))
							)
							
						else
						
							str = string.format("%s\nOn-Foot", player.name)
							
						end
						
					end
					
					if self.labels ~= 0 then
					
						Render:FillArea(position + Render.Size * 0.003, Vector2(Render:GetTextWidth(str, self.text_size), Render:GetTextHeight(str, self.text_size)), self:ColorA(Color.Black, 128))
						Render:DrawText(position + Render.Size * 0.003 + Vector2.One, str, self:ColorA(Color.Black, 128), self.text_size)
						Render:DrawText(position + Render.Size * 0.003, str, player.col, self.text_size)
						
					end
					
				end
					
			end
			
			local str = "Left-click for extraction.    Middle-click to set waypoint.    Right-click to toggle labels."
			local str_size = Render:GetTextSize(str, self.text_size)
			Render:DrawText(Vector2(0.5 * Render.Width - 0.5 * str_size.x, 0 + 0.5 * str_size.y), str, Color.White, self.text_size)
			
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

function Map:ColorA(color, alpha)

	return Color(color.r, color.g, color.b, alpha)

end

function Map:PlayerUpdate(args)

	self.players = args
	
end

function Map:ResolutionChange(args)

	self.text_size = args.size.y * self.text_scale
	self.map:SetSize(Vector2(args.size.y, args.size.y))
	self.waypoint:SetSize(Vector2.One * args.size.y * 0.04)
	self.marker:SetSize(Vector2.One * args.size.y * 0.04)
	self.heli:SetSize(Vector2.One * args.size.y * 0.04)
	self.map:SetPosition(Vector2(0.5 * args.size.x - 0.5 * self.map:GetSize().x, 0))

end

function Map:InputBlock(args)

	if self.extraction_sequence then
		return false
	end
	
	if self.render and self.actions[args.input] then
		return false
	end

end

Map = Map()
