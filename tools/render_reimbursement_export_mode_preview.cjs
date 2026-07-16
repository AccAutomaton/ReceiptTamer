const fs = require('fs');
const path = require('path');
const { pathToFileURL } = require('url');
const { chromium } = require('playwright-core');

const root = path.resolve(__dirname, '..');
const sourceDir = path.join(root, 'docs', 'design', 'reimbursement-export-mode-preview');
const outputDir = path.join(sourceDir, 'rendered');
const executableCandidates = [
  process.env.CHROME_PATH,
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
].filter(Boolean);

async function main() {
  const executablePath = executableCandidates.find((candidate) => fs.existsSync(candidate));
  if (!executablePath) throw new Error('未找到 Chrome/Edge。');
  fs.mkdirSync(outputDir, { recursive: true });

  const browser = await chromium.launch({
    executablePath,
    headless: true,
    args: ['--allow-file-access-from-files', '--disable-gpu'],
  });
  const context = await browser.newContext({
    viewport: { width: 1420, height: 1050 },
    deviceScaleFactor: 1,
    colorScheme: 'light',
    reducedMotion: 'reduce',
  });
  const page = await context.newPage();

  try {
    const errors = [];
    page.on('pageerror', (error) => errors.push(error.stack || String(error)));
    page.on('console', (message) => {
      if (message.type() === 'error') errors.push(message.text());
    });
    await page.goto(pathToFileURL(path.join(sourceDir, 'index.html')).href, { waitUntil: 'networkidle' });
    await page.evaluate(() => document.fonts.ready);

    const metrics = await page.locator('.phone').evaluateAll((phones) => phones.map((phone) => {
      const rect = phone.getBoundingClientRect();
      const screen = phone.querySelector('.screen');
      const title = phone.querySelector('.appbar h2');
      const basis = phone.querySelector('.basis-tab');
      const menu = phone.querySelector('.basis-menu');
      const screenRect = screen.getBoundingClientRect();
      const basisRect = basis.getBoundingClientRect();
      const basisStyle = getComputedStyle(basis);
      const menuRect = menu?.getBoundingClientRect();
      return {
        width: rect.width,
        height: rect.height,
        overflow: screen.scrollWidth > screen.clientWidth,
        basisText: basis.textContent.trim(),
        basisBackground: basisStyle.backgroundColor,
        basisBorder: basisStyle.borderTopColor,
        basisColorMatchesTitle: basisStyle.color === getComputedStyle(title).color,
        basisCenterOffset: Math.abs(
          (basisRect.left + basisRect.right) / 2 -
          (screenRect.left + screenRect.right) / 2,
        ),
        menuOutside: menuRect
          ? menuRect.left < screenRect.left || menuRect.right > screenRect.right
          : false,
      };
    }));
    const expectedBasisLabels = ['按订单导出', '按订单导出', '按发票导出'];
    if (
      metrics.length !== 3 ||
      metrics.some(({
        width,
        height,
        overflow,
        basisBackground,
        basisBorder,
        basisColorMatchesTitle,
        basisCenterOffset,
        menuOutside,
      }, index) =>
        width !== 412 ||
        height !== 915 ||
        overflow ||
        metrics[index].basisText !== expectedBasisLabels[index] ||
        basisBackground !== 'rgba(0, 0, 0, 0)' ||
        basisBorder !== 'rgba(0, 0, 0, 0)' ||
        !basisColorMatchesTitle ||
        basisCenterOffset > 0.6 ||
        menuOutside)
    ) {
      throw new Error(`手机画板尺寸异常: ${JSON.stringify(metrics)}`);
    }
    if (errors.length > 0) throw new Error(errors.join('\n'));

    const outputPath = path.join(outputDir, 'overview.png');
    await page.screenshot({ path: outputPath, fullPage: true, animations: 'disabled' });
    process.stdout.write(`${outputPath}\n`);
  } finally {
    await context.close();
    await browser.close();
  }
}

main().catch((error) => {
  process.stderr.write(`${error.stack || error}\n`);
  process.exitCode = 1;
});
