"""HTML dashboard and playground template."""

DASHBOARD_HTML = """<!DOCTYPE html>
<html lang="en" class="dark">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Open Directory Indexer & Search Playground</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
    .hidden { display: none !important; }
    .tab-active { border-bottom: 2px solid #6366f1; color: #6366f1; font-weight: 600; }
    .badge-video { background: rgba(239, 68, 68, 0.15); color: #f87171; border: 1px solid rgba(239, 68, 68, 0.3); }
    .badge-audio { background: rgba(234, 179, 8, 0.15); color: #facc15; border: 1px solid rgba(234, 179, 8, 0.3); }
    .badge-doc { background: rgba(59, 130, 246, 0.15); color: #60a5fa; border: 1px solid rgba(59, 130, 246, 0.3); }
    .badge-archive { background: rgba(168, 85, 247, 0.15); color: #c084fc; border: 1px solid rgba(168, 85, 247, 0.3); }
    .badge-exe { background: rgba(34, 197, 94, 0.15); color: #4ade80; border: 1px solid rgba(34, 197, 94, 0.3); }
  </style>
</head>
<body class="bg-slate-950 text-slate-100 min-h-screen flex flex-col antialiased">

  <!-- Navigation Bar -->
  <header class="border-b border-slate-800 bg-slate-900/70 backdrop-blur sticky top-0 z-40 px-6 py-3.5 flex items-center justify-between">
    <div class="flex items-center space-x-3">
      <div class="w-9 h-9 rounded-lg bg-indigo-600 flex items-center justify-center font-bold text-white shadow-lg shadow-indigo-500/30">
        📁
      </div>
      <div>
        <h1 class="font-bold text-lg leading-tight tracking-tight text-white flex items-center gap-2">
          FilePursuit Indexer
          <span class="text-xs font-medium px-2 py-0.5 rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 flex items-center gap-1">
            <span class="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse"></span>
            Online Engine
          </span>
        </h1>
        <p class="text-xs text-slate-400">Asynchronous Open-Directory File Indexer, FTS5 & SQL Playground</p>
      </div>
    </div>
    <div class="flex items-center space-x-3">
      <a href="/docs" target="_blank" class="text-xs text-slate-400 hover:text-indigo-400 transition flex items-center gap-1 border border-slate-800 hover:border-slate-700 rounded-lg px-3 py-1.5 bg-slate-900">
        📖 OpenAPI Docs
      </a>
      <button onclick="fetchStats()" class="text-xs bg-indigo-600 hover:bg-indigo-500 text-white font-medium px-3.5 py-1.5 rounded-lg transition shadow-sm flex items-center gap-1.5">
        🔄 Refresh
      </button>
    </div>
  </header>

  <!-- Main Container -->
  <main class="flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 py-6 space-y-6">

    <!-- KPI Stats Cards -->
    <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3.5">
      <div class="bg-slate-900/60 border border-slate-800 rounded-xl p-3.5 flex flex-col justify-between">
        <span class="text-xs text-slate-400 font-medium">Total Files</span>
        <span id="stat-total" class="text-2xl font-bold text-white mt-1">--</span>
      </div>
      <div class="bg-slate-900/60 border border-slate-800 rounded-xl p-3.5 flex flex-col justify-between">
        <span class="text-xs text-red-400 font-medium flex items-center gap-1">🎥 Videos</span>
        <span id="stat-video" class="text-2xl font-bold text-red-400 mt-1">0</span>
      </div>
      <div class="bg-slate-900/60 border border-slate-800 rounded-xl p-3.5 flex flex-col justify-between">
        <span class="text-xs text-purple-400 font-medium flex items-center gap-1">📦 Archives</span>
        <span id="stat-archive" class="text-2xl font-bold text-purple-400 mt-1">0</span>
      </div>
      <div class="bg-slate-900/60 border border-slate-800 rounded-xl p-3.5 flex flex-col justify-between">
        <span class="text-xs text-blue-400 font-medium flex items-center gap-1">📄 Documents</span>
        <span id="stat-document" class="text-2xl font-bold text-blue-400 mt-1">0</span>
      </div>
      <div class="bg-slate-900/60 border border-slate-800 rounded-xl p-3.5 flex flex-col justify-between">
        <span class="text-xs text-yellow-400 font-medium flex items-center gap-1">🎵 Audio</span>
        <span id="stat-audio" class="text-2xl font-bold text-yellow-400 mt-1">0</span>
      </div>
      <div class="bg-slate-900/60 border border-slate-800 rounded-xl p-3.5 flex flex-col justify-between">
        <span class="text-xs text-emerald-400 font-medium flex items-center gap-1">⚡ FTS5 Search</span>
        <span id="stat-fts" class="text-sm font-semibold text-emerald-400 mt-2">Active</span>
      </div>
    </div>

    <!-- Playground Tabs Navigation -->
    <div class="flex border-b border-slate-800 space-x-6 text-sm">
      <button id="tab-btn-search" onclick="switchTab('search')" class="tab-active py-2.5 px-1 flex items-center gap-2 transition">
        🔍 File Search Engine
      </button>
      <button id="tab-btn-sql" onclick="switchTab('sql')" class="text-slate-400 hover:text-slate-200 py-2.5 px-1 flex items-center gap-2 transition">
        ⚡ Live SQL Playground
      </button>
      <button id="tab-btn-crawl" onclick="switchTab('crawl')" class="text-slate-400 hover:text-slate-200 py-2.5 px-1 flex items-center gap-2 transition">
        🕷️ Seed & Crawler
      </button>
    </div>

    <!-- TAB 1: FILE SEARCH ENGINE -->
    <section id="tab-content-search" class="space-y-4">
      <div class="bg-slate-900/80 border border-slate-800 rounded-2xl p-4 sm:p-5 space-y-4 shadow-xl">
        <!-- Search Input -->
        <div class="relative">
          <input 
            type="text" 
            id="search-input" 
            placeholder="Search millions of indexed files by keyword, title, extension (e.g. sintel, reel, avi, iso)..." 
            class="w-full bg-slate-950 border border-slate-700 rounded-xl px-4 py-3 text-white placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 text-sm sm:text-base pr-24 shadow-inner"
            oninput="handleSearchInput()"
          />
          <button onclick="executeSearch()" class="absolute right-2 top-2 bottom-2 bg-indigo-600 hover:bg-indigo-500 text-white font-medium px-4 rounded-lg text-sm transition">
            Search
          </button>
        </div>

        <!-- Filter Controls -->
        <div class="flex flex-wrap items-center justify-between gap-3 text-xs">
          <div class="flex flex-wrap items-center gap-1.5" id="category-filters">
            <button onclick="setCategoryFilter(null)" data-cat="all" class="cat-pill bg-indigo-600 text-white font-medium px-3 py-1.5 rounded-lg border border-indigo-500 transition">
              All Files
            </button>
            <button onclick="setCategoryFilter('video')" data-cat="video" class="cat-pill bg-slate-950 hover:bg-slate-800 text-slate-300 px-3 py-1.5 rounded-lg border border-slate-800 transition">
              🎥 Video
            </button>
            <button onclick="setCategoryFilter('audio')" data-cat="audio" class="cat-pill bg-slate-950 hover:bg-slate-800 text-slate-300 px-3 py-1.5 rounded-lg border border-slate-800 transition">
              🎵 Audio
            </button>
            <button onclick="setCategoryFilter('document')" data-cat="document" class="cat-pill bg-slate-950 hover:bg-slate-800 text-slate-300 px-3 py-1.5 rounded-lg border border-slate-800 transition">
              📄 Document
            </button>
            <button onclick="setCategoryFilter('archive')" data-cat="archive" class="cat-pill bg-slate-950 hover:bg-slate-800 text-slate-300 px-3 py-1.5 rounded-lg border border-slate-800 transition">
              📦 Archive
            </button>
            <button onclick="setCategoryFilter('executable')" data-cat="executable" class="cat-pill bg-slate-950 hover:bg-slate-800 text-slate-300 px-3 py-1.5 rounded-lg border border-slate-800 transition">
              ⚙️ Executable
            </button>
          </div>
          <div class="flex items-center gap-2 text-slate-400">
            <span>Limit:</span>
            <select id="search-limit" onchange="executeSearch()" class="bg-slate-950 border border-slate-800 rounded-lg px-2.5 py-1 text-slate-300 focus:outline-none focus:ring-1 focus:ring-indigo-500 text-xs">
              <option value="25">25</option>
              <option value="50" selected>50</option>
              <option value="100">100</option>
              <option value="200">200</option>
            </select>
          </div>
        </div>
      </div>

      <!-- Search Results Header -->
      <div class="flex items-center justify-between text-xs text-slate-400 px-1">
        <span id="results-count">Type a keyword above to search indexed files</span>
        <span id="results-meta"></span>
      </div>

      <!-- Results Grid -->
      <div id="results-container" class="space-y-2.5">
        <!-- Results injected here -->
      </div>
    </section>

    <!-- TAB 2: LIVE SQL PLAYGROUND -->
    <section id="tab-content-sql" class="hidden space-y-4">
      <div class="bg-slate-900/80 border border-slate-800 rounded-2xl p-5 space-y-4 shadow-xl">
        <div class="flex items-center justify-between">
          <div>
            <h2 class="font-bold text-white text-base">Direct SQLite Read-Only Playground</h2>
            <p class="text-xs text-slate-400">Query tables: <code class="text-indigo-400 font-mono">indexed_files</code>, <code class="text-indigo-400 font-mono">indexed_files_fts</code></p>
          </div>
          <button onclick="executeSQL()" class="bg-indigo-600 hover:bg-indigo-500 text-white font-medium px-4 py-1.5 rounded-lg text-xs transition flex items-center gap-1.5 shadow">
            ▶ Run Query (Ctrl+Enter)
          </button>
        </div>

        <!-- Query Presets -->
        <div class="flex flex-wrap items-center gap-2 text-xs">
          <span class="text-slate-500">Presets:</span>
          <button onclick="setSQLPreset(1)" class="bg-slate-950 hover:bg-slate-800 text-slate-300 px-2.5 py-1 rounded-md border border-slate-800 transition">
            Top 10 Largest Files
          </button>
          <button onclick="setSQLPreset(2)" class="bg-slate-950 hover:bg-slate-800 text-slate-300 px-2.5 py-1 rounded-md border border-slate-800 transition">
            Total Size by Category
          </button>
          <button onclick="setSQLPreset(3)" class="bg-slate-950 hover:bg-slate-800 text-slate-300 px-2.5 py-1 rounded-md border border-slate-800 transition">
            All Videos Ordered by Size
          </button>
          <button onclick="setSQLPreset(4)" class="bg-slate-950 hover:bg-slate-800 text-slate-300 px-2.5 py-1 rounded-md border border-slate-800 transition">
            FTS5 Full-Text Match
          </button>
        </div>

        <!-- Query Editor Textarea -->
        <div class="relative">
          <textarea 
            id="sql-input" 
            rows="4" 
            class="w-full bg-slate-950 border border-slate-700 rounded-xl p-3 font-mono text-sm text-emerald-400 focus:outline-none focus:ring-2 focus:ring-indigo-500 shadow-inner"
            placeholder="SELECT file_name, file_type, file_size_bytes FROM indexed_files LIMIT 20;"
            onkeydown="if((event.ctrlKey || event.metaKey) && event.key === 'Enter') executeSQL()"
          >SELECT file_name, file_type, file_size_bytes, file_url FROM indexed_files ORDER BY file_size_bytes DESC LIMIT 20;</textarea>
        </div>

        <div id="sql-error" class="hidden p-3 rounded-xl bg-red-500/10 border border-red-500/30 text-red-400 text-xs font-mono"></div>

        <!-- SQL Results Table -->
        <div id="sql-results-wrapper" class="hidden border border-slate-800 rounded-xl overflow-hidden bg-slate-950">
          <div class="px-4 py-2 bg-slate-900 border-b border-slate-800 flex justify-between items-center text-xs text-slate-400 font-mono">
            <span id="sql-meta">0 rows returned</span>
          </div>
          <div class="overflow-x-auto max-h-96">
            <table class="w-full text-left text-xs font-mono">
              <thead id="sql-thead" class="bg-slate-900/80 text-slate-400 border-b border-slate-800 sticky top-0"></thead>
              <tbody id="sql-tbody" class="divide-y divide-slate-800/60 text-slate-300"></tbody>
            </table>
          </div>
        </div>
      </div>
    </section>

    <!-- TAB 3: SEED & CRAWLER PLAYGROUND -->
    <section id="tab-content-crawl" class="hidden space-y-4">
      <div class="bg-slate-900/80 border border-slate-800 rounded-2xl p-5 space-y-5 shadow-xl">
        <div>
          <h2 class="font-bold text-white text-base">Trigger New Open-Directory Crawl</h2>
          <p class="text-xs text-slate-400">Provide any public open directory URL to index files asynchronously in the background.</p>
        </div>

        <div class="space-y-3">
          <label class="text-xs text-slate-300 font-medium block">Seed Open Directory URL:</label>
          <input 
            type="url" 
            id="crawl-url-input" 
            placeholder="https://example.com/pub/" 
            class="w-full bg-slate-950 border border-slate-700 rounded-xl px-4 py-2.5 text-white placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 text-sm"
          />

          <!-- Quick Presets -->
          <div class="flex flex-wrap items-center gap-2 text-xs">
            <span class="text-slate-500">Live Samples:</span>
            <button onclick="setCrawlPreset('https://download.blender.org/demo/movies/')" class="bg-slate-950 hover:bg-slate-800 text-slate-300 px-2.5 py-1 rounded-md border border-slate-800 transition">
              Blender Movies Open Directory
            </button>
            <button onclick="setCrawlPreset('https://ftp.gnu.org/gnu/which/')" class="bg-slate-950 hover:bg-slate-800 text-slate-300 px-2.5 py-1 rounded-md border border-slate-800 transition">
              GNU FTP Which Releases
            </button>
          </div>

          <div class="pt-2">
            <button onclick="triggerCrawl()" class="bg-indigo-600 hover:bg-indigo-500 text-white font-medium px-5 py-2 rounded-xl text-sm transition shadow-md shadow-indigo-600/30 flex items-center gap-2">
              🚀 Start Crawl Job
            </button>
          </div>
        </div>

        <div id="crawl-status" class="hidden p-4 rounded-xl bg-slate-950 border border-slate-800 text-xs font-mono space-y-1">
          <div class="text-indigo-400 font-semibold flex items-center gap-2">
            <span class="w-2 h-2 rounded-full bg-indigo-400 animate-ping"></span>
            Crawl status: <span id="crawl-status-text">Pending</span>
          </div>
          <div class="text-slate-400" id="crawl-details"></div>
        </div>
      </div>
    </section>

  </main>

  <!-- Video Preview Modal -->
  <div id="video-modal" style="display: none;" onclick="if(event.target === this) closeVideoModal()" class="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm items-center justify-center p-4">
    <div class="bg-slate-900 border border-slate-800 rounded-2xl max-w-3xl w-full p-4 space-y-3 shadow-2xl">
      <div class="flex items-center justify-between">
        <h3 id="modal-video-title" class="text-sm font-semibold text-white truncate max-w-xl">Video Player</h3>
        <button onclick="closeVideoModal()" class="text-slate-400 hover:text-white p-1 text-lg">✕</button>
      </div>
      <div class="bg-black rounded-xl overflow-hidden aspect-video flex items-center justify-center">
        <video id="modal-video-player" controls autoplay class="w-full h-full"></video>
      </div>
      <div class="flex justify-between items-center text-xs text-slate-400 pt-1">
        <span id="modal-video-size"></span>
        <a id="modal-video-download" href="#" target="_blank" class="text-indigo-400 hover:underline">Open Raw File ↗</a>
      </div>
    </div>
  </div>

  <script>
    let activeCategory = null;
    let searchDebounceTimer = null;

    function formatBytes(bytes) {
      if (bytes === null || bytes === undefined || isNaN(bytes)) return "Size unknown";
      if (bytes === 0) return "0 B";
      const k = 1024;
      const sizes = ["B", "KB", "MB", "GB", "TB"];
      const i = Math.floor(Math.log(bytes) / Math.log(k));
      return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + " " + sizes[i];
    }

    function switchTab(tabId) {
      document.querySelectorAll("[id^='tab-btn-']").forEach(btn => {
        btn.className = "text-slate-400 hover:text-slate-200 py-2.5 px-1 flex items-center gap-2 transition";
      });
      document.querySelectorAll("[id^='tab-content-']").forEach(content => {
        content.classList.add("hidden");
      });

      document.getElementById("tab-btn-" + tabId).className = "tab-active py-2.5 px-1 flex items-center gap-2 transition";
      document.getElementById("tab-content-" + tabId).classList.remove("hidden");
    }

    async function fetchStats() {
      try {
        const res = await fetch("/stats");
        if (!res.ok) return;
        const data = await res.json();
        document.getElementById("stat-total").textContent = data.total_files.toLocaleString();
        document.getElementById("stat-video").textContent = (data.by_type.Video || 0).toLocaleString();
        document.getElementById("stat-archive").textContent = (data.by_type.Archive || 0).toLocaleString();
        document.getElementById("stat-document").textContent = (data.by_type.Document || 0).toLocaleString();
        document.getElementById("stat-audio").textContent = (data.by_type.Audio || 0).toLocaleString();
        document.getElementById("stat-fts").textContent = data.fts_enabled ? "Active (FTS5)" : "Active (LIKE)";
      } catch (err) {
        console.error("Failed to fetch stats:", err);
      }
    }

    function setCategoryFilter(cat) {
      activeCategory = cat;
      document.querySelectorAll("#category-filters .cat-pill").forEach(btn => {
        const btnCat = btn.getAttribute("data-cat");
        if ((cat === null && btnCat === "all") || (cat === btnCat)) {
          btn.className = "cat-pill bg-indigo-600 text-white font-medium px-3 py-1.5 rounded-lg border border-indigo-500 transition";
        } else {
          btn.className = "cat-pill bg-slate-950 hover:bg-slate-800 text-slate-300 px-3 py-1.5 rounded-lg border border-slate-800 transition";
        }
      });
      executeSearch();
    }

    function handleSearchInput() {
      clearTimeout(searchDebounceTimer);
      searchDebounceTimer = setTimeout(executeSearch, 300);
    }

    async function executeSearch() {
      const query = document.getElementById("search-input").value.trim();
      const container = document.getElementById("results-container");
      const countEl = document.getElementById("results-count");
      const metaEl = document.getElementById("results-meta");
      const limit = document.getElementById("search-limit").value;

      if (!query) {
        container.innerHTML = `
          <div class="text-center py-12 text-slate-500 text-sm">
            Enter a search term above (e.g. <span class="text-indigo-400 cursor-pointer" onclick="setQuery('sintel')">sintel</span>, <span class="text-indigo-400 cursor-pointer" onclick="setQuery('avi')">avi</span>, <span class="text-indigo-400 cursor-pointer" onclick="setQuery('which')">which</span>)
          </div>
        `;
        countEl.textContent = "Awaiting query...";
        metaEl.textContent = "";
        return;
      }

      countEl.textContent = "Searching...";
      const startTime = performance.now();

      let url = `/search?q=${encodeURIComponent(query)}&limit=${limit}`;
      if (activeCategory) {
        url += `&type=${encodeURIComponent(activeCategory)}`;
      }

      try {
        const res = await fetch(url);
        const data = await res.json();
        const elapsed = (performance.now() - startTime).toFixed(1);

        if (!res.ok) {
          container.innerHTML = `<div class="p-4 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-xs">${data.detail || 'Search error'}</div>`;
          countEl.textContent = "Error";
          return;
        }

        countEl.textContent = `Found ${data.count} result${data.count === 1 ? '' : 's'} for "${query}"`;
        metaEl.textContent = `${elapsed} ms`;

        if (data.results.length === 0) {
          container.innerHTML = `
            <div class="text-center py-12 text-slate-500 text-sm bg-slate-900/30 rounded-xl border border-slate-800/50">
              No files matched your query. Try a different keyword or category.
            </div>
          `;
          return;
        }

        container.innerHTML = data.results.map(f => {
          let badgeClass = "badge-doc";
          let icon = "📄";
          if (f.file_type === "Video") { badgeClass = "badge-video"; icon = "🎥"; }
          else if (f.file_type === "Audio") { badgeClass = "badge-audio"; icon = "🎵"; }
          else if (f.file_type === "Archive") { badgeClass = "badge-archive"; icon = "📦"; }
          else if (f.file_type === "Executable") { badgeClass = "badge-exe"; icon = "⚙️"; }

          const isPlayableVideo = f.file_type === "Video" && (f.file_name.endsWith(".mp4") || f.file_name.endsWith(".webm") || f.file_name.endsWith(".mov") || f.file_name.endsWith(".mkv"));

          return `
            <div class="bg-slate-900/50 hover:bg-slate-900 border border-slate-800 hover:border-slate-700 rounded-xl p-3.5 transition flex items-center justify-between gap-4">
              <div class="flex items-center gap-3 min-w-0 flex-1">
                <span class="text-xl shrink-0">${icon}</span>
                <div class="min-w-0 flex-1">
                  <div class="flex items-center gap-2 flex-wrap">
                    <a href="${f.file_url}" target="_blank" class="text-sm font-medium text-white hover:text-indigo-400 transition truncate">
                      ${f.file_name}
                    </a>
                    <span class="text-[10px] font-semibold px-2 py-0.5 rounded-md ${badgeClass}">
                      ${f.file_type}
                    </span>
                    <span class="text-xs text-slate-400 font-mono">
                      ${formatBytes(f.file_size_bytes)}
                    </span>
                  </div>
                  <div class="text-[11px] text-slate-500 truncate font-mono mt-0.5">
                    ${f.file_url}
                  </div>
                </div>
              </div>
              <div class="flex items-center gap-2 shrink-0">
                ${isPlayableVideo ? `
                  <button onclick="openVideoModal('${encodeURIComponent(f.file_url)}', '${encodeURIComponent(f.file_name)}', '${formatBytes(f.file_size_bytes)}')" class="bg-indigo-600/20 hover:bg-indigo-600/30 text-indigo-300 text-xs px-2.5 py-1.5 rounded-lg border border-indigo-500/30 transition flex items-center gap-1">
                    ▶ Play
                  </button>
                ` : ''}
                <button onclick="copyToClipboard('${f.file_url}')" class="bg-slate-950 hover:bg-slate-800 text-slate-400 hover:text-slate-200 text-xs px-2.5 py-1.5 rounded-lg border border-slate-800 transition">
                  📋 Copy
                </button>
                <a href="${f.file_url}" target="_blank" download class="bg-slate-950 hover:bg-slate-800 text-slate-400 hover:text-slate-200 text-xs px-2.5 py-1.5 rounded-lg border border-slate-800 transition">
                  ⬇ Download
                </a>
              </div>
            </div>
          `;
        }).join("");

      } catch (err) {
        container.innerHTML = `<div class="p-4 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-xs">Network error connecting to API</div>`;
      }
    }

    function setQuery(q) {
      document.getElementById("search-input").value = q;
      executeSearch();
    }

    async function copyToClipboard(text) {
      try {
        if (navigator.clipboard && navigator.clipboard.writeText) {
          await navigator.clipboard.writeText(text);
        } else {
          const ta = document.createElement("textarea");
          ta.value = text;
          document.body.appendChild(ta);
          ta.select();
          document.execCommand("copy");
          document.body.removeChild(ta);
        }
        alert("URL copied to clipboard:\\n" + text);
      } catch (err) {
        prompt("Copy this URL:", text);
      }
    }

    function openVideoModal(urlEnc, nameEnc, sizeStr) {
      const url = decodeURIComponent(urlEnc);
      const name = decodeURIComponent(nameEnc);
      document.getElementById("modal-video-title").textContent = name;
      document.getElementById("modal-video-size").textContent = sizeStr;
      document.getElementById("modal-video-download").href = url;
      const player = document.getElementById("modal-video-player");
      player.src = url;
      document.getElementById("video-modal").style.display = "flex";
    }

    function closeVideoModal() {
      const player = document.getElementById("modal-video-player");
      player.pause();
      player.src = "";
      document.getElementById("video-modal").style.display = "none";
    }

    // SQL Playground Execution
    function setSQLPreset(id) {
      const input = document.getElementById("sql-input");
      if (id === 1) {
        input.value = "SELECT file_name, file_type, file_size_bytes, file_url FROM indexed_files ORDER BY file_size_bytes DESC LIMIT 10;";
      } else if (id === 2) {
        input.value = "SELECT file_type, COUNT(*) AS count, SUM(file_size_bytes) AS total_bytes FROM indexed_files GROUP BY file_type ORDER BY count DESC;";
      } else if (id === 3) {
        input.value = "SELECT file_name, file_size_bytes, file_url FROM indexed_files WHERE file_type = 'Video' ORDER BY file_size_bytes DESC LIMIT 20;";
      } else if (id === 4) {
        input.value = "SELECT i.file_name, i.file_type, i.file_size_bytes FROM indexed_files_fts AS f JOIN indexed_files AS i ON i.id = f.rowid WHERE indexed_files_fts MATCH 'sintel*' LIMIT 10;";
      }
      executeSQL();
    }

    async function executeSQL() {
      const query = document.getElementById("sql-input").value.trim();
      const errEl = document.getElementById("sql-error");
      const wrapperEl = document.getElementById("sql-results-wrapper");
      const thead = document.getElementById("sql-thead");
      const tbody = document.getElementById("sql-tbody");
      const meta = document.getElementById("sql-meta");

      errEl.classList.add("hidden");
      wrapperEl.classList.add("hidden");

      if (!query) return;

      const startTime = performance.now();

      try {
        const res = await fetch("/api/sql", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ query: query, limit: 100 })
        });
        const data = await res.json();
        const elapsed = (performance.now() - startTime).toFixed(1);

        if (!res.ok) {
          errEl.textContent = data.detail || "Query error";
          errEl.classList.remove("hidden");
          return;
        }

        meta.textContent = `${data.count} row${data.count === 1 ? '' : 's'} returned in ${elapsed} ms`;
        thead.innerHTML = "<tr>" + data.columns.map(c => `<th class="px-4 py-2.5">${c}</th>`).join("") + "</tr>";
        tbody.innerHTML = data.rows.map(r => {
          return "<tr>" + r.map(val => `<td class="px-4 py-2 truncate max-w-xs">${val === null ? '<span class="text-slate-600">null</span>' : val}</td>`).join("") + "</tr>";
        }).join("");

        wrapperEl.classList.remove("hidden");
      } catch (err) {
        errEl.textContent = "Network error executing query: " + err;
        errEl.classList.remove("hidden");
      }
    }

    // Crawl Playground
    function setCrawlPreset(url) {
      document.getElementById("crawl-url-input").value = url;
    }

    async function triggerCrawl() {
      const url = document.getElementById("crawl-url-input").value.trim();
      if (!url) {
        alert("Please enter an open directory URL.");
        return;
      }

      const statusEl = document.getElementById("crawl-status");
      const statusText = document.getElementById("crawl-status-text");
      const details = document.getElementById("crawl-details");

      statusEl.classList.remove("hidden");
      statusText.textContent = "Crawl started...";
      details.textContent = `Connecting to ${url} and crawling links in background...`;

      try {
        const res = await fetch("/api/crawl", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ seed_url: url, max_depth: 1 })
        });
        const data = await res.json();
        statusText.textContent = "Crawling in progress";
        details.textContent = `Background crawler dispatched for: ${data.seed_url}. Refresh stats in a few seconds!`;
        setTimeout(fetchStats, 3000);
      } catch (err) {
        statusText.textContent = "Error";
        details.textContent = "Failed to dispatch crawl: " + err;
      }
    }

    // Initialize
    fetchStats();
    executeSearch();
  </script>
</body>
</html>
"""
