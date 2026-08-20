function idx = build_search_index(papers)
% Build a normalized lexical index from paper abstracts.

idx.ids = papers.id;
idx.texts = lower(string(papers.abstract));
idx.texts = regexprep(idx.texts, '[^a-zA-Z0-9\s]', ' ');
idx.texts = regexprep(idx.texts, '\s+', ' ');
idx.texts = strtrim(idx.texts);

end
