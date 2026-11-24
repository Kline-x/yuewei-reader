/// 局域网 Wi-Fi 传书响应式网页模板（Modern Soft UI 风格，纯内联零外链依赖）
const String kWifiTransferHtml = r'''<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>阅微 · 局域网无线传书</title>
<style>
  :root {
    --bg: #F6F4EF;
    --card: rgba(255, 255, 255, 0.92);
    --surface: #EFECE4;
    --text: #1B2421;
    --sub: #5E6A65;
    --accent: #1F5E50;
    --accent-soft: rgba(31, 94, 80, 0.10);
    --border: rgba(27, 36, 33, 0.08);
    --ok: #1E7A55;
    --err: #B8423B;
    --shadow: 0 18px 44px rgba(24, 34, 30, 0.08);
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #121615;
      --card: rgba(26, 32, 30, 0.92);
      --surface: #222A27;
      --text: #ECF1EE;
      --sub: #9AA7A1;
      --accent: #55B39B;
      --accent-soft: rgba(85, 179, 155, 0.14);
      --border: rgba(255, 255, 255, 0.08);
      --ok: #59C191;
      --err: #E06D66;
      --shadow: 0 20px 48px rgba(0, 0, 0, 0.42);
    }
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    min-height: 100vh;
    font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Noto Sans SC", sans-serif;
    background: radial-gradient(circle at top right, var(--accent-soft), transparent 48%), var(--bg);
    color: var(--text);
    display: flex;
    justify-content: center;
    padding: 28px 16px 48px;
  }
  .wrap { width: 100%; max-width: 680px; display: flex; flex-direction: column; gap: 18px; }
  .card {
    background: var(--card);
    border: 1px solid var(--border);
    border-radius: 24px;
    box-shadow: var(--shadow);
    padding: 24px;
  }
  .eyebrow { font-size: 11px; letter-spacing: 1.6px; font-weight: 700; color: var(--accent); }
  h1 { font-size: 24px; margin-top: 4px; font-weight: 700; }
  .subtitle { font-size: 13px; color: var(--sub); margin-top: 6px; line-height: 1.5; }
  .status-pill {
    display: inline-flex; align-items: center; gap: 6px; margin-top: 12px;
    padding: 5px 12px; border-radius: 999px; background: var(--accent-soft);
    color: var(--accent); font-size: 12px; font-weight: 600;
  }
  .dropzone {
    margin-top: 18px; border: 2px dashed var(--accent); border-radius: 20px;
    background: var(--accent-soft); padding: 34px 18px; text-align: center;
    cursor: pointer; transition: transform .16s ease, background .16s ease;
  }
  .dropzone.active { transform: scale(0.99); background: rgba(31, 94, 80, 0.18); }
  .drop-title { font-size: 16px; font-weight: 600; }
  .drop-hint { font-size: 12px; color: var(--sub); margin-top: 6px; }
  .btn {
    display: inline-block; margin-top: 14px; padding: 10px 22px; border-radius: 999px;
    background: var(--accent); color: #fff; font-size: 13px; font-weight: 600; border: 0;
  }
  .list-title { font-size: 14px; font-weight: 700; margin-bottom: 10px; }
  .empty { font-size: 13px; color: var(--sub); text-align: center; padding: 14px 0; }
  .item {
    display: flex; flex-direction: column; gap: 6px; padding: 12px 14px;
    background: var(--surface); border-radius: 16px; margin-top: 8px;
  }
  .item-row { display: flex; justify-content: space-between; align-items: center; gap: 10px; }
  .item-name { font-size: 13px; font-weight: 600; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .badge { font-size: 12px; font-weight: 600; flex-shrink: 0; }
  .badge.ok { color: var(--ok); }
  .badge.err { color: var(--err); }
  .badge.wait { color: var(--accent); }
  .bar-bg { height: 5px; border-radius: 999px; background: var(--border); overflow: hidden; }
  .bar-fg { height: 100%; width: 0%; background: var(--accent); transition: width .12s ease; }
</style>
</head>
<body>
<div class="wrap">
  <section class="card">
    <div class="eyebrow">YUEWEI WIFI TRANSFER</div>
    <h1>阅微 · 局域网无线传书</h1>
    <p class="subtitle">保持手机与电脑处于同一 Wi-Fi，拖拽或选择文件即可直接入库书架或导入书源。</p>
    <div class="status-pill" id="statusPill">正在检测服务连接…</div>
    <div class="dropzone" id="dropzone">
      <div class="drop-title">拖拽书籍或书源到此处，或点击浏览文件</div>
      <div class="drop-hint">支持 .txt / .epub 电子书，以及 .json（Legado 书源规则），单文件上限 120MB</div>
      <button class="btn" type="button" id="pickBtn">选择本地文件</button>
      <input type="file" id="fileInput" multiple accept=".txt,.epub,.json" hidden />
    </div>
  </section>
  <section class="card">
    <div class="list-title">传输记录</div>
    <div id="list"><div class="empty">暂无传输任务，请选择文件开始发送</div></div>
  </section>
</div>
<script>
(function () {
  const dropzone = document.getElementById('dropzone');
  const fileInput = document.getElementById('fileInput');
  const pickBtn = document.getElementById('pickBtn');
  const listEl = document.getElementById('list');
  const statusPill = document.getElementById('statusPill');

  async function refreshStatus() {
    try {
      const res = await fetch('/api/status');
      const data = await res.json();
      statusPill.textContent = '已连接 · 端口 ' + data.port + ' · 本次已收 ' + data.receivedCount + ' 份';
    } catch (_) {
      statusPill.textContent = '连接状态异常，请确认手机传书面板仍开启';
    }
  }
  refreshStatus();

  pickBtn.addEventListener('click', (e) => { e.stopPropagation(); fileInput.click(); });
  dropzone.addEventListener('click', () => fileInput.click());
  dropzone.addEventListener('dragover', (e) => { e.preventDefault(); dropzone.classList.add('active'); });
  dropzone.addEventListener('dragleave', () => dropzone.classList.remove('active'));
  dropzone.addEventListener('drop', (e) => {
    e.preventDefault();
    dropzone.classList.remove('active');
    if (e.dataTransfer && e.dataTransfer.files) enqueueFiles(e.dataTransfer.files);
  });
  fileInput.addEventListener('change', () => {
    if (fileInput.files) enqueueFiles(fileInput.files);
    fileInput.value = '';
  });

  function enqueueFiles(files) {
    const empty = listEl.querySelector('.empty');
    if (empty) empty.remove();
    Array.from(files).forEach(uploadOne);
  }

  function uploadOne(file) {
    const item = document.createElement('div');
    item.className = 'item';
    item.innerHTML =
      '<div class="item-row">' +
      '<span class="item-name"></span>' +
      '<span class="badge wait">准备上传…</span>' +
      '</div>' +
      '<div class="bar-bg"><div class="bar-fg"></div></div>';
    item.querySelector('.item-name').textContent = file.name;
    const badge = item.querySelector('.badge');
    const bar = item.querySelector('.bar-fg');
    listEl.prepend(item);

    const xhr = new XMLHttpRequest();
    xhr.open('POST', '/api/upload?name=' + encodeURIComponent(file.name), true);
    xhr.upload.onprogress = (e) => {
      if (e.lengthComputable && e.total > 0) {
        const pct = Math.round((e.loaded / e.total) * 100);
        bar.style.width = pct + '%';
        badge.textContent = pct < 100 ? ('上传中 ' + pct + '%') : '正在解析入库…';
      }
    };
    xhr.onload = () => {
      bar.style.width = '100%';
      try {
        const resp = JSON.parse(xhr.responseText || '{}');
        if (xhr.status >= 200 && xhr.status < 300 && resp.ok) {
          badge.className = 'badge ok';
          badge.textContent = resp.kind === 'source'
            ? ('导入 ' + resp.count + ' 条书源')
            : ('已入架《' + resp.title + '》· ' + resp.chapters + ' 章');
          refreshStatus();
        } else {
          badge.className = 'badge err';
          badge.textContent = resp.error || ('失败 HTTP ' + xhr.status);
        }
      } catch (_) {
        badge.className = 'badge err';
        badge.textContent = '响应解析失败';
      }
    };
    xhr.onerror = () => {
      badge.className = 'badge err';
      badge.textContent = '网络传输中断';
    };
    xhr.send(file);
  }
})();
</script>
</body>
</html>
''';
