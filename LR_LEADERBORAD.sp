
/*	Copyright (C) 2017 IT-KiLLER
	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.
	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.
	
	You should have received a copy of the GNU General Public License
	along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <lastrequest>
#pragma semicolon 1
#pragma newdecls required
#define PLUGIN_DB "lr-leaderboard"
int iMostLRRound[MAXPLAYERS+1] = {0,...};
int bPlayersInLR[MAXPLAYERS+1][MAXPLAYERS+1];

public Plugin myinfo =
{
	name = "Last-Request: LEADERBOARD",
	author = "IT-KiLLER",
	description = "An LR addons for sm hosties.",
	version = "1.0",
	url = "https://github.com/IT-KiLLER"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_lrtop", Command_LRTopListMenu, "Leaderboard");
	RegServerCmd("sm_clearlrtop", Command_CLEARSQL, "Emptying the leaderboard.");
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Pre);
}

public Action Command_CLEARSQL(int args)
{	
	dbExecute("delete from leaderboard;");
	PrintToServer("[SM] Emptying the leaderboard.");
	return Plugin_Handled;
}

public Action Command_LRTopListMenu(int client, int arg)
{
	buildMenu(client);
	return Plugin_Handled;
}

public void OnAllPluginsLoaded()
{
	if(!SQL_CheckConfig(PLUGIN_DB)) 
	{
		SetFailState("[LR-LEADERBOARD] DATABASE ERROR");
	}
	else
	{
		if(dbExecute("CREATE TABLE IF NOT EXISTS leaderboard (id INTEGER PRIMARY KEY AUTOINCREMENT, name varchar(64) NOT NULL DEFAULT ' ', steamid varchar(64) NOT NULL UNIQUE, eligible_lr INTEGER DEFAULT '0', start_lr INTEGER DEFAULT '0', won_lr INTEGER DEFAULT '0', most_lr INTEGER DEFAULT '0', guards_beaten INTEGER DEFAULT '0');"))
		{
			PrintToServer("[LR-LEADERBOARD] DATABAS CREATED");
		}
	}
}

Database Connect()
{
	char error[255];
	Database db;
	
	if (SQL_CheckConfig(PLUGIN_DB))
	{
		db = SQL_Connect(PLUGIN_DB, true, error, sizeof(error));
	} else {
		SetFailState("[LR-LEADERBOARD] DATABASE.CFG error");
	}
	
	if (db == null)
	{
		LogError("Could not connect to database: %s", error);
	}
	
	return db;
}


public int OnStartLR(int PrisonerIndex, int GuardIndex, int LRType)
{
	bPlayersInLR[GuardIndex][PrisonerIndex] = true;
	dbIncrease_StartLR(PrisonerIndex);
}

public int OnAvailableLR(int Announced)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == CS_TEAM_T)
		{
			dbIncrease_EligibleLR(client);
		}
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(!client) return;

	bool bClientInLR = client && view_as<bool>(IsClientInLastRequest(client));
	bool bAttaclerInLR = attacker && view_as<bool>(IsClientInLastRequest(attacker));

	// LR REBEL dies
	if(bPlayersInLR[client][client])
	{
		bPlayersInLR[client][client] = false;
		return;
	}

	// LR REBEL kills a guard
	if(bPlayersInLR[attacker][attacker])
	{
		dbIncrease_Guardbeaten(attacker);
		return;
	}

	// LR prisoner kills a guard
	if(bClientInLR && bAttaclerInLR && GetClientTeam(client) == CS_TEAM_CT && GetClientTeam(attacker) == CS_TEAM_T)
	{
		dbIncrease_Guardbeaten(attacker);
		dbIncrease_WonLR(attacker);
		dbIncrease_MostLR(attacker, ++iMostLRRound[attacker]);
		return;
	}

	// LR (disconnect / suicide / slay or LR Slay)
	if(bClientInLR && GetClientTeam(client) == CS_TEAM_CT)
	{
		for (int prisoner = 1; prisoner <= MaxClients; prisoner++)
		{
			if(bPlayersInLR[client][prisoner])
			{
				dbIncrease_WonLR(prisoner);
				dbIncrease_MostLR(prisoner, ++iMostLRRound[prisoner]);
				bPlayersInLR[client][prisoner] = false;
				break;
			}
		}
		return;
	}
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for (int client = 0; client <= MaxClients; client++)
	{
		iMostLRRound[client] = 0;
		if(bPlayersInLR[client][client])
		{
			dbIncrease_WonLR(client);
			dbIncrease_MostLR(client, ++iMostLRRound[client]);
		}
		for (int target = 0; target <= MaxClients; target++)
		{
			bPlayersInLR[client][target] = false;
		}
	}
}

stock void buildMenu(int client)
{
	if(!client) return;
	DBStatement stmt = dbResult("Select name, steamid, start_lr, won_lr, guards_beaten from leaderboard order by guards_beaten desc limit 30"); 
	char sName[64];
	char sSteamID[64];
	int iGuardsBeaten;
	int iStart_lr = 0;
	int iWon_lr = 0;
	char sFormat[250];
	float fSucessRate;
	
	Menu menu = new Menu(LRTopMenuHandler);
	menu.SetTitle("[LR LEADERBOARD]");
	while(SQL_FetchRow(stmt))
	{
		SQL_FetchString(stmt, 0, sName, sizeof(sName));
		SQL_FetchString(stmt, 1, sSteamID, sizeof(sSteamID));
		iStart_lr = SQL_FetchInt(stmt, 2);
		iWon_lr = SQL_FetchInt(stmt, 3);
		iGuardsBeaten = SQL_FetchInt(stmt, 4);
		fSucessRate=  (iStart_lr > 0) ? (float(iWon_lr)/float(iStart_lr))*100 : 0.0;
		FormatEx(sFormat, sizeof(sFormat), "%s (GB %d | %0.0f%% Won)", sName, iGuardsBeaten, fSucessRate);
		menu.AddItem(sSteamID, sFormat);
	}
	delete stmt;
	if(menu.ItemCount==0)
	{
		PrintToChat(client, "[SM] No players are in the top list.");
		delete menu;
		return;
	}
	if(menu.ItemCount>7)
	{
		menu.ExitBackButton = true;
	}
	menu.ExitButton = true;
	menu.Display(client, 45);
}

public int LRTopMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char sSteamID[32];
		menu.GetItem(param2, sSteamID, sizeof(sSteamID));
		if(param2 != -1)
		{
			char sText[300];
			char queryString[1][64];
			queryString[0] = sSteamID;
			DBStatement stmt = dbResultData("Select name, eligible_lr, start_lr, won_lr, most_lr, guards_beaten from leaderboard where steamid=? limit 1", queryString, 1); 
			char sName[64];
			int iEligible_lr = 0;
			int iStart_lr = 0;
			int iWon_lr = 0;
			int iMost_lr = 0;
			int iGuards_beaten = 0;
			
			if (stmt !=null && SQL_HasResultSet(stmt))
			{
				SQL_FetchString(stmt, 0, sName, sizeof(sName));
				iEligible_lr = SQL_FetchInt(stmt, 1);
				iStart_lr = SQL_FetchInt(stmt, 2);
				iWon_lr = SQL_FetchInt(stmt, 3);
				iMost_lr = SQL_FetchInt(stmt, 4);
				iGuards_beaten = SQL_FetchInt(stmt, 5);
				float fSucessRate =  (iStart_lr > 0) ? (float(iWon_lr)/float(iStart_lr))*100 : 0.0;
				Format(sText, sizeof(sText), "Player: %s\nEligible: %d\nStarted: %d\nWon: %d\nLR success rate: %0.0f%%\nMost LR per round: %d\nGuards beaten: %d\n", sName, iEligible_lr, iStart_lr, iWon_lr, fSucessRate, iMost_lr, iGuards_beaten);
			}
			else
			{
				PrintToChat(param1, "[SM] The player could not be found.");
				delete stmt;
				return;
			}
			delete stmt;
			Panel pTemp = new Panel();
			SetPanelTitle(pTemp,"[LR-LEADERBOARD]");
			DrawPanelText(pTemp,sText);
			DrawPanelItem(pTemp,"Back");
			pTemp.Send(param1, PanelHandler1, MENU_TIME_FOREVER);
			delete pTemp;
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public int PanelHandler1(Menu menu, MenuAction action, int param1, int param2)
{
	buildMenu(param1);
	delete menu;
}

stock bool dbIncrease_EligibleLR(int client)
{
	char sSteamId[64];
	char sName[64];
	GetClientName(client, sName, 64);
	if (!GetClientAuthId(client, AuthId_Steam2, sSteamId, sizeof(sSteamId), false))
	{
		// Unknown SteamID
		return false;
	}
	ReplaceString(sSteamId, sizeof(sSteamId), "STEAM_", "", true);
	char queryString[2][64];
	queryString[0] = sName;
	queryString[1] = sSteamId;
	if(!dbExecuteData("INSERT INTO leaderboard (name, steamid, eligible_lr) VALUES (?, ?, 1);", queryString, 2))
	{
		return dbExecuteData("UPDATE leaderboard SET name=?, eligible_lr=eligible_lr+1 WHERE steamid=?;", queryString, 2);
	}
	return true;
}


stock bool dbIncrease_StartLR(int client)
{
	char sSteamId[64];
	char sName[64];
	GetClientName(client, sName, 64);
	if (!GetClientAuthId(client, AuthId_Steam2, sSteamId, sizeof(sSteamId), false))
	{
		// Unknown SteamID
		return false;
	}
	ReplaceString(sSteamId, sizeof(sSteamId), "STEAM_", "", true);
	char queryString[2][64];
	queryString[0] = sName;
	queryString[1] = sSteamId;
	if(dbExecuteData("UPDATE leaderboard SET name=?, start_lr=start_lr+1 WHERE steamid=?;", queryString, 2))
	{
		return true;
	}
	return dbExecuteData("INSERT INTO leaderboard (name, steamid, start_lr) VALUES (?, ?, 1);", queryString, 2);
}

stock bool dbIncrease_WonLR(int client)
{
	char sSteamId[64];
	char sName[64];
	GetClientName(client, sName, 64);
	if (!GetClientAuthId(client, AuthId_Steam2, sSteamId, sizeof(sSteamId), false))
	{
		// Unknown SteamID
		return false;
	}
	ReplaceString(sSteamId, sizeof(sSteamId), "STEAM_", "", true);
	char queryString[2][64];
	queryString[0] = sName;
	queryString[1] = sSteamId;
	if(dbExecuteData("UPDATE leaderboard SET name=?, won_lr=won_lr+1 WHERE steamid=?;", queryString, 2))
	{
		return true;
	}
	return dbExecuteData("INSERT INTO leaderboard (name, steamid, won_lr) VALUES (?, ?, 1);", queryString, 2);
}

stock bool dbIncrease_MostLR(int client, int MaxLR)
{
	char sSteamId[64];
	char sName[64];
	GetClientName(client, sName, 64);
	if (!GetClientAuthId(client, AuthId_Steam2, sSteamId, sizeof(sSteamId), false))
	{
		// Unknown SteamID
		return false;
	}
	ReplaceString(sSteamId, sizeof(sSteamId), "STEAM_", "", true);
	char queryString[4][64];
	queryString[0] = sName;
	FormatEx(queryString[1], 64, "%d", MaxLR);
	FormatEx(queryString[2], 64, "%d", MaxLR);
	queryString[3] = sSteamId;
	if(dbExecuteData("UPDATE leaderboard SET name=?, most_lr=(CASE WHEN ? > most_lr THEN ? ELSE most_lr END) WHERE steamid=?;", queryString, 4))
	{
		return true;
	}
	queryString[0] = sName;
	queryString[1] = sSteamId;
	return dbExecuteData("INSERT INTO leaderboard (name, steamid, most_lr) VALUES (?, ?, 1);", queryString, 2);
}

stock bool dbIncrease_Guardbeaten(int client)
{
	char sSteamId[64];
	char sName[64];
	GetClientName(client, sName, 64);
	if (!GetClientAuthId(client, AuthId_Steam2, sSteamId, sizeof(sSteamId), false))
	{
		// Unknown SteamID
		return false;
	}
	ReplaceString(sSteamId, sizeof(sSteamId), "STEAM_", "", true);
	char queryString[2][64];
	queryString[0] = sName;
	queryString[1] = sSteamId;
	if(dbExecuteData("UPDATE leaderboard SET name=?, guards_beaten=guards_beaten+1 WHERE steamid=?;", queryString, 2))
	{
		return true;
	}
	return dbExecuteData("INSERT INTO leaderboard (name, steamid, guards_beaten) VALUES (?, ?, 1);", queryString, 2);
}

stock bool dbExecute(const char[] queryString)
{
	char temp[][] = {""};
	return dbExecuteData(queryString, temp, 0);
}

stock bool dbExecuteData(const char[] queryString, char[][] queryData, int size)
{
	DBStatement stmt = null;
	Database db = Connect();
	bool bSuccess = true;
	if (stmt == null)
	{
		char error[255];
		stmt = SQL_PrepareQuery(db, queryString, error, sizeof(error));
		if (stmt == null)
		{
			PrintToServer("[LR-LEADERBOARD] SQL ERROR: %s", error);
			bSuccess = false;
		}
	}
	for(int i = 0; i < size; i++)
	{
		SQL_BindParamString(stmt, i, queryData[i], false);
	}
	if (!SQL_Execute(stmt))
	{
		bSuccess = false;
	}
	delete db;
	return bSuccess;
}
stock DBStatement dbResult(const char[] queryString)
{
	char temp[][] = {""};
	return dbResultData(queryString, temp, 0);
}

stock DBStatement dbResultData(const char[] queryString, char[][] queryData, int size)
{
	DBStatement stmt = null;
	Database db = Connect();
	if (stmt == null)
	{
		char error[255];
		stmt = SQL_PrepareQuery(db, queryString, error, sizeof(error));
		if (stmt == null)
		{
			PrintToServer("[LR-LEADERBOARD] SQL ERROR: %s", error);
		}
	}
	for(int i = 0; i < size; i++)
	{
		SQL_BindParamString(stmt, i, queryData[i], false);
	}
	if (!SQL_Execute(stmt))
	{
		stmt = null;
	}

	delete db;
	return stmt;
}