#pragma semicolon 1

#include <sourcemod>

#define PLUGIN_NAME 	"UpdateRadarFix"
#define PLUGIN_VERSION 	"1.0"

#pragma newdecls required

// Should not need more than 16
#define QUEUE_SIZE		24

bool g_bQueued[QUEUE_SIZE];
int g_iBits[QUEUE_SIZE][2048];
int g_iPlayers[QUEUE_SIZE][MAXPLAYERS+1];
int g_iPlayersNum[QUEUE_SIZE];

bool g_bConnected[MAXPLAYERS+1];

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "GoD-Tony, maxime1907",
	description = "Fixes the UpdateRadar usermessage on large servers",
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net/"
};

public void OnPluginStart()
{
	CreateConVar("sm_updateradar_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY|FCVAR_DONTRECORD);
	HookUserMessage(GetUserMessageId("UpdateRadar"), Hook_UpdateRadar, true);
}

public void OnClientConnected(int client)
{
	g_bConnected[client] = true;
}

public void OnClientDisconnect(int client)
{
	g_bConnected[client] = false;
}

public Action Hook_UpdateRadar(UserMsg msg_id, Handle bf, const char[] players, int playersNum, bool reliable, bool init)
{
	if (BfGetNumBytesLeft(bf) > 253)
	{
		int count, index = GetOpenQueue();

		// We don't want the closing byte.
		while (BfGetNumBytesLeft(bf) > 1)
		{
			g_iBits[index][count] = BfReadBool(bf);
			count++;
			
			// 252 bytes
			if (count == 2016)
			{
				g_iBits[index][count] = -1;
				g_iPlayersNum[index] = playersNum;
				
				for (int i = 0; i < playersNum; i++)
				{
					g_iPlayers[index][i] = players[i];
				}
				
				g_bQueued[index] = true;
				index = GetOpenQueue();
				count = 0;
			}
		}

		g_iBits[index][count] = -1;
		g_iPlayersNum[index] = playersNum;
		
		for (int i = 0; i < playersNum; i++)
		{
			g_iPlayers[index][i] = players[i];
		}
		
		g_bQueued[index] = true;

		// Block this one and send out the queued messages later.
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public void SendQueuedMsg(int index)
{
	// Make sure each client is still connected.
	for (int i = 0; i < g_iPlayersNum[index]; i++)
	{
		// Remove the player from the array.
		if (!g_bConnected[g_iPlayers[index][i]])
		{
			for (int j = i; j < g_iPlayersNum[index]-1; j++)
			{
				g_iPlayers[index][j] = g_iPlayers[index][j+1];
			}
			
			g_iPlayersNum[index]--;
			i--;
		}
	}
	
	// Don't send the message if there are no recipients.
	if(g_iPlayersNum[index] <= 0)
		return;
	
	Handle hBf = StartMessage("UpdateRadar", g_iPlayers[index], g_iPlayersNum[index], USERMSG_BLOCKHOOKS);
	
	int count = 0;
	while (g_iBits[index][count] != -1)
	{
		BfWriteBool(hBf, view_as<bool>(g_iBits[index][count]));
		count++;
	}

	BfWriteByte(hBf, 0);
	EndMessage();
}

public int GetOpenQueue()
{
	// Return the first free queue spot we find.
	for (int i = 0; i < QUEUE_SIZE; i++)
	{
		if (!g_bQueued[i])
		{
			return i;
		}
	}

	// Free up a spot.
	g_bQueued[0] = false;
	return 0;
}

public void OnGameFrame()
{
	// Send out all queued messages.
	for (int i = 0; i < QUEUE_SIZE; i++)
	{
		if (g_bQueued[i])
		{
			SendQueuedMsg(i);
			g_bQueued[i] = false;
		}
	}
}