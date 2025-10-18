const { app, BrowserWindow, ipcMain, dialog } = require('electron');
const path = require('path');
const fs = require('fs').promises;
const { v4: uuidv4 } = require('uuid');
const { createBundleConfig, encrypt, generateDeviceKey } = require('@scripture-media/shared');

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false,
    },
  });

  mainWindow.loadFile(path.join(__dirname, 'index.html'));
  
  // Open DevTools in development
  if (process.env.NODE_ENV === 'development') {
    mainWindow.webContents.openDevTools();
  }
}

app.whenReady().then(() => {
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

// IPC Handlers

ipcMain.handle('select-media-files', async () => {
  const result = await dialog.showOpenDialog(mainWindow, {
    properties: ['openFile', 'multiSelections'],
    filters: [
      { name: 'Media Files', extensions: ['mp3', 'mp4', 'wav', 'm4a', 'webm', 'avi', 'mov'] },
      { name: 'All Files', extensions: ['*'] }
    ]
  });

  if (result.canceled) {
    return [];
  }

  return result.filePaths;
});

ipcMain.handle('select-output-directory', async () => {
  const result = await dialog.showOpenDialog(mainWindow, {
    properties: ['openDirectory', 'createDirectory']
  });

  if (result.canceled) {
    return null;
  }

  return result.filePaths[0];
});

ipcMain.handle('create-bundle', async (event, bundleData) => {
  try {
    const { name, deviceIds, mediaFiles, playbackLimits, outputDir } = bundleData;
    
    // Generate bundle ID
    const bundleId = `bundle_${name.replace(/\s+/g, '_')}_${Date.now()}`;
    
    // Create bundle directory
    const bundleDir = path.join(outputDir, bundleId);
    await fs.mkdir(bundleDir, { recursive: true });
    
    // Create media directory
    const mediaDir = path.join(bundleDir, 'media');
    await fs.mkdir(mediaDir, { recursive: true });

    // Process and encrypt media files
    const processedMediaFiles = [];
    
    for (const mediaFile of mediaFiles) {
      try {
        const mediaId = uuidv4();
        const fileExt = path.extname(mediaFile.path);
        const encryptedFileName = `${mediaId}.enc`;
        const encryptedPath = path.join(mediaDir, encryptedFileName);
        
        // Read media file
        const fileData = await fs.readFile(mediaFile.path);
        const base64Data = fileData.toString('base64');
        
        // Encrypt with a device-specific key
        // For simplicity, using the first device ID as the base
        const deviceKey = generateDeviceKey(deviceIds[0], 'scripture-media-app-2024');
        const encryptedData = encrypt(base64Data, deviceKey);
        
        // Write encrypted file
        await fs.writeFile(encryptedPath, encryptedData, 'utf8');
        
        // Calculate file checksum (simple hash for verification)
        const crypto = require('crypto');
        const checksum = crypto.createHash('sha256').update(fileData).digest('hex');
        
        processedMediaFiles.push({
          id: mediaId,
          fileName: path.basename(mediaFile.path),
          title: mediaFile.title || path.basename(mediaFile.path, fileExt),
          type: mediaFile.type || (fileExt.match(/\.(mp4|avi|mov|webm)$/i) ? 'video' : 'audio'),
          encryptedPath: `media/${encryptedFileName}`,
          checksum: checksum,
          playbackLimit: mediaFile.playbackLimit || playbackLimits.default
        });
      } catch (error) {
        console.error(`Failed to process media file ${mediaFile.path}:`, error);
        throw error;
      }
    }

    // Create bundle configuration
    const bundleConfig = createBundleConfig({
      bundleId,
      allowedDeviceIds: deviceIds,
      mediaFiles: processedMediaFiles,
      playbackLimits
    });

    // Write bundle configuration
    const configPath = path.join(bundleDir, 'bundle.json');
    await fs.writeFile(configPath, JSON.stringify(bundleConfig, null, 2), 'utf8');

    // Create README
    const readmePath = path.join(bundleDir, 'README.txt');
    const readmeContent = `Scripture Media Bundle
======================

Bundle ID: ${bundleId}
Created: ${new Date().toLocaleString()}

Authorized Devices: ${deviceIds.length}
Media Files: ${processedMediaFiles.length}

Playback Limits:
- Max plays per file: ${playbackLimits.default.maxPlays}
- Reset interval: ${playbackLimits.default.resetIntervalHours} hours

To use this bundle:
1. Copy the entire bundle directory to the mobile device
2. Import the bundle in the Scripture Media app
3. The app will verify device authorization before allowing access

Note: This bundle is encrypted and can only be accessed by authorized devices.
`;
    await fs.writeFile(readmePath, readmeContent, 'utf8');

    return {
      success: true,
      bundleDir,
      bundleId,
      filesProcessed: processedMediaFiles.length
    };
  } catch (error) {
    console.error('Failed to create bundle:', error);
    return {
      success: false,
      error: error.message
    };
  }
});

ipcMain.handle('get-file-info', async (event, filePath) => {
  try {
    const stats = await fs.stat(filePath);
    const ext = path.extname(filePath).toLowerCase();
    
    return {
      path: filePath,
      name: path.basename(filePath),
      size: stats.size,
      type: ext.match(/\.(mp4|avi|mov|webm)$/i) ? 'video' : 'audio',
      ext: ext
    };
  } catch (error) {
    console.error('Failed to get file info:', error);
    return null;
  }
});
