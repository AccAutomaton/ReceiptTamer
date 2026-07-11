const fs = require('fs');
const path = require('path');
const { pathToFileURL } = require('url');
const { chromium } = require('playwright-core');

const root = path.resolve(__dirname, '..');
const sourceDir = path.join(
  root,
  'docs',
  'design',
  'morning-ledger-relief-island-preview',
);
const baselineDir = path.join(
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
const parityFiles = [...boardFiles, compactFile];
const requiredFiles = [
  ...parityFiles,
  indexFile,
  'shared.css',
  'relief-island.css',
  'icons.svg',
];

const blurAllowlist = [
  '.appbar-actions',
  '.appbar-main > .icon-button',
  '.bottom-nav',
  '.sheet',
  '.dialog',
];
const blurSelector = blurAllowlist.join(', ');

const chromeCandidates = [
  process.env.CHROME_PATH,
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
  'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
].filter(Boolean);

function assertDirectoryFiles(directory, files, label) {
  if (!fs.existsSync(directory)) {
    throw new Error(`${label}目录不存在: ${directory}`);
  }

  const missingFiles = files.filter(
    (fileName) => !fs.existsSync(path.join(directory, fileName)),
  );
  if (missingFiles.length > 0) {
    throw new Error(`${label}文件缺失: ${missingFiles.join(', ')}`);
  }
}

function assertSourceContract() {
  assertDirectoryFiles(sourceDir, requiredFiles, '新版预览');
  assertDirectoryFiles(baselineDir, parityFiles, '上一版预览');

  const discoveredBoards = fs
    .readdirSync(sourceDir)
    .filter((name) => /^board-\d{2}\.html$/.test(name))
    .sort();
  if (
    discoveredBoards.length !== boardFiles.length ||
    discoveredBoards.some((name, index) => name !== boardFiles[index])
  ) {
    throw new Error(
      `新版画板契约不匹配，应为 ${boardFiles.join(', ')}，实际为 ${
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

async function readPhoneSnapshot(page, filePath) {
  await page.goto(pathToFileURL(filePath).href, { waitUntil: 'networkidle' });
  return page.locator('.phone').evaluateAll((phones) => {
    function serializeNode(node) {
      if (node.nodeType === Node.TEXT_NODE) {
        const text = node.textContent.replace(/\s+/g, ' ').trim();
        return text ? { text } : null;
      }
      if (node.nodeType !== Node.ELEMENT_NODE) return null;

      const attributes = Array.from(node.attributes)
        .map((attribute) => [attribute.name, attribute.value])
        .sort(([left], [right]) => left.localeCompare(right));
      const children = Array.from(node.childNodes)
        .map(serializeNode)
        .filter(Boolean);
      return {
        tag: node.tagName.toLowerCase(),
        attributes,
        children,
      };
    }

    return phones.map(serializeNode);
  });
}

async function assertPhoneDomParity(browser) {
  const baselinePage = await browser.newPage();
  const candidatePage = await browser.newPage();

  try {
    for (const fileName of parityFiles) {
      const [baselineSnapshot, candidateSnapshot] = await Promise.all([
        readPhoneSnapshot(baselinePage, path.join(baselineDir, fileName)),
        readPhoneSnapshot(candidatePage, path.join(sourceDir, fileName)),
      ]);
      const expectedCount = 3;
      if (
        baselineSnapshot.length !== expectedCount ||
        candidateSnapshot.length !== expectedCount
      ) {
        throw new Error(
          `${fileName} 新旧预览均应包含 ${expectedCount} 个手机框，实际为旧版 ${baselineSnapshot.length}、新版 ${candidateSnapshot.length}。`,
        );
      }
      if (JSON.stringify(baselineSnapshot) !== JSON.stringify(candidateSnapshot)) {
        throw new Error(`${fileName} 的新版手机 DOM 与上一版不等价。`);
      }
    }
  } finally {
    await baselinePage.close();
    await candidatePage.close();
  }
}

async function waitForImages(page) {
  await page.locator('img').evaluateAll(async (images) => {
    await Promise.all(
      images.map(async (image) => {
        if (image.complete) return;
        try {
          await image.decode();
        } catch (_) {
          // Broken images are reported with their final URL below.
        }
      }),
    );
  });
}

async function assertImagesLoaded(page, fileName) {
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

async function validateComputedQa(page, fileName) {
  const isCompact = fileName === compactFile;
  const expectedPhoneWidth = isCompact ? 360 : 412;
  const minimumInsets = isCompact
    ? { left: 12, right: 12, bottom: 10 }
    : { left: 14, right: 14, bottom: 12 };

  const issues = await page.locator('.phone').evaluateAll(
    (phones, options) => {
      const {
        allowlist,
        allowedSelector,
        expectedWidth,
        insets,
      } = options;
      const errors = [];

      function describe(element) {
        const classes = Array.from(element.classList).join('.');
        return `${element.tagName.toLowerCase()}${classes ? `.${classes}` : ''}`;
      }

      function filterValue(style) {
        return style.backdropFilter || style.webkitBackdropFilter || 'none';
      }

      function parseAlpha(color) {
        const value = color.trim().toLowerCase();
        if (value === 'transparent') return 0;

        const functionMatch = value.match(/^(?:rgba?|color)\((.*)\)$/);
        if (!functionMatch) return 1;
        const body = functionMatch[1];
        if (body.includes('/')) {
          const alphaText = body.split('/').pop().trim();
          return alphaText.endsWith('%')
            ? Number.parseFloat(alphaText) / 100
            : Number.parseFloat(alphaText);
        }

        const commaParts = body.split(',').map((part) => part.trim());
        if (commaParts.length === 4) {
          const alphaText = commaParts[3];
          return alphaText.endsWith('%')
            ? Number.parseFloat(alphaText) / 100
            : Number.parseFloat(alphaText);
        }
        return 1;
      }

      function isVisible(element) {
        const style = getComputedStyle(element);
        const rect = element.getBoundingClientRect();
        return (
          style.display !== 'none' &&
          style.visibility !== 'hidden' &&
          rect.width > 0 &&
          rect.height > 0
        );
      }

      phones.forEach((phone, phoneIndex) => {
        const phoneLabel = `手机 ${phoneIndex + 1}`;
        const phoneRect = phone.getBoundingClientRect();
        if (Math.abs(phoneRect.width - expectedWidth) > 0.6) {
          errors.push(
            `${phoneLabel} 宽度应为 ${expectedWidth}px，实际为 ${phoneRect.width.toFixed(2)}px。`,
          );
        }

        const allElements = [phone, ...phone.querySelectorAll('*')];
        const nonOpaque = allElements.filter(
          (element) => Math.abs(Number.parseFloat(getComputedStyle(element).opacity) - 1) > 0.001,
        );
        if (nonOpaque.length > 0) {
          errors.push(
            `${phoneLabel} 存在 opacity 非 1 的元素: ${nonOpaque.slice(0, 5).map(describe).join(', ')}。`,
          );
        }

        const filteredElements = allElements.filter((element) => {
          const value = filterValue(getComputedStyle(element));
          return value && value !== 'none';
        });
        if (filteredElements.length > 3) {
          errors.push(
            `${phoneLabel} 的模糊层超过 3 个，实际为 ${filteredElements.length}。`,
          );
        }

        for (const element of filteredElements) {
          const style = getComputedStyle(element);
          const value = filterValue(style);
          if (!allowlist.some((selector) => element.matches(selector))) {
            errors.push(`${phoneLabel} 的 ${describe(element)} 不在滤镜白名单。`);
          }

          const radii = Array.from(value.matchAll(/blur\(\s*([0-9.]+)px\s*\)/g))
            .map((match) => Number.parseFloat(match[1]));
          if (radii.length === 0 || radii.some((radius) => radius > 12.001)) {
            errors.push(`${phoneLabel} 的 ${describe(element)} 模糊值不合规: ${value}。`);
          }

          const alpha = parseAlpha(style.backgroundColor);
          if (!Number.isFinite(alpha) || alpha < 0.899 || alpha > 0.951) {
            errors.push(
              `${phoneLabel} 的 ${describe(element)} 背景 alpha 应为 .90–.95，实际为 ${style.backgroundColor}。`,
            );
          }
        }

        const expectedFloats = Array.from(phone.querySelectorAll(allowedSelector))
          .filter(isVisible);
        for (const element of expectedFloats) {
          if (filterValue(getComputedStyle(element)) === 'none') {
            errors.push(`${phoneLabel} 的浮控件 ${describe(element)} 未启用适度背景模糊。`);
          }
        }

        const screen = phone.querySelector('.screen');
        if (!screen) {
          errors.push(`${phoneLabel} 缺少 .screen。`);
          return;
        }
        const screenRect = screen.getBoundingClientRect();
        for (const navigation of phone.querySelectorAll('.bottom-nav')) {
          if (!isVisible(navigation)) continue;
          const navRect = navigation.getBoundingClientRect();
          const actualInsets = {
            left: navRect.left - screenRect.left,
            right: screenRect.right - navRect.right,
            bottom: screenRect.bottom - navRect.bottom,
          };
          for (const edge of ['left', 'right', 'bottom']) {
            if (actualInsets[edge] + 0.5 < insets[edge]) {
              errors.push(
                `${phoneLabel} 导航 ${edge} 边距至少应为 ${insets[edge]}px，实际为 ${actualInsets[edge].toFixed(2)}px。`,
              );
            }
          }

          const centerAction = navigation.querySelector('.nav-add');
          const destination = navigation.querySelector('.nav-item');
          if (centerAction && destination && isVisible(centerAction)) {
            const centerRect = centerAction.getBoundingClientRect();
            const destinationRect = destination.getBoundingClientRect();
            if (
              centerRect.top + 0.5 < navRect.top ||
              centerRect.bottom - 0.5 > navRect.bottom
            ) {
              errors.push(
                `${phoneLabel} 中央新增必须完整位于悬浮岛内，导航范围 ${navRect.top.toFixed(2)}–${navRect.bottom.toFixed(2)}，实际 ${centerRect.top.toFixed(2)}–${centerRect.bottom.toFixed(2)}。`,
              );
            }
            if (Math.abs(centerRect.height - destinationRect.height) > 0.5) {
              errors.push(
                `${phoneLabel} 中央新增与导航目的地应同高，实际 ${centerRect.height.toFixed(2)}px / ${destinationRect.height.toFixed(2)}px。`,
              );
            }
            const centerY = centerRect.top + centerRect.height / 2;
            const destinationY = destinationRect.top + destinationRect.height / 2;
            if (Math.abs(centerY - destinationY) > 0.5) {
              errors.push(
                `${phoneLabel} 中央新增与导航目的地应共享垂直基线，中心差 ${Math.abs(centerY - destinationY).toFixed(2)}px。`,
              );
            }
          }
        }
      });

      return errors;
    },
    {
      allowlist: blurAllowlist,
      allowedSelector: blurSelector,
      expectedWidth: expectedPhoneWidth,
      insets: minimumInsets,
    },
  );

  if (issues.length > 0) {
    throw new Error(`${fileName} 视觉 QA 未通过:\n${issues.join('\n')}`);
  }
}

async function validatePage(page, fileName) {
  if (parityFiles.includes(fileName)) {
    const phoneCount = await page.locator('.phone').count();
    if (phoneCount !== 3) {
      throw new Error(`${fileName} 应包含 3 个 .phone，实际为 ${phoneCount}。`);
    }
    await validateComputedQa(page, fileName);
  }

  if (fileName === 'board-04.html') {
    const darkCount = await page.locator('.phone.dark').count();
    const dangerCount = await page.locator('.phone.danger-preview').count();
    if (darkCount === 0) {
      throw new Error('board-04.html 必须包含至少一个 .phone.dark 状态。');
    }
    if (dangerCount === 0) {
      throw new Error('board-04.html 必须包含至少一个 .phone.danger-preview 状态。');
    }
  }

  await assertImagesLoaded(page, fileName);
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
    await waitForImages(page);
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
    await assertPhoneDomParity(browser);

    const page = await browser.newPage({
      viewport: { width: 1450, height: 900 },
      deviceScaleFactor: 1,
      colorScheme: 'light',
      reducedMotion: 'reduce',
    });

    try {
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
      await page.close();
    }
  } finally {
    await browser.close();
  }
}

main().catch((error) => {
  process.stderr.write(`${error.stack || error}\n`);
  process.exitCode = 1;
});
