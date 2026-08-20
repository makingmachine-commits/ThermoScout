function responseText = call_llm(systemPrompt, userPrompt, cfg)
% CALL_LLM
% OpenAI 또는 Ollama로 LLM을 호출하는 공용 함수.
% MATLAB R2025b 기준 webwrite 기반 구현.

    switch cfg.llmProvider
        case "openai"
            responseText = call_openai(systemPrompt, userPrompt, cfg);

        case "ollama"
            responseText = call_ollama(systemPrompt, userPrompt, cfg);

        otherwise
            error("지원하지 않는 llmProvider: %s", cfg.llmProvider);
    end
end


function out = call_openai(systemPrompt, userPrompt, cfg)

    apiKey = string(getenv("OPENAI_API_KEY"));

    if strlength(apiKey) == 0
        error("OPENAI_API_KEY 환경변수가 설정되지 않았습니다.");
    end

    url = "https://api.openai.com/v1/chat/completions";

    systemMessage = struct( ...
        "role", "system", ...
        "content", char(string(systemPrompt)) ...
    );

    userMessage = struct( ...
        "role", "user", ...
        "content", char(string(userPrompt)) ...
    );

    messages(1) = systemMessage;
    messages(2) = userMessage;

    payload = struct();
    payload.model = char(string(cfg.openaiModel));
    payload.messages = messages;
    payload.temperature = 0.1;
    payload.response_format = struct("type", "json_object");

    headerFields = [
    "Authorization", "Bearer " + apiKey
];

    options = weboptions( ...
    "MediaType", "application/json", ...
    "HeaderFields", headerFields, ...
    "Timeout", 120 ...
);

    try
        response = webwrite(url, payload, options);

    catch ME
        errorMessage = sprintf( ...
            'OpenAI webwrite 호출 실패.\n원본 MATLAB 오류: %s', ...
            ME.message ...
        );

        error('%s', errorMessage);
    end

    if ~isstruct(response) || ~isfield(response, "choices") || ...
            isempty(response.choices)

        error("OpenAI 응답 형식이 예상과 다릅니다.");
    end

    out = string(response.choices(1).message.content);
end


function out = call_ollama(systemPrompt, userPrompt, cfg)

    url = "http://127.0.0.1:11434/api/generate";

    fullPrompt = string(systemPrompt) + newline + newline + ...
        "USER REQUEST:" + newline + string(userPrompt) + ...
        newline + newline + ...
        "IMPORTANT: Return valid JSON only. Do not use Markdown code fences.";


    payload = struct();
    payload.model = char(string(cfg.ollamaModel));
    payload.prompt = char(fullPrompt);
    payload.stream = false;


    payloadJSON = jsonencode(payload);

    options = weboptions( ...
        "MediaType", "application/json", ...
        "ContentType", "json", ...
        "Timeout", 300 ...
    );

    try

        response = webwrite(url, payloadJSON, options);

    catch ME
        errorMessage = sprintf( ...
            'Ollama 호출 실패.\n원본 MATLAB 오류: %s', ...
            ME.message ...
        );

        error('%s', errorMessage);
    end


    if ~isstruct(response) || ~isfield(response, "response")
        error("Ollama 응답에 response 필드가 없습니다.");
    end

    out = string(response.response);
end