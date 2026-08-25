const { execSync } = require('child_process');
const http = require('http');

async function ensureCdpRunning() {
  return new Promise((resolve) => {
    const req = http.get('http://127.0.0.1:9222/json/version', (res) => {
      resolve(true);
    });
    req.on('error', () => {
      console.log('[!] CDP port 9222 not active. Auto-launching Chrome CDP...');
      try {
        const isWin = process.platform === 'win32';
        const scriptPath = path.resolve(__dirname, 'scripts', isWin ? 'test-cdp.ps1' : 'test-cdp.sh');
        if (isWin) {
          execSync(`powershell -ExecutionPolicy Bypass -File "${scriptPath}"`, { stdio: 'inherit' });
        } else {
          execSync(`bash "${scriptPath}"`, { stdio: 'inherit' });
        }
      } catch (e) {
        console.error('[-] Failed to auto-launch Chrome CDP script:', e.message);
      }
      resolve(false);
    });
    req.end();
  });
}

async function runGptReview(options = {}) {
  const {
    diffFilePath = 'pr_review_prompt.txt',
    forceNewChat = false,
    outputFile = 'gpt_review_response.txt'
  } = options;

  const resolvedDiffPath = path.resolve(diffFilePath);

  if (!fs.existsSync(resolvedDiffPath)) {
    throw new Error(`File not found -> ${resolvedDiffPath}`);
  }

  await ensureCdpRunning();

  console.log('[1] Connecting to Chrome CDP (ChatGPT)...');
  const browser = await chromium.connectOverCDP('http://127.0.0.1:9222');
  
  const contexts = browser.contexts();
  const allPages = contexts.flatMap(c => c.pages());
  let chatPage = allPages.find(p => p.url().includes('chatgpt.com'));
  
  if (!chatPage) {
    console.log('[-] No active ChatGPT tab found, creating new page...');
    const context = contexts[0] || await browser.newContext();
    chatPage = await context.newPage();
    await chatPage.goto('https://chatgpt.com/', { waitUntil: 'domcontentloaded' });
  }

  await chatPage.bringToFront();

  if (forceNewChat) {
    console.log('[2] Forcing a completely new chat by navigating to root...');
    await chatPage.goto('https://chatgpt.com/', { waitUntil: 'domcontentloaded' });
    await chatPage.waitForTimeout(4000);
  } else {
    console.log('[2] Reusing active ChatGPT chat session...');
  }

  console.log(`[3] Reading PR Diff prompt from: ${resolvedDiffPath}...`);
  const promptText = fs.readFileSync(resolvedDiffPath, 'utf-8');

  const textareaSelector = '#prompt-textarea';
  await chatPage.waitForSelector(textareaSelector, { state: 'visible', timeout: 15000 });
  
  const assistantSelector = '[data-message-author-role="assistant"]';
  const beforeCount = await chatPage.locator(assistantSelector).count();

  console.log('[4] Typing and sending PR Diff into ChatGPT session...');
  const textarea = chatPage.locator(textareaSelector);
  await textarea.click();
  
  await chatPage.evaluate(([selector, text]) => {
    const el = document.querySelector(selector);
    el.focus();
    document.execCommand('insertText', false, text);
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
  }, [textareaSelector, promptText]);
  
  await chatPage.waitForTimeout(1500);

  const sendButton = chatPage.locator('button[data-testid="send-button"]');
  if (await sendButton.count() > 0 && await sendButton.isVisible()) {
    await sendButton.click();
  } else {
    await chatPage.keyboard.press('Enter');
  }

  console.log('[5] Waiting for GPT to generate review response...');
  try {
    await chatPage.waitForFunction(
      ({ selector, prev }) => document.querySelectorAll(selector).length > prev,
      { selector: assistantSelector, prev: beforeCount },
      { timeout: 90000 }
    );
  } catch (e) {
    console.log('[-] Timeout waiting for new message element, checking available responses...');
  }

  // Dynamic wait for response generation to complete
  await chatPage.waitForTimeout(45000);

  console.log('[6] Reading response...');
  const assistantMessages = chatPage.locator(assistantSelector);
  const count = await assistantMessages.count();
  
  const targetIndex = count > beforeCount ? count - 1 : (count > 0 ? count - 1 : -1);

  if (targetIndex >= 0) {
    const lastMessage = assistantMessages.nth(targetIndex);
    const resultText = await lastMessage.innerText();
    console.log('\n--- GPT RESPONSE ---\n' + resultText + '\n--------------------\n');
    
    if (outputFile) {
      const resolvedOutputPath = path.resolve(outputFile);
      fs.writeFileSync(resolvedOutputPath, resultText, 'utf-8');
      console.log(`[+] Saved GPT Response to: ${resolvedOutputPath}`);
    }

    const match = resultText.match(/^REVIEW_STATUS:\s*(APPROVED|CHANGES_REQUESTED)\s*$/im);
    const status = match ? match[1].toUpperCase() : 'UNKNOWN';

    return {
      status,
      resultText,
      browser
    };
  } else {
    throw new Error('Could not find assistant message in ChatGPT.');
  }
}

module.exports = { runGptReview };

// Standalone execution
if (require.main === module) {
  (async () => {
    try {
      const args = process.argv.slice(2);
      const diffFilePath = args.find(a => !a.startsWith('--')) || 'pr_review_prompt.txt';
      const forceNewChat = args.includes('--new-chat');

      const result = await runGptReview({ diffFilePath, forceNewChat });
      console.log(`\n📌 Parsed GPT Status: ${result.status}`);

      if (result.status === 'APPROVED') {
        console.log('✅ ChatGPT Review Status: APPROVED!');
        process.exit(0);
      } else {
        console.log('❌ ChatGPT Review Status: CHANGES_REQUESTED (or UNKNOWN)!');
        process.exit(1);
      }
    } catch (err) {
      console.error('ERROR in test-gpt-pr:', err);
      process.exit(1);
    }
  })();
}
