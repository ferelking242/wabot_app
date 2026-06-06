#!/usr/bin/env node
  /**
   * build.js — Bundle wabot-android avec esbuild pour Android (nodejs-mobile)
   */
  const { execFileSync } = require('child_process');
  const path = require('path');

  const args = [
    'main.js',
    '--bundle',
    '--platform=node',
    '--format=cjs',
    '--outfile=bundle.js',
    '--log-limit=0',
    // Modules natifs C++ à exclure
    '--external:bufferutil',
    '--external:utf-8-validate',
    '--external:canvas',
    // Modules Python/binaires incompatibles Android
    '--external:gtts',
    '--external:file-type',
    '--external:@google-cloud/text-to-speech',
    '--external:ffmpeg-static',
    '--external:@ffmpeg/ffmpeg',
    '--external:sox',
    '--external:node-opus',
    '--external:opusscript',
    // Aliases vers les mocks Android
    '--alias:fluent-ffmpeg=./android-mocks/ffmpeg.js',
    '--alias:sharp=./android-mocks/sharp.js',
    '--alias:puppeteer=./android-mocks/puppeteer.js',
    '--alias:bcrypt=./android-mocks/bcrypt.js',
    '--alias:ytdl-core=./android-mocks/ytdl.js',
  ];

  console.log('🔨 esbuild:', args.slice(0, 5).join(' '), '...');
  try {
    execFileSync(
      path.join(__dirname, '..', 'node_modules', '.bin', 'esbuild'),
      args,
      { stdio: 'inherit', cwd: path.join(__dirname, '..') }
    );
    const fs = require('fs');
    const size = fs.statSync(path.join(__dirname, '..', 'bundle.js')).size;
    console.log(`✅ bundle.js créé: ${(size / 1024 / 1024).toFixed(1)} MB`);
  } catch (e) {
    console.error('❌ esbuild failed:', e.message);
    process.exit(1);
  }
  