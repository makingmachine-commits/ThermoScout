# ThermoScout (MATLAB) — Packaging Thermal Management Research Agent

## 개요
논문 초록/PDF를 입력하면 `문제–열원–열경로–해결책–정량 지표–한계`를 구조화 추출하고,
저자 명시 한계와 검증 필요 항목(inferred gap)을 구분한 뒤, 각 한계에 대한 후속 연구
방향(가설–검증법–성공지표–trade-off)을 제안하고 로컬 코퍼스에서 관련 논문을 추천합니다.

## 실행 방법
1. `data/papers.csv`를 채운다 (최소 5편, 아래 필수 컬럼 참고).
2. `src/main_pipeline.m`에서 `cfg.llmProvider`(`"ollama"` 또는 `"openai"`)와 `cfg.topK`를 필요에 맞게 설정한다.
3. MATLAB에서 `src` 폴더를 현재 폴더로 두고 `main_pipeline`을 실행한다.
4. 실행 중 콘솔 프롬프트에서 분석 방식을 선택한다.
   - `1` = `data/papers.csv`에 이미 있는 논문을 ID로 지정해 분석
   - `2` = 제목/키워드로 Semantic Scholar를 검색해 새 논문을 코퍼스에 추가한 뒤 분석
5. 결과는 `outputs/reports/*.md`(+ Windows/Edge 설치 시 `*.pdf` 자동 생성), `outputs/paper_cards/*.csv`에 생성된다.

## 필요 준비물 (꼼꼼히)

### 1. MATLAB 환경
- MATLAB R2021a 이상 (권장: R2024a 이상, `extractFileText` 안정성 때문)
- **추가 툴박스 불필요** — 검색 인덱스(`build_search_index.m`)와 관련 논문 검색(`retrieve_related_papers.m`)은 Text Analytics Toolbox 없이 순수 MATLAB 토큰 오버랩 스코어링으로 구현되어 있음
- PDF에서 텍스트 추출 시: 기본 MATLAB 내장 함수 `extractFileText` 사용 (툴박스 불필요, R2020a+)
- 스캔 PDF(이미지 기반) 처리 시: **Computer Vision Toolbox** (OCR 기능, 선택사항 — 코드에 스텁만 있고 직접 구현 필요)
- 웹 API 호출: `matlab.net.http`, `webwrite` 등 MATLAB 기본 제공 함수만 사용, 별도 툴박스 불필요
- PDF 리포트 자동 생성: Windows + Microsoft Edge 설치 시에만 동작 (`markdown_to_pdf.m`가 Edge headless 인쇄 기능 사용). Edge를 못 찾으면 경고만 뜨고 `outputs/reports/*.html`까지만 생성됨 (macOS/Linux에서는 항상 이 경로를 탄다)

### 2. LLM 접근 방법 (택 1)
- **OpenAI API 사용 시**
  - OpenAI API 키 필요 (https://platform.openai.com 에서 발급)
  - 환경변수 등록: `setenv("OPENAI_API_KEY", "sk-...")` (MATLAB 세션마다 또는 OS 환경변수로 영구 등록)
  - `cfg.llmProvider = "openai";`로 설정 시 `cfg.openaiModel`(예: `"gpt-4o-mini"`)도 `main_pipeline.m`에 직접 추가해야 함 — 현재 스크립트 기본값에는 빠져 있음
  - 인터넷 연결 필요, 유료 API이므로 사용량에 따라 과금됨
- **Ollama(로컬 LLM) 사용 시 — 기본값**
  - Ollama 설치 (https://ollama.com) 후 로컬 서버 실행 (`ollama serve`, 기본 포트 11434)
  - 모델 다운로드: 예) `ollama pull llama3.1`
  - 인터넷 불필요 (모델 다운로드 후에는 완전 오프라인 실행 가능)
  - GPU 또는 충분한 RAM 권장 (llama3.1 8B 기준 최소 8GB RAM)
- `main_pipeline.m`의 `cfg.llmProvider`를 `"openai"` 또는 `"ollama"`로 설정 (기본값: `"ollama"`)

### 3. 논문 검색 (선택 — 모드 2 사용 시 필요)
- 제목/키워드로 새 논문을 검색해 코퍼스에 추가하려면(`search_semantic_scholar.m`) Semantic Scholar API를 사용
- 환경변수 `SEMANTIC_SCHOLAR_API_KEY`를 등록하면 요청 제한이 완화됨 (없어도 동작은 하지만 429 에러 발생 가능성이 커짐)
- 429(요청 제한) 응답 시 자동으로 최대 3회까지 대기 후 재시도함

### 4. 데이터 파일
- `data/papers.csv` — 필수, 최소 5~15편의 논문 메타데이터/초록
  - 컬럼: `id, title, year, doi, abstract, source`
  - abstract는 영어/한글 모두 가능하나 영어 논문 초록 권장 (LLM 추출 품질이 더 안정적)
- (선택) `data/papers_pdf/*.pdf` — PDF 원문으로 분석하고 싶을 경우 폴더 생성 후 PDF 저장 (`main_pipeline.m`의 Option B 주석 참고)
  - 저작권/구독 라이선스 논문은 외부 API(OpenAI)로 전송 시 라이선스 위반 소지 있음 → 공개 논문(open-access, arXiv, 저자 공개 preprint)만 사용 권장

### 5. 코드 파일 (본 프로젝트에서 이미 생성됨)
```
thermoscout_matlab/
├── src/
│   ├── main_pipeline.m              (실행 진입점)
│   ├── load_corpus.m
│   ├── build_search_index.m
│   ├── search_semantic_scholar.m    (모드 2: 논문 검색)
│   ├── append_paper_to_corpus.m     (모드 2: 검색 결과를 papers.csv에 추가)
│   ├── extract_pdf_text.m
│   ├── call_llm.m
│   ├── extract_structured_info.m
│   ├── analyze_limitations.m
│   ├── propose_research_directions.m
│   ├── retrieve_related_papers.m
│   ├── validate_outputs.m
│   ├── safe_json_decode.m
│   ├── generate_report.m
│   └── markdown_to_pdf.m            (Markdown → PDF, Windows/Edge 전용)
├── prompts/
│   ├── extraction_prompt.txt
│   └── limitation_prompt.txt
├── data/
│   └── papers.csv                   (샘플 논문 포함, 본인 데이터로 교체 필요)
└── outputs/
    ├── reports/                     (실행 후 .md, 조건부 .pdf/.html 생성됨)
    └── paper_cards/                 (실행 후 .csv 생성됨)
```

### 6. 실행 전 체크리스트
- [ ] `data/papers.csv`에 최소 5편 이상 실제 논문 데이터 입력
- [ ] `data/`, `outputs/`, `prompts/` 폴더가 `src/`와 같은 상위 폴더 안에 존재하는지 확인 (없으면 코드가 자동으로 만들어주지 않음)
- [ ] LLM provider 선택 후 API 키(OpenAI) 또는 로컬 서버(Ollama) 준비 완료
- [ ] `cfg.llmProvider = "openai"`로 바꿀 경우 `cfg.openaiModel` 값도 직접 추가
- [ ] (모드 2로 논문 검색 예정 시) `SEMANTIC_SCHOLAR_API_KEY` 등록 권장
- [ ] (PDF 원문 분석 시) `main_pipeline.m`의 Option B 주석 해제 및 파일 경로 확인

### 7. 알려진 한계
- 공개 논문 코퍼스 기반이며 실제 회사 기밀 데이터나 패키지 설계 검증을 수행하지 않음
- LLM 추출 결과는 원문 근거(evidence)와 함께 제공되나, 최종 사용 전 사람이 원문과 대조 검증 필요
- 관련 논문 검색은 진짜 BM25가 아니라 문서 길이로 보정한 단순 토큰 오버랩 스코어링임 (의미 기반 임베딩 검색은 추후 확장 과제)
- 스캔 PDF의 OCR 처리는 스텁 코드만 있고 실제 구현은 별도로 필요
- PDF 리포트 자동 생성은 Windows + Microsoft Edge 환경에서만 동작하며, 그 외 환경에서는 HTML까지만 생성됨

## Scope and Limitations

ThermoScout is a research-support prototype for literature triage and
engineering-question generation. Its outputs are not autonomous design decisions
or scholarly citations; extracted information and references require human review.
