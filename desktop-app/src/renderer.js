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
const messageContainer = document.getElementById('message-container');
const loadingDiv = document.getElementById('loading');

// Event Listeners
deviceIdsInput.addEventListener('input', updateDeviceIdsDisplay);
addMediaButton.addEventListener('click', handleAddMedia);
createBundleButton.addEventListener('click', handleCreateBundle);

// Functions
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
