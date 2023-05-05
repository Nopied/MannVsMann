#if defined _MVM_included
 #endinput
#endif
#define _MVM_included

static int g_IsMannVsMachineModeCount;
static bool g_IsMannVsMachineModeState[8];

enum CurrencyRewards
{
	TF_CURRENCY_PACK_SMALL = 6,
	TF_CURRENCY_PACK_MEDIUM,
	TF_CURRENCY_PACK_LARGE,
	TF_CURRENCY_PACK_CUSTOM
}

// TODO: methodmap support

/**
 * Get/set player's carteen cooldown
 * 
 * @param client   player's index
 * @param time     cooldown time
 */
native float MVM_GetPlayerCarteenCooldown(int client);
native void MVM_SetPlayerCarteenCooldown(int client, float time);

/**
 * Get player's currency spent
 * 
 * @param client       player's index
 * 
 * @return player's currency spent 
 * 
 */
native int MVM_GetPlayerCurrencySpent(int client);

/**
 * Get player's currency
 * 
 * @param client       player's index
 * 
 * @return player's currency
 * 
 */
native int MVM_GetPlayerCurrency(int client);

/**
 * Set player's currency
 * 
 * @param client       player's index
 * @param currency     currency value
 * 
 * @noreturn
 * 
 */
native void MVM_SetPlayerCurrency(int client, int currency);

/**
 * Remove All of player's upgrade
 * 
 * @param client       player's index
 * 
 * @noreturn
 * 
 */
native void MVM_RemoveAllUpgrades(int client);

/**
 * Drop currency for team
 * 
 * @param player currency pos
 * @param size see CurrencyRewards
 * @param amount amount of money 
 * @param forceDistribute true = red money (sniper reward)
 * @param moneyMaker TODO: Unknown
 * @param team only visible for specific team
 * 
 * @noreturn
 * 
 */
native void MVM_DropCurrency(int player, CurrencyRewards size = TF_CURRENCY_PACK_SMALL, int amount = 0, bool forceDistribute = false, int moneyMaker = -1, TFTeam team = view_as<TFTeam>(-1));

/**
 * Called when player starting touch or touching the upgrade station
 * 
 * @param upgradeStation       upgradeStation's index
 * @param client               player's index
 * 
 * @return
 *      Plugin_Continue         Player will be able to access to upgrade menu.
 *      Otherwise               Player will NOT be able to access to upgrade menu.
 * 
 */
forward Action MVM_OnTouchedUpgradeStation(int upgradeStation, int client);

/**
 * Called when player starting touch or touching the currency
 * 
 * @param upgradeStation       currency's index
 * @param client               player's index
 * 
 * @return
 *      Plugin_Continue         Player will be able to access to currency.
 *      Plugin_Changed          Overwrite result.
 *      Otherwise               Player will NOT be able to access to currency.
 * 
 */
forward Action MVM_OnTouchedMoney(int money, int client);

stock bool IsMannVsMachineMode()
{
	return view_as<bool>(GameRules_GetProp("m_bPlayingMannVsMachine"));
}

stock void SetMannVsMachineMode(bool value)
{
    int count = ++g_IsMannVsMachineModeCount;
    g_IsMannVsMachineModeState[count - 1] = IsMannVsMachineMode();
    GameRules_SetProp("m_bPlayingMannVsMachine", value);
}

stock void ResetMannVsMachineMode()
{
    int count = g_IsMannVsMachineModeCount--;
    GameRules_SetProp("m_bPlayingMannVsMachine", g_IsMannVsMachineModeState[count - 1]);
}

public SharedPlugin __pl_MVM=
{
	name="mannvsmann",
	file="mannvsmann.smx",
	#if defined REQUIRE_PLUGIN
		required=1,
	#else
		required=0,
	#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_MVM_SetNTVOptional()
{
    MarkNativeAsOptional("MVM_GetPlayerCarteenCooldown");
    MarkNativeAsOptional("MVM_SetPlayerCarteenCooldown");
    MarkNativeAsOptional("MVM_GetPlayerCurrencySpent");
    MarkNativeAsOptional("MVM_GetPlayerCurrency");
    MarkNativeAsOptional("MVM_SetPlayerCurrency");
    MarkNativeAsOptional("MVM_RemoveAllUpgrades");
    MarkNativeAsOptional("MVM_DropCurrency");
}
#endif
