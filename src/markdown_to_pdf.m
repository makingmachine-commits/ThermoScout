function pdfPath = markdown_to_pdf(mdPath, outputDir)
% Export a Markdown report as HTML and PDF via Microsoft Edge.
% Build HTML document.
% Locate Edge executable.
% Render PDF through headless Edge.
% Minimal Markdown renderer.


    mdText = fileread(mdPath);


    htmlText = convert_markdown_to_html(mdText);


    fullHTML = [ ...
        "<!DOCTYPE html>" newline ...
        "<html><head><meta charset=""UTF-8"">" newline ...
        "<style>" newline ...
        "body { font-family: Arial, 'Malgun Gothic', sans-serif;" ...
        " margin: 40px; line-height: 1.55; color: #222; }" newline ...
        "h1 { color: #1f4e79; border-bottom: 2px solid #1f4e79; }" newline ...
        "h2 { color: #1f4e79; margin-top: 28px; }" newline ...
        "h3 { color: #333; margin-top: 20px; }" newline ...
        "table { border-collapse: collapse; width: 100%; margin: 12px 0; }" newline ...
        "th, td { border: 1px solid #888; padding: 8px; vertical-align: top; }" newline ...
        "th { background-color: #d9eaf7; }" newline ...
        "code { background: #f2f2f2; padding: 2px 4px; }" newline ...
        "</style></head><body>" newline ...
        htmlText newline ...
        "</body></html>" ...
    ];


    [~, baseName, ~] = fileparts(mdPath);
    htmlPath = fullfile(outputDir, baseName + ".html");
    pdfPath = fullfile(outputDir, baseName + ".pdf");

    fid = fopen(htmlPath, "w", "n", "UTF-8");
    fprintf(fid, "%s", fullHTML);
    fclose(fid);


    edgePaths = [ ...
        "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
        "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
    ];

    edgeExe = "";
    for i = 1:numel(edgePaths)
        if isfile(edgePaths(i))
            edgeExe = edgePaths(i);
            break;
        end
    end

    if edgeExe == ""
        warning("Microsoft Edge를 찾지 못했습니다. HTML만 생성했습니다: %s", htmlPath);
        pdfPath = "";
        return;
    end


    command = sprintf( ...
        '"%s" --headless --disable-gpu --no-pdf-header-footer --print-to-pdf="%s" "file:///%s"', ...
         edgeExe, pdfPath, strrep(htmlPath, "\", "/") ...
        );
    [status, cmdout] = system(command);

    if status ~= 0 || ~isfile(pdfPath)
        warning("PDF 생성 실패. HTML 결과를 확인하세요.\n%s", cmdout);
        pdfPath = "";
    else
        fprintf("PDF report written to: %s\n", pdfPath);
    end
end


function htmlText = convert_markdown_to_html(mdText)


    lines = splitlines(string(mdText));
    htmlLines = strings(0);

    inTable = false;
    inList = false;

    for i = 1:numel(lines)

        line = strtrim(lines(i));


        if line == ""
            if inTable
                htmlLines(end+1) = "</table>";
                inTable = false;
            end

            if inList
                htmlLines(end+1) = "</ul>";
                inList = false;
            end

            continue;
        end


        if startsWith(line, "# ")
            htmlLines(end+1) = "<h1>" + escape_html(extractAfter(line, 2)) + "</h1>";
            continue;
        elseif startsWith(line, "## ")
            htmlLines(end+1) = "<h2>" + escape_html(extractAfter(line, 3)) + "</h2>";
            continue;
        elseif startsWith(line, "### ")
            htmlLines(end+1) = "<h3>" + escape_html(extractAfter(line, 4)) + "</h3>";
            continue;
        end


        if startsWith(line, "|---")
            continue;
        end


        if startsWith(line, "|") && endsWith(line, "|")
            cells = split(extractBetween(line, 2, strlength(line)-1), "|");

            if ~inTable
                htmlLines(end+1) = "<table>";
                inTable = true;

                htmlLines(end+1) = "<tr>";
                for c = 1:numel(cells)
                    htmlLines(end+1) = "<th>" + format_inline(cells(c)) + "</th>";
                end
                htmlLines(end+1) = "</tr>";

            else
                htmlLines(end+1) = "<tr>";
                for c = 1:numel(cells)
                    htmlLines(end+1) = "<td>" + format_inline(cells(c)) + "</td>";
                end
                htmlLines(end+1) = "</tr>";
            end

            continue;
        end


        if startsWith(line, "- ")
            if ~inList
                htmlLines(end+1) = "<ul>";
                inList = true;
            end

            htmlLines(end+1) = "<li>" + format_inline(extractAfter(line, 2)) + "</li>";
            continue;
        end


        htmlLines(end+1) = "<p>" + format_inline(line) + "</p>";
    end

    if inTable
        htmlLines(end+1) = "</table>";
    end

    if inList
        htmlLines(end+1) = "</ul>";
    end

    htmlText = strjoin(htmlLines, newline);
end


function out = format_inline(text)

    out = escape_html(string(text));


    out = regexprep(out, '\*\*(.*?)\*\*', '<strong>$1</strong>');


    out = regexprep(out, '`(.*?)`', '<code>$1</code>');
end


function out = escape_html(text)

    out = replace(text, "&", "&amp;");
    out = replace(out, "<", "&lt;");
    out = replace(out, ">", "&gt;");
end