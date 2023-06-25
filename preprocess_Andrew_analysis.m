%ERP pre-processing script for NCL standard 32 channel Biosemi data

%This script performs the following processing steps according to
%parameters given below:
% 1. Import data from Biosemi bdf file
% 2. Assign channel locations from standard 32 channel .xyz file
% 3. Re-reference the data
% 4. Apply filters with half-amplitude cut-offs given
% 5. Bin and epoch data according to bin descriptor file
% 6. Rejects trials outside of voltage threshold limits as set in 
%    threshold_abs
% 7. Removes bad channels as specified in bad_channels
% 8. Runs ICA on the participant's data
% 9. Interpolates previously removed bad channels
% 10. Creates and saves EEG and ERP sets representing the processed data


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
addpath('C:\Program Files\MATLAB\eeglab2022.1')
main_dir      = 'C:\Users\thoma\Documents\First Year PHD\FYP Presentation'; %main folder

% BELOW IS DIRECTORY CODE FOR ANDREW'S COMPUTER
%addpath('/Users/Andrew/Desktop/MatLab/eeglab2023.0')
%cd('/Users/Andrew/Desktop/MatLab');
%main_dir      = [pwd '/Andrew_PreProcess_FileStructure']; %main folder

raw_dir            = fullfile(main_dir, 'rawEEG'); %location of raw data in bdf format
chanlocs_file      = fullfile(main_dir, 'biosemi32+8_tufts.xyz'); %location of chanlocs file. Old system should use Standard-10-20-Cap29.locs, Biosemi should use biosemi32+8_tufts.xyz
bin_desc_file      = fullfile(main_dir, 'InfoPos_bdf.txt'); %location of the bin descriptor file, saved as a txt.

%%%% so we can get rid of anything that talks about the _arf. Thats the
%%%% Artifact Rejection File, but we are just doing a simple voltage
%%%% threshold and don't need a script for rejecting artifacts


% BAD CHANNELS ARE STORED IN THE VARIABLE BELOW. CURRENTLY, THE VARIABLE
% CONTAINS RANDOM CHANNELS FOR DEMONSTRATION AND TESTING PURPOSES.
% These are the channels to remove from the analysis.
% Change this variable depending on results of quality data analysis. 
bad_channels = {'CP5', 'FPz'};

    %%%% yes, so as we discussed, generating the data quality sheets for each
    %%%% participants is something we are ALWAYS going to want to do,
    %%%% because the data in those sheets is what's going to allow us to
    %%%% identify which channels are 'bad' and need to be removed. So maybe
    %%%% it makes sense to just have one short script that gets the data
    %%%% quality spreadsheets and that scripts allows you to get those
    %%%% sheets for as many participants as you want. Then the
    %%%% preprocessing script could be on a single participant basis, which
    %%%% essentially what I am advocating for in the first place -- just
    %%%% more individual time spent on processing each participant. Then in
    %%%% the preprocessing script, we would want to remove the bad channels
    %%%% after we've gone through filtering and epoching and binning and
    %%%% everything, just right before the ICA starts
    

% absolute value of simple voltage threshold. Channels with absolute values
% outside of this threshold are rejected.
threshold_abs = 250;

% absolute value of simple voltage threshold used to reject bad data 
% when forming the ERP data set. Channels with absolute values
% outside of this threshold are rejected when forming ERP data set.
ERP_threshold_abs = 250;
    
    %%%% yep, this is fine. This threshold is really something to think
    %%%% about more. It's a nice option to have in the preprocessing, but
    %%%% it would be nice if it could be something you could specify
    %%%% whether you want to include or not on a by participant basis. This
    %%%% step is to help the ICA decomposition. The cleaner the data we can
    %%%% give to the ICA algorithm, the better components we will get. In
    %%%% EEG there are as Steve Luck calls them, Commonly Rejected
    %%%% Artifactual Potentials or CRAP in the data and these are things
    %%%% like single trial muscle activity bursts that cause a trial to be
    %%%% unusable (e.g., someone adjusting their body in the middle of a
    %%%% trial). Ideally, we would want to remove this CRAP before we feed
    %%%% the data into ICA, which our current preprocessing script doesn't
    %%%% allow for. Why it would be nice to have this as an option and not
    %%%% necessarily use it 100% of the time is that for some participants,
    %%%% the CRAP might just be on one or 2 trials and then we could just
    %%%% easily look at the data (which we will be doing anyways) and then
    %%%% remove those trials manually. If there is a lot of CRAP then it
    %%%% would be nice to just use a big simple voltage threshold to kind
    %%%% of 'weed out' the really big stuff before feeding into ICA without
    %%%% wasting too much time scanning through the data and removing
    %%%% trials manually. Either way, including this step will improve on
    %%%% the current preprocessing script

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
    subject_ids = input('\n\nID of single subject:  ','s');
end
%If subject_ids is a string (i.e., single subject), convert to cell array
if ischar(subject_ids)
    sub_ids = {subject_ids};
else
    error('\nInappropriate value for subject_ids variable\n');
end


if ~exist(fullfile(main_dir, 'belist'), 'dir')
    mkdir(fullfile(main_dir, 'belist'))
end
if ~exist(fullfile(main_dir, 'EEGsets'), 'dir')
    mkdir(fullfile(main_dir, 'EEGsets'))
end
if ~exist(fullfile(main_dir, 'ERPsets'), 'dir')
    mkdir(fullfile(main_dir, 'ERPsets'))
end
if ~exist(fullfile(main_dir, 'log'), 'dir')
    mkdir(fullfile(main_dir, 'log'))
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

        %%%% so ALLEEG is all the current .set files you have loaded into
        %%%% EEGlab and EEG should just be specifying that we are working
        %%%% with EEG not ERP sets, and then CURRENTSET should just be the
        %%%% current set that is loaded into the GUI 


    log_text{end+1} = sprintf('%s\tRaw data loaded from\t%s', datestr(clock), fullfile(main_dir, 'EEGsets', [sub_id '_raw.set']));
        
else
        
    %Import data
    EEG = pop_biosig(fullfile(raw_dir, [sub_id '.bdf']));
    EEG.subject = sub_id;
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 0, 'setname', sub_id, 'gui', 'off');

            %%%% so take note of the 'gui' 'off' here, you can manipulate
            %%%% when the GUI is shown to the researcher or not, which is
            %%%% something to think about 


           
    log_text{end+1} = sprintf('%s\tRaw data loaded from\t%s', datestr(clock), fullfile(raw_dir, [sub_id '.bdf']));
        
            %%%% loading in the raw data as a biosemi data format
            %%%% (.bdf)


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

                    %%%% so just renaming the current EEG set, doing it to
                    %%%% all channels and the boundary code part is just
                    %%%% specifying whether their is a boundary, which is
                    %%%% probably important to this pop_basicfilter
                    %%%% function as it probably doesn't work unless the
                    %%%% boundaries are specified since there would be
                    %%%% nothing to filter. The other arguments are just
                    %%%% the specifications for what kind of filter we want
                    %%%% to use

    log_text{end+1} = sprintf('%s\tFiltered all channels with a 2nd order Butterworth IIR filter with a half-amplitude high pass cutoff of\t%.2f', datestr(clock), high_pass);
end
if low_pass
    EEG  = pop_basicfilter(EEG, 1:length(EEG.chanlocs), 'Boundary', boundary_code, 'Cutoff', low_pass, 'Design', 'butter', 'Filter', 'lowpass', 'Order',  2, 'RemoveDC', 'on');
    log_text{end+1} = sprintf('%s\tFiltered all channels with a 2nd order Butterworth IIR filter with a half-amplitude low pass cutoff of\t%.1f', datestr(clock), low_pass);
end
[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET, 'setname', [EEG.setname '_filt'], 'gui', 'off');

        %%%% so note that after each step, we save a new dataset in the
        %%%% ALLEEG variable and then update the currentset 
   
    
%% Bin and epoch

            %%%% this stuff is really never going to change so I don't know
            %%%% how much time we needa spend rethinking any of this 

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


%% Rejecting Thresholds Beyond Boundary

% rejects time periods with values outside of simple voltage threshold
% [EEG, Indices] = pop_eegthresh(EEG, 1, 1:34, -1 * threshold_abs, threshold_abs, -0.30078, 1.1973, 1, 1);
EEG = pop_artextval( EEG , 'Channel',  1:34, 'Flag',  1, 'LowPass',  -1, 'Threshold', [ (-1 * threshold_abs) threshold_abs], 'Twindow', [ -300.8 1197.3] ) 


%% Program continues with analysis

% removes bad channels
EEG = pop_select(EEG, 'rmchannel', bad_channels);

            %%%% again, this is something that we are not necessarily going
            %%%% to do everytime. It's just a good option to have. We might
            %%%% remove a bunch of channels on one person but then none on
            %%%% another, and the determination comes after going through
            %%%% the data quality sheets

%Run ICA to calculate ICA weights
EEG = pop_runica(EEG, 'runica')

% interpolates bad channels
% (It seems that the bad channels will be located at indices between
% seven and the end of the removedchans array. We might want to test
% this more to make sure that this is always the case on all versions)
EEG = pop_interp(EEG, EEG.chaninfo.removedchans(7:end), 'spherical');

            %%% and yes we will keep this in mind, though I think you are
            %%% corrent with what you did, so good job figuring that out

% saves corrected data set with "_corr" ending
[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET, 'setname', [EEG.setname '_corr'], 'gui', 'off');
    
%Save post-interpolation EEGset
EEG = eeg_checkset(EEG);
EEG = pop_saveset(EEG, 'filename', [sub_id '_processed.set'], 'filepath', fullfile(main_dir, 'EEGsets'));
[ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
log_text{end+1} = sprintf('%s\tInterpolated EEGset saved as\t%s', datestr(clock), fullfile(main_dir, 'EEGsets', [sub_id '_processed.set']));
    
            %%% change text output to 'Interpolated EEGset saved as....,
            %%% right? All good just pointing out small stuff too


% set up ERP Averaging/processing and save the ERP data set 
EEG  = pop_artextval( EEG , 'Channel',  1:34, 'Flag',  1, 'LowPass',  -1, 'Threshold', [(-1 * ERP_threshold_abs) ERP_threshold_abs], 'Twindow',epoch_time); 

            %%%% so 1:34 channels, 32 electrodes on head and then the 2 eye
            %%%% related external electrodes. The Flag 1 part has to do
            %%%% with Artifact Rejection. I believe Steve Luck explains
            %%%% that in those chapters I assigned, but it's just another
            %%%% option for removing data and marking artifacts in a
            %%%% specific way if we want to keep that option. Not entirely
            %%%% sure what the lowpass part is, but the threshold is the
            %%%% same as what you did previously, and then the twindow part
            %%%% is the epoch we want, so it should be -300 to 1200, not
            %%%% the default which is -200 to 800


ERP = pop_averager( ALLEEG , 'Criterion', 'good', 'DQ_custom_wins', 0, 'DQ_flag', 1, 'DQ_preavg_txt', 0, 'DSindex', 8, 'ExcludeBoundary','on', 'SEM', 'on' );
    
            %%%% note entirely sure what all this means, but the Criterion
            %%%% good is, I believe, the averaging method used, the
            %%%% DQ_custom_wins part is if the person has changed any of
            %%%% the default settings for averaging, the flag is likely
            %%%% similar to the artifact rejection flag in the previous
            %%%% code, and the SEM part is just saying to also calculate
            %%%% the standard error of the mean 


ERP.erpname = [ERP.subject '_processedERP'];
pop_savemyerp(ERP, 'erpname', ERP.erpname, 'filename', [ERP.erpname '.erp'], 'filepath', fullfile(main_dir, 'ERPsets'));
log_text{end+1} = sprintf('%s\tProcessed ERPset saved as\t%s', datestr(clock), fullfile(main_dir, 'ERPsets', [ERP.erpname '.erp']));

eeglab redraw;

return;