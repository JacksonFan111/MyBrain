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

document.addEventListener('DOMContentLoaded', () => {
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
});

