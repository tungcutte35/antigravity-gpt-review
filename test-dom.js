const { chromium } = require('playwright');
(async () => {
    const browser = await chromium.connectOverCDP('http://127.0.0.1:9222');
    const contexts = browser.contexts();
    const allPages = contexts.flatMap(c => c.pages());
    let chatPage = allPages.find(p => p.url().includes('chatgpt.com')) || allPages[0];
    
    const count = await chatPage.locator('[data-message-author-role="assistant"]').count();
    console.log("Assistant messages count:", count);
    
    const count2 = await chatPage.locator('.markdown').count();
    console.log("Markdown blocks count:", count2);

    if (count > 0) {
        console.log("Text:", await chatPage.locator('[data-message-author-role="assistant"]').last().innerText());
    }
    
    process.exit(0);
})();
