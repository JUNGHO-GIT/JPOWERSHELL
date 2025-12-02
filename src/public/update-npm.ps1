# run-npmupdate.ps1

# 1. 공통 클래스 가져오기 ---------------------------------------------------------------------
using module ..\lib\classes.psm1

# 0. 전역변수 설정 ---------------------------------------------------------------------------
$global:line = "────────────────────────────────────────────────────────────────"
$global:currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$global:fileName = Split-Path -Leaf $PSCommandPath
$global:rootPath = "C:\JUNGHO\5.Ide\0.Vscode\Workspace\2.Project\1.Node"
$global:stack = New-Object System.Collections.Generic.Stack[System.IO.DirectoryInfo]

# 2. 메인 ----------------------------------------------------------------------------------------
class M {
	static [void] InitializeStack() {
		$global:stack.Push((Get-Item -Path $global:rootPath))
	}

	static [string] GetPackageManagerFromReset(
		[string]$pkgPath
	) {
		try {
			$pkgContent = Get-Content -Path $pkgPath -Raw | ConvertFrom-Json
			$resetScript = $pkgContent.scripts.reset
			if ($resetScript -match '--(\w+)') {
				return $matches[1]
			}
		}
		catch {
			[T]::PrintText("Yellow", "- Warning: unable to parse package.json for reset argument")
		}
		return "pnpm"
	}

	static [void] UpdatePackageJson(
		[string]$pm = "pnpm"
	) {
		$pm -eq "npm" ? (
			& npx npm-check-updates -u
		) : (
			& $pm dlx npm-check-updates -u
		)
	}

	static [void] InstallDependencies(
		[string]$pm = "pnpm"
	) {
		$env:CI = "true"
		$installed = $false
		try {
			& $pm install 2>&1 | Out-Null
			if ($LASTEXITCODE -eq 0) {
				$installed = $true
			}
		}
		catch {
			[T]::PrintText("Yellow", "- $pm install failed or blocked by prompt: $($_.Exception.Message)")
		}
		if (-not $installed) {
			[T]::PrintText("Yellow", "- Retrying with forced 'Y' to stdin...")
			"Y" | & $pm install 2>&1 | Out-Null
		}
	}

	static [void] RunResetScript(
		[string]$pm = "pnpm"
	) {
		[T]::PrintText("Cyan", "- Running reset script...")
		& $pm run reset
	}

	static [void] CleanupEnvironment() {
		Remove-Item Env:\CI -ErrorAction SilentlyContinue
	}

	static [void] AddChildDirectories(
		[string]$dirFullName
	) {
		try {
			Get-ChildItem -Path $dirFullName -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "node_modules" -and $_.Name -ne "client" } | ForEach-Object {
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
		if (!$dir -or !$dir.Exists) {
			continue
		}
		else {
			$pkg = Join-Path $dir.FullName "package.json"
			if (Test-Path $pkg) {
				$pm = [M]::GetPackageManagerFromReset($pkg)
				[T]::PrintLine("Cyan")
				[T]::PrintText("Cyan", "▶ Processing directory: $($dir.FullName)")
				[T]::PrintText("Cyan", "▶ Package Manager: [$pm]")
				Push-Location $dir.FullName
				try {
					[M]::UpdatePackageJson($pm)
					[M]::InstallDependencies($pm)
					[M]::RunResetScript($pm)
					[T]::PrintText("Green", "✓ Successfully updated & reset in $($dir.FullName)")
					# 클라이언트 폴더가 있는지 확인하고 처리
					$clientPath = Join-Path $dir.FullName "client"
					$clientPkg = Join-Path $clientPath "package.json"
					if (Test-Path $clientPkg) {
						$clientPm = [M]::GetPackageManagerFromReset($clientPkg)
						[T]::PrintText("Cyan", "- Found client folder, processing...")
						[T]::PrintText("Cyan", "- Client Package Manager: [$clientPm]")
						Push-Location $clientPath
						try {
							[M]::UpdatePackageJson($clientPm)
							[M]::InstallDependencies($clientPm)
							[M]::RunResetScript($clientPm)
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
					Pop-Location
				}
			}
			[M]::AddChildDirectories($dir.FullName)
		}
	}
}

# 99. 프로세스 종료 ---------------------------------------------------------------------------
& {
	[T]::PrintContinue($PSCommandPath)
}