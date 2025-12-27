const { google } = require('googleapis');
const Minio = require('minio');
const fs = require('fs');
const path = require('path');
const logger = require('../utils/logger');

class StorageService {
  constructor(config) {
    this.config = config.storage;
    this.storageType = this.config.provider;

    if (this.storageType === 'googleDrive' && this.config.googleDrive.enabled) {
      this.initGoogleDrive(this.config.googleDrive);
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

  initMinio(config) {
    let endPoint = config.endpoint;
    if (endPoint.startsWith('http://')) {
      endPoint = endPoint.replace('http://', '');
    } else if (endPoint.startsWith('https://')) {
      endPoint = endPoint.replace('https://', '');
    }

    let port = config.port;
    if (endPoint.includes(':')) {
      const parts = endPoint.split(':');
      endPoint = parts[0];
      port = parseInt(parts[1]);
    }

    this.minioClient = new Minio.Client({
      endPoint: endPoint,
      port: port,
      useSSL: config.useSSL,
      accessKey: config.accessKeyId,
      secretKey: config.secretAccessKey
    });
    this.bucket = config.bucket;
  }

  async upload(filePath, type, filename) {
    if (this.storageType === 'googleDrive') {
      return this._uploadToGoogleDrive(filePath, type, filename);
    } else if (this.storageType === 'minio') {
      return this._uploadToMinio(filePath, filename);
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

  async _uploadToMinio(filePath, filename) {
    if (!this.minioClient) return;
    const key = path.basename(filePath);
    
    try {
      const bucketExists = await this.minioClient.bucketExists(this.bucket);
      if (!bucketExists) {
        await this.minioClient.makeBucket(this.bucket, 'us-east-1');
        logger.info(`Bucket ${this.bucket} created.`);
      }

      await this.minioClient.fPutObject(this.bucket, key, filePath, {
        'Content-Type': 'application/octet-stream'
      });
      
      logger.info(`Uploaded to MinIO: ${key}`);
      return key;
    } catch (error) {
      logger.error(`MinIO upload failed: ${error.message}`);
      throw error;
    }
  }
}

module.exports = StorageService;