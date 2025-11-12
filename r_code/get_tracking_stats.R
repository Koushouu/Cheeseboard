library(data.table)

source('crossings.R')

get_stats = function(tracking_df, animal_locations.df) {
  valid_pos_df = tracking_df %>%
    filter(smooth_x > -1 & smooth_y > -1) %>%
    arrange(timestamp)
  
  # Override distance to reward using passed locations
  for (i in 1:nrow(animal_locations.df)) {
    dist.var = sprintf('dist_reward%d', i-1)
    valid_pos_df[[dist.var]] = norm2(
      valid_pos_df$smooth_trans_x - animal_locations.df$trans_x[i],
      valid_pos_df$smooth_trans_y - animal_locations.df$trans_y[i])
  }
  
  dist_df = valid_pos_df %>%
    mutate(dist_trans = vec_dist(smooth_trans_x, smooth_trans_y),
           velocity = get_velocity(dist_trans, timestamp),
           #inside_roi = pmin(dist_reward0, dist_reward1) < rew_zone_radius,
           ts = (timestamp - valid_pos_df$timestamp[1]) / 1000) 
  
  # Calculate at_reward
  for (i in 1:nrow(animal_locations.df)) {
    dist.var = sprintf('at_rew%d', i-1)
    rew_dist = dist_df[[sprintf('dist_reward%d', i-1)]]
    dist_df[[dist.var]] = with(dist_df, is.at.reward(velocity, rew_dist, timestamp))
  }
  dist_df$frame_dur = c(diff(dist_df$ts),0)
  dist_df = add.running.col(as.data.table(dist_df), 3.3, 10)
  
  mvelocity = mean(dist_df$velocity[which(dist_df$is_running)])
  
  # ignore tracking jumps from calculation of distance
  dist_df = mutate(dist_df, dist_trans = ifelse(dist_trans > 10, 0, dist_trans))
  
  total_dist = sum(dist_df$dist_trans)
  total_frames = dist_df$frame[length(dist_df$frame)] - dist_df$frame[1]
  total_dur = dist_df$ts[nrow(dist_df)] - dist_df$ts[1]
  
  inside_roi = fill.gaps(dist_df$inside_roi, dist_df$timestamp, max.gap.ms=100)
  roi_durs = get.crossing.durations(1-inside_roi, dist_df$ts, zone_radius=0.5)
  roi_velocity = dist_df$velocity[which(inside_roi==1 & dist_df$is_running)]
  outside_roi_velocity = dist_df$velocity[which(inside_roi==0 & dist_df$is_running)]
  
  
  #rew_dwell_pct = dist_df$frame_dur[inside_roi > 0] %>% sum() / total_dur * 100
  rew_dwell_pct = sum_crossings(dist_df)$dur / total_dur * 100
  
  med_frame_rate = median(1/diff(dist_df$ts))
  frame_30s = find.fst.idx(dist_df$ts, 30)
  frame_60s = find.fst.idx(dist_df$ts, 60)
  frame_120s = find.fst.idx(dist_df$ts, 120)
  frame_180s = find.fst.idx(dist_df$ts, 180)
  
  main_summary = list(
    total_dist=total_dist, 
    dist_0_30s=sum(dist_df$dist_trans[1:frame_30s],na.rm=TRUE),
    dist_30_60s=sum(dist_df$dist_trans[frame_30s:frame_60s],na.rm=TRUE),
    dist_60_120s=sum(dist_df$dist_trans[frame_60s:frame_120s],na.rm=TRUE),
    dist_120_180s=sum(dist_df$dist_trans[frame_120s:frame_180s],na.rm=TRUE),
    total_frames=total_frames, 
    total_dur=total_dur,
    crossings_n=sum_crossings(dist_df)$n,
    crossings_0_30s=sum_crossings(dist_df[1:frame_30s,])$n,
    crossings_30_60s=sum_crossings(dist_df[frame_30s:frame_60s,])$n,
    crossings_60_120s=sum_crossings(dist_df[frame_60s:frame_120s,])$n,
    crossings_120_180s=sum_crossings(dist_df[frame_120s:frame_180s,])$n,
    mvelocity=mvelocity,
    roi_duration=sum(roi_durs),
    mroi_velocity=mean(roi_velocity),
    moutside_roi_velocity=mean(outside_roi_velocity),
    rew_dwell_pct=rew_dwell_pct,
    start_x=dist_df$trans_x[1], 
    start_y=dist_df$trans_y[1])
  
  for (i in 1:nrow(animal_locations.df)) {
    main_summary[[sprintf('arrived_rew%d', i-1)]] = get_time_arrived(dist_df[[sprintf('at_rew%d', i-1)]], dist_df$ts)
    main_summary[[sprintf('timestamp_crossed_rew%d', i-1)]] = get_time_fst_crossed(dist_df[[sprintf('dist_reward%d', i-1)]], dist_df$ts)
  }
  
  return(main_summary)
}
