const { google } = require('googleapis');
const path = require('path');
const logger = require('../utils/logger');

class SheetsService {
  constructor(config) {
    this.config = config;
    this.initSheets(config);
  }

  async initSheets(config) {
    const credentials = require(path.resolve(config.credentialsPath));
    const auth = new google.auth.GoogleAuth({
      credentials,
      scopes: ['https://www.googleapis.com/auth/spreadsheets']
    });
    this.sheets = google.sheets({ version: 'v4', auth });
  }

  async addEntry(data) {
    try {
      const response = await this.sheets.spreadsheets.values.append({
        spreadsheetId: this.config.spreadsheetId,
        range: `${this.config.sheetName}!A:G`,
        valueInputOption: 'USER_ENTERED',
        requestBody: {
          values: [[data.title, data.keywords, data.description, data.script, data.numImages, data.timestamp, data.status]]
        }
      });
      logger.info('Entry added to Google Sheets');
      return response.data;
    } catch (error) {
      logger.error(`Sheets update failed: ${error.message}`);
      throw error;
    }
  }
}

module.exports = SheetsService;
