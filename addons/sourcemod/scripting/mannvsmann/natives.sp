void Natives_Initialize()
{
    CreateNative("MVM_GetPlayerCarteenCooldown", Native_GetPlayerCarteenCooldown);
    CreateNative("MVM_SetPlayerCarteenCooldown", Native_SetPlayerCarteenCooldown);
    CreateNative("MVM_GetPlayerCurrency", Native_GetPlayerCurrency);
    CreateNative("MVM_SetPlayerCurrency", Native_SetPlayerCurrency);
    CreateNative("MVM_RemoveAllUpgrades", Native_RemoveAllUpgrades);
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
