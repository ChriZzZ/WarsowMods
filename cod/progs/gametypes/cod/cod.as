void GT_scoreEvent(cClient @client, cString &score_event, cString &args) {
	// Some game actions trigger score events. These are events not related to killing
	// oponents, like capturing a flag
	
	if(score_event == "dmg") {
		if(match.getState() == MATCH_STATE_PLAYTIME) {
			GT_updateScore(client);
			cCodPlayer @codPlayer = @getCodPlayer(client);
			
			if (@codPlayer != null) {
				codPlayer.update();
			}
		}
	} else if(score_event == "kill") {
		cEntity @target = G_GetEntity(args.getToken(0).toInt());
		cEntity @attacker = @client.getEnt();
		
		if (@target != null || @target.client != null) {
			@getCodPlayer(@target).reset();
		}
		
		if (@attacker != null || @attacker.client != null) {
			@getCodPlayer(@attacker).update();
		}
		
	} else if(score_event == "disconnect") {
		cCodPlayer @codPlayer = @getCodPlayer(client);
		if (@codPlayer != null) {
			codPlayer.disconnect();
		}
	}
}

void GT_playerRespawn(cEntity @ent, int old_team, int new_team) {
	// a player is being respawned. This can happen from several ways, as dying, changing team,
	// being moved to ghost state, be placed in respawn queue, being spawned from spawn queue, etc
	
	if (old_team != new_team) {
		cCodPlayer @player = getCodPlayer(ent.client);
		if (@player != null) {
			player.reset();
		}
		else {
			cCodPlayer(ent.client);
		}
	}
	
	if(ent.isGhosting()) {
		return;
	}

	// auto-select best weapon in the inventory
	if(ent.client.pendingWeapon == WEAP_NONE) {
		ent.client.selectWeapon(-1);
	}

	// add a teleportation effect
	ent.respawnEffect();
}


bool GT_UpdateBotStatus(cEntity @ent) {
	// TODO: make bots defrost people
	return GENERIC_UpdateBotStatus(ent);
}

cEntity @GT_SelectSpawnPoint(cEntity @self) {
	// select a spawning point for a player
	// TODO: make players spawn near where they were defrosted?
	return GENERIC_SelectBestRandomSpawnPoint(self, "info_player_deathmatch");
}

// Thinking function. Called each frame
void GT_ThinkRules() {
	if(match.scoreLimitHit() || match.timeLimitHit() || match.suddenDeathFinished()) {
		match.launchState(match.getState() + 1);
	}

bool GT_MatchStateFinished(int incomingMatchState) {
	// The game has detected the end of the match state, but it
	// doesn't advance it before calling this function.
	// This function must give permission to move into the next
	// state by returning true.
	if(match.getState() <= MATCH_STATE_WARMUP && incomingMatchState > MATCH_STATE_WARMUP && incomingMatchState < MATCH_STATE_POSTMATCH) {
		match.startAutorecord();
	}

	if(match.getState() == MATCH_STATE_POSTMATCH) {
		match.stopAutorecord();
	}

	return true;
}

void GT_MatchStateStarted() {
	// the match state has just moved into a new state. Here is the
	// place to set up the new state rules
	switch(match.getState()) {
		case MATCH_STATE_WARMUP:
			gametype.pickableItemsMask = gametype.spawnableItemsMask;
			gametype.dropableItemsMask = gametype.spawnableItemsMask;

			GENERIC_SetUpWarmup();

			for(int team = TEAM_PLAYERS; team < GS_MAX_TEAMS; team++) {
				gametype.setTeamSpawnsystem(team, SPAWNSYSTEM_INSTANT, 0, 0, false);
			}

			break;

		case MATCH_STATE_COUNTDOWN:
			gametype.pickableItemsMask = 0;
			gametype.dropableItemsMask = 0;

			GENERIC_SetUpCountdown();

			break;

		case MATCH_STATE_PLAYTIME:
			gametype.pickableItemsMask = gametype.spawnableItemsMask;
			gametype.dropableItemsMask = gametype.spawnableItemsMask;

			GENERIC_SetUpMatch();

			COD_InitCodPlayers();

			// set spawnsystem type to not respawn the players when they die
			for(int team = TEAM_PLAYERS; team < GS_MAX_TEAMS; team++) {
				gametype.setTeamSpawnsystem(team, SPAWNSYSTEM_HOLD, 0, 0, true);
			}

			break;

		case MATCH_STATE_POSTMATCH:
			gametype.pickableItemsMask = 0;
			gametype.dropableItemsMask = 0;

			GENERIC_SetUpEndMatch();

			break;

		default:
			break;
	}
}

void GT_Shutdown() {
	// the gametype is shutting down cause of a match restart or map change
}

void GT_SpawnGametype() {
	// The map entities have just been spawned. The level is initialized for
	// playing, but nothing has yet started.
}

void GT_InitGametype() {
	// Important: This function is called before any entity is spawned, and
	// spawning entities from it is forbidden. ifyou want to make any entity
	// spawning at initialization do it in GT_SpawnGametype, which is called
	// right after the map entities spawning.
	gametype.setTitle("CoD Remix");
	gametype.setVersion("0.1");
	gametype.setAuthor("ChriZzZ");

	gametype.spawnableItemsMask = IT_WEAPON | IT_AMMO | IT_ARMOR | IT_POWERUP | IT_HEALTH;
	if(!CODAllowPowerups.getBool()) {
		gametype.spawnableItemsMask &= ~IT_POWERUP;
	}
	if(gametype.isInstagib()) {
		gametype.spawnableItemsMask &= ~uint(G_INSTAGIB_NEGATE_ITEMMASK);
	}
	gametype.respawnableItemsMask = gametype.spawnableItemsMask;
	gametype.dropableItemsMask = gametype.spawnableItemsMask;
	gametype.pickableItemsMask = gametype.spawnableItemsMask | gametype.dropableItemsMask;

	gametype.isTeamBased = true;
	gametype.isRace = false;
	gametype.hasChallengersQueue = false;
	gametype.maxPlayersPerTeam = 0;

	gametype.ammoRespawn = 20;
	gametype.armorRespawn = 25;
	gametype.weaponRespawn = 15;
	gametype.healthRespawn = 25;
	gametype.powerupRespawn = 90;
	gametype.megahealthRespawn = 20;
	gametype.ultrahealthRespawn = 60;
	gametype.readyAnnouncementEnabled = false;

	gametype.scoreAnnouncementEnabled = true;
	gametype.countdownEnabled = true;
	gametype.mathAbortDisabled = false;
	gametype.shootingDisabled = false;
	gametype.infiniteAmmo = false;
	gametype.canForceModels = true;
	gametype.canShowMinimap = true;
	gametype.teamOnlyMinimap = true;

	gametype.spawnpointRadius = 256;
	if(gametype.isInstagib()) {
		gametype.spawnpointRadius *= 2;
	}

	// set spawnsystem type to instant while players join
	for(int t = TEAM_PLAYERS; t < GS_MAX_TEAMS; t++) {
		gametype.setTeamSpawnsystem(t, SPAWNSYSTEM_INSTANT, 0, 0, false);
	}

	// define the scoreboard layout
	if(gametype.isInstagib()) {
		G_ConfigString(CS_SCB_PLAYERTAB_LAYOUT, "%n 112 %s 52 %i 52 %i 52 %l 48 %p 18");
		G_ConfigString(CS_SCB_PLAYERTAB_TITLES, "Name Clan Score Dfrst Ping R");
	} else {
		G_ConfigString(CS_SCB_PLAYERTAB_LAYOUT, "%n 112 %s 52 %i 52 %i 52 %i 52 %l 48 " + "%p 18 " + "%p 18");
		G_ConfigString(CS_SCB_PLAYERTAB_TITLES, "Name Clan Score Frags Dfrst Ping " + "C " + " R");
	}

	// precache images that can be used by the scoreboard
	prcYesIcon = G_ImageIndex("gfx/hud/icons/vsay/yes");
	prcShockIcon = G_ImageIndex("gfx/hud/icons/powerup/quad");
	prcShellIcon = G_ImageIndex("gfx/hud/icons/powerup/warshell");

	// add commands
	G_RegisterCommand("drop");
	G_RegisterCommand("gametype");

	// add callvotes
	G_RegisterCallvote("COD_powerups", "1 or 0", "Enables or disables powerups in Freeze Tag.");
	G_RegisterCallvote("COD_powerup_drop", "1 or 0", "Enables or disables powerup dropping in Freeze Tag.");

	if(!G_FileExists("configs/server/gametypes/" + gametype.getName() + ".cfg")) {
		cString config;
		// the config file doesn't exist or it's empty, create it
		config = "// '" + gametype.getTitle() + "' gametype configuration file\n"
			+ "// This config will be executed each time the gametype is started\n"
			+ "\n// " + gametype.getTitle() + " specific settings\n"
			+ "set COD_allowPowerups \"1\"\n"
			+ "set COD_powerupDrop \"1\"\n"
			+ "\n// map rotation\n"
			+ "set g_maplist \"wdm1 wdm2 wdm3 wdm4 wdm5 wdm6 wdm7 wdm8 wdm9 wdm10 wdm11 wdm12 wdm13 wdm14 wdm15 wdm16 wdm17\" // list of maps in automatic rotation\n"
			+ "set g_maprotation \"1\"   // 0 = same map, 1 = in order, 2 = random\n"
			+ "\n// game settings\n"
			+ "set g_scorelimit \"15\"\n"
			+ "set g_timelimit \"0\"\n"
			+ "set g_warmup_enabled \"1\"\n"
			+ "set g_warmup_timelimit \"1.5\"\n"
			+ "set g_match_extendedtime \"0\"\n"
			+ "set g_allow_falldamage \"1\"\n"
			+ "set g_allow_selfdamage \"1\"\n"
			+ "set g_allow_teamdamage \"1\"\n"
			+ "set g_allow_stun \"1\"\n"
			+ "set g_teams_maxplayers \"0\"\n"
			+ "set g_teams_allow_uneven \"0\"\n"
			+ "set g_countdown_time \"5\"\n"
			+ "set g_maxtimeouts \"3\" // -1 = unlimited\n"
			+ "set g_challengers_queue \"0\"\n"
			+ "\necho \"" + gametype.getName() + ".cfg executed\"\n";
		G_WriteFile("configs/server/gametypes/" + gametype.getName() + ".cfg", config);
		G_Print("Created default config file for '" + gametype.getName() + "'\n");
		G_CmdExecute("exec configs/server/gametypes/" + gametype.getName() + ".cfg silent");
	}
	G_Print("Gametype '" + gametype.getTitle() + "' initialized\n");
}
