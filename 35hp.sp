#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <nekocore>
#include <smlib>


#define iClutch 3
#pragma semicolon 1
#pragma newdecls required
bool VoteAlready;
bool GiveSnowBall;
bool IsBlock;
bool ShowDmg[MAXPLAYERS + 1];

int hp;

int g_iOpponents; 
int g_iClutchFor;

int iSpecialKnives[] =  { 500, 505, 506, 507, 508, 509, 512, 515 };

float fPickUpRange = 125.000;

public void OnPluginStart()
{
	
	GiveSnowBall = false;
	
	HookEvent("player_spawn", PlayerSpawn);
	HookEvent("round_prestart", VoteHp);
	HookEvent("bomb_pickup", Event_BombPickup);
	HookEvent("round_end", Event_RoundEnd); 
	HookEvent("player_death", Event_Death); 
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
	
	AddCommandListener(CommandDrop, "drop");
	
	RegConsoleCmd("sm_knifeadmin",knifeadmin);
	RegConsoleCmd("sm_hide",hidetext);
	
	for(int i = 1; i <= MaxClients; i++)
	{ 
		if(IsValidClient(i))
		{
			SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}
}

public void OnMapStart()
{
	ServerCommand("mp_warmuptime	30");
	IsBlock = true;
	VoteAlready = false;
	
	hp = 35;
	
	PrecacheSound("weapons/party_horn_01.wav");
	
}

public Action PlayerSpawn(Event event, const char[] name, bool dontBroadcast) 
{
	
	int client=GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(IsValidClient(client))
	{
		RequestFrame(RemoveRadar,client);
		RequestFrame(RemoveGuns,client);
		RequestFrame(GiveHP,client);
	}

}

void RemoveRadar(int client)
{
	SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") | (1 << 12));
}

void GiveHP(int client)
{
	SetEntProp(client, Prop_Send, "m_iHealth", hp, 1);
	SetEntProp(client, Prop_Send, "m_ArmorValue",0, 1);
}

public Action CommandDrop(int iClient, const char[] chCommand, int iArgs)
{
	if (!IsValidClient(iClient)) {
		return Plugin_Continue;
	}
	
	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	
	if (!IsValidWeapon(iWeapon)) {
		return Plugin_Continue;
	}
	
	if (!IsSpecialKnife(iWeapon) && !IsDefaultKnife(iWeapon)) {
		return Plugin_Continue;
	}
	
	CS_DropWeaponCustom(iClient, iWeapon, true, true);
	
	return Plugin_Handled;
}

void RemoveGuns(int client)
{
	int WpnId = GetPlayerWeaponSlot(client,0);
	if (WpnId!=-1)
	{
		RemovePlayerItem(client, WpnId);
		AcceptEntityInput(WpnId, "Kill");
	}
	
	WpnId = GetPlayerWeaponSlot(client,1);
	if (WpnId!=-1)
	{
		RemovePlayerItem(client, WpnId);
		AcceptEntityInput(WpnId, "Kill");
	}
	
	WpnId = GetPlayerWeaponSlot(client,2);
	while (WpnId!=-1)
	{
		RemovePlayerItem(client, WpnId);
		AcceptEntityInput(WpnId, "Kill");
		WpnId = GetPlayerWeaponSlot(client,2);
	}
	
	WpnId = GetPlayerWeaponSlot(client,3);
	while (WpnId!=-1)
	{
		RemovePlayerItem(client, WpnId);
		AcceptEntityInput(WpnId, "Kill");
		WpnId = GetPlayerWeaponSlot(client,3);
	}
	
	GivePlayerItem(client,"weapon_knife");
	if(GiveSnowBall)
		GivePlayerItem(client,"weapon_snowball");
}

public Action knifeadmin(int client,int ags)
{
	if(!NEKO_IsAdmin(client))
	{
		PrintToChat(client,"没有权限");
		return;
	}
	Menus_Show(client);
}

public Action hidetext(int client,int ags)
{
	ShowDmg[client] = !ShowDmg[client];
	PrintToChat(client,"显示 伤害血量 %s",ShowDmg[client]?"开启":"关闭");
}

void Menus_Show(int client)
{
	Menu menu = new Menu(Handler_MainMenu);
	menu.SetTitle("[Neko]刀服菜单");
	char buffer[32];
	Format(buffer,32,"出生装备雪球%s",GiveSnowBall?"[开启]":"[关闭]");
	menu.AddItem("1", buffer);
	Format(buffer,32,"屏蔽地图强制35HP%s",IsBlock?"[开启]":"[关闭]");
	menu.AddItem("2", buffer);
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_MainMenu(Menu menu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		switch (itemNum)
		{
			case 0:
			{
				GiveSnowBall = !GiveSnowBall;
				PrintToChatAll("管理员%N,%s了给每个玩家出生时一个雪球",client,GiveSnowBall?"开启":"关闭");
			}
			case 1:
			{
				IsBlock = !IsBlock;
				PrintToChatAll("管理员%N,%s了屏蔽地图强制35HP",client,IsBlock?"开启":"关闭");
			}
		}
	}
}

//block map trigger

public void OnEntityCreated(int entity, const char[] classname) {

	if(StrEqual(classname, "trigger_multiple"))
	{
		SDKHook(entity, SDKHook_Use, OnEntityUse);
		SDKHook(entity, SDKHook_StartTouch, OnEntityUse);
		SDKHook(entity, SDKHook_Touch, OnEntityUse);
		SDKHook(entity, SDKHook_EndTouch, OnEntityUse);
	}
}

public Action OnPlayerRunCmd(int iClient, int &iButtons)
{
	if (!IsPlayerAlive(iClient) || IsFakeClient(iClient)) {
		return;
	}
	
	if (iButtons & IN_USE) {
		
		int iEntity = GetClientAimTarget(iClient, false);
		
		if (!IsValidWeapon(iEntity)) {
			return;
		}
		
		if (!IsSpecialKnife(iEntity) && !IsDefaultKnife(iEntity)) {
			return;
		}
		
		if (GetDistance(iClient, iEntity) > fPickUpRange) {
			return;
		}
		
		ReplaceClientKnife(iClient, GetPlayerWeaponSlot(iClient, CS_SLOT_KNIFE), iEntity);
	}
}

stock void ReplaceClientKnife(int iClient, int iOriginalKnife, int iNewKnife)
{
	if (IsValidWeapon(iOriginalKnife) && iOriginalKnife != iNewKnife) {
		CS_DropWeaponCustom(iClient, iOriginalKnife, true, true);
	}
	
	EquipPlayerWeapon(iClient, iNewKnife);
}

stock bool IsDefaultKnife(int iWeapon)
{
	int iDefIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
	
	if (iDefIndex == 42 || iDefIndex == 59) {
		return true;
	}
	
	return false;
}

stock void CS_DropWeaponCustom(int iClient, int iWeapon, bool bToss, bool bBlockHook)
{
	int iOwnerEntity = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
	
	if (iOwnerEntity != iClient) {
		SetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity", iClient);
	}
	
	CS_DropWeapon(iClient, iWeapon, bToss, bBlockHook);
	
	if (iOwnerEntity != -1) {
		SetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity", iOwnerEntity);
	}
	
	if (!IsPlayerAlive(iClient)) {
		return;
	}
	
	RemovePlayerItem(iClient, iWeapon);
	
	int iPrimary = GetPlayerWeaponSlot(iClient, CS_SLOT_PRIMARY);
	int iSecondary = GetPlayerWeaponSlot(iClient, CS_SLOT_SECONDARY);
	int iSwitchTo = iPrimary != -1 ? iPrimary : iSecondary;
	
	if (!IsValidWeapon(iSwitchTo)) {
		return;
	}
	
	static char chWeapon[64]; GetEdictClassname(iSwitchTo, chWeapon, sizeof(chWeapon));
	FakeClientCommandEx(iClient, "use %s", chWeapon);
	SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iSwitchTo);
}

public Action OnEntityUse(int entity, int client)
{
	if(IsBlock)
		return Plugin_Handled;
	return Plugin_Continue;
}

public Action VoteHp(Event event, const char[] name, bool dontBroadcast)
{
	if (GameRules_GetProp("m_bWarmupPeriod"))
    {
		VoteAlready = false;
		return;
	}
	if (!VoteAlready)
		DoVoteMenu();
}

public int Handle_VoteMenu(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        /* This is called after VoteEnd */
        delete menu;
    }
}
 
public void Handle_VoteResults(Menu menu, 
        int num_votes, 
        int num_clients, 
        const int[][] client_info, 
        int num_items, 
        const int[][] item_info)
{
	int winner = 0;
	if (num_items > 1
	&& (item_info[0][VOTEINFO_ITEM_VOTES] == item_info[1][VOTEINFO_ITEM_VOTES])
	&& (item_info[1][VOTEINFO_ITEM_VOTES] == item_info[2][VOTEINFO_ITEM_VOTES]))
	{
		winner = GetRandomInt(0, 2);
	}
	
	char results[8];
	menu.GetItem(item_info[winner][VOTEINFO_ITEM_INDEX], results, sizeof(results));
	hp = StringToInt(results);
	PrintToChatAll("投票结束,血量设定为%i",hp);
	ServerCommand("mp_restartgame 2");
	VoteAlready = true;
	
}

void DoVoteMenu()
{
	if (IsVoteInProgress())
	{
		return;
	}
	Menu menu = new Menu(Handle_VoteMenu);
	menu.VoteResultCallback = Handle_VoteResults;
	menu.SetTitle("出生血量投票");
	menu.AddItem("35", "35Hp");
	menu.AddItem("50", "50Hp");
	menu.AddItem("100", "100Hp");
	menu.ExitButton = false;
	menu.DisplayVoteToAll(20);
}


public void Event_BombPickup(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	StripC4(client); 
}

bool StripC4(int client)
{
    if (IsValidClient(client) && IsPlayerAlive(client))
    {
        int c4Index = GetPlayerWeaponSlot(client, CS_SLOT_C4);
        if (c4Index != -1)
        {
            char weapon[24];
            GetClientWeapon(client, weapon, sizeof(weapon));
            /* If the player is holding C4, switch to the best weapon before removing it. */
            if (StrEqual(weapon, "weapon_c4"))
            {
                ClientCommand(client, "slot2");
            }
            RemovePlayerItem(client, c4Index);
            AcceptEntityInput(c4Index, "Kill");
            return true;
        }
    }
    return false;
}

public void OnClientPutInServer(int client)
{
	if(IsValidClient(client))
	{
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	}
	ShowDmg[client] = true;
}

public Action OnTakeDamage (int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
    if (IsValidEntity(victim) && IsValidClient(attacker) && ShowDmg[attacker])
    {
		char sdamage[8];
		int idamage = RoundToZero(damage);
		IntToString(idamage, sdamage, sizeof(sdamage));
		Format(sdamage,sizeof(sdamage),"-%s HP",sdamage);
		
		if (idamage > 0)
        {
			int health = GetEntProp(victim, Prop_Data, "m_iHealth");
			float victimpos[3], clientAngle[3], clientpos[3];
			GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimpos);
			GetClientEyeAngles(attacker, clientAngle);
			GetClientAbsOrigin(attacker, clientpos);
			
			if(damagetype == 8)	return;	// inferno doesn't have damageposition and damageForce :(
			
			if(weapon == -1 && damagetype == 64)	// grenades
			{
				if(idamage > health)	ShowDamageText(attacker, damagePosition, clientAngle, sdamage, true, victim);
				else	ShowDamageText(attacker, damagePosition, clientAngle, sdamage, false, victim);
			}
			else if(weapon != -1)	// normal weapons
			{
				if(idamage > health)	ShowDamageText(attacker, damagePosition, clientAngle, sdamage, true, victim);
				else	ShowDamageText(attacker, damagePosition, clientAngle, sdamage, false, victim);
			}
        }
    }
}  

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int idamage = event.GetInt("dmg_health");
	char sWeapon[50];
	event.GetString("weapon", sWeapon, 50, "");
	int health = GetClientHealth(victim);

	if(!IsValidClient(attacker) || IsFakeClient(attacker) || attacker == victim || !ShowDmg[attacker]) return;

	ReplaceString(sWeapon, 50, "_projectile", "");

	if (!sWeapon[0])	return;
	if(StrContains("inferno|molotov|decoy|flashbang|hegrenade|smokegrenade", sWeapon) != -1)
	{
		float victimpos[3], clientAngle[3];
		GetClientAbsOrigin(victim, victimpos);
		GetClientEyeAngles(attacker, clientAngle);
		
		victimpos[0] += GetRandomFloat(-20.0, 20.0);
		victimpos[1] += GetRandomFloat(-20.0, 20.0);
		victimpos[2] += GetRandomFloat(10.0, 30.0);
		
		char damage[8];
		IntToString(idamage, damage, sizeof(damage));
		Format(damage,sizeof(damage),"-%s HP",damage);
		
		if(health < 1)	ShowDamageText(attacker, victimpos, clientAngle, damage, true, victim);
		else	ShowDamageText(attacker, victimpos, clientAngle, damage, false, victim);
	}
	else
	{
		float pos[3], clientEye[3], clientAngle[3];
		GetClientEyePosition(attacker, clientEye);
		GetClientEyeAngles(attacker, clientAngle);
		
		TR_TraceRayFilter(clientEye, clientAngle, MASK_SOLID, RayType_Infinite, HitSelf, attacker);
		
		if (TR_DidHit(INVALID_HANDLE))	TR_GetEndPosition(pos);
		
		char damage[8];
		IntToString(idamage, damage, sizeof(damage));
		Format(damage,sizeof(damage),"-%s HP",damage);
		
		if(health < 1)	ShowDamageText(attacker, pos, clientAngle, damage, true, victim);
		else	ShowDamageText(attacker, pos, clientAngle, damage, false, victim);
	}
}

public Action SetTransmit(int entity, int client) 
{ 
	SetFlags(entity);
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if(client == owner) return Plugin_Continue;	// draw
	else return Plugin_Stop; // not draw
} 

public bool HitSelf(int entity, int contentsMask, any data)
{
	if (entity == data)	return false;
	return true;
}

public void SetFlags(int entity) 
{ 
	if (GetEdictFlags(entity) & FL_EDICT_ALWAYS) 
	{ 
		SetEdictFlags(entity, (GetEdictFlags(entity) ^ FL_EDICT_ALWAYS)); 
	} 
}

public void OnClientDisconnect_Post(int client)
{
	CheckAlive();
}

public Action Event_Death(Event event, char[] name, bool dontBroadcast) 
{ 
	CheckAlive();
} 

public void CheckAlive()
{
	// if already in a clutch situation then dont continue
	if(g_iClutchFor > 0)
		return;
		
	// get alive cts and ts
	int g_iTeamCT, g_iTeamT; 
	for (int i = 1; i <= MaxClients; i++) 
	{ 
		if(IsClientInGame(i) && IsPlayerAlive(i)) 
		{ 
			if(GetClientTeam(i) == CS_TEAM_CT) 
				g_iTeamCT++; 
			else if(GetClientTeam(i) == CS_TEAM_T) 
				g_iTeamT++; 
		} 
	} 
	
	// if only 1 player alive in the then and enought players in the other team
	
	if(g_iTeamT == 1  && g_iTeamCT >= iClutch) 
	{ 
		g_iClutchFor = CS_TEAM_T; // get clutch team
		g_iOpponents = g_iTeamCT; // get oponnents number
	} 
	else if(g_iTeamCT == 1  && g_iTeamT >= iClutch) 
	{
		g_iClutchFor = CS_TEAM_CT;
		g_iOpponents = g_iTeamT; 
	} 
} 

public Action Event_RoundEnd(Event event, char[] name, bool dontBroadcast) 
{ 
	if(g_iClutchFor != 0 && g_iOpponents >= iClutch) 
	{
		// if team winner is equal to the clutch player
		if(GetEventInt(event, "winner") == g_iClutchFor)
		{
			// get the last player alive that is should be the protagonist
			int client = GetClutchPlayerIndex();
			if(client > 0)
			{
        		PrintToChatAll(" [\x06翻盘成功\x01] 玩家 %N 获得了一次 单人翻盘的胜利！", client); 
        		CreateParticle(client, "weapon_confetti_balloons", 5.0); 
        	}
		}
	}
	g_iClutchFor = 0;
	g_iOpponents = 0; 
} 

stock void CreateParticle(int ent, char[] particleType, float time) 
{ 
    int particle = CreateEntityByName("info_particle_system"); 
     
    char name[64]; 
     
    if (IsValidEdict(particle)) 
    { 
        float position[3]; 
        GetEntPropVector(ent, Prop_Send, "m_vecOrigin", position); 
        TeleportEntity(particle, position, NULL_VECTOR, NULL_VECTOR); 
        GetEntPropString(ent, Prop_Data, "m_iName", name, sizeof(name)); 
        DispatchKeyValue(particle, "targetname", "tf2particle"); 
        DispatchKeyValue(particle, "parentname", name); 
        DispatchKeyValue(particle, "effect_name", particleType); 
        DispatchSpawn(particle); 
        SetVariantString(name); 
        AcceptEntityInput(particle, "SetParent", particle, particle, 0); 
        ActivateEntity(particle); 
        AcceptEntityInput(particle, "start"); 
        CreateTimer(time, DeleteParticle, particle); 
    } 
    EmitSoundToAll("weapons/party_horn_01.wav");   
} 

public Action DeleteParticle(Handle timer, any particle) 
{ 
    if (IsValidEntity(particle)) 
    { 
        char classN[64]; 
        GetEdictClassname(particle, classN, sizeof(classN)); 
        if (StrEqual(classN, "info_particle_system", false)) 
        { 
            AcceptEntityInput(particle, "Kill");
        } 
    } 
}

int GetClutchPlayerIndex()
{
	int index;
	
	for (int i = 1; i <= MaxClients; i++) 
	{ 
		if(IsClientInGame(i) && IsPlayerAlive(i)) 
		{ 
			if(GetClientTeam(i) == g_iClutchFor) 
				index = i;
		} 
	} 	
    
	return index;
}

stock bool IsValidClient( int client )
{
	if ( client < 1 || client > MaxClients ) return false;
	if ( !IsClientConnected( client )) return false;
	if ( !IsClientInGame( client )) return false;
	//if ( IsFakeClient(client)) return false;
	return true;
}

stock int ShowDamageText(int client, float fPos[3], float fAngles[3], char[] sText, bool kill, int victim) 
{
	int entity = CreateEntityByName("point_worldtext"); 
	
	if(entity == -1)	return entity; 
	
	float distance;
	
	char stext_size_kill[32];
	char stext_size_normal[32];
	
	distance = Entity_GetDistance(client, victim);
	DispatchKeyValue(entity, "message", sText); 
	
	FloatToString(0.0015*distance*17, stext_size_kill, sizeof(stext_size_kill));
	FloatToString(0.0015*distance*15, stext_size_normal, sizeof(stext_size_normal));
	
	if(kill)
	{
		DispatchKeyValue(entity, "textsize", stext_size_kill);
		DispatchKeyValue(entity, "color", "255 0 0"); 
	}
	else
	{
		DispatchKeyValue(entity, "textsize", stext_size_normal);
		DispatchKeyValue(entity, "color", "255 255 255"); 
	}

	SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);  
	SetFlags(entity);
	
	SDKHook(entity, SDKHook_SetTransmit, SetTransmit);
	TeleportEntity(entity, fPos, fAngles, NULL_VECTOR);
	
	CreateTimer(0.75, KillText, EntIndexToEntRef(entity));
    
	return entity; 
}

public Action KillText(Handle timer, int ref)
{
	int entity = EntRefToEntIndex(ref);
	if(entity == INVALID_ENT_REFERENCE || !IsValidEntity(entity))	return;
	SDKUnhook(entity, SDKHook_SetTransmit, SetTransmit);
	AcceptEntityInput(entity, "kill");
}

stock float GetDistance(int iClient, int iEntity)
{
	float fClientPos[3]; float fEntityPos[3]; float fClientMins[3]; float fClientMaxs[3];
	
	GetClientMins(iClient, fClientMins); GetClientMaxs(iClient, fClientMins);
	
	float fHalfHeight = fClientMins[2] - fClientMaxs[2] + 10;
	
	GetClientAbsOrigin(iClient, fClientPos); GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fEntityPos);
	
	float fPosHeightDiff = fClientPos[2] - fEntityPos[2];
	
	if (fPosHeightDiff > fHalfHeight) {
		fClientPos[2] -= fHalfHeight;
	}
	
	else if (fPosHeightDiff < (-1.0 * fHalfHeight)) {
		fClientPos[2] -= fHalfHeight;
	}
	
	else {
		fClientPos[2] = fEntityPos[2];
	}
	
	return GetVectorDistance(fClientPos, fEntityPos, false);
}

stock bool IsValidWeapon(int iWeapon)
{
	if (iWeapon > 4096 && iWeapon != INVALID_ENT_REFERENCE) {
		iWeapon = EntRefToEntIndex(iWeapon);
	}
	
	if (!IsValidEdict(iWeapon) || !IsValidEntity(iWeapon) || iWeapon == -1) {
		return false;
	}
	
	char chWeapon[64];
	GetEdictClassname(iWeapon, chWeapon, sizeof(chWeapon));
	
	return StrContains(chWeapon, "weapon_") == 0;
}

stock bool IsSpecialKnife(int iWeapon)
{
	int iDefIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
	
	if (iDefIndex == 42 || iDefIndex == 59) {
		return false;
	}
	
	else {
		for (int i; i < sizeof(iSpecialKnives); i++) {
			if (iDefIndex == iSpecialKnives[i]) {
				return true;
			}
		}
	}
	
	return false;
}

