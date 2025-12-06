# run-sqlresult.ps1

# 1. 공통 클래스 가져오기 ---------------------------------------------------------------------
using module ..\lib\classes.psm1

# 0. 전역변수 설정 ---------------------------------------------------------------------------
$global:line = "────────────────────────────────────────────────────────────────"
$global:currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$global:fileName = Split-Path -Leaf $PSCommandPath
$global:projectPath = "C:\JUNGHO\5.Ide\0.Vscode\Workspace\2.Project\2.Node\JNODE"
$global:exePath = "src/js/mysql2-result.js"
$global:sqlInput = ""
$global:sqlFilePath = ""

# 2. 메인 ----------------------------------------------------------------------------------------
class M {
	static [void] Run1() {
		[T]::PrintLine("Green")
		[T]::PrintText("Green", "▶ 실행할 SELECT 쿼리를 그대로 복사/붙여넣기 하세요.")
		[T]::PrintText("Green", "▶ 입력을 마치려면 마지막 줄에서 한 번 더 엔터(빈 줄) 를 입력하세요.")

		$lines = @()

		while ($true) {
			$line = Read-Host
			if ([string]::IsNullOrWhiteSpace($line)) {
				break
			}
			$lines += $line
		}

		$global:sqlInput = ($lines -join [Environment]::NewLine).Trim()

		if ($global:sqlInput -eq "") {
			[T]::PrintExit("Red", "! 입력된 쿼리가 없습니다. 프로세스를 종료합니다.")
		}

		$global:sqlFilePath = [System.IO.Path]::GetTempFileName()
		Set-Content -Path $global:sqlFilePath -Value $global:sqlInput -Encoding UTF8

		[T]::PrintText("Green", "▶ 입력된 SQL 저장 완료")
		[T]::PrintText("Green", "▶ 임시 SQL 파일: [$global:sqlFilePath]")
	}

	static [void] Run2() {
		[T]::PrintLine("Yellow")
		[T]::PrintText("Yellow", "▶ js 파일 실행")

		try {
			[T]::PrintText("Yellow", "▶ 작업 경로: [$global:projectPath]")
			[T]::PrintText("Yellow", "▶ 실행 파일: [$global:exePath]")
			[T]::PrintText("Yellow", "▶ 현재 위치: [$(Get-Location)]")

			Push-Location $global:projectPath

			$bunCmd = (Get-Command bun -ErrorAction SilentlyContinue).Source
			if (-not $bunCmd) {
				$bunCmd = "C:\Users\jungh\.bun\bin\bun.exe"
			}

			[T]::PrintText("Yellow", "▶ bun 경로: [$bunCmd]")

			$scriptPath = Join-Path $global:projectPath $global:exePath
			& $bunCmd $scriptPath $global:sqlFilePath 2>&1 | Write-Host
			$exitCode = $LASTEXITCODE

			Pop-Location

			if ($exitCode -ne 0) {
				throw "bun 프로세스가 비정상 종료되었습니다. ExitCode: $exitCode"
			}
		}
		catch {
			Pop-Location -ErrorAction SilentlyContinue
			[T]::PrintLine("Red")
			[T]::PrintText("Red", "! 오류가 발생했습니다: $($_.Exception.Message)")
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
	[M]::Run2()
}

# 99. 프로세스 종료 ---------------------------------------------------------------------------
& {
	[T]::PrintContinue($PSCommandPath)
}
