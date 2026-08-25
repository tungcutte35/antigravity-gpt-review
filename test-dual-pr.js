const path = require('path');
const fs = require('fs');
const { runGptReview } = require('./test-gpt-pr');
const { runClaudeReview } = require('./test-claude-pr');

const lockFile = path.resolve(__dirname, 'test-dual-pr.lock');
if (fs.existsSync(lockFile)) {
  try {
    const pid = parseInt(fs.readFileSync(lockFile, 'utf-8').trim(), 10);
    process.kill(pid, 0);
    console.error(`[-] Error: Another review process (PID ${pid}) is already running. Exiting to prevent browser freeze...`);
    process.exit(1);
  } catch (e) {
    try { fs.unlinkSync(lockFile); } catch(err){}
  }
}
fs.writeFileSync(lockFile, String(process.pid));
const cleanupLock = () => { try { if (fs.existsSync(lockFile)) fs.unlinkSync(lockFile); } catch(e){} };
process.on('exit', cleanupLock);
process.on('SIGINT', cleanupLock);
process.on('uncaughtException', (err) => { cleanupLock(); throw err; });

(async () => {
  try {
    const args = process.argv.slice(2);
    const diffFilePath = args.find(a => !a.startsWith('--')) || 'pr_review_prompt.txt';
    const forceNewChat = args.includes('--new-chat');

    const gptOutputFile = path.resolve('gpt_review_response.txt');
    const claudeOutputFile = path.resolve('claude_review_response.txt');

    // Clean up stale files before running
    if (fs.existsSync(gptOutputFile)) fs.unlinkSync(gptOutputFile);
    if (fs.existsSync(claudeOutputFile)) fs.unlinkSync(claudeOutputFile);

    console.log('==================================================');
    console.log('🚀 DUAL-STAGE REVIEW PIPELINE: ChatGPT -> Claude.ai');
    console.log('==================================================\n');

    console.log('--------------------------------------------------');
    console.log('STAGE 1: ChatGPT First-Pass Code Review');
    console.log('--------------------------------------------------');
    
    let gptResult = null;
    try {
      gptResult = await runGptReview({
        diffFilePath,
        forceNewChat: true,
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
      gptResponseText: gptResult ? gptResult.resultText : '',
      gptResponseFilePath: gptResult ? 'gpt_review_response.txt' : null,
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
