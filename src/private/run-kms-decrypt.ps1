# run-kms-decrypt.ps1

# 1. 공통 클래스 가져오기 ---------------------------------------------------------------------
using module ..\lib\classes.psm1

# 전역변수 설정 ------------------------------------------------------------------------------------------------
$global:line = '────────────────────────────────────────────────────────────────'
$global:currentTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$global:fileName = Split-Path -Leaf $PSCommandPath
$global:runMode = ($env:RUN_MODE -eq 'AUTO') ? 'AUTO' : 'MANUAL'
$global:projectPath = 'C:\git\kms'
$global:warPath = Join-Path $global:projectPath 'build\libs\kms.war'
$global:processType = ''
$global:processTypeName = ''
$global:operation = ''
$global:inputText = ''
$global:resultText = ''
$global:resultJson = $null

# KMS 관련 함수 ------------------------------------------------------------------------------------------------
class KMS {

	## war 빌드 확인 및 빌드
	static [void] EnsureWarBuilt([string]$projectPath, [string]$warPath) {
		if (-not (Test-Path $warPath)) {
			[T]::PrintText('Yellow', '▶ war 파일이 없습니다. 빌드를 시작합니다...')

			Push-Location $projectPath

			try {
				$gradlewPath = Join-Path $projectPath 'gradlew.bat'

				if (Test-Path $gradlewPath) {
					[T]::PrintText('Cyan', '▶ gradlew.bat를 사용하여 빌드합니다...')
					$buildResult = & $gradlewPath clean bootWar 2>&1
				}
				else {
					[T]::PrintText('Cyan', '▶ gradle 명령어를 사용하여 빌드합니다...')
					$buildResult = & gradle clean bootWar 2>&1
				}

				if ($LASTEXITCODE -ne 0) {
					throw "빌드 실패: $buildResult"
				}
				[T]::PrintText('Green', '▶ 빌드가 완료되었습니다.')
			}
			catch {
				[T]::PrintExit('Red', "빌드 오류: $_")
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

# 2. 메인 ----------------------------------------------------------------------------------------
class M {
	static [void] Run1() {
		# 프로젝트 경로 확인
		if (-not (Test-Path $global:projectPath)) {
			[T]::PrintExit('Red', "프로젝트 경로가 존재하지 않습니다: $global:projectPath")
		}
	}

	static [void] Run2() {
		# war 빌드 확인
		[T]::PrintLine('Yellow')
		[T]::PrintText('Yellow', '▶ war 파일을 확인합니다...')
		[KMS]::EnsureWarBuilt($global:projectPath, $global:warPath)
		[T]::PrintText('Yellow', "▶ war 파일: $global:warPath")
	}

	static [void] Run3() {
		# 작업 유형 선택
		[T]::PrintLine('Yellow')
		[T]::PrintText('Yellow', '▶ 작업 유형 목록:')
		[T]::PrintText('Yellow', '- 1: 암호화 (Encrypt)')
		[T]::PrintText('Yellow', '- 2: 복호화 (Decrypt)')

		[T]::PrintLine('Yellow')
		[T]::TextInput('Yellow', '작업 유형을 선택하세요 (1: 암호화, 2: 복호화):', [ref]$global:processType)
		if ($global:processType -notin @('1', '2')) {
			[T]::PrintExit('Red', '잘못된 입력입니다. 1 또는 2를 입력하세요.')
		}

		$global:processTypeName = ($global:processType -eq '1') ? '암호화' : '복호화'
		$global:operation = ($global:processType -eq '1') ? 'encrypt' : 'decrypt'
		[T]::PrintText('Yellow', "▶ 선택한 작업: $global:processTypeName")
	}

	static [void] Run4() {
		# 텍스트 입력
		[T]::PrintLine('Yellow')
		$inputPrompt = ($global:processType -eq '1') ? '암호화할 텍스트를 입력하세요:' : '복호화할 암호문을 입력하세요:'
		[T]::TextInput('Yellow', $inputPrompt, [ref]$global:inputText)

		if ([string]::IsNullOrWhiteSpace($global:inputText)) {
			[T]::PrintExit('Red', '입력값이 비어있습니다.')
		}

		[T]::PrintText('Yellow', "▶ 입력값: $global:inputText")
	}

	static [void] Run5() {
		# 암복호화 실행
		[T]::PrintLine('Cyan')
		[T]::PrintText('Cyan', "▶ $global:processTypeName 을 실행합니다...")

		try {
			$global:resultJson = [KMS]::Execute($global:warPath, $global:operation, $global:inputText)

			[T]::PrintLine('Green')
			[T]::PrintText('Green', "▶ $global:processTypeName 결과:")

			if ($global:processType -eq '1') {
				[T]::PrintText('Cyan', "- 원본 텍스트 (TXT): $($global:resultJson.TXT)")
				[T]::PrintText('Green', "- 암호화 결과 (ENC): $($global:resultJson.ENC)")
			}
			else {
				[T]::PrintText('Cyan', "- 암호문 (ENC): $($global:resultJson.ENC)")
				[T]::PrintText('Green', "- 복호화 결과 (DEC): $($global:resultJson.DEC)")
			}
		}
		catch {
			$errorMessage = "오류 발생: $_"
			[T]::PrintExit('Red', $errorMessage)
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
	[M]::Run3()
	[M]::Run4()
	[M]::Run5()
}

# 99. 프로세스 종료 ---------------------------------------------------------------------------
& {
	[T]::PrintContinue($PSCommandPath)
}