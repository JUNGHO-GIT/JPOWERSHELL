# run-settingfile.ps1

# 1. 공통 클래스 가져오기 ---------------------------------------------------------------------
using module ..\common\classes.psm1

# 0. 전역변수 설정 ---------------------------------------------------------------------------
$global:line = "────────────────────────────────────────────────────────────────"
$global:currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$global:fileName = Split-Path -Leaf $PSCommandPath
$global:runMode = $env:RUN_MODE -eq "AUTO" ? "AUTO" : "MANUAL"
$global:rootPath = "C:\JUNGHO\2.IDE\2.Vscode\Workspace\0.Korpay"
$global:projectList = @()
$global:projectListCount = 0
$global:projectName = ""
$global:projectNumber = 0
$global:listFilePath = "_etc\_common\_list.txt"
$global:deleteListFilePath = "_etc\_common\_delete.txt"
$global:commonFilePath = "_etc\_common"
$global:commonFileList = @()

# 2. 메인 ----------------------------------------------------------------------------------------
class M {

	## 프로젝트 목록 반환
	static [array] GetProjectList() {
		$projectList = @()
		if (Test-Path $global:rootPath) {
			$directories = Get-ChildItem -Path $global:rootPath -Directory
			$number = 1
			foreach ($dir in $directories) {
				if ($dir.Name -ne "git") {
					$projectList += [PSCustomObject]@{
						number = $number
						name = $dir.Name
					}
					$number++
				}
			}
		}
		return $projectList
	}

	static [array] GetCommonFileList() {
		$projectName = (
			$global:projectList | Where-Object { $_.number -eq $global:projectNumber }
		).name
		$commonPath = "$global:rootPath\$projectName\$global:commonFilePath"
		$commonFileList = @()
		if (Test-Path $commonPath) {
			$files = Get-ChildItem -Path $commonPath -File
			foreach ($file in $files) {
				$commonFileList += [PSCustomObject]@{
					name = $file.Name
					path = $file.FullName
				}
			}
		}
		return $commonFileList
	}

	static [void] OverwriteCommonFiles() {
		$projectName = $global:projectName
		$rootPath = $global:rootPath
		$commonFileList = $global:commonFileList
		$commonFilePath = "$rootPath\$projectName\$global:commonFilePath"
		$listFilePath = "$rootPath\$projectName\$global:listFilePath"
		[T]::PrintText("Cyan", "▶ 공통 파일 덮어쓰기 시작")
		[T]::PrintText("Cyan", "▶ 프로젝트: $projectName")
		[T]::PrintText("Cyan", "▶ 공통 파일 경로: $commonFilePath")
		[T]::PrintText("Cyan", "▶ 목록 파일 경로: $listFilePath")
		if (-not (Test-Path $listFilePath)) {
			[T]::PrintExit("Red", "! _list.txt 파일이 존재하지 않습니다. 경로: $listFilePath")
		}
		$targetPaths = Get-Content $listFilePath | Where-Object {
			$line = $_.Trim()
			$line -ne "" -and -not ($line.StartsWith("#"))
		}
		if ($targetPaths.Count -eq 0) {
			[T]::PrintExit("Red", "! _list.txt에 적용할 경로가 없습니다.")
		}
		$overwriteCount = 0
		[T]::PrintLine("Cyan")
		[T]::PrintText("Cyan", "▶ 공통 파일 덮어쓰기 시작합니다...")
		foreach ($targetRelPath in $targetPaths) {
			$targetRelPath = $targetRelPath.Trim()
			$targetAbsPath = Join-Path $rootPath "$projectName\$targetRelPath"
			if (Test-Path $targetAbsPath -PathType Container) {
				foreach ($commonFile in $commonFileList) {
					$targetFilePath = Join-Path $targetAbsPath $commonFile.name
					if (Test-Path $targetFilePath) {
						Copy-Item -Path $commonFile.path -Destination $targetFilePath -Force
						[T]::PrintText("Green", "▶ 덮어씀: $targetFilePath")
						$overwriteCount++
					}
					else {
						[T]::PrintText("Yellow", "▶ 파일 없음(스킵): $targetFilePath")
					}
				}
			}
			elseif (Test-Path $targetAbsPath -PathType Leaf) {
				$fileName = Split-Path $targetAbsPath -Leaf
				$matched = $false
				foreach ($commonFile in $commonFileList) {
					if ($commonFile.name -eq $fileName) {
						Copy-Item -Path $commonFile.path -Destination $targetAbsPath -Force
						[T]::PrintText("Green", "▶ 덮어씀: $targetAbsPath")
						$overwriteCount++
						$matched = $true
					}
				}
				if (-not $matched) {
					[T]::PrintText("Yellow", "▶ 공통파일에 없음(스킵): $targetAbsPath")
				}
			}
			else {
				[T]::PrintText("Red", "▶ 대상 없음: $targetAbsPath")
			}
		}
		[T]::PrintLine("Cyan")
		[T]::PrintText("Cyan", "▶ 총 $overwriteCount 개의 파일을 덮어썼습니다.")
	}

	static [void] DeleteCommonFiles() {
		$deleteListFilePath = "$global:rootPath\$global:projectName\$global:deleteListFilePath"
		$rootPath = $global:rootPath
		$projectName = $global:projectName
		$projectRootPath = "$rootPath\$projectName"
		$commonFilePath = "$projectRootPath\$global:commonFilePath"
		$deleteList = @()
		if (Test-Path $deleteListFilePath) {
			$deleteList = Get-Content $deleteListFilePath | Where-Object {
				$line = $_.Trim()
				$line -ne "" -and -not ($line.StartsWith("#"))
			}
		}
		if ($deleteList.Count -eq 0) {
			[T]::PrintExit("Red", "! 삭제할 파일 목록이 없습니다. 경로: $deleteListFilePath")
		}
		[T]::PrintLine("Cyan")
		[T]::PrintText("Cyan", "▶ 공통 파일 삭제 시작")
		[T]::PrintText("Cyan", "▶ 프로젝트: $projectName")
		[T]::PrintText("Cyan", "▶ 프로젝트 루트: $projectRootPath")
		[T]::PrintText("Cyan", "▶ 삭제 목록 파일 경로: $deleteListFilePath")
		$deleteCount = 0
		foreach ($fileName in $deleteList) {
			$trimmedFileName = $fileName.Trim()
			$filePath = Join-Path $projectRootPath $trimmedFileName
			if (Test-Path $filePath) {
				Remove-Item -Path $filePath -Force
				[T]::PrintText("Green", "▶ 삭제됨: $filePath")
				$deleteCount++
			}
			else {
				[T]::PrintText("Yellow", "▶ 파일 없음(스킵): $filePath")
			}
		}
		[T]::PrintText("Cyan", "▶ 총 $deleteCount 개의 파일을 삭제했습니다.")
		[T]::PrintText("Cyan", "▶ 공통 파일 삭제가 완료되었습니다.")
	}
}

# 3. 프로세스 시작 --------------------------------------------------------------------------------
& {
	[T]::PrintLine("Cyan")
	[T]::PrintText("Cyan", "▶ 기본 설정파일 덮어쓰기 프로세스 시작")
	[T]::PrintText("Cyan", "▶ 현재 시간: [$global:currentTime]")
	[T]::PrintText("Cyan", "▶ 현재 실행 모드: [$global:runMode]")
}

# 4. 메인 로직 실행 ---------------------------------------------------------------------------
& {
	[T]::PrintLine("Yellow")
	$global:projectList = [M]::GetProjectList()
	if ($global:projectList.Count -eq 0) {
		[T]::PrintExit("Red", "! 프로젝트가 없습니다. 먼저 프로젝트를 생성하세요.")
	}
	else {
		[T]::PrintText("Yellow", "▶ 프로젝트 목록:")
		foreach ($project in $global:projectList) {
			[T]::PrintText("Yellow", "▶ $($project.number). $($project.name)")
		}
		$global:projectListCount = $global:projectList.Count
	}

	[T]::PrintLine("Yellow")
	[T]::TextInput("Yellow", "▶ 설정할 프로젝트 번호를 입력하세요 (1-$($global:projectListCount)):", [ref]$global:projectNumber)
	$global:projectNumber = [int]$global:projectNumber
	$global:projectName = $global:projectList[$global:projectNumber - 1].name
	[T]::PrintText("Yellow", "▶ 선택한 프로젝트: $global:projectName")

	[T]::PrintLine("Yellow")
	$global:commonFileList = [M]::GetCommonFileList()
	if ($global:commonFileList.Count -eq 0) {
		[T]::PrintExit("Red", "! 선택한 프로젝트에 공통 파일이 없습니다.")
	}
	else {
		[T]::PrintText("Yellow", "▶ 공통 파일 목록:")
		foreach ($file in $global:commonFileList) {
			[T]::PrintText("Yellow", "▶ $($file.name)")
		}
	}

	[T]::PrintLine("Cyan")
	try {
		[M]::OverwriteCommonFiles()
		[T]::PrintText("Green", "▶ 공통 파일 덮어쓰기가 완료되었습니다.")
	}
	catch {
		[T]::PrintExit("Red", "! 오류 발생: $_")
	}

	[T]::PrintLine("Cyan")
	try {
		[M]::DeleteCommonFiles()
		[T]::PrintText("Green", "▶ 공통 파일 삭제가 완료되었습니다.")
	}
	catch {
		[T]::PrintExit("Red", "! 오류 발생: $_")
	}
}

# 99. 프로세스 종료 ---------------------------------------------------------------------------
& {
	[T]::PrintContinue($PSCommandPath)
}