#include <sourcemod>
#include <sdktools>
#include <multicolors>

#pragma tabsize 0

KeyValues Kv;
StringMap g_smSteamID;

char FilePath[128], SteamID[32], ForcedName[64], OriginalName[64], CurrentName[64], NewName[64], AdminName[64], Time[32];

public Plugin myinfo =
{
	name = "ForcedName",
	author = "ire.",
	description = "Force a name on a player",
	version = "1.0"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_forcename", ForceName, ADMFLAG_BAN);
	RegAdminCmd("sm_forcednames", ForcedNames, ADMFLAG_BAN);
	
	HookEvent("player_changename", Event_ChangeName);
	
	LoadTranslations("common.phrases");
	LoadTranslations("forcedname.phrases");
}

public void OnMapStart()
{
	g_smSteamID = new StringMap();
	
	GetNamesFromCfg();
}

public void OnMapEnd()
{
	g_smSteamID.Clear();
	delete g_smSteamID;
	delete Kv;
}

public void OnClientPostAdminCheck(int client)
{
    if(!IsFakeClient(client))
	{
		CreateTimer(2.0, CheckClientName, GetClientUserId(client));
	}
}

public Action CheckClientName(Handle timer, userid)
{
    int client = GetClientOfUserId(userid);
	
	if(client)
	{
		if(GetClientAuthId(client, AuthId_Steam2, SteamID, sizeof(SteamID)) && g_smSteamID.GetString(SteamID, ForcedName, sizeof(ForcedName)))
		{
			SetClientName(client, ForcedName);
		}	
	}
}

public void Event_ChangeName(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(!IsFakeClient(client)) 
	{
		event.GetString("newname", NewName, sizeof(NewName));
		if(GetClientAuthId(client, AuthId_Steam2, SteamID, sizeof(SteamID)) && g_smSteamID.GetString(SteamID, ForcedName, sizeof(ForcedName)))
		{
			if(!StrEqual(NewName, ForcedName, false))
			{
				SetClientName(client, ForcedName);
			}
		}
	}
}

public Action ForceName(int client, int args)
{	
	if(args != 2)
	{
		CPrintToChat(client, "%t", "Usage");
		return Plugin_Handled;
	}
	
	GetCmdArg(1, CurrentName, sizeof(CurrentName));
	GetCmdArg(2, NewName, sizeof(NewName));
	
	int g_iTarget = FindTarget(client, CurrentName, true);
	if(g_iTarget == -1)
	{
		return Plugin_Handled;
	}
	
	GetClientName(client, AdminName, sizeof(AdminName));
	
	GetClientAuthId(g_iTarget, AuthId_Steam2, SteamID, sizeof(SteamID));
	if(StrEqual(SteamID, "STEAM_ID_STOP_IGNORING_RETVALS", false) || StrEqual(SteamID, "STEAM_ID_PENDING", false))
	{
		CPrintToChat(client, "%t", "InvalidSteamID");
		return Plugin_Handled;
	}
	
	CPrintToChat(client, "%t", "ForcedName", NewName, g_iTarget, SteamID); 
	
	SetClientName(g_iTarget, NewName);
	
	SetUpKeyValues();
	Kv.JumpToKey(SteamID, true);
	Kv.SetString("OriginalName", CurrentName);
	Kv.SetString("ForcedName", NewName);
	Kv.SetString("AdminName", AdminName);
	FormatTime(Time, sizeof(Time), "%c", GetTime());
	Kv.SetString("Time", Time);
	Kv.Rewind();
	Kv.ExportToFile(FilePath);
	delete Kv;

	GetNamesFromCfg();
	
	return Plugin_Handled;
}

public Action ForcedNames(int client, int args)
{
	char MenuBuffer[256];
	
	Menu menu = new Menu(MenuHandle);
	
	Format(MenuBuffer, sizeof(MenuBuffer), "%T", "MenuTitle", client);
	menu.SetTitle(MenuBuffer);

	SetUpKeyValues();
	if(!Kv.GotoFirstSubKey())
	{
		Format(MenuBuffer, sizeof(MenuBuffer), "%T", "MenuEmpty", client);
		menu.AddItem("empty", MenuBuffer, ITEMDRAW_DISABLED);
	}
	else
	{
		do
		{
			Kv.GetSectionName(SteamID, sizeof(SteamID));
			Kv.GetString("ForcedName", ForcedName, sizeof(ForcedName));
			Kv.GetString("OriginalName", OriginalName, sizeof(OriginalName));
			Kv.GetString("AdminName", AdminName, sizeof(AdminName));
			Kv.GetString("Time", Time, sizeof(Time));
			Format(MenuBuffer, sizeof(MenuBuffer), "Forced name: %s - Original name: %s \nOn %s by admin %s", ForcedName, OriginalName, Time, AdminName);
			menu.AddItem(SteamID, MenuBuffer);
		}
		while(Kv.GotoNextKey());
	}
	delete Kv;
	
	menu.ExitButton = true;
	menu.Display(client, 999);
	return Plugin_Handled;
}

public int MenuHandle(Menu menu, MenuAction action, param1, param2)
{
	if(action == MenuAction_Select)
	{
		char MenuChoice[32];
		menu.GetItem(param2, MenuChoice, sizeof(MenuChoice));
		SetUpKeyValues();
		Kv.JumpToKey(MenuChoice, false)
		Kv.DeleteThis();
		Kv.Rewind();
		Kv.ExportToFile(FilePath);
		delete Kv;
		g_smSteamID.Remove(MenuChoice);
		CPrintToChat(param1, "%t", "NameDeleted");
		
		ForcedNames(param1, param2);
	}
	
    else if(action == MenuAction_End)
    {
        delete menu;
    }
}

void GetNamesFromCfg()
{
	SetUpKeyValues();
	Kv.GotoFirstSubKey();
	do
	{
	    Kv.GetSectionName(SteamID, sizeof(SteamID));
		Kv.GetString("ForcedName", ForcedName, sizeof(ForcedName));
		g_smSteamID.SetString(SteamID, ForcedName);
	}
	while(Kv.GotoNextKey());
	delete Kv;
}

void SetUpKeyValues()
{
	BuildPath(Path_SM, FilePath, sizeof(FilePath), "configs/forcednames.cfg");
	Kv = new KeyValues("Names");
	Kv.ImportFromFile(FilePath);
}