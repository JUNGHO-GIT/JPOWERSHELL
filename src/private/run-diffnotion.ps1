# run-diffnotion.ps1

# ---------------------------------------------------------------------
# 1. 공통 클래스 가져오기
# ---------------------------------------------------------------------
using module ..\common\classes.psm1

# ---------------------------------------------------------------------
# 0. 전역변수 설정
# ---------------------------------------------------------------------
$global:line = "────────────────────────────────────────────────────────────────"
$global:currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$global:fileName = Split-Path -Leaf $PSCommandPath
$global:workspaceRoot = "C:\git"
$global:outputDir = "C:\Users\jungh\Downloads"
$global:projectList = @()
$global:selectedProject = $null
$global:targetHash = "" # 최신 (Report 대상)
$global:baseHash = ""   # 과거 (비교 기준)
$global:targetShort = ""
$global:baseShort = ""
$global:outputFile = ""
$global:changedFiles = @()
$global:num = 0

# ---------------------------------------------------------------------
# GPT 프롬프트 템플릿
# {0}: 프로젝트 이름
# {1}: 프로젝트 경로
# {2}: Base Hash
# {3}: Base Short
# {4}: Target Hash
# {5}: Target Short
# {6}: 변경 파일 목록
# ---------------------------------------------------------------------
$global:promptTemplate = @"
아래 내용은 git 프로젝트 [{0}] 의 구간 변경사항(Diff)입니다.
이 Diff를 바탕으로 Notion 업무보고용 Markdown 파일을 작성해 주세요.

[핵심 작성 원칙]
1. **코드는 최소한으로**: 각 파일당 핵심 로직만 5-10줄 이내로 제한
2. **변경 요약 중심**: 무엇을 왜 바꿨는지 설명에 집중
3. **불필요한 코드 제외**: 단순 getter/setter, 로깅, 주석, import, 포맷팅 변경은 제외
4. **핵심 비즈니스 로직만**: 실제 기능 변경이나 버그 수정 관련 코드만 포함
5. **생략 적극 활용**: 긴 코드는 ...로 생략하고 핵심 1-2줄만 표시

[작성 요청]
1. 각 파일의 변경 내용을 분석하여 클라이언트/서버/DB 섹션에 분류
2. 변경 요약은 구체적이고 상세하게 작성 (각 항목 1-2문장)
3. 코드 블록은 정말 필요한 경우만 포함하며, 5-10줄 이내로 제한
4. 긴 메서드는 핵심 로직 1-2줄만 표시하고 나머지는 ...로 생략
5. 일반 코드 형식으로 작성 (diff 형식 사용 금지)
6. import문, 단순 변수 선언, 로깅문은 절대 포함하지 않음
7. 날짜는 Target 커밋의 날짜를 사용하여 기재
8. 작성된 내용을 파일로 만들어 다운로드 가능하게 제공

[파일 분류 기준]
- 클라이언트: .html, .htm, .js, .jsx, .ts, .tsx, .css, .scss, .sass, .vue
- 서버: .java, .kt, .py, .go, .properties, .yml, .yaml 등
- DB: .xml, .sql, mapper/repository 경로 포함 파일

[출력 형식]
## **2. 작업 내용**

### **2-1. 클라이언트**
- **파일명**: (파일 경로 기재)
  1. **변경 요약 제목**: 구체적인 설명 1-2문장
  2. **변경 요약 제목**: 구체적인 설명 1-2문장

  **핵심 코드** (선택적, 정말 필요한 경우만):
  ```javascript
  // 핵심 로직만 5-10줄 이내
  function processPayment(data) {{
    const result = validateTransaction(data);
    ...
    return result;
  }}
  ```

---

### **2-2. 서버**
- **파일명**: (파일 경로 기재)
  1. **변경 요약 제목**: 구체적인 설명 1-2문장
  2. **변경 요약 제목**: 구체적인 설명 1-2문장

  **핵심 코드** (선택적, 정말 필요한 경우만):
  ```java
  // 핵심 비즈니스 로직만 표시
  public Result processTransaction(Transaction tx) {{
    if (tx.getAmount() > limit) {{
      throw new LimitExceededException();
    }}
    ...
    return save(tx);
  }}
  ```

---

### **2-3. 데이터베이스**
- **파일명**: (파일 경로 기재)
  1. **변경 요약 제목**: 구체적인 설명 1-2문장
  2. **변경 요약 제목**: 구체적인 설명 1-2문장

  **핵심 쿼리** (선택적):
  ```sql
  SELECT t.*, c.name
  FROM transactions t
  JOIN customers c ON t.customer_id = c.id
  WHERE t.status = 'pending'
  ```

---

## **3. 수정사항**

### **3-1. 주요 변경사항 요약**
- **날짜**: (Target 커밋 날짜 기재)
- **변경 내역**:
  1. 전체 변경 내용 요약
  2. 주요 개선 사항
  3. 버그 수정 내용

---

[최종결과 예제]
1. 개요
1-1. 특징
MID 심사시 사업자번호 api 심사유무 클라이언트에서 선택할수있도록 수정
VID 등록시 사업자번호 api 심사유무 클라이언트에서 선택할수있도록 수정
2. 작업 내용
2-1. 클라이언트
midApplyMng.html
사업자번호 API 미요청 유무 체크박스 추가 및 관련 함수 생성
CODE
enrollSalesOrga.html
사업자번호 API 미요청 유무 체크박스 추가 및 관련 함수 생성
CODE
2-2. 서버
BaseInfoService.java
coNoApiCheck 파라미터를 받아서 api 요청 수행하고 에러코드 반환
CODE
3. 수정사항 및 테스트
3-1. 수정사항
MID 심사 이후 체크박스 초기화 (25-10-15)
VID 등록 이후 체크박스 초기화 (25-10-15)
3-2. 테스트

[프로젝트 정보]
- 프로젝트: {0}
- 경로: {1}
- Base: {2} ({3})
- Target: {4} ({5})

[변경된 파일 목록]
{6}

[Diff 내용]
"@
# ---------------------------------------------------------------------
# 파일별 Diff 섹션 템플릿
# {0}: 파일 경로/이름
# {1}: Diff 내용
# ---------------------------------------------------------------------
$global:diffSectionTemplate = @"
---------------------------------------------------------------------
[FILE] {0}
---------------------------------------------------------------------
{1}
"@

# ---------------------------------------------------------------------
# 2. 메인
# ---------------------------------------------------------------------
class M {
	static [void] SetConsoleEncoding() {
		try {
			[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
			[Console]::InputEncoding = [System.Text.Encoding]::UTF8
			$global:OutputEncoding = [System.Text.Encoding]::UTF8
			chcp 65001 | Out-Null
			Start-Sleep -Milliseconds 100
		}
		catch {
			[T]::PrintText("Yellow", "▶ 인코딩 설정 오류: $_")
		}
	}

	static [void] ScanProjects() {
		$root = $global:workspaceRoot
		[T]::PrintText("Cyan", "▶ 워크스페이스 루트: $root")

		if (-not (Test-Path $root)) {
			[T]::PrintExit("Red", "! 워크스페이스 경로가 존재하지 않습니다: $root")
		}

		$dirs = Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue
		if ($null -eq $dirs -or $dirs.Count -eq 0) {
			[T]::PrintExit("Red", "! 워크스페이스에 하위 프로젝트 폴더가 없습니다.")
		}

		$index = 1
		foreach ($dir in $dirs) {
			$gitPath = Join-Path $dir.FullName ".git"
			$isGit = Test-Path $gitPath
			if ($isGit) {
				$global:projectList += [PSCustomObject]@{
					number = $index
					name   = $dir.Name
					path   = $dir.FullName
				}
				$index++
			}
		}

		if ($global:projectList.Count -eq 0) {
			[T]::PrintExit("Red", "! .git 이 존재하는 프로젝트를 찾지 못했습니다.")
		}

		[T]::PrintLine("Cyan")
		[T]::PrintText("Cyan", "▶ Git 프로젝트 목록:")
		foreach ($p in $global:projectList) {
			[T]::PrintText("White", ("- {0}. {1}" -f $p.number, $p.name))
		}
	}

	static [void] SelectProject() {
		$inputs = ""
		[T]::PrintLine("Green")
		[T]::TextInput("Green", "▶ 사용할 프로젝트 번호를 입력하세요:", [ref]$inputs)
		[T]::PrintEmpty()

		if ([string]::IsNullOrWhiteSpace($inputs)) {
			[T]::PrintExit("Red", "! 최소 1개의 번호를 입력해야 합니다.")
		}

		try {
			$global:num = [int]$inputs
		}
		catch {
			[T]::PrintExit("Red", "! 올바른 숫자를 입력하세요.")
		}

		if ($global:num -lt 1 -or $global:num -gt $global:projectList.Count) {
			[T]::PrintExit("Red", ("! 번호 {0} 가 범위를 벗어났습니다. (1-{1})" -f $global:num, $global:projectList.Count))
		}

		$global:selectedProject = $global:projectList[$global:num - 1]
		[T]::PrintText(
			"Green",
			("▶ 선택된 프로젝트: {0} ({1})" -f $global:selectedProject.name, $global:selectedProject.path)
		)
	}

	static [string] ResolveGitHash([string]$inputHash) {
		if ([string]::IsNullOrWhiteSpace($inputHash)) {
			return ""
		}
		$resolved = git rev-parse "$inputHash" 2>$null
		return ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($resolved)) ? $inputHash : ""
	}

	static [string] GetShortHash([string]$fullHash) {
		$short = git rev-parse --short "$fullHash" 2>$null
		return $LASTEXITCODE -eq 0 ? $short : $fullHash
	}

	static [void] InputCommitAndOutput() {
		$projPath = $global:selectedProject.path
		$oldLocation = Get-Location
		Set-Location $projPath

		[T]::PrintLine("Cyan")
		[T]::PrintText("Cyan", "▶ Git 저장소 확인: $projPath")

		$inside = git rev-parse --is-inside-work-tree 2>$null
		if ($LASTEXITCODE -ne 0 -or $inside -ne "true") {
			Set-Location $oldLocation
			[T]::PrintExit("Red", "! 유효한 git 저장소가 아닙니다: $projPath")
		}

		# 1. Target Hash
		$targetInput = ""
		[T]::PrintLine("Green")
		[T]::PrintText("Green", "▶ 1. Target Hash (리포트 대상 최신 시점) 선택")
		[T]::TextInput("Green", "▶ Target 해시/참조 (엔터=HEAD):", [ref]$targetInput)

		$targetInput = [string]::IsNullOrWhiteSpace($targetInput) ? "HEAD" : $targetInput

		if (-not ([M]::ResolveGitHash($targetInput))) {
			Set-Location $oldLocation
			[T]::PrintExit("Red", ("! Target 커밋을 찾을 수 없습니다: {0}" -f $targetInput))
		}
		$global:targetHash = $targetInput
		$global:targetShort = [M]::GetShortHash($global:targetHash)

		# 2. Base Hash
		$baseInput = ""
		[T]::PrintEmpty()
		[T]::PrintText("Green", "▶ 2. Base Hash (비교할 기준/과거 시점) 선택")
		[T]::PrintText("White", ("  - Target({0})과 비교할 기준점을 입력하세요." -f $global:targetShort))
		[T]::TextInput("Green", "▶ Base 해시/참조 (엔터=Target~1):", [ref]$baseInput)

		$baseInput = [string]::IsNullOrWhiteSpace($baseInput) ? "$($global:targetHash)~1" : $baseInput

		if (-not ([M]::ResolveGitHash($baseInput))) {
			Set-Location $oldLocation
			[T]::PrintExit("Red", ("! Base 커밋을 찾을 수 없습니다: {0}" -f $baseInput))
		}
		$global:baseHash = $baseInput
		$global:baseShort = [M]::GetShortHash($global:baseHash)

		# 3. 출력 파일 이름 및 변경 파일 목록
		[T]::PrintEmpty()
		$defaultFileName = "gpt-notion-{0}-{1}.txt" -f $global:baseShort, $global:targetShort
		$outInput = ""
		[T]::TextInput(
			"Green",
			("▶ 출력 파일 이름을 입력하세요 (엔터={0}):" -f $defaultFileName),
			[ref]$outInput
		)
		[T]::PrintEmpty()

		$outName = [string]::IsNullOrWhiteSpace($outInput) ? $defaultFileName : $outInput.Trim()
		$outName = [string]::IsNullOrWhiteSpace($outName) ? $defaultFileName : $outName
		$global:outputFile = Join-Path $global:outputDir $outName

		$files = git diff --name-only --diff-filter=AM "$global:baseHash" "$global:targetHash"
		if ($LASTEXITCODE -ne 0) {
			Set-Location $oldLocation
			[T]::PrintExit("Red", "! 변경 파일 목록을 가져오는 중 오류가 발생했습니다.")
		}

		if (-not $files -or $files.Count -eq 0) {
			Set-Location $oldLocation
			[T]::PrintExit("Yellow", "! 두 커밋 사이에 변경된 파일(추가/수정)이 없습니다.")
		}

		$global:changedFiles = $files

		[T]::PrintLine("Cyan")
		[T]::PrintText("Cyan", ("▶ 변경 파일 목록 (Base: {0} -> Target: {1}):" -f $global:baseShort, $global:targetShort))
		foreach ($f in $global:changedFiles) {
			[T]::PrintText("White", ("  - {0}" -f $f))
		}

		[T]::PrintLine("Cyan")
		[T]::PrintText("Cyan", ("▶ 출력 파일: {0}" -f $global:outputFile))

		Set-Location $oldLocation
	}

	# 제거 대상 import 및 불필요한 코드 식별
	static [string] CleanupDiffImports([string]$content) {
		$blockedTokens = @(
			"import ",
			"package ",
			"com.",
			"java.",
			"org.",
			"lombok",
			"kms."
		)

		$lines = $content -split "`r?`n"
		$result = New-Object System.Collections.Generic.List[string]

		foreach ($line in $lines) {
			$trimmed = $line.TrimStart('+', '-', ' ')
			$skip = $false

			# import문 및 package문 필터링
			foreach ($token in $blockedTokens) {
				if ($trimmed -like "$token*") {
					$skip = $true
					break
				}
			}

			if (-not $skip) {
				$result.Add($line)
			}
		}

		return ($result -join "`r`n")
	}

	static [void] GeneratePromptFile() {
		$projPath = $global:selectedProject.path
		$oldLocation = Get-Location
		Set-Location $projPath

		[T]::PrintLine("Cyan")
		[T]::PrintText("Cyan", "▶ GPT 업무보고 생성용 프롬프트 파일 생성")

		if (-not (Test-Path $global:outputDir)) {
			New-Item -ItemType Directory -Path $global:outputDir -Force | Out-Null
			[T]::PrintText("Cyan", ("▶ 출력 디렉토리 생성: {0}" -f $global:outputDir))
		}

		$fileListBlock = ""
		foreach ($f in $global:changedFiles) {
			$fileListBlock += ("  - {0}`r`n" -f $f)
		}

		$prompt = $global:promptTemplate -f `
			$global:selectedProject.name, `
			$projPath, `
			$global:baseHash, `
			$global:baseShort, `
			$global:targetHash, `
			$global:targetShort, `
			$fileListBlock

		$sections = @()
		foreach ($f in $global:changedFiles) {
			$fileDiffLines = git diff --no-color --diff-filter=AM --unified=3 "$($global:baseHash)" "$($global:targetHash)" -- "$f"
			if ($LASTEXITCODE -ne 0) {
				[T]::PrintText("Yellow", ("! diff 생성 중 오류가 발생했습니다: {0}" -f $f))
				continue
			}
			if (-not $fileDiffLines -or $fileDiffLines.Count -eq 0) {
				continue
			}

			$fileDiffRaw = $fileDiffLines -join "`r`n"
			$fileDiff = [M]::CleanupDiffImports($fileDiffRaw)
			$section = $global:diffSectionTemplate -f $f, $fileDiff

			$sections += $section
		}

		if ($sections.Count -eq 0) {
			Set-Location $oldLocation
			[T]::PrintExit("Yellow", "! 실제 diff 내용이 존재하는 파일이 없습니다.")
		}

		$diffBlock = $sections -join "`r`n"
		$content = $prompt + "`r`n" + $diffBlock
		$content | Set-Content -Path $global:outputFile -Encoding UTF8

		[T]::PrintLine("Green")
		[T]::PrintText("Green", "▶ GPT 업무보고 생성용 프롬프트 파일 생성 완료")
		[T]::PrintText("White", ("  - 파일 경로: {0}" -f $global:outputFile))
		[T]::PrintText("White", "  - 이 파일 전체 내용을 GPT에 붙여넣으면 간결한 Notion용 MD가 생성됩니다.")

		Set-Location $oldLocation
	}

	static [void] Run1() {
		[M]::SetConsoleEncoding()
		[M]::ScanProjects()
		[M]::SelectProject()
		[M]::InputCommitAndOutput()
	}

	static [void] Run2() {
		[M]::GeneratePromptFile()
	}
}

# ---------------------------------------------------------------------
# 3. 프로세스 시작
# ---------------------------------------------------------------------
& {
	[T]::PrintLine("Cyan")
	[T]::PrintText("Cyan", "▶ 파일 이름: [$global:fileName]")
	[T]::PrintText("Cyan", "▶ 현재 시간: [$global:currentTime]")
	[T]::PrintText("Cyan", "▶ Korpay git 구간 Notion 업무보고 GPT 프롬프트 생성 시작")
}

# ---------------------------------------------------------------------
# 4. 메인 로직 실행
# ---------------------------------------------------------------------
& {
	[M]::Run1()
	[M]::Run2()
}

# ---------------------------------------------------------------------
# 99. 프로세스 종료
# ---------------------------------------------------------------------
& {
	[T]::PrintContinue($PSCommandPath)
}