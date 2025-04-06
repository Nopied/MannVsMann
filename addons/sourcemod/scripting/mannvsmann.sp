/*
 * Copyright (C) 2021  Mikusch
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2utils>
#include <dhooks>
#include <tf2attributes>
#include <memorypatch>
#include <mannvsmann>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION	"1.2.0"

#define MEDIGUN_CHARGE_INVULN	0
#define LOADOUT_POSITION_ACTION	9

#define SOLID_BBOX	2

#define UPGRADE_STATION_MODEL	"models/error.mdl"
#define SOUND_CREDITS_UPDATED	"ui/credits_updated.wav"
#define SOUND_BUY_UPGRADE		")mvm/mvm_bought_upgrade.wav"

const TFTeam TFTeam_Invalid = view_as<TFTeam>(-1);

//ConVars
ConVar mvm_starting_currency;
ConVar mvm_currency_rewards_player_killed;
ConVar mvm_currency_death_penalty;
ConVar mvm_currency_rewards_player_count_bonus;
ConVar mvm_reset_on_round_end;
ConVar mvm_spawn_protection;
ConVar mvm_disable_hud_currency;
ConVar mvm_disable_respec_menu;
ConVar mvm_drop_revivemarker;
ConVar mvm_enable_music;
ConVar mvm_carteen_cooldown;
ConVar mvm_allow_dropweapon;
ConVar mvm_custom_upgrades_file;
ConVar mvm_block_using_nav;
ConVar mvm_force_currency_victim_team;

//DHooks
TFTeam g_CurrencyPackTeam;

//Offsets
int g_OffsetPlayerSharedOuter;
// int g_OffsetPlayerReviveMarker;
// int g_OffsetCurrencyPackAmount;
// int g_OffsetRestoringCheckpoint;

//Other globals
// ArrayList g_hCornerList;
// int g_BeamSprite, g_HaloSprite;
Handle g_HudSync;
Handle g_onTouchedUpgradeStation;
Handle g_onTouchedMoney;
bool g_ForceMapReset;

#include "mannvsmann/methodmaps.sp"

#include "mannvsmann/dhooks.sp"
#include "mannvsmann/events.sp"
#include "mannvsmann/helpers.sp"
#include "mannvsmann/offsets.sp"
#include "mannvsmann/patches.sp"
#include "mannvsmann/sdkhooks.sp"
#include "mannvsmann/sdkcalls.sp"

#include "mannvsmann/natives.sp"

public Plugin myinfo =
{
	name = "Mann vs. Mann",
	author = "Mikusch (Forked by Nopied◎)",
	description = "Regular Team Fortress 2 with Mann vs. Machine upgrades",
	version = PLUGIN_VERSION,
	url = "https://github.com/Mikusch/MannVsMann"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_onTouchedUpgradeStation = CreateGlobalForward("MVM_OnTouchedUpgradeStation", ET_Hook, Param_Cell, Param_Cell); // upgradeStation, client
	g_onTouchedMoney = CreateGlobalForward("MVM_OnTouchedMoney", ET_Hook, Param_Cell, Param_Cell); // money, client

	// mannvsmann/natives.sp
	Natives_Initialize();

	RegPluginLibrary("mannvsmann");

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mannvsmann.phrases");

	CreateConVar("mvm_version", PLUGIN_VERSION, "Mann vs. Mann plugin version", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	mvm_starting_currency = CreateConVar("mvm_starting_currency", "800", "Number of credits that players get at the start of a match.", _, true, 0.0);
	mvm_currency_rewards_player_killed = CreateConVar("mvm_currency_rewards_player_killed", "15", "The fixed number of credits dropped by players on death.");
	mvm_currency_death_penalty = CreateConVar("mvm_currency_death_penalty", "1", "Drop all of dead player's money.");
	mvm_currency_rewards_player_count_bonus = CreateConVar("mvm_currency_rewards_player_count_bonus", "2.0", "Multiplier to dropped currency that gradually increases up to this value until all player slots have been filled.", _, true, 1.0);
	mvm_reset_on_round_end = CreateConVar("mvm_reset_on_round_end", "1", "When set to 1, player upgrades and cash will reset when a full round has been played.");
	mvm_spawn_protection = CreateConVar("mvm_spawn_protection", "0", "When set to 1, players are granted ubercharge while they leave their spawn.");
	mvm_disable_hud_currency = CreateConVar("mvm_disable_hud_currency", "1", "When set to 1, disabled currency HUD.");
	mvm_disable_respec_menu = CreateConVar("mvm_disable_respec_menu", "1", "When set to 1, disabled respec menu.");
	mvm_drop_revivemarker = CreateConVar("mvm_drop_revivemarker", "0", "When set to 1, drop revive marker when player dead.");
	mvm_enable_music = CreateConVar("mvm_enable_music", "1", "When set to 1, Mann vs. Machine music will play at the start and end of a round.");
	mvm_carteen_cooldown = CreateConVar("mvm_carteen_cooldown", "30.0", "Cooldown time of carteen.", _, true, 0.0);
	mvm_allow_dropweapon = CreateConVar("mvm_allow_dropweapon", "0", "When set to 1, drop player's weapon when player dead.");
	mvm_custom_upgrades_file = CreateConVar("mvm_custom_upgrades_file", "", "Custom upgrade menu file to use, set to an empty string to use the default.");
	mvm_block_using_nav = CreateConVar("mvm_block_using_nav", "1", "If the server using custom map, currency will be removed when server has no nav mash file of current map.");
	mvm_force_currency_victim_team = CreateConVar("mvm_force_currency_victim_team", "2", "Force set the currency's team, which will be seen to the victim's team. 2 - red, 3 - blue");

	mvm_custom_upgrades_file.AddChangeHook(ConVarChanged_CustomUpgradesFile);

	HookEntityOutput("team_round_timer", "On10SecRemain", EntityOutput_OnTimer10SecRemain);

	AddNormalSoundHook(NormalSoundHook);

	g_HudSync = CreateHudSynchronizer();

	Events_Initialize();

	GameData gamedata = new GameData("mannvsmann");
	if (gamedata)
	{
		DHooks_Initialize(gamedata);
		Patches_Initialize(gamedata);
		SDKCalls_Initialize(gamedata);
		Offsets_Init(gamedata);

		g_OffsetPlayerSharedOuter = gamedata.GetOffset("CTFPlayerShared::m_pOuter");
		// g_OffsetPlayerReviveMarker = gamedata.GetOffset("CTFPlayer::m_hReviveMarker");
		// g_OffsetCurrencyPackAmount = gamedata.GetOffset("CCurrencyPack::m_nAmount");
		// g_OffsetRestoringCheckpoint = gamedata.GetOffset("CPopulationManager::m_isRestoringCheckpoint");

		delete gamedata;
	}
	else
	{
		SetFailState("Could not find mannvsmann gamedata");
	}

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			OnClientPutInServer(client);
		}
	}
}

public void ConVarChanged_CustomUpgradesFile(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (newValue[0] != '\0')
	{
		SetCustomUpgradesFile(newValue);
	}
	else
	{
		int gamerules = FindEntityByClassname(MaxClients + 1, "tf_gamerules");
		if (gamerules != -1)
		{
			//Reset to the default upgrades file
			SetVariantString("scripts/items/mvm_upgrades.txt");
			AcceptEntityInput(gamerules, "SetCustomUpgradesFile");
		}
	}
}

public void OnPluginEnd()
{
	Patches_Destroy();

	//Remove the populator on plugin end
	int populator = FindEntityByClassname(MaxClients + 1, "info_populator");
	if (populator != -1)
	{
		//NOTE: We use RemoveImmediate here because RemoveEntity deletes it a few frames later.
		//This causes the global populator pointer to be set to NULL despite us having created a new populator already.
		SDKCall_RemoveImmediate(populator);
	}

	//Remove all upgrade stations in the map
	int upgradestation = MaxClients + 1;
	while ((upgradestation = FindEntityByClassname(upgradestation, "func_upgradestation")) != -1)
	{
		RemoveEntity(upgradestation);
	}

	//Remove all currency packs still in the map
	int currencypack = MaxClients + 1;
	while ((currencypack = FindEntityByClassname(currencypack, "item_currencypack*")) != -1)
	{
		RemoveEntity(currencypack);
	}

	//Remove all revive markers still in the map
	int marker = MaxClients + 1;
	while ((marker = FindEntityByClassname(marker, "entity_revive_marker")) != -1)
	{
		RemoveEntity(marker);
	}

	// Disable upgrades
	SetVariantString("ForceEnableUpgrades(0)");
	AcceptEntityInput(0, "RunScriptCode");
}

public void OnMapStart()
{
	PrecacheModel(UPGRADE_STATION_MODEL);
	PrecacheModel(UPGRADE_SIGN_MODEL);
	PrecacheSound(SOUND_CREDITS_UPDATED);

	DHooks_HookGameRules();

	// Set solid type to SOLID_NONE to suppress warnings
	int upgradestation = CreateEntityByName("func_upgradestation");
	SetEntProp(upgradestation, Prop_Send, "m_nSolidType", 0); // SOLID_NONE
	DispatchSpawn(upgradestation);

	//Set custom upgrades file on level init
	char path[PLATFORM_MAX_PATH];
	mvm_custom_upgrades_file.GetString(path, sizeof(path));
	if (path[0] != '\0')
	{
		SetCustomUpgradesFile(path);
	}

	//An info_populator entity is required for a lot of MvM-related stuff (preserved entity)
	CreateEntityByName("info_populator");

	SetVariantString("ForceEnableUpgrades(2)");
	AcceptEntityInput(0, "RunScriptCode");
}

public Action OnTouchUpgradeStation(int upgradeStation, int other)
{
	if(!IsValidClient(other))
		return Plugin_Continue;

	// Prevents after stun
	if(TF2_IsPlayerInCondition(other, TFCond_Dazed))
	{
		SetEntProp(other, Prop_Send, "m_bInUpgradeZone", 0);
		return Plugin_Handled;
	}

	Action action = Plugin_Continue;
	Call_StartForward(g_onTouchedUpgradeStation);
	Call_PushCell(upgradeStation);
	Call_PushCell(other);
	Call_Finish(action);

	if(action != Plugin_Continue)
	{
		SetEntProp(other, Prop_Send, "m_bInUpgradeZone", 0);
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public void OnClientPutInServer(int client)
{
	MvMPlayer(client).CarteenCooldown = 0.0;
	MvMPlayer(client).Currency = mvm_starting_currency.IntValue;

	SDKHooks_HookClient(client);
}

public void TF2_OnWaitingForPlayersEnd()
{
	g_ForceMapReset = true;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	DHooks_OnEntityCreated(entity, classname);
	SDKHooks_OnEntityCreated(entity, classname);

	if (strncmp(classname, "item_currencypack", 17) == 0)
	{
		//CTFPlayer::DropCurrencyPack does not assign a team to the currency pack but CTFGameRules::DistributeCurrencyAmount needs to know it
		if (g_CurrencyPackTeam != TFTeam_Invalid)
		{
			TF2_SetTeam(entity, g_CurrencyPackTeam);
		}
	}
	else if (strcmp(classname, "tf_dropped_weapon") == 0)
	{
		//  && !IsFakeClient(owner)
		SDKHook(entity, SDKHook_SpawnPost, OnDroppedWeaponSpawned);
		if(mvm_allow_dropweapon.IntValue == 0)
			RemoveEntity(entity);

		//Do not allow dropped weapons, as you can sell their upgrades for free currency
		//ㄴ NO.
	}
}

public void OnDroppedWeaponSpawned(int weapon)
{
	/*
	int id = GetEntProp(weapon, Prop_Send, "m_iAccountID");
	if(GetIndexOfAccountID(id) == -1)
	 	RemoveEntity(weapon);
	*/

	// PrintToChatAll("%N", GetIndexOfAccountID(id));
}

public void OnEntityDestroyed(int entity)
{
	if (!IsValidEntity(entity))
		return;

	char classname[32];
	if (GetEntityClassname(entity, classname, sizeof(classname)) && strncmp(classname, "item_currencypack", 17) == 0)
	{
		//Remove the currency value from the world money
		if (!GetEntProp(entity, Prop_Send, "m_bDistributed"))
		{
			TFTeam team = TF2_GetTeam(entity);
			MvMTeam(team).WorldCredits -= GetEntData(entity, GetOffset("CCurrencyPack", "m_nAmount"));
		}
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(buttons & IN_ATTACK2)
	{
		char name[32];
		GetClientWeapon(client, name, sizeof(name));

		//Resist mediguns can instantly revive in MvM (CWeaponMedigun::SecondaryAttack)
		if (strcmp(name, "tf_weapon_medigun") == 0)
		{
			SetMannVsMachineMode(true);
		}
	}


	if(GetEntProp(client, Prop_Send, "m_bInUpgradeZone") > 0)
	{
		int currentWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

		// PrintToChatAll("m_nInspectStage = %d", GetEntProp(currentWeapon, Prop_Send, "m_nInspectStage"));
		SetEntProp(currentWeapon, Prop_Send, "m_nInspectStage", 1);
		buttons &= ~IN_RELOAD;
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	if (IsMannVsMachineMode())
	{
		ResetMannVsMachineMode();
	}
}

public Action OnClientCommandKeyValues(int client, KeyValues kv)
{
	char section[32];
	if (kv.GetSectionName(section, sizeof(section)))
	{
		if (strncmp(section, "MvM_", 4, false) == 0)
		{
			if (!strcmp(section, "MVM_Upgrade"))
			{
				// Required for tracking of spent currency
				SetMannVsMachineMode(true);
			}
			else if (strcmp(section, "MvM_UpgradesBegin") == 0)
			{
				if(mvm_disable_respec_menu.BoolValue
					|| CheckRoundState() == 1)	return Plugin_Continue;

				//Create a menu to substitute client-side "Refund Upgrades" button
				Menu menu = new Menu(MenuHandler_UpgradeRespec, MenuAction_Select | MenuAction_Cancel | MenuAction_End | MenuAction_DisplayItem);

				menu.SetTitle("%t", "MvM_UpgradeStation");
				menu.AddItem("respec", "MvM_UpgradeRespec");

				if (menu.Display(client, MENU_TIME_FOREVER))
				{
					MvMPlayer(client).RespecMenu = menu;
				}
				else
				{
					delete menu;
				}
			}
			else if (strcmp(section, "MvM_UpgradesDone") == 0
				&& kv.GetNum("num_upgrades", 0) > 0)
			{
				//Enable upgrade voice lines
				SetVariantString("IsMvMDefender:1");
				AcceptEntityInput(client, "AddContext");
				SetVariantString("TLK_MVM_UPGRADE_COMPLETE");
				AcceptEntityInput(client, "SpeakResponseConcept");
				AcceptEntityInput(client, "ClearContext");

				SetEntProp(client, Prop_Send, "m_bInUpgradeZone", 0);

				//Cancel and reset refund menu
				Menu menu = MvMPlayer(client).RespecMenu;
				if (menu)
				{
					menu.Cancel();
					MvMPlayer(client).RespecMenu = null;
				}
			}
		}
		else if (strcmp(section, "+use_action_slot_item_server") == 0)
		{
			//Required for td_buyback and CTFPowerupBottle::Use to work properly
			SetMannVsMachineMode(true);

			if (IsClientObserver(client))
			{
				float nextRespawn = SDKCall_GetNextRespawnWave(GetClientTeam(client), client);
				if (nextRespawn)
				{
					float respawnWait = (nextRespawn - GetGameTime());
					if (respawnWait > 1.0)
					{
						//Player buys back into the game
						FakeClientCommand(client, "td_buyback");
					}
				}
			}
			else if (!SDKCall_CanRecieveMedigunChargeEffect(GetPlayerShared(client), MEDIGUN_CHARGE_INVULN))
			{
				//Do not allow players to use ubercharge canteens if they are also unable to receive medigun charge effects
				int powerupBottle = SDKCall_GetEquippedWearableForLoadoutSlot(client, LOADOUT_POSITION_ACTION);
				if (powerupBottle != -1 && TF2Attrib_GetByName(powerupBottle, "ubercharge") != Address_Null)
				{
					ResetMannVsMachineMode();
					return Plugin_Handled;
				}
			}
		}
		else if(strcmp(section, "+inspect_server") == 0)
		{
			if(OnTouchUpgradeStation(-1, client) == Plugin_Continue)
			{
				SetEntProp(client, Prop_Send, "m_bInUpgradeZone", 1);
			}
		}
		else if(strcmp(section, "-inspect_server") == 0)
		{
			SetEntProp(client, Prop_Send, "m_bInUpgradeZone", 0);

			int currentWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			if(IsValidEntity(currentWeapon))
			{
				SetEntProp(currentWeapon, Prop_Send, "m_nInspectStage", -1);
				SetEntPropFloat(currentWeapon, Prop_Send, "m_flInspectAnimEndTime", 0.0);
			}
		}
	}

	return Plugin_Continue;
}

public void OnClientCommandKeyValues_Post(int client, KeyValues kv)
{
	if (IsMannVsMachineMode())
	{
		ResetMannVsMachineMode();
	}
}

public void TF2_OnConditionAdded(int client, TFCond condition)
{
	if (condition == TFCond_UberchargedCanteen)
	{
		//Prevent players from receiving uber canteens if they are unable to be ubered by mediguns
		if (!SDKCall_CanRecieveMedigunChargeEffect(GetPlayerShared(client), MEDIGUN_CHARGE_INVULN))
		{
			TF2_RemoveCondition(client, condition);
		}
	}
}

public Action EntityOutput_OnTimer10SecRemain(const char[] output, int caller, int activator, float delay)
{
	if (mvm_enable_music.BoolValue)
	{
		if (GameRules_GetProp("m_bInSetup"))
		{
			EmitGameSoundToAll("music.mvm_start_mid_wave");
		}
	}

	return Plugin_Continue;
}

public Action NormalSoundHook(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	Action action = Plugin_Continue;

	if (IsValidEntity(entity))
	{
		char classname[32];
		if (GetEntityClassname(entity, classname, sizeof(classname)))
		{
			//Make revive markers and money pickups silent for the other team
			if (strcmp(classname, "entity_revive_marker") == 0 || strncmp(classname, "item_currencypack", 17) == 0)
			{
				for (int i = 0; i < numClients; i++)
				{
					int client = clients[i];
					if (TF2_GetClientTeam(client) != TF2_GetTeam(entity) && TF2_GetClientTeam(client) != TFTeam_Spectator)
					{
						for (int j = i; j < numClients - 1; j++)
						{
							clients[j] = clients[j + 1];
						}

						numClients--;
						i--;
						action = Plugin_Changed;
					}
				}
			}
		}
	}

	if(StrEqual(SOUND_BUY_UPGRADE, sample)
		&& IsValidClient(entity)
		&& (/*CheckRoundState() < 1 ||*/ GetEntProp(entity, Prop_Send, "m_bInUpgradeZone") == 0))
		return Plugin_Handled;

	return action;
}

public int MenuHandler_UpgradeRespec(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			MvMPlayer(param1).RespecMenu = null;

			if(CheckRoundState() == 1)	return 0;

			if(GetEntProp(param1, Prop_Send, "m_bInUpgradeZone") == 0)
			{
				PrintToChat(param1, "%T", "MvM_RefundOnMenu", param1);
				return 0;
			}

			char info[64];
			if (menu.GetItem(param2, info, sizeof(info)))
			{
				if (strcmp(info, "respec") == 0)
				{
					// FIXME: 사용한 수통은 초기화되지 않고 자금 사용량에서 차감되지도 않음
					// MvMPlayer(param1).Currency += spentCurrency;
					MvMPlayer(param1).Currency = mvm_starting_currency.IntValue;

					MvMPlayer(param1).RemoveAllUpgrades();
					SetEntProp(param1, Prop_Send, "m_bInUpgradeZone", false);
/*
					int populator = FindEntityByClassname(MaxClients + 1, "info_populator");
					if (populator != -1)
					{
						//This should put us at the right currency, given that we've removed item and player upgrade tracking by this point
						// int totalAcquiredCurrency = MvMTeam(TF2_GetClientTeam(param1)).AcquiredCredits + mvm_starting_currency.IntValue;
						// int spentCurrency = SDKCall_GetPlayerCurrencySpent(populator, param1);
						// MvMPlayer(param1).Currency = totalAcquiredCurrency - spentCurrency;	
					}
*/
				}
			}
		}
		case MenuAction_Cancel:
		{
			MvMPlayer(param1).RespecMenu = null;
		}
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_DisplayItem:
		{
			char info[64], display[128];
			if (menu.GetItem(param2, info, sizeof(info), _, display, sizeof(display)))
			{
				Format(display, sizeof(display), "%t", display);
				return RedrawMenuItem(display);
			}
		}
	}

	return 0;
}
