-- Written by Sinister Rectus - http://www.jc-mp.com/forums/index.php?action=profile;u=73431

class 'Map'

function Map:__init()
	
	self.players = {}
	self.viewers = {}
	
	self.timer = Timer()
	self.delay = 1000
	
	Network:Subscribe("InitialTeleport", self, self.Teleport)
	Network:Subscribe("CorrectedTeleport", self, self.Teleport)
	Network:Subscribe("MapShown", self, self.AddViewer)
	Network:Subscribe("MapHidden", self, self.RemoveViewer)
	
	Events:Subscribe("PreTick", self, self.BroadcastUpdate)
	Events:Subscribe("ModuleLoad", self, self.ModuleLoad)
	Events:Subscribe("PlayerSpawn", self, self.AddPlayer)
	Events:Subscribe("PlayerDeath", self, self.RemovePlayer)
	Events:Subscribe("PlayerQuit", self, self.RemovePlayer)

end

function Map:Teleport(args, sender)

	sender:SetPosition(Vector3(args.position.x, math.max(args.position.y, 200), args.position.z))
	
end

function Map:AddViewer(_, sender)

	self.viewers[sender:GetId()] = sender

end

function Map:RemoveViewer(_, sender)

	self.viewers[sender:GetId()] = nil

end

function Map:BroadcastUpdate()

	if self.timer:GetMilliseconds() < self.delay then return end
	if table.count(self.viewers) == 0 then return end
	
	self.timer:Restart()

	local send_args = {}
	
	for _, player in pairs(self.players) do
	
		if IsValid(player) then
		
			local data = {}
		
			data.id = player:GetId()
			data.name = player:GetName()
			data.pos = player:GetPosition()
			data.col = player:GetColor()
			
			local vehicle = player:GetVehicle()
			if IsValid(vehicle) and vehicle:GetDriver() == player then
				data.veh = vehicle:GetName()
				data.vel = vehicle:GetLinearVelocity()
				data.ang = vehicle:GetAngle()
			end
				
			table.insert(send_args, data)

		end
		
	end
	
	Network:SendToPlayers(self.viewers, "PlayerUpdate", send_args)
	
end

function Map:ModuleLoad()

	for player in Server:GetPlayers() do
		self.players[player:GetId()] = player
	end

end

function Map:AddPlayer(args)

	self.players[args.player:GetId()] = args.player

end

function Map:RemovePlayer(args)

	self.players[args.player:GetId()] = nil
	
end

Map = Map()
