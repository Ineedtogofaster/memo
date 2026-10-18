"""애플 메모 내보내기 폴더(Exporter, 마크다운) → 메모 앱 Supabase SQL.

python3 import_notes.py <내보낸 폴더> <사용자 uid>  → batch_*.sql 생성
같은 메모는 항상 같은 id(경로 기반)라 여러 번 돌려도 중복 없이 덮어쓴다.
"""
import html, os, re, sys, uuid
from datetime import datetime, timezone

NS = uuid.UUID('6f1c1f0e-8a39-4c7e-9a52-6d0d3c1e2b7a')
esc = html.escape


def inline(s):
    s = esc(s, quote=False)
    s = re.sub(r'!\[[^\]]*\]\(([^)]*)\)', lambda m: f'[사진: {os.path.basename(m[1])}]', s)
    s = re.sub(r'\[([^\]]+)\]\((?:attachments|images)/[^)]*\)', r'[첨부: \1]', s)
    s = re.sub(r'\[([^\]]+)\]\((https?://[^)\s]+)\)', r'<a href="\2">\1</a>', s)
    return re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', s)


def md_to_html(md):
    out, lines, i = [], md.replace('\r\n', '\n').split('\n'), 0
    while i < len(lines):
        ln = lines[i]
        if re.match(r'\s*- \[[ xX]\] ', ln):  # 체크리스트 묶음
            items = []
            while i < len(lines) and re.match(r'\s*- \[[ xX]\] ', lines[i]):
                done = lines[i].strip()[3] in 'xX'
                cls = ' class="done"' if done else ''
                items.append(f'<li{cls}>{inline(lines[i].strip()[6:])}</li>')
                i += 1
            out.append('<ul class="cl">' + ''.join(items) + '</ul>')
            continue
        if re.match(r'\s*[-*] ', ln):  # 글머리 목록
            items = []
            while i < len(lines) and re.match(r'\s*[-*] ', lines[i]):
                items.append(f'<li>{inline(lines[i].strip()[2:])}</li>')
                i += 1
            out.append('<ul>' + ''.join(items) + '</ul>')
            continue
        if ln.startswith('|') and ln.rstrip().endswith('|'):  # 표
            rows = []
            while i < len(lines) and lines[i].startswith('|'):
                cells = [c.strip() for c in lines[i].strip().strip('|').split('|')]
                if not all(re.fullmatch(r':?-+:?', c) for c in cells if c):
                    rows.append('<tr>' + ''.join(f'<td>{inline(c) or "<br>"}</td>' for c in cells) + '</tr>')
                i += 1
            out.append('<table>' + ''.join(rows) + '</table>')
            continue
        h = re.match(r'(#{1,6}) (.*)', ln)
        if h and (not out or len(h[1]) > 1):  # 첫 줄 # 제목 → h1, 본문 ## → h2
            tag = 'h1' if not out else 'h2'
            out.append(f'<{tag}>{inline(h[2])}</{tag}>')
        else:
            out.append(f'<div>{inline(ln) or "<br>"}</div>')
        i += 1
    while out and out[-1] == '<div><br></div>':
        out.pop()
    return ''.join(out)


def sql(s):
    return 'null' if s is None else "'" + s.replace("'", "''") + "'"


def main(root, uid):
    root = os.path.abspath(root)
    folders, notes = {}, []
    for d, dirs, files in os.walk(root):
        dirs[:] = sorted(x for x in dirs if x not in ('images', 'attachments'))
        rel = os.path.relpath(d, root)
        trash = rel.split(os.sep)[0] == 'Recently Deleted'
        name = None if rel == '.' or trash else ('메모' if rel == 'Notes' else rel)
        for f in sorted(files):
            if not f.endswith('.md'):
                continue
            p = os.path.join(d, f)
            if name and name not in folders:
                folders[name] = str(uuid.uuid5(NS, 'folder:' + name))
            body = md_to_html(open(p, encoding='utf-8').read())
            if not body.startswith('<h1>'):  # 제목 줄이 없던 메모는 파일 이름을 제목으로
                body = f'<h1>{esc(f[:-3])}</h1>' + body
            mtime = datetime.fromtimestamp(os.path.getmtime(p), timezone.utc).isoformat()
            notes.append(dict(id=str(uuid.uuid5(NS, 'note:' + os.path.relpath(p, root))), folder_id=folders.get(name),
                              html=body, updated_at=mtime,
                              deleted_at=datetime.now(timezone.utc).isoformat() if trash else None))

    stmts = [f"insert into folders (id,user_id,name) values ({sql(i)},{sql(uid)},{sql(n)}) on conflict (id) do update set name=excluded.name;"
             for n, i in folders.items()]
    stmts += [f"insert into notes (id,user_id,folder_id,html,updated_at,deleted_at) values ({sql(n['id'])},{sql(uid)},{sql(n['folder_id'])},"
              f"{sql(n['html'])},{sql(n['updated_at'])},{sql(n['deleted_at'])}) on conflict (id) do update set "
              f"folder_id=excluded.folder_id,html=excluded.html,updated_at=excluded.updated_at,deleted_at=excluded.deleted_at;"
              for n in notes]
    for k in range(0, len(stmts), 100):
        open(f'batch_{k // 100:03d}.sql', 'w').write('\n'.join(stmts[k:k + 100]))
    print(f'폴더 {len(folders)}개, 메모 {len(notes)}개 (최근 삭제 {sum(1 for n in notes if n["deleted_at"])}개)')


if __name__ == '__main__':
    if sys.argv[1:2] == ['test']:
        h = md_to_html('# 할 거\n\n- [ ] 유튜브\n- [x] 대본\n**굵게** <b>\n| a | b |\n|---|---|\n| 1 | 2 |\n![x](images/A.png)')
        assert h.startswith('<h1>할 거</h1><div><br></div><ul class="cl"><li>유튜브</li><li class="done">대본</li></ul>'), h
        assert '<div><b>굵게</b> &lt;b&gt;</div>' in h and '<table><tr><td>a</td><td>b</td></tr><tr><td>1</td><td>2</td></tr></table>' in h, h
        assert h.endswith('<div>[사진: A.png]</div>'), h
        print('ok')
    else:
        main(*sys.argv[1:3])
