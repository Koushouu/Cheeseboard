library(dplyr)
library(purrr)

source('utils.R')

# 
# get_tracking_files = function(root_dat_dir) {
#   print(paste0('Getting tracking files for dir=', root_dat_dir))
#   tracking_files = tibble(filepath = character(), 
#                           filename = character(),
#                           date = character(),
#                           animal = factor(),
#                           trial = integer())
#   
#   all_subfiles = list.files(root_dat_dir, full.names=TRUE)
#   dated_subdirs = all_subfiles[file.info(all_subfiles)$isdir]
#   for (dated_dir in dated_subdirs) {
# 
# 
#     tracking_files_list = list.files(dated_dir, 
#                                      pattern='*_positions.csv', 
#                                      recursive=TRUE,
#                                      full.names = TRUE)
# 
#     for (filepath in tracking_files_list) {
#       if (str_detect(filepath, 'tracking_bac')) {
#         next
#       }
#       
#       filename = basename(filepath)
#       fileparts = strsplit(filename,'_')[[1]]
#       date_str = basename(dated_dir)
#       
#       animal = fileparts[length(fileparts)-3]
#       trial_n = fileparts[length(fileparts)-1]
#       
#       tracking_files = add_row(tracking_files, 
#                                filepath=filepath,
#                                date=date_str,
#                                filename=basename(filename), 
#                                animal=animal, 
#                                trial=as.integer(trial_n))
#     }
#   }
#   tracking_files$date = char2date(tracking_files$date)
# 
#   return(tracking_files)
# }


get_tracking_files = function(root_dat_dir) {
  print(paste0('Getting tracking files for dir=', root_dat_dir))
 
  all_subfiles = list.files(root_dat_dir, full.names=TRUE)
  dated_subdirs = all_subfiles[file.info(all_subfiles)$isdir]
  tracking_files = map_dfr(dated_subdirs, get_dated_tracking_files)
  tracking_files$date = char2date(tracking_files$date)
  
  return(tracking_files)
}

get_dated_tracking_files = function(dated_dir) {
  tracking_files = tibble(filepath = character(), 
                          filename = character(),
                          date = character(),
                          animal = factor(),
                          trial = integer())
  
  tracking_files_list = list.files(dated_dir, 
                                   pattern='*_positions.csv', 
                                   recursive=TRUE,
                                   full.names = TRUE)
  
  for (filepath in tracking_files_list) {
    if (str_detect(filepath, 'tracking_bac')) {
      next
    }
    
    filename = basename(filepath)
    fileparts = strsplit(filename,'_')[[1]]
    date_str = basename(dated_dir)
    
    animal = fileparts[length(fileparts)-3]
    trial_n = fileparts[length(fileparts)-1]
    
    tracking_files = add_row(tracking_files, 
                             filepath=filepath,
                             date=date_str,
                             filename=basename(filename), 
                             animal=animal, 
                             trial=as.integer(trial_n))
  }
  return(tracking_files)
}