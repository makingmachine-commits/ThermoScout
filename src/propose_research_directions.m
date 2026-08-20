function proposals = propose_research_directions(limitations, cfg)
% Generate rule-based follow-up research directions.


    %#ok<INUSD>  

    if ~isfield(limitations, "inferred_validation_gaps") || ...
            isempty(limitations.inferred_validation_gaps)

        proposals = struct([]);
        return;
    end

    gaps = limitations.inferred_validation_gaps;
    proposals = struct([]);

    for i = 1:numel(gaps)

        % Support cell and struct JSON outputs.
        if iscell(gaps)
            g = gaps{i};
        else
            g = gaps(i);
        end

        category = lower(string(get_field_or_empty(g, "category")));
        limitationText = string(get_field_or_empty(g, "limitation"));

        % Map gap category to a validation plan.
        p = build_proposal(category, limitationText);

        % Retain source gap.
        p.source_limitation = g;

        if isempty(proposals)
            proposals = p;
        else
            proposals(end+1) = p; %#ok<AGROW>
        end
    end
end


function p = build_proposal(category, limitationText)

    p = struct();
    p.target_gap = limitationText;

    if contains(category, "boundary") || ...
            contains(category, "cooling")

        p.hypothesis = ...
            "Cooling boundary conditions can materially change peak junction temperature and the ranking of thermal solutions.";

        p.verification_method = ...
            "Run a sensitivity analysis over ambient temperature, convection coefficient, and heat-sink thermal resistance; validate selected conditions with controlled thermal measurements.";

        p.success_metric = ...
            "Peak junction temperature, total thermal resistance, and ranking stability across boundary conditions.";

        p.trade_off = ...
            "More simulation cases and test-fixture control are required.";

    elseif contains(category, "contact") || ...
            contains(category, "interface") || ...
            contains(category, "tim")

        p.hypothesis = ...
            "Interfacial contact resistance between die, TIM, and heat spreader can offset the apparent benefit of a high-conductivity thermal path.";

        p.verification_method = ...
            "Perform contact-resistance sensitivity analysis and measure assembled-package thermal resistance under controlled bonding pressure and surface roughness.";

        p.success_metric = ...
            "Junction-to-case thermal resistance, interface resistance variation, and repeatability across assemblies.";

        p.trade_off = ...
            "Requires assembly-condition control and thermal characterization equipment.";

    elseif contains(category, "thermo") || ...
            contains(category, "mechanical") || ...
            contains(category, "warpage") || ...
            contains(category, "stress")

        p.hypothesis = ...
            "A low-resistance thermal path may introduce CTE-mismatch stress, warpage, or fatigue risk in stacked packages.";

        p.verification_method = ...
            "Conduct coupled thermo-mechanical finite-element analysis and thermal-cycling tests; compare predicted warpage with measurement.";

        p.success_metric = ...
            "Maximum von Mises stress, warpage, interfacial damage indicator, and post-cycle thermal-resistance change.";

        p.trade_off = ...
            "Thermal-optimal materials or geometries may reduce mechanical reliability.";

    elseif contains(category, "electrical") || ...
            contains(category, "signal") || ...
            contains(category, "insulation")

        p.hypothesis = ...
            "Thermally conductive additions must be evaluated for electrical insulation and high-speed signal integrity before package integration.";

        p.verification_method = ...
            "Measure dielectric breakdown and leakage; run electromagnetic simulation or S-parameter measurement for the relevant interconnect region.";

        p.success_metric = ...
            "Breakdown voltage, leakage current, insertion loss, return loss, and eye-diagram margin.";

        p.trade_off = ...
            "Electrical isolation layers can increase thermal resistance.";

    elseif contains(category, "manufactur") || ...
            contains(category, "yield") || ...
            contains(category, "cost") || ...
            contains(category, "process")

        p.hypothesis = ...
            "A thermally effective structure requires an acceptable process window and yield to be viable for production.";

        p.verification_method = ...
            "Define a process DOE covering material thickness, bonding pressure, and cure/reflow conditions; measure yield and thermal-property variation.";

        p.success_metric = ...
            "Process yield, thermal-resistance distribution, defect rate, and estimated cost per package.";

        p.trade_off = ...
            "Tighter process control and added materials can raise manufacturing cost.";

    elseif contains(category, "transient") || ...
            contains(category, "cycling") || ...
            contains(category, "operating")

        p.hypothesis = ...
            "Steady-state thermal performance does not fully predict temperature peaks or degradation under dynamic AI workloads and power cycling.";

        p.verification_method = ...
            "Run transient electro-thermal simulation with representative power traces and execute power-cycling experiments.";

        p.success_metric = ...
            "Peak junction temperature, thermal time constant, temperature swing, and performance change after cycling.";

        p.trade_off = ...
            "Transient models and reliability tests require longer run time and more measurement data.";

    elseif contains(category, "scale") || ...
            contains(category, "stack") || ...
            contains(category, "sip") || ...
            contains(category, "multi")

        p.hypothesis = ...
            "Thermal behavior observed in a simplified or single-die model may change after expansion to multi-die HBM/logic integration.";

        p.verification_method = ...
            "Extend the model to representative multi-die geometry and compare heat-flow paths, hotspot location, and thermal coupling among dies.";

        p.success_metric = ...
            "Maximum junction temperature, die-to-die temperature spread, thermal coupling coefficient, and hotspot displacement.";

        p.trade_off = ...
            "Model size, computational cost, and input-data requirements increase.";

    else
        p.hypothesis = ...
            "The identified gap requires targeted validation before the reported thermal-management solution can be generalized.";

        p.verification_method = ...
            "Define the missing boundary conditions and perform a sensitivity analysis followed by focused experiment or simulation.";

        p.success_metric = ...
            "Reproducibility of peak temperature and thermal resistance under the defined validation conditions.";

        p.trade_off = ...
            "Additional characterization time and experimental resources are required.";
    end
end


function value = get_field_or_empty(s, fieldName)

    if isfield(s, fieldName) && ~isempty(s.(fieldName))
        value = s.(fieldName);
    else
        value = "";
    end
end