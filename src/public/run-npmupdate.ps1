# run-npmupdate.ps1

# 0. 전역변수 설정 ---------------------------------------------------------------------------
$global:line = "────────────────────────────────────────────────────────────────"
$global:currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$global:fileName = Split-Path -Leaf $PSCommandPath
$global:rootPath = "C:\JUNGHO\2.IDE\2.Vscode\Workspace\2.Project\1.Node"
$global:stack = New-Object System.Collections.Generic.Stack[System.IO.DirectoryInfo]

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
class M {
	static [void] InitializeStack() {
		$global:stack.Push((Get-Item -Path $global:rootPath))
	}

	static [void] UpdatePackageJson() {
		pnpm dlx npm-check-updates -u
	}

	static [void] InstallDependencies() {
		$env:CI = "true"
		$installed = $false
		try {
			pnpm install 2>&1 | Out-Null
			if ($LASTEXITCODE -eq 0) {
				$installed = $true
			}
		}
		catch {
			[T]::PrintText("Yellow", "- pnpm install failed or blocked by prompt: $($_.Exception.Message)")
		}
		if (-not $installed) {
			[T]::PrintText("Yellow", "- Retrying with forced 'Y' to stdin...")
			"Y" | pnpm install 2>&1 | Out-Null
		}
	}

	static [void] RunResetScript() {
		[T]::PrintText("Cyan", "- Running reset script...")
		pnpm run reset --if-present
	}

	static [void] CleanupEnvironment() {
		Remove-Item Env:\CI -ErrorAction SilentlyContinue
	}

	static [void] AddChildDirectories(
		[string]$dirFullName
	) {
		try {
			Get-ChildItem -Path $dirFullName -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "node_modules" } | ForEach-Object {
				$global:stack.Push($_)
			}
		}
		catch {
			[T]::PrintText("Yellow", "- Warning: unable to enumerate children of $($dirFullName): $($_.Exception.Message)")
		}
	}
}

# 3. 프로세스 시작 --------------------------------------------------------------------------------
& {
	[T]::PrintLine("Cyan")
	[T]::PrintText("Cyan", "▶ 파일 이름: [$global:fileName]")
	[T]::PrintText("Cyan", "▶ 현재 시간: [$global:currentTime]")
	[T]::PrintText("Cyan", "▶ 루트 경로: [$global:rootPath]")
}

# 4. 메인 로직 실행 ---------------------------------------------------------------------------
& {
	[T]::PrintLine("Yellow")
	[M]::InitializeStack()
	while ($global:stack.Count -gt 0) {
		$dir = $global:stack.Pop()
		if ($dir.Name -eq "node_modules") {
			continue
		}
		$pkg = Join-Path $dir.FullName "package.json"
		if (Test-Path $pkg) {
			[T]::PrintLine("Cyan")
			[T]::PrintText("Cyan", "▶ Processing directory: $($dir.FullName)")
			Push-Location $dir.FullName
			try {
				[M]::UpdatePackageJson()
				[M]::InstallDependencies()
				[M]::RunResetScript()
				[T]::PrintText("Green", "✓ Successfully updated & reset in $($dir.FullName)")
				# 클라이언트 폴더 처리
				$clientPath = Join-Path $dir.FullName "client"
				$clientPkg = Join-Path $clientPath "package.json"
				if ((Test-Path $clientPath) -and (Test-Path $clientPkg)) {
					[T]::PrintText("Cyan", "- Found client folder, processing...")
					Push-Location $clientPath
					try {
						[M]::UpdatePackageJson()
						[M]::InstallDependencies()
						[T]::PrintText("Cyan", "- Running client reset script...")
						pnpm run reset --if-present
						[T]::PrintText("Green", "✓ Successfully updated & reset in client folder")
					}
					catch {
						[T]::PrintText("Red", "! Error in client folder: $($_.Exception.Message)")
					}
					finally {
						Pop-Location
					}
				}
				[T]::PrintEmpty()
			}
			catch {
				[T]::PrintText("Red", "! Error in $($dir.FullName): $($_.Exception.Message)")
			}
			finally {
				[M]::CleanupEnvironment()
				Pop-Location
			}
		}
		[M]::AddChildDirectories($dir.FullName)
	}
}

# 99. 프로세스 종료 ---------------------------------------------------------------------------
& {
	[T]::PrintLine("Green")
	[T]::PrintExit("Green", "✓ 모든 작업이 정상적으로 완료되었습니다.")
}