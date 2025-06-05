program pacman
#include "seqPVmacros.h"

%%#include "math.h"
%%#include "stdlib.h"
%%#include "errlog.h"
%%#define PRINTF errlogPrintf

/* options */
option  +r;

/* variables pacman game --> some Values are double even though they behave like ints, because they need to be for conversion. */

PV( int     , pv_PACMAN_USER_X			, "{NAME}:PACMAN_USER_X"		, PV_MON );   
PV( int     , pv_PACMAN_USER_Y			, "{NAME}:PACMAN_USER_Y"		, PV_MON );
PV( int     , pv_PACMAN_USER_DIRECTION	, "{NAME}:PACMAN_USER_DIRECTION", PV_MON );
PV( int     , pv_PACMAN_FIELD_SIZE    	, "{NAME}:PACMAN_FIELD_SIZE"	, PV_MON );
PV( int     , pv_PACMAN_ARRAY_X_SIZE	, "{NAME}:PACMAN_ARRAY_X_SIZE"	, PV_MON );
PV( int     , pv_PACMAN_ARRAY_X_FACTOR	, "{NAME}:PACMAN_ARRAY_X_FACTOR", PV_MON );
PV( int     , pv_PACMAN_PACMAN_STATE	, "{NAME}:PACMAN_PACMAN_STATE"	, PV_MON );
PV( string  , pv_SS_PACMAN				, "{NAME}:SS_PACMAN"			, PV_NONE );
PVA( short	, pv_PACMAN_PLAY_FIELD, 1024, "{NAME}:PACMAN_PLAY_FIELD"	, PV_MON);

%{
	static int get_array_index_from_xy (int x, int y, int PACMAN_ARRAY_X_SIZE, int PACMAN_ARRAY_X_FACTOR) {
		int index = 0;
		int column = (int) (x / PACMAN_ARRAY_X_FACTOR);
		int row = (int) (y / PACMAN_ARRAY_X_FACTOR);
		if (column < 0 || column >= PACMAN_ARRAY_X_SIZE || row < 0 || row >= PACMAN_ARRAY_X_SIZE) {
			return -1; // out of bounds
		}
		index = row * PACMAN_ARRAY_X_SIZE + column;
		return index;
	}

	static int get_x_from_index (int index, int PACMAN_FIELD_SIZE, int PACMAN_ARRAY_X_SIZE, int PACMAN_ARRAY_X_FACTOR) {
		if (index < 0 || index >= PACMAN_FIELD_SIZE) {
			return -1; // out of bounds
		}
		return (index % PACMAN_ARRAY_X_SIZE) * PACMAN_ARRAY_X_FACTOR;
	}

	static int get_y_from_index (int index, int PACMAN_FIELD_SIZE, int PACMAN_ARRAY_X_SIZE, int PACMAN_ARRAY_X_FACTOR) {
		if (index < 0 || index >= PACMAN_FIELD_SIZE) {
			return -1; // out of bounds
		}
		return (index / PACMAN_ARRAY_X_SIZE) * PACMAN_ARRAY_X_FACTOR;
	}
}%

ss pacman_game {
    state INIT {
		entry {
			pvSetStr( pv_SS_PACMAN, "INIT" );
			pvSet(pv_PACMAN_USER_X, 25); // Initial X position
			pvSet(pv_PACMAN_USER_Y, 25); // Initial Y position
			pvSet(pv_PACMAN_USER_DIRECTION, 0); // Initial direction (0=right, 1=left, 2=up, 3=down)
		}
        when () {
	        printf( "PACMAN Started\n" );

		} state MOVE_RIGHT
    }

	state MOVE_RIGHT {
        entry { pvSetStr(pv_SS_PACMAN, "MOVE_RIGHT"); }
        when (pv_PACMAN_USER_DIRECTION != 0) {
        } state MOVE_ANY
        when (delay(0.02)) {
            int idx = get_array_index_from_xy(pv_PACMAN_USER_X + 1, pv_PACMAN_USER_Y, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
            if (idx < 0 || pv_PACMAN_PLAY_FIELD[idx] == 1) {
                // Stop walking if blocked
				if (pv_PACMAN_PACMAN_STATE == 0) {
					pvSet(pv_PACMAN_PACMAN_STATE, 1); // Change state to "blocked"
				}
            } else {
                pvSet(pv_PACMAN_USER_X, pv_PACMAN_USER_X + 1);
            }
        } state MOVE_RIGHT
    }
		
	state MOVE_LEFT {
        entry { pvSetStr(pv_SS_PACMAN, "MOVE_LEFT"); }
        when (pv_PACMAN_USER_DIRECTION != 1) {
        } state MOVE_ANY
        when (delay(0.02)) {
            int idx = get_array_index_from_xy(pv_PACMAN_USER_X - 1, pv_PACMAN_USER_Y, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
            if (idx < 0 || pv_PACMAN_PLAY_FIELD[idx] == 1) {
                // Stop walking if blocked
				if (pv_PACMAN_PACMAN_STATE == 0) {
					pvSet(pv_PACMAN_PACMAN_STATE, 1); // Change state to "blocked"
				}
            } else {
                pvSet(pv_PACMAN_USER_X, pv_PACMAN_USER_X - 1);
            }
        } state MOVE_LEFT
    }

	// y=0 is top

	state MOVE_UP {
        entry { pvSetStr(pv_SS_PACMAN, "MOVE_UP"); }
        when (pv_PACMAN_USER_DIRECTION != 2) {
        } state MOVE_ANY
        when (delay(0.02)) {
            int idx = get_array_index_from_xy(pv_PACMAN_USER_X, pv_PACMAN_USER_Y - 1, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
            if (idx < 0 || pv_PACMAN_PLAY_FIELD[idx] == 1) {
                // Stop walking if blocked
				if (pv_PACMAN_PACMAN_STATE == 0) {
					pvSet(pv_PACMAN_PACMAN_STATE, 1); // Change state to "blocked"
				}
            } else {
                pvSet(pv_PACMAN_USER_Y, pv_PACMAN_USER_Y - 1);
            }
        } state MOVE_UP
    }

	state MOVE_DOWN {
        entry { pvSetStr(pv_SS_PACMAN, "MOVE_DOWN"); }
        when (pv_PACMAN_USER_DIRECTION != 3) {
        } state MOVE_ANY
        when (delay(0.02)) {
            int idx = get_array_index_from_xy(pv_PACMAN_USER_X, pv_PACMAN_USER_Y + 1, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
            if (idx < 0 || pv_PACMAN_PLAY_FIELD[idx] == 1) {
                // Stop walking if blocked
				if (pv_PACMAN_PACMAN_STATE == 0) {
					pvSet(pv_PACMAN_PACMAN_STATE, 1); // Change state to "blocked"
				}
            } else {
                pvSet(pv_PACMAN_USER_Y, pv_PACMAN_USER_Y + 1);
            }
        } state MOVE_DOWN
    }

    state MOVE_ANY {
		entry {
			if (pv_PACMAN_PACMAN_STATE == 1) {
				pvSet(pv_PACMAN_PACMAN_STATE, 0); // Reset state to "walking"
			}
			pvSetStr(pv_SS_PACMAN, "MOVE_ANY");
		}		
        when (pv_PACMAN_USER_DIRECTION == 0) { } state MOVE_RIGHT
        when (pv_PACMAN_USER_DIRECTION == 1) { } state MOVE_LEFT
        when (pv_PACMAN_USER_DIRECTION == 2) { } state MOVE_UP
        when (pv_PACMAN_USER_DIRECTION == 3) { } state MOVE_DOWN
    }
}