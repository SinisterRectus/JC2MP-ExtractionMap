local max = math.max
local insert = table.insert

class 'ExtractionMap'

function ExtractionMap:__init()

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

function ExtractionMap:Teleport(args, sender)
	sender:SetPosition(Vector3(args.position.x, max(args.position.y, 200), args.position.z))
end

function ExtractionMap:AddViewer(viewer)
	self.viewers[viewer:GetId()] = viewer
end

function ExtractionMap:RemoveViewer(viewer)
	self.viewers[viewer:GetId()] = nil
end

function ExtractionMap:AddPlayer(player)
	self.players[player:GetId()] = player
end

function ExtractionMap:RemovePlayer(player)
	self.players[player:GetId()] = nil
end

function ExtractionMap:MapShown(_, sender)
	self:AddViewer(sender)
end

function ExtractionMap:MapHidden(_, sender)
	self:RemoveViewer(sender)
end

function ExtractionMap:PlayerSpawn(args)
	self:AddPlayer(args.player)
end

function ExtractionMap:PlayerDeath(args)
	self:RemovePlayer(args.player)
end

function ExtractionMap:PlayerQuit(args)
	self:RemoveViewer(args.player)
	self:RemovePlayer(args.player)
end

function ExtractionMap:BroadcastUpdate()

	if self.timer:GetMilliseconds() < self.delay then return end
	self.timer:Restart()

	if not next(self.viewers) then return end

	local send_args = {}

	for _, player in pairs(self.players) do

		if IsValid(player) then

			local data = {
				id = player:GetId(),
				name = player:GetName(),
				pos = player:GetPosition(),
				col = player:GetColor()
			}

			local vehicle = player:GetVehicle()
			if IsValid(vehicle) and vehicle:GetDriver() == player then
				data.veh = vehicle:GetName()
				data.vel = vehicle:GetLinearVelocity()
				data.ang = vehicle:GetAngle()
			end

			insert(send_args, data)

		end

	end

	Network:SendToPlayers(self.viewers, "PlayerUpdate", send_args)

end

function ExtractionMap:ModuleLoad()
	for player in Server:GetPlayers() do
		self.players[player:GetId()] = player
	end
end

ExtractionMap = ExtractionMap()
