%ERPcprocessing script for NCL standard 32 channel Biosemi data

%This script performs the following steps:

% 1. Import ERP sets from subjects specified by user
% 2. Compute grand average of ERP sets
% 3. Display graphs of average ERP data according to parameters set
%    in "comparison_bins" array


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


% comparison_bins variable 
% contains all sets of bins to compare to each other in the graphs 
% that are produced by this program. One graph will be produced 
% for each set of bin indices specified in this array. 
comparison_bins = {[1 2], [3 4], [5 6], [7 8], [9 11], [10 12]};

%DON'T CHANGE BELOW THIS LINE UNLESS YOU KNOW WHAT YOU'RE DOING
%**************************************************************************
%**************************************************************************
%**************************************************************************





%% ***** SET-UP *****

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

%start EEGLAB
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

num_valid_subs = 0;
    
for i = 1:length(sub_ids)
    
    % get next subject in list
    sub_id = sub_ids{i};
    
    log_text = {};
    log_text{end+1} = sprintf('Subject ID:\t%s\n', sub_id);

   
     %Import ERP set
     if exist(fullfile(main_dir, 'ERPsets', [sub_id '_processedERP.erp']), 'file')
        
         %Load existing ERP set
         [ERP ALLERP] = pop_loaderp('filename', [sub_id '_processedERP.erp'], 'filepath', [main_dir filesep 'ERPsets']);

    
         log_text{end+1} = sprintf('%s\tERP set loaded from\t%s', datestr(clock), fullfile(main_dir, 'ERPsets', [sub_id '_processedERP.erp']));
        
     num_valid_subs = num_valid_subs + 1;

     % Print error if ERP set is not found
     else
         fprintf('%s\tWARNING: could not find ERP set "%s" in ERPsets folder.\n', datestr(clock), [sub_id '_processedERP.erp']);
     end

end 
    
% compute grand average of loaded ERP sets
ERP = pop_gaverager(ALLERP, 'DQ_flag', 1, 'Erpsets', 1:num_valid_subs, 'ExcludeNullBin', 'on', 'SEM', 'on');

% plots the ERPs
for i = 1:length(comparison_bins)
    ERP = pop_ploterps( ERP,  comparison_bins{i},  1:34 , 'AutoYlim', 'on', 'Axsize', [ 0.1 0.1], 'BinNum', 'on', 'Blc', 'pre', 'Box', [ 6 6], 'ChLabel', 'on', 'FontSizeChan',  10, 'FontSizeLeg',  12, 'FontSizeTicks',  10, 'LegPos', 'bottom', 'Linespec', {'k-' , 'r-' , 'b-' , 'g-' , 'c-' , 'm-' ,'y-' , 'w-' , 'k-' , 'r-' , 'b-' , 'g-' }, 'LineWidth',  1, 'Maximize', 'on', 'Position', [ 103.714 27.2937 106.857 31.9286], 'Style','Topo', 'Tag', 'ERP_figure', 'Transparency',  0, 'xscale', [ -300.0 1197.0   -200:200:1000 ], 'YDir', 'normal' );
end 

            %%%% as for plotting, the first argument picks which ERPset we
            %%%% are plotting from the loaded ERPs, then the 1:12 part is
            %%%% specifying which conditions we want to compare. This will
            %%%% change on a by experiment basis, but for me, it would
            %%%% ultimately be nice to have a script that does 1:2 , 3:4,
            %%%% 5:6, 7:8, 9 11, 10 12, and then generate different plots
            %%%% for each of those. The Ylim part just has to do with the
            %%%% axes for the plotting, a better Axsize for visual
            %%%% inspection is 0.1 0.1, so we could change it so it always
            %%%% has that as the value. The other arguments, I'm not to
            %%%% sure about honestly, except the obvious ones, but the
            %%%% letters in the {} are just different color options for
            %%%% plotting, I know that at the very least. -k is black and
            %%%% black and red are usually the defaults for comparing 2
            %%%% conditions against each other 
eeglab redraw;

return;