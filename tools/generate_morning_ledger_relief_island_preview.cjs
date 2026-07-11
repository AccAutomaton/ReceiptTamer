const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const sourceDir = path.join(
  root,
  'docs',
  'design',
  'morning-ledger-mid-bold-preview',
);
const targetDir = path.join(
  root,
  'docs',
  'design',
  'morning-ledger-relief-island-preview',
);

const files = [
  'board-01.html',
  'board-02.html',
  'board-03.html',
  'board-04.html',
  'compact-check.html',
];

const metadata = {
  'board-01.html': {
    title: '晨雾浮签 · 01 日常主壳',
    kicker: 'EXPLORATION · RELIEF ISLAND',
    heading: '01 · 日常主壳',
    note:
      '<b>内容仍完全来自 ce04b3c。</b> 页面不再被一张大卡包住：统计、快捷功能与最近订单各自形成实体层；搜索、筛选和底部导航才使用高不透明雾化悬浮材质。',
  },
  'board-02.html': {
    title: '晨雾浮签 · 02 详情与编辑',
    kicker: 'EXPLORATION · RELIEF ISLAND',
    heading: '02 · 详情与编辑',
    note:
      '<b>立体感只服务可操作区域。</b> 图片、金额、字段与关联记录按原顺序自然分层；返回、编辑、删除、输入控件和主按钮拥有明确压感，不新增任何业务分组。',
  },
  'board-03.html': {
    title: '晨雾浮签 · 03 操作与层级',
    kicker: 'EXPLORATION · RELIEF ISLAND',
    heading: '03 · 操作与层级',
    note:
      '<b>浮层使用 94% 实色与 12px 模糊。</b> 中央新增、筛选和导出继续保留 ce04b3c 的原选项；遮罩不做全屏模糊，浮层文字始终完全锐利。',
  },
  'board-04.html': {
    title: '晨雾浮签 · 04 边界状态',
    kicker: 'EXPLORATION · RELIEF ISLAND',
    heading: '04 · 边界状态',
    note:
      '<b>暗色与危险状态共用同一材质逻辑。</b> 关于仍是“关于”，订单字段和删除确认文案完全不变；暗色浮岛保持深色实底，不泛白成灰雾。',
  },
  'compact-check.html': {
    title: '晨雾浮签 · 360×800 紧凑检查',
    kicker: 'EXPLORATION · RELIEF ISLAND · 360×800',
    heading: '悬浮岛紧凑检查',
    note:
      '360×800 仍保留完整五栏与原两项新增面板；导航岛左右 12px、底部 10px，内容从岛后延续但不被遮挡。',
  },
};

function phoneSnapshots(html) {
  return [...html.matchAll(/<article class="phone-card">([\s\S]*?)<\/article>/g)].map(
    (match) => {
      const article = match[1];
      const phoneOnly = article.split('<div class="phone-label">')[0];
      return phoneOnly.replace(/\r\n/g, '\n').trim();
    },
  );
}

function replaceRequired(html, pattern, replacement, fileName, label) {
  if (!pattern.test(html)) {
    throw new Error(`${fileName} 未找到 ${label}`);
  }
  return html.replace(pattern, replacement);
}

fs.mkdirSync(targetDir, { recursive: true });

for (const fileName of files) {
  const sourcePath = path.join(sourceDir, fileName);
  const targetPath = path.join(targetDir, fileName);
  const source = fs.readFileSync(sourcePath, 'utf8');
  const meta = metadata[fileName];
  let html = source;

  html = replaceRequired(
    html,
    /<html lang="zh-CN"(?:[^>]*)>/,
    '<html lang="zh-CN" data-preview-theme="relief-island">',
    fileName,
    'html 根节点',
  );
  html = replaceRequired(
    html,
    /<title>[\s\S]*?<\/title>/,
    `<title>${meta.title}</title>`,
    fileName,
    'title',
  );
  html = replaceRequired(
    html,
    /<\/head>/,
    '    <link rel="stylesheet" href="relief-island.css" />\n  </head>',
    fileName,
    'head 结束标签',
  );
  html = replaceRequired(
    html,
    /<body>/,
    `<body class="${fileName.replace('.html', '')}">`,
    fileName,
    'body',
  );
  html = replaceRequired(
    html,
    /<div class="board-kicker">[\s\S]*?<\/div>/,
    `<div class="board-kicker">${meta.kicker}</div>`,
    fileName,
    'board kicker',
  );
  html = replaceRequired(
    html,
    /<h1 class="board-title">[\s\S]*?<\/h1>/,
    `<h1 class="board-title">${meta.heading}</h1>`,
    fileName,
    'board title',
  );
  html = replaceRequired(
    html,
    /<p class="board-note">[\s\S]*?<\/p>/,
    `<p class="board-note">${meta.note}</p>`,
    fileName,
    'board note',
  );

  html = html
    .replace('首页 · 连续归档页', '首页 · 分层实体模块')
    .replace('订单 · 连续月份组', '订单 · 月份实体模块');

  const beforePhones = phoneSnapshots(source);
  const afterPhones = phoneSnapshots(html);
  if (
    beforePhones.length !== afterPhones.length ||
    beforePhones.some((snapshot, index) => snapshot !== afterPhones[index])
  ) {
    throw new Error(`${fileName} 的手机框 DOM 发生变化`);
  }

  fs.writeFileSync(targetPath, html, 'utf8');
  process.stdout.write(`${fileName} -> ${targetPath}\n`);
}

for (const asset of ['shared.css', 'icons.svg']) {
  fs.copyFileSync(path.join(sourceDir, asset), path.join(targetDir, asset));
}
