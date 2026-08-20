function [papers, newID] = append_paper_to_corpus( ...
    papers, selectedPaper, papersCSVPath ...
)
% APPEND_PAPER_TO_CORPUS
% Semantic Scholar 검색 결과를 현재 코퍼스와 papers.csv에 추가합니다.

existingIDs = string(papers.id);

idNumbers = zeros(height(papers), 1);

for i = 1:height(papers)

    token = regexp(existingIDs(i), "\d+", "match");

    if ~isempty(token)
        idNumbers(i) = str2double(token{1});
    end

end

nextNumber = max(idNumbers) + 1;
newID = string(sprintf("P%03d", nextNumber));

yearValue = str2double(string(selectedPaper.year));

if isnan(yearValue)
    yearValue = NaN;
end

% Match the existing table schema.
newRow = papers(1, :);

% Initialize default values.
for col = 1:width(newRow)

    variableName = newRow.Properties.VariableNames{col};
    variableData = newRow.(variableName);

    if isstring(variableData)
        newRow.(variableName) = "";
    elseif iscell(variableData)
        newRow.(variableName) = {[]};
    elseif isnumeric(variableData)
        newRow.(variableName) = NaN;
    elseif islogical(variableData)
        newRow.(variableName) = false;
    elseif isdatetime(variableData)
        newRow.(variableName) = NaT;
    else
        % Preserve unsupported column types.
        warning( ...
            "열 '%s'의 데이터 타입을 자동 초기화하지 못했습니다.", ...
            variableName ...
        );
    end

end

% Populate recognized metadata fields.
if ismember("id", newRow.Properties.VariableNames)
    newRow.id = newID;
end

if ismember("title", newRow.Properties.VariableNames)
    newRow.title = string(selectedPaper.title);
end

if ismember("year", newRow.Properties.VariableNames)
    newRow.year = yearValue;
end

if ismember("doi", newRow.Properties.VariableNames)
    newRow.doi = string(selectedPaper.doi);
end

if ismember("abstract", newRow.Properties.VariableNames)
    newRow.abstract = string(selectedPaper.abstract);
end

if ismember("source", newRow.Properties.VariableNames)
    newRow.source = string(selectedPaper.source);
end

% Append the schema-compatible row.
papers = [papers; newRow];
try
    writetable(papers, papersCSVPath);

    fprintf("\n코퍼스에 새 논문을 저장했습니다.\n");
    fprintf("ID: %s\n", newID);
    fprintf("제목: %s\n", selectedPaper.title);
    fprintf("저장 위치: %s\n\n", papersCSVPath);

catch ME
    warning([ ...
        "papers.csv 저장에는 실패했습니다. 그러나 현재 MATLAB 실행 중에는 " + ...
        "새 논문이 메모리에 유지됩니다.\n원인: " + string(ME.message) ...
    ]);
end

end