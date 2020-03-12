local get_items=function(t,n)local c={}for i=1, #t do c[#c+1]=t[i][n]end return c end

local tab = gui.Tab(gui.Reference('Visuals'), 'team_based', 'Team Based Skins')
local group = gui.Groupbox(tab, 'Change visual items', 16, 16)

local list = gui.Listbox(group, 'skins', 388)
	list:SetWidth(280)

local TEAM = {'T', 'CT'}
local team = gui.Combobox(group, 'team', 'Team', 'T', 'CT')
	team:SetDescription('Team you wish to have the skin on.')
	team:SetPosX(296)
	team:SetPosY(0)
	team:SetWidth(280)


local skins = {}
http.Get('https://raw.githubusercontent.com/Zack2kl/Team-Based-Skins/master/skins.txt', function(cnt)
	local N = 1
	for line in cnt:gmatch('([^\n]*)\n') do
		local N1 = 1

		for word in line:gmatch('([^,]*)') do
			if N1 == 1 then
				skins[N] = {}
			end

			if N1 > 1 and word ~= '' then
				table.insert(skins[N], word)
			end
			N1 = N1 + 1
		end

		N = N + 1
	end
end)

local all_skins = {}
http.Get('https://raw.githubusercontent.com/Zack2kl/Team-Based-Skins/master/skin_to_actual_name.txt', function(cnt)
	for line in cnt:gmatch('([^\n]*)\n') do
		local words = {}
		for word in line:gmatch('([^,]*)') do
			words[#words + 1] = word
		end
		all_skins[words[1]] = words[3]
	end
end)

local weapons, last_item = {}, 0
http.Get('https://raw.githubusercontent.com/Zack2kl/Team-Based-Skins/master/name_to_var.txt', function(cnt)
	local N = 1
	for line in cnt:gmatch('([^\n]*)\n') do
		local words = {}
		for word in line:gmatch('([^,]*)') do
			words[#words + 1] = word
		end
		weapons[N] = {words[3], words[1]}
		N = N + 1
	end

	item = gui.Combobox(group, 'item', 'Item', unpack(get_items(weapons, 2)))
		item:SetDescription('Select weapon or model')
		item:SetPosX(296)
		item:SetPosY(70)
		item:SetWidth(280)
	local val = item:GetValue() + 1

	skin = gui.Combobox(group, 'skin', 'Paint Kits', '')
		skin:SetDescription('Select skin of model')
		skin:SetPosX(296)
		skin:SetPosY(140)
		skin:SetWidth(280)
		if last_item ~= val then
			skin:SetOptions( unpack( skins[val]) )
			last_item = val
		end
end)

local wear = gui.Slider(group, 'wear', 'Wear', 0, 0, 1, 0.0001)
	wear:SetDescription('Quality of item texture.')
	wear:SetPosX(296)
	wear:SetPosY(210)
	wear:SetWidth(280)

local _seed = gui.Text(group, 'Seed')
	_seed:SetPosX(296)
	_seed:SetPosY(280)

local seed = gui.Editbox(group, 'seed', '')
	seed:SetPosX(296)
	seed:SetPosY(300)
	seed:SetWidth(280)
	seed:SetHeight(20)

local _stattrak = gui.Text(group, 'Stattrak')
	_stattrak:SetPosX(296)
	_stattrak:SetPosY(340)

local stattrak = gui.Editbox(group, 'stattrak', '')
	stattrak:SetPosX(296)
	stattrak:SetPosY(360)
	stattrak:SetWidth(280)
	stattrak:SetHeight(20)

local _name = gui.Text(group, 'Name')
	_name:SetPosX(296)
	_name:SetPosY(400)

local name = gui.Editbox(group, 'name', '')
	name:SetPosX(296)
	name:SetPosY(420)
	name:SetWidth(280)
	name:SetHeight(20)

local items_in_list, update_items = {}, {}
local function add_to_list()
	local cmd = ''

	local v = item:GetValue() + 1
	local skin = skins[v][skin:GetValue() + 1]
	local actual_name = all_skins[ skin ]

	if actual_name then
		cmd = string.format('%s %s %s %s %s', weapons[v][1], all_skins[ skin ], wear:GetValue(), seed:GetValue() or '', stattrak:GetValue() or '', name:GetValue() or '')
	else
		cmd = string.format('%s %s', weapons[v][1], actual_name)
	end

	print(cmd)

	items_in_list[#items_in_list + 1] = TEAM[team:GetValue() + 1].. ' - '.. (weapons[v][2] or '').. (skin and ' - '.. skin or '')
	update_items[#update_items + 1] = cmd

	list:SetOptions( unpack(items_in_list) )
end

local function remove_from_list()
	gui.Command('skin.clear')

	local item = list:GetValue() + 1
	items_in_list[item] = nil
	update_items[item] = nil

	list:SetOptions( unpack(items_in_list) )
end

local add = gui.Button(group, 'Add', add_to_list)
	add:SetPosY(404)
	add:SetWidth(136)
	add:SetHeight(28)

local rem = gui.Button(group, 'Remove', remove_from_list)
	rem:SetPosX(144)
	rem:SetPosY(404)
	rem:SetWidth(136)
	rem:SetHeight(28)

callbacks.Register('Draw', function()
	if not item then
		return
	end

	if item:GetValue() == nil then
		return
	end

	local val = type(item:GetValue()) ~= 'string' and item:GetValue() + 1 or 0

	if last_item ~= val then
		skin:SetOptions( unpack(skins[val] or {}) )
		skin:SetValue(0)
		last_item = val
	end
end)

local function on_events(e)
	if e:GetName() ~= 'player_team' then
		return
	end

	if client.GetPlayerIndexByUserID( e:GetInt('userid') ) ~= client.GetLocalPlayerIndex() then
		return
	end

	local team = TEAM[e:GetInt('team') - 1] or nil
	if not team then
		return
	end

	gui.Command('skin.clear')

	for i=1, #update_items do
		local item = items_in_list[i]
		if item:sub(1,1) == team or item:sub(1,2) == team then
			gui.Command('skin.add '.. update_items[i])
		end
	end
end

client.AllowListener('player_team')
callbacks.Register('FireGameEvent', on_events)
