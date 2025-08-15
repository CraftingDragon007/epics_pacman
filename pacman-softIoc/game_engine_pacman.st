program game_engine_pacman
#include "seqPVmacros.h"

%%#include "math.h"
%%#include "stdlib.h"
%%#include "stdio.h"
%%#include "png.h"
%%#include "errlog.h"
%%#define PRINTF errlogPrintf

/* options */
option  +r;

PV( int, pv_PACMAN_RESET_FOOD, "{NAME}:PACMAN_RESET_FOOD", PV_MON );
PV( int, pv_PACMAN_USER_SCORE, "{NAME}:PACMAN_USER_SCORE", PV_MON );
PV( string, pv_LOGS, "{NAME}:SS_GAME_ENGINE", PV_NONE );

ss game_logic {
    state INIT {
        entry {
            pvSetStr(pv_LOGS, "INIT");
        }

        when (pv_PACMAN_USER_SCORE==200){

        } state INIT
    }
}