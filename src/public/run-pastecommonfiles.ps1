# run-paste.ps1

# 1. 공통 클래스 가져오기 ---------------------------------------------------------------------
using module ..\common\classes.psm1

# 0. 전역변수 설정 ---------------------------------------------------------------------------
$global:line = "────────────────────────────────────────────────────────────────"
$global:currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$global:fileName = Split-Path -Leaf $PSCommandPath
$global:rootPath = "C:\JUNGHO\2.IDE\2.Vscode\Workspace\2.Project"
$global:selectedFolder = @(".github", ".node")
$global:targetPath = @("0.Java", "1.Node")
$global:ignoreFolders = @("node_modules", "bin", "target", "build", "out", "dist", ".gradle", ".idea")
$global:workTypes = @()
$global:selectedRoots = @()
$global:deleteFiles = @()
$global:workInput = ""
$global:targetInput = ""
$global:deleteInput = ""

# 2. 메인  ---------------------------------------------------------------------------
class M {
	## .github 폴더 정리
	static [int] CleanupGitHub([string[]]$roots) {
		[T]::PrintLine("Cyan")
		[T]::PrintText("Cyan", "▶ .github 폴더 정리 (bin/target/client 내부)")
		[T]::PrintEmpty()

		$count = 0
		foreach ($root in $roots) {
			Get-ChildItem -Path $root -Directory -Recurse -Force -Filter ".github" -ErrorAction SilentlyContinue | Where-Object {
				$_.FullName -match '\\(bin|target|client)\\'
			} | ForEach-Object {
				try {
					Remove-Item -Path $_.FullName -Recurse -Force
					[T]::PrintText("Yellow", "✓ 삭제됨: $($_.FullName)")
					$count++
				}
				catch {
					[T]::PrintText("Red", "! 삭제 실패: $($_.FullName)")
				}
			}
		}
		[T]::PrintLine("Green")
		[T]::PrintText("Green", "✓ 정리 완료: $count 개 폴더 삭제됨")
		return $count
	}

	## .github 폴더 복사
	static [hashtable] CopyGitHub([string]$source, [string[]]$roots) {
		[T]::PrintLine("Cyan")
		[T]::PrintText("Cyan", "▶ .github 폴더 복사 시작")
		[T]::PrintEmpty()

		$totalSuccess = 0
		$totalFail = 0

		foreach ($root in $roots) {
			[T]::PrintLine("White")
			[T]::PrintText("White", "- 처리중: $root")
			[T]::PrintEmpty()

			$result = [M]::ProcessDirectory($root, {
				param($dir)

				$pkg = Join-Path $dir.FullName "package.json"
				if (-not (Test-Path $pkg)) {
					return $null
				}

				if ($dir.Name -eq "client") {
					[T]::PrintText("DarkGray", "- client 폴더 건너뜀: $($dir.FullName)")
					return $null
				}

				[T]::PrintText("White", "- 처리 중: $($dir.FullName)")
				try {
					$target = Join-Path $dir.FullName ".github"

					if (Test-Path $target) {
						Remove-Item -Path $target -Recurse -Force
					}

					Copy-Item -Path $source -Destination $target -Recurse -Force
					[T]::PrintLine("Green")
					[T]::PrintText("Green", "✓ .github 복사 완료")

					$clientGithub = Join-Path (Join-Path $dir.FullName "client") ".github"
					if (Test-Path $clientGithub) {
						Remove-Item -Path $clientGithub -Recurse -Force
						[T]::PrintLine("Yellow")
						[T]::PrintText("Yellow", "✓ client/.github 삭제 완료")
					}

					[T]::PrintEmpty()
					return @{ "success" = $true }
				}
				catch {
					[T]::PrintText("Red", "! 에러: $($_.Exception.Message)")
					return @{ "success" = $false }
				}
			})

			[T]::PrintLine("Green")
			[T]::PrintText("Green", "✓ 루트 완료 - 성공: $($result.success) | 실패: $($result.fail)")
			$totalSuccess += $result.success
			$totalFail += $result.fail
		}

		return @{ "success" = $totalSuccess; "fail" = $totalFail }
	}

	## .node 파일 복사
	static [hashtable] CopyNode([string]$source, [string[]]$roots) {
		[T]::PrintLine("Cyan")
		[T]::PrintText("Cyan", "▶ .node 파일 복사 시작")
		[T]::PrintEmpty()

		$files = Get-ChildItem -Path $source -File -Force -ErrorAction SilentlyContinue
		if ($files.Count -eq 0) {
			[T]::PrintExit("Red", "! 소스 경로에 파일이 없습니다: $source")
		}

		[T]::PrintText("Green", "✓ $($files.Count)개 파일 발견")
		$totalSuccess = 0
		$totalFail = 0

		foreach ($root in $roots) {
			[T]::PrintLine("White")
			[T]::PrintText("White", "- 처리중: $root")
			[T]::PrintEmpty()

			$result = [M]::ProcessDirectory($root, {
				param($dir)

				$pkg = Join-Path $dir.FullName "package.json"
				if (-not (Test-Path $pkg)) {
					return $null
				}

				[T]::PrintEmpty()
				[T]::PrintLine("DarkGray")
				[T]::PrintText("White", "- 처리 중: $($dir.FullName)")

				$success = 0
				$fail = 0

				$nodePath = Join-Path $dir.FullName ".node"
				if (Test-Path $nodePath) {
					try {
						$files | ForEach-Object {
							Copy-Item -Path $_.FullName -Destination (Join-Path $nodePath $_.Name) -Force
						}
						[T]::PrintText("Green", "✓ .node에 $($files.Count)개 파일 복사 완료")
						$success++
					}
					catch {
						[T]::PrintText("Red", "! .node 복사 실패: $($_.Exception.Message)")
						$fail++
					}
				}
				else {
					[T]::PrintText("DarkGray", "- .node 폴더 없음, 건너뜀")
				}

				$clientPath = Join-Path $dir.FullName "client"
				$clientPkg = Join-Path $clientPath "package.json"
				$clientNodePath = Join-Path $clientPath ".node"

				if ((Test-Path $clientPath) -and (Test-Path $clientPkg) -and (Test-Path $clientNodePath)) {
					try {
						$files | ForEach-Object {
							Copy-Item -Path $_.FullName -Destination (Join-Path $clientNodePath $_.Name) -Force
						}
						[T]::PrintText("Green", "✓ client/.node에 $($files.Count)개 파일 복사 완료")
						$success++
					}
					catch {
						[T]::PrintText("Red", "! client/.node 복사 실패: $($_.Exception.Message)")
						$fail++
					}
				}

				return ($success -gt 0) ? @{ "success" = $true } : @{ "success" = $false }
			})

			[T]::PrintLine("Green")
			[T]::PrintText("Green", "✓ 루트 완료 - 성공: $($result.success) | 실패: $($result.fail)")
			$totalSuccess += $result.success
			$totalFail += $result.fail
		}

		return @{ "success" = $totalSuccess; "fail" = $totalFail }
	}

	## 파일 삭제
	static [hashtable] DeleteFiles([string[]]$fileNames, [string[]]$roots) {
		[T]::PrintLine("Cyan")
		[T]::PrintText("Cyan", "▶ 파일 삭제 시작")
		[T]::PrintEmpty()

		$totalSuccess = 0
		$totalFail = 0

		foreach ($root in $roots) {
			[T]::PrintLine("White")
			[T]::PrintText("White", "- 처리중: $root")
			[T]::PrintEmpty()

			$result = [M]::ProcessDirectory($root, {
				param($dir)

				[T]::PrintText("White", "- 처리 중: $($dir.FullName)")
				$deletedCount = 0
				$failedCount = 0

				foreach ($fileName in $fileNames) {
					$filePath = Join-Path $dir.FullName $fileName
					if (Test-Path $filePath) {
						try {
							Remove-Item -Path $filePath -Force -Recurse
							[T]::PrintText("Green", "✓ 삭제됨: $filePath")
							$deletedCount++
						}
						catch {
							[T]::PrintText("Red", "! 삭제 실패: $filePath - $($_.Exception.Message)")
							$failedCount++
						}
					}
				}

				if ($deletedCount -gt 0 -or $failedCount -gt 0) {
					return @{ "success" = ($deletedCount -gt 0) }
				}
				else {
					return $null
				}
			})

			[T]::PrintLine("Green")
			[T]::PrintText("Green", "✓ 루트 완료 - 성공: $($result.success) | 실패: $($result.fail)")
			$totalSuccess += $result.success
			$totalFail += $result.fail
		}

		return @{ "success" = $totalSuccess; "fail" = $totalFail }
	}

	## 디렉토리 순회 처리
	static [hashtable] ProcessDirectory([string]$root, [scriptblock]$action) {
		$stack = New-Object System.Collections.Generic.Stack[System.IO.DirectoryInfo]
		$stack.Push((Get-Item -Path $root))
		$success = 0
		$fail = 0

		while ($stack.Count -gt 0) {
			$dir = $stack.Pop()

			if ($global:ignoreFolders -contains $dir.Name) {
				continue
			}

			$result = & $action $dir
			if ($null -ne $result) {
				if ($result.success) {
					$success++
				}
				else {
					$fail++
				}
			}

			try {
				Get-ChildItem -Path $dir.FullName -Directory -Force -ErrorAction SilentlyContinue | Where-Object {
					$global:ignoreFolders -notcontains $_.Name
				} | ForEach-Object {
					$stack.Push($_)
				}
			}
			catch {
				[T]::PrintText("Yellow", "! 경고: $($dir.FullName) 하위 조회 실패")
			}
		}

		return @{ "success" = $success; "fail" = $fail }
	}
}

# 3. 프로세스 시작 ----------------------------------------------------------------------------
& {
	[T]::PrintLine("Cyan")
	[T]::PrintText("Cyan", "▶ $fileName 스크립트 시작")
	[T]::PrintText("Cyan", "▶ 현재 시간: [$global:currentTime]")
}

# 4. 사용자 입력 처리 -------------------------------------------------------------------------
& {
	[T]::PrintLine("Yellow")
	[T]::PrintText("Yellow", "▶ 복사할 폴더를 선택하세요 (여러 개 선택 가능)")
	for ($i = 0; $i -lt $selectedFolder.Count; $i++) {
		[T]::PrintText("White", "- $($i + 1): $($selectedFolder[$i])")
	}
	[T]::PrintEmpty()
	[T]::TextInput("Yellow", "▶ 폴더 선택 (쉼표로 구분, 예: 1,2):", ([ref]$global:workInput))

	$workIndices = $global:workInput -split "," | ForEach-Object { $_.Trim() }
	foreach ($idx in $workIndices) {
		if ($idx -match "^\d+$" -and [int]$idx -ge 1 -and [int]$idx -le $selectedFolder.Count) {
			$global:workTypes += $idx
			[T]::PrintText("Green", "✓ 선택됨: $($selectedFolder[[int]$idx - 1])")
		}
		else {
			[T]::PrintText("Red", "! 잘못된 선택: $idx")
		}
	}

	if ($global:workTypes.Count -eq 0) {
		[T]::PrintExit("Red", "! 최소 1개 이상의 폴더를 선택해야 합니다.")
	}

	[T]::PrintLine("Yellow")
	[T]::PrintText("Yellow", "▶ 대상 경로를 선택하세요 (여러 개 선택 가능)")
	for ($i = 0; $i -lt $targetPath.Count; $i++) {
		[T]::PrintText("White", "- $($i + 1): $($targetPath[$i])")
	}
	[T]::PrintEmpty()
	[T]::TextInput("Yellow", "▶ 선택 (쉼표로 구분, 예: 1,2):", ([ref]$targetInput))

	$targetIndices = $targetInput -split "," | ForEach-Object { $_.Trim() }
	foreach ($idx in $targetIndices) {
		if ($idx -match "^\d+$" -and [int]$idx -ge 1 -and [int]$idx -le $targetPath.Count) {
			$targetRoot = Join-Path $rootPath $targetPath[[int]$idx - 1]
			if (Test-Path $targetRoot) {
				$global:selectedRoots += $targetRoot
				[T]::PrintText("Green", "✓ 추가됨: $targetRoot")
			}
			else {
				[T]::PrintText("Red", "! 경로를 찾을 수 없습니다: $targetRoot")
			}
		}
		else {
			[T]::PrintText("Red", "! 잘못된 선택: $idx")
		}
	}

	if ($global:selectedRoots.Count -eq 0) {
		[T]::PrintExit("Red", "! 최소 1개 이상의 대상 경로가 필요합니다.")
	}

	[T]::PrintLine("Yellow")
	[T]::PrintText("Yellow", "▶ 삭제할 파일명을 입력하세요 (선택사항, 여러 개 가능)")
	[T]::PrintText("DarkGray", "- 예: file1.txt,file2.js")
	[T]::PrintText("DarkGray", "- 입력 없이 Enter 시 건너뜀")
	[T]::PrintEmpty()
	[T]::TextInput("Yellow", "▶ 파일명 (쉼표로 구분):", ([ref]$global:deleteInput))

	if ($global:deleteInput.Trim() -ne "") {
		$deleteNames = $global:deleteInput -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
		foreach ($name in $deleteNames) {
			$global:deleteFiles += $name
			[T]::PrintText("Green", "✓ 삭제 대상: $name")
		}
	}
	else {
		[T]::PrintText("DarkGray", "- 파일 삭제 건너뜀")
	}
}

# 5. 파일 삭제 실행 ---------------------------------------------------------------------------
& {
	if ($global:deleteFiles.Count -gt 0) {
		$result = [M]::DeleteFiles($global:deleteFiles, $global:selectedRoots)
		[T]::PrintLine("Green")
		[T]::PrintText("Green", "▶ 파일 삭제 완료 - 성공: $($result.success) | 실패: $($result.fail)")
	}
}

# 6. 복사 작업 실행 ---------------------------------------------------------------------------
& {
	foreach ($workType in $global:workTypes) {
		$folderName = $selectedFolder[[int]$workType - 1]
		$sourcePath = Join-Path $rootPath $folderName

		if (-not (Test-Path $sourcePath)) {
			[T]::PrintText("Red", "! 소스 경로를 찾을 수 없습니다: $sourcePath")
			continue
		}

		[T]::PrintLine("Cyan")
		[T]::PrintText("Cyan", "✓ 소스 경로: $sourcePath")

		if ($workType -eq "1") {
			[M]::CleanupGitHub($global:selectedRoots)
			$result = [M]::CopyGitHub($sourcePath, $global:selectedRoots)
			[T]::PrintLine("Green")
			[T]::PrintText("Green", "▶ .github 작업 완료 - 성공: $($result.success) | 실패: $($result.fail)")
		}

		if ($workType -eq "2") {
			$result = [M]::CopyNode($sourcePath, $global:selectedRoots)
			[T]::PrintLine("Green")
			[T]::PrintText("Green", "▶ .node 작업 완료 - 성공: $($result.success) | 실패: $($result.fail)")
		}
	}
}

# 99. 프로세스 종료 ---------------------------------------------------------------------------
& {
	[T]::PrintLine("Green")
	[T]::PrintExit("Green", "✓ 모든 작업이 정상적으로 완료되었습니다.")
}
