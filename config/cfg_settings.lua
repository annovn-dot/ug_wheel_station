Config                    = {}

Config.Framework          = 'esx' -- 'esx', 'qb', 'qbox'
Config.Debug              = false

Config.OpenCommand        = 'wstation'
Config.FitmentTick        = 2
Config.FitmentScanTimer   = 2000
Config.FitmentCheckRadius = 30.0

Config.VehicleTable       = { -- vehicle DB tables
    esx  = 'owned_vehicles',
    qb   = 'player_vehicles',
    qbox = 'player_vehicles',
}

Config.OwnerColumn        = { -- owner identifier column
    esx  = 'owner',
    qb   = 'citizenid',
    qbox = 'citizenid',
}

Config.PlateColumn        = { -- plate column
    esx  = 'plate',
    qb   = 'plate',
    qbox = 'plate',
}

Config.WheelsColumn       = 'wheels' -- JSON column to store wheel data

Config.DiscordLogs        = {
    Enabled        = true,
    Webhook        = "",

    Username       = "ug_wheel_tuning",
    Avatar         = "",

    ColorSave      = 3447003, -- blue
    IncludeRawJson = false, -- set true if you want JSON payload in message (can be long)
}

