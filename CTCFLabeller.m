classdef CTCFLabeller < handle
    %% Labeller Class
    %
    %
    % The labeller was inspired by Jonas Reber's CROIEditor class which
    % enables the definition of class object containing multiple ROIs.
    % date. Mai 6th 2011
    % email. jonas.reber at gmail dot com
    % web.  desperate-engineers.com
    %
    % 
    % Modification & improvements by Brett Yang
    %   - Major modification: the improved script records the order in
    %   which the ROIs are selected and labels each instance of the ROIs by
    %   an integer (8-bit).
    %   - M
    % Date: 11th August 2021
    % Email : [at] live [dot] com
    % Web: brettyang.info
    %
    %
    %
    %
    % 
    % You can listen to the object's "MaskDefined" event to retrieve the
    % ROI information generated (obj.getROIData) or get them directly from
    % the objects public properties.    
    %
    % Example usage:
    %    myimage = imread('eight.tif');
    %    roiwindow = CROIEditor(myimage);
    %    ...
    %    addlistener(roiwindow,'MaskDefined',@your_roi_defined_callback)
    %    ...
    %    function your_roi_defined_callback(h,e)
    %         [mask, labels, n] = roiwindow.getROIData;
    %         delete(roiwindow); 
    %    end
    %
    % Notes:
    % - instance mask is storesd as a int8 matrix - that is up to 2^8 ROIs 
    % - if you assign an new image to the class, the window gets
    %   resized according to the image dimensions to have a smooth looking
    %   UI. Initial height can be defined (set figureheight).
    % - if you don't like that the window is centered, remove it in
    %   resizeWindow function
    % - you can enable/disable the ROI preview by handing over a 'nopreview'
    %   to the applyclick function
    % - Image Processing Toolbox is required
    % - please report bugs and suggestions for improvement
    % 
    
    %%
    events 
        MaskDefined % thrown when "apply" button is hit, listen to this event
                    % to get the ROI information (obj.getROIData)
    end
    
    properties
        image = ones(256,256);   % image to work on, obj.image = theImageToWorkOn
        masks = {}; % list of all masks
        
        figureheight = 600; % initial figure height - your image is scaled to fit.
                    % On change of this the window gets resized
    end
    
    properties(Access=private)
        
        % UI stuff
        guifig    % mainwindow
          imax    % holds working area
          roiax   % holds roid preview image
          imag    % image to work on
          roifig  % roi image 
          tl      % userinfo bar
        
        FigureWidth    % initial window height, this is calculated on load
        AspectRatioHeightWidth = 2.1;  % aspect ratio
        
        % Class stuff
        BinaryMask      % mask defined by shapes
        InstanceMask     % multi-label mask (to record the chronological order of labelling events)
        shapes % holds all the shapes to define the mask
        
        % load/save information
        filename
        pathname
        
        % Buttons
        ROIButtons
        LabelButton
        
        % Define colour for convenience
        ROIColourCell
        ROIColourBackground
        ROIColourSelected
    end
    
    %% Public Methods
    methods 

        % CONSTRUCTOR
        function this = CTCFLabeller(InputImage)    
            % make sure the window appears "nice" (was hard to find this
            % aspect ratio to show a well aligned UI ;)
            this.FigureWidth = this.figureheight*this.AspectRatioHeightWidth;
            
            % invoke the UI window
            this.createWindow;
  
            % load the image
            if nargin > 0
                this.image = InputImage;
            else
                this.image = ones(256,256);
            end        
            % predefine class variables
            this.shapes = {}; % no shapes at start
            this.filename = 'MyRegionsOfInterest'; % default filename
            this.pathname = pwd;      % current directory
            this.ROIColourCell = [144 238 144]./256;
            this.ROIColourBackground = [32 178 170]./256;
            this.ROIColourSelected = [0.8203, 0.1758, 0.1758];
            
        end
        
        % DESTRUCTOR
        function delete(this)
            delete(this.guifig);
        end 
        
        % SET METHODS
        % set method for image. uses grayscale images for region selection
        function set.image(this,InputImage)
            if size(InputImage,3) == 3
                this.image = im2double(rgb2gray(InputImage));
            elseif size(InputImage,3) == 1
                this.image = im2double(InputImage);
            else
                error('Unknown image type. Only RGB and greyscale images are supported.');
            end
            this.resetImages;
            this.resizeWindow;
        end
        % set method for figure height etc. automatically adjust window size 
        function set.figureheight(this, height)
            this.figureheight = height;
            this.FigureWidth = this.figureheight*this.AspectRatioHeightWidth;
            this.resizeWindow;
        end
        
        % Public method to retrieve ROI data
        function [masks, binarymask, instancemask, numberofrois] = getROIData(this,varargin)
            masks = this.masks;
            binarymask = false(size(masks{1}));
            for i=1:numel(masks)
                % Write binary mask
                binarymask = binarymask | masks{i};
            end
            instancemask = this.InstanceMask;
            numberofrois = numel(masks);
        end        
        
    end
    
    %% private methods 
    methods(Access=private)

        %%%%%%%%%%%%%%%%%% Useful Mathematical Functions %%%%%%%%%%%%%%%%%%
        
        % This function when applied to a sequence of natural numbers,
        % gives two identical sequences of natural numbers
        function y = f(this, x)
            if rem(x,2) % x is odd 
                y = 1 + (x-1)/2; 
            else
                y = x/2;
            end
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%% Generic Functions %%%%%%%%%%%%%%%%%%%%%%%%
        function resetImages(this)
            this.newROI;
            
            % load images
            this.imag = imshow(this.image,'parent',this.imax); 
            this.roifig = imshow(this.image,'parent',this.roiax);  
            
        end
        
        % Function to update ROI 
        function updateROI(this, a)
            
            if isempty(this.shapes)
                set(this.tl,'String','Draw your first ROI, beginning with a CELL',...
                    'Visible','on','BackgroundColor','g');
            end
            
            this.BinaryMask = zeros(size(this.image));
            this.InstanceMask = zeros(size(this.image)); % reset InstanceMask before each iteration
            
            for i=1:numel(this.shapes)
                roi = this.shapes{i};
                if isvalid(roi)
                    % Crete a mask for each individual ROI
                    BWadd = createMask(roi, this.imag);
                    % Write binary mask
                    this.BinaryMask = this.BinaryMask | BWadd;
                    
                    % Write instance mask
                    currentMax = max(max(int8(this.InstanceMask)));
                    this.InstanceMask = uint8(this.InstanceMask) + (uint8(BWadd)*i);
                    this.InstanceMask(this.InstanceMask>currentMax) = i;
                    
                end
            end
            
            set(this.roifig,'CData',this.image.*this.BinaryMask); 
        end
        
        % Function to label and add listener to any 'shape' (ROI) when the 
        % shape.Tag property is known
        function shapeCreated(this, tag)
            numROIs = numel(this.shapes);
            %%%% Set title bar
            if rem(numROIs,2)
                set(this.tl,'String',sprintf('Draw the %s BACKGROUND ROI.', ordinal(this.f(numROIs))),...
                    'Visible','on','BackgroundColor',this.ROIColourBackground);
            else
                set(this.tl,'String',sprintf('Draw the %s CELL ROI, or click apply if you have finished.', ordinal(1+this.f(numROIs))),...
                    'Visible','on','BackgroundColor',this.ROIColourCell);
            end  
            %%%% Set properties
            % Set tag
            set(this.shapes{tag}, 'Tag', string(tag));
            % Set label and colour
            if rem(tag, 2) % odd => cell
                set(this.shapes{tag}, 'Label', sprintf('Cell %d', this.f(tag)));
                set(this.shapes{tag}, 'Color', this.ROIColourCell);
            else % even => background
                set(this.shapes{tag}, 'Label', sprintf('Background %d', this.f(tag)));
                set(this.shapes{tag}, 'Color', this.ROIColourBackground);
            end
            % Set label visibility
            if this.LabelButton.Value
                set(this.shapes{tag}, 'LabelVisible', 'on');
            else
                set(this.shapes{tag}, 'LabelVisible', 'hover');
            end
            % Set opacity
            set(this.shapes{tag}, 'FaceAlpha', 0.1);
            %%%% Create listeners
            % Generic listeners
            %             addlistener(this.shapes{tag}, 'DrawingStarted', @this.allevents);
            addlistener(this.shapes{tag}, 'ROIMoved', @this.allevents);
            addlistener(this.shapes{tag}, 'DeletingROI', @this.allevents);
            addlistener(this.shapes{tag}, 'ROIClicked', @this.allevents);
            % Listeners to events specific to different ROI types
            if (isa(this.shapes{tag},'images.roi.Freehand') || isa(this.shapes{tag},'images.roi.AssistedFreehand'))
                addlistener(this.shapes{tag}, 'WaypointAdded', @this.allevents);
                addlistener(this.shapes{tag}, 'WaypointRemoved', @this.allevents);
            elseif isa(this.shapes{tag},'images.roi.Polygon')
                addlistener(this.shapes{tag}, 'VertexAdded', @this.allevents);
                addlistener(this.shapes{tag}, 'VertexDeleted', @this.allevents);
            end
            
            %%%% Update ROI
            this.updateROI;      
            
        end
        
        % Function to label and add listener to each new ROI
        function newShapeCreated(this)
            % Set tag
            set(this.shapes{end}, 'Tag', num2str(numel(this.shapes)));
            % convert to double for convenience
            tag = str2double(this.shapes{end}.Tag);
            % Call shapeCreated
            shapeCreated(this, tag);
        end
        
        function tag = DeleteROI(this, src)
            % Convert 'Tag' to number to index array
            tag = str2double(src.Tag);
            % Display the name & rank of deleted object
            set(this.tl,'String',...
                sprintf('You have deleted %s. Define a new ROI to replace it.', src.Label),...
                'Visible','on','BackgroundColor','y');
            % Delete data linked to the user-deleted ROI
            delete(src);
            this.updateROI; % Update ROI preview
        end
        
        function ReplaceROI(this, tag)
            % Begin drawing
            set(this.ROIButtons, 'Enable', 'off');
            % Allow user draw new ROI using 'Freehand'
            this.shapes{tag} = images.roi.Freehand(this.imax);
            draw(this.shapes{tag});
            if isempty(this.shapes{tag}.Position)
                % If the ROI Position is empty then the drawing was either
                % cancelled by user or invalid. Delete the ROI.
                delete(this.shapes{tag});
                this.shapes{tag} = [];
                this.ReplaceROI(tag);
            else
                this.shapeCreated(tag); % add tag, and callback to new shape
            end
            set(this.ROIButtons, 'Enable', 'on');
        end
        
        % Integrity check
        function checkIntegrity(this)
            % This function checks whether the drawing is completed by 
            % looking at whether a drawing is empty or not
            if isempty(this.shapes{end}.Position)
                % if empty => cancelled drawing event
                delete(this.shapes{end}); % delete ROI object
                this.shapes(end) = []; % delete cell element by bracket '()' indexing
                disp('Drawing was interrupted.')               
            else
                this.newShapeCreated; % add tag, and callback to new shape
            end
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%% Event Handles %%%%%%%%%%%%%%%%%%%%%%%%%
        
        % Function handle for all events
        function allevents(this,src,evt)
            evname = evt.EventName;
            switch(evname)
                % General cases
                case{'ROIMoved'}
                    this.updateROI;        
                case{'DeletingROI'}
                    this.ReplaceROI(this.DeleteROI(src));
                case{'DrawingFinished'}
                    this.newShapeCreated;
                    
                % Specific cases
                case{'WaypointAdded','VertexAdded',}
                    this.updateROI;
                case{'WaypointRemoved','VertexDeleted'}
                    if numel(src.Position) <= 4 % if only one waypoint has been drawn (x,y), may as well deleted it
                        this.ReplaceROI(this.DeleteROI(src));
                    else
                        this.updateROI;
                    end
            end
        end
        
        %%%%%%%%%%%%%%%%%%%%%%% CALLBACK FUNCTIONS %%%%%%%%%%%%%%%%%%%%%%%
        
        function closefig(this,h,e) % Close figure
            delete(this);
        end
        
        %%% Button Callbacks
        % Polygon
        function polyclick(this, h,e)
            % Disable all buttons at the start
            set(this.ROIButtons, 'Enable', 'off');
            
            this.shapes{end+1} = images.roi.Polygon(this.imax);
            draw(this.shapes{end});
            this.checkIntegrity;
            
            % Renable all buttons when finished
            set(this.ROIButtons, 'Enable', 'on');
        end
        % Circle
        function circleclick(this, h,e)
            set(this.ROIButtons, 'Enable', 'off');
            this.shapes{end+1} = images.roi.Circle(this.imax);
            draw(this.shapes{end});
            this.checkIntegrity; % add tag, and callback to new shape
            set(this.ROIButtons, 'Enable', 'on');
        end
        % Freehand
        function freeclick(this,h,e)
            set(this.ROIButtons, 'Enable', 'off');
            this.shapes{end+1} = images.roi.Freehand(this.imax);
            draw(this.shapes{end});
            this.checkIntegrity; % add tag, and callback to new shape
            set(this.ROIButtons, 'Enable', 'on');
        end
        % Assisted Freehand
        function assistedclick(this,h,e)
            set(this.ROIButtons, 'Enable', 'off');
            this.shapes{end+1} = images.roi.AssistedFreehand(this.imax);
            draw(this.shapes{end});
            this.checkIntegrity; % add tag, and callback to new shape
            set(this.ROIButtons, 'Enable', 'on');
        end
        
        
        % Apply ROIs - write public properties
        function applyclick(this, h, e, varargin)
            if rem(numel(this.shapes), 2)
                set(this.tl,'String',...
                'You need to select at 1 more background ROI.',...
                    'Visible','on','BackgroundColor','r');
            elseif isempty(this.shapes)
                set(this.tl,'String',...
                'You must define select at least 1 cell ROI and 1 background ROI.',...
                    'Visible','on','BackgroundColor','r');
            else
                set(this.tl,'String','ROI applied','Visible','on','BackgroundColor','g');
                % Write public data
                % First store all instances of ROIs in an array of masks
                for i=1:numel(this.shapes)
                    this.masks{i} = createMask(this.shapes{i}, this.imag);
                end
%                 % -------------- Display ROIs as colour regions ---------------
%                 if~(nargin > 3 && strcmp(varargin{1},'nopreview'))
%                     % preview window
%                     preview = figure('MenuBar','none','Resize','off',...
%                         'Toolbar','none','Name','Created ROI', ...
%                         'NumberTitle','off','Color','white',...
%                         'position',[0 0 300 300]);
%                     movegui(preview,'center');
%                     
%                     imshow(label2rgb(this.InstanceMask),'InitialMagnification','fit');
%                     title({'This is your labelled ROI', ...
%                         ['you have ', num2str(numel(this.masks)), ' independent region(s)']});
%                     uicontrol('style','pushbutton',...
%                         'string','OK!','Callback','close(gcf)');
%                 end
%                 % -------------------------------------------------------------
                notify(this, 'MaskDefined');
            end
        end
        
        % Label visibility Toggle callback
        function showLabel(this, h, e)
            if this.LabelButton.Value
                for i=1:numel(this.shapes)
                    set(this.shapes{i}, 'LabelVisible', 'on');
                end
            else
                for i=1:numel(this.shapes)
                    set(this.shapes{i}, 'LabelVisible', 'hover');
                end
            end
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%% File IO %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function saveROI(this, h,e)
        % save Mask to File
            try 
                [this.filename, this.pathname] = uiputfile('*.ROI','Save Mask as',this.filename);
                ROIs = this.shapes;
                save([this.pathname, this.filename],'ROIs','-mat');
                set(this.tl,'String',['ROI saved: ' this.filename],'Visible','on','BackgroundColor','g');
            catch
                % aborted
            end
        end

        function openROI(this, h,e)
            % load Mask from File
            this.newROI; % delete whatever is on the screen
            [this.filename,this.pathname,~] = uigetfile('*.ROI');
            try
                b = load([this.pathname, this.filename],'-mat');
                ROIs = b.ROIs;
                
                for i=1:size(ROIs)
                    roiType = class(ROIs{i});
                    roiCoordinates = ROIs{i}.Position;
                    % Draw new ROI of different types, according to given coordinates
                    switch(roiType)
                        case{'images.roi.Polygon'}          
                            this.shapes{end+1} = drawpolygon(this.imax, 'Position',roiCoordinates);
                        case{'images.roi.Circle'}
                            this.shapes{end+1} = drawcircle(this.imax, 'Position',roiCoordinates);
                        case{'images.roi.Freehand'}
                            this.shapes{end+1} = drawfreehand(this.imax, 'Position',roiCoordinates);
                        case{'images.roi.AssistedFreehand'}
                            this.shapes{end+1} = drawassisted(this.imax, 'Position',roiCoordinates);
                    end
                    % follow up using pre-defined method 'newShapeCreated'
                    this.newShapeCreated;
                end
                set(this.tl,'String',['Current: ' this.filename],'Visible','on','BackgroundColor','g');
            catch
                % aborted
            end
        end

        function newROI(this, h,e)
            this.masks = {};
            this.BinaryMask = zeros(size(this.image));
            this.InstanceMask = zeros(size(this.image));
            % remove all the this.shapes
            for i=1:numel(this.shapes)
                delete(this.shapes{i});
            end
            this.shapes = {}; % reset shapes holder
            this.updateROI;
        end
    

        % UI FUNCTIONS ----------------------------------------------------
        function createWindow(this, w, h)
            
            this.guifig=figure('MenuBar','none','Resize','on','Toolbar','none','Name','Image Labeller', ...
                'NumberTitle','off','Color','white', 'units','pixels','position',[0 0 this.FigureWidth this.figureheight],...
                'CloseRequestFcn',@this.closefig, 'visible','off');
            
            % buttons
            buttons = [];
            buttons(end+1) = uicontrol('Parent',this.guifig,'String','Polygon',...
                'units','normalized',...
                'FontName','Avenir', 'FontSize',14,...
                'Position',[0.01 0.8 0.08 0.15], ...
                'Callback',@(h,e)this.polyclick(h,e));
            buttons(end+1) = uicontrol('Parent',this.guifig,'String','Circle',...
                'units','normalized',...
                'FontName','Avenir', 'FontSize',14,...
                'Position',[0.01 0.65 0.08 0.15],...
                'Callback',@(h,e)this.circleclick(h,e));
            buttons(end+1) = uicontrol('Parent',this.guifig,'String','Freehand',...
                'units','normalized',...
                'FontName','Avenir', 'FontSize',14,...
                'Position',[0.01 0.5 0.08 0.15],...
                'Callback',@(h,e)this.freeclick(h,e));
            buttons(end+1) = uicontrol('Parent',this.guifig,'String','Assisted',...
                'units','normalized',...
                'FontName','Avenir', 'FontSize',14,...
                'Position',[0.01 0.35 0.08 0.15],...
                'Callback',@(h,e)this.assistedclick(h,e));
            buttons(end+1) = uicontrol('Parent',this.guifig,'String','Apply',...
                'units','normalized',...
                'FontName','Avenir', 'FontSize',14,...
                'Position',[0.01 0.075 0.08 0.1],...
                'Callback',@(h,e)this.applyclick(h,e));
            this.ROIButtons = buttons;
            
            showLabelButton = uicontrol('Parent',this.guifig,'String','Show Labels',...
                'units','normalized',...
                'Style', 'togglebutton',...
                'FontName','Avenir', 'FontSize',14,...
                'Position',[0.01 0.2125 0.08 0.1],...
                'Callback',@(h,e)this.showLabel(h,e));
            this.LabelButton = showLabelButton;
            
            
            % axes    
            this.imax = axes('parent',this.guifig,'units','normalized','position',[0.08 0.07 0.49 0.87]);
            this.roiax = axes('parent',this.guifig,'units','normalized','position',[0.52 0.07 0.49 0.87]);
            linkaxes([this.imax this.roiax]);

            % create toolbar
            this.createToolbar(this.guifig);
           
            
            % axis titles
            uicontrol('tag','txtimax','style','text',...
                'string','Workspace','units','normalized',...
                'FontName','Avenir', 'FontSize',14,...
                'position',[0.08 0.95 0.49 0.05], ...
                'BackgroundColor','w');
            uicontrol('tag','txtroiax','style','text',...
                'string','Preview','units','normalized',...
                'FontName','Avenir', 'FontSize',14,...
                'position',[0.52 0.95 0.49 0.05], ...
                'BackgroundColor','w');
            
            % file load info
            this.tl = uicontrol('tag','txtfileinfo','style','text',...
                'FontName','Avenir', 'FontSize',14,...
                'string','','units','normalized',...
                'position',[0.11675 0.01 0.85725 0.05], ...
                'BackgroundColor','g','visible','off');
        end
        
        function resizeWindow(this)
            [h,w]=size(this.image);
            f = w/h;
            this.FigureWidth = this.figureheight*this.AspectRatioHeightWidth*f;
            
            set(this.guifig,'position',[0 0 this.FigureWidth this.figureheight]);
            movegui(this.guifig,'center');
            set(this.guifig,'visible','on');
            
        end
        
        function tb=createToolbar(this, fig)
            tb = uitoolbar('parent',fig);

            hpt=[];
            hpt(end+1) = uipushtool(tb,'CData',localLoadIconCData('file_new.png'),...
                         'TooltipString','New ROI',...
                         'ClickedCallback',...
                         @this.newROI);
            hpt(end+1) = uipushtool(tb,'CData',localLoadIconCData('file_open.png'),...
                         'TooltipString','Open ROI',...
                         'ClickedCallback',...
                         @this.openROI);   
            hpt(end+1) = uipushtool(tb,'CData',localLoadIconCData('file_save.png'),...
                         'TooltipString','Save ROI',...
                         'ClickedCallback',...
                         @this.saveROI);      

            %---
            hpt(end+1) = uitoggletool(tb,'CData',localLoadIconCData('tool_zoom_in.png'),...
                         'TooltipString','Zoom In',...
                         'ClickedCallback',...
                         'putdowntext(''zoomin'',gcbo)',...
                        'Separator','on');                
            hpt(end+1) = uitoggletool(tb,'CData',localLoadIconCData('tool_zoom_out.png'),...
                         'TooltipString','Zoom Out',...
                         'ClickedCallback',...
                         'putdowntext(''zoomout'',gcbo)');     
            hpt(end+1) = uitoggletool(tb,'CData',localLoadIconCData('tool_hand.png'),...
                         'TooltipString','Pan',...
                         'ClickedCallback',...
                         'putdowntext(''pan'',gcbo)');    
        end      
    end  % end private methods
end


% this is copied from matlabs uitoolfactory.m, to load the icons for the toolbar
function cdata = localLoadIconCData(filename)
% Loads CData from the icon files (PNG, GIF or MAT) in toolbox/matlab/icons.
% filename = info.icon;

    % Load cdata from *.gif file
    persistent ICONROOT
    if isempty(ICONROOT)
        ICONROOT = fullfile(matlabroot,'toolbox','matlab','icons',filesep);
    end

    if length(filename)>3 && strncmp(filename(end-3:end),'.gif',4)
        [cdata,map] = imread([ICONROOT,filename]);
        % Set all white (1,1,1) colors to be transparent (nan)
        ind = map(:,1)+map(:,2)+map(:,3)==3;
        map(ind) = NaN;
        cdata = ind2rgb(cdata,map);

        % Load cdata from *.png file
    elseif length(filename)>3 && strncmp(filename(end-3:end),'.png',4)
        [cdata map alpha] = imread([ICONROOT,filename],'Background','none');
        % Converting 16-bit integer colors to MATLAB colorspec
        cdata = double(cdata) / 65535.0;
        % Set all transparent pixels to be transparent (nan)
        cdata(alpha==0) = NaN;

        % Load cdata from *.mat file
    else
        temp = load([ICONROOT,filename],'cdata');
        cdata = temp.cdata;
    end
end

