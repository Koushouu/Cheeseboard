source('locations.R')

#MIN_DUR_INSIDE_ZONE_S = 0.2
MIN_DUR_INSIDE_ZONE_S = 0.2


get_time_arrived = function(at.reward.vec, ts) {
  indecies = which(at.reward.vec == 1)
  if (length(indecies) == 0) {
    return(-1)
  }
  return(ts[min(indecies)])
}


get_crossing_frames = function(zone_dist, zone_radius=rew_zone_radius) {
  is_inside = zone_dist < zone_radius
  inside_diff = diff(c(0,is_inside,0)) 
  entries = which(inside_diff == 1)
  exits = which(inside_diff == -1) - 1
  if (length(entries) > length(exits)) {
    exits = c(exits, length(is_inside))
  }
  return(list(entries=entries, exits=exits))
}

get_crossings_n = function(zone_dist, ts, zone_radius=rew_zone_radius, min_dur_inside_s=MIN_DUR_INSIDE_ZONE_S) {
  x = get_crossing_frames(zone_dist, zone_radius)
  crossing_durations = ts[x$exits] - ts[x$entries]
  crossings_n = sum(crossing_durations >= min_dur_inside_s)
  return(list(n=crossings_n, dur=sum(crossing_durations)))
}

get_time_fst_crossed = function(zone_dist, ts, zone_radius=rew_zone_radius, min_dur_inside_s=MIN_DUR_INSIDE_ZONE_S) {
  x = get_crossing_frames(zone_dist, zone_radius)
  crossing_durations = ts[x$exits] - ts[x$entries]
  valid_crossings = which(crossing_durations >= min_dur_inside_s)
  if (length(valid_crossings) > 0) {
    return(ts[x$entries[valid_crossings[1]]])
  }
  return(-1)
}


get.crossing.durations = function(zone_dist, ts, zone_radius=rew_zone_radius, min_dur_inside_s=MIN_DUR_INSIDE_ZONE_S) {
  x = get_crossing_frames(zone_dist, zone_radius)
  crossing_durations = ts[x$exits] - ts[x$entries]
  valid_crossings = which(crossing_durations >= min_dur_inside_s)
  return(crossing_durations[valid_crossings])
}


sum_crossings = function(tracking_df, zone_radius=rew_zone_radius, min_dur_inside_s=MIN_DUR_INSIDE_ZONE_S) {
  dist_cols_idx = which(startsWith(names(tracking_df), 'dist_reward'))
  total_n = 0
  total_dur = 0
  for (i in 1:length(dist_cols_idx)) {
    dist.var = sprintf('dist_reward%d', i-1)
    
    x = get_crossings_n(tracking_df[[dist.var]], tracking_df$ts, 
                        zone_radius=zone_radius,
                        min_dur_inside_s=min_dur_inside_s)
    total_n = total_n + x$n
    total_dur = total_dur + x$dur
  }
  return(list(n=total_n, dur=total_dur))
}

crossings4positions = function(pos_x, pos_y, ts, zone_x, zone_y, zone_radius=rew_zone_radius) {
  zone_dist = sqrt((pos_x - zone_x)^2 + (pos_y - zone_y)^2)
  return(get_crossings_n(zone_dist, ts, zone_radius=zone_radius))
}
