# fix-pwshloading.ps1

# 1. 공통 클래스 가져오기 ---------------------------------------------------------------------
using module ..\lib\classes.psm1

# 0. 전역변수 설정 ---------------------------------------------------------------------------
$global:line = "────────────────────────────────────────────────────────────────"
$global:currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$global:fileName = Split-Path -Leaf $PSCommandPath
$global:registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\SystemCertificates\ChainEngine"
$global:timeoutValue = 1000

# 2. 메인 ----------------------------------------------------------------------------------------
class M {
	static [void] Run1() {
		try {
			# 레지스트리 키 생성 (관리자 권한 필요)
			(Test-Path $global:registryPath) -eq $false && (New-Item -Path $global:registryPath -Force -ErrorAction Stop | Out-Null)

			# 하위 키 생성
			(Test-Path "$global:registryPath\Config") -eq $false && (New-Item -Path "$global:registryPath\Config" -Force -ErrorAction Stop | Out-Null)

			# 타임아웃 값 설정 (1초 = 1000ms)
			Set-ItemProperty -Path "$global:registryPath\Config" -Name ChainUrlRetrievalTimeoutMilliseconds -Value $global:timeoutValue -Type DWORD -Force -ErrorAction Stop

			Set-ItemProperty -Path "$global:registryPath\Config" -Name ChainRevAccumulativeUrlRetrievalTimeoutMilliseconds -Value $global:timeoutValue -Type DWORD -Force -ErrorAction Stop
		}
		catch {
			[T]::PrintLine("Red")
			[T]::PrintExit("Red", "! 오류가 발생하여 작업을 종료합니다.`n`n$($_.Exception.Message)`n")
		}
	}
}

# 3. 프로세스 시작 --------------------------------------------------------------------------------
& {
	[T]::PrintLine("Cyan")
	[T]::PrintText("Cyan", "▶ 파일 이름: [$global:fileName]")
	[T]::PrintText("Cyan", "▶ 현재 시간: [$global:currentTime]")
}

# 10. 메인 로직 실행 -----------------------------------------------------------------------------
& {
	[M]::Run1()
}

# 99. 프로세스 종료 ---------------------------------------------------------------------------
& {
	[T]::PrintContinue($PSCommandPath)
}