const { google } = require('googleapis');
const AWS = require('aws-sdk');
const fs = require('fs');
const path = require('path');
const logger = require('../utils/logger');

class StorageService {
  constructor(config) {
    this.config = config.storage;
    this.storageType = this.config.provider;

    if (this.storageType === 'googleDrive' && this.config.googleDrive.enabled) {
      this.initGoogleDrive(this.config.googleDrive);
    } else if (this.storageType === 's3' && this.config.s3.enabled) {
      this.initS3(this.config.s3);
    } else if (this.storageType === 'minio' && this.config.minio.enabled) {
      this.initMinio(this.config.minio);
    }
  }

  initGoogleDrive(config) {
    const credentials = require(path.resolve(config.credentialsPath));
    const auth = new google.auth.GoogleAuth({
      credentials,
      scopes: ['https://www.googleapis.com/auth/drive.file']
    });
    this.drive = google.drive({ version: 'v3', auth });
  }

  initS3(config) {
    this.s3 = new AWS.S3({
      region: config.region,
      accessKeyId: config.accessKeyId,
      secretAccessKey: config.secretAccessKey
    });
    this.s3Bucket = config.bucket;
  }

  initMinio(config) {
    this.s3 = new AWS.S3({
      endpoint: config.endpoint,
      accessKeyId: config.accessKeyId,
      secretAccessKey: config.secretAccessKey,
      s3ForcePathStyle: true,
      signatureVersion: 'v4',
      sslEnabled: config.useSSL
    });
    this.s3Bucket = config.bucket;
  }

  async upload(filePath, type, filename) {
    if (this.storageType === 'googleDrive') {
      return this._uploadToGoogleDrive(filePath, type, filename);
    } else if (this.storageType === 's3' || this.storageType === 'minio') {
      return this._uploadToS3(filePath, filename);
    }
    return null;
  }

  async _uploadToGoogleDrive(filePath, type, filename) {
    if (!this.drive) return;
    const folderMap = {
      voiceover: this.config.googleDrive.folders.voiceovers,
      image: this.config.googleDrive.folders.images,
      final: this.config.googleDrive.folders.finals
    };
    const folderId = folderMap[type];
    const baseName = path.basename(filePath);
    try {
      const response = await this.drive.files.create({
        requestBody: {
          name: type === 'image' ? `Images_${filename}` : baseName,
          parents: [folderId]
        },
        media: { body: fs.createReadStream(filePath) }
      });
      logger.info(`Uploaded to Google Drive: ${response.data.id}`);
      return response.data;
    } catch (error) {
      logger.error(`Google Drive upload failed: ${error.message}`);
      throw error;
    }
  }

  async _uploadToS3(filePath, filename) {
    if (!this.s3) return;
    const fileContent = fs.readFileSync(filePath);
    const key = path.basename(filePath);
    try {
      const response = await this.s3.upload({
        Bucket: this.s3Bucket,
        Key: key,
        Body: fileContent
      }).promise();
      logger.info(`Uploaded to ${this.storageType}: ${response.Location}`);
      return response;
    } catch (error) {
      logger.error(`${this.storageType} upload failed: ${error.message}`);
      throw error;
    }
  }
}

module.exports = StorageService;
