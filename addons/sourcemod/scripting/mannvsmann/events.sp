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

#define UPGRADE_SIGN_MODEL	"models/props_mvm/mvm_upgrade_tools.mdl"

// ArrayList g_hStationList;

void Events_Initialize()
{
	HookEvent("teamplay_broadcast_audio", Event_TeamplayBroadcastAudio, EventHookMode_Pre);
	HookEvent("teamplay_round_win", Event_TeamplayRoundWin);
	HookEvent("teamplay_restart_round", Event_TeamplayRestartRound);
	HookEvent("teamplay_setup_finished", Event_TeamplaySetupFinished);
	HookEvent("teamplay_round_start", Event_TeamplayRoundStart);
	HookEvent("post_inventory_application", Event_PostInventoryApplication);

	HookEvent("player_spawn", Event_PlayerSpawn_Pre, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn_Post, EventHookMode_Post);

	HookEvent("player_death", Event_PlayerDeath);
	// HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_buyback", Event_PlayerBuyback, EventHookMode_Pre);
	HookEvent("player_used_powerup_bottle", Event_PlayerUsedPowerupBottle, EventHookMode_Pre);

	HookEvent("arena_round_start", Event_RoundStart);
	HookEvent("teamplay_round_active", Event_RoundStart); // for non-arena maps
}

public Action Event_TeamplayBroadcastAudio(Event event, const char[] name, bool dontBroadcast)
{
	if (mvm_enable_music.BoolValue)
	{
		char sound[PLATFORM_MAX_PATH];
		event.GetString("sound", sound, sizeof(sound));

		if (strncmp(sound, "Game.TeamRoundStart", 19) == 0)
		{
			event.SetString("sound", "Announcer.MVM_Get_To_Upgrade");
			return Plugin_Changed;
		}
		if (strcmp(sound, "Game.YourTeamWon") == 0)
		{
			event.SetString("sound", "music.mvm_end_mid_wave");
			return Plugin_Changed;
		}
		else if (strcmp(sound, "Game.YourTeamLost") == 0 || strcmp(sound, "Game.Stalemate") == 0)
		{
			event.SetString("sound", "music.mvm_lost_wave");
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}


public void Event_TeamplayRoundWin(Event event, const char[] name, bool dontBroadcast)
{
	//NOTE: teamplay_round_start fires too late for us to reset player upgrades.
	//Instead we hook this event to reset everything in a RoundRespawn hook.
	g_ForceMapReset = event.GetBool("full_round") && mvm_reset_on_round_end.BoolValue;
/*
	for(int loop = 0; loop < g_hStationList.Length; loop++)
	{
		CTFUpgradeStation station = g_hStationList.Get(loop);

		delete station.PropTimer;
		station.PropTimer = null;
	}
*/
}

public void Event_TeamplayRestartRound(Event event, const char[] name, bool dontBroadcast)
{
	g_ForceMapReset = true;
}

public void Event_TeamplaySetupFinished(Event event, const char[] name, bool dontBroadcast)
{
	int resource = FindEntityByClassname(MaxClients + 1, "tf_objective_resource");
	if (resource != -1)
	{
		//Disallow selling individual upgrades
		SetEntProp(resource, Prop_Send, "m_nMannVsMachineWaveCount", 2);

		//Disable faster rage gain on heal
		SetEntProp(resource, Prop_Send, "m_bMannVsMachineBetweenWaves", false);
	}
}

public void Event_TeamplayRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	//Allow players to sell individual upgrades during setup
	int resource = FindEntityByClassname(MaxClients + 1, "tf_objective_resource");
	if (resource != -1)
	{
		if (GameRules_GetProp("m_bInSetup"))
		{
			//Allow selling individual upgrades
			SetEntProp(resource, Prop_Send, "m_nMannVsMachineWaveCount", 1);

			//Enable faster rage gain on heal
			SetEntProp(resource, Prop_Send, "m_bMannVsMachineBetweenWaves", true);
		}
		else
		{
			SetEntProp(resource, Prop_Send, "m_nMannVsMachineWaveCount", 2);
			SetEntProp(resource, Prop_Send, "m_bMannVsMachineBetweenWaves", false);
		}
	}

	for(int client = 1; client <= MaxClients; client++)
	{
		MvMPlayer(client).ReviveThinkCooldown = 0.0;

		if(!IsClientInGame(client))		continue;

		TFClassType class = TF2_GetPlayerClass(client);
		TF2_SetPlayerClass(client, TFClass_Unknown);
		TF2_SetPlayerClass(client, class);
	}
}

public void Event_PostInventoryApplication(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (TF2_GetPlayerClass(client) == TFClass_Medic)
	{
		//Allow medics to revive
		TF2Attrib_SetByName(client, "revive", 1.0);
	}
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	TFTeam team = view_as<TFTeam>(event.GetInt("team"));

	if (team > TFTeam_Spectator)
	{
		SetEntProp(client, Prop_Send, "m_bInUpgradeZone", true);
		MvMPlayer(client).RemoveAllUpgrades();
		SetEntProp(client, Prop_Send, "m_bInUpgradeZone", false);

		int populator = FindEntityByClassname(MaxClients + 1, "info_populator");
		if (populator != -1)
		{
			//This should put us at the right currency, given that we've removed item and player upgrade tracking by this point
			int totalAcquiredCurrency = MvMTeam(team).AcquiredCredits + mvm_starting_currency.IntValue;
			int spentCurrency = SDKCall_GetPlayerCurrencySpent(populator, client);
			MvMPlayer(client).Currency = totalAcquiredCurrency - spentCurrency;
		}
	}
}

public void Event_PlayerSpawn_Pre(Event event, const char[] name, bool dontBroadcast)
{
	SetMannVsMachineMode(true);
}

public void Event_PlayerSpawn_Post(Event event, const char[] name, bool dontBroadcast)
{
	ResetMannVsMachineMode();
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	SDKCall_ReapplyPlayerUpgrades(client);
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if(CheckRoundState() != 1)		return;

	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int weaponid = event.GetInt("weaponid");
	int death_flags = event.GetInt("death_flags");
	bool silent_kill = event.GetBool("silent_kill");

	int amount = mvm_currency_rewards_player_killed.IntValue;
	bool deathpenalty = mvm_currency_death_penalty.BoolValue;

	if(IsValidClient(attacker) && !(death_flags & TF_DEATHFLAG_DEADRINGER))
	{
		//Create currency pack
		bool forceDistribute = TF2_GetPlayerClass(attacker) == TFClass_Sniper
			&& WeaponID_IsSniperRifleOrBow(weaponid);

		int forcedVictimTeam = mvm_force_currency_victim_team.IntValue;
		//CTFPlayer::DropCurrencyPack does not assign a team to the currency pack but CTFGameRules::DistributeCurrencyAmount needs to know it

		if(forcedVictimTeam > 1)
		{
			if(view_as<int>(TF2_GetClientTeam(victim)) != forcedVictimTeam)
				return;

			g_CurrencyPackTeam = TF2_GetClientTeam(victim);
		}
		else
			g_CurrencyPackTeam = TF2_GetClientTeam(attacker);

		SetMannVsMachineMode(true);
		if(deathpenalty && MvMPlayer(victim).Currency > 0)
		{
			int alive = GetAlivePlayers(GetClientTeam(victim), false);
			int currentMoney = MvMPlayer(victim).Currency / (alive > 0 ? alive : 1);
			MvMPlayer(victim).Currency = 0;

			while(currentMoney > 0)
			{
				if(currentMoney >= 100)
					SDKCall_DropCurrencyPack(victim, TF_CURRENCY_PACK_CUSTOM, 100);
				else
					SDKCall_DropCurrencyPack(victim, TF_CURRENCY_PACK_CUSTOM, currentMoney);

				currentMoney -= 100;
			}
		}

		if(IsValidClient(attacker) && victim != attacker
			&& amount > 0)
		{
			float multiplier = (mvm_currency_rewards_player_count_bonus.FloatValue - 1.0) / MaxClients * (MaxClients - GetClientCount(true));
			amount += RoundToCeil(mvm_currency_rewards_player_killed.IntValue * multiplier);

			//Enable MvM so money earned by Snipers gets force-distributed
			if (forceDistribute)
				SDKCall_DropCurrencyPack(victim, TF_CURRENCY_PACK_CUSTOM, amount, forceDistribute, attacker);
			else
				SDKCall_DropCurrencyPack(victim, TF_CURRENCY_PACK_CUSTOM, amount);
		}
		ResetMannVsMachineMode();

		if (mvm_drop_revivemarker.BoolValue && !(death_flags & TF_DEATHFLAG_DEADRINGER) && !silent_kill)
		{
			//Create revive marker
			SetEntDataEnt2(victim, GetOffset("CTFPlayer", "m_hReviveMarker"), SDKCall_ReviveMarkerCreate(victim));
		}
	}
}

public Action Event_PlayerBuyback(Event event, const char[] name, bool dontBroadcast)
{
	int player = event.GetInt("player");

	//Only broadcast to spectators and our own team
	event.BroadcastDisabled = true;

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && (TF2_GetClientTeam(client) == TF2_GetClientTeam(player) || TF2_GetClientTeam(client) == TFTeam_Spectator))
		{
			event.FireToClient(client);
		}
	}

	return Plugin_Changed;
}

public Action Event_PlayerUsedPowerupBottle(Event event, const char[] name, bool dontBroadcast)
{
/*
	// Only broadcast to spectators and our own team (notice on chat)
	event.BroadcastDisabled = true;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client)  && (TF2_GetClientTeam(client) == TF2_GetClientTeam(player) || TF2_GetClientTeam(client) == TFTeam_Spectator))
		{
			event.FireToClient(client);
		}
	}
*/
	int player = event.GetInt("player");
	int medigun = GetPlayerWeaponSlot(player, TFWeaponSlot_Secondary);

	if(IsValidEntity(medigun) && HasEntProp(medigun, Prop_Send, "m_hHealingTarget"))
	{
		int currentHeal = GetEntProp(medigun, Prop_Send, "m_hHealingTarget") & 0xff;
		if((0 < currentHeal && currentHeal <= MaxClients) && TF2_GetClientTeam(player) != TF2_GetClientTeam(currentHeal))
		{
			SetEntProp(medigun, Prop_Send, "m_hHealingTarget", -1);
		}
	}

	return Plugin_Changed;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for(int client = 1; client <= MaxClients; client++)
	{
		MvMPlayer(client).CarteenCooldown = 0.0;
	}
}
