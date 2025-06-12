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
PV( int     , pv_PACMAN_TRY_DIRECTION	, "{NAME}:PACMAN_TRY_DIRECTION"	, PV_MON );
PV( int     , pv_PACMAN_STOP_DIRECTION	, "{NAME}:PACMAN_STOP_DIRECTION", PV_MON );
PV( int     , pv_PACMAN_FIELD_SIZE    	, "{NAME}:PACMAN_FIELD_SIZE"	, PV_MON );
PV( int     , pv_PACMAN_RESERVE_SIZE	, "{NAME}:PACMAN_RESERVE_SIZE"	, PV_MON );
PV( int     , pv_PACMAN_ARRAY_X_SIZE	, "{NAME}:PACMAN_ARRAY_X_SIZE"	, PV_MON );
PV( int     , pv_PACMAN_ARRAY_X_FACTOR	, "{NAME}:PACMAN_ARRAY_X_FACTOR", PV_MON );
PV( int     , pv_PACMAN_PACMAN_STATE	, "{NAME}:PACMAN_PACMAN_STATE"	, PV_MON );
PV( int     , pv_PACMAN_PACMAN_ABORT	, "{NAME}:PACMAN_PACMAN_ABORT"	, PV_MON );
PV( int     , pv_PACMAN_PACMAN_SIZE     , "{NAME}:PACMAN_PACMAN_SIZE"	, PV_MON );
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

    static char* toString(int value) {
        static char buffer[20];
        snprintf(buffer, sizeof(buffer), "%d", value);
        return buffer;
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

		} state MOVE_CHECK

    }

    state MOVE_CHECK {
        entry {  
            int current_index;
            int second_index;
            int third_index;
            int offset = (int)(pv_PACMAN_PACMAN_SIZE / 2);

            // right
            if(pv_PACMAN_USER_DIRECTION == 0){
                current_index = get_array_index_from_xy(pv_PACMAN_USER_X + offset, pv_PACMAN_USER_Y, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
                second_index = current_index + 1;
                third_index = second_index + pv_PACMAN_ARRAY_X_SIZE; // Check field below the next field to the right
                if (pv_PACMAN_PLAY_FIELD[third_index] == 1 && pv_PACMAN_PLAY_FIELD[second_index] == 0) {
                    // correct position - y 1
                    pvSet(pv_PACMAN_USER_Y, pv_PACMAN_USER_Y - pv_PACMAN_ARRAY_X_FACTOR - pv_PACMAN_RESERVE_SIZE);
                }
                if (pv_PACMAN_PLAY_FIELD[third_index] == 0 && pv_PACMAN_PLAY_FIELD[second_index] == 1) {
                    // correct position - y 0
                    pvSet(pv_PACMAN_USER_Y, pv_PACMAN_USER_Y + pv_PACMAN_ARRAY_X_FACTOR + pv_PACMAN_RESERVE_SIZE);
                }
                printf("right current_index: %d second_index: %d third_index: %d x: %d y: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
                printf("right current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
                if (second_index < 0 || pv_PACMAN_PLAY_FIELD[second_index] == 1 || pv_PACMAN_PACMAN_ABORT == 1) {
                    // Stop walking if blocked
                    if (pv_PACMAN_PACMAN_STATE == 0) {
                        pvSet(pv_PACMAN_PACMAN_STATE, 1); // Change state to "blocked"
                    }
                } else {
                    if (pv_PACMAN_PLAY_FIELD[second_index] == 2) {
                        pvSet(pv_PACMAN_PACMAN_STATE, 2); // Teleport Pacman to the other side
                    }
                    if (pv_PACMAN_PACMAN_STATE == 1 && pv_PACMAN_PACMAN_ABORT == 0) {
                        pvSet(pv_PACMAN_PACMAN_STATE, 0); // Change state to "walking"
                    }
                }
            }
            // left 
            if(pv_PACMAN_USER_DIRECTION == 1){
                current_index = get_array_index_from_xy(pv_PACMAN_USER_X - offset, pv_PACMAN_USER_Y, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
                second_index = current_index - 1; // Check previous field to the left
                third_index = second_index + pv_PACMAN_ARRAY_X_SIZE; // Check field below the previous field to the left
                if (pv_PACMAN_PLAY_FIELD[third_index] == 1 && pv_PACMAN_PLAY_FIELD[second_index] == 0) {
                    // correct position - y 1
                    pvSet(pv_PACMAN_USER_Y, pv_PACMAN_USER_Y - pv_PACMAN_ARRAY_X_FACTOR - pv_PACMAN_RESERVE_SIZE);
                }
                if (pv_PACMAN_PLAY_FIELD[third_index] == 0 && pv_PACMAN_PLAY_FIELD[second_index] == 1) {
                    // correct position - y 0
                    pvSet(pv_PACMAN_USER_Y, pv_PACMAN_USER_Y + pv_PACMAN_ARRAY_X_FACTOR + pv_PACMAN_RESERVE_SIZE);
                }
                printf("left current_index: %d second_index: %d third_index: %d x: %d y: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
                printf("left current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
                if (second_index < 0 || pv_PACMAN_PLAY_FIELD[second_index] == 1 || pv_PACMAN_PACMAN_ABORT == 1) {
                    // Stop walking if blocked
                    if (pv_PACMAN_PACMAN_STATE == 0) {
                        pvSet(pv_PACMAN_PACMAN_STATE, 1); // Change state to "blocked"
                    }
                } else {
                    if (pv_PACMAN_PLAY_FIELD[second_index] == 2) {
                        pvSet(pv_PACMAN_PACMAN_STATE, 2); // Teleport Pacman to the other side
                    }
                    if (pv_PACMAN_PACMAN_STATE == 1 && pv_PACMAN_PACMAN_ABORT == 0) {
                        pvSet(pv_PACMAN_PACMAN_STATE, 0); // Change state to "walking"
                    }
                }            
            }
            // up
            if(pv_PACMAN_USER_DIRECTION == 2){
                current_index = get_array_index_from_xy(pv_PACMAN_USER_X, pv_PACMAN_USER_Y - offset, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
                second_index = current_index - pv_PACMAN_ARRAY_X_SIZE; // Check field above
                third_index = second_index + 1; // Check field to the right of the above field
                if (pv_PACMAN_PLAY_FIELD[third_index] == 1 && pv_PACMAN_PLAY_FIELD[second_index] == 0) {
                    // correct position - x 1
                    pvSet(pv_PACMAN_USER_X, pv_PACMAN_USER_X + pv_PACMAN_ARRAY_X_FACTOR + pv_PACMAN_RESERVE_SIZE);
                }
                if (pv_PACMAN_PLAY_FIELD[third_index] == 0 && pv_PACMAN_PLAY_FIELD[second_index] == 1) {
                    // correct position - x 0
                    pvSet(pv_PACMAN_USER_X, pv_PACMAN_USER_X - pv_PACMAN_ARRAY_X_FACTOR - pv_PACMAN_RESERVE_SIZE);
                }
                printf("up current_index: %d second_index: %d third_index: %d x: %d y: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
                printf("up current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
                if (second_index < 0 || pv_PACMAN_PLAY_FIELD[second_index] == 1 || pv_PACMAN_PACMAN_ABORT == 1) {
                    // Stop walking if blocked
                    if (pv_PACMAN_PACMAN_STATE == 0) {
                        pvSet(pv_PACMAN_PACMAN_STATE, 1); // Change state to "blocked"
                    }
                } else {
                    if (pv_PACMAN_PLAY_FIELD[second_index] == 2) {
                        pvSet(pv_PACMAN_PACMAN_STATE, 2); // Teleport Pacman to the other side
                    }
                    if (pv_PACMAN_PACMAN_STATE == 1 && pv_PACMAN_PACMAN_ABORT == 0) {
                        pvSet(pv_PACMAN_PACMAN_STATE, 0); // Change state to "walking"
                    }
                }
            }
            // down
            if(pv_PACMAN_USER_DIRECTION == 3){
                current_index = get_array_index_from_xy(pv_PACMAN_USER_X, pv_PACMAN_USER_Y + offset, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
                second_index = current_index + pv_PACMAN_ARRAY_X_SIZE; // Check field below
                third_index = second_index + 1; // Check field to the right of the below field
                if (pv_PACMAN_PLAY_FIELD[third_index] == 1 && pv_PACMAN_PLAY_FIELD[second_index] == 0) {
                    // correct position - x 1
                    pvSet(pv_PACMAN_USER_X, pv_PACMAN_USER_X + pv_PACMAN_ARRAY_X_FACTOR + pv_PACMAN_RESERVE_SIZE);
                }
                if (pv_PACMAN_PLAY_FIELD[third_index] == 0 && pv_PACMAN_PLAY_FIELD[second_index] == 1) {
                    // correct position - x 0
                    pvSet(pv_PACMAN_USER_X, pv_PACMAN_USER_X - pv_PACMAN_ARRAY_X_FACTOR - pv_PACMAN_RESERVE_SIZE);
                }
                printf("down current_index: %d second_index: %d third_index: %d x: %d y: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
                printf("down current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
                if (second_index < 0 || pv_PACMAN_PLAY_FIELD[second_index] == 1 || pv_PACMAN_PACMAN_ABORT == 1) {
                    // Stop walking if blocked
                    if (pv_PACMAN_PACMAN_STATE == 0) {
                        pvSet(pv_PACMAN_PACMAN_STATE, 1); // Change state to "blocked"
                    }
                } else {
                    if (pv_PACMAN_PLAY_FIELD[second_index] == 2) {
                        pvSet(pv_PACMAN_PACMAN_STATE, 2); // Teleport Pacman to the other side
                    }
                    if (pv_PACMAN_PACMAN_STATE == 1 && pv_PACMAN_PACMAN_ABORT == 0) {
                        pvSet(pv_PACMAN_PACMAN_STATE, 0); // Change state to "walking"
                    }
                }
            }
        }

        when (pv_PACMAN_TRY_DIRECTION != -1 && pv_PACMAN_TRY_DIRECTION != pv_PACMAN_USER_DIRECTION) {
            // If try direction is not right, change to TRY_MOVE
        } state TRY_MOVE
        when (pv_PACMAN_PACMAN_STATE == 2) {

        } state TELEPORT
        when (pv_PACMAN_PACMAN_STATE != 0) {
            // If Pacman is blocked, do not move
        } state MOVE_STOP
        when () {

        } state MOVE
        
    }



    state MOVE {
        when (pv_PACMAN_USER_DIRECTION == 0) {
            // Move right
            pvSetStr(pv_SS_PACMAN, "MOVE_RIGHT");
            pvSet(pv_PACMAN_USER_X, pv_PACMAN_USER_X + 1);
        } state MOVE_CHECK
        when (pv_PACMAN_USER_DIRECTION == 1) {
            // Move left
            pvSetStr(pv_SS_PACMAN, "MOVE_LEFT");
            pvSet(pv_PACMAN_USER_X, pv_PACMAN_USER_X - 1);
        } state MOVE_CHECK
        when (pv_PACMAN_USER_DIRECTION == 2) {
            // Move up
            pvSetStr(pv_SS_PACMAN, "MOVE_UP");
            pvSet(pv_PACMAN_USER_Y, pv_PACMAN_USER_Y - 1);
        } state MOVE_CHECK
        when (pv_PACMAN_USER_DIRECTION == 3) {
            // Move down
            pvSetStr(pv_SS_PACMAN, "MOVE_DOWN");
            pvSet(pv_PACMAN_USER_Y, pv_PACMAN_USER_Y + 1);
        } state MOVE_CHECK
        when (pv_PACMAN_USER_DIRECTION == -1) {
            // If no direction is set, stay in this state
        } state MOVE_CHECK
        when () {
            // If no conditions are met, do nothing
        } state MOVE_CHECK
    }

    state MOVE_STOP {
        entry { 
            pvSetStr(pv_SS_PACMAN, "MOVE_STOP"); 
            if (pv_PACMAN_PACMAN_STATE != 1) {
                pvSet(pv_PACMAN_PACMAN_STATE, 1); // Change state to "blocked"
            }
            pvSet(pv_PACMAN_STOP_DIRECTION, pv_PACMAN_USER_DIRECTION);
            pvSet(pv_PACMAN_TRY_DIRECTION, -1); // Reset try direction
        }
        when (pv_PACMAN_STOP_DIRECTION == pv_PACMAN_USER_DIRECTION && pv_PACMAN_STOP_DIRECTION == -1) {
            // If already stopped, stay in this state
        } state MOVE_STOP
        when (pv_PACMAN_USER_DIRECTION != pv_PACMAN_STOP_DIRECTION) {
            // If direction changes, go to MOVE_ANY
            pvSet(pv_PACMAN_STOP_DIRECTION, -1); // Reset stop direction
        } state MOVE_CHECK
        when (pv_PACMAN_TRY_DIRECTION != -1) {
            // If try direction is set, go to TRY_MOVE
        } state TRY_MOVE
    }

    /*
    state TELEPORT_RIGHT {
        entry {
            int idx;
            pvSetStr(pv_SS_PACMAN, "TELEPORT_RIGHT"); 
            idx = get_x_from_index(pv_PACMAN_ARRAY_X_SIZE - 1, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
            pvSet(pv_PACMAN_USER_X, idx); // Reset X position to the right side
        }
        when () {
            pvSet(pv_PACMAN_PACMAN_STATE, 0); // Change state to "walking"
        } state MOVE_LEFT
    }

    state TELEPORT_LEFT {
        entry { pvSetStr(pv_SS_PACMAN, "TELEPORT_LEFT"); }
        when () {
            pvSet(pv_PACMAN_USER_X, 0); // Reset X position to the left side
            pvSet(pv_PACMAN_PACMAN_STATE, 0); // Change state to "walking"
        } state MOVE_RIGHT
    }

	state MOVE_RIGHT {
        entry { pvSetStr(pv_SS_PACMAN, "MOVE_RIGHT"); }
        when (delay(0.02)) {
            pvSet(pv_PACMAN_USER_X, pv_PACMAN_USER_X + 1);
        } state MOVE_RIGHT_CHECK
    }

    state MOVE_RIGHT_CHECK {
        entry { 
            int current_index;
            int next_index;
            int bl_next_index;
            pvSetStr(pv_SS_PACMAN, "MOVE_RIGHT_CHECK"); 
            current_index = get_array_index_from_xy(pv_PACMAN_USER_X + (int)(pv_PACMAN_PACMAN_SIZE / 2), pv_PACMAN_USER_Y, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
            next_index = current_index + 1; // Check next field to the right
            bl_next_index = next_index + pv_PACMAN_ARRAY_X_SIZE; // Check field below the next field to the right
            if (pv_PACMAN_PLAY_FIELD[bl_next_index] == 1 && pv_PACMAN_PLAY_FIELD[next_index] == 0) {
                // correct position - y 1
                pvSet(pv_PACMAN_USER_Y, pv_PACMAN_USER_Y - pv_PACMAN_ARRAY_X_FACTOR - pv_PACMAN_RESERVE_SIZE);
            }
            if (pv_PACMAN_PLAY_FIELD[bl_next_index] == 0 && pv_PACMAN_PLAY_FIELD[next_index] == 1) {
                // correct position - y 0
                pvSet(pv_PACMAN_USER_Y, pv_PACMAN_USER_Y + pv_PACMAN_ARRAY_X_FACTOR + pv_PACMAN_RESERVE_SIZE);
            }
            printf("right current_index: %d next_index: %d bl_next_index: %d x: %d y: %d\n", current_index, next_index, bl_next_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
            printf("right current_index_state: %d next_index_state: %d bl_next_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[next_index], pv_PACMAN_PLAY_FIELD[bl_next_index]);
            if (next_index < 0 || pv_PACMAN_PLAY_FIELD[next_index] == 1 || pv_PACMAN_PACMAN_ABORT == 1) {
                // Stop walking if blocked
                if (pv_PACMAN_PACMAN_STATE == 0) {
                    pvSet(pv_PACMAN_PACMAN_STATE, 1); // Change state to "blocked"
                }
            } else {
                if (pv_PACMAN_PLAY_FIELD[next_index] == 2) {
                    pvSet(pv_PACMAN_PACMAN_STATE, 2); // Teleport Pacman to the other side
                }                
                if (pv_PACMAN_PACMAN_STATE == 1 && pv_PACMAN_PACMAN_ABORT == 0) {
                    pvSet(pv_PACMAN_PACMAN_STATE, 0); // Change state to "walking"
                }
            }
        }

        when (pv_PACMAN_TRY_DIRECTION != -1 && pv_PACMAN_TRY_DIRECTION != 0) {
            // If try direction is not right, change to TRY_MOVE_ANY
        } state TRY_MOVE_ANY
        when (pv_PACMAN_PACMAN_STATE == 2) {

        } state TELEPORT_LEFT
        when (pv_PACMAN_USER_DIRECTION != 0) {
            // If direction is not right, change to MOVE_ANY
        } state MOVE_ANY
        when (pv_PACMAN_PACMAN_STATE != 0) {
            // If Pacman is blocked, do not move
        } state MOVE_STOP
        when () {

        } state MOVE_RIGHT

    }

	state MOVE_LEFT {
        entry { pvSetStr(pv_SS_PACMAN, "MOVE_LEFT"); }
        when (delay(0.02)) {
            pvSet(pv_PACMAN_USER_X, pv_PACMAN_USER_X - 1);
        } state MOVE_LEFT_CHECK
    }

    state MOVE_LEFT_CHECK {
        entry { 
            int current_index;
            int previous_index;
            int bl_previous_index;
            pvSetStr(pv_SS_PACMAN, "MOVE_LEFT_CHECK"); 
            current_index = get_array_index_from_xy(pv_PACMAN_USER_X - pv_PACMAN_RESERVE_SIZE, pv_PACMAN_USER_Y, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
            previous_index = current_index - 1; // Check previous field to the left
            bl_previous_index = previous_index + pv_PACMAN_ARRAY_X_SIZE;
            if (pv_PACMAN_PLAY_FIELD[bl_previous_index] == 1 && pv_PACMAN_PLAY_FIELD[previous_index] == 0) {
                // correct position - y 1
                pvSet(pv_PACMAN_USER_Y, pv_PACMAN_USER_Y - pv_PACMAN_ARRAY_X_FACTOR - pv_PACMAN_RESERVE_SIZE);
            }
            if (pv_PACMAN_PLAY_FIELD[bl_previous_index] == 0 && pv_PACMAN_PLAY_FIELD[previous_index] == 1) {
                // correct position - y 0
                pvSet(pv_PACMAN_USER_Y, pv_PACMAN_USER_Y + pv_PACMAN_ARRAY_X_FACTOR + pv_PACMAN_RESERVE_SIZE);
            }
            printf("left current_index: %d previous_index: %d bl_previous_index: %d x: %d y: %d\n", current_index, previous_index, bl_previous_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
            printf("left current_index_state: %d previous_index_state: %d bl_previous_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[previous_index], pv_PACMAN_PLAY_FIELD[bl_previous_index]);
            
            if (previous_index < 0 || pv_PACMAN_PLAY_FIELD[previous_index] == 1 || pv_PACMAN_PACMAN_ABORT == 1) {
                // Stop walking if blocked
                if (pv_PACMAN_PACMAN_STATE == 0) {
                    pvSet(pv_PACMAN_PACMAN_STATE, 1); // Change state to "blocked"
                }
            } else {
                if (pv_PACMAN_PLAY_FIELD[previous_index] == 2) {
                    pvSet(pv_PACMAN_PACMAN_STATE, 2); // Teleport Pacman to the other side
                }
                if (pv_PACMAN_PACMAN_STATE == 1 && pv_PACMAN_PACMAN_ABORT == 0) {
                    pvSet(pv_PACMAN_PACMAN_STATE, 0); // Change state to "walking"
                }
            }
        }

        when (pv_PACMAN_TRY_DIRECTION != -1 && pv_PACMAN_TRY_DIRECTION != 1) {
            // If try direction is not left, change to TRY_MOVE_ANY
        } state TRY_MOVE_ANY
        when (pv_PACMAN_PACMAN_STATE == 2) {

        } state TELEPORT_RIGHT
        when (pv_PACMAN_USER_DIRECTION != 1) {
            // If direction is not left, change to MOVE_ANY
        } state MOVE_ANY
        when (pv_PACMAN_PACMAN_STATE != 0) {
            // If Pacman is blocked, do not move
        } state MOVE_STOP
        when () {

        } state MOVE_LEFT
    }

	// y=0 is top

	state MOVE_UP {
        entry { pvSetStr(pv_SS_PACMAN, "MOVE_UP"); }
        when (delay(0.02)) {
            pvSet(pv_PACMAN_USER_Y, pv_PACMAN_USER_Y - 1);
        } state MOVE_UP_CHECK
    }

    state MOVE_UP_CHECK {
        entry { 
            int current_index;
            int above_index;
            int r_above_index;
            pvSetStr(pv_SS_PACMAN, "MOVE_UP_CHECK");
            current_index = get_array_index_from_xy(pv_PACMAN_USER_X, pv_PACMAN_USER_Y - pv_PACMAN_RESERVE_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
            above_index = current_index - pv_PACMAN_ARRAY_X_SIZE; // Check field above
            r_above_index = above_index + 1; // Check field to the right of the above field
            if (pv_PACMAN_PLAY_FIELD[r_above_index] == 1 && pv_PACMAN_PLAY_FIELD[above_index] == 0) {
                // correct position - x 1
                pvSet(pv_PACMAN_USER_X, pv_PACMAN_USER_X + pv_PACMAN_ARRAY_X_FACTOR + pv_PACMAN_RESERVE_SIZE);
            }
            if (pv_PACMAN_PLAY_FIELD[r_above_index] == 0 && pv_PACMAN_PLAY_FIELD[above_index] == 1) {
                // correct position - x 0
                pvSet(pv_PACMAN_USER_X, pv_PACMAN_USER_X - pv_PACMAN_ARRAY_X_FACTOR - pv_PACMAN_RESERVE_SIZE);
            }
            printf("up current_index: %d above_index: %d r_above_index: %d x: %d y: %d\n", current_index, above_index, r_above_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
            printf("up current_index_state: %d above_index_state: %d r_above_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[above_index], pv_PACMAN_PLAY_FIELD[r_above_index]);
            if (above_index < 0 || pv_PACMAN_PLAY_FIELD[above_index] == 1 || pv_PACMAN_PACMAN_ABORT == 1) {
                // Stop walking if blocked
                if (pv_PACMAN_PACMAN_STATE == 0) {
                    pvSet(pv_PACMAN_PACMAN_STATE, 1); // Change state to "blocked"
                }
            } else {
                if (pv_PACMAN_PLAY_FIELD[above_index] == 2) {
                    pvSet(pv_PACMAN_PACMAN_STATE, 2); // Teleport Pacman to the other side
                }
                if (pv_PACMAN_PACMAN_STATE == 1 && pv_PACMAN_PACMAN_ABORT == 0) {
                    pvSet(pv_PACMAN_PACMAN_STATE, 0); // Change state to "walking"
                }
            }
        }

        when (pv_PACMAN_TRY_DIRECTION != -1 && pv_PACMAN_TRY_DIRECTION != 2) {
            // If try direction is not up, change to TRY_MOVE_ANY
        } state TRY_MOVE_ANY
        when (pv_PACMAN_USER_DIRECTION != 2) {
            // If direction is not up, change to MOVE_ANY
        } state MOVE_ANY
        when (pv_PACMAN_PACMAN_STATE != 0) {
            // If Pacman is blocked, do not move
        } state MOVE_STOP
        when () {

        } state MOVE_UP
    }

	state MOVE_DOWN {
        entry { pvSetStr(pv_SS_PACMAN, "MOVE_DOWN"); }
        when (delay(0.02)) {
            pvSet(pv_PACMAN_USER_Y, pv_PACMAN_USER_Y + 1);
        } state MOVE_DOWN_CHECK        
    }

    state MOVE_DOWN_CHECK {
        entry { 
            int idx;
            pvSetStr(pv_SS_PACMAN, "MOVE_DOWN_CHECK"); 
            idx = get_array_index_from_xy(pv_PACMAN_USER_X, pv_PACMAN_USER_Y + pv_PACMAN_PACMAN_SIZE + pv_PACMAN_RESERVE_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
            if (idx < 0 || pv_PACMAN_PLAY_FIELD[idx] == 1) {
                // Stop walking if blocked
                if (pv_PACMAN_PACMAN_STATE == 0) {
                    pvSet(pv_PACMAN_PACMAN_STATE, 1); // Change state to "blocked"
                }
            } else {
                pvSet(pv_PACMAN_USER_Y, pv_PACMAN_USER_Y + 1);
                if (pv_PACMAN_PACMAN_STATE == 1) {
                    pvSet(pv_PACMAN_PACMAN_STATE, 0); // Change state to "walking"
                }
            }
        }
        when (pv_PACMAN_TRY_DIRECTION != -1 && pv_PACMAN_TRY_DIRECTION != 3) {
            // If try direction is not down, change to TRY_MOVE_ANY
        } state TRY_MOVE_ANY
        when (pv_PACMAN_USER_DIRECTION != 3) {
            // If direction is not down, change to MOVE_ANY
        } state MOVE_ANY
        when (pv_PACMAN_PACMAN_STATE != 0) {
            // If Pacman is blocked, do not move
        } state MOVE_STOP
        when () {

        } state MOVE_DOWN
    }

    state TRY_MOVE_ANY {
        entry { 
           pvSetStr(pv_SS_PACMAN, "TRY_MOVE_ANY");
           pvSet(pv_PACMAN_STOP_DIRECTION, -1); // Reset stop direction
        }
        when (pv_PACMAN_TRY_DIRECTION == -1 || pv_PACMAN_USER_DIRECTION == pv_PACMAN_TRY_DIRECTION) {
            // If the user direction matches the try direction, go to MOVE_ANY
        } state MOVE_ANY
        when (pv_PACMAN_TRY_DIRECTION == 0) {} state TRY_MOVE_RIGHT
        when (pv_PACMAN_TRY_DIRECTION == 1) {} state TRY_MOVE_LEFT
        when (pv_PACMAN_TRY_DIRECTION == 2) {} state TRY_MOVE_UP
        when (pv_PACMAN_TRY_DIRECTION == 3) {} state TRY_MOVE_DOWN
    }

    state TRY_MOVE_RIGHT {
        // check if the user can move right
        entry {
            int idx;
            pvSetStr(pv_SS_PACMAN, "TRY_MOVE_RIGHT");
            idx = get_array_index_from_xy(pv_PACMAN_USER_X + pv_PACMAN_PACMAN_SIZE + pv_PACMAN_RESERVE_SIZE, pv_PACMAN_USER_Y, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
            if (idx < 0 || pv_PACMAN_PLAY_FIELD[idx] == 1) {
                // If blocked, set try direction -1
                pvSet(pv_PACMAN_TRY_DIRECTION, -1);
            } else {
                // If not blocked, set try direction to right
                pvSet(pv_PACMAN_USER_DIRECTION, 0);
            }
        }

        when () {
        } state MOVE_ANY
    }

    state TRY_MOVE_LEFT {
        // check if the user can move left
        entry {
            int idx;
            pvSetStr(pv_SS_PACMAN, "TRY_MOVE_LEFT");
            idx = get_array_index_from_xy(pv_PACMAN_USER_X - pv_PACMAN_RESERVE_SIZE, pv_PACMAN_USER_Y, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
            if (idx < 0 || pv_PACMAN_PLAY_FIELD[idx] == 1) {
                // If blocked, set try direction -1
                pvSet(pv_PACMAN_TRY_DIRECTION, -1);
            } else {
                // If not blocked, set try direction to left
                pvSet(pv_PACMAN_USER_DIRECTION, 1);
            }
        }

        when () {
        } state MOVE_ANY
    }
    state TRY_MOVE_UP {
        // check if the user can move up
        entry {
            int idx;
            pvSetStr(pv_SS_PACMAN, "TRY_MOVE_UP");
            idx = get_array_index_from_xy(pv_PACMAN_USER_X, pv_PACMAN_USER_Y - pv_PACMAN_RESERVE_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
            if (idx < 0 || pv_PACMAN_PLAY_FIELD[idx] == 1) {
                // If blocked, set try direction -1
                pvSet(pv_PACMAN_TRY_DIRECTION, -1);
            } else {
                // If not blocked, set try direction to up
                pvSet(pv_PACMAN_USER_DIRECTION, 2);
            }
        }

        when () {
        } state MOVE_ANY
    }
    state TRY_MOVE_DOWN {
        // check if the user can move down
        entry {
            int idx;
            pvSetStr(pv_SS_PACMAN, "TRY_MOVE_DOWN");
            idx = get_array_index_from_xy(pv_PACMAN_USER_X, pv_PACMAN_USER_Y + pv_PACMAN_PACMAN_SIZE + pv_PACMAN_RESERVE_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
            if (idx < 0 || pv_PACMAN_PLAY_FIELD[idx] == 1) {
                // If blocked, set try direction -1
                pvSet(pv_PACMAN_TRY_DIRECTION, -1);
            } else {
                // If not blocked, set try direction to down
                pvSet(pv_PACMAN_USER_DIRECTION, 3);
            }
        }
        when () {
        } state MOVE_ANY
    }

    state MOVE_ANY {
		entry { pvSetStr(pv_SS_PACMAN, "MOVE_ANY"); }
        when (pv_PACMAN_USER_DIRECTION == pv_PACMAN_STOP_DIRECTION) {
            // If stopped, go to MOVE_STOP
        } state MOVE_STOP
        when (pv_PACMAN_USER_DIRECTION == 0) { } state MOVE_RIGHT_CHECK
        when (pv_PACMAN_USER_DIRECTION == 1) { } state MOVE_LEFT_CHECK
        when (pv_PACMAN_USER_DIRECTION == 2) { } state MOVE_UP_CHECK
        when (pv_PACMAN_USER_DIRECTION == 3) { } state MOVE_DOWN_CHECK
    }*/
}