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
PV( int     , pv_PACMAN_USER_DIRECTION	, "{NAME}:PACMAN_USER_DIRECTION"	, PV_MON );
PV( string  , pv_SS_PACMAN				, "{NAME}:SS_PACMAN"			, PV_NONE);

ss pacman_game {
    state INIT {
		entry{pvSetStr( pv_SS_PACMAN, "INIT" );}
        when () {
	        printf( "PACMAN Started\n" );

		} state MOVE_RIGHT
    }

	state MOVE_RIGHT {
		entry{pvSetStr( pv_SS_PACMAN, "MOVE_RIGHT" ); pvSet(pv_PACMAN_USER_DIRECTION, 0);}
		when (pv_PACMAN_USER_X < 460 && delay(0.02)) {
			pvSet(pv_PACMAN_USER_X, pv_PACMAN_USER_X + 1);
		} state MOVE_RIGHT

		when (pv_PACMAN_USER_X >= 460) {
		} state MOVE_LEFT
	}
		
	state MOVE_LEFT {
		entry{pvSetStr( pv_SS_PACMAN, "MOVE_LEFT" ); pvSet(pv_PACMAN_USER_DIRECTION, 1);}
		when (pv_PACMAN_USER_X > 0 && delay(0.02)) {
			pvSet(pv_PACMAN_USER_X, pv_PACMAN_USER_X - 1);
		} state MOVE_LEFT

		when (pv_PACMAN_USER_X <= 0) {
		} state MOVE_RIGHT
	}
}