const fs = require('fs');
const path = require('path');
const { pathToFileURL } = require('url');
const { chromium } = require('playwright-core');

const root = path.resolve(__dirname, '..');
const sourceDir = path.join(root, 'docs', 'design', 'reimbursement-binding-preview');
const outputDir = path.join(sourceDir, 'rendered');
const boardFiles = ['board-01.html', 'board-02.html', 'board-03.html', 'board-04.html', 'board-05.html'];
const compactFile = 'compact-check.html';
const typeScaleFile = 'type-scale-check.html';
const indexFile = 'index.html';
const requiredFiles = [...boardFiles, compactFile, typeScaleFile, indexFile, 'shared.css', 'icons.svg', 'README.md'];

const browserCandidates = [
  process.env.CHROME_PATH,
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
  'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
].filter(Boolean);

function assertSources() {
  const missing = requiredFiles.filter((file) => !fs.existsSync(path.join(sourceDir, file)));
  if (missing.length > 0) throw new Error(`设计稿文件缺失: ${missing.join(', ')}`);
  const discovered = fs.readdirSync(sourceDir).filter((name) => /^board-\d{2}\.html$/.test(name)).sort();
  if (JSON.stringify(discovered) !== JSON.stringify(boardFiles)) {
    throw new Error(`画板集合不匹配: ${discovered.join(', ')}`);
  }

  const uiFiles = [...boardFiles, compactFile, typeScaleFile];
  const forbiddenPeriodTerms = ['当前账期', '本月报销', '本期报销夹', '本期材料', '本期全部'];
  for (const fileName of uiFiles) {
    const source = fs.readFileSync(path.join(sourceDir, fileName), 'utf8');
    const found = forbiddenPeriodTerms.filter((term) => source.includes(term));
    if (found.length > 0) throw new Error(`${fileName} 在报销范围外残留周期语义: ${found.join(', ')}`);
  }

  const reportSource = fs.readFileSync(path.join(sourceDir, 'board-01.html'), 'utf8');
  const flowSource = fs.readFileSync(path.join(sourceDir, 'board-03.html'), 'utf8');
  const shortcutSource = fs.readFileSync(path.join(sourceDir, 'board-05.html'), 'utf8');
  const invoiceSource = fs.readFileSync(path.join(sourceDir, 'board-04.html'), 'utf8');
  const styleSource = fs.readFileSync(path.join(sourceDir, 'shared.css'), 'utf8');
  const overviewSource = fs.readFileSync(path.join(sourceDir, indexFile), 'utf8');
  if (!reportSource.includes('日期范围') || !reportSource.includes('未选择')) {
    throw new Error('报销入口必须先呈现未选择范围状态。');
  }
  const homeTools = ['用餐证明导出', '开票助手', '发票导出', '报销材料导出'];
  const missingHomeTools = homeTools.filter((label) => !reportSource.includes(label));
  if (missingHomeTools.length > 0) {
    throw new Error(`首页快捷工作台缺少原有能力: ${missingHomeTools.join(', ')}`);
  }
  const homeStats = reportSource.match(/class="folio-stat/g) ?? [];
  if (!reportSource.includes('folio-desk') || !reportSource.includes('folio-spine') || homeStats.length < 3) {
    throw new Error('首页必须保留单一上装订票据目录与三组概览数据。');
  }
  const recentEntries = reportSource.match(/class="recent-entry/g) ?? [];
  if (!reportSource.includes('home-scroll') || !reportSource.includes('recent-sheet') || recentEntries.length !== 10) {
    throw new Error('首页目录与独立最近收录卡必须共用滚动区，并完整展示 10 条资料。');
  }
  if (!styleSource.includes('.screen:has(> .scroll)::before') || !styleSource.includes('.screen:has(> .scroll):has(> :is(.bottom-nav, .bottom-action, .selection-bar))::after')) {
    throw new Error('所有中间列表必须在顶部控件下方淡入，并在固定底栏上方渐隐。');
  }
  if (!reportSource.includes('ledger-sheet') || !invoiceSource.includes('ledger-sheet')) {
    throw new Error('订单与发票主列表必须使用连续账页结构。');
  }
  if (!styleSource.includes('NotoSerifSC-VF.ttf') || !styleSource.includes('Tinos-Regular.ttf')) {
    throw new Error('全衬线试验必须同时加载中文与西文衬线字体。');
  }
  const latinFaces = styleSource.match(/@font-face\s*{[^}]*font-family:\s*"RT Latin Serif";[^}]*}/gs) ?? [];
  const cjkFaces = styleSource.match(/@font-face\s*{[^}]*font-family:\s*"RT CJK Serif";[^}]*}/gs) ?? [];
  if (latinFaces.length !== 2 || latinFaces.some((face) => !face.includes('Tinos-') || !face.includes('unicode-range'))) {
    throw new Error('RT Latin Serif 必须用两条带 unicode-range 的 Tinos 字体面覆盖常规与粗体。');
  }
  if (cjkFaces.length !== 1 || !cjkFaces[0].includes('NotoSerifSC-VF.ttf') || !cjkFaces[0].includes('unicode-range')) {
    throw new Error('RT CJK Serif 必须用独立的 Noto Serif SC 字体面覆盖中文，避免同 family 缺字回退。');
  }
  const fontSources = `${styleSource}\n${overviewSource}`;
  const legacyFontRoles = fontSources.match(/"RT (?:Sans|Display|Mono)"/g) ?? [];
  if (legacyFontRoles.length > 0 || !styleSource.includes('"RT Latin Serif", "RT CJK Serif", serif') || !overviewSource.includes('"RT Latin Serif","RT CJK Serif",serif')) {
    throw new Error('全部文字必须使用独立的 RT Latin Serif + RT CJK Serif 组合栈。');
  }
  if (!flowSource.includes('第 2 步 / 共 3 步') || !flowSource.includes('第 3 步 / 共 3 步')) {
    throw new Error('报销流程必须覆盖选择范围后的检查与导出步骤。');
  }
  if (!shortcutSource.includes('没有发票也可以导出') || !shortcutSource.includes('全部日期') || !shortcutSource.includes('保存并关联 2 笔')) {
    throw new Error('快捷任务画板必须覆盖无发票用餐证明与按店开票自动关联。');
  }
}

function findBrowser() {
  const executablePath = browserCandidates.find((candidate) => fs.existsSync(candidate));
  if (!executablePath) throw new Error('未找到 Chrome/Edge；可通过 CHROME_PATH 指定浏览器。');
  return executablePath;
}

async function waitForImages(page) {
  await page.locator('img').evaluateAll(async (images) => {
    await Promise.all(images.map(async (img) => {
      if (img.complete) return;
      try { await img.decode(); } catch (_) { /* reported below */ }
    }));
  });
  const broken = await page.locator('img').evaluateAll((images) => images
    .filter((img) => !img.complete || img.naturalWidth === 0)
    .map((img) => img.currentSrc || img.src));
  if (broken.length > 0) throw new Error(`图片加载失败: ${broken.join(', ')}`);
}

async function validatePhones(page, fileName) {
  const compact = fileName === compactFile;
  const expectedWidth = compact ? 360 : 412;
  const expectedHeight = compact ? 800 : 915;
  const issues = await page.locator('.phone').evaluateAll((phones, expected) => {
    const errors = [];
    if (phones.length !== 3) errors.push(`应包含 3 个手机框，实际 ${phones.length}`);

    const filterValue = (style) => style.backdropFilter || style.webkitBackdropFilter || 'none';
    phones.forEach((phone, index) => {
      const rect = phone.getBoundingClientRect();
      if (Math.abs(rect.width - expected.width) > 0.6) errors.push(`手机 ${index + 1} 宽度 ${rect.width}`);
      if (Math.abs(rect.height - expected.height) > 0.6) errors.push(`手机 ${index + 1} 高度 ${rect.height}`);

      const screen = phone.querySelector('.screen');
      if (!screen) {
        errors.push(`手机 ${index + 1} 缺少 .screen`);
        return;
      }

      const filtered = [screen, ...screen.querySelectorAll('*')].filter((element) => {
        const filter = filterValue(getComputedStyle(element));
        return filter && filter !== 'none';
      });
      for (const element of filtered) {
        const filter = filterValue(getComputedStyle(element));
        const radii = [...filter.matchAll(/blur\(\s*([0-9.]+)px\s*\)/g)].map((m) => Number(m[1]));
        if (radii.some((radius) => radius > 12.001)) errors.push(`手机 ${index + 1} 模糊超过 12px: ${filter}`);
      }

      const screenElements = [screen, ...screen.querySelectorAll('*')];
      const depthEffects = [];
      for (const element of screenElements) {
        for (const pseudo of [null, '::before', '::after']) {
          const style = getComputedStyle(element, pseudo);
          if (style.boxShadow !== 'none' || style.filter !== 'none') {
            const label = element.className ? `.${String(element.className).trim().replace(/\s+/g, '.')}` : element.tagName.toLowerCase();
            depthEffects.push(`${label}${pseudo || ''}`);
          }
        }
      }
      if (depthEffects.length > 0) {
        errors.push(`手机 ${index + 1} 应用内表面仍有投影或滤镜: ${depthEffects.slice(0, 5).join(', ')}`);
      }

      const flatControls = screen.querySelectorAll('.primary-button, .secondary-button, .icon-button, .back-button, .nav-item, .intake-dock, .chip, .selection-check, .check-box, .toggle');
      for (const control of flatControls) {
        const style = getComputedStyle(control);
        if (style.transform !== 'none') errors.push(`手机 ${index + 1} 扁平控件不应使用位移或下沉变换`);
        const borderWidths = [style.borderTopWidth, style.borderRightWidth, style.borderBottomWidth, style.borderLeftWidth].map(Number.parseFloat);
        if (borderWidths[2] > Math.max(borderWidths[0], borderWidths[1], borderWidths[3]) + 0.1) {
          errors.push(`手机 ${index + 1} 扁平控件不应使用加粗底边`);
        }
      }

      const middleScroll = screen.querySelector(':scope > .scroll');
      if (middleScroll) {
        const scrollStyle = getComputedStyle(middleScroll);
        const topFade = getComputedStyle(screen, '::before');
        if (topFade.content === 'none' || parseFloat(topFade.height) < 28 || topFade.pointerEvents !== 'none') {
          errors.push(`手机 ${index + 1} 顶栏下方缺少有效列表淡入层`);
        }
        if (!['auto', 'scroll'].includes(scrollStyle.overflowY)) errors.push(`手机 ${index + 1} 中间列表未启用纵向滚动`);

        const bottomControl = screen.querySelector(':scope > .bottom-nav, :scope > .bottom-action, :scope > .selection-bar');
        const bottomFade = getComputedStyle(screen, '::after');
        if (bottomControl) {
          const scrollBottom = parseFloat(scrollStyle.bottom);
          const fadeBottom = parseFloat(bottomFade.bottom);
          if (bottomFade.content === 'none' || parseFloat(bottomFade.height) < 40 || bottomFade.pointerEvents !== 'none') {
            errors.push(`手机 ${index + 1} 固定底栏上方缺少有效列表渐隐层`);
          }
          if (Math.abs(scrollBottom - fadeBottom) > 0.6) errors.push(`手机 ${index + 1} 底部渐隐未贴合滚动区边界`);
        } else if (bottomFade.content !== 'none') {
          errors.push(`手机 ${index + 1} 没有固定底控件却出现底部渐隐`);
        }
      }

      const homeScroll = screen.querySelector('.home-scroll');
      if (homeScroll) {
        const desk = homeScroll.querySelector('.folio-desk');
        const recent = homeScroll.querySelector('.recent-sheet');
        const entries = homeScroll.querySelectorAll('.recent-entry');
        if (!desk || !recent || entries.length !== 10) errors.push(`手机 ${index + 1} 首页滚动区必须包含目录卡与 10 条最近资料`);
        if (desk && recent && desk.compareDocumentPosition(recent) !== Node.DOCUMENT_POSITION_FOLLOWING) {
          errors.push(`手机 ${index + 1} 最近收录卡必须位于目录卡之后`);
        }
        if (homeScroll.scrollHeight <= homeScroll.clientHeight + 40) errors.push(`手机 ${index + 1} 首页两张卡未形成有效共同滚动`);
        if (entries.length > 0) {
          homeScroll.scrollTop = homeScroll.scrollHeight;
          const scrollRect = homeScroll.getBoundingClientRect();
          const lastRect = entries[entries.length - 1].getBoundingClientRect();
          if (scrollRect.bottom - lastRect.bottom < 40) errors.push(`手机 ${index + 1} 第 10 条资料无法滚出底部渐隐区`);
          homeScroll.scrollTop = 0;
        }
      }

      for (const nav of screen.querySelectorAll('.bottom-nav')) {
        const screenRect = screen.getBoundingClientRect();
        const navRect = nav.getBoundingClientRect();
        if (navRect.left < screenRect.left + 11 || navRect.right > screenRect.right - 11 || navRect.bottom > screenRect.bottom - 9) {
          errors.push(`手机 ${index + 1} 悬浮导航未保留安全边距`);
        }
        const targets = nav.querySelectorAll('.nav-item');
        const labels = [...targets].map((target) => target.textContent.trim());
        if (JSON.stringify(labels) !== JSON.stringify(['首页', '订单', '发票', '报销'])) {
          errors.push(`手机 ${index + 1} 导航顺序应为首页—订单—发票—报销`);
        }
        for (const target of targets) {
          const targetRect = target.getBoundingClientRect();
          if (targetRect.height < 48) errors.push(`手机 ${index + 1} 导航命中高度小于 48px`);
        }

        const intake = screen.querySelector('.intake-dock');
        if (!intake) {
          errors.push(`手机 ${index + 1} 缺少独立新增侧键`);
          continue;
        }
        const intakeRect = intake.getBoundingClientRect();
        if (intake.textContent.trim() !== '新增') errors.push(`手机 ${index + 1} 新增侧键标签不明确`);
        if (intakeRect.width < 48 || intakeRect.height < 48) errors.push(`手机 ${index + 1} 新增侧键命中范围小于 48px`);
        if (intakeRect.right > screenRect.right - 11 || intakeRect.bottom > screenRect.bottom - 9) {
          errors.push(`手机 ${index + 1} 新增侧键未保留安全边距`);
        }
        if (intakeRect.left - navRect.right < 6) errors.push(`手机 ${index + 1} 导航与新增侧键间距不足`);
        if (Math.abs(intakeRect.height - navRect.height) > 0.6) errors.push(`手机 ${index + 1} 导航与新增侧键未同高`);
      }
    });
    return errors;
  }, { width: expectedWidth, height: expectedHeight });
  if (issues.length > 0) throw new Error(`${fileName} 视觉检查失败:\n${issues.join('\n')}`);
}

async function render(page, fileName, outputName, viewport, validate = true) {
  await page.setViewportSize(viewport);
  const errors = [];
  const onPageError = (error) => errors.push(error.stack || String(error));
  const onConsole = (message) => { if (message.type() === 'error') errors.push(message.text()); };
  page.on('pageerror', onPageError);
  page.on('console', onConsole);

  try {
    await page.goto(pathToFileURL(path.join(sourceDir, fileName)).href, { waitUntil: 'networkidle' });
    await page.evaluate(() => document.fonts.ready);
    await waitForImages(page);
    if (validate) await validatePhones(page, fileName);
    if (errors.length > 0) throw new Error(errors.join('\n'));
    const outputPath = path.join(outputDir, outputName);
    await page.screenshot({ path: outputPath, fullPage: true, animations: 'disabled' });
    process.stdout.write(`${fileName} -> ${outputPath}\n`);
  } finally {
    page.off('pageerror', onPageError);
    page.off('console', onConsole);
  }
}

async function main() {
  assertSources();
  fs.mkdirSync(outputDir, { recursive: true });
  const browser = await chromium.launch({ executablePath: findBrowser(), headless: true, args: ['--allow-file-access-from-files'] });
  const context = await browser.newContext({ deviceScaleFactor: 1, colorScheme: 'light', reducedMotion: 'reduce' });
  const page = await context.newPage();
  try {
    for (const fileName of boardFiles) {
      await render(page, fileName, fileName.replace('.html', '.png'), { width: 1450, height: 900 });
    }
    await render(page, compactFile, 'compact-check.png', { width: 1260, height: 820 });
    await render(page, typeScaleFile, 'type-scale-check.png', { width: 1450, height: 900 });
    await render(page, indexFile, 'overview.png', { width: 1500, height: 1000 }, false);
  } finally {
    await context.close();
    await browser.close();
  }
}

main().catch((error) => {
  process.stderr.write(`${error.stack || error}\n`);
  process.exitCode = 1;
});
