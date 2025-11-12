from util import config
from util import utilities as util
import os

class DataLoader:
    '''
    DataLoader class to load data from files
    '''
    def __init__(self, metadata_ses):
        self.data_dir = config.data_path
        # set attributes from metadata_ses
        if hasattr(metadata_ses, "to_dict"):
            self.__dict__.update(metadata_ses.to_dict())
        self.sub = int(self.sub)
        self.sub_dir = f"sub-{self.sub:03d}_id-{self.id}"
        self.ses_dir = f"ses-{self.ses:02d}_date-{self.date}"
        self.filename_init = f"sub-{self.sub:03d}_ses-{self.ses:02d}_trial-{self.trial_id:02d}"

    def generate_filepath(self, data_name, data_type='derivatives', mod='behav', ext='pkl'):
        '''
        generate filepath based on the provided trial information.
        Note: There should be NO "-" or "_" in `data_name` variable
        '''
        # Generate full path to file based on data type and extension
        return os.path.join(self.data_dir, data_type, self.sub_dir, self.ses_dir, mod, f"{self.filename_init}_data-{data_name}.{ext}")
    
    def get_data(self, data_name, preprocess = True):
        '''
        Get data
        data_name: str, data to load. Can be:
            - 'video'
            - 'position'
            - 'trace'
            - 'triggerLoc'
        preprocess: True or False. if True:
            - 'position' ->  see `util.preprocess_position`
            - 'triggerLoc' -> see `util.preprocess_triggerLoc`
        '''

        if data_name == 'video':
            return util.load_data(self.generate_filepath('video', 'rawdata', 'behav', 'avi'))
        elif data_name == 'position':
            position = util.load_data(self.generate_filepath('position', 'derivatives', 'behav', 'csv'))
            if preprocess:
                return util.preprocess_position(position=position)
            else:
                return position
        elif data_name == 'trace':
            return util.load_data(self.generate_filepath('trace', 'derivatives', 'behav', 'png'))
        elif data_name == 'triggerLoc':
            triggerLoc = util.load_data(self.generate_filepath('triggerLoc', 'rawdata', 'behav', 'csv'))
            if preprocess:
                return util.preprocess_triggerLoc(triggerLoc)
            else:
                return triggerLoc
        
