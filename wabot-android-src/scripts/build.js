#!/usr/bin/env node
  /**
   * build.js — Bundle wabot-android avec esbuild (auto-retry sur modules non résolus)
   */
  const { execFileSync, spawnSync } = require('child_process');
  const path = require('path');
  const fs = require('fs');

  const ROOT = path.join(__dirname, '..');
  const ESBUILD = path.join(ROOT, 'node_modules', '.bin', 'esbuild');

  // Modules connus comme incompatibles Android (binaires natifs, Python, etc.)
  const KNOWN_EXTERNALS = [
    'bufferutil', 'utf-8-validate', 'canvas',
    'fluent-ffmpeg', 'sharp', 'puppeteer', 'bcrypt', 'ytdl-core',
    'gtts', 'file-type', '@google-cloud/text-to-speech',
    'ffmpeg-static', '@ffmpeg/ffmpeg', 'sox', 'node-opus', 'opusscript',
  ];

  // Aliases vers les mocks Android
  const ALIASES = [
    '--alias:fluent-ffmpeg=./android-mocks/ffmpeg.js',
    '--alias:sharp=./android-mocks/sharp.js',
    '--alias:puppeteer=./android-mocks/puppeteer.js',
    '--alias:bcrypt=./android-mocks/bcrypt.js',
    '--alias:ytdl-core=./android-mocks/ytdl.js',
  ];

  function buildArgs(externals) {
    return [
      'main.js',
      '--bundle',
      '--platform=node',
      '--format=cjs',
      '--outfile=bundle.js',
      '--log-level=warning',
      ...externals.map(e => '--external:' + e),
      ...ALIASES,
    ];
  }

  function tryBuild(externals) {
    const args = buildArgs(externals);
    const result = spawnSync(ESBUILD, args, {
      cwd: ROOT,
      encoding: 'utf8',
      maxBuffer: 50 * 1024 * 1024,
    });
    return result;
  }

  console.log('🔨 Build Android — auto-retry sur modules non résolus...');

  let externals = [...KNOWN_EXTERNALS];
  let attempt = 0;
  const MAX_ATTEMPTS = 5;

  while (attempt < MAX_ATTEMPTS) {
    attempt++;
    console.log('\nTentative ' + attempt + '/' + MAX_ATTEMPTS + ' (' + externals.length + ' externals)');
    
    const result = tryBuild(externals);
    const stderr = result.stderr || '';
    const stdout = result.stdout || '';
    
    if (result.status === 0) {
      const size = fs.existsSync(path.join(ROOT, 'bundle.js'))
        ? (fs.statSync(path.join(ROOT, 'bundle.js')).size / 1024 / 1024).toFixed(1)
        : '?';
      console.log('✅ bundle.js créé: ' + size + ' MB');
      process.exit(0);
    }
    
    // Extraire les modules non résolus
    const unresolvedRe = /Could not resolve "([^"]+)"/g;
    const combined = stderr + stdout;
    const newExternals = [];
    let match;
    while ((match = unresolvedRe.exec(combined)) !== null) {
      const mod = match[1];
      if (!externals.includes(mod) && !mod.startsWith('.')) {
        newExternals.push(mod);
        console.log('  ➕ external: ' + mod);
      }
    }
    
    if (newExternals.length === 0) {
      // Pas de nouveaux modules — erreur non récupérable
      console.error('\n❌ esbuild a échoué sans modules non résolus:');
      console.error(stderr.substring(0, 3000));
      process.exit(1);
    }
    
    externals = [...externals, ...newExternals];
  }

  console.error('❌ Trop de tentatives (' + MAX_ATTEMPTS + ')');
  process.exit(1);
  