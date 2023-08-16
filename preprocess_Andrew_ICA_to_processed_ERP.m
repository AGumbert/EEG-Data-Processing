%%%%%% preprocess_Andrew_ICA_to_processed_ERP.m %%%%%%
%
% Created by Andrew Gumbert for Thomas Hansen InfoPos 
% Project, in the Kuperberg NeuroCognition of Language Lab
% Last updated August 2023
%
% This script is loosely based on prior processing
% scripts used in the Hansen Lab.
% Credit to Edward Wlotko and Arim Perrachione
% for some of the set-up functionality with
% regard to reading in participant data. Also,
% credit to them for setting up folder-creating 
% code, and for setting up some parameters.
%
% All other parts of this script were written 
% by Andrew



%EEG analysis script for NCL standard 32 channel Biosemi data

%This script performs the following processing steps according to
%parameters given below:
% 1. Import EEG set with removed outlier channels and ICA components
%    removed or labeled for rejection
%    IMPORTANT: Post-ICA EEG sets must be saved to the folder 
%               called 'EEGsets_after_ICA_rejection' in main_dir
% 2. Re-epochs the data to make sure it is in desired range
% 3. Removes ICA components labeled for rejection
% 4. Interpolates removed outlier channels
% 5. Runs simple voltage artifact rejection 
% 6. Creates and saves an EEG set and an ERP set with the processed data


%clear the workspace and close all figures/windows
clearvars; close all;

%% ************************************************************************
%*****************************  PARAMETERS  *******************************
%**************************************************************************

%CHANGE AS APPROPRIATE FOR YOUR STUDY
%We recommend copying the NCLpipeline folder into your study's EEGdata
%folder, changing the filenames to be study-specific. Then, set the
%parameters once for the whole study 

%Full path for data directory and relevant files. Currently, you can set
%the main directory (where it will make all the new folders), and it will
%assume a default folder structure (see preprocessing readme), but you can
%change as needed if you prefer different spots.

% HERE IS DIRECTORY CODE FOR TOM'S COMPUTER
addpath('S:\PROJECTS\InfoPos\eeglab2023.0')
main_dir      = 'S:\PROJECTS\InfoPos'; %main folder

% BELOW IS DIRECTORY CODE FOR ANDREW'S COMPUTER
%addpath('/Volumes/as_rsch_NCL02$/PROJECTS/InfoPos/eeglab2023.0');
%main_dir   = '/Volumes/as_rsch_NCL02$/PROJECTS/InfoPos/'; %main folder

ICA_dir            = fullfile(main_dir, 'EEGsets_after_ICA_rejection'); %location of raw data in bdf format
ERP_output_dir     = fullfile(main_dir, 'ERPsets'); %location of outputed processed ERP sets
chanlocs_file      = fullfile(main_dir, 'biosemi32+8_tufts.xyz'); %location of chanlocs file. Old system should use Standard-10-20-Cap29.locs, Biosemi should use biosemi32+8_tufts.xyz
bin_desc_file      = fullfile(main_dir, 'InfoPos_bdf.txt'); %location of the bin descriptor file, saved as a txt.

artifact_rejection_output_dir = fullfile(main_dir, 'art_rej_after_ICA'); % stores output of artifact rejection process after ICA

    

% absolute value of simple voltage threshold. Channels with absolute values
% outside of this threshold are rejected.
threshold_abs = 75;
    

%Code used to denote boundary events
boundary_code = 300; %filtering will "break" at a boundary code, resuming on the other side (put the code for pauses to EEG data collection here).

%Set reference electrodes.
%For Biosemi, there is no online reference channel, there is instead a virtual reference, so we have to list ALL reference channels here to be averaged together. Most commonly, we will list the left mastoid channel AND the right mastoid channel in order to re-reference to the average of the left and right mastoids.
ref_chans = [35, 36]; % Boisemi: left and right mastoid are generally channels [35, 36].

%Filtering for continuous data
%High-pass filters should be applied here; low pass filters can be applied later
high_pass = 0.1;
low_pass  = 30;

%Epoch information
epoch_time    = [-300, 1200]; %any EEG data not within an epoch will be removed during epoching.
baseline_time = [-100, 0]; %set the baseline average. Standard is [-100, 0]. Sometimes, we might use a post-stimulus baseline, e.g. [-50, 50].


%DON'T CHANGE BELOW THIS LINE UNLESS YOU KNOW WHAT YOU'RE DOING
%**************************************************************************
%**************************************************************************
%**************************************************************************





%% ***** SET-UP *****

cd(main_dir);

%Parse subject ID input
%If subject_ids variable doesn't exist, prompt user. Can input subject_ids as a single subject, an array of subjects (e.g. [01_study, 02_study]), or a text file containing many subjects (one per line).
if ~exist('subject_ids', 'var')
    subject_ids = input('\n\nSubject ID:  ','s');
end
%If subject_ids is a cell array, use as is
if iscell(subject_ids)
    sub_ids = subject_ids;
%If subject_ids is a text file, read lines into cell array
elseif exist(subject_ids, 'file')
    sub_ids = {};
    f_in = fopen(subject_ids);
    while ~feof(f_in)
        sub_ids = [sub_ids fgetl(f_in)]; %#ok<AGROW>
    end
    fclose(f_in);
%If subject_ids is a string (i.e., single subject), convert to cell array
elseif ischar(subject_ids)
    sub_ids = {subject_ids};
else
    error('\nInappropriate value for subject_ids variable\n');
end




% creates necessary folders if they do not exist
if ~exist(fullfile(main_dir, 'log'), 'dir')
    mkdir(fullfile(main_dir, 'log'))
end
if ~exist(fullfile(main_dir, 'art_rej_after_ICA'), 'dir')
    mkdir(fullfile(main_dir, 'art_rej_after_ICA'))
end
if ~exist(fullfile(main_dir, 'ERPsets'), 'dir')
    mkdir(fullfile(main_dir, 'ERPsets'))
end
if ~exist(fullfile(main_dir, 'Processed_EEGsets'), 'dir')
    mkdir(fullfile(main_dir, 'Processed_EEGsets'))
end

%% ***** DATA PROCESSING *****
    
for i = 1:length(sub_ids)

     sub_id = sub_ids{i};
    
     log_text = {};
     log_text{end+1} = sprintf('Subject ID:\t%s\n', sub_id);
     log_text{end+1} = sprintf('%s\n', 'ICA to Processed ERP');
     log_text{end+1} = sprintf('%s\t%s\t%s', 'Timestamp', 'Processing Step', 'Parameter');

    
     %% Import EEG

     %start EEGLAB
     [ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

     %Import data 
     if exist(fullfile(ICA_dir, [sub_id '_after_ICA_rejection.set']), 'file')
        
          %Load existing raw set
          EEG = pop_loadset('filename', [sub_id '_after_ICA_rejection.set'], 'filepath', ICA_dir);
          [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, 0);


          log_text{end+1} = sprintf('%s\tData loaded from\t%s', datestr(clock), fullfile(ICA_dir, [sub_id '_after_ICA_rejection.set']));
        
     else
         
           % warning message for unfound EEG set
           fprintf(['%s\tWARNING: could not find EEG set "%s" in ' ICA_dir ' folder.\n'], datestr(clock), [sub_id '_after_ICA_rejection.set']);
           continue;

     end

     %% Re-epochs data
     EEG = pop_epochbin(EEG , epoch_time,  baseline_time);
     [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET, 'setname', [EEG.setname '_be'], 'gui', 'off');
     log_text{end+1} = sprintf('%s\tBin-based epochs created from\t%s', datestr(clock), bin_desc_file);

     %% removes ICA components labeled for rejection in case the 
     %% components have been labeled but not removed
      
     EEG = pop_subcomp( EEG, [], 0);
     EEG = eeg_checkset( EEG );

     %% interpolates bad channels

     % All excluded channels for interpolation in the InfoPos
     % pipeline are located between the indices of 7 and the 
     % end. If using a different pipeline version with 
     % different criteria for excluding channels, then this
     % range might need to change.
     EEG = pop_interp(EEG, EEG.chaninfo.removedchans(7:end), 'spherical');

     %% Rejecting Thresholds Beyond Boundary

     % rejects time periods with values outside of simple voltage threshold
     % and puts result out to the command window and to a file 
     EEG = pop_artextval( EEG , 'Channel',  1:34, 'Flag',  1, 'LowPass',  -1, 'Threshold', [ (-1 * threshold_abs) threshold_abs], 'Twindow', [ -300.8 1197.3] );
     pop_summary_AR_eeg_detection(EEG, [artifact_rejection_output_dir '/' EEG.subject '_art_rej_after_ICA.txt'], 'History', 'gui');
     EEG = pop_rejepoch(EEG, find(EEG.reject.rejmanual), 0);

     %% Updates EEG Data set to prepare for conversion to ERP

     [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET, 'setname', [EEG.subject '_final'], 'gui', 'off');

     % saves EEGset
     EEG = eeg_checkset(EEG);
     EEG = pop_saveset(EEG, 'filename', [sub_id '_processed_EEG.set'], 'filepath', fullfile(main_dir, 'Processed_EEGsets'));

     %% averages data set into ERP format
 
     ERP = pop_averager( ALLEEG , 'Criterion', 'good', 'DQ_custom_wins', 0, 'DQ_flag', 1, 'DQ_preavg_txt', 0, 'DSindex', 3, 'ExcludeBoundary','on', 'SEM', 'on' );
  

     ERP.erpname = [ERP.subject '_processed_ERP'];
     pop_savemyerp(ERP, 'erpname', ERP.erpname, 'filename', [ERP.erpname '.erp'], 'filepath', fullfile(ERP_output_dir));
     log_text{end+1} = sprintf('%s\tProcessed ERPset saved as\t%s', datestr(clock), fullfile(ERP_output_dir, [ERP.erpname '.erp']));

end
eeglab redraw;

return;
