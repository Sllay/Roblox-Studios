--!strict
-- S09.5 owner-approved staging activation only; never implicitly enable production.
return table.freeze({Enabled=game.GameId==10769712441 and game.PlaceId==93428341652658,DeveloperAllowlist=table.freeze({})})
