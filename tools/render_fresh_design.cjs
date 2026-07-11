const fs = require('fs');
const path = require('path');
const { pathToFileURL } = require('url');
const { chromium } = require('playwright-core');

const root = path.resolve(__dirname, '..');
const sourceDir = path.join(root, 'docs', 'design', 'fresh-redesign');
const outputDir = path.join(sourceDir, 'rendered');
const chromeCandidates = [
  process.env.CHROME_PATH,
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
].filter(Boolean);

const executablePath = chromeCandidates.find((candidate) =>
  fs.existsSync(candidate),
);

if (!executablePath) {
  throw new Error(
    '未找到 Chrome/Edge。请设置 CHROME_PATH 后重新运行清新风画板渲染脚本。',
  );
}

const boardFiles = fs
  .readdirSync(sourceDir)
  .filter((name) => /^board-\d{2}\.html$/.test(name))
  .sort();

if (boardFiles.length !== 1) {
  throw new Error(`清新风方向稿应为 1 张，当前找到 ${boardFiles.length} 张。`);
}

const renderFiles = [...boardFiles, 'index.html'];

fs.mkdirSync(outputDir, { recursive: true });

(async () => {
  const browser = await chromium.launch({
    executablePath,
    headless: true,
  });

  try {
    const page = await browser.newPage({
      viewport: { width: 1450, height: 900 },
      deviceScaleFactor: 1,
      colorScheme: 'light',
    });

    for (const fileName of renderFiles) {
      const sourcePath = path.join(sourceDir, fileName);
      const outputPath = path.join(
        outputDir,
        fileName === 'index.html'
          ? 'comparison.png'
          : fileName.replace(/\.html$/, '.png'),
      );

      await page.goto(pathToFileURL(sourcePath).href, {
        waitUntil: 'networkidle',
      });
      await page.evaluate(() => document.fonts.ready);
      await page.screenshot({
        path: outputPath,
        fullPage: true,
        animations: 'disabled',
      });
      process.stdout.write(`${fileName} -> ${outputPath}\n`);
    }
  } finally {
    await browser.close();
  }
})().catch((error) => {
  process.stderr.write(`${error.stack || error}\n`);
  process.exitCode = 1;
});
