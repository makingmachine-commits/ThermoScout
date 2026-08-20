%% ThermoScout pipeline entry point.

%% 0. Configuration
cfg.dataDir      = fullfile(pwd, "..", "data");
cfg.outputDir    = fullfile(pwd, "..", "outputs");
cfg.promptDir    = fullfile(pwd, "..", "prompts");
cfg.papersCSV    = fullfile(cfg.dataDir, "papers.csv");
cfg.llmProvider = "ollama";
cfg.ollamaModel = "llama3.1:latest";
cfg.topK         = 2;          % number of related papers to recommend

if ~isfile(cfg.papersCSV)
    error("papers.csv not found at %s. See README.md for required format.", cfg.papersCSV);
end

%% 1. Load corpus (paper metadata + abstracts)
papers = load_corpus(cfg.papersCSV);
fprintf("Loaded %d papers from corpus.\n", height(papers));

%% 2. Build search index (BM25 over abstracts)
searchIndex = build_search_index(papers);
fprintf("Search index built.\n");

%% 3. Search a target paper by title, or use an existing corpus ID

inputMode = input( ...
    "모드 선택: 1 = 기존 papers.csv 논문 분석, 2 = 제목으로 새 논문 검색: " ...
);

if inputMode == 1

    targetID = input("분석할 논문 ID를 입력하세요 (예: P001): ", "s");
    targetID = string(targetID);

elseif inputMode == 2

    titleQuery = input("논문 제목 또는 검색 키워드를 입력하세요: ", "s");

    selectedPaper = search_semantic_scholar(string(titleQuery));

    if isempty(fieldnames(selectedPaper))
        error("논문 선택이 취소되어 파이프라인을 종료합니다.");
    end

    [papers, targetID] = append_paper_to_corpus( ...
        papers, selectedPaper, cfg.papersCSV ...
    );
    searchIndex = build_search_index(papers);

else
    error("모드는 1 또는 2만 입력할 수 있습니다.");
end

targetRow = papers(papers.id == targetID, :);

if isempty(targetRow)
    error("Target paper ID '%s' not found in papers.csv", targetID);
end

targetText = string(targetRow.abstract(1));

fprintf("Target paper: %s\n", targetRow.title(1));
fprintf("Target ID: %s\n", targetID);


%% 4. Structured extraction via LLM
extraction = extract_structured_info(targetText, cfg);
fprintf("Structured extraction complete.\n");

%% 5. Limitation analysis (author-stated vs inferred gaps)
limitations = analyze_limitations(extraction, targetText, cfg);
fprintf("Limitation analysis complete.\n");

%% 6. Research direction proposals for each limitation
proposals = propose_research_directions(limitations, cfg);
fprintf("Research direction proposals generated.\n");

%% 7. Retrieve related papers for each proposed direction
recommendations = retrieve_related_papers(proposals, papers, searchIndex, cfg);
fprintf("Related paper retrieval complete.\n");

%% 8. Validate everything against schema/evidence rules
validation_report = validate_outputs(extraction, limitations, proposals, recommendations);

%% 9. Generate final report (Markdown + CSV comparison table)
generate_report(targetRow, extraction, limitations, proposals, recommendations, ...
    validation_report, cfg);

fprintf("\nDone. See outputs/reports/ and outputs/paper_cards/ for results.\n");
