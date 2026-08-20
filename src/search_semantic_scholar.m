function selectedPaper = search_semantic_scholar(queryText)
% Search Semantic Scholar and return a selected paper.

selectedPaper = struct();

apiKey = getenv("SEMANTIC_SCHOLAR_API_KEY");

if apiKey == ""
    warning([ ...
        "SEMANTIC_SCHOLAR_API_KEY가 설정되지 않았습니다. " + ...
        "비인증 요청으로 진행합니다. 검색 제한이 걸릴 수 있습니다." ...
    ]);
end

baseURL = "https://api.semanticscholar.org/graph/v1/paper/search";

fields = "title,year,externalIds,abstract,url,venue";
encodedQuery = urlencode(char(queryText));

fullURL = baseURL + ...
    "?query=" + string(encodedQuery) + ...
    "&limit=10" + ...
    "&fields=" + fields;

headers = matlab.net.http.HeaderField( ...
    "Accept", "application/json" ...
);

if apiKey ~= ""
    headers = [ ...
        headers, ...
        matlab.net.http.HeaderField("x-api-key", apiKey) ...
    ];
end


request = matlab.net.http.RequestMessage;
request.Method = matlab.net.http.RequestMethod.GET;
request.Header = headers;
pause(1.2);

maxRetries = 3;
waitSeconds = 2;

for attempt = 1:maxRetries
    pause(1.2);
    try
        response = send(request, matlab.net.URI(fullURL));
    catch ME
        error("Semantic Scholar API 요청 실패: %s", ME.message);
    end
    if response.StatusCode ~= matlab.net.http.StatusCode.TooManyRequests
        break;
    end

    if attempt < maxRetries

        fprintf( ...
            "429 요청 제한 발생: %d초 후 재시도합니다. (%d/%d)\n", ...
            waitSeconds, attempt, maxRetries ...
        );

        pause(waitSeconds);
        waitSeconds = waitSeconds * 2;

    else

        error([ ...
            "Semantic Scholar API가 3회 연속 429를 반환했습니다. " + ...
            "약 2~5분 뒤 다시 시도하세요." ...
        ]);

    end

end

if response.StatusCode == matlab.net.http.StatusCode.TooManyRequests
    error([ ...
        "Semantic Scholar API 요청 제한(429)에 도달했습니다. " + ...
        "잠시 후 재시도하거나 API 키 등록 상태를 확인하세요." ...
    ]);
end

if response.StatusCode ~= matlab.net.http.StatusCode.OK
    error( ...
        "Semantic Scholar API 오류. 상태 코드: %s", ...
        string(response.StatusCode) ...
    );
end

responseData = response.Body.Data;

if ~isfield(responseData, "data") || isempty(responseData.data)
    fprintf("검색 결과가 없습니다: %s\n", queryText);
    return;
end

results = responseData.data;
nResults = numel(results);

fprintf("\n검색 결과: %d건\n", nResults);

for i = 1:nResults
    paper = results(i);

    if isfield(paper, "title") && ~isempty(paper.title)
        title = string(paper.title);
    else
        title = "제목 없음";
    end

    if isfield(paper, "year") && ~isempty(paper.year)
        yearText = string(paper.year);
    else
        yearText = "연도 없음";
    end

    fprintf("[%d] %s (%s)\n", i, title, yearText);
end

fprintf("[0] 취소\n");

choice = input("분석할 논문 번호를 입력하세요: ");

if isempty(choice) || choice == 0
    fprintf("논문 선택을 취소했습니다.\n");
    return;
end

if choice < 1 || choice > nResults || floor(choice) ~= choice
    error("1부터 %d 사이의 정수를 입력하세요.", nResults);
end

paper = results(choice);

selectedPaper.title = get_field_or_default(paper, "title", "not reported");
selectedPaper.year = get_field_or_default(paper, "year", NaN);
selectedPaper.abstract = get_field_or_default( ...
    paper, "abstract", "not reported" ...
);
selectedPaper.url = get_field_or_default(paper, "url", "");
selectedPaper.source = "Semantic Scholar";

selectedPaper.doi = "";

if isfield(paper, "externalIds") && ...
        isstruct(paper.externalIds) && ...
        isfield(paper.externalIds, "DOI") && ...
        ~isempty(paper.externalIds.DOI)

    selectedPaper.doi = string(paper.externalIds.DOI);

elseif selectedPaper.url ~= ""
    selectedPaper.doi = selectedPaper.url;
end

if selectedPaper.abstract == "not reported" || ...
        strlength(strtrim(selectedPaper.abstract)) < 20

    warning([ ...
        "선택한 논문에 Semantic Scholar 초록이 충분히 없습니다. " + ...
        "현재 파이프라인은 초록 기반이므로, PDF 원문을 넣는 편이 더 정확합니다." ...
    ]);
end

end

function value = get_field_or_default(s, fieldName, defaultValue)

if isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = s.(fieldName);
else
    value = defaultValue;
end

value = string(value);

end