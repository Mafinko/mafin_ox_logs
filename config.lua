Config = {}

Config.Discord = {
    Webhook = 'https://discord.com/api/webhooks/YOUR URL',
    BotName = 'Mafin Ox Logs',
    AvatarUrl = '',
    Footer = 'mafin_ox_logs',

    -- Keeps Discord mentions visible in logs but prevents real pings.
    DisableMentions = true
}

Config.Logging = {
    SuccessfulOnly = true,
    QueueDelay = 125,
    PrintToConsole = true,

    ShowPlayerSource = true,
    ShowLicense = true,
    ShowDiscord = true,
    ShowSlots = true,

    IncludeMetadata = true,
    MaxMetadataLength = 900,

    MetadataOrder = {
        'label',
        'description',
        'serial',
        'plate',
        'ammo',
        'components',
        'durability',
        'degrade',
        'image',
        'weight'
    },

    MetadataLabels = {
        label = 'Label',
        description = 'Description',
        serial = 'Serial',
        plate = 'Plate',
        ammo = 'Ammo',
        components = 'Components',
        durability = 'Durability',
        degrade = 'Degrade',
        image = 'Image',
        weight = 'Weight'
    }
}

Config.EnabledLogs = {
    drop = true,
    pickup = true,
    give = true,
    stash_put = true,
    stash_take = true,
    trunk_put = true,
    trunk_take = true,
    glovebox_put = true,
    glovebox_take = true,
    move = false
}

Config.LogTypes = {
    drop = {
        title = 'Item Dropped',
        action = 'Dropped',
        color = 15158332
    },
    pickup = {
        title = 'Item Picked Up',
        action = 'Picked Up',
        color = 3066993
    },
    give = {
        title = 'Item Shared',
        action = 'Shared / Given',
        color = 3447003
    },
    stash_put = {
        title = 'Item Put In Stash',
        action = 'Put In Stash',
        color = 15844367
    },
    stash_take = {
        title = 'Item Taken From Stash',
        action = 'Taken From Stash',
        color = 10181046
    },
    trunk_put = {
        title = 'Item Put In Trunk',
        action = 'Put In Trunk',
        color = 9807270
    },
    trunk_take = {
        title = 'Item Taken From Trunk',
        action = 'Taken From Trunk',
        color = 9807270
    },
    glovebox_put = {
        title = 'Item Put In Glovebox',
        action = 'Put In Glovebox',
        color = 2123412
    },
    glovebox_take = {
        title = 'Item Taken From Glovebox',
        action = 'Taken From Glovebox',
        color = 2123412
    },
    move = {
        title = 'Item Moved',
        action = 'Moved',
        color = 8421504
    }
}
