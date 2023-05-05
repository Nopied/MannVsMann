void Natives_Initialize()
{
    CreateNative("MVM_GetPlayerCarteenCooldown", Native_GetPlayerCarteenCooldown);
    CreateNative("MVM_SetPlayerCarteenCooldown", Native_SetPlayerCarteenCooldown);
    CreateNative("MVM_GetPlayerCurrencySpent", Native_GetPlayerCurrencySpent);
    CreateNative("MVM_GetPlayerCurrency", Native_GetPlayerCurrency);
    CreateNative("MVM_SetPlayerCurrency", Native_SetPlayerCurrency);
    CreateNative("MVM_RemoveAllUpgrades", Native_RemoveAllUpgrades);
    CreateNative("MVM_DropCurrency", Native_DropCurrency);
}

public any Native_GetPlayerCarteenCooldown(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    float time = MvMPlayer(client).CarteenCooldown - GetGameTime();
    return time > 0.0 ? time : 0.0;
}

public /*void*/ int Native_SetPlayerCarteenCooldown(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    float time = GetNativeCell(2);
    MvMPlayer(client).CarteenCooldown = time + GetGameTime();
    
    return 0;
}

public int Native_GetPlayerCurrencySpent(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    int populator = FindEntityByClassname(MaxClients + 1, "info_populator");
    if(populator == -1)
        return 0;

    return SDKCall_GetPlayerCurrencySpent(populator, client);
}

public int Native_GetPlayerCurrency(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    return MvMPlayer(client).Currency;
}

public /*void*/ int Native_SetPlayerCurrency(Handle plugin, int numParams)
{
    int client = GetNativeCell(1), currency = GetNativeCell(2);
    MvMPlayer(client).Currency = currency;

    return 0;
}

public /*void*/ int Native_RemoveAllUpgrades(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    MvMPlayer(client).RemoveAllUpgrades();

    return 0;
}

public /*void*/ int Native_DropCurrency(Handle plugin, int numParams)
// (int player, CurrencyRewards size = TF_CURRENCY_PACK_SMALL, int amount = 0, bool forceDistribute = false, int moneyMaker = -1)
{
    int player = GetNativeCell(1);
    CurrencyRewards reward = GetNativeCell(2);
    int amount = GetNativeCell(3);
    bool forceDistribute = GetNativeCell(4);
    int moneyMaker = GetNativeCell(5);
    TFTeam team = GetNativeCell(6);

    if(team == TFTeam_Invalid)
        g_CurrencyPackTeam = TF2_GetClientTeam(player);
    else
        g_CurrencyPackTeam = team;
    
    SDKCall_DropCurrencyPack(player, reward, amount, forceDistribute, moneyMaker);
    return 0;
}
