# Cheeseboard
All scripts for the cheeseboard project

## Data organization details

The data organization largely follows the [NeuroBlueprint](https://neuroblueprint.neuroinformatics.dev/) format, with a structure like following:

```
└── cheeseboard-data/
    ├── rawdata/
    │   └── sub-001_id-A/
    │       ├── ses-01_date-20240930/
    │       │   ├── ephys/
    │       │   │   ├── ... (TBD)
    │       │   │   └── ... (TBD)
    │       │   └── behav/
    │       │       ├── sub-001_ses-01_trial-01_data-video.avi
    │       │       ├── sub-001_ses-01_trial-02_data-video.avi    
    │       │       ├── ... 
    │       │       └── sub-001_ses-01_trial-nn_data-video.avi
    │       └── ses-02_date-20241001/
    │           └── ...
    └── derivatives/
        └── sub-001_id-A/
            ├── ses-01_date-20240930/
            │   ├── ephys/
            │   │   └── ... (TBD)
            │   └── behav/
            │       ├── sub-001_ses-01_trial-01_data-positions.csv
            │       ├── ...
            │       ├── sub-001_ses-01_trial-nn_data-positions.csv
            │       ├── sub-001_ses-01_trial-01_data-trace.png
            │       ├── ...
            │       ├── sub-001_ses-01_trial-nn_data-trace.png
            │       └── sub-001_ses-01_trial-nn_data-locations.csv
            └── ses-02_date-20241001/
                └── ...
```
Where:
* `video.avi`:  
* `positions.csv`:  
* `trace.png`:  
* `locations.csv`:  

## Useful resources:

* Prez's GitHub page: https://github.com/przemyslawj
* Prez's paper that used cheese board: https://www.cell.com/current-biology/fulltext/S0960-9822(21)01700-0
