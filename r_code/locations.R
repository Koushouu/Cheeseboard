library(dplyr)
library(purrr)
library(stringr)
library(tidyr)

source('utils.R')
perc2dist = 1.2
rew_zone_radius  = 12 / perc2dist # distance of 12 cm
goal.cell.max.dist = rew_zone_radius

is.date <- function(x) !is.na(char2date(x))

get.subdirs = function(path) {
  subdirs = list.files(path, full.names=TRUE)
  return(subdirs[file.info(subdirs)$isdir])
}

add_location_set = function(merged.df) {
  result.df = data.frame()
  
  if (nrow(merged.df) == 0) {
    return(merged.df)
  }
  
  # Add location_set column 
  merged.df$location_set = rep(0, nrow(merged.df))

  for (animal_name in unique(merged.df$animal)) {
    animal.locations = filter(merged.df, .data$animal == animal_name) %>% 
      tidyr::replace_na(list(Valence='Negative')) %>%
      arrange(date)
    location_set = 0
    animal_locs = c()
    prev_locs = c()
    prev_date = '0000-00-00'
    for (i in 1:nrow(animal.locations)) {
      loc = paste0(animal.locations$Well_row[i], 'x', animal.locations$Well_col[i])
      #print(animal.locations$Valence[i])
      #print(prev_locs)
      if (!(loc %in% prev_locs) && animal.locations$Valence[i] == 'Negative') {
        if (prev_date == animal.locations$date[i] && !is.na(loc)) {
          prev_locs = append(prev_locs, loc)
        } else {
          location_set = location_set + 1
          prev_locs = c(prev_locs, loc)
          prev_date = animal.locations$date[i]
        }
      }
      if (!loc %in% animal_locs) {
        animal_locs = append(animal_locs, loc)
      }
      
      animal.locations$location_set[i] = location_set
      animal.locations$location_ordinal[i] = which(loc == animal_locs)
      
    }
    
    result.df = bind_rows(result.df, animal.locations)
  }
  
  # Make location set consistent in one day: if one reward changed then update
  # the location set for all rewards
  result.df = group_by(result.df, animal, date) %>%
    dplyr::mutate(location_set = max(location_set)) %>%
    ungroup() %>%
    arrange(animal, date)
  return(result.df)
}



read_locations = function(root.data.dir) {
  cheeseboard.map = read.csv(file.path(root.data.dir, 'cheeseboard_map.csv')) %>%
    dplyr::select(Row_X, Row_Y, trans_X, trans_Y) %>%
    rename(trans_x=trans_X,
           trans_y=trans_Y) 
  
  merged.df = data.frame()
  dated_subdirs = get.subdirs(root.data.dir)
    
  for (dated_dir in dated_subdirs) {
    date_str = basename(dated_dir)
    

    if (is.date(date_str)) {
      fpath = file.path(dated_dir, 'locations.csv')
      print(paste('Reading locations from: ', fpath))
      if (file.exists(fpath)) {
        locations.df = read.csv(fpath, stringsAsFactors=TRUE) %>%
          filter(!is.na(Well_row), !is.na(Well_col))
        locations.df$date = rep(date_str, nrow(locations.df))
        locations.df.pos = left_join(locations.df, cheeseboard.map, by=c("Well_row"="Row_X", "Well_col"="Row_Y"))
        merged.df = bind_rows(merged.df, locations.df.pos)
      }
    }


  }
  
  if (nrow(merged.df) == 0) {
    return(merged.df)
  }
  
  merged.df = dplyr::rename(merged.df, animal=Animal)
  merged.df$animal = as.factor(merged.df$animal)
  merged.df = add_location_set(merged.df)
  merged.df$date = char2date(merged.df$date)
  
  dplyr::distinct(merged.df, animal, Well_row, Well_col, Valence, date, .keep_all=TRUE)
}


filter.rews.df = function(locs.df, day, animal_name) {
  locs.df = as.data.table(locs.df)
  locs = locs.df[animal == animal_name, ]
  if (!is.null(day) && ('date' %in% colnames(locs))) {
    locs = locs[date==format(day) ,]  
  }
  
  return(locs)
}

geom_circle = function(center, r, npoints=100, offset=0, color='#333333ff') {
  tt = seq(0,2*pi, length.out=npoints)
  xx = center[1] + r * cos(tt)
  yy = center[2] + r * sin(tt)
  circle.df = data.frame(x = xx, y = yy)
  geom_path(data=circle.df, aes(x = x + offset, y = y - offset), color=color)  
}

geom_maze_contour = function(diameter, npoints=100, offset=0) {
  r = diameter / 2
  center = c(r, r)
  geom_circle(center, r, npoints, offset)
}

geom_reward_zone = function(rewards.df, subject=NULL, day=NULL, nbins=100, r=16.67, rew.color='red') {
  dayreward.df = rewards.df
  if (!is.null(subject)) {
    dayreward.df = filter(rewards.df, animal==subject)
  }
  if (!is.null(day)) {
    dayreward.df = filter(dayreward.df, date==char2date(day))
  }
  
  bin.size = 100 / nbins
  dayreward.df$center_x = dayreward.df$trans_x / bin.size
  dayreward.df$center_y = (100 - dayreward.df$trans_y) / bin.size
  geoms = list()
  for (i in 1:nrow(dayreward.df)) {
    geoms[[i]] = geom_circle(c(dayreward.df$center_x[i], dayreward.df$center_y[i]), r, color=rew.color)
  }
  return(geoms)
}
