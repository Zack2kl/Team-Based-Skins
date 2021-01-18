local weapons, weapon_keys, skins, JSON = {}, {}, {} do
	local n = {'json.txt', 'skins.txt'}
	for i=1,2 do n[i+2]=http.Get('https://raw.githubusercontent.com/Zack2kl/Team-Based-Skins/master/'..n[i])end

	JSON = loadstring(n[3])()
	local parsed = JSON.parse(n[4])

	-- Setup weapon tables
	for l in parsed.item_names:gmatch('([^\n]*)\n')do local n,a=l:match('([^\n]*)='),l:gsub('([^\n]*)=','')weapons[n]=a weapon_keys[#weapon_keys+1]=n end

	-- Setup skin tables
	local s,t,N=parsed.paintkit_names,{},0
	for k,v in pairs(parsed.weapon_skins)do local r=tonumber(k)if not t[r]then t[r]={}end for _,b in pairs(v)do table.insert(t[r],s[b]..'='..b)end end
	local s=''for i=1,#t do s=s..table.concat(t[i],',')..',\n'end
	for l in s:gmatch('([^\n]*)\n')do skins[N]={}for o in l:gmatch('([^,]*),')do local n,b=o:match('([^=]*)='),o:gsub('([^=]*)=','')table.insert(skins[N],{n,b})end N=N+1 end
end

local ref = gui.Reference('Visuals', 'Skins')
local group = gui.Groupbox(ref, 'Randomize Skins')
	group:SetPosX(16) group:SetPosY(528)

local enable = gui.Checkbox(ref, 'random.enable', '', 0)
	enable:SetPosX(590) enable:SetPosY(544)

local opts = {}
local opts_l = {}
local list = gui.Listbox(group, 'random.to_randomize', 200, '')
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

for i, v in next, weapon_keys do
	if v == 'Bayonet' then
		break
	end

	opts_l[i] = v
	opts[i] = {
		gui.Checkbox(group, '', 'Random on '.. v, 0),
		gui.Checkbox(group, '', 'Random Skin', 0),
		gui.Checkbox(group, '', 'Random Wear', 0),
		gui.Checkbox(group, '', 'Random Seed', 0),
		gui.Checkbox(group, '', 'Random Stattrak', 0)
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
local multi_1 = gui.Multibox(group, 'Knife Options')
	multi_1:SetPosX(400) multi_1:SetPosY(0) multi_1:SetWidth(176)

local on_knife = {
	gui.Checkbox(multi_1, '', 'Enable Random Knife', 0),
	gui.Checkbox(multi_1, '', 'Random Skin', 0),
	gui.Checkbox(multi_1, '', 'Random Wear', 0),
	gui.Checkbox(multi_1, '', 'Random Seed', 0),
	gui.Checkbox(multi_1, '', 'Random Stattrak', 0)
}

local multi_2 = gui.Multibox(group, 'Gloves Options')
	multi_2:SetPosX(400) multi_2:SetPosY(56) multi_2:SetWidth(176)
local on_glove = {
	gui.Checkbox(multi_2, '', 'Enable Random Gloves', 0),
	gui.Checkbox(multi_2, '', 'Random Skin', 0),
	gui.Checkbox(multi_2, '', 'Random Wear', 0),
	gui.Checkbox(multi_2, '', 'Random Seed', 0)
}

local on_agent = gui.Checkbox(group, '', 'Random Agent Models', 0)
	on_agent:SetPosX(400) on_agent:SetPosY(112)

local min_wear = gui.Slider(group, 'random.min_wear', 'Best Wear', 1, 0, 1, 0.001 )
local max_wear = gui.Slider(group, 'random.max_wear', 'Worst Wear', 0, 0, 1, 0.001 )
	min_wear:SetDescription('0 is factory-new.') min_wear:SetPosX(216) min_wear:SetPosY(166) min_wear:SetWidth(180)
	max_wear:SetDescription('1 is battle-scarred.') max_wear:SetPosX(400) max_wear:SetPosY(166) max_wear:SetWidth(180)


local function get_wear()
	local a = min_wear:GetValue() * 1000
	local b = max_wear:GetValue() * 1000
	return math.random( b, a ) / 1000
end

local last_val, last_global, last_global2, last_w, last_k
local function to_update()
	local global = gui.GetValue('esp.skins.enable')
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

	local vals = get_vals(tbl, true)
	local random_skin, random_wear, random_seed, random_stat = unpack(vals)

	local ss = vanilla == 1 and 0 or 1
	local a = skins[index - 1]
	local r = math.random(ss, #skins[index-1])
	local s = a[r] and a[r][2]

	local str = ('skin.add "%s" "%s" "%s" "%s" "%s" ""'):format(
		weapon_wep,
		random_skin and s or '',
		random_wear and get_wear() or '',
		random_seed and math.random(0, 1000) or '',
		random_stat and math.random(0, 10000) or ''
	)

	gui.Command(str)
end

local function on_event(e)
	if not last_global then
		return
	end

	if not enable:GetValue() or e:GetName() ~= 'round_prestart' then
		return
	end

	gui.Command('skin.clear')

	for i=1, #opts do
		local el = opts[i]

		if el[1]:GetValue() then
			add_skin(i, el)
		end
	end

	if on_knife[1]:GetValue() then
		add_skin(math.random(35, 53), on_knife, 1)
	end

	if on_glove[1]:GetValue() then
		add_skin(math.random(54, 60), on_glove)
	end

	if on_agent:GetValue() then
		local name = weapon_keys[ math.random(61, 101) ]
		gui.Command( ('skin.add "%s"'):format(weapons[name]) )
	end

	client.Command('cl_fullupdate', true)
end

client.AllowListener('round_prestart')
callbacks.Register('FireGameEvent', on_event)
callbacks.Register('Draw', to_update)

local data = ''
if pcall(function() data = file.Read('random_skin_options.dat') end) then
	local options = JSON.parse(data)

	for i=1, #options[1] do
		set_vals(opts[i], options[1][i])
	end

	set_vals(on_knife, options[2])
	set_vals(on_glove, options[3])
	on_agent:SetValue(options[4])
	min_wear:SetValue(options[5])
	max_wear:SetValue(options[6])
end

callbacks.Register('Unload', function()
	local options = {{}, {}, {}, false, 1, 0}

	for i=1, #opts do
		options[1][i] = get_vals(opts[i])
	end

	options[2] = get_vals(on_knife)
	options[3] = get_vals(on_glove)
	options[4] = on_agent:GetValue()
	options[5] = min_wear:GetValue()
	options[6] = max_wear:GetValue()

	file.Write( 'random_skin_options.dat', JSON.stringify(options) )
end)