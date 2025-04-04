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

//Dynamic hook handles
static DynamicHook g_DHookMyTouch;
static DynamicHook g_DHookComeToRest;
static DynamicHook g_DHookValidTouch;
static DynamicHook g_DHookShouldRespawnQuickly;
static DynamicHook g_DHookRoundRespawn;

//Detour state
static RoundState g_PreHookRoundState;
static TFTeam g_PreHookTeam;	//Note: For clients, use the MvMPlayer methodmap

//Hook some functions
static bool g_bComeToRest = false;
// static bool g_bSpawning = false;

void DHooks_Initialize(GameData gamedata)
{
	CreateDynamicDetour(gamedata, "CNavMesh::GetNavArea", DHookCallback_GetNavArea_Pre);
	CreateDynamicDetour(gamedata, "CPopulationManager::Update", DHookCallback_PopulationManagerUpdate_Pre, _);
	CreateDynamicDetour(gamedata, "CPopulationManager::ResetMap", DHookCallback_PopulationManagerResetMap_Pre, DHookCallback_PopulationManagerResetMap_Post);
	CreateDynamicDetour(gamedata, "CTFGameRules::IsQuickBuildTime", DHookCallback_IsQuickBuildTime_Pre, DHookCallback_IsQuickBuildTime_Post);
	CreateDynamicDetour(gamedata, "CTFGameRules::CanPlayerUseRespec", DHookCallback_CanPlayerUseRespec_Pre, DHookCallback_CanPlayerUseRespec_Post);
	CreateDynamicDetour(gamedata, "CTFGameRules::DistributeCurrencyAmount", DHookCallback_DistributeCurrencyAmount_Pre, DHookCallback_DistributeCurrencyAmount_Post);
	CreateDynamicDetour(gamedata, "CTFPlayerShared::ConditionGameRulesThink", DHookCallback_ConditionGameRulesThink_Pre, DHookCallback_ConditionGameRulesThink_Post);
	CreateDynamicDetour(gamedata, "CTFPlayerShared::CanRecieveMedigunChargeEffect", DHookCallback_CanRecieveMedigunChargeEffect_Pre, DHookCallback_CanRecieveMedigunChargeEffect_Post);
	CreateDynamicDetour(gamedata, "CTFPlayerShared::RadiusSpyScan", DHookCallback_RadiusSpyScan_Pre, DHookCallback_RadiusSpyScan_Post);
	CreateDynamicDetour(gamedata, "CTFPlayer::CanBuild", DHookCallback_CanBuild_Pre, DHookCallback_CanBuild_Post);
	CreateDynamicDetour(gamedata, "CTFPlayer::RegenThink", DHookCallback_RegenThink_Pre, DHookCallback_RegenThink_Post);
	CreateDynamicDetour(gamedata, "CTFPlayer::Regenerate", DHookCallback_Regenerate_Pre);
	CreateDynamicDetour(gamedata, "CBaseObject::FindSnapToBuildPos", DHookCallback_FindSnapToBuildPos_Pre, DHookCallback_FindSnapToBuildPos_Post);
	CreateDynamicDetour(gamedata, "CBaseObject::ShouldQuickBuild", DHookCallback_ShouldQuickBuild_Pre, DHookCallback_ShouldQuickBuild_Post);
	CreateDynamicDetour(gamedata, "CObjectSapper::ApplyRoboSapperEffects", DHookCallback_ApplyRoboSapperEffects_Pre, DHookCallback_ApplyRoboSapperEffects_Post);
	CreateDynamicDetour(gamedata, "CTFPowerupBottle::AllowedToUse", _, DHookCallback_PowerupBottle_AllowedToUse_Post);
	CreateDynamicDetour(gamedata, "CWeaponMedigun::HealTargetThink", DHookCallback_Medigun_HealTargetThink_Pre, DHookCallback_Medigun_HealTargetThink_Post);
	CreateDynamicDetour(gamedata, "CWeaponMedigun::SubtractChargeAndUpdateDeployState", DHookCallback_Medigun_SubtractChargeAndUpdateDeployState_Pre);
//	CreateDynamicDetour(gamedata, "CPopulationManager::IsInEndlessWaves", DHookCallback_PopulationManager_IsInEndlessWaves);

	g_DHookMyTouch = CreateDynamicHook(gamedata, "CCurrencyPack::MyTouch");
	g_DHookComeToRest = CreateDynamicHook(gamedata, "CCurrencyPack::ComeToRest");
	g_DHookValidTouch = CreateDynamicHook(gamedata, "CTFPowerup::ValidTouch");
	g_DHookShouldRespawnQuickly = CreateDynamicHook(gamedata, "CTFGameRules::ShouldRespawnQuickly");
	g_DHookRoundRespawn = CreateDynamicHook(gamedata, "CTFGameRules::RoundRespawn");
}

void DHooks_HookGameRules()
{
	if (g_DHookShouldRespawnQuickly)
	{
		g_DHookShouldRespawnQuickly.HookGamerules(Hook_Pre, DHookCallback_ShouldRespawnQuickly_Pre);
		g_DHookShouldRespawnQuickly.HookGamerules(Hook_Post, DHookCallback_ShouldRespawnQuickly_Post);
	}

	if (g_DHookRoundRespawn)
	{
		g_DHookRoundRespawn.HookGamerules(Hook_Pre, DHookCallback_RoundRespawn_Pre);
		g_DHookRoundRespawn.HookGamerules(Hook_Post, DHookCallback_RoundRespawn_Post);
	}
}

void DHooks_OnEntityCreated(int entity, const char[] classname)
{
	if (strncmp(classname, "item_currencypack", 17) == 0)
	{
		if (g_DHookMyTouch)
		{
			g_DHookMyTouch.HookEntity(Hook_Pre, entity, DHookCallback_MyTouch_Pre);
			g_DHookMyTouch.HookEntity(Hook_Post, entity, DHookCallback_MyTouch_Post);
		}

		if (g_DHookComeToRest)
		{
			g_DHookComeToRest.HookEntity(Hook_Pre, entity, DHookCallback_ComeToRest_Pre);
			g_DHookComeToRest.HookEntity(Hook_Post, entity, DHookCallback_ComeToRest_Post);
		}

		if (g_DHookValidTouch)
		{
			g_DHookValidTouch.HookEntity(Hook_Pre, entity, DHookCallback_ValidTouch_Pre);
			g_DHookValidTouch.HookEntity(Hook_Post, entity, DHookCallback_ValidTouch_Post);
		}
	}
}

static void CreateDynamicDetour(GameData gamedata, const char[] name, DHookCallback callbackPre = INVALID_FUNCTION, DHookCallback callbackPost = INVALID_FUNCTION)
{
	DynamicDetour detour = DynamicDetour.FromConf(gamedata, name);
	if (detour)
	{
		if (callbackPre != INVALID_FUNCTION)
			detour.Enable(Hook_Pre, callbackPre);

		if (callbackPost != INVALID_FUNCTION)
			detour.Enable(Hook_Post, callbackPost);
	}
	else
	{
		LogError("Failed to create detour setup handle for %s", name);
	}
}

static DynamicHook CreateDynamicHook(GameData gamedata, const char[] name)
{
	DynamicHook hook = DynamicHook.FromConf(gamedata, name);
	if (!hook)
		LogError("Failed to create hook setup handle for %s", name);

	return hook;
}

public MRESReturn DHookCallback_GetNavArea_Pre(DHookReturn ret)
{
	if(mvm_block_using_nav.BoolValue && g_bComeToRest)
	{
		// Just not return NULL.
		ret.Value = 1;
		return MRES_Supercede;
	}

	g_bComeToRest = false;
	return MRES_Ignored;
}

public MRESReturn DHookCallback_PopulationManagerUpdate_Pre()
{
	//Prevents the populator from messing with the GC and allocating bots
	return MRES_Supercede;
}

public MRESReturn DHookCallback_PopulationManagerResetMap_Pre()
{
	//MvM defenders get their upgrades and stats reset on map reset, move all players to the defender team
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			MvMPlayer(client).SetTeam(TFTeam_Red);
		}
	}

	return MRES_Ignored;
}

public MRESReturn DHookCallback_PopulationManagerResetMap_Post()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			MvMPlayer(client).ResetTeam();
		}
	}

	return MRES_Ignored;
}

public MRESReturn DHookCallback_IsQuickBuildTime_Pre()
{
	//Allows Engineers to quickbuild during setup
	SetMannVsMachineMode(true);

	return MRES_Ignored;
}

public MRESReturn DHookCallback_IsQuickBuildTime_Post()
{
	ResetMannVsMachineMode();

	return MRES_Ignored;
}


public MRESReturn DHookCallback_CanPlayerUseRespec_Pre()
{
	//Enables respecs regardless of round state
	g_PreHookRoundState = GameRules_GetRoundState();
	GameRules_SetProp("m_iRoundState", RoundState_BetweenRounds);

	return MRES_Ignored;
}

public MRESReturn DHookCallback_CanPlayerUseRespec_Post()
{
	GameRules_SetProp("m_iRoundState", g_PreHookRoundState);
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_DistributeCurrencyAmount_Pre(DHookReturn ret, DHookParam params)
{
	if (IsMannVsMachineMode())
	{
		int amount = params.Get(1);
		bool shared = params.Get(3);

		if (shared)
		{
			//If the player is NULL, take the value of g_CurrencyPackTeam because our code has likely set it to something
			TFTeam team = params.IsNull(2) ? g_CurrencyPackTeam : TF2_GetClientTeam(params.Get(2));

			MvMTeam(team).AcquiredCredits += amount;

			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientInGame(client))
				{
					if (TF2_GetClientTeam(client) == team)
					{
						MvMPlayer(client).SetTeam(TFTeam_Red);
					}
					else
					{
						MvMPlayer(client).SetTeam(TFTeam_Blue);
					}

					EmitSoundToClient(client, SOUND_CREDITS_UPDATED, _, SNDCHAN_STATIC, SNDLEVEL_NONE, _, 0.1);
				}
			}
		}
		else if (!params.IsNull(2))
		{
			int player = params.Get(2);

			EmitSoundToClient(player, SOUND_CREDITS_UPDATED, _, SNDCHAN_STATIC, SNDLEVEL_NONE, _, 0.1);
		}
	}

	return MRES_Ignored;
}

public MRESReturn DHookCallback_DistributeCurrencyAmount_Post(DHookReturn ret, DHookParam params)
{
	if (IsMannVsMachineMode())
	{
		bool shared = params.Get(3);

		if (shared)
		{
			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientInGame(client))
				{
					MvMPlayer(client).ResetTeam();
				}
			}
		}
	}

	return MRES_Ignored;
}

public MRESReturn DHookCallback_ConditionGameRulesThink_Pre()
{
	//Enables radius currency collection, radius spy scan and increased rage gain during setup
	SetMannVsMachineMode(true);

	return MRES_Ignored;
}

public MRESReturn DHookCallback_ConditionGameRulesThink_Post()
{
	ResetMannVsMachineMode();

	return MRES_Ignored;
}

public MRESReturn DHookCallback_CanRecieveMedigunChargeEffect_Pre()
{
	//MvM allows flag carriers to be ubered, we don't want this (enabled from CTFPlayerShared::ConditionGameRulesThink)
	SetMannVsMachineMode(false);

	return MRES_Ignored;
}

public MRESReturn DHookCallback_CanRecieveMedigunChargeEffect_Post()
{
	ResetMannVsMachineMode();

	return MRES_Ignored;
}

public MRESReturn DHookCallback_RadiusSpyScan_Pre(Address playerShared)
{
	int outer = GetPlayerSharedOuter(playerShared);

	TFTeam team = TF2_GetClientTeam(outer);

	//RadiusSpyScan only allows defenders to see invaders, move all teammates to the defender team and enemies to the invader team
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			if (client == outer)
			{
				MvMPlayer(client).SetTeam(TFTeam_Red);
			}
			else
			{
				if (TF2_GetClientTeam(client) == team)
				{
					MvMPlayer(client).SetTeam(TFTeam_Red);
				}
				else
				{
					MvMPlayer(client).SetTeam(TFTeam_Blue);
				}
			}
		}
	}

	return MRES_Ignored;
}

public MRESReturn DHookCallback_RadiusSpyScan_Post(Address playerShared)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			MvMPlayer(client).ResetTeam();
		}
	}

	return MRES_Ignored;
}

public MRESReturn DHookCallback_CanBuild_Pre()
{
	//Limits the amount of sappers that can be placed on players
	SetMannVsMachineMode(true);

	return MRES_Ignored;
}

public MRESReturn DHookCallback_CanBuild_Post()
{
	ResetMannVsMachineMode();

	return MRES_Ignored;
}

public MRESReturn DHookCallback_RegenThink_Pre()
{
	//Health regeneration has no scaling in MvM
	SetMannVsMachineMode(true);

	return MRES_Ignored;
}

public MRESReturn DHookCallback_RegenThink_Post()
{
	ResetMannVsMachineMode();

	return MRES_Ignored;
}

public MRESReturn DHookCallback_Regenerate_Pre(int pThis)
{
	if(GetEntProp(pThis, Prop_Send, "m_bInUpgradeZone") > 0)
	{
		TF2Util_UpdatePlayerSpeed(pThis, true);
		return MRES_Supercede;
	}

	return MRES_Ignored;
}

public MRESReturn DHookCallback_FindSnapToBuildPos_Pre(int obj)
{
	//Allows placing sappers on other players
	SetMannVsMachineMode(true);

	int builder = GetEntPropEnt(obj, Prop_Send, "m_hBuilder");

	//The robot sapper only works on bots, give every player the fake client flag
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && client != builder)
		{
			SetEntityFlags(client, GetEntityFlags(client) | FL_FAKECLIENT);
		}
	}

	return MRES_Ignored;
}

public MRESReturn DHookCallback_FindSnapToBuildPos_Post(int obj)
{
	ResetMannVsMachineMode();

	int builder = GetEntPropEnt(obj, Prop_Send, "m_hBuilder");

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && client != builder)
		{
			SetEntityFlags(client, GetEntityFlags(client) & ~FL_FAKECLIENT);
		}
	}

	return MRES_Ignored;
}

public MRESReturn DHookCallback_ShouldQuickBuild_Pre(int obj)
{
	SetMannVsMachineMode(true);

	//Sentries owned by MvM defenders can be re-deployed quickly, move the sentry to the defender team
	g_PreHookTeam = TF2_GetTeam(obj);
	TF2_SetTeam(obj, TFTeam_Red);

	return MRES_Ignored;
}

public MRESReturn DHookCallback_ShouldQuickBuild_Post(int obj, DHookReturn ret)
{
	ResetMannVsMachineMode();

	TF2_SetTeam(obj, g_PreHookTeam);

	return MRES_Ignored;
}

public MRESReturn DHookCallback_ApplyRoboSapperEffects_Pre(int sapper, DHookReturn ret, DHookParam params)
{
	int target = params.Get(1);

	//Minibosses in MvM get slowed down instead of fully stunned
	SetEntProp(target, Prop_Send, "m_bIsMiniBoss", true);

	return MRES_Ignored;
}

public MRESReturn DHookCallback_ApplyRoboSapperEffects_Post(int sapper, DHookReturn ret, DHookParam params)
{
	int target = params.Get(1);
	SetEntProp(target, Prop_Send, "m_bIsMiniBoss", false);

	return MRES_Ignored;
}

public MRESReturn DHookCallback_MyTouch_Pre(int currencypack, DHookReturn ret, DHookParam params)
{
	int player = params.Get(1);

	//NOTE: You cannot substitute this virtual hook with SDKHooks because the Touch function for CItem is actually CItem::ItemTouch, and NOT CItem::MyTouch.
	//CItem::ItemTouch simply calls CItem::MyTouch and deletes the entity if it returns true, which causes a TouchPost SDKHook to never get called!

	//Allows Scouts to gain health from currency packs and distributes the currency
	SetMannVsMachineMode(true);

	//Enables money pickup voice lines
	SetVariantString("IsMvMDefender:1");
	AcceptEntityInput(player, "AddContext");

	return MRES_Ignored;
}

public MRESReturn DHookCallback_MyTouch_Post(int currencypack, DHookReturn ret, DHookParam params)
{
	int player = params.Get(1);

	ResetMannVsMachineMode();

	SetVariantString("IsMvMDefender");
	AcceptEntityInput(player, "RemoveContext");

	return MRES_Ignored;
}

public MRESReturn DHookCallback_ComeToRest_Pre(int currencypack)
{
	//Enable MvM for currency distribution
	SetMannVsMachineMode(true);

	//Set the currency pack team for distribution
	g_CurrencyPackTeam = TF2_GetTeam(currencypack);
	g_bComeToRest = true;

	return MRES_Ignored;
}

public MRESReturn DHookCallback_ComeToRest_Post()
{
	ResetMannVsMachineMode();

	g_CurrencyPackTeam = TFTeam_Invalid;

	return MRES_Ignored;
}

public MRESReturn DHookCallback_ValidTouch_Pre(int pThis, DHookReturn ret, DHookParam params)
{
	//MvM invaders are not allowed to collect money
	//We are disabling MvM instead of swapping teams because ValidTouch also checks the player's team against the currency pack's team
	SetMannVsMachineMode(false);

	int touchedPlayer = params.Get(1);
	Action action = Plugin_Continue;

	Call_StartForward(g_onTouchedMoney);
	Call_PushCell(pThis);
	Call_PushCell(touchedPlayer);
	Call_Finish(action);

	if(action == Plugin_Changed)
	{
		ret.Value = true;
		return MRES_Supercede;
	}
	else if(action == Plugin_Handled || action == Plugin_Stop)
	{
		ret.Value = false;
		return MRES_Supercede;
	}

	return MRES_Ignored;
}

public MRESReturn DHookCallback_ValidTouch_Post()
{
	ResetMannVsMachineMode();

	return MRES_Ignored;
}

public MRESReturn DHookCallback_ShouldRespawnQuickly_Pre(DHookReturn ret, DHookParam params)
{
	int player = params.Get(1);

	//Enables quick respawn for Scouts
	SetMannVsMachineMode(true);

	//MvM defenders are allowed to respawn quickly, move the player to the defender team
	MvMPlayer(player).SetTeam(TFTeam_Red);

	return MRES_Ignored;
}

public MRESReturn DHookCallback_ShouldRespawnQuickly_Post(DHookReturn ret, DHookParam params)
{
	int player = params.Get(1);

	ResetMannVsMachineMode();

	MvMPlayer(player).ResetTeam();

	return MRES_Ignored;
}

public MRESReturn DHookCallback_RoundRespawn_Pre()
{
	//NOTE: It is too late to run this logic in a teamplay_round_start event hook
	//since it depends on the state of the round before the call to RoundRespawn.

	//Switch team credits if the teams are being switched
	if (SDKCall_ShouldSwitchTeams())
	{
		int redCredits = MvMTeam(TFTeam_Red).AcquiredCredits;
		int blueCredits = MvMTeam(TFTeam_Blue).AcquiredCredits;

		MvMTeam(TFTeam_Red).AcquiredCredits = blueCredits;
		MvMTeam(TFTeam_Blue).AcquiredCredits = redCredits;
	}

	int populator = FindEntityByClassname(MaxClients + 1, "info_populator");
	if (populator != -1)
	{
		if (g_ForceMapReset)
		{
			g_ForceMapReset = !g_ForceMapReset;

			//Reset accumulated team credits on a full reset
			MvMTeam(TFTeam_Red).AcquiredCredits = 0;
			MvMTeam(TFTeam_Blue).AcquiredCredits = 0;

			//Reset currency for all clients
			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientInGame(client))
				{
					int spentCurrency = SDKCall_GetPlayerCurrencySpent(populator, client);
					SDKCall_AddPlayerCurrencySpent(populator, client, -spentCurrency);
					MvMPlayer(client).Currency = mvm_starting_currency.IntValue;
				}
			}

			//Reset player and item upgrades
			SDKCall_ResetMap(populator);
		}
		else
		{
			//Retain player upgrades (forces a call to CTFPlayer::ReapplyPlayerUpgrades)
			SetEntData(populator, GetOffset("CPopulationManager", "m_isRestoringCheckpoint"), true, 1);
		}
	}

	return MRES_Ignored;
}

public MRESReturn DHookCallback_RoundRespawn_Post()
{
	int populator = FindEntityByClassname(MaxClients + 1, "info_populator");
	if (populator != -1)
	{
		SetEntData(populator, GetOffset("CPopulationManager", "m_isRestoringCheckpoint"), false, 1);
	}

	return MRES_Ignored;
}

public MRESReturn DHookCallback_PowerupBottle_AllowedToUse_Post(int pThis, DHookReturn ret)
{
	if(pThis==-1)			return MRES_Ignored;

	int owner = GetEntPropEnt(pThis, Prop_Send, "m_hOwnerEntity");

	if(!IsPlayerAlive(owner)
	|| TF2_IsPlayerInCondition(owner, TFCond_Dazed))
		return MRES_Ignored;

	if(MvMPlayer(owner).CarteenCooldown > GetGameTime())
	{
		ret.Value = false;
		return MRES_ChangedOverride;
	}

	ret.Value = true;
	MvMPlayer(owner).CarteenCooldown = GetGameTime() + mvm_carteen_cooldown.FloatValue;

	return MRES_ChangedOverride;
}

int g_iHealthBeforeHeal = -1;
public MRESReturn DHookCallback_Medigun_HealTargetThink_Pre(int pThis)
{
	if(pThis==-1)			return MRES_Ignored;

	int owner = GetEntPropEnt(pThis, Prop_Send, "m_hOwnerEntity"),
		healingTarget = GetEntPropEnt(pThis, Prop_Send, "m_hHealingTarget");

	if(!IsValidEntity(healingTarget))		return MRES_Ignored;

	char classname[64];
	GetEntityClassname(healingTarget, classname, sizeof(classname));
	if(!IsPlayerAlive(owner) || !StrEqual(classname, "entity_revive_marker"))
		return MRES_Ignored;

	g_iHealthBeforeHeal = GetEntProp(healingTarget, Prop_Data, "m_iHealth");
	if(MvMPlayer(owner).ReviveThinkCooldown >= GetGameTime())
	{
		return MRES_Ignored;
	}

	return MRES_Ignored;
}

public MRESReturn DHookCallback_Medigun_HealTargetThink_Post(int pThis)
{
	int health = g_iHealthBeforeHeal;
	g_iHealthBeforeHeal = -1;

	if(pThis==-1)			return MRES_Ignored;

	int owner = GetEntPropEnt(pThis, Prop_Send, "m_hOwnerEntity"),
		healingTarget = GetEntPropEnt(pThis, Prop_Send, "m_hHealingTarget"),
		healed = GetEntProp(healingTarget, Prop_Data, "m_iHealth") - health;
	bool isCharging = GetEntProp(pThis, Prop_Send, "m_bChargeRelease") > 0;

	if(!IsValidEntity(healingTarget))		return MRES_Ignored;

	char classname[64];
	GetEntityClassname(healingTarget, classname, sizeof(classname));
	if(!IsPlayerAlive(owner) || !StrEqual(classname, "entity_revive_marker"))
		return MRES_Ignored;

	if(MvMPlayer(owner).ReviveThinkCooldown < GetGameTime())
	{
		// PrintToChatAll("%.3f, game time: %.3f, isCharging: %s", MvMPlayer(owner).ReviveThinkCooldown, GetGameTime(), isCharging ? "true" : "false");
		MvMPlayer(owner).ReviveThinkCooldown = GetGameTime() + 0.15;
	}
	else
	{
		SetEntProp(healingTarget, Prop_Data, "m_iHealth", health);
		return MRES_Ignored;
	}

	if(isCharging)
		SetEntProp(healingTarget, Prop_Data, "m_iHealth", health + (healed * 3));

	return MRES_Ignored;
}

public MRESReturn DHookCallback_Medigun_SubtractChargeAndUpdateDeployState_Pre(int pThis, DHookParam params)
{
	if(pThis==-1)			return MRES_Ignored;

	int owner = GetEntPropEnt(pThis, Prop_Send, "m_hOwnerEntity"),
		healingTarget = GetEntPropEnt(pThis, Prop_Send, "m_hHealingTarget");
	bool isCharging = GetEntProp(pThis, Prop_Send, "m_bChargeRelease") > 0;

	if(!IsValidEntity(healingTarget))		return MRES_Ignored;

	char classname[64];
	GetEntityClassname(healingTarget, classname, sizeof(classname));
	if(!IsPlayerAlive(owner) || !StrEqual(classname, "entity_revive_marker") || !isCharging)
		return MRES_Ignored;

	float flSubtractAmount = params.Get(1);
	params.Set(1, flSubtractAmount * 4.0);

	return MRES_ChangedOverride;
}

// public MRESReturn DHookCallback_PopulationManager_IsInEndlessWaves()
// {
// 	if(g_bSpawning)
// 		return MRES_Supercede;

// 	return MRES_Ignored;
// }