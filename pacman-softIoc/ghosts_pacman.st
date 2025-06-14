program ghosts_pacman
#include "seqPVmacros.h"

%%#include "math.h"
%%#include "stdlib.h"
%%#include "errlog.h"
%%#define PRINTF errlogPrintf

/* options */
option  +r;

/* variables  ghosts */
PV( string, pv_SS_GHOSTS, "{NAME}:SS_GHOSTS", PV_NONE );
PV( int, pv_GHOSTS_NPC_DIRECTION, "{NAME}:GHOSTS_NPC_DIR", PV_MON );  

/* variables ghost run */
PV( string, pv_SS_GHOSTS_RUN, "{NAME}:SS_GHOSTS_RUN", PV_NONE );
PV( int, pv_GHOSTS_NPC_RUN, "{NAME}:GHOSTS_NPC_RUN", PV_MON );
PV( int, pv_GHOSTS_NPC_RUNFRAME1, "{NAME}:GHOSTS_NPC_RUNFRAME1", PV_MON );
PV( int, pv_GHOSTS_NPC_RUNFRAME2, "{NAME}:GHOSTS_NPC_RUNFRAME2", PV_MON );  

/* Functions */
%{
    
}%

ss ghosts_pacman{
    state CHECK_MOVE{
        entry{
            pvSetStr( pv_SS_GHOSTS, "CHECK_MOVE" );
        }
        when(){
        } state INIT
    }

    state MOVE{
        entry{
            pvSetStr( pv_SS_GHOSTS, "CHECK_MOVE" );
        } when(){
            
        }state MOVE
    }
}

ss run_ghost{
    state INIT{
        entry{
            pvSetStr(pv_SS_GHOSTS_RUN, "INIT");
        }when(delay(1)){

        }state CHECK_DIRECTION
    }

    state CHECK_DIRECTION{
        entry{
            int direction = pv_GHOSTS_NPC_DIRECTION % 3;
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
        }when (delay(0.05)){
            pvSet(pv_GHOSTS_NPC_RUN, pv_GHOSTS_NPC_RUNFRAME1);
        }state FRAME_2
    }

      state FRAME_2{
        entry{
            pvSetStr(pv_SS_GHOSTS_RUN, "FRAME_2");
        }when (delay(0.05)){
            pvSet(pv_GHOSTS_NPC_RUN, pv_GHOSTS_NPC_RUNFRAME2);
        }state CHECK_DIRECTION
    }
}