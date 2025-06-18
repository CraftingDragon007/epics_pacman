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
    * @param PACMAN_FIELD_RESOLUTION The resolution of the field (width and height).
    * @param png_width The width of the PNG image.
    * @param png_height The height of the PNG image.
    * @return The index in the 1D RGB array for the PNG image.
    */
static int get_png_index_from_xy(int x, int y, int PACMAN_FIELD_RESOLUTION, int png_width, int png_height) {
    if (x < 0 || x >= PACMAN_FIELD_RESOLUTION || y < 0 || y >= PACMAN_FIELD_RESOLUTION) {
        return -1; // out of bounds
    }

    x = (x * png_width) / PACMAN_FIELD_RESOLUTION; // Scale x to PNG width
    y = (y * png_height) / PACMAN_FIELD_RESOLUTION; // Scale y to PNG height
    if (x < 0 || x >= png_width || y < 0 || y >= png_height) {
        return -1; // out of bounds after scaling
    }

    return (y * png_width + x) * 3; // 3 bytes per pixel (RGB)
}

int previous_index = -1; // Variable to store the previous index for debugging

}%

%{
	static int get_array_index_from_xy (int x, int y, int PACMAN_ARRAY_X_SIZE, int PACMAN_ARRAY_X_FACTOR) {
		int index = 0;
		int column = (int) (x / PACMAN_ARRAY_X_FACTOR);
		int row = (int) (y / PACMAN_ARRAY_X_FACTOR);
		if (column < 0 || column >= PACMAN_ARRAY_X_SIZE || row < 0 || row >= PACMAN_ARRAY_X_SIZE) {
			return -1; // out of bounds
		}
		index = row * PACMAN_ARRAY_X_SIZE + column;
		return index;
	}

	static int get_x_from_index (int index, int PACMAN_FIELD_SIZE, int PACMAN_ARRAY_X_SIZE, int PACMAN_ARRAY_X_FACTOR) {
		if (index < 0 || index >= PACMAN_FIELD_SIZE) {
			return -1; // out of bounds
		}
		return (index % PACMAN_ARRAY_X_SIZE) * PACMAN_ARRAY_X_FACTOR;
	}

	static int get_y_from_index (int index, int PACMAN_FIELD_SIZE, int PACMAN_ARRAY_X_SIZE, int PACMAN_ARRAY_X_FACTOR) {
		if (index < 0 || index >= PACMAN_FIELD_SIZE) {
			return -1; // out of bounds
		}
		return (index / PACMAN_ARRAY_X_SIZE) * PACMAN_ARRAY_X_FACTOR;
	}

    static char* toString(int value) {
        static char buffer[20];
        snprintf(buffer, sizeof(buffer), "%d", value);
        return buffer;
    }
}%

ss pacman_game {
    state INIT {
		entry {
			pvSetStr( pv_SS_PACMAN, "INIT" );
			pvSet(pv_PACMAN_USER_X, 25); // Initial X position
			pvSet(pv_PACMAN_USER_Y, 25); // Initial Y position
			pvSet(pv_PACMAN_USER_DIRECTION, 0); // Initial direction (0=right, 1=left, 2=up, 3=down)
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
        } state MOVE_CHECK
    }

    state MOVE_CHECK {
        entry {  
            int current_index;
            int second_index;
            int third_index;
            int offset = (int)(pv_PACMAN_PACMAN_SIZE / 2);
            int half_offset = (int)(pv_PACMAN_PACMAN_SIZE / 4);
            int png_index;

            pvSetStr(pv_SS_PACMAN, "MOVE_CHECK");

            pvSet(pv_PACMAN_ARRAY_COL, (int)(pv_PACMAN_USER_X / pv_PACMAN_ARRAY_X_FACTOR));
            pvSet(pv_PACMAN_ARRAY_ROW, (int)(pv_PACMAN_USER_Y / pv_PACMAN_ARRAY_X_FACTOR));

            // right
            if(pv_PACMAN_USER_DIRECTION == 0){
                current_index = get_array_index_from_xy(pv_PACMAN_USER_X + offset, pv_PACMAN_USER_Y, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
                second_index = current_index + 1;
                third_index = second_index + pv_PACMAN_ARRAY_X_SIZE; // Check field below the next field to the right
                if (pv_PACMAN_PLAY_FIELD[third_index] == 1 && pv_PACMAN_PLAY_FIELD[second_index] == 0) {
                    // correct position - y 1 using index to get y
                    pvSet(pv_PACMAN_USER_Y, get_y_from_index(current_index - pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR));
                    pvSet(pv_PACMAN_USER_X, get_x_from_index(current_index, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR));
                    printf("corrected position right - y 1\n");
                    printf("right current_index: %d second_index: %d third_index: %d x: %d y: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
                    printf("right current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
                    png_index = get_png_index_from_xy(pv_PACMAN_USER_X, pv_PACMAN_USER_Y, pv_PACMAN_FIELD_RESOLUTION, pv_PACMAN_PNG_WIDTH, pv_PACMAN_PNG_HEIGHT);
                    if (png_index >= 0 && png_index < pv_PACMAN_DATA_SIZE) {
                        // Set the color of red for debugging purposes
                        pv_PACMAN_PNG_DATA[png_index] = 255; // Red channel
                        pv_PACMAN_PNG_DATA[png_index + 1] = 0; // Green channel
                        pv_PACMAN_PNG_DATA[png_index + 2] = 0; // Blue channel
                        pvPut(pv_PACMAN_PNG_DATA);
                    } else {
                        printf("Error: PNG index out of bounds: %d\n", png_index);
                    }
                }
                if (pv_PACMAN_PLAY_FIELD[third_index] == 0 && pv_PACMAN_PLAY_FIELD[second_index] == 1) {
                    // correct position + y 1 using index to get y
                    pvSet(pv_PACMAN_USER_Y, get_y_from_index(third_index + pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR));
                    pvSet(pv_PACMAN_USER_X, get_x_from_index(third_index, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR));
                    printf("corrected position right y + 1\n");
                    printf("right current_index: %d second_index: %d third_index: %d x: %d y: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
                    printf("right current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
                    png_index = get_png_index_from_xy(pv_PACMAN_USER_X, pv_PACMAN_USER_Y, pv_PACMAN_FIELD_RESOLUTION, pv_PACMAN_PNG_WIDTH, pv_PACMAN_PNG_HEIGHT);
                    if (png_index >= 0 && png_index < pv_PACMAN_DATA_SIZE) {
                        // Set the color of red for debugging purposes
                        pv_PACMAN_PNG_DATA[png_index] = 255; // Red channel
                        pv_PACMAN_PNG_DATA[png_index + 1] = 0; // Green channel
                        pv_PACMAN_PNG_DATA[png_index + 2] = 0; // Blue channel
                        pvPut(pv_PACMAN_PNG_DATA);
                    } else {
                        printf("Error: PNG index out of bounds: %d\n", png_index);
                    }
                }
                
                if (second_index < 0 || (pv_PACMAN_PLAY_FIELD[second_index] == 1 && pv_PACMAN_PLAY_FIELD[third_index] == 1) || pv_PACMAN_PACMAN_ABORT == 1) {
                    // Stop walking if blocked
                    if (pv_PACMAN_PACMAN_STATE == 0) {
                        pvSet(pv_PACMAN_PACMAN_STATE, 1); // Change state to "blocked"
                        printf("right blocked\n");
                        printf("right current_index: %d second_index: %d third_index: %d x: %d y: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
                        printf("right current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
                    }
                } else {
                    if (pv_PACMAN_PLAY_FIELD[second_index] == 2) {
                        pvSet(pv_PACMAN_PACMAN_STATE, 2); // Teleport Pacman to the other side
                    }
                    if (pv_PACMAN_PACMAN_STATE == 1 && pv_PACMAN_PACMAN_ABORT == 0) {
                        pvSet(pv_PACMAN_PACMAN_STATE, 0); // Change state to "walking"
                    }
                }
            }
            // left 
            if(pv_PACMAN_USER_DIRECTION == 1){
                current_index = get_array_index_from_xy(pv_PACMAN_USER_X + offset, pv_PACMAN_USER_Y, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
                second_index = current_index - 1; // Check previous field to the left
                third_index = second_index + pv_PACMAN_ARRAY_X_SIZE; // Check field below the previous field to the left
                if (pv_PACMAN_PLAY_FIELD[third_index] == 1 && pv_PACMAN_PLAY_FIELD[second_index] == 0) {
                    // correct position - y 1 using index to get y
                    pvSet(pv_PACMAN_USER_Y, get_y_from_index(current_index - pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR) + offset);
                    pvSet(pv_PACMAN_USER_X, get_x_from_index(current_index, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR));
                    printf("corrected position left - y 1\n");
                    printf("left current_index: %d second_index: %d third_index: %d x: %d y: %d offset: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y, offset);
                    printf("left current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
                    png_index = get_png_index_from_xy(pv_PACMAN_USER_X, pv_PACMAN_USER_Y, pv_PACMAN_FIELD_RESOLUTION, pv_PACMAN_PNG_WIDTH, pv_PACMAN_PNG_HEIGHT);
                    if (png_index >= 0 && png_index < pv_PACMAN_DATA_SIZE) {
                        // Set the color of red for debugging purposes
                        pv_PACMAN_PNG_DATA[png_index] = 255; // Red channel
                        pv_PACMAN_PNG_DATA[png_index + 1] = 0; // Green channel
                        pv_PACMAN_PNG_DATA[png_index + 2] = 0; // Blue channel
                        pvPut(pv_PACMAN_PNG_DATA);
                    } else {
                        printf("Error: PNG index out of bounds: %d\n", png_index);
                    }
                }
                if (pv_PACMAN_PLAY_FIELD[third_index] == 0 && pv_PACMAN_PLAY_FIELD[second_index] == 1) {
                    // correct position + y 1 using index to get y
                    pvSet(pv_PACMAN_USER_Y, get_y_from_index(current_index + pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR) - half_offset);
                    pvSet(pv_PACMAN_USER_X, get_x_from_index(current_index, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR));
                    printf("corrected position left y + 1\n");
                    printf("left current_index: %d second_index: %d third_index: %d x: %d y: %d offset: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y, offset);
                    printf("left current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
                    png_index = get_png_index_from_xy(pv_PACMAN_USER_X, pv_PACMAN_USER_Y, pv_PACMAN_FIELD_RESOLUTION, pv_PACMAN_PNG_WIDTH, pv_PACMAN_PNG_HEIGHT);
                    if (png_index >= 0 && png_index < pv_PACMAN_DATA_SIZE) {
                        // Set the color of red for debugging purposes
                        pv_PACMAN_PNG_DATA[png_index] = 255; // Red channel
                        pv_PACMAN_PNG_DATA[png_index + 1] = 0; // Green channel
                        pv_PACMAN_PNG_DATA[png_index + 2] = 0; // Blue channel
                        pvPut(pv_PACMAN_PNG_DATA);
                    } else {
                        printf("Error: PNG index out of bounds: %d\n", png_index);
                    }
                }
                
                if (second_index < 0 || pv_PACMAN_PLAY_FIELD[second_index] == 1 || pv_PACMAN_PACMAN_ABORT == 1) {
                    // Stop walking if blocked
                    if (pv_PACMAN_PACMAN_STATE == 0) {
                        pvSet(pv_PACMAN_PACMAN_STATE, 1); // Change state to "blocked"
                        printf("left blocked\n");
                        printf("left current_index: %d second_index: %d third_index: %d x: %d y: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
                        printf("left current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
                    }
                } else {
                    if (pv_PACMAN_PLAY_FIELD[second_index] == 2) {
                        pvSet(pv_PACMAN_PACMAN_STATE, 2); // Teleport Pacman to the other side
                    }
                    if (pv_PACMAN_PACMAN_STATE == 1 && pv_PACMAN_PACMAN_ABORT == 0) {
                        pvSet(pv_PACMAN_PACMAN_STATE, 0); // Change state to "walking"
                    }
                }            
            }
            // up
            if(pv_PACMAN_USER_DIRECTION == 2){
                current_index = get_array_index_from_xy(pv_PACMAN_USER_X, pv_PACMAN_USER_Y + offset, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
                second_index = current_index - pv_PACMAN_ARRAY_X_SIZE; // Check field above
                third_index = second_index + 1; // Check field to the right of the above field
                if (pv_PACMAN_PLAY_FIELD[third_index] == 1 && pv_PACMAN_PLAY_FIELD[second_index] == 0) {
                    // correct position - x 1 using index to get x
                    pvSet(pv_PACMAN_USER_X, get_x_from_index(current_index - 1, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR) + offset);
                    pvSet(pv_PACMAN_USER_Y, get_y_from_index(current_index, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR) + offset);
                    printf("corrected position up - x 1\n");
                    printf("up current_index: %d second_index: %d third_index: %d x: %d y: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
                    printf("up current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
                    png_index = get_png_index_from_xy(pv_PACMAN_USER_X, pv_PACMAN_USER_Y, pv_PACMAN_FIELD_RESOLUTION, pv_PACMAN_PNG_WIDTH, pv_PACMAN_PNG_HEIGHT);
                    if (png_index >= 0 && png_index < pv_PACMAN_DATA_SIZE) {
                        // Set the color of red for debugging purposes
                        pv_PACMAN_PNG_DATA[png_index] = 255; // Red channel
                        pv_PACMAN_PNG_DATA[png_index + 1] = 0; // Green channel
                        pv_PACMAN_PNG_DATA[png_index + 2] = 0; // Blue channel
                        pvPut(pv_PACMAN_PNG_DATA);
                    } else {
                        printf("Error: PNG index out of bounds: %d\n", png_index);
                    }
                }
                if (pv_PACMAN_PLAY_FIELD[third_index] == 0 && pv_PACMAN_PLAY_FIELD[second_index] == 1) {
                    // correct position + x 1 using index to get x
                    pvSet(pv_PACMAN_USER_X, get_x_from_index(current_index + 1, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR) + offset);
                    pvSet(pv_PACMAN_USER_Y, get_y_from_index(current_index, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR));
                    printf("corrected position up x + 1\n");
                    printf("up current_index: %d second_index: %d third_index: %d x: %d y: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
                    printf("up current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
                    png_index = get_png_index_from_xy(pv_PACMAN_USER_X, pv_PACMAN_USER_Y, pv_PACMAN_FIELD_RESOLUTION, pv_PACMAN_PNG_WIDTH, pv_PACMAN_PNG_HEIGHT);
                    if (png_index >= 0 && png_index < pv_PACMAN_DATA_SIZE) {
                        // Set the color of red for debugging purposes
                        pv_PACMAN_PNG_DATA[png_index] = 255; // Red channel
                        pv_PACMAN_PNG_DATA[png_index + 1] = 0; // Green channel
                        pv_PACMAN_PNG_DATA[png_index + 2] = 0; // Blue channel
                        pvPut(pv_PACMAN_PNG_DATA);
                    } else {
                        printf("Error: PNG index out of bounds: %d\n", png_index);
                    }
                }
                
                if (second_index < 0 || pv_PACMAN_PLAY_FIELD[second_index] == 1 || pv_PACMAN_PACMAN_ABORT == 1) {
                    // Stop walking if blocked
                    if (pv_PACMAN_PACMAN_STATE == 0) {
                        pvSet(pv_PACMAN_PACMAN_STATE, 1); // Change state to "blocked"
                        printf("up blocked\n");
                        printf("up current_index: %d second_index: %d third_index: %d x: %d y: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
                        printf("up current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
                    }
                } else {
                    if (pv_PACMAN_PLAY_FIELD[second_index] == 2) {
                        pvSet(pv_PACMAN_PACMAN_STATE, 2); // Teleport Pacman to the other side
                    }
                    if (pv_PACMAN_PACMAN_STATE == 1 && pv_PACMAN_PACMAN_ABORT == 0) {
                        pvSet(pv_PACMAN_PACMAN_STATE, 0); // Change state to "walking"
                    }
                }
            }
            // down
            if(pv_PACMAN_USER_DIRECTION == 3){
                current_index = get_array_index_from_xy(pv_PACMAN_USER_X, pv_PACMAN_USER_Y + offset, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
                second_index = current_index + pv_PACMAN_ARRAY_X_SIZE; // Check field below
                third_index = second_index + 1; // Check field to the right of the below field
                if (pv_PACMAN_PLAY_FIELD[third_index] == 1 && pv_PACMAN_PLAY_FIELD[second_index] == 0) {
                    // correct position - x 1
                    pvSet(pv_PACMAN_USER_X, get_x_from_index(third_index, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR) + offset);
                    pvSet(pv_PACMAN_USER_Y, get_y_from_index(current_index, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR));
                    printf("corrected position down - x 1\n");

                    printf("down current_index: %d second_index: %d third_index: %d x: %d y: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
                    printf("down current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
                    png_index = get_png_index_from_xy(pv_PACMAN_USER_X, pv_PACMAN_USER_Y, pv_PACMAN_FIELD_RESOLUTION, pv_PACMAN_PNG_WIDTH, pv_PACMAN_PNG_HEIGHT);
                    if (png_index >= 0 && png_index < pv_PACMAN_DATA_SIZE) {
                        // Set the color of red for debugging purposes
                        pv_PACMAN_PNG_DATA[png_index] = 255; // Red channel
                        pv_PACMAN_PNG_DATA[png_index + 1] = 0; // Green channel
                        pv_PACMAN_PNG_DATA[png_index + 2] = 0; // Blue channel
                        pvPut(pv_PACMAN_PNG_DATA);
                    } else {
                        printf("Error: PNG index out of bounds: %d\n", png_index);
                    }
                }
                if (pv_PACMAN_PLAY_FIELD[third_index] == 0 && pv_PACMAN_PLAY_FIELD[second_index] == 1) {
                    // correct position + x 1
                    pvSet(pv_PACMAN_USER_X, get_x_from_index(current_index + 1, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR));
                    pvSet(pv_PACMAN_USER_Y, get_y_from_index(current_index, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR));
                    printf("corrected position down x + 1\n");

                    printf("down current_index: %d second_index: %d third_index: %d x: %d y: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
                    printf("down current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
                    png_index = get_png_index_from_xy(pv_PACMAN_USER_X, pv_PACMAN_USER_Y, pv_PACMAN_FIELD_RESOLUTION, pv_PACMAN_PNG_WIDTH, pv_PACMAN_PNG_HEIGHT);
                    if (png_index >= 0 && png_index < pv_PACMAN_DATA_SIZE) {
                        // Set the color of red for debugging purposes
                        pv_PACMAN_PNG_DATA[png_index] = 255; // Red channel
                        pv_PACMAN_PNG_DATA[png_index + 1] = 0; // Green channel
                        pv_PACMAN_PNG_DATA[png_index + 2] = 0; // Blue channel
                        pvPut(pv_PACMAN_PNG_DATA);
                    } else {
                        printf("Error: PNG index out of bounds: %d\n", png_index);
                    }
                }
                
                if (second_index < 0 || pv_PACMAN_PLAY_FIELD[second_index] == 1 || pv_PACMAN_PACMAN_ABORT == 1) {
                    // Stop walking if blocked
                    if (pv_PACMAN_PACMAN_STATE == 0) {
                        pvSet(pv_PACMAN_PACMAN_STATE, 1); // Change state to "blocked"
                        printf("down blocked\n");
                        printf("down current_index: %d second_index: %d third_index: %d x: %d y: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
                        printf("down current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
                    }
                } else {
                    if (pv_PACMAN_PLAY_FIELD[second_index] == 2) {
                        pvSet(pv_PACMAN_PACMAN_STATE, 2); // Teleport Pacman to the other side
                    }
                    if (pv_PACMAN_PACMAN_STATE == 1 && pv_PACMAN_PACMAN_ABORT == 0) {
                        pvSet(pv_PACMAN_PACMAN_STATE, 0); // Change state to "walking"
                    }
                }
            }
        }

        when (pv_PACMAN_TRY_DIRECTION != -1 && pv_PACMAN_TRY_DIRECTION != pv_PACMAN_USER_DIRECTION) {
            // If try direction is not right, change to TRY_MOVE
        } state TRY_MOVE
        when (pv_PACMAN_PACMAN_STATE == 2) {

        } state TELEPORT
        when (pv_PACMAN_PACMAN_STATE != 0) {
            // If Pacman is blocked, do not move
        } state MOVE_STOP
        when () {

        } state DELAY
        
    }

    state TELEPORT {
        entry {
            int pos;
            pvSetStr(pv_SS_PACMAN, "TELEPORT");
            if (pv_PACMAN_USER_DIRECTION == 0) {
                // Teleport right
                pvSet(pv_PACMAN_USER_X, 0); // Reset X position to the left side
            } else if (pv_PACMAN_USER_DIRECTION == 1) {
                // Teleport left
                pos = get_x_from_index(pv_PACMAN_ARRAY_X_SIZE - 1, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
                pvSet(pv_PACMAN_USER_X, pos); // Reset X position to the right side
            } else if (pv_PACMAN_USER_DIRECTION == 2) {
                // Teleport up
                pvSet(pv_PACMAN_USER_Y, 0); // Reset Y position to the top side
            } else if (pv_PACMAN_USER_DIRECTION == 3) {
                // Teleport down
                pos = get_y_from_index(pv_PACMAN_FIELD_SIZE - 1, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
                pvSet(pv_PACMAN_USER_Y, pos); // Reset Y position to the bottom side
            }
        }
        when () {
            pvSet(pv_PACMAN_PACMAN_STATE, 0); // Change state to "walking"
        } state MOVE_CHECK
    }

    state DELAY {
        entry { pvSetStr(pv_SS_PACMAN, "DELAY"); }
        when (delay(0.02)) {
            // Delay for 20ms
        } state MOVE
    }

    state DRAW_PACMAN {
        entry { pvSetStr(pv_SS_PACMAN, "DRAW_PACMAN"); }
        when () {
            // Draw Pacman at the current position in the png data array
            int x = pv_PACMAN_USER_X;
            int y = pv_PACMAN_USER_Y;
            int width = pv_PACMAN_PNG_WIDTH;
            int height = pv_PACMAN_PNG_HEIGHT;
            int data_size = pv_PACMAN_DATA_SIZE;

            // Calculate the index in the 1D array
            int index = get_png_index_from_xy(x, y, pv_PACMAN_FIELD_RESOLUTION, width, height);
            if (index < 0 || index + 2 >= data_size) {
                printf("Error: Index out of bounds for drawing Pacman: %d\n", index);
            } else {
                // Set the color for Pacman (yellow)
                pv_PACMAN_PNG_DATA[index] = 255;     // Red
                pv_PACMAN_PNG_DATA[index + 1] = 255; // Green
                pv_PACMAN_PNG_DATA[index + 2] = 0;   // Blue

                if (previous_index >= 0 && previous_index + 2 < data_size) {
                    // Clear the previous position (set it to green)
                    pv_PACMAN_PNG_DATA[previous_index] = 0;   // Red
                    pv_PACMAN_PNG_DATA[previous_index + 1] = 255; // Green
                    pv_PACMAN_PNG_DATA[previous_index + 2] = 0;   // Blue
                }

                // Store the current index as the previous index for the next draw
                previous_index = index;

                // Update the PV with the modified image data
                pvPut(pv_PACMAN_PNG_DATA);
            }
        } state MOVE_CHECK
    }

    state MOVE {
        entry {
            pvSetStr(pv_SS_PACMAN, "MOVE");
        }
        when (pv_PACMAN_USER_DIRECTION == 0) {
            // Move right
            pvSetStr(pv_SS_PACMAN, "MOVE_RIGHT");
            pvSet(pv_PACMAN_USER_X, pv_PACMAN_USER_X + 1);
        } state DRAW_PACMAN
        when (pv_PACMAN_USER_DIRECTION == 1) {
            // Move left
            pvSetStr(pv_SS_PACMAN, "MOVE_LEFT");
            pvSet(pv_PACMAN_USER_X, pv_PACMAN_USER_X - 1);
        } state DRAW_PACMAN
        when (pv_PACMAN_USER_DIRECTION == 2) {
            // Move up
            pvSetStr(pv_SS_PACMAN, "MOVE_UP");
            pvSet(pv_PACMAN_USER_Y, pv_PACMAN_USER_Y - 1);
        } state DRAW_PACMAN
        when (pv_PACMAN_USER_DIRECTION == 3) {
            // Move down
            pvSetStr(pv_SS_PACMAN, "MOVE_DOWN");
            pvSet(pv_PACMAN_USER_Y, pv_PACMAN_USER_Y + 1);
        } state DRAW_PACMAN
        when (pv_PACMAN_USER_DIRECTION == -1) {
            // If no direction is set, stay in this state
        } state DRAW_PACMAN
        when () {
            // If no conditions are met, do nothing
        } state DRAW_PACMAN
    }

    state MOVE_STOP {
        entry { 
            pvSetStr(pv_SS_PACMAN, "MOVE_STOP"); 
            if (pv_PACMAN_PACMAN_STATE != 1) {
                pvSet(pv_PACMAN_PACMAN_STATE, 1); // Change state to "blocked"
            }
            pvSet(pv_PACMAN_STOP_DIRECTION, pv_PACMAN_USER_DIRECTION);
            pvSet(pv_PACMAN_TRY_DIRECTION, -1); // Reset try direction
        }
        when (pv_PACMAN_STOP_DIRECTION == pv_PACMAN_USER_DIRECTION && pv_PACMAN_STOP_DIRECTION == -1) {
            // If already stopped, stay in this state
        } state MOVE_STOP
        when (pv_PACMAN_USER_DIRECTION != pv_PACMAN_STOP_DIRECTION) {
            // If direction changes, go to MOVE_ANY
            pvSet(pv_PACMAN_STOP_DIRECTION, -1); // Reset stop direction
        } state MOVE_CHECK
        when (pv_PACMAN_TRY_DIRECTION != -1) {
            // If try direction is set, go to TRY_MOVE
        } state TRY_MOVE
    }

    state TRY_MOVE {
        entry {
            int current_index;
            int second_index;
            int third_index;
            int offset = (int)(pv_PACMAN_PACMAN_SIZE / 2);
            int half_offset = (int)(pv_PACMAN_PACMAN_SIZE / 4);
            int png_index;

            pvSetStr(pv_SS_PACMAN, "TRY_MOVE");            

            if (pv_PACMAN_TRY_DIRECTION == 0) {
                // Try move right
                current_index = get_array_index_from_xy(pv_PACMAN_USER_X + offset, pv_PACMAN_USER_Y, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
                second_index = current_index + 1;
                third_index = second_index + pv_PACMAN_ARRAY_X_SIZE; // Check field below the next field to the right
                // check if one of second_index or third_index is free
                if ((pv_PACMAN_PLAY_FIELD[second_index] == 0 || pv_PACMAN_PLAY_FIELD[third_index] == 0) && pv_PACMAN_PLAY_FIELD[current_index] != 1) {
                    // check one field further right is free
                    second_index = second_index + 1; // Check field two to the right
                    third_index = second_index + pv_PACMAN_ARRAY_X_SIZE; // Check field below
                    if (pv_PACMAN_PLAY_FIELD[second_index] == 0 || pv_PACMAN_PLAY_FIELD[third_index] == 0) {
                        // If at least one is free, set try direction to right
                        pvSet(pv_PACMAN_USER_DIRECTION, 0);
                    } else {
                        // If both are blocked, set try direction to -1
                        pvSet(pv_PACMAN_TRY_DIRECTION, -1);
                    }
                } else {
                    // If both are blocked, set try direction to -1
                    pvSet(pv_PACMAN_TRY_DIRECTION, -1);
                }

                printf("try right current_index: %d second_index: %d third_index: %d x: %d y: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
                printf("try right current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);                  
            }

            if (pv_PACMAN_TRY_DIRECTION == 1){
                // Try move left
                current_index = get_array_index_from_xy(pv_PACMAN_USER_X - offset, pv_PACMAN_USER_Y, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
                second_index = current_index - 1; // Check previous field to the left
                third_index = second_index + pv_PACMAN_ARRAY_X_SIZE; // Check field below the previous field to the left
                // check if one of second_index or third_index is free
                if ((pv_PACMAN_PLAY_FIELD[second_index] == 0 || pv_PACMAN_PLAY_FIELD[third_index] == 0) && pv_PACMAN_PLAY_FIELD[current_index] != 1) {
                    // If at least one is free, set try direction to left
                    pvSet(pv_PACMAN_USER_DIRECTION, 1);
                } else {
                    // If both are blocked, set try direction to -1
                    pvSet(pv_PACMAN_TRY_DIRECTION, -1);
                }

                printf("try left current_index: %d second_index: %d third_index: %d x: %d y: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);  
                printf("try left current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
            }

            if (pv_PACMAN_TRY_DIRECTION == 2){
                // Try move up
                current_index = get_array_index_from_xy(pv_PACMAN_USER_X, pv_PACMAN_USER_Y - offset, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
                second_index = current_index - pv_PACMAN_ARRAY_X_SIZE; // Check field above
                third_index = second_index + 1; // Check field to the right of the above field
                // check if one of second_index or third_index is free
                if ((pv_PACMAN_PLAY_FIELD[second_index] == 0 || pv_PACMAN_PLAY_FIELD[third_index] == 0) && pv_PACMAN_PLAY_FIELD[current_index] != 1) {
                    // If at least one is free, set try direction to up
                    pvSet(pv_PACMAN_USER_DIRECTION, 2);
                } else {
                    // If both are blocked, set try direction to -1
                    pvSet(pv_PACMAN_TRY_DIRECTION, -1);
                }

                printf("try up current_index: %d second_index: %d third_index: %d x: %d y: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
                printf("try up current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
            }

            if (pv_PACMAN_TRY_DIRECTION == 3){
                // Try move down
                current_index = get_array_index_from_xy(pv_PACMAN_USER_X, pv_PACMAN_USER_Y + offset, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
                second_index = current_index + pv_PACMAN_ARRAY_X_SIZE; // Check field below
                third_index = second_index + 1; // Check field to the right of the below field
                // check if one of second_index or third_index is free
                if ((pv_PACMAN_PLAY_FIELD[second_index] == 0 || pv_PACMAN_PLAY_FIELD[third_index] == 0) && pv_PACMAN_PLAY_FIELD[current_index] != 1) {
                    // check if one field further down is free
                    second_index = second_index + pv_PACMAN_ARRAY_X_SIZE; // Check field two below
                    third_index = second_index + 1; // Check field to the right of the two
                    if (pv_PACMAN_PLAY_FIELD[second_index] == 0 || pv_PACMAN_PLAY_FIELD[third_index] == 0) {
                        // If at least one is free, set try direction to down
                        pvSet(pv_PACMAN_USER_DIRECTION, 3);
                    } else {
                        // If both are blocked, set try direction to -1
                        pvSet(pv_PACMAN_TRY_DIRECTION, -1);
                    }
                } else {
                    // If both are blocked, set try direction to -1
                    pvSet(pv_PACMAN_TRY_DIRECTION, -1);
                }

                printf("try down current_index: %d second_index: %d third_index: %d x: %d y: %d\n", current_index, second_index, third_index, pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
                printf("try down current_index_state: %d second_index_state: %d third_index_state: %d\n", pv_PACMAN_PLAY_FIELD[current_index], pv_PACMAN_PLAY_FIELD[second_index], pv_PACMAN_PLAY_FIELD[third_index]);
            }

        }

        when () {
            if (pv_PACMAN_TRY_DIRECTION != -1 && pv_PACMAN_TRY_DIRECTION == pv_PACMAN_USER_DIRECTION) {
                int current_index = get_array_index_from_xy(pv_PACMAN_USER_X, pv_PACMAN_USER_Y, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR);
                // set x and y using the get_x_from_index and get_y_from_index functions
                pvSet(pv_PACMAN_USER_X, get_x_from_index(current_index, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR));
                pvSet(pv_PACMAN_USER_Y, get_y_from_index(current_index, pv_PACMAN_FIELD_SIZE, pv_PACMAN_ARRAY_X_SIZE, pv_PACMAN_ARRAY_X_FACTOR));
                printf("new aligned position right x: %d y: %d\n", pv_PACMAN_USER_X, pv_PACMAN_USER_Y);
            }
        } state MOVE_CHECK
    }
}