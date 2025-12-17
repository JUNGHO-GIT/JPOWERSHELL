# run-kill-debloat.ps1

# 1. 공통 클래스 가져오기 ---------------------------------------------------------------------
using module ..\lib\classes.psm1

# 0. 전역변수 설정 ---------------------------------------------------------------------------
$global:line = "────────────────────────────────────────────────────────────────"
$global:currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$global:fileName = Split-Path -Leaf $PSCommandPath

# 2. 메인 ----------------------------------------------------------------------------------------
class M {
	## 관리자 권한 확인
	static [void] Run1() {
		if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
			[T]::PrintExit("Red", "! 관리자 권한으로 실행해주세요.")
		}
	}

	static [void] RemoveRegKey([string]$path, [string]$label) {
		if (Test-Path $path) {
			Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
			[T]::PrintText("Yellow", "✓ $label 제거 완료")
		}
		else {
			[T]::PrintText("Gray", "- $label 항목이 이미 제거되어 있습니다")
		}
	}

	static [void] SetRegDword([string]$path, [string]$name, [int]$value, [string]$label) {
		try {
			if (-not (Test-Path $path)) {
				New-Item -Path $path -Force | Out-Null
			}
			New-ItemProperty -Path $path -Name $name -Value $value -PropertyType DWord -Force | Out-Null
			[T]::PrintText("Yellow", "✓ $label 설정 완료")
		}
		catch {
			[T]::PrintText("Red", "! $label 설정 실패: $($_.Exception.Message)")
		}
	}

	## 레지스트리 항목 제거
	static [void] Run2() {
		[T]::PrintLine("Green")
		[T]::PrintText("Green", "✓ 파일 탐색기 홈/갤러리/기본폴더/원드라이브 항목 제거 시작...")

		# 1) 홈/갤러리 제거
		$desktopNs = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace"
		$homeClsid = "{f874310e-b6b7-47dc-bc84-b9e6b38f5903}"
		$galleryClsid = "{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}"

		[M]::RemoveRegKey((Join-Path -Path $desktopNs -ChildPath $homeClsid), "홈(Home)")
		[M]::RemoveRegKey((Join-Path -Path $desktopNs -ChildPath $galleryClsid), "갤러리(Gallery)")

		# 2) "내 PC" 기본 폴더(불필요한 것들) 제거
		$myPcNs64 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace"
		$myPcNs32 = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace"

		$removeFromThisPc = @(
			@{ "name" = "3D 개체"; "clsid" = "{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}" },
			@{ "name" = "동영상"; "clsid" = "{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}" },
			@{ "name" = "음악"; "clsid" = "{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}" },
			@{ "name" = "사진"; "clsid" = "{24ad3ad4-a569-4530-98e1-ab02f9417aa8}" }
		)

		foreach ($it in $removeFromThisPc) {
			[M]::RemoveRegKey((Join-Path -Path $myPcNs64 -ChildPath $it["clsid"]), "내 PC: $($it["name"]) (64-bit)")
			[M]::RemoveRegKey((Join-Path -Path $myPcNs32 -ChildPath $it["clsid"]), "내 PC: $($it["name"]) (32-bit)")
		}

		# 3) OneDrive 탐색기 트리/네임스페이스 숨김
		$oneDriveClsid = "{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
		$oneDriveShell64 = "Registry::HKEY_CLASSES_ROOT\CLSID\$oneDriveClsid\ShellFolder"
		$oneDriveShell32 = "Registry::HKEY_CLASSES_ROOT\Wow6432Node\CLSID\$oneDriveClsid\ShellFolder"

		[M]::SetRegDword($oneDriveShell64, "System.IsPinnedToNameSpaceTree", 0, "OneDrive 탐색기 트리 숨김 (64-bit)")
		[M]::SetRegDword($oneDriveShell32, "System.IsPinnedToNameSpaceTree", 0, "OneDrive 탐색기 트리 숨김 (32-bit)")

		[M]::RemoveRegKey("HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\$oneDriveClsid", "OneDrive 네임스페이스 (HKCU)")
		[M]::RemoveRegKey("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\$oneDriveClsid", "OneDrive 네임스페이스 (HKLM)")
		[M]::RemoveRegKey("HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\$oneDriveClsid", "OneDrive 네임스페이스 (HKLM WOW6432Node)")
	}

	static [void] StopOneDrive() {
		try {
			$od = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
			if ($null -ne $od) {
				Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
				Start-Sleep -Seconds 1
				[T]::PrintText("Yellow", "✓ OneDrive 프로세스 종료 완료")
			}
			else {
				[T]::PrintText("Gray", "- OneDrive 프로세스가 실행 중이 아닙니다")
			}
		}
		catch {
			[T]::PrintText("Red", "! OneDrive 종료 실패: $($_.Exception.Message)")
		}

		try {
			$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
			if (Test-Path $runKey) {
				$prop = Get-ItemProperty -Path $runKey -Name "OneDrive" -ErrorAction SilentlyContinue
				if ($null -ne $prop) {
					Remove-ItemProperty -Path $runKey -Name "OneDrive" -Force -ErrorAction SilentlyContinue
					[T]::PrintText("Yellow", "✓ OneDrive 시작프로그램 항목 제거 완료")
				}
				else {
					[T]::PrintText("Gray", "- OneDrive 시작프로그램 항목이 이미 없습니다")
				}
			}
		}
		catch {
			[T]::PrintText("Red", "! OneDrive 시작프로그램 항목 제거 실패: $($_.Exception.Message)")
		}
	}

	## 사용자 폴더 정리(쓸데없는 기본폴더 삭제)
	static [void] Run4() {
		[T]::PrintLine("Magenta")
		[T]::PrintText("Magenta", "✓ 사용자 경로 기본 폴더 정리 시작...")

		[M]::StopOneDrive()

		$ts = Get-Date -Format "yyyyMMdd_HHmmss"
		$backupRoot = Join-Path -Path $env:USERPROFILE -ChildPath "_deleted_default_folders\$ts"
		$targets = @(
			@{ "name" = "3D Objects"; "path" = (Join-Path $env:USERPROFILE "3D Objects") },
			@{ "name" = "Videos"; "path" = (Join-Path $env:USERPROFILE "Videos") },
			@{ "name" = "Music"; "path" = (Join-Path $env:USERPROFILE "Music") },
			@{ "name" = "Pictures"; "path" = (Join-Path $env:USERPROFILE "Pictures") },
			@{ "name" = "OneDrive"; "path" = (Join-Path $env:USERPROFILE "OneDrive") },
			@{ "name" = "Contacts"; "path" = (Join-Path $env:USERPROFILE "Contacts") },
			@{ "name" = "Favorites"; "path" = (Join-Path $env:USERPROFILE "Favorites") },
			@{ "name" = "Links"; "path" = (Join-Path $env:USERPROFILE "Links") },
			@{ "name" = "Saved Games"; "path" = (Join-Path $env:USERPROFILE "Saved Games") },
			@{ "name" = "Searches"; "path" = (Join-Path $env:USERPROFILE "Searches") },
			@{ "name" = "OneDriveTemp"; "path" = (Join-Path $env:LOCALAPPDATA "Microsoft\OneDrive") }
		)

		foreach ($it in $targets) {
			$p = $it["path"]
			$n = $it["name"]

			if (-not (Test-Path $p)) {
				[T]::PrintText("Gray", "- $n 폴더 없음: $p")
				continue
			}

			try {
				$item = Get-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
				$isReparse = $false
				if ($null -ne $item) {
					$isReparse = (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
				}

				if ($isReparse) {
					Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
					[T]::PrintText("Yellow", "✓ $n (ReparsePoint) 제거 완료: $p")
					continue
				}

				$children = Get-ChildItem -LiteralPath $p -Force -ErrorAction SilentlyContinue
				$hasChild = ($null -ne $children -and $children.Count -gt 0)

				if ($hasChild) {
					if (-not (Test-Path $backupRoot)) {
						New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
					}
					$dst = Join-Path -Path $backupRoot -ChildPath (Split-Path -Leaf $p)
					if (Test-Path $dst) {
						$dst = "$dst`_$((Get-Date).ToString("HHmmss"))"
					}
					Move-Item -LiteralPath $p -Destination $dst -Force -ErrorAction Stop
					[T]::PrintText("Yellow", "✓ $n 폴더 이동(백업) 후 제거: $dst")
				}
				else {
					Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop
					[T]::PrintText("Yellow", "✓ $n 폴더 삭제 완료: $p")
				}
			}
			catch {
				[T]::PrintText("Red", "! $n 처리 실패: $($_.Exception.Message) / $p")
			}
		}

		if (Test-Path $backupRoot) {
			[T]::PrintText("Cyan", "! 비어있지 않은 폴더는 안전하게 백업 이동됨: $backupRoot")
		}
	}

	## 탐색기 재시작
	static [void] Run3() {
		[T]::PrintLine("Cyan")
		[T]::PrintText("Cyan", "! 변경사항이 즉시 반영되지 않으면 PC를 재부팅하세요.")
		[T]::PrintEmpty()

		$restart = ""
		[T]::TextInput("Green", "▶ 탐색기를 지금 재시작하시겠습니까? (Y/N)", [ref]$restart)

		if ($restart -eq "Y" -or $restart -eq "y") {
			[T]::PrintText("Yellow", "✓ 탐색기 재시작 중...")
			Stop-Process -Name explorer -Force
			Start-Sleep -Seconds 2
			Start-Process explorer
			[T]::PrintText("Green", "✓ 탐색기 재시작 완료")
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
	[M]::Run4()
	[M]::Run3()
}

# 99. 프로세스 종료 ---------------------------------------------------------------------------
& {
	[T]::PrintContinue($PSCommandPath)
}
