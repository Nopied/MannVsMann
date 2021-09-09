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

public void FloatToVector(float vector[3], float x, float z, float y)
{
	vector[0] = x, vector[1] = z, vector[2] = y;
}

stock float fmax(float x, float y)
{
	return x < y ? y : x;
}

stock float fmin(float x, float y)
{
	return x > y ? y : x;
}

bool WeaponID_IsSniperRifle(int weaponID)
{
	if (weaponID == TF_WEAPON_SNIPERRIFLE ||
		weaponID == TF_WEAPON_SNIPERRIFLE_DECAP ||
		weaponID == TF_WEAPON_SNIPERRIFLE_CLASSIC)
		return true;
	else
		return false;
}

bool WeaponID_IsSniperRifleOrBow(int weaponID)
{
	if (weaponID == TF_WEAPON_COMPOUND_BOW)
		return true;
	else
		return WeaponID_IsSniperRifle(weaponID);
}

bool IsValidClient(int client)
{
	return 0 < client <= MaxClients && IsClientInGame(client);
}

TFTeam TF2_GetTeam(int entity)
{
	return view_as<TFTeam>(GetEntProp(entity, Prop_Send, "m_iTeamNum"));
}

void TF2_SetTeam(int entity, TFTeam team)
{
	SetEntProp(entity, Prop_Send, "m_iTeamNum", team);
}

Address GetPlayerShared(int client)
{
	Address offset = view_as<Address>(GetEntSendPropOffs(client, "m_Shared", true));
	return GetEntityAddress(client) + offset;
}

int GetPlayerSharedOuter(Address playerShared)
{
	Address outer = view_as<Address>(LoadFromAddress(playerShared + view_as<Address>(g_OffsetPlayerSharedOuter), NumberType_Int32));
	return SDKCall_GetBaseEntity(outer);
}
/*
stock int GetIndexOfAccountID(int id)
{
	char auth[32], idString[3][32];
	for(int client = 1; client <= MaxClients; client++)
	{
		if(!IsClientInGame(client) || IsFakeClient(client))
			continue;

		GetClientAuthId(client, AuthId_Steam3, auth, 32);
		ExplodeString(auth, ":", idString, 3, 32);

		if(StringToInt(idString[2]) == id)
			return client;
	}
	return -1;
}
*/
stock int CheckRoundState()
{
	switch(GameRules_GetRoundState())
	{
		case RoundState_Init, RoundState_Pregame:
		{
			return -1;
		}
		case RoundState_StartGame, RoundState_Preround:
		{
			return 0;
		}
		case RoundState_RoundRunning, RoundState_Stalemate:  //Oh Valve.
		{
			return 1;
		}
		default:
		{
			return 2;
		}
	}
}

stock void LoadStationStats(char[] path)
{
	char F[PLATFORM_MAX_PATH];
	Format(F, sizeof(F), "scripts/items/%s.txt", path);

	PrecacheGeneric(F, true);
	AddFileToDownloadsTable(F);

	int edict = FindEntityByClassname(-1, "tf_gamerules");
	if(edict == -1)	return;

	Format(F, sizeof(F), "download/scripts/items/%s.txt", path);
	SetVariantString(F);
	AcceptEntityInput(edict, "SetCustomUpgradesFile");
}
