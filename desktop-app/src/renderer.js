const { ipcRenderer } = require('electron');

let mediaFiles = [];

// DOM Elements
const bundleNameInput = document.getElementById('bundle-name');
const deviceIdsInput = document.getElementById('device-ids');
const deviceIdsDisplay = document.getElementById('device-ids-display');
const maxPlaysInput = document.getElementById('max-plays');
const resetHoursInput = document.getElementById('reset-hours');
const addMediaButton = document.getElementById('add-media-button');
const mediaList = document.getElementById('media-list');
const createBundleButton = document.getElementById('create-bundle-button');
const buildAPKButton = document.getElementById('build-apk-button');
const messageContainer = document.getElementById('message-container');
const loadingDiv = document.getElementById('loading');
const loadingText = document.getElementById('loading-text');
const outputTypeRadios = document.querySelectorAll('input[name="output-type"]');
const apkOptions = document.getElementById('apk-options');
const appNameInput = document.getElementById('app-name');
const environmentStatus = document.getElementById('environment-status');
const statusIndicator = document.getElementById('status-indicator');
const statusText = document.getElementById('status-text');
const statusDetails = document.getElementById('status-details');

// Event Listeners
deviceIdsInput.addEventListener('input', updateDeviceIdsDisplay);
addMediaButton.addEventListener('click', handleAddMedia);
createBundleButton.addEventListener('click', handleCreateBundle);
buildAPKButton.addEventListener('click', handleBuildAPK);

outputTypeRadios.forEach(radio => {
  radio.addEventListener('change', handleOutputTypeChange);
});

// Listen for APK build progress
ipcRenderer.on('apk-build-progress', (event, message) => {
  loadingText.textContent = message;
});

// Hook up optional template packaging controls if present
function setupTemplatePackagingControls() {
  const pkgBtn = document.getElementById('package-template-button');
  if (!pkgBtn) return; // feature not present in UI

  pkgBtn.addEventListener('click', handlePackageFromTemplate);
}

// Functions
function handleOutputTypeChange() {
  const selectedType = document.querySelector('input[name="output-type"]:checked').value;
  
  if (selectedType === 'apk') {
    apkOptions.style.display = 'block';
    environmentStatus.style.display = 'block';
    createBundleButton.style.display = 'none';
    buildAPKButton.style.display = 'inline-block';
    
    // Check environment when APK option is selected
    checkAPKEnvironment();
  } else {
    apkOptions.style.display = 'none';
    environmentStatus.style.display = 'none';
    createBundleButton.style.display = 'inline-block';
    buildAPKButton.style.display = 'none';
  }
}

// No-compile packaging using a template APK
async function handlePackageFromTemplate() {
  try {
    const templateApkPathInput = document.getElementById('template-apk-path');
    const keystorePathInput = document.getElementById('keystore-path');
    const aliasInput = document.getElementById('keystore-alias');
    const storepassInput = document.getElementById('keystore-storepass');
    const keypassInput = document.getElementById('keystore-keypass');

    if (!templateApkPathInput || !templateApkPathInput.value.trim()) {
      showError('Please select a template APK');
      return;
    }

    // Validate inputs
    const bundleName = bundleNameInput.value.trim();
    if (!bundleName) {
      showError('Please enter a bundle name');
      return;
    }

    const deviceIds = deviceIdsInput.value
      .split('\n')
      .map(id => id.trim())
      .filter(id => id.length > 0);

    if (deviceIds.length === 0) {
      showError('Please enter at least one device ID');
      return;
    }

    if (mediaFiles.length === 0) {
      showError('Please add at least one media file');
      return;
    }

    const maxPlays = parseInt(maxPlaysInput.value);
    const resetHours = parseInt(resetHoursInput.value);

    // Select output directory
    const outputDir = await ipcRenderer.invoke('select-output-directory');
    if (!outputDir) {
      return;
    }

    // Prepare sign options if provided
    const signOptions = (keystorePathInput && aliasInput && storepassInput && keystorePathInput.value && aliasInput.value && storepassInput.value)
      ? {
          keystorePath: keystorePathInput.value.trim(),
          alias: aliasInput.value.trim(),
          storepass: storepassInput.value.trim(),
          keypass: keypassInput?.value?.trim()
        }
      : undefined;

    loadingDiv.classList.add('active');
    loadingText.textContent = 'Packaging APK (no compile)...';

    const res = await ipcRenderer.invoke('package-apk-from-template', {
      templateApkPath: templateApkPathInput.value.trim(),
      bundleData: {
        name: bundleName,
        deviceIds,
        mediaFiles,
        playbackLimits: { default: { maxPlays, resetIntervalHours: resetHours } }
      },
      outputDir,
      outFileName: `${(appNameInput?.value?.trim() || bundleName).replace(/\s+/g, '_')}.apk`,
      signOptions
    });

    loadingDiv.classList.remove('active');

    if (res.success) {
      showSuccess(`APK packaged successfully!\n\nLocation: ${res.apkPath}\nSigned: ${res.signed ? 'Yes' : 'No (unsigned)'}\n`);
    } else {
      showError('Failed to package APK: ' + res.error);
    }
  } catch (error) {
    loadingDiv.classList.remove('active');
    showError('Failed to package APK: ' + error.message);
  }
}

async function checkAPKEnvironment() {
  try {
    statusText.textContent = 'Checking build environment...';
    statusIndicator.className = 'status-indicator';
    
    const result = await ipcRenderer.invoke('validate-apk-environment');
    
    if (result.valid) {
      environmentStatus.className = 'environment-status valid';
      statusText.textContent = 'Build environment ready ✓';
      statusDetails.innerHTML = '<p style="color: #28a745;">All required tools are available for APK building.</p>';
      buildAPKButton.disabled = false;
    } else {
      environmentStatus.className = 'environment-status invalid';
      statusText.textContent = 'Build environment issues found';
      statusDetails.innerHTML = `
        <p style="color: #dc3545;">The following issues need to be resolved:</p>
        <ul>
          ${result.errors.map(error => `<li>${error}</li>`).join('')}
        </ul>
        <p><small>Please resolve these issues before building APK.</small></p>
      `;
      buildAPKButton.disabled = true;
    }
  } catch (error) {
    environmentStatus.className = 'environment-status invalid';
    statusText.textContent = 'Failed to check environment';
    statusDetails.innerHTML = `<p style="color: #dc3545;">Error: ${error.message}</p>`;
    buildAPKButton.disabled = true;
  }
}

function updateDeviceIdsDisplay() {
  const deviceIds = deviceIdsInput.value
    .split('\n')
    .map(id => id.trim())
    .filter(id => id.length > 0);

  deviceIdsDisplay.innerHTML = '';
  
  if (deviceIds.length > 0) {
    deviceIds.forEach(id => {
      const tag = document.createElement('div');
      tag.className = 'device-id-tag';
      tag.textContent = id;
      deviceIdsDisplay.appendChild(tag);
    });
  }
}

async function handleAddMedia() {
  try {
    const filePaths = await ipcRenderer.invoke('select-media-files');
    
    if (filePaths.length === 0) {
      return;
    }

    for (const filePath of filePaths) {
      const fileInfo = await ipcRenderer.invoke('get-file-info', filePath);
      
      if (fileInfo) {
        mediaFiles.push({
          path: filePath,
          name: fileInfo.name,
          size: fileInfo.size,
          type: fileInfo.type,
          title: fileInfo.name.replace(/\.[^/.]+$/, ''),
          playbackLimit: {
            maxPlays: parseInt(maxPlaysInput.value),
            resetIntervalHours: parseInt(resetHoursInput.value)
          }
        });
      }
    }

    renderMediaList();
  } catch (error) {
    showError('Failed to add media files: ' + error.message);
  }
}

function renderMediaList() {
  if (mediaFiles.length === 0) {
    mediaList.innerHTML = '<div class="empty-state">No media files added yet</div>';
    return;
  }

  mediaList.innerHTML = '';

  mediaFiles.forEach((file, index) => {
    const item = document.createElement('div');
    item.className = 'media-item';

    const sizeInMB = (file.size / (1024 * 1024)).toFixed(2);

    item.innerHTML = `
      <div class="media-info">
        <div class="media-name">${file.name}</div>
        <div class="media-details">
          ${file.type.toUpperCase()} • ${sizeInMB} MB • 
          Max plays: ${file.playbackLimit.maxPlays} • 
          Reset: ${file.playbackLimit.resetIntervalHours}h
        </div>
      </div>
      <div class="media-settings">
        <button class="remove-button" data-index="${index}">Remove</button>
      </div>
    `;

    const removeButton = item.querySelector('.remove-button');
    removeButton.addEventListener('click', () => removeMedia(index));

    mediaList.appendChild(item);
  });
}

function removeMedia(index) {
  mediaFiles.splice(index, 1);
  renderMediaList();
}

async function handleBuildAPK() {
  try {
    // Validate inputs
    const bundleName = bundleNameInput.value.trim();
    if (!bundleName) {
      showError('Please enter a bundle name');
      return;
    }

    const appName = appNameInput.value.trim();
    if (!appName) {
      showError('Please enter an app name');
      return;
    }

    const deviceIds = deviceIdsInput.value
      .split('\n')
      .map(id => id.trim())
      .filter(id => id.length > 0);

    if (deviceIds.length === 0) {
      showError('Please enter at least one device ID');
      return;
    }

    if (mediaFiles.length === 0) {
      showError('Please add at least one media file');
      return;
    }

    const maxPlays = parseInt(maxPlaysInput.value);
    const resetHours = parseInt(resetHoursInput.value);

    if (maxPlays < 1 || resetHours < 1) {
      showError('Playback limits must be at least 1');
      return;
    }

    // Select output directory
    const outputDir = await ipcRenderer.invoke('select-output-directory');
    if (!outputDir) {
      return;
    }

    // Show loading
    loadingDiv.classList.add('active');
    loadingText.textContent = 'Preparing to build APK...';
    buildAPKButton.disabled = true;

    // Build APK
    const result = await ipcRenderer.invoke('build-apk', {
      bundleData: {
        name: bundleName,
        deviceIds,
        mediaFiles,
        playbackLimits: {
          default: {
            maxPlays,
            resetIntervalHours: resetHours
          }
        }
      },
      outputDir,
      appName
    });

    loadingDiv.classList.remove('active');
    buildAPKButton.disabled = false;

    if (result.success) {
      showSuccess(`APK built successfully!
        
Location: ${result.apkPath}
App Name: ${appName}

The APK contains the embedded bundle and is ready for installation on authorized devices.`);
      
      // Reset form
      bundleNameInput.value = '';
      appNameInput.value = '';
      deviceIdsInput.value = '';
      updateDeviceIdsDisplay();
      mediaFiles = [];
      renderMediaList();
    } else {
      showError('Failed to build APK: ' + result.error);
    }
  } catch (error) {
    loadingDiv.classList.remove('active');
    buildAPKButton.disabled = false;
    showError('Failed to build APK: ' + error.message);
  }
}

async function handleCreateBundle() {
  try {
    // Validate inputs
    const bundleName = bundleNameInput.value.trim();
    if (!bundleName) {
      showError('Please enter a bundle name');
      return;
    }

    const deviceIds = deviceIdsInput.value
      .split('\n')
      .map(id => id.trim())
      .filter(id => id.length > 0);

    if (deviceIds.length === 0) {
      showError('Please enter at least one device ID');
      return;
    }

    if (mediaFiles.length === 0) {
      showError('Please add at least one media file');
      return;
    }

    const maxPlays = parseInt(maxPlaysInput.value);
    const resetHours = parseInt(resetHoursInput.value);

    if (maxPlays < 1 || resetHours < 1) {
      showError('Playback limits must be at least 1');
      return;
    }

    // Select output directory
    const outputDir = await ipcRenderer.invoke('select-output-directory');
    if (!outputDir) {
      return;
    }

    // Show loading
    loadingDiv.classList.add('active');
    createBundleButton.disabled = true;

    // Create bundle
    const result = await ipcRenderer.invoke('create-bundle', {
      name: bundleName,
      deviceIds,
      mediaFiles,
      playbackLimits: {
        default: {
          maxPlays,
          resetIntervalHours: resetHours
        }
      },
      outputDir
    });

    loadingDiv.classList.remove('active');
    createBundleButton.disabled = false;

    if (result.success) {
      showSuccess(`Bundle created successfully!
        
Location: ${result.bundleDir}
Bundle ID: ${result.bundleId}
Files processed: ${result.filesProcessed}

You can now copy this bundle to authorized devices.`);
      
      // Reset form
      bundleNameInput.value = '';
      deviceIdsInput.value = '';
      updateDeviceIdsDisplay();
      mediaFiles = [];
      renderMediaList();
    } else {
      showError('Failed to create bundle: ' + result.error);
    }
  } catch (error) {
    loadingDiv.classList.remove('active');
    createBundleButton.disabled = false;
    showError('Failed to create bundle: ' + error.message);
  }
}

function showSuccess(message) {
  messageContainer.innerHTML = `
    <div class="success-message">
      <strong>Success!</strong><br>
      ${message.replace(/\n/g, '<br>')}
    </div>
  `;
  
  setTimeout(() => {
    messageContainer.innerHTML = '';
  }, 10000);
}

function showError(message) {
  messageContainer.innerHTML = `
    <div class="error-message">
      <strong>Error!</strong><br>
      ${message}
    </div>
  `;
  
  setTimeout(() => {
    messageContainer.innerHTML = '';
  }, 5000);
}

// Initialize
updateDeviceIdsDisplay();
handleOutputTypeChange(); // Set initial state based on default radio selection
setupTemplatePackagingControls();
