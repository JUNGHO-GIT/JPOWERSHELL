# 1. 공통 클래스 가져오기 ---------------------------------------------------------------------
using module ..\lib\classes.psm1

# 0. 전역변수 설정 ---------------------------------------------------------------------------
$global:line = "────────────────────────────────────────────────────────────────"
$global:currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$global:fileName = Split-Path -Leaf $PSCommandPath

# ▼ 키 경로와 접속 정보 확인
$global:keyPath = "C:\Users\jungh\.ssh\JKEY" 
$global:parameter = "junghomun00@104.196.212.101"

# 2. 메인 ----------------------------------------------------------------------------------------
class M {
	static [void] Run1() {
		[T]::PrintLine("Yellow")
		[T]::PrintText("Yellow", "▶ SSH 화면으로 전환합니다... (종료하려면 exit 입력)")
    
		# ------------------------------------------------------------------------
		# [핵심 수정] Start-Process 사용
		# -NoNewWindow: 새 창을 띄우지 않고 현재 창을 사용합니다.
		# -Wait: SSH가 끝날 때까지 PowerShell이 대기합니다.
		# ------------------------------------------------------------------------
    
		# 명령어 인자 구성 (배열로 전달해야 안전합니다)
		# 주의: 윈도우에서는 .ppk 파일이 작동하지 않습니다. 반드시 OpenSSH 키여야 합니다.
		$sshArgs = @("-i", $global:keyPath, $global:parameter)

		try {
			# SSH 프로세스에 화면 제어권을 완전히 넘깁니다.
			$process = Start-Process -FilePath "ssh" -ArgumentList $sshArgs -NoNewWindow -Wait -PassThru
        
			if ($process.ExitCode -ne 0) {
				[T]::PrintLine("Red")
				[T]::PrintText("Red", "! 접속이 비정상적으로 종료되었습니다. (코드: $($process.ExitCode))")
				[T]::PrintText("Red", "! 키 파일 형식이 올바른지(.ppk 아님), IP가 맞는지 확인하세요.")
			}
		}
		catch {
			[T]::PrintLine("Red")
			[T]::PrintText("Red", "! SSH 실행 실패: $($_.Exception.Message)")
		}

		[T]::PrintLine("Green")
		[T]::PrintText("Green", "✓ 로컬 터미널로 복귀했습니다.")
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