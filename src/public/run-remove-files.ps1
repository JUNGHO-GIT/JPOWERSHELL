# run-removefiles.ps1

# 1. 공통 클래스 가져오기 ---------------------------------------------------------------------
using module ..\lib\classes.psm1

# 0. 전역변수 설정 ---------------------------------------------------------------------------
$global:line = "────────────────────────────────────────────────────────────────"
$global:currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$global:fileName = Split-Path -Leaf $PSCommandPath
$global:rootPath = "C:\JUNGHO\5.Ide\0.Vscode\Workspace\2.Project"
$global:ignoreFolders = @("node_modules", "bin", "target", "build", "out", "dist", ".gradle", ".idea", ".git", ".history")
$global:projectMarkers = @("package.json", "pom.xml", "build.gradle")
$global:deleteTargets = @()
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

	## 삭제 확인
	static [bool] ConfirmDelete() {
		[T]::PrintLine("Red")
		[T]::PrintText("Red", "▶ 삭제 작업 확인")
		[T]::PrintText("White", "- 삭제 대상: $($global:deleteTargets -join ', ')")
		[T]::PrintText("White", "- 대상 루트: $($global:selectedRoots -join ', ')")
		[T]::PrintText("White", "- 공통 경로: $($global:commonPath -eq '' ? '(프로젝트 루트)' : $global:commonPath)")
		[T]::PrintText("White", "- 제외 프로젝트: $($global:excludedProjects.Count)개")
		[T]::PrintEmpty()
		[T]::PrintText("Red", "! 이 작업은 되돌릴 수 없습니다.")
		[T]::PrintEmpty()

		$inputs = ""
		[T]::TextInput("Red", "▶ 계속하시겠습니까? (y/n):", ([ref]$inputs))

		return $inputs.Trim().ToLower() -eq "y"
	}

	## 삭제 실행
	static [void] ExecuteDelete() {
		[T]::PrintLine("Cyan")
		[T]::PrintText("Cyan", "▶ 삭제 작업 시작")
		[T]::PrintEmpty()

		$totalDeleted = 0
		$totalFailed = 0
		$totalSkipped = 0

		foreach ($root in $global:selectedRoots) {
			[T]::PrintLine("White")
			[T]::PrintText("White", "▶ 처리 중: $root")

			$projects = [M]::FindProjectRoots($root)
			[T]::PrintText("White", "▶ 발견된 프로젝트: $($projects.Count)개")
			[T]::PrintEmpty()

			$deleted = 0
			$failed = 0
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
					continue
				}

				foreach ($target in $global:deleteTargets) {
					$targetPath = Join-Path $targetDir $target

					if (Test-Path $targetPath) {
						try {
							Remove-Item -Path $targetPath -Recurse -Force
							[T]::PrintText("Green", "✓ 삭제: $targetPath")
							$deleted++
						}
						catch {
							[T]::PrintText("Red", "! 실패: $targetPath - $($_.Exception.Message)")
							$failed++
						}
					}
				}
			}

			[T]::PrintText("Green", "✓ 완료 - 삭제: $deleted | 실패: $failed | 건너뜀: $skipped")
			$totalDeleted += $deleted
			$totalFailed += $failed
			$totalSkipped += $skipped
		}

		[T]::PrintLine("Green")
		[T]::PrintText("Green", "▶ 전체 삭제 완료 - 삭제: $totalDeleted | 실패: $totalFailed | 건너뜀: $totalSkipped")
	}

	## 삭제 대상 입력
	static [void] Run1() {
		[T]::PrintLine("Yellow")
		[T]::PrintText("Yellow", "▶ 삭제할 파일/폴더명을 입력하세요")
		[T]::PrintText("DarkGray", "- 쉼표로 구분하여 다중 입력 가능")
		[T]::PrintText("DarkGray", "- 예: gitignore, .node, temp.txt")
		[T]::PrintEmpty()

		$inputs = ""
		[T]::TextInput("Yellow", "▶ 삭제 대상:", ([ref]$inputs))

		$targets = $inputs -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

		foreach ($target in $targets) {
			$global:deleteTargets += $target
			[T]::PrintText("Green", "✓ 추가됨: $target")
		}

		if ($global:deleteTargets.Count -eq 0) {
			[T]::PrintExit("Red", "! 최소 1개 이상의 삭제 대상이 필요합니다.")
		}
	}

	## 대상 루트 경로 선택
	static [void] Run2() {
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
	static [void] Run3() {
		[T]::PrintLine("Yellow")
		[T]::PrintText("Yellow", "▶ 프로젝트 폴더 내 공통 대상 경로를 입력하세요")
		[T]::PrintText("DarkGray", "- 예: .node, src/config, client/.node")
		[T]::PrintText("DarkGray", "- 빈 입력 = 프로젝트 루트에서 삭제")
		[T]::PrintEmpty()

		$inputs = ""
		[T]::TextInput("Yellow", "▶ 공통 경로:", ([ref]$inputs))

		$global:commonPath = $inputs.Trim()
		if ($global:commonPath -eq "") {
			[T]::PrintText("DarkGray", "- 프로젝트 루트에서 삭제합니다.")
		}
		else {
			[T]::PrintText("Green", "✓ 공통 경로: $global:commonPath")
		}
	}

	## 제외할 프로젝트 선택
	static [void] Run4() {
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
}

# 99. 프로세스 종료 ---------------------------------------------------------------------------
& {
	[T]::PrintContinue($PSCommandPath)
}