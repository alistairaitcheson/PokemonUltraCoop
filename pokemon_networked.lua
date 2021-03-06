-- https://datacrystal.romhacking.net/wiki/Pok%C3%A9mon_Red/Blue:RAM_map#Misc.

-- there needs to be some kind of timestamping
-- if there are multiple copies of the same data area, only use the one with the latest timestamp

console.clear();

DEBUG_MODE = true

BUFFER_TIME_BETWEEN_SENDS = 30

BANNED_MEMORY_ADDRESSES = {
    0x15CD, -- changes when walking about room
    0x173B, 0x173C, -- changes when going up/down stairs (room ID?)
    0x1730, 0x1736, -- changes when going up/down stairs (fade in/out?)
    0x15CF, 0x15D0, -- changes when going in/out of houses (room ID?)
}

DATA_AREAS_LOC = { -- INCLUSIVE ARRAYS
    {0x1009, 0x1030, "battle", "in-battle-pokemon"}, -- in-battle pokemon data
    {0x1163, 0x116A, "pokemon", "party-list"}, -- pokemon party list
    {0x116B, 0x1196, "pokemon", "pokemon 1"}, -- pokemon 1
    {0x1197, 0x11C2, "pokemon", "pokemon 2"}, -- pokemon 2
    {0x11C3, 0x11EE, "pokemon", "pokemon 3"}, -- pokemon 3
    {0x11EF, 0x121A, "pokemon", "pokemon 4"}, -- pokemon 4
    {0x121B, 0x1246, "pokemon", "pokemon 5"}, -- pokemon 5
    {0x1247, 0x1272, "pokemon", "pokemon 6"}, -- pokemon 6
    {0x1273, 0x12B4, "pokemon", "pokemon original trainers"}, -- trainer name per pokemon
    {0x12B5, 0x12F6, "pokemon", "nicknames"}, -- nickname per pokemon
    {0x131D, 0x1346, "items", "items"}, -- items (include?)
    {0x1347, 0x1349, "money", "money"}, -- money (include?)
    {0x1356, 0x1356, "events", "badges"}, -- badges
    {0x0022, 0x0025, "music", "audio tracks"}, -- music track (use this? needs something paired with it?)
    {0x135B, 0x135C, "music", "music track"}, -- music track (use this? needs something paired with it?)
    {0x153A, 0x159F, "items", "stored items"}, -- stored items (use it?)
    {0x15A6, 0x15FF, "events", "mega-event-batch-1"}, -- event flags (and a bunch of other stuff in the middle? Should I limit this?)
    {0x1600, 0x168F, "events", "mega-event-batch-2"}, -- event flags (and a bunch of other stuff in the middle? Should I limit this?)
    {0x1690, 0x16FF, "events", "mega-event-batch-3"}, -- event flags (and a bunch of other stuff in the middle? Should I limit this?)
    {0x1700, 0x178F, "events", "mega-event-batch-4"}, -- event flags (and a bunch of other stuff in the middle? Should I limit this?)
    {0x1790, 0x17FF, "events", "mega-event-batch-5"}, -- event flags (and a bunch of other stuff in the middle? Should I limit this?)
    {0x1800, 0x185F, "events", "mega-event-batch-6"}, -- event flags (and a bunch of other stuff in the middle? Should I limit this?)
}



math.randomseed(os.time())

function addToDebugLog(text)
	if DEBUG_MODE then
		console.log(text)
	end
end

function tablelength(T)
    -- addToDebugLog("tablelength: " .. tostring(T))
	local count = 0
	for _ in pairs(T) do count = count + 1 end
	return count
end

function file_exists(filePath)
	local f = io.open(filePath, "rb")
	if f then f:close() end
	return f ~= nil
end

area_states = {}
countdown_per_state = {}

for whichArea = 1, tablelength(DATA_AREAS_LOC) do 
    bounds = DATA_AREAS_LOC[whichArea]
    state = {}
    table.insert(area_states, state)
    table.insert(countdown_per_state, 0)

    for i = bounds[1], bounds[2], 1 do
        state[i] = memory.readbyte(i, "WRAM")
    end
end

function checkForLocalChanges()
    for whichArea = 1, tablelength(DATA_AREAS_LOC) do 
        bounds = DATA_AREAS_LOC[whichArea]
        has_changed = false

        for i = bounds[1], bounds[2], 1 do
            is_allowed = true
            for j = 1, tablelength(BANNED_MEMORY_ADDRESSES) do
                if i == BANNED_MEMORY_ADDRESSES[j] then
                    is_allowed = false
                end
            end

            if is_allowed then
                last_val = area_states[whichArea][i]
                now_val = memory.readbyte(i, "WRAM")
                if last_val ~= now_val then
                    has_changed = true
                    area_states[whichArea][i] = now_val
                    addToDebugLog("Detected change in " .. bounds[4] .. " ".. string.format("%X", i) .. " " .. tostring(last_val) .. " --> " .. tostring(now_val))
                end
            end
        end

        if has_changed then
            countdown_per_state[whichArea] = BUFFER_TIME_BETWEEN_SENDS
        end
    end
end

function sendStateOverNetwork(whichArea) 
    -- send this state over the network!
    file_index = math.random(1, 100)
    file_path_to_write = "pokemon_network_data/write_" .. tostring(file_index) .. ".txt"
    attempts = 0
    while attempts < 100 and file_exists(file_path_to_write) do
        file_index = math.random(1, 100)
        file_path_to_write = "pokemon_network_data/write_" .. tostring(file_index) .. ".txt"
        attempts = attempts + 1
    end
    if attempts >= 100 then
        -- cannot send data SHOW AN ALERT!
        -- is the assistant switched on?
        addToDebugLog("Out of space to send! Is the assistant switched on?")
        return
    end

    output_text = "" .. tostring(whichArea)

    bounds = DATA_AREAS_LOC[whichArea]
    for i = bounds[1], bounds[2], 1 do
        value = memory.readbyte(i, "WRAM")
        output_text = output_text .. "\n" .. tostring(value) 
    end

    local write_file = io.open(file_path_to_write,"w")
    write_file:write(output_text)
    write_file:close()

    addToDebugLog("Wrote to output " .. file_path_to_write)
    -- addToDebugLog("Wrote data: " .. output_text)
end

function checkForNetworkChanges()
    -- if we detect a change remember to make sure area_states is edited, *then* memory is written!
    for i = 1, 100, 1 do
        file_path_to_read = "pokemon_network_data/read_" .. tostring(i) .. ".txt"
        if file_exists(file_path_to_read) then
            addToDebugLog("Reading from file at " .. file_path_to_read)
            local f = io.open(file_path_to_read, "r")
            addToDebugLog("Did open file at " .. file_path_to_read)
            index = -1
            which_data_area = -1
            for line in io.lines(file_path_to_read) do
                -- addToDebugLog(tostring(index) .. ": Parsing line: " .. line)
                if string.len(line) > 0 then
                    if index == -1 then 
                        addToDebugLog("Getting data area")
                        which_data_area = tonumber(line)
                        addToDebugLog("Data area is " .. DATA_AREAS_LOC[which_data_area][4])
                    elseif which_data_area > 0 then
                        loc = DATA_AREAS_LOC[which_data_area][1] + index
                        -- addToDebugLog(tostring(index) .. ": writing to loc " .. tostring(loc))
                        val = tonumber(line)
                        -- addToDebugLog(tostring(index) .. ": writing val " .. tostring(val))
                        memory.writebyte(loc, val, "WRAM")
                        -- addToDebugLog(tostring(index) .. ": wrote val " .. tostring(val))
                        area_states[which_data_area][loc] = val  
                        -- addToDebugLog(tostring(index) .. ": cached val " .. tostring(val))
                    end              
                    -- addToDebugLog(tostring(index) .. ": Successfully parsed line: " .. line)
                end          
                index = index + 1
            end
            addToDebugLog("Finished writing")
            f:close()
            addToDebugLog("Removing file at " .. file_path_to_read)
            os.remove(file_path_to_read)
        end
    end
end

while true do
    checkForNetworkChanges()
    checkForLocalChanges()

    for i = 1, tablelength(countdown_per_state), 1 do
        if countdown_per_state[i] > 0 then
            -- addToDebugLog(tostring(i) .. ": " .. tostring(countdown_per_state[i]))
            countdown_per_state[i] = countdown_per_state[i] - 1
            if countdown_per_state[i] <= 0 then
                -- addToDebugLog("SENDING " .. tostring(i) .. ": " .. tostring(countdown_per_state[i]))
                sendStateOverNetwork(i)
            end
        end
    end

    emu.frameadvance()
end
