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
PV( int     , pv_PACMAN_ARRAY_ROW       , "{NAME}:PACMAN_ARRAY_ROW"	    , PV_MON );
PV( int     , pv_PACMAN_ARRAY_COL       , "{NAME}:PACMAN_ARRAY_COL"	    , PV_MON );
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
            int half_offset = (int)(pv_PACMAN_PACMAN_SIZE / 4);

            pvSetStr(pv_SS_PACMAN, "MOVE_CHECK");

            pvSet(pv_PACMAN_ARRAY_COL, (int)(pv_PACMAN_USER_X / pv_PACMAN_ARRAY_X_FACTOR));
            pvSet(pv_PACMAN_ARRAY_ROW, (int)(pv_PACMAN_USER_Y / pv_PACMAN_ARRAY_X_FACTOR));

            // right
            if(pv_PACMAN_USER_DIRECTION == 0){
                current_index = get_array_index_from_xy(pv_PACMAN_USER_X + offset, pv_PACMAN_USER_Y, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
                second_index = current_index + 1;
                third_index = second_index + pv_PACMAN_ARRAY_X_SIZE; // Check field below the next field to the right
                if (pv_PACMAN_PLAY_FIELD[third_index] == 1 && pv_PACMAN_PLAY_FIELD[second_index] == 0) {
                    // correct position - y 1 using index to get y
                    pvSet(pv_PACMAN_USER_Y, get_y_from_index(current_index - pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR));
                    pvSet(pv_PACMAN_USER_X, get_x_from_index(current_index, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR));
                    printf("corrected position right - y 1\n");
                    printf("right current_index: %d second_index: %d third_index: %d x: %d y: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
                    printf("right current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
                }
                if (pv_PACMAN_PLAY_FIELD[third_index] == 0 && pv_PACMAN_PLAY_FIELD[second_index] == 1) {
                    // correct position + y 1 using index to get y
                    pvSet(pv_PACMAN_USER_Y, get_y_from_index(third_index + pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR));
                    pvSet(pv_PACMAN_USER_X, get_x_from_index(third_index, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR));
                    printf("corrected position right y + 1\n");
                    printf("right current_index: %d second_index: %d third_index: %d x: %d y: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
                    printf("right current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
                }
                
                if (second_index < 0 || (pv_PACMAN_PLAY_FIELD[second_index] == 1 && pv_PACMAN_PLAY_FIELD[third_index] == 1) || pv_PACMAN_PACMAN_ABORT == 1) {
                    // Stop walking if blocked
                    if (pv_PACMAN_PACMAN_STATE == 0) {
                        pvSet(pv_PACMAN_PACMAN_STATE, 1); // Change state to "blocked"
                        printf("right blocked\n");
                        printf("right current_index: %d second_index: %d third_index: %d x: %d y: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
                        printf("right current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
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
                current_index = get_array_index_from_xy(pv_PACMAN_USER_X + offset, pv_PACMAN_USER_Y, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
                second_index = current_index - 1; // Check previous field to the left
                third_index = second_index + pv_PACMAN_ARRAY_X_SIZE; // Check field below the previous field to the left
                if (pv_PACMAN_PLAY_FIELD[third_index] == 1 && pv_PACMAN_PLAY_FIELD[second_index] == 0) {
                    // correct position - y 1 using index to get y
                    pvSet(pv_PACMAN_USER_Y, get_y_from_index(current_index - pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR) + offset);
                    pvSet(pv_PACMAN_USER_X, get_x_from_index(current_index, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR));
                    printf("corrected position left - y 1\n");
                    printf("left current_index: %d second_index: %d third_index: %d x: %d y: %d offset: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y, offset);
                    printf("left current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
                }
                if (pv_PACMAN_PLAY_FIELD[third_index] == 0 && pv_PACMAN_PLAY_FIELD[second_index] == 1) {
                    // correct position + y 1 using index to get y
                    pvSet(pv_PACMAN_USER_Y, get_y_from_index(current_index + pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR) - half_offset);
                    pvSet(pv_PACMAN_USER_X, get_x_from_index(current_index, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR));
                    printf("corrected position left y + 1\n");
                    printf("left current_index: %d second_index: %d third_index: %d x: %d y: %d offset: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y, offset);
                    printf("left current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
                }
                
                if (second_index < 0 || pv_PACMAN_PLAY_FIELD[second_index] == 1 || pv_PACMAN_PACMAN_ABORT == 1) {
                    // Stop walking if blocked
                    if (pv_PACMAN_PACMAN_STATE == 0) {
                        pvSet(pv_PACMAN_PACMAN_STATE, 1); // Change state to "blocked"
                        printf("left blocked\n");
                        printf("left current_index: %d second_index: %d third_index: %d x: %d y: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
                        printf("left current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
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
                current_index = get_array_index_from_xy(pv_PACMAN_USER_X, pv_PACMAN_USER_Y + offset, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
                second_index = current_index - pv_PACMAN_ARRAY_X_SIZE; // Check field above
                third_index = second_index + 1; // Check field to the right of the above field
                if (pv_PACMAN_PLAY_FIELD[third_index] == 1 && pv_PACMAN_PLAY_FIELD[second_index] == 0) {
                    // correct position - x 1 using index to get x
                    pvSet(pv_PACMAN_USER_X, get_x_from_index(current_index - 1, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR) + offset);
                    pvSet(pv_PACMAN_USER_Y, get_y_from_index(current_index, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR) + offset);
                    printf("corrected position up - x 1\n");
                    printf("up current_index: %d second_index: %d third_index: %d x: %d y: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
                    printf("up current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
                }
                if (pv_PACMAN_PLAY_FIELD[third_index] == 0 && pv_PACMAN_PLAY_FIELD[second_index] == 1) {
                    // correct position + x 1 using index to get x
                    pvSet(pv_PACMAN_USER_X, get_x_from_index(current_index + 1, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR) + offset);
                    pvSet(pv_PACMAN_USER_Y, get_y_from_index(current_index, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR));
                    printf("corrected position up x + 1\n");
                    printf("up current_index: %d second_index: %d third_index: %d x: %d y: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
                    printf("up current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
                }
                
                if (second_index < 0 || pv_PACMAN_PLAY_FIELD[second_index] == 1 || pv_PACMAN_PACMAN_ABORT == 1) {
                    // Stop walking if blocked
                    if (pv_PACMAN_PACMAN_STATE == 0) {
                        pvSet(pv_PACMAN_PACMAN_STATE, 1); // Change state to "blocked"
                        printf("up blocked\n");
                        printf("up current_index: %d second_index: %d third_index: %d x: %d y: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
                        printf("up current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
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
                    pvSet(pv_PACMAN_USER_X, get_x_from_index(third_index, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR) + offset);
                    pvSet(pv_PACMAN_USER_Y, get_y_from_index(current_index, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR));
                    printf("corrected position down - x 1\n");

                    printf("down current_index: %d second_index: %d third_index: %d x: %d y: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
                    printf("down current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
                }
                if (pv_PACMAN_PLAY_FIELD[third_index] == 0 && pv_PACMAN_PLAY_FIELD[second_index] == 1) {
                    // correct position + x 1
                    pvSet(pv_PACMAN_USER_X, get_x_from_index(current_index + 1, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR));
                    pvSet(pv_PACMAN_USER_Y, get_y_from_index(current_index, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR));
                    printf("corrected position down x + 1\n");

                    printf("down current_index: %d second_index: %d third_index: %d x: %d y: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
                    printf("down current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
                }
                
                if (second_index < 0 || pv_PACMAN_PLAY_FIELD[second_index] == 1 || pv_PACMAN_PACMAN_ABORT == 1) {
                    // Stop walking if blocked
                    if (pv_PACMAN_PACMAN_STATE == 0) {
                        pvSet(pv_PACMAN_PACMAN_STATE, 1); // Change state to "blocked"
                        printf("down blocked\n");
                        printf("down current_index: %d second_index: %d third_index: %d x: %d y: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
                        printf("down current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
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

        } state DELAY
        
    }

    state TELEPORT {
        entry {
            int pos;
            pvSetStr(pv_SS_PACMAN, "TELEPORT");
            if (pv_PACMAN_USER_DIRECTION == 0) {
                // Teleport right
                pvSet(pv_PACMAN_USER_X, 0); // Reset X position to the left side
            } else if (pv_PACMAN_USER_DIRECTION == 1) {
                // Teleport left
                pos = get_x_from_index(pv_PACMAN_ARRAY_X_SIZE - 1, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
                pvSet(pv_PACMAN_USER_X, pos); // Reset X position to the right side
            } else if (pv_PACMAN_USER_DIRECTION == 2) {
                // Teleport up
                pvSet(pv_PACMAN_USER_Y, 0); // Reset Y position to the top side
            } else if (pv_PACMAN_USER_DIRECTION == 3) {
                // Teleport down
                pos = get_y_from_index(pv_PACMAN_FIELD_SIZE - 1, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
                pvSet(pv_PACMAN_USER_Y, pos); // Reset Y position to the bottom side
            }
        }
        when () {
            pvSet(pv_PACMAN_PACMAN_STATE, 0); // Change state to "walking"
        } state MOVE_CHECK
    }

    state DELAY {
        entry { pvSetStr(pv_SS_PACMAN, "DELAY"); }
        when (delay(0.02)) {
            // Delay for 20ms
        } state MOVE
    }

    state MOVE {
        entry {
            pvSetStr(pv_SS_PACMAN, "MOVE");
        }
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

    state TRY_MOVE {
        entry {
            int current_index;
            int second_index;
            int third_index;

            int offset = 0;

            pvSetStr(pv_SS_PACMAN, "TRY_MOVE");            

            if (pv_PACMAN_TRY_DIRECTION == 0) {
                // Try move right
                current_index = get_array_index_from_xy(pv_PACMAN_USER_X + offset, pv_PACMAN_USER_Y, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
                second_index = current_index + 1;
                third_index = second_index + pv_PACMAN_ARRAY_X_SIZE; // Check field below the next field to the right
                // check if one of second_index or third_index is free
                if (pv_PACMAN_PLAY_FIELD[second_index] == 0 || pv_PACMAN_PLAY_FIELD[third_index] == 0) {
                    // If at least one is free, set try direction to right
                    pvSet(pv_PACMAN_USER_DIRECTION, 0);
                } else {
                    // If both are blocked, set try direction to -1
                    pvSet(pv_PACMAN_TRY_DIRECTION, -1);
                }

                printf("try right current_index: %d second_index: %d third_index: %d x: %d y: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
                printf("try right current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);                  
            }

            if (pv_PACMAN_TRY_DIRECTION == 1){
                // Try move left
                current_index = get_array_index_from_xy(pv_PACMAN_USER_X - offset, pv_PACMAN_USER_Y, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
                second_index = current_index - 1; // Check previous field to the left
                third_index = second_index + pv_PACMAN_ARRAY_X_SIZE; // Check field below the previous field to the left
                // check if one of second_index or third_index is free
                if (pv_PACMAN_PLAY_FIELD[second_index] == 0 || pv_PACMAN_PLAY_FIELD[third_index] == 0) {
                    // If at least one is free, set try direction to left
                    pvSet(pv_PACMAN_USER_DIRECTION, 1);
                } else {
                    // If both are blocked, set try direction to -1
                    pvSet(pv_PACMAN_TRY_DIRECTION, -1);
                }

                printf("try left current_index: %d second_index: %d third_index: %d x: %d y: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);  
                printf("try left current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
            }

            if (pv_PACMAN_TRY_DIRECTION == 2){
                // Try move up
                current_index = get_array_index_from_xy(pv_PACMAN_USER_X, pv_PACMAN_USER_Y - offset, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
                second_index = current_index - pv_PACMAN_ARRAY_X_SIZE; // Check field above
                third_index = second_index + 1; // Check field to the right of the above field
                // check if one of second_index or third_index is free
                if (pv_PACMAN_PLAY_FIELD[second_index] == 0 || pv_PACMAN_PLAY_FIELD[third_index] == 0) {
                    // If at least one is free, set try direction to up
                    pvSet(pv_PACMAN_USER_DIRECTION, 2);
                } else {
                    // If both are blocked, set try direction to -1
                    pvSet(pv_PACMAN_TRY_DIRECTION, -1);
                }

                printf("try up current_index: %d second_index: %d third_index: %d x: %d y: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
                printf("try up current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
            }

            if (pv_PACMAN_TRY_DIRECTION == 3){
                // Try move down
                current_index = get_array_index_from_xy(pv_PACMAN_USER_X, pv_PACMAN_USER_Y + offset, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
                second_index = current_index + pv_PACMAN_ARRAY_X_SIZE; // Check field below
                third_index = second_index + 1; // Check field to the right of the below field
                // check if one of second_index or third_index is free
                if (pv_PACMAN_PLAY_FIELD[second_index] == 0 || pv_PACMAN_PLAY_FIELD[third_index] == 0) {
                    // If at least one is free, set try direction to down
                    pvSet(pv_PACMAN_USER_DIRECTION, 3);
                } else {
                    // If both are blocked, set try direction to -1
                    pvSet(pv_PACMAN_TRY_DIRECTION, -1);
                }

                printf("try down current_index: %d second_index: %d third_index: %d x: %d y: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
                printf("try down current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
            }

        }
        when () {

        } state MOVE_CHECK
    }
}