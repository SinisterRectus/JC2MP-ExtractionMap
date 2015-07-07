-- Written by Sinister Rectus - http://www.jc-mp.com/forums/index.php?action=profile;u=73431

class 'Map'

function Map:__init()
	
	self.players = {}
	
	Network:Subscribe("InitialTeleport", self, self.InitialTeleport)
	Network:Subscribe("CorrectedTeleport", self, self.CorrectedTeleport)
	Network:Subscribe("RequestUpdate", self, self.OnRequestUpdate)
	
	Events:Subscribe("ModuleLoad", self, self.OnModuleLoad)
	Events:Subscribe("PlayerSpawn", self, self.AddPlayer)
	Events:Subscribe("PlayerDeath", self, self.RemovePlayer)
	Events:Subscribe("PlayerQuit", self, self.RemovePlayer)

end

function Map:InitialTeleport(args, sender)

	sender:SetPosition(Vector3(args.position.x, math.max(args.position.y + 5, 200), args.position.z))
	
end

function Map:CorrectedTeleport(args, sender)

	sender:SetPosition(Vector3(args.position.x, math.max(args.position.y, 200), args.position.z))

end

function Map:OnRequestUpdate(args, sender)

	local send_args = {}
	
	for id in pairs(self.players) do
	
		local player = Player.GetById(id)
	
		if player ~= sender then
		
			local data = {}
		
			data.name = player:GetName()
			data.position = player:GetPosition()
			data.color = player:GetColor()
			
			if player:InVehicle() then
				local vehicle = player:GetVehicle()
				if player == vehicle:GetDriver() then
					data.vehicle_name = vehicle:GetName()
					data.velocity = vehicle:GetLinearVelocity()
					data.angle = vehicle:GetAngle()
				end
			end
				
			table.insert(send_args, data)

		end
		
	end
	
	Network:Send(sender, "PlayerUpdate", send_args)
	
end

function Map:OnModuleLoad()

	for player in Server:GetPlayers() do
	
		self.players[player:GetId()] = true
		
	end

end

function Map:AddPlayer(args)

	self.players[args.player:GetId()] = true

end

function Map:RemovePlayer(args)

	self.players[args.player:GetId()] = nil
	
end

Map = Map()
