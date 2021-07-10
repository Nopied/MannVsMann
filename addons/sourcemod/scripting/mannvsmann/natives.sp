void Natives_Initialize()
{
    CreateNative("MVM_GetPlayerCurrency", Native_GetPlayerCurrency);
    CreateNative("MVM_SetPlayerCurrency", Native_SetPlayerCurrency);
    CreateNative("MVM_RemoveAllUpgrades", Native_RemoveAllUpgrades);
}

public int Native_GetPlayerCurrency(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    return MvMPlayer(client).Currency;
}

public int Native_SetPlayerCurrency(Handle plugin, int numParams)
{
    int client = GetNativeCell(1), currency = GetNativeCell(2);
    MvMPlayer(client).Currency = currency;
}

public int Native_RemoveAllUpgrades(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    MvMPlayer(client).RemoveAllUpgrades();
}
