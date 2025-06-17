program ghosts_pacman
#include "seqPVmacros.h"

%%#include "math.h"
%%#include "stdlib.h"
%%#include "errlog.h"
%%#include "time.h"
%%#define PRINTF errlogPrintf

/* options */
option  +r;

/* variables  ghosts */
PV( string, pv_SS_GHOSTS, "{NAME}:SS_GHOSTS", PV_NONE );
PV( int, pv_GHOSTS_NPC_DIR, "{NAME}:GHOSTS_NPC_DIR", PV_MON );  
PV( int, pv_GHOSTS_NPC_X, "{NAME}:GHOSTS_NPC_X", PV_MON );  
PV( int, pv_GHOSTS_NPC_Y, "{NAME}:GHOSTS_NPC_Y", PV_MON );  
PV( int, pv_GHOSTS_NPC_SIZE, "{NAME}:GHOSTS_NPC_SIZE", PV_MON );  
PV( int, pv_GHOSTS_NPC_MOVDIST, "{NAME}:GHOSTS_NPC_MOVDIST", PV_MON );
PV( int, pv_GHOSTS_NPC_IDX, "{NAME}:GHOSTS_NPC_IDX", PV_MON );
PV( int, pv_GHOSTS_NPC_IDXVAL, "{NAME}:GHOSTS_NPC_IDXVAL", PV_MON );    


/* variables ghost run */
PV( string, pv_SS_GHOSTS_RUN, "{NAME}:SS_GHOSTS_RUN", PV_NONE );
PV( int, pv_GHOSTS_NPC_RUN, "{NAME}:GHOSTS_NPC_RUN", PV_MON );
PV( int, pv_GHOSTS_NPC_RUNFRAME1, "{NAME}:GHOSTS_NPC_RUNFRAME1", PV_MON );
PV( int, pv_GHOSTS_NPC_RUNFRAME2, "{NAME}:GHOSTS_NPC_RUNFRAME2", PV_MON );  

/* variables from pcman */
PV( int, pv_PACMAN_ARRAY_ROW_LENGTH	, "{NAME}:PACMAN_ARRAY_X_SIZE"	, PV_MON );
PV( int, pv_PACMAN_ARRAY_CELL_WIDTH	, "{NAME}:PACMAN_ARRAY_X_FACTOR", PV_MON );
PV( int, pv_PACMAN_USER_X, "{NAME}:PACMAN_USER_X", PV_MON );
PV( int, pv_PACMAN_USER_Y, "{NAME}:PACMAN_USER_Y", PV_MON );
PVA( short, pv_PACMAN_PLAY_FIELD, 1024, "{NAME}:PACMAN_PLAY_FIELD", PV_MON);
PV( int, pv_PACMAN_FIELD_SIZE, "{NAME}:PACMAN_FIELD_SIZE"	, PV_MON );

/* Functions */
%{
    int CONST_ARRAY_ROW_LENGTH = 32;
    int CONST_ARRAY_CELL_WIDTH = 25;
    int CONST_PACMAN_FIELD_SIZE = 32*32;

    	static int get_array_index_from_xy (int x, int y) {
            int index = 0;
            int column = (int) (x / CONST_ARRAY_CELL_WIDTH);
            int row = (int) (y / CONST_ARRAY_CELL_WIDTH);
            // game is quadratic --> row and columns are of equal length
            if (column < 0 || column >= CONST_ARRAY_ROW_LENGTH || row < 0 || row >= CONST_ARRAY_ROW_LENGTH) {
                return -1; // out of bounds
            }
            index = row * CONST_ARRAY_ROW_LENGTH + column;
            return index;
	    }

      	static int get_x_from_index (int index) {
            if (index < 0 || index >= CONST_PACMAN_FIELD_SIZE) {
                return -1; // out of bounds
            }
            return (index % CONST_ARRAY_ROW_LENGTH) * CONST_ARRAY_CELL_WIDTH;
        }

    	static int get_y_from_index (int index) {
            if (index < 0 || index >= CONST_PACMAN_FIELD_SIZE) {
                return -1; // out of bounds
            }
            return (index / CONST_ARRAY_ROW_LENGTH) * CONST_ARRAY_CELL_WIDTH;
        }

        static char* toString(int value) {
            static char buffer[20];
            snprintf(buffer, sizeof(buffer), "%d", value);
            return buffer;
        }

        static int randomNr(){
            int nr;
            srand(time(NULL));
            nr = rand();
            return nr;
        }

        static int get_distance_from_pacman(int pacx, int pacy, int ghox, int ghoy){
            int diff_x = abs(ghox - pacx);
            int diff_y = abs(ghoy - pacy);
            int difference = sqrt(diff_x*diff_x + diff_y*diff_y);

            return difference;
        }

        static void get_shortest_direction_to_pacman(int index, int pacx, int pacy, int* first, int* second, int* third, int* fourth) {
            int distance[4];
            int dir[4] = {0, 1, 2, 3}; // 0=right, 1=left, 2=up, 3=down
            int idx[4] = {
                index + 1, // right
                index - 1, // left
                index - CONST_ARRAY_ROW_LENGTH, // up
                index + CONST_ARRAY_ROW_LENGTH  // down
            };

            for(int i = 0; i < 4; i++) {
                distance[i] = get_distance_from_pacman(pacx, pacy, get_x_from_index(idx[i]), get_y_from_index(idx[i]));
            }

            // Sort directions by distance (ascending)
            for(int i = 0; i < 3; i++) {
                for(int j = i + 1; j < 4; j++) {
                    if(distance[dir[j]] < distance[dir[i]]) {
                        int tmp = dir[i];
                        dir[i] = dir[j];
                        dir[j] = tmp;
                    }
                }
            }

            // Save sorted directions to pointers
            if (first)  *first  = dir[0];
            if (second) *second = dir[1];
            if (third)  *third  = dir[2];
            if (fourth) *fourth = dir[3];
        }

        static int get_surrounding_index_from_direction(int index, int direction){
            switch(direction){
                case 0: // right
                    return index + 1;
                case 1: // left
                    return index - 1;
                case 2: // up
                    return index - CONST_ARRAY_ROW_LENGTH;
                case 3: // down
                    return index + CONST_ARRAY_ROW_LENGTH;
                default:
                    return -1; // invalid direction
            }
        }

}%

// movement of ghosts
ss ghosts_pacman{
    state INIT{
        entry{
            pvSetStr(pv_SS_GHOSTS, "INIT");
            pvSet(pv_GHOSTS_NPC_SIZE, 25);
            pvSet(pv_GHOSTS_NPC_IDXVAL, 0);
            pvSet(pv_GHOSTS_NPC_MOVDIST, 5);
            pvSet(pv_GHOSTS_NPC_X, (int)pv_GHOSTS_NPC_SIZE*1.3);
            pvSet(pv_GHOSTS_NPC_Y, (int)pv_GHOSTS_NPC_SIZE*1.3);
            pvSet(pv_GHOSTS_NPC_IDX, get_array_index_from_xy(pv_GHOSTS_NPC_X + (pv_GHOSTS_NPC_SIZE/2), pv_GHOSTS_NPC_Y + (pv_GHOSTS_NPC_SIZE/2)));
        }
        when(){
        } state CHECK_MOVE
    }
    state CHECK_MOVE{
        entry{
            int idx; 
            pvSetStr( pv_SS_GHOSTS, "CHECK_MOVE" );
            idx = get_array_index_from_xy(pv_GHOSTS_NPC_X + (pv_GHOSTS_NPC_SIZE/2), pv_GHOSTS_NPC_Y + (pv_GHOSTS_NPC_SIZE/2));
            pvSet(pv_GHOSTS_NPC_IDX, idx);
            pvSet(pv_GHOSTS_NPC_IDXVAL, pv_PACMAN_PLAY_FIELD[(int)pv_GHOSTS_NPC_IDX+1]);
        }
        when(){
        } state MOVE
    }

    state MOVE{
        when(pv_GHOSTS_NPC_IDX == -1){
        }state MOVE_MIDDLE
        when(pv_GHOSTS_NPC_DIR % 4 == 0 ){
        } state MOVE_RIGHT
        when(pv_GHOSTS_NPC_DIR % 4 == 1){
        } state MOVE_LEFT
        when(pv_GHOSTS_NPC_DIR % 4 == 2){
        } state MOVE_UP
        when(pv_GHOSTS_NPC_DIR % 4 == 3){
        } state MOVE_DOWN
        
    }
    
    state MOVE_MIDDLE{
        when(delay(0.1)){
            int respawn = 370;
            pvSetStr(pv_SS_GHOSTS, "MOVE_MIDDLE");
            pvSet(pv_GHOSTS_NPC_X, respawn);
            pvSet(pv_GHOSTS_NPC_Y, respawn);
        } state CHECK_MOVE
    }

    state CHECK_MOVEABLE_DIRECTIONS{
        entry{
            int rnd = randomNr();
            int sorted_dir[4];
            int first, second, third, fourth;
            pvSetStr(pv_SS_GHOSTS, "CHECK_MOVEABLE_DIRECTIONS");
            get_shortest_direction_to_pacman(pv_GHOSTS_NPC_IDX, pv_PACMAN_USER_X, pv_PACMAN_USER_Y, &first, &second, &third, &fourth);
       
            // Check if the ghost can move in the fastest direction of the pacman, otherwise check the others in descending order
            if(pv_PACMAN_PLAY_FIELD[get_surrounding_index_from_direction(pv_GHOSTS_NPC_IDX, first)] != 1){
                pvSet(pv_GHOSTS_NPC_DIR, first);
            } else if(pv_PACMAN_PLAY_FIELD[get_surrounding_index_from_direction(pv_GHOSTS_NPC_IDX, second)] != 1){
                pvSet(pv_GHOSTS_NPC_DIR, second);
            } else if(pv_PACMAN_PLAY_FIELD[get_surrounding_index_from_direction(pv_GHOSTS_NPC_IDX, third)] != 1){
                pvSet(pv_GHOSTS_NPC_DIR, third);
            } else if(pv_PACMAN_PLAY_FIELD[get_surrounding_index_from_direction(pv_GHOSTS_NPC_IDX, fourth)] != 1){
                pvSet(pv_GHOSTS_NPC_DIR, fourth);
            }
        }when(){
        } state CHECK_MOVE
    }

    state MOVE_RIGHT{
        when(pv_GHOSTS_NPC_IDX == -1){
        } state MOVE_MIDDLE
        when(pv_PACMAN_PLAY_FIELD[((int)pv_GHOSTS_NPC_IDX+1)] == 1){
        } state CHECK_MOVEABLE_DIRECTIONS
        when(delay(0.1)){
            pvSetStr( pv_SS_GHOSTS, "MOVE_RIGHT" );
            if(pv_GHOSTS_NPC_X < 1000 && pv_GHOSTS_NPC_X >= 0){
                pvSet(pv_GHOSTS_NPC_X, (pv_GHOSTS_NPC_X + pv_GHOSTS_NPC_MOVDIST));
            }
        }state CHECK_MOVE
    }
    state MOVE_LEFT{
        when(pv_GHOSTS_NPC_IDX == -1){
        }state MOVE_MIDDLE
        when(pv_PACMAN_PLAY_FIELD[((int)pv_GHOSTS_NPC_IDX-1)] == 1){
        } state CHECK_MOVEABLE_DIRECTIONS
        when(delay(0.1)){
            pvSetStr( pv_SS_GHOSTS, "MOVE_LEFT" );
            if(pv_GHOSTS_NPC_X <= 1000 && pv_GHOSTS_NPC_X > 0){
                pvSet(pv_GHOSTS_NPC_X, (pv_GHOSTS_NPC_X - pv_GHOSTS_NPC_MOVDIST));
            }
        }state CHECK_MOVE
    }
    state MOVE_UP{
        when(pv_GHOSTS_NPC_IDX == -1){
        }state MOVE_MIDDLE
        when(pv_PACMAN_PLAY_FIELD[((int)pv_GHOSTS_NPC_IDX-(int)pv_PACMAN_ARRAY_ROW_LENGTH)] == 1){
        } state CHECK_MOVEABLE_DIRECTIONS
        when(delay(0.1)){
            pvSetStr(pv_SS_GHOSTS, "MOVE_UP" );
            if(pv_GHOSTS_NPC_Y < 1000 && pv_GHOSTS_NPC_Y > 0){
                pvSet(pv_GHOSTS_NPC_Y, (pv_GHOSTS_NPC_Y - pv_GHOSTS_NPC_MOVDIST));
            }
        }state CHECK_MOVE
    }
    state MOVE_DOWN{
        when(pv_GHOSTS_NPC_IDX == -1){
        }state MOVE_MIDDLE
        when(pv_PACMAN_PLAY_FIELD[((int)pv_GHOSTS_NPC_IDX+(int)pv_PACMAN_ARRAY_ROW_LENGTH)] == 1){
        } state CHECK_MOVEABLE_DIRECTIONS
        when(delay(0.1)){
            pvSetStr( pv_SS_GHOSTS, "MOVE_DOWN" );
            if(pv_GHOSTS_NPC_Y <= 1000 && pv_GHOSTS_NPC_Y >= 0){
                pvSet(pv_GHOSTS_NPC_Y, (pv_GHOSTS_NPC_Y + pv_GHOSTS_NPC_MOVDIST));
            }
        }state CHECK_MOVE
    }
}

// animation of ghosts
ss run_ghost{
    state INIT{
        entry{
            pvSetStr(pv_SS_GHOSTS_RUN, "INIT");
        }when(delay(1)){

        }state CHECK_DIRECTION
    }

    state CHECK_DIRECTION{
        entry{
            int direction = pv_GHOSTS_NPC_DIR % 4;
            int FRAME_1;
            int FRAME_2;
            pvSetStr(pv_SS_GHOSTS_RUN, "CHECK_DIRECTION");
            // right
            if(direction == 0){
                FRAME_1 = 0;
                FRAME_2 = 1;
            }
            //left
            if(direction == 1){
                FRAME_1 = 2;
                FRAME_2 = 3;
            }
            // up
            if(direction == 2){
                FRAME_1 = 4;
                FRAME_2 = 5;
            }
            // down
            if(direction == 3){
                FRAME_1 = 6;
                FRAME_2 = 7;
            }
            pvSet(pv_GHOSTS_NPC_RUNFRAME1, FRAME_1);
            pvSet(pv_GHOSTS_NPC_RUNFRAME2, FRAME_2);
        }
        when(){
        } state FRAME_1
    }

    state FRAME_1{
        entry{
            pvSetStr(pv_SS_GHOSTS_RUN, "FRAME_1");
        }when (delay(0.4)){
            pvSet(pv_GHOSTS_NPC_RUN, pv_GHOSTS_NPC_RUNFRAME1);
        }state FRAME_2
    }

      state FRAME_2{
        entry{
            pvSetStr(pv_SS_GHOSTS_RUN, "FRAME_2");
        }when (delay(0.4)){
            pvSet(pv_GHOSTS_NPC_RUN, pv_GHOSTS_NPC_RUNFRAME2);
        }state CHECK_DIRECTION
    }
}