program ghosts_pacman
#include "seqPVmacros.h"

%%#include "math.h"
%%#include "stdlib.h"
%%#include "errlog.h"
%%#define PRINTF errlogPrintf

/* options */
option  +r;

/* variables  ghosts */

/* Functions */
%{
    
}%

ss ghosts_pacman{
    state STATE{
        entry{

        }
        when(){

        } state MOVE_RIGHT
    }

        state STATE{
        entry{

        }
        when(){

        } state MOVE_RIGHT
    }

        state STATE{
        entry{

        }
        when(){

        } state MOVE_RIGHT
    }
}