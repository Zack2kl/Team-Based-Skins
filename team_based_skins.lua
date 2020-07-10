-- local variables for API functions. any changes to the line below will be lost on re-generation
local callbacks_Register, client_AllowListener, client_GetLocalPlayerIndex, client_GetPlayerIndexByUserID, draw_GetScreenSize, entities_GetLocalPlayer, file_Enumerate, file_Read, file_Write, gui_Button, gui_Combobox, gui_Command, gui_Editbox, gui_Groupbox, gui_Listbox, gui_Reference, gui_Slider, gui_Tab, gui_Window, http_Get, string_format, table_concat, table_insert, table_remove, table_sort, unpack, pairs, tonumber = callbacks.Register, client.AllowListener, client.GetLocalPlayerIndex, client.GetPlayerIndexByUserID, draw.GetScreenSize, entities.GetLocalPlayer, file.Enumerate, file.Read, file.Write, gui.Button, gui.Combobox, gui.Command, gui.Editbox, gui.Groupbox, gui.Listbox, gui.Reference, gui.Slider, gui.Tab, gui.Window, http.Get, string.format, table.concat, table.insert, table.remove, table.sort, unpack, pairs, tonumber

local allow_temp_file = false -- Setting this to true will save the skin cfg on lua unload. *This might crash you.
local git, dir, files = 'https://raw.githubusercontent.com/Zack2kl/', 'Team-Based-Skins/', {}
file_Enumerate(function(c)if c:sub(1,17)==dir then files[c:sub(18)]=''end end)

local MENU = gui_Reference('MENU')
local tab = gui_Tab(gui_Reference('Visuals'), 'team_based', 'Team Based Skins')
local group = gui_Groupbox(tab, 'Change visual items', 16, 16)

local TEAMS, team_skins = {'T', 'CT'}, {T = {}, CT = {}}
local weapons, _weapons, weapon_keys, skins, _skins, skin_keys = {}, {}, {}, {}, {}, {}

local function __init__()
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

			local tbl = {
				weapons[weapon_keys[item + 1]],
				skins[item] and skins[item][skin] and skins[item][skin][2] or '',
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
		local cfgs, new = {}, {}
		file_Enumerate(function(name) if name:find('.dat$') then new[ name:sub(18):gsub('/CT.dat', ''):gsub('/T.dat', '') ] = '' end end)
		for k in pairs(new) do cfgs[#cfgs + 1] = k end
		table_sort(cfgs, function(a)return a=='default'end)
		return cfgs
	end

	local function config_system(f, t)
		local x, y = MENU:GetValue()
		local X, Y = draw_GetScreenSize()
		MENU:SetValue(X, Y)

		local window = gui_Window('temp_window', 'Config System', (X * 0.5) - 85, (Y * 0.5) - 130, 170, 260)
		local group = gui_Groupbox(window, t, 16, 16)
		local function back() MENU:SetValue(x, y) window:Remove() end

		local cfgs = gather_configs()
		local config = gui_Combobox(group, 'temp_combo', 'Configs', unpack(cfgs)) 
		local new = t == 'Save' and gui_Editbox(group, 'temp_editbox', 'New Config')

		if t == 'Save' then
			new:SetDescription('Creates new config')
			window:SetHeight(330)
			window:SetPosY( (Y * 0.5) - 165 )
		end

		local co = gui_Button(group, 'Confirm', function() back() f( t == 'Load' and cfgs[config:GetValue() + 1] or (new:GetValue():find('[a-zA-Z0-9]') and new:GetValue() or cfgs[config:GetValue() + 1])) end)
		local ca = gui_Button(group, 'Cancel', back) 
			co:SetWidth(106) ca:SetWidth(106)
	end

	local function save_to_file(name)
		for t=1, #TEAMS do
			local team = TEAMS[t]
			local opts = {}

			for i=1, #team_skins[team] do
				opts[i] = string_format('"%s" "%s" "%s" "%s" "%s" "%s"', unpack( team_skins[team][i] ))
			end

			file_Write(dir..name:lower()..'/'..team..'.dat', table_concat(opts, '\n').. '\n')
		end
	end

	local function load_from_file(name)
		for t=1, #TEAMS do
			local team, N = TEAMS[t], 1
			team_skins[team] = {}
			local info = file_Read(dir..name:lower()..'/'..team..'.dat')

			for line in info:gmatch('([^\n]*)\n') do
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

			list_update(true, team)
		end
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
		local val = item:GetValue()
		if last_item ~= val then
			local skins = skin_keys[val]
			local a = not skins
			skin:SetDisabled(a) wear:SetDisabled(a) seed:SetDisabled(a) stattrak:SetDisabled(a) name:SetDisabled(a)
			if val > 33 and val < 53 then
				skin:SetOptions( 'Vanilla', unpack(skins or {}) )
			else
				skin:SetOptions( unpack(skins or {}) )
			end
			skin:SetValue(0)
			last_item = val
		end

		local local_player = entities_GetLocalPlayer()
		if not local_player then
			return
		end

		local current_team = TEAMS[local_player:GetTeamNumber() - 1]
		if current_team and last_team ~= current_team then
			changer_update( current_team )
			last_team = current_team
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

	if allow_temp_file then
		callbacks_Register('Unload', function() save_to_file('temp') end)
	end

	load_from_file('default')
end

-- credit: https://gist.github.com/tylerneylon/59f4bcf316be525b30ab
local json = loadstring([[local a={}local function b(c)if type(c)~='table'then return type(c)end;local d=1;for e in pairs(c)do if c[d]~=nil then d=d+1 else return'table'end end;if d==1 then return'table'else return'array'end end;local function f(g)local h={'\\','"','/','\b','\f','\n','\r','\t'}local i={'\\','"','/','b','f','n','r','t'}for d,j in ipairs(h)do g=g:gsub(j,'\\'..i[d])end;return g end;local function k(l,m,n,o)m=m+#l:match('^%s*',m)if l:sub(m,m)~=n then if o then error('Expected '..n..' near position '..m)end;return m,false end;return m+1,true end;local function p(l,m,q)q=q or''local r='End of input found while parsing string.'if m>#l then error(r)end;local j=l:sub(m,m)if j=='"'then return q,m+1 end;if j~='\\'then return p(l,m+1,q..j)end;local s={b='\b',f='\f',n='\n',r='\r',t='\t'}local t=l:sub(m+1,m+1)if not t then error(r)end;return p(l,m+2,q..(s[t]or t))end;local function u(l,m)local v=l:match('^-?%d+%.?%d*[eE]?[+-]?%d*',m)local q=tonumber(v)if not q then error('Error parsing number at position '..m..'.')end;return q,m+#v end;function a.stringify(c,w)local g={}local x=b(c)if x=='array'then if w then error('Can\'t encode array as key.')end;g[#g+1]='['for d,q in ipairs(c)do if d>1 then g[#g+1]=', 'end;g[#g+1]=a.stringify(q)end;g[#g+1]=']'elseif x=='table'then if w then error('Can\'t encode table as key.')end;g[#g+1]='{'for y,z in pairs(c)do if#g>1 then g[#g+1]=', 'end;g[#g+1]=a.stringify(y,true)g[#g+1]=':'g[#g+1]=a.stringify(z)end;g[#g+1]='}'elseif x=='string'then return'"'..f(c)..'"'elseif x=='number'then if w then return'"'..tostring(c)..'"'end;return tostring(c)elseif x=='boolean'then return tostring(c)elseif x=='nil'then return'null'else error('Unjsonifiable type: '..x..'.')end;return table.concat(g)end;a.null={}function a.parse(l,m,A)m=m or 1;if m>#l then error('Reached unexpected end of input.')end;local m=m+#l:match('^%s*',m)local B=l:sub(m,m)if B=='{'then local c,C,D={},true,true;m=m+1;while true do C,m=a.parse(l,m,'}')if C==nil then return c,m end;if not D then error('Comma missing between object items.')end;m=k(l,m,':',true)c[C],m=a.parse(l,m)m,D=k(l,m,',')end elseif B=='['then local E,q,D={},true,true;m=m+1;while true do q,m=a.parse(l,m,']')if q==nil then return E,m end;if not D then error('Comma missing between array items.')end;E[#E+1]=q;m,D=k(l,m,',')end elseif B=='"'then return p(l,m+1)elseif B=='-'or B:match('%d')then return u(l,m)elseif B==A then return nil,m+1 else local F={['true']=true,['false']=false,['null']=a.null}for G,H in pairs(F)do local I=m+#G-1;if l:sub(m,I)==G then return H,I+1 end end;local J='position '..m..': '..l:sub(m,m+10)error('Invalid json syntax starting at '..J)end end;return a]])()

if not files['default/T.dat'] then
	file_Write(dir..'default/T.dat', '')
	file_Write(dir..'default/CT.dat', '')
end

http_Get(git..dir..'master/skins.txt', function(cnt)
	local p = json.parse(cnt)

	-- Setup weapon tables
	for l in p.item_names:gmatch('([^\n]*)\n')do local n,a=l:match('([^\n]*)='),l:gsub('([^\n]*)=','')weapons[n]=a _weapons[a]=n weapon_keys[#weapon_keys+1]=n end

	-- Setup skin tables
	local s,t,N=p.paintkit_names,{},0
	for k,v in pairs(p.weapon_skins)do local r=tonumber(k)if not t[r]then t[r]={}end for _,b in pairs(v)do table_insert(t[r],s[b]..'='..b)end end
	local s=''for i=1,#t do s=s..table_concat(t[i],',')..',\n'end
	for l in s:gmatch('([^\n]*)\n')do skin_keys[N],skins[N]={},{}for o in l:gmatch('([^,]*),')do local n,b=o:match('([^=]*)='),o:gsub('([^=]*)=','')table_insert(skins[N],{n,b})table_insert(skin_keys[N],n)_skins[b]=n end N=N+1 end

	__init__()
end)