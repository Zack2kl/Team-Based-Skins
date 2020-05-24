local core = 'Team-Based-Skins/'
local file_exists = function(n)local n,e=core..n file.Enumerate(function(c)if c==n then e=1 return end end)return e end
local function download_file(name)http.Get('https://raw.githubusercontent.com/Zack2kl/Team-Based-Skins/master/'..name,function(c)file.Open(core..name,'w'):Write(c):Close()end)end

local MENU = gui.Reference('MENU')
local tab = gui.Tab(gui.Reference('Visuals'), 'team_based', 'Team Based Skins')
local group = gui.Groupbox(tab, 'Change visual items', 16, 16)

local space = '-'
local list = gui.Listbox(group, 'T.skins', 194, space)
	list:SetWidth(280)
local list2 = gui.Listbox(group, 'CT.skins', 194, space)
	list2:SetWidth(280) list2:SetPosY(226)

local TEAMS = { 'T', 'CT' }
local team = gui.Combobox(group, 'team', 'Team', unpack(TEAMS))
	team:SetDescription('Team you wish to have the skin on.') team:SetPosX(296) team:SetPosY(0) team:SetWidth(280)

local weapons, _weapons, weapon_keys, skins, _skins, skin_keys = {}, {}, {}, {}, {}, {}
local team_skins = {T = {}, CT = {}}

local weaponlist = file_exists('weapon_list.txt')
local skinlist = file_exists('skin_list.txt')

if not weaponlist then
	download_file('weapon_list.txt')
end

if not skinlist then
	download_file('skin_list.txt')
end

if weaponlist then
	local f = file.Open(core..'weapon_list.txt', 'r')

	for line in f:Read():gmatch('([^\n]*)\n') do
		weapons[ line:match('([^\n]*)=') ] = line:gsub('([^\n]*)=', '')
		_weapons[ line:gsub('([^\n]*)=', '') ] = line:match('([^\n]*)=')
		weapon_keys[#weapon_keys + 1] = line:match('([^\n]*)=')
	end

	f:Close()
end

if skinlist then
	local f = file.Open(core..'skin_list.txt', 'r')
	local N = 0

	for line in f:Read():gmatch('([^\n]*)\n') do
		skin_keys[N], skins[N] = {}, {}
		for skin in line:gmatch('([^,]*),') do
			table.insert(skins[N], {skin:match('([^=]*)='), skin:gsub('([^=]*)=', '')})
			table.insert(skin_keys[N], skin:match('([^=]*)='))
			_skins[skin:gsub('([^=]*)=', '')] = skin:match('([^=]*)=')
		end
		N = N + 1
	end

	f:Close()
end

local item = gui.Combobox(group, 'item', 'Item', unpack(weapon_keys)) or gui.Text(group, 'If you see this message, reload the lua.')
	item:SetDescription('Select weapon or model') item:SetPosX(296) item:SetPosY(70) item:SetWidth(280)

local skin = gui.Combobox(group, 'skin', 'Paint Kits', '')
	skin:SetDescription('Select skin of model') skin:SetPosX(296) skin:SetPosY(140) skin:SetWidth(280)

local wear = gui.Slider(group, 'wear', 'Wear', 0, 0, 1, 0.0001)
	wear:SetDescription('Quality of item texture.')	wear:SetPosX(296) wear:SetPosY(210) wear:SetWidth(280)

local _seed = gui.Text(group, 'Seed')
	_seed:SetPosX(296) _seed:SetPosY(274)

local seed = gui.Editbox(group, 'seed', '')
	seed:SetPosX(294) seed:SetPosY(294) seed:SetWidth(280) seed:SetHeight(16)

local _stattrak = gui.Text(group, 'Stattrak')
	_stattrak:SetPosX(296) _stattrak:SetPosY(326)

local stattrak = gui.Editbox(group, 'stattrak', '')
	stattrak:SetPosX(296) stattrak:SetPosY(346) stattrak:SetWidth(280) stattrak:SetHeight(16)

local _name = gui.Text(group, 'Name')
	_name:SetPosX(296) _name:SetPosY(378)

local name = gui.Editbox(group, 'name', '')
	name:SetPosX(296) name:SetPosY(398) name:SetWidth(280) name:SetHeight(16)

local function changer_update(team)
	gui.Command('skin.clear')

	for i=1, #team_skins[team] do
		gui.Command( string.format('skin.add "%s" "%s" "%s" "%s" "%s" "%s"', unpack( team_skins[team][i] )) )
	end

	client.Command('cl_fullupdate', true)
end

local function add_to_list(_load, _team)
	local team = _team and _team or TEAMS[team:GetValue() + 1]
	local list = team == 'T' and list or list2
	local options = {}

	if not _load then
		local item = item:GetValue()
		local skin = skin:GetValue() + 1

		local tbl = {
			weapons[weapon_keys[item + 1]],
			skins[item][skin][2],
			wear:GetValue(),
			seed:GetValue(),
			stattrak:GetValue(),
			name:GetValue()
		}

		table.insert(team_skins[team], tbl)
	end

	for i=1, #team_skins[team] do
		local v = team_skins[team][i]
		options[#options + 1] = string.format('%s - %s', _weapons[v[1]], _skins[v[2]])
	end

	list:SetOptions( space, unpack(options) )

	if team == TEAMS[entities.GetLocalPlayer():GetTeamNumber() - 1] then
		changer_update(team)
	end
end

local function remove_from_list(team)
	local list = team == 'T' and list or list2
	table.remove(team_skins[team], list:GetValue())
	add_to_list(true, team)
end

local function confirmation(f, t)
	MENU:SetActive(0)
	local X, Y = draw.GetScreenSize()

	local window = gui.Window('temp_window', 'Confirmation', (X * 0.5) - 80, (Y * 0.5) - 75, 162, 140)
	local function back() MENU:SetActive(1) window:Remove() end
	local co = gui.Button(window, 'Confirm'..t, function() back() f() end)
		co:SetPosX(17) co:SetPosY(16)
	local ca = gui.Button(window, 'Cancel'..t, back) 
		ca:SetPosX(17) ca:SetPosY(64)
end

local function save_to_file()
	for t=1, #TEAMS do
		local opts = {}

		for i=1, #team_skins[TEAMS[t]] do
			opts[i] = string.format('"%s" "%s" "%s" "%s" "%s" "%s"', unpack( team_skins[TEAMS[t]][i] ))
		end

		local f = file.Open(core..TEAMS[t]..'.dat', 'w')
		f:Write( table.concat(opts, '\n').. '\n' )
		f:Close()
	end
end

local function load_from_file()
	for t=1, #TEAMS do
		local team = TEAMS[t]
		local f = file.Open(core..team..'.dat', 'r')
		local N = 1

		if not f then
			goto skip
		end

		for line in f:Read():gmatch('([^\n]*)\n') do
			local A = 1
			for var in line:gmatch('("[^ ]*)') do
				if not team_skins[team][N] then
					team_skins[team][N] = {}
				end

				team_skins[team][N][A] = var:gsub('"', '')
				A = A + 1
			end

			N = N + 1
		end

		add_to_list(true, team)
		f:Close()
		::skip::
	end
end

load_from_file()

local add = gui.Button(group, 'Add', add_to_list)
	add:SetPosX(296) add:SetPosY(426) add:SetWidth(280) add:SetHeight(20)

local rem = gui.Button(group, 'Remove from T', function() remove_from_list('T') end)
	rem:SetPosY(200) rem:SetWidth(280) rem:SetHeight(20)

local rem2 = gui.Button(group, 'Remove from CT',  function() remove_from_list('CT') end)
	rem2:SetPosY(426) rem2:SetWidth(280) rem2:SetHeight(20)

local save = gui.Button(group, 'Save to File',  function() confirmation(save_to_file, ' Save') end)
	save:SetPosY(462) save:SetWidth(576) save:SetHeight(20)

local _load = gui.Button(group, 'Load from File',  function() confirmation(load_from_file, ' Load') end)
	_load:SetPosY(498) _load:SetWidth(576) _load:SetHeight(20)

local last_item = -1
local function menu_update()
	local val = item:GetValue()
	if last_item ~= val then
		local skins = skin_keys[val]
		local a = not skins
		skin:SetDisabled(a) wear:SetDisabled(a) seed:SetDisabled(a) stattrak:SetDisabled(a) name:SetDisabled(a) _seed:SetDisabled(a) _stattrak:SetDisabled(a) _name:SetDisabled(a)
		skin:SetOptions( unpack(skins or {}) )
		skin:SetValue(0)
		last_item = val
	end
end

local function on_events(e)
	if e:GetName() ~= 'player_team' then
		return
	end

	if client.GetPlayerIndexByUserID( e:GetInt('userid') ) ~= client.GetLocalPlayerIndex() then
		return
	end

	local team = TEAMS[e:GetInt('team') - 1]
	if not team then
		return
	end

	changer_update(team)
end

client.AllowListener('player_team')
callbacks.Register('FireGameEvent', on_events)
callbacks.Register('Draw', menu_update)
