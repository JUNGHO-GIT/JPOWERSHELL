# run-gcloud.ps1

# 1. 공통 클래스 가져오기 ---------------------------------------------------------------------
using module ..\common\classes.psm1

# 0. 전역변수 설정 ---------------------------------------------------------------------------
$global:line = "────────────────────────────────────────────────────────────────"
$global:currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$global:fileName = Split-Path -Leaf $PSCommandPath
$global:keyPath = "C:\Users\jungh\.ssh\JKEY"
$global:parameter = "junghomun00@104.196.212.101"

# 3. 프로세스 시작 --------------------------------------------------------------------------------
& {
	[T]::PrintLine("Cyan")
	[T]::PrintText("Cyan", "▶ 파일 이름: [$global:fileName]")
	[T]::PrintText("Cyan", "▶ 현재 시간: [$global:currentTime]")
}

# 4. ssh 접속 --------------------------------------------------------------------------------------
& {
	[T]::PrintLine("Yellow")
	[T]::PrintText("Yellow", "▶ gcloud SSH 접속 시작")

	try {
		# SSH 접속 명령어 실행
		$sshCommand = "ssh -i `"$global:keyPath`" $global:parameter"
		Start-Process powershell -ArgumentList "-NoExit", "-Command", $sshCommand

		[T]::PrintLine("Green")
		[T]::PrintText("Green", "✓ gcloud SSH 접속 명령어가 실행되었습니다.")
	}
	catch {
		[T]::PrintLine("Red")
		[T]::PrintText("Red", "! gcloud SSH 접속 중 오류가 발생했습니다: $($_.Exception.Message)")
		[T]::PrintExit("Red", "! 프로세스를 종료합니다.")
	}
}

# 99. 프로세스 종료 ---------------------------------------------------------------------------
& {
	[T]::PrintContinue($PSCommandPath)
}
