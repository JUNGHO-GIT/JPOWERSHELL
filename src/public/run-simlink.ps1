# run-simlink.ps1

# 1. 공통 클래스 가져오기 ---------------------------------------------------------------------
using module ..\common\classes.psm1

# 0. 전역변수 설정 ---------------------------------------------------------------------------
$global:line = "────────────────────────────────────────────────────────────────"
$global:currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$global:fileName = Split-Path -Leaf $PSCommandPath
$global:sourcePath = ""
$global:targetPath = ""
$global:isDirectory = $false
$global:cloneType = ""
$global:sourceItem = $null
$global:targetParent = ""

# 2. 메인 ----------------------------------------------------------------------------------------
class M {

	static [void] Run1() {
		[T]::PrintLine("Yellow")
		[T]::PrintText("Yellow", "▶ 복제 대상 정보를 입력합니다.")

		# 2-1. 복제 유형 선택 -------------------------------------------------------------------
		do {
			$global:cloneType = ""
			[T]::TextInput("Green", "번호를 입력하세요. (1.file / 2.dir)", [ref]$global:cloneType)

			$global:cloneType = $global:cloneType.Trim()

			if ([string]::IsNullOrWhiteSpace($global:cloneType)) {
				[T]::PrintText("Red", "✗ 복제 유형은 비워둘 수 없습니다. 다시 입력하세요.")
			}
			else {
				$global:cloneType = $global:cloneType.ToLower()
				if ($global:cloneType -eq "1") {
					$global:cloneType = "file"
				}
				elseif ($global:cloneType -eq "2") {
					$global:cloneType = "dir"
				}

				if ($global:cloneType -ne "file" -and $global:cloneType -ne "dir") {
					[T]::PrintText("Red", "✗ 복제 유형은 '1', '2', 'file', 'dir' 만 입력할 수 있습니다. 다시 입력하세요.")
					$global:cloneType = ""
				}
			}
		} while ([string]::IsNullOrWhiteSpace($global:cloneType))

		# 2-2. 원본 경로 입력 -------------------------------------------------------------------
		do {
			$global:sourcePath = ""
			[T]::TextInput("Green", "복제할 원본 경로를 입력하세요.", [ref]$global:sourcePath)
			$global:sourcePath = $global:sourcePath.Trim('"').Trim()

			if ([string]::IsNullOrWhiteSpace($global:sourcePath)) {
				[T]::PrintText("Red", "✗ 원본 경로는 비워둘 수 없습니다. 다시 입력하세요.")
			}
		} while ([string]::IsNullOrWhiteSpace($global:sourcePath))

		# 2-3. 대상 경로 입력 -------------------------------------------------------------------
		do {
			$global:targetPath = ""
			[T]::TextInput("Green", "복제본(링크)이 생성될 대상 경로를 입력하세요.", [ref]$global:targetPath)
			$global:targetPath = $global:targetPath.Trim('"').Trim()

			if ([string]::IsNullOrWhiteSpace($global:targetPath)) {
				[T]::PrintText("Red", "✗ 대상 경로는 비워둘 수 없습니다. 다시 입력하세요.")
			}
		} while ([string]::IsNullOrWhiteSpace($global:targetPath))

		$global:isDirectory = $global:cloneType -eq "dir"

		[T]::PrintEmpty()
		[T]::PrintText("Cyan", "원본 경로 : [$global:sourcePath]")
		[T]::PrintText("Cyan", "대상 경로 : [$global:targetPath]")
	}

	static [void] Run2() {
		[T]::PrintLine("Yellow")
		[T]::PrintText("Yellow", "▶ 경로 유효성 검사를 수행합니다.")

		if (-not (Test-Path -LiteralPath $global:sourcePath)) {
			[T]::PrintExit("Red", "✗ 원본 경로가 존재하지 않습니다: $global:sourcePath")
		}

		try {
			$global:sourceItem = Get-Item -LiteralPath $global:sourcePath -ErrorAction Stop
		}
		catch {
			[T]::PrintExit("Red", "✗ 원본 정보를 가져오는 중 오류가 발생했습니다: $($_.Exception.Message)")
		}

		if ($global:sourceItem.PSIsContainer -and -not $global:isDirectory) {
			[T]::PrintExit("Red", "✗ 디렉터리를 선택했지만 복제 유형을 'file' 로 지정했습니다. 'dir' 로 다시 실행하세요.")
		}
		if (-not $global:sourceItem.PSIsContainer -and $global:isDirectory) {
			[T]::PrintExit("Red", "✗ 파일을 선택했지만 복제 유형을 'dir' 로 지정했습니다. 'file' 로 다시 실행하세요.")
		}

		if (Test-Path -LiteralPath $global:targetPath) {
			[T]::PrintExit("Red", "✗ 대상 경로가 이미 존재합니다. 다른 경로를 지정하거나 수동으로 정리한 후 다시 실행하세요.`n  → $global:targetPath")
		}

		if ($global:isDirectory) {
			$global:targetParent = Split-Path -Parent $global:targetPath
			if (-not [string]::IsNullOrWhiteSpace($global:targetParent) -and -not (Test-Path -LiteralPath $global:targetParent)) {
				try {
					New-Item -ItemType Directory -Path $global:targetParent -ErrorAction Stop | Out-Null
				}
				catch {
					[T]::PrintExit("Red", "✗ 대상 폴더의 상위 경로를 생성하는 중 오류가 발생했습니다: $($_.Exception.Message)")
				}
			}
		}
		else {
			$global:targetParent = Split-Path -Parent $global:targetPath
			if (-not [string]::IsNullOrWhiteSpace($global:targetParent) -and -not (Test-Path -LiteralPath $global:targetParent)) {
				try {
					New-Item -ItemType Directory -Path $global:targetParent -ErrorAction Stop | Out-Null
				}
				catch {
					[T]::PrintExit("Red", "✗ 대상 파일의 상위 폴더를 생성하는 중 오류가 발생했습니다: $($_.Exception.Message)")
				}
			}
		}

		[T]::PrintText("Green", "✓ 경로 유효성 검사가 완료되었습니다.")
	}

	static [void] Run3() {
		[T]::PrintLine("Yellow")
		[T]::PrintText("Yellow", "▶ 심볼릭 링크(또는 정션) 생성 작업을 시작합니다.")

		try {
			if ($global:isDirectory) {
				[T]::PrintText("Cyan", "폴더 정션(Junction) 생성 중...")
				New-Item -ItemType Junction -Path $global:targetPath -Target $global:sourcePath -ErrorAction Stop | Out-Null
				[T]::PrintText("Green", "✓ 폴더 정션이 성공적으로 생성되었습니다.")
			}
			else {
				[T]::PrintText("Cyan", "파일 심볼릭 링크(SymbolicLink) 생성 중...")
				New-Item -ItemType SymbolicLink -Path $global:targetPath -Target $global:sourcePath -ErrorAction Stop | Out-Null
				[T]::PrintText("Green", "✓ 파일 심볼릭 링크가 성공적으로 생성되었습니다.")
			}
		}
		catch {
			[T]::PrintExit("Red", "✗ 링크 생성 중 오류가 발생했습니다: $($_.Exception.Message)")
		}
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
