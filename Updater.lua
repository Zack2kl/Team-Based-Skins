-- Run this lua to automatically download/update Team Based Skins lua.

local dir = 'Team-Based-Skins/'
local url = 'https://raw.githubusercontent.com/Zack2kl/'..dir..'master/'
local lua, skins, json, cur = 'Team Based Skins.lua', 'skins.txt', 'json.txt', 'Updater.lua'

file.Write( dir..json, http.Get(url..json) )
file.Write( dir..skins, http.Get(url..skins) )
file.Write( dir..lua, http.Get(url..lua) )
file.Write( dir..cur, http.Get(url..cur) )

LoadScript( dir .. lua )
file.Delete( GetScriptName() )