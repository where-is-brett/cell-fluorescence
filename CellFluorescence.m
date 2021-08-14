classdef CellFluorescence < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                      matlab.ui.Figure
        FileMenu                      matlab.ui.container.Menu
        SaveMenu                      matlab.ui.container.Menu
        SaveMaskMenu                  matlab.ui.container.Menu
        SaveResultsMenu               matlab.ui.container.Menu
        LoadMenu                      matlab.ui.container.Menu
        LoadMaskMenu                  matlab.ui.container.Menu
        HelpMenu                      matlab.ui.container.Menu
        DemonstrationMenu             matlab.ui.container.Menu
        ContactMenu                   matlab.ui.container.Menu
        BrettYangLabel                matlab.ui.control.Label
        Version013Label               matlab.ui.control.Label
        CalculateCTCFButton           matlab.ui.control.Button
        LabelRegionsofInterestButton  matlab.ui.control.Button
        ROISelectionChannelDropDown   matlab.ui.control.DropDown
        ROISelectionChannelDropDownLabel  matlab.ui.control.Label
        MeasureBlueChannelCheckBox    matlab.ui.control.CheckBox
        MeasureGreenChannelCheckBox   matlab.ui.control.CheckBox
        MeasureRedChannelCheckBox     matlab.ui.control.CheckBox
        LoadButton                    matlab.ui.control.Button
        ImageAxes                     matlab.ui.control.UIAxes
    end


    properties (Access = private)
        %%%%%%% APP Properties %%%%%%%
        ROISelectionChannel = 2 % Green channel by default
        MeasurementChannels = [0,2,0] % when all activated [1,2,3]; green by default
        Masks
        InstanceMask
        InstanceMaskLoaded
        NumberOfROIs
        Image % to load: display image
        LabellerObject %%% Custom Class Object

        % Results are stored as table objects
        ResultsRed
        ResultsGreen
        ResultsBlue
        ResultsGrey

        % App Components
        RGBcomponents
        StartDisabledComponents
    end

    % App methods
    methods (Access = private)
        % Function to bring main UI window back to front
        function bringtofront(app, component)
            % Bring window back to front
            component.Visible = 'off';
            component.Visible = 'on';
        end


        %%% Function to instantiate custom class object
        function this = CTCFLabeller(image)
            app.LabellerObject = CTCFLabeller(app.Image); %initialised here
        end

        % Function to update image
        function updateimage(app,imagefile)
            try
                im = imread(imagefile);
                % Enable other functions once image has been loaded
                set(app.LabelRegionsofInterestButton, 'Enable', 'on');
            catch ME
                % If problem reading image, display error message
                uialert(app.UIFigure, ME.message, 'Image Error');
                return;
            end
            app.Image = im;
            % Display image based on the number of colour channels
            switch size(im,3)
                case 1
                    % Display the grayscale image
                    app.ImageAxes.Colormap = gray(256);
                    imagesc(app.ImageAxes,im);
                    % Enable ROI labeller
                    set(app.LabelRegionsofInterestButton, 'Enable', 'on');
                case 3
                    % Display the truecolor image
                    imagesc(app.ImageAxes,im);
                    % Enable ROI labeller and 'ROI selection channel'
                    set([app.LabelRegionsofInterestButton, app.ROISelectionChannelDropDown], 'Enable', 'on');
                otherwise
                    % Error when image is not grayscale or truecolor
                    uialert(app.UIFigure, 'Image must be grayscale or truecolor.', 'Image Error');
                    return;
            end
        end

        % Function to compute CTCF from region masks
        function [means, areas, IntDens,CTCFs] = measure(app, GreyImage)
            % Delcarte arrays (or whatever name it has) to store numberical data
            means = zeros(1,app.NumberOfROIs/2);
            IntDens = zeros(1,app.NumberOfROIs/2);
            areas = zeros(1,app.NumberOfROIs/2);
            for i=1:app.NumberOfROIs
                % create region segments
                roi_data = double(GreyImage(app.Masks{i}));
                % Distinguish between foreground and background by checking whether
                % the index is even or not.
                % We calculate IntDen and cell area for foreground objects
                if rem(i,2) % ODD
                    odd_index = 1 + (i-1)/2; % Convert index back to natural number sequence
                    IntDen_of_roi_i = sum(roi_data);
                    area_of_roi_i = numel(roi_data);
                    % Store data to array
                    IntDens(odd_index) = IntDen_of_roi_i;
                    areas(odd_index) = area_of_roi_i;
                    % Otherwise for background noise we take the mean value
                else % EVEN
                    even_index = i/2; % Convert index back to natural number sequence
                    mean_of_roi_i = mean(roi_data);
                    % Store data to array
                    means(even_index) = mean_of_roi_i;
                end
            end
            % We calculate CTCF according to the following equation:
            % CTCF = Integrated Density – (Area of selected cell * Mean background)
            % in the context of array operations this translate to:
            CTCFs = IntDens - (areas.*means);
        end
        
        % Function to measure CTCF from laoded instance mask
        function [means, areas, IntDens,CTCFs] = measureLoaded(app, GreyImage)
            % Delcarte arrays (or whatever name it has) to store numberical data
            means = zeros(1,app.NumberOfROIs/2);
            IntDens = zeros(1,app.NumberOfROIs/2);
            areas = zeros(1,app.NumberOfROIs/2);
            for i=1:app.NumberOfROIs
                % create region segments
                roi_data = double(GreyImage(app.InstanceMaskLoaded==i));
                % Distinguish between foreground and background by checking whether
                % the index is even or not.
                % We calculate IntDen and cell area for foreground objects
                if rem(i,2) % ODD
                    odd_index = 1 + (i-1)/2; % Convert index back to natural number sequence
                    IntDen_of_roi_i = sum(roi_data);
                    area_of_roi_i = numel(roi_data);
                    % Store data to array
                    IntDens(odd_index) = IntDen_of_roi_i;
                    areas(odd_index) = area_of_roi_i;
                    % Otherwise for background noise we take the mean value
                else % EVEN
                    even_index = i/2; % Convert index back to natural number sequence
                    mean_of_roi_i = mean(roi_data);
                    % Store data to array
                    means(even_index) = mean_of_roi_i;
                end
            end
            % We calculate CTCF according to the following equation:
            % CTCF = Integrated Density – (Area of selected cell * Mean background)
            % in the context of array operations this translate to:
            CTCFs = IntDens - (areas.*means);
        end


        % Helper function to create and display results in a table
        function CreateTable(app, means, areas, IntDens, CTCFs, channel)
            %% Display CTCF and Integrated Density
            T = table(transpose(means), transpose(areas), transpose(IntDens), ...
                transpose(CTCFs), 'VariableNames', ...
                {'Mean Background','Cellular Area','Integrated Density','CTCF'});

            % distinguish colour channel
            if channel == 1 % Red
                app.ResultsRed = T; % store table data and corresponding channel name
                fig = figure('NumberTitle','off', 'Name','Red Channel', 'Color',[1 0.8 0.8]);
            elseif channel == 2 % Green
                app.ResultsGreen = T;
                fig = figure('NumberTitle','off', 'Name','Green Channel', 'Color',[0.8 1 0.8]);
            elseif channel == 3 % Blue
                app.ResultsBlue = T;
                fig = figure('NumberTitle','off', 'Name','Blue Channel', 'Color',[0.8 0.89804 1]);
            elseif channel == 0 % grey
                app.ResultsGrey = T;
                fig = figure('NumberTitle','off', 'Name','Grey Image');
            end
            % Create UI table
            T = uitable(fig, 'Data',T{:,:},'ColumnName',T.Properties.VariableNames,...
                'RowName',T.Properties.RowNames,'Units', 'Normalized', 'Position',[0, 0, 1, 1]);
            % Display table
            disp(T);
        end
    end   %end private methods


    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            % Configure image axes
            disableDefaultInteractivity(app.ImageAxes); % prevent image from moving around
            app.ImageAxes.Visible = 'on';
            axis(app.ImageAxes, 'image');
            startpage = imread("start_page.png");
            imagesc(app.ImageAxes,startpage);
            
            
            % List all components
            app.RGBcomponents = [app.MeasureRedChannelCheckBox, ...
                app.MeasureGreenChannelCheckBox, ...
                app.MeasureBlueChannelCheckBox, ...
                app.ROISelectionChannelDropDown];
            app.StartDisabledComponents = [app.CalculateCTCFButton, ...
                app.LabelRegionsofInterestButton, ...
                app.SaveResultsMenu, ...
                app.SaveMaskMenu...
                app.LoadMaskMenu...
                app.RGBcomponents];
            % Disable components at start up - enable them when
            % they become meaningful
            set(app.StartDisabledComponents, 'Enable', 'off');

        end

        % Value changed function: ROISelectionChannelDropDown
        function DropDownValueChanged(app, event)

            channel = app.ROISelectionChannelDropDown.Value;
            if channel == "Red"
                app.ROISelectionChannel = 1;
            elseif channel == "Green"
                app.ROISelectionChannel = 2;
            elseif channel == "Blue"
                app.ROISelectionChannel = 3;
            end

        end

        % Button pushed function: LoadButton
        function LoadButtonPushed(app, event)

            % First turn of visibility of main UI
            app.UIFigure.Visible = 'off';

            % Display uigetfile dialog
            filterspec = {'*.jpg;*.tif;*.png;*.gif','All Image Files'};
            [f, p] = uigetfile(filterspec, 'Select Image for CTCF Measurements');
            % Make sure user didn't cancel uigetfile dialog
            if (ischar(p))
                fname = [p f];
                updateimage(app, fname);
            end
            
            % Once an image is loaded, user can load an instance mask
            set(app.LoadMaskMenu, 'Enable', 'on');
            
            % When done, switch visibility back on
            app.UIFigure.Visible = 'on';
        end

        % Button pushed function: CalculateCTCFButton
        function CalculateCTCFButtonPushed(app, event)
            % Close all previous figures upon click
            close all;
            
            if ~isempty(app.InstanceMaskLoaded)
                if size(app.Image,3) == 1
                    channel = 0;
                    [means,IntDens,areas,CTCFs] = measureLoaded(app, app.Image);
                    CreateTable(app, means, IntDens, areas, CTCFs, channel);
                else
                    for ch=1:length(app.MeasurementChannels)
                        channel = app.MeasurementChannels(ch);
                        if channel
                            [means,areas,IntDens,CTCFs] = measureLoaded(app, app.Image(:,:,channel));
                            CreateTable(app, means, areas, IntDens, CTCFs, channel);
                        end
                    end
                end
                % Now enable saving option
                set(app.SaveResultsMenu, 'Enable', 'on');
            else
                if size(app.Image,3) == 1
                    channel = 0;
                    [means,IntDens,areas,CTCFs] = measure(app, app.Image);
                    CreateTable(app, means, IntDens, areas, CTCFs, channel);
                else
                    for ch=1:length(app.MeasurementChannels)
                        channel = app.MeasurementChannels(ch);
                        if channel
                            [means,areas,IntDens,CTCFs] = measure(app, app.Image(:,:,channel));
                            CreateTable(app, means, areas, IntDens, CTCFs, channel);
                        end
                    end
                end
                % Now enable saving option
                set(app.SaveResultsMenu, 'Enable', 'on');
            end
            
            
            
            % Bring main UI back to front
            app.UIFigure.Visible = 'off';
            app.UIFigure.Visible = 'on';
        end

        % Button pushed function: LabelRegionsofInterestButton
        function LabelRegionsofInterestButtonPushed(app, event)

            % First turn of visibility of main UI
            app.UIFigure.Visible = 'off';

            % Check whether image is greyscale or true colour
            if size(app.Image,3) == 1
                AnnotationImage = app.Image;
            else
                AnnotationImage = app.Image(:,:,app.ROISelectionChannel); % Select channel to work with
            end
            %%% OOP Activate ROI window from custom class
            roiwindow = CTCFLabeller(AnnotationImage);
            % wait for masks to be assigned
            waitfor(roiwindow,'masks');
            % ROIs defined
            if ~isvalid(roiwindow)
                delete(roiwindow);
                % Bring main UI back to front
                app.UIFigure.Visible = 'on';
                % Activate UI alert
                uialert(app.UIFigure,...
                    'You closed the window before applying ROIs. Data has not been stored.',...
                    'Warning','Icon','warning');
            else
                [app.Masks, ~, app.InstanceMask, app.NumberOfROIs] = roiwindow.getROIData;
                delete(roiwindow);
                app.UIFigure.Visible = 'on';
            end

            % Enable more UI options if masks exist
            if ~isempty(app.Masks)
                set(app.CalculateCTCFButton, 'Enable', 'on');
                set(app.SaveMaskMenu, 'Enable', 'on'); % instance mask is now available
                if size(app.Image,3)==3
                    set(app.RGBcomponents, 'Enable', 'on');
                end
                % If user defined a new mask, then clear the loaded
                % instance mask
                app.InstanceMaskLoaded=[];
            end
            
            
        end

        % Value changed function: MeasureBlueChannelCheckBox
        function MeasureBlueChannelCheckBoxValueChanged(app, event)
            value = app.MeasureBlueChannelCheckBox.Value;
            if value
                app.MeasurementChannels(3) = 3;
            else
                app.MeasurementChannels(3) = 0;
            end
        end

        % Value changed function: MeasureGreenChannelCheckBox
        function MeasureGreenChannelCheckBoxValueChanged(app, event)
            value = app.MeasureGreenChannelCheckBox.Value;
            if value
                app.MeasurementChannels(2) = 2;
            else
                app.MeasurementChannels(2) = 0;
            end
        end

        % Value changed function: MeasureRedChannelCheckBox
        function MeasureRedChannelCheckBoxValueChanged(app, event)
            value = app.MeasureRedChannelCheckBox.Value;
            if value
                app.MeasurementChannels(1) = 1;
            else
                app.MeasurementChannels(1) = 0;
            end
        end

        % Button down function: ImageAxes
        function ImageAxesButtonDown(app, event)

        end

        % Menu selected function: DemonstrationMenu
        function DemonstrationMenuSelected(app, event)
            DemoURL = 'https://www.brettyang.info/projects/CTCF';
            web(DemoURL);
        end

        % Menu selected function: ContactMenu
        function ContactMenuSelected(app, event)
            ContactFormURL = 'https://www.brettyang.info/contact';
            web(ContactFormURL);
        end

        % Callback function
        function SaveResultsMenu_2Selected(app, event)
            app.UIFigure.Visible = 'off';
            
            % Ask user to choose file dir and name
            filter = {'*.xls';'*.xlsm';'*.xlsx';'*.xlsb'};
            [file, path] = uiputfile(filter);
            if ~file % User clicked the Cancel button.
                app.UIFigure.Visible = 'on';
                return
            end
            filename = fullfile(path, file);
            
            % Write all table data to excel file
            if ~isempty(app.ResultsRed)
                writetable(app.ResultsRed, filename, 'Sheet', sprintf('%s', 'Red Channel'));
            end
            if ~isempty(app.ResultsGreen)
                writetable(app.ResultsGreen, filename, 'Sheet', sprintf('%s', 'Green Channel'));
            end
            if ~isempty(app.ResultsBlue)
                writetable(app.ResultsBlue, filename, 'Sheet', sprintf('%s', 'Blue Channel'));
            end
            if ~isempty(app.ResultsGrey)
                writetable(app.ResultsGrey, filename, 'Sheet', sprintf('%s', 'Grey Channel'));
            end
            
            app.UIFigure.Visible = 'on';
        end

        % Menu selected function: SaveResultsMenu
        function SaveResultsMenuSelected(app, event)
            app.UIFigure.Visible = 'off';

            % Ask user to choose file dir and name
            filter = {'*.xls';'*.xlsm';'*.xlsx';'*.xlsb'};
            [file, path] = uiputfile(filter);
            if ~file % User clicked the Cancel button.
                app.UIFigure.Visible = 'on';
                return
            end
            filename = fullfile(path, file);

            % Write all table data to excel file
            if ~isempty(app.ResultsRed)
                writetable(app.ResultsRed, filename, 'Sheet', sprintf('%s', 'Red Channel'));
            end
            if ~isempty(app.ResultsGreen)
                writetable(app.ResultsGreen, filename, 'Sheet', sprintf('%s', 'Green Channel'));
            end
            if ~isempty(app.ResultsBlue)
                writetable(app.ResultsBlue, filename, 'Sheet', sprintf('%s', 'Blue Channel'));
            end
            if ~isempty(app.ResultsGrey)
                writetable(app.ResultsGrey, filename, 'Sheet', sprintf('%s', 'Grey Channel'));
            end

            app.UIFigure.Visible = 'on';
        end

        % Menu selected function: SaveMaskMenu
        function SaveMaskMenuSelected(app, event)
            
            app.UIFigure.Visible = 'off';

            % Ask user to choose file dir and name
            filter = {'*.png';};
            [file, path] = uiputfile(filter);
            if ~file % User clicked the Cancel button.
                app.UIFigure.Visible = 'on';
                return
            end
            filename = fullfile(path, file);
            
            % write mask to file
            imwrite(app.InstanceMask, filename);

            app.UIFigure.Visible = 'on';
        end

        % Menu selected function: LoadMaskMenu
        function LoadMaskMenuSelected(app, event)
            app.UIFigure.Visible = 'off';

            % Ask user to choose file dir and name
            filter = {'*.png'};
            [file, path] = uigetfile(filter);
            if ~file % User clicked the Cancel button.
                app.UIFigure.Visible = 'on';
                return
            end
            
            filename = fullfile(path, file);
            mask = imread(filename);
            
            if size(mask) == size(app.Image,1,2)
                app.InstanceMaskLoaded = mask;
                % Once instance mask has been loaded, allow calculation
                set(app.CalculateCTCFButton, 'Enable', 'on');
            else
                uialert('Mask and image dimensions do not match.');
            end
            app.UIFigure.Visible = 'on';
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.AutoResizeChildren = 'off';
            app.UIFigure.Position = [100 100 730 409];
            app.UIFigure.Name = 'Measure Cell Fluorescense';
            app.UIFigure.Resize = 'off';

            % Create FileMenu
            app.FileMenu = uimenu(app.UIFigure);
            app.FileMenu.Text = 'File';

            % Create SaveMenu
            app.SaveMenu = uimenu(app.FileMenu);
            app.SaveMenu.Text = 'Save';

            % Create SaveMaskMenu
            app.SaveMaskMenu = uimenu(app.SaveMenu);
            app.SaveMaskMenu.MenuSelectedFcn = createCallbackFcn(app, @SaveMaskMenuSelected, true);
            app.SaveMaskMenu.Text = 'Save Mask';

            % Create SaveResultsMenu
            app.SaveResultsMenu = uimenu(app.SaveMenu);
            app.SaveResultsMenu.MenuSelectedFcn = createCallbackFcn(app, @SaveResultsMenuSelected, true);
            app.SaveResultsMenu.Text = 'Save Results';

            % Create LoadMenu
            app.LoadMenu = uimenu(app.FileMenu);
            app.LoadMenu.Text = 'Load';

            % Create LoadMaskMenu
            app.LoadMaskMenu = uimenu(app.LoadMenu);
            app.LoadMaskMenu.MenuSelectedFcn = createCallbackFcn(app, @LoadMaskMenuSelected, true);
            app.LoadMaskMenu.Text = 'Load Mask';

            % Create HelpMenu
            app.HelpMenu = uimenu(app.UIFigure);
            app.HelpMenu.Text = 'Help';

            % Create DemonstrationMenu
            app.DemonstrationMenu = uimenu(app.HelpMenu);
            app.DemonstrationMenu.MenuSelectedFcn = createCallbackFcn(app, @DemonstrationMenuSelected, true);
            app.DemonstrationMenu.Text = 'Demonstration';

            % Create ContactMenu
            app.ContactMenu = uimenu(app.HelpMenu);
            app.ContactMenu.MenuSelectedFcn = createCallbackFcn(app, @ContactMenuSelected, true);
            app.ContactMenu.Text = 'Contact';

            % Create ImageAxes
            app.ImageAxes = uiaxes(app.UIFigure);
            app.ImageAxes.Toolbar.Visible = 'off';
            app.ImageAxes.FontName = 'Avenir';
            app.ImageAxes.XColor = 'none';
            app.ImageAxes.XTick = [];
            app.ImageAxes.XTickLabel = '';
            app.ImageAxes.YColor = 'none';
            app.ImageAxes.YTick = [];
            app.ImageAxes.ZColor = 'none';
            app.ImageAxes.GridColor = 'none';
            app.ImageAxes.MinorGridColor = 'none';
            app.ImageAxes.ButtonDownFcn = createCallbackFcn(app, @ImageAxesButtonDown, true);
            app.ImageAxes.Position = [330 32 365 354];

            % Create LoadButton
            app.LoadButton = uibutton(app.UIFigure, 'push');
            app.LoadButton.ButtonPushedFcn = createCallbackFcn(app, @LoadButtonPushed, true);
            app.LoadButton.FontName = 'Avenir';
            app.LoadButton.Position = [46 338 242 39];
            app.LoadButton.Text = '1. Load Image';

            % Create MeasureRedChannelCheckBox
            app.MeasureRedChannelCheckBox = uicheckbox(app.UIFigure);
            app.MeasureRedChannelCheckBox.ValueChangedFcn = createCallbackFcn(app, @MeasureRedChannelCheckBoxValueChanged, true);
            app.MeasureRedChannelCheckBox.Text = 'Measure Red Channel';
            app.MeasureRedChannelCheckBox.FontName = 'Avenir';
            app.MeasureRedChannelCheckBox.Position = [48 174 140 22];

            % Create MeasureGreenChannelCheckBox
            app.MeasureGreenChannelCheckBox = uicheckbox(app.UIFigure);
            app.MeasureGreenChannelCheckBox.ValueChangedFcn = createCallbackFcn(app, @MeasureGreenChannelCheckBoxValueChanged, true);
            app.MeasureGreenChannelCheckBox.Text = 'Measure Green Channel';
            app.MeasureGreenChannelCheckBox.FontName = 'Avenir';
            app.MeasureGreenChannelCheckBox.Position = [48 141 152 22];
            app.MeasureGreenChannelCheckBox.Value = true;

            % Create MeasureBlueChannelCheckBox
            app.MeasureBlueChannelCheckBox = uicheckbox(app.UIFigure);
            app.MeasureBlueChannelCheckBox.ValueChangedFcn = createCallbackFcn(app, @MeasureBlueChannelCheckBoxValueChanged, true);
            app.MeasureBlueChannelCheckBox.Text = 'Measure Blue Channel';
            app.MeasureBlueChannelCheckBox.FontName = 'Avenir';
            app.MeasureBlueChannelCheckBox.Position = [48 109 143 22];

            % Create ROISelectionChannelDropDownLabel
            app.ROISelectionChannelDropDownLabel = uilabel(app.UIFigure);
            app.ROISelectionChannelDropDownLabel.HorizontalAlignment = 'right';
            app.ROISelectionChannelDropDownLabel.FontName = 'Avenir';
            app.ROISelectionChannelDropDownLabel.Position = [46 289 126 22];
            app.ROISelectionChannelDropDownLabel.Text = 'ROI Selection Channel';

            % Create ROISelectionChannelDropDown
            app.ROISelectionChannelDropDown = uidropdown(app.UIFigure);
            app.ROISelectionChannelDropDown.Items = {'Red', 'Green', 'Blue'};
            app.ROISelectionChannelDropDown.ValueChangedFcn = createCallbackFcn(app, @DropDownValueChanged, true);
            app.ROISelectionChannelDropDown.FontName = 'Avenir';
            app.ROISelectionChannelDropDown.Position = [187 289 100 22];
            app.ROISelectionChannelDropDown.Value = 'Green';

            % Create LabelRegionsofInterestButton
            app.LabelRegionsofInterestButton = uibutton(app.UIFigure, 'push');
            app.LabelRegionsofInterestButton.ButtonPushedFcn = createCallbackFcn(app, @LabelRegionsofInterestButtonPushed, true);
            app.LabelRegionsofInterestButton.FontName = 'Avenir';
            app.LabelRegionsofInterestButton.Position = [45 222 242 39];
            app.LabelRegionsofInterestButton.Text = '2. Label Regions of Interest';

            % Create CalculateCTCFButton
            app.CalculateCTCFButton = uibutton(app.UIFigure, 'push');
            app.CalculateCTCFButton.ButtonPushedFcn = createCallbackFcn(app, @CalculateCTCFButtonPushed, true);
            app.CalculateCTCFButton.FontName = 'Avenir';
            app.CalculateCTCFButton.Position = [47 43 241 39];
            app.CalculateCTCFButton.Text = '3. Calculate CTCF';

            % Create Version013Label
            app.Version013Label = uilabel(app.UIFigure);
            app.Version013Label.FontName = 'Avenir';
            app.Version013Label.Position = [11 3 75 22];
            app.Version013Label.Text = 'Version 0.1.3';

            % Create BrettYangLabel
            app.BrettYangLabel = uilabel(app.UIFigure);
            app.BrettYangLabel.FontName = 'Avenir';
            app.BrettYangLabel.Position = [616 3 104 22];
            app.BrettYangLabel.Text = '© 2021 Brett Yang';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = CellFluorescence

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end