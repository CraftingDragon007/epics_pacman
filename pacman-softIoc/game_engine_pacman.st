program game_engine_pacman
#include "seqPVmacros.h"
#include "pacman_common.h"

%%#include "math.h"
%%#include "stdlib.h"
%%#include "stdio.h"
%%#include "png.h"
%%#include "errlog.h"
%%#define PRINTF errlogPrintf

/* options */
option  +r;

PV( int, pv_GAME_STATE_INDICATOR, "{NAME}:GAME_STATE_INDICATOR", PV_MON );
PV( int, pv_GAME_FRIGHT_MODE, "{NAME}:GAME_FRIGHT_MODE", PV_MON );
PV( int, pv_GAME_KILLED_GHOSTS_MULTIPLIER, "{NAME}:GAME_KILLED_GHOSTS_MULTIPLIER", PV_MON );
PV( int, pv_GAME_WIN_CONDITION, "{NAME}:GAME_WIN_CONDITION", PV_MON );
PV( int, pv_GAME_PACMAN_LIVES, "{NAME}:GAME_PACMAN_LIVES", PV_MON );

PV( int, pv_GAME_GHOSTS_INKY_RELEASE, "{NAME}:GAME_GHOSTS_INKY_RELEASE", PV_MON );
PV( int, pv_GAME_GHOSTS_CLYDE_RELEASE, "{NAME}:GAME_GHOSTS_CLYDE_RELEASE", PV_MON );

PV( int, pv_GAME_GHOSTS_BLINKY_RESPAWN, "{NAME}:GAME_GHOSTS_BLINKY_RESPAWN", PV_MON );
PV( int, pv_GAME_GHOSTS_PINKY_RESPAWN, "{NAME}:GAME_GHOSTS_PINKY_RESPAWN", PV_MON );
PV( int, pv_GAME_GHOSTS_INKY_RESPAWN, "{NAME}:GAME_GHOSTS_INKY_RESPAWN", PV_MON );
PV( int, pv_GAME_GHOSTS_CLYDE_RESPAWN, "{NAME}:GAME_GHOSTS_CLYDE_RESPAWN", PV_MON );

PV( int, pv_PACMAN_RESET_FOOD, "{NAME}:PACMAN_RESET_FOOD", PV_MON );
PV( int, pv_PACMAN_USER_SCORE, "{NAME}:PACMAN_USER_SCORE", PV_MON );
PV( int, pv_PACMAN_USER_X, "{NAME}:PACMAN_USER_X", PV_MON );
PV( int, pv_PACMAN_USER_Y, "{NAME}:PACMAN_USER_Y", PV_MON );
PV( int, pv_PACMAN_USER_DIRECTION, "{NAME}:PACMAN_USER_DIRECTION", PV_MON );
PV( int, pv_PACMAN_PACMAN_STATE, "{NAME}:PACMAN_PACMAN_STATE", PV_MON );
PV( int, pv_PACMAN_PACMAN_ABORT, "{NAME}:PACMAN_PACMAN_ABORT", PV_MON );
PV( int, pv_PACMAN_TRY_DIRECTION, "{NAME}:PACMAN_TRY_DIRECTION", PV_MON );
PV( int, pv_PACMAN_PACMAN_DEATH, "{NAME}:PACMAN_PACMAN_DEATH", PV_MON );

PV( int, pv_GHOSTS_BLINKY_MODE, "{NAME}:GHOSTS_BLINKY_MODE", PV_MON );
PV( int, pv_GHOSTS_BLINKY_X, "{NAME}:GHOSTS_BLINKY_X", PV_MON );
PV( int, pv_GHOSTS_BLINKY_Y, "{NAME}:GHOSTS_BLINKY_Y", PV_MON );

PV( int, pv_GHOSTS_PINKY_MODE, "{NAME}:GHOSTS_PINKY_MODE", PV_MON );
PV( int, pv_GHOSTS_PINKY_X, "{NAME}:GHOSTS_PINKY_X", PV_MON );
PV( int, pv_GHOSTS_PINKY_Y, "{NAME}:GHOSTS_PINKY_Y", PV_MON );

PV( int, pv_GHOSTS_INKY_MODE, "{NAME}:GHOSTS_INKY_MODE", PV_MON );
PV( int, pv_GHOSTS_INKY_X, "{NAME}:GHOSTS_INKY_X", PV_MON );
PV( int, pv_GHOSTS_INKY_Y, "{NAME}:GHOSTS_INKY_Y", PV_MON );

PV( int, pv_GHOSTS_CLYDE_MODE, "{NAME}:GHOSTS_CLYDE_MODE", PV_MON );
PV( int, pv_GHOSTS_CLYDE_X, "{NAME}:GHOSTS_CLYDE_X", PV_MON );
PV( int, pv_GHOSTS_CLYDE_Y, "{NAME}:GHOSTS_CLYDE_Y", PV_MON );

PV( string, pv_LOGS, "{NAME}:SS_GAME_ENGINE", PV_NONE );

#define PACMAN_GHOST_KILL_REWARD 200
#define PACMAN_DEATH_ANIMATION_DELAY 0.5

ss game_logic {
    bool initial_fright = true;
    int tolerance = 10; // tolerance for ghost collision detection

    state INIT {
        entry {
            pvSetStr(pv_LOGS, "INIT");
            pvSet(pv_PACMAN_USER_DIRECTION, INVALID_DIRECTION);
            pvSet(pv_PACMAN_TRY_DIRECTION, INVALID_DIRECTION);
        }

        when (pv_PACMAN_USER_DIRECTION != INVALID_DIRECTION && pv_PACMAN_TRY_DIRECTION != INVALID_DIRECTION){
            if (pv_GAME_PACMAN_LIVES <= 0){
                pvSet(pv_PACMAN_USER_SCORE, 0);
                pvSet(pv_GAME_PACMAN_LIVES, 3);
            }
        } state START

        when () {

        } state INIT
    }

    state START {
        entry {
            pvSetStr(pv_LOGS, "START");
            pvSet(pv_GHOSTS_BLINKY_MODE, MODE_SCATTER);
            pvSet(pv_GHOSTS_PINKY_MODE, MODE_SCATTER);
            pvSet(pv_GHOSTS_INKY_MODE, MODE_WAIT);
            pvSet(pv_GHOSTS_CLYDE_MODE, MODE_WAIT);
            pvSet(pv_GAME_GHOSTS_INKY_RELEASE, 1);
            pvSet(pv_GAME_STATE_INDICATOR, 1);
            pvSet(pv_GAME_PACMAN_LIVES, pv_GAME_PACMAN_LIVES - 1);            
        }

        when (){

        } state RUN
    }

    state RUN {
        entry {
            pvSetStr(pv_LOGS, "RUN");
        }

        when (pv_PACMAN_PACMAN_DEATH != -1){

        } state PACMAN_DEATH

        when (pv_GAME_WIN_CONDITION <= 0){

        } state RESET

        // release inky
        when (pv_GAME_GHOSTS_INKY_RELEASE == 0 && pv_GAME_STATE_INDICATOR == 1 && pv_GAME_FRIGHT_MODE == 0){
            pvSet(pv_GHOSTS_INKY_MODE, MODE_SCATTER);
            pvSet(pv_GAME_GHOSTS_CLYDE_RELEASE, 1);
            pvSet(pv_GAME_STATE_INDICATOR, 2);
        } state RUN

        // release clyde
        when (pv_GAME_GHOSTS_CLYDE_RELEASE == 0 && pv_GAME_STATE_INDICATOR == 2 && pv_GAME_FRIGHT_MODE == 0){
            pvSet(pv_GHOSTS_CLYDE_MODE, MODE_SCATTER);
            pvSet(pv_GAME_GHOSTS_CLYDE_RELEASE, 1);
            pvSet(pv_GAME_STATE_INDICATOR, 3);
        } state RUN

        when (pv_GAME_FRIGHT_MODE == 1 && initial_fright == true){
            initial_fright = false;
        } state FRIGHTENED

        when (pv_GAME_FRIGHT_MODE == 0 && initial_fright == false){
            if (pv_GHOSTS_BLINKY_MODE == MODE_FRIGHT) {
                pvSet(pv_GHOSTS_BLINKY_MODE, MODE_SCATTER);
            }
            if (pv_GHOSTS_PINKY_MODE == MODE_FRIGHT) {
                pvSet(pv_GHOSTS_PINKY_MODE, MODE_SCATTER);
            }
            if (pv_GHOSTS_INKY_MODE == MODE_FRIGHT) {
                pvSet(pv_GHOSTS_INKY_MODE, MODE_SCATTER);
            }
            if (pv_GHOSTS_CLYDE_MODE == MODE_FRIGHT) {
                pvSet(pv_GHOSTS_CLYDE_MODE, MODE_SCATTER);
            }
            
            pvSet(pv_GAME_KILLED_GHOSTS_MULTIPLIER, 1);
            initial_fright = true;
        } state RUN

        // check if colliding with blinky
        when (pv_PACMAN_USER_X >= pv_GHOSTS_BLINKY_X - tolerance &&
              pv_PACMAN_USER_X <= pv_GHOSTS_BLINKY_X + tolerance &&
              pv_PACMAN_USER_Y >= pv_GHOSTS_BLINKY_Y - tolerance &&
              pv_PACMAN_USER_Y <= pv_GHOSTS_BLINKY_Y + tolerance) {
            if (pv_GHOSTS_BLINKY_MODE == MODE_FRIGHT) {
                pvSet(pv_PACMAN_USER_SCORE, pv_PACMAN_USER_SCORE + PACMAN_GHOST_KILL_REWARD * pv_GAME_KILLED_GHOSTS_MULTIPLIER);
                pvSet(pv_GAME_KILLED_GHOSTS_MULTIPLIER, pv_GAME_KILLED_GHOSTS_MULTIPLIER + 1);
                pvSet(pv_GHOSTS_BLINKY_MODE, MODE_SPAWN);
                pvSet(pv_GAME_GHOSTS_BLINKY_RESPAWN, 1);
            } else if(pv_GHOSTS_BLINKY_MODE == MODE_SCATTER || pv_GHOSTS_BLINKY_MODE == MODE_CHASE) {
                pvSet(pv_PACMAN_PACMAN_DEATH, 1);
            }
        } state RUN

        // check if colliding with pinky
        when (pv_PACMAN_USER_X >= pv_GHOSTS_PINKY_X - tolerance &&
              pv_PACMAN_USER_X <= pv_GHOSTS_PINKY_X + tolerance &&
              pv_PACMAN_USER_Y >= pv_GHOSTS_PINKY_Y - tolerance &&
              pv_PACMAN_USER_Y <= pv_GHOSTS_PINKY_Y + tolerance) {
            if (pv_GHOSTS_PINKY_MODE == MODE_FRIGHT) {
                pvSet(pv_PACMAN_USER_SCORE, pv_PACMAN_USER_SCORE + PACMAN_GHOST_KILL_REWARD * pv_GAME_KILLED_GHOSTS_MULTIPLIER);
                pvSet(pv_GAME_KILLED_GHOSTS_MULTIPLIER, pv_GAME_KILLED_GHOSTS_MULTIPLIER + 1);
                pvSet(pv_GHOSTS_PINKY_MODE, MODE_SPAWN);
                pvSet(pv_GAME_GHOSTS_PINKY_RESPAWN, 1);
            } else if(pv_GHOSTS_PINKY_MODE == MODE_SCATTER || pv_GHOSTS_PINKY_MODE == MODE_CHASE) {
                pvSet(pv_PACMAN_PACMAN_DEATH, 1);
            }
        } state RUN

        // check if colliding with inky
        when (pv_PACMAN_USER_X >= pv_GHOSTS_INKY_X - tolerance &&
              pv_PACMAN_USER_X <= pv_GHOSTS_INKY_X + tolerance &&
              pv_PACMAN_USER_Y >= pv_GHOSTS_INKY_Y - tolerance &&
              pv_PACMAN_USER_Y <= pv_GHOSTS_INKY_Y + tolerance) {
            if (pv_GHOSTS_INKY_MODE == MODE_FRIGHT) {
                pvSet(pv_PACMAN_USER_SCORE, pv_PACMAN_USER_SCORE + PACMAN_GHOST_KILL_REWARD * pv_GAME_KILLED_GHOSTS_MULTIPLIER);
                pvSet(pv_GAME_KILLED_GHOSTS_MULTIPLIER, pv_GAME_KILLED_GHOSTS_MULTIPLIER + 1);
                pvSet(pv_GHOSTS_INKY_MODE, MODE_SPAWN);
                pvSet(pv_GAME_GHOSTS_INKY_RESPAWN, 1);
            } else if(pv_GHOSTS_INKY_MODE == MODE_SCATTER || pv_GHOSTS_INKY_MODE == MODE_CHASE) {
                pvSet(pv_PACMAN_PACMAN_DEATH, 1);
            }
        } state RUN

        // check if colliding with clyde
        when (pv_PACMAN_USER_X >= pv_GHOSTS_CLYDE_X - tolerance &&
              pv_PACMAN_USER_X <= pv_GHOSTS_CLYDE_X + tolerance &&
              pv_PACMAN_USER_Y >= pv_GHOSTS_CLYDE_Y - tolerance &&
              pv_PACMAN_USER_Y <= pv_GHOSTS_CLYDE_Y + tolerance) {
            if (pv_GHOSTS_CLYDE_MODE == MODE_FRIGHT) {
                pvSet(pv_PACMAN_USER_SCORE, pv_PACMAN_USER_SCORE + PACMAN_GHOST_KILL_REWARD * pv_GAME_KILLED_GHOSTS_MULTIPLIER);
                pvSet(pv_GAME_KILLED_GHOSTS_MULTIPLIER, pv_GAME_KILLED_GHOSTS_MULTIPLIER + 1);
                pvSet(pv_GHOSTS_CLYDE_MODE, MODE_SPAWN);
                pvSet(pv_GAME_GHOSTS_CLYDE_RESPAWN, 1);
            } else if(pv_GHOSTS_CLYDE_MODE == MODE_SCATTER || pv_GHOSTS_CLYDE_MODE == MODE_CHASE) {
                pvSet(pv_PACMAN_PACMAN_DEATH, 1);
            }
        } state RUN

        when (pv_GAME_GHOSTS_BLINKY_RESPAWN == 0 && pv_GHOSTS_BLINKY_MODE == MODE_SPAWN) {
            pvSet(pv_GHOSTS_BLINKY_MODE, MODE_WAIT);
            pvSet(pv_GAME_GHOSTS_BLINKY_RESPAWN, 1);
        } state RUN

        when (pv_GAME_GHOSTS_PINKY_RESPAWN == 0 && pv_GHOSTS_PINKY_MODE == MODE_SPAWN) {
            pvSet(pv_GHOSTS_PINKY_MODE, MODE_WAIT);
            pvSet(pv_GAME_GHOSTS_PINKY_RESPAWN, 1);
        } state RUN

        when (pv_GAME_GHOSTS_INKY_RESPAWN == 0 && pv_GHOSTS_INKY_MODE == MODE_SPAWN) {
            pvSet(pv_GHOSTS_INKY_MODE, MODE_WAIT);
            pvSet(pv_GAME_GHOSTS_INKY_RESPAWN, 1);
        } state RUN

        when (pv_GAME_GHOSTS_CLYDE_RESPAWN == 0 && pv_GHOSTS_CLYDE_MODE == MODE_SPAWN) {
            pvSet(pv_GHOSTS_CLYDE_MODE, MODE_WAIT);
            pvSet(pv_GAME_GHOSTS_CLYDE_RESPAWN, 1);
        } state RUN

        when (pv_GAME_GHOSTS_BLINKY_RESPAWN == 0 && pv_GHOSTS_BLINKY_MODE == MODE_WAIT && pv_PACMAN_USER_DIRECTION != INVALID_DIRECTION){
            pvSet(pv_GHOSTS_BLINKY_MODE, MODE_CHASE);
        } state RUN

        when (pv_GAME_GHOSTS_PINKY_RESPAWN == 0 && pv_GHOSTS_PINKY_MODE == MODE_WAIT && pv_PACMAN_USER_DIRECTION != INVALID_DIRECTION){
            pvSet(pv_GHOSTS_PINKY_MODE, MODE_CHASE);
        } state RUN

        when (pv_GAME_GHOSTS_INKY_RESPAWN == 0 && pv_GHOSTS_INKY_MODE == MODE_WAIT && pv_PACMAN_USER_DIRECTION != INVALID_DIRECTION && pv_GAME_GHOSTS_INKY_RELEASE == 0){
            pvSet(pv_GHOSTS_INKY_MODE, MODE_CHASE);
        } state RUN

        when (pv_GAME_GHOSTS_CLYDE_RESPAWN == 0 && pv_GHOSTS_CLYDE_MODE == MODE_WAIT && pv_PACMAN_USER_DIRECTION != INVALID_DIRECTION && pv_GAME_GHOSTS_INKY_RELEASE == 0 && pv_GAME_GHOSTS_CLYDE_RELEASE == 0){
            pvSet(pv_GHOSTS_CLYDE_MODE, MODE_CHASE);
        } state RUN

        when (){
            
        } state RUN
    }

    state FRIGHTENED {
        entry {
            pvSetStr(pv_LOGS, "FRIGHTENED");
        }

        when (pv_GAME_FRIGHT_MODE == 1){
            pvSet(pv_GHOSTS_BLINKY_MODE, MODE_FRIGHT);
            pvSet(pv_GHOSTS_PINKY_MODE, MODE_FRIGHT);
            pvSet(pv_GHOSTS_INKY_MODE, MODE_FRIGHT);
            pvSet(pv_GHOSTS_CLYDE_MODE, MODE_FRIGHT);
        } state RUN

        when (){

        } state RUN
    }

    state PACMAN_DEATH {
        entry {
            pvSetStr(pv_LOGS, "PACMAN_DEATH");

            pvSet(pv_PACMAN_PACMAN_ABORT, 1);
            pvSet(pv_GHOSTS_BLINKY_MODE, MODE_WAIT);
            pvSet(pv_GHOSTS_PINKY_MODE, MODE_WAIT);
            pvSet(pv_GHOSTS_INKY_MODE, MODE_WAIT);
            pvSet(pv_GHOSTS_CLYDE_MODE, MODE_WAIT);
        }

        when (pv_PACMAN_PACMAN_DEATH == 1){
            pvSet(pv_PACMAN_PACMAN_DEATH, 8);
        } state PACMAN_DEATH

        when (pv_PACMAN_PACMAN_DEATH < 20 && pv_PACMAN_PACMAN_DEATH > 1){
        } state PACMAN_DEATH_DELAY

        when (pv_PACMAN_PACMAN_DEATH >= 20){
            pvSet(pv_PACMAN_PACMAN_DEATH, -1);
        } state PACMAN_DEATH

        when (pv_PACMAN_PACMAN_DEATH == -1){
            pvSet(pv_PACMAN_PACMAN_ABORT, 0);
        } state RESET
    }

    state PACMAN_DEATH_DELAY {
        entry {
            pvSetStr(pv_LOGS, "PACMAN_DEATH_DELAY");
        }

        when (delay(PACMAN_DEATH_ANIMATION_DELAY)){
            pvSet(pv_PACMAN_PACMAN_DEATH, pv_PACMAN_PACMAN_DEATH + 1);
        } state PACMAN_DEATH
    }

    state RESET {
        entry {
            pvSetStr(pv_LOGS, "RESET");
        }
    
        when (pv_GAME_PACMAN_LIVES == 0){
            pvSet(pv_GAME_WIN_CONDITION, 244);
            pvSet(pv_PACMAN_RESET_FOOD, 1);
            pvSet(pv_GAME_PACMAN_LIVES, -1);
        } state INIT

        when (){
            if(pv_GAME_WIN_CONDITION <= 0){
                pvSet(pv_GHOSTS_BLINKY_MODE, MODE_WAIT);
                pvSet(pv_GHOSTS_PINKY_MODE, MODE_WAIT);
                pvSet(pv_GHOSTS_INKY_MODE, MODE_WAIT);
                pvSet(pv_GHOSTS_CLYDE_MODE, MODE_WAIT);
                pvSet(pv_PACMAN_RESET_FOOD, 1);
            }
        } state INIT
    }
}