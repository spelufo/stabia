import os
from pathlib import Path

# files

DATA_DIR = Path(os.environ["VESUVIUS_DATA_DIR"])
VOLPKG = "Scroll1.volpkg"

def segmentation_dir():
  return DATA_DIR / "full-scrolls" / VOLPKG / "segmentation"

def cell_name(jy, jx, jz):
  return f"cell_yxz_{jy:03d}_{jx:03d}_{jz:03d}"

def segmentation_cell_dir(jy, jx, jz):
  return segmentation_dir() / cell_name(jy, jx, jz)


# utils

def mkdir(path):
  if not Path(path).is_dir():
    os.mkdir(path)

# data

gp_segments = [
  "20230929220926",
  "20231005123336",
  "20231007101619",
  "20231210121321",
  "20231012184424",
  "20231022170901",
  "20231221180251",
  "20231106155351",
  "20231031143852",
  "20230702185753",
  "20231016151002",
]

scroll_1_umbilicus = [
  (4079, 2443, 250),
  (4070, 2367, 750),
  (4081, 2327, 1250),
  (4038, 2300, 1750),
  (3978, 2240, 2250),
  (3853, 2181, 2750),
  (3730, 2196, 3250),
  (3803, 2211, 3750),
  (3827, 2247, 4250),
  (3785, 2377, 4750),
  (3795, 2551, 5250),
  (3852, 2868, 5750),
  (3884, 3282, 6250),
  (3776, 3485, 6750),
  (3721, 3535, 7250),
  (3649, 3524, 7750),
  (3547, 3498, 8250),
  (3471, 3490, 8750),
  (3393, 3480, 9250),
  (3365, 3596, 9750),
  (3288, 3690, 10250),
  (3199, 3782, 10750),
  (3085, 3917, 11250),
  (2976, 4017, 11750),
  (2978, 4185, 12250),
  (2963, 4387, 12750),
  (2879, 4627, 13250),
  (2879, 4627, 13750),
]

scroll_1_layer_ojs = {}  # scroll_1_layer_ojs[jz] == (ojx, ojy)
for jz in [1, 2, 3, 4]:
  scroll_1_layer_ojs[jz] = (8, 5)
for jz in [5, 6, 7, 8, 9]:
  scroll_1_layer_ojs[jz] = (8, 4)
for jz in [10, 11]:
  scroll_1_layer_ojs[jz] = (8, 5)
for jz in [12]:
  scroll_1_layer_ojs[jz] = (8, 6)
for jz in [13, 14]:
  scroll_1_layer_ojs[jz] = (8, 7)
for jz in [15, 16, 17, 18, 19, 20, 21]:
  scroll_1_layer_ojs[jz] = (7, 7)
for jz in [22, 23, 24, 25]:
  scroll_1_layer_ojs[jz] = (6, 8)
for jz in [26, 27, 28, 29]:
  scroll_1_layer_ojs[jz] = (6, 9)
