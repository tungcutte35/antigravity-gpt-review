const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const http = require('http');

async function ensureCdpRunning() {
  const checkPort = () => new Promise((resolve) => {
    const req = http.get('http://127.0.0.1:9222/json/version', (res) => {
      resolve(res.statusCode === 200);
    });
    req.setTimeout(1500, () => {
      req.destroy();
      resolve(false);
    });
    req.on('error', () => resolve(false));
    req.end();
  });

  if (await checkPort()) return true;

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

  console.log('[*] Polling for CDP readiness...');
  for (let i = 0; i < 30; i++) {
    await new Promise(r => setTimeout(r, 500));
    if (await checkPort()) return true;
  }
  
  throw new Error('CDP port 9222 did not become ready in time.');
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
    await chatPage.bringToFront();
    await chatPage.waitForTimeout(3000);
  } else {
    console.log('[2] Reusing active ChatGPT chat session...');
    await chatPage.bringToFront();
  }

  console.log(`[3] Reading PR Diff prompt from: ${resolvedDiffPath}...`);
  const promptText = fs.readFileSync(resolvedDiffPath, 'utf-8');

  const textareaSelector = '#prompt-textarea';
  await chatPage.waitForSelector(textareaSelector, { state: 'visible', timeout: 15000 });
  
  const assistantSelector = '[data-message-author-role="assistant"]';
  const assistantMessages = chatPage.locator(assistantSelector);
  const beforeCount = await assistantMessages.count();

  console.log('[4] Typing and sending PR Diff into ChatGPT session...');
  const textarea = chatPage.locator(textareaSelector);
  await textarea.click();

  try {
    // Try Playwright native fill first
    await textarea.fill(promptText);
  } catch (e) {
    // Fallback to DOM evaluation & execCommand
    await chatPage.evaluate(([selector, text]) => {
      const el = document.querySelector(selector);
      if (!el) return;
      el.focus();
      if ('value' in el) {
        el.value = text;
      } else {
        document.execCommand('insertText', false, text);
      }
      el.dispatchEvent(new Event('input', { bubbles: true }));
      el.dispatchEvent(new Event('change', { bubbles: true }));
    }, [textareaSelector, promptText]);
  }
  
  await chatPage.waitForTimeout(1000);

  // Trigger key events to ensure React state enables send button
  await chatPage.keyboard.type(' ');
  await chatPage.keyboard.press('Backspace');
  await chatPage.waitForTimeout(1000);

  const sendBtnSelectors = [
    'button[data-testid="send-button"]',
    'button[aria-label*="Send"]',
    'button[aria-label*="Gửi"]',
    'button[data-testid="fruitjuice-send-button"]'
  ];

  let sent = false;
  for (const sSel of sendBtnSelectors) {
    const btn = chatPage.locator(sSel).last();
    if (await btn.count() > 0 && await btn.isVisible() && await btn.isEnabled()) {
      await btn.click();
      sent = true;
      console.log(`[+] Clicked send button (${sSel})`);
      break;
    }
  }

  if (!sent) {
    console.log('[+] Pressing Enter to send prompt...');
    await chatPage.keyboard.press('Enter');
  }

  console.log('[5] Waiting for GPT to finish generating review response (checking text stability)...');
  let generationComplete = false;
  let lastText = '';
  let stableCount = 0;

  for (let i = 0; i < 90; i++) {
    await chatPage.waitForTimeout(2000);
    const currentCount = await assistantMessages.count();
    
    if (currentCount > beforeCount) {
      const currentMessage = assistantMessages.nth(currentCount - 1);
      const currentText = await currentMessage.innerText();
      
      if (currentText === lastText && currentText.trim().length > 0) {
        stableCount++;
        console.log(`[+] Text stable for ${stableCount * 2}s (length: ${currentText.length})`);
        if (stableCount >= 3) { // 6 seconds of no text change
          console.log('[+] Assistant response stabilized, generation complete.');
          generationComplete = true;
          break;
        }
      } else {
        if (currentText !== lastText) {
          console.log(`[-] Text changing... (length: ${currentText.length})`);
        }
        lastText = currentText;
        stableCount = 0;
      }
    } else {
      console.log(`[-] Waiting for new message... (current: ${currentCount}, before: ${beforeCount})`);
    }
  }

  if (!generationComplete) {
    throw new Error('GPT generation did not complete within the 180-second timeout (text did not stabilize).');
  }

  console.log('[6] Reading response...');
  const count = await assistantMessages.count();
  
  if (count <= beforeCount) {
    throw new Error('No new GPT response generated for this review (timeout or generation failed).');
  }

  const targetIndex = count - 1;

  if (targetIndex >= 0) {
    const lastMessage = assistantMessages.nth(targetIndex);
    const resultText = await lastMessage.innerText();
    console.log('\n--- GPT RESPONSE ---\n' + resultText + '\n--------------------\n');
    
    if (outputFile) {
      const resolvedOutputPath = path.resolve(outputFile);
      fs.writeFileSync(resolvedOutputPath, resultText, 'utf-8');
      console.log(`[+] Saved GPT Response to: ${resolvedOutputPath}`);
    }

    // Parse the LAST occurrence of the verdict to avoid false-positives from inline examples
    const matches = [...resultText.matchAll(/^REVIEW_STATUS:\s*(APPROVED|CHANGES_REQUESTED)\s*$/igm)];
    const status = matches.length > 0 ? matches[matches.length - 1][1].toUpperCase() : 'UNKNOWN';

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
