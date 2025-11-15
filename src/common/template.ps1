# template.ps1

# - 해당 파일의 기본 구조나 형식을 따릅니다.
# - 특히 'T' 클래스는 수정하지 않고 그대로 사용합니다.
# - 기존코드의 주석은 유지합니다.
# 2.메인, 3.프로세스 시작, 4.메인 로직 실행, 99.프로세스 종료 형식을 반드시 지킵니다.

# 0. 전역변수 설정 ---------------------------------------------------------------------------
# - 공통적으로 쓰이는 전역변수를 정의합니다.
# - 파일이름, 파일경로 ..., 레지스트리 경로, ... 등은 왠만하면 전역변수로 정의합니다.
$global:line = "────────────────────────────────────────────────────────────────"
$global:currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$global:fileName = Split-Path -Leaf $PSCommandPath

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
		[T]::PrintLine("Red")
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
# - 역할에 따라서 메서드를 구분하여 작성합니다.
# - 작성한 메서드는 M 클래스 내부에서 호출지말고 메인 로직 실행 부분에서 호출합니다.
# - 따라서 메서드 간의 의존성을 최소화합니다.
# - M 클래스 내부에서는 [T] 클래스 메서드들을 자유롭게 호출할 수 있습니다.!!
class M {
	static [void] Run1() {
	}
	static [void] Run2() {
	}
	static [void] Run3() {
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
	[T]::PrintLine("Green")
	[T]::PrintExit("Green", "✓ 모든 작업이 정상적으로 완료되었습니다.")
}