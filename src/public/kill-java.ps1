# kill-java.ps1

# 0. 전역변수 설정 ---------------------------------------------------------------------------
$global:line = "────────────────────────────────────────────────────────────────"
$global:currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$global:fileName = Split-Path -Leaf $PSCommandPath
$global:javaProcesses = Get-Process java -ErrorAction SilentlyContinue

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