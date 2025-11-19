# kill-java.ps1

# 0. 전역변수 설정 ---------------------------------------------------------------------------
$global:line = "────────────────────────────────────────────────────────────────"
$global:currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$global:fileName = Split-Path -Leaf $PSCommandPath
$global:javaProcesses = Get-Process java -ErrorAction SilentlyContinue

# 1. 공통 클래스 가져오기 ---------------------------------------------------------------------
. "$PSScriptRoot/../common/classes.ps1"

# 3. 프로세스 시작 --------------------------------------------------------------------------------
& {
	[T]::PrintLine("Cyan")
	[T]::PrintText("Cyan", "▶ 파일 이름: [$global:fileName]")
	[T]::PrintText("Cyan", "▶ 현재 시간: [$global:currentTime]")
}

# 4. 메인 실행 ------------------------------------------------------------------------------------
& {
	if ($global:javaProcesses) {
		foreach ($process in $global:javaProcesses) {
			[T]::PrintLine("Yellow")
			[T]::PrintText("Yellow", "▶ 실행 중인 Java 프로세스가 발견되었습니다:")
			[T]::PrintText("Yellow", " - 프로세스 이름: $($process.Name)")
			[T]::PrintText("Yellow", " - 프로세스 ID: $($process.Id)")
			[T]::PrintText("Yellow", " - 시작 시간: $($process.StartTime)")
			[T]::PrintLine("Yellow")
			[T]::PrintText("Yellow", "▶ 모든 Java 프로세스를 강제 종료합니다...")
			Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
			[T]::PrintText("Yellow", "▶ 프로세스 ID $($process.Id) 가 종료되었습니다.")
		}
	}
	else {
		[T]::PrintLine("Yellow")
		[T]::PrintText("Yellow", "! 실행 중인 Java 프로세스가 없습니다.")
	}
}

# 99. 프로세스 종료 ---------------------------------------------------------------------------
& {
	[T]::PrintLine("Green")
	[T]::PrintExit("Green", "✓ 모든 작업이 정상적으로 완료되었습니다.")
}