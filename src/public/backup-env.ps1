# run-envbackup.ps1

# 1. 공통 클래스 가져오기 ---------------------------------------------------------------------
using module ..\common\classes.psm1

# 0. 전역변수 설정 ---------------------------------------------------------------------------
$global:line = "────────────────────────────────────────────────────────────────"
$global:currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$global:fileName = Split-Path -Leaf $PSCommandPath
$global:outputPath = "C:\Users\jungh\Downloads\env_variables.txt"

# 2. 메인 ----------------------------------------------------------------------------------------
class M {
	static [void] Run1() {
		try {
			[T]::PrintLine("Yellow")
			[T]::PrintText("Yellow", "▶ 환경변수 백업 시작")

			# 기존 파일이 있으면 삭제
			if (Test-Path $global:outputPath) {
				Remove-Item $global:outputPath
			}

			# 환경변수를 파일에 저장
			Get-ChildItem Env: | ForEach-Object {
				"$($_.Name)=$($_.Value)" | Out-File -FilePath $global:outputPath -Append -Encoding UTF8
			}

			[T]::PrintLine("Green")
			[T]::PrintText("Green", "✓ 환경변수들이 $global:outputPath 에 저장되었습니다.")
		}
		catch {
			[T]::PrintLine("Red")
			[T]::PrintText("Red", "! 환경변수 백업 중 오류가 발생했습니다: $($_.Exception.Message)")
			[T]::PrintExit("Red", "! 프로세스를 종료합니다.")
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
}

# 99. 프로세스 종료 ---------------------------------------------------------------------------
& {
	[T]::PrintContinue($PSCommandPath)
}