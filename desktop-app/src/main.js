const { app, BrowserWindow, ipcMain, dialog } = require('electron');
const path = require('path');
const fs = require('fs').promises;
const { v4: uuidv4 } = require('uuid');
const { createBundleConfig } = require('@scripture-media/shared');
const { encrypt, generateDeviceKey } = require('@scripture-media/shared');
// Shared config encryption key (must match mobile app)
const CONFIG_SHARED_KEY = 'scripture-media-config-v1';
const tar = require('tar');
const crypto = require('crypto');

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
      // Limit to formats widely supported on Android via ExoPlayer
      { name: 'Media Files (Android-friendly)', extensions: ['mp3', 'mp4', 'm4a', 'wav'] },
      { name: 'All Files', extensions: ['*'] }
    ]
  });

  if (result.canceled) {
    return [];
  }

  return result.filePaths;
});

ipcMain.handle('select-output-directory', async (event, opts) => {
  const defaultPath = opts && typeof opts === 'object' ? opts.defaultPath : undefined;
  const dialogOptions = {
    properties: ['openDirectory', 'createDirectory']
  };
  if (defaultPath && typeof defaultPath === 'string') {
    dialogOptions.defaultPath = defaultPath;
  }
  const result = await dialog.showOpenDialog(mainWindow, dialogOptions);

  if (result.canceled) {
    return null;
  }

  return result.filePaths[0];
});

ipcMain.handle('create-bundle', async (event, bundleData) => {
  try {
    const { name, deviceIds, mediaFiles, playbackLimits, playlistLimits, expirationDate, outputDir } = bundleData;
    
    // Generate bundle ID and secure bundle key
    const bundleId = `bundle_${name.replace(/\s+/g, '_')}_${Date.now()}`;
  const bundleKey = crypto.randomBytes(32).toString('hex'); // Random key for bundle encryption
    
    // Create temporary bundle directory
    const tempDir = path.join(require('os').tmpdir(), bundleId);
    await fs.mkdir(tempDir, { recursive: true });
    
    // Create media directory
    const mediaDir = path.join(tempDir, 'media');
    await fs.mkdir(mediaDir, { recursive: true });

  // Process and protect media files (lightweight obfuscation to reduce device CPU/memory)
    const processedMediaFiles = [];
    
    const supportedVideo = /\.(mp4)$/i;
    const supportedAudio = /\.(mp3|m4a|wav)$/i;
  for (const mediaFile of mediaFiles) {
      try {
        const mediaId = uuidv4();
        const fileExt = path.extname(mediaFile.path);
        const lowerExt = fileExt.toLowerCase();
        if (!supportedVideo.test(lowerExt) && !supportedAudio.test(lowerExt)) {
          throw new Error(`Unsupported media type for Android: ${fileExt}. Supported: .mp4 (H.264/AAC), .mp3, .m4a, .wav`);
        }
  const encryptedFileName = `${mediaId}${fileExt}.obf`;
  const encryptedPath = path.join(mediaDir, encryptedFileName);

        // Stream obfuscation: XOR-based keystream (not cryptographically secure)
        // to make files non-playable outside our app with minimal device cost.
        const keyBytes = Buffer.from(bundleKey, 'hex');
        const salt = crypto.randomBytes(8); // per-file salt
        // Stream, obfuscate, and compute checksum of original content in a single pass
        const checksumHasher = crypto.createHash('sha256');
        await new Promise((resolve, reject) => {
          const rs = require('fs').createReadStream(mediaFile.path);
          const ws = require('fs').createWriteStream(encryptedPath);
          let offset = 0;
          rs.on('data', (chunk) => {
            // Update checksum with original bytes
            checksumHasher.update(chunk);
            // Obfuscate chunk
            const out = Buffer.allocUnsafe(chunk.length);
            for (let i = 0; i < chunk.length; i++) {
              const pos = offset + i;
              const k = keyBytes[pos % keyBytes.length];
              const s = salt[pos % salt.length];
              const mask = (k ^ s ^ ((pos * 31) & 0xff)) & 0xff;
              out[i] = chunk[i] ^ mask;
            }
            ws.write(out);
            offset += chunk.length;
          });
          rs.on('error', reject);
          ws.on('error', reject);
          rs.on('end', () => ws.end());
          ws.on('finish', resolve);
        });

        // Calculate checksum (of original content) for verification
        const checksum = checksumHasher.digest('hex');
        
        processedMediaFiles.push({
          id: mediaId,
          fileName: path.basename(mediaFile.path),
          title: mediaFile.title || path.basename(mediaFile.path, fileExt),
          type: mediaFile.type || (supportedVideo.test(lowerExt) ? 'video' : 'audio'),
          encryptedPath: `media/${encryptedFileName}`,
          protection: { scheme: 'xor-v1', salt: salt.toString('base64') },
          checksum: checksum,
          playbackLimit: mediaFile.playbackLimit || playbackLimits.default
        });
      } catch (error) {
        console.error(`Failed to process media file ${mediaFile.path}:`, error);
        throw error;
      }
    }

    // Build per-device wrapped keys: deviceId -> AES(passphrase) ciphertext
    const bundleKeyEncryptedForDevices = {};
    for (const id of deviceIds) {
      const deviceKey = generateDeviceKey(id, 'scripture-media-app-2024');
      bundleKeyEncryptedForDevices[id] = encrypt(bundleKey, deviceKey);
    }

    // Create bundle configuration
    const bundleConfig = createBundleConfig({
      bundleId,
      allowedDeviceIds: deviceIds,
      mediaFiles: processedMediaFiles,
      playbackLimits,
      playlistLimits,
      expirationDate,
      bundleKeyEncryptedForDevices,
      integrity: crypto.createHash('sha256').update(JSON.stringify({
        bundleId,
        allowedDeviceIds: deviceIds,
        mediaFiles: processedMediaFiles,
        playbackLimits,
        playlistLimits,
        expirationDate
      })).digest('hex')
    });

  // Encrypt the bundle configuration using a shared key
  const configJson = JSON.stringify(bundleConfig, null, 2);
  const encryptedConfig = encrypt(configJson, CONFIG_SHARED_KEY);
    
    // Write encrypted bundle configuration with .smb extension (Scripture Media Bundle)
    const configPath = path.join(tempDir, 'bundle.smb');
    await fs.writeFile(configPath, encryptedConfig, 'utf8');

    // Create README with updated instructions
    const readmePath = path.join(tempDir, 'README.txt');
    // Derive human-friendly reset interval (hours) if provided in ms
    const resetMs = playbackLimits && playbackLimits.default && typeof playbackLimits.default.resetIntervalMs === 'number'
      ? playbackLimits.default.resetIntervalMs
      : null;
    const resetHours = resetMs != null ? Math.round(resetMs / (60 * 60 * 1000)) : 'N/A';
    const readmeContent = `Scripture Media Bundle
======================

Bundle ID: ${bundleId}
Created: ${new Date().toLocaleString()}

Authorized Devices: ${deviceIds.length}
Media Files: ${processedMediaFiles.length}

Playback Limits:
- Max plays per file: ${playbackLimits.default.maxPlays}
- Reset interval: ${resetHours} hours

To use this bundle:
1. Transfer the entire .smbundle file to the mobile device
2. Import the bundle in the Scripture Media app
3. The app will verify device authorization before allowing access

SECURITY NOTICE:
- This bundle is protected and compressed
- Media is protected with a per-bundle key that is wrapped for each authorized device
- The configuration is encrypted with a shared key between desktop and mobile
- Tampering with the bundle will prevent it from working
- Only authorized devices can unwrap the content key and use this content

Note: This bundle can only be accessed by specifically authorized devices.
Do not attempt to modify the bundle file as it will become unusable.
`;
    await fs.writeFile(readmePath, readmeContent, 'utf8');

    // Create bundle manifest for integrity checking
    const manifestPath = path.join(tempDir, 'manifest.json');
    const manifest = {
      version: '2.2',
      bundleId,
      created: new Date().toISOString(),
      files: processedMediaFiles.length,
      devices: deviceIds.length,
      checksum: crypto.createHash('sha256').update(configJson).digest('hex')
    };
    await fs.writeFile(manifestPath, JSON.stringify(manifest, null, 2), 'utf8');

    // Create compressed archive with custom extension
    const archiveName = `${bundleId}.smbundle`;
    const archivePath = path.join(outputDir, archiveName);
    
    // Create tar.gz archive
    await tar.create(
      {
        // Use a compatible ustar format to avoid PAX headers and keep filenames ASCII-safe
        format: 'ustar',
        portable: true,
        // Choose a moderate gzip level to reduce on-device CPU for decompression
        gzip: { level: 6 },
        file: archivePath,
        cwd: tempDir,
        noMtime: true,
      },
      ['.'] // Include all files in temp directory
    );

    // Clean up temporary directory
    await fs.rm(tempDir, { recursive: true, force: true });

    return {
      success: true,
      bundleDir: archivePath,
      bundleId,
      filesProcessed: processedMediaFiles.length,
      archiveName
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
      type: ext.match(/\.(mp4)$/i) ? 'video' : 'audio',
      ext: ext
    };
  } catch (error) {
    console.error('Failed to get file info:', error);
    return null;
  }
});
