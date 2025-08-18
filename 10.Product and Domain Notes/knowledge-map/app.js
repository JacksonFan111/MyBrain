/* global cytoscape, NODES, EDGES, Fuse */

function buildElements(nodes, edges){
  const elements = [];
  nodes.forEach(n => {
    elements.push({ data: { id: n.id, label: n.label, url: n.url || null, type: n.type, tags: (n.tags||[]).join(',') } });
  });
  edges.forEach(([src,tgt]) => elements.push({ data: { id: `${src}__${tgt}`, source: src, target: tgt }}));
  return elements;
}

function layoutOptions(name){
  switch(name){
    case 'grid': return { name: 'grid', fit: true, padding: 30 };
    case 'circle': return { name: 'circle', fit: true, padding: 30 };
    case 'concentric': return { name: 'concentric', fit: true, padding: 30, minNodeSpacing: 40 };
    case 'breadthfirst': return { name: 'breadthfirst', fit: true, padding: 30, directed: true };
    default:
      return {
        name: 'fcose',
        quality: 'proof',
        randomize: false,
        nodeRepulsion: 6000,
        idealEdgeLength: 120,
        edgeElasticity: 0.3,
        nestingFactor: 0.9,
        gravity: 0.6,
        numIter: 3000,
        tile: true,
        fit: true,
        padding: 30
      };
  }
}

function style(){
  return [
    { selector: 'node', style: {
      'background-color': ele => {
        const t = ele.data('type');
        if (t === 'topic') return '#2563eb';
        if (t === 'md') return '#10b981';
        return '#94a3b8';
      },
      'label': 'data(label)',
      'color': '#e6eef7',
      'text-wrap': 'wrap',
      'text-max-width': 160,
      'font-size': 11,
      'font-weight': 600,
      'text-outline-color': '#0b0f14',
      'text-outline-width': 2,
      'border-color': '#1f2a37',
      'border-width': 2,
      'width': ele => ele.data('type') === 'topic' ? 60 : 40,
      'height': ele => ele.data('type') === 'topic' ? 60 : 40,
      'shape': ele => ele.data('type') === 'topic' ? 'round-rectangle' : 'ellipse'
    }},
    { selector: 'edge', style: {
      'width': 2,
      'line-color': '#334155',
      'curve-style': 'unbundled-bezier',
      'target-arrow-shape': 'triangle',
      'target-arrow-color': '#334155'
    }},
    { selector: '.faded', style: { 'opacity': 0.15 }},
    { selector: '.hidden', style: { 'display': 'none' }},
    { selector: 'node:selected', style: { 'overlay-opacity': 0, 'border-color': '#60a5fa' }}
  ];
}

function initFilters(){
  const chipBar = document.getElementById('chipBar');
  chipBar.innerHTML = '';
  const selected = new Set();
  const chips = [];
  ALL_TAGS.forEach(tag => {
    const span = document.createElement('span');
    span.className = 'chip';
    span.textContent = tag;
    span.addEventListener('click', () => {
      if (selected.has(tag)) { selected.delete(tag); span.classList.remove('active'); }
      else { selected.add(tag); span.classList.add('active'); }
      document.dispatchEvent(new CustomEvent('chipFilterChange', { detail: Array.from(selected) }));
    });
    chips.push(span); chipBar.appendChild(span);
  });
}

function initTopicSelect(){
  const select = document.getElementById('topicSelect');
  select.innerHTML = '<option value="">(none)</option>';
  NODES.filter(n => n.type === 'topic').forEach(n => {
    const opt = document.createElement('option');
    opt.value = n.id; opt.textContent = n.label; select.appendChild(opt);
  });
}

function setDetails(content){
  const panel = document.querySelector('#details .detail-content');
  panel.innerHTML = content;
}

function renderDetails(node){
  const data = node.data();
  const tags = (data.tags || '').split(',').filter(Boolean).map(t => `<span class="chip">${t}</span>`).join(' ');
  const link = data.url ? `<a class="btn" href="${data.url}" target="_blank" rel="noopener">Open</a>` : '';
  setDetails(`
    <div>
      <div style="display:flex;justify-content:space-between;align-items:center;gap:8px">
        <div>
          <div style="font-size:13px;color:#9fb2c7">Type: ${data.type.toUpperCase()}</div>
          <h3 style="margin:4px 0 6px 0">${data.label}</h3>
        </div>
        ${link}
      </div>
      <div style="display:flex;flex-wrap:wrap;gap:6px;margin-top:6px">${tags}</div>
    </div>
  `);
}

async function augmentFromIndex(cy, fuse) {
  try {
    const res = await fetch('../Confluence-space-export-205412.html/index.html');
    const html = await res.text();
    const parser = new DOMParser();
    const doc = parser.parseFromString(html, 'text/html');
    const anchors = Array.from(doc.querySelectorAll('div.pageSection a[href]'));
    const seen = new Set();
    const addedNodes = [];
    const progress = document.getElementById('progress');
    const bar = document.getElementById('progressBar');
    const label = document.getElementById('progressLabel');
    progress.hidden = false; bar.style.width = '0%'; label.textContent = 'Ingesting pages…';

    const guessTags = (label, href) => {
      const l = (label||'').toLowerCase();
      const h = (href||'').toLowerCase();
      const tags = [];
      if (/power\s*bi|dax|measure|subscription/.test(l)) tags.push('powerbi');
      if (/devops|synapse|workspace|arm|dacpac/.test(l)) tags.push('devops','synapse');
      if (/ace|orders|holdings|chelmer/.test(l)) tags.push('ace');
      if (/crm|audit/.test(l)) tags.push('crm','audit');
      if (/nzxwt/.test(l)) tags.push('nzxwt');
      if (/circuit|servicelevels|fum/.test(l)) tags.push('circuit');
      if (/aloha|rds/.test(l)) tags.push('aloha','rds');
      if (/fatca|crs|ides|tin|usp/.test(l)) tags.push('fatca','crs');
      if (/ssrs/.test(l)) tags.push('ssrs');
      if (tags.length === 0) tags.push('misc');
      return tags;
    };

    anchors.forEach((a, i) => {
      const href = a.getAttribute('href');
      if (!href || href.includes('attachments/') || href.includes('styles/') || href.includes('images/')) return;
      const id = `html-${href.replace(/[^a-zA-Z0-9_-]/g,'_')}`;
      if (seen.has(id)) return; seen.add(id);
      const label = a.textContent.trim() || href;
      const url = `../Confluence-space-export-205412.html/${href}`;
      const tags = guessTags(label, href);

      cy.add({ data: { id, label, url, type: 'html', tags: tags.join(',') } });
      cy.add({ data: { id: `topic-all__${id}`, source: 'topic-all', target: id } });
      // Attach to heuristic topic hubs as well
      if (tags.includes('devops')) cy.add({ data: { id: `topic-devops__${id}`, source: 'topic-devops', target: id } });
      if (tags.includes('powerbi')) cy.add({ data: { id: `topic-powerbi__${id}`, source: 'topic-powerbi', target: id } });
      if (tags.includes('ace')) cy.add({ data: { id: `topic-ace__${id}`, source: 'topic-ace', target: id } });
      if (tags.includes('crm')) cy.add({ data: { id: `topic-crm__${id}`, source: 'topic-crm', target: id } });
      if (tags.includes('nzxwt')) cy.add({ data: { id: `topic-nzxwt__${id}`, source: 'topic-nzxwt', target: id } });
      if (tags.includes('circuit')) cy.add({ data: { id: `topic-circuit__${id}`, source: 'topic-circuit', target: id } });
      if (tags.includes('aloha')) cy.add({ data: { id: `topic-aloha__${id}`, source: 'topic-aloha', target: id } });

      addedNodes.push({ id, label, tags: tags.join(' ') });
      if (i % 20 === 0) { bar.style.width = `${Math.round((i/anchors.length)*100)}%`; }
    });

    // Update search index
    fuse.addDocuments(addedNodes);
    cy.layout(layoutOptions('fcose')).run();
    bar.style.width = '100%'; label.textContent = `Ingested ${addedNodes.length} pages.`;
    setTimeout(() => { progress.hidden = true; }, 1200);
  } catch (e) {
    console.warn('Index ingestion failed', e);
  }
}

document.addEventListener('DOMContentLoaded', async () => {
  const elements = buildElements(NODES, EDGES);
  const cy = cytoscape({
    container: document.getElementById('cy'),
    elements,
    style: style(),
    layout: layoutOptions('fcose'),
    wheelSensitivity: 0.2,
    pixelRatio: 1
  });

  // Fuse search index on label + tags
  const fuse = new Fuse(NODES.map(n => ({ id: n.id, label: n.label, tags: (n.tags||[]).join(' ') })), {
    keys: ['label', 'tags'], threshold: 0.35, ignoreLocation: true
  });

  initFilters();
  initTopicSelect();

  const searchInput = document.getElementById('search');
  const resetBtn = document.getElementById('resetBtn');
  const exportBtn = document.getElementById('exportBtn');
  const toggleHtml = document.getElementById('toggleHtml');
  const toggleMd = document.getElementById('toggleMd');
  const topicSelect = document.getElementById('topicSelect');
  const layoutSelect = document.getElementById('layoutSelect');
  const enrichBtn = document.getElementById('enrichBtn');
  const linkBtn = document.getElementById('linkBtn');

  function applyVisibility(){
    const showHtml = toggleHtml.checked; const showMd = toggleMd.checked;
    cy.nodes().forEach(n => {
      const t = n.data('type');
      if (t === 'html' && !showHtml) n.addClass('hidden');
      else if (t === 'md' && !showMd) n.addClass('hidden');
      else n.removeClass('hidden');
    });
  }

  function applyChipFilter(tags){
    // If no tags selected: clear fades
    cy.nodes().removeClass('faded');
    if (!tags || tags.length === 0) return;
    cy.nodes().forEach(n => {
      const nodeTags = (n.data('tags')||'').split(',').filter(Boolean);
      const match = tags.every(t => nodeTags.includes(t));
      if (!match) n.addClass('faded'); else n.removeClass('faded');
    });
  }

  function focusTopic(id){
    cy.nodes().removeClass('faded');
    if (!id) { cy.fit(undefined, 30); return; }
    const topic = cy.getElementById(id);
    const neighbors = topic.closedNeighborhood();
    cy.elements().not(neighbors).not(topic).addClass('faded');
    cy.animate({ center: { eles: neighbors }, fit: { eles: neighbors, padding: 40 }, duration: 400 });
  }

  searchInput.addEventListener('input', (e) => {
    const q = e.target.value.trim();
    cy.nodes().removeClass('faded');
    if (!q) { return; }
    const results = fuse.search(q).map(r => r.item.id);
    const keep = new Set(results);
    cy.nodes().forEach(n => { if (!keep.has(n.id())) n.addClass('faded'); });
  });

  resetBtn.addEventListener('click', () => {
    searchInput.value = '';
    cy.nodes().removeClass('faded');
    cy.nodes().removeClass('hidden');
    toggleHtml.checked = true; toggleMd.checked = true;
    topicSelect.value = '';
    cy.layout(layoutOptions(layoutSelect.value || 'fcose')).run();
  });

  exportBtn.addEventListener('click', () => {
    const png64 = cy.png({ full: true, scale: 2, bg: '#0b0f14' });
    const a = document.createElement('a');
    a.href = png64; a.download = 'knowledge-map.png'; a.click();
  });

  // Enrich tags using quick heuristics across all nodes
  enrichBtn.addEventListener('click', () => {
    cy.nodes().forEach(n => {
      if (n.data('type') === 'topic') return;
      const cur = (n.data('tags')||'').split(',').filter(Boolean);
      const extra = [];
      const L = (n.data('label')||'').toLowerCase();
      if (/sql|proc|usp|merge|table|view/.test(L)) extra.push('sql');
      if (/etl|pipeline|metadata|framework/.test(L)) extra.push('etl');
      if (/aml|napier/.test(L)) extra.push('aml');
      const tags = Array.from(new Set([...cur, ...extra])).filter(Boolean);
      n.data('tags', tags.join(','));
    });
  });

  // Link similar nodes (cosine on Fuse scores; simplistic pairing)
  linkBtn.addEventListener('click', () => {
    // Build a simple index: for each node, find top-1 similar other node and link with dotted edge
    const items = cy.nodes().map(n => ({ id: n.id(), label: n.data('label'), tags: (n.data('tags')||'').replace(/,/g,' ') }));
    const idx = new Fuse(items, { keys: ['label','tags'], threshold: 0.25, ignoreLocation: true });
    const made = new Set();
    items.forEach(it => {
      const hits = idx.search(it.label).filter(h => h.item.id !== it.id).slice(0,1);
      hits.forEach(h => {
        const eid = `sim_${it.id}__${h.item.id}`;
        if (made.has(eid)) return; made.add(eid);
        cy.add({ data: { id: eid, source: it.id, target: h.item.id }, classes: 'sim' });
      });
    });
    cy.style().selector('edge.sim').style({ 'line-style': 'dotted', 'opacity': 0.5 }).update();
    cy.layout(layoutOptions(layoutSelect.value || 'fcose')).run();
  });

  toggleHtml.addEventListener('change', applyVisibility);
  toggleMd.addEventListener('change', applyVisibility);
  layoutSelect.addEventListener('change', () => cy.layout(layoutOptions(layoutSelect.value)).run());

  document.addEventListener('chipFilterChange', (e) => applyChipFilter(e.detail));
  topicSelect.addEventListener('change', () => focusTopic(topicSelect.value));

  cy.on('tap', 'node', (evt) => {
    const n = evt.target; renderDetails(n);
  });
  cy.on('tap', (evt) => {
    if (evt.target === cy) setDetails('<div class="hint">Click a node to see details.</div>');
  });

  cy.on('cxttap', 'node', (evt) => {
    const n = evt.target; const url = n.data('url');
    if (url) window.open(url, '_blank', 'noopener');
  });

  // Ingest all pages dynamically from Confluence export index
  await augmentFromIndex(cy, fuse);
});

