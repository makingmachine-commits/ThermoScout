function recommendations = retrieve_related_papers(proposals, papers, searchIndex, cfg)


recommendations = struct([]);

if isempty(proposals)
    return;
end

for i = 1:numel(proposals)
    p = proposals(i);
    queryText = "";
    if isfield(p, "target_gap"); queryText = queryText + " " + string(p.target_gap); end
    if isfield(p, "hypothesis"); queryText = queryText + " " + string(p.hypothesis); end
    queryText = strtrim(queryText);
    if queryText == ""
        continue;
    end

    % Toolbox-free lexical similarity search
    queryText = lower(string(queryText));
    queryText = regexprep(queryText, '[^a-zA-Z0-9\s]', ' ');
    queryText = regexprep(queryText, '\s+', ' ');
    queryTokens = unique(split(strtrim(queryText)));
    queryTokens(queryTokens == "") = [];

    scores = zeros(numel(searchIndex.texts), 1);

    for j = 1:numel(searchIndex.texts)
        docTokens = unique(split(searchIndex.texts(j)));
        docTokens(docTokens == "") = [];

        overlap = numel(intersect(queryTokens, docTokens));

    % Normalize for document length.
        scores(j) = overlap / sqrt(max(1, numel(docTokens)));
    end
    [sortedScores, idx] = sort(scores, "descend");

    topK = min(cfg.topK, numel(idx));
    matchIDs = searchIndex.ids(idx(1:topK));
    matchScores = sortedScores(1:topK);

    rec.proposal_index = i;
    rec.target_gap = queryText;
    rec.matches = struct("paper_id", {}, "title", {}, "doi", {}, "score", {});
    for k = 1:topK
        row = papers(papers.id == matchIDs(k), :);
        if isempty(row); continue; end
        rec.matches(end+1) = struct( ...
            "paper_id", matchIDs(k), ...
            "title", row.title(1), ...
            "doi", row.doi(1), ...
            "score", matchScores(k)); %#ok<AGROW>
    end

    if isempty(recommendations)
        recommendations = rec;
    else
        recommendations(end+1) = rec; %#ok<AGROW>
    end
end

end
