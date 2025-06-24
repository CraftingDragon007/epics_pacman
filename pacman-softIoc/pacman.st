program pacman
#include "seqPVmacros.h"

%%#include "stdbool.h"
%%#include "math.h"
%%#include "stdlib.h"
%%#include "stdio.h"
%%#include "errlog.h"
%%#define PRINTF errlogPrintf

/* options */
option  +r;

PV( int		, pv_GAME_STATE			, "{NAME}:PACMAN_GAME_STATE"		, PV_MON );
PV( int		, pv_GAME_COUNTDOWN		, "{NAME}:PACMAN_GAME_COUNTDOWN"	, PV_MON );
PV( int		, pv_PLAYER_X			, "{NAME}:PACMAN_PLAYER_X"			, PV_MON );   
PV( int		, pv_PLAYER_Y			, "{NAME}:PACMAN_PLAYER_Y"			, PV_MON );
PV( int		, pv_PLAYER_DIRECTION	, "{NAME}:PACMAN_PLAYER_DIRECTION"	, PV_MON );
PV( int		, pv_PLAYER_STEP		, "{NAME}:PACMAN_PLAYER_STEP"		, PV_MON );
PV( int		, pv_PLAYER_SIZE		, "{NAME}:PACMAN_PLAYER_SIZE"		, PV_MON );
PV( int		, pv_PLAYER_STATE		, "{NAME}:PACMAN_PLAYER_STATE"		, PV_MON );
PV( int		, pv_FIELD_WIDTH		, "{NAME}:PACMAN_FIELD_WIDTH"		, PV_MON );
PV( int		, pv_FIELD_HEIGHT		, "{NAME}:PACMAN_FIELD_HEIGHT"		, PV_MON );
PV( string	, pv_SS_PACMAN			, "{NAME}:SS_PACMAN"				, PV_NONE );

%{

	struct Obstacle {
		int x;
		int y;
		int width;
		int height;
	};

	struct Obstacle obstacles[] = {
    {0, 0, 14, 260},
    {0, 490, 14, 310},
    {0, 245, 157, 105},
    {0, 400, 157, 105},
    {71, 168, 86, 27},
    {71, 65, 86, 52},
    {215, 65, 115, 52},
    {10, 0, 780, 14},
    {10, 786, 780, 14},
    {11, 630, 60, 29},
    {72, 555, 85, 26},
    {130, 580, 27, 78},
    {73, 710, 255, 26},
    {215, 632, 28, 80},
    {215, 400, 28, 103},
    {215, 168, 28, 182},
    {215, 555, 115, 26},
    {240, 245, 88, 26},
    {300, 632, 200, 26},
    {300, 477, 200, 26},
    {300, 168, 200, 26},
    {387, 656, 27, 79},
    {387, 501, 27, 79},
    {387, 192, 27, 79},
    {387, 12, 27, 104},
    {301, 320, 199, 106},
    {471, 65, 115, 52},
    {644, 65, 86, 52},
    {787, 0, 14, 260},
    {787, 490, 14, 310},
    {644, 400, 157, 105},
    {644, 244, 157, 105},
    {471, 555, 115, 26},
    {473, 710, 255, 26},
    {558, 632, 28, 80},
    {644, 555, 85, 26},
    {644, 580, 27, 78},
    {730, 630, 60, 29},
    {558, 400, 28, 103},
    {644, 168, 86, 27},
    {558, 168, 28, 182},
    {472, 245, 88, 26},
};

	bool is_intersecting_ghost(int x, int y, int size) {
		return false;
	}

	bool is_intersecting_obstacle(int x, int y, int size) {
		for (size_t i = 0; i < sizeof(obstacles) / sizeof(obstacles[0]); i++) {
			if (obstacles[i].x < x + size && obstacles[i].x + obstacles[i].width > x) {
				if (obstacles[i].y < y + size && obstacles[i].y + obstacles[i].height > y) {
					return true;
				}
			}
		}
		return false;
	}

}%

int internal_direction = 3;

ss pacman_game {
	state INIT {
		entry {
			pvSetStr( pv_SS_PACMAN, "INIT" );
			pvSet(pv_PLAYER_X, 400 - pv_PLAYER_SIZE / 2);
			pvSet(pv_PLAYER_Y, 606 - pv_PLAYER_SIZE / 2);
			pvSet(pv_PLAYER_DIRECTION, 1); // (0=right, 1=left, 2=up, 3=down)
			internal_direction = 1;
			pvSet(pv_PLAYER_STATE, 1);
		}
		when (pv_GAME_STATE == 1) {
	        printf( "PACMAN Started\n" );
			pvSet(pv_GAME_COUNTDOWN, 300);		
		} state COUNTDOWN
    }
	
	state COUNTDOWN {
		entry {
			pvSetStr( pv_SS_PACMAN, "COUNTDOWN");
		}
		when (pv_GAME_COUNTDOWN == 0) {
			pvSet(pv_PLAYER_STATE, 0);
		} state GAME
		when (delay(0.01)) {
			int new_countdown = pv_GAME_COUNTDOWN - 1;
			pvSet(pv_GAME_COUNTDOWN, new_countdown);
		} state COUNTDOWN 
	}

	state GAME {
		entry {
			pvSetStr( pv_SS_PACMAN, "GAME" );
		}
		when (pv_GAME_STATE == 0) {
		} state INIT
		when (delay(0.015)) {
		} state CHECK_INTERSECTION
	}

	state CHECK_INTERSECTION {
		entry {
			pvSetStr( pv_SS_PACMAN, "CHECK_INTERSECTION" );	
		}
		when(is_intersecting_ghost(pv_PLAYER_X, pv_PLAYER_Y, pv_PLAYER_SIZE)) {
		} state GAME_OVER
		when() {
		} state TRY_MOVE
	}

	state GAME_OVER {
		entry {
			pvSetStr( pv_SS_PACMAN, "GAME_OVER" );
			pvSet(pv_PLAYER_STATE, 1);
		}
		when (delay(5)) {
		} state INIT
	}

	state TRY_MOVE {
                entry {
                        pvSetStr( pv_SS_PACMAN, "TRY_MOVE" );
                }
		when () {
			int x_new = pv_PLAYER_X + pv_FIELD_WIDTH;
			int y_new = pv_PLAYER_Y + pv_FIELD_WIDTH;			
			if (internal_direction == 0) { // rigtht, increase x
				x_new = x_new + pv_PLAYER_STEP;
			} else if (internal_direction == 1) { // left, decrease x
				x_new = x_new - pv_PLAYER_STEP; 
			} else if (internal_direction == 2) { // up, decrease y (inverted axis)
				y_new = y_new - pv_PLAYER_STEP;
			} else { // down, increase y (inverted axis)
				y_new = y_new + pv_PLAYER_STEP;
			}

			x_new = x_new % pv_FIELD_WIDTH;
			y_new = y_new % pv_FIELD_HEIGHT;

			if (!is_intersecting_obstacle(x_new, y_new, pv_PLAYER_SIZE)) {
				pvSet(pv_PLAYER_X, x_new)
				pvSet(pv_PLAYER_Y, y_new)
			}

		} state GAME
	}
}

ss pacman_direction {
	state INIT {
		when () {
		} state CHECK_DIRECTION_CHANGE
	}

	state CHECK_DIRECTION_CHANGE {
		when (pv_PLAYER_DIRECTION != internal_direction) {
			int new_direction = pv_PLAYER_DIRECTION;

			int x_new = pv_PLAYER_X + pv_FIELD_WIDTH;
			int y_new = pv_PLAYER_Y + pv_FIELD_WIDTH;			
			if (new_direction == 0) { // rigtht, increase x
				x_new = x_new + pv_PLAYER_SIZE;
			} else if (new_direction == 1) { // left, decrease x
				x_new = x_new - pv_PLAYER_SIZE; 
			} else if (new_direction == 2) { // up, decrease y (inverted axis)
				y_new = y_new - pv_PLAYER_SIZE;
			} else { // down, increase y (inverted axis)
				y_new = y_new + pv_PLAYER_SIZE;
			}

			x_new = x_new % pv_FIELD_WIDTH;
			y_new = y_new % pv_FIELD_HEIGHT;

			if (is_intersecting_obstacle(x_new, y_new, pv_PLAYER_SIZE)) {
				pvSet(pv_PLAYER_DIRECTION, internal_direction);
			} else {
				internal_direction = new_direction;
			}
		} state CHECK_DIRECTION_CHANGE
	}
}