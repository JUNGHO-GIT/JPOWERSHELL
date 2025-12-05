# review-notion.ps1

# 1. 공통 클래스 가져오기 ---------------------------------------------------------------------
using module ..\lib\classes.psm1

# 0. 전역변수 설정 ---------------------------------------------------------------------------
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
# {0}: 프로젝트 이름, {1}: 프로젝트 경로, {2}: Base Hash, {3}: Base Short
# {4}: Target Hash, {5}: Target Short, {6}: 변경 파일 목록
# ---------------------------------------------------------------------
$global:promptTemplate = @(
	"# Git Diff → Notion 업무보고 변환 요청",
	"",
	"## 프로젝트 정보",
	"| 항목 | 값 |",
	"|------|-----|",
	"| 프로젝트 | {0} |",
	"| 경로 | {1} |",
	"| Base 커밋 | {2} ({3}) |",
	"| Target 커밋 | {4} ({5}) |",
	"",
	"## 변경 파일 목록",
	"{6}",
	"",
	"---",
	"",
	"## 작성 요청사항",
	"",
	"### 핵심 원칙",
	"1. **코드 최소화**: 파일당 핵심 로직 5줄 이내, 불필요 시 생략",
	"2. **변경 요약 중심**: 무엇을 왜 바꿨는지 1-2문장으로 설명",
	"3. **제외 대상**: getter/setter, 로깅, 주석, import, 포맷팅 변경",
	"4. **생략 활용**: 긴 코드는 ``...``로 생략",
	"",
	"### 파일 분류 기준",
	"| 분류 | 확장자/경로 |",
	"|------|-------------|",
	"| 클라이언트 | .html, .js, .jsx, .ts, .tsx, .css, .vue |",
	"| 서버 | .java, .kt, .py, .go, .properties, .yml |",
	"| DB | .xml, .sql, mapper/, repository/ 경로 |",
	"",
	"---",
	"",
	"## 응답 형식",
	"",
	"### 1. 개요",
	"#### 1-1. 특징",
	"- 전체 변경사항 요약 (1-3줄)",
	"",
	"---",
	"",
	"### 2. 작업 내용",
	"",
	"#### 2-1. 클라이언트",
	"**파일명**: ``경로/파일.html``",
	"1. **변경 제목**: 설명 1-2문장",
	"2. **변경 제목**: 설명 1-2문장",
	"",
	"**핵심 코드** (선택적):",
	"``````javascript",
	"// 핵심 로직만 3-5줄",
	"function process(data) {{{{",
	"  // ...",
	"}}}}",
	"``````",
	"",
	"---",
	"",
	"#### 2-2. 서버",
	"**파일명**: ``경로/파일.java``",
	"1. **변경 제목**: 설명 1-2문장",
	"",
	"**핵심 코드** (선택적):",
	"``````java",
	"// 핵심 비즈니스 로직만",
	"public Result process(Request req) {{{{",
	"  // ...",
	"}}}}",
	"``````",
	"",
	"---",
	"",
	"#### 2-3. 데이터베이스",
	"**파일명**: ``경로/파일.xml``",
	"1. **변경 제목**: 설명 1-2문장",
	"",
	"**핵심 쿼리** (선택적):",
	"``````sql",
	"SELECT * FROM table WHERE condition",
	"``````",
	"",
	"---",
	"",
	"### 3. 수정사항",
	"#### 3-1. 변경 이력",
	"| 날짜 | 내용 |",
	"|------|------|",
	"| (Target 커밋 날짜) | 주요 변경 내용 요약 |",
	"",
	"---",
	"",
	"## Diff 내용"
) -join "`r`n"

# 2. 메인 ---------------------------------------------------------------------------
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

	static [array] GetTrackedChangedFiles([string]$baseHash, [string]$targetHash) {
		# git diff로 변경된 파일 중 추적되는 파일만 가져오기
		$allFiles = git diff --name-only --diff-filter=AM "$baseHash" "$targetHash" 2>$null
		if ($LASTEXITCODE -ne 0 -or -not $allFiles) {
			return @()
		}

		$trackedFiles = @()
		foreach ($file in $allFiles) {
			# git check-ignore로 gitignore 대상인지 확인
			git check-ignore -q "$file" 2>$null
			if ($LASTEXITCODE -ne 0) {
				# LASTEXITCODE가 0이 아니면 gitignore 대상이 아님 (추적 대상)
				$trackedFiles += $file
			}
		}

		return $trackedFiles
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
		$defaultFileName = "notion-{0}-{1}.txt" -f $global:baseShort, $global:targetShort
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

		# gitignore 필터링 적용
		$files = [M]::GetTrackedChangedFiles($global:baseHash, $global:targetHash)
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
		[T]::PrintText("Cyan", "▶ GPT Notion 업무보고 생성용 프롬프트 파일 생성")

		if (-not (Test-Path $global:outputDir)) {
			New-Item -ItemType Directory -Path $global:outputDir -Force | Out-Null
			[T]::PrintText("Cyan", ("▶ 출력 디렉토리 생성: {0}" -f $global:outputDir))
		}

		# 파일 목록 블록 생성
		$fileListBlock = ($global:changedFiles | ForEach-Object { "- $_" }) -join "`r`n"

		# 프롬프트 템플릿에 값 바인딩
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

			# 배열 + join 방식으로 섹션 생성
			$section = @(
				"",
				"### FILE: $f",
				"``````diff",
				$fileDiff,
				"``````"
			) -join "`r`n"
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
		[T]::PrintText("Green", "▶ GPT Notion 업무보고 생성용 프롬프트 파일 생성 완료")
		[T]::PrintText("White", ("  - 파일 경로: {0}" -f $global:outputFile))
		[T]::PrintText("White", "  - 이 파일 내용을 GPT에 붙여넣으면 Notion용 MD가 생성됩니다.")

		Set-Location $oldLocation
	}

	static [void] Run1() {
		[M]::SetConsoleEncoding()
		[M]::ScanProjects()
	}

	static [void] Run2() {
		[M]::SelectProject()
	}

	static [void] Run3() {
		[M]::InputCommitAndOutput()
	}

	static [void] Run4() {
		[M]::GeneratePromptFile()
	}
}

# 3. 프로세스 시작 ---------------------------------------------------------------------------
& {
	[T]::PrintLine("Cyan")
	[T]::PrintText("Cyan", "▶ 파일 이름: [$global:fileName]")
	[T]::PrintText("Cyan", "▶ 현재 시간: [$global:currentTime]")
}

# 4. 메인 로직 실행 ---------------------------------------------------------------------------
& {
	[M]::Run1()
	[M]::Run2()
	[M]::Run3()
	[M]::Run4()
}

# 99. 프로세스 종료 ---------------------------------------------------------------------------
& {
	[T]::PrintContinue($PSCommandPath)
}