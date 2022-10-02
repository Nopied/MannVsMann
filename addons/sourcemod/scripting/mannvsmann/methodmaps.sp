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

static int g_PlayerTeamCount[MAXPLAYERS + 1];
static TFTeam g_PlayerTeam[MAXPLAYERS + 1][8];
static Menu g_PlayerRespecMenu[MAXPLAYERS + 1];
static float g_flPlayerCarteenCooldown[MAXPLAYERS+1];
static float g_flReviveThinkCooldown[MAXPLAYERS+1];

static int g_TeamAcquiredCredits[view_as<int>(TFTeam_Blue) + 1];
static int g_TeamWorldCredits[view_as<int>(TFTeam_Blue) + 1];

methodmap MvMPlayer
{
	public MvMPlayer(int client)
	{
		return view_as<MvMPlayer>(client);
	}

	property int Client
	{
		public get()
		{
			return view_as<int>(this);
		}
	}

	property Menu RespecMenu
	{
		public get()
		{
			return g_PlayerRespecMenu[this];
		}
		public set(Menu menu)
		{
			g_PlayerRespecMenu[this] = menu;
		}
	}

	property int Currency
	{
		public get()
		{
			return GetEntProp(this.Client, Prop_Send, "m_nCurrency");
		}
		public set(int val)
		{
			SetEntProp(this.Client, Prop_Send, "m_nCurrency", val);
		}
	}

	property float CarteenCooldown
	{
		public get()
		{
			return g_flPlayerCarteenCooldown[this.Client];
		}
		public set(float time)
		{
			g_flPlayerCarteenCooldown[this.Client] = time;
		}
	}

	property float ReviveThinkCooldown
	{
		public get()
		{
			return g_flReviveThinkCooldown[this.Client];
		}
		public set(float time)
		{
			g_flReviveThinkCooldown[this.Client] = time;
		}
	}

	public void SetTeam(TFTeam team)
	{
		int count = ++g_PlayerTeamCount[this];
		g_PlayerTeam[this][count - 1] = TF2_GetClientTeam(this.Client);
		TF2_SetTeam(this.Client, team);
	}

	public void ResetTeam()
	{
		int count = g_PlayerTeamCount[this]--;
		TF2_SetTeam(this.Client, g_PlayerTeam[this][count - 1]);
	}

	public void RemoveAllUpgrades()
	{
		//This clears the upgrade history and removes upgrade attributes from the player and their items
		KeyValues respec = new KeyValues("MVM_Respec");
		FakeClientCommandKeyValues(this.Client, respec);
		delete respec;
	}
}

methodmap MvMTeam
{
	public MvMTeam(TFTeam team)
	{
		return view_as<MvMTeam>(team);
	}

	property int AcquiredCredits
	{
		public get()
		{
			return g_TeamAcquiredCredits[this];
		}
		public set(int val)
		{
			g_TeamAcquiredCredits[this] = val;
		}
	}

	property int WorldCredits
	{
		public get()
		{
			return g_TeamWorldCredits[this];
		}
		public set(int val)
		{
			g_TeamWorldCredits[this] = val;
		}
	}
}

enum // CTFSpawnPoint_Items
{
	CTFSpawnPoint_Index = 0,
	CTFSpawnPoint_Team,

	CTFSpawnPoint_PosX,
	CTFSpawnPoint_PosZ,
	CTFSpawnPoint_PosY,

	CTFSpawnPoint_Item_MAX
};

methodmap CTFSpawnPoint < ArrayList
{
	 public CTFSpawnPoint(int index, int team)
	 {
		CTFSpawnPoint array =
			view_as<CTFSpawnPoint>(new ArrayList());

		array.Push(index);
		array.Push(team);
		return array;
	 }

	 property int Index
	 {
		 public get()
		 {
			 return this.Get(view_as<int>(CTFSpawnPoint_Index));
		 }
		 public set(int index)
		 {
			 this.Set(view_as<int>(CTFSpawnPoint_Index), index);
		 }
	 }
	 property int Team
	 {
		 public get()
		 {
			 return this.Get(view_as<int>(CTFSpawnPoint_Team));
		 }
		 public set(int team)
		 {
			 this.Set(view_as<int>(CTFSpawnPoint_Team), team);
		 }
	 }

	 public void GetPos(float pos[3])
	 {
		int index;
		for(int loop = CTFSpawnPoint_PosX; loop <= CTFSpawnPoint_PosY; loop++)
		{
			index = loop - CTFSpawnPoint_PosX;
			pos[index] = this.Get(loop);
		}
	 }

	 public void SetPos(float pos[3])
	 {
		int index;
		for(int loop = CTFSpawnPoint_PosX; loop <= CTFSpawnPoint_PosY; loop++)
		{
			index = loop - CTFSpawnPoint_PosX;
			this.Set(loop, pos[index]);
		}
	 }
}

enum // CTFUpgradeStation_Items
{
	CTFUpgradeStation_Index = 0,

	CTFUpgradeStation_PosX,
	CTFUpgradeStation_PosZ,
	CTFUpgradeStation_PosY,

	CTFUpgradeStation_PropTimer,

	CTFUpgradeStation_Item_MAX
};

methodmap CTFUpgradeStation < ArrayList
{
	 public CTFUpgradeStation(int index, float pos[3])
	 {
		CTFUpgradeStation array =
			view_as<CTFUpgradeStation>(new ArrayList(16, CTFUpgradeStation_Item_MAX));

		array.Push(index);

		array.Set(CTFUpgradeStation_PosX, pos[0]);
		array.Set(CTFUpgradeStation_PosZ, pos[1]);
		array.Set(CTFUpgradeStation_PosY, pos[2]);

		return array;
	 }

	 property int Index
	 {
		 public get()
		 {
			 return this.Get(CTFUpgradeStation_Index);
		 }
		 public set(int index)
		 {
			 this.Set(CTFUpgradeStation_Index, index);
		 }
	 }

	 property Handle PropTimer
	 {
		 public get()
		 {
			 return this.Get(CTFUpgradeStation_PropTimer);
		 }
		 public set(Handle propTimer)
		 {
			 this.Set(CTFUpgradeStation_PropTimer, propTimer);
		 }
	 }

	 public void GetPos(float pos[3])
	 {
		int index;
		for(int loop = CTFUpgradeStation_PosX; loop <= CTFUpgradeStation_PosY; loop++)
		{
			index = loop - CTFUpgradeStation_PosX;
			pos[index] = this.Get(loop);
		}
	 }

	 public void SetPos(float pos[3])
	 {
		int index;
		for(int loop = CTFUpgradeStation_PosX; loop <= CTFUpgradeStation_PosY; loop++)
		{
			index = loop - CTFUpgradeStation_PosX;
			this.Set(loop, pos[index]);
		}
	 }
}

enum CornerList_Items
{
	CornerList_StartPosX = 0,
	CornerList_StartPosZ,
	CornerList_StartPosY,

	CornerList_EndPosX,
	CornerList_EndPosZ,
	CornerList_EndPosY,

	CornerList_Items_MAX
};

methodmap CornerList < ArrayList
{
	 public CornerList(float startPos[3], float endPos[3])
	 {
		CornerList array =
			view_as<CornerList>(new ArrayList());

		for(int pos = 0; pos < 3; pos++)
			array.Push(startPos[pos]);

		for(int pos = 0; pos < 3; pos++)
			array.Push(endPos[pos]);

		return array;
	 }

	 public void GetStartPos(float pos[3])
	 {
		 for(int loop = 0; loop < 3; loop++)
		 	pos[loop] = this.Get(view_as<int>(CornerList_StartPosX) + loop);
	 }

	 public void GetEndPos(float pos[3])
	 {
		 for(int loop = 0; loop < 3; loop++)
 			pos[loop] = this.Get(view_as<int>(CornerList_EndPosX) + loop);
	 }
}
