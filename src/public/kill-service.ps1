# kill-service.ps1

# 0. 전역변수 설정 ---------------------------------------------------------------------------
$global:line = "────────────────────────────────────────────────────────────────"
$global:currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$global:fileName = Split-Path -Leaf $PSCommandPath

# 1. 공통 클래스 가져오기 ---------------------------------------------------------------------
. "$PSScriptRoot/../common/classes.ps1"

# 2. 메인 ----------------------------------------------------------------------------------------
class M {
	## 관리자 권한 확인 및 재실행
	static [void] CheckAdmin() {
		$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
		if (-not $IsAdmin) {
			[T]::PrintText("Yellow", "✓ 관리자 권한이 필요합니다. 다시 실행 중...")
			$self = $PSCommandPath
			if (-not $self) {
				$self = "$pwd\run-elevated-temp.ps1"
				Set-Content -Path $self -Value $MyInvocation.Line
			}
			Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File","`"$self`"" -Verb RunAs
			exit
		}
	}

	## 서비스 검색
	static [object] SearchServices([string]$keyword) {
		$matchedServices = Get-CimInstance -ClassName Win32_Service -ErrorAction SilentlyContinue | Where-Object {
			$_.Name -like "*$keyword*" -or $_.DisplayName -like "*$keyword*"
		} | Select-Object -ExpandProperty Name
		return $matchedServices
	}

	## 서비스 중지
	static [void] StopService([string]$svc) {
		[T]::PrintText("Yellow", "✓ $svc 서비스를 중지 중...")
		try {
			Stop-Service -Name $svc -Force -ErrorAction Stop
			Start-Sleep -Seconds 2
		}
		catch {
			[T]::PrintText("Yellow", "- $svc 서비스 중지 실패. 강제 종료 시도...")
			Get-Process -Name "$svc*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
		}
	}

	## 실행 파일 삭제
	static [void] DeleteExecutable([string]$svc) {
		$regKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$svc"
		if (Test-Path $regKeyPath) {
			try {
				$imagePath = (Get-ItemProperty -Path $regKeyPath -Name ImagePath -ErrorAction Stop).ImagePath
				if ($imagePath) {
					$exePath = $imagePath.Trim()
					if ($exePath.StartsWith('"')) {
						$exePath = $exePath -replace '^"([^"]+)".*$', '$1'
					}
					else {
						$exePath = $exePath -replace '(^\S+)(.*)$', '$1'
					}
					if (Test-Path $exePath) {
						& takeown.exe /f "$exePath" /a | Out-Null
						& icacls.exe "$exePath" /grant:r "Administrators:F" /t /c | Out-Null
						Remove-Item -LiteralPath $exePath -Force -ErrorAction SilentlyContinue
					}
				}
			}
			catch {
				[T]::PrintText("Yellow", "- $svc 실행 파일 삭제 실패 (계속 진행)")
			}
		}
	}

	## 레지스트리 삭제
	static [void] DeleteRegistry([string]$svc) {
		$regKeyProv = "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\$svc"
		if (Test-Path -Path $regKeyProv) {
			try {
				$acl = Get-Acl -Path $regKeyProv
				$adminSid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
				$admin = $adminSid.Translate([System.Security.Principal.NTAccount])
				$acl.SetOwner($admin)
				$rule = New-Object System.Security.AccessControl.RegistryAccessRule($admin, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
				$acl.ResetAccessRule($rule)
				Set-Acl -Path $regKeyProv -AclObject $acl
				Remove-Item -Path $regKeyProv -Recurse -Force -ErrorAction Stop
			}
			catch {
				[T]::PrintText("Yellow", "- $svc 레지스트리 삭제 실패 (계속 진행)")
			}
		}
	}

	## 서비스 제거
	static [void] RemoveService([string]$svc) {
		[T]::PrintText("Yellow", "✓ $svc 서비스를 삭제 중...")
		sc.exe delete "$svc" | Out-Null
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
	[M]::CheckAdmin()

	while ($true) {
		[T]::PrintLine("Cyan")
		$keyword = ""
		[T]::TextInput("Green", "▶ 삭제할 서비스 이름이나 이름에 포함된 특정 단어를 입력해주세요 (종료하려면 'exit' 입력)", [ref]$keyword)

		if ($keyword -ieq "exit") {
			[T]::PrintText("Green", "✓ 프로그램을 종료합니다.")
			break
		}

		$matchedServices = [M]::SearchServices($keyword)
		if (-not $matchedServices -or $matchedServices.Count -eq 0) {
			[T]::PrintText("Yellow", "- '$keyword' 단어를 포함하는 서비스가 없습니다.")
			continue
		}

		[T]::PrintLine("Yellow")
		[T]::PrintText("Yellow", "✓ 아래 서비스가 '$keyword' 단어를 포함하고 있습니다:")
		$matchedServices | ForEach-Object { [T]::PrintText("White", "  - $_") }
		[T]::PrintEmpty()

		$confirm = ""
		[T]::TextInput("Red", "▶ 이 서비스를 모두 삭제하시겠습니까? (y/n)", [ref]$confirm)

		if ($confirm -ine "y") {
			[T]::PrintText("Yellow", "- 작업을 취소합니다.")
			continue
		}

		[T]::PrintLine("Green")
		foreach ($svc in $matchedServices) {
			[M]::StopService($svc)
			[M]::DeleteExecutable($svc)
			[M]::DeleteRegistry($svc)
			[M]::RemoveService($svc)
		}
		[T]::PrintText("Green", "✓ 작업이 완료되었습니다.")
		[T]::PrintEmpty()
	}
}

# 99. 프로세스 종료 ---------------------------------------------------------------------------
& {
	[T]::PrintLine("Green")
	[T]::PrintExit("Green", "✓ 모든 작업이 정상적으로 완료되었습니다.")
}