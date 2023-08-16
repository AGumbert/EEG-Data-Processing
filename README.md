# EEG-Data-Processing
Andrew Gumbert 

August 2023


This repository contains Python and MATLAB scripts for EEG Data Processing.
The scripts use the EEGLAB and ERPLAB toolboxes for MATLAB.
Together, these scripts form a data processing pipeline for Thomas Hansen's
InfoPos Project in Dr. Gina Kuperberg's NeuroCognition of Language Lab.

The scripts are partly based on prior processing scripts from the
Kuperberg lab, but Andrew heavily redesigned and developed the code
during the summer of 2023.

-----------------------------------------------------------------------

Purpose of Pipeline:

This pipeline is designed to process raw electroencephalogram (EEG) data.
The data is processed in EEGLAB to filter and visualize Event-Related 
Potentials (ERPs) in a study designed to test the predictive coding model
of cognition on language processing.

-----------------------------------------------------------------------
Here are the necessary files in the main directory that must be present
before beginning the pipeline:


- rawEEG folder containing all raw participant data

This participant data will be processed by the pipeline.
(not public in this Github repository)

- subject_ids.txt

A text file specifying subject ids, one per row, to be processed in
the pipeline.

- InfoPos_bdf.txt

A text file used by EEGLAB to specify the bins dividing each trial into
the different experimental groups.
(not public in this Github repository)

- InfoPos_bdf_overall.txt

A text file for creating one overall group with all trials used for
data quality analysis.
(not public in this Github repository)

- widescreen.pptx

This pptx is used to set the dimensions of the pptx with topographical maps,
an output of topo_placer_script_Andrew.py. This is used in step 9 below to
visualize the data.

- A working version of EEGLAB with ERPLAB installed
(not public in this Github repository)

-----------------------------------------------------------------------
Here are the stages in the current data processing pipeline:

1. Run "preprocess_Andrew_quality_sheets.m" on raw participant data files.
   Quality sheets will be produced in the "data_quality_sheets" folder.
   In addition, artifact rejection information will appear in the 
   "art_rej_from_dq", and channel spectrum data will appear in the 
   "spectrum_map_outputs" folder. These files can all be used to help 
   determine which channels should be interpolated in steps 2 and 3. 

2. Run "analyze_quality_sheets.py" in the "data_quality_sheets" folder.
   Quality sheets will be changed with color to indicate outlier measurements.
   Specifically, the cells of outlier measurements will become red. 
   Colored quality sheets from the Python script will appear in the 
   "quality_sheets_color" folder in the main directory. 

3. Look through the quality sheets and identify channels with more than 50% 
   outlier measurements for the purpose of interpolation. Note these channels
   for each participant as a cell array in the "interpolated_channels.txt" file 
   in the "data_quality_sheets_color" folder.

4. Run "preprocess_Andrew_raw_to_ICA.m" on each participant. Remove the appropriate 
   channels when prompted according to the results of the previous step. 
   This will generate data sets in the "EEGsets_before_ICA_rejection" folder.
   For reference, artifact rejection sets from this script will appear in the 
   "art_rej_before_ICA" folder.

5. Run ICLabel on each participant, and reject the components of each participant
   that are labeled with more than 50% eye, or are obviously from muscle or 
   channel noise rather than neural activity. Save the post-ICA rejection sets to
   the "EEGsets_after_ICA_rejection" folder.

6. Run the "preprocess_Andrew_ICA_to_processed_ERP.m" script on the data sets 
   generated in the previous step. This will generate ERP sets in the "ERPsets"
   folder. For reference, EEG sets will appear in the "Processed_EEGsets" folder,
   and final artifact rejection information will appear in the "art_rej_after_ICA"
   folder.

7. Compute a grand ERP average across all ERP sets from the previous 
   step, and then perform visualization or statistical analysis as desired. 

   "preprocess_Andrew_plot_grand_avrg.m" can be used to produce plots 
   of comparison bin data (one bin in black vs a second bin in red).
   Outputs of "preprocess_Andrew_plot_grand_avrg.m" go to the "erp_plots"
   folder in the main directory. 

   "preprocess_Andrew_plot_grand_avrg_diff." produces difference waves for
   each comparison bin and graphs the waves as topographic map gifs in the 
   "scalp_maps_diff" folder, as well as waveforms in the "erp_plots_diff"
   folder. 

   IMPORTANT NOTE: If there is a non-empty folder name suffix set in the 
   plotting scripts, the names of the output folders will contain this 
   suffix. For example, if the folder suffix is "abc123", the 
   "preprocess_Andrew_plot_grand_avrg.m" script will put outputs into 
   a folder called "erp_plotsabc123".

8. To create an orderly spreadsheet containing topographic maps of all 
   difference waves across time, run "Voltage_Map_Generator_Andrew.m" 
   on the processed ERP sets in the "ERPsets(Andrew)" folder. Topographical 
   maps will be generated in a specific format in a folder called "topo_maps".

9. Run "topo_placer_script_Andrew.py" on the topographical maps in "topo_maps".
   Note that "widescreen.pptx" must be present in the main directory to 
   set the dimensions of the resulting pptx. The resulting pptx will be 
   called "Export_all_topoplots.pptx" and will contain orderly rows of 
   topographical map images. Resized and cropped images used for the pptx 
   will be stored in the "extra_images" subfolder of "topo_maps".
   


