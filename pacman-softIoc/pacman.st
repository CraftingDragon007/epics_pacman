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

PV( int		, pv_PLAYER_X			, "{NAME}:PACMAN_PLAYER_X"		, PV_MON );   
PV( int		, pv_PLAYER_Y			, "{NAME}:PACMAN_PLAYER_Y"		, PV_MON );
PV( int		, pv_PLAYER_DIRECTION	, "{NAME}:PACMAN_PLAYER_DIRECTION"	, PV_MON );
PV( int		, pv_PLAYER_STEP		, "{NAME}:PACMAN_PLAYER_STEP"		, PV_MON );
PV( int		, pv_PLAYER_SIZE		, "{NAME}:PACMAN_PLAYER_SIZE"		, PV_MON );
PV( int		, pv_PLAYER_STATE		, "{NAME}:PACMAN_PLAYER_STATE"		, PV_MON );
PV( int		, pv_FIELD_WIDTH		, "{NAME}:PACMAN_FIELD_WIDTH"		, PV_MON );
PV( int		, pv_FIELD_HEIGHT		, "{NAME}:PACMAN_FIELD_HEIGHT"		, PV_MON );
PV( string	, pv_SS_PACMAN			, "{NAME}:SS_PACMAN"			, PV_NONE );

%{

	struct Obstacle {
		int x;
		int y;
		int width;
		int height;
	};

	struct Obstacle obstacles[] = {
		{0, 0, 800, 1},     // Top Wall
		{0, 800, 800, 1},   // Bottom Wall

		{0, 0, 1, 350},     // Left Upper Wall
		{0, 400, 1, 400},   // Left Lower Wall

		{799, 0, 1, 350},   // Right Upper Wall
		{799, 400, 1, 400}  // Right Lower Wall
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


ss pacman_game {
	state INIT {
		entry {
			pvSetStr( pv_SS_PACMAN, "INIT" );
			pvSet(pv_PLAYER_X, 25);
			pvSet(pv_PLAYER_Y, 25);
			pvSet(pv_PLAYER_DIRECTION, 0); // (0=right, 1=left, 2=up, 3=down)
			pvSet(pv_PLAYER_STATE, 0);
		}
		 when () {
	        	printf( "PACMAN Started\n" );
		} state GAME
    	}

	state GAME {
		entry {
			pvSetStr( pv_SS_PACMAN, "GAME" );
		}
		when (delay(0.01)) {
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
                        pvSetStr( pv_SS_PACMAN, "MOVE" );
                }
		when () {
			int x_new = pv_PLAYER_X + pv_FIELD_WIDTH;
			int y_new = pv_PLAYER_Y + pv_FIELD_WIDTH;			
			if (pv_PLAYER_DIRECTION == 0) { // rigtht, increase x
				x_new = x_new + pv_PLAYER_STEP;
			} else if (pv_PLAYER_DIRECTION == 1) { // left, decrease x
				x_new = x_new - pv_PLAYER_STEP; 
			} else if (pv_PLAYER_DIRECTION == 2) { // up, decrease y (inverted axis)
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
