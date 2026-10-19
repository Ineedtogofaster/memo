#!/bin/bash
# 태그·스마트 폴더·첨부 점검 (test_basic.sh 와 같은 로컬 서버 필요: supabase start(저장소 포함) + http://127.0.0.1:8789)
A="agent-browser --session ta"; B="agent-browser --session tb"; C="agent-browser --session tc"
U=http://127.0.0.1:8789/
EM="g$(date +%s)@memo.test"; PW="test-$(date +%s)"; EM2="o$(date +%s)@memo.test"   # 로컬 시험 전용 계정
pass=0; fail=0
ok() { if [ "$2" = "true" ]; then echo "✅ $1"; pass=$((pass+1)); else echo "❌ $1  → $3"; fail=$((fail+1)); fi; }
ev() { $1 eval "$2" 2>&1 | sed 's/^"//; s/"$//; s/\\"/"/g'; }
login() { $1 open $U >/dev/null; $1 set viewport 1400 900 >/dev/null; $1 fill '#em' "$2" >/dev/null; $1 fill '#pw' "$PW" >/dev/null; $1 click "$3" >/dev/null; $1 wait '#app:not([hidden])' >/dev/null; sleep 1; }
login "$A" "$EM" '#signup'; login "$B" "$EM" 'button.main'

echo "── 태그"
$A click '#tools .newn' >/dev/null
$A keyboard type "회의 메모" >/dev/null; $A press Enter >/dev/null; $A keyboard type "내용 #아시아링크 " >/dev/null; $A keyboard type "끝" >/dev/null
H=$(ev "$A" "ed.innerHTML"); ok "#단어+띄어쓰기 → 태그" "$([[ "$H" == *'<span class="tag" contenteditable="false">#아시아링크</span>'*'끝'* ]] && echo true)" "$H"
sleep 0.4; ok "사이드바에 태그 칩" "$([[ $(ev "$A" "document.querySelector('[data-tag=\"아시아링크\"]')?.textContent") == '#아시아링크' ]] && echo true)"
$A press Enter >/dev/null; $A keyboard type "#아시" >/dev/null; sleep 0.2
S1=$(ev "$A" "document.querySelector('#pop').hidden ? 'none' : document.querySelector('#pop').innerText"); ok "'#아시' 치면 태그 제안" "$([[ "$S1" == *'#아시아링크'* ]] && echo true)" "$S1"
$A eval "[...document.querySelectorAll('#pop button')].find(b=>b.textContent.includes('#아시아링크')).click();1" >/dev/null
ok "제안 눌러서 태그 넣기" "$([[ $(ev "$A" "ed.querySelectorAll('.tag').length") == 2 ]] && echo true)" "$(ev "$A" "ed.innerHTML")"
$A keyboard type "C#언어 #1234 " >/dev/null
ok "C#·숫자만(#1234)은 태그 아님" "$([[ $(ev "$A" "ed.querySelectorAll('.tag').length") == 2 ]] && echo true)" "$(ev "$A" "ed.innerHTML")"
sleep 1.5
$A eval "document.querySelector('[data-tag=\"아시아링크\"]').click();1" >/dev/null
ok "태그 누르면 그 태그 메모만" "$([[ $(ev "$A" "document.querySelector('#ltitle').textContent + '/' + document.querySelectorAll('#nlist .it').length") == '#아시아링크/1' ]] && echo true)" "$(ev "$A" "document.querySelector('#ltitle').textContent")"
ok "다른 기기에도 태그 반영" "$([[ $(ev "$B" "allTags().map(t=>t[0]).join()") == '아시아링크' ]] && echo true)" "$(ev "$B" "allTags().join()")"
$A eval "retag('아시아링크','jh');1" >/dev/null; sleep 1.5
ok "태그 이름 변경 (모든 메모)" "$([[ $(ev "$B" "allTags().map(t=>t[0]).join()") == 'jh' ]] && echo true)" "$(ev "$B" "allTags().join()")"

echo "── 스마트 폴더"
$A eval "S.notes.push({id:crypto.randomUUID(),folder_id:null,html:'<h1>할 일</h1><ul class=\"cl\"><li>남음</li><li class=\"done\">끝</li></ul>',pinned:false,deleted_at:null,updated_at:new Date().toISOString(),created_at:new Date().toISOString()});put('notes',S.notes.at(-1));render();1" >/dev/null
$A eval "smartDialog();document.querySelector('#sm-name').value='할 일 남음';document.querySelector('#sm-cl').value='unchecked';document.querySelector('#smartdlg').close('ok');1" >/dev/null
ok "스마트 폴더: 체크 안 된 항목 남은 메모만" "$([[ $(ev "$A" "folder(S.view)?.smart && document.querySelectorAll('#nlist .it').length") == 1 ]] && echo true)" "$(ev "$A" "document.querySelectorAll('#nlist .it').length")"
$A eval "smartDialog();document.querySelector('#sm-name').value='jh 태그';document.querySelector('#sm-tags [data-t=\"jh\"]').click();document.querySelector('#smartdlg').close('ok');1" >/dev/null
ok "스마트 폴더: 태그 조건" "$([[ $(ev "$A" "document.querySelectorAll('#nlist .it').length") == 1 ]] && echo true)" "$(ev "$A" "document.querySelectorAll('#nlist .it').length")"
$A eval "newNote();1" >/dev/null
ok "스마트 폴더에서 새 메모 → 태그 자동으로 붙음" "$([[ $(ev "$A" "note(S.open).html") == *'#jh</span>'* ]] && echo true)" "$(ev "$A" "note(S.open).html")"
$A eval "leave();S.open=null;render();1" >/dev/null; sleep 1.5
ok "스마트 폴더 다른 기기에 반영" "$([[ $(ev "$B" "S.folders.filter(f=>f.smart).length") == 2 ]] && echo true)" "$(ev "$B" "S.folders.filter(f=>f.smart).length")"
DROPJS=$(cat <<'JS'
(() => { drag = { type: 'note', id: 'x', ids: ['x'] }; const f = S.folders.find(f => f.smart); const z = dropZone({ target: document.querySelector(`[data-f="${f.id}"]`), clientY: 0 }); drag = null; return z === null; })()
JS
)
ok "스마트 폴더에는 메모 끌어 넣기 안 됨" "$([[ $(ev "$A" "$DROPJS") == true ]] && echo true)"

echo "── 사진·파일 첨부"
$A eval "openNote(S.notes.find(n=>n.html.includes('회의 메모')).id);const E=ed;const w=document.createTreeWalker(E,NodeFilter.SHOW_TEXT);let t,l;while((t=w.nextNode()))l=t;getSelection().collapse(l,l.length);E.focus();1" >/dev/null
$A eval "(async()=>{const cv=Object.assign(document.createElement('canvas'),{width:3000,height:2000});const g=cv.getContext('2d');g.fillStyle='#e3a600';g.fillRect(0,0,3000,2000);g.fillStyle='#000';g.font='300px sans-serif';g.fillText('yun',900,1100);const b=await new Promise(r=>cv.toBlob(r,'image/png'));await addFiles([new File([b],'photo.png',{type:'image/png'}),new File(['hello pdf'],'계약서.pdf',{type:'application/pdf'})]);return 1})()" >/dev/null
sleep 1
H=$(ev "$A" "note(S.open).html")
ok "사진 첨부 → 메모엔 경로만 (사진 데이터·주소 없음)" "$([[ "$H" == *'data-att="'*'.jpg" data-thumb="'* && "$H" != *'src='* && "$H" != *'base64'* ]] && echo true)" "${H:0:300}"
ok "파일 첨부 (이름·크기 표시)" "$([[ "$H" == *'class="file"'*'계약서.pdf'* ]] && echo true)" "${H:0:300}"
P=$(ev "$A" "note(S.open).html.match(/data-att=\"([^\"]+\\.jpg)\"/)[1]")
SZ=$(ev "$A" "(async()=>{const r=await db.storage.from('attachments').download('$P');const b=await createImageBitmap(r.data);return r.data.size+' bytes '+b.width+'x'+b.height})()")
ok "큰 사진은 줄여서 저장 (3000px → 2048px)" "$([[ "$SZ" == *'2048x1365'* ]] && echo true)" "$SZ"
sleep 1.5
ok "목록에 작은 미리보기" "$([[ $(ev "$A" "!!document.querySelector('#nlist .it.on img.thumb')?.getAttribute('src')") == true ]] && echo true)"
$A eval "document.querySelector('#ed img[data-att]').click();1" >/dev/null
ok "사진 누르면 크게 보기" "$([[ $(ev "$A" "!document.querySelector('#lightbox').hidden") == true ]] && echo true)"; $A press Escape >/dev/null
$B eval "openNote(S.notes.find(n=>n.html.includes('회의 메모')).id);1" >/dev/null; sleep 2
ok "다른 기기에서 사진 보임" "$([[ $(ev "$B" "document.querySelector('#ed img[data-att]')?.naturalWidth > 0") == true ]] && echo true)" "$(ev "$B" "document.querySelector('#ed img[data-att]')?.outerHTML.slice(0,160)")"
login "$C" "$EM2" '#signup'
OTHER=$(ev "$C" "(async()=>{const r=await db.storage.from('attachments').download('$P');return r.error?'막힘':'보임'})()")
ok "다른 계정은 내 사진 못 봄" "$([[ "$OTHER" == '막힘' ]] && echo true)" "$OTHER"
NID=$(ev "$A" "S.open"); $A eval "window.__nid=S.open;1" >/dev/null
$A eval "const n=note(S.open);save(n,{deleted_at:new Date().toISOString()},false);dropNote(n);1" >/dev/null; sleep 2
GONE=$(ev "$A" "(async()=>{const r=await db.storage.from('attachments').list(uid+'/'+window.__nid);return r.data.length===0?'삭제됨':'남아있음 '+r.data.length})()")
ok "메모 영구 삭제하면 첨부 파일도 삭제" "$([[ "$GONE" == '삭제됨' ]] && echo true)" "$GONE"
for X in "$A" "$B"; do E=$($X errors 2>&1 | grep -v -i favicon | head -2); ok "오류 없음" "$([[ -z "$E" ]] && echo true)" "$E"; done
echo "결과: 통과 $pass · 실패 $fail"
$A close >/dev/null; $B close >/dev/null; $C close >/dev/null
