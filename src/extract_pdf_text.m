function text = extract_pdf_text(pdfPath, cfg) %#ok<INUSD>
% EXTRACT_PDF_TEXT Extract raw text from a PDF file.


if ~isfile(pdfPath)
    error("PDF not found: %s", pdfPath);
end

try
    text = extractFileText(pdfPath);
catch ME
    warning("extractFileText failed (%s). Attempting OCR fallback...", ME.message);
    text = ocr_pdf_fallback(pdfPath);
end

text = string(text);
if strlength(strtrim(text)) < 50
    warning("Extracted text is very short (%d chars). PDF may be scanned; consider OCR.", strlength(text));
end

end

function text = ocr_pdf_fallback(pdfPath)

    error(["OCR fallback not implemented in this template. " ...
           "Install Computer Vision Toolbox and implement page-to-image " ...
           "conversion + ocr() call, or use a text-based PDF instead. " ...
           "Failed file: %s"], pdfPath);
end
