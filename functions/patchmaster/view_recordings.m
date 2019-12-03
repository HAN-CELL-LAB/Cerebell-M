classdef view_recordings < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        MainFigure     
        MonitorAxes
        StimAxes   
        LoadButton 
        StimList
        StimListText
    end

    
    properties (Access = public)
        data_table
    end
    
    methods (Access = public)
        
        function results = getRecording(app, ind_rec)
            
            dt_ms = 1000/double(app.data_table.SR(ind_rec));
            results = struct('channels', struct(), 'stimulus', struct(), ...
                'dt_ms', dt_ms, 't', '', 'num_sweeps', double(app.data_table.nSweeps(ind_rec)));
            
            % Get monitored channel data
            channel_units = app.data_table.ChUnit{ind_rec};
            channel_names = app.data_table.ChName{ind_rec};
            channel_data  = app.data_table.dataRaw{ind_rec};
            
            num_channels = length(channel_data);
            for ind_chan = 1:num_channels
                chan_unit  = channel_units{ind_chan};
                chan_datum = channel_data{ind_chan};
                
                switch upper(chan_unit)
                    case 'A'
                        chan_unit  = 'nA';
                        chan_datum = chan_datum * 1e9;
                    case 'V'
                        chan_unit  = 'mV';
                        chan_datum = chan_datum * 1e3;
                    otherwise
                        error('%s is not an acceptable channel unit as this point', chan_unit);
                end
                
                channel_units{ind_chan} = chan_unit;
                channel_data{ind_chan} = chan_datum;
            end
            
            results.channels.names = channel_names;
            results.channels.units = channel_units;
            results.channels.data  = channel_data;
            results.channels.num   = num_channels;
            
            % Get stimulus data
            stim_data = app.data_table.stimWave{ind_rec};
            stim_units = app.data_table.stimUnit{ind_rec};
            stim_names = fieldnames(stim_data);
            num_stims = length(stim_names);
            stim_units = cellfun(@(x) x(1), stim_units, 'uni', 0);
            
            results.stimulus.names = stim_names;
            results.stimulus.units = stim_units;
            results.stimulus.data  = cellfun(@(x) stim_data.(x), stim_names, 'uni', 0);
            results.stimulus.num   = num_stims;
            
            % Time vector
            len_dat = size(channel_data{1},1);
            results.t = dt_ms*(0:(len_dat-1));
        end
    end
    
    

    methods (Access = private)

        % Button pushed function: LoadButton
        function LoadButtonPushed(app)
            app.LoadButton.String = 'wait for it ...'; 
            tmp_data = HEKA_Importer.GUI;
            if isempty(tmp_data.RecTable), return; end
            app.data_table = tmp_data.RecTable;
            app.StimList.String = cellfun(@(ind_rec, stim_name) ...
                sprintf('%02d: %s',ind_rec,stim_name), ...
                num2cell(app.data_table.Rec), app.data_table.Stimulus, ...
                'uni', 0);
            app.LoadButton.String = 'Load data'; 
        end

        % Selection changed function: StimList
        function StimListSelectionChanged(app)
            ind_rec = app.StimList.Value;
            data = getRecording(app, ind_rec);
            
            app_axes = [app.MonitorAxes, app.StimAxes]; 
            
            arrayfun(@(x) cla(x, 'reset'), app_axes);
            arrayfun(@(x) cla(x), app_axes);
            arrayfun(@(x) hold(x, 'on'), app_axes);            
            
            chan_ind = 1;
            chan_dat = data.channels.data{chan_ind};
            arrayfun(@(x) plot(app.MonitorAxes, data.t, chan_dat(:,x), '-k'), 1:data.num_sweeps);
            xlabel(app.MonitorAxes, 'time (ms)');
            ylabel(app.MonitorAxes, sprintf('%s (%s)', data.channels.names{chan_ind}, data.channels.units{chan_ind}));
            
            yyaxis(app.StimAxes, 'left');
            stim_ind = 1;
            stim_dat = data.stimulus.data{stim_ind};
            t_stim = (0:(size(stim_dat,1)-1)) * data.dt_ms;
            arrayfun(@(x) plot(app.StimAxes, t_stim, stim_dat(:,x), '-k'), 1:size(stim_dat,2));
            xlabel(app.StimAxes, 'time (ms)');
            app.StimAxes.YAxis(1).Color = 'k';
            app.StimAxes.YAxis(2).Color = 'r';
            ylabel(app.StimAxes, sprintf('%s (%s)', data.stimulus.names{chan_ind}, data.stimulus.units{chan_ind}));
            
            if data.stimulus.num >= 2
                yyaxis(app.StimAxes, 'right');
                stim_ind = 2;
                stim_dat = data.stimulus.data{stim_ind};
                t_stim = (0:(size(stim_dat,1)-1)) * data.dt_ms;
                arrayfun(@(x) plot(app.StimAxes, t_stim, stim_dat(:,x), '-r'), 1:size(stim_dat,2));
                
                ylabel(app.StimAxes, sprintf('%s (%s)', ...
                    data.stimulus.names{stim_ind}, data.stimulus.units{stim_ind}));
            end
        end
    end

    % App initialization and construction
    methods (Access = private)

        % Create MainFigure and components
        function createComponents(app)

            % Create MainFigure
            app.MainFigure = figure(...
                'Units', 'normalized', ...
                'WindowState', 'maximized'); 

            % Create MonitorAxes           
            app.MonitorAxes = axes(app.MainFigure, ...
                'Units', 'normalized', ...
                'Position', [0.1, 0.5, 0.7, 0.45], ...
                'TickDir', 'out');
            title(app.MonitorAxes, 'Monitored channels'); 
            
            % Create StimAxes
            app.StimAxes = axes(app.MainFigure, ...
                'Units', 'normalized', ...
                'Position', [0.1, 0.07, 0.7, 0.22], ...
                'TickDir', 'out');
            title(app.StimAxes, 'Stimulus channels'); 

            % Create StimListText
            app.StimListText = uicontrol(app.MainFigure, ...
                'Style', 'text', ...
                'Units', 'normalized', ...
                'Position', [0.85, 0.75, 0.1, 0.05], ...
                'FontSize', 15, ...
                'String', 'Stimulation list', ...
                'BackgroundColor', 'w'); 
            
            % Create LoadButton
            app.LoadButton = uicontrol(app.MainFigure, ...
                'Units', 'normalized', ...
                'Position', [0.85, 0.1, 0.1, 0.05], ...
                'Style', 'pushbutton', ...
                'String', 'Load data', ...
                'FontSize', 15, ...
                'Callback',  @(src, ev) LoadButtonPushed(app)); 
            
            % Create StimList
            app.StimList = uicontrol(app.MainFigure, ...
                'Style', 'popupmenu', ...
                'Units', 'normalized', ...
                'FontSize', 15, ...
                'Position', [0.85, 0.5, 0.1, 0.2], ...
                'CallBack', @(src, ev) StimListSelectionChanged(app));
            
        end
    end

    methods (Access = public)

        % Construct app
        function app = view_recordings

            % Create and configure components
            createComponents(app);
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete MainFigure when app is deleted
            delete(app.MainFigure);
        end
    end
end