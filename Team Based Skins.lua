local callbacks_Register, client_AllowListener, client_GetLocalPlayerIndex, client_GetPlayerIndexByUserID, client_Command, draw_GetScreenSize, entities_GetLocalPlayer, file_Enumerate, file_Read, file_Write, gui_Button, gui_Combobox, gui_Text, gui_GetValue, gui_Command, gui_Editbox, gui_Groupbox, gui_Listbox, gui_Reference, gui_Slider, gui_Tab, gui_Window, http_Get, loadstring, string_format, table_insert, table_remove, table_sort, unpack, tostring, tonumber = callbacks.Register, client.AllowListener, client.GetLocalPlayerIndex, client.GetPlayerIndexByUserID, client.Command, draw.GetScreenSize, entities.GetLocalPlayer, file.Enumerate, file.Read, file.Write, gui.Button, gui.Combobox, gui.Text, gui.GetValue, gui.Command, gui.Editbox, gui.Groupbox, gui.Listbox, gui.Reference, gui.Slider, gui.Tab, gui.Window, http.Get, loadstring, string.format, table.insert, table.remove, table.sort, unpack, tostring, tonumber
local dir = 'Team-Based-Skins/'
local allow_temp_file = false
local dev = false

local weapons, _weapons, weapon_keys, skins, _skins, skin_keys, stickers, _stickers, sticker_keys, json do
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
		n[i+2] = dev and file.Read(dir..n[i]) or http.Get('https://raw.githubusercontent.com/Zack2kl/'..dir..'master/'..n[i])
	end

	json = loadstring(n[3])()
	local parsed = json.parse(n[4])

	local function separate_info(tbl)
		local normal, reversed, indexed = {}, {}, {}
		local o, a = tbl['1'], tbl['2']
		local i = 0

		repeat
			local FullName = o[i]
			local item_name = a[i]

			if FullName then
				normal[FullName] = item_name
				reversed[item_name] = FullName
				indexed[i] = FullName
			end

			i = i + 1
		until o[i] == nil

		return normal, reversed, indexed
	end

	weapons, _weapons, weapon_keys = separate_info(parsed.weapon_keys)
	_stickers, stickers, sticker_keys = separate_info(parsed.sticker_keys)
	skins, _skins, skin_keys = {}, {}, {}

	local function getn(tbl)
		local n = 0

		for _ in pairs(tbl) do
			n = n + 1
		end

		return n
	end

	for wep_index=0, getn(parsed.skin_keys) - 1 do
		local wep_skins = parsed.skin_keys[ tostring(wep_index) ]

		skins[wep_index] = {}
		skin_keys[wep_index] = {}

		local n, last = 0, 1
		repeat
			local SkinName = wep_skins[n + 1]
			local skin_name = wep_skins[n + 2]

			if SkinName and skin_name then
				skins[wep_index][last] = skin_name
				skin_keys[wep_index][last] = SkinName
				_skins[skin_name] = SkinName
				last = last + 1
			end

			n = n + 2
		until wep_skins[n] == nil
	end
end

local set_pos = function(t)
	t.obj = t.obj or t[1]
	if not t.obj then error('Missing GUI Object', 2) end
	if t.x then t.obj:SetPosX(t.x) end
	if t.y then t.obj:SetPosY(t.y) end
	if t.w then t.obj:SetWidth(t.w) end
	if t.h then t.obj:SetHeight(t.h) end
	if t.desc then t.obj:SetDescription(t.desc) end
end

local MENU = gui_Reference('MENU')
local tab = gui_Tab(gui_Reference('Visuals'), 'team_based', 'Team Based Skins')
local group = gui_Groupbox(tab, 'Change visual items', 16, 16)
local TEAMS, team_skins = {'T', 'CT'}, {T = {}, CT = {}}

local list = gui_Listbox(group, 'T.skins', 194)
	set_pos{list, w=280, y=0}
local list2 = gui_Listbox(group, 'CT.skins', 194)
	set_pos{list2, w=280, y=218}

local menu_items = {
	gui_Combobox(group, 'team', 'Team', unpack(TEAMS)),
	gui_Combobox(group, 'item', 'Item', unpack(weapon_keys)),
	gui_Combobox(group, 'skin', 'Paint Kits', ''),
	gui_Slider(group, 'wear', 'Wear', 0, 0, 1, 0.01),
	gui_Editbox(group, 'seed', 'Seed'),
	gui_Editbox(group, 'stattrak', 'Stattrak'),
	gui_Editbox(group, 'name', 'Name'),
	gui_Combobox(group, 'sticker_location', 'Sticker Position', 'A', 'B', 'C', 'D', 'E')
}
local selected_stickers = {
	gui_Text(group, 'A) No Sticker Selected'),
	gui_Text(group, 'B) No Sticker Selected'),
	gui_Text(group, 'C) No Sticker Selected'),
	gui_Text(group, 'D) No Sticker Selected'),
	gui_Text(group, 'E) No Sticker Selected')
}

local menu_descs = {
	'Team you wish to have the skin on.',
	'Select weapon or model',
	'Select skin of model',
	'Quality of item texture.',
	'Seed of texture generation.',
	'Kill counter of weapon.',
	'Custom name of item.',
	'Position of sticker.'
}

local stickers_pos = {'A', 'B', 'C', 'D', 'E'}
local temp_sticker_list = {}
local temp_stickers = {}

local s = 0
for i=1, #menu_items do
	set_pos{menu_items[i], x=296, y=s, w=280, h=35, desc=menu_descs[i]}
	s = 60 + s
end

local s = 0
for i=1, #selected_stickers do
	set_pos{selected_stickers[i], x=296, y=516+s, w=280}
	s = 16 + s
end

local team, item, skin, wear, seed, stattrak, name, sticker_pos = unpack(menu_items)
local sticker_search, sticker_list = gui_Editbox(group, 'sticker_search', 'Sticker Search Bar'), gui_Listbox(group, 'sticker_list', 194)
	set_pos{sticker_search, y=450, w=280}
	set_pos{sticker_list, y=502, w=280}
	sticker_list:SetOptions( unpack(sticker_keys) )

local function changer_update(team)
	gui_Command('skin.clear')

	local tbl = team_skins[team]
	for i=1, #tbl do
		local v = tbl[i]
		gui_Command( string_format('skin.add "%s" "%s" "%s" "%s" "%s" "%s" "%s" "%s" "%s" "%s" "%s"',
			v[1] or '', v[2] or '', v[3] or '', v[4] or '', v[5] or '', v[6] or '', -- dumb checks just incase
			v[7] or '', v[8] or '', v[9] or '', v[10] or '', v[11] or ''
		))
	end

	if client.GetConVar('sv_cheats') == '1' then
		client_Command('cl_fullupdate', true) -- Doesn't work if sv_cheats isn't 1
	else
		client_Command('record a; stop;', true) -- Might work idk
	end
end

local function list_update(_load, _team)
	local team = _team or TEAMS[team:GetValue() + 1]
	local list = team == 'T' and list or list2
	local options = {}

	if not _load then
		local item = item:GetValue()
		local skin = (item >= 34 and item <= 52 and skin:GetValue()) or skin:GetValue() + 1

		local tbl = {
			weapons[weapon_keys[item + 1]],
			skins[item] and skins[item][skin] or '',
			string_format('%.2f', wear:GetValue()),
			seed:GetValue() == '' and 0 or seed:GetValue(),
			stattrak:GetValue() == '' and 0 or stattrak:GetValue(),
			name:GetValue(),
			temp_stickers[1] or '',
			temp_stickers[2] or '',
			temp_stickers[3] or '',
			temp_stickers[4] or '',
			temp_stickers[5] or '',
		}

		temp_stickers = {}
		for i=1, 5 do
			selected_stickers[i]:SetText( stickers_pos[i] .. ') No Sticker Selected' )
		end

		table_insert(team_skins[team], tbl)
	end

	for i=1, #team_skins[team] do
		local v = team_skins[team][i]
		options[1 + (#team_skins[team] - i)] = string_format('%s %s', _weapons[v[1]], v[2] == '' and '' or '- ' .. _skins[v[2]])
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
		set_pos{window, h=330, y=(Y * 0.5) - 165}
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
	set_pos{add, x=296, y=482, w=280, h=16}

local rem = gui_Button(group, 'Remove from T', function() remove_from_list('T') end)
	set_pos{rem, y=198, w=280, h=16}

local rem2 = gui_Button(group, 'Remove from CT',  function() remove_from_list('CT') end)
	set_pos{rem2, y=416, w=280, h=16}

local save = gui_Button(group, 'Save to File',  function() config_system(save_to_file, 'Save') end)
	set_pos{save, x=360, y=-43, w=100, h=18}

local _load = gui_Button(group, 'Load from File',  function() config_system(load_from_file, 'Load') end)
	set_pos{_load, x=476, y=-43, w=100, h=18}

local last_item, last_team, last_search, last_sticker_list
local function update()
	tab:SetDisabled( not gui_GetValue('esp.skins.enabled') )

	local search = sticker_search:GetString()
	if search ~= last_search then
		local s = search:lower()
		local results = {}
		local keywords = {}

		if #s ~= 0 then
			for word in s:gmatch('([^%s]+)') do
				keywords[#keywords + 1] = word
			end

			for i=1, #sticker_keys do
				local sticker = sticker_keys[i]
				local s2 = sticker:lower()
				local found = 0

				for k=1, #keywords do
					if s2:find(keywords[k]) then
						found = found + 1
					end
				end

				if found == #keywords then
					results[#results + 1] = sticker
				end
			end
		end

		temp_sticker_list = #s == 0 and sticker_keys or results
		sticker_list:SetOptions( unpack(temp_sticker_list) )
		last_search = s
	end

	local sticker_l = sticker_list:GetValue() + 1
	if sticker_l ~= last_sticker_list then
		local sticker_sel = sticker_pos:GetValue() + 1
		local _sticker_ = temp_sticker_list[sticker_l]

		if _sticker_ then
			selected_stickers[sticker_sel]:SetText( sticker_pos:GetString() .. ') ' .. _sticker_ )
			temp_stickers[sticker_sel] = _stickers[_sticker_]
		end

		last_sticker_list = sticker_l
	end

	local val = item:GetValue()
	if last_item ~= val then
		local skins = skin_keys[val]
		local a = not skins

		skin:SetDisabled(a)
		wear:SetDisabled(a)
		seed:SetDisabled(a)
		stattrak:SetDisabled(a)
		name:SetDisabled(a)
		sticker_search:SetDisabled(a)
		sticker_pos:SetDisabled(a)
		sticker_list:SetDisabled(a)

		if val >= 34 and val <= 52 then
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