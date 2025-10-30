/* eslint-disable no-console */
const path = require('path');
const fs = require('fs');
const sharp = require('sharp');
const iconGen = require('icon-gen');

(async () => {
  try {
    const root = path.resolve(__dirname, '../../');
  const desktopSvg = path.join(root, 'assets', 'app_icon_desktop.svg');
  const mobileSvg = path.join(root, 'assets', 'app_icon_mobile.svg');
    const desktopBuildDir = path.resolve(__dirname, '../build');
    const mobileAssetsDir = path.resolve(root, 'mobile_app', 'assets');

    if (!fs.existsSync(desktopSvg)) {
      console.error('[icons] Desktop SVG source missing:', desktopSvg);
      process.exit(1);
    }
    if (!fs.existsSync(mobileSvg)) {
      console.error('[icons] Mobile SVG source missing:', mobileSvg);
      process.exit(1);
    }
    if (!fs.existsSync(desktopBuildDir)) fs.mkdirSync(desktopBuildDir, { recursive: true });
    if (!fs.existsSync(mobileAssetsDir)) fs.mkdirSync(mobileAssetsDir, { recursive: true });

    const pngPath = path.join(desktopBuildDir, 'icon.png');
    const mobilePng = path.join(mobileAssetsDir, 'app_icon_1024.png');

    console.log('[icons] Rendering desktop PNG from SVG (1024x1024)...');
    await sharp(desktopSvg)
      .resize(1024, 1024, { fit: 'cover' })
      .png({ compressionLevel: 9 })
      .toFile(pngPath);

    // Generate mobile app launcher base PNG from mobile-specific SVG
    await sharp(mobileSvg)
      .resize(1024, 1024, { fit: 'cover' })
      .png({ compressionLevel: 9 })
      .toFile(mobilePng);

    console.log('[icons] Generating ICNS and ICO from PNG...');
    await iconGen(pngPath, desktopBuildDir, { report: true, modes: ['icns', 'ico'] });

    console.log('[icons] Done.');
  } catch (err) {
    console.error('[icons] Failed:', err);
    process.exit(1);
  }
})();
