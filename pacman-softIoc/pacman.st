program pacman
#include "seqPVmacros.h"

%%#include "math.h"
%%#include "stdlib.h"
%%#include "stdio.h"
%%#include "png.h"
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
PV( int     , pv_PACMAN_FIELD_RESOLUTION, "{NAME}:PACMAN_FIELD_RESOLUTION", PV_MON );
PV( int     , pv_PACMAN_RESERVE_SIZE	, "{NAME}:PACMAN_RESERVE_SIZE"	, PV_MON );
PV( int     , pv_PACMAN_ARRAY_X_SIZE	, "{NAME}:PACMAN_ARRAY_X_SIZE"	, PV_MON );
PV( int     , pv_PACMAN_ARRAY_X_FACTOR	, "{NAME}:PACMAN_ARRAY_X_FACTOR", PV_MON );
PV( int     , pv_PACMAN_ARRAY_ROW       , "{NAME}:PACMAN_ARRAY_ROW"	    , PV_MON );
PV( int     , pv_PACMAN_ARRAY_COL       , "{NAME}:PACMAN_ARRAY_COL"	    , PV_MON );
PV( int     , pv_PACMAN_PACMAN_STATE	, "{NAME}:PACMAN_PACMAN_STATE"	, PV_MON );
PV( int     , pv_PACMAN_PACMAN_ABORT	, "{NAME}:PACMAN_PACMAN_ABORT"	, PV_MON );
PV( int     , pv_PACMAN_PACMAN_SIZE     , "{NAME}:PACMAN_PACMAN_SIZE"	, PV_MON );
PV( int     , pv_PACMAN_PNG_WIDTH		, "{NAME}:PACMAN_PNG_WIDTH"		, PV_MON );
PV( int     , pv_PACMAN_PNG_HEIGHT      , "{NAME}:PACMAN_PNG_HEIGHT"	, PV_MON );
PV( int     , pv_PACMAN_DATA_SIZE       , "{NAME}:PACMAN_PNG_DATA_SIZE"	, PV_MON );
PV( int     , pv_PACMAN_DEBUG_MODE	    , "{NAME}:PACMAN_DEBUG_MODE"	, PV_MON );
PV( string  , pv_SS_PACMAN				, "{NAME}:SS_PACMAN"			, PV_NONE );
PVA( short	, pv_PACMAN_PLAY_FIELD, 1024, "{NAME}:PACMAN_PLAY_FIELD"	, PV_MON);
PVA( unsigned char, pv_PACMAN_PNG_DATA, 200000, "{NAME}:PACMAN_PNG_DATA" , PV_NONE );

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

#define FIELD_WIDTH 28
#define FIELD_HEIGHT 31
#define TILE_SIZE 32

#define TILE_PATH 0
#define TILE_WALL 1
#define TILE_PORTAL 2
#define TILE_SPAWN_ENTRY 3

#define INVALID_DIRECTION -1
#define READY_DIRECTION -1

// PNG logic
%{
    // Function to handle libpng errors
    void png_error_function(png_structp png_ptr, png_const_charp msg) {
        fprintf(stderr, "libpng error: %s\n", msg);
        if (png_ptr) {
            png_destroy_read_struct(&png_ptr, NULL, NULL);
        }
        exit(EXIT_FAILURE);
    }

    // Function to handle libpng warnings (optional)
    void png_warning_function(png_structp png_ptr, png_const_charp msg) {
        fprintf(stderr, "libpng warning: %s\n", msg);
    }

    /**
     * Reads an 8-bit RGB image from a PNG file into a single 1D array.
     * The caller is responsible for freeing the returned data array.
     *
     * @param filename The path to the PNG file.
     * @param width Pointer to store the image width.
     * @param height Pointer to store the image height.
     * @return A pointer to the 1D unsigned char array containing RGB data,
     *         or NULL on failure.
     */
    unsigned char* read_png_to_1d_rgb(const char* filename, int* width, int* height) {
        FILE* fp = NULL;
        png_structp png_ptr = NULL;
        png_infop info_ptr = NULL;
        png_bytep* row_pointers = NULL;
        unsigned char* image_data = NULL;

        fp = fopen(filename, "rb");
        if (!fp) {
            fprintf(stderr, "Error: Could not open file %s for reading.\n", filename);
            return NULL;
        }

        // 1. Create and initialize the png_structs
        png_ptr = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL,
                                         png_error_function, png_warning_function);
        if (!png_ptr) {
            fprintf(stderr, "Error: Could not create PNG read struct.\n");
            fclose(fp);
            return NULL;
        }

        info_ptr = png_create_info_struct(png_ptr);
        if (!info_ptr) {
            fprintf(stderr, "Error: Could not create PNG info struct.\n");
            png_destroy_read_struct(&png_ptr, NULL, NULL);
            fclose(fp);
            return NULL;
        }

        // 2. Set up error handling (longjmp for non-fatal errors)
        if (setjmp(png_jmpbuf(png_ptr))) {
            // This code is executed if an error occurs during PNG processing
            fprintf(stderr, "Error during PNG image processing.\n");
            if (fp) fclose(fp);
            if (png_ptr) png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
            if (row_pointers) free(row_pointers);
            if (image_data) free(image_data);
            return NULL;
        }

        // 3. Initialize PNG I/O
        png_init_io(png_ptr, fp);

        // 4. Read the PNG file header and info
        png_read_info(png_ptr, info_ptr);

        // Get image dimensions and properties
        *width = png_get_image_width(png_ptr, info_ptr);
        *height = png_get_image_height(png_ptr, info_ptr);
        png_byte color_type = png_get_color_type(png_ptr, info_ptr);
        png_byte bit_depth = png_get_bit_depth(png_ptr, info_ptr);

        printf("Image: %s, Width: %d, Height: %d, Color Type: %d, Bit Depth: %d\n",
               filename, *width, *height, color_type, bit_depth);

        // 5. Set up transformations for 8-bit RGB output
        // Expand paletted colors to RGB
        if (color_type == PNG_COLOR_TYPE_PALETTE) {
            png_set_palette_to_rgb(png_ptr);
        }

        // Expand grayscale to 8-bit RGB
        if (color_type == PNG_COLOR_TYPE_GRAY && bit_depth < 8) {
            png_set_expand_gray_1_2_4_to_8(png_ptr);
        } else if (color_type == PNG_COLOR_TYPE_GRAY ||
                   color_type == PNG_COLOR_TYPE_GRAY_ALPHA) {
            // Convert grayscale to RGB by duplicating channels
            png_set_gray_to_rgb(png_ptr);
        }

        // Strip 16-bit per channel images down to 8-bit per channel
        if (bit_depth == 16) {
            png_set_strip_16(png_ptr);
        }

        // Strip alpha channel if present (we only want RGB)
        if (png_get_valid(png_ptr, info_ptr, PNG_INFO_tRNS) ||
            color_type == PNG_COLOR_TYPE_RGB_ALPHA ||
            color_type == PNG_COLOR_TYPE_GRAY_ALPHA) {
            png_set_strip_alpha(png_ptr);
        }

        // After setting transformations, update the info structure
        png_read_update_info(png_ptr, info_ptr);

        // Re-check properties after transformations
        color_type = png_get_color_type(png_ptr, info_ptr); // Should now be RGB
        bit_depth = png_get_bit_depth(png_ptr, info_ptr);   // Should now be 8

        if (color_type != PNG_COLOR_TYPE_RGB || bit_depth != 8) {
            fprintf(stderr, "Error: Image could not be transformed to 8-bit RGB.\n");
            png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
            fclose(fp);
            return NULL;
        }

        // Calculate row_bytes and total image data size
        png_size_t row_bytes = png_get_rowbytes(png_ptr, info_ptr);
        size_t total_size = (size_t)*height * row_bytes; // row_bytes should be width * 3

        if (row_bytes != (png_size_t)*width * 3) {
            fprintf(stderr, "Warning: Expected %d bytes per row (Width * 3), got %zu. "
                            "This might indicate an issue with transformation.\n",
                    *width * 3, row_bytes);
        }

        // 6. Allocate memory for the 1D image data array
        image_data = (unsigned char*)malloc(total_size);
        if (!image_data) {
            fprintf(stderr, "Error: Could not allocate memory for image data.\n");
            png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
            fclose(fp);
            return NULL;
        }

        // 7. Allocate memory for row pointers (for libpng's internal reading)
        row_pointers = (png_bytep*)malloc(sizeof(png_bytep) * (*height));
        if (!row_pointers) {
            fprintf(stderr, "Error: Could not allocate memory for row pointers.\n");
            free(image_data);
            png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
            fclose(fp);
            return NULL;
        }

        // Point each row_pointer to the correct offset in the 1D array
        for (int y = 0; y < *height; y++) {
            row_pointers[y] = image_data + (size_t)y * row_bytes;
        }

        // 8. Read the entire image
        png_read_image(png_ptr, row_pointers);

        // 9. Cleanup
        png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
        fclose(fp);
        free(row_pointers); // Free the array of pointers, not the data they point to

        return image_data;
    }

    void write_rgb_into_pointer(unsigned char* original_data, unsigned char* target_data, int width, int height) {
        if (!original_data || !target_data) {
            fprintf(stderr, "Error: Null pointer passed to write_rgb_into_pointer.\n");
            return;
        }
        size_t total_size = width * height * 3; // 3 bytes per pixel (RGB)
        memcpy(target_data, original_data, total_size);
    }

    /** Converts a position on the pv_PACMAN_FIELD_RESOLUTION * pv_PACMAN_FIELD_RESOLUTION field to an index in a png rgb (3-bit) image
        * @param x The x-coordinate in the field.
        * @param y The y-coordinate in the field.
        * @param field_size_x The width of the field in pixels.
        * @param field_size_y The height of the field in pixels.
        * @param png_width The width of the PNG image.
        * @param png_height The height of the PNG image.
        * @return The index in the 1D RGB array for the PNG image.
        */
    static int get_png_index_from_xy(int x, int y, int field_size_x, int field_size_y, int png_width, int png_height) {
        field_size_x = field_size_x * TILE_SIZE; // Convert field size to pixels
        field_size_y = field_size_y * TILE_SIZE; // Convert field size to pixels

        if (x < 0 || x >= field_size_x || y < 0 || y >= field_size_y) {
            return -1; // out of bounds
        }

        x = (x * png_width) / field_size_x; // Scale x to PNG width
        y = (y * png_height) / field_size_y; // Scale y to PNG height
        if (x < 0 || x >= png_width || y < 0 || y >= png_height) {
            return -1; // out of bounds after scaling
        }

        return (y * png_width + x) * 3; // 3 bytes per pixel (RGB)
    }

    static void draw_pixel(int x, int y, unsigned char* png_data, int png_width, int png_height, unsigned char r, unsigned char g, unsigned char b) {
        if (x < 0 || x >= png_width || y < 0 || y >= png_height) {
            printf("Error: Pixel coordinates out of bounds: (%d, %d)\n", x, y);
            return;
        }
        int index = (y * png_width + x) * 3; // 3 bytes per pixel (RGB)
        png_data[index] = r;     // Red channel
        png_data[index + 1] = g; // Green channel
        png_data[index + 2] = b; // Blue channel
    }

    int previous_index = -1; // Variable to store the previous index for debugging
}%

%{

    int get_tile_index_from_tile_coordinates(int tile_x, int tile_y){
        return tile_y * FIELD_WIDTH + tile_x;
    }

    void get_tile_coordinates_from_tile_index(int tile_index, int *tile_x, int *tile_y) {
        *tile_x = tile_index % FIELD_WIDTH;
        *tile_y = tile_index / FIELD_WIDTH;
    }

    static char* toString(int value) {
        static char buffer[20];
        snprintf(buffer, sizeof(buffer), "%d", value);
        return buffer;
    }
}%

ss pacman_game {
    int current_tile_x = 0; // Current tile X coordinate
    int current_tile_y = 0; // Current tile Y coordinate
    int target_tile_x = 0;
    int target_tile_y = 0;
    int valid_target = 0; // Flag to indicate if a valid target tile is set

    state INIT {
		entry {
			pvSetStr( pv_SS_PACMAN, "INIT" );
			pvSet(pv_PACMAN_USER_X, 25); // Initial X position
			pvSet(pv_PACMAN_USER_Y, 25); // Initial Y position
			pvSet(pv_PACMAN_USER_DIRECTION, -1); // Initial direction (0=right, 1=left, 2=up, 3=down)
            pvSet(pv_PACMAN_TRY_DIRECTION, -1); // No direction tried yet
            pvSet(pv_PACMAN_PACMAN_STATE, 0); // Initial state
            current_tile_x = 1; // Start at tile (1, 1)
            current_tile_y = 1; // Start at tile (1, 1)
		}
        when () {
	        printf( "PACMAN Started\n" );

		} state LOAD_PNG

    }

    state LOAD_PNG {
        entry { pvSetStr(pv_SS_PACMAN, "LOAD_PNG"); }
        when () {
            int width, height;
            unsigned char* image_data = read_png_to_1d_rgb("../pacman_ui/pacman_background.png", &width, &height);
            if (image_data) {
                // Store the image data in the pv_PACMAN_PNG_DATA array
                write_rgb_into_pointer(image_data, pv_PACMAN_PNG_DATA, width, height);
                free(image_data); // Free the image data after copying it
                pvPut(pv_PACMAN_PNG_DATA);
                // Set the width, height, and data size in the PVs
                pvSet(pv_PACMAN_PNG_WIDTH, width);
                pvSet(pv_PACMAN_PNG_HEIGHT, height);
                pvSet(pv_PACMAN_DATA_SIZE, width * height * 3);
            } else {
                printf("Failed to load PNG image.\n");
            }
        } state READY
    }

    state READY {
        entry { pvSetStr(pv_SS_PACMAN, "READY"); }

        when (pv_PACMAN_TRY_DIRECTION != pv_PACMAN_USER_DIRECTION) {
            // Check if the direction is valid
            int direction = pv_PACMAN_TRY_DIRECTION;
            if (direction < 0 || direction > 3) {
                printf("Invalid direction: %d\n", direction);
                pvSet(pv_PACMAN_TRY_DIRECTION, -1); // Reset to invalid
            }
        } state MOVE_CHECK
    }

    state MOVE_CHECK {
        int up_tile;
        int down_tile;
        int left_tile;
        int right_tile;
        int current_tile;
        int direction;

        entry {
            pvSetStr(pv_SS_PACMAN, "MOVE_CHECK");
            up_tile = get_tile_index_from_tile_coordinates(current_tile_x, current_tile_y - 1);
            down_tile = get_tile_index_from_tile_coordinates(current_tile_x, current_tile_y + 1);
            left_tile = get_tile_index_from_tile_coordinates(current_tile_x - 1, current_tile_y);
            right_tile = get_tile_index_from_tile_coordinates(current_tile_x + 1, current_tile_y);
            current_tile = get_tile_index_from_tile_coordinates(current_tile_x, current_tile_y);
            direction = pv_PACMAN_USER_DIRECTION = pv_PACMAN_TRY_DIRECTION;         
        }

        when (direction == DIRECTION_UP && pv_PACMAN_PLAY_FIELD[up_tile] != TILE_PATH){

        } state BLOCKED

        when (direction == DIRECTION_DOWN && pv_PACMAN_PLAY_FIELD[down_tile] != TILE_PATH){

        } state BLOCKED

        when (direction == DIRECTION_LEFT && pv_PACMAN_PLAY_FIELD[left_tile] != TILE_PATH){

        } state BLOCKED

        when (direction == DIRECTION_RIGHT && pv_PACMAN_PLAY_FIELD[right_tile] != TILE_PATH){

        } state BLOCKED

        when (pv_PACMAN_USER_DIRECTION == READY_DIRECTION) {
            // No direction set, stay in READY state
        } state READY

        when () {
            // Proceed to SET_TARGET state if a valid direction is set
            pvSet(pv_PACMAN_TRY_DIRECTION, -1); // Reset tried direction
        } state SET_TARGET
    }

    // Enumerate all tiles in one direction until a wall, spawn_area or a portal is hit, then sets the target to the tile before the wall, spawn_area but on top of the portal
    state SET_TARGET {
        int target_tile_index = -1; // Index of the target tile
        entry {
            pvSetStr(pv_SS_PACMAN, "SET_TARGET");
            target_tile_index = get_tile_index_from_tile_coordinates(target_tile_x, target_tile_y);
            valid_target = 0; // Reset valid target flag
            if (pv_PACMAN_USER_DIRECTION == DIRECTION_UP) {
                if (pv_PACMAN_PLAY_FIELD[target_tile_index - FIELD_WIDTH] != TILE_PATH) {
                    valid_target = 1;
                } else {
                    target_tile_y -= 1; // Move up one tile                    
                }
            } else if (pv_PACMAN_USER_DIRECTION == DIRECTION_DOWN) {
                if (pv_PACMAN_PLAY_FIELD[target_tile_index + FIELD_WIDTH] != TILE_PATH) {
                    valid_target = 1;
                } else {
                    target_tile_y += 1; // Move down one tile
                }
            } else if (pv_PACMAN_USER_DIRECTION == DIRECTION_LEFT) {
                if (pv_PACMAN_PLAY_FIELD[target_tile_index - 1] != TILE_PATH) {
                    valid_target = 1;
                } else {
                    target_tile_x -= 1; // Move left one tile
                }
            } else if (pv_PACMAN_USER_DIRECTION == DIRECTION_RIGHT) {
                if (pv_PACMAN_PLAY_FIELD[target_tile_index + 1] != TILE_PATH) {
                    valid_target = 1;
                } else {
                    target_tile_x += 1; // Move right one tile
                }
            } else {
                printf("Invalid direction: %d\n", pv_PACMAN_USER_DIRECTION);
                valid_target = 0; // Reset valid target flag
            }
        }
        when (valid_target == 1){

        } state MOVE
        when () {

        } state SET_TARGET
    }


    state BLOCKED {
        entry {
            pvSetStr(pv_SS_PACMAN, "BLOCKED");
            pvSet(pv_PACMAN_TRY_DIRECTION, pv_PACMAN_USER_DIRECTION);
        }
        when (pv_PACMAN_TRY_DIRECTION != pv_PACMAN_USER_DIRECTION){
            
        } state MOVE_CHECK
    }

    // Slowly moves pacman to the target tile, if the target tile is a wall, spawn_area or portal, it will not move
    // If the target tile is a portal, go to state TELEPORT
    // it will stay in this state until the target tile is reached or trying to move in a different direction
    state MOVE {
        entry {
            pvSetStr(pv_SS_PACMAN, "MOVE");
        }
        when (pv_PACMAN_TRY_DIRECTION != -1) {
            // If the user tries to change direction, go back to MOVE_CHECK
            printf("User tried to change direction while moving.\n");
        } state MOVE_CHECK

        when (pv_PACMAN_PLAY_FIELD[get_tile_index_from_tile_coordinates(current_tile_x, current_tile_y)] == TILE_PORTAL) {
            // If the current tile is a portal, go to TELEPORT state
            printf("Pacman reached a portal at (%d, %d).\n", current_tile_x, current_tile_y);
        } state TELEPORT

        when (current_tile_x == target_tile_x && current_tile_y == target_tile_y) {

        } state BLOCKED

        when (delay(0.02)){
            // Move pacman towards the target tile
            int current_x = pv_PACMAN_USER_X;
            int current_y = pv_PACMAN_USER_Y;
            int target_x = target_tile_x * TILE_SIZE + TILE_SIZE / 2; // Center of the target tile
            int target_y = target_tile_y * TILE_SIZE + TILE_SIZE / 2; // Center of the target tile
            int direction = pv_PACMAN_USER_DIRECTION;
            int field_size = pv_PACMAN_FIELD_SIZE * TILE_SIZE; // Convert field size to pixels
            int step_size = 1; // Step size in pixels
            int new_x = current_x;
            int new_y = current_y;
            if (direction == DIRECTION_UP) {
                new_y -= step_size;
            } else if (direction == DIRECTION_DOWN) {
                new_y += step_size;
            } else if (direction == DIRECTION_LEFT) {
                new_x -= step_size;
            } else if (direction == DIRECTION_RIGHT) {
                new_x += step_size;
            }
            // Check if the new position is within bounds
            if (new_x >= 0 && new_x < field_size && new_y >= 0 && new_y < field_size) {
                // Update the position
                pvSet(pv_PACMAN_USER_X, new_x);
                pvSet(pv_PACMAN_USER_Y, new_y);
                // Update the current tile coordinates
                current_tile_x = new_x / TILE_SIZE;
                current_tile_y = new_y / TILE_SIZE;

            }

        } state MOVE
    }

    state TELEPORT {
        entry {
            pvSetStr(pv_SS_PACMAN, "TELEPORT");
        }
        when (){

        } state TELEPORT
    }

}