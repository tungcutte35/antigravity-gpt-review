const path = require('path');
const fs = require('fs');
const { runGptReview } = require('./test-gpt-pr');
const { runClaudeReview } = require('./test-claude-pr');

(async () => {
  try {
    const args = process.argv.slice(2);
    const diffFilePath = args.find(a => !a.startsWith('--')) || 'pr_review_prompt.txt';
    const forceNewChat = args.includes('--new-chat');

    console.log('==================================================');
    console.log('🚀 DUAL-STAGE REVIEW PIPELINE: ChatGPT -> Claude.ai');
    console.log('==================================================\n');

    console.log('--------------------------------------------------');
    console.log('STAGE 1: ChatGPT First-Pass Code Review');
    console.log('--------------------------------------------------');
    
    let gptResult;
    try {
      gptResult = await runGptReview({
        diffFilePath,
        forceNewChat,
        outputFile: 'gpt_review_response.txt'
      });
      console.log(`[Stage 1 Complete] ChatGPT Status: ${gptResult.status}\n`);
    } catch (gptErr) {
      console.error('[-] Stage 1 (ChatGPT) encountered an error:', gptErr.message);
      console.log('[!] Proceeding to Stage 2 with diff context only...');
    }

    console.log('--------------------------------------------------');
    console.log('STAGE 2: Claude.ai Second-Pass Audit & Final Verdict');
    console.log('--------------------------------------------------');

    const claudeResult = await runClaudeReview({
      diffFilePath,
      gptResponseFilePath: 'gpt_review_response.txt',
      outputFile: 'claude_review_response.txt',
      forceNewChat: true
    });

    console.log('==================================================');
    console.log(`📌 FINAL VERDICT (Decided by Claude.ai): ${claudeResult.status}`);
    console.log('==================================================\n');

    if (claudeResult.status === 'APPROVED') {
      console.log('✅ Dual-Stage Code Review APPROVED!');
      process.exit(0);
    } else {
      console.log('❌ Dual-Stage Code Review CHANGES_REQUESTED!');
      process.exit(1);
    }

  } catch (err) {
    console.error('CRITICAL ERROR in test-dual-pr:', err);
    process.exit(1);
  }
})();
