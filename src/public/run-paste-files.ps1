# run-pastefiles.ps1

# 1. 공통 클래스 가져오기 ---------------------------------------------------------------------
using module ..\lib\classes.psm1

# 0. 전역변수 설정 ---------------------------------------------------------------------------
$global:line = "────────────────────────────────────────────────────────────────"
$global:currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$global:fileName = Split-Path -Leaf $PSCommandPath
$global:rootPath = "C:\JUNGHO\5.Ide\0.Vscode\Workspace\2.Project"
$global:ignoreFolders = @("node_modules", "bin", "target", "build", "out", "dist", ".gradle", ".idea", ".git", ".history")
$global:projectMarkers = @("package.json", "pom.xml", "build.gradle")
$global:sourceFolder = ""
$global:sourceFiles = @()
$global:selectedRoots = @()
$global:commonPath = ""
$global:allProjects = @()
$global:excludedProjects = @()

# 2. 메인 -------------------------------------------------------------------------------------
class M {
	## 프로젝트 루트인지 확인
	static [bool] IsProjectRoot([string]$path) {
		foreach ($marker in $global:projectMarkers) {
			$markerPath = Join-Path $path $marker
			if (Test-Path $markerPath) {
				return $true
			}
		}
		return $false
	}

	## 프로젝트 루트 목록 찾기 (직계 자식 + client 폴더)
	static [System.Collections.ArrayList] FindProjectRoots([string]$root) {
		$projects = New-Object System.Collections.ArrayList
		$childDirs = Get-ChildItem -Path $root -Directory -Force -ErrorAction SilentlyContinue

		foreach ($dir in $childDirs) {
			if ($global:ignoreFolders -contains $dir.Name) {
				continue
			}

			if ([M]::IsProjectRoot($dir.FullName)) {
				[void]$projects.Add($dir.FullName)

				# client 하위 폴더도 프로젝트로 추가
				$clientPath = Join-Path $dir.FullName "client"
				if ((Test-Path $clientPath) -and [M]::IsProjectRoot($clientPath)) {
					[void]$projects.Add($clientPath)
				}
			}
		}

		return $projects
	}

	## 소스 폴더 선택
	static [void] Run1() {
		[T]::PrintLine("Yellow")
		[T]::PrintText("Yellow", "▶ 소스 폴더를 선택하세요 (rootPath 기준)")
		[T]::PrintText("DarkGray", "- rootPath: $global:rootPath")
		[T]::PrintEmpty()

		$folders = Get-ChildItem -Path $global:rootPath -Directory -Force -ErrorAction SilentlyContinue | Sort-Object Name
		if ($folders.Count -eq 0) {
			[T]::PrintExit("Red", "! rootPath에 폴더가 없습니다.")
		}

		for ($i = 0; $i -lt $folders.Count; $i++) {
			[T]::PrintText("White", "- $($i + 1): $($folders[$i].Name)")
		}
		[T]::PrintEmpty()

		$inputs = ""
		[T]::TextInput("Yellow", "▶ 폴더 선택:", ([ref]$inputs))

		$idx = $inputs.Trim()
		$valid = $idx -match "^\d+$" -and [int]$idx -ge 1 -and [int]$idx -le $folders.Count
		if (-not $valid) {
			[T]::PrintExit("Red", "! 잘못된 선택입니다.")
		}

		$global:sourceFolder = $folders[[int]$idx - 1].FullName
		[T]::PrintText("Green", "✓ 소스 폴더: $global:sourceFolder")
	}

	## 소스 파일 선택
	static [void] Run2() {
		[T]::PrintLine("Yellow")
		[T]::PrintText("Yellow", "▶ 복사할 파일을 선택하세요")
		[T]::PrintEmpty()

		$files = Get-ChildItem -Path $global:sourceFolder -File -Force -ErrorAction SilentlyContinue
		if ($files.Count -eq 0) {
			[T]::PrintExit("Red", "! 폴더에 파일이 없습니다: $global:sourceFolder")
		}

		for ($i = 0; $i -lt $files.Count; $i++) {
			[T]::PrintText("White", "- $($i + 1): $($files[$i].Name)")
		}
		[T]::PrintEmpty()

		$inputs = ""
		[T]::TextInput("Yellow", "▶ 파일 선택 (쉼표로 구분, 예: 1,2,3 / all=전체):", ([ref]$inputs))

		if ($inputs.Trim().ToLower() -eq "all") {
			foreach ($file in $files) {
				$global:sourceFiles += $file.Name
				[T]::PrintText("Green", "✓ 선택됨: $($file.Name)")
			}
		}
		else {
			$indices = $inputs -split "," | ForEach-Object { $_.Trim() }
			foreach ($idx in $indices) {
				if ($idx -match "^\d+$" -and [int]$idx -ge 1 -and [int]$idx -le $files.Count) {
					$global:sourceFiles += $files[[int]$idx - 1].Name
					[T]::PrintText("Green", "✓ 선택됨: $($files[[int]$idx - 1].Name)")
				}
				else {
					[T]::PrintText("Red", "! 잘못된 선택: $idx")
				}
			}
		}

		if ($global:sourceFiles.Count -eq 0) {
			[T]::PrintExit("Red", "! 최소 1개 이상의 파일을 선택해야 합니다.")
		}
	}

	## 대상 루트 경로 선택
	static [void] Run3() {
		[T]::PrintLine("Yellow")
		[T]::PrintText("Yellow", "▶ 대상 루트 경로를 선택하세요 (다중 선택 가능)")
		[T]::PrintEmpty()

		$folders = Get-ChildItem -Path $global:rootPath -Directory -Force -ErrorAction SilentlyContinue | Sort-Object Name
		if ($folders.Count -eq 0) {
			[T]::PrintExit("Red", "! rootPath에 폴더가 없습니다.")
		}

		for ($i = 0; $i -lt $folders.Count; $i++) {
			[T]::PrintText("White", "- $($i + 1): $($folders[$i].Name)")
		}
		[T]::PrintEmpty()

		$inputs = ""
		[T]::TextInput("Yellow", "▶ 선택 (쉼표로 구분, 예: 1,2):", ([ref]$inputs))

		$indices = $inputs -split "," | ForEach-Object { $_.Trim() }
		foreach ($idx in $indices) {
			if ($idx -match "^\d+$" -and [int]$idx -ge 1 -and [int]$idx -le $folders.Count) {
				$targetRoot = $folders[[int]$idx - 1].FullName
				$global:selectedRoots += $targetRoot
				[T]::PrintText("Green", "✓ 추가됨: $targetRoot")
			}
			else {
				[T]::PrintText("Red", "! 잘못된 선택: $idx")
			}
		}

		if ($global:selectedRoots.Count -eq 0) {
			[T]::PrintExit("Red", "! 최소 1개 이상의 대상 경로가 필요합니다.")
		}
	}

	## 공통 대상 경로 입력
	static [void] Run4() {
		[T]::PrintLine("Yellow")
		[T]::PrintText("Yellow", "▶ 프로젝트 폴더 내 공통 대상 경로를 입력하세요")
		[T]::PrintText("DarkGray", "- 예: .node, src/config, client/.node")
		[T]::PrintText("DarkGray", "- 빈 입력 = 프로젝트 루트에 복사")
		[T]::PrintEmpty()

		$inputs = ""
		[T]::TextInput("Yellow", "▶ 공통 경로:", ([ref]$inputs))

		$global:commonPath = $inputs.Trim()
		if ($global:commonPath -eq "") {
			[T]::PrintText("DarkGray", "- 프로젝트 루트에 복사합니다.")
		}
		else {
			[T]::PrintText("Green", "✓ 공통 경로: $global:commonPath")
		}
	}

	## 제외할 프로젝트 선택
	static [void] Run5() {
		[T]::PrintLine("Yellow")
		[T]::PrintText("Yellow", "▶ 발견된 프로젝트 목록")
		[T]::PrintEmpty()

		# 모든 프로젝트 수집
		$global:allProjects = @()
		foreach ($root in $global:selectedRoots) {
			$projects = [M]::FindProjectRoots($root)
			foreach ($project in $projects) {
				$global:allProjects += $project
			}
		}

		if ($global:allProjects.Count -eq 0) {
			[T]::PrintExit("Red", "! 프로젝트가 발견되지 않았습니다.")
		}

		# 프로젝트 목록 출력
		for ($i = 0; $i -lt $global:allProjects.Count; $i++) {
			$relativePath = $global:allProjects[$i].Replace($global:rootPath, "").TrimStart("\")
			[T]::PrintText("White", "- $($i + 1): $relativePath")
		}
		[T]::PrintEmpty()

		[T]::PrintText("DarkGray", "- 제외할 프로젝트 번호를 입력하세요")
		[T]::PrintText("DarkGray", "- 빈 입력 = 모든 프로젝트 포함")
		[T]::PrintEmpty()

		$inputs = ""
		[T]::TextInput("Yellow", "▶ 제외할 프로젝트 (쉼표로 구분, 예: 1,3,5):", ([ref]$inputs))

		if ($inputs.Trim() -ne "") {
			$indices = $inputs -split "," | ForEach-Object { $_.Trim() }
			foreach ($idx in $indices) {
				if ($idx -match "^\d+$" -and [int]$idx -ge 1 -and [int]$idx -le $global:allProjects.Count) {
					$excludePath = $global:allProjects[[int]$idx - 1]
					$global:excludedProjects += $excludePath
					$relativePath = $excludePath.Replace($global:rootPath, "").TrimStart("\")
					[T]::PrintText("Red", "✗ 제외됨: $relativePath")
				}
				else {
					[T]::PrintText("Red", "! 잘못된 선택: $idx")
				}
			}
		}
		else {
			[T]::PrintText("DarkGray", "- 모든 프로젝트가 포함됩니다.")
		}

		$includeCount = $global:allProjects.Count - $global:excludedProjects.Count
		[T]::PrintEmpty()
		[T]::PrintText("Green", "✓ 포함될 프로젝트: $includeCount 개")
	}

	## 파일 복사 실행
	static [void] Run6() {
		[T]::PrintLine("Cyan")
		[T]::PrintText("Cyan", "▶ 작업 요약")
		[T]::PrintText("White", "- 소스: $global:sourceFolder")
		[T]::PrintText("White", "- 파일: $($global:sourceFiles -join ', ')")
		[T]::PrintText("White", "- 대상 루트: $($global:selectedRoots -join ', ')")
		[T]::PrintText("White", "- 공통 경로: $($global:commonPath -eq '' ? '(프로젝트 루트)' : $global:commonPath)")
		[T]::PrintText("White", "- 제외 프로젝트: $($global:excludedProjects.Count)개")
		[T]::PrintEmpty()

		$totalSuccess = 0
		$totalFail = 0
		$totalSkipped = 0

		foreach ($root in $global:selectedRoots) {
			[T]::PrintLine("White")
			[T]::PrintText("White", "▶ 처리 중: $root")

			$projects = [M]::FindProjectRoots($root)
			[T]::PrintText("White", "▶ 발견된 프로젝트: $($projects.Count)개")
			[T]::PrintEmpty()

			$success = 0
			$fail = 0
			$skipped = 0

			foreach ($project in $projects) {
				# 제외된 프로젝트 건너뛰기
				if ($global:excludedProjects -contains $project) {
					$relativePath = $project.Replace($global:rootPath, "").TrimStart("\")
					[T]::PrintText("DarkGray", "- 건너뜀 (제외됨): $relativePath")
					$skipped++
					continue
				}

				$targetDir = $global:commonPath -eq "" ? $project : (Join-Path $project $global:commonPath)

				if (-not (Test-Path $targetDir)) {
					[T]::PrintText("DarkGray", "- 경로 없음: $targetDir")
					continue
				}

				[T]::PrintText("White", "- 복사 중: $targetDir")
				$copied = 0

				foreach ($fileName in $global:sourceFiles) {
					$sourcePath = Join-Path $global:sourceFolder $fileName
					$destPath = Join-Path $targetDir $fileName

					try {
						Copy-Item -Path $sourcePath -Destination $destPath -Force
						[T]::PrintText("Green", "  ✓ $fileName")
						$copied++
					}
					catch {
						[T]::PrintText("Red", "  ! $fileName - $($_.Exception.Message)")
					}
				}

				if ($copied -gt 0) {
					$success++
				}
				else {
					$fail++
				}
			}

			[T]::PrintText("Green", "✓ 완료 - 성공: $success | 실패: $fail | 건너뜀: $skipped")
			$totalSuccess += $success
			$totalFail += $fail
			$totalSkipped += $skipped
		}

		[T]::PrintLine("Green")
		[T]::PrintText("Green", "▶ 전체 복사 완료 - 성공: $totalSuccess | 실패: $totalFail | 건너뜀: $totalSkipped")
	}
}

# 3. 프로세스 시작 ----------------------------------------------------------------------------
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
	[M]::Run5()
	[M]::Run6()
}

# 99. 프로세스 종료 ---------------------------------------------------------------------------
& {
	[T]::PrintContinue($PSCommandPath)
}