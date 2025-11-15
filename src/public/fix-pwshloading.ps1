# fix-pwshloading.ps1

# 0. 전역변수 설정 ---------------------------------------------------------------------------
$global:line = "────────────────────────────────────────────────────────────────"
$global:currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$global:fileName = Split-Path -Leaf $PSCommandPath
$global:registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\SystemCertificates\ChainEngine"
$global:timeoutValue = 1000

# 1. 텍스트 -----------------------------------------------------------------------------------
class T {
	## 줄나눔 출력
	static [void] PrintEmpty() {
		Write-Host ""
	}

	## 줄 구분자 출력
	static [void] PrintLine(
		[string]$color = "White"
	) {
		Write-Host ""
		Write-Host $global:line -ForegroundColor $color
	}

	## 텍스트 출력
	static [void] PrintText(
		[string]$color = "White",
		[string]$message = ""
	) {
		Write-Host $message -ForegroundColor $color
	}

	## 종료 메시지 출력
	static [void] PrintExit(
		[string]$color = "Red",
		[string]$message = ""
	) {
		Write-Host $message -ForegroundColor $color
		Write-Host "! 아무 키나 누르면 종료됩니다..." -ForegroundColor $color
		[void][System.Console]::ReadKey($true)
		exit
	}

	## 텍스트 포맷
	static [string] TextFormat(
		[string]$str = "",
		[int]$target = 50
	) {
		$str = "$str"
		$width = 0
		$result = ""
		foreach ($ch in $str.ToCharArray()) {
			$len = ([System.Text.Encoding]::GetEncoding("euc-kr").GetByteCount($ch))
			if ($width + $len -gt $target) {
				break
			}
			$result += $ch
			$width += $len
		}
		$pad = $target - $width
		$pad -gt 0 && ($result += (" " * $pad))
		return $result
	}

	## 텍스트 입력
	static [void] TextInput(
		[string]$color = "Green",
		[string]$message = "",
		[ref]$target
	) {
		Write-Host $message -ForegroundColor $color
		$target.Value = Read-Host "- "
	}
}

# 2. 메인 ----------------------------------------------------------------------------------------
class M {
	static [void] Run() {
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
	[M]::Run()
}

# 99. 프로세스 종료 ---------------------------------------------------------------------------
& {
	[T]::PrintLine("Green")
	[T]::PrintExit("Green", "✓ 모든 작업이 정상적으로 완료되었습니다.")
}