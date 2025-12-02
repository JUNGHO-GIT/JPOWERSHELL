# run-simlink.ps1

# 1. 공통 클래스 가져오기 ---------------------------------------------------------------------
using module ..\common\classes.psm1

# 0. 전역변수 설정 ---------------------------------------------------------------------------
$global:line = "────────────────────────────────────────────────────────────────"
$global:currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$global:fileName = Split-Path -Leaf $PSCommandPath
$global:sourcePaths = @()
$global:targetBasePaths = @()
$global:isDirectory = $false
$global:cloneType = ""

# 2. 메인 ----------------------------------------------------------------------------------------
class M {

	# 2-1. 복제 정보 입력 -------------------------------------------------------------------
	static [void] Run1() {
		[T]::PrintLine("Yellow")
		[T]::PrintText("Yellow", "▶ 복제 대상 정보를 입력합니다.")

		# 1. 복제 유형 선택
		do {
			$global:cloneType = ""
			[T]::TextInput("Green", "번호를 입력하세요. (1.file / 2.dir)", [ref]$global:cloneType)

			$global:cloneType = $global:cloneType.Trim()

			if ([string]::IsNullOrWhiteSpace($global:cloneType)) {
				[T]::PrintText("Red", "✗ 복제 유형은 비워둘 수 없습니다. 다시 입력하세요.")
			}
			else {
				$global:cloneType = $global:cloneType.ToLower()
				$global:cloneType = $global:cloneType -eq "1" ? "file" : $global:cloneType -eq "2" ? "dir" : $global:cloneType

				if ($global:cloneType -ne "file" -and $global:cloneType -ne "dir") {
					[T]::PrintText("Red", "✗ 복제 유형은 '1', '2', 'file', 'dir' 만 입력할 수 있습니다.")
					$global:cloneType = ""
				}
			}
		} while ([string]::IsNullOrWhiteSpace($global:cloneType))

		$global:isDirectory = $global:cloneType -eq "dir"

		# 2. 원본 경로 입력 (파일인 경우 콤마로 다중 입력 가능)
		$promptMsg = $global:isDirectory ? "복제할 원본 폴더 경로를 입력하세요." : "복제할 원본 파일 경로를 입력하세요. (콤마로 다중 파일 가능)"
		do {
			$global:sourcePaths = @()
			$inputSources = ""
			[T]::TextInput("Green", $promptMsg, [ref]$inputSources)

			$inputSources.Split(",") | ForEach-Object {
				$trimmed = $_.Trim('"').Trim()
				(-not [string]::IsNullOrWhiteSpace($trimmed)) ? ($global:sourcePaths += $trimmed) : $null
			}

			($global:sourcePaths.Count -eq 0) ? [T]::PrintText("Red", "✗ 원본 경로는 비워둘 수 없습니다. 다시 입력하세요.") : $null
		} while ($global:sourcePaths.Count -eq 0)

		# 3. 대상 경로 입력 (콤마로 다중 경로 지원)
		do {
			$global:targetBasePaths = @()
			$inputTargets = ""
			[T]::TextInput("Green", "대상 경로를 입력하세요. (콤마로 다중 경로 가능, 원본명 자동 추가)", [ref]$inputTargets)

			$inputTargets.Split(",") | ForEach-Object {
				$trimmed = $_.Trim('"').Trim()
				(-not [string]::IsNullOrWhiteSpace($trimmed)) ? ($global:targetBasePaths += $trimmed) : $null
			}

			($global:targetBasePaths.Count -eq 0) ? [T]::PrintText("Red", "✗ 대상 경로는 비워둘 수 없습니다. 다시 입력하세요.") : $null
		} while ($global:targetBasePaths.Count -eq 0)

		[T]::PrintEmpty()
		[T]::PrintText("Cyan", "원본 경로 ($($global:sourcePaths.Count)개):")
		$global:sourcePaths | ForEach-Object { [T]::PrintText("Cyan", "  → $_") }
		[T]::PrintText("Cyan", "대상 경로 ($($global:targetBasePaths.Count)개):")
		$global:targetBasePaths | ForEach-Object { [T]::PrintText("Cyan", "  → $_") }
	}

	# 2-2. 경로 유효성 검사 ---------------------------------------------------------------------
	static [void] Run2() {
		[T]::PrintLine("Yellow")
		[T]::PrintText("Yellow", "▶ 경로 유효성 검사를 수행합니다.")

		# 원본 경로 검증
		foreach ($sourcePath in $global:sourcePaths) {
			if (-not (Test-Path -LiteralPath $sourcePath)) {
				[T]::PrintExit("Red", "✗ 원본 경로가 존재하지 않습니다: $sourcePath")
			}

			try {
				$sourceItem = Get-Item -LiteralPath $sourcePath -ErrorAction Stop
				if ($sourceItem.PSIsContainer -and -not $global:isDirectory) {
					[T]::PrintExit("Red", "✗ 디렉터리를 선택했지만 복제 유형을 'file' 로 지정했습니다: $sourcePath")
				}
				if (-not $sourceItem.PSIsContainer -and $global:isDirectory) {
					[T]::PrintExit("Red", "✗ 파일을 선택했지만 복제 유형을 'dir' 로 지정했습니다: $sourcePath")
				}
			}
			catch {
				[T]::PrintExit("Red", "✗ 원본 정보를 가져오는 중 오류가 발생했습니다: $($_.Exception.Message)")
			}
		}

		# 대상 경로 검증 및 준비
		foreach ($targetBase in $global:targetBasePaths) {
			foreach ($sourcePath in $global:sourcePaths) {
				$sourceName = Split-Path -Leaf $sourcePath
				$targetPath = Join-Path $targetBase $sourceName

				if (Test-Path -LiteralPath $targetPath) {
					try {
						$existingItem = Get-Item -LiteralPath $targetPath -Force
						$isLink = $existingItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint
						$isLink ? (
							(Remove-Item -LiteralPath $targetPath -Force -ErrorAction Stop),
							[T]::PrintText("Magenta", "  기존 링크 삭제: $targetPath")
						) : (
							(Remove-Item -LiteralPath $targetPath -Recurse -Force -ErrorAction Stop),
							[T]::PrintText("Magenta", "  기존 항목 삭제: $targetPath")
						)
					}
					catch {
						[T]::PrintExit("Red", "✗ 기존 경로 삭제 중 오류가 발생했습니다: $($_.Exception.Message)")
					}
				}

				$targetParent = Split-Path -Parent $targetPath
				if (-not [string]::IsNullOrWhiteSpace($targetParent) -and -not (Test-Path -LiteralPath $targetParent)) {
					try {
						New-Item -ItemType Directory -Path $targetParent -ErrorAction Stop | Out-Null
						[T]::PrintText("Cyan", "  상위 폴더 생성: $targetParent")
					}
					catch {
						[T]::PrintExit("Red", "✗ 대상의 상위 경로를 생성하는 중 오류가 발생했습니다: $($_.Exception.Message)")
					}
				}
			}
		}

		[T]::PrintText("Green", "✓ 경로 유효성 검사가 완료되었습니다.")
	}

	# 2-3. 심볼릭 링크 생성 ---------------------------------------------------------------------------
	static [void] Run3() {
		[T]::PrintLine("Yellow")
		[T]::PrintText("Yellow", "▶ 심볼릭 링크(또는 정션) 생성 작업을 시작합니다.")

		$linkType = $global:isDirectory ? "Junction" : "SymbolicLink"
		$linkName = $global:isDirectory ? "폴더 정션(Junction)" : "파일 심볼릭 링크(SymbolicLink)"

		foreach ($targetBase in $global:targetBasePaths) {
			foreach ($sourcePath in $global:sourcePaths) {
				$sourceName = Split-Path -Leaf $sourcePath
				$targetPath = Join-Path $targetBase $sourceName

				try {
					[T]::PrintText("Cyan", "$linkName 생성 중: $targetPath")
					New-Item -ItemType $linkType -Path $targetPath -Target $sourcePath -ErrorAction Stop | Out-Null
					[T]::PrintText("Green", "  ✓ 생성 완료")
				}
				catch {
					[T]::PrintText("Red", "  ✗ 링크 생성 실패: $($_.Exception.Message)")
				}
			}
		}

		[T]::PrintText("Green", "✓ 모든 링크 생성 작업이 완료되었습니다.")
	}
}

# 3. 프로세스 시작 --------------------------------------------------------------------------------
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
}

# 99. 프로세스 종료 ---------------------------------------------------------------------------
& {
	[T]::PrintContinue($PSCommandPath)
}