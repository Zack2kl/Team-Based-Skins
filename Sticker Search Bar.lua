local sticker_keys = {} do
	local n = {'json.txt', 'skins.txt'}

	for i=1, 2 do
		n[i+2] = http.Get('https://raw.githubusercontent.com/Zack2kl/Team-Based-Skins/master/'..n[i])
	end

	local json = loadstring(n[3])()
	local parsed = json.parse(n[4])
	local o = parsed.sticker_keys['1']
	local i = 1

	while o[i] do
		sticker_keys[i] = o[i]
		i = i + 1
	end
end

local sticker_positions = {'A', 'B', 'C', 'D', 'E'}
local selected_stickers = {}
local sticker_refs = {}

local ref = gui.Reference('Visuals', 'Skins', 'Configuration')
local sticker_pos = gui.Combobox(ref, '', 'Sticker Position', 'A', 'B', 'C', 'D', 'E')
local sticker_search = gui.Editbox(ref, '', 'Sticker Search Bar')
local group = gui.Groupbox(gui.Reference('Visuals', 'Skins'), 'Stickers Selected', 16, 656, 296, 296)

for i=1, 5 do
	sticker_refs[i] = gui.Reference('Visuals', 'Skins', 'Configuration', 'Sticker ' .. sticker_positions[i])
	sticker_refs[i]:SetInvisible(true)

	selected_stickers[i] = gui.Text(group, sticker_positions[i] .. ') ' .. sticker_refs[i]:GetString())
end

local sticker_list = gui.Listbox(ref, '', 200)
sticker_list:SetOptions( unpack(sticker_keys) )

local temp_sticker_list, last_search, last_sticker_list = {}
local function update()
	group:SetDisabled( not gui.GetValue('esp.skins.enabled') )

	local search = sticker_search:GetString()

	if search ~= last_search then
		local s = search:lower()
		local results = {}
		local keywords = {}

		if #s ~= 0 then
			for word in s:gmatch('([^%s]+)') do
				keywords[#keywords + 1] = word
					:gsub('%%', '%%%%')
					:gsub('^%^', '%%^')
					:gsub('%$$', '%%$')
					:gsub('%(', '%%(')
					:gsub('%)', '%%)')
					:gsub('%.', '%%.')
					:gsub('%[', '%%[')
					:gsub('%]', '%%]')
					:gsub('%*', '%%*')
					:gsub('%+', '%%+')
					:gsub('%-', '%%-')
					:gsub('%?', '%%?')
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
			sticker_refs[sticker_sel]:SetString(_sticker_)
			selected_stickers[sticker_sel]:SetText(sticker_positions[sticker_sel] .. ') ' .. _sticker_)
		end

		last_sticker_list = sticker_l
	end
end

callbacks.Register('Draw', update)
callbacks.Register('Unload', function()
	table.foreachi(sticker_refs, function(k, v)
		v:SetInvisible(false)
	end)
end)

collectgarbage('collect')