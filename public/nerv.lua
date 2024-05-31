-- ======================================
--         _   ____________ _    __      
--        / | / / ____/ __ \ |  / /      
--       /  |/ / __/ / /_/ / | / /       
--      / /|  / /___/ _, _/| |/ /        
--     /_/ |_/_____/_/ |_| |___/         
--                                       
-- ======================================
--
-- Author: Chlod Alejandro
-- License: BSD-3-Clause
--
-- Nerv management script
-- Download on computer using:
--    wget https://nerv.chlod.net/nerv.lua
-- Then run with:
--    nerv <subcommand>

NERV_SERVER = "https://nerv.chlod.net"
NERV_BIN = "/nerv"

local tArgs = { ... }
if #tArgs == 0 then
    print("Nerv management script")
    print("Usage: nerv <subcommand>")
    print()
    print("Available subcommands:")
    print("  setup <scriptSet> - Set up a script set")
    print("  update - Update the Nerv script")
    print("  clean - Clean the Nerv directory")
    return
end

local subcommand = tArgs[1]

if subcommand == "setup" then
    local scriptSet = tArgs[2]

    if scriptSet == nil then
        print("Usage: nerv setup <scriptSet>")
        return
    end

    print("Setting up '" .. scriptSet .. "'...")
    print("Getting manifest...")
    local manifestRequest = http.get(NERV_SERVER .. "/lua/manifest.json")
    if manifestRequest == nil then
        printError("Failed to get manifest.")
        return
    end
    local manifestText = manifestRequest.readAll()
    -- safely json decode with pcall and textutils.unserializeJSON
    local success, manifest = pcall(textutils.unserializeJSON, manifestText)
    if not success then
        printError("Failed to decode manifest.")
        return
    end
    manifestRequest.close()
    
    if manifest[scriptSet] == nil then
        printError("No such script set.")
        return
    end

    local startupFile = manifest[scriptSet].startup

    if startupFile == nil then
        printError("No startup file for script set.")
        return
    end

    local toDownload = { unpack(manifest[scriptSet].depends or {}) }
    table.insert(toDownload, startupFile)
    print("Downloading " .. #toDownload .. " files...")
    for _, file in pairs(toDownload) do
        print("Downloading " .. file)
        local fileRequest = http.get(NERV_SERVER .. "/lua/" .. file)
        if fileRequest == nil then
            printError("Failed to download " .. file)
            return
        end
        local fileText = fileRequest.readAll()
        fileRequest.close()

        -- Update dependency paths
        fileText = fileText:gsub("require%(\"%.%.%/", "require(\"" .. NERV_BIN .. "/")
        fileText = fileText:gsub("require%(\"%.%/", "require(\"" 
            .. NERV_BIN .. "/" .. file:gsub("/([^/]+)$", "")
            .. "/")

        local fileHandle = fs.open(NERV_BIN .. "/" .. file, "w")
        fileHandle.write(fileText)
        fileHandle.close()
    end

    if fs.exists("/startup") then
        print("startup exists. Deleting...")
        fs.delete("/startup")
    end
    print("Creating startup...")
    local startup = fs.open("/startup", "w")
    startup.write(
        "require(\""
        .. NERV_BIN
        .. "/"
        .. startupFile:gsub("%.lua$", "")
        .. "\")"
    )

    print("Done. Rebooting...")
    sleep(2)
    os.reboot()
elseif subcommand == "turtle" then
    local script = tArgs[2]

    if script == nil then
        print("Usage: nerv turtle <script>")
        return
    end

    print("Downloading turtle script: \"" .. script .. "\"")
    local fileRequest = http.get(NERV_SERVER .. "/lua/turtle/" .. script)
    if fileRequest == nil then
        printError("Failed to download " .. script)
        return
    end
    local fileText = fileRequest.readAll()
    fileRequest.close()

    local filePath = NERV_BIN .. "/turtle/" .. script
    local fileHandle = fs.open(filePath, "w")
    fileHandle.write(fileText)
    fileHandle.close()

    os.run({}, filePath, table.unpack(tArgs, 3))
elseif subcommand == "update" then
    print("Updating Nerv script...")
    local scriptRequest = http.get(NERV_SERVER .. "/nerv.lua")
    if scriptRequest == nil then
        printError("Failed to get script.")
        return
    end
    local scriptText = scriptRequest.readAll()
    scriptRequest.close()
    local scriptHandle = fs.open("/nerv.lua", "w")
    scriptHandle.write(scriptText)
    scriptHandle.close()
    print("Done.")
elseif subcommand == "clean" then
    print("Deleting /nerv directory...")
    fs.delete(NERV_BIN)
    print("Done.")
else
    printError("Unknown subcommand: " .. subcommand)
end