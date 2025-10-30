const { ipcRenderer } = require('electron');

let mediaFiles = [];

// DOM Elements
const bundleNameInput = document.getElementById('bundle-name');
const deviceIdsInput = document.getElementById('device-ids');
const deviceIdsDisplay = document.getElementById('device-ids-display');
const maxPlaysInput = document.getElementById('max-plays');
const resetDaysInput = document.getElementById('reset-days');
const resetHoursInput = document.getElementById('reset-hours');
const resetMinutesInput = document.getElementById('reset-minutes');
const intervalDaysInput = document.getElementById('interval-days');
const intervalHoursInput = document.getElementById('interval-hours');
const intervalMinutesInput = document.getElementById('interval-minutes');
const maxPlaysTotalInput = document.getElementById('max-plays-total');
const expirationDateInput = document.getElementById('expiration-date');
const addMediaButton = document.getElementById('add-media-button');
const mediaList = document.getElementById('media-list');
const createBundleButton = document.getElementById('create-bundle-button');
const messageContainer = document.getElementById('message-container');
const loadingDiv = document.getElementById('loading');

// Event Listeners
deviceIdsInput.addEventListener('input', updateDeviceIdsDisplay);
addMediaButton.addEventListener('click', handleAddMedia);
createBundleButton.addEventListener('click', handleCreateBundle);

// Functions
function calculatePlaybackLimit() {
  const resetDays = parseInt(resetDaysInput.value) || 0;
  const resetHours = parseInt(resetHoursInput.value) || 0;
  const resetMinutes = parseInt(resetMinutesInput.value) || 0;
  const resetIntervalMs = (resetDays * 24 * 60 * 60 * 1000) + (resetHours * 60 * 60 * 1000) + (resetMinutes * 60 * 1000);
  
  const intervalDays = parseInt(intervalDaysInput.value) || 0;
  const intervalHours = parseInt(intervalHoursInput.value) || 0;
  const intervalMinutes = parseInt(intervalMinutesInput.value) || 0;
  const minIntervalMs = (intervalDays * 24 * 60 * 60 * 1000) + (intervalHours * 60 * 60 * 1000) + (intervalMinutes * 60 * 1000);
  
  const maxPlaysTotalValue = maxPlaysTotalInput.value.trim();
  const maxPlaysTotal = maxPlaysTotalValue ? parseInt(maxPlaysTotalValue) : null;
  
  return {
    maxPlays: parseInt(maxPlaysInput.value),
    resetIntervalMs: resetIntervalMs || 24 * 60 * 60 * 1000, // Default to 24 hours
    minIntervalBetweenPlaysMs: minIntervalMs || null,
    maxPlaysTotal: maxPlaysTotal
  };
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

    const playbackLimit = calculatePlaybackLimit();

    for (const filePath of filePaths) {
      const fileInfo = await ipcRenderer.invoke('get-file-info', filePath);
      
      if (fileInfo) {
        mediaFiles.push({
          path: filePath,
          name: fileInfo.name,
          size: fileInfo.size,
          type: fileInfo.type,
          title: fileInfo.name.replace(/\.[^/.]+$/, ''),
          playbackLimit: { ...playbackLimit }
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
    
    // Format time intervals for display
    const resetMs = file.playbackLimit.resetIntervalMs || 0;
    const resetDays = Math.floor(resetMs / (24 * 60 * 60 * 1000));
    const resetHours = Math.floor((resetMs % (24 * 60 * 60 * 1000)) / (60 * 60 * 1000));
    const resetMinutes = Math.floor((resetMs % (60 * 60 * 1000)) / (60 * 1000));
    const resetStr = [
      resetDays > 0 ? `${resetDays}d` : '',
      resetHours > 0 ? `${resetHours}h` : '',
      resetMinutes > 0 ? `${resetMinutes}m` : ''
    ].filter(s => s).join(' ') || '0m';

    const minIntervalMs = file.playbackLimit.minIntervalBetweenPlaysMs || 0;
    const intervalDays = Math.floor(minIntervalMs / (24 * 60 * 60 * 1000));
    const intervalHours = Math.floor((minIntervalMs % (24 * 60 * 60 * 1000)) / (60 * 60 * 1000));
    const intervalMinutes = Math.floor((minIntervalMs % (60 * 60 * 1000)) / (60 * 1000));
    const intervalStr = minIntervalMs > 0 ? [
      intervalDays > 0 ? `${intervalDays}d` : '',
      intervalHours > 0 ? `${intervalHours}h` : '',
      intervalMinutes > 0 ? `${intervalMinutes}m` : ''
    ].filter(s => s).join(' ') : 'None';

    const maxTotalStr = file.playbackLimit.maxPlaysTotal ? `Max total: ${file.playbackLimit.maxPlaysTotal}` : 'No lifetime limit';

    item.innerHTML = `
      <div class="media-info">
        <div class="media-name">${file.name}</div>
        <div class="media-details">
          ${file.type.toUpperCase()} • ${sizeInMB} MB • 
          Max plays: ${file.playbackLimit.maxPlays} • 
          Reset: ${resetStr} • 
          Interval: ${intervalStr} • 
          ${maxTotalStr}
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
    const playbackLimit = calculatePlaybackLimit();

    if (maxPlays < 1) {
      showError('Maximum plays must be at least 1');
      return;
    }

    if (playbackLimit.resetIntervalMs < 60000) {
      showError('Reset interval must be at least 1 minute');
      return;
    }

    // Validate expiration date if set
    let expirationDate = null;
    if (expirationDateInput.value) {
      expirationDate = new Date(expirationDateInput.value).toISOString();
      if (new Date(expirationDate) <= new Date()) {
        showError('Expiration date must be in the future');
        return;
      }
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
        default: playbackLimit
      },
      expirationDate,
      outputDir
    });

    loadingDiv.classList.remove('active');
    createBundleButton.disabled = false;

    if (result.success) {
      showSuccess(`Bundle created successfully!
        
Location: ${result.bundleDir}
Bundle ID: ${result.bundleId}
Files processed: ${result.filesProcessed}
Archive: ${result.archiveName}

You can now transfer this secure .smbundle file to authorized devices.
The bundle is encrypted and compressed for security.`);
      
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
