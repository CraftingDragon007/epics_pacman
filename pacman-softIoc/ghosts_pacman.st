program ghosts_pacman
#include "seqPVmacros.h"

%%#include "math.h"
%%#include "stdlib.h"
%%#include "errlog.h"
%%#define PRINTF errlogPrintf

/* options */
option  +r;

/* variables  ghosts */
PV( string  , pv_SS_GHOSTS, "{NAME}:SS_GHOSTS", PV_NONE );

/* Functions */
%{
    
}%

ss ghosts_pacman{
    state INIT{
        entry{
            pvSetStr( pv_SS_GHOSTS, "INIT_GHOST" );
        }
        when(delay(0.22)){

        } state MOVE_RIGHT
    }

    state MOVE_RIGHT{
        entry{
            pvSetStr( pv_SS_GHOSTS, "MOVE_RIGHT_GHOST" );
        }
        when(delay(1)){

        } state INIT
    }
}