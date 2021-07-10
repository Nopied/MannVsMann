#if defined _MVM_included
 #endinput
#endif
#define _MVM_included

// TODO: methodmap support

/*
    Get player's currency

    @param client       player's index

    @return player's currency
*/
native int MVM_GetPlayerCurrency(int client);

/*
    Set player's currency

    @param client       player's index
    @param currency     currency value

    @noreturn
*/
native void MVM_SetPlayerCurrency(int client, int currency);

/*
    Remove All of player's upgrade

    @param client       player's index

    @noreturn
*/
native void MVM_RemoveAllUpgrades(int client);

/*
    Called when player starting touch or touching the upgrade station

    @param upgradeStation       upgradeStation's index
    @param client               player's index

    @return
        Plugin_Continue       Player will be able to access to upgrade menu.
        Otherwise               Player will NOT be able to access to upgrade menu.
*/
forward Action MVM_OnTouchedUpgradeStation(int upgradeStation, int client);

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
    MarkNativeAsOptional("MVM_GetPlayerCurrency");
    MarkNativeAsOptional("MVM_SetPlayerCurrency");
    MarkNativeAsOptional("MVM_RemoveAllUpgrades");
}
#endif
