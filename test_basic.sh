#!/bin/bash
# 실행 전: 로컬 Supabase(supabase start) + 이 폴더를 config.js만 로컬 주소로 바꿔 http://127.0.0.1:8789 에 띄우기
# 기본 편집 기능 전체 점검: 로컬 Supabase(실제 저장·실시간 동기화) + 실제 키 입력, 맥 화면(A)과 폰 화면(B)
A="agent-browser --session mac"; B="agent-browser --session phone"
U=http://127.0.0.1:8789/
EM="q$(date +%s)@memo.test"; PW="test-$(date +%s)"   # 로컬 테스트 전용 계정
pass=0; fail=0
ok() { if [ "$2" = "true" ]; then echo "✅ $1"; pass=$((pass+1)); else echo "❌ $1  → $3"; fail=$((fail+1)); fi; }
ev() { $1 eval "$2" 2>&1 | sed 's/^"//; s/"$//'; }
html() { ev "$1" "document.querySelector('#ed').innerHTML"; }
caretEnd() { $1 eval "(()=>{const E=document.querySelector('#ed');const w=document.createTreeWalker(E,NodeFilter.SHOW_TEXT);let t,l;while((t=w.nextNode()))l=t;if(l)getSelection().collapse(l,l.length);E.focus();return 1})()" >/dev/null; }

$A open $U >/dev/null; $B open $U >/dev/null
$A set viewport 1400 900 >/dev/null; $B set viewport 412 900 >/dev/null
$A fill '#em' "$EM" >/dev/null; $A fill '#pw' "$PW" >/dev/null; $A click '#signup' >/dev/null; $A wait '#app:not([hidden])' >/dev/null
$B fill '#em' "$EM" >/dev/null; $B fill '#pw' "$PW" >/dev/null; $B click 'button.main' >/dev/null; $B wait '#app:not([hidden])' >/dev/null
sleep 1

echo "── 입력·줄바꿈"
$A click '#tools .newn' >/dev/null
$A keyboard type "장보기" >/dev/null; $A press Enter >/dev/null; $A keyboard type "우유" >/dev/null; $A press Enter >/dev/null; $A press Enter >/dev/null; $A keyboard type "셋째 줄" >/dev/null
H=$(html "$A"); ok "엔터로 줄 바꾸기 (빈 줄 포함)" "$([[ "$H" == '<h1>장보기</h1><div>우유</div><div><br></div><div>셋째 줄</div>' ]] && echo true)" "$H"
$A press "Shift+Enter" >/dev/null; $A keyboard type "같은 문단" >/dev/null
H=$(html "$A"); ok "⇧엔터: 문단 안 줄바꿈" "$([[ "$H" == *'셋째 줄<br>같은 문단'* ]] && echo true)" "$H"
$A press Home >/dev/null; $A press Backspace >/dev/null
H=$(html "$A"); ok "줄 맨 앞에서 ⌫: 윗줄과 합치기" "$([[ "$H" == *'셋째 줄같은 문단'* || "$H" == *'셋째 줄'*'같은 문단'* ]] && echo true)" "$H"
$A eval "document.execCommand('undo');1" >/dev/null
H=$(html "$A"); ok "⌘Z 실행 취소" "$([[ "$H" == *'<br>같은 문단'* ]] && echo true)" "$H"

echo "── 엔터가 안 먹는 키보드 흉내 → 안전장치"
caretEnd "$A"
$A eval "window.__blockEnter=e=>{if(e.key==='Enter'){e.preventDefault()}};document.querySelector('#ed').addEventListener('keydown',window.__blockEnter);1" >/dev/null
$A press Enter >/dev/null; sleep 0.2; $A keyboard type "안전장치" >/dev/null
$A eval "document.querySelector('#ed').removeEventListener('keydown',window.__blockEnter);1" >/dev/null
H=$(html "$A"); ok "엔터가 막혀도 줄이 바뀜" "$([[ "$H" == *'<div>안전장치</div>'* ]] && echo true)" "$H"

echo "── 목록"
$A press Enter >/dev/null; $A press "Shift+Meta+l" >/dev/null; $A keyboard type "빵" >/dev/null; $A press Enter >/dev/null; $A keyboard type "계란" >/dev/null
H=$(html "$A"); ok "체크리스트에서 엔터 → 다음 항목" "$([[ "$H" == *'<li>빵</li><li>계란</li>'* ]] && echo true)" "$H"
$A press Enter >/dev/null; $A press Enter >/dev/null; $A keyboard type "목록 밖" >/dev/null
H=$(html "$A"); ok "빈 항목에서 엔터 → 목록 빠져나오기" "$([[ "$H" == *'계란</li></ul>'*'목록 밖'* && "$H" != *'<li>목록 밖'* ]] && echo true)" "$H"
$A press Enter >/dev/null; $A keyboard type "- 대시로 시작" >/dev/null
H=$(html "$A"); ok "'- ' 입력하면 자동 목록 (스마트 목록)" "$([[ "$H" == *'<li>대시로 시작</li>'* ]] && echo true)" "$H"
$A press Enter >/dev/null; $A press Enter >/dev/null; $A keyboard type "1. 하나" >/dev/null; $A press Enter >/dev/null; $A keyboard type "둘" >/dev/null
H=$(html "$A"); ok "'1. ' 입력하면 번호 목록, 엔터로 이어짐" "$([[ "$H" == *'<ol><li>하나</li><li>둘</li></ol>'* ]] && echo true)" "$H"
$A press Enter >/dev/null; $A press Enter >/dev/null

echo "── 붙여넣기"
$A eval "(()=>{const dt=new DataTransfer();dt.setData('text/html','<p style=\"color:red;font-size:30px\"><span style=\"font-family:Comic\">빨간 <b>굵게</b></span></p><p>둘째 문단</p>');dt.setData('text/plain','x');document.querySelector('#ed').dispatchEvent(new ClipboardEvent('paste',{clipboardData:dt,bubbles:true,cancelable:true}));return 1})()" >/dev/null
H=$(html "$A"); ok "HTML 붙여넣기: 색·크기·글꼴 제거, 굵게 유지" "$([[ "$H" == *'빨간 <b>굵게</b>'* && "$H" != *'color'* && "$H" != *'font-size'* && "$H" == *'둘째 문단'* ]] && echo true)" "$H"
caretEnd "$A"; $A press Enter >/dev/null; $A eval "(()=>{const dt=new DataTransfer();dt.setData('text/plain','줄1\n줄2\n\n줄4');document.querySelector('#ed').dispatchEvent(new ClipboardEvent('paste',{clipboardData:dt,bubbles:true,cancelable:true}));return 1})()" >/dev/null
H=$(html "$A"); ok "여러 줄 글 붙여넣기 → 줄마다 나뉨" "$([[ "$H" == *'<div>줄1</div><div>줄2</div><div><br></div><div>줄4</div>'* ]] && echo true)" "$H"

echo "── 목록·저장·동기화"
sleep 1.5
T=$(ev "$A" "document.querySelector('#nlist .it.on b')?.textContent"); ok "목록 제목이 첫 줄로 바로 바뀜" "$([[ "$T" == '장보기' ]] && echo true)" "$T"
FIRST=$(ev "$A" "document.querySelector('#nlist .it b').textContent"); ok "고친 메모가 목록 맨 위로" "$([[ "$FIRST" == '장보기' ]] && echo true)" "$FIRST"
SERVER=$(ev "$A" "(async()=>(await db.from('notes').select('html')).data[0]?.html)()"); LOCAL=$(ev "$A" "note(S.open).html")
ok "서버에 그대로 저장됨" "$([[ "$SERVER" == "$LOCAL" && -n "$SERVER" ]] && echo true)" "server=$SERVER"
sleep 1
BH=$(ev "$B" "S.notes[0]?.html"); ok "폰 화면에 실시간 반영" "$([[ "$BH" == "$LOCAL" ]] && echo true)" "$BH"
$B eval "openNote(S.notes[0].id);1" >/dev/null; caretEnd "$B"; $B press Enter >/dev/null; $B keyboard type "폰에서 추가" >/dev/null; sleep 2
AH=$(html "$A"); ok "폰에서 친 줄이 맥 화면에 반영" "$([[ "$AH" == *'폰에서 추가'* ]] && echo true)" "$AH"
$A reload >/dev/null; $A wait '#app:not([hidden])' >/dev/null; sleep 1.5
RH=$(ev "$A" "S.notes[0]?.html"); ok "새로고침 후에도 그대로" "$([[ "$RH" == *'폰에서 추가'* && "$RH" == *'<li>빵</li>'* ]] && echo true)" "$RH"

echo "── 전체 선택 후 지우고 다시 쓰기"
$A eval "openNote(S.notes[0].id);1" >/dev/null; $A click '#ed' >/dev/null; $A press "Meta+a" >/dev/null; $A press Backspace >/dev/null; sleep 0.3
$A keyboard type "새 제목" >/dev/null; $A press Enter >/dev/null; $A keyboard type "새 본문" >/dev/null; sleep 0.3
H=$(html "$A"); ok "전체 지운 뒤에도 엔터 정상" "$([[ "$H" == *'새 제목'*'<div>새 본문</div>'* ]] && echo true)" "$H"

echo "── 검색·삭제·복구"
$A eval "setQ('새 본문');renderList();1" >/dev/null; C=$(ev "$A" "document.querySelectorAll('#nlist .it').length"); ok "검색으로 찾기" "$([[ "$C" == 1 ]] && echo true)" "$C"
$A eval "setQ('');deleteNote(S.notes[0]);1" >/dev/null; sleep 1.5
D=$(ev "$B" "!!S.notes[0]?.deleted_at"); ok "삭제가 폰에도 반영" "$D" "$D"
$A eval "save(S.notes[0],{deleted_at:null},false);render();1" >/dev/null; sleep 1.5
D=$(ev "$B" "!S.notes[0]?.deleted_at"); ok "복구가 폰에도 반영" "$D" "$D"

E1=$($A errors 2>&1 | grep -v -i "favicon" | head -3); ok "맥 화면 오류 없음" "$([[ -z "$E1" ]] && echo true)" "$E1"
E2=$($B errors 2>&1 | grep -v -i "favicon" | head -3); ok "폰 화면 오류 없음" "$([[ -z "$E2" ]] && echo true)" "$E2"
echo "결과: 통과 $pass · 실패 $fail"
$A close >/dev/null; $B close >/dev/null
