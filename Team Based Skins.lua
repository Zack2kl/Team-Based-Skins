local callbacks_Register, client_AllowListener, client_GetLocalPlayerIndex, client_GetPlayerIndexByUserID, draw_GetScreenSize, entities_GetLocalPlayer, file_Enumerate, file_Read, file_Write, gui_Button, gui_Combobox, gui_Command, gui_Editbox, gui_Groupbox, gui_Listbox, gui_Reference, gui_Slider, gui_Tab, gui_Window, http_Get, loadstring, string_format, table_insert, table_remove, table_sort, unpack, tostring, tonumber = callbacks.Register, client.AllowListener, client.GetLocalPlayerIndex, client.GetPlayerIndexByUserID, draw.GetScreenSize, entities.GetLocalPlayer, file.Enumerate, file.Read, file.Write, gui.Button, gui.Combobox, gui.Command, gui.Editbox, gui.Groupbox, gui.Listbox, gui.Reference, gui.Slider, gui.Tab, gui.Window, http.Get, loadstring, string.format, table.insert, table.remove, table.sort, unpack, tostring, tonumber
local dir = 'Team-Based-Skins/'
local allow_temp_file = false

local weapons, _weapons, weapon_keys, skins, _skins, skin_keys, json do
	local def_cfg

	file_Enumerate(function(c)
		if c == dir..'default.dat' then
			def_cfg = 1
		end
	end)

	if not def_cfg then
		file_Write(dir..'default.dat', '{"T":[],"CT":[]}')
	end

	local n = {'json.txt', 'skins.txt'}

	for i=1, 2 do
		n[i+2] = http.Get('https://raw.githubusercontent.com/Zack2kl/'..dir..'master/'..n[i])
	end

	json = loadstring(n[3])()
	local parsed = json.parse(n[4])

	weapons, _weapons, weapon_keys, skins, _skins, skin_keys = unpack(parsed)
end

local MENU = gui_Reference('MENU')
local tab = gui_Tab(gui_Reference('Visuals'), 'team_based', 'Team Based Skins')
local group = gui_Groupbox(tab, 'Change visual items', 16, 16)
local TEAMS, team_skins = {'T', 'CT'}, {T = {}, CT = {}}

local list = gui_Listbox(group, 'T.skins', 194)
	list:SetWidth(280) list:SetPosY(0)
local list2 = gui_Listbox(group, 'CT.skins', 194)
	list2:SetWidth(280) list2:SetPosY(218)

local menu_items = {
	gui_Combobox(group, 'team', 'Team', unpack(TEAMS)),
	gui_Combobox(group, 'item', 'Item', unpack(weapon_keys)),
	gui_Combobox(group, 'skin', 'Paint Kits', ''),
	gui_Slider(group, 'wear', 'Wear', 0, 0, 1, 0.01),
	gui_Editbox(group, 'seed', 'Seed'),
	gui_Editbox(group, 'stattrak', 'Stattrak'),
	gui_Editbox(group, 'name', 'Name')
}

local s = 0
for i=1, #menu_items do
	local a = menu_items[i]
	a:SetPosX(296)
	a:SetPosY(s)
	a:SetWidth(280)
	a:SetHeight(35)
	s = 60 + s
end

local team, item, skin, wear, seed, stattrak, name = unpack(menu_items)
	team:SetDescription('Team you wish to have the skin on.')
	item:SetDescription('Select weapon or model')
	skin:SetDescription('Select skin of model')
	wear:SetDescription('Quality of item texture.')
	seed:SetDescription('Seed of texture generation.')
	stattrak:SetDescription('Kill counter of weapon.')
	name:SetDescription('Custom name of item.')

local function changer_update(team)
	gui_Command('skin.clear')

	local tbl = team_skins[team]
	for i=1, #tbl do
		gui_Command( string_format('skin.add "%s" "%s" "%s" "%s" "%s" "%s"', unpack(tbl[i])) )
	end
end

local function list_update(_load, _team)
	local team = _team or TEAMS[team:GetValue() + 1]
	local list = team == 'T' and list or list2
	local options = {}

	if not _load then
		local item = item:GetValue()
		local skin = (item > 33 and item < 53 and skin:GetValue()) or skin:GetValue() + 1
		local new_i = tostring(item)

		local tbl = {
			weapons[weapon_keys[item + 1]],
			skins[new_i] and skins[new_i][skin] and skins[new_i][skin][2] or '',
			string_format('%.2f', wear:GetValue()),
			seed:GetValue() == '' and 0 or seed:GetValue(),
			stattrak:GetValue() == '' and 0 or stattrak:GetValue(),
			name:GetValue()
		}

		table_insert(team_skins[team], tbl)
	end

	for i=1, #team_skins[team] do
		local v = team_skins[team][i]
		options[1 + (#team_skins[team] - i)] = string_format('%s %s', _weapons[v[1]], v[2] == '' and '' or '- '.. _skins[v[2]] )
	end

	list:SetOptions( unpack(options) )

	local local_player = entities_GetLocalPlayer()
	if local_player then
		if team == TEAMS[local_player:GetTeamNumber() - 1] then
			changer_update(team)
		end
	end
end

local function remove_from_list(team)
	local list = team == 'T' and list or list2
	table_remove(team_skins[team], 1 + (#team_skins[team] - (list:GetValue() + 1)) )
	list_update(true, team)
end

local gather_configs = function()
	local cfgs = {}

	file_Enumerate(function(name)
		if name:sub(1, #dir) == dir then
			cfgs[#cfgs + 1] = name:match('/(.*).dat$')
		end
	end)

	table_sort(cfgs, function(a)
		return a == 'default'
	end)

	return cfgs
end

local function config_system(func, _type)
	local x, y = MENU:GetValue()
	local X, Y = draw_GetScreenSize()
	MENU:SetValue(X, Y)

	local window = gui_Window('', 'Config System', (X * 0.5) - 85, (Y * 0.5) - 130, 170, 260)
	local group = gui_Groupbox(window, t, 16, 16)

	local function back()
		MENU:SetValue(x, y)
		window:Remove()
	end

	local cfgs = gather_configs()
	local config = gui_Combobox(group, '', 'Configs', unpack(cfgs)) 
	local new = _type == 'Save' and gui_Editbox(group, '', 'New Config')

	if _type == 'Save' then
		new:SetDescription('Creates new config')
		window:SetHeight(330)
		window:SetPosY( (Y * 0.5) - 165 )
	end

	local co = gui_Button(group, 'Confirm', function()
		if _type == 'Load' then
			func( cfgs[config:GetValue() + 1] )
		else
			local v = new:GetValue()

			if v:find('[a-zA-Z0-9]') then
				func( v )
			else
				func( cfgs[config:GetValue() + 1] )
			end
		end

		back()
	end)

	local ca = gui_Button(group, 'Cancel', back) 
		co:SetWidth(106) ca:SetWidth(106)
end

local function save_to_file(name)
	file_Write( dir..name:lower()..'.dat', json.stringify(team_skins) )
end

local function load_from_file(name)
	local info = file_Read(dir..name:lower()..'.dat')
	team_skins = json.parse(info)

	list_update(true, 'T')
	list_update(true, 'CT')
end

local add = gui_Button(group, 'Add', list_update)
	add:SetPosX(296) add:SetPosY(416) add:SetWidth(280) add:SetHeight(16)

local rem = gui_Button(group, 'Remove from T', function() remove_from_list('T') end)
	rem:SetPosY(198) rem:SetWidth(280) rem:SetHeight(16)

local rem2 = gui_Button(group, 'Remove from CT',  function() remove_from_list('CT') end)
	rem2:SetPosY(416) rem2:SetWidth(280) rem2:SetHeight(16)

local save = gui_Button(group, 'Save to File',  function() config_system(save_to_file, 'Save') end)
	save:SetPosX(360) save:SetPosY(-43) save:SetWidth(100) save:SetHeight(18)

local _load = gui_Button(group, 'Load from File',  function() config_system(load_from_file, 'Load') end)
	_load:SetPosX(476) _load:SetPosY(-43) _load:SetWidth(100) _load:SetHeight(18)

local last_item, last_team
local function update()
	local val = item:GetValue() + 1

	if last_item ~= val then
		local skins = skin_keys[val]
		local a = not skins

		skin:SetDisabled(a)
		wear:SetDisabled(a)
		seed:SetDisabled(a)
		stattrak:SetDisabled(a)
		name:SetDisabled(a)

		if val > 33 and val < 53 then
			skin:SetOptions( 'Vanilla', unpack(skins or {}) )
		else
			skin:SetOptions( unpack(skins or {}) )
		end

		skin:SetValue(0)
		last_item = val
	end

	local local_player = entities_GetLocalPlayer()
	if local_player then
		local current_team = TEAMS[local_player:GetTeamNumber() - 1]

		if current_team and last_team ~= current_team then
			changer_update( current_team )
			last_team = current_team
		end
	end
end

local knife_name = function(a)
	for i=1, #a do
		local s = a[i]

		if s[1]:find('knife') or s[1] == 'weapon_bayonet' then
			return s[1]
		end
	end
end

local need_update
local function on_event(e)
	local event = e:GetName()

	if event ~= 'round_prestart' and event ~= 'player_death' then
		return
	end

	local cur_team = TEAMS[entities_GetLocalPlayer():GetTeamNumber() - 1]
	if event == 'round_prestart' and cur_team then
		if need_update then
			changer_update( cur_team )
			need_update = false
		end

		return
	end

	local local_player = client_GetLocalPlayerIndex()
	if client_GetPlayerIndexByUserID(e:GetInt('attacker')) ~= local_player or client_GetPlayerIndexByUserID(e:GetInt('userid')) == local_player then
		return
	end

	local tbl = team_skins[cur_team]
	local weapon = e:GetString('weapon')
	local weapon = (weapon:find('knife') and knife_name(tbl)) or ('weapon_'.. weapon)

	for i=1, #tbl do
		local s = tbl[i]

		if s[1] == weapon then
			local v = tonumber(s[5])

			if v > 0 then
				team_skins[cur_team][i][5] = v + 1
				need_update = true
			end

			break
		end
	end
end

client_AllowListener('round_prestart')
client_AllowListener('player_death')
callbacks_Register('FireGameEvent', on_event)
callbacks_Register('Draw', update)

callbacks_Register('Unload', function()
	if allow_temp_file then
		save_to_file('temp')
	end

	tab:Remove()
end)

load_from_file('default')