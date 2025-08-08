program ghosts_pacman
#include "seqPVmacros.h"

%%#include "math.h"
%%#include "stdlib.h"
%%#include "stdio.h"
%%#include "stdbool.h"
%%#include "png.h"
%%#include "errlog.h"
%%#include "time.h"
%%#include "stdint.h"
%%#define PRINTF errlogPrintf

/* options */
option  +r;

/* variables for ghost */
PV( string, pv_LOGS, "{NAME}:SS_GHOSTS", PV_NONE );
PV(double, pv_SCATTER_DELAY, "{NAME}:GHOSTS_COMMON_SCATTER_DELAY", PV_MON);
PV(double, pv_CHASE_DELAY, "{NAME}:GHOSTS_COMMON_CHASE_DELAY", PV_MON);
PV(double, pv_FRIGHT_DELAY, "{NAME}:GHOSTS_COMMON_FRIGHT_DELAY", PV_MON);
PV(double, pv_SPAWN_DELAY, "{NAME}:GHOSTS_COMMON_SPAWN_DELAY", PV_MON);
PV(int, pv_CURRENT_MODE, "{NAME}:GHOSTS_{GHOST}_MODE", PV_MON);
PV( int, pv_GHOST_DIR, "{NAME}:GHOSTS_{GHOST}_DIR", PV_MON );  
PV( int, pv_GHOST_X, "{NAME}:GHOSTS_{GHOST}_X", PV_MON );  
PV( int, pv_GHOST_Y, "{NAME}:GHOSTS_{GHOST}_Y", PV_MON );
PV( int, pv_GHOST_SIZE, "{NAME}:GHOSTS_{GHOST}_SIZE", PV_MON );  

/* variables for ghost animation */
PV( double, pv_GHOST_ANIMATION_DELAY, "{NAME}:GHOSTS_COMMON_ANIMATION_DELAY", PV_MON);
PV( int, pv_GHOST_CURRENT_FRAME, "{NAME}:GHOSTS_{GHOST}_FRAME", PV_MON );

/* variables from pacman */
PV( int, pv_PACMAN_X, "{NAME}:PACMAN_USER_X", PV_MON );
PV( int, pv_PACMAN_Y, "{NAME}:PACMAN_USER_Y", PV_MON );
PV( int, pv_PACMAN_SIZE     , "{NAME}:PACMAN_PACMAN_SIZE"	, PV_MON );
PV( int, pv_PACMAN_ARRAY_ROW_LENGTH	, "{NAME}:PACMAN_ARRAY_X_SIZE"	, PV_MON );
PV( int, pv_PACMAN_ARRAY_CELL_WIDTH	, "{NAME}:PACMAN_ARRAY_X_FACTOR", PV_MON );
PVA( short, pv_PACMAN_PLAY_FIELD, 868, "{NAME}:PACMAN_PLAY_FIELD", PV_MON);
PV( int, pv_PACMAN_FIELD_SIZE, "{NAME}:PACMAN_FIELD_SIZE"	, PV_MON );
PV( int, pv_PACMAN_FIELD_RESOLUTION, "{NAME}:PACMAN_FIELD_RESOLUTION", PV_MON );

#define MODE_WAIT 0
#define MODE_SCATTER 1
#define MODE_CHASE 2
#define MODE_FRIGHT 3
#define MODE_SPAWN 4

#define DIRECTION_RIGHT 0
#define DIRECTION_LEFT 1
#define DIRECTION_UP 2
#define DIRECTION_DOWN 3

#define bool int

#define PICK_MAX 1
#define PICK_MIN 0

#define ANGLE_INVALID -1.0
#define ANGLE_MIN 0.0
#define ANGLE_MAX 3.15

#define FIELD_WIDTH 28
#define FIELD_HEIGHT 31
#define TILE_SIZE 32

#define TILE_PATH 0
#define TILE_WALL 1
#define TILE_PORTAL 2
#define TILE_SPAWN_ENTRY 3

%{
    void swap_values(int* a, int* b) {
         int temp = *a;
         *a = *b;
         *b = temp;
    }

    double get_angle_for_coordinates(int current_x, int current_y, int next_x, int next_y, int target_x, int target_y) {
        double nt = sqrt((next_x - target_x) * (next_x - target_x) + (next_y - target_y) * (next_y - target_y));
        double cn = sqrt((next_x - current_x) * (next_x - current_x) + (next_y - current_y) * (next_y - current_y));
        double ct = sqrt((target_x - current_x)*(target_x - current_x) + (target_y - current_y) * (target_y - current_y));
        
        double dividend = nt * nt - ct * ct - cn * cn; 
        double divisor = -2 * ct * cn;
        if (divisor == 0) return 0;
        
        double cosResult = dividend / divisor;
        if (fabs(cosResult + 1.0) < 1e-9) {
            cosResult = -1; // Due to precision loss, it could be slightly less than -1, resulting in nan when doing acos (domain error)
        }

        return acos(cosResult);
    }

    int get_tile_index_from_tile_coordinates(int tile_x, int tile_y){
        return tile_y * FIELD_WIDTH + tile_x;
    }

    void get_tile_coordinates_from_tile_index(int tile_index, int *tile_x, int *tile_y) {
        *tile_x = tile_index % FIELD_WIDTH;
        *tile_y = tile_index / FIELD_WIDTH;
    }

    int random_int_between(int min, int max) {
        if (min > max) {
            int temp = min;
            min = max;
            max = temp;
        }

        int range = max - min + 1;
        int bucket_size = (RAND_MAX) / range;
        int limit = bucket_size * range;

        int r;
        do {
            r = rand();
        } while (r >= limit);

        return min + (r / bucket_size);
    }

    double pick_angle(double a, double b, double c, double d, int pick_max) {
        double result = pick_max == PICK_MAX ? ANGLE_MIN : ANGLE_MAX;
        if (pick_max == PICK_MAX) {
            if (a > result && a != ANGLE_INVALID) result = a;
            if (b > result && b != ANGLE_INVALID) result = b;
            if (c > result && c != ANGLE_INVALID) result = c;
            if (d > result && d != ANGLE_INVALID) result = d;
        } else {
            if (a < result && a != ANGLE_INVALID) result = a;
            if (b < result && b != ANGLE_INVALID) result = b;
            if (c < result && c != ANGLE_INVALID) result = c;
            if (d < result && d != ANGLE_INVALID) result = d;
        }
        return result;
    }

    double get_time_from_now(double offset_seconds) {
        struct timespec now;
        clock_gettime(CLOCK_MONOTONIC, &now);

        double now_ms = (double)now.tv_sec * 1000.0 + (double)now.tv_nsec / 1e6;
        double offset_ms = offset_seconds * 1000.0;

        return now_ms + offset_ms;
    }

    bool is_time_reached(double target_time) {
        double current_time = get_time_from_now(0.0);
        return current_time >= target_time;
    }

    // In spawn mode, the shortest path to spawn is needed. In some cases, using angles is horribly wrong, which is why some tiles are overriden to go upwards instead of using the angle.
    bool is_spawn_upwards_override(int tile) {
        switch (tile) {
            case 401:
            case 410:
            case 485:
            case 494:
                return true;
            default:
                return false;
        }
    }
}%

ss gameloop {
    int previous_mode = MODE_WAIT;
    int current_mode = MODE_WAIT;
    double delay_time = 1;

    int current_direction = DIRECTION_RIGHT;
    int chosen_direction = DIRECTION_RIGHT;
    int inverse_direction = DIRECTION_RIGHT;
    int num_directions_possible = 0;

    bool current_direction_possible = false;

    int origin_tile = -1;
    int target_tile = -1;
    int target_pixel_x = 0;
    int target_pixel_y = 0;
    int origin_tile_x = 0;
    int origin_tile_y = 0;
    int target_tile_x = 0;
    int target_tile_y = 0;

    int ghost_size = 40;

    state INIT {
        entry {
            pvSetStr(pv_LOGS, "INIT");
            %% srand((unsigned) time(NULL));
        }
        when() {
        } state READY
    }

    state READY {
        entry {
            pvSetStr(pv_LOGS, "READY");
            origin_tile_x = FIELD_WIDTH / 2;
            origin_tile_y = FIELD_HEIGHT / 2 - 1;
            origin_tile = get_tile_index_from_tile_coordinates(origin_tile_x, origin_tile_y);
            target_tile_x = origin_tile_x;
            target_tile_y = origin_tile_y - 4;
            target_tile = get_tile_index_from_tile_coordinates(target_tile_x, target_tile_y);
            ghost_size = pv_GHOST_SIZE;
            target_pixel_x = target_tile_x * TILE_SIZE + TILE_SIZE / 2;
            target_pixel_y = target_tile_y * TILE_SIZE + TILE_SIZE / 2;
            pvSet(pv_GHOST_X, origin_tile_x * TILE_SIZE + TILE_SIZE / 2 - ghost_size / 2);
            pvSet(pv_GHOST_Y, origin_tile_y * TILE_SIZE + TILE_SIZE / 2 - ghost_size / 2);
        }
        when(pv_CURRENT_MODE != MODE_WAIT) {
            current_mode = pv_CURRENT_MODE;
            previous_mode = current_mode;
            ghost_size = pv_GHOST_SIZE;
            target_pixel_x = target_tile_x * TILE_SIZE + TILE_SIZE / 2;
            target_pixel_y = target_tile_y * TILE_SIZE + TILE_SIZE / 2;
            pvSet(pv_GHOST_X, origin_tile_x * TILE_SIZE + TILE_SIZE / 2 - ghost_size / 2);
            pvSet(pv_GHOST_Y, origin_tile_y * TILE_SIZE + TILE_SIZE / 2 - ghost_size / 2);
            current_direction = DIRECTION_UP;
            chosen_direction = DIRECTION_UP;
            pvSet(pv_GHOST_DIR, current_direction);
            delay_time = pv_SCATTER_DELAY;
        } state MOVE_DIRECTION
    }

    state CHECK_MODE {
        entry {
            pvSetStr(pv_LOGS, "CHECK_MODE");

            ghost_size = pv_GHOST_SIZE;
            if ((pv_GHOST_X + ghost_size / 2) % TILE_SIZE < TILE_SIZE / 2) {
                pvSet(pv_GHOST_X, pv_GHOST_X + 1);
            } else if ((pv_GHOST_X + ghost_size / 2) % TILE_SIZE > TILE_SIZE / 2) {
                pvSet(pv_GHOST_X, pv_GHOST_X - 1);
            }

            if ((pv_GHOST_Y + ghost_size / 2) % TILE_SIZE < TILE_SIZE / 2) {
                pvSet(pv_GHOST_Y, pv_GHOST_Y + 1);
            } else if ((pv_GHOST_Y + ghost_size / 2) % TILE_SIZE > TILE_SIZE / 2) {
                pvSet(pv_GHOST_Y, pv_GHOST_Y - 1);
            }

            current_mode = pv_CURRENT_MODE;
            if (current_mode == MODE_SCATTER) {
                delay_time = pv_SCATTER_DELAY;
            } else if (current_mode == MODE_CHASE) {
                delay_time = pv_CHASE_DELAY;
            } else if (current_mode == MODE_FRIGHT) {
                delay_time = pv_FRIGHT_DELAY;
            } else if (current_mode == MODE_SPAWN) {
                delay_time = pv_SPAWN_DELAY;
            }
        }
        when(current_mode == MODE_WAIT) {
        } state READY
        when () {
        } state CHOOSE_DIRECTION
    }

    state CHOOSE_DIRECTION {
        entry {
            pvSetStr(pv_LOGS, "CHOOSE_DIRECTION");
        }
        when () {
            // Get possible directions, with theta to pacman and spawn
            int up_tile = get_tile_index_from_tile_coordinates(target_tile_x, target_tile_y - 1);
            int down_tile = get_tile_index_from_tile_coordinates(target_tile_x, target_tile_y + 1);
            int left_tile = get_tile_index_from_tile_coordinates(target_tile_x - 1, target_tile_y);
            int right_tile = get_tile_index_from_tile_coordinates(target_tile_x + 1, target_tile_y);

            double up_angle_pacman = ANGLE_INVALID;
            double down_angle_pacman = ANGLE_INVALID;
            double left_angle_pacman = ANGLE_INVALID;
            double right_angle_pacman = ANGLE_INVALID;
            double min_angle_pacman = ANGLE_MAX;
            double max_angle_pacman = ANGLE_MIN;

            double up_angle_spawn = ANGLE_INVALID;
            double down_angle_spawn = ANGLE_INVALID;
            double left_angle_spawn = ANGLE_INVALID;
            double right_angle_spawn = ANGLE_INVALID;
            double min_angle_spawn = ANGLE_MAX;

            bool is_spawn = (current_mode == MODE_SPAWN);

            num_directions_possible = 0;

            chosen_direction = -1;

            if (pv_PACMAN_PLAY_FIELD[up_tile] == TILE_PATH || (pv_PACMAN_PLAY_FIELD[up_tile] == TILE_SPAWN_ENTRY && is_spawn)) {
                up_angle_pacman = get_angle_for_coordinates(target_pixel_x, target_pixel_y, target_pixel_x, target_pixel_y - 1, pv_PACMAN_X + pv_PACMAN_SIZE / 2, pv_PACMAN_Y + pv_PACMAN_SIZE / 2);
                up_angle_spawn = get_angle_for_coordinates(target_pixel_x, target_pixel_y, target_pixel_x, target_pixel_y - 1, FIELD_WIDTH / 2 * TILE_SIZE, FIELD_HEIGHT / 2 * TILE_SIZE);
                num_directions_possible += 1;
            }

            if (pv_PACMAN_PLAY_FIELD[down_tile] == TILE_PATH || (pv_PACMAN_PLAY_FIELD[down_tile] == TILE_SPAWN_ENTRY && is_spawn)) {
                down_angle_pacman = get_angle_for_coordinates(target_pixel_x, target_pixel_y, target_pixel_x, target_pixel_y + 1, pv_PACMAN_X + pv_PACMAN_SIZE / 2, pv_PACMAN_Y + pv_PACMAN_SIZE / 2);
                down_angle_spawn = get_angle_for_coordinates(target_pixel_x, target_pixel_y, target_pixel_x, target_pixel_y + 1, FIELD_WIDTH / 2 * TILE_SIZE, FIELD_HEIGHT / 2 * TILE_SIZE);
                num_directions_possible += 1;
            }

            if (pv_PACMAN_PLAY_FIELD[left_tile] == TILE_PATH || (pv_PACMAN_PLAY_FIELD[left_tile] == TILE_SPAWN_ENTRY && is_spawn)) {
                left_angle_pacman = get_angle_for_coordinates(target_pixel_x, target_pixel_y, target_pixel_x - 1, target_pixel_y, pv_PACMAN_X + pv_PACMAN_SIZE / 2, pv_PACMAN_Y + pv_PACMAN_SIZE / 2);
                left_angle_spawn = get_angle_for_coordinates(target_pixel_x, target_pixel_y, target_pixel_x - 1, target_pixel_y, FIELD_WIDTH / 2 * TILE_SIZE, FIELD_HEIGHT / 2 * TILE_SIZE);
                num_directions_possible += 1;
            }

            if (pv_PACMAN_PLAY_FIELD[right_tile] == TILE_PATH || (pv_PACMAN_PLAY_FIELD[right_tile] == TILE_SPAWN_ENTRY && is_spawn)) {
                right_angle_pacman = get_angle_for_coordinates(target_pixel_x, target_pixel_y, target_pixel_x + 1, target_pixel_y, pv_PACMAN_X + pv_PACMAN_SIZE / 2, pv_PACMAN_Y + pv_PACMAN_SIZE / 2);
                right_angle_spawn = get_angle_for_coordinates(target_pixel_x, target_pixel_y, target_pixel_x + 1, target_pixel_y, FIELD_WIDTH / 2 * TILE_SIZE, FIELD_HEIGHT / 2 * TILE_SIZE);
                num_directions_possible += 1;
            }

            if (current_mode == previous_mode && num_directions_possible > 1) {
                num_directions_possible -= 1;
                if (current_direction == DIRECTION_DOWN) {
                    up_angle_pacman = ANGLE_INVALID;
                    up_angle_spawn = ANGLE_INVALID;
                } else if (current_direction == DIRECTION_UP) {
                    down_angle_pacman = ANGLE_INVALID;
                    down_angle_spawn = ANGLE_INVALID;
                } else if (current_direction == DIRECTION_RIGHT) {
                    left_angle_pacman = ANGLE_INVALID;
                    left_angle_spawn = ANGLE_INVALID;
                } else if (current_direction == DIRECTION_LEFT) {
                    right_angle_pacman = ANGLE_INVALID;
                    right_angle_spawn = ANGLE_INVALID;
                } else {
                    num_directions_possible += 1;
                }
            }

            min_angle_pacman = pick_angle(up_angle_pacman, down_angle_pacman, left_angle_pacman, right_angle_pacman, PICK_MIN);
            max_angle_pacman = pick_angle(up_angle_pacman, down_angle_pacman, left_angle_pacman, right_angle_pacman, PICK_MAX);
            min_angle_spawn = pick_angle(up_angle_spawn, down_angle_spawn, left_angle_spawn, right_angle_spawn, PICK_MIN);

            if (current_mode == MODE_SCATTER) {
                // pick random from possible direction
                int rand_dir_counter = random_int_between(0, num_directions_possible - 1);
                if (up_angle_pacman != ANGLE_INVALID) {
                    if (rand_dir_counter == 0) {
                        chosen_direction = DIRECTION_UP;
                    }
                    rand_dir_counter -= 1;
                }

                if (down_angle_pacman != ANGLE_INVALID) {
                    if (rand_dir_counter == 0) {
                        chosen_direction = DIRECTION_DOWN;
                    }
                    rand_dir_counter -= 1;
                }

                if (left_angle_pacman != ANGLE_INVALID) {
                    if (rand_dir_counter == 0) {
                        chosen_direction = DIRECTION_LEFT;
                    }
                    rand_dir_counter -= 1;
                }

                if (right_angle_pacman != ANGLE_INVALID) {
                    if (rand_dir_counter == 0) {
                        chosen_direction = DIRECTION_RIGHT;
                    }
                    rand_dir_counter -= 1;
                }
            } else if (current_mode == MODE_CHASE) {
                // lowest angle to pacman
                if (up_angle_pacman != ANGLE_INVALID && up_angle_pacman == min_angle_pacman) {
                    chosen_direction = DIRECTION_UP;
                } else if (down_angle_pacman != ANGLE_INVALID && down_angle_pacman == min_angle_pacman) {
                    chosen_direction = DIRECTION_DOWN;
                } else if (left_angle_pacman != ANGLE_INVALID && left_angle_pacman == min_angle_pacman) {
                    chosen_direction = DIRECTION_LEFT;
                } else if (right_angle_pacman != ANGLE_INVALID && right_angle_pacman == min_angle_pacman) {
                    chosen_direction = DIRECTION_RIGHT;
                }
            } else if (current_mode == MODE_FRIGHT) {
                // highest angle to pacman
                if (up_angle_pacman != ANGLE_INVALID && up_angle_pacman == max_angle_pacman) {
                    chosen_direction = DIRECTION_UP;
                } else if (down_angle_pacman != ANGLE_INVALID && down_angle_pacman == max_angle_pacman) {
                    chosen_direction = DIRECTION_DOWN;
                } else if (left_angle_pacman != ANGLE_INVALID && left_angle_pacman == max_angle_pacman) {
                    chosen_direction = DIRECTION_LEFT;
                } else if (right_angle_pacman != ANGLE_INVALID && right_angle_pacman == max_angle_pacman) {
                    chosen_direction = DIRECTION_RIGHT;
                }
            } else if (current_mode == MODE_SPAWN) {
                // lowest angle to spawn
                if (up_angle_spawn != ANGLE_INVALID && (up_angle_spawn == min_angle_spawn || is_spawn_upwards_override(target_tile))) {
                    chosen_direction = DIRECTION_UP;
                } else if (down_angle_spawn != ANGLE_INVALID && down_angle_spawn == min_angle_spawn) {
                    chosen_direction = DIRECTION_DOWN;
                } else if (left_angle_spawn != ANGLE_INVALID && left_angle_spawn == min_angle_spawn) {
                    chosen_direction = DIRECTION_LEFT;
                } else if (right_angle_spawn != ANGLE_INVALID && right_angle_spawn == min_angle_spawn) {
                    chosen_direction = DIRECTION_RIGHT;
                }
            }

            pvSet(pv_GHOST_DIR, chosen_direction);

            origin_tile = target_tile;
            origin_tile_x = target_tile_x;
            origin_tile_y = target_tile_y;
            if (chosen_direction == DIRECTION_UP) {
                target_tile_y = target_tile_y - 1;
            } else if (chosen_direction == DIRECTION_DOWN) {
                target_tile_y = target_tile_y + 1;
            } else if (chosen_direction == DIRECTION_LEFT) {
                target_tile_x = target_tile_x - 1;
            } else if (chosen_direction == DIRECTION_RIGHT) {
                target_tile_x = target_tile_x + 1;
            }

            target_tile = get_tile_index_from_tile_coordinates(target_tile_x, target_tile_y);
            target_pixel_x = target_tile_x * TILE_SIZE + TILE_SIZE / 2;
            target_pixel_y = target_tile_y * TILE_SIZE + TILE_SIZE / 2;
        } state MOVE_DIRECTION
    }

    state MOVE_DIRECTION {
        entry {
            pvSetStr(pv_LOGS, "MOVE_DIRECTION");
        }
        when (pv_CURRENT_MODE == MODE_WAIT) {
        } state CHECK_MODE
        when (pv_GHOST_X + ghost_size / 2 == target_pixel_x && pv_GHOST_Y + ghost_size / 2 == target_pixel_y) {
            previous_mode = current_mode;
        } state CHECK_MODE
        when (delay(delay_time)) {
            // Move step towards target_pixel_x and target_pixel_y
            int current_x = pv_GHOST_X + ghost_size / 2;
            int current_y = pv_GHOST_Y + ghost_size / 2;
            if (current_x < target_pixel_x) {
                pvSet(pv_GHOST_X, pv_GHOST_X + 1)
            } else if (current_x > target_pixel_x) {
                pvSet(pv_GHOST_X, pv_GHOST_X - 1)
            }

            if (current_y < target_pixel_y) {
                pvSet(pv_GHOST_Y, pv_GHOST_Y + 1)
            } else if (current_y > target_pixel_y) {
                pvSet(pv_GHOST_Y, pv_GHOST_Y - 1)
            }
            current_direction = chosen_direction;
        } state MOVE_DIRECTION
    }
}

#define GHOST_SKIN_RIGHT_1 0
#define GHOST_SKIN_RIGHT_2 1
#define GHOST_SKIN_LEFT_1 2
#define GHOST_SKIN_LEFT_2 3
#define GHOST_SKIN_UP_1 4
#define GHOST_SKIN_UP_2 5
#define GHOST_SKIN_DOWN_1 6
#define GHOST_SKIN_DOWN_2 7

ss ghost_animation{
    int frame_1;
    int frame_2;
    int current_direction;
    double time_next_frame;
    int current_frame = 2;

    state INIT{
        when () {
        } state CHECK_DIRECTION
    }

    state CHECK_DIRECTION{
        entry {
            current_direction = pv_GHOST_DIR;
            if(current_direction == DIRECTION_RIGHT){
                frame_1 = GHOST_SKIN_RIGHT_1;
                frame_2 = GHOST_SKIN_RIGHT_2;
            }
            if(current_direction == DIRECTION_LEFT){
                frame_1 = GHOST_SKIN_LEFT_1;
                frame_2 = GHOST_SKIN_LEFT_2;
            }
            if(current_direction == DIRECTION_UP){
                frame_1 = GHOST_SKIN_UP_1;
                frame_2 = GHOST_SKIN_UP_2;
            }
            if(current_direction == DIRECTION_DOWN){
                frame_1 = GHOST_SKIN_DOWN_1;
                frame_2 = GHOST_SKIN_DOWN_2;
            }
        }
        when () {
            pvSet(pv_GHOST_CURRENT_FRAME, frame_2);
        } state FRAME_1
    }

    state FRAME_1 {
        entry {
            if (current_frame == 2) {
                time_next_frame = get_time_from_now(pv_GHOST_ANIMATION_DELAY);
                current_frame = 1;
            }
        }
        when (is_time_reached(time_next_frame)) {
            pvSet(pv_GHOST_CURRENT_FRAME, frame_1);
        } state FRAME_2
        when (current_direction != pv_GHOST_DIR) {
        } state CHECK_DIRECTION
        when () {
        } state FRAME_1
    }

    state FRAME_2 {
        entry {
            if (current_frame == 1) {
                time_next_frame = get_time_from_now(pv_GHOST_ANIMATION_DELAY);
                current_frame = 2;
            }
        }
        when (is_time_reached(time_next_frame)) {
            pvSet(pv_GHOST_CURRENT_FRAME, frame_2);
        } state FRAME_1
        when (current_direction != pv_GHOST_DIR) {
        } state CHECK_DIRECTION
        when () {
        } state FRAME_2
    }
}