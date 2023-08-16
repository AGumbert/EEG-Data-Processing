%%%%%% Voltage_Map_Generator_Andrew.m %%%%%%
%
% Created by Andrew Gumbert for Thomas Hansen InfoPos 
% Project, in the Kuperberg NeuroCognition of Language Lab
% Last updated August 2023
%
% This script is partly based on prior processing
% scripts used in the Hansen Lab, such as the old
% "Voltage_Map_Generator.m" script.
%
% Credit to Edward Alexander for the original 
% "Voltage_Map_Generator.m" script.
% edward.alexander@tufts.edu
% Alexander wrote code for outputing topographical
% maps in a format that is usable for the 
% topo_placer_script_Andrew.py script.
% 
% Credit to Edward Wlotko and Arim Perrachione
% for some of the set-up functionality with
% regard to reading in participant data.
%
% All other parts of this script were written 
% by Andrew

% Expects ERP Sets to be in ERPsets(Andrew) folder.

% Will take processed ERP sets from ERPsets(Andrew) folder
% According to provided subject ids
% Then will compute grand average, difference waves, 
% and put out topographic maps of difference waves 
% to topo_plots folder in a format that is usable by
% topo_placer_script_Andrew.py

clearvars; close all; clc;
eeglab;


% HERE IS DIRECTORY CODE FOR TOM'S COMPUTER
addpath('S:\PROJECTS\InfoPos\eeglab2023.0')
main_dir      = 'S:\PROJECTS\InfoPos'; %main folder


% HERE IS DIRECTORY CODE FOR ANDREW'S COMPUTER
%addpath('/Users/Andrew/Desktop/MatLab/eeglab2023.0')
%cd('/Users/Andrew/Desktop/MatLab');
%main_dir      = [pwd '/Andrew_PreProcess_FileStructure']; %main folder



% Folder_suffix variable
% can be '', '/whole_data', '/first_half', or '/second_half',
% depending on if ERP sets are in a subfolder of the 'ERPsets'
% folder.
% Right now, the variable is set to '(Andrew)' to get erp sets
% in the "ERPsets(Andrew)" folder.
folder_suffix = '(Andrew)';

% change in case data files have a prefix
% (like 'first_half_' or 'second_half_')
filename_prefix = '';




cd(main_dir);

%Parse ERP ID input
%If subject_ids variable doesn't exist, prompt user. Can input subject_ids as a single subject, an array of subjectss (e.g. [01_study, 02_study]), or a text file containing many subjects (one per line).
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
%If subject_ids is a string (i.e., single ERP set), convert to cell array
elseif ischar(subject_ids)
    sub_ids = {subject_ids}
else
    error('\nInappropriate value for subject_ids variable\n');
end;


% creates necessary output folder if it does not 
% already exist
if ~exist(fullfile([main_dir '/topo_plots']), 'dir')
    mkdir(fullfile([main_dir '/topo_plots']))
end


%% ***** DATA PROCESSING *****

%start EEGLAB
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

num_valid_subs = 0;

% clears ERP sets in EEGlab
ALLERP = {};
    
for i = 1:length(sub_ids)
    
    % get next subject in list
    sub_id = sub_ids{i};
    
    log_text = {};
    log_text{end+1} = sprintf('Subject ID:\t%s\n', sub_id);

   
     %Import ERP set
     if exist(fullfile(main_dir, ['ERPsets' folder_suffix], [filename_prefix sub_id '_processed_ERP.erp']), 'file')
        
         %Load existing ERP set
         [ERP ALLERP] = pop_loaderp('filename', [filename_prefix sub_id '_processed_ERP.erp'], 'filepath', [main_dir filesep 'ERPsets' folder_suffix]);

    
         log_text{end+1} = sprintf('%s\tERP set loaded from\t%s', datestr(clock), fullfile(main_dir, ['ERPsets' folder_suffix], [filename_prefix sub_id '_processed_ERP.erp']));
        
         num_valid_subs = num_valid_subs + 1;

     % Print error if ERP set is not found
     else
         fprintf('%s\tWARNING: could not find ERP set "%s" in the given folder.\n', datestr(clock), [sub_id '.erp']);
     end

end 

% compute grand average of loaded ERP sets
ERP = pop_gaverager(ALLERP, 'DQ_flag', 1, 'Erpsets', 1:num_valid_subs, 'ExcludeNullBin', 'on', 'SEM', 'on');


% Once in ERPLab:

% Bin subtractions (can write over old bins, we're not saving the ERP
% struct here)

% These are the six comparison bins used in the 
% InfoPos project. A difference wave is created
% for each comparison group.
ERP = pop_binoperator( ERP, {'b13=b1-b2'});
ERP = pop_binoperator( ERP, {'b14=b3-b4'});
ERP = pop_binoperator( ERP, {'b15=b5-b6'});
ERP = pop_binoperator( ERP, {'b16=b7-b8'});
ERP = pop_binoperator( ERP, {'b17=b9-b11'});
ERP = pop_binoperator( ERP, {'b18=b10-b12'});

scale = 2.5 % assuming symmetric scale, edit function below if not

% Change path following 'Filename' to your desired output directory for
% individual images of voltage maps
for condition=13:18,
  for time=200:50:1100,
    ERP = pop_scalplot( ERP,  condition, [ time time+50] , 'Animated', 'on', 'Blc', [ -100 0], 'Colormap', 'jet', 'Compression', 'none', 'Electrodes', 'on',  'Filename', sprintf([main_dir '/topo_plots/' '%s_%s.gif'], num2str(condition), num2str(time)), 'FontName', 'Courier New', 'FontSize',  10, 'FPS',  1, 'Legend',  'bn-la', 'Maplimit', [ -(scale) scale   ], 'Mapstyle', 'both', 'Maptype', '2D', 'Mapview', '+X', 'Plotrad',  0.55, 'Position', [ 30 246 960 756],  'Quality',  60, 'Value', 'mean', 'VideoIntro', 'erplab' );
  end
end
