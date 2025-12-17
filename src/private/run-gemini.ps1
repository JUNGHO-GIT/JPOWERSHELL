# run-gemini.ps1

# 1. 공통 클래스 가져오기 ---------------------------------------------------------------------
using module ..\lib\classes.psm1

# 0. 전역변수 설정 ---------------------------------------------------------------------------
$global:line = "────────────────────────────────────────────────────────────────"
$global:currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$global:fileName = Split-Path -Leaf $PSCommandPath

# 2. 메인 ----------------------------------------------------------------------------------------
class M {
  static [void] Run1() {
    [T]::PrintLine("Yellow")
    [T]::PrintText("Yellow", "▶ Gemini CLI 시작 (현재 세션)")

    try {
      # 이 키는 이 프로세스가 실행되는 동안에만 유효합니다.
      $env:GEMINI_API_KEY = "AIzaSyBHUgpP6e_IrRLs2RP9Zp-6v89XrMoe5Ko"

      # 2. Gemini 실행 (화면 멈춤 해결을 위한 강제 실행 모드)
      # -WorkingDirectory: C:\JUNGHO 에서 실행하여 루트 권한 오류 방지
      # cmd /c gemini: Node.js 프로그램의 화면 출력을 강제로 활성화
      # -NoNewWindow -Wait: 현재 창을 유지하며 종료될 때까지 대기
      
      Start-Process "cmd.exe" -ArgumentList "/c gemini" -WorkingDirectory "C:\JUNGHO" -NoNewWindow -Wait
      
      [T]::PrintLine("Green")
      [T]::PrintText("Green", "✓ Gemini CLI 작업이 완료되었습니다.")
    }
    catch {
      [T]::PrintLine("Red")
      [T]::PrintText("Red", "! 오류가 발생했습니다: $($_.Exception.Message)")
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
}

# 99. 프로세스 종료 ---------------------------------------------------------------------------
& {
  [T]::PrintContinue($PSCommandPath)
}