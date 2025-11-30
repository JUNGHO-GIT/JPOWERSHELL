# run-diffgit.ps1

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
$global:targetHash = "" # 최신 (Review 대상)
$global:baseHash = ""   # 과거 (비교 기준)
$global:targetShort = ""
$global:baseShort = ""
$global:outputFile = ""
$global:changedFiles = @()
$global:num = 0

# 메인 프롬프트 템플릿
# {0}: 프로젝트 이름, {1}: 프로젝트 경로, {2}: Base Hash, {3}: Base Short
# {4}: Target Hash, {5}: Target Short, {6}: 파일 목록 블록
$global:promptTemplate = @"
아래 내용은 git 프로젝트 [{0}] 의 구간 변경사항(Diff)입니다.

[Meta]
- 프로젝트 경로: {1}
- 기준 커밋 (Base): {2} (short: {3})
- 대상 커밋 (Target): {4} (short: {5})
- 변경된 파일 목록 (추가/수정된 파일만):
	{6}

[Review Request]
- 실제 동작을 바꾸는 변경과 리팩토링/스타일 변경을 구분해서 설명해 주세요.
- 심각도는 "High" / "Medium" / "Low" 로 구분해서 표기해 주세요.
- 과도한 설명은 생략하고, 핵심 이슈만 간단히 요약한 후 수정이 필요한 경우 수정된 코드를 제공해 주세요.
- 각 섹션은 독립적으로 리뷰해도 됩니다.
- 최대한 'Review Template' 의 형식에 맞춰서 각 파일별 답변형식을 통일해주세요.
- 중점적으로 봐야 할 부분:
	1) 예외 처리 누락 여부
	2) 성능 / 리소스 낭비 가능성 (쿼리, 컬렉션, 루프 등)
	3) 불필요한 복잡도, 과한 분기, 중복 코드
	4) 함수/메서드/변수 네이밍 및 책임 분리

[Review Template]
## 파일: Foo.java
### - 심각도: 'High'
### - 문제사항: ....
### - 수정전 부분
	```javascript
	FOO
	```
### - 수정후 부분
	```javascript
	FOO
	```
"@

# 파일별 Diff 섹션 템플릿
# {0}: 파일 경로/이름
# {1}: Diff 내용
$global:diffSectionTemplate = @"
	---------------------------------------------------------------------
	[FILE] {0}
	---------------------------------------------------------------------
	{1}
"@

# 2. 메인 ----------------------------------------------------------------------------------------
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
				$index = $index + 1
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
		if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($resolved)) {
			return ""
		}
		return $inputHash
	}

	static [string] GetShortHash([string]$fullHash) {
		$short = git rev-parse --short "$fullHash" 2>$null
		if ($LASTEXITCODE -ne 0) {
			return $fullHash
		}
		return $short
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
		[T]::PrintText("Green", "▶ 1. Target Hash (리뷰할 최신 시점) 선택")
		[T]::TextInput("Green", "▶ Target 해시/참조 (엔터=HEAD):", [ref]$targetInput)

		if ([string]::IsNullOrWhiteSpace($targetInput)) {
			$targetInput = "HEAD"
		}
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

		if ([string]::IsNullOrWhiteSpace($baseInput)) {
			$baseInput = "$($global:targetHash)~1"
		}
		if (-not ([M]::ResolveGitHash($baseInput))) {
			Set-Location $oldLocation
			[T]::PrintExit("Red", ("! Base 커밋을 찾을 수 없습니다: {0}" -f $baseInput))
		}
		$global:baseHash = $baseInput
		$global:baseShort = [M]::GetShortHash($global:baseHash)

		# 3. 출력 파일 이름 및 변경 파일 목록
		[T]::PrintEmpty()
		$defaultFileName = ("gpt-{0}-{1}.txt" -f $global:baseShort, $global:targetShort)
		$outInput = ""
		[T]::TextInput(
			"Green",
			("▶ 출력 파일 이름을 입력하세요 (엔터={0}):" -f $defaultFileName),
			[ref]$outInput
		)
		[T]::PrintEmpty()

		if ([string]::IsNullOrWhiteSpace($outInput)) {
			$outName = $defaultFileName
		}
		else {
			$outName = $outInput.Trim()
		}
		if ([string]::IsNullOrWhiteSpace($outName)) {
			$outName = $defaultFileName
		}
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

	# 제거 대상 import 식별 키워드 (패키지/타입 단위)
	static [string] CleanupDiffImports([string]$content) {
		$blockedTokens = @(
			"com",
			"java",
			"org",
			"lombok",
			"kms"
		)

		# 라인 단위로 파싱해서 import 라인만 선택적으로 제거
		$lines = $content -split "`r`n"
		$result = New-Object System.Collections.Generic.List[string]

		foreach ($line in $lines) {
			$trimmed = $line.TrimStart()

			if ($trimmed -match '^[+ ]*import\s+(.+);') {
				$importPart = $matches[1]
				$skip = $false

				foreach ($token in $blockedTokens) {
					if ($importPart -like ("*{0}*" -f $token)) {
						$skip = $true
						break
					}
				}

				if ($skip) {
					continue
				}
			}

			$result.Add($line) | Out-Null
		}

		return ($result -join "`r`n")
	}

	static [void] GeneratePromptFile() {
		$projPath = $global:selectedProject.path
		$oldLocation = Get-Location
		Set-Location $projPath

		[T]::PrintLine("Cyan")
		[T]::PrintText("Cyan", "▶ GPT 전송용 프롬프트 + Diff 파일 생성")

		if (-not (Test-Path $global:outputDir)) {
			New-Item -ItemType Directory -Path $global:outputDir -Force | Out-Null
			[T]::PrintText("Cyan", ("▶ 출력 디렉토리 생성: {0}" -f $global:outputDir))
		}

		$fileListBlock = ""
		foreach ($f in $global:changedFiles) {
			$fileListBlock += ("- {0}`r`n" -f $f)
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
		[T]::PrintText("Green", "▶ GPT 전송용 파일 생성 완료")
		[T]::PrintText("White", ("  - 파일 경로: {0}" -f $global:outputFile))
		[T]::PrintText("White", "  - 이 파일 전체 내용을 그대로 복사해서 GPT 입력창에 붙여넣으면 됩니다.")

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
	[T]::PrintText("Cyan", "▶ Korpay git 구간(Range) diff 프롬프트 생성 시작")
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
