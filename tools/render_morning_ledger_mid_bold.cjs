const fs = require('fs');
const path = require('path');
const { pathToFileURL } = require('url');
const { chromium } = require('playwright-core');

const root = path.resolve(__dirname, '..');
const sourceDir = path.join(
  root,
  'docs',
  'design',
  'morning-ledger-mid-bold-preview',
);
const outputDir = path.join(sourceDir, 'rendered');

const boardFiles = [
  'board-01.html',
  'board-02.html',
  'board-03.html',
  'board-04.html',
];
const compactFile = 'compact-check.html';
const indexFile = 'index.html';
const requiredFiles = [...boardFiles, compactFile, indexFile];

const chromeCandidates = [
  process.env.CHROME_PATH,
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
  'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
].filter(Boolean);

function assertSourceContract() {
  if (!fs.existsSync(sourceDir)) {
    throw new Error(`预览目录不存在: ${sourceDir}`);
  }

  const missingFiles = requiredFiles.filter(
    (fileName) => !fs.existsSync(path.join(sourceDir, fileName)),
  );
  if (missingFiles.length > 0) {
    throw new Error(`预览源文件缺失: ${missingFiles.join(', ')}`);
  }

  const discoveredBoards = fs
    .readdirSync(sourceDir)
    .filter((name) => /^board-\d{2}\.html$/.test(name))
    .sort();
  if (
    discoveredBoards.length !== boardFiles.length ||
    discoveredBoards.some((name, index) => name !== boardFiles[index])
  ) {
    throw new Error(
      `画板契约不匹配，应为 ${boardFiles.join(', ')}，实际为 ${
        discoveredBoards.length > 0 ? discoveredBoards.join(', ') : '(无)'
      }。`,
    );
  }
}

function findBrowserExecutable() {
  const executablePath = chromeCandidates.find((candidate) =>
    fs.existsSync(candidate),
  );
  if (!executablePath) {
    throw new Error(
      '未找到 Chrome/Edge。请安装本机浏览器或通过 CHROME_PATH 指定可执行文件。',
    );
  }
  return executablePath;
}

function formatConsoleError(message) {
  const location = message.location();
  const suffix = location.url
    ? ` (${location.url}${location.lineNumber ? `:${location.lineNumber}` : ''})`
    : '';
  return `${message.text()}${suffix}`;
}

async function validatePage(page, fileName) {
  const phoneCount = await page.locator('.phone').count();
  if (boardFiles.includes(fileName) && phoneCount !== 3) {
    throw new Error(`${fileName} 应包含 3 个 .phone，实际为 ${phoneCount}。`);
  }
  if (fileName === compactFile && phoneCount !== 3) {
    throw new Error(
      `${compactFile} 应包含 3 个 .phone，实际为 ${phoneCount}。`,
    );
  }

  if (fileName === 'board-04.html') {
    const darkCount = await page.locator('.dark').count();
    const dangerCount = await page.locator('.danger-preview').count();
    if (darkCount === 0) {
      throw new Error('board-04.html 必须包含至少一个 .dark 状态。');
    }
    if (dangerCount === 0) {
      throw new Error('board-04.html 必须包含至少一个 .danger-preview 状态。');
    }
  }

  const brokenImages = await page.locator('img').evaluateAll((images) =>
    images
      .filter((image) => !image.complete || image.naturalWidth === 0)
      .map((image) => image.currentSrc || image.src || '(无 src)'),
  );
  if (brokenImages.length > 0) {
    throw new Error(
      `${fileName} 存在加载失败的图片: ${brokenImages.join(', ')}`,
    );
  }
}

function assertNoRuntimeErrors(fileName, pageErrors, consoleErrors) {
  if (pageErrors.length === 0 && consoleErrors.length === 0) return;

  const details = [
    ...pageErrors.map((error) => `pageerror: ${error}`),
    ...consoleErrors.map((error) => `console.error: ${error}`),
  ];
  throw new Error(`${fileName} 页面运行异常:\n${details.join('\n')}`);
}

async function renderFile(page, fileName, outputName) {
  const pageErrors = [];
  const consoleErrors = [];
  const onPageError = (error) => {
    pageErrors.push(error.stack || error.message || String(error));
  };
  const onConsole = (message) => {
    if (message.type() === 'error') {
      consoleErrors.push(formatConsoleError(message));
    }
  };

  page.on('pageerror', onPageError);
  page.on('console', onConsole);

  try {
    const sourcePath = path.join(sourceDir, fileName);
    const outputPath = path.join(outputDir, outputName);

    await page.goto(pathToFileURL(sourcePath).href, {
      waitUntil: 'networkidle',
    });
    await page.evaluate(() => document.fonts.ready);
    await validatePage(page, fileName);
    assertNoRuntimeErrors(fileName, pageErrors, consoleErrors);

    await page.screenshot({
      path: outputPath,
      fullPage: true,
      animations: 'disabled',
    });
    assertNoRuntimeErrors(fileName, pageErrors, consoleErrors);
    process.stdout.write(`${fileName} -> ${outputPath}\n`);
  } catch (error) {
    throw new Error(
      `${fileName} 渲染失败: ${error.stack || error.message || error}`,
    );
  } finally {
    page.off('pageerror', onPageError);
    page.off('console', onConsole);
  }
}

async function main() {
  assertSourceContract();
  const executablePath = findBrowserExecutable();
  fs.mkdirSync(outputDir, { recursive: true });

  const browser = await chromium.launch({
    executablePath,
    headless: true,
    args: ['--allow-file-access-from-files'],
  });

  try {
    const page = await browser.newPage({
      viewport: { width: 1450, height: 900 },
      deviceScaleFactor: 1,
      colorScheme: 'light',
      reducedMotion: 'reduce',
    });

    for (const boardFile of boardFiles) {
      await renderFile(
        page,
        boardFile,
        boardFile.replace(/\.html$/, '.png'),
      );
    }
    await renderFile(page, compactFile, 'compact-check.png');
    await renderFile(page, indexFile, 'overview.png');
  } finally {
    await browser.close();
  }
}

main().catch((error) => {
  process.stderr.write(`${error.stack || error}\n`);
  process.exitCode = 1;
});
