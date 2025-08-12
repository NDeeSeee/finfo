# HTML Dashboard exporter (single-file, inline CSS/JS)

# Public entry: finfo_html_dashboard PATH...
# - Expands directories into files (capped by $FINFO_DASHBOARD_MAX, default 5000)
# - Emits dist/index.html with embedded JSON dataset
# - Provides minimal search/sort/pagination without external assets
finfo_html_dashboard() {
  emulate -L zsh
  set -o errexit -o nounset -o pipefail

  local -a inputs; inputs=( "$@" )
  (( ${#inputs[@]} == 0 )) && inputs=( . )

  local max_items=${FINFO_DASHBOARD_MAX:-5000}
  local -a dataset_paths; dataset_paths=()

  local p
  for p in "${inputs[@]}"; do
    if [[ -f "$p" ]]; then
      dataset_paths+=( "$p" )
    elif [[ -d "$p" ]]; then
      # Collect files under directory, capped; breadth-first-ish using find order
      local -a found
      local IFS=$'\n'
      found=( $(command find "$p" -type f 2>/dev/null) )
      local f
      for f in "${found[@]}"; do
        dataset_paths+=( "$f" )
        (( ${#dataset_paths[@]} >= max_items )) && break
      done
    fi
    (( ${#dataset_paths[@]} >= max_items )) && break
  done

  # Ensure dist dir
  local dist_dir="$FINFOROOT/dist"
  mkdir -p "$dist_dir"
  local out_html="$dist_dir/index.html"

  # Write HTML head and inline styles
  cat >| "$out_html" <<'HTML_HEAD'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>finfo dashboard</title>
  <style>
    :root{--bg:#0f1115;--panel:#151822;--text:#e6e6e6;--muted:#9aa4b2;--accent:#7cc0ff;--good:#70e000;--warn:#ffd166;--bad:#ff6b6b;--tableStripe:#111520}
    @media (prefers-color-scheme: light){:root{--bg:#fafafa;--panel:#ffffff;--text:#0f1115;--muted:#5b6572;--accent:#0b6bcb;--good:#2a7;--warn:#b67b00;--bad:#c43;--tableStripe:#f3f5f7}}
    html,body{height:100%}
    body{margin:0;font:14px/1.4 ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace;background:var(--bg);color:var(--text)}
    header{position:sticky;top:0;z-index:2;display:flex;gap:12px;align-items:center;padding:12px 16px;background:var(--panel);box-shadow:0 1px 0 #0003}
    header .title{font-weight:700;color:var(--accent)}
    header input{flex:1;max-width:520px;padding:8px 10px;border:1px solid #0006;border-radius:6px;background:transparent;color:var(--text)}
    main{padding:10px 16px}
    table{width:100%;border-collapse:separate;border-spacing:0}
    thead th{position:sticky;top:56px;background:var(--panel);text-align:left;padding:8px 10px;border-bottom:1px solid #0006;cursor:pointer}
    tbody td{padding:8px 10px;border-bottom:1px solid #0003;vertical-align:top}
    tbody tr:nth-child(even){background:var(--tableStripe)}
    .muted{color:var(--muted)}
    .badge{padding:1px 6px;border-radius:10px;background:#0003}
    .good{color:var(--good)}.warn{color:var(--warn)}.bad{color:var(--bad)}
    .controls{display:flex;gap:8px;align-items:center;margin:8px 0}
    .pager{display:flex;gap:6px;align-items:center}
    .pager button{padding:4px 8px;border:1px solid #0006;background:transparent;color:var(--text);border-radius:6px}
    .count{margin-left:auto}
    code{color:var(--accent)}
  </style>
</head>
<body>
  <header>
    <div class="title"> finfo dashboard</div>
    <input id="q" type="search" placeholder="Search name, path, type, verdict…" />
    <div class="count muted" id="count"></div>
  </header>
  <main>
    <div class="controls">
      <div class="pager">
        <button id="prev">Prev</button>
        <span id="page" class="muted"></span>
        <button id="next">Next</button>
      </div>
    </div>
    <table id="tbl">
      <thead>
        <tr>
          <th data-k="name">Name</th>
          <th data-k="size.bytes">Bytes</th>
          <th data-k="size.human">Size</th>
          <th data-k="type.description">Type</th>
          <th data-k="security.verdict">Verdict</th>
          <th data-k="dates.modified">Modified</th>
          <th data-k="path.rel">Path</th>
        </tr>
      </thead>
      <tbody></tbody>
    </table>
  </main>
  <script id="data" type="application/json">
[
HTML_HEAD

  # Embed JSON dataset
  local first=1 j
  for p in "${dataset_paths[@]}"; do
    j=$("$FINFOROOT/finfo.zsh" --json -- "$p" 2>/dev/null) || j=""
    [[ -z "$j" ]] && continue
    if (( ! first )); then
      print "," >> "$out_html"
    fi
    first=0
    print -r -- "$j" >> "$out_html"
  done

  # Close JSON and add app script
  cat >> "$out_html" <<'HTML_TAIL'
]
  </script>
  <script>
    const raw = document.getElementById('data').textContent.trim();
    /** @type {any[]} */
    const DATA = raw ? JSON.parse(raw) : [];
    const PAGE_SIZE = 100;
    let page = 1;
    let sortKey = 'name';
    let sortAsc = true;
    let query = '';

    const tbody = document.querySelector('#tbl tbody');
    const countEl = document.getElementById('count');
    const pageEl = document.getElementById('page');
    const qEl = document.getElementById('q');

    function get(obj, path){
      return path.split('.').reduce((o,k)=> (o && k in o) ? o[k] : '', obj);
    }
    function verdictClass(v){
      if(v==='safe') return 'good'; if(v==='caution') return 'warn'; if(v==='unsafe') return 'bad'; return '';
    }
    function fmtDate(d){ return d || ''; }
    function formatRow(r){
      const verdict = get(r,'security.verdict');
      return `<tr>
        <td><code>${r.name}</code></td>
        <td class="muted">${get(r,'size.bytes')}</td>
        <td>${get(r,'size.human')}</td>
        <td class="muted">${get(r,'type.description')}</td>
        <td class="${verdictClass(verdict)}"><span class="badge">${verdict||''}</span></td>
        <td class="muted">${fmtDate(get(r,'dates.modified'))}</td>
        <td class="muted">${get(r,'path.rel')}</td>
      </tr>`;
    }
    function applyFilter(rows){
      if(!query) return rows;
      const q = query.toLowerCase();
      return rows.filter(r => {
        return (r.name||'').toLowerCase().includes(q)
          || (get(r,'path.rel')||'').toLowerCase().includes(q)
          || (get(r,'type.description')||'').toLowerCase().includes(q)
          || (get(r,'security.verdict')||'').toLowerCase().includes(q);
      });
    }
    function applySort(rows){
      const k = sortKey; const asc = sortAsc ? 1 : -1;
      return rows.slice().sort((a,b)=>{
        const av = get(a,k); const bv = get(b,k);
        if(typeof av === 'number' && typeof bv === 'number') return (av-bv)*asc;
        return String(av).localeCompare(String(bv)) * asc;
      });
    }
    function render(){
      const filtered = applyFilter(DATA);
      const sorted = applySort(filtered);
      const totalPages = Math.max(1, Math.ceil(sorted.length / PAGE_SIZE));
      if(page>totalPages) page = totalPages;
      const start = (page-1)*PAGE_SIZE;
      const slice = sorted.slice(start, start+PAGE_SIZE);
      tbody.innerHTML = slice.map(formatRow).join('');
      countEl.textContent = `${filtered.length} items (${PAGE_SIZE}/page)`;
      pageEl.textContent = `Page ${page} / ${totalPages}`;
    }
    document.getElementById('prev').addEventListener('click',()=>{ if(page>1){ page--; render(); }});
    document.getElementById('next').addEventListener('click',()=>{ page++; render(); });
    qEl.addEventListener('input', e=>{ query = e.target.value; page=1; render(); });
    document.querySelectorAll('thead th').forEach(th=>{
      th.addEventListener('click',()=>{
        const k = th.getAttribute('data-k');
        if(sortKey===k){ sortAsc = !sortAsc; } else { sortKey=k; sortAsc=true; }
        render();
      });
    });
    render();
  </script>
</body>
</html>
HTML_TAIL

  printf "Generated dashboard: %s\n" "$out_html"
}


