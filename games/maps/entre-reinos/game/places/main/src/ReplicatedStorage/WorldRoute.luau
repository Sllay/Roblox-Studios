--!strict
-- Pure, portable contract for lobby/server routing. No API calls or Instances.
local SlotModel = require("./SlotModel")
local Route = {}
Route.PROTOCOL = 1
Route.KIND = "EntreReinosWorld"

function Route.isWorldServer(privateServerId: any, privateOwnerId: any): boolean
    return type(privateServerId) == "string" and #privateServerId > 0
        and privateOwnerId == 0
end

function Route.validArrival(ticket: any, userId: number,
        placeId: number, privateServerId: string): boolean
    return type(ticket) == "table"
        and ticket.kind == Route.KIND
        and ticket.protocol == Route.PROTOCOL
        and SlotModel.validIndex(ticket.slot)
        and ticket.ownerUserId == userId
        and ticket.sourcePlaceId == placeId
        and type(ticket.reservedId) == "string"
        and #ticket.reservedId > 0
        and ticket.reservedId == privateServerId
        and type(privateServerId) == "string"
        and privateServerId ~= ""
end

return Route
