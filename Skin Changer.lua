local callbacks_Register, callbacks_Unregister, client_AllowListener, client_GetLocalPlayerIndex, client_GetPlayerIndexByUserID, client_GetPlayerInfo, debug_getmetatable, entities_GetLocalPlayer, error, gui_Button, gui_Checkbox, gui_Combobox, gui_Editbox, gui_Groupbox, gui_Listbox, gui_Reference, gui_Tab, gui_Text, mem_FindPattern, type, print, table_concat, tonumber, tostring, unpack, string_format, table_insert, table_sort, math_floor, pcall, pairs, ipairs = 
	  callbacks.Register, callbacks.Unregister, client.AllowListener, client.GetLocalPlayerIndex, client.GetPlayerIndexByUserID, client.GetPlayerInfo, debug.getmetatable, entities.GetLocalPlayer, error, gui.Button, gui.Checkbox, gui.Combobox, gui.Editbox, gui.Groupbox, gui.Listbox, gui.Reference, gui.Tab, gui.Text, mem.FindPattern, type, print, table.concat, tonumber, tostring, unpack, string.format, table.insert, table.sort, math.floor, pcall, pairs, ipairs

local FFI = (function()
	local ffi_cast, ffi_typeof, ffi_new, ffi_string, ffi_C, ffi_NULL, ffi_sizeof, ffi_cdef, ffi_copy = ffi.cast, ffi.typeof, ffi.new, ffi.string, ffi.C, ffi.NULL, ffi.sizeof, ffi.cdef, ffi.copy
	local voidppp 	= ffi_typeof('void***')
	local voidp 	= ffi_typeof('void*')
	local charp 	= ffi_typeof('char*')
	local intp 		= ffi_typeof('int*')
	local floatp 	= ffi_typeof('float*')

	if not pcall(function() return ffi_C.GetProcAddress end) then
		ffi_cdef('void* GetProcAddress(void*, const char*);')
	end

	if not pcall(function() return ffi_C.GetModuleHandleA end) then
		ffi_cdef('void* GetModuleHandleA(const char*);')
	end

	local PaintKits = {}
	local WeaponKits = {}
	local ItemInfo = {}
	local Interfaces = {}
	local FFI = {}

	FFI.CreateInterface = function(mod, name)
		-- Credit: Stacky
		if Interfaces[name] then
			return Interfaces[name]
		end

		local modHandle = ffi_C.GetModuleHandleA(mod)
			if modHandle == ffi_NULL then error(mod .. ' was not found!', 2)end
		local create = ffi_C.GetProcAddress(modHandle, "CreateInterface")
			if create == ffi_NULL then error('CreateInterface was not found in ' .. mod, 2)end
		local CInterface = [[
			struct {
				void*(__thiscall *Get)();
				char* Name;
				void* Next;
			}
		]]

		local pCreateInterface = ffi_cast("int", create)
		local interface = ffi_cast(CInterface..'***', pCreateInterface + ffi_cast(intp, pCreateInterface + 5)[0] + 15)[0][0]

		while interface ~= ffi_NULL do
			if ffi_string(interface.Name) == name then
				local f = interface.Get()
				Interfaces[name] = f
				return f
			end

			interface = ffi_cast(CInterface..'*', interface.Next)
		end

		error('Failed to find interface "'.. name ..'"', 2)
	end

	-- Credit: Sapphyrus
	local function get_call_target(ptr)
		local insn = ffi_cast("uint8_t*", ptr)

		if insn[0] == 0xE8 then -- relative, displacement relative to next instruction
			local offset = ffi_cast("uint32_t*", insn + 1)[0]
			return insn + offset + 5
		elseif insn[0] == 0xFF and insn[1] == 0x15 then -- absolute
			local call_addr = ffi_cast("uint32_t**", ffi_cast("const char*", ptr)+2)
			return call_addr[0][0]
		else
			error("unknown instruction!")
		end
	end

	local String_t = [[
		struct {
			char* buffer;
			int capacity;
			int grow_size;
			int length;
		}
	]]

	local CPaintKit_t = [[
		struct {
			int index;
			]].. String_t ..[[ name;
			]].. String_t ..[[ desc;
			]].. String_t ..[[ tag;
		}
	]]

	local native_GetItemSchemaPointer = ffi_cast("intptr_t(__stdcall*)()", mem_FindPattern("client.dll", "A1 ?? ?? ?? ?? 85 C0 75 53"))
	local native_GetPaintKitDefinitionPointer = ffi_cast(CPaintKit_t.."*(__thiscall*)(void*, int)", get_call_target(mem_FindPattern("client.dll", "E8 ?? ?? ?? ?? 8B F0 8B 4E 7C")))

	FFI.GetPaintKit = function(index)--index of skin (or console_name for later use)
		if PaintKits[index] then
			return PaintKits[index]
		else
			if index == nil or type(index) == 'string' then
				return
			end
		end

		local item_schema = native_GetItemSchemaPointer()
		if item_schema == 0 then
			return
		end

		local this = ffi_cast(voidp, item_schema + 4)
		local paint_kit = native_GetPaintKitDefinitionPointer(this, index)

		if paint_kit ~= ffi_NULL then
			local info = {
				index = paint_kit.index,
				console_name = ffi_string(paint_kit.name.buffer, paint_kit.name.length - 1),
				name = FFI.Localize(paint_kit.tag.buffer)
			}

			PaintKits[info.console_name] = info
			return info
		end
	end

	FFI.VMT = (function()
		local entry = function(ins, i, c)
			return ffi_cast(c, ffi_cast(voidppp, ins)[0][i])
		end

		local bind = function(mod, name, i, c)
			local ins = FFI.CreateInterface(mod, name)
			local t = ffi_typeof(c)
			local fn = entry(ins, i, t)

			return function(...)
				return fn(ins, ...)
			end
		end

		local thunk = function(i, c)
			local t = ffi_typeof(c)

			return function(ins, ...)
				return entry(ins, i, t)(ins, ...)
			end
		end

		return {entry=entry, bind=bind, thunk=thunk}
	end)()

	FFI.Hook = (function()
		assert(mem.GetModuleBase('gameoverlayrenderer.dll') ~= nil, 'gameoverlayrenderer.dll not found, do you have GameOverlay enabled?')

		local sig = '55 8B EC 64 A1 ?? ?? ?? ?? 6A FF 68 ?? ?? ?? ?? 50 64 89 25 ?? ?? ?? ?? 81 EC '
		local Unhook_match = mem_FindPattern("gameoverlayrenderer.dll", sig .. "?? ?? ?? ?? 56 8B 75") or error("UnhookFunc could not be found.")
		local Hook_match = mem_FindPattern("gameoverlayrenderer.dll", sig .. "?? ?? ?? ?? 53 8B 5D") or error("HookFunc could not be found.")
		local Unhook_fn = ffi_cast('void(__cdecl*)(void*, bool bLog)', Unhook_match)
		local Hook_fn = ffi_cast('int(__cdecl*)(void*, void*, uintptr_t*, int*, int)', Hook_match)
		local trampoline_t, success_t = ffi_typeof('uintptr_t[1]'), ffi_typeof('int[1]')

		return function(typestring, real_address, new_function)
			local real_function = ffi_cast(typestring, real_address)
			local hook_function = ffi_cast(typestring, new_function)
			local trampoline, success = trampoline_t(), success_t()
			local hook = {
				started = false,
				trampoline = function() error('This should not be seen.', 2) end
			}

			function hook.start()
				if not hook.started and Hook_fn(real_function, hook_function, trampoline, success, 0) ~= 0 then
					hook.trampoline = ffi_cast(typestring, trampoline[0])
					hook.started = true
				end
			end

			function hook.stop(self)
				if hook.started then
					Unhook_fn(real_function, false)
					hook.started = false
				end
			end

			return setmetatable({ start=hook.start, stop=hook.stop }, {
				__call = function(self, ...)
					return hook.trampoline(...)
				end
			})
		end
	end)()

	FFI.InitPostDataUpdateHook = function(callback)
		local iface = FFI.CreateInterface('client.dll', 'VClient018')
		local vtbl = ffi_cast(voidppp, iface)[0]--cast iface to class pointer then dereference to vtbl
		local hook = nil;

		hook = FFI.Hook('void(__stdcall*)(int)', vtbl[37], function(stage)
			callback(stage)
			return hook(stage)
		end)

		hook.start()
		callbacks_Register('Unload', hook.stop)
	end

	FFI.FileSystemEnumerate = (function()
		local find_next = FFI.VMT.bind("filesystem_stdio.dll", "VFileSystem017", 33, 'const char*(__thiscall*)(void*, int)')
		local find_close = FFI.VMT.bind("filesystem_stdio.dll", "VFileSystem017", 35, 'void(__thiscall*)(void*, int)')
		local find_first_ex = FFI.VMT.bind("filesystem_stdio.dll", "VFileSystem017", 36, 'const char*(__thiscall*)(void*, const char*, const char*, int*)')

		local function findFirstEx(path, path_id)
			local handle = ffi_new("int[1]")
			local file = find_first_ex(path, path_id, handle)

			if file ~= ffi_NULL then
				return handle, ffi_string(file)
			end
		end

		local function findNext(handle)
			local file = find_next(handle)

			if file ~= ffi_NULL then
				return ffi_string(file)
			end
		end

		local function findEnumerate(path)
			local fileHandle, fileNamePtr = findFirstEx(path, 'GAME')
			if fileHandle == nil then
				return {}
			end

			local found = {}
			while fileNamePtr ~= nil do
				found[#found + 1] = ffi_string(fileNamePtr)
				fileNamePtr = findNext(fileHandle[0])
			end

			find_close(fileHandle[0])
			return found;
		end

		return findEnumerate
	end)()

	FFI.Localize = (function()
		local native_findAsUTF8 = FFI.VMT.bind('localize.dll', 'Localize_001', 47, 'const char*(__thiscall*)(void*, const char*)')

		return function(str)
			local utf = native_findAsUTF8(str)
			return utf ~= ffi_NULL and ffi_string(utf) or ''
		end
	end)()

	FFI.GetWeaponKits = function(weapon_name)
		if not weapon_name or weapon_name == '' then
			return {}
		end

		if WeaponKits[weapon_name] then
			return WeaponKits[weapon_name]
		end

		--('resource/flash/econ/default_generated/weapon_ak47_*')
		local files = FFI.FileSystemEnumerate('resource/flash/econ/default_generated/'.. weapon_name ..'_*')
		local list = {}
		local last = ''
		local n = 1

		for i=1, #files do
			local skin = files[i]
				:gsub('^'..weapon_name ..'_', '')
				:gsub('.png$', '')
				:gsub('_large$', '')
				:gsub('_light$', '')
				:gsub('_medium$', '')
				:gsub('_heavy$', '')

			if skin:find('silencer_') then
				goto continue
			end

			if skin ~= last then
				for console_name in pairs(PaintKits) do
					if console_name:find(skin) then
						local r = console_name:reverse()
						local s = skin:reverse()
						local at = s:find(r)

						if at then
							skin = s:sub(at, -1):reverse()
							list[n] = skin
							n = n + 1
							last = skin
							break
						end
					end
				end
			end

			::continue::
		end

		WeaponKits[weapon_name] = list
		return list
	end

	local native_GetItemDefinitionInterface = FFI.VMT.thunk(4, 'intptr_t(__thiscall*)(void*, int)')
	local native_GetItemDefinitionByName = FFI.VMT.thunk(42, 'intptr_t(__thiscall*)(void*, const char*)')
		local native_getWeaponIndex = FFI.VMT.thunk(0, 'int(__thiscall*)(void*)')
		local native_getItemBaseNameTag = FFI.VMT.thunk(2, 'const char*(__thiscall*)(void*)')
		local native_getItemTypeNameTag = FFI.VMT.thunk(3, 'const char*(__thiscall*)(void*)')
		local native_getItemDescriptionTag = FFI.VMT.thunk(4, 'const char*(__thiscall*)(void*)')
		local native_getInventoryImage = FFI.VMT.thunk(5, 'const char*(__thiscall*)(void*)')
		local native_getPlayerDisplayModel = FFI.VMT.thunk(6, 'const char*(__thiscall*)(void*)')
		local native_getWorldDisplayModel = FFI.VMT.thunk(7, 'const char*(__thiscall*)(void*)')
		local native_getRarity = FFI.VMT.thunk(12, 'uint8_t(__thiscall*)(void*)')
		local native_getNumberOfSupportedStickerSlots = FFI.VMT.thunk(44, 'int(__thiscall*)(void*)')

	FFI.GetItemInfo = function(item)
		if ItemInfo[item] then
			return ItemInfo[item]
		end

		local item_schema = native_GetItemSchemaPointer()
		if item_schema == 0 then
			return {}
		end

		local this = ffi_cast(voidp, item_schema + 4)
		local item_iface = 0
		local info = {}

		if type(item) == 'number' then
			item_iface = native_GetItemDefinitionInterface(this, item)
		elseif type(item) == 'string' then
			item_iface = native_GetItemDefinitionByName(this, item)
		end

		if item_iface ~= 0 then
			local ptr = ffi_cast(voidp, item_iface);--EconItemDefinition*
				local playerDisplayModel = native_getPlayerDisplayModel(ptr)
				local worldDisplayModel = native_getWorldDisplayModel(ptr)
				local inventoryImage = native_getInventoryImage(ptr)
				local descriptionTag = native_getItemDescriptionTag(ptr)

			info.index = native_getWeaponIndex(ptr)
			info.name = FFI.Localize(native_getItemBaseNameTag(ptr))
			info.type = FFI.Localize(native_getItemTypeNameTag(ptr))
			info.rarity = native_getRarity(ptr)
			info.numberOfSupportedStickerSlots = native_getNumberOfSupportedStickerSlots(ptr)

			info.descTag = descriptionTag ~= ffi_NULL and ffi_string(descriptionTag) or ''
			info.image = inventoryImage ~= ffi_NULL and ffi_string(inventoryImage) or ''
			info.player_model = playerDisplayModel ~= ffi_NULL and ffi_string(playerDisplayModel) or ''
			info.world_model = worldDisplayModel ~= ffi_NULL and ffi_string(worldDisplayModel) or ''
			info.type2 = (
				info.type == 'Pistol' or info.type == 'Rifle' or 
				info.type == 'Sniper Rifle' or info.type == 'Machinegun' or
				info.type == 'SMG' or info.type == 'Shotgun'
			) and 'Weapon' or info.type

			ItemInfo[item] = info
		end

		return info
	end

	FFI.FullUpdate = (function()
		local match = mem_FindPattern('engine.dll', 'A1 ?? ?? ?? ?? B9 ?? ?? ?? ?? 56 FF 50 14 8B 34 85') or print('FullUpdate not found. Setting delta manually.')

		if match then
			return ffi_cast('void(__cdecl*)()', match)
		else
			local engineDll = mem.GetModuleBase('engine.dll')
			local client_state = ffi_cast('intptr_t*', engineDll + 0x589FC4)

			return function()
				ffi_cast('int*', client_state[0] + 0x174)[0] = -1
			end
		end
	end)()

	FFI.UpdateHudIcons = (function()
		local find_hud_element = ffi.cast("intptr_t(__thiscall*)(void*, const char*)",
			mem_FindPattern("client.dll", "55 8B EC 53 8B 5D 08 56 57 8B F9 33 F6 39"))
		local this = ffi_cast("void**", mem_FindPattern("client.dll", "B9 ?? ?? ?? ?? E8 ?? ?? ?? ?? 8B 5D 08") + 1)[0]

		local hud = find_hud_element(this, 'CCSGO_HudWeaponSelection')
		local hud_this = ffi_cast(charp, hud - 0xA0)
		local wep_count = ffi_cast('int32_t*', hud_this + 0x80)
		local clear_f = ffi_cast('int32_t(__thiscall*)(void*, int32_t)',
			mem_FindPattern("client.dll", "55 8B EC 51 53 56 8B 75 08 8B D9 57 6B FE") or
			error('ClearHudWeaponIcon signature was not found.')
		)

		return function()
			for i=0, wep_count[0] - 1 do
				clear_f(hud_this, i)
			end
		end
	end)()

	FFI.ChangeWeaponPaintKit = (function()
		local get_client_entity = FFI.VMT.bind('client.dll', 'VClientEntityList003', 3, 'void*(__thiscall*)(void*, int)')
		local on_data_changed 	= FFI.VMT.thunk(5, 'void(__thiscall*)(void*, int)')
		local post_data_update 	= FFI.VMT.thunk(7, 'void(__thiscall*)(void*, int)')

		return function(PlayerEntity, WeaponEntity, data)
			local WeaponIndex = WeaponEntity:GetIndex()
			if not WeaponIndex then
				return
			end

			local PlayerIndex = PlayerEntity:GetIndex()
			if not PlayerIndex then
				return
			end

			local PlayerInfo = client_GetPlayerInfo(PlayerIndex)
			if not PlayerInfo then
				return
			end

			local ptr = ffi_cast(charp, get_client_entity(WeaponIndex))
			local m_OriginalOwnerXuidLow = ffi_cast(intp,  ptr + 0x31D0)
			if m_OriginalOwnerXuidLow[0] ~= PlayerInfo.SteamID then
				return
			end

			if data.item.type == 'Knife' then
				local m_iEntityQuality = ffi_cast(intp,  ptr + 0x2FBC)
				m_iEntityQuality[0] = 3
			end

			if data.stattrak > -1 then
				local m_iAccountID = ffi_cast(intp,  ptr + 0x2FD8)
				m_iAccountID[0] = PlayerInfo.SteamID
			end

			local m_iItemIDHigh 		= ffi_cast(intp,  ptr + 0x2FD0)
			local m_nFallbackStatTrak 	= ffi_cast(intp,  ptr + 0x31E4)
			local m_nFallbackPaintKit 	= ffi_cast(intp,  ptr + 0x31D8)
			local m_flFallbackWear 		= ffi_cast(floatp,ptr + 0x31E0)
			local m_nFallbackSeed 		= ffi_cast(intp,  ptr + 0x31DC)
			local m_szCustomName 		= ffi_cast(charp, ptr + 0x304C)

			m_iItemIDHigh[0] = -1
			m_nFallbackPaintKit[0] = data.skin.index
			m_nFallbackStatTrak[0] = data.stattrak
			m_flFallbackWear[0] = data.wear
			m_nFallbackSeed[0] = data.seed

			if data.name ~= '' and ffi_string(m_szCustomName) ~= data.name then
				ffi_copy(m_szCustomName, data.name)
			end

			post_data_update(ptr + 0x8, 0)
			on_data_changed(ptr + 0x8, 0)
		end
	end)()

	FFI.GatherItems = function()
		local inGame = {}
		local Other = {}

		-- Gather Weapons + Knives + Gloves + Agents
		for i=1, 22000 do--30000 do
			local item = FFI.GetItemInfo(i)

			if item.type2 == 'Weapon' then
				item.console_name = item.image:gsub('econ/weapons/base_weapons/', '')
				inGame[#inGame + 1] = item

			elseif item.type == 'Knife' then
				if item.rarity > 1 then
					item.console_name = item.image:gsub('econ/weapons/base_weapons/', '')
					inGame[#inGame + 1] = item
				end

			elseif item.type == 'Gloves' then
				if item.image == '' then
					item.console_name = item.descTag:sub(18):gsub('_Desc', '')

					if item.console_name == 'studdedgloves' then
						item.console_name = 'studded_bloodhound_gloves'
					elseif item.console_name:sub(-1) ~= 's' then
						item.console_name = item.console_name .. 's'
					end

					Other[#Other + 1] = item
				end

			elseif item.type == 'Agent' then
				if item.image ~= '' then
					item.console_name = item.image:gsub('econ/characters/', '')
					Other[#Other + 1] = item
				end
			end
		end

		local names, items, n = {}, {}, 1
		for i=1, #inGame do
			names[n] = inGame[i].name
			items[n] = inGame[i]
			n = n + 1
		end

		for i=1, #Other do
			names[n] = Other[i].name
			items[n] = Other[i]
			n = n + 1
		end

		return names, items
	end

	FFI.GatherSkins = function()
		local names, skins = {}, {}
		local n = 1

		for i=0, 12000 do
			local kit = FFI.GetPaintKit(i)

			if kit and i ~= 9001 then
				names[n] = kit.name
				skins[n] = kit
				n = n + 1
			end
		end

		return names, skins
	end

	FFI.Json = (function()
		--Credit: https://gist.github.com/tylerneylon/59f4bcf316be525b30ab

		local json = {null = {}}
		local in_char  = {'\\', '"', '/', '\b', '\f', '\n', '\r', '\t'}
		local out_char = {'\\', '"', '/',  'b',  'f',  'n',  'r',  't'}
		local esc_map = {b = '\b', f = '\f', n = '\n', r = '\r', t = '\t'}
		local literals = {['true'] = true, ['false'] = false, ['null'] = json.null}

		local function kind_of(obj)
			if type(obj) ~= 'table' then
				return type(obj)
			end

			local i = 1
			for _ in pairs(obj) do
				if obj[i] ~= nil then
					i = i + 1
				else
					return 'table'
				end
			end

			return i == 1 and 'table' or 'array'
		end

		local function escape_str(s)
			for i=1, #in_char do
				s = s:gsub(in_char[i], '\\' .. out_char[i])
			end

			return s
		end

		local function skip_delim(str, pos, delim, err_if_missing)
			pos = pos + #str:match('^%s*', pos)

			if str:sub(pos, pos) ~= delim then
				if err_if_missing then
					error('Expected ' .. delim .. ' near position ' .. pos)
				end

				return pos, false
			end

			return pos + 1, true
		end

		local function parse_str_val(str, pos, val)
			val = val or ''

			if pos > #str then
				error('End of input found while parsing string.')
			end

			local c = str:sub(pos, pos)
			if c == '"'  then
				return val, pos + 1
			end

			if c ~= '\\' then
				return parse_str_val(str, pos + 1, val .. c)
			end

			-- We must have a \ character.
			local nextc = str:sub(pos + 1, pos + 1)

			if not nextc then
				error('End of input found while parsing string.')
			end

			return parse_str_val(str, pos + 2, val .. (esc_map[nextc] or nextc))
		end

		local function parse_num_val(str, pos)
			local num_str = str:match('^-?%d+%.?%d*[eE]?[+-]?%d*', pos)
			local val = tonumber(num_str)

			if not val then
				error('Error parsing number at position ' .. pos .. '.')
			end

			return val, pos + #num_str
		end

		json.stringify = function(obj, as_key)
			local s = {}  -- We'll build the string as an array of strings to be concatenated.
			local kind = kind_of(obj)  -- This is 'array' if it's an array or type(obj) otherwise.

			if kind == 'array' then
				if as_key then
					error('Can\'t encode array as key.')
				end

				s[#s + 1] = '['
				for i=1, #obj do
					if i > 1 then
						s[#s + 1] = ', '
					end

					s[#s + 1] = json.stringify(obj[i])
				end
				s[#s + 1] = ']'

			elseif kind == 'table' then
				if as_key then
					error('Can\'t encode table as key.')
				end

				s[#s + 1] = '{'
				for k, v in pairs(obj) do
					if #s > 1 then
						s[#s + 1] = ', '
					end

					s[#s + 1] = json.stringify(k, true)
					s[#s + 1] = ':'
					s[#s + 1] = json.stringify(v)
				end
				s[#s + 1] = '}'

			elseif kind == 'string' then
				return '"' .. escape_str(obj) .. '"'

			elseif kind == 'number' then
				return as_key and ('"' .. tostring(obj) .. '"') or tostring(obj)

			elseif kind == 'boolean' then
				return tostring(obj)

			elseif kind == 'nil' then
				return 'null'

			else
				error('Unjsonifiable type: ' .. kind .. '.')
			end

			return table_concat(s)
		end

		json.parse = function(str, pos, end_delim)
			pos = pos or 1

			if pos > #str then
				error('Reached unexpected end of input.')
			end

			local pos = pos + #str:match('^%s*', pos)  -- Skip whitespace.
			local first = str:sub(pos, pos)

			if first == '{' then  -- Parse an object.
				local obj, key, delim_found = {}, true, true
				pos = pos + 1

				while true do
					key, pos = json.parse(str, pos, '}')

					if key == nil then
						return obj, pos
					end

					if not delim_found then
						error('Comma missing between object items.')
					end

					pos = skip_delim(str, pos, ':', true)  -- true -> error if missing.
					obj[key], pos = json.parse(str, pos)
					pos, delim_found = skip_delim(str, pos, ',')
				end

			elseif first == '[' then  -- Parse an array.
				local arr, val, delim_found = {}, true, true
				pos = pos + 1

				while true do
					val, pos = json.parse(str, pos, ']')

					if val == nil then
						return arr, pos
					end

					if not delim_found then
						error('Comma missing between array items.')
					end

					arr[#arr + 1] = val
					pos, delim_found = skip_delim(str, pos, ',')
				end

			elseif first == '"' then  -- Parse a string.
				return parse_str_val(str, pos + 1)

			elseif first == '-' or first:match('%d') then  -- Parse a number.
				return parse_num_val(str, pos)

			elseif first == end_delim then  -- End of an object or array.
				return nil, pos + 1

			else  -- Parse true, false, or null.
				for lit_str, lit_val in pairs(literals) do
					local lit_end = pos + #lit_str - 1

					if str:sub(pos, lit_end) == lit_str then
						return lit_val, lit_end + 1
					end
				end

				local pos_info_str = 'position ' .. pos .. ': ' .. str:sub(pos, pos + 10)
				error('Invalid json syntax starting at ' .. pos_info_str)
			end
		end

		return json
	end)()

	return FFI
end)();

local function SetupGuiMetatable(obj)
	local gui_mt = debug_getmetatable(obj)
	local gui_mt_index = gui_mt.__index

	return setmetatable({
		values = {},
		raw_values = {},
		backup_values = {},
		search_values = {},
		callback = nil,
	}, {
		__tostring = function()
			return gui_mt.__tostring(obj)
		end,
		__index = function(self, index)
			if index == 'values' or index == 'raw_values' or index == 'backup_values' or index == 'search_values' or index == 'callback' then
				return rawget(self, index)
			end

			return function(...)
				--GET
				if index == 'GetOptions' then
					return rawget(self, 'values')
				elseif index == 'GetRawOptions' then
					return rawget(self, 'raw_values')
				elseif index == 'GetBackupRaw' then
					return rawget(self, 'backup_values')
				elseif index == 'GetSearchRaw' then
					return rawget(self, 'search_values')
				end

				--SET
				local args = {...}-- args[1] is supposed to be obj but its 'this' table so dont use it
				if index == 'SetOptions' then
					if type(args[2]) == 'table' then
						rawset(self, 'values', args[2])
						return gui_mt_index(obj, index)(obj, unpack(args[2]))
					else
						rawset(self, 'values', {unpack(args, 2)})
						return gui_mt_index(obj, index)(obj, unpack(args, 2))
					end
				elseif index == 'SetRawOptions' then
					return rawset( self, 'raw_values', 	  type(args[2]) == 'table' and args[2] or {unpack(args, 2)} )
				elseif index == 'SetBackupRaw' then
					return rawset( self, 'backup_values', type(args[2]) == 'table' and args[2] or {unpack(args, 2)} )
				elseif index == 'SetSearchRaw' then
					return rawset( self, 'search_values', type(args[2]) == 'table' and args[2] or {unpack(args, 2)} )

				--CALLBACK
				elseif index == 'SetCallback' then
					if type(args[2]) ~= 'function' then
						error('Callback is not a function.', 2)
					end

					if rawget(self, 'callback') ~= nil then
						error('Callback is already set.', 2)
					end

					rawset(self, 'callback', args[2])
					local callback = args[2]
					local last, last2, last3, last4;

					local mainCallback = function(override)
						local v, v2, v3, v4 = obj:GetValue()

						if override or (last ~= v or last2 ~= v2 or last3 ~= v3 or last4 ~= v4) then
							last, last2, last3, last4 = v, v2, v3, v4
							return callback(v, v2, v3, v4)
						end
					end

					callbacks_Register('Draw', tostring(rawget(self, 'callback')), mainCallback)
					return mainCallback
				elseif index == 'UnsetCallback' then
					if rawget(self, 'callback') then
						callbacks_Unregister('Draw', tostring(rawget(self, 'callback')))
						rawset(self, 'callback', nil)
					end
					return
				end

				return gui_mt_index(obj, index)(obj, unpack(args, 2))
			end
		end
	})
end

local function guiCheckbox(...)return SetupGuiMetatable(gui_Checkbox(...))end
local function guiCombobox(...)return SetupGuiMetatable(gui_Combobox(...))end
local function guiEditbox(...) return SetupGuiMetatable( gui_Editbox(...))end
local function guiListbox(...) return SetupGuiMetatable( gui_Listbox(...))end
local GUI = {}

local UpdateHud = false
local UpdateIcons = false
local function AddItemIntoSkins(data)
	local w_skins = FFI.GetWeaponKits(data.item.console_name)
	local found_normal_skin = false

	for i=1, #w_skins do
		if w_skins[i] == data.skin.console_name then
			found_normal_skin = true
			break
		end
	end

	local s = ('skin.add "%s" "%s" "%s" "%s" "%s" "%s" "default" "default" "default" "default" "default"'):format(
		data.item.console_name,
		found_normal_skin and data.skin.console_name or '',
		data.wear,
		data.seed,
		data.stattrak,
		data.name
	)

	gui.Command(s)
end

local function PopulateAimwareSkins(team)
	if team ~= 'T' and team ~= 'CT' then
		local LP = entities_GetLocalPlayer()

		if LP then
			local team_num = LP:GetTeamNumber()
			if team_num == 2 or team_num == 3 then
				team = team_num == 2 and 'T' or 'CT'
			else
				return
			end
		else
			return
		end
	end

	local haveknife, haveglove, haveagent = false, false, false
	gui.Command('skin.clear')--Why doesn't this force update like pressing the "Add" or "Remove" button?

	for _, team in ipairs{team, 'Both'} do--Check ""team"" first then "Both" and add each item them into the list
		for k, v in pairs(GUI.Group3Item.List[team].raw_values) do
			if v.item.type == 'Knife' and not haveknife then
				AddItemIntoSkins(v)
				haveknife = true
			end

			if v.item.type == 'Gloves' and not haveglove then
				AddItemIntoSkins(v)
				haveglove = true
			end

			if v.item.type == 'Agent' and not haveagent then
				AddItemIntoSkins(v)
				haveagent = true
			end

			if v.item.type ~= 'Knife' and v.item.type ~= 'Gloves' and v.item.type ~= 'Agent' then
				AddItemIntoSkins(v)
			end
		end
	end

	UpdateHud = true
	UpdateIcons = true
end

local function SaveSettings()
	local settings = {
		Both = GUI.Group3Item.List.Both:GetRawOptions(),
		T 	 = GUI.Group3Item.List.T:GetRawOptions(),
		CT 	 = GUI.Group3Item.List.CT:GetRawOptions()
	}

	file.Write('SkinChanger/SkinConfig.dat', FFI.Json.stringify(settings))
end

local function LoadSettings()
	local success, settings = pcall(function()
		return file.Read('SkinChanger/SkinConfig.dat')
	end)

	if not success then
		settings = FFI.Json.stringify({Both={}, T={}, CT={}})
		file.Write('SkinChanger/SkinConfig.dat', settings)
	end

	local parsed = FFI.Json.parse(settings)
	for team, skin_data in pairs(parsed) do
		local temp = {}
		local n = 1

		for k, v in pairs(skin_data) do
			temp[n] = v.item.name .. ' - ' .. v.skin.name
			n = n + 1
		end

		GUI.Group3Item.List[team]:SetOptions(temp)
		GUI.Group3Item.List[team]:SetRawOptions(skin_data)
	end
end

FFI.InitPostDataUpdateHook(function(stage)
	if stage ~= 2 then --FRAME_NET_UPDATE_POSTDATAUPDATE_START
		return
	end

	if not GUI.TabItem.Enabled:GetValue() then
		return
	end

	local LocalPlayer = entities_GetLocalPlayer()
	if not LocalPlayer or not LocalPlayer:IsAlive() then
		return
	end

	local TeamNum = LocalPlayer:GetTeamNumber()
	if TeamNum ~= 2 and TeamNum ~= 3 then
		return
	end

	local Team = TeamNum == 2 and 'T' or 'CT'
	local BothSkinData = GUI.Group3Item.List.Both.raw_values
	local SkinData = GUI.Group3Item.List[Team].raw_values

	for i=0, 15 do
		local Weapon = LocalPlayer:GetPropEntity('m_hMyWeapons', i)
		local Name = Weapon and Weapon:GetName()

		if Name then
			local data = SkinData[Name] or BothSkinData[Name]

			if data then
				FFI.ChangeWeaponPaintKit(LocalPlayer, Weapon, data)
			end
		end
	end

	if UpdateHud then
		FFI.FullUpdate()
		UpdateHud = false
	elseif UpdateIcons and not LocalPlayer:IsDormant() then
		FFI.UpdateHudIcons()
		UpdateIcons = false
	end
end)

local need_to_save = false
client_AllowListener('round_start')
client_AllowListener('player_team')
client_AllowListener('player_death')
callbacks_Register('FireGameEvent', function(event)
	if not GUI.TabItem.Enabled:GetValue() then
		return
	end

	local event_name = event:GetName()
	if event_name == 'player_team' then
		if client_GetPlayerIndexByUserID(event:GetInt('userid')) == client_GetLocalPlayerIndex() then
			local t = event:GetInt('team')
			PopulateAimwareSkins(t == 2 and 'T' or t == 3 and 'CT')
		end
	elseif event_name == 'round_start' and need_to_save then
		SaveSettings()
		need_to_save = false

	elseif event_name == 'player_death' then
		local index = client_GetLocalPlayerIndex()
		if client_GetPlayerIndexByUserID(event:GetInt('attacker')) ~= index or client_GetPlayerIndexByUserID(event:GetInt('userid')) == index then
			return
		end

		local Team = entities_GetLocalPlayer():GetTeamNumber() == 2 and 'T' or 'CT'
		local weapon = 'weapon_' .. event:GetString('weapon')
		local data = GUI.Group3Item.List[Team].raw_values[weapon] or
					 GUI.Group3Item.List.Both.raw_values[weapon] or {}

		if data.count_stattrak then
			data.stattrak = data.stattrak + 1
			need_to_save = true
		end
	end
end)

GUI.Tab = gui_Tab(gui_Reference('Visuals'), 'skin_changer', 'Skin Changer')
GUI.TabItem = {}
GUI.GroupItem = {}
GUI.Group2Item = {}
GUI.Group3Item = {}
	GUI.Group3Item.List = {}

GUI.TabItem.Group = gui_Groupbox(GUI.Tab, '', 16, 16)
GUI.TabItem.EnabledText = gui_Text(GUI.TabItem.Group, 'Enabled')
GUI.TabItem.Enabled = guiCheckbox(GUI.TabItem.Group, '', '', 0)
	GUI.TabItem.EnabledText:SetPosY(-32)
	GUI.TabItem.Enabled:SetPosX(607-47)
	GUI.TabItem.Enabled:SetPosY(-37)

GUI.TabItem.EnabledCallback = GUI.TabItem.Enabled:SetCallback(function(value)
	for _, group in ipairs{GUI.GroupItem, GUI.Group2Item, GUI.Group3Item} do
		for k, v in pairs(group) do
			if type(v) ~= 'function' and type(v) ~= 'table' then
				v:SetDisabled(not value)
			end
		end
	end

	gui.SetValue('esp.skins.enabled', value)
	if value then
		PopulateAimwareSkins()
	end
end)

GUI.GroupItem.Group = gui_Groupbox(GUI.Tab, 'Options', 16, 80, 607/2, 300)
	GUI.GroupItem.Item = (function()
		local ref = guiCombobox(GUI.GroupItem.Group, '', 'Item', '')
		local items, raw = FFI.GatherItems()
			ref:SetOptions(items)
			ref:SetRawOptions(raw)
		return ref
	end)()
	GUI.GroupItem.ShowWeaponSkins = guiCheckbox(GUI.GroupItem.Group, '', 'Show Weapon Skins', 0)
	GUI.GroupItem.ShowExtraInfo = guiCheckbox(GUI.GroupItem.Group, '', 'Show Extra Skin Info', 0)
	GUI.GroupItem.Search = guiEditbox(GUI.GroupItem.Group, '', 'Search')
	GUI.GroupItem.Skin = (function()
		local ref = guiListbox(GUI.GroupItem.Group, '', 200)
		local skins, raw = FFI.GatherSkins()
			ref:SetOptions(skins)
			ref:SetRawOptions(raw)
			ref:SetBackupRaw(raw)
			ref:SetSearchRaw(raw)
		return ref
	end)()
	GUI.GroupItem.ShowExtraInfoCallback = GUI.GroupItem.ShowExtraInfo:SetCallback(function(value)
		if value then
			local Skins = GUI.GroupItem.Skin.raw_values
			local List = {}

			for i=1, #Skins do
				local skin = Skins[i]
				List[i] = skin.name .. ' | ' .. skin.index .. ' | ' .. skin.console_name
			end

			GUI.GroupItem.Skin:SetOptions(List)
		else
			GUI.GroupItem.ShowWeaponSkinsCallback(1)
		end

		GUI.GroupItem.SearchCallback(1)
	end)
	GUI.GroupItem.SearchCallback = GUI.GroupItem.Search:SetCallback(function(value)
		local Skins = GUI.GroupItem.Skin.raw_values
		local List = {}
		local RawList = {}
		local search = value:lower()

		if GUI.GroupItem.ShowExtraInfo:GetValue() then
			for i=1, #Skins do
				local skin = Skins[i]
				local str = skin.name .. '/' .. skin.index .. '/' .. skin.console_name

				if str:lower():find(search) then
					List[#List + 1] = skin.name .. ' | ' .. skin.index .. ' | ' .. skin.console_name
					RawList[#RawList + 1] = skin
				end
			end
		else
			for i=1, #Skins do
				local skin = Skins[i]
				if skin.name:lower():find(search) then
					List[#List + 1] = skin.name
					RawList[#RawList + 1] = skin
				end
			end
		end

		GUI.GroupItem.Skin:SetOptions(List)
		GUI.GroupItem.Skin:SetSearchRaw(RawList)
	end)
	GUI.GroupItem.ShowWeaponSkinsCallback = GUI.GroupItem.ShowWeaponSkins:SetCallback(function(value)
		local Skins = {}
		local List = {}

		if value then
			local item = GUI.GroupItem.Item.raw_values[GUI.GroupItem.Item:GetValue() + 1]
			local Kits = FFI.GetWeaponKits(item.console_name)
			local n = 1

			for i=1, #Kits do
				local kit = FFI.GetPaintKit(Kits[i])

				if kit then
					Skins[n] = kit
					n = n + 1
				end
			end

			table_sort(Skins, function(a, b)
				return a.index < b.index
			end)
		else
			Skins = GUI.GroupItem.Skin.backup_values
		end

		if GUI.GroupItem.ShowExtraInfo:GetValue() then
			for i=1, #Skins do
				List[i] = Skins[i].name .. ' | ' .. Skins[i].index .. ' | ' .. Skins[i].console_name
			end
		else
			for i=1, #Skins do
				List[i] = Skins[i].name
			end
		end

		GUI.GroupItem.Skin:SetOptions(List)
		GUI.GroupItem.Skin:SetRawOptions(Skins)
		GUI.GroupItem.SearchCallback(1)
	end)
	GUI.GroupItem.ItemCallback = GUI.GroupItem.Item:SetCallback(function(value)
		GUI.GroupItem.ShowWeaponSkinsCallback(1)
		GUI.GroupItem.ShowExtraInfoCallback(1)
		GUI.GroupItem.SearchCallback(1)
	end)

GUI.Group2Item.Group = gui_Groupbox(GUI.Tab, 'Item Options', 607/2 + 32, 80, 607/2.115, 300)
	GUI.Group2Item.Team = guiCombobox(GUI.Group2Item.Group, '', 'Team', 'Both', 'CT', 'T')
	GUI.Group2Item.Wear = gui.Slider(GUI.Group2Item.Group, '', 'Wear', 0, 0, 1, 0.0001)
	GUI.Group2Item.Seed = guiEditbox(GUI.Group2Item.Group, '', 'Seed')
	GUI.Group2Item.Stattrak = guiEditbox(GUI.Group2Item.Group, '', 'Stattrak')
	GUI.Group2Item.CountStattrak = guiCheckbox(GUI.Group2Item.Group, '', 'Count Stattrak', 0)
	GUI.Group2Item.Name = guiEditbox(GUI.Group2Item.Group, '', 'Name')
	GUI.Group2Item.AddItem = gui_Button(GUI.Group2Item.Group, 'Add Item', function()
		local item = GUI.GroupItem.Item.raw_values[GUI.GroupItem.Item:GetValue() + 1]
		local skin = {}

		if GUI.GroupItem.Search:GetString() ~= '' then
			skin = GUI.GroupItem.Skin.search_values[GUI.GroupItem.Skin:GetValue() + 1]
		else
			skin = GUI.GroupItem.Skin.raw_values[GUI.GroupItem.Skin:GetValue() + 1]
		end

		if not skin then
			skin = FFI.GetPaintKit(0)
		end

		local team = GUI.Group2Item.Team:GetString()
		local wear = GUI.Group2Item.Wear:GetValue()
		local seed = GUI.Group2Item.Seed:GetString()
		local stattrak = GUI.Group2Item.Stattrak:GetString()
		local countStatTrak = GUI.Group2Item.CountStattrak:GetValue()
		local name = GUI.Group2Item.Name:GetString()
			wear = wear == 0 and 0.0001 or wear == 1 and 0.9999 or wear
			seed = tonumber(seed:match('%d+') or 0)
			stattrak = tonumber(stattrak:match('%d+') or -1)

		if stattrak == -1 and countStatTrak then
			stattrak = 0
		end

		local info = {
			item = item,
			skin = skin,
			wear = wear,
			seed = seed,
			name = name,
			stattrak = stattrak,
			count_stattrak = countStatTrak
		}

		local RawItems = GUI.Group3Item.List[team].raw_values
		local Items = GUI.Group3Item.List[team].values
		local raw = RawItems[item.console_name]

		if raw then
			for i=1, #Items do
				if Items[i]:match('(.*) %-') == raw.item.name then
					Items[i] = info.item.name .. ' - ' .. info.skin.name
					break
				end
			end
		else
			Items[#Items + 1] = info.item.name .. ' - ' .. info.skin.name
		end

		RawItems[item.console_name] = info
		GUI.Group3Item.List[team]:SetOptions(Items)
		GUI.Group3Item.List[team]:SetRawOptions(RawItems)
		SaveSettings()

		PopulateAimwareSkins()
	end)

local ItemRemove = function(team)
	return function()
		local Items = GUI.Group3Item.List[team].values
		local RawItems = GUI.Group3Item.List[team].raw_values
		local selected = GUI.Group3Item.List[team]:GetValue() + 1
		local List = {}
		local RawList = {}

		for i=1, #Items do
			if i ~= selected then
				List[#List + 1] = Items[i]

				for k, v in pairs(RawItems) do
					if Items[i]:match('(.*) %-') == v.item.name then
						RawList[k] = v
					end
				end
			end
		end

		GUI.Group3Item.List[team]:SetOptions(List)
		GUI.Group3Item.List[team]:SetRawOptions(RawList)
		SaveSettings()

		PopulateAimwareSkins()
	end
end

GUI.Group3Item.Group = gui_Groupbox(GUI.Tab, 'Active Skins', 16, 544)
	GUI.Group3Item.List.BothText = gui_Text(GUI.Group3Item.Group, 'Both')
		GUI.Group3Item.List.BothText:SetPosY(-12)
		GUI.Group3Item.List.BothText:SetPosX(72)
	GUI.Group3Item.List.Both = guiListbox(GUI.Group3Item.Group, '', 200)
		GUI.Group3Item.List.Both:SetOptions({})
		GUI.Group3Item.List.Both:SetRawOptions({})
		GUI.Group3Item.List.Both:SetWidth(170)
		GUI.Group3Item.List.Both:SetPosY(0)
	GUI.Group3Item.List.BothRemove = gui_Button(GUI.Group3Item.Group, 'Remove Selected', ItemRemove('Both'))
		GUI.Group3Item.List.BothRemove:SetWidth(170)
		GUI.Group3Item.List.BothRemove:SetHeight(24)

	GUI.Group3Item.List.CTText = gui_Text(GUI.Group3Item.Group, 'CT')
		GUI.Group3Item.List.CTText:SetPosY(-12)
		GUI.Group3Item.List.CTText:SetPosX(78 + 170 + 32)
	GUI.Group3Item.List.CT = guiListbox(GUI.Group3Item.Group, '', 200)
		GUI.Group3Item.List.CT:SetOptions({})
		GUI.Group3Item.List.CT:SetRawOptions({})
		GUI.Group3Item.List.CT:SetWidth(170)
		GUI.Group3Item.List.CT:SetPosX(170 + 32)
		GUI.Group3Item.List.CT:SetPosY(0)
	GUI.Group3Item.List.CTRemove = gui_Button(GUI.Group3Item.Group, 'Remove Selected', ItemRemove('CT'))
		GUI.Group3Item.List.CTRemove:SetPosX(170 + 32)
		GUI.Group3Item.List.CTRemove:SetWidth(170)
		GUI.Group3Item.List.CTRemove:SetHeight(24)

	GUI.Group3Item.List.TText = gui_Text(GUI.Group3Item.Group, 'T')
		GUI.Group3Item.List.TText:SetPosY(-12)
		GUI.Group3Item.List.TText:SetPosX(81 + 170*2 + 32*2)
	GUI.Group3Item.List.T = guiListbox(GUI.Group3Item.Group, '', 200)
		GUI.Group3Item.List.T:SetOptions({})
		GUI.Group3Item.List.T:SetRawOptions({})
		GUI.Group3Item.List.T:SetWidth(170)
		GUI.Group3Item.List.T:SetPosX(170*2 + 32*2)
		GUI.Group3Item.List.T:SetPosY(0)
	GUI.Group3Item.List.TRemove = gui_Button(GUI.Group3Item.Group, 'Remove Selected', ItemRemove('T'))
		GUI.Group3Item.List.TRemove:SetPosX(170*2 + 32*2)
		GUI.Group3Item.List.TRemove:SetWidth(170)
		GUI.Group3Item.List.TRemove:SetHeight(24)

LoadSettings()
