#!/bin/bash
# 오프라인·재연결·충돌 점검 (로컬 Supabase + http://127.0.0.1:8789, test_basic.sh 와 같은 준비)
A(){ env -u AGENT_BROWSER_CDP agent-browser --session om "$@"; }; B(){ env -u AGENT_BROWSER_CDP agent-browser --session op "$@"; }
U=http://127.0.0.1:8789/; EM="o$(date +%s)@memo.test"; PW="test-$(date +%s)"
pass=0; fail=0
ev(){ $1 eval "$2" 2>&1 | sed 's/^"//; s/"$//'; }
ok(){ if [ "$2" = true ]; then echo "✅ $1"; pass=$((pass+1)); else echo "❌ $1 → $3"; fail=$((fail+1)); fi; }
A open $U >/dev/null; B open $U >/dev/null; A set viewport 1400 900 >/dev/null; B set viewport 412 900 >/dev/null
A fill '#em' $EM >/dev/null; A fill '#pw' $PW >/dev/null; A eval 'auth(true)' >/dev/null; A wait '#app:not([hidden])' >/dev/null
B fill '#em' $EM >/dev/null; B fill '#pw' $PW >/dev/null; B click 'button.main' >/dev/null; B wait '#app:not([hidden])' >/dev/null
echo "── 저장 중에 또 고치기 (11/17 가짜 충돌본 사건)"
R=$(ev A "(async()=>{const t=now();const n={id:crypto.randomUUID(),folder_id:null,html:'<h1>a</h1>',pinned:false,deleted_at:null,updated_at:t,created_at:t};S.notes.push(n);save(n,{html:'<h1>ab</h1>'});await flush();for(let i=0;i<5;i++){await new Promise(r=>setTimeout(r,5));save(n,{html:'<h1>ab'+i+'</h1>'});const p=flush();await new Promise(r=>setTimeout(r,1));save(n,{html:'<h1>abc'+i+'</h1>'});await p;await flush();}save(n,{deleted_at:now()});await flush();return S.notes.filter(x=>x.html.includes('충돌본')).length})()")
ok "혼자 빨리 고쳐도 충돌본 안 생김" "$([ "$R" = 0 ] && echo true)" "$R"
A click '#tools .newn' >/dev/null; A keyboard type "공통 메모" >/dev/null; A press Enter >/dev/null; A keyboard type "처음 내용" >/dev/null
A click '#tools .newn' >/dev/null; A keyboard type "지울 메모" >/dev/null; sleep 3
ID=$(ev A "S.notes.find(n=>n.html.includes('공통 메모')).id"); DID=$(ev A "S.notes.find(n=>n.html.includes('지울 메모')).id")
ok "폰에 두 메모 도착" "$(ev B "S.notes.filter(n=>!n.deleted_at&&!n.html.includes('<h1>abc')).length===2")"
B reload >/dev/null; sleep 2
echo "── 폰 비행기 모드"
B set offline on >/dev/null; B eval "dispatchEvent(new Event('offline'));1" >/dev/null; sleep 1
ok "끊김 안내 띠 보임" "$(ev B "getComputedStyle(document.querySelector('#offbar')).display!=='none'")"
B eval "save(note('$ID'),{html:'<h1>공통 메모</h1><div>폰에서 오프라인 수정</div>'});1" >/dev/null
B eval "S.notes.push({id:crypto.randomUUID(),folder_id:null,html:'<h1>오프라인 새 메모</h1>',pinned:false,deleted_at:null,updated_at:now(),created_at:now()});save(S.notes.at(-1),{});1" >/dev/null
B eval "save(note('$DID'),{deleted_at:now()});render();1" >/dev/null; sleep 1
ok "대기열에 3개" "$(ev B "Object.keys(queue).length===3")" "$(ev B "Object.keys(queue).length")"
echo "── 폰 앱 껐다 켜기 (오프라인, 로그인 만료)"
B eval "for(const k of Object.keys(localStorage))if(/auth-token/.test(k)){const v=JSON.parse(localStorage[k]);v.expires_at=1;localStorage[k]=JSON.stringify(v)};1" >/dev/null
B reload >/dev/null; sleep 3
ok "로그인 화면 아닌 메모 화면" "$(ev B "!document.querySelector('#app').hidden")"
ok "오프라인 수정 그대로" "$(ev B "note('$ID')?.html.includes('폰에서 오프라인 수정')")"
ok "새 메모 그대로" "$(ev B "S.notes.some(n=>n.html.includes('오프라인 새 메모'))")"
ok "대기열 남아 있음" "$(ev B "Object.keys(queue).length===3")"
ok "끊김 안내 띠(다시 켠 뒤)" "$(ev B "document.body.classList.contains('offline')")"
echo "── 그동안 맥에서 같은 메모 수정"
A eval "save(note('$ID'),{html:'<h1>공통 메모</h1><div>맥에서 고친 내용</div>'});1" >/dev/null; sleep 2
echo "── 폰 다시 연결"
B set offline off >/dev/null; B eval "dispatchEvent(new Event('online'));1" >/dev/null; sleep 6
ok "폰 대기열 비움" "$(ev B "Object.keys(queue).length===0")" "$(ev B "Object.keys(queue).length")"
ok "안내 띠 사라짐" "$(ev B "!document.body.classList.contains('offline')")"
sleep 2; A reload >/dev/null; sleep 3
ok "맥: 폰 수정 반영" "$(ev A "note('$ID')?.html.includes('폰에서 오프라인 수정')")"
ok "맥: 폰 새 메모 반영" "$(ev A "S.notes.some(n=>n.html.includes('오프라인 새 메모'))")"
ok "맥: 폰 삭제 반영" "$(ev A "!!note('$DID')?.deleted_at")"
ok "맥에서 고친 판은 충돌본 1개로 남음" "$(ev A "S.notes.filter(n=>n.html.includes('충돌본')&&n.html.includes('맥에서 고친 내용')).length===1")"
A close >/dev/null; B close >/dev/null
echo "결과: 통과 $pass · 실패 $fail"
