const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs').promises;

/**
 * Template APK Packager - No compile path
 *
 * Relies on system zip/unzip and optionally apksigner if available.
 * On macOS, zip/unzip are available by default.
 */
class TemplateAPKPackager {
  constructor() {
    this.tempRoot = path.join(__dirname, '../temp');
  }

  async packageAPK(options) {
    const {
      templateApkPath,
      bundleDir,
      outputDir,
      outFileName = `Packaged_${Date.now()}.apk`,
      signOptions // { keystorePath, alias, storepass, keypass }
    } = options;

    const workDir = path.join(this.tempRoot, `apkpack_${Date.now()}`);
    const unpackDir = path.join(workDir, 'unpacked');
    const unsignedApk = path.join(workDir, 'unsigned.apk');
    const finalApk = path.join(outputDir, outFileName);

    try {
      await fs.mkdir(this.tempRoot, { recursive: true });
      await fs.mkdir(workDir, { recursive: true });
      await fs.mkdir(unpackDir, { recursive: true });

      // 1) Unzip template APK
      await this.run('unzip', ['-q', templateApkPath, '-d', unpackDir]);

      // 2) Inject bundle into assets/bundle
      const assetsDir = path.join(unpackDir, 'assets');
      const bundleAssetsDir = path.join(assetsDir, 'bundle');

      await fs.mkdir(assetsDir, { recursive: true });
      // Clean existing bundle dir if exists
      await this.rmDirSafe(bundleAssetsDir);
      await fs.mkdir(bundleAssetsDir, { recursive: true });

      // Copy bundle.json
      await fs.copyFile(path.join(bundleDir, 'bundle.json'), path.join(bundleAssetsDir, 'bundle.json'));

      // Copy media folder recursively
      await this.copyDir(path.join(bundleDir, 'media'), path.join(bundleAssetsDir, 'media'));

      // Add marker file
      await fs.writeFile(path.join(bundleAssetsDir, '.embedded'), JSON.stringify({ embedded: true, createdAt: new Date().toISOString() }), 'utf8');

      // 3) Zip back up (unsigned)
      // zip -r9 unsigned.apk .  (run inside unpackDir)
      await this.run('zip', ['-r9', unsignedApk, '.'], { cwd: unpackDir });

      // 4) Try to align (optional)
      const zipalignOk = await this.tryRun('zipalign', ['-p', '4', unsignedApk, unsignedApk + '.aligned']);
      const alignedApk = zipalignOk ? unsignedApk + '.aligned' : unsignedApk;

      // 5) Sign if credentials provided and apksigner available
      let signed = false;
      if (signOptions && signOptions.keystorePath && signOptions.alias && (await this.hasCommand('apksigner'))) {
        const args = [
          'sign',
          '--ks', signOptions.keystorePath,
          '--ks-key-alias', signOptions.alias,
        ];
        if (signOptions.storepass) args.push('--ks-pass', `pass:${signOptions.storepass}`);
        if (signOptions.keypass) args.push('--key-pass', `pass:${signOptions.keypass}`);
        args.push('--out', finalApk, alignedApk);

        await this.run('apksigner', args);
        signed = true;
      } else {
        // Fallback: output unsigned APK
        await fs.copyFile(alignedApk, finalApk);
      }

      return { success: true, apkPath: finalApk, signed };
    } catch (error) {
      return { success: false, error: error.message };
    } finally {
      // cleanup workspace
      await this.rmDirSafe(workDir);
    }
  }

  async hasCommand(cmd) {
    try {
      await this.run('which', [cmd]);
      return true;
    } catch {
      return false;
    }
  }

  run(cmd, args = [], opts = {}) {
    return new Promise((resolve, reject) => {
      const child = spawn(cmd, args, { shell: true, stdio: 'inherit', ...opts });
      child.on('error', reject);
      child.on('exit', code => {
        if (code === 0) resolve(); else reject(new Error(`${cmd} exited with code ${code}`));
      });
    });
  }

  async tryRun(cmd, args = [], opts = {}) {
    try {
      await this.run(cmd, args, opts);
      return true;
    } catch {
      return false;
    }
  }

  async rmDirSafe(dir) {
    try { await fs.rm(dir, { recursive: true, force: true }); } catch {}
  }

  async copyDir(src, dest) {
    await fs.mkdir(dest, { recursive: true });
    const entries = await fs.readdir(src, { withFileTypes: true }).catch(() => []);
    for (const entry of entries) {
      const s = path.join(src, entry.name);
      const d = path.join(dest, entry.name);
      if (entry.isDirectory()) await this.copyDir(s, d);
      else await fs.copyFile(s, d);
    }
  }
}

module.exports = TemplateAPKPackager;
