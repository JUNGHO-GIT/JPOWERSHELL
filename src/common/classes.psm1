# classes.psm1
# 공통으로 사용되는 클래스 정의

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

Export-ModuleMember -Variable * -Function * -Alias *
