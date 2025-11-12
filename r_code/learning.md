---
title: "Cheeseboard learning analysis for ChR2 and eYFP animals" 
output:
  html_notebook: default
  word_document: default
---

Before running the notebook run trial_stats.R.

```{r imports, include=FALSE, echo=FALSE}
knitr::opts_chunk$set(echo=FALSE)

library(dplyr)
library(ggplot2)
library(plotly)
library(readr)
library(tidyr)
library(purrr)
library(plotly)
library(ggplot2)
library(ggrepel)

source('crossings.R')
source('distances.R')
source('get_tracking_stats.R')
source('locations.R')
source('tracking_files.R')
source('tracking_info.R')
source('utils.R')

rotate.xlab = theme(axis.text.x = element_text(angle = -90, vjust = 0.5, hjust=1))
```


```{r}
root_dat_dir = '/Users/stella/Desktop/PhD/paulsen lab/Analysis/ChR2vsEYFP'
#root_dat_dir = '/media/prez/DATA/Lucas/2025-01/ChR2vsEYFP'
```

Read animal info
```{r}
animal.info = read.csv(file.path(root_dat_dir, 'animal_info.csv'))
animal.info$fst_learning_date = as.Date(animal.info$fst_learning_date)
```

Read locations
```{r}
add.learning.day = function(df, date, fst_learning_date) {
  df %>% mutate(learning_day1 = as.integer(as.Date(date) - fst_learning_date + 1))
}
rootdirs = c(root_dat_dir)

locations.df = map_dfr(rootdirs, read_locations)
locations.df = locations.df %>%
  left_join(animal.info, by='animal') %>%
  add.learning.day(date, fst_learning_date) %>%
  mutate(is.habit.trial = learning_day1 <= 0)

cheeseboard.len.cm = 120
```
Read tracking data
```{r}
df = read.csv('trial_stats.csv')
df = df %>% left_join(animal.info, by='animal') %>%
  add.learning.day(date, fst_learning_date)

df = df %>%
  group_by(animal, date) %>%
  mutate(day.ntrials = max(trial_n)) 
```

Missing group and learning start date 
```{r}
for (a in unique(df$animal)) {
  if (!(a %in% animal.info$animal)) {
    days_recorded = filter(df, animal == a) %>% pull(date) %>% unique()
    warning(sprintf('Missing entry for animal %s in animal_info.csv, animal recorded for %d days', a, length(days_recorded)))
  }
}
```



Some mislabelled animals, print and remove:
# ```{r}
# MAX_LEARNING_DAYS = 10
# 
# mislabel_animal_ids = filter(df, learning_day1 > MAX_LEARNING_DAYS) %>% 
#   select(animal, date) %>% distinct()
# df = filter(df, is.na(learning_day1) | learning_day1 <= MAX_LEARNING_DAYS)
# for (i in 1:nrow(mislabel_animal_ids) ) {
#   warning(sprintf('removed mislabed data for animal %s on %s', mislabel_animal_ids$animal[i], mislabel_animal_ids$date[i]))
# }
# ```

Traces for example trial
```{r}
date_str = '2025-01-19'
animal = 'AB'
trial = 5

fname = paste(date_str, animal, 'trial', trial, 'positions.csv', sep='_') 
traces.df = read.csv(file.path(root_dat_dir, date_str, 'movie', 'tracking', fname)) %>%
  filter(smooth_trans_x > -1, smooth_trans_y > -1)
traces.df$ts = (traces.df$timestamp - traces.df$timestamp[1]) / 1000
```

```{r}
traces.df %>%
  ggplot() +
  geom_path(aes(x=smooth_trans_x, y=100-smooth_trans_y, colour=ts), linewidth=0.5) +
  geom_reward_zone(locations.df, animal, date_str, r=rew_zone_radius, rew.color='blue') +
  geom_maze_contour(100) +
  scale_color_continuous(low='#b8e2ff', high='#222222') +
  theme_void() +
  coord_fixed(ratio=1) +
  labs(color='Time (s)')
```

```{r}
select.fst.time = function(a, b, na.val) {
  a.na = ifelse(a < 0, NA, a)
  b.na = ifelse(b < 0, NA, b)
  res = pmin(a.na, b.na, na.rm=T)
  return(ifelse(is.na(res), na.val, res))
}

df = df %>%
  mutate(is.learning = learning_day1 >= 1) %>%
  group_by(animal, is.learning) %>%
  arrange(animal, date, trial_n) %>%
  mutate(total_trial_n = row_number()) %>%
  mutate(is.learning = (learning_day1 >= 1) & (!(day.ntrials == 1))) %>%
  mutate(is.test.trial = (learning_day1 >= 1) & (day.ntrials  == 1)) %>%
  mutate(timestamp_fst_rew = select.fst.time(timestamp_crossed_rew0, timestamp_crossed_rew1, total_dur + 1),
         arrived_fst_rew = select.fst.time(arrived_rew0, arrived_rew1, total_dur + 1)) %>%
  ungroup() %>%
  group_by(animal, is.test.trial) %>%
  mutate(is.fst.test.trial = is.test.trial & (learning_day1==min(learning_day1))) %>%
  ungroup()
scale_x_learning = scale_x_continuous(breaks=sort(unique(df$learning_day1)))
```

```{r}
df = df %>%
  mutate(dist_m = total_dist / cheeseboard.len.cm / total_dur * 60,
         crossings_0_60s=crossings_0_30s+crossings_30_60s,
         crossings_0_120s=crossings_0_60s+crossings_60_120s,
         crossings_per_min=crossings_n/(total_dur) * 60,
         dist_0_60s = dist_0_30s + dist_30_60s,
         dist_0_120s = dist_0_60s + dist_60_120s,
         norm_crossings_30s=crossings_0_30s / (dist_0_30s / cheeseboard.len.cm),
         norm_crossings_60s=crossings_0_60s / (dist_0_60s / cheeseboard.len.cm),
         norm_crossings_120s=crossings_0_120s / (dist_0_120s / cheeseboard.len.cm)) 
```


Info about learning trials per animal: number of trials and their duration
```{r}
df %>%
  group_by(animal) %>%
  dplyr::summarise(
    all_trials=n(),
    learning_trials = sum(is.learning),
    mean.dur.s = mean(total_dur),
    total.dur.s = sum(total_dur),
    .groups='drop')
```

Info about number of reward locations
```{r}
locations.df %>%
  mutate(rew_loc = paste(Well_row, Well_col, sep='x'),
         learning_day = as.numeric(date - fst_learning_date + 1)) %>%
  group_by(animal, learning_day) %>%
  dplyr::summarise(nrewards=length(unique(rew_loc)), .groups='drop') %>%
  arrange(animal, learning_day)
  
```

```{r}
# Day summary data frame
df.day = df %>%
  group_by(animal, date, group, is.learning, learning_day1) %>%
  dplyr::summarise(mtimes_arrived_rew0=mean(arrived_rew0 > 0),
                   mtimes_arrived_rew1=mean(arrived_rew1 > 0),
                   mcrossed_rew0 = mean(timestamp_crossed_rew0 > 0),
                   mcrossed_rew1 = mean(timestamp_crossed_rew1 > 0),
                   m.roi_duration = mean(roi_duration),
                   m.timestamp_fst_rew = mean(timestamp_fst_rew),
                   m.arrived_fst_rew = mean(arrived_fst_rew),
                   m.rew_dwell_pct = mean(rew_dwell_pct),
                   m.crossings_0_60s = mean(crossings_0_60s),
                   m.crossings_0_120s = mean(crossings_0_120s),
                   m.dist_0_60s = mean(dist_0_60s),
                   m.dist_0_120s = mean(dist_0_120s),
                   m.dist_m = mean(dist_m),
                   m.norm_crossings_30s = mean(norm_crossings_30s),
                   m.norm_crossings_60s = mean(norm_crossings_60s),
                   m.norm_crossings_120s = mean(norm_crossings_120s),
                   ntrials=n(), .groups='drop')
```

Number of learning days per animal
```{r}
count(df.day %>% filter(is.learning), group, animal) %>% arrange(n)
```

Distance run - changes per trial

```{r}
g = df.day %>%
  filter(is.learning) %>%
  filter(learning_day1 >= 1) %>%
  ggplot( 
       aes(x=learning_day1, y=m.dist_m,
           group=animal, color=group)) +
  geom_line() +
  scale_x_learning + 
  xlab('Learning day') +
  ylab('Distance run (m per min)')
  
ggplotly(g)
```


# Time to arrive at first reward
Summary across animals
```{r}
alltrial.mean.dist = df %>%
  filter(total_trial_n >= 9, total_trial_n <= 49) %>%
  group_by(group, total_trial_n) %>%
  summarise(
    mean.ts = mean(arrived_fst_rew),
    sem.ts = sem(arrived_fst_rew)
  )

ggplot(alltrial.mean.dist, aes(x = total_trial_n, color = group)) +
  geom_errorbar(aes(
    ymin = mean.ts - sem.ts,
    ymax = mean.ts + sem.ts
  )) +
  # (Optional) uncomment to show mean points
  # geom_point(aes(y = mean.ts)) +
  facet_wrap(~ group) +
  xlab("Trial number") +
  ylab("Time to arrive at first reward (s)")

```

Changes for each individual animal
```{r}
cmp.var = quo(arrived_fst_rew)
#cmp.var = quo(norm_crossings_120s)
g = df %>%
  filter(!is.na(group)) %>%
  filter(is.learning) %>% 
  ggplot( 
       aes(x=total_trial_n, y=!!cmp.var,
           group=animal, color=animal)) +
  geom_line() +
  facet_grid(group ~ .) +
  xlab('Trial number') +
  ylab('Time to arrive at first reward (s)')

ggplotly(g)
```
Day average
```{r}
g = df.day %>%
  #filter(is.learning) %>%
  
  ggplot( 
       aes(x=learning_day1, y=m.arrived_fst_rew,
           group=animal, color=group)) +
  geom_line() +
  scale_x_learning +
  xlab('Learning day') +
  ylab('Time to arrive at first reward (s)')
ggplotly(g)
```

Stella edit - show data for each animal
```{r}

df_plot <- df.day %>%
  # Only keep rows where learning_day1 >= 1
  filter(learning_day1 >= 1)

library(dplyr)
library(ggrepel)
library(scales)  # for colorRampPalette

# 2A) Add a group_animal column
df_plot <- df_plot %>%
  mutate(group_animal = paste(group, animal, sep = "_"))

# 2B) Identify unique combos
unique_combos <- df_plot %>%
  distinct(group, animal, group_animal) %>%
  arrange(group, animal)

# Suppose we have 2 groups: "ChR2" and "eYFP"
chR2_animals <- unique_combos$animal[unique_combos$group == "ChR2"]
eYFP_animals <- unique_combos$animal[unique_combos$group == "eYFP"]

# 2C) Create color palettes 
red_palette  <- colorRampPalette(c("mistyrose", "red"))(length(chR2_animals))
blue_palette <- colorRampPalette(c("lightblue", "blue"))(length(eYFP_animals))

# 2D) Name each color after its group_animal
chR2_names <- unique_combos$group_animal[unique_combos$group == "ChR2"]
names(red_palette) <- chR2_names

eYFP_names <- unique_combos$group_animal[unique_combos$group == "eYFP"]
names(blue_palette) <- eYFP_names

# 2E) Combine into one named vector
color_map <- c(red_palette, blue_palette)

# Label Animals on the Graph
df_labels <- df_plot %>%
  group_by(group_animal, animal) %>%
  slice_max(learning_day1)  # row with the largest day

library(ggplot2)
library(plotly)

g <- ggplot(df_plot, aes(
    x = learning_day1,
    y = m.arrived_fst_rew,
    color = group_animal,    # each group_animal gets a unique shade
    group = animal
  )) +
  geom_line() +
  geom_point() +
  # Use our custom color map
  scale_color_manual(values = color_map) +
  # Label each animal near its final day
  ggrepel::geom_text_repel(
    data = df_labels,
    aes(label = animal),
    show.legend = FALSE  # hide duplicate labels in the legend
  ) +
  scale_x_continuous(
    breaks = c(1, 366, 731, 1097, 1462, 1827),
    labels = c("Day 1", "Day 2", "Day 3", "Day 4", "Day 5", "Day 6")
  ) +
  xlab("Learning Day") +
  ylab("Time to arrive at first reward (s)")

ggplotly(g)

```

Stella edit - show mean data from trial
```{r}
library(dplyr)

df <- df %>%
  group_by(animal) %>%
  mutate(total_trial_n = row_number()) %>%
  ungroup()

df_day <- df %>%
  filter(total_trial_n >= 9, total_trial_n <= 49) %>%
  mutate(day = (total_trial_n - 9) %/% 8 + 1)

df_day_mean <- df_day %>%
  group_by(group, day) %>%
  summarize(
    mean_rew = mean(arrived_fst_rew, na.rm = TRUE),
    sem_rew = sd(arrived_fst_rew, na.rm = TRUE) / sqrt(n()),
    .groups = "drop"
  )

library(ggplot2)
library(plotly)

g <- ggplot(df_day_mean, aes(x = day, y = mean_rew, color = group, group = group)) +
  geom_line() +
  geom_point() +
  geom_errorbar(aes(ymin = mean_rew - sem_rew, ymax = mean_rew + sem_rew), width = 0.2) +
  scale_x_continuous(breaks = 1:6, limits = c(1, 6), labels = paste("Day", 1:6)) +
  labs(
    x = "Day",
    y = "Mean time to arrive at first reward (s)",
    color = "Group"
  )

ggplotly(g)

```

# Time dwelling inside reward zone
```{r}

g <- df.day %>%
  # Only keep rows where learning_day1 >= 1
  filter(learning_day1 >= 1) %>%
  
  
  ggplot(aes(x = learning_day1, y = m.rew_dwell_pct,
             group = animal, color = group)) +
  geom_line() +
scale_x_continuous(
    breaks = c(1, 366, 731, 1097, 1462, 1827),
    labels = c("Day 1", "Day 2", "Day 3", "Day 4", "Day 5", "Day 6")
  ) +
  xlab("Day") +
  ylab("Time spent inside reward zone (% of the trial)")

ggplotly(g)
```

# Time inside reward zone during test trial
```{r}
test.df = df %>% filter(is.fst.test.trial) 
g = test.df %>%
  ggplot(aes(x=group, y=rew_dwell_pct, text=animal)) +
  #geom_boxplot() +
  geom_jitter(aes(color=group), height=0, width=0.1) +
  xlab('') + 
  ylab('Time spent inside reward zone (% of the test trial)') 
ggplotly(g)
```

# Comparison with habituation trials
Calculate number of crossings during habituation for each location set
```{r, warning=FALSE}
hab_dirs_df = df %>% 
  filter(learning_day1 < 1) %>% 
  select(animal, date) %>%
  mutate(animal_date = paste(animal, date, sep='_')) %>%
  distinct()

hab.paths = purrr::map2_chr(hab_dirs_df$animal, hab_dirs_df$date, ~ file.path(root_dat_dir, .y))
hab.files = map_dfr(hab.paths, get_dated_tracking_files) %>%
  mutate(animal_date = paste(animal, date, sep='_')) %>%
  filter(animal_date %in% hab_dirs_df$animal_date)

animal.locations = locations.df %>%
  dplyr::mutate(rowxcol=paste0(as.character(Well_row), 'x', as.character(Well_col))) %>%
  filter(!is.habit.trial) %>%
  group_by(animal, rowxcol, location_set) %>%
  dplyr::select(animal, rowxcol, Well_row, Well_col, trans_x, trans_y, location_set) %>%
  dplyr::distinct()
```

```{r}
hab_loc = full_join(hab.files, animal.locations, by=c("animal")) %>%
  filter(!is.na(filepath))
hab_loc$crossings = rep(0, nrow(hab_loc))
hab_loc$total_dist = rep(0, nrow(hab_loc))
hab_loc$rew_dwell_pct = rep(0, nrow(hab_loc))
hab_loc$arrived_fst_rew = rep(0, nrow(hab_loc))
hab_loc$timestamp_fst_rew = rep(0, nrow(hab_loc))

for (i in 1:nrow(hab.files)) {
  tracking.df = read_csv(hab.files$filepath[i], col_types = cols(), name_repair = "unique_quiet")

  test.locs = animal.locations %>%
    filter(animal == hab.files$animal[i])
  res = get_stats(tracking.df, test.locs)
  hab_loc$total_dist[i] = res$total_dist
  hab_loc$crossings[i] = res$crossings_n
  hab_loc$rew_dwell_pct[i] = res$rew_dwell_pct
  hab_loc$arrived_fst_rew[i] = with(res, select.fst.time(arrived_rew0, arrived_rew1, total_dur + 1))
  hab_loc$timestamp_fst_rew[i] = with(res, select.fst.time(timestamp_crossed_rew0, timestamp_crossed_rew1, total_dur + 1))
} 


```

Average across habituation trials on the day
```{r}
mhab_loc = hab_loc %>%
  dplyr::mutate(norm_crossings = crossings / (total_dist  / cheeseboard.len.cm)) %>%
  group_by(animal, location_set) %>%
  dplyr::summarise(mnorm_crossings = mean(norm_crossings),
                   #mcrossings_0_60s = mean(crossings_0_60s),
                   #mcrossings_0_120s = mean(crossings_0_120s)
                   mrew_dwell_pct = mean(rew_dwell_pct),
                   marrived_fst_rew = mean(arrived_fst_rew),
                   mtimestamp_fst_rew = mean(timestamp_fst_rew)
                   ) %>%
  dplyr::rename(norm_crossings=mnorm_crossings, 
                #crossings_0_60s=mcrossings_0_60s, 
                #crossings_0_120s=mcrossings_0_120s,
                rew_dwell_pct=mrew_dwell_pct,
                arrived_fst_rew=marrived_fst_rew,
                timestamp_fst_rew=mtimestamp_fst_rew) %>%
  dplyr::mutate(type="habituation")
```

```{r}
selected.columns = c('animal', 'rew_dwell_pct', 'arrived_fst_rew','timestamp_fst_rew')
combined.test.habit = mhab_loc %>% select(all_of(selected.columns)) %>% mutate(trial = 'foraging') %>%
  bind_rows(test.df %>% select(all_of(selected.columns)) %>% mutate(trial='test')) %>%
  left_join(animal.info, by='animal') 


g = combined.test.habit %>%
  ggplot(aes(x=trial, y=rew_dwell_pct, group=animal, color=group)) +
    geom_line() +
    geom_point() +
    facet_wrap(group ~ . ) +
    ylab('Time spent inside reward zone (% of the trial duration)') 

ggplotly(g)
```

