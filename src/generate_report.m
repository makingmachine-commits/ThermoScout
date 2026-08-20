function generate_report(targetRow, extraction, limitations, proposals, ...
    recommendations, validation_report, cfg)
% Write analysis outputs.

paperID = targetRow.id(1);
ts = datestr(now, "yyyymmdd_HHMMSS"); 

%% Markdown 
mdPath = fullfile(cfg.outputDir, "reports", sprintf("%s_%s.md", paperID, ts));
fid = fopen(mdPath, "w");

fprintf(fid, "# ThermoScout Report: %s\n\n", targetRow.title(1));
fprintf(fid, "**DOI/Source:** %s (%s)\n\n", targetRow.doi(1), targetRow.source(1));
fprintf(fid, "**Validation status:** %s (%d warnings)\n\n", ...
    validation_report.status, validation_report.n_warnings);

fprintf(fid, "## Structured Extraction\n\n");
write_field(fid, "Thermal problem", extraction, "thermal_problem");
write_field(fid, "Package type", extraction, "package_type");
write_field(fid, "Heat source / hotspot", extraction, "heat_source_or_hotspot");
write_field(fid, "Thermal path & solution", extraction, "thermal_path_and_solution");

fprintf(fid, "\n### Quantitative Metrics\n\n");
fprintf(fid, "| Metric | Value | Unit | Evidence |\n|---|---|---|---|\n");
if isfield(extraction, "quantitative_metrics")
    for i = 1:numel(extraction.quantitative_metrics)
        m = extraction.quantitative_metrics(i);
        fprintf(fid, "| %s | %s | %s | %s |\n", ...
            safe_str(m,"metric"), safe_str(m,"value"), safe_str(m,"unit"), safe_str(m,"evidence"));
    end
end

fprintf(fid, "\n## Limitations\n\n### Author-stated\n\n");
if isfield(limitations, "author_stated_limitations")
    for i = 1:numel(limitations.author_stated_limitations)
        fprintf(fid, "- %s\n", string(limitations.author_stated_limitations(i)));
    end
end

fprintf(fid, "\n### Inferred Validation Gaps\n\n");
if isfield(limitations, "inferred_validation_gaps")
    gaps = limitations.inferred_validation_gaps;
    for i = 1:numel(gaps)
        g = gaps(i);
        fprintf(fid, "- **[%s]** %s (reasoning: %s)\n", ...
            safe_str(g,"category"), safe_str(g,"limitation"), safe_str(g,"reasoning"));
    end
end

fprintf(fid, "\n## Proposed Research Directions\n\n");
fprintf(fid, "| Target Gap | Hypothesis | Verification Method | Success Metric | Trade-off |\n|---|---|---|---|---|\n");
for i = 1:numel(proposals)
    p = proposals(i);
    fprintf(fid, "| %s | %s | %s | %s | %s |\n", ...
        safe_str(p,"target_gap"), safe_str(p,"hypothesis"), ...
        safe_str(p,"verification_method"), safe_str(p,"success_metric"), safe_str(p,"trade_off"));
end

fprintf(fid, "\n## Recommended Related Papers\n\n");
for i = 1:numel(recommendations)
    r = recommendations(i);
    fprintf(fid, "**Gap:** %s\n\n", r.target_gap);
    for k = 1:numel(r.matches)
        mm = r.matches(k);
        fprintf(fid, "- %s (%s) — score %.3f\n", mm.title, mm.doi, mm.score);
    end
    fprintf(fid, "\n");
end

fprintf(fid, '## Scope and Validation Notice\n\n');

fprintf(fid, ['This report is a public demonstration of the ThermoScout ', ...
    'research-support workflow.\n\n']);

fprintf(fid, ['Source-grounded fields are extracted from the cited paper text. ', ...
    'Validation hypotheses are AI-generated prompts for engineering review and ', ...
    'are not author-stated conclusions.\n\n']);

fprintf(fid, ['No independently verified experimental validation was performed. ', ...
    'Extracted values and references must be cross-checked against the original ', ...
    'publication before external or scholarly use.\n']);

fclose(fid);

%% CSV
csvPath = fullfile(cfg.outputDir, "paper_cards", sprintf("%s_%s.csv", paperID, ts));
metricNames = "";
metricVals = "";
if isfield(extraction, "quantitative_metrics")
    for i = 1:numel(extraction.quantitative_metrics)
        m = extraction.quantitative_metrics(i);
        metricNames = metricNames + safe_str(m,"metric") + ";";
        metricVals  = metricVals + safe_str(m,"value") + safe_str(m,"unit") + ";";
    end
end

T = table(paperID, targetRow.title(1), targetRow.doi(1), ...
    string(safe_str(extraction,"thermal_problem")), ...
    string(safe_str(extraction,"package_type")), ...
    string(metricNames), string(metricVals), ...
    'VariableNames', {'paper_id','title','doi','thermal_problem','package_type','metric_names','metric_values'});
writetable(T, csvPath);

fprintf("Report written to: %s\n", mdPath);
fprintf("Comparison row written to: %s\n", csvPath);
% Export PDF when available.
pdfPath = markdown_to_pdf(mdPath, fullfile(cfg.outputDir, "reports"));

if pdfPath ~= ""
    fprintf("PDF report written to: %s\n", pdfPath);
end

end

function write_field(fid, label, s, fieldName)
fprintf(fid, "**%s:** %s\n\n", label, safe_str(s, fieldName));
end

function v = safe_str(s, fieldName)
if isfield(s, fieldName) && ~isempty(s.(fieldName))
    v = string(s.(fieldName));
else
    v = "not reported";
end
end
