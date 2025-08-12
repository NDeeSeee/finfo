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
    :root{--bg:#0e1014;--panel:#131722;--text:#e7e9ee;--muted:#9aa4b2;--accent:#7cc0ff;--good:#70e000;--warn:#ffd166;--bad:#ff6b6b;--stripe:#0b0f19;--card:#161b27}
    @media (prefers-color-scheme: light){:root{--bg:#f8fafc;--panel:#ffffff;--text:#10141a;--muted:#5b6572;--accent:#0b6bcb;--good:#2a7;--warn:#b67b00;--bad:#c43;--stripe:#f1f5f9;--card:#ffffff}}
    html,body{height:100%}
    body{margin:0;font:13px/1.5 ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace;background:var(--bg);color:var(--text)}
    header{position:sticky;top:0;z-index:2;display:flex;gap:12px;align-items:center;padding:12px 16px;background:var(--panel);box-shadow:0 1px 0 #0003}
    header .title{font-weight:800;color:var(--accent);letter-spacing:0.4px}
    header input{flex:1;max-width:540px;padding:8px 10px;border:1px solid #0006;border-radius:8px;background:transparent;color:var(--text)}
    header .btn{padding:6px 10px;border:1px solid #0006;border-radius:8px;background:transparent;color:var(--text);cursor:pointer}
    main{padding:14px 16px;display:grid;grid-template-columns: 1fr;gap:12px}
    .cards{display:grid;grid-template-columns: repeat(auto-fit,minmax(160px,1fr));gap:12px}
    .card{background:var(--card);border:1px solid #0005;border-radius:10px;padding:10px 12px}
    .card .k{color:var(--muted);font-size:12px}
    .card .v{font-size:16px;font-weight:700}
    .layout{display:grid;grid-template-columns: 220px 1fr;gap:14px}
    .side{background:var(--panel);border:1px solid #0005;border-radius:10px;padding:10px}
    .facet h3{margin:8px 0 6px 0;color:var(--muted);font-size:12px;font-weight:700}
    .facet .opt{display:flex;align-items:center;gap:8px;margin:4px 0}
    .facet input{accent-color:var(--accent)}
    table{width:100%;border-collapse:separate;border-spacing:0}
    thead th{position:sticky;top:56px;background:var(--panel);text-align:left;padding:8px 10px;border-bottom:1px solid #0006;cursor:pointer}
    /* Virtual scroll body */
    .vwrap{border-top:1px solid #0006; height: calc(100vh - 260px); overflow:auto}
    .row{display:grid;grid-template-columns:minmax(160px,2fr) 130px 90px minmax(220px,2fr) 110px 200px 2fr;gap:0;border-bottom:1px solid #0003}
    .cell{padding:8px 10px}
    .row:nth-child(even){background:var(--stripe)}
    .row.selected{outline:1px solid var(--accent); outline-offset:-1px; background: linear-gradient(0deg, #0003, #0003)}
    .row:focus{outline:2px solid var(--accent); outline-offset:-2px}
    .muted{color:var(--muted)}
    .badge{padding:1px 6px;border-radius:10px;background:#0003}
    .good{color:var(--good)}.warn{color:var(--warn)}.bad{color:var(--bad)}
    .controls{display:flex;gap:8px;align-items:center;margin:8px 0}
    .pager{display:flex;gap:6px;align-items:center}
    .pager button{padding:4px 8px;border:1px solid #0006;background:transparent;color:var(--text);border-radius:6px}
    .count{margin-left:auto}
    code{color:var(--accent)}
    /* Column visibility helpers */
    .hide-col-name .col-name, .hide-col-bytes .col-bytes, .hide-col-size .col-size,
    .hide-col-type .col-type, .hide-col-verdict .col-verdict, .hide-col-modified .col-modified, .hide-col-path .col-path { display:none }
    .chosen{background: linear-gradient(0deg, #115, #115);}
    /* Modal */
    .overlay{position:fixed;inset:0;background:#0008;display:none;align-items:center;justify-content:center}
    .modal{background:var(--panel);border:1px solid #0005;border-radius:12px;max-width:720px;width:90%;max-height:80vh;overflow:auto;padding:16px;position:relative}
    .modal h2{margin:0 0 8px 0;color:var(--accent)}
    .modal .kv{display:grid;grid-template-columns:140px 1fr;gap:6px 12px;margin:8px 0}
    .modal .k{color:var(--muted)}
    .close{position:absolute;top:12px;right:16px;cursor:pointer}
  </style>
</head>
<body>
  <header>
    <div class="title"> finfo dashboard</div>
    <input id="q" type="search" placeholder="Search name, path, type, verdict…" />
    <div class="count muted" id="count"></div>
  </header>
  <main>
    <section class="cards" aria-label="summary">
      <div class="card"><div class="k">Items</div><div class="v" id="sum-items">0</div></div>
      <div class="card"><div class="k">Files</div><div class="v" id="sum-files">0</div></div>
      <div class="card"><div class="k">Dirs</div><div class="v" id="sum-dirs">0</div></div>
      <div class="card"><div class="k">Total bytes</div><div class="v" id="sum-bytes">0</div></div>
    </section>

    <div class="layout">
      <aside class="side" aria-label="filters">
        <div class="facet" id="facet-verdict">
          <h3>Verdict</h3>
          <div id="facet-verdict-opts"></div>
        </div>
        <div class="facet" id="facet-ext">
          <h3>Extension</h3>
          <div id="facet-ext-opts"></div>
        </div>
        <div class="facet" id="facet-mime">
          <h3>MIME</h3>
          <div id="facet-mime-opts"></div>
        </div>
        <div class="facet" id="facet-owner">
          <h3>Owner</h3>
          <div id="facet-owner-opts"></div>
        </div>
        <div class="facet">
          <h3>Date range</h3>
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:6px">
            <input id="dateFrom" type="date" aria-label="From" />
            <input id="dateTo" type="date" aria-label="To" />
          </div>
        </div>
        <div class="facet">
          <h3>Page size</h3>
          <select id="pageSize" aria-label="Page size">
            <option>50</option>
            <option selected>100</option>
            <option>200</option>
          </select>
        </div>
        <div class="facet">
          <h3>Export</h3>
          <div style="display:flex;gap:8px;flex-wrap:wrap">
            <button class="btn" id="dljson" aria-label="Download JSON">JSON</button>
            <button class="btn" id="dlyaml" aria-label="Download YAML">YAML</button>
          </div>
        </div>
      </aside>

      <section>
        <div class="controls">
          <div class="pager">
            <button id="prev">Prev</button>
            <span id="page" class="muted"></span>
            <button id="next">Next</button>
          </div>
          <div style="margin-left:8px">
            <details>
              <summary class="muted">Columns</summary>
              <div id="colpicker" class="facet" style="margin-top:6px"></div>
            </details>
          </div>
          <div style="display:flex;gap:6px;margin-left:auto">
            <button class="btn" id="copyjson" aria-label="Copy selected as JSON">Copy JSON</button>
            <button class="btn" id="copyyaml" aria-label="Copy selected as YAML">Copy YAML</button>
          </div>
        </div>
        <table id="tbl" aria-label="Results header">
      <thead>
        <tr>
          <th data-k="name" scope="col">Name</th>
          <th data-k="size.bytes" scope="col">Bytes</th>
          <th data-k="size.human" scope="col">Size</th>
          <th data-k="type.description" scope="col">Type</th>
          <th data-k="security.verdict" scope="col">Verdict</th>
          <th data-k="dates.modified" scope="col">Modified</th>
          <th data-k="path.rel" scope="col">Path</th>
        </tr>
      </thead>
        </table>
        <div id="vbody" class="vwrap" role="grid" aria-label="Results"></div>
      </section>
    </div>
  </main>
  <div class="overlay" id="overlay" role="dialog" aria-modal="true" aria-labelledby="dlg-title">
    <div class="modal">
      <div class="close" id="close">✕</div>
      <h2 id="dlg-title">Details</h2>
      <div id="dlg-body"></div>
    </div>
  </div>
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
    let PAGE_SIZE = 100;
    let page = 1;
    let sortKey = 'name';
    let sortAsc = true;
    let query = '';
    const filters = { verdict: new Set(), ext: new Set(), mime: new Set(), owner: new Set(), from:null, to:null };
    const cols = [
      {key:'name', label:'Name', cls:'col-name', on:true},
      {key:'size.bytes', label:'Bytes', cls:'col-bytes', on:true},
      {key:'size.human', label:'Size', cls:'col-size', on:true},
      {key:'type.description', label:'Type', cls:'col-type', on:true},
      {key:'security.verdict', label:'Verdict', cls:'col-verdict', on:true},
      {key:'dates.modified', label:'Modified', cls:'col-modified', on:true},
      {key:'path.rel', label:'Path', cls:'col-path', on:true},
    ];
    function loadState(){
      try{
        const s = JSON.parse(localStorage.getItem('finfoState')||'{}');
        if(s.cols){ cols.forEach(c=>{ if(s.cols[c.key]!==undefined) c.on = !!s.cols[c.key]; }); }
        if(s.query) { query = s.query; qEl.value = query; }
      }catch(_e){}
    }
    function saveState(){
      const state = { cols:Object.fromEntries(cols.map(c=>[c.key,c.on])), query };
      try{ localStorage.setItem('finfoState', JSON.stringify(state)); }catch(_e){}
    }

    const vbody = document.getElementById('vbody');
    const countEl = document.getElementById('count'); countEl.setAttribute('aria-live','polite');
    const pageEl = document.getElementById('page');
    const qEl = document.getElementById('q');
    const facetVerdict = document.getElementById('facet-verdict-opts');
    const facetExt = document.getElementById('facet-ext-opts');
    const facetMime = document.getElementById('facet-mime-opts');
    const facetOwner = document.getElementById('facet-owner-opts');
    const dateFrom = document.getElementById('dateFrom');
    const dateTo = document.getElementById('dateTo');
    const sumItems = document.getElementById('sum-items');
    const sumFiles = document.getElementById('sum-files');
    const sumDirs = document.getElementById('sum-dirs');
    const sumBytes = document.getElementById('sum-bytes');

    function get(obj, path){
      return path.split('.').reduce((o,k)=> (o && k in o) ? o[k] : '', obj);
    }
    function verdictClass(v){
      if(v==='safe') return 'good'; if(v==='caution') return 'warn'; if(v==='unsafe') return 'bad'; return '';
    }
    function fmtDate(d){ return d || ''; }
    const ROW_H = 33; // px fixed row height
    function activeCls(){
      const body = document.body;
      body.classList.toggle('hide-col-name', !cols.find(c=>c.key==='name').on);
      body.classList.toggle('hide-col-bytes', !cols.find(c=>c.key==='size.bytes').on);
      body.classList.toggle('hide-col-size', !cols.find(c=>c.key==='size.human').on);
      body.classList.toggle('hide-col-type', !cols.find(c=>c.key==='type.description').on);
      body.classList.toggle('hide-col-verdict', !cols.find(c=>c.key==='security.verdict').on);
      body.classList.toggle('hide-col-modified', !cols.find(c=>c.key==='dates.modified').on);
      body.classList.toggle('hide-col-path', !cols.find(c=>c.key==='path.rel').on);
    }
    function formatRow(r){
      const verdict = get(r,'security.verdict');
      return `<div class="row" role="row" tabindex="-1">
        <div class="cell col-name"><code>${r.name}</code></div>
        <div class="cell col-bytes muted">${get(r,'size.bytes')}</div>
        <div class="cell col-size">${get(r,'size.human')}</div>
        <div class="cell col-type muted">${get(r,'type.description')}</div>
        <div class="cell col-verdict ${verdictClass(verdict)}"><span class="badge">${verdict||''}</span></div>
        <div class="cell col-modified muted">${fmtDate(get(r,'dates.modified'))}</div>
        <div class="cell col-path muted">${get(r,'path.rel')}</div>
      </div>`;
    }
    function extOf(name){ const i = name.lastIndexOf('.'); return i>0 ? name.slice(i+1).toLowerCase() : '(noext)'; }
    function applyFilter(rows){
      if(!query) return rows;
      const q = query.toLowerCase();
      return rows.filter(r => {
        const passQ = (r.name||'').toLowerCase().includes(q)
          || (get(r,'path.rel')||'').toLowerCase().includes(q)
          || (get(r,'type.description')||'').toLowerCase().includes(q)
          || (get(r,'security.verdict')||'').toLowerCase().includes(q);
        const v = (get(r,'security.verdict')||'').toLowerCase();
        const e = extOf(r.name||'');
        const m = (get(r,'type.mime')||'').split(';')[0].toLowerCase();
        const o = (get(r,'owner.user')||'').toLowerCase();
        const passVerdict = filters.verdict.size ? filters.verdict.has(v) : true;
        const passExt = filters.ext.size ? filters.ext.has(e) : true;
        const passMime = filters.mime.size ? filters.mime.has(m) : true;
        const passOwner = filters.owner.size ? filters.owner.has(o) : true;
        const me = get(r,'dates.modified_epoch');
        const passDate = (!filters.from && !filters.to) || (typeof me==='number' && (!filters.from || me>=filters.from) && (!filters.to || me<=filters.to));
        return passQ && passVerdict && passExt && passMime && passOwner && passDate;
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
    function summarize(rows){
      const items = rows.length;
      let files=0, dirs=0, bytes=0;
      rows.forEach(r=>{ if(r.is_dir) dirs++; else { files++; const b=get(r,'size.bytes'); if(typeof b==='number') bytes+=b; }});
      sumItems.textContent = items.toLocaleString();
      sumFiles.textContent = files.toLocaleString();
      sumDirs.textContent = dirs.toLocaleString();
      sumBytes.textContent = bytes.toLocaleString();
    }
    let sel = 0; // focus index within current viewport (sorted indices)
    let filteredCache = DATA;
    let sortedCache = DATA;
    let selected = new Set(); // Set<number> over sorted indices
    let anchor = null; // number | null
    function clearSelection(){ selected.clear(); anchor = null; }
    function ensureVisible(el){ if(!el) return; const r=el.getBoundingClientRect(); const p=vbody.getBoundingClientRect(); if(r.top<p.top) el.scrollIntoView({block:'nearest'}); if(r.bottom>p.bottom) el.scrollIntoView({block:'nearest'}); }
    function render(){
      const filtered = applyFilter(DATA);
      summarize(filtered);
      const sorted = applySort(filtered);
      filteredCache = filtered; sortedCache = sorted;
      countEl.textContent = `${filtered.length} items`;
      pageEl.textContent = '';
      // Virtual render for viewport
      const H = vbody.clientHeight; const rowsPer = Math.max(1, Math.floor(H / ROW_H) + 5);
      function draw(){
        const scrollTop = vbody.scrollTop;
        const firstIdx = Math.max(0, Math.floor(scrollTop / ROW_H));
        const lastIdx = Math.min(sorted.length, firstIdx + rowsPer);
        const slice = sorted.slice(firstIdx, lastIdx);
        const topPad = firstIdx * ROW_H;
        const bottomPad = Math.max(0, (sorted.length - lastIdx) * ROW_H);
        vbody.innerHTML = `<div style="height:${topPad}px"></div>` + slice.map(formatRow).join('') + `<div style="height:${bottomPad}px"></div>`;
        const rows = vbody.querySelectorAll('.row');
        rows.forEach((rowEl, i)=>{
          const idx = firstIdx + i;
          rowEl.style.cursor='pointer';
          const handleClick = (e)=>{
            if(e.shiftKey){
              if(anchor===null) anchor = sel;
              selected.clear();
              const a = Math.min(anchor, idx), b = Math.max(anchor, idx);
              for(let k=a;k<=b;k++) selected.add(k);
              sel = idx;
            } else if(e.metaKey || e.ctrlKey){
              if(selected.has(idx)) selected.delete(idx); else selected.add(idx);
              sel = idx; anchor = idx;
            } else {
              selected.clear(); selected.add(idx); sel = idx; anchor = idx;
            }
            applySelection(rows, firstIdx);
          };
          rowEl.addEventListener('click', handleClick);
          rowEl.addEventListener('keydown', (e)=>{ if(e.key==='Enter'){ e.preventDefault(); showDetails(sorted[idx]); }});
        });
        function applySelection(rowsLocal, base){ rowsLocal.forEach((el,j)=>{ const idx = base + j; const isSel = selected.has(idx); el.classList.toggle('selected', isSel); el.setAttribute('aria-selected', isSel?'true':'false'); el.setAttribute('tabindex', idx===sel?'0':'-1'); }); const focusEl = rowsLocal[Math.max(0, sel-firstIdx)]; focusEl && focusEl.focus({preventScroll:true}); }
        // Initial paint selection
        applySelection(rows, firstIdx);
      }
      vbody.onscroll = draw;
      draw();
      vbody.onkeydown = (e)=>{
        const step = Math.floor(vbody.clientHeight/ROW_H) || 10;
        if(e.key==='a' && (e.ctrlKey || e.metaKey)){
          e.preventDefault(); selected.clear(); for(let i=0;i<sorted.length;i++) selected.add(i); sel = Math.min(sel, sorted.length-1); draw(); return;
        }
        if(e.key==='ArrowDown'){
          e.preventDefault(); const prev = sel; sel=Math.min(sorted.length-1, sel+1);
          if(e.shiftKey){ if(anchor===null) anchor=prev; selected.clear(); const a=Math.min(anchor, sel), b=Math.max(anchor, sel); for(let k=a;k<=b;k++) selected.add(k);} else { anchor=sel; }
          draw();
        } else if(e.key==='ArrowUp'){
          e.preventDefault(); const prev = sel; sel=Math.max(0, sel-1);
          if(e.shiftKey){ if(anchor===null) anchor=prev; selected.clear(); const a=Math.min(anchor, sel), b=Math.max(anchor, sel); for(let k=a;k<=b;k++) selected.add(k);} else { anchor=sel; }
          draw();
        } else if(e.key==='PageDown'){
          e.preventDefault(); const prev = sel; sel=Math.min(sorted.length-1, sel + step);
          if(e.shiftKey){ if(anchor===null) anchor=prev; selected.clear(); const a=Math.min(anchor, sel), b=Math.max(anchor, sel); for(let k=a;k<=b;k++) selected.add(k);} else { anchor=sel; }
          draw();
        } else if(e.key==='PageUp'){
          e.preventDefault(); const prev = sel; sel=Math.max(0, sel - step);
          if(e.shiftKey){ if(anchor===null) anchor=prev; selected.clear(); const a=Math.min(anchor, sel), b=Math.max(anchor, sel); for(let k=a;k<=b;k++) selected.add(k);} else { anchor=sel; }
          draw();
        } else if(e.key==='Home'){
          e.preventDefault(); sel=0; if(e.shiftKey){ if(anchor===null) anchor=0; selected.clear(); for(let k=0;k<=anchor;k++) selected.add(k);} else { selected.clear(); selected.add(sel); anchor=sel; } vbody.scrollTop=0; draw();
        } else if(e.key==='End'){
          e.preventDefault(); sel=sorted.length-1; if(e.shiftKey){ if(anchor===null) anchor=sel; selected.clear(); const a=Math.min(anchor, sel), b=Math.max(anchor, sel); for(let k=a;k<=b;k++) selected.add(k);} else { selected.clear(); selected.add(sel); anchor=sel; } vbody.scrollTop = sorted.length*ROW_H; draw();
        } else if(e.key==='Enter'){
          e.preventDefault(); showDetails(sorted[sel]);
        }
      };
    }
    document.getElementById('prev').addEventListener('click',()=>{ if(page>1){ page--; render(); }});
    document.getElementById('next').addEventListener('click',()=>{ page++; render(); });
    qEl.addEventListener('input', e=>{ query = e.target.value; saveState(); page=1; render(); });
    document.getElementById('pageSize').addEventListener('change', e=>{ PAGE_SIZE = parseInt(e.target.value,10)||100; page=1; render(); });
    document.querySelectorAll('thead th').forEach(th=>{
      th.addEventListener('click',()=>{
        const k = th.getAttribute('data-k');
        if(sortKey===k){ sortAsc = !sortAsc; } else { sortKey=k; sortAsc=true; }
        render();
      });
    });
    function buildColPicker(){
      const holder = document.getElementById('colpicker');
      holder.innerHTML = cols.map(c=>`<label class="opt"><input type="checkbox" data-ckey="${c.key}" ${c.on?'checked':''}><span>${c.label}</span></label>`).join('');
      holder.querySelectorAll('input').forEach(inp=>{
        inp.addEventListener('change', e=>{
          const k = e.target.getAttribute('data-ckey');
          const c = cols.find(x=>x.key===k); if(!c) return; c.on = e.target.checked; activeCls(); saveState(); render();
        });
      });
      activeCls();
    }
    function buildFacets(){
      const vset = new Set(); const eset = new Set(); const mset = new Set(); const oset = new Set();
      DATA.forEach(r=>{ const v=(get(r,'security.verdict')||'').toLowerCase(); if(v) vset.add(v); eset.add(extOf(r.name||'')); const mm=(get(r,'type.mime')||'').split(';')[0].toLowerCase(); if(mm) mset.add(mm); const oo=(get(r,'owner.user')||'').toLowerCase(); if(oo) oset.add(oo); });
      const mk = (container, set, target)=>{
        container.innerHTML = Array.from(set).sort().map(val=>`<label class="opt"><input type="checkbox" data-facet="${target}" value="${val}"><span>${val}</span></label>`).join('');
        container.querySelectorAll('input').forEach(inp=>{
          inp.addEventListener('change', e=>{
            const facet = e.target.getAttribute('data-facet');
            const val = e.target.value;
            const coll = filters[facet];
            if(e.target.checked) coll.add(val); else coll.delete(val);
            saveState();
            page=1; render();
          });
        });
      };
      mk(facetVerdict, vset, 'verdict');
      mk(facetExt, eset, 'ext');
      mk(facetMime, mset, 'mime');
      mk(facetOwner, oset, 'owner');
      function toEpoch(d){ if(!d) return null; const t = Date.parse(d); return isNaN(t)? null : Math.floor(t/1000); }
      dateFrom && dateFrom.addEventListener('change', e=>{ filters.from = toEpoch(e.target.value); saveState(); page=1; render(); });
      dateTo && dateTo.addEventListener('change', e=>{ const t = Date.parse(e.target.value); filters.to = isNaN(t)? null : Math.floor(t/1000)+86399; saveState(); page=1; render(); });
    }
    function downloadJSON(){
      const filtered = applyFilter(DATA);
      const blob = new Blob([JSON.stringify(filtered,null,2)],{type:'application/json'});
      const a = document.createElement('a'); a.href = URL.createObjectURL(blob); a.download = 'finfo-data.json'; a.click(); URL.revokeObjectURL(a.href);
    }
    document.getElementById('dljson').addEventListener('click', downloadJSON);
    // Minimal JSON→YAML converter (strings, numbers, booleans, null, arrays, objects)
    function toYAML(value, indent=''){
      const IND = '  ';
      if(value===null) return 'null';
      const t = typeof value;
      if(t==='string'){
        if(/[:#\-\n]/.test(value)) return JSON.stringify(value); // quote
        return value;
      }
      if(t==='number' || t==='boolean') return String(value);
      if(Array.isArray(value)){
        if(value.length===0) return '[]';
        return value.map(v=> `${indent}- ${/^(object|array)$/.test(typeof v)?'':toYAML(v, indent+IND)}${(typeof v==='object' && v!==null)?'\n'+toYAML(v, indent+IND).replace(/^/gm, indent+IND):''}`)
          .join('\n');
      }
      // object
      const keys = Object.keys(value);
      if(keys.length===0) return '{}';
      return keys.map(k=>{
        const v = value[k];
        const key = /[:#\-\n]/.test(k) ? JSON.stringify(k) : k;
        if(v===null || typeof v!=='object' || Array.isArray(v)){
          const vv = toYAML(v, indent+IND).replace(/^/gm, indent+IND);
          return `${indent}${key}: ${vv.trimStart()}`;
        } else {
          const vv = toYAML(v, indent+IND).replace(/^/gm, indent+IND);
          return `${indent}${key}:\n${vv}`;
        }
      }).join('\n');
    }
    function downloadYAML(){
      const filtered = applyFilter(DATA);
      const yaml = toYAML(filtered, '');
      const blob = new Blob([yaml],{type:'text/yaml'});
      const a = document.createElement('a'); a.href = URL.createObjectURL(blob); a.download = 'finfo-data.yaml'; a.click(); URL.revokeObjectURL(a.href);
    }
    document.getElementById('dlyaml').addEventListener('click', downloadYAML);
    function copyToClipboard(text){ const ta=document.createElement('textarea'); ta.value=text; document.body.appendChild(ta); ta.select(); document.execCommand('copy'); document.body.removeChild(ta); }
    function getSelectedRows(){
      if(!sortedCache || !sortedCache.length) return [];
      const out = [];
      if(selected.size===0){ out.push(sortedCache[sel]); return out; }
      selected.forEach(i=>{ if(i>=0 && i<sortedCache.length) out.push(sortedCache[i]); });
      return out;
    }
    document.getElementById('copyjson').addEventListener('click', ()=>{
      const rows = getSelectedRows();
      const txt = JSON.stringify(rows, null, 2);
      copyToClipboard(txt);
    });
    document.getElementById('copyyaml').addEventListener('click', ()=>{
      const rows = getSelectedRows();
      const y = toYAML(rows, '');
      copyToClipboard(y);
    });

    loadState();
    buildFacets();
    buildColPicker();
    const overlay = document.getElementById('overlay');
    const close = document.getElementById('close');
    close.addEventListener('click', ()=> overlay.style.display='none');
    overlay.addEventListener('click', (e)=>{ if(e.target===overlay) overlay.style.display='none'; });
    document.addEventListener('keydown', (e)=>{ if(e.key==='Escape') overlay.style.display='none'; });
    function showDetails(r){
      const body = document.getElementById('dlg-body');
      const safe = s=> (s==null?'' : String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;'));
      body.innerHTML = `
        <div class="kv"><div class="k">Name</div><div>${safe(r.name)}</div></div>
        <div class="kv"><div class="k">Path</div><div><code>${safe(get(r,'path.rel'))}</code></div></div>
        <div class="kv"><div class="k">Bytes</div><div>${safe(get(r,'size.bytes'))} (${safe(get(r,'size.human'))})</div></div>
        <div class="kv"><div class="k">Type</div><div>${safe(get(r,'type.description'))}</div></div>
        <div class="kv"><div class="k">Verdict</div><div>${safe(get(r,'security.verdict'))}</div></div>
        <div class="kv"><div class="k">Created</div><div>${safe(get(r,'dates.created'))}</div></div>
        <div class="kv"><div class="k">Modified</div><div>${safe(get(r,'dates.modified'))}</div></div>
        <div class="kv"><div class="k">Owner</div><div>${safe(get(r,'perms.symbolic'))} (${safe(get(r,'perms.octal'))})</div></div>
      `;
      overlay.style.display='flex';
    }
    render();
  </script>
</body>
</html>
HTML_TAIL

  printf "Generated dashboard: %s\n" "$out_html"
}


