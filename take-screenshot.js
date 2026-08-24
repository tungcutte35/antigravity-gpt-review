const { chromium } = require('playwright');
(async () => {
    const browser = await chromium.connectOverCDP('http://127.0.0.1:9222');
    const contexts = browser.contexts();
    const allPages = contexts.flatMap(c => c.pages());
    let chatPage = allPages.find(p => p.url().includes('chatgpt.com')) || allPages[0];
    await chatPage.bringToFront();
    await chatPage.screenshot({ path: '/tmp/chatgpt-screenshot.png', fullPage: true });
    console.log("Screenshot taken at /tmp/chatgpt-screenshot.png");
    process.exit(0);
})();
