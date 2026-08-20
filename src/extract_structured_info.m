function extraction = extract_structured_info(paperText, cfg)
% Extract structured metadata from source text.

promptPath = fullfile(cfg.promptDir, "extraction_prompt.txt");
systemPrompt = fileread(promptPath);

userPrompt = "EVIDENCE TEXT:" + newline + newline + paperText;

rawResponse = call_llm(systemPrompt, userPrompt, cfg);
extraction = safe_json_decode(rawResponse);

if isempty(fieldnames(extraction))
    warning("Extraction returned empty JSON. Check LLM provider/API key.");
end

end
