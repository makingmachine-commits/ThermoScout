function limitations = analyze_limitations(extraction, paperText, cfg)
% Separate stated limitations from validation gaps.

promptPath = fullfile(cfg.promptDir, "limitation_prompt.txt");
systemPrompt = fileread(promptPath);

extractionJSON = jsonencode(extraction);
userPrompt = "STRUCTURED EXTRACTION:" + newline + string(extractionJSON) + ...
    newline + newline + "ORIGINAL EVIDENCE TEXT:" + newline + paperText;

rawResponse = call_llm(systemPrompt, userPrompt, cfg);
limitations = safe_json_decode(rawResponse);

end
