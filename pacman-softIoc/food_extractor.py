import cv2
import numpy as np

# Load image
img = cv2.imread("../pacman_ui/pacman_background_with_food.png")
rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

# Define pellet color (light pink from the map)
pellet_color = np.array([255, 183, 174])

# Create mask for pellets
mask = cv2.inRange(rgb, pellet_color, pellet_color)

# Find connected components
num_labels, labels, stats, centroids = cv2.connectedComponentsWithStats(mask)

# Original and new sizes
old_width, old_height = img.shape[1], img.shape[0]
new_width, new_height = 896, 992

# Output lists
pellets_data = []
mapping_parts = []

# Virtual grid counters
virtual_x = 1
virtual_y = 1

# Sort pellets by Y then X for consistent virtual coordinates
pellet_list = []
for i in range(1, num_labels):
    cx, cy = centroids[i]
    pellet_list.append((cy, cx, stats[i]))

pellet_list.sort(key=lambda p: (p[0], p[1]))  # Sort by row then column

for cy, cx, stat in pellet_list:
    x, y, w, h, area = stat

    # Scale coordinates
    scaled_x = int(cx * new_width / old_width) - 15
    scaled_y = int(cy * new_height / old_height) - 15

    # Determine food state
    food_state = 2 if area > 10 else 1

    # Append to pellet data
    pellets_data.append(
        {
            "NAME": "PACMAN",
            "X": virtual_x,
            "Y": virtual_y,
            "VALX": scaled_x,
            "VALY": scaled_y,
            "FOODSTATE": food_state,
        }
    )

    # Append to mapping string
    mapping_parts.append(
        f"NAME=$(NAME),X={virtual_x},Y={virtual_y}, "
        f"[ $(NAME):DOTX_{virtual_x}_{virtual_y},$(NAME):DOTY_{virtual_x}_{virtual_y} ]"
    )

    # Increment virtual coordinates
    virtual_x += 1
    if virtual_x > 28:  # Example: Pac-Man grid width
        virtual_x = 1
        virtual_y += 1

# --- Write template file ---
with open("pacman_food.subs", "w") as f:
    f.write("file pacman_food.template\n{ pattern\n")
    f.write("  { NAME,\tX,\tY , VALX, VALY, FOODSTATE }\n")
    for p in pellets_data:
        f.write(
            f"  {{ {p['NAME']}, {p['X']}, {p['Y']}, "
            f"{p['VALX']}, {p['VALY']}, {p['FOODSTATE']} }}\n"
        )
    f.write("}\n")

# --- Write mapping string ---
with open("pacman_mapping.txt", "w") as f:
    f.write(";".join(mapping_parts))

# --- Info output ---
small_count = sum(1 for p in pellets_data if p["FOODSTATE"] == 1)
big_count = sum(1 for p in pellets_data if p["FOODSTATE"] == 2)

print(f"Small pellets: {small_count}")
print(f"Big pellets: {big_count}")
print("First 5 pellets:", pellets_data[:5])
print("Mapping string saved to pacman_mapping.txt")
print("Template saved to pacman_food.subs")