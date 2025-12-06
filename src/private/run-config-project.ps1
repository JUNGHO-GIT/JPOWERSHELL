# run-config-project.ps1

# 1. 공통 클래스 가져오기 ---------------------------------------------------------------------
using module ..\lib\classes.psm1

# 0. 전역변수 설정 ---------------------------------------------------------------------------
$global:line = "────────────────────────────────────────────────────────────────"
$global:currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$global:fileName = Split-Path -Leaf $PSCommandPath
$global:rootPath = "C:\git"
$global:listFilePath = ".etc\config\overwrite_list.conf"
$global:deleteListFilePath = ".etc\config\delete_list.conf"
$global:commonFilePath = ".etc\config\common"
$global:projectList = @()
$global:projectName = ""
$global:commonFileList = @()

# 2. 메인 ----------------------------------------------------------------------------------------
class M {

	## 프로젝트 및 공통 파일 목록 조회
	static [array] GetProjectList() {
		$list = @()
		if (Test-Path $global:rootPath) {
			$dirs = Get-ChildItem -Path $global:rootPath -Directory
			$i = 1
			foreach ($d in $dirs) {
				if ($d.Name -ne "git") {
					$list += [PSCustomObject]@{ number=$i; name=$d.Name }
					$i++
				}
			}
		}
		return $list
	}
	
	## 공통 파일 목록 조회
	static [array] GetCommonFileList() {
		$path = Join-Path $global:rootPath "$global:projectName\$global:commonFilePath"
		$list = @()
		if (Test-Path $path) {
			Get-ChildItem -Path $path -File | ForEach-Object {
				$list += [PSCustomObject]@{ name=$_.Name; path=$_.FullName }
			}
		}
		return $list
	}

	## 1. 프로젝트 선택 및 초기화
	static [void] Run1() {
		[T]::PrintLine("Yellow")
		$global:projectList = [M]::GetProjectList()

		if ($global:projectList.Count -eq 0) {
			[T]::PrintExit("Red", "! 프로젝트가 없습니다. 먼저 프로젝트를 생성하세요.")
		}

		[T]::PrintText("Yellow", "▶ 프로젝트 목록:")
		foreach ($p in $global:projectList) {
			[T]::PrintText("Yellow", "▶ $($p.number). $($p.name)")
		}

		[T]::PrintLine("Yellow")
		$inputNum = ""
		[T]::TextInput("Yellow", "▶ 설정할 프로젝트 번호를 입력하세요 (1-$($global:projectList.Count)):", [ref]$inputNum)
		
		try {
			$sel = [int]$inputNum
			if ($sel -lt 1 -or $sel -gt $global:projectList.Count) { throw "Range Error" }
			$global:projectName = $global:projectList[$sel - 1].name
			[T]::PrintText("Yellow", "▶ 선택한 프로젝트: $global:projectName")
		}
		catch {
			[T]::PrintExit("Red", "! 잘못된 입력입니다.")
		}

		# 공통 파일 목록 로드
		[T]::PrintLine("Yellow")
		$global:commonFileList = [M]::GetCommonFileList()
		
		if ($global:commonFileList.Count -eq 0) {
			[T]::PrintExit("Red", "! 선택한 프로젝트에 공통 파일이 없습니다.")
		}
		
		[T]::PrintText("Yellow", "▶ 공통 파일 목록:")
		foreach ($f in $global:commonFileList) {
			[T]::PrintText("Yellow", "▶ $($f.name)")
		}
	}

	## 2. 공통 파일 덮어쓰기
	static [void] Run2() {
		$configPath = Join-Path $global:rootPath "$global:projectName\$global:listFilePath"
		
		[T]::PrintLine("Cyan")
		[T]::PrintText("Cyan", "▶ 공통 파일 덮어쓰기 시작")
		[T]::PrintText("Cyan", "▶ 설정 파일: $configPath")

		if (-not (Test-Path $configPath)) {
			[T]::PrintExit("Red", "! 설정 파일이 존재하지 않습니다.")
		}

		$targets = Get-Content $configPath | Where-Object {
			$l = $_.Trim()
			$l -ne "" -and -not ($l.StartsWith("#")) -and -not ($l.StartsWith("["))
		}

		if ($targets.Count -eq 0) {
			[T]::PrintExit("Red", "! 설정 파일에 적용할 경로가 없습니다.")
		}

		$cnt = 0
		$projRoot = Join-Path $global:rootPath $global:projectName

		foreach ($rel in $targets) {
			$abs = Join-Path $projRoot $rel.Trim()

			# 폴더인 경우
			if (Test-Path $abs -PathType Container) {
				foreach ($cf in $global:commonFileList) {
					$dest = Join-Path $abs $cf.name
					if (Test-Path $dest) {
						Copy-Item -Path $cf.path -Destination $dest -Force
						[T]::PrintText("Green", "▶ 덮어씀: $dest")
						$cnt++
					}
					else {
						[T]::PrintText("Yellow", "▶ 대상 파일 없음(스킵): $dest")
					}
				}
			}
			# 파일인 경우
			elseif (Test-Path $abs -PathType Leaf) {
				$name = Split-Path $abs -Leaf
				$match = $false
				foreach ($cf in $global:commonFileList) {
					if ($cf.name -eq $name) {
						Copy-Item -Path $cf.path -Destination $abs -Force
						[T]::PrintText("Green", "▶ 덮어씀: $abs")
						$cnt++
						$match = $true
					}
				}
				if (-not $match) { [T]::PrintText("Yellow", "▶ 공통 목록에 없음(스킵): $abs") }
			}
			else {
				[T]::PrintText("Red", "! 경로 없음: $abs")
			}
		}
		[T]::PrintLine("Cyan")
		[T]::PrintText("Cyan", "▶ 총 $cnt 개의 파일을 덮어썼습니다.")
	}

	## 3. 불필요 파일 삭제
	static [void] Run3() {
		$delConfigPath = Join-Path $global:rootPath "$global:projectName\$global:deleteListFilePath"
		
		if (-not (Test-Path $delConfigPath)) { return }

		$delList = Get-Content $delConfigPath | Where-Object {
			$l = $_.Trim()
			$l -ne "" -and -not ($l.StartsWith("#")) -and -not ($l.StartsWith("["))
		}

		if ($delList.Count -eq 0) {
			[T]::PrintExit("Red", "! 삭제할 파일 목록이 없습니다.")
		}

		[T]::PrintLine("Cyan")
		[T]::PrintText("Cyan", "▶ 불필요 파일 삭제 시작")
		[T]::PrintText("Cyan", "▶ 설정 파일: $delConfigPath")

		$cnt = 0
		$projRoot = Join-Path $global:rootPath $global:projectName

		foreach ($rel in $delList) {
			$abs = Join-Path $projRoot $rel.Trim()
			if (Test-Path $abs) {
				Remove-Item -Path $abs -Force
				[T]::PrintText("Green", "▶ 삭제됨: $abs")
				$cnt++
			}
			else {
				[T]::PrintText("Yellow", "▶ 파일 없음(스킵): $abs")
			}
		}
		[T]::PrintText("Cyan", "▶ 총 $cnt 개의 파일을 삭제했습니다.")
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
	[T]::PrintContinue($PSCommandPath)
}