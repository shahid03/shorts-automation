// index.js - Main entry point
const StoicShortsGenerator = require('./src/generator');
const config = require('./config/config');
const logger = require('./src/utils/logger');

async function main() {
  try {
    logger.info('Starting Stoic Shorts automation...');
    const generator = new StoicShortsGenerator(config);
    await generator.run();
    logger.info('Automation completed successfully');
  } catch (error) {
    logger.error('Automation failed:', error);
    process.exit(1);
  }
}

// Run on schedule or immediately
if (config.schedule.enabled) {
  const cron = require('node-cron');
  cron.schedule(config.schedule.cron, main);
  logger.info(`Scheduled to run: ${config.schedule.cron}`);
} else {
  main();
}
