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
PV( int     , pv_PACMAN_TRY_DIRECTION_LEFT, "{NAME}:PACMAN_TRY_DIRECTION_LEFT", PV_MON );
PV( int     , pv_PACMAN_TRY_DIRECTION_RIGHT, "{NAME}:PACMAN_TRY_DIRECTION_RIGHT", PV_MON );
PV( int     , pv_PACMAN_TRY_DIRECTION_UP, "{NAME}:PACMAN_TRY_DIRECTION_UP", PV_MON );
PV( int     , pv_PACMAN_TRY_DIRECTION_DOWN, "{NAME}:PACMAN_TRY_DIRECTION_DOWN", PV_MON );
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
PV( int     , pv_PACMAN_TARGET_VALID	, "{NAME}:PACMAN_TARGET_VALID"	, PV_MON );
PV( string  , pv_SS_PACMAN				, "{NAME}:SS_PACMAN"			, PV_NONE );
PVA( short	, pv_PACMAN_PLAY_FIELD, 1024, "{NAME}:PACMAN_PLAY_FIELD"	, PV_MON);
PVA( unsigned char, pv_PACMAN_PNG_DATA, 200000, "{NAME}:PACMAN_PNG_DATA" , PV_NONE );

#define DIRECTION_RIGHT 0
#define DIRECTION_LEFT 1
#define DIRECTION_UP 2
#define DIRECTION_DOWN 3

#define bool int
#define true 1
#define false 0

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

#define STATE_NORMAL 0
#define STATE_BLOCKED 1
#define STATE_TELEPORT 2
#define STATE_READY 3

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

    static void field_to_png_xy(int fx, int fy, int png_w, int png_h, int* outx, int* outy) {
        const int field_w_px = FIELD_WIDTH * TILE_SIZE;
        const int field_h_px = FIELD_HEIGHT * TILE_SIZE;

        double sx = (double)png_w / (double)field_w_px;
        double sy = (double)png_h / (double)field_h_px;
        double s = (sx < sy) ? sx : sy; // uniform scale to preserve aspect

        int off_x = (int)((png_w - (int)(field_w_px * s)) * 0.5 + 0.5);
        int off_y = (int)((png_h - (int)(field_h_px * s)) * 0.5 + 0.5);

        int x = (int)(fx * s + 0.5) + off_x;
        int y = (int)(fy * s + 0.5) + off_y;

        if (x < 0) x = 0; if (x >= png_w) x = png_w - 1;
        if (y < 0) y = 0; if (y >= png_h) y = png_h - 1;

        *outx = x;
        *outy = y;
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

    int convert_graphical_coordinate_to_tile_coordinate(int coordinate, int field_size, int tile_size) {
        // Convert a graphical coordinate to a tile coordinate, clamped to field size
        int tile = coordinate / tile_size;
        if (tile < 0) tile = 0;
        if (tile >= field_size) tile = field_size - 1;
        return tile;
    }

    // allow "almost centered" checks with small tolerance
    static int is_near(int a, int b, int tolerance) {
        int d = (a > b) ? (a - b) : (b - a);
        return d <= tolerance;
    }
}%

ss pacman_game {
    int current_tile_x = 0; // Current tile X coordinate
    int current_tile_y = 0; // Current tile Y coordinate
    int target_tile_x = -1;
    int target_tile_y = -1;
    int origin_tile = 0; // Origin tile index
    int origin_tile_x = 0; // Origin tile X coordinate
    int origin_tile_y = 0; // Origin tile Y coordinate
    bool trying_new_direction = false; // Flag to indicate if a new direction is being tried

    state INIT {
		entry {
			pvSetStr( pv_SS_PACMAN, "INIT" );
			pvSet(pv_PACMAN_USER_X, 25); // Initial X position
			pvSet(pv_PACMAN_USER_Y, 25); // Initial Y position
			pvSet(pv_PACMAN_USER_DIRECTION, -1); // Initial direction (0=right, 1=left, 2=up, 3=down)
            
            // No direction tried yet
            pvSet(pv_PACMAN_TRY_DIRECTION, -1); 
            pvSet(pv_PACMAN_TRY_DIRECTION_LEFT, 0);
            pvSet(pv_PACMAN_TRY_DIRECTION_RIGHT, 0);
            pvSet(pv_PACMAN_TRY_DIRECTION_UP, 0);
            pvSet(pv_PACMAN_TRY_DIRECTION_DOWN, 0);

            pvSet(pv_PACMAN_PACMAN_STATE, STATE_READY); // Initial state is ready
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
        int pos_x;
        int pos_y;
        entry { 
            pvSetStr(pv_SS_PACMAN, "READY");
            origin_tile_x = FIELD_WIDTH / 2;
            origin_tile_y = FIELD_HEIGHT / 2 - 1;
            printf("Initial: origin_tile_x=%d, origin_tile_y=%d\n", origin_tile_x, origin_tile_y);
            origin_tile = get_tile_index_from_tile_coordinates(origin_tile_x, origin_tile_y);
            printf("origin_tile index=%d\n", origin_tile);
            origin_tile = origin_tile + 3 * FIELD_WIDTH;
            printf("After adding 3 rows: origin_tile=%d\n", origin_tile);
            get_tile_coordinates_from_tile_index(origin_tile, &origin_tile_x, &origin_tile_y);
            printf("Final: origin_tile_x=%d, origin_tile_y=%d\n", origin_tile_x, origin_tile_y);
            current_tile_x = origin_tile_x;
            current_tile_y = origin_tile_y;
            pos_x = origin_tile_x * TILE_SIZE + TILE_SIZE / 2 - pv_PACMAN_PACMAN_SIZE / 2;
            pos_y = origin_tile_y * TILE_SIZE + TILE_SIZE / 2 - pv_PACMAN_PACMAN_SIZE / 2;
            printf("Setting position to: (%d, %d) with pacman_size=%d\n", pos_x, pos_y, pv_PACMAN_PACMAN_SIZE);
            pvSet(pv_PACMAN_USER_X, pos_x);
            pvSet(pv_PACMAN_USER_Y, pos_y);
        }

        when (pv_PACMAN_TRY_DIRECTION_LEFT == true){
            pvSet(pv_PACMAN_TRY_DIRECTION, DIRECTION_LEFT);
            pvSet(pv_PACMAN_TRY_DIRECTION_LEFT, 0);
        } state MOVE_CHECK

        when (pv_PACMAN_TRY_DIRECTION_RIGHT == true){
            pvSet(pv_PACMAN_TRY_DIRECTION, DIRECTION_RIGHT);
            pvSet(pv_PACMAN_TRY_DIRECTION_RIGHT, 0);
        } state MOVE_CHECK

        when (pv_PACMAN_TRY_DIRECTION != pv_PACMAN_USER_DIRECTION) {            
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
            direction = pv_PACMAN_TRY_DIRECTION;         
        }

        when (trying_new_direction == true && direction == DIRECTION_UP && pv_PACMAN_PLAY_FIELD[up_tile] != TILE_PATH){
            pvSet(pv_PACMAN_TRY_DIRECTION, INVALID_DIRECTION); // Reset direction if blocked
        } state MOVE

        when (trying_new_direction == true && direction == DIRECTION_DOWN && pv_PACMAN_PLAY_FIELD[down_tile] != TILE_PATH){
            pvSet(pv_PACMAN_TRY_DIRECTION, INVALID_DIRECTION); // Reset direction if blocked
        } state MOVE

        when (trying_new_direction == true && direction == DIRECTION_LEFT && pv_PACMAN_PLAY_FIELD[left_tile] != TILE_PATH){
            pvSet(pv_PACMAN_TRY_DIRECTION, INVALID_DIRECTION); // Reset direction if blocked
        } state MOVE

        when (trying_new_direction == true && direction == DIRECTION_RIGHT && pv_PACMAN_PLAY_FIELD[right_tile] != TILE_PATH){
            pvSet(pv_PACMAN_TRY_DIRECTION, INVALID_DIRECTION); // Reset direction if blocked
        } state MOVE

        when (direction == DIRECTION_UP && pv_PACMAN_PLAY_FIELD[up_tile] != TILE_PATH){

        } state BLOCKED

        when (direction == DIRECTION_DOWN && pv_PACMAN_PLAY_FIELD[down_tile] != TILE_PATH){

        } state BLOCKED

        when (direction == DIRECTION_LEFT && pv_PACMAN_PLAY_FIELD[left_tile] != TILE_PATH){

        } state BLOCKED

        when (direction == DIRECTION_RIGHT && pv_PACMAN_PLAY_FIELD[right_tile] != TILE_PATH){

        } state BLOCKED

        when (pv_PACMAN_TRY_DIRECTION == READY_DIRECTION) {
            // No direction set, stay in READY state
        } state READY

        when () {
            // Proceed to SET_TARGET state if a valid direction is set
            pvSet(pv_PACMAN_PACMAN_STATE, STATE_NORMAL);
            pvSet(pv_PACMAN_USER_DIRECTION, pv_PACMAN_TRY_DIRECTION);
            target_tile_x = -1; // Reset target tile coordinates
            target_tile_y = -1; // Reset target tile coordinates
        } state SET_TARGET
    }

    // Enumerate all tiles in one direction until a wall, spawn_area or a portal, then sets the target to the tile before the wall, spawn_area but on top of the portal
    state SET_TARGET {
        int target_tile_index = -1; // Index of the target tile
        entry {
            pvSetStr(pv_SS_PACMAN, "SET_TARGET");
        }
        when (pv_PACMAN_TARGET_VALID == 1 && target_tile_x != -1 && target_tile_y != -1) {

        } state MOVE
        when () {
            if (target_tile_x == -1 || target_tile_y == -1) {
                // If target tile coordinates are not set, initialize them to current tile coordinates
                target_tile_x = current_tile_x;
                target_tile_y = current_tile_y;
            }
            target_tile_index = get_tile_index_from_tile_coordinates(target_tile_x, target_tile_y);
            //printf("Current tile: (%d, %d), Target tile: (%d, %d)\n", current_tile_x, current_tile_y, target_tile_x, target_tile_y);
            pvSet(pv_PACMAN_TARGET_VALID, 0); // Reset valid target flag
            if (pv_PACMAN_USER_DIRECTION == DIRECTION_UP) {
                if (pv_PACMAN_PLAY_FIELD[target_tile_index - FIELD_WIDTH] != TILE_PATH) {
                    pvSet(pv_PACMAN_TARGET_VALID, 1);
                } else {
                    target_tile_y -= 1; // Move up one tile                    
                }
            } else if (pv_PACMAN_USER_DIRECTION == DIRECTION_DOWN) {
                if (pv_PACMAN_PLAY_FIELD[target_tile_index + FIELD_WIDTH] != TILE_PATH) {
                    pvSet(pv_PACMAN_TARGET_VALID, 1);
                } else {
                    target_tile_y += 1; // Move down one tile
                }
            } else if (pv_PACMAN_USER_DIRECTION == DIRECTION_LEFT) {
                if (pv_PACMAN_PLAY_FIELD[target_tile_index - 1] != TILE_PATH) {
                    pvSet(pv_PACMAN_TARGET_VALID, 1);
                } else {
                    target_tile_x -= 1; // Move left one tile
                }
            } else if (pv_PACMAN_USER_DIRECTION == DIRECTION_RIGHT) {
                if (pv_PACMAN_PLAY_FIELD[target_tile_index + 1] != TILE_PATH) {
                    pvSet(pv_PACMAN_TARGET_VALID, 1);
                } else {
                    target_tile_x += 1; // Move right one tile
                }
            } else {
                printf("Invalid direction: %d\n", pv_PACMAN_USER_DIRECTION);
                pvSet(pv_PACMAN_TARGET_VALID, 0); // Reset valid target flag
            }
        } state SET_TARGET
    }


    state BLOCKED {
        entry {
            pvSetStr(pv_SS_PACMAN, "BLOCKED");
            pvSet(pv_PACMAN_TRY_DIRECTION, pv_PACMAN_USER_DIRECTION);
            pvSet(pv_PACMAN_PACMAN_STATE, STATE_BLOCKED);
        }

        when (pv_PACMAN_TRY_DIRECTION_LEFT == true){
            pvSet(pv_PACMAN_TRY_DIRECTION, DIRECTION_LEFT);
            pvSet(pv_PACMAN_TRY_DIRECTION_LEFT, 0); // Reset left
        } state MOVE_CHECK

        when (pv_PACMAN_TRY_DIRECTION_RIGHT == true){
            pvSet(pv_PACMAN_TRY_DIRECTION, DIRECTION_RIGHT);
            pvSet(pv_PACMAN_TRY_DIRECTION_RIGHT, 0); // Reset right
        } state MOVE_CHECK

        when (pv_PACMAN_TRY_DIRECTION_UP == true){
            pvSet(pv_PACMAN_TRY_DIRECTION, DIRECTION_UP);
            pvSet(pv_PACMAN_TRY_DIRECTION_UP, 0); // Reset up
        } state MOVE_CHECK

        when (pv_PACMAN_TRY_DIRECTION_DOWN == true){
            pvSet(pv_PACMAN_TRY_DIRECTION, DIRECTION_DOWN);
            pvSet(pv_PACMAN_TRY_DIRECTION_DOWN, 0); // Reset down
        } state MOVE_CHECK

        when (pv_PACMAN_TRY_DIRECTION != pv_PACMAN_USER_DIRECTION){
            
        } state MOVE_CHECK
    }

    // Slowly moves pacman to the target tile, if the target tile is a wall, spawn_area or portal, it will not move
    // If the target tile is a portal, go to state TELEPORT
    // it will stay in this state until the target tile is reached or trying to move in a different direction
    state MOVE {
        int old_tile_y = -1; // Store the previous tile Y coordinate for comparison
        int stop_reason = 0; // Variable to store the reason for stopping
        entry {
            pvSetStr(pv_SS_PACMAN, "MOVE");
            trying_new_direction = false; // Reset the flag for trying a new direction
        }

        when (pv_PACMAN_PACMAN_ABORT == 1) {
            // If the user aborts, go to USER_ABORT state
            printf("User aborted the movement.\n");
        } state USER_ABORT

        when (pv_PACMAN_TRY_DIRECTION != pv_PACMAN_USER_DIRECTION && pv_PACMAN_TRY_DIRECTION != INVALID_DIRECTION) {
            // If the user tries to change direction, go back to MOVE_CHECK
            printf("User tried to change direction while moving.\n");
            trying_new_direction = true; // Set flag to indicate a new direction is being tried
        } state MOVE_CHECK

        when (pv_PACMAN_USER_DIRECTION == DIRECTION_LEFT && current_tile_x == 0) {
            // If the current tile is a portal, go to TELEPORT state
            printf("Pacman reached a portal at (%d, %d).\n", current_tile_x, current_tile_y);
        } state TELEPORT_LEFT

        when (pv_PACMAN_USER_DIRECTION == DIRECTION_RIGHT && current_tile_x == FIELD_WIDTH - 1){
            // If the current tile is a portal, go to TELEPORT state
            printf("Pacman reached a portal at (%d, %d).\n", current_tile_x, current_tile_y);
        } state TELEPORT_RIGHT        

        when (pv_PACMAN_USER_X + (pv_PACMAN_PACMAN_SIZE / 2) == (target_tile_x * TILE_SIZE + TILE_SIZE / 2) && pv_PACMAN_USER_Y + (pv_PACMAN_PACMAN_SIZE / 2) == (target_tile_y * TILE_SIZE + TILE_SIZE / 2)) {
            printf("Pacman reached the target tile (%d, %d).\n", target_tile_x, target_tile_y);            
            target_tile_x = -1; // Reset target tile coordinates
            target_tile_y = -1; // Reset target tile coordinates
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
            int tolerance = step_size + 1; // small leeway to detect alignment
            int new_x = current_x;
            int new_y = current_y;
            int png_x = 0;
            int png_y = 0;
            //printf("Starting movement: current_x=%d, current_y=%d, direction=%d\n", current_x, current_y, direction);
            if (direction == DIRECTION_UP) {
                new_y -= step_size;
                //printf("Moving up to (%d, %d)\n", new_x, new_y);
            } else if (direction == DIRECTION_DOWN) {
                new_y += step_size;
                //printf("Moving down to (%d, %d)\n", new_x, new_y);
            } else if (direction == DIRECTION_LEFT) {
                new_x -= step_size;
                //printf("Moving left to (%d, %d)\n", new_x, new_y);
            } else if (direction == DIRECTION_RIGHT) {
                new_x += step_size;
                //printf("Moving right to (%d, %d)\n", new_x, new_y);
            }
            // Check if the new position is within bounds
            if (new_x >= 0 && new_x < field_size && new_y >= 0 && new_y < field_size) {
                // Update the position
                pvSet(pv_PACMAN_USER_X, new_x);
                pvSet(pv_PACMAN_USER_Y, new_y);
                // Update the current tile coordinates
                //printf("Before conversion: new_x=%d, new_y=%d, current_tile_y=%d\n", new_x, new_y, current_tile_y);
                //printf("Debug: new_y=%d, FIELD_HEIGHT=%d, TILE_SIZE=%d\n", new_y, FIELD_HEIGHT, TILE_SIZE);
                //printf("Debug: new_y/TILE_SIZE = %d/%d = %d\n", new_y, TILE_SIZE, new_y / TILE_SIZE);

                // Store old values for comparison
                old_tile_y = current_tile_y;
                
                current_tile_x = convert_graphical_coordinate_to_tile_coordinate(new_x + pv_PACMAN_PACMAN_SIZE / 2, FIELD_WIDTH, TILE_SIZE);
                current_tile_y = convert_graphical_coordinate_to_tile_coordinate(new_y + pv_PACMAN_PACMAN_SIZE / 2, FIELD_HEIGHT, TILE_SIZE);
                
                /*printf("After conversion: current_tile_x=%d, current_tile_y=%d (was %d)\n", 
                       current_tile_x, current_tile_y, old_tile_y);
                printf("Pacman moved to tile (%d, %d) at position (%d, %d) targeting tile (%d, %d)\n",
                       current_tile_x, current_tile_y, new_x, new_y, target_tile_x, target_tile_y);*/

                field_to_png_xy(new_x, new_y, pv_PACMAN_PNG_WIDTH, pv_PACMAN_PNG_HEIGHT, &png_x, &png_y);

                //printf("Drawing Pacman at PNG coordinates (%d, %d)\n", png_x, png_y);

                draw_pixel(png_x, png_y, pv_PACMAN_PNG_DATA, pv_PACMAN_PNG_WIDTH, pv_PACMAN_PNG_HEIGHT, 255, 255, 0);
                pvPut(pv_PACMAN_PNG_DATA);
            }

            // Turning logic with tolerance and snapping to center line
            if (pv_PACMAN_TRY_DIRECTION_LEFT == true) {
                // check if the left tile to the current position is valid and pacman is near the center on the Y axis
                int center_y = current_tile_y * TILE_SIZE + TILE_SIZE / 2 - pv_PACMAN_PACMAN_SIZE / 2;
                if (current_tile_x > 0 &&
                    pv_PACMAN_PLAY_FIELD[get_tile_index_from_tile_coordinates(current_tile_x - 1, current_tile_y)] == TILE_PATH &&
                    is_near(new_y, center_y, tolerance)) {
                    // snap to center line to stabilize movement
                    if (new_y != center_y) {
                        new_y = center_y;
                        pvSet(pv_PACMAN_USER_Y, new_y);
                    }
                    printf("User changed direction to LEFT\n");
                    pvSet(pv_PACMAN_TRY_DIRECTION, DIRECTION_LEFT);
                    pvSet(pv_PACMAN_TRY_DIRECTION_LEFT, 0); // Reset left
                }
            } else if (pv_PACMAN_TRY_DIRECTION_RIGHT == true) {
                // check if the right tile to the current position is valid and pacman is near the center on the Y axis
                int center_y = current_tile_y * TILE_SIZE + TILE_SIZE / 2 - pv_PACMAN_PACMAN_SIZE / 2;
                if (current_tile_x < FIELD_WIDTH - 1 &&
                    pv_PACMAN_PLAY_FIELD[get_tile_index_from_tile_coordinates(current_tile_x + 1, current_tile_y)] == TILE_PATH &&
                    is_near(new_y, center_y, tolerance)) {
                    if (new_y != center_y) {
                        new_y = center_y;
                        pvSet(pv_PACMAN_USER_Y, new_y);
                    }
                    printf("User changed direction to RIGHT\n");
                    pvSet(pv_PACMAN_TRY_DIRECTION, DIRECTION_RIGHT);
                    pvSet(pv_PACMAN_TRY_DIRECTION_RIGHT, 0); // Reset right
                }
            } else if (pv_PACMAN_TRY_DIRECTION_UP == true) {
                // check if the upper tile to the current position is valid and pacman is near the center on the X axis
                int center_x = current_tile_x * TILE_SIZE + TILE_SIZE / 2 - pv_PACMAN_PACMAN_SIZE / 2;
                if (current_tile_y > 0 &&
                    pv_PACMAN_PLAY_FIELD[get_tile_index_from_tile_coordinates(current_tile_x, current_tile_y - 1)] == TILE_PATH &&
                    is_near(new_x, center_x, tolerance)) {
                    if (new_x != center_x) {
                        new_x = center_x;
                        pvSet(pv_PACMAN_USER_X, new_x);
                    }
                    printf("User changed direction to UP\n");
                    pvSet(pv_PACMAN_TRY_DIRECTION, DIRECTION_UP);
                    pvSet(pv_PACMAN_TRY_DIRECTION_UP, 0); // Reset up
                }
            } else if (pv_PACMAN_TRY_DIRECTION_DOWN == true) {
                // check if the lower tile to the current position is valid and pacman is near the center on the X axis
                int center_x = current_tile_x * TILE_SIZE + TILE_SIZE / 2 - pv_PACMAN_PACMAN_SIZE / 2;
                if (current_tile_y < FIELD_HEIGHT - 1 &&
                    pv_PACMAN_PLAY_FIELD[get_tile_index_from_tile_coordinates(current_tile_x, current_tile_y + 1)] == TILE_PATH &&
                    is_near(new_x, center_x, tolerance)) {
                    if (new_x != center_x) {
                        new_x = center_x;
                        pvSet(pv_PACMAN_USER_X, new_x);
                    }
                    printf("User changed direction to DOWN\n");
                    pvSet(pv_PACMAN_TRY_DIRECTION, DIRECTION_DOWN);
                    pvSet(pv_PACMAN_TRY_DIRECTION_DOWN, 0); // Reset down
                }
            }

        } state MOVE
    }

    state TELEPORT_LEFT {
        entry {
            pvSetStr(pv_SS_PACMAN, "TELEPORT_LEFT");
        }
        when (delay(0.02)){
            pvSet(pv_PACMAN_USER_X, FIELD_WIDTH * TILE_SIZE - pv_PACMAN_PACMAN_SIZE);
            current_tile_x = FIELD_WIDTH - 1; // Update current tile X coordinate
        } state MOVE_CHECK
    }

    state TELEPORT_RIGHT {
        entry {
            pvSetStr(pv_SS_PACMAN, "TELEPORT_RIGHT");
        }
        when (delay(0.02)){
            pvSet(pv_PACMAN_USER_X, pv_PACMAN_PACMAN_SIZE - TILE_SIZE / 2);
            current_tile_x = 0; // Update current tile X coordinate
        } state MOVE_CHECK
    }

    state USER_ABORT {
        entry {
            pvSetStr(pv_SS_PACMAN, "USER_ABORT");
            pvSet(pv_PACMAN_PACMAN_STATE, STATE_BLOCKED);
        }
        when (pv_PACMAN_PACMAN_ABORT == 0){
            pvSet(pv_PACMAN_PACMAN_STATE, STATE_NORMAL);
        } state MOVE
    }

}