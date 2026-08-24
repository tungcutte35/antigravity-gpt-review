const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  try {
    const args = process.argv.slice(2);
    let diffFilePath = args.find(a => !a.startsWith('--')) || 'pr_review_prompt.txt';
    const forceNewChat = args.includes('--new-chat');

    diffFilePath = path.resolve(diffFilePath);

    if (!fs.existsSync(diffFilePath)) {
        console.error(`[-] Error: File not found -> ${diffFilePath}`);
        process.exit(1);
    }

    console.log('[1] Connecting to Chrome CDP...');
    const browser = await chromium.connectOverCDP('http://127.0.0.1:9222');
    
    const contexts = browser.contexts();
    const allPages = contexts.flatMap(c => c.pages());
    let chatPage = allPages.find(p => p.url().includes('chatgpt.com')) || allPages[0];
    
    if (!chatPage) {
        console.error('[-] No browser page found.');
        process.exit(1);
    }

    await chatPage.bringToFront();

    if (forceNewChat) {
        console.log('[2] Forcing a completely new chat by navigating to root...');
        await chatPage.goto('https://chatgpt.com/', { waitUntil: 'domcontentloaded' });
        await chatPage.waitForTimeout(4000); // Wait for the new chat UI to fully mount
    } else {
        console.log('[2] Reusing current active ChatGPT chat session...');
    }

    console.log(`[3] Reading PR Diff prompt from: ${diffFilePath}...`);
    const promptText = fs.readFileSync(diffFilePath, 'utf-8');

    const textareaSelector = '#prompt-textarea';
    await chatPage.waitForSelector(textareaSelector, { state: 'visible', timeout: 10000 });
    
    const assistantSelector = '[data-message-author-role="assistant"]';
    const beforeCount = await chatPage.locator(assistantSelector).count();

    console.log('[4] Typing and sending PR Diff into current session...');
    const textarea = chatPage.locator(textareaSelector);
    await textarea.click();
    
    // Using execCommand to bypass React freeze on huge text insertions
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
        
        const match = resultText.match(/^REVIEW_STATUS:\s*(APPROVED|CHANGES_REQUESTED)\s*$/im);
        if (match) {
            const status = match[1].toUpperCase();
            console.log(`\n📌 Parsed Status: ${status}`);
            try { await browser.close(); } catch(e) {}
            if (status === 'APPROVED') {
                console.log('✅ Code Review Status: APPROVED!');
                process.exit(0);
            } else {
                console.log('❌ Code Review Status: CHANGES_REQUESTED!');
                process.exit(1);
            }
        } else {
            console.log('⚠️ Unexpected Status Format in response text.');
            try { await browser.close(); } catch(e) {}
            process.exit(1);
        }
    } else {
        console.log('[-] Could not find assistant message.');
        try { await browser.close(); } catch(e) {}
        process.exit(1);
    }

  } catch (err) {
    console.error('ERROR:', err);
    process.exit(1);
  }
})();
