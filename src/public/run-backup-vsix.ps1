# run-backup-vsix.ps1

# 1. 공통 클래스 가져오기 ---------------------------------------------------------------------
using module ..\lib\classes.psm1

# 0. 전역변수 설정 ---------------------------------------------------------------------------
$global:line = "────────────────────────────────────────────────────────────────"
$global:currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$global:fileName = Split-Path -Leaf $PSCommandPath
$global:srcPath = Join-Path $env:USERPROFILE ".vscode\extensions"
$global:dstPath = "C:\JUNGHO\5.Ide\0.Vscode\Workspace\2.Project\1.Node\JNODE\src\public\vscode\vsix"
$global:extensions = @()

# 2. 메인 ------------------------------------------------------------------------------------
class M {
	# 2-1. 경로 유효성 검사 및 대상 경로 입력
	static [void] Run1() {
		$srcExists = Test-Path $global:srcPath

		if (!$srcExists) {
			[T]::PrintExit("Red", "! 소스 경로가 존재하지 않습니다: $global:srcPath") 
		}

		[T]::PrintText("Yellow", "▶ 소스 경로: $global:srcPath")
		[T]::PrintText("Yellow", "▶ 기본 대상 경로: $global:dstPath")
		[T]::PrintEmpty()

		$inputPath = $null
		[T]::TextInput("Green", "대상 경로를 입력하세요 (Enter: 기본경로 사용):", ([ref]$inputPath))

		if ($inputPath -and $inputPath.Trim() -ne "") {
			$global:dstPath = $inputPath.Trim()
		}

		$dstExists = Test-Path $global:dstPath
		if (!$dstExists) {
			New-Item -Path $global:dstPath -ItemType Directory -Force | Out-Null 
		}

		[T]::PrintText("Cyan", "▶ 선택된 대상 경로: $global:dstPath")
	}

	# 2-2. 확장 목록 조회 (일주일 이내 업데이트된 것만)
	static [void] Run2() {
		$weekAgo = (Get-Date).AddDays(-7)

		# 확장 폴더 패턴: publisher.extension-name-version (예: github.copilot-1.388.0)
		# 일주일 이내 수정된 폴더만 필터링
		$global:extensions = Get-ChildItem -Path $global:srcPath -Directory | Where-Object {
			$_.Name -match "^[a-zA-Z0-9-]+\.[a-zA-Z0-9-]+-\d+\.\d+\.\d+" -and $_.LastWriteTime -ge $weekAgo
		}

		[T]::PrintLine("Yellow")
		[T]::PrintText("Yellow", "▶ 기준일: $($weekAgo.ToString('yyyy-MM-dd')) 이후 업데이트")
		[T]::PrintText("Yellow", "▶ 발견된 확장 프로그램 수: $($global:extensions.Count)개")
	}

	# 2-3. 전체 백업 실행
	static [void] Run3() {
		if ($global:extensions.Count -eq 0) {
			[T]::PrintExit("Yellow", "! 백업할 확장 프로그램이 없습니다.") 
		}

		[T]::PrintLine("Yellow")
		[T]::PrintText("Yellow", "▶ 백업 시작...")
		[T]::PrintEmpty()

		$success = 0
		$failed = 0
		$total = $global:extensions.Count

		for ($i = 0; $i -lt $total; $i++) {
			$ext = $global:extensions[$i]
			$extName = $ext.Name
			$vsixPath = Join-Path $global:dstPath "$extName.vsix"
			$tempZip = Join-Path $env:TEMP "$extName.zip"
			$progress = "[$($i + 1)/$total]"
			$displayName = [T]::TextFormat($extName, 50)

			if (Test-Path $vsixPath) {
				Remove-Item $vsixPath -Force 
			}
			if (Test-Path $tempZip) {
				Remove-Item $tempZip -Force 
			}

			try {
				Compress-Archive -Path "$($ext.FullName)\*" -DestinationPath $tempZip -Force
				Move-Item -Path $tempZip -Destination $vsixPath -Force
				[T]::PrintText("Green", "$progress ✓ $displayName")
				$success++
			}
			catch {
				[T]::PrintText("Red", "$progress ✗ $displayName - $($_.Exception.Message)")
				$failed++
			}
			finally {
				if (Test-Path $tempZip) {
					Remove-Item $tempZip -Force -ErrorAction SilentlyContinue 
				}
			}
		}

		[T]::PrintLine("Cyan")
		[T]::PrintText("Cyan", "▶ 백업 완료!")
		[T]::PrintText("Green", "  - 성공: $success 개")
		if ($failed -gt 0) {
			[T]::PrintText("Red", "  - 실패: $failed 개") 
		}
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
}

# 99. 프로세스 종료 ---------------------------------------------------------------------------
& {
	[T]::PrintContinue($PSCommandPath)
}
