# kms-crypt.ps1

# 전역변수 설정 ------------------------------------------------------------------------------------------------
$line = '────────────────────────────────────────────────────────────────'
$currentTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$runMode = ($env:RUN_MODE -eq 'AUTO') ? 'AUTO' : 'MANUAL'
$projectPath = 'C:\git\kms'
$warPath = Join-Path $projectPath 'build\libs\kms.war'
$processType = ''
$inputText = ''
$resultText = ''
$resultJson = $null

# 텍스트 관련 함수 ------------------------------------------------------------------------------------------------
class Text {

	## 줄 구분자 출력
	static [void] Line(
		[string]$color = 'White'
	) {
		Write-Host ''
		Write-Host $global:line -ForegroundColor $color
	}

	## 텍스트 출력 함수
	static [void] Print(
		[string]$message = '',
		[string]$color = 'White',
		[bool]$isList = $false
	) {
		$resultMessage = ($isList) ? '- ' : '▶ '
		if ($message) {
			$resultMessage += $message
		}
		Write-Host $resultMessage -ForegroundColor $color
	}

	## 텍스트 입력 함수
	static [void] Input(
		[ref]$target,
		[string]$message = '',
		[string]$color = 'Green'
	) {
		$resultMessage = '▶ '
		if ($message) {
			$resultMessage += $message
		}
		Write-Host $resultMessage -ForegroundColor $color
		$target.Value = Read-Host
	}

	## 종료 메시지 출력 함수
	static [void] ExitMessage(
		[string]$message = '',
		[string]$color = 'Red'
	) {
		if ($env:RUN_MODE -eq 'AUTO') {
			Write-Host $message -ForegroundColor $color
			Write-Host ''
			Write-Host '2초 후 자동 종료됩니다...' -ForegroundColor $color
			Start-Sleep -Seconds 2
			exit
		}
		else {
			Write-Host $message -ForegroundColor $color
			Write-Host ''
			Write-Host '아무 키나 누르면 종료됩니다...' -ForegroundColor $color
			[void][System.Console]::ReadKey($true)
			exit
		}
	}
}

# KMS 관련 함수 ------------------------------------------------------------------------------------------------
class KMS {

	## war 빌드 확인 및 빌드
	static [void] EnsureWarBuilt([string]$projectPath, [string]$warPath) {
		if (-not (Test-Path $warPath)) {
			[Text]::Print('war 파일이 없습니다. 빌드를 시작합니다...', 'Yellow', $false)

			Push-Location $projectPath

			try {
				$gradlewPath = Join-Path $projectPath 'gradlew.bat'

				if (Test-Path $gradlewPath) {
					[Text]::Print('gradlew.bat를 사용하여 빌드합니다...', 'Cyan', $false)
					$buildResult = & $gradlewPath clean bootWar 2>&1
				}
				else {
					[Text]::Print('gradle 명령어를 사용하여 빌드합니다...', 'Cyan', $false)
					$buildResult = & gradle clean bootWar 2>&1
				}

				if ($LASTEXITCODE -ne 0) {
					throw "빌드 실패: $buildResult"
				}
				[Text]::Print('빌드가 완료되었습니다.', 'Green', $false)
			}
			catch {
				[Text]::ExitMessage("빌드 오류: $_", 'Red')
			}
			finally {
				Pop-Location
			}
		}
	}

	## KMS 암복호화 실행
	static [PSCustomObject] Execute([string]$warPath, [string]$operation, [string]$text) {
		try {
			$tempOutput = [System.IO.Path]::GetTempFileName()
			$tempError = [System.IO.Path]::GetTempFileName()

			$process = Start-Process -FilePath "java" -ArgumentList "-jar", $warPath, $operation, $text -NoNewWindow -Wait -PassThru -RedirectStandardOutput $tempOutput -RedirectStandardError $tempError

			$allOutput = Get-Content $tempOutput -Raw -ErrorAction SilentlyContinue
			$errors = Get-Content $tempError -Raw -ErrorAction SilentlyContinue

			Remove-Item $tempOutput -Force -ErrorAction SilentlyContinue
			Remove-Item $tempError -Force -ErrorAction SilentlyContinue

			if ($process.ExitCode -ne 0) {
				throw "실행 오류 (Exit Code: $($process.ExitCode))"
			}

			if ([string]::IsNullOrWhiteSpace($allOutput)) {
				throw "결과가 비어있습니다."
			}

			$lines = $allOutput -split "`r?`n" | Where-Object { $_.Trim() -ne '' }

			foreach ($line in $lines) {
				$trimmed = $line.Trim()
				if ($trimmed -match '^\{.*\}$') {
					try {
						$jsonResult = $trimmed | ConvertFrom-Json
						return $jsonResult
					}
					catch {
						continue
					}
				}
			}

			throw "유효한 JSON 결과를 찾을 수 없습니다."
		}
		catch {
			throw "실행 오류: $_"
		}
	}
}

# 프로세스 시작 ----------------------------------------------------------------------------------------------------
[Text]::Line('Cyan')
[Text]::Print('KMS 암복호화 프로세스 시작', 'Cyan', $false)
[Text]::Print("현재 시간: [$global:currentTime]", 'Cyan', $false)
[Text]::Print("현재 실행 모드: [$global:runMode]", 'Cyan', $false)

# 프로젝트 경로 확인 ----------------------------------------------------------------------------------------------
if (-not (Test-Path $projectPath)) {
	[Text]::ExitMessage("프로젝트 경로가 존재하지 않습니다: $projectPath", 'Red')
}

# war 빌드 확인 ----------------------------------------------------------------------------------------------------
[Text]::Line('Yellow')
[Text]::Print('war 파일을 확인합니다...', 'Yellow', $false)
[KMS]::EnsureWarBuilt($projectPath, $warPath)
[Text]::Print("war 파일: $warPath", 'Yellow', $false)

# 작업 유형 선택 ---------------------------------------------------------------------------------------------------
[Text]::Line('Yellow')
[Text]::Print('작업 유형 목록:', 'Yellow', $false)
[Text]::Print('1: 암호화 (Encrypt)', 'Yellow', $true)
[Text]::Print('2: 복호화 (Decrypt)', 'Yellow', $true)

[Text]::Line('Yellow')
[Text]::Input([ref]$global:processType, '작업 유형을 선택하세요 (1: 암호화, 2: 복호화):', 'Yellow')
if ($global:processType -notin @('1', '2')) {
	[Text]::ExitMessage('잘못된 입력입니다. 1 또는 2를 입력하세요.', 'Red')
}

$processTypeName = ($global:processType -eq '1') ? '암호화' : '복호화'
$operation = ($global:processType -eq '1') ? 'encrypt' : 'decrypt'
[Text]::Print("선택한 작업: $processTypeName", 'Yellow', $false)

# 텍스트 입력 ------------------------------------------------------------------------------------------------------
[Text]::Line('Yellow')
$inputPrompt = ($global:processType -eq '1') ? '암호화할 텍스트를 입력하세요:' : '복호화할 암호문을 입력하세요:'
[Text]::Input([ref]$global:inputText, $inputPrompt, 'Yellow')

if ([string]::IsNullOrWhiteSpace($global:inputText)) {
	[Text]::ExitMessage('입력값이 비어있습니다.', 'Red')
}

[Text]::Print("입력값: $global:inputText", 'Yellow', $false)

# 암복호화 실행 ----------------------------------------------------------------------------------------------------
[Text]::Line('Cyan')
[Text]::Print("$processTypeName 을 실행합니다...", 'Cyan', $false)

try {
	$global:resultJson = [KMS]::Execute($warPath, $operation, $global:inputText)

	[Text]::Line('Green')
	[Text]::Print("$processTypeName 결과:", 'Green', $false)

	if ($global:processType -eq '1') {
		[Text]::Print("원본 텍스트 (TXT): $($global:resultJson.TXT)", 'Cyan', $true)
		[Text]::Print("암호화 결과 (ENC): $($global:resultJson.ENC)", 'Green', $true)
	}
	else {
		[Text]::Print("암호문 (ENC): $($global:resultJson.ENC)", 'Cyan', $true)
		[Text]::Print("복호화 결과 (DEC): $($global:resultJson.DEC)", 'Green', $true)
	}
}
catch {
	$errorMessage = "오류 발생: $_"
	[Text]::ExitMessage($errorMessage, 'Red')
}

# 99. 프로세스 종료 ---------------------------------------------------------------------------
& {
	[T]::PrintContinue($PSCommandPath)
}