const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const sourceDir = path.join(root, 'docs', 'design', 'ledger-redesign');
const targetDir = path.join(root, 'docs', 'design', 'hybrid-redesign');

const boardFiles = fs
  .readdirSync(sourceDir)
  .filter((name) => /^board-\d{2}\.html$/.test(name))
  .sort();

if (boardFiles.length !== 10) {
  throw new Error(`应从墨色账簿读取 10 张画板，当前找到 ${boardFiles.length} 张。`);
}

const sourceFiles = [...boardFiles, 'compact-check.html'];
fs.mkdirSync(targetDir, { recursive: true });

let boardPhoneTotal = 0;
let boardDarkTotal = 0;

for (const fileName of sourceFiles) {
  const sourcePath = path.join(sourceDir, fileName);
  const targetPath = path.join(targetDir, fileName);
  const sourceHtml = fs.readFileSync(sourcePath, 'utf8');
  const sourcePhoneCount = (sourceHtml.match(/class="phone(?:\s|\")/g) || [])
    .length;
  const sourceDarkCount = (sourceHtml.match(/class="phone dark"/g) || []).length;
  let html = sourceHtml;

  html = html.replace('<html lang="zh-CN">', '<html lang="zh-CN" data-preview-theme="fresh-dense">');
  html = html.replace(
    'href="shared.css"',
    'href="../ledger-redesign/shared.css"',
  );
  html = html.replace(
    '</head>',
    '    <link rel="stylesheet" href="hybrid.css" />\n  </head>',
  );
  html = html.replace(
    /(<title>[^<]*)墨色账簿([^<]*<\/title>)/,
    '$1晨雾账簿$2',
  );
  html = html.replace(
    /<small>(待关联|待开票|未关联|未开票|失败|部分失败)<\/small>/g,
    '<small class="text-seal">$1</small>',
  );
  html = html.replace(
    /<small>(已关联|已开票|已配齐|已完成|已保存)<\/small>/g,
    '<small class="text-teal">$1</small>',
  );

  const targetPhoneCount = (html.match(/class="phone(?:\s|\")/g) || []).length;
  const targetDarkCount = (html.match(/class="phone dark"/g) || []).length;
  if (targetPhoneCount !== sourcePhoneCount || targetDarkCount !== sourceDarkCount) {
    throw new Error(`${fileName} 的手机框或暗色状态数量发生变化。`);
  }
  if (!html.includes('href="hybrid.css"')) {
    throw new Error(`${fileName} 未正确插入晨雾账簿覆盖样式。`);
  }

  const sourceBody = sourceHtml.match(/<body[^>]*>([\s\S]*)<\/body>/)?.[1];
  const targetBody = html.match(/<body[^>]*>([\s\S]*)<\/body>/)?.[1];
  const visibleText = (body) =>
    body.replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim();
  if (!sourceBody || !targetBody || visibleText(sourceBody) !== visibleText(targetBody)) {
    throw new Error(`${fileName} 的可见正文发生变化。`);
  }

  if (/^board-\d{2}\.html$/.test(fileName)) {
    boardPhoneTotal += targetPhoneCount;
    boardDarkTotal += targetDarkCount;
  }

  fs.writeFileSync(targetPath, html, 'utf8');
  process.stdout.write(`${fileName} -> ${targetPath}\n`);
}

if (boardPhoneTotal !== 60 || boardDarkTotal !== 12) {
  throw new Error(
    `完整画板应保留 60 个手机框与 12 个暗色状态，当前为 ${boardPhoneTotal} / ${boardDarkTotal}。`,
  );
}
