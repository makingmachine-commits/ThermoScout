function resultsTable = search_semantic_scholar_results(queryText)

apiKey = string(getenv("SEMANTIC_SCHOLAR_API_KEY"));

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
        matlab.net.http.HeaderField("x-api-key", char(apiKey)) ...
    ];
end

request = matlab.net.http.RequestMessage;
request.Method = matlab.net.http.RequestMethod.GET;
request.Header = headers;

maxRetries = 3;
waitSeconds = 2;
response = [];

for attempt = 1:maxRetries

    pause(1.2);

    try
        response = send(request, matlab.net.URI(fullURL));
    catch ME
        error("Semantic Scholar request failed: %s", ME.message);
    end

    if response.StatusCode ~= matlab.net.http.StatusCode.TooManyRequests
        break;
    end

    if attempt < maxRetries
        pause(waitSeconds);
        waitSeconds = waitSeconds * 2;
    else
        error("Semantic Scholar returned 429 after %d attempts.", maxRetries);
    end

end

if response.StatusCode ~= matlab.net.http.StatusCode.OK
    error( ...
        "Semantic Scholar request failed with status: %s", ...
        string(response.StatusCode) ...
    );
end

responseData = response.Body.Data;

if ~isfield(responseData, "data") || isempty(responseData.data)

    resultsTable = emptyResultsTable();
    return;

end

rawResults = responseData.data;
n = numel(rawResults);

titleColumn = strings(n, 1);
yearColumn = strings(n, 1);
doiColumn = strings(n, 1);
abstractColumn = strings(n, 1);
urlColumn = strings(n, 1);
venueColumn = strings(n, 1);

for i = 1:n

    paper = rawResults(i);

    titleColumn(i, 1) = getFieldAsScalar( ...
        paper, "title", "not reported" ...
    );

    yearColumn(i, 1) = getFieldAsScalar( ...
        paper, "year", "not reported" ...
    );

    abstractColumn(i, 1) = getFieldAsScalar( ...
        paper, "abstract", "not reported" ...
    );

    urlColumn(i, 1) = getFieldAsScalar( ...
        paper, "url", "" ...
    );

    venueColumn(i, 1) = getFieldAsScalar( ...
        paper, "venue", "not reported" ...
    );

    if isfield(paper, "externalIds") && ...
            isstruct(paper.externalIds) && ...
            isfield(paper.externalIds, "DOI") && ...
            ~isempty(paper.externalIds.DOI)

        doiColumn(i, 1) = string(paper.externalIds.DOI);

    else

        doiColumn(i, 1) = urlColumn(i, 1);

    end

end

resultsTable = table();

resultsTable.title = titleColumn(:);
resultsTable.year = yearColumn(:);
resultsTable.doi = doiColumn(:);
resultsTable.abstract = abstractColumn(:);
resultsTable.url = urlColumn(:);
resultsTable.venue = venueColumn(:);

end

function value = getFieldAsScalar(s, fieldName, defaultValue)

if isfield(s, fieldName) && ~isempty(s.(fieldName))

    value = string(s.(fieldName));

else

    value = string(defaultValue);

end

value = value(1);
value = reshape(value, 1, 1);

end

function resultsTable = emptyResultsTable()

resultsTable = table( ...
    strings(0,1), ...
    strings(0,1), ...
    strings(0,1), ...
    strings(0,1), ...
    strings(0,1), ...
    strings(0,1), ...
    "VariableNames", { ...
        "title", ...
        "year", ...
        "doi", ...
        "abstract", ...
        "url", ...
        "venue" ...
    } ...
);

end