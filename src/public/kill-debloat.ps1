# kill-debloat.ps1

# 1. 공통 클래스 가져오기 ---------------------------------------------------------------------
using module ..\lib\classes.psm1

# 0. 전역변수 설정 ---------------------------------------------------------------------------
$global:line = "────────────────────────────────────────────────────────────────"
$global:currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$global:fileName = Split-Path -Leaf $PSCommandPath

# 2. 메인 ----------------------------------------------------------------------------------------
class M {
	## 관리자 권한 확인
	static [void] CheckAdmin() {
		if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
			[T]::PrintExit("Red", "! 관리자 권한으로 실행해주세요.")
		}
	}

	## 레지스트리 항목 제거
	static [void] RemoveRegistryItems() {
		[T]::PrintLine("Green")
		[T]::PrintText("Green", "✓ 파일 탐색기 홈/갤러리 항목 제거 시작...")

		$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace"
		$homeClsid = "{f874310e-b6b7-47dc-bc84-b9e6b38f5903}"
		$galleryClsid = "{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}"

		$homePath = Join-Path -Path $registryPath -ChildPath $homeClsid
		if (Test-Path $homePath) {
			Remove-Item -Path $homePath -Recurse -Force
			[T]::PrintText("Yellow", "✓ 홈(Home) 항목 제거 완료")
		}
		else {
			[T]::PrintText("Gray", "- 홈(Home) 항목이 이미 제거되어 있습니다")
		}

		$galleryPath = Join-Path -Path $registryPath -ChildPath $galleryClsid
		if (Test-Path $galleryPath) {
			Remove-Item -Path $galleryPath -Recurse -Force
			[T]::PrintText("Yellow", "✓ 갤러리(Gallery) 항목 제거 완료")
		}
		else {
			[T]::PrintText("Gray", "- 갤러리(Gallery) 항목이 이미 제거되어 있습니다")
		}
	}

	## 탐색기 재시작
	static [void] RestartExplorer() {
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
	[M]::CheckAdmin()
	[M]::RemoveRegistryItems()
	[M]::RestartExplorer()
}

# 99. 프로세스 종료 ---------------------------------------------------------------------------
& {
	[T]::PrintContinue($PSCommandPath)
}