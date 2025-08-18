// Minimal data model for the map. Extend this file to add more nodes.
// Types: topic, html, md

const NODES = [
  { id: 'topic-devops', label: 'DevOps & Platform', type: 'topic', tags: ['devops','synapse','cicd'] },
  { id: 'topic-powerbi', label: 'Power BI', type: 'topic', tags: ['powerbi','dax'] },
  { id: 'topic-ace', label: 'ACE', type: 'topic', tags: ['ace','operations'] },
  { id: 'topic-crm', label: 'CRM & Audit', type: 'topic', tags: ['crm','audit'] },
  { id: 'topic-nzxwt', label: 'NZXWT', type: 'topic', tags: ['nzxwt'] },
  { id: 'topic-circuit', label: 'Circuit Breaker', type: 'topic', tags: ['circuit','fum'] },
  { id: 'topic-aloha', label: 'ALOHA RDS', type: 'topic', tags: ['aloha','rds'] },
  { id: 'topic-all', label: 'All Pages', type: 'topic', tags: ['all'] },

  // DevOps HTML/MD
  { id: 'html-devops-1', label: 'Workshop Day1 Part 1 (HTML)', type: 'html', url: '../Confluence-space-export-205412.html/Data-platform-DevOps-Workshop-Day-1---part-1_3255730205.html', tags: ['synapse','workshop','devops'] },
  { id: 'html-devops-2', label: 'Workshop Day1 Part 2 (HTML)', type: 'html', url: '../Confluence-space-export-205412.html/Data-Platform-DevOps-Workshop-Day-1---Part-2_3256156203.html', tags: ['cicd','arm','dacpac'] },
  { id: 'md-synapse', label: 'Synapse DevOps (MD)', type: 'md', url: '../synapse-devops.md', tags: ['runbook','synapse','cicd'] },

  // Power BI
  { id: 'html-dax', label: 'DAX Indirect filtering (HTML)', type: 'html', url: '../Confluence-space-export-205412.html/DAX---Indirect-filtering-pattern_3107192894.html', tags: ['dax','treatas'] },
  { id: 'md-dax', label: 'DAX Indirect filtering (MD)', type: 'md', url: '../dax-indirect-filtering.md', tags: ['dax'] },

  // ACE
  { id: 'html-ace-audit', label: 'ACE Schema Audit (HTML)', type: 'html', url: '../Confluence-space-export-205412.html/Ace-Schema-Audit-on-SQLUAT-and-SQLCIP_3084255305.html', tags: ['ace','schema'] },
  { id: 'html-ace-orders', label: 'sp_GetACEOrders (HTML)', type: 'html', url: '../Confluence-space-export-205412.html/Overview-of-sp_GetACEOrders-Process_3086287042.html', tags: ['ace','orders'] },
  { id: 'md-ace', label: 'ACE Operations (MD)', type: 'md', url: '../ace-operations.md', tags: ['ace'] },

  // CRM & Audit
  { id: 'html-crm-audit', label: 'CRM Audit Master (HTML)', type: 'html', url: '../Confluence-space-export-205412.html/CRM-Audit-Master-Tech-Notes_3204120591.html', tags: ['crm','audit'] },
  { id: 'md-citi-csl-crm', label: 'CITI → CSL → CRM (MD)', type: 'md', url: '../citi-csl-crm.md', tags: ['crm','bridge'] },

  // NZXWT
  { id: 'html-nzxwt-join', label: 'NZXWT Refresher (HTML)', type: 'html', url: '../Confluence-space-export-205412.html/NZXWT-Refresher---hwo-to-join-tables_3060400310.html', tags: ['nzxwt','joins'] },

  // Circuit Breaker
  { id: 'html-circuit', label: 'ChangedServiceLevels (HTML)', type: 'html', url: '../Confluence-space-export-205412.html/3.5-Circuit-Breaker---ChangedServiceLevels-Logics_3198156825.html', tags: ['circuit','fum'] },
  { id: 'md-circuit', label: 'Circuit Breaker (MD)', type: 'md', url: '../circuit-breaker.md', tags: ['circuit'] },

  // ALOHA
  { id: 'html-aloha', label: 'ALOHA RDS (HTML)', type: 'html', url: '../Confluence-space-export-205412.html/ALOHA-RDS-Exploration_3016327726.html', tags: ['aloha','rds'] },
  { id: 'md-aloha', label: 'ALOHA RDS (MD)', type: 'md', url: '../aloha-rds.md', tags: ['aloha'] },
];

const EDGES = [
  // Topic containment edges
  ['topic-devops','html-devops-1'],
  ['topic-devops','html-devops-2'],
  ['topic-devops','md-synapse'],

  ['topic-powerbi','html-dax'],
  ['topic-powerbi','md-dax'],

  ['topic-ace','html-ace-audit'],
  ['topic-ace','html-ace-orders'],
  ['topic-ace','md-ace'],

  ['topic-crm','html-crm-audit'],
  ['topic-crm','md-citi-csl-crm'],

  ['topic-nzxwt','html-nzxwt-join'],

  ['topic-circuit','html-circuit'],
  ['topic-circuit','md-circuit'],

  ['topic-aloha','html-aloha'],
  ['topic-aloha','md-aloha'],

  // Cross-links
  ['md-synapse','html-aloha'],
  ['md-ace','html-circuit'],
  ['md-dax','html-dax'],
  ['md-citi-csl-crm','html-ace-orders'],
];

const ALL_TAGS = Array.from(new Set(NODES.flatMap(n => n.tags || []))).sort();

