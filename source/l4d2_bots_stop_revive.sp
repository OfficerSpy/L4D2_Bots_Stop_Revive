#include <sourcemod>
#include <sdkhooks>
#include <dhooks>

#pragma semicolon 1

bool g_bStopRevive[MAXPLAYERS + 1];

DynamicHook g_DHookIsBot;

public Plugin myinfo = 
{
	name = "[L4D2] Bots Stop Revive",
	author = "Officer Spy",
	description = "Bots stop reviving when their incapacitated survivor is taking damage.",
	version = "1.0.0",
	url = ""
};

public void OnPluginStart()
{
	GameData hGamedata = new GameData("l4d2.botsstoprevive");
	
	if (hGamedata == null)
		SetFailState("Could not find gamedata file: l4d2.botsstoprevive");
	
	int offset = hGamedata.GetOffset("CBasePlayer::IsBot");
	
	if (offset == -1)
		SetFailState("Failed to retrieve offset for CBasePlayer::IsBot!");
	
	delete hGamedata;
	
	g_DHookIsBot = new DynamicHook(offset, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity);
}

public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client))
		DHookEntity(g_DHookIsBot, true, client, _, DHookCallback_IsBot_Post);
	
	SDKHook(client, SDKHook_OnTakeDamageAlive, Player_OnTakeDamageAlive);
	SDKHook(client, SDKHook_OnTakeDamageAlivePost, Player_OnTakeDamageAlivePost);
}

public Action Player_OnTakeDamageAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (IsIncapacitatedSurvivor(victim))
	{
		int reviver = GetEntPropEnt(victim, Prop_Send, "m_reviveOwner");
		
		if (reviver != -1 && IsFakeClient(reviver))
			g_bStopRevive[reviver] = true;
	}
	
	return Plugin_Continue;
}

public void Player_OnTakeDamageAlivePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	if (IsIncapacitatedSurvivor(victim))
	{
		int reviver = GetEntPropEnt(victim, Prop_Send, "m_reviveOwner");
		
		if (reviver != -1 && IsFakeClient(reviver))
			g_bStopRevive[reviver] = false;
	}
}

public MRESReturn DHookCallback_IsBot_Post(int pThis, DHookReturn hReturn)
{
	if (g_bStopRevive[pThis])
	{
		hReturn.Value = false;
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

bool IsIncapacitatedSurvivor(int client)
{
	return GetClientTeam(client) == 2 && GetEntProp(client, Prop_Send, "m_isIncapacitated") == 1;
}

/* NOTE: CTerrorPlayer::StopBeingRevived appears to be located in 10 places,
but the notable one here is CTerrorPlayer::OnTakeDamage_Alive, where it
seems this isn't called when the one reviving said player is a bot */