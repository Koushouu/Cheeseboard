from util import config
import pandas as pd
import os
from PIL import Image
import numpy as np
import pickle

def load_metadata(type = 'combined'):
    '''
    Read the metadata file 
    type can be 'combined', 'animals' or 'trials'
    '''
    animal_info = pd.read_csv(config.animal_info_path)
    trial_info = pd.read_csv(config.trial_info_path)
    if type == 'combined':
        animal_info = pd.read_csv(config.animal_info_path)
        trial_info = pd.read_csv(config.trial_info_path)
        return trial_info.merge(animal_info, on=['sub', 'id'], how='left')
    elif type == 'animals':
        return animal_info
    elif type == 'trials':
        return trial_info
    
def load_cheeseboard_map(preprocess=True):
    cheeseboardMap = pd.read_csv(config.cheeseboard_map_path)
    if preprocess == True:
        cheeseboardMap = cheeseboardMap[['well_row','well_col','trans_X', 'trans_Y']]
        cheeseboardMap.columns = ['well_row','well_col','x', 'y']
    return cheeseboardMap
    
def check_file_existence(file_name):
    if os.path.isfile(file_name):
        return True
    else:
        print(f"The file '{file_name}' does not exist.")
        return False
    
def load_data(fullpath):
    '''
    Load data from file based on extension
    '''
    if not check_file_existence(fullpath):
        return None
    
    # if fullpath.endswith('.csv'):
    #     return pd.read_csv(fullpath)
    
    if fullpath.endswith('.csv'):
        try:
            return pd.read_csv(fullpath)  # try UTF-8 first
        except UnicodeDecodeError:
            return pd.read_csv(fullpath, encoding='latin1')
    
    elif fullpath.endswith('.pkl'):
        with open(fullpath, "rb") as f:
            content = pickle.load(f)
            return content
        
    elif fullpath.endswith('.png'):
        im = Image.open(fullpath)
        return np.array(im)

    elif fullpath.endswith('.npy'):
        return np.load(fullpath, allow_pickle=True)    
    

def preprocess_position(position):
    '''
        Preprocess the position DataFrame to extract only valid positional data
    and standardize column names for analysis.

     This function performs the following steps:
     1. Selects relevant columns: `frame`, `timestamp`, `smooth_trans_x`, `smooth_trans_y`.
     2. In the first 20 seconds (timestamps are milliseconds), finds the first time
         `smooth_trans_x != -1` that is part of a continuous >=3 s detected run and
         removes all rows before that start time.
     3. Resets the timestamp so that time starts from zero, relative to the first
         valid frame, and adds a column that preserves the original timestamp.
     4. Renames columns to standardized names: `frame`, `t`, `x`, and `y`.

    Parameters
    ----------
    position : pandas.DataFrame
        Original position data containing at least the columns:
        `frame`, `timestamp`, `smooth_trans_x`, and `smooth_trans_y`.

    Returns
    -------
    position_truncate : pandas.DataFrame
        Cleaned DataFrame containing only valid positional data with the following columns:
        - `frame`: Frame index from the original data.
        - `t`: Time in seconds, starting from 0 at the first valid frame.
        - `x`: Smoothed x-coordinate of the animal position.
        - `y`: Smoothed y-coordinate of the animal position.
        - `timestamp_original`: Original timestamp in milliseconds.
    '''
    if position is None:
        return position
    # Only extract ['frames','timestamp','smooth_trans_x','smooth_trans_y'] in position dataframe and make a new dataframe 
    position_truncate = position[['frame','timestamp','smooth_trans_x','smooth_trans_y']].copy()

    if len(position_truncate) == 0:
        return None  # or return position_truncate (empty), depending on what you want upstream

    # timestamps are in milliseconds
    ts = position_truncate['timestamp'].astype(float).values
    t_rel = ts - ts[0]

    detected_mask = (position_truncate['smooth_trans_x'].values != -1)

    # Find trial start within first 20 s: first >=3 s continuous detected run
    first_window_ms = 20000.0
    min_detected_ms = 3000.0

    idx_limit = np.searchsorted(t_rel, first_window_ms, side='right')
    if idx_limit < 2:
        return None

    dt = float(np.nanmedian(np.diff(t_rel[:idx_limit])))
    if not np.isfinite(dt) or dt <= 0:
        return None

    min_len = int(np.ceil(min_detected_ms / dt))
    m = detected_mask[:idx_limit]

    edges = np.diff(m.astype(np.int8), prepend=0, append=0)
    starts = np.where(edges == 1)[0]
    ends   = np.where(edges == -1)[0]

    start_idx = None
    for s, e in zip(starts, ends):
        if (e - s) >= min_len:
            start_idx = int(s)
            break

    if start_idx is None:
        return None

    # Remove everything before trial start
    position_truncate = position_truncate.iloc[start_idx:].reset_index(drop=True)

    # Remove rows where `smooth_trans_x` column is -1
    position_truncate = position_truncate[position_truncate['smooth_trans_x'] != -1].reset_index(drop=True)
    if len(position_truncate) == 0:
        return None

    # Preserve original timestamp
    position_truncate['timestamp_original'] = position_truncate['timestamp'].values

    # Reset the time stamp such that time start from 0
    position_truncate['timestamp'] = position_truncate['timestamp'].values - position_truncate['timestamp'].iloc[0]
    # position_truncate['timestamp'] = position_truncate['timestamp'].values - position_truncate['timestamp'][0]
    # Change the column names [timestamp','smooth_trans_x','smooth_trans_y'] to ['t','x','y]
    position_truncate = position_truncate.rename(columns={
        'timestamp': 't',
        'smooth_trans_x': 'x',
        'smooth_trans_y': 'y'
    })
    return position_truncate

def preprocess_triggerLoc(triggerLoc):
    '''
    Preprocess triggerLoc DataFrame to add x and y coordinates based on cheeseboard map.
    '''
    cheeseboardMap = load_cheeseboard_map(preprocess=True)
    triggerLoc_ = triggerLoc[['well_row', 'well_col']]
    # Add column x and y to triggerLoc_
    triggerLoc_ = triggerLoc_.merge(cheeseboardMap, on=['well_row', 'well_col'], how='left')
    return triggerLoc_