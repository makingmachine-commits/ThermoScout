function papers = load_corpus(csvPath)
% Load and validate the local paper corpus.


opts = detectImportOptions(csvPath, "TextType", "string");
papers = readtable(csvPath, opts);

requiredCols = ["id","title","year","doi","abstract","source"];
missingCols = setdiff(requiredCols, string(papers.Properties.VariableNames));
if ~isempty(missingCols)
    error("papers.csv missing required columns: %s", strjoin(missingCols, ", "));
end

papers.id = string(papers.id);
papers.title = string(papers.title);
papers.doi = string(papers.doi);
papers.abstract = string(papers.abstract);
papers.source = string(papers.source);

emptyAbs = papers.abstract == "" | ismissing(papers.abstract);
if any(emptyAbs)
    warning("%d papers have empty abstracts and will be excluded from search index.", sum(emptyAbs));
end
papers = papers(~emptyAbs, :);

end
