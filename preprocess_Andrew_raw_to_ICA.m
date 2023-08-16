%%%%%% preprocess_Andrew_raw_to_ICA.m %%%%%%
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
% code, setting up parameters, and setting up initial 
% filtering, binning, and epoching.
%
% All other parts of this script were written 
% by Andrew

%EEG analysis script for NCL standard 32 channel Biosemi data

%This script performs the following processing steps according to
%parameters given below:
% 1. Import data from Biosemi bdf file
% 2. Assign channel locations from standard 32 channel .xyz file
% 3. Re-reference the data
% 4. Apply filters with half-amplitude cut-offs given
% 5. Bin and epoch data according to bin descriptor file
% 6. Removes bad channels as specified in bad_channels
% 7. Rejects trials outside of voltage threshold limits as set in 
%    threshold_abs. Saves artifact rejection data to 
%    'art_rej_before_ICA' folder. 
% 8. Runs ICA on the participant's data
% 10. Creates and saves an EEG set representing the processed data


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

raw_dir            = fullfile(main_dir, 'rawEEG'); %location of raw data in bdf format
chanlocs_file      = fullfile(main_dir, 'biosemi32+8_tufts.xyz'); %location of chanlocs file. Old system should use Standard-10-20-Cap29.locs, Biosemi should use biosemi32+8_tufts.xyz
bin_desc_file      = fullfile(main_dir, 'InfoPos_bdf.txt'); %location of the bin descriptor file, saved as a txt.

artifact_rejection_output_dir = fullfile(main_dir, 'art_rej_before_ICA'); % stores output of artifact rejection process before ICA

    

% absolute value of simple voltage threshold. Channels with absolute values
% outside of this threshold are rejected.
threshold_abs = 250;
    

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
epoch_time    = [-1000, 2000]; %any EEG data not within an epoch will be removed during epoching.
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
    subject_ids = input('\n\nID of single subject:  ','s');
end
%If subject_ids is a string (i.e., single subject), convert to cell array
if ischar(subject_ids)
    sub_ids = {subject_ids};
else
    error('Inappropriate value for subject_ids variable');
end



if ~exist('bad_channels_input', 'var')
    bad_channels_input = input('\n\nEnter bad channels as a cell array for interpolation.\n(Enter "{}" if there are no bad channels): ');
end
%If bad_channels_input is a cell, put the value in bad_channels
if iscell(bad_channels_input)
    bad_channels = bad_channels_input;
else
    error('Inappropriate value for bad_channels_input variable');
end


% creates necessary folders if they do not already exist
if ~exist(fullfile(main_dir, 'belist'), 'dir')
    mkdir(fullfile(main_dir, 'belist'))
end
if ~exist(fullfile(main_dir, 'EEGsets_before_ICA_rejection'), 'dir')
    mkdir(fullfile(main_dir, 'EEGsets_before_ICA_rejection'))
end
if ~exist(fullfile(main_dir, 'log'), 'dir')
    mkdir(fullfile(main_dir, 'log'))
end
if ~exist(fullfile(main_dir, 'art_rej_before_ICA'), 'dir')
    mkdir(fullfile(main_dir, 'art_rej_before_ICA'))
end

%% ***** DATA PROCESSING *****
    
sub_id = sub_ids{1};
    
log_text = {};
log_text{end+1} = sprintf('Subject ID:\t%s\n', sub_id);
log_text{end+1} = sprintf('%s\n', 'PRE-PROCESSING');
log_text{end+1} = sprintf('%s\t%s\t%s', 'Timestamp', 'Processing Step', 'Parameter');

    
%% Import EEG

%start EEGLAB
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

 %Import data or load existing raw set
 if exist(fullfile(main_dir, 'EEGsets', [sub_id '_raw.set']), 'file')
        
    %Load existing raw set
    EEG = pop_loadset('filename', [sub_id '_raw.set'], 'filepath', [main_dir filesep 'EEGsets']);
    [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, 0);


    log_text{end+1} = sprintf('%s\tRaw data loaded from\t%s', datestr(clock), fullfile(main_dir, 'EEGsets', [sub_id '_raw.set']));
        
else
        
    %Import data
    EEG = pop_biosig(fullfile(raw_dir, [sub_id '.bdf']));
    EEG.subject = sub_id;
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 0, 'setname', sub_id, 'gui', 'off');


           
    log_text{end+1} = sprintf('%s\tRaw data loaded from\t%s', datestr(clock), fullfile(raw_dir, [sub_id '.bdf']));


    %Add channel locations
    EEG = pop_editset(EEG, 'chanlocs', chanlocs_file);
    [ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
    log_text{end+1} = sprintf('%s\tChannel locations added from\t%s', datestr(clock), chanlocs_file);
        
    %Save raw data as EEG set
    EEG = pop_saveset(EEG, 'filename', [sub_id '_raw'], 'filepath', fullfile(main_dir, 'EEGsets'));
    [ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
    log_text{end+1} = sprintf('%s\tRaw EEGset saved as\t%s', datestr(clock), fullfile(main_dir, 'EEGsets', [sub_id '_raw.set']));

end
    
%% Re-reference

EEG = eeg_checkset(EEG);
    
%Biosemi system needs to first remove empty channels, then re-reference to the specified channel averages.
EEG = pop_select(EEG, 'nochannel', {'ExG1' 'ExG2' 'ExG3' 'ExG4'}); %removes extraneous channels in Biosemi
[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET, 'setname', [EEG.setname '_rchan'], 'gui', 'off');
           
    
        %%%% this pop_newset function is how all the different EEG sets
        %%%% are generated, which is a good feature of this script

log_text{end+1} = sprintf('%s\tExtraneous extension channels (37-40) removed', datestr(datetime('now')));
EEG = pop_reref(EEG, ref_chans); %biosemi rereferencing
[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET, 'setname', [EEG.setname '_ref'], 'gui', 'off');
log_text{end+1} = sprintf('%s\tAll channels referenced to\t%s', datestr(clock), num2str(ref_chans));
    


%% Filtering

if high_pass
    EEG  = pop_basicfilter(EEG, 1:length(EEG.chanlocs), 'Boundary', boundary_code, 'Cutoff', high_pass, 'Design', 'butter', 'Filter', 'highpass', 'Order', 2, 'RemoveDC', 'on');

                 

    log_text{end+1} = sprintf('%s\tFiltered all channels with a 2nd order Butterworth IIR filter with a half-amplitude high pass cutoff of\t%.2f', datestr(clock), high_pass);
end
if low_pass
    EEG  = pop_basicfilter(EEG, 1:length(EEG.chanlocs), 'Boundary', boundary_code, 'Cutoff', low_pass, 'Design', 'butter', 'Filter', 'lowpass', 'Order',  2, 'RemoveDC', 'on');
    log_text{end+1} = sprintf('%s\tFiltered all channels with a 2nd order Butterworth IIR filter with a half-amplitude low pass cutoff of\t%.1f', datestr(clock), low_pass);
end
[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET, 'setname', [EEG.setname '_filt'], 'gui', 'off');

   
    
%% Bin and epoch

%Create event list
EEG  = pop_creabasiceventlist(EEG, 'AlphanumericCleaning', 'on', 'BoundaryNumeric', {-99}, 'BoundaryString', {'boundary'}, 'Eventlist', fullfile(main_dir, 'belist', [sub_id '_eventlist.txt'])); 
[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET, 'setname', [EEG.setname '_elist'], 'gui','off');

%Assign events to bins
EEG  = pop_binlister(EEG, 'BDF', bin_desc_file, 'ExportEL', fullfile(main_dir, 'belist', [sub_id '_binlist.txt']), 'IndexEL', 1, 'SendEL2', 'EEG&Text', 'Voutput', 'EEG');
[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET, 'setname', [EEG.setname '_bins'], 'gui', 'off');

%Extract epochs from bins
EEG = pop_epochbin(EEG , epoch_time,  baseline_time);
[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET, 'setname', [EEG.setname '_be'], 'gui', 'off');
log_text{end+1} = sprintf('%s\tBin-based epochs created from\t%s', datestr(clock), bin_desc_file);


%% Program continues with analysis

% removes bad channels
EEG = pop_select(EEG, 'rmchannel', bad_channels);

%% Rejecting Thresholds Beyond Boundary

% rejects time periods with values outside of simple voltage threshold
% and puts result out to the command window and to a file 
EEG = pop_artextval( EEG , 'Channel',  1:length(EEG.chanlocs), 'Flag',  1, 'LowPass',  -1, 'Threshold', [ (-1 * threshold_abs) threshold_abs], 'Twindow', [ -300.8 1197.3] );
pop_summary_AR_eeg_detection(EEG, [artifact_rejection_output_dir '/' EEG.subject '_art_rej_before_ICA.txt'], 'History', 'gui');


% removes marked trials and saves dataset
EEG = pop_rejepoch(EEG, find(EEG.reject.rejmanual), 0);
[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET, 'setname', [EEG.setname '_rej'], 'gui', 'off');
log_text{end+1} = sprintf('%s\tArtifact Rejection Set created from\t%s', datestr(clock), bin_desc_file);



% Run ICA to calculate ICA weights
EEG = pop_runica(EEG, 'runica')


% saves corrected data set with "_ICA" ending
[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET, 'setname', [EEG.setname '_ICA'], 'gui', 'off');
    
%Save finalized EEGset
EEG = eeg_checkset(EEG);
EEG = pop_saveset(EEG, 'filename', [sub_id '_before_ICA_rejection.set'], 'filepath', fullfile(main_dir, 'EEGsets_before_ICA_rejection'));
[ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
log_text{end+1} = sprintf('%s\tInterpolated EEGset saved as\t%s', datestr(clock), fullfile(main_dir, 'EEGsets_before_ICA_rejection', [sub_id '_before_ICA_rejection.set']));
    
eeglab redraw;

return;
