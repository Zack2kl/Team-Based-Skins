local callbacks_Register, client_AllowListener, client_Command, common_Time, file_Read, file_Write, gui_Checkbox, gui_Command, gui_GetValue, gui_Groupbox, gui_Listbox, gui_Multibox, gui_Reference, gui_Slider, http_Get, loadstring, math_random, math_randomseed, unpack, tostring, pcall = callbacks.Register, client.AllowListener, client.Command, common.Time, file.Read, file.Write, gui.Checkbox, gui.Command, gui.GetValue, gui.Groupbox, gui.Listbox, gui.Multibox, gui.Reference, gui.Slider, http.Get, loadstring, math.random, math.randomseed, unpack, tostring, pcall

local weapons, weapon_keys, skins, json do
	local n = {'json.txt', 'skins.txt'}

	for i=1, 2 do
		n[i+2] = http_Get('https://raw.githubusercontent.com/Zack2kl/Team-Based-Skins/master/'..n[i])
	end

	json = loadstring(n[3])()
	local parsed = json.parse(n[4])
	weapons, weapon_keys, skins = {}, {}, {}

	local o, a = parsed.weapon_keys['1'], parsed.weapon_keys['2']
	local i = 0

	repeat
		local FullName = o[i]
		local item_name = a[i]

		if FullName then
			weapons[FullName] = item_name
			weapon_keys[i] = FullName
		end

		i = i + 1
	until o[i] == nil

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

		local n, last = 0, 1
		repeat
			local SkinName = wep_skins[n + 1]
			local skin_name = wep_skins[n + 2]

			if SkinName and skin_name then
				skins[wep_index][last] = skin_name
				last = last + 1
			end

			n = n + 2
		until wep_skins[n] == nil
	end
end

local ref = gui_Reference('Visuals', 'Skins')
local group = gui_Groupbox(ref, 'Randomize Skins')
	group:SetPosX(16) group:SetPosY(824)

local enable = gui_Checkbox(ref, 'random.enable', '', 0)
	enable:SetPosX(590) enable:SetPosY(836)

local opts = {}
local opts_l = {}
local list = gui_Listbox(group, 'random.to_randomize', 200, '')
	list:SetPosY( 0 )
	list:SetWidth( 200 )

local function set_visible(tbl, v)
	for i=1, #tbl do
		tbl[i]:SetInvisible(not v)
	end
end

local function get_vals(tbl, s)
	local t, n = {},1
	for i=(s and 2 or 1), #tbl do
		t[n] = tbl[i]:GetValue()
		n = n + 1
	end
	return t
end

local function set_vals(tbl, vals)
	for i=1, #tbl do
		tbl[i]:SetValue(vals[i])
	end
end

local function set_disabled(tbl, v)
	for i=1, #tbl do
		tbl[i]:SetDisabled(v)
	end
end

local function m_random(...)
	local seed = math_random(common_Time() * 1000)
	math_randomseed( seed )
	return math_random(...)
end

for i, v in next, weapon_keys do
	if v == 'Bayonet' then
		break
	end

	opts_l[i] = v
	opts[i] = {
		gui_Checkbox(group, '', 'Random on '.. v, 0),
		gui_Checkbox(group, '', 'Random Skin', 0),
		gui_Checkbox(group, '', 'Random Wear', 0),
		gui_Checkbox(group, '', 'Random Seed', 0),
		gui_Checkbox(group, '', 'Random Stattrak', 0)
	}

	set_visible(opts[i], false)
	local last = 0
	for a=1, 5 do
		opts[i][a]:SetPosX(216)
		opts[i][a]:SetPosY(last)
		last = a * 34
	end
end

list:SetOptions( unpack(opts_l) )
local multi_1 = gui_Multibox(group, 'Knife Options')
	multi_1:SetPosX(400) multi_1:SetPosY(0) multi_1:SetWidth(176)

local on_knife = {
	gui_Checkbox(multi_1, '', 'Enable Random Knife', 0),
	gui_Checkbox(multi_1, '', 'Random Skin', 0),
	gui_Checkbox(multi_1, '', 'Random Wear', 0),
	gui_Checkbox(multi_1, '', 'Random Seed', 0),
	gui_Checkbox(multi_1, '', 'Random Stattrak', 0)
}

local multi_2 = gui_Multibox(group, 'Gloves Options')
	multi_2:SetPosX(400) multi_2:SetPosY(56) multi_2:SetWidth(176)
local on_glove = {
	gui_Checkbox(multi_2, '', 'Enable Random Gloves', 0),
	gui_Checkbox(multi_2, '', 'Random Skin', 0),
	gui_Checkbox(multi_2, '', 'Random Wear', 0),
	gui_Checkbox(multi_2, '', 'Random Seed', 0)
}

local on_agent = gui_Checkbox(group, '', 'Random Agent Models', 0)
	on_agent:SetPosX(400) on_agent:SetPosY(112)

local min_wear = gui_Slider(group, 'random.min_wear', 'Best Wear', 1, 0, 1, 0.001 )
local max_wear = gui_Slider(group, 'random.max_wear', 'Worst Wear', 0, 0, 1, 0.001 )
	min_wear:SetDescription('0 is factory-new.') min_wear:SetPosX(216) min_wear:SetPosY(166) min_wear:SetWidth(180)
	max_wear:SetDescription('1 is battle-scarred.') max_wear:SetPosX(400) max_wear:SetPosY(166) max_wear:SetWidth(180)


local function get_wear()
	local a = min_wear:GetValue() * 1000
	local b = max_wear:GetValue() * 1000
	return m_random( b, a ) / 1000
end

local last_val, last_global, last_global2, last_w, last_k
local function to_update()
	local global = gui_GetValue('esp.skins.enabled')
	local global_2 = enable:GetValue()

	if global ~= last_global or global_2 ~= last_global2 then
		group:SetDisabled( not global or not global_2 )
		last_global = global
	end

	local val = list:GetValue() + 1
	local w = opts[val][1]:GetValue() and 1 or 0
	local k = on_knife[1]:GetValue()

	if last_val ~= val then
		if last_val then
			set_visible(opts[last_val], false)
		end

		set_visible(opts[val], true)
		last_val = val
	end

	if last_w ~= val .. w then
		set_disabled({unpack(opts[val],2)}, w == 0)
		last_w = val .. w
	end
end

local function add_skin(index, tbl, vanilla)
	local actual_wep = weapon_keys[index]
	local weapon_wep = weapons[actual_wep]
	local ii = tostring(index - 1)

	local vals = get_vals(tbl, true)
	local random_skin, random_wear, random_seed, random_stat = unpack(vals)

	local ss = vanilla == 1 and 0 or 1
	local a = skins[ii]
	local r = m_random(ss, #skins[ii])
	local s = a[r] or ''

	local str = ('skin.add "%s" "%s" "%s" "%s" "%s" ""'):format(
		weapon_wep,
		random_skin and s or '',
		random_wear and get_wear() or '',
		random_seed and m_random(0, 1000) or '',
		random_stat and m_random(0, 10000) or ''
	)

	gui_Command(str)
end

local function on_event(e)
	if not last_global then
		return
	end

	if not enable:GetValue() or e:GetName() ~= 'round_prestart' then
		return
	end

	gui_Command('skin.clear')

	for i=1, #opts do
		local el = opts[i]

		if el[1]:GetValue() then
			add_skin(i, el)
		end
	end

	if on_knife[1]:GetValue() then
		add_skin(m_random(35, 53), on_knife, 1)
	end

	if on_glove[1]:GetValue() then
		add_skin(m_random(54, 60), on_glove)
	end

	if on_agent:GetValue() then
		local name = weapon_keys[ m_random(61, 101) ]
		gui_Command( ('skin.add "%s"'):format(weapons[name]) )
	end

	client_Command('cl_fullupdate', true)
end

client_AllowListener('round_prestart')
callbacks_Register('FireGameEvent', on_event)
callbacks_Register('Draw', to_update)

local data = ''
if pcall(function() data = file_Read('random_skin_options.dat') end) then
	local options = json.parse(data)

	for i=1, #options[1] do
		set_vals(opts[i], options[1][i])
	end

	set_vals(on_knife, options[2])
	set_vals(on_glove, options[3])
	on_agent:SetValue(options[4])
	min_wear:SetValue(options[5])
	max_wear:SetValue(options[6])
end

callbacks_Register('Unload', function()
	local options = {{}, {}, {}, false, 1, 0}

	for i=1, #opts do
		options[1][i] = get_vals(opts[i])
	end

	options[2] = get_vals(on_knife)
	options[3] = get_vals(on_glove)
	options[4] = on_agent:GetValue()
	options[5] = min_wear:GetValue()
	options[6] = max_wear:GetValue()

	file_Write( 'random_skin_options.dat', json.stringify(options) )
end)
