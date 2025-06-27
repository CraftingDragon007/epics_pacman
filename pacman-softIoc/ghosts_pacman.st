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
PV( double, pv_GHOSTS_NPC_MOVE_DELAY, "{NAME}:GHOSTS_NPC_MOVE_DELAY", PV_MON );  
PV( int, pv_GHOSTS_NPC_SIZE, "{NAME}:GHOSTS_NPC_SIZE", PV_MON );  
PV( int, pv_GHOSTS_NPC_MOVDIST, "{NAME}:GHOSTS_NPC_MOVDIST", PV_MON );

PV( int, pv_GHOSTS_TAB_X, "{NAME}:GHOSTS_NPC_TABX", PV_MON );  
PV( int, pv_GHOSTS_TAB_Y, "{NAME}:GHOSTS_NPC_TABY", PV_MON );  
PV( int, pv_GHOSTS_IDX, "{NAME}:GHOSTS_NPC_IDX", PV_MON );  
PV( int, pv_GHOSTS_IDXVAL, "{NAME}:GHOSTS_NPC_IDXVAL", PV_MON );  

PV( int, pv_GHOSTS_NPC_X_CORRECT, "{NAME}:GHOSTS_NPC_X_CORRECT", PV_MON );
PV( int, pv_GHOSTS_NPC_Y_CORRECT, "{NAME}:GHOSTS_NPC_Y_CORRECT", PV_MON );
PV( int, pv_GHOSTS_NPC_INTERSECT, "{NAME}:GHOSTS_NPC_INTERSECT", PV_MON );

/* variables ghost run */
PV( string, pv_SS_GHOSTS_RUN, "{NAME}:SS_GHOSTS_RUN", PV_NONE );
PV( int, pv_GHOSTS_NPC_RUN, "{NAME}:GHOSTS_NPC_RUN", PV_MON );
PV( int, pv_GHOSTS_NPC_RUNFRAME1, "{NAME}:GHOSTS_NPC_RUNFRAME1", PV_MON );
PV( int, pv_GHOSTS_NPC_RUNFRAME2, "{NAME}:GHOSTS_NPC_RUNFRAME2", PV_MON );  
PV( double, pv_GHOSTS_NPC_RUN_DELAY, "{NAME}:GHOSTS_NPC_RUN_DELAY", PV_MON );  

/* variables from pcman */
PV( int, pv_PACMAN_ARRAY_ROW_LENGTH	, "{NAME}:PACMAN_ARRAY_X_SIZE"	, PV_MON );
PV( int, pv_PACMAN_ARRAY_CELL_WIDTH	, "{NAME}:PACMAN_ARRAY_X_FACTOR", PV_MON );
PV( int, pv_PACMAN_USER_X, "{NAME}:PACMAN_USER_X", PV_MON );
PV( int, pv_PACMAN_USER_Y, "{NAME}:PACMAN_USER_Y", PV_MON );
PVA( short, pv_PACMAN_PLAY_FIELD, 868, "{NAME}:PACMAN_PLAY_FIELD", PV_MON);
PV( int, pv_PACMAN_FIELD_SIZE, "{NAME}:PACMAN_FIELD_SIZE"	, PV_MON );
PV( int, pv_PACMAN_FIELD_RESOLUTION, "{NAME}:PACMAN_FIELD_RESOLUTION", PV_MON );

/* variables for png */
PV( int, pv_GHOSTS_PNG_WIDTH, "{NAME}:GHOSTS_PNG_WIDTH"		, PV_MON );
PV( int, pv_GHOSTS_PNG_HEIGHT, "{NAME}:GHOSTS_PNG_HEIGHT"	, PV_MON );
PV( int, pv_GHOSTS_DATA_SIZE, "{NAME}:GHOSTS_PNG_DATA_SIZE"	, PV_MON );
PVA( unsigned char, pv_GHOSTS_PNG_DATA, 200000, "{NAME}:GHOSTS_PNG_DATA" , PV_NONE );

/* Functions */
%{

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

%{
    int NPC_SIZE;
    int CELL_SIZE = 32;
    int ARRAY_ROW_LENGTH = 32;

    int gh_get_tab_coordinates(int cor, int offset){
        double tabcor = (cor + (NPC_SIZE/2) + offset) / CELL_SIZE;
        int tab = round(tabcor);
        if(tabcor < 0) tabcor = 0;
        if(tabcor > 32) tabcor = 32;
        return tab;
    }

    int gh_get_caqtdm_coordinates(int tab_cor){
        int cor = tab_cor;
        if(cor < 0) cor = 0;
        if(cor > 31) cor = 31;
        return (cor * CELL_SIZE) - (NPC_SIZE/2);
    }

    int gh_tab_coordinates_to_index(int tab_x, int tab_y){
        if(tab_x < 0) tab_x = 0;
        if(tab_x > 27) tab_x = 27;
        if(tab_y < 0) tab_y = 0;
        if(tab_y > 30) tab_y = 30;
        return tab_y * 28 + tab_x;
    }

    
    int gh_get_distance_from_pacman(int pac_x, int pac_y, int ghost_x, int ghost_y){
        int diff_x = abs(ghost_x - pac_x);
        int diff_y = abs(ghost_y - pac_y);
        int difference = sqrt(diff_x*diff_x + diff_y*diff_y);

        return difference;
    }

    void gh_get_shortest_direction_to_pacman(int ghost_x, int ghost_y, int pac_x, int pac_y, int* first, int* second, int* third, int* fourth) {
            int distance[4];
            int dir[4] = {0, 1, 2, 3}; // 0=right, 1=left, 2=up, 3=down
            int x[4] = {
                ghost_x + CELL_SIZE, // right
                ghost_x - CELL_SIZE, // left
                ghost_x, // up
                ghost_x,  // down
            };

            int y[4] = {
                ghost_y, // right
                ghost_y, // left
                ghost_y - CELL_SIZE, // up
                ghost_y + CELL_SIZE  // down 
            };

            for(int i = 0; i < 4; i++) {
                distance[i] = gh_get_distance_from_pacman(pac_x, pac_y, x[i], y[i]);
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

          // printf("\nDIR: %d, %d, %d, %d", dir[0], dir[1], dir[2], dir[3]);
            // Save sorted directions to pointers
            if (first)  *first  = dir[0];
            if (second) *second = dir[1];
            if (third)  *third  = dir[2];
            if (fourth) *fourth = dir[3];
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
            pvSet(pv_GHOSTS_NPC_MOVDIST, 5);
            pvSet(pv_GHOSTS_NPC_X, 25);
            pvSet(pv_GHOSTS_NPC_Y, 25);
            pvSet(pv_GHOSTS_NPC_DIR,2);

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
            }   
        }
        when(){
            NPC_SIZE = pv_GHOSTS_NPC_SIZE;
            CELL_SIZE = pv_PACMAN_ARRAY_CELL_WIDTH;
            ARRAY_ROW_LENGTH = pv_PACMAN_ARRAY_ROW_LENGTH;
        } state CHECK_MOVE
    }
    state CHECK_MOVE{
        entry{
            int dir = pv_GHOSTS_NPC_DIR % 4;
            int offset = pv_GHOSTS_NPC_MOVDIST;
            pvSetStr(pv_SS_GHOSTS, "CHECK_MOVE2");

            // calculate wether a ghost is able to move
            pvSet(pv_GHOSTS_TAB_X, gh_get_tab_coordinates(pv_GHOSTS_NPC_X, 0));
            pvSet(pv_GHOSTS_TAB_Y, gh_get_tab_coordinates(pv_GHOSTS_NPC_Y, 0));
            
            pvSet(pv_GHOSTS_IDX, gh_tab_coordinates_to_index(pv_GHOSTS_TAB_X, pv_GHOSTS_TAB_Y));
            pvSet(pv_GHOSTS_IDXVAL, pv_PACMAN_PLAY_FIELD[pv_GHOSTS_IDX]);
        }
        when(delay(pv_GHOSTS_NPC_MOVE_DELAY) && pv_GHOSTS_IDXVAL == 0){
        } state CHECK_CORRECTION
        when(pv_GHOSTS_IDXVAL == 1){
        } state CHECK_MOVEABLE_DIRECTION
    }

    state CHECK_CORRECTION{
        entry{
            int dir = pv_GHOSTS_NPC_DIR % 4;
            int tab_x = gh_get_tab_coordinates(pv_GHOSTS_NPC_X, 0);
            int tab_y = gh_get_tab_coordinates(pv_GHOSTS_NPC_Y, 0);
            int y;
            int x;
            int xx;
            int size = 32;

            if(dir == 0 || dir == 1){
                y = tab_y * size;
                if(pv_GHOSTS_NPC_Y > y){
                    pvSet(pv_GHOSTS_NPC_Y_CORRECT, y - pv_GHOSTS_NPC_Y);
                }else if(y > pv_GHOSTS_NPC_Y){
                    pvSet(pv_GHOSTS_NPC_Y_CORRECT, -(pv_GHOSTS_NPC_Y - y));
                }else{
                    pvSet(pv_GHOSTS_NPC_Y_CORRECT, 0);
                }
            }else if(dir == 2 || dir == 3){
                x = tab_x * size;
                xx = pv_GHOSTS_NPC_X + (pv_GHOSTS_NPC_SIZE/4);
                if(pv_GHOSTS_NPC_X> x){
                    pvSet(pv_GHOSTS_NPC_X_CORRECT, x - xx);
                }else if(x > pv_GHOSTS_NPC_X){
                    pvSet(pv_GHOSTS_NPC_X_CORRECT, -(xx - x));
                }else{
                    pvSet(pv_GHOSTS_NPC_X_CORRECT, 0);
                }
            }
        }
        when(){
        } state CHECK_INTERSECTION
    }

    state CHECK_MOVEABLE_DIRECTION{
        entry{
            int dir = pv_GHOSTS_NPC_DIR % 4;
            int first, second, third, fourth;
            int opposite;
            int new_dir;

            pvSetStr(pv_SS_GHOSTS, "CHECK_MOVEABLE DIRECTION");
            gh_get_shortest_direction_to_pacman(pv_GHOSTS_NPC_X, pv_GHOSTS_NPC_Y, pv_PACMAN_USER_X, pv_PACMAN_USER_Y, &first, &second, &third, &fourth);
           
            // Avoid reversing direction
            if(dir == 0) new_dir = 1;
            if(dir == 1) new_dir = 0;
            if(dir == 2) new_dir = 3;
            if(dir == 3) new_dir = 2;

            if(first != new_dir) pvSet(pv_GHOSTS_NPC_DIR, first);
            if(second != new_dir) pvSet(pv_GHOSTS_NPC_DIR, second);

            if(pv_GHOSTS_NPC_DIR != dir){
                pvSet(pv_GHOSTS_IDXVAL, 0);
            }
            
        }
        when(delay(pv_GHOSTS_NPC_MOVE_DELAY)){
        } state MOVE
    }

    state CHECK_INTERSECTION{
        entry{
            int horizontal_count = 0;
            int vertical_count = 0;
            int tab_x = pv_GHOSTS_TAB_X;
            int tab_y = pv_GHOSTS_TAB_Y;
            pvSetStr(pv_SS_GHOSTS, "CHECK_INTERSECTION");
        
            // to the right
            if(pv_PACMAN_PLAY_FIELD[gh_tab_coordinates_to_index(tab_x + 1, tab_y)] == 0){
                horizontal_count++;
            }

            // to the left
            if(pv_PACMAN_PLAY_FIELD[gh_tab_coordinates_to_index(tab_x-1, tab_y)] == 0){
                horizontal_count++;
            }

            // upwards
            if(pv_PACMAN_PLAY_FIELD[gh_tab_coordinates_to_index(tab_x, tab_y-1)] == 0){
                vertical_count++;
            }

            // downwards
            if(pv_PACMAN_PLAY_FIELD[gh_tab_coordinates_to_index(tab_x, tab_y + 1)] == 0){
                vertical_count++;
            }

            if(vertical_count > 0 && vertical_count > 0){
                pvSet(pv_GHOSTS_NPC_INTERSECT, 1);
            }else{
                pvSet(pv_GHOSTS_NPC_INTERSECT, 0);
            }
        }
        when(pv_GHOSTS_NPC_INTERSECT == 0){
        } state MOVE
        when(pv_GHOSTS_NPC_INTERSECT == 1){
        } state CHECK_MOVEABLE_DIRECTION
    }

    state MOVE{
        entry{
            int png_index;
            int correction_distance = pv_GHOSTS_NPC_MOVDIST/3;
            pvSetStr(pv_SS_GHOSTS, "MOVE");
        
            png_index = gh_get_png_index_from_xy(pv_GHOSTS_NPC_X + (NPC_SIZE/2), pv_GHOSTS_NPC_Y + (NPC_SIZE/2), pv_PACMAN_FIELD_RESOLUTION, pv_GHOSTS_PNG_WIDTH, pv_GHOSTS_PNG_HEIGHT);
            if (png_index >= 0 && png_index < pv_GHOSTS_DATA_SIZE) {
                // Set the color of red for debugging purposes
                pv_GHOSTS_PNG_DATA[png_index] = 0; // Red channel
                pv_GHOSTS_PNG_DATA[png_index + 1] = 255; // Green channel
                pv_GHOSTS_PNG_DATA[png_index + 2] = 0; // Blue channel
                pvPut(pv_GHOSTS_PNG_DATA);
            }

            // Apply Correction
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
            }
        }
        when(pv_GHOSTS_NPC_DIR % 4 == 0 ){
        } state MOVE_RIGHT
        when(pv_GHOSTS_NPC_DIR % 4 == 1){
        } state MOVE_LEFT
        when(pv_GHOSTS_NPC_DIR % 4 == 2){
        } state MOVE_UP
        when(pv_GHOSTS_NPC_DIR % 4 == 3){
        } state MOVE_DOWN
        
    }

    state MOVE_RIGHT{
        when(){
            pvSetStr(pv_SS_GHOSTS, "MOVE_RIGHT");
            pvSet(pv_GHOSTS_NPC_X, pv_GHOSTS_NPC_X + pv_GHOSTS_NPC_MOVDIST);
        } state CHECK_MOVE
    }

    state MOVE_LEFT{
        when(){
            pvSetStr(pv_SS_GHOSTS, "MOVE_LEFT");
            pvSet(pv_GHOSTS_NPC_X, pv_GHOSTS_NPC_X - pv_GHOSTS_NPC_MOVDIST);
        } state CHECK_MOVE
    }

    state MOVE_UP{
        when(){
            pvSetStr(pv_SS_GHOSTS, "MOVE_UP");
            pvSet(pv_GHOSTS_NPC_Y, pv_GHOSTS_NPC_Y - pv_GHOSTS_NPC_MOVDIST);
        } state CHECK_MOVE
    }

    state MOVE_DOWN{
        when(){
            pvSetStr(pv_SS_GHOSTS, "MOVE_UP");
            pvSet(pv_GHOSTS_NPC_Y, pv_GHOSTS_NPC_Y + pv_GHOSTS_NPC_MOVDIST);
        } state CHECK_MOVE
    }

    
    state TELEPORT_CENTER{
        when(delay(0.1)){
            int respawn = 370;
            pvSetStr(pv_SS_GHOSTS, "TELEPORT_CENTER");
            pvSet(pv_GHOSTS_NPC_X, respawn);
            pvSet(pv_GHOSTS_NPC_Y, respawn);
        } state CHECK_MOVE
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
        }when (delay(pv_GHOSTS_NPC_RUN_DELAY)){
            pvSet(pv_GHOSTS_NPC_RUN, pv_GHOSTS_NPC_RUNFRAME1);
        }state FRAME_2
    }

      state FRAME_2{
        entry{
            pvSetStr(pv_SS_GHOSTS_RUN, "FRAME_2");
        }when (delay(pv_GHOSTS_NPC_RUN_DELAY)){
            pvSet(pv_GHOSTS_NPC_RUN, pv_GHOSTS_NPC_RUNFRAME2);
        }state CHECK_DIRECTION
    }
}