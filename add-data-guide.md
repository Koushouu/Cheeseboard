# Data Incoorporation Guide

This document details how to incoorporate new cheeseboard data into the framework

## Step 1: Data preparation

Prepare a folder with any name, with the following structure

```
└── new-data/
    ├── animal_info.csv
    ├── trial_info.csv
    └── data/
        ├── YYYY-MM-DD
        │   ├── locations.csv
        │   └── movie
        │       ├── tracking
        |       |   ├── YYYY-MM-DD_{animal-id}_trial_{trial-id}_positions.csv
        |       |   ├── YYYY-MM-DD_{animal-id}_trial_{trial-id}_trace.png
        |       |   └── ... (other positions/ trace files)
        |       ├── YYYY-MM-DD_{animal-id}_trial_{trial-id}.avi
        |       └── ... (other avi files)
        ├── ... (other dates)
        └── YYYY-MM-DD
```
with the `animal_info.csv` and `trail_info.csv` the same structure as the corresponding csv files in the main `cheeseboard-data` folder. Check `README.md` for more details. Make sure that the first `sub` id in both csv files are exactly +1 to the max `sub` of already existing files.

## Step 2: Check data completeness

From this step onwards, you will use the script `operational/add_new_data.ipynb`. Follow the instruction in that notebook.

This step checks if all files that are listed in the `trial_info.csv` exists.

Files for each trial:
* trackInfo: `*.positions.csv`
* exampleImg: `*.trace.png`
* behVid: `*.avi`
Files for each day:
* triggerLoc: `*.locations.csv`

If any data is missing you should log it to `cheeseboard-data/missing-data-info`

## Step 3: Move file

Move data from the source to the destination folder. Once its finished, add data operation is complete.