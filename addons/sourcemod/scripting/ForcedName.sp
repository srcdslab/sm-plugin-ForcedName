#include <sourcemod>
#include <sdktools>
#include <multicolors>

#pragma semicolon 1
#pragma newdecls required

KeyValues Kv;
StringMap g_smSteamID;

char FilePath[128], SteamID[32], ForcedName[64], OriginalName[64], AdminName[64], Time[32];

public Plugin myinfo =
{
	name = "ForcedName",
	author = "ire.",
	description = "Force a name on a player",
	version = "1.2"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("ForcedName");
	return APLRes_Success;
}

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
	delete g_smSteamID;
	g_smSteamID = new StringMap();

	GetNamesFromCfg();
}

public void OnClientConnected(int client)
{
	if (!IsValidClient(client))
		CreateTimer(2.0, CheckClientName, GetClientUserId(client));
}

public Action CheckClientName(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);

	if (client)
	{
		if (GetClientAuthId(client, AuthId_Steam2, SteamID, sizeof(SteamID)) && g_smSteamID.GetString(SteamID, ForcedName, sizeof(ForcedName)))
			SetClientName(client, ForcedName);
	}
}

public void Event_ChangeName(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!IsValidClient(client)) 
	{
		char NewName[64];
		event.GetString("newname", NewName, sizeof(NewName));
		if (GetClientAuthId(client, AuthId_Steam2, SteamID, sizeof(SteamID)) && g_smSteamID.GetString(SteamID, ForcedName, sizeof(ForcedName)))
		{
			if (!StrEqual(NewName, ForcedName, false))
				SetClientName(client, ForcedName);
		}
	}
}

public Action ForceName(int client, int args)
{
	char Arg1[64], Arg2[64], TargetName[64];

	if (args != 2)
	{
		CReplyToCommand(client, "%t", "Usage");
		return Plugin_Handled;
	}

	GetCmdArg(1, Arg1, sizeof(Arg1));
	GetCmdArg(2, Arg2, sizeof(Arg2));

	int g_iTarget = FindTarget(client, Arg1, true);

	if (g_iTarget == -1)
		return Plugin_Handled;

	GetClientName(client, AdminName, sizeof(AdminName));

	if (client <= 0)
		Format(AdminName, sizeof(AdminName), "Console/Server");

	GetClientName(g_iTarget, TargetName, sizeof(TargetName));

	if (!GetClientAuthId(g_iTarget, AuthId_Steam2, SteamID, sizeof(SteamID)))
	{
		CReplyToCommand(client, "%t", "InvalidSteamID");
		return Plugin_Handled;
	}

	CReplyToCommand(client, "%t", "ForcedName", Arg2, TargetName, SteamID); 

	SetClientName(g_iTarget, Arg2);

	SetUpKeyValues();
	Kv.JumpToKey(SteamID, true);
	Kv.SetString("OriginalName", TargetName);
	Kv.SetString("ForcedName", Arg2);
	g_smSteamID.SetString(SteamID, Arg2);
	Kv.SetString("AdminName", AdminName);
	FormatTime(Time, sizeof(Time), "%d.%m.%Y %R", GetTime());
	Kv.SetString("Date", Time);
	Kv.Rewind();
	Kv.ExportToFile(FilePath);
	delete Kv;

	return Plugin_Handled;
}

public Action ForcedNames(int client, int args)
{
	char MenuBuffer[128], MenuBuffer2[32], MenuBuffer3[128];

	Menu MainMenu = new Menu(MenuHandle);

	Format(MenuBuffer, sizeof(MenuBuffer), "%T", "MenuTitle", client);
	MainMenu.SetTitle(MenuBuffer);

	SetUpKeyValues();
	if (!Kv.GotoFirstSubKey())
	{
		Format(MenuBuffer2, sizeof(MenuBuffer2), "%T", "MenuEmpty", client);
		MainMenu.AddItem("", MenuBuffer2, ITEMDRAW_DISABLED);
	} else {
		do
		{
			Kv.GetSectionName(SteamID, sizeof(SteamID));
			Kv.GetString("ForcedName", ForcedName, sizeof(ForcedName));
			Format(MenuBuffer3, sizeof(MenuBuffer3), "%T", "MenuContent", client, ForcedName);
			MainMenu.AddItem(SteamID, MenuBuffer3);
		}
		while(Kv.GotoNextKey());
	}
	delete Kv;

	MainMenu.ExitButton = true;
	MainMenu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

int MenuHandle(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char MenuBuffer[128], MenuChoice[32], MenuBuffer2[128], MenuBuffer3[32];

		Menu SubMenu = new Menu(SubMenuHandle);

		Format(MenuBuffer, sizeof(MenuBuffer), "%T", "SubMenuTitle", param1);
		SubMenu.SetTitle(MenuBuffer);

		menu.GetItem(param2, MenuChoice, sizeof(MenuChoice));

		SetUpKeyValues();
		Kv.JumpToKey(MenuChoice, false);
		Kv.GetString("ForcedName", ForcedName, sizeof(ForcedName));
		Kv.GetString("OriginalName", OriginalName, sizeof(OriginalName));
		Kv.GetString("AdminName", AdminName, sizeof(AdminName));
		Kv.GetString("Date", Time, sizeof(Time));
		delete Kv;

		Format(MenuBuffer2, sizeof(MenuBuffer2), "%T", "SubMenuContent", param1, ForcedName, OriginalName, AdminName, Time);
		Format(MenuBuffer3, sizeof(MenuBuffer3), "%T", "SubMenuDeleteName", param1);
		SubMenu.AddItem("0", MenuBuffer2, ITEMDRAW_DISABLED);
		SubMenu.AddItem(MenuChoice, MenuBuffer3);

		SubMenu.ExitBackButton = true;
		SubMenu.Display(param1, MENU_TIME_FOREVER);
	}

	else if (action == MenuAction_End)
		delete menu;
}

int SubMenuHandle(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{
			case 1:
			{
				char MenuChoice[32];
				menu.GetItem(param2, MenuChoice, sizeof(MenuChoice));
				SetUpKeyValues();
				Kv.JumpToKey(MenuChoice, false);
				Kv.DeleteThis();
				Kv.Rewind();
				Kv.ExportToFile(FilePath);
				delete Kv;
				g_smSteamID.Remove(MenuChoice);
				CReplyToCommand(param1, "%t", "NameDeleted");
				ForcedNames(param1, param2);
			}
		}
	}

	if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack)
			ForcedNames(param1, param2);
	}

	else if (action == MenuAction_End)
		delete menu;
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

bool IsValidClient(int client, bool nobots = true)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
	{
		return false;
	}
	return IsClientInGame(client);
}
