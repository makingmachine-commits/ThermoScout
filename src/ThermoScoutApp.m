classdef ThermoScoutApp < matlab.apps.AppBase

    properties (Access = public)
        UIFigure
        MainGrid

        HeaderPanel
        TitleLabel
        SubtitleLabel
        StatusLabel

        ControlPanel
        QueryLabel
        QueryEditField
        SearchButton
        SearchResultsTable
        AddPaperButton
        SelectedRowLabel
        SelectedRowEditField
        CorpusLabel
        CorpusDropDown
        RefreshButton
        AnalyzeButton
        ExportButton

        ResultPanel
        PaperTitleLabel
        PaperMetaLabel
        AbstractTextArea

        TabGroup
        ExtractionTab
        LimitationsTab
        DirectionsTab
        RelatedPapersTab
        LogTab

        ExtractionTextArea
        LimitationsTextArea
        DirectionsTextArea
        RelatedPapersTextArea
        LogTextArea
    end

    properties (Access = private)
        cfg
        papers
        searchIndex
        searchResults
        targetRow
        extraction
        limitations
        proposals
        recommendations
        validationReport
    end

    methods (Access = private)

        function startup(app)

            app.cfg.dataDir = fullfile(pwd, "..", "data");
            app.cfg.outputDir = fullfile(pwd, "..", "outputs");
            app.cfg.promptDir = fullfile(pwd, "..", "prompts");
            app.cfg.papersCSV = fullfile(app.cfg.dataDir, "papers.csv");

            app.cfg.llmProvider = "ollama";
            app.cfg.ollamaModel = "llama3.1:latest";
            app.cfg.topK = 2;

            if ~isfolder(app.cfg.outputDir)
                mkdir(app.cfg.outputDir);
            end

            if ~isfolder(fullfile(app.cfg.outputDir, "reports"))
                mkdir(fullfile(app.cfg.outputDir, "reports"));
            end

            if ~isfolder(fullfile(app.cfg.outputDir, "paper_cards"))
                mkdir(fullfile(app.cfg.outputDir, "paper_cards"));
            end

            app.loadCorpus();

            app.StatusLabel.Text = "Ready";
            app.writeLog("Application initialized.");
            app.writeLog(sprintf("Loaded %d papers from the local corpus.", ...
                height(app.papers)));

        end

        function loadCorpus(app)

            if ~isfile(app.cfg.papersCSV)
                uialert(app.UIFigure, ...
                    "papers.csv was not found. Check the data directory.", ...
                    "Corpus Error");
                return;
            end

            app.papers = load_corpus(app.cfg.papersCSV);
            app.searchIndex = build_search_index(app.papers);

            paperOptions = strings(height(app.papers), 1);

            for i = 1:height(app.papers)
                paperOptions(i) = app.papers.id(i) + " | " + ...
                    app.papers.title(i);
            end

            app.CorpusDropDown.Items = cellstr(paperOptions);

            if ~isempty(paperOptions)
                app.CorpusDropDown.Value = app.CorpusDropDown.Items{1};
                app.selectCorpusPaper();
            end

        end

        function selectCorpusPaper(app)

            selectedValue = string(app.CorpusDropDown.Value);

            parts = split(selectedValue, " | ");
            targetID = parts(1);

            app.targetRow = app.papers(app.papers.id == targetID, :);

            if isempty(app.targetRow)
                app.writeLog("Selected corpus paper could not be found.");
                return;
            end

            app.updatePaperPreview();
            app.StatusLabel.Text = "Corpus paper selected";
            app.writeLog("Selected corpus paper: " + app.targetRow.title(1));

        end

        function updatePaperPreview(app)

            if isempty(app.targetRow)
                return;
            end

            app.PaperTitleLabel.Text = app.targetRow.title(1);

            yearText = string(app.targetRow.year(1));
            doiText = app.targetRow.doi(1);
            sourceText = app.targetRow.source(1);

            app.PaperMetaLabel.Text = ...
                "Year: " + yearText + ...
                "    Source: " + sourceText + ...
                "    DOI/URL: " + doiText;

            app.AbstractTextArea.Value = splitlines( ...
                string(app.targetRow.abstract(1)) ...
            );

        end

        function searchPaper(app)

            queryText = strtrim(string(app.QueryEditField.Value));

            if queryText == ""
                uialert(app.UIFigure, ...
                    "Enter a paper title or search keyword first.", ...
                    "Missing Query");
                return;
            end

            app.setBusyState(true, "Searching Semantic Scholar...");
            app.writeLog("Search started: " + queryText);

            try
                app.searchResults = search_semantic_scholar_results(queryText);
                app.SelectedRowEditField.Value = 1;

                if isempty(app.searchResults)
                    app.SearchResultsTable.Data = {};
                    app.setBusyState(false, "No results found");
                    app.writeLog("No papers found.");
                    return;
                end

            displayData = cell( ...
                height(app.searchResults), 3 ...
            );

            displayData(:, 1) = cellstr(string(app.searchResults.title));
            displayData(:, 2) = cellstr(string(app.searchResults.year));
            displayData(:, 3) = cellstr(string(app.searchResults.venue));

            app.SearchResultsTable.Data = displayData;

            app.SearchResultsTable.ColumnName = { ...
                "Title", "Year", "Venue" ...
            };

            app.setBusyState(false, ...
                string(height(app.searchResults)) + " papers found");

            app.writeLog( ...
                string(height(app.searchResults)) + " papers returned." ...
            );

            catch ME
                app.writeLog("Search error: " + string(ME.message));
                app.setBusyState(false, "Search failed");

                uialert(app.UIFigure, ME.message, "Search Error");
            end

        end
        function addSelectedSearchPaper(app)

            if isempty(app.searchResults)
                uialert(app.UIFigure, ...
                    "Search for papers before adding one.", ...
                    "No Search Results");
                return;
            end

            selectedRowIndex = round(app.SelectedRowEditField.Value);

            if isempty(selectedRowIndex) || isnan(selectedRowIndex)
                uialert(app.UIFigure, ...
                    "Enter a paper number before adding a paper.", ...
                    "No Paper Selected");
                return;
            end

            if selectedRowIndex < 1 || ...
                    selectedRowIndex > height(app.searchResults)

                uialert(app.UIFigure, ...
                    "Select a valid paper row.", ...
                    "Invalid Selection");
                return;
            end

            selected = app.searchResults(selectedRowIndex, :);

            selectedPaper = struct();
            selectedPaper.title = string(selected.title(1));
            selectedPaper.year = string(selected.year(1));
            selectedPaper.doi = string(selected.doi(1));
            selectedPaper.abstract = string(selected.abstract(1));
            selectedPaper.url = string(selected.url(1));
            selectedPaper.source = "Semantic Scholar";

            app.setBusyState(true, "Adding paper to corpus...");

            try
                [app.papers, newID] = append_paper_to_corpus( ...
                    app.papers, selectedPaper, app.cfg.papersCSV ...
                );

                app.searchIndex = build_search_index(app.papers);
                app.refreshCorpusDropdown();

                selectedItem = "";

                for i = 1:numel(app.CorpusDropDown.Items)
                    itemText = string(app.CorpusDropDown.Items{i});

                    if startsWith(itemText, newID + " | ")
                        selectedItem = itemText;
                        break;
                    end
                end

                if selectedItem ~= ""
                    app.CorpusDropDown.Value = char(selectedItem);
                    app.selectCorpusPaper();
                end

                app.writeLog("Paper added to corpus: " + newID);
                app.setBusyState(false, "Paper added");

            catch ME
                app.writeLog("Corpus add error: " + string(ME.message));
                app.setBusyState(false, "Add failed");

                uialert(app.UIFigure, ME.message, "Corpus Error");
            end

        end

        function refreshCorpusDropdown(app)

            paperOptions = strings(height(app.papers), 1);

            for i = 1:height(app.papers)
                paperOptions(i) = app.papers.id(i) + " | " + ...
                    app.papers.title(i);
            end

            app.CorpusDropDown.Items = cellstr(paperOptions);

        end

        function refreshCorpus(app)

            app.setBusyState(true, "Refreshing corpus...");

            try
                app.loadCorpus();
                app.writeLog("Corpus refreshed.");
                app.setBusyState(false, "Corpus refreshed");

            catch ME
                app.writeLog("Corpus refresh error: " + string(ME.message));
                app.setBusyState(false, "Refresh failed");

                uialert(app.UIFigure, ME.message, "Refresh Error");
            end

        end

        function analyzePaper(app)

            if isempty(app.targetRow)
                uialert(app.UIFigure, ...
                    "Select or search for a paper before analysis.", ...
                    "No Paper Selected");
                return;
            end

            targetText = string(app.targetRow.abstract(1));

            if strlength(strtrim(targetText)) < 20
                uialert(app.UIFigure, ...
                    "The selected paper has no usable abstract.", ...
                    "Insufficient Text");
                return;
            end

            app.setBusyState(true, "Running analysis...");
            app.writeLog("Analysis started: " + app.targetRow.title(1));

            try
                app.extraction = extract_structured_info(targetText, app.cfg);
                app.updateExtractionTab();

                app.limitations = analyze_limitations( ...
                    app.extraction, targetText, app.cfg ...
                );
                app.updateLimitationsTab();

                app.proposals = propose_research_directions( ...
                    app.limitations, app.cfg ...
                );
                app.updateDirectionsTab();

                app.recommendations = retrieve_related_papers( ...
                    app.proposals, app.papers, app.searchIndex, app.cfg ...
                );
                app.updateRelatedPapersTab();

                app.validationReport = validate_outputs( ...
                    app.extraction, app.limitations, app.proposals, ...
                    app.recommendations ...
                );

                app.writeLog( ...
                    "Analysis completed. Validation status: " + ...
                    string(app.validationReport.status) ...
                );

                app.setBusyState(false, "Analysis complete");

            catch ME
                app.writeLog("Analysis error: " + string(ME.message));
                app.setBusyState(false, "Analysis failed");

                uialert(app.UIFigure, ME.message, "Analysis Error");
            end

        end

        function exportReport(app)

            if isempty(app.targetRow) || isempty(app.extraction)
                uialert(app.UIFigure, ...
                    "Run analysis before exporting a report.", ...
                    "No Analysis Result");
                return;
            end

            app.setBusyState(true, "Exporting report...");

            try
                generate_report( ...
                    app.targetRow, ...
                    app.extraction, ...
                    app.limitations, ...
                    app.proposals, ...
                    app.recommendations, ...
                    app.validationReport, ...
                    app.cfg ...
                );

                app.writeLog("Report export completed.");
                app.setBusyState(false, "Report exported");

                uialert(app.UIFigure, ...
                    "Report export completed. Check outputs/reports.", ...
                    "Export Complete");

            catch ME
                app.writeLog("Export error: " + string(ME.message));
                app.setBusyState(false, "Export failed");

                uialert(app.UIFigure, ME.message, "Export Error");
            end

        end

        function updateExtractionTab(app)

            if isempty(app.extraction)
                return;
            end

            text = "";

            text = text + "THERMAL PROBLEM" + newline;
            text = text + getStructField(app.extraction, "thermal_problem") + ...
                newline + newline;

            text = text + "PACKAGE TYPE" + newline;
            text = text + getStructField(app.extraction, "package_type") + ...
                newline + newline;

            text = text + "HEAT SOURCE / HOTSPOT" + newline;
            text = text + getStructField( ...
                app.extraction, "heat_source_or_hotspot" ...
            ) + newline + newline;

            text = text + "THERMAL PATH AND SOLUTION" + newline;
            text = text + getStructField( ...
                app.extraction, "thermal_path_and_solution" ...
            ) + newline + newline;

            text = text + "QUANTITATIVE METRICS" + newline;

            if isfield(app.extraction, "quantitative_metrics")
                metrics = app.extraction.quantitative_metrics;

                for i = 1:numel(metrics)
                    metric = metrics(i);

                    text = text + "- " + ...
                        getStructField(metric, "metric") + ": " + ...
                        getStructField(metric, "value") + " " + ...
                        getStructField(metric, "unit") + newline;

                    evidence = getStructField(metric, "evidence");

                    if evidence ~= ""
                        text = text + "  Evidence: " + evidence + newline;
                    end
                end
            else
                text = text + "not reported" + newline;
            end

            app.ExtractionTextArea.Value = splitlines(text);

        end

        function updateLimitationsTab(app)

            if isempty(app.limitations)
                return;
            end

            text = "AUTHOR-STATED LIMITATIONS" + newline;

            if isfield(app.limitations, "author_stated_limitations")
                stated = app.limitations.author_stated_limitations;

                if iscell(stated)
                    stated = string(stated);
                end

                for i = 1:numel(stated)
                    text = text + "- " + string(stated(i)) + newline;
                end
            else
                text = text + "- not reported" + newline;
            end

            text = text + newline + "INFERRED VALIDATION GAPS" + newline;

            if isfield(app.limitations, "inferred_validation_gaps")
                gaps = app.limitations.inferred_validation_gaps;

                for i = 1:numel(gaps)
                    gap = gaps(i);

                    text = text + "- [" + ...
                        getStructField(gap, "category") + "] " + ...
                        getStructField(gap, "limitation") + newline;

                    reasoning = getStructField(gap, "reasoning");

                    if reasoning ~= ""
                        text = text + "  Reasoning: " + reasoning + newline;
                    end
                end
            else
                text = text + "- not reported" + newline;
            end

            app.LimitationsTextArea.Value = splitlines(text);

        end

        function updateDirectionsTab(app)

            if isempty(app.proposals)
                app.DirectionsTextArea.Value = ...
                    "No research directions were generated.";
                return;
            end

            text = "";

            for i = 1:numel(app.proposals)
                proposal = app.proposals(i);

                text = text + "DIRECTION " + string(i) + newline;
                text = text + "Target gap: " + ...
                    getStructField(proposal, "target_gap") + newline;

                text = text + "Hypothesis: " + ...
                    getStructField(proposal, "hypothesis") + newline;

                text = text + "Verification method: " + ...
                    getStructField(proposal, "verification_method") + newline;

                text = text + "Success metric: " + ...
                    getStructField(proposal, "success_metric") + newline;

                text = text + "Trade-off: " + ...
                    getStructField(proposal, "trade_off") + ...
                    newline + newline;
            end

            app.DirectionsTextArea.Value = splitlines(text);

        end

        function updateRelatedPapersTab(app)

            if isempty(app.recommendations)
                app.RelatedPapersTextArea.Value = ...
                    "No related papers were retrieved.";
                return;
            end

            text = "";

            for i = 1:numel(app.recommendations)
                recommendation = app.recommendations(i);

                text = text + "QUERY / GAP" + newline;
                text = text + string(recommendation.target_gap) + ...
                    newline + newline;

                text = text + "RECOMMENDED PAPERS" + newline;

                for k = 1:numel(recommendation.matches)
                    match = recommendation.matches(k);

                    text = text + string(k) + ". " + ...
                        string(match.title) + newline;

                    text = text + "   DOI/URL: " + ...
                        string(match.doi) + newline;

                    text = text + "   Score: " + ...
                        string(round(match.score, 4)) + newline;
                end

                text = text + newline;
            end

            app.RelatedPapersTextArea.Value = splitlines(text);

        end

        function writeLog(app, message)

            timestamp = string(datetime("now", ...
                "Format", "HH:mm:ss"));

            line = "[" + timestamp + "] " + string(message);

            currentLog = string(app.LogTextArea.Value);

            if isempty(currentLog) || ...
                    (numel(currentLog) == 1 && currentLog == "")
                app.LogTextArea.Value = line;
            else
                app.LogTextArea.Value = [currentLog; line];
            end

            drawnow limitrate;

        end

        function setBusyState(app, isBusy, statusText)

            if isBusy
                app.UIFigure.Pointer = "watch";
                app.SearchButton.Enable = "off";
                app.RefreshButton.Enable = "off";
                app.AnalyzeButton.Enable = "off";
                app.ExportButton.Enable = "off";
                app.AddPaperButton.Enable = "off";
            else
                app.SearchButton.Enable = "on";
                app.AddPaperButton.Enable = "on";
                app.RefreshButton.Enable = "on";
                app.AnalyzeButton.Enable = "on";
                app.ExportButton.Enable = "on";
            end

            app.StatusLabel.Text = statusText;
            drawnow;

        end

        function SearchButtonPushed(app, ~)

            app.searchPaper();

        end

        function AddPaperButtonPushed(app, ~)
            app.addSelectedSearchPaper();
        end

        function RefreshButtonPushed(app, ~)

            app.refreshCorpus();

        end

        function CorpusDropDownValueChanged(app, ~)

            app.selectCorpusPaper();

        end

        function AnalyzeButtonPushed(app, ~)

            app.analyzePaper();

        end

        function ExportButtonPushed(app, ~)

            app.exportReport();

        end

        function createComponents(app)

            app.UIFigure = uifigure( ...
                "Visible", "off", ...
                "Position", [50 30 1280 2000], ...
                "Name", "ThermoScout" ...
            );

            app.MainGrid = uigridlayout(app.UIFigure, [4 2]);
            app.MainGrid.RowHeight = {80, 480, 45, "1x"};
            app.MainGrid.ColumnWidth = {400, "1x"};
            app.MainGrid.Padding = [15 15 15 15];
            app.MainGrid.RowSpacing = 12;
            app.MainGrid.ColumnSpacing = 12;

            app.HeaderPanel = uipanel(app.MainGrid);
            app.HeaderPanel.Layout.Row = 1;
            app.HeaderPanel.Layout.Column = [1 2];
            app.HeaderPanel.BorderType = "none";
            app.HeaderPanel.BackgroundColor = [0.08 0.14 0.22];

            headerGrid = uigridlayout(app.HeaderPanel, [2 2]);
            headerGrid.RowHeight = {32, 24};
            headerGrid.ColumnWidth = {"1x", 200};
            headerGrid.Padding = [18 10 18 8];

            app.TitleLabel = uilabel(headerGrid);
            app.TitleLabel.Text = "ThermoScout";
            app.TitleLabel.FontName = "Arial";
            app.TitleLabel.FontSize = 24;
            app.TitleLabel.FontWeight = "bold";
            app.TitleLabel.FontColor = [0.95 0.97 1.00];
            app.TitleLabel.Layout.Row = 1;
            app.TitleLabel.Layout.Column = 1;

            app.SubtitleLabel = uilabel(headerGrid);
            app.SubtitleLabel.Text = ...
                "Packaging Thermal Management Research Agent";
            app.SubtitleLabel.FontName = "Arial";
            app.SubtitleLabel.FontSize = 12;
            app.SubtitleLabel.FontColor = [0.72 0.82 0.95];
            app.SubtitleLabel.Layout.Row = 2;
            app.SubtitleLabel.Layout.Column = 1;

            app.StatusLabel = uilabel(headerGrid);
            app.StatusLabel.Text = "Initializing...";
            app.StatusLabel.FontName = "Arial";
            app.StatusLabel.FontSize = 12;
            app.StatusLabel.FontWeight = "bold";
            app.StatusLabel.FontColor = [0.60 0.95 0.72];
            app.StatusLabel.HorizontalAlignment = "right";
            app.StatusLabel.Layout.Row = [1 2];
            app.StatusLabel.Layout.Column = 2;

            app.ControlPanel = uipanel(app.MainGrid);
            app.ControlPanel.Title = "Paper Selection";
            app.ControlPanel.FontWeight = "bold";
            app.ControlPanel.Layout.Row = 2;
            app.ControlPanel.Layout.Column = 1;

            controlGrid = uigridlayout(app.ControlPanel, [10 2]);
            controlGrid.RowHeight = { ...
                22, ...
                30, ...
                170, ...
                28, ...
                32, ...
                22, ...
                30, ...
                30, ...
                30, ...
                "1x" ...
            };

            controlGrid.ColumnWidth = {"1x", 120};
            controlGrid.Padding = [12 10 12 10];
            controlGrid.RowSpacing = 7;
            controlGrid.ColumnSpacing = 8;
            controlGrid.ColumnWidth = {"1x", 120};
            controlGrid.Padding = [12 10 12 10];
            controlGrid.RowSpacing = 7;
            controlGrid.ColumnSpacing = 8;

            app.QueryLabel = uilabel(controlGrid);
            app.QueryLabel.Text = "Semantic Scholar Search";
            app.QueryLabel.FontWeight = "bold";
            app.QueryLabel.Layout.Row = 1;
            app.QueryLabel.Layout.Column = [1 2];

            app.QueryEditField = uieditfield(controlGrid, "text");
            app.QueryEditField.Placeholder = ...
                "e.g., HBM thermal management";
            app.QueryEditField.Layout.Row = 2;
            app.QueryEditField.Layout.Column = 1;

            app.SearchButton = uibutton(controlGrid, "push");
            app.SearchButton.Text = "Search";
            app.SearchButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @SearchButtonPushed, true);
            app.SearchButton.Layout.Row = 2;
            app.SearchButton.Layout.Column = 2;

            app.SearchResultsTable = uitable(controlGrid);

            app.SearchResultsTable.ColumnName = { ...
                "Title", "Year", "Venue" ...
            };

            app.SearchResultsTable.ColumnEditable = [false false false];

            app.SearchResultsTable.Layout.Row = 3;
            app.SearchResultsTable.Layout.Column = [1 2];



            app.SelectedRowLabel = uilabel(controlGrid);
            app.SelectedRowLabel.Text = "Paper No.";
            app.SelectedRowLabel.HorizontalAlignment = "right";
            app.SelectedRowLabel.Layout.Row = 4;
            app.SelectedRowLabel.Layout.Column = 1;

            app.SelectedRowEditField = uieditfield(controlGrid, "numeric");
            app.SelectedRowEditField.Limits = [1 10];
            app.SelectedRowEditField.RoundFractionalValues = "on";
            app.SelectedRowEditField.Value = 1;
            app.SelectedRowEditField.Layout.Row = 4;
            app.SelectedRowEditField.Layout.Column = 2;

            app.AddPaperButton = uibutton(controlGrid, "push");
            app.AddPaperButton.Text = "Add Selected Paper";
            app.AddPaperButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @AddPaperButtonPushed, true);
            app.AddPaperButton.Layout.Row = 5;
            app.AddPaperButton.Layout.Column = [1 2];

            app.CorpusLabel = uilabel(controlGrid);
            app.CorpusLabel.Text = "Local Corpus";
            app.CorpusLabel.FontWeight = "bold";
            app.CorpusLabel.Layout.Row = 6;
            app.CorpusLabel.Layout.Column = [1 2];

            app.CorpusDropDown = uidropdown(controlGrid);
            app.CorpusDropDown.Items = {};
            app.CorpusDropDown.ValueChangedFcn = ...
                createCallbackFcn(app, @CorpusDropDownValueChanged, true);
            app.CorpusDropDown.Layout.Row = 7;
            app.CorpusDropDown.Layout.Column = [1 2];

            app.RefreshButton = uibutton(controlGrid, "push");
            app.RefreshButton.Text = "Refresh Corpus";
            app.RefreshButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @RefreshButtonPushed, true);
            app.RefreshButton.Layout.Row = 8;
            app.RefreshButton.Layout.Column = [1 2];

            actionPanel = uipanel(app.MainGrid);
            actionPanel.Layout.Row = 3;
            actionPanel.Layout.Column = [1 2];
            actionPanel.BorderType = "none";

            actionGrid = uigridlayout(actionPanel, [1 4]);
            actionGrid.ColumnWidth = {"1x", 180, 180, "1x"};
            actionGrid.Padding = [0 4 0 4];
            actionGrid.ColumnSpacing = 12;

            app.AnalyzeButton = uibutton(actionGrid, "push");
            app.AnalyzeButton.Text = "Run Analysis";
            app.AnalyzeButton.FontWeight = "bold";
            app.AnalyzeButton.FontSize = 14;
            app.AnalyzeButton.BackgroundColor = [0.12 0.45 0.78];
            app.AnalyzeButton.FontColor = [1 1 1];
            app.AnalyzeButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @AnalyzeButtonPushed, true);
            app.AnalyzeButton.Layout.Row = 1;
            app.AnalyzeButton.Layout.Column = 2;

            app.ExportButton = uibutton(actionGrid, "push");
            app.ExportButton.Text = "Export Report";
            app.ExportButton.FontSize = 14;
            app.ExportButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @ExportButtonPushed, true);
            app.ExportButton.Layout.Row = 1;
            app.ExportButton.Layout.Column = 3;

            app.ResultPanel = uipanel(app.MainGrid);
            app.ResultPanel.Title = "Selected Paper";
            app.ResultPanel.FontWeight = "bold";
            app.ResultPanel.Layout.Row = 2;
            app.ResultPanel.Layout.Column = 2;

            resultGrid = uigridlayout(app.ResultPanel, [3 1]);
            resultGrid.RowHeight = {34, 28, "1x"};
            resultGrid.Padding = [12 10 12 10];

            app.PaperTitleLabel = uilabel(resultGrid);
            app.PaperTitleLabel.Text = "No paper selected";
            app.PaperTitleLabel.FontWeight = "bold";
            app.PaperTitleLabel.FontSize = 14;
            app.PaperTitleLabel.FontColor = [0.08 0.20 0.36];
            app.PaperTitleLabel.Layout.Row = 1;

            app.PaperMetaLabel = uilabel(resultGrid);
            app.PaperMetaLabel.Text = "";
            app.PaperMetaLabel.FontSize = 10;
            app.PaperMetaLabel.FontColor = [0.35 0.35 0.35];
            app.PaperMetaLabel.Layout.Row = 2;

            app.AbstractTextArea = uitextarea(resultGrid);
            app.AbstractTextArea.Editable = "off";
            app.AbstractTextArea.FontName = "Arial";
            app.AbstractTextArea.FontSize = 11;
            app.AbstractTextArea.Layout.Row = 3;

            app.TabGroup = uitabgroup(app.MainGrid);
            app.TabGroup.Layout.Row = 4;
            app.TabGroup.Layout.Column = [1 2];

            app.ExtractionTab = uitab(app.TabGroup);
            app.ExtractionTab.Title = "Structured Extraction";

            app.LimitationsTab = uitab(app.TabGroup);
            app.LimitationsTab.Title = "Limitations";

            app.DirectionsTab = uitab(app.TabGroup);
            app.DirectionsTab.Title = "Research Directions";

            app.RelatedPapersTab = uitab(app.TabGroup);
            app.RelatedPapersTab.Title = "Related Papers";

            app.LogTab = uitab(app.TabGroup);
            app.LogTab.Title = "Activity Log";

            app.ExtractionTextArea = uitextarea(app.ExtractionTab);
            app.ExtractionTextArea.Position = [12 12 1218 410];
            app.ExtractionTextArea.Editable = "off";
            app.ExtractionTextArea.FontName = "Consolas";
            app.ExtractionTextArea.FontSize = 12;

            app.LimitationsTextArea = uitextarea(app.LimitationsTab);
            app.LimitationsTextArea.Position = [12 12 1218 410];
            app.LimitationsTextArea.Editable = "off";
            app.LimitationsTextArea.FontName = "Consolas";
            app.LimitationsTextArea.FontSize = 12;

            app.DirectionsTextArea = uitextarea(app.DirectionsTab);
            app.DirectionsTextArea.Position = [12 12 1218 410];
            app.DirectionsTextArea.Editable = "off";
            app.DirectionsTextArea.FontName = "Consolas";
            app.DirectionsTextArea.FontSize = 12;

            app.RelatedPapersTextArea = uitextarea(app.RelatedPapersTab);
            app.RelatedPapersTextArea.Position = [12 12 1218 410];
            app.RelatedPapersTextArea.Editable = "off";
            app.RelatedPapersTextArea.FontName = "Consolas";
            app.RelatedPapersTextArea.FontSize = 12;

            app.LogTextArea = uitextarea(app.LogTab);
            app.LogTextArea.Position = [12 12 1218 410];
            app.LogTextArea.Editable = "off";
            app.LogTextArea.FontName = "Consolas";
            app.LogTextArea.FontSize = 11;

            app.UIFigure.Visible = "on";

        end

    end

    methods (Access = public)

        function app = ThermoScoutApp

            createComponents(app);
            registerApp(app, app.UIFigure);
            runStartupFcn(app, @startup);

            if nargout == 0
                clear app
            end

        end

        function delete(app)

            delete(app.UIFigure);

        end

    end

end

function value = getStructField(s, fieldName)

    if isfield(s, fieldName) && ~isempty(s.(fieldName))
        value = string(s.(fieldName));
    else
        value = "not reported";
    end

end