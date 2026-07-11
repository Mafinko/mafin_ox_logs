local logQueue = {}
local queueRunning = false

local function sanitize(value)
    value = tostring(value or 'Unknown')
    value = value:gsub('`', "'")
    value = value:gsub('\r', ' ')
    value = value:gsub('\n', ' ')

    if #value > 1024 then
        value = value:sub(1, 1021) .. '...'
    end

    return value
end

local function isDiscordWebhook(url)
    if type(url) ~= 'string' or url == '' then
        return false
    end

    return url:match('^https://discord%.com/api/webhooks/%d+/.+') ~= nil
        or url:match('^https://discordapp%.com/api/webhooks/%d+/.+') ~= nil
        or url:match('^https://canary%.discord%.com/api/webhooks/%d+/.+') ~= nil
end

local function getIdentifier(source, prefix)
    source = tonumber(source)

    if not source then
        return 'N/A'
    end

    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local identifier = GetPlayerIdentifier(source, i)

        if identifier and identifier:sub(1, #prefix) == prefix then
            return identifier
        end
    end

    return 'N/A'
end

local function describePlayer(source)
    source = tonumber(source)

    if not source or source <= 0 then
        return 'N/A'
    end

    local name = GetPlayerName(source) or 'Unknown'
    local license = getIdentifier(source, 'license:')
    local discord = getIdentifier(source, 'discord:')

    if discord ~= 'N/A' then
        discord = '<@' .. discord:gsub('discord:', '') .. '>'
    end

    local lines = {}
    local playerName = sanitize(name)

    if Config.Logging.ShowPlayerSource then
        playerName = ('%s [%s]'):format(playerName, source)
    end

    lines[#lines + 1] = playerName

    if Config.Logging.ShowLicense then
        lines[#lines + 1] = ('License: %s'):format(sanitize(license))
    end

    if Config.Logging.ShowDiscord then
        lines[#lines + 1] = ('Discord: %s'):format(sanitize(discord))
    end

    return table.concat(lines, '\n')
end

local function inventoryId(inventory)
    if type(inventory) == 'table' then
        return inventory.id or inventory.name or inventory.label or inventory.type or json.encode(inventory)
    end

    return inventory
end

local function describeInventory(inventory, inventoryType)
    local id = inventoryId(inventory)

    if inventoryType == 'player' then
        return describePlayer(id)
    end

    if inventoryType == 'drop' then
        return ('Ground drop: %s'):format(sanitize(id))
    end

    if inventoryType == 'stash' then
        return ('Stash: %s'):format(sanitize(id))
    end

    if inventoryType == 'trunk' then
        return ('Trunk: %s'):format(sanitize(id))
    end

    if inventoryType == 'glovebox' then
        return ('Glovebox: %s'):format(sanitize(id))
    end

    return ('%s: %s'):format(sanitize(inventoryType or 'inventory'), sanitize(id))
end

local function itemLabel(slot)
    if type(slot) ~= 'table' then
        return 'Unknown item'
    end

    if type(slot.metadata) == 'table' and slot.metadata.label then
        return slot.metadata.label
    end

    return slot.label or slot.name or 'Unknown item'
end

local function classify(payload)
    local action = tostring(payload.action or '')
    local fromType = tostring(payload.fromType or '')
    local toType = tostring(payload.toType or '')

    if action == 'give' or (fromType == 'player' and toType == 'player') then
        return 'give'
    end

    if fromType == 'player' and toType == 'drop' then
        return 'drop'
    end

    if fromType == 'drop' and toType == 'player' then
        return 'pickup'
    end

    if toType == 'stash' then
        return 'stash_put'
    end

    if fromType == 'stash' then
        return 'stash_take'
    end

    if toType == 'trunk' then
        return 'trunk_put'
    end

    if fromType == 'trunk' then
        return 'trunk_take'
    end

    if toType == 'glovebox' then
        return 'glovebox_put'
    end

    if fromType == 'glovebox' then
        return 'glovebox_take'
    end

    return 'move'
end

local function formatMetadataKey(key)
    local labels = Config.Logging.MetadataLabels or {}

    if labels[key] then
        return labels[key]
    end

    local label = tostring(key or 'Unknown'):gsub('_', ' ')

    return label:gsub('^%l', string.upper)
end

local function formatMetadataValue(value)
    local valueType = type(value)

    if valueType == 'boolean' then
        return value and '`Yes`' or '`No`'
    end

    if valueType == 'number' then
        return ('`%s`'):format(value)
    end

    if valueType == 'string' then
        local cleaned = sanitize(value)

        if cleaned:find('%s') then
            return cleaned
        end

        return ('`%s`'):format(cleaned)
    end

    if valueType == 'table' then
        return ('`%s`'):format(sanitize(json.encode(value, { sort_keys = true }) or 'Table'))
    end

    return sanitize(value)
end

local function addMetadataLine(lines, metadata, usedKeys, key)
    if metadata[key] == nil then
        return
    end

    usedKeys[key] = true
    lines[#lines + 1] = ('**%s:** %s'):format(sanitize(formatMetadataKey(key)), formatMetadataValue(metadata[key]))
end

local function formatMetadata(metadata)
    if not Config.Logging.IncludeMetadata or type(metadata) ~= 'table' or not next(metadata) then
        return nil
    end

    local lines = {}
    local usedKeys = {}
    local order = Config.Logging.MetadataOrder or {}

    for i = 1, #order do
        addMetadataLine(lines, metadata, usedKeys, order[i])
    end

    local extraKeys = {}

    for key in pairs(metadata) do
        if not usedKeys[key] then
            extraKeys[#extraKeys + 1] = key
        end
    end

    table.sort(extraKeys, function(a, b)
        return tostring(a) < tostring(b)
    end)

    for i = 1, #extraKeys do
        addMetadataLine(lines, metadata, usedKeys, extraKeys[i])
    end

    local formatted = table.concat(lines, '\n')

    if formatted == '' then
        return nil
    end

    if #formatted > Config.Logging.MaxMetadataLength then
        formatted = formatted:sub(1, Config.Logging.MaxMetadataLength - 3) .. '...'
    end

    return formatted
end

local function makeEmbed(eventType, payload)
    local logType = Config.LogTypes[eventType] or Config.LogTypes.move
    local slot = payload.fromSlot or {}
    local metadata = type(slot) == 'table' and slot.metadata or nil
    local count = tonumber(payload.count) or tonumber(slot.count) or 1
    local itemName = type(slot) == 'table' and slot.name or 'unknown'
    local metadataText = formatMetadata(metadata)

    local fields = {
        {
            name = 'Player',
            value = describePlayer(payload.source),
            inline = false
        },
        {
            name = 'Item',
            value = ('%sx %s (`%s`)'):format(count, sanitize(itemLabel(slot)), sanitize(itemName)),
            inline = true
        },
        {
            name = 'Action',
            value = sanitize(logType.action or payload.action or 'Unknown'),
            inline = true
        },
        {
            name = 'From',
            value = describeInventory(payload.fromInventory, payload.fromType),
            inline = false
        },
        {
            name = 'To',
            value = describeInventory(payload.toInventory, payload.toType),
            inline = false
        }
    }

    if Config.Logging.ShowSlots and payload.fromSlot and payload.fromSlot.slot then
        fields[#fields + 1] = {
            name = 'From Slot',
            value = sanitize(payload.fromSlot.slot),
            inline = true
        }
    end

    if Config.Logging.ShowSlots and payload.toSlot then
        local toSlot = type(payload.toSlot) == 'table' and payload.toSlot.slot or payload.toSlot

        fields[#fields + 1] = {
            name = 'To Slot',
            value = sanitize(toSlot),
            inline = true
        }
    end

    if metadataText then
        fields[#fields + 1] = {
            name = 'Metadata',
            value = metadataText,
            inline = false
        }
    end

    return {
        title = logType.title or 'Item Log',
        color = logType.color or 8421504,
        fields = fields,
        footer = {
            text = Config.Discord.Footer
        },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
    }
end

local function sendDiscord(embed)
    if not isDiscordWebhook(Config.Discord.Webhook) then
        if Config.Logging.PrintToConsole then
            print('[mafin_ox_logs] Invalid or missing Discord webhook. Set Config.Discord.Webhook in config.lua.')
        end

        return
    end

    local payload = {
        username = Config.Discord.BotName,
        avatar_url = Config.Discord.AvatarUrl ~= '' and Config.Discord.AvatarUrl or nil,
        embeds = { embed }
    }

    if Config.Discord.DisableMentions then
        payload.allowed_mentions = {
            parse = {}
        }
    end

    PerformHttpRequest(Config.Discord.Webhook, function(status)
        if Config.Logging.PrintToConsole and (status < 200 or status > 299) then
            print(('[mafin_ox_logs] Discord webhook failed with HTTP %s.'):format(status))
        end
    end, 'POST', json.encode(payload), {
        ['Content-Type'] = 'application/json'
    })
end

local function processQueue()
    if queueRunning then
        return
    end

    queueRunning = true

    CreateThread(function()
        while #logQueue > 0 do
            local embed = table.remove(logQueue, 1)

            sendDiscord(embed)
            Wait(Config.Logging.QueueDelay or 125)
        end

        queueRunning = false
    end)
end

local function queueLog(embed)
    logQueue[#logQueue + 1] = embed
    processQueue()
end

CreateThread(function()
    while GetResourceState('ox_inventory') ~= 'started' do
        Wait(500)
    end

    local hookId = exports.ox_inventory:registerHook('swapItems', nil, {
        print = false
    })

    AddEventHandler(hookId, function(success, payload)
        if Config.Logging.SuccessfulOnly and not success then
            return
        end

        local eventType = classify(payload)

        if not Config.EnabledLogs[eventType] then
            return
        end

        queueLog(makeEmbed(eventType, payload))
    end)

    if Config.Logging.PrintToConsole then
        print('[mafin_ox_logs] ox_inventory webhook logging started.')
    end
end)
