Framework = {}
Framework.Name = Config.Framework or 'standalone'

if Framework.Name == 'esx' then
    local ESX

    CreateThread(function()
        while not ESX do
            TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
            Wait(250)
        end
        print('[ug_wheel_tuning] ESX framework attached.')
    end)

    function Framework.GetPlayer(src)
        if not ESX then return nil end
        return ESX.GetPlayerFromId(src)
    end

    function Framework.GetIdentifier(xPlayer)
        return xPlayer and xPlayer.identifier or nil
    end

    function Framework.GetJob(xPlayer)
        return xPlayer and xPlayer.job and xPlayer.job.name or nil
    end
elseif Framework.Name == 'qb' then
    local QBCore = exports['qb-core']:GetCoreObject()

    function Framework.GetPlayer(src)
        return QBCore.Functions.GetPlayer(src)
    end

    function Framework.GetIdentifier(player)
        return player and player.PlayerData and player.PlayerData.citizenid or nil
    end

    function Framework.GetJob(player)
        return player and player.PlayerData
            and player.PlayerData.job
            and player.PlayerData.job.name or nil
    end
elseif Framework.Name == 'qbox' then
    local QBCore = exports['qb-core']:GetCoreObject()

    function Framework.GetPlayer(src)
        return QBCore.Functions.GetPlayer(src)
    end

    function Framework.GetIdentifier(player)
        return player and player.PlayerData and player.PlayerData.citizenid or nil
    end

    function Framework.GetJob(player)
        return player and player.PlayerData
            and player.PlayerData.job
            and player.PlayerData.job.name or nil
    end
else
    print('[ug_wheel_tuning] WARNING: Unknown framework "' ..
        tostring(Framework.Name) .. '", running in standalone mode.')

    function Framework.GetPlayer(src)
        return { source = src }
    end

    function Framework.GetIdentifier(player)
        return player and ('steam:' .. tostring(player.source)) or nil
    end

    function Framework.GetJob(_)
        return nil
    end
end
