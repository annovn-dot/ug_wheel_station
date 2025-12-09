-- exports('IsInWheelZone', IsInWheelZone)

Config.FitmentZones = {
    ["ug_wheel_zone_public"] = {
        coords             = vector3(-325.6886, -138.7019, 38.3868),
        heading            = 250.1908,
        radius             = 1.5,

        price              = 0,   -- if you want to charge per use later

        job                = nil, -- nil for none
        allowedIdentifiers = {
            -- 'char1:license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
            -- 'ABC12345',  -- qb/qbox citizenid
        },
        accessMode         = 'public', -- 'public' | 'jobOnly' | 'identifiersOnly' | 'jobOrIdentifier'
    },
}
