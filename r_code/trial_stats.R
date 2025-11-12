# Creates behaviour stats

library(dplyr)
library(purrr)
library(readr)
library(data.table)


source('crossings.R')
source('distances.R')
source('locations.R')
source('tracking_files.R')
source('tracking_info.R')
source('get_tracking_stats.R')


root_dat_dir = '/Users/stella/Desktop/PhD/paulsen lab/Analysis/ChR2vsEYFP'
#root_dat_dir = '/media/prez/DATA/Lucas/2025-01/ChR2vsEYFP'
rootdirs = c(root_dat_dir)


output_df = data.frame()

locations.df = map_dfr(rootdirs, read_locations)

files.df = map_dfr(rootdirs, get_tracking_files) %>%
  # Used to concatenate the test tracking files with the same id
  mutate(joined_tracking_id = paste(date, animal, trial, sep='_'))

for (joined_tracking_id in unique(files.df$joined_tracking_id)) {
  file_indecies = which(files.df$joined_tracking_id == joined_tracking_id)
  tracking_df = data.frame()
  frame_start = 0
  timestamp_start = 0
  
  print("Columns in tracking_df:")
  print(colnames(tracking_df))
  
  print(paste("Number of rows:", nrow(tracking_df)))
  # Concatenate tracking for files with the same id
  for (i in file_indecies) {
    file_tracking_df = suppressWarnings(read_csv(files.df$filepath[i], col_types = cols()))
    file_tracking_df$frame = file_tracking_df$frame + frame_start
    file_tracking_df$timestamp = file_tracking_df$timestamp + timestamp_start
    frame_start = file_tracking_df$frame[nrow(file_tracking_df)]
    timestamp_start = file_tracking_df$timestamp[nrow(file_tracking_df)]
    tracking_df = bind_rows(tracking_df, file_tracking_df)
  }

  file_i = file_indecies[1]
  
  tracking_df$inside_roi = as.logical(tracking_df$inside_roi)
  print(files.df$filepath[file_i])
      
  animal_pos.df = filter(locations.df, animal == files.df$animal[file_i], 
                         date == files.df$date[file_i])
  
  
  if (!('dist_reward0' %in% colnames(tracking_df))) {
    for (i in 1:nrow(animal_pos.df)) {
      loc = list(x=animal_pos.df$trans_x[i],
                 y=animal_pos.df$trans_y[i])
      dist_var = sprintf('dist_reward%d', i-1)
      is_valid_pos = tracking_df$smooth_trans_x > -1
      tracking_df[[dist_var]] = norm2(tracking_df$smooth_trans_x - loc$x,
                                      tracking_df$smooth_trans_y - loc$y)
      tracking_df[[dist_var]][!is_valid_pos] = -1
    }
    #warning('Distances to reward not present in the tracking file')
  }
  
  
  res = get_stats(tracking_df, animal_pos.df)
  current_stim_pos = filter(animal_pos.df, Valence == 'Negative')
  time_finished_sec = -1
  if (res[['arrived_rew0']] >= 0 && res[['arrived_rew1']] >= 0) {
    time_finished_sec = max(res[['arrived_rew0']], res[['arrived_rew1']])
  }
  
  new_row = data.frame(date=files.df$date[file_i],
                       animal=files.df$animal[file_i],
                       trial_n=files.df$trial[file_i],
                       dist=res['total_dist'],
                       dist_0_30s=res['dist_0_30s'],
                       dist_30_60s=res['dist_30_60s'],
                       dist_60_120s=res['dist_60_120s'],
                       dist_120_180s=res['dist_120_180s'],
                       total_frames=res['total_frames'],
                       total_dur=res['total_dur'],
                       location_set=current_stim_pos$location_set[1],
                       start_x=res['start_x'],
                       start_y=res['start_y'],
                       rew1_x=current_stim_pos$trans_x[1],
                       rew1_y=current_stim_pos$trans_y[1],
                       rew2_x=current_stim_pos$trans_x[2],
                       rew2_y=current_stim_pos$trans_y[2],
                       arrived_rew0=res[['arrived_rew0']],
                       arrived_rew1=res[['arrived_rew1']],
                       timestamp_crossed_rew0=res[['timestamp_crossed_rew0']],
                       timestamp_crossed_rew1=res[['timestamp_crossed_rew1']],
                       time_finished=time_finished_sec,
                       crossings_n=res['crossings_n'],
                       mvelocity=res['mvelocity'],
                       crossings_0_30s=res['crossings_0_30s'],
                       crossings_30_60s=res['crossings_30_60s'],
                       crossings_60_120s=res['crossings_60_120s'],
                       crossings_120_180s=res['crossings_120_180s'],
                       roi_duration=res['roi_duration'],
                       mroi_velocity=res['mroi_velocity'],
                       m_outside_roi_velocity=res['moutside_roi_velocity'],
                       rew_dwell_pct=res['rew_dwell_pct'])
  output_df = bind_rows(output_df, new_row) 
}

output_df$animal = as.factor(output_df$animal)
output_df$date = char2date(output_df$date)
output_df$trial_n = as.integer(output_df$trial_n)

#output_df$trial_id = as.integer(output_df$trial_id)

write_csv(output_df, 'trial_stats.csv')

