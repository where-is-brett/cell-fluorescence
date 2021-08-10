# Measure Corrected Total Cell Fluorescence
Simple &amp; efficient MATLAB app for corrected total cell fluorescence (CTCF) measurements.
[![View Corrected Total Cell Fluorescence on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)](https://au.mathworks.com/matlabcentral/fileexchange/97377-corrected-total-cell-fluorescence)

For detailed instructions please visit [this page](https://www.brettyang.info/projects/CTCF/).

### Note
It is **vital** that ROIs for cells and background are drawn in an alternating fashion, beginning with a cell ROI. That is, Cell_ROI -> Background_ROI -> Cell_ROI -> Background_ROI …”. Furthermore, you must ensure that the ROIs do not intersect with each other.
Each click on a ROI tool button will activate a new ROI selection. To avoid runtime errors, please make sure to click on a tool name once for each ROI definition. If you have selected a tool by mistake, draw an ROI and select that ROI by left-clicking on it, then use the delete button to remove it.
This is an initial release. Runtime error can be avoided if the app is used as instructed. Work is underway to make the app more self-consistent and less prone to errors.

### Acknowledgement
I would like to acknowledge that the ROI selection component was based on a MATLAB handle subclass written by Jonas Reber (2011). I have improved on Reber's code adapted it to this application. 


*Created for the Laboratory of Molecular Neuroscience and Dementia, University of Sydney.*