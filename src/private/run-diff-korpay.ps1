# run-diff-korpay.ps1

# 1. 공통 클래스 가져오기 ---------------------------------------------------------------------
using module ..\lib\classes.psm1

# 0. 전역변수 설정 ---------------------------------------------------------------------------
$global:line = "───────────────────────────────────────"
$global:currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$global:fileName = Split-Path -Leaf $PSCommandPath
$global:workspaceRoot = "C:\JUNGHO\5.Ide\0.Vscode\Workspace\2.Project\2.Node\JNODE"
$global:rootPath = "C:\JUNGHO\5.Ide\0.Vscode\Workspace\2.Project\2.Node\JNODE\src\diff"
$global:folderList = @()
$global:folderCount = 0
$global:selectedFolders = @()
$global:selectedInput = ""
$global:dateInput = ""
$global:pgCode = ""
$global:jsessionKorpay = ""
$global:jsessionSecta = ""
$global:tempOutputPath = Join-Path $env:TEMP "diff-output"
$global:topFiles = @()
$global:useTopFilesMode = $false
$global:allFiles = @()

# 2. 메인 ----------------------------------------------------------------------------------------
class M {
	## 환경파일 로드
	static [void] LoadEnvFile() {
		$envFilePath = Join-Path $global:workspaceRoot ".env"
		if (-not (Test-Path $envFilePath)) {
			[T]::PrintText("Yellow", "▶ 환경변수 파일을 찾을 수 없습니다: $envFilePath")
		}
		else {
			Get-Content $envFilePath | ForEach-Object {
				$line = $_.Trim()
				$shouldProcess = $line -and -not $line.StartsWith("#") -and $line.Contains("=")
				if ($shouldProcess) {
					$parts = $line.Split("=", 2)
					if ($parts.Count -eq 2) {
						$key = $parts[0].Trim()
						$value = $parts[1].Trim()
						if ($key) {
							[System.Environment]::SetEnvironmentVariable($key, $value, [System.EnvironmentVariableTarget]::Process)
						}
					}
				}
			}
		}
	}

	## 환경파일 업데이트
	static [void] UpdateEnvFile(
		[string]$key,
		[string]$value
	) {
		$envFilePath = Join-Path $global:workspaceRoot ".env"
		if (-not (Test-Path $envFilePath)) {
			[T]::PrintText("Yellow", "▶ 환경변수 파일을 찾을 수 없어 업데이트를 건너뜁니다: $envFilePath")
		}
		else {
			$lines = Get-Content $envFilePath -ErrorAction SilentlyContinue
			if ($null -eq $lines) {
				$lines = @()
			}
			$found = $false
			$updatedLines = @()
			foreach ($line in $lines) {
				$trimmed = $line.Trim()
				if ($trimmed.StartsWith("$key=")) {
					$updatedLines += "$key=$value"
					$found = $true
				}
				else {
					$updatedLines += $line
				}
			}
			if (-not $found) {
				$updatedLines += "$key=$value"
			}
			Set-Content -Path $envFilePath -Value $updatedLines -Encoding UTF8 -Force
			[System.Environment]::SetEnvironmentVariable($key, $value, [System.EnvironmentVariableTarget]::Process)
			[T]::PrintText("Green", "▶ .env 파일 업데이트: $key")
		}
	}

	## 콘솔 인코딩 설정
	static [void] SetConsoleEncoding() {
		try {
			[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
			[Console]::InputEncoding = [System.Text.Encoding]::UTF8
			$global:OutputEncoding = [System.Text.Encoding]::UTF8
			chcp 65001 | Out-Null
			Start-Sleep -Milliseconds 100
		}
		catch {
			[T]::PrintText("Yellow", "▶ 인코딩 설정 오류: $_")
		}
	}

	## 루트에서 topFiles 결정
	static [void] DetectStructureMode() {
		$jsPath = $global:rootPath
		if (-not (Test-Path $jsPath)) {
			[T]::PrintExit("Red", "! js 경로가 존재하지 않습니다: $jsPath")
		}
		else {
			$files = Get-ChildItem -Path $jsPath -File -ErrorAction SilentlyContinue | Where-Object {
				$_.Extension -eq ".js" -or $_.Extension -eq ".ts" -or $_.Extension -eq ".ps1"
			}
			if ($null -ne $files) {
				$preferred = @("korpay.js", "secta.js")
				$sorted = @()
				foreach ($p in $preferred) {
					$hit = $files | Where-Object { $_.Name -ieq $p }
					if ($hit) {
						$sorted += $hit
					}
				}
				$rest = $files | Where-Object { $preferred -notcontains $_.Name }
				$sorted += $rest
				foreach ($f in $sorted) {
					$global:topFiles += [PSCustomObject]@{
						name = $f.Name
						path = $f.FullName
						extension = $f.Extension
					}
				}
				$global:useTopFilesMode = $global:topFiles.Count -gt 0
			}
			else {
				$global:useTopFilesMode = $false
			}
		}
	}

	## 폴더 목록 수집
	static [void] GetFolderList() {
		$jsPath = $global:rootPath
		[T]::PrintText("Cyan", "▶ 현재 경로: $jsPath")
		$pathExists = Test-Path $jsPath
		[T]::PrintText("Cyan", "▶ 경로 존재: $pathExists")
		if (-not $pathExists) {
			[T]::PrintExit("Red", "! js 경로가 존재하지 않습니다: $jsPath")
		}
		else {
			$folders = Get-ChildItem -Path $jsPath -Directory -ErrorAction SilentlyContinue
			$folderCount = if ($null -ne $folders) { $folders.Count } else { 0 }
			[T]::PrintText("Cyan", "▶ 발견된 폴더 개수: $folderCount")
			if ($null -eq $folders) {
				$folders = @()
			}
			$number = 1
			foreach ($folder in $folders) {
				$files = Get-ChildItem -Path $folder.FullName -File -ErrorAction SilentlyContinue | Where-Object {
					$_.Extension -eq ".js" -or $_.Extension -eq ".ts" -or $_.Extension -eq ".ps1"
				}
				$fileCount = if ($null -ne $files) { $files.Count } else { 0 }
				[T]::PrintText("White", "- 폴더 발견: $($folder.Name) - 파일: $fileCount 개")
				$global:folderList += [PSCustomObject]@{
					number = $number
					name = $folder.Name
					path = $folder.FullName
					fileCount = $fileCount
				}
				$number++
			}
		}
	}

	## 임시 출력 디렉토리 생성
	static [void] CreateTempOutputDir() {
		if (-not (Test-Path $global:tempOutputPath)) {
			New-Item -Path $global:tempOutputPath -ItemType Directory -Force | Out-Null
		}
	}

	## 임시 출력 파일 정리
	static [void] CleanupTempOutputFiles() {
		if (Test-Path $global:tempOutputPath) {
			Remove-Item -Path "$global:tempOutputPath\*.txt" -Force -ErrorAction SilentlyContinue
		}
	}

	## 선택된 폴더에서 실행 파일 수집
	static [void] CollectExecutableFiles() {
		foreach ($folder in $global:selectedFolders) {
			$files = Get-ChildItem -Path $folder.path -File -ErrorAction SilentlyContinue | Where-Object {
				$_.Extension -eq ".js" -or $_.Extension -eq ".ts" -or $_.Extension -eq ".ps1"
			}
			if ($null -eq $files) {
				[T]::PrintText("Yellow", "- [$($folder.name)] 실행 가능한 파일이 없습니다.")
			}
			else {
				foreach ($file in $files) {
					[T]::PrintText("White", "- [$($folder.name)] $($file.Name)")
					$global:allFiles += [PSCustomObject]@{
						name = $file.Name
						path = $file.FullName
						extension = $file.Extension
					}
				}
			}
		}
	}

	## 모든 파일 병렬 실행
	static [void] RunMultipleFiles() {
		[T]::PrintLine("Yellow")
		[T]::PrintText("Yellow", "▶ 실행할 파일 목록:")
		for ($i = 0; $i -lt $global:allFiles.Count; $i++) {
			[T]::PrintText("White", "- $($i + 1). $($global:allFiles[$i].name)")
		}
		[T]::PrintLine("Yellow")
		[T]::PrintText("Yellow", "▶ 파일 실행 시작...")
		$syncStartTime = (Get-Date).AddSeconds(2)
		$syncStartTimeStr = $syncStartTime.ToString("yyyy-MM-ddTHH:mm:ss.fff")
		$env:SYNC_START_TIME = $syncStartTimeStr
		$env:DATE_INPUT = $global:dateInput
		$env:PG_CODE = $global:pgCode
		$env:SECTA_JSESSION = $global:jsessionSecta
		$env:KORPAY_JSESSION = $global:jsessionKorpay
		[T]::PrintText("Yellow", "- 동기화된 시작 시간: $syncStartTimeStr")
		if ($global:dateInput) {
			[T]::PrintText("Yellow", "- 조회 날짜: $($global:dateInput)")
		}
		if ($global:pgCode) {
			[T]::PrintText("Yellow", "- PG사 코드: $($global:pgCode)")
		}
		if ($global:jsessionKorpay) {
			[T]::PrintText("Yellow", "- KORPAY JSESSION: $($global:jsessionKorpay)...")
		}
		if ($global:jsessionSecta) {
			[T]::PrintText("Yellow", "- SECTA JSESSION: $($global:jsessionSecta)...")
		}
		$processes = @()
		$outputFiles = @()
		$errorFiles = @()
		for ($i = 0; $i -lt $global:allFiles.Count; $i++) {
			$file = $global:allFiles[$i]
			$outputFile = Join-Path $global:tempOutputPath "output$($i + 1).txt"
			$errorFile = Join-Path $global:tempOutputPath "error$($i + 1).txt"
			$outputFiles += $outputFile
			$errorFiles += $errorFile
			if ($file.extension -eq ".ps1") {
				$executor = "powershell.exe"
				$arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($file.path)`""
			}
			else {
				$executor = "node.exe"
				$arguments = "`"$($file.path)`""
			}
			$process = Start-Process -FilePath $executor -ArgumentList $arguments -PassThru -NoNewWindow -RedirectStandardOutput $outputFile -RedirectStandardError $errorFile
			$processes += $process
			[T]::PrintText("Yellow", "- 실행: $($file.name) (PID: $($process.Id))")
		}
		[T]::PrintLine("Yellow")
		[T]::PrintText("Yellow", "▶ 모든 프로세스가 완료될 때까지 대기 중...")
		foreach ($process in $processes) {
			$process.WaitForExit()
		}
		[T]::PrintText("Yellow", "▶ 모든 프로세스가 완료되었습니다.")
		for ($i = 0; $i -lt $global:allFiles.Count; $i++) {
			[T]::PrintLine("Cyan")
			[T]::PrintText("Cyan", "▶ [$($global:allFiles[$i].name)] 실행 결과:")
			[T]::PrintLine("White")
			if (Test-Path $outputFiles[$i]) {
				$content = Get-Content $outputFiles[$i] -Raw -ErrorAction SilentlyContinue -Encoding UTF8
				if ($content) {
					Write-Host $content
				}
			}
			if (Test-Path $errorFiles[$i]) {
				$errorContent = Get-Content $errorFiles[$i] -Raw -ErrorAction SilentlyContinue -Encoding UTF8
				if ($errorContent) {
					Write-Host $errorContent -ForegroundColor Red
				}
			}
		}
		Remove-Item Env:\SYNC_START_TIME -ErrorAction SilentlyContinue
		Remove-Item Env:\DATE_INPUT -ErrorAction SilentlyContinue
		Remove-Item Env:\PG_CODE -ErrorAction SilentlyContinue
		Remove-Item Env:\SECTA_JSESSION -ErrorAction SilentlyContinue
		Remove-Item Env:\KORPAY_JSESSION -ErrorAction SilentlyContinue
		[T]::PrintLine("Yellow")
		[T]::PrintText("Yellow", "▶ 총 $($processes.Count)개의 프로세스가 실행되었습니다.")
	}

	## JSESSION 입력 공통 처리
	static [void] PromptJSession(
		[string]$displayName,
		[string]$envVarName,
		[ref]$targetVar
	) {
		[T]::PrintLine("Green")
		[T]::PrintText("Green", "▶ [$displayName] 설정")
		$defaultVal = [System.Environment]::GetEnvironmentVariable($envVarName, [System.EnvironmentVariableTarget]::Process)
		if ($defaultVal) {
			$jsessionDisplayMsg = "▶ $displayName JSESSION을 입력하세요 (엔터=기본값: $defaultVal):"
		}
		else {
			$jsessionDisplayMsg = "▶ $displayName JSESSION을 입력하세요:"
		}
		[T]::TextInput("Green", $jsessionDisplayMsg, $targetVar)
		[T]::PrintEmpty()
		if ([string]::IsNullOrWhiteSpace($targetVar.Value)) {
			$targetVar.Value = $defaultVal
		}
		else {
			[M]::UpdateEnvFile($envVarName, $targetVar.Value)
		}
	}

	## PG 코드 입력 공통 처리
	static [void] PromptPgCode([ref]$targetVar) {
		[T]::PrintLine("Green")
		[T]::PrintText("Green", "▶ PG사 선택:")
		[T]::PrintText("White", "- 01: 코페이")
		[T]::PrintText("White", "- 02: 모빌")
		[T]::PrintText("White", "- 03: 다날")
		[T]::PrintText("White", "- 04: 갤컴")
		[T]::PrintText("White", "- 05: KIS")
		[T]::PrintText("White", "- 06: TOSS")
		[T]::PrintText("White", "- 07: KSNET")
		[T]::PrintText("White", "- 08: SECTANINE (기본값)")
		[T]::PrintText("White", "- 09: SECTANINE-VAN")
		[T]::PrintText("White", "- 10: KOCES")
		[T]::PrintText("White", "- 11: 다우")
		[T]::PrintLine("Green")
		$defaultPgCode = [System.Environment]::GetEnvironmentVariable("PG_CODE", [System.EnvironmentVariableTarget]::Process)
		if ([string]::IsNullOrWhiteSpace($defaultPgCode)) {
			$defaultPgCode = "08"
		}
		$pgPromptMessage = "▶ PG사 코드를 입력하세요 (1-11, 엔터=$defaultPgCode):"
		[T]::TextInput("Green", $pgPromptMessage, $targetVar)
		[T]::PrintEmpty()
		if ([string]::IsNullOrWhiteSpace($targetVar.Value)) {
			$targetVar.Value = $defaultPgCode
		}
		else {
			try {
				$numValue = [int]$targetVar.Value
				if ($numValue -lt 1 -or $numValue -gt 11) {
					[T]::PrintExit("Red", "! 잘못된 PG사 코드입니다. 1-11 사이의 값을 입력하세요.")
				}
				else {
					$formattedCode = $numValue.ToString("00")
					$targetVar.Value = $formattedCode
					[M]::UpdateEnvFile("PG_CODE", $formattedCode)
				}
			}
			catch {
				[T]::PrintExit("Red", "! 올바른 숫자를 입력하세요.")
			}
		}
	}

	static [void] Run1() {
		[M]::LoadEnvFile()
		[M]::SetConsoleEncoding()
		[M]::DetectStructureMode()
	}

	static [void] Run2() {
		if ($global:useTopFilesMode) {
			[T]::PrintLine("Cyan")
			[T]::PrintText("Cyan", "▶ 루트 경로에서 실행 가능한 파일이 발견되었습니다.")
			for ($i = 0; $i -lt $global:topFiles.Count; $i++) {
				[T]::PrintText("White", "- $($i + 1). $($global:topFiles[$i].name)")
			}
			[T]::PrintLine("Green")
			[T]::TextInput("Green", "▶ 실행할 파일 번호를 입력하세요 (예: 1, 2):", [ref]$global:selectedInput)
			[T]::PrintEmpty()
			$inputParts = $global:selectedInput -split "," | ForEach-Object { $_.Trim() }
			if ($inputParts.Count -lt 1) {
				[T]::PrintExit("Red", "! 최소 1개 이상의 번호를 입력해야 합니다.")
			}
			else {
				$selectedFileIdx = @()
				foreach ($part in $inputParts) {
					try {
						$num = [int]$part
						if ($num -lt 1 -or $num -gt $global:topFiles.Count) {
							[T]::PrintExit("Red", "! 번호 $num 가 범위를 벗어났습니다. (1-$($global:topFiles.Count))")
						}
						else {
							if ($selectedFileIdx -contains $num) {
								[T]::PrintExit("Red", "! 중복된 번호가 있습니다: $num")
							}
							else {
								$selectedFileIdx += $num
							}
						}
					}
					catch {
						[T]::PrintExit("Red", "! 올바른 숫자를 입력하세요.")
					}
				}
				foreach ($n in $selectedFileIdx) {
					$global:allFiles += $global:topFiles[$n - 1]
				}
				[T]::PrintLine("Green")
				[T]::TextInput("Green", "▶ 조회 날짜를 입력하세요 (오늘, 어제, 20251021, 2025-10-21 형식, 엔터=오늘):", [ref]$global:dateInput)
				[T]::PrintEmpty()
				$hasKorpay = $false
				$hasSecta = $false
				foreach ($file in $global:allFiles) {
					if ($file.name -eq "korpay.js") {
						$hasKorpay = $true
					}
					elseif ($file.name -eq "secta.js") {
						$hasSecta = $true
					}
				}
				if ($hasKorpay) {
					[M]::PromptJSession("KORPAY", "KORPAY_JSESSION", [ref]$global:jsessionKorpay)
					[M]::PromptPgCode([ref]$global:pgCode)
				}
				if ($hasSecta) {
					[M]::PromptJSession("SECTANINE", "SECTA_JSESSION", [ref]$global:jsessionSecta)
				}
				[T]::PrintText("Green", "▶ 총 $($global:allFiles.Count)개의 파일을 실행합니다.")
				try {
					[M]::CreateTempOutputDir()
					[M]::CleanupTempOutputFiles()
					[M]::RunMultipleFiles()
				}
				catch {
					[T]::PrintExit("Red", "! 오류 발생: $_")
				}
				[T]::PrintLine("Cyan")
				[T]::PrintText("Cyan", "▶ 모든 작업이 완료되었습니다.")
			}
		}
		else {
			[T]::PrintLine("Cyan")
			[M]::GetFolderList()
			if ($global:folderList.Count -eq 0) {
				[T]::PrintExit("Red", "! js 경로에 폴더가 없습니다.")
			}
			else {
				[T]::PrintLine("Cyan")
				[T]::PrintText("Cyan", "▶ 폴더 목록:")
				foreach ($folder in $global:folderList) {
					$message = "- $($folder.number). $($folder.name) ($($folder.fileCount)개 파일)"
					[T]::PrintText("White", $message)
				}
				$global:folderCount = $global:folderList.Count
				[T]::PrintLine("Green")
				$promptMessage = "▶ 실행할 폴더 번호를 입력하세요 (예: 1, 2):"
				[T]::TextInput("Green", $promptMessage, [ref]$global:selectedInput)
				[T]::PrintEmpty()
				$inputParts = $global:selectedInput -split "," | ForEach-Object { $_.Trim() }
				if ($inputParts.Count -lt 1) {
					[T]::PrintExit("Red", "! 최소 1개 이상의 번호를 입력해야 합니다.")
				}
				else {
					$selectedFolderNumbers = @()
					foreach ($part in $inputParts) {
						try {
							$num = [int]$part
							if ($num -lt 1 -or $num -gt $global:folderCount) {
								[T]::PrintExit("Red", "! 번호 $num 가 범위를 벗어났습니다. (1-$global:folderCount)")
							}
							else {
								if ($selectedFolderNumbers -contains $num) {
									[T]::PrintExit("Red", "! 중복된 번호가 있습니다: $num")
								}
								else {
									$selectedFolderNumbers += $num
								}
							}
						}
						catch {
							[T]::PrintExit("Red", "! 올바른 숫자를 입력하세요.")
						}
					}
					foreach ($num in $selectedFolderNumbers) {
						$global:selectedFolders += $global:folderList[$num - 1]
					}
					[T]::PrintText("Green", "▶ 선택한 폴더:")
					foreach ($folder in $global:selectedFolders) {
						[T]::PrintText("White", "- $($folder.name) ($($folder.fileCount)개 파일)")
					}
					[T]::PrintLine("Green")
					$datePromptMessage = "▶ 조회 날짜를 입력하세요 (오늘, 어제, 20251021, 2025-10-21 형식, 엔터=오늘):"
					[T]::TextInput("Green", $datePromptMessage, [ref]$global:dateInput)
					[T]::PrintEmpty()
					[T]::PrintLine("Cyan")
					[T]::PrintText("Cyan", "▶ 실행 파일 수집 중...")
					[M]::CollectExecutableFiles()
					if ($global:allFiles.Count -eq 0) {
						[T]::PrintExit("Red", "! 선택한 폴더에 실행 가능한 파일이 없습니다.")
					}
					else {
						$hasKorpay = $false
						$hasSecta = $false
						foreach ($file in $global:allFiles) {
							if ($file.name -eq "korpay.js") {
								$hasKorpay = $true
							}
							elseif ($file.name -eq "secta.js") {
								$hasSecta = $true
							}
						}
						if ($hasKorpay) {
							[M]::PromptJSession("KORPAY", "KORPAY_JSESSION", [ref]$global:jsessionKorpay)
							[M]::PromptPgCode([ref]$global:pgCode)
						}
						if ($hasSecta) {
							[M]::PromptJSession("SECTANINE", "SECTA_JSESSION", [ref]$global:jsessionSecta)
						}
						[T]::PrintText("Cyan", "▶ 총 $($global:allFiles.Count)개의 파일을 실행합니다.")
						try {
							[M]::CreateTempOutputDir()
							[M]::CleanupTempOutputFiles()
							[M]::RunMultipleFiles()
						}
						catch {
							[T]::PrintExit("Red", "! 오류 발생: $_")
						}
						[T]::PrintLine("Cyan")
						[T]::PrintText("Cyan", "▶ 모든 작업이 완료되었습니다.")
					}
				}
			}
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
