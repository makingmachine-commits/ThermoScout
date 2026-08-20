function report = validate_outputs(extraction, limitations, proposals, recommendations)
% VALIDATE_OUTPUTS Basic sanity checks on pipeline outputs before reporting.

report = struct();
report.warnings = {};

if isempty(fieldnames(extraction)) || ~isfield(extraction, "thermal_problem")
    report.warnings{end+1} = "Extraction missing or malformed.";
end

if isfield(extraction, "quantitative_metrics")
    for i = 1:numel(extraction.quantitative_metrics)
        m = extraction.quantitative_metrics(i);
        if isfield(m,"evidence") && strtrim(string(m.evidence)) == ""
            report.warnings{end+1} = sprintf("Metric '%s' has no evidence quote.", string(m.metric));
        end
    end
end

if isempty(fieldnames(limitations))
    report.warnings{end+1} = "Limitation analysis missing or malformed.";
end

if isempty(proposals)
    report.warnings{end+1} = "No research proposals generated (no inferred gaps found).";
end

if isempty(recommendations)
    report.warnings{end+1} = "No related papers retrieved.";
end

report.n_warnings = numel(report.warnings);
report.status = "OK";
if report.n_warnings > 0
    report.status = "REVIEW_NEEDED";
end

end
