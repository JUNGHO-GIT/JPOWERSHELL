# kill-onedrive.ps1

# 1. 공통 클래스 가져오기 ---------------------------------------------------------------------
using module ..\lib\classes.psm1

# 0. 전역변수 설정 ---------------------------------------------------------------------------
$global:line = "────────────────────────────────────────────────────────────────"
$global:currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$global:fileName = Split-Path -Leaf $PSCommandPath
$global:workspaceDir = ""
$global:backupDir = ""
$global:englishFolders = @('Desktop','Documents','Downloads','Pictures','Music','Videos')

# 2. 메인 ----------------------------------------------------------------------------------------
class M {
	## 관리자 권한 확인
	static [void] Run1() {
		$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
		if (-not $isAdmin) {
			[T]::PrintExit("Red", "! 관리자 권한으로 실행해주세요.")
		}
		[T]::PrintText("Green", "✓ 관리자 권한 확인 완료")
	}

	## 작업 공간 생성
	static [void] Run2() {
		$downloadsPath = Join-Path $env:USERPROFILE 'Downloads'
		if (-not (Test-Path -LiteralPath $downloadsPath)) {
			New-Item -ItemType Directory -Path $downloadsPath | Out-Null
		}

		$workspaceRoot = Join-Path $downloadsPath 'backup'
		if (-not (Test-Path -LiteralPath $workspaceRoot)) {
			New-Item -ItemType Directory -Path $workspaceRoot | Out-Null
		}

		$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
		$global:workspaceDir = Join-Path $workspaceRoot "run_$stamp"
		if (-not (Test-Path $global:workspaceDir)) {
			New-Item -ItemType Directory -Path $global:workspaceDir | Out-Null
		}

		$global:backupDir = Join-Path $global:workspaceDir "reg_backup"
		if (-not (Test-Path $global:backupDir)) {
			New-Item -ItemType Directory -Path $global:backupDir | Out-Null
		}

		try {
			Start-Transcript -Path (Join-Path $global:workspaceDir "cleanup.log") -ErrorAction Stop | Out-Null
		}
		catch {}

		[T]::PrintText("Green", "✓ 작업 공간 생성: [$global:workspaceDir]")
	}

	## OneDrive 프로세스 종료
	static [void] Run3() {
		$processNames = @('OneDrive','OneDriveStandaloneUpdater','OneDriveSetup','FileCoAuth')
		foreach ($name in $processNames) {
			Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object {
				try {
					$_ | Stop-Process -Force -ErrorAction Stop
					[T]::PrintText("Yellow", "✓ 프로세스 종료: $($_.ProcessName) (PID=$($_.Id))")
				}
				catch {
					[T]::PrintText("Gray", "- 프로세스 종료 실패 또는 미실행: $($_.ProcessName)")
				}
			}
		}
	}

	## OneDrive 설치 제거
	static [void] Run4() {
		foreach ($path in @("$env:SystemRoot\System32\OneDriveSetup.exe","$env:SystemRoot\SysWOW64\OneDriveSetup.exe")) {
			if (Test-Path -LiteralPath $path) {
				try {
					Start-Process -FilePath $path -ArgumentList "/uninstall" -Wait -ErrorAction Stop
					[T]::PrintText("Yellow", "✓ Setup 제거 실행: $path")
				}
				catch {
					[T]::PrintText("Gray", "- Setup 제거 실패: $path")
				}
			}
		}

		try {
			$pkgs = Get-AppxPackage -AllUsers *OneDrive* -ErrorAction SilentlyContinue
			foreach ($pkg in $pkgs) {
				try {
					Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
					[T]::PrintText("Yellow", "✓ Appx 제거: $($pkg.PackageFullName)")
				}
				catch {
					[T]::PrintText("Gray", "- Appx 제거 실패: $($pkg.PackageFullName)")
				}
			}
		}
		catch {}

		try {
			$prov = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*OneDrive*" }
			foreach ($p in $prov) {
				try {
					Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction Stop | Out-Null
					[T]::PrintText("Yellow", "✓ 사전배포 제거: $($p.PackageName)")
				}
				catch {
					[T]::PrintText("Gray", "- 사전배포 제거 실패: $($p.PackageName)")
				}
			}
		}
		catch {}
	}

	## 예약 작업 제거
	static [void] Run5() {
		$all = Get-ScheduledTask -ErrorAction SilentlyContinue
		$targets = $all | Where-Object { $_.TaskName -like "*OneDrive*" -or $_.TaskPath -like "*OneDrive*" }
		foreach ($task in $targets) {
			try {
				Unregister-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -Confirm:$false -ErrorAction Stop
				[T]::PrintText("Yellow", "✓ 예약 작업 삭제: $($task.TaskPath)$($task.TaskName)")
			}
			catch {
				[T]::PrintText("Gray", "- 예약 작업 삭제 실패: $($task.TaskPath)$($task.TaskName)")
			}
		}
	}

	## OneDrive 폴더 삭제
	static [void] Run6() {
		$commonPaths = @(
			"$env:ProgramData\Microsoft OneDrive",
			"$env:ProgramData\Microsoft\OneDrive",
			"$env:LocalAppData\Microsoft\OneDrive",
			"$env:LocalAppData\OneDrive",
			"$env:ProgramFiles\Microsoft OneDrive",
			"${env:ProgramFiles(x86)}\Microsoft OneDrive"
		)

		foreach ($path in $commonPaths) {
			if ([string]::IsNullOrWhiteSpace($path)) {
				continue
			}
			if (Test-Path -LiteralPath $path) {
				try {
					Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction Stop
					[T]::PrintText("Yellow", "✓ 삭제 완료: $path")
				}
				catch {
					[T]::PrintText("Gray", "- 삭제 실패: $path")
				}
			}
		}

		$root = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
		if (Test-Path $root) {
			foreach ($sidKey in (Get-ChildItem $root).PSChildName) {
				$key = Join-Path $root $sidKey
				$profilePath = (Get-ItemProperty -Path $key -Name ProfileImagePath -ErrorAction SilentlyContinue).ProfileImagePath
				if ($profilePath -and (Test-Path $profilePath)) {
					$userPaths = @(
						(Join-Path $profilePath 'OneDrive'),
						(Join-Path $profilePath 'AppData\Local\Microsoft\OneDrive'),
						(Join-Path $profilePath 'AppData\Local\OneDrive'),
						(Join-Path $profilePath 'AppData\Roaming\Microsoft\OneDrive'),
						(Join-Path $profilePath 'AppData\Roaming\OneDrive'),
						(Join-Path $profilePath 'Links\OneDrive.lnk'),
						(Join-Path $profilePath 'Start Menu\Programs\OneDrive.lnk'),
						(Join-Path $profilePath 'Desktop\OneDrive.lnk')
					)
					foreach ($path in $userPaths) {
						if (Test-Path -LiteralPath $path) {
							try {
								Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction Stop
								[T]::PrintText("Yellow", "✓ 삭제 완료: $path")
							}
							catch {
								[T]::PrintText("Gray", "- 삭제 실패: $path")
							}
						}
					}
				}
			}
		}
	}

	## 레지스트리 정리
	static [void] Run7() {
		$clsidOneDrive = '{018D5C66-4533-4307-9B53-224DE2ED1FE6}'
		$skyDriveKF = '{A52BBA46-E9E1-435f-B3D9-28DAA648C0F6}'

		$regKeys = @(
			"HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive",
			"HKLM:\SOFTWARE\Microsoft\OneDrive",
			"HKLM:\SOFTWARE\WOW6432Node\Microsoft\OneDrive",
			"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\$clsidOneDrive",
			"HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\$clsidOneDrive",
			"HKCR:\CLSID\$clsidOneDrive",
			"HKCR:\Wow6432Node\CLSID\$clsidOneDrive",
			"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\$skyDriveKF",
			"HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\$skyDriveKF",
			"HKCR:\*\shellex\ContextMenuHandlers\OneDrive",
			"HKCR:\AllFileSystemObjects\shellex\ContextMenuHandlers\OneDrive",
			"HKCR:\Directory\shellex\ContextMenuHandlers\OneDrive",
			"HKCR:\Directory\Background\shellex\ContextMenuHandlers\OneDrive",
			"HKCR:\Drive\shellex\ContextMenuHandlers\OneDrive"
		)

		foreach ($key in $regKeys) {
			if (Test-Path -LiteralPath $key) {
				try {
					$regKey = $key -replace 'HK.*?:\\','' -replace ':',''
					$regKey = $key.Replace(':\','\').Replace('HKLM:\','HKLM\').Replace('HKCR:\','HKCR\')
					$safe = ($key -replace "[:\\\/\*\?\[\]\| ]","_")
					$out = Join-Path $global:backupDir "$safe.reg"
					& reg.exe export "$regKey" "$out" /y 2>$null | Out-Null
					Remove-Item -LiteralPath $key -Recurse -Force -ErrorAction Stop
					[T]::PrintText("Yellow", "✓ 레지스트리 키 삭제: $key")
				}
				catch {
					[T]::PrintText("Gray", "- 레지스트리 키 삭제 실패: $key")
				}
			}
		}

		$hkcuKeys = @(
			"HKCU:\Software\Microsoft\OneDrive",
			"HKCU:\Software\Microsoft\SkyDrive",
			"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\$clsidOneDrive"
		)

		foreach ($key in $hkcuKeys) {
			if (Test-Path -LiteralPath $key) {
				try {
					Remove-Item -LiteralPath $key -Recurse -Force -ErrorAction Stop
					[T]::PrintText("Yellow", "✓ 레지스트리 키 삭제: $key")
				}
				catch {
					[T]::PrintText("Gray", "- 레지스트리 키 삭제 실패: $key")
				}
			}
		}
	}

	## 표준 폴더 경로 복구
	static [void] Run8() {
		$pf = $env:USERPROFILE
		$USF = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
		$SF = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders'

		$folders = @(
			@{ Name = 'Desktop'; Rel = 'Desktop'; Guid = '{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}'; Usf = @('Desktop'); Sf = @('Desktop') },
			@{ Name = 'Documents'; Rel = 'Documents'; Guid = '{FDD39AD0-238F-46AF-ADB4-6C85480369C7}'; Usf = @('Personal'); Sf = @('Personal') },
			@{ Name = 'Downloads'; Rel = 'Downloads'; Guid = '{374DE290-123F-4565-9164-39C4925E467B}'; Usf = @('Downloads'); Sf = @('Downloads') },
			@{ Name = 'Pictures'; Rel = 'Pictures'; Guid = '{33E28130-4E1E-4676-835A-98395C3BC3BB}'; Usf = @('My Pictures'); Sf = @('My Pictures') },
			@{ Name = 'Music'; Rel = 'Music'; Guid = '{4BD8D571-6D19-48D3-BE97-422220080E43}'; Usf = @('My Music'); Sf = @('My Music') },
			@{ Name = 'Videos'; Rel = 'Videos'; Guid = '{18989B1D-99B5-455B-841C-AB7C74E4DDFC}'; Usf = @('My Video'); Sf = @('My Video') }
		)

		foreach ($kf in $folders) {
			$abs = Join-Path $pf $kf.Rel
			if (-not (Test-Path -LiteralPath $abs)) {
				New-Item -ItemType Directory -Path $abs | Out-Null
			}

			if (-not (Test-Path -LiteralPath $USF)) {
				New-Item -Path $USF -Force | Out-Null
			}
			if (-not (Test-Path -LiteralPath $SF)) {
				New-Item -Path $SF -Force | Out-Null
			}

			foreach ($n in $kf.Usf) {
				try {
					if ((Get-ItemProperty -LiteralPath $USF -ErrorAction SilentlyContinue).PSObject.Properties.Name -contains $n) {
						Set-ItemProperty -LiteralPath $USF -Name $n -Value ("%USERPROFILE%\" + $kf.Rel) -Type ExpandString -Force
					}
					else {
						New-ItemProperty -LiteralPath $USF -Name $n -Value ("%USERPROFILE%\" + $kf.Rel) -PropertyType ExpandString -Force | Out-Null
					}
				}
				catch {}
			}

			try {
				if ((Get-ItemProperty -LiteralPath $USF -ErrorAction SilentlyContinue).PSObject.Properties.Name -contains $kf.Guid) {
					Set-ItemProperty -LiteralPath $USF -Name $kf.Guid -Value ("%USERPROFILE%\" + $kf.Rel) -Type ExpandString -Force
				}
				else {
					New-ItemProperty -LiteralPath $USF -Name $kf.Guid -Value ("%USERPROFILE%\" + $kf.Rel) -PropertyType ExpandString -Force | Out-Null
				}
			}
			catch {}

			foreach ($n in $kf.Sf) {
				try {
					if ((Get-ItemProperty -LiteralPath $SF -ErrorAction SilentlyContinue).PSObject.Properties.Name -contains $n) {
						Set-ItemProperty -LiteralPath $SF -Name $n -Value $abs -Type String -Force
					}
					else {
						New-ItemProperty -LiteralPath $SF -Name $n -Value $abs -PropertyType String -Force | Out-Null
					}
				}
				catch {}
			}
		}

		[T]::PrintText("Green", "✓ 표준 폴더 경로 복구 완료")
	}

	## 영어 표시 적용
	static [void] Run9() {
		$map = @{
			'Desktop' = 'Desktop'
			'Documents' = 'Documents'
			'Downloads' = 'Downloads'
			'Pictures' = 'Pictures'
			'Music' = 'Music'
			'Videos' = 'Videos'
		}

		$pf = $env:USERPROFILE
		foreach ($name in $global:englishFolders) {
			if (-not $map.ContainsKey($name)) {
				continue
			}
			$folderPath = Join-Path $pf $name
			if (-not (Test-Path -LiteralPath $folderPath)) {
				New-Item -ItemType Directory -Path $folderPath | Out-Null
			}

			$ini = Join-Path $folderPath 'desktop.ini'
			$content = @(
				'[.ShellClassInfo]',
				"LocalizedResourceName=$($map[$name])"
			)
			try {
				Set-Content -LiteralPath $ini -Value $content -Encoding Unicode -Force
				& attrib +s +h "$ini" 2>$null
				& attrib +r +s "$folderPath" 2>$null
				[T]::PrintText("Yellow", "✓ 영어 표시 적용: $folderPath")
			}
			catch {
				[T]::PrintText("Gray", "- 영어 표시 적용 실패: $folderPath")
			}
		}
	}

	## 권한 정합화 및 캐시 갱신
	static [void] Run10() {
		$pf = $env:USERPROFILE
		$who = "$env:USERNAME"
		foreach ($name in $global:englishFolders) {
			$path = Join-Path $pf $name
			if (Test-Path -LiteralPath $path) {
				try {
					& icacls "$path" /inheritance:e 2>$null | Out-Null
					& icacls "$path" /grant "$who`:(OI)(CI)M" 2>$null | Out-Null
				}
				catch {}
			}
		}

		try {
			& ie4uinit.exe -ClearIconCache 2>$null
		}
		catch {}
		try {
			& ie4uinit.exe -show 2>$null
		}
		catch {}
		try {
			& rundll32.exe user32.dll,UpdatePerUserSystemParameters 1, True 2>$null
		}
		catch {}

		[T]::PrintText("Green", "✓ 권한 정합화 및 캐시 갱신 완료")
	}

	## UI 언어 복구
	static [void] Run11() {
		$intlKey = 'HKCU:\Control Panel\International'
		if (Test-Path $intlKey) {
			try {
				Remove-ItemProperty -LiteralPath $intlKey -Name 'WinUILanguageOverride' -ErrorAction SilentlyContinue
			}
			catch {}
		}

		try {
			$list = Get-WinUserLanguageList -ErrorAction SilentlyContinue
			if ($list) {
				$pref = $list | ForEach-Object { $_.LanguageTag }
				$desk = 'HKCU:\Control Panel\Desktop'
				New-ItemProperty -LiteralPath $desk -Name 'PreferredUILanguages' -PropertyType MultiString -Value $pref -Force | Out-Null
			}
		}
		catch {}

		[T]::PrintText("Green", "✓ UI 언어 복구 완료")
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
	[M]::Run4()
	[M]::Run5()
	[M]::Run6()
	[M]::Run7()
	[M]::Run8()
	[M]::Run9()
	[M]::Run10()
	[M]::Run11()
}

# 99. 프로세스 종료 ---------------------------------------------------------------------------
& {
	[T]::PrintContinue($PSCommandPath)
}