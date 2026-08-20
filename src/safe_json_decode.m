function s = safe_json_decode(rawText)
% Parse JSON after removing optional Markdown fences.

txt = strtrim(string(rawText));
txt = erase(txt, "```json");
txt = erase(txt, "```");
txt = strtrim(txt);

try
    s = jsondecode(txt);
catch ME
    warning("JSON decode failed: %s\nRaw text was:\n%s", ME.message, txt);
    s = struct();
end

end
