-- Written by Sinister Rectus - http://www.jc-mp.com/forums/index.php?action=profile;u=73431

class 'Map'

function Map:__init()
	
	self.players = {}
	self.viewers = {}
	
	self.timer = Timer()
	self.delay = 1000
	
	Network:Subscribe("InitialTeleport", self, self.Teleport)
	Network:Subscribe("CorrectedTeleport", self, self.Teleport)
	Network:Subscribe("MapShown", self, self.MapShown)
	Network:Subscribe("MapHidden", self, self.MapHidden)
	
	Events:Subscribe("PreTick", self, self.BroadcastUpdate)
	Events:Subscribe("ModuleLoad", self, self.ModuleLoad)
	Events:Subscribe("PlayerSpawn", self, self.PlayerSpawn)
	Events:Subscribe("PlayerDeath", self, self.PlayerDeath)
	Events:Subscribe("PlayerQuit", self, self.PlayerQuit)

end

function Map:Teleport(args, sender)

	sender:SetPosition(Vector3(args.position.x, math.max(args.position.y, 200), args.position.z))
	
end

function Map:MapShown(_, sender)

	self:AddViewer(sender)

end

function Map:MapHidden(_, sender)

	self:RemoveViewer(sender)

end

function Map:AddViewer(viewer)

	self.viewers[viewer:GetId()] = viewer

end

function Map:RemoveViewer(viewer)

	self.viewers[viewer:GetId()] = nil

end

function Map:PlayerSpawn(args)

	self:AddPlayer(args.player)

end

function Map:PlayerDeath(args)

	self:RemovePlayer(args.player)

end

function Map:PlayerQuit(args)

	self:RemoveViewer(args.player)
	self:RemovePlayer(args.player)

end

function Map:AddPlayer(player)

	self.players[player:GetId()] = player

end

function Map:RemovePlayer(player)

	self.players[player:GetId()] = nil
	
end

function Map:BroadcastUpdate()

	if self.timer:GetMilliseconds() < self.delay then return end
	self.timer:Restart()
	
	local is_viewed
	for	_, viewer in pairs(self.viewers) do
		is_viewed = true
		break
	end
	
	if not is_viewed then return end

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

Map = Map()
