program ghosts_pacman
#include "seqPVmacros.h"

%%#include "math.h"
%%#include "stdlib.h"
%%#include "stdio.h"
%%#include "png.h"
%%#include "errlog.h"
%%#include "time.h"
%%#define PRINTF errlogPrintf

/* options */
option  +r;

/* variables  ghosts */
PV( string, pv_SS_GHOSTS, "{NAME}:SS_GHOSTS", PV_NONE );
PV( int, pv_GHOSTS_NPC_DIR, "{NAME}:GHOSTS_NPC_DIR", PV_MON );  
PV( int, pv_GHOSTS_NPC_X, "{NAME}:GHOSTS_NPC_X", PV_MON );  
PV( int, pv_GHOSTS_NPC_Y, "{NAME}:GHOSTS_NPC_Y", PV_MON );  
PV( int, pv_GHOSTS_NPC_SIZE, "{NAME}:GHOSTS_NPC_SIZE", PV_MON );  
PV( int, pv_GHOSTS_NPC_MOVDIST, "{NAME}:GHOSTS_NPC_MOVDIST", PV_MON );
PV( int, pv_GHOSTS_NPC_IDX, "{NAME}:GHOSTS_NPC_IDX", PV_MON );
PV( int, pv_GHOSTS_NPC_IDXVAL, "{NAME}:GHOSTS_NPC_IDXVAL", PV_MON );

PV( int, pv_GHOSTS_NPC_X_CORRECT, "{NAME}:GHOSTS_NPC_X_CORRECT", PV_MON );
PV( int, pv_GHOSTS_NPC_Y_CORRECT, "{NAME}:GHOSTS_NPC_Y_CORRECT", PV_MON );
PV( int, pv_GHOSTS_NPC_INTERSECT, "{NAME}:GHOSTS_NPC_INTERSECT", PV_MON );

/* variables ghost run */
PV( string, pv_SS_GHOSTS_RUN, "{NAME}:SS_GHOSTS_RUN", PV_NONE );
PV( int, pv_GHOSTS_NPC_RUN, "{NAME}:GHOSTS_NPC_RUN", PV_MON );
PV( int, pv_GHOSTS_NPC_RUNFRAME1, "{NAME}:GHOSTS_NPC_RUNFRAME1", PV_MON );
PV( int, pv_GHOSTS_NPC_RUNFRAME2, "{NAME}:GHOSTS_NPC_RUNFRAME2", PV_MON );  

/* variables from pcman */
PV( int, pv_PACMAN_ARRAY_ROW_LENGTH	, "{NAME}:PACMAN_ARRAY_X_SIZE"	, PV_MON );
PV( int, pv_PACMAN_ARRAY_CELL_WIDTH	, "{NAME}:PACMAN_ARRAY_X_FACTOR", PV_MON );
PV( int, pv_PACMAN_USER_X, "{NAME}:PACMAN_USER_X", PV_MON );
PV( int, pv_PACMAN_USER_Y, "{NAME}:PACMAN_USER_Y", PV_MON );
PVA( short, pv_PACMAN_PLAY_FIELD, 1024, "{NAME}:PACMAN_PLAY_FIELD", PV_MON);
PV( int, pv_PACMAN_FIELD_SIZE, "{NAME}:PACMAN_FIELD_SIZE"	, PV_MON );
PV( int, pv_PACMAN_FIELD_RESOLUTION, "{NAME}:PACMAN_FIELD_RESOLUTION", PV_MON );

/* variables for png */
PV( int, pv_GHOSTS_PNG_WIDTH, "{NAME}:GHOSTS_PNG_WIDTH"		, PV_MON );
PV( int, pv_GHOSTS_PNG_HEIGHT, "{NAME}:GHOSTS_PNG_HEIGHT"	, PV_MON );
PV( int, pv_GHOSTS_DATA_SIZE, "{NAME}:GHOSTS_PNG_DATA_SIZE"	, PV_MON );
PVA( unsigned char, pv_GHOSTS_PNG_DATA, 200000, "{NAME}:GHOSTS_PNG_DATA" , PV_NONE );

/* Functions */
%{
    int GH_CONST_ARRAY_ROW_LENGTH = 32;
    int GH_CONST_ARRAY_CELL_WIDTH = 25;
    int GH_CONST_PACMAN_FIELD_SIZE = 32*32;

        int gh_get_array_index_from_xy (int x, int y) {
            int index = 0;
            int column = (int) (x / GH_CONST_ARRAY_CELL_WIDTH);
            int row = (int) (y / GH_CONST_ARRAY_CELL_WIDTH);
            // game is quadratic --> row and columns are of equal length
            if (column < 0 || column >= GH_CONST_ARRAY_ROW_LENGTH || row < 0 || row >= GH_CONST_ARRAY_ROW_LENGTH) {
                return -1; // out of bounds
            }
            index = row * GH_CONST_ARRAY_ROW_LENGTH + column;
            return index;
	    }

      	int gh_get_x_from_index (int index) {
            if (index < 0 || index >= GH_CONST_PACMAN_FIELD_SIZE) {
                return -1; // out of bounds
            }
            return (index % GH_CONST_ARRAY_ROW_LENGTH) * GH_CONST_ARRAY_CELL_WIDTH;
        }

    	int gh_get_y_from_index (int index) {
            if (index < 0 || index >= GH_CONST_PACMAN_FIELD_SIZE) {
                return -1; // out of bounds
            }
            return (index / GH_CONST_ARRAY_ROW_LENGTH) * GH_CONST_ARRAY_CELL_WIDTH;
        }

        char* gh_toString(int value) {
            char buffer[20];
            snprintf(buffer, sizeof(buffer), "%d", value);
            return buffer;
        }

        int gh_randomNr(){
            int nr;
            srand(time(NULL));
            nr = rand();
            return nr;
        }

        int gh_get_distance_from_pacman(int pacx, int pacy, int ghox, int ghoy){
            int diff_x = abs(ghox - pacx);
            int diff_y = abs(ghoy - pacy);
            int difference = sqrt(diff_x*diff_x + diff_y*diff_y);

            return difference;
        }

        void gh_get_shortest_direction_to_pacman(int index, int pacx, int pacy, int* first, int* second, int* third, int* fourth) {
            int distance[4];
            int dir[4] = {0, 1, 2, 3}; // 0=right, 1=left, 2=up, 3=down
            int idx[4] = {
                index + 1, // right
                index - 1, // left
                index - GH_CONST_ARRAY_ROW_LENGTH, // up
                index + GH_CONST_ARRAY_ROW_LENGTH  // down
            };

            for(int i = 0; i < 4; i++) {
                distance[i] = gh_get_distance_from_pacman(pacx, pacy, gh_get_x_from_index(idx[i]), gh_get_y_from_index(idx[i]));
            }

            // Sort directions by distance (ascending)
            for(int i = 0; i < 3; i++) {
                for(int j = i + 1; j < 4; j++) {
                    if(distance[dir[j]] < distance[dir[i]]) {
                        int tmp = dir[i];
                        dir[i] = dir[j];
                        dir[j] = tmp;
                    }
                }
            }

            // Save sorted directions to pointers
            if (first)  *first  = dir[0];
            if (second) *second = dir[1];
            if (third)  *third  = dir[2];
            if (fourth) *fourth = dir[3];
        }

        int gh_get_surrounding_index_from_direction(int index, int direction){
            switch(direction){
                case 0: // right
                    return index + 1;
                case 1: // left
                    return index - 1;
                case 2: // up
                    return index - GH_CONST_ARRAY_ROW_LENGTH;
                case 3: // down
                    return index + GH_CONST_ARRAY_ROW_LENGTH;
                default:
                    return -1; // invalid direction
            }
        }

        void gh_png_error_function(png_structp png_ptr, png_const_charp msg) {
            fprintf(stderr, "libpng error: %s\n", msg);
            if (png_ptr) {
                png_destroy_read_struct(&png_ptr, NULL, NULL);
            }
            exit(EXIT_FAILURE);
        }

        // Function to handle libpng warnings (optional)
        void gh_png_warning_function(png_structp png_ptr, png_const_charp msg) {
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
        unsigned char* gh_read_png_to_1d_rgb(const char* filename, int* width, int* height) {
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
                                            gh_png_error_function, gh_png_warning_function);
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

        void gh_write_rgb_into_pointer(unsigned char* original_data, unsigned char* target_data, int width, int height) {
            if (!original_data || !target_data) {
                fprintf(stderr, "Error: Null pointer passed to gh_write_rgb_into_pointer.\n");
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
        int gh_get_png_index_from_xy(int x, int y, int PACMAN_FIELD_RESOLUTION, int png_width, int png_height) {
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
}%

// movement of ghosts
ss ghosts_pacman{
    state INIT{
        entry{
            int width, height;
            unsigned char* image_data = gh_read_png_to_1d_rgb("../pacman_ui/pacman_background.png", &width, &height);
            
            // GHOSTS
            pvSetStr(pv_SS_GHOSTS, "INIT");
            pvSet(pv_GHOSTS_NPC_SIZE, 40);
            pvSet(pv_GHOSTS_NPC_IDXVAL, 0);
            pvSet(pv_GHOSTS_NPC_MOVDIST, 5);
            pvSet(pv_GHOSTS_NPC_X, (int)pv_GHOSTS_NPC_SIZE*1.3);
            pvSet(pv_GHOSTS_NPC_Y, (int)pv_GHOSTS_NPC_SIZE*1.3);
            pvSet(pv_GHOSTS_NPC_IDX, gh_get_array_index_from_xy(pv_GHOSTS_NPC_X + (pv_GHOSTS_NPC_SIZE/4), pv_GHOSTS_NPC_Y + (pv_GHOSTS_NPC_SIZE/4)));
            
            // PNG
            if (image_data) {
                // Store the image data in the pv_PACMAN_PNG_DATA array
                gh_write_rgb_into_pointer(image_data, pv_GHOSTS_PNG_DATA, width, height);
                free(image_data); // Free the image data after copying it
                pvPut(pv_GHOSTS_PNG_DATA);
                // Set the width, height, and data size in the PVs
                pvSet(pv_GHOSTS_PNG_WIDTH, width);
                pvSet(pv_GHOSTS_PNG_HEIGHT, height);
                pvSet(pv_GHOSTS_DATA_SIZE, width * height * 3);
            } else {
                // printf("Failed to load PNG image.\n");
            }
        }
        when(){
        } state CHECK_MOVE
    }
    state CHECK_MOVE{
        entry{
            int idx; 
            pvSetStr( pv_SS_GHOSTS, "CHECK_MOVE" );
            idx = gh_get_array_index_from_xy(pv_GHOSTS_NPC_X + (pv_GHOSTS_NPC_SIZE/4), pv_GHOSTS_NPC_Y + (pv_GHOSTS_NPC_SIZE/4));
            pvSet(pv_GHOSTS_NPC_IDX, idx);
            pvSet(pv_GHOSTS_NPC_IDXVAL, pv_PACMAN_PLAY_FIELD[(int)pv_GHOSTS_NPC_IDX+1]);
        }
        when(){
        } state CHECK_INTERSECTION
    }

    state CHECK_INTERSECTION{
        entry{
            int idx = pv_GHOSTS_NPC_IDX;
            
            int idxbelow = idx + pv_PACMAN_ARRAY_ROW_LENGTH;
            int idxbelow_2 = idx + (pv_PACMAN_ARRAY_ROW_LENGTH * 2);
            
            int idxleft = idx - 1;
            int idxleft_2 = idx - 2;
            
            int idxright = idx + 1;
            int idxright_2 = idx + 2;
            
            int idxabove = idx - pv_PACMAN_ARRAY_ROW_LENGTH;
            int idxabove_2 = idx - (pv_PACMAN_ARRAY_ROW_LENGTH * 2);

            int horizontal_intersection = 0;
            int vertical_intersection = 0;

            pvSetStr( pv_SS_GHOSTS, "CHECK_INTERSECTION" );
            
            if ((pv_PACMAN_PLAY_FIELD[idxbelow] == 0 && pv_PACMAN_PLAY_FIELD[idxbelow_2] == 0) ||
                (pv_PACMAN_PLAY_FIELD[idxabove] == 0 && pv_PACMAN_PLAY_FIELD[idxabove_2] == 0)){
                vertical_intersection = 1;
            }

            if((pv_PACMAN_PLAY_FIELD[idxleft] == 0 && pv_PACMAN_PLAY_FIELD[idxleft_2] == 0) ||
                (pv_PACMAN_PLAY_FIELD[idxright] == 0 && pv_PACMAN_PLAY_FIELD[idxright_2] == 0)) {
                horizontal_intersection = 1;
            }

            if(horizontal_intersection == 1 && vertical_intersection == 1){
                pvSet(pv_GHOSTS_NPC_INTERSECT, 1);
            }else{
                pvSet(pv_GHOSTS_NPC_INTERSECT, 0);
            }
        } when(pv_GHOSTS_NPC_INTERSECT == 1){
        } state CHECK_MOVEABLE_DIRECTIONS
        when(){} state CALCULATE_CORRECTION
    }

    state CALCULATE_CORRECTION{
        entry{
            pvSetStr( pv_SS_GHOSTS, "CALCULATE_CORRECTION" );
        }
        when(abs(pv_GHOSTS_NPC_X - pv_PACMAN_USER_X) < 30 && abs(pv_GHOSTS_NPC_Y - pv_PACMAN_USER_Y) < 30){
        }  state MOVE_RIGHT
        when(pv_GHOSTS_NPC_DIR % 4 == 0 || pv_GHOSTS_NPC_DIR % 4 == 1){
            int distance = gh_get_y_from_index(pv_GHOSTS_NPC_IDX+32);
            int png_index;
            png_index = gh_get_png_index_from_xy(pv_GHOSTS_NPC_X, distance, pv_PACMAN_FIELD_RESOLUTION, pv_GHOSTS_PNG_WIDTH, pv_GHOSTS_PNG_HEIGHT);
            if (png_index >= 0 && png_index < pv_GHOSTS_DATA_SIZE) {
                // Set the color of red for debugging purposes
                pv_GHOSTS_PNG_DATA[png_index] = 0; // Red channel
                pv_GHOSTS_PNG_DATA[png_index + 1] = 255; // Green channel
                pv_GHOSTS_PNG_DATA[png_index + 2] = 0; // Blue channel
                pvPut(pv_GHOSTS_PNG_DATA);
                } else {
                // printf("Error: PNG index out of bounds: %d\n", png_index);
            }
            /*
            int idx = pv_GHOSTS_NPC_IDX;
            int above = idx - pv_PACMAN_ARRAY_ROW_LENGTH;
            int below = idx + pv_PACMAN_ARRAY_ROW_LENGTH;

            if(pv_PACMAN_PLAY_FIELD[above] == 1 && pv_PACMAN_PLAY_FIELD[below] == 0){
                pvSet(pv_GHOSTS_NPC_Y_CORRECT, (distance - pv_GHOSTS_NPC_Y));
            }else if(pv_PACMAN_PLAY_FIELD[above] == 0 && pv_PACMAN_PLAY_FIELD[below] == 1){
                pvSet(pv_GHOSTS_NPC_Y_CORRECT, pv_GHOSTS_NPC_Y - distance);
            }

            */
        } state MOVE 
        when(pv_GHOSTS_NPC_DIR % 4 == 2 || pv_GHOSTS_NPC_DIR % 4 == 3){
            int distance = gh_get_x_from_index(pv_GHOSTS_NPC_IDX+1);
            int png_index;
            png_index = gh_get_png_index_from_xy(distance, pv_GHOSTS_NPC_Y, pv_PACMAN_FIELD_RESOLUTION, pv_GHOSTS_PNG_WIDTH, pv_GHOSTS_PNG_HEIGHT);
            if (png_index >= 0 && png_index < pv_GHOSTS_DATA_SIZE) {
                // Set the color of red for debugging purposes
                pv_GHOSTS_PNG_DATA[png_index] = 0; // Red channel
                pv_GHOSTS_PNG_DATA[png_index + 1] = 255; // Green channel
                pv_GHOSTS_PNG_DATA[png_index + 2] = 0; // Blue channel
                pvPut(pv_GHOSTS_PNG_DATA);
                } else {
                // printf("Error: PNG index out of bounds: %d\n", png_index);
            }
            /*
            int idx = pv_GHOSTS_NPC_IDX;
            int left = idx - 1;
            int right = idx + 1;

            if(pv_PACMAN_PLAY_FIELD[left] == 1 && pv_PACMAN_PLAY_FIELD[right] == 0){
                pvSet(pv_GHOSTS_NPC_X_CORRECT, ((distance + pv_GHOSTS_NPC_SIZE/2) - pv_GHOSTS_NPC_X));
            }else if(pv_PACMAN_PLAY_FIELD[left] == 0 && pv_PACMAN_PLAY_FIELD[right] == 1){
                pvSet(pv_GHOSTS_NPC_X_CORRECT, (pv_GHOSTS_NPC_X - (distance + pv_GHOSTS_NPC_SIZE/2)));
            }

            */
        } state MOVE
    }

    state MOVE{
        entry{
            int correction_distance = 1;
            int png_index;

            // Y - Correction
            if(pv_GHOSTS_NPC_Y_CORRECT > 0){
                pvSet(pv_GHOSTS_NPC_Y, (pv_GHOSTS_NPC_Y + correction_distance));
                pvSet(pv_GHOSTS_NPC_Y_CORRECT, (pv_GHOSTS_NPC_Y_CORRECT - 1));
            }else if(pv_GHOSTS_NPC_Y_CORRECT < 0){
                pvSet(pv_GHOSTS_NPC_Y, (pv_GHOSTS_NPC_Y - correction_distance));
                pvSet(pv_GHOSTS_NPC_Y_CORRECT, (pv_GHOSTS_NPC_Y_CORRECT + 1));
            }

            // X-Correction
            if(pv_GHOSTS_NPC_X_CORRECT > 0){
                pvSet(pv_GHOSTS_NPC_X, (pv_GHOSTS_NPC_X + correction_distance));
                pvSet(pv_GHOSTS_NPC_X_CORRECT, (pv_GHOSTS_NPC_X_CORRECT - 1));
            }else if(pv_GHOSTS_NPC_X_CORRECT < 0){
                pvSet(pv_GHOSTS_NPC_X, (pv_GHOSTS_NPC_X - correction_distance));
                pvSet(pv_GHOSTS_NPC_X_CORRECT, (pv_GHOSTS_NPC_X_CORRECT + 1));
            }            png_index = gh_get_png_index_from_xy(pv_GHOSTS_NPC_X, pv_GHOSTS_NPC_Y, pv_PACMAN_FIELD_RESOLUTION, pv_GHOSTS_PNG_WIDTH, pv_GHOSTS_PNG_HEIGHT);
            if (png_index >= 0 && png_index < pv_GHOSTS_DATA_SIZE) {
                // Set the color of red for debugging purposes
                pv_GHOSTS_PNG_DATA[png_index] = 255; // Red channel
                pv_GHOSTS_PNG_DATA[png_index + 1] = 0; // Green channel
                pv_GHOSTS_PNG_DATA[png_index + 2] = 0; // Blue channel
                pvPut(pv_GHOSTS_PNG_DATA);
                } else {
                // printf("Error: PNG index out of bounds: %d\n", png_index);
            }

        }
        when(pv_GHOSTS_NPC_IDX == -1){
        }state TELEPORT_CENTER
        when(pv_GHOSTS_NPC_DIR % 4 == 0 ){
        } state MOVE_RIGHT
        when(pv_GHOSTS_NPC_DIR % 4 == 1){
        } state MOVE_LEFT
        when(pv_GHOSTS_NPC_DIR % 4 == 2){
        } state MOVE_UP
        when(pv_GHOSTS_NPC_DIR % 4 == 3){
        } state MOVE_DOWN
        
    }

    
    state TELEPORT_CENTER{
        when(delay(0.1)){
            int respawn = 370;
            pvSetStr(pv_SS_GHOSTS, "TELEPORT_CENTER");
            pvSet(pv_GHOSTS_NPC_X, respawn);
            pvSet(pv_GHOSTS_NPC_Y, respawn);
        } state CHECK_MOVE
    }

    state CHECK_MOVEABLE_DIRECTIONS{
        entry{
            int rnd = gh_randomNr();
            int sorted_dir[4];
            int first, second, third, fourth;
            pvSetStr(pv_SS_GHOSTS, "CHECK_MOVEABLE_DIRECTIONS");
            gh_get_shortest_direction_to_pacman(pv_GHOSTS_NPC_IDX, pv_PACMAN_USER_X, pv_PACMAN_USER_Y, &first, &second, &third, &fourth);
       
            // Check if the ghost can move in the fastest direction of the pacman, otherwise check the others in descending order
            if(abs(pv_GHOSTS_NPC_X_CORRECT) == 0 && abs(pv_GHOSTS_NPC_Y_CORRECT) == 0){
                if(pv_PACMAN_PLAY_FIELD[gh_get_surrounding_index_from_direction(pv_GHOSTS_NPC_IDX, first)] != 1){
                    pvSet(pv_GHOSTS_NPC_DIR, first);
                } else if(pv_PACMAN_PLAY_FIELD[gh_get_surrounding_index_from_direction(pv_GHOSTS_NPC_IDX, second)] != 1){
                    pvSet(pv_GHOSTS_NPC_DIR, second);
                } else if(pv_PACMAN_PLAY_FIELD[gh_get_surrounding_index_from_direction(pv_GHOSTS_NPC_IDX, third)] != 1){
                    pvSet(pv_GHOSTS_NPC_DIR, third);
                } else if(pv_PACMAN_PLAY_FIELD[gh_get_surrounding_index_from_direction(pv_GHOSTS_NPC_IDX, fourth)] != 1){
                    pvSet(pv_GHOSTS_NPC_DIR, fourth);
                }
            }
        }
        when(pv_GHOSTS_NPC_INTERSECT == 1){
            pvSet(pv_GHOSTS_NPC_INTERSECT, 0)
        } state CALCULATE_CORRECTION 
        when(){
        } state CHECK_MOVE
    }

    state MOVE_RIGHT{
        when(pv_GHOSTS_NPC_IDX == -1){
        } state TELEPORT_CENTER
        when(pv_PACMAN_PLAY_FIELD[((int)pv_GHOSTS_NPC_IDX+1)] == 1){
        } state CHECK_MOVEABLE_DIRECTIONS
        when(delay(0.1)){
            pvSetStr( pv_SS_GHOSTS, "MOVE_RIGHT" );
            if(pv_GHOSTS_NPC_X < pv_PACMAN_FIELD_RESOLUTION && pv_GHOSTS_NPC_X >= 0){
                pvSet(pv_GHOSTS_NPC_X, (pv_GHOSTS_NPC_X + pv_GHOSTS_NPC_MOVDIST));
            }
        }state CHECK_MOVE
    }

    state MOVE_LEFT{
        when(pv_GHOSTS_NPC_IDX == -1){
        }state TELEPORT_CENTER
        when(pv_PACMAN_PLAY_FIELD[((int)pv_GHOSTS_NPC_IDX-1)] == 1){
        } state CHECK_MOVEABLE_DIRECTIONS
        when(delay(0.1)){
            pvSetStr( pv_SS_GHOSTS, "MOVE_LEFT" );
            if(pv_GHOSTS_NPC_X <= pv_PACMAN_FIELD_RESOLUTION && pv_GHOSTS_NPC_X > 0){
                pvSet(pv_GHOSTS_NPC_X, (pv_GHOSTS_NPC_X - pv_GHOSTS_NPC_MOVDIST));
            }
        }state CHECK_MOVE
    }
    
    state MOVE_UP{
        when(pv_GHOSTS_NPC_IDX == -1){
        }state TELEPORT_CENTER
        when(pv_PACMAN_PLAY_FIELD[((int)pv_GHOSTS_NPC_IDX-(int)pv_PACMAN_ARRAY_ROW_LENGTH)] == 1){
        } state CHECK_MOVEABLE_DIRECTIONS
        when(delay(0.1)){
            pvSetStr(pv_SS_GHOSTS, "MOVE_UP" );
            if(pv_GHOSTS_NPC_Y < pv_PACMAN_FIELD_RESOLUTION && pv_GHOSTS_NPC_Y > 0){
                pvSet(pv_GHOSTS_NPC_Y, (pv_GHOSTS_NPC_Y - pv_GHOSTS_NPC_MOVDIST));
            }
        }state CHECK_MOVE
    }
    state MOVE_DOWN{
        when(pv_GHOSTS_NPC_IDX == -1){
        }state TELEPORT_CENTER
        when(pv_PACMAN_PLAY_FIELD[((int)pv_GHOSTS_NPC_IDX+(int)pv_PACMAN_ARRAY_ROW_LENGTH)] == 1){
        } state CHECK_MOVEABLE_DIRECTIONS
        when(delay(0.1)){
            pvSetStr( pv_SS_GHOSTS, "MOVE_DOWN" );
            if(pv_GHOSTS_NPC_Y <= pv_PACMAN_FIELD_RESOLUTION && pv_GHOSTS_NPC_Y >= 0){
                pvSet(pv_GHOSTS_NPC_Y, (pv_GHOSTS_NPC_Y + pv_GHOSTS_NPC_MOVDIST));
            }
        }state CHECK_MOVE
    }
}

// animation of ghosts
ss run_ghost{
    state INIT{
        entry{
            pvSetStr(pv_SS_GHOSTS_RUN, "INIT");
        }when(delay(1)){

        }state CHECK_DIRECTION
    }

    state CHECK_DIRECTION{
        entry{
            int direction = pv_GHOSTS_NPC_DIR % 4;
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
        }when (delay(0.4)){
            pvSet(pv_GHOSTS_NPC_RUN, pv_GHOSTS_NPC_RUNFRAME1);
        }state FRAME_2
    }

      state FRAME_2{
        entry{
            pvSetStr(pv_SS_GHOSTS_RUN, "FRAME_2");
        }when (delay(0.4)){
            pvSet(pv_GHOSTS_NPC_RUN, pv_GHOSTS_NPC_RUNFRAME2);
        }state CHECK_DIRECTION
    }
}