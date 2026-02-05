# Cheeseboard
All scripts for the cheeseboard project

camera is recording ±30 frames per second
DLC detection every ±15 frames，every 0.5 sec
for the duration of animal in the zone, the animal receives ~10 mW, 20Hz, 5ms laser stimulation every 1 second

## Data organization details

The data organization largely follows the [NeuroBlueprint](https://neuroblueprint.neuroinformatics.dev/) format, with a structure like following:  
xx: trial id in two digits, e.g. 01

```
└── cheeseboard-data/
    ├── rawdata/
    │   └── sub-001_id-A/
    │       ├── ses-01_date-20241205/
    │       │   ├── ephys/
    │       │   │   ├── ... (TBD)
    │       │   │   └── ... (TBD)
    │       │   └── behav/
    │       │       ├── sub-001_ses-01_trial-xx_data-video.avi
    │       │       └── sub-001_ses-01_trial-xx_data-triggerLoc.csv
    │       └── ses-02_date-20241206/
    │           └── ...
    └── derivatives/
        └── sub-001_id-A/
            ├── ses-01_date-20241205/
            │   ├── ephys/
            │   │   └── ... (TBD)
            │   └── behav/
            │       ├── sub-001_ses-01_trial-xx_data-positions.csv
            │       └── sub-001_ses-01_trial-xx_data-trace.png
            └── ses-02_date-20241206/
                └── ...
```
Where `data-`:
* `video.avi`: video of the animal running in the circular maze
* `triggerLoc.csv`: records the location of the reward on the cheeseboard. columns:
    * `id`: animal id
    * `well_row` and `well_col`: the coordinate location of the reward on the cheeseboard. Check `cheeseboard_map.csv` for the exact location
    * `valence`: could be ignored. It was used in the past by Prez to distinguish between large and small reward area.
* `positions.csv`:  animal position over time in the trial. Columns:
    * **?????**
* `trace.png`:  image of the maze, overlayed with the mice track and the reward locations

## Metadata

There are two metadata for this project: `animal_info_YYYYMMDD.csv` and `trial_info_YYYYMMDD.csv` (`YYYYMMDD` for the date they are updated). The two metadata will be combined whenever `util.load_metadata()` is called.  

* `animal_info_YYYYMMDD.csv`: animal information table. With columns:
    * `sub`: 1, 2, 3, 4, 5…
    * `id`: animal id
    * `genotype`: 
        * `ChR2` = ChR2 virus expressed in VTA for activation of dopamine neurons.
        * `eYFP_ChR2` = control animals that expressed only eYFP in VTA and received same behaviour protocol as the ChR2 animals.
        * `ArchT` = ArchT virus expressed in VTA for inhibition of dopamine neurons.
        * `eYFP_ArchT` = control animals that expressed only eYFP in VTA and received same behaviour protocol as the ArchT animals.
        * `WT` = wild type animals. 
        * `Hp` = DAT-Cre;Ai 32 animals, a cross of Ai32 mice with a DA cell-specifying Cre-expressing line that is driven by the DA transporter (DAT) promoter. They have ChR2 virus expressed in dopamine neurons in entire projection field, including in the hippocampus. Optic fibre has been implanted in the hippocampus in these animals. 
    * `test_order`: some animals had extinction (tested for 3-5 days continuously) or forgetting (tested for day 1 and day 5) trials.
        * `n/a` or empty = no forgetting or extinction trials;
        * `fe` = forgetting then extinction
        * `ef` = extinction then forgetting
        * `e` = only extinction trials
        * `ee` = extinction then extinction
        * `ff` = forgetting then forgetting
    * `remapping`: 1 = had remapping experiment; 0 = no remapping experiment
    * `short_duration`: 1 = had short_duration learning trials; 0 = no short_duration learning trials. Note that animal AN has been used in experiment twice, first round the animal is used as short duration animal 25/07/2025- 23/08/2025, test order fe (different to the second round with LFP recording). 
    * `LFP`: 1 = LFP recording available; 0 = LFP recording unavailable. 
    * `animal_note`: any additional note will be here

* `trial_info_YYYYMMDD.csv`: trial information table
    * `sub`: animal id by number
    * `id`: animal ID
    * `date`: the date when the trials are recorded, in `YYYYMMDD`
    * `ses`: session id, the day number of the experiment. This variable will always be continuous, i.e. will not leave gap when a day is missing in purpose
    * `trial_id`: based on the number of trials recorded on that day. For baseline ephys recording, this is 0
    * `trial_type`:
        * `H` = habituation
        * `L` = learning / short duration learning
        * `T` = test
        * `EL` = extra learning
        * `RL` = remapping learning
        * `B` = Baseline / interval break for animals with ephys recording, no behaviour recorded

    * `trial_type_day`: number of days in a specific trial type
    * `test_type`: When there are several test trials, it differentiates between whether the test trials are extinction / forgetting
    * `usable`: 0/1, it tells whether the trial could be used in the analysis, as there are animals that didn’t learn the task. 1= usable, 0 = unusable.
    
    * `ephys_trial_id`: match the ephys recording folder with the behaviour trial
    * `ephys_usable`: 0/1, it tells whether the ephys could be used in the analysis, as there are certain trials where ephys recording is missing or very bad quality


* `tracking.csv`: tracking information of each single trial
    * `Unnamed: 0`: frame
    * `inter_x` & `inter_y`: inter_x and inter_y = interpolated x and y in pixels. gaps between the frame rate where the mouse is not located = – 1
    * `frame`
    * `timestamp`: in milliseconds
    * `inside_roi`: true = inside reward zone; false = not in reward zone
    * `is_headdip`    
    * `x` and `y` : real locations in pixels
    * `trans_x` and `trans_y`: transpolate, 0-100, in a reference frame of the cheeseboard. As each time the cheeseboard might move a little bit, 0 would mean leftmost, 100 means rightmost. Square corners are impossible to reach. 50:50 is in the middle of the cheeseboard     
    * `smooth_x` and `smooth_y`: gaussian smoothing averaging     
    * `smooth_trans_x`    
    * `smooth_trans_y`    
    * `heading_angle`: DLC tracks the tip of nose and the middle of head and the joint between tail and body etc to calculate that     
    * `smooth_heading_angle`    




## Other data
* `cheeseboard_map.csv`: Cheeseboard map data
    We don't have a precise blueprint of the cheeseboard; however previous papers have described the structure of the cheeseboard maze [^1] and [^2]:
    * The maze's diameter = 120 cm, later transformed to 100 au
    * There are 177 evenly spaced wells
    * Wells are 2.5 cm in diameter, 1.5 cm in depth
    * reward zone radius = 10 cm, which is ±8.3333333 au
    * Distance between centers of wells: 8cm
    Note: I found that there is a subtle difference between Deprut's and Prez's cheeseboard

    * ' ': each row describes a location on the cheeseboard
    *`Area` `Mean` `Min` `Max`
    *`X` and `Y`: position in pixel? 
    * `trans_X` and `trans_Y`: transpolate, 0-100, in a reference frame of the cheeseboard
    * `well_row` and `well_col`: tell the specific location, for example, A1

[^1]: https://www.cell.com/current-biology/fulltext/S0960-9822(21)01700-0 check the method section -> cheeseboard maze task
[^2]: https://www.nature.com/articles/nn.2599#MOESM14: Check supplementary text

## Useful resources:

* Prez's GitHub page: https://github.com/przemyslawj
* Prez's paper that used cheese board: https://www.cell.com/current-biology/fulltext/S0960-9822(21)01700-0